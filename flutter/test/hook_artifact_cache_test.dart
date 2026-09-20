import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../hook/build.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('ffmpeg_kit_cache_');
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('copies a local override when the destination is missing', () async {
    final source = File(p.join(tempRoot.path, 'source.zip'))
      ..writeAsBytesSync([1, 2, 3]);
    final destination = File(p.join(tempRoot.path, 'cache', 'source.zip'));

    final changed = await syncLocalOverride(source, destination);

    expect(changed, isTrue);
    expect(destination.readAsBytesSync(), equals([1, 2, 3]));
  });

  test('replaces a same-size changed local override', () async {
    final source = File(p.join(tempRoot.path, 'source.zip'))
      ..writeAsBytesSync([1, 2, 3, 4]);
    final destination = File(p.join(tempRoot.path, 'cache', 'source.zip'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([5, 6, 7, 8]);

    final changed = await syncLocalOverride(source, destination);

    expect(changed, isTrue);
    expect(destination.readAsBytesSync(), equals([1, 2, 3, 4]));
  });

  test('changed local override removes stale extracted artifact', () async {
    final source = File(p.join(tempRoot.path, 'bundles', 'source.zip'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    final cacheDir = Directory(p.join(tempRoot.path, 'cache'));
    final cachedArchive = File(p.join(cacheDir.path, 'source.zip'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([4, 5, 6]);
    final extractRoot = extractRootFor(cachedArchive, cacheDir);
    File(p.join(extractRoot.path, 'stale-file')).createSync(recursive: true);
    extractCompletionMarkerFor(extractRoot).createSync();
    final dependencies = <Uri>[];

    final cached = await resolveLocalOverrideToCache(
      overridePath: p.join('bundles', 'source.zip'),
      configBaseDir: tempRoot.path,
      cacheDir: cacheDir,
      addDependency: dependencies.add,
    );

    expect(cached.readAsBytesSync(), equals([1, 2, 3]));
    expect(extractRoot.existsSync(), isFalse);
    expect(dependencies, contains(source.uri));
  });

  test('does not copy an identical local override', () async {
    final source = File(p.join(tempRoot.path, 'source.zip'))
      ..writeAsBytesSync([1, 2, 3]);
    final destination = File(p.join(tempRoot.path, 'cache', 'source.zip'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);

    final changed = await syncLocalOverride(source, destination);

    expect(changed, isFalse);
    expect(destination.readAsBytesSync(), equals([1, 2, 3]));
  });

  test('tracks a local override source as a hook dependency', () async {
    final source = File(p.join(tempRoot.path, 'bundles', 'native.zip'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    final dependencies = <Uri>[];

    final cached = await resolveLocalOverrideToCache(
      overridePath: p.join('bundles', 'native.zip'),
      configBaseDir: tempRoot.path,
      cacheDir: Directory(p.join(tempRoot.path, 'cache')),
      addDependency: dependencies.add,
    );

    expect(cached.readAsBytesSync(), equals([1, 2, 3]));
    expect(dependencies, contains(source.uri));
  });

  test('accepts only HTTP and HTTPS remote overrides', () {
    expect(
      parseRemoteOverride('http://example.test/bundle.zip')!.scheme,
      'http',
    );
    expect(
      parseRemoteOverride('https://example.test/bundle.zip')!.scheme,
      'https',
    );
    expect(parseRemoteOverride(r'C:\bundles\bundle.zip'), isNull);
    expect(parseRemoteOverride(r'\\wsl.localhost\Ubuntu\bundle.zip'), isNull);
    expect(
      () => parseRemoteOverride('ftp://example.test/bundle.zip'),
      throwsA(
        predicate<Exception>(
          (error) => error.toString().contains('only http:// and https://'),
        ),
      ),
    );
    expect(
      () => parseRemoteOverride('s3://example.test/bundle.zip'),
      throwsA(isA<Exception>()),
    );
  });

  test('uses the full URL for remote cache identity', () {
    final cacheDir = Directory(p.join(tempRoot.path, 'cache'));
    final first = Uri.parse('https://one.example/bundle.zip');
    final second = Uri.parse('https://two.example/bundle.zip');

    expect(
      remoteCacheFileFor(first, cacheDir).path,
      isNot(equals(remoteCacheFileFor(second, cacheDir).path)),
    );
    expect(
      p.basename(remoteCacheFileFor(first, cacheDir).path),
      endsWith('-bundle.zip'),
    );
  });

  test('uses the same source identity contract for native and Web caches', () {
    final uri = Uri.parse('https://example.test/bundle.zip');
    final nativeCache = Directory(p.join(tempRoot.path, 'native'));
    final webCache = Directory(p.join(tempRoot.path, 'web'));

    expect(
      p.basename(remoteCacheFileFor(uri, nativeCache).path),
      equals(p.basename(remoteCacheFileFor(uri, webCache).path)),
    );
    expect(
      p.basename(remoteCacheFileFor(uri, nativeCache).path),
      isNot(equals('bundle.zip')),
    );
  });

  test(
    'refreshes a remote override and invalidates changed extraction',
    () async {
      final cacheDir = Directory(p.join(tempRoot.path, 'cache'));
      final uri = Uri.parse('https://example.test/bundle-official-looking.zip');
      final dependencies = <Uri>[];
      var bytes = <int>[1, 2, 3];
      Future<bool> download(Uri requestedUri, File target) async {
        expect(requestedUri, uri);
        target.parent.createSync(recursive: true);
        target.writeAsBytesSync(bytes);
        return true;
      }

      final cacheFile = await resolveRemoteOverrideToCache(
        overrideUrl: uri.toString(),
        cacheDir: cacheDir,
        addDependency: dependencies.add,
        download: download,
      );
      final extractRoot = extractRootFor(cacheFile, cacheDir);
      File(p.join(extractRoot.path, 'payload')).createSync(recursive: true);
      extractCompletionMarkerFor(extractRoot).createSync();

      final reusedCacheFile = await resolveRemoteOverrideToCache(
        overrideUrl: uri.toString(),
        cacheDir: cacheDir,
        addDependency: dependencies.add,
        download: download,
      );
      expect(reusedCacheFile.path, equals(cacheFile.path));
      expect(extractRoot.existsSync(), isTrue);

      bytes = <int>[4, 5, 6];
      final changed = await syncRemoteOverrideToCache(
        uri: uri,
        cacheFile: cacheFile,
        cacheDir: cacheDir,
        download: download,
      );

      expect(changed, isTrue);
      expect(cacheFile.readAsBytesSync(), equals(<int>[4, 5, 6]));
      expect(extractRoot.existsSync(), isFalse);
      expect(dependencies, contains(uri));
    },
  );

  test('rejects unsupported remotes before invoking the downloader', () async {
    var invoked = false;
    expect(
      () => resolveRemoteOverrideToCache(
        overrideUrl: 'ftp://example.test/bundle.zip',
        cacheDir: Directory(p.join(tempRoot.path, 'cache')),
        addDependency: (_) {},
        download: (_, _) async {
          invoked = true;
          return true;
        },
      ),
      throwsA(isA<Exception>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(invoked, isFalse);
  });
}
