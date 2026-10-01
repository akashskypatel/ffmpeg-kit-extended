// FFmpegKit Flutter Extended Plugin - Linux (Thread-Safe & Deadlock-Free)
// Copyright (C) 2026 Akash Patel
// Licensed under LGPL-2.1
#include "include/ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter_plugin.h"
#include "../native/frame_notification_coalescer.h"
#include "../native/ffplay_owner_coordinator.h"
#include "../native/pixel_buffer_frame_store.h"
#include "../native/texture_registration_transaction.h"
#include "../native/packed_rgba_frame.h"
#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <dlfcn.h>
#include <mutex>
#include <string>
#include <vector>
#include <cstring>
#include <algorithm>
#include <thread>
#include <iomanip>
#include <ctime>
#include <flutter_linux/fl_texture_registrar.h>
#include <sys/time.h>

std::string GetCurrentDateTime() {
  time_t now = time(0);
  struct tm *timeinfo = localtime(&now);
  char buffer[80];
  strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", timeinfo);
  struct timeval tv;
  gettimeofday(&tv, NULL);
  char milliseconds[4];
  snprintf(milliseconds, sizeof(milliseconds), "%03d", (int)(tv.tv_usec / 1000));
  return std::string(buffer) + "." + std::string(milliseconds);
}

#define FFKIT_LOG_T(fmt, ...) \
  g_printerr("[%s] [FFKit] [%p] " fmt "\n", GetCurrentDateTime().c_str(), (void*)pthread_self(), ##__VA_ARGS__)

// --- FFmpegKit ABI (runtime-resolved) ----------------------------------------
typedef void (*FFplayKitFrameCallback)(void* userdata, const uint8_t* pixels,
                                       int width, int height, int linesize,
                                       const char* format);
typedef void (*RegisterFrameCallbackFn)(FFplayKitFrameCallback, void*);
typedef void (*UnregisterFrameCallbackFn)();

static RegisterFrameCallbackFn g_register_fn = nullptr;
static UnregisterFrameCallbackFn g_unregister_fn = nullptr;
static std::mutex g_resolve_mutex;

static bool ResolveFFplayProcs() {
  std::lock_guard<std::mutex> lock(g_resolve_mutex);
  if (g_register_fn && g_unregister_fn) return true;
  FFKIT_LOG_T("Resolving FFmpegKit symbols...");
  RegisterFrameCallbackFn resolved_register = reinterpret_cast<RegisterFrameCallbackFn>(
      dlsym(RTLD_DEFAULT, "ffplay_kit_register_frame_callback"));
  UnregisterFrameCallbackFn resolved_unregister = reinterpret_cast<UnregisterFrameCallbackFn>(
      dlsym(RTLD_DEFAULT, "ffplay_kit_unregister_frame_callback"));
  
  if (!resolved_register || !resolved_unregister) {
    const char* libs[] = { "libffmpegkit.so", "libffmpegkit.so.0", "libffmpegkit.so.1", nullptr};
    for (int i = 0; libs[i]; ++i) {
      void* h = dlopen(libs[i], RTLD_LAZY | RTLD_NOLOAD);
      if (!h) continue;
      if (!resolved_register) resolved_register = reinterpret_cast<RegisterFrameCallbackFn>(dlsym(h, "ffplay_kit_register_frame_callback"));
      if (!resolved_unregister) resolved_unregister = reinterpret_cast<UnregisterFrameCallbackFn>(dlsym(h, "ffplay_kit_unregister_frame_callback"));
      if (resolved_register && resolved_unregister) break;
    }
  }

  if (!resolved_register || !resolved_unregister) {
    g_register_fn = nullptr;
    g_unregister_fn = nullptr;
    FFKIT_LOG_T("FFplay frame API remains unavailable; lookup will retry");
    return false;
  }
  g_register_fn = resolved_register;
  g_unregister_fn = resolved_unregister;
  FFKIT_LOG_T("Symbols resolved: reg=%p, unreg=%p", g_register_fn, g_unregister_fn);
  return true;
}

static bool ffplay_kit_register_frame_callback(FFplayKitFrameCallback cb, void* ud) {
  if (!ResolveFFplayProcs() || !g_register_fn) return false;
  g_register_fn(cb, ud);
  return true;
}

static bool ffplay_kit_unregister_frame_callback() {
  if (!ResolveFFplayProcs() || !g_unregister_fn) return false;
  g_unregister_fn();
  return true;
}

// --- TextureState (Double-Buffered & Thread-Safe) ----------------------------
struct TextureState {
  FlTextureRegistrar* registrar = nullptr;
  std::mutex mutex;

  bool destroyed = false;
  ffmpeg_kit_extended_flutter::FrameNotificationCoalescer frame_notification;
  ffmpeg_kit_extended_flutter::PixelBufferFrameStore frame_store;
  int64_t fl_texture_id = 0;
};

// --- FfkitPixelBufferTexture (FlPixelBufferTexture subtype) ------------------
typedef struct _FfkitPixelBufferTexture FfkitPixelBufferTexture;
typedef struct _FfkitPixelBufferTextureClass FfkitPixelBufferTextureClass;
struct _FfkitPixelBufferTexture {
  FlPixelBufferTexture parent_instance;
  TextureState* state = nullptr;
};
struct _FfkitPixelBufferTextureClass {
  FlPixelBufferTextureClass parent_class;
};

static ffmpeg_kit_extended_flutter::FfplayOwnerCoordinator<FfkitPixelBufferTexture>
    g_ffplay_owner;

#define FFKIT_PIXEL_BUFFER_TEXTURE(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), ffkit_pixel_buffer_texture_get_type(), \
                              FfkitPixelBufferTexture))

