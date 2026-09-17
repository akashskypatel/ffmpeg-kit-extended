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
}
