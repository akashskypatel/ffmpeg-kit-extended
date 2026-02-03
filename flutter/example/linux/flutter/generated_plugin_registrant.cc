//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <ffmpeg_kit_flutter/f_fmpeg_kit_flutter_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) ffmpeg_kit_flutter_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FFmpegKitFlutterPlugin");
  f_fmpeg_kit_flutter_plugin_register_with_registrar(ffmpeg_kit_flutter_registrar);
}