G_DEFINE_TYPE(FfkitPixelBufferTexture, ffkit_pixel_buffer_texture,
              fl_pixel_buffer_texture_get_type())

static gboolean ffkit_pixel_buffer_texture_copy_pixels(
    FlPixelBufferTexture* texture, const uint8_t** buffer, uint32_t* width,
    uint32_t* height, GError** error) {
  if (error && *error) return FALSE;

  FfkitPixelBufferTexture* self = FFKIT_PIXEL_BUFFER_TEXTURE(texture);
  if (!self || !self->state) return FALSE;

  std::lock_guard<std::mutex> lock(self->state->mutex);
  return self->state->frame_store.copyForRender(buffer, width, height) ? TRUE
                                                                        : FALSE;
}

static void ffkit_pixel_buffer_texture_finalize(GObject* object) {
  FfkitPixelBufferTexture* self = FFKIT_PIXEL_BUFFER_TEXTURE(object);
  if (self->state) {
    // FlPixelBufferTexture owns the engine-side GL texture and retires it in
    // Flutter's supported texture lifecycle. The plugin only owns CPU bytes.
    delete self->state;
    self->state = nullptr;
  }
  G_OBJECT_CLASS(ffkit_pixel_buffer_texture_parent_class)->finalize(object);
}

static void ffkit_pixel_buffer_texture_class_init(
    FfkitPixelBufferTextureClass* klass) {
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels =
      ffkit_pixel_buffer_texture_copy_pixels;
  G_OBJECT_CLASS(klass)->finalize = ffkit_pixel_buffer_texture_finalize;
}

static void ffkit_pixel_buffer_texture_init(FfkitPixelBufferTexture* self) {
  self->state = new TextureState();
}

static FfkitPixelBufferTexture* ffkit_pixel_buffer_texture_new(
    FlTextureRegistrar* registrar) {
  auto tex = FFKIT_PIXEL_BUFFER_TEXTURE(
      g_object_new(ffkit_pixel_buffer_texture_get_type(), nullptr));
  tex->state->registrar = registrar;
  return tex;
}

// --- Main Thread Callbacks ---------------------------------------------------
static gboolean mark_frame_idle_cb(gpointer user_data) {
  FfkitPixelBufferTexture* tex = FFKIT_PIXEL_BUFFER_TEXTURE(user_data);
  if (!tex || !tex->state) {
    g_object_unref(tex);
    return G_SOURCE_REMOVE;
  }

  bool should_mark = false;
  FlTextureRegistrar* registrar = nullptr;

  {
    std::lock_guard<std::mutex> lock(tex->state->mutex);
    tex->state->frame_notification.consume();
    if (!tex->state->destroyed && tex->state->frame_store.hasPendingFrame()) {
      should_mark = true;
      registrar = tex->state->registrar;
    }
  }

  if (should_mark && registrar) {
    fl_texture_registrar_mark_texture_frame_available(registrar, FL_TEXTURE(tex));
  }

  g_object_unref(tex);
  return G_SOURCE_REMOVE;
}

