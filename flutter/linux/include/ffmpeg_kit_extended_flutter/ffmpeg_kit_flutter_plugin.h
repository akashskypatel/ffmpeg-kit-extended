#ifndef FLUTTER_PLUGIN_FFMPEG_KIT_FLUTTER_PLUGIN_H_
#define FLUTTER_PLUGIN_FFMPEG_KIT_FLUTTER_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

#define FFMPEG_KIT_TYPE_FLUTTER_PLUGIN (ffmpeg_kit_flutter_plugin_get_type())
G_DECLARE_FINAL_TYPE(FfmpegKitFlutterPlugin, ffmpeg_kit_flutter_plugin,
                     FFMPEG_KIT, FLUTTER_PLUGIN, GObject)

FLUTTER_PLUGIN_EXPORT GType ffmpeg_kit_flutter_plugin_get_type();

FLUTTER_PLUGIN_EXPORT void
ffmpeg_kit_flutter_plugin_register_with_registrar(FlPluginRegistrar *registrar);

G_END_DECLS

#endif // FLUTTER_PLUGIN_FFMPEG_KIT_FLUTTER_PLUGIN_H_
