#include "include/ffmpeg_kit_extended_flutter/ffmpeg_kit_flutter_plugin.h"

#include <flutter/plugin_registrar_windows.h>

void FfmpegKitFlutterPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  ffmpeg_kit_extended_flutter::FfmpegKitFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
