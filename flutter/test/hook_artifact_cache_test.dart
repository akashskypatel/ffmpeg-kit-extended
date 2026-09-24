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

  test('reuses extraction only when the archive marker hash matches', () async {
    final archive = File(p.join(tempRoot.path, 'bundle.zip'))
      ..writeAsBytesSync([1, 2, 3]);
    final cacheDir = Directory(p.join(tempRoot.path, 'cache'));
    var extractionCount = 0;

    Future<bool> extract(File file, String destination) async {
      extractionCount++;
      File(p.join(destination, 'payload'))
        ..createSync(recursive: true)
        ..writeAsStringSync(file.readAsBytesSync().join(','));
      return true;
    }

    final first = await prepareExtractedArtifact(archive, cacheDir, extract);
    expect(extractionCount, 1);
    expect(extractCompletionMarkerFor(first).readAsStringSync(), isNotEmpty);

    await prepareExtractedArtifact(archive, cacheDir, extract);
    expect(extractionCount, 1);

    archive.writeAsBytesSync([4, 5, 6]);
    await prepareExtractedArtifact(archive, cacheDir, extract);
    expect(extractionCount, 2);
    expect(
      Directory(tempRoot.path)
          .listSync(recursive: true)
          .where(
            (entry) =>
                p.basename(entry.path).contains('.extracting.') ||
                p.basename(entry.path).endsWith('.lock'),
          ),
      isEmpty,
    );
  });

  test(
    'coordinates concurrent local override writers across processes',
    () async {
      final sourceA = File(p.join(tempRoot.path, 'source-a.zip'))
        ..writeAsBytesSync(List<int>.generate(8 * 1024 * 1024, (i) => i % 251));
      final sourceB = File(p.join(tempRoot.path, 'source-b.zip'))
        ..writeAsBytesSync(
          List<int>.generate(8 * 1024 * 1024, (i) => (i * 7) % 251),
        );
      final destination = File(p.join(tempRoot.path, 'cache', 'shared.zip'));
      final worker = p.join(
        Directory.current.path,
        'test',
        'hook_cache_worker.dart',
      );
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      expect(flutterRoot, isNotNull);
      final dartExecutable = p.join(
        flutterRoot!,
        'bin',
        'cache',
        'dart-sdk',
        'bin',
        Platform.isWindows ? 'dart.exe' : 'dart',
      );

      final processes = await Future.wait([
        Process.start(
          dartExecutable,
          ['run', worker, sourceA.path, destination.path],
          workingDirectory: Directory.current.path,
          environment: {
            ...Platform.environment,
            'REVIEW30_PROCESS': 'review30-g4-cache-worker-a',
          },
        ),
        Process.start(
          dartExecutable,
          ['run', worker, sourceB.path, destination.path],
          workingDirectory: Directory.current.path,
          environment: {
            ...Platform.environment,
            'REVIEW30_PROCESS': 'review30-g4-cache-worker-b',
          },
        ),
      ]);
      final results = await Future.wait(
        processes.map((process) async {
          final stdout = await process.stdout
              .transform(systemEncoding.decoder)
              .join();
          final stderr = await process.stderr
              .transform(systemEncoding.decoder)
              .join();
          return (
            exitCode: await process.exitCode,
            stdout: stdout,
            stderr: stderr,
          );
        }),
      );

      for (final result in results) {
        expect(
          result.exitCode,
          0,
          reason: 'worker stdout=${result.stdout} stderr=${result.stderr}',
        );
      }
      expect(
        destination.readAsBytesSync(),
        anyOf(
          equals(sourceA.readAsBytesSync()),
          equals(sourceB.readAsBytesSync()),
        ),
      );

      final cacheEntries = Directory(tempRoot.path)
          .listSync(recursive: true)
          .map((entry) => p.basename(entry.path))
          .toList();
      expect(
        cacheEntries.where(
          (name) =>
              name.contains('.copying.') ||
              name.contains('.refreshing.') ||
              name.contains('.downloading.') ||
              name.contains('.extracting.') ||
              name.endsWith('.lock'),
        ),
        isEmpty,
      );
    },
  );

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

  test('translates the local ManyLinux authority when the hook runs in WSL', () {
    expect(
      resolveLocalOverridePath(
        overridePath:
            r'\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders\prebuilt\linux-x86_64\releases\bundle.zip',
        configBaseDir: '/mnt/d/projects/ffmpeg_kit_extended/flutter/example',
        runningOnLinux: true,
      ),
      equals(
        '/home/vscode/ffmpeg-kit-builders/prebuilt/linux-x86_64/releases/bundle.zip',
      ),
    );
  });

  test('does not translate the ManyLinux authority on Windows', () {
    const overridePath =
        r'\\wsl.localhost\ManyLinux\home\vscode\bundle.zip';
    expect(
      resolveLocalOverridePath(
        overridePath: overridePath,
        configBaseDir: r'D:\Projects\ffmpeg_kit_extended\flutter\example',
        runningOnLinux: false,
      ),
      equals(overridePath),
    );
  });

  test('local-only validation rejects defaults and remote overrides', () {
    expect(
      () => validateLocalArtifactSelection(
        platformName: 'Web',
        overrideValue: null,
        localOnly: true,
      ),
      throwsA(
        predicate<Exception>(
          (error) => error.toString().contains(
            'requires an explicit local bundle override',
          ),
        ),
      ),
    );
    expect(
      () => validateLocalArtifactSelection(
        platformName: 'Web',
        overrideValue: 'https://example.test/runtime.zip',
        localOnly: true,
      ),
      throwsA(
        predicate<Exception>(
          (error) =>
              error.toString().contains('rejects remote bundle overrides'),
        ),
      ),
    );
  });

  test('local-only validation accepts a local filesystem override', () {
    expect(
      () => validateLocalArtifactSelection(
        platformName: 'Windows',
        overrideValue: r'\\wsl.localhost\ManyLinux\bundle.zip',
        localOnly: true,
      ),
      returnsNormally,
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
    'refreshes a remote override without a filesystem dependency callback',
    () async {
      final cacheDir = Directory(p.join(tempRoot.path, 'cache'));
      final uri = Uri.parse('https://example.test/bundle-official-looking.zip');
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
        download: download,
      );
      final extractRoot = extractRootFor(cacheFile, cacheDir);
      File(p.join(extractRoot.path, 'payload')).createSync(recursive: true);
      extractCompletionMarkerFor(extractRoot).createSync();

      final reusedCacheFile = await resolveRemoteOverrideToCache(
        overrideUrl: uri.toString(),
        cacheDir: cacheDir,
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
    },
  );

  test('rejects unsupported remotes before invoking the downloader', () async {
    var invoked = false;
    expect(
      () => resolveRemoteOverrideToCache(
        overrideUrl: 'ftp://example.test/bundle.zip',
        cacheDir: Directory(p.join(tempRoot.path, 'cache')),
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