// --- Frame callback (FFmpeg thread) ------------------------------------------
static void on_frame_callback(void* userdata, const uint8_t* pixels, int width,
                              int height, int linesize, const char* pixel_format) {
  if (!userdata || !pixels || width <= 0 || height <= 0) return;
  
  FfkitPixelBufferTexture* tex = FFKIT_PIXEL_BUFFER_TEXTURE(userdata);
  if (!tex || !tex->state) return;
  TextureState* state = tex->state;

  ffmpeg_kit_extended_flutter::PackedRgbaFrame frame;
  if (!ffmpeg_kit_extended_flutter::NormalizePackedRgbaFrame(
          pixels, width, height, linesize, pixel_format, &frame)) {
    return;
  }

  bool schedule_mark = false;

  {
    std::lock_guard<std::mutex> lock(state->mutex);
    if (state->destroyed) return;

    state->frame_store.publish(frame.bytes.data(), frame.bytes.size(),
                                frame.width, frame.height);
    schedule_mark = state->frame_notification.request();
  }

  if (schedule_mark) {
    g_object_ref(tex);
    g_idle_add(mark_frame_idle_cb, tex);
  }
}

// --- Plugin Method Handlers --------------------------------------------------
struct _FfmpegKitExtendedFlutterPlugin {
  GObject parent_instance;
  FlTextureRegistrar* texture_registrar;
  FlMethodChannel* channel;
  FfkitPixelBufferTexture* texture;
};

G_DEFINE_TYPE(FfmpegKitExtendedFlutterPlugin, ffmpeg_kit_extended_flutter_plugin, g_object_get_type())

static void release_texture(FfmpegKitExtendedFlutterPlugin *self, int64_t texture_id) {
  if (!self->texture || self->texture->state->fl_texture_id != texture_id) return;
  
  g_ffplay_owner.uninstallIfOwned(
      self->texture, [] { ffplay_kit_unregister_frame_callback(); });

  {
    std::lock_guard<std::mutex> lock(self->texture->state->mutex);
    self->texture->state->destroyed = true;
    self->texture->state->frame_store.markDestroyed();
  }
  // Keep the registration and render bytes for reuse. FlPixelBufferTexture
  // owns the engine-side GL name and handles its context-safe retirement.
}

static void handle_create_texture(FfmpegKitExtendedFlutterPlugin* self, FlMethodCall* method_call) {
  if (!ResolveFFplayProcs()) {
    fl_method_call_respond_error(
        method_call, "FFPLAY_UNAVAILABLE",
        "FFplay frame callback API is not available yet", nullptr, nullptr);
    return;
  }

  // Reuse existing texture if available
  if (self->texture) {
    g_ffplay_owner.uninstallIfOwned(
        self->texture, [] { ffplay_kit_unregister_frame_callback(); });
    
    {
      std::lock_guard<std::mutex> lock(self->texture->state->mutex);
      self->texture->state->destroyed = false;
      self->texture->state->frame_store.resetForReuse();
    }

    if (!g_ffplay_owner.install(self->texture, [self] {
      return ffplay_kit_register_frame_callback(on_frame_callback, self->texture);
    })) {
      std::lock_guard<std::mutex> lock(self->texture->state->mutex);
      self->texture->state->destroyed = true;
      self->texture->state->frame_store.markDestroyed();
      fl_method_call_respond_error(
          method_call, "FFPLAY_UNAVAILABLE",
          "FFplay frame callback API could not be registered", nullptr, nullptr);
      return;
    }
    
    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "textureId", fl_value_new_int(self->texture->state->fl_texture_id));
    fl_method_call_respond_success(method_call, result, nullptr);
    return;
  }

  // First time: Create & Register
  FfkitPixelBufferTexture* tex =
      ffkit_pixel_buffer_texture_new(self->texture_registrar);
  if (!fl_texture_registrar_register_texture(self->texture_registrar,
                                             FL_TEXTURE(tex))) {
    g_object_unref(tex);
    fl_method_call_respond_error(
        method_call, "TEXTURE_REGISTRATION_FAILED",
        "Flutter could not register the FFplay texture", nullptr, nullptr);
    return;
  }

  self->texture = tex;
  self->texture->state->fl_texture_id = fl_texture_get_id(FL_TEXTURE(tex));
  
  if (!ffmpeg_kit_extended_flutter::InstallOwnerAfterTextureRegistration(
          self->texture->state->fl_texture_id,
          [tex] {
            return g_ffplay_owner.install(
                tex, [tex] {
                  return ffplay_kit_register_frame_callback(on_frame_callback,
                                                            tex);
                });
          },
          [self, tex](int64_t) {
            fl_texture_registrar_unregister_texture(self->texture_registrar,
                                                    FL_TEXTURE(tex));
            self->texture = nullptr;
            g_object_unref(tex);
          })) {
    fl_method_call_respond_error(
        method_call, "FFPLAY_UNAVAILABLE",
        "FFplay frame callback could not be registered", nullptr, nullptr);
    return;
  }
  
  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "textureId", fl_value_new_int(self->texture->state->fl_texture_id));
  fl_method_call_respond_success(method_call, result, nullptr);
}

