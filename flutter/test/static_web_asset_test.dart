import 'dart:io';

import 'package:ffmpeg_kit_extended_flutter/src/platform/web/web_asset_paths.dart';
import 'package:test/test.dart';

void main() {
  test('uses the build-hook staged Web runtime URL root', () {
    expect(
      WebAssetPaths.defaultAssetKeyRoot,
      'packages/ffmpeg_kit_extended_flutter/wasm',
    );
    expect(
      WebAssetPaths.defaultAssetRoot,
      'assets/packages/ffmpeg_kit_extended_flutter/wasm',
    );
  });

  test('keeps current Web support modules as build-hook staging sources', () {
    for (final name in <String>[
      'ffmpegkit_bridge.mjs',
      'ffmpegkit_callback_runtime.mjs',
      'ffmpegkit_loader.mjs',
    ]) {
      final file = File('web/$name');
      expect(file.existsSync(), isTrue, reason: name);
      expect(file.lengthSync(), greaterThan(0), reason: name);
    }
  });

  test('does not declare DataAssets or pinned runtime Flutter assets', () {
    final source = File('pubspec.yaml').readAsStringSync();
    expect(source, isNot(contains('data_assets:')));
    expect(source, isNot(contains('- assets/wasm/')));
  });
}
