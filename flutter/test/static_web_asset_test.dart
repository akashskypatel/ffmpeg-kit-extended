import 'dart:io';

import 'package:test/test.dart';

void main() {
  const runtimeFiles = <String>[
    'ffmpegkit.mjs',
    'ffmpegkit.wasm',
    'ffmpegkit_bridge.mjs',
    'ffmpegkit_callback_runtime.mjs',
    'ffmpegkit_loader.mjs',
  ];

  test('packages the pinned default Web runtime and support modules', () {
    final assetRoot = Directory('assets/wasm');
    expect(assetRoot.existsSync(), isTrue);

    for (final name in runtimeFiles) {
      expect(File('${assetRoot.path}/$name').existsSync(), isTrue);
      expect(File('${assetRoot.path}/$name').lengthSync(), greaterThan(0));
    }

    final wasmHeader = File('${assetRoot.path}/ffmpegkit.wasm')
        .readAsBytesSync()
        .take(4);
    expect(wasmHeader, orderedEquals([0, 97, 115, 109]));
    expect(
      File('${assetRoot.path}/ffmpegkit.mjs').readAsStringSync(),
      contains('export default'),
    );
  });

  test('keeps packaged support modules synchronized with hook sources', () {
    for (final name in [
      'ffmpegkit_bridge.mjs',
      'ffmpegkit_callback_runtime.mjs',
      'ffmpegkit_loader.mjs',
    ]) {
      expect(
        File('assets/wasm/$name').readAsBytesSync(),
        orderedEquals(File('web/$name').readAsBytesSync()),
      );
    }
  });
}
