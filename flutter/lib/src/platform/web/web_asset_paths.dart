/// Logical and browser URL roots for the Flutter Web runtime assets.
final class WebAssetPaths {
  WebAssetPaths._();

  /// The dependency-package asset key produced from `pubspec.yaml`'s
  /// `assets/wasm/` declaration.
  static const defaultAssetKeyRoot =
      'packages/ffmpeg_kit_extended_flutter/assets/wasm';

  /// The browser URL root for the packaged default runtime.
  static const defaultAssetRoot = 'assets/$defaultAssetKeyRoot';

  /// The logical DataAsset key root for an explicit custom runtime.
  static const overrideAssetKeyRoot =
      'packages/ffmpeg_kit_extended_flutter/wasm_override';

  /// The logical asset key that marks an explicit custom runtime.
  static const overrideManifestKey =
      '$overrideAssetKeyRoot/ffmpegkit_wasm_manifest.json';

  /// The browser URL root for an explicit custom runtime.
  static const overrideAssetRoot = 'assets/$overrideAssetKeyRoot';

  static const overrideManifest =
      '$overrideAssetRoot/ffmpegkit_wasm_manifest.json';
}
