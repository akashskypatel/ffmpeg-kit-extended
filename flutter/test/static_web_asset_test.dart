import 'dart:io';

import 'package:ffmpeg_kit_extended_flutter/src/platform/web/web_asset_paths.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/web/web_runtime_selection.dart';
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

  test('matches Flutter dependency-asset URL roots', () {
    expect(
      WebAssetPaths.defaultAssetKeyRoot,
      'packages/ffmpeg_kit_extended_flutter/assets/wasm',
    );
    expect(
      WebAssetPaths.defaultAssetRoot,
      'assets/packages/ffmpeg_kit_extended_flutter/assets/wasm',
    );
    expect(
      WebAssetPaths.overrideAssetKeyRoot,
      'packages/ffmpeg_kit_extended_flutter/wasm_override',
    );
    expect(
      WebAssetPaths.overrideAssetRoot,
      'assets/packages/ffmpeg_kit_extended_flutter/wasm_override',
    );
    expect(
      WebAssetPaths.overrideManifestKey,
      'packages/ffmpeg_kit_extended_flutter/wasm_override/'
      'ffmpegkit_wasm_manifest.json',
    );
  });

  test('uses asset metadata as the authoritative Web runtime selector', () {
    expect(
      selectWebRuntime(const <String>[]),
      WebRuntimeSelection.packagedDefault,
    );
    expect(
      selectWebRuntime(const <String>[
        'packages/ffmpeg_kit_extended_flutter/wasm_override/ffmpegkit.mjs',
      ]),
      WebRuntimeSelection.packagedDefault,
    );
    expect(
      selectWebRuntime(const <String>[
        WebAssetPaths.overrideManifestKey,
      ]),
      WebRuntimeSelection.customOverride,
    );
  });

  test('requires the custom manifest to identify the override root', () {
    expect(
      () => validateCustomWebRuntimeManifest(
        '{"schema":1,"root":"wasm_override"}',
      ),
      returnsNormally,
    );
    expect(
      () => validateCustomWebRuntimeManifest('{"schema":1,"root":"wasm"}'),
      throwsFormatException,
    );
    expect(
      () => validateCustomWebRuntimeManifest('not-json'),
      throwsFormatException,
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
