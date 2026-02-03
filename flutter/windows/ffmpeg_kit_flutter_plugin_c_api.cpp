#include "include/ffmpeg_kit_flutter/ffmpeg_kit_flutter_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "ffmpeg_kit_flutter_plugin.h"

void FfmpegKitFlutterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  ffmpeg_kit_flutter::FfmpegKitFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
