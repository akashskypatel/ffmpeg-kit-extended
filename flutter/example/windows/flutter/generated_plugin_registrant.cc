//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter_plugin.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FfmpegKitExtendedFlutterPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FfmpegKitExtendedFlutterPlugin"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
}