static void handle_release_texture(FfmpegKitExtendedFlutterPlugin* self, FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  if (!args || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    fl_method_call_respond_error(method_call, "INVALID_ARGUMENT", "Expected map", nullptr, nullptr);
    return;
  }
  FlValue* val = fl_value_lookup_string(args, "textureId");
  if (!val || fl_value_get_type(val) != FL_VALUE_TYPE_INT) {
    fl_method_call_respond_error(method_call, "INVALID_ARGUMENT", "Expected textureId int", nullptr, nullptr);
    return;
  }
  release_texture(self, fl_value_get_int(val));
  fl_method_call_respond_success(method_call, nullptr, nullptr);
}

static void ffmpeg_kit_extended_flutter_plugin_handle_method_call(
    FfmpegKitExtendedFlutterPlugin* self, FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
  if (strcmp(method, "createTexture") == 0) {
    handle_create_texture(self, method_call);
  } else if (strcmp(method, "releaseTexture") == 0) {
    handle_release_texture(self, method_call);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
  ffmpeg_kit_extended_flutter_plugin_handle_method_call(FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN(user_data), method_call);
}

static void ffmpeg_kit_extended_flutter_plugin_dispose(GObject* object) {
  auto* self = FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN(object);
  if (self->texture) {
    FfkitPixelBufferTexture* texture = self->texture;
    self->texture = nullptr;

    // Only the current process-global owner may unregister the callback.
    g_ffplay_owner.uninstallIfOwned(
        texture, [] { ffplay_kit_unregister_frame_callback(); });

    // The plugin owns the reference returned by g_object_new. Mark the state
    // destroyed before releasing it so queued idle callbacks can finish
    // safely using their own temporary GObject references.
    ffmpeg_kit_extended_flutter::ReleaseRegisteredTexture(
        [texture] {
          g_ffplay_owner.uninstallIfOwned(
              texture, [] { ffplay_kit_unregister_frame_callback(); });
        },
        [texture] {
          std::lock_guard<std::mutex> lock(texture->state->mutex);
          texture->state->destroyed = true;
          texture->state->frame_store.markDestroyed();
        },
        [self, texture] {
          fl_texture_registrar_unregister_texture(self->texture_registrar,
                                                  FL_TEXTURE(texture));
        },
        [texture] {
          std::lock_guard<std::mutex> lock(texture->state->mutex);
          texture->state->frame_store.clearAfterUnregister();
          g_object_unref(texture);
        });
  }
  self->texture_registrar = nullptr;
  g_clear_object(&self->channel);
  G_OBJECT_CLASS(ffmpeg_kit_extended_flutter_plugin_parent_class)->dispose(object);
}

static void ffmpeg_kit_extended_flutter_plugin_class_init(FfmpegKitExtendedFlutterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = ffmpeg_kit_extended_flutter_plugin_dispose;
}

static void ffmpeg_kit_extended_flutter_plugin_init(FfmpegKitExtendedFlutterPlugin* self) {
  self->texture = nullptr;
}

void ffmpeg_kit_extended_flutter_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  auto* plugin = FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN(
      g_object_new(ffmpeg_kit_extended_flutter_plugin_get_type(), nullptr));
  plugin->texture_registrar = FL_TEXTURE_REGISTRAR(fl_plugin_registrar_get_texture_registrar(registrar));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel = fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                                          "ffplay_kit_desktop", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(plugin->channel, method_call_cb, g_object_ref(plugin), g_object_unref);
  g_object_unref(plugin);
}
