#include "include/ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter_plugin.h"

#include <flutter/plugin_registrar_windows.h>

namespace ffmpeg_kit_extended_flutter {

// static
void FfmpegKitExtendedFlutterPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<FfmpegKitExtendedFlutterPlugin>();
  registrar->AddPlugin(std::move(plugin));
}

FfmpegKitExtendedFlutterPlugin::FfmpegKitExtendedFlutterPlugin() {}

FfmpegKitExtendedFlutterPlugin::~FfmpegKitExtendedFlutterPlugin() {}

}  // namespace ffmpeg_kit_extended_flutter
