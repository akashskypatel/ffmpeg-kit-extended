/// Canonical browser URL for the runtime staged by the Flutter build hook.
final class WebAssetPaths {
  WebAssetPaths._();

  /// Logical package root used by build-hook staging.
  static const defaultAssetKeyRoot =
      'packages/ffmpeg_kit_extended_flutter/wasm';

  /// Browser URL root for the selected default or custom runtime.
  static const defaultAssetRoot = 'assets/$defaultAssetKeyRoot';
}
