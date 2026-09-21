import 'dart:convert';

import 'web_asset_paths.dart';

enum WebRuntimeSelection { packagedDefault, customOverride }

WebRuntimeSelection selectWebRuntime(Iterable<String> assets) =>
    assets.contains(WebAssetPaths.overrideManifestKey)
        ? WebRuntimeSelection.customOverride
        : WebRuntimeSelection.packagedDefault;

void validateCustomWebRuntimeManifest(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic> ||
      decoded['schema'] != 1 ||
      decoded['root'] != 'wasm_override') {
    throw const FormatException(
      'The custom FFmpegKit Web runtime manifest is invalid.',
    );
  }
}
