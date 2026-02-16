#include "include/ffmpeg_kit_extended_flutter/ffmpeg_kit_flutter_plugin.h"

#include <flutter/plugin_registrar_windows.h>

namespace ffmpeg_kit_extended_flutter {

// static
void FfmpegKitFlutterPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<FfmpegKitFlutterPlugin>();
  registrar->AddPlugin(std::move(plugin));
}

FfmpegKitFlutterPlugin::FfmpegKitFlutterPlugin() {}

FfmpegKitFlutterPlugin::~FfmpegKitFlutterPlugin() {}

}  // namespace ffmpeg_kit_extended_flutter
