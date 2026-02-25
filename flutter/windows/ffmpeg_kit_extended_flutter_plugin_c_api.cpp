#include "include/ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter_plugin.h"

#include <flutter/plugin_registrar_windows.h>

void FfmpegKitExtendedFlutterPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  ffmpeg_kit_extended_flutter::FfmpegKitExtendedFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
