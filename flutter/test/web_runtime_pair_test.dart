import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../hook/build.dart';

void main() {
  late Directory tempRoot;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('ffmpeg_web_runtime_');
  });

  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  File writeRuntimeFile(String directory, String name) =>
      File(p.join(tempRoot.path, directory, name))
        ..createSync(recursive: true)
        ..writeAsStringSync(name);

  test('accepts a flat runtime pair', () {
    writeRuntimeFile('bundle', 'ffmpegkit.mjs');
    writeRuntimeFile('bundle', 'ffmpegkit.wasm');

    expect(
      selectWebRuntimeDirectory(
        Directory(p.join(tempRoot.path, 'bundle')),
      )?.path,
      equals(p.join(tempRoot.path, 'bundle')),
    );
  });

  test('accepts a nested coherent runtime pair', () {
    writeRuntimeFile('bundle/runtime', 'ffmpegkit.mjs');
    writeRuntimeFile('bundle/runtime', 'ffmpegkit.wasm');

    expect(
      selectWebRuntimeDirectory(
        Directory(p.join(tempRoot.path, 'bundle')),
      )?.path,
      equals(p.join(tempRoot.path, 'bundle', 'runtime')),
    );
  });

  test('rejects a split runtime pair', () {
    writeRuntimeFile('bundle/scripts', 'ffmpegkit.mjs');
    writeRuntimeFile('bundle/wasm', 'ffmpegkit.wasm');

    expect(
      selectWebRuntimeDirectory(Directory(p.join(tempRoot.path, 'bundle'))),
      isNull,
    );
  });

  test('rejects multiple complete runtime pairs', () {
    writeRuntimeFile('bundle/one', 'ffmpegkit.mjs');
    writeRuntimeFile('bundle/one', 'ffmpegkit.wasm');
    writeRuntimeFile('bundle/two', 'ffmpegkit.mjs');
    writeRuntimeFile('bundle/two', 'ffmpegkit.wasm');

    expect(
      selectWebRuntimeDirectory(Directory(p.join(tempRoot.path, 'bundle'))),
      isNull,
    );
  });

  test('allows unrelated files beside one complete runtime pair', () {
    writeRuntimeFile('bundle', 'ffmpegkit.mjs');
    writeRuntimeFile('bundle', 'ffmpegkit.wasm');
    writeRuntimeFile('bundle', 'README.txt');

    expect(
      selectWebRuntimeDirectory(Directory(p.join(tempRoot.path, 'bundle'))),
      isNotNull,
    );
  });

  test('rejects a missing runtime file', () {
    writeRuntimeFile('bundle', 'ffmpegkit.mjs');

    expect(
      selectWebRuntimeDirectory(Directory(p.join(tempRoot.path, 'bundle'))),
      isNull,
    );
  });
}
