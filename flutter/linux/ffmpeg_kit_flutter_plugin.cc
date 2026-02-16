#include "include/ffmpeg_kit_extended_flutter/ffmpeg_kit_flutter_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>



#define FFMPEG_KIT_FLUTTER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), ffmpeg_kit_flutter_plugin_get_type(), \
                              FfmpegKitFlutterPlugin))

struct _FfmpegKitFlutterPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(FfmpegKitFlutterPlugin, ffmpeg_kit_flutter_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void ffmpeg_kit_flutter_plugin_handle_method_call(
    FfmpegKitFlutterPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    // Keep a simple platform version check if needed, or just return not implemented/null
    // since we are moving to FFI.
    // Ideally we remove method channel entirely.
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  // fl_method_call_respond(method_call, response, nullptr);
  // Actually, since we don't register the channel, this function is dead code.
  // I will just correct usage in case we need it, or I can remove the whole function if not used.
  // It IS used by method_call_cb, which is dead code (commented out registration).
  // So I can remove method_call_cb and this handler.
  fl_method_call_respond(method_call, response, nullptr);
}

static void ffmpeg_kit_flutter_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(ffmpeg_kit_flutter_plugin_parent_class)->dispose(object);
}

static void ffmpeg_kit_flutter_plugin_class_init(FfmpegKitFlutterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = ffmpeg_kit_flutter_plugin_dispose;
}

static void ffmpeg_kit_flutter_plugin_init(FfmpegKitFlutterPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  FfmpegKitFlutterPlugin* plugin = FFMPEG_KIT_FLUTTER_PLUGIN(user_data);
  ffmpeg_kit_flutter_plugin_handle_method_call(plugin, method_call);
}

void ffmpeg_kit_flutter_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FfmpegKitFlutterPlugin* plugin = FFMPEG_KIT_FLUTTER_PLUGIN(
      g_object_new(ffmpeg_kit_flutter_plugin_get_type(), nullptr));

  // MethodChannel registration code (commented out for FFI)

  g_object_unref(plugin);
}
