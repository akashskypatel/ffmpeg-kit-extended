// FFmpegKit Flutter Extended Plugin - Linux (Thread-Safe & Deadlock-Free)
// Copyright (C) 2026 Akash Patel
// Licensed under LGPL-2.1
#include "include/ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter_plugin.h"
#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <GLES3/gl3.h>
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
#include <flutter_linux/fl_texture_gl.h>
#include <sys/time.h>

// GL error checking helper
#define GL_CHECK(msg) do { \
  GLenum err = glGetError(); \
  if (err != GL_NO_ERROR) { \
    FFKIT_LOG_T("GL ERROR in %s: 0x%x", msg, err); \
  } \
} while(0)

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

// ─── FFmpegKit ABI (runtime-resolved) ────────────────────────────────────────
typedef void (*FFplayKitFrameCallback)(void* userdata, const uint8_t* pixels,
                                       int width, int height, int linesize,
                                       const char* format);
typedef void (*RegisterFrameCallbackFn)(FFplayKitFrameCallback, void*);
typedef void (*UnregisterFrameCallbackFn)();

static RegisterFrameCallbackFn g_register_fn = nullptr;
static UnregisterFrameCallbackFn g_unregister_fn = nullptr;
static bool g_symbols_resolved = false;

static void ResolveFFplayProcs() {
  if (g_symbols_resolved) return;
  FFKIT_LOG_T("Resolving FFmpegKit symbols...");
  g_register_fn = reinterpret_cast<RegisterFrameCallbackFn>(
      dlsym(RTLD_DEFAULT, "ffplay_kit_register_frame_callback"));
  g_unregister_fn = reinterpret_cast<UnregisterFrameCallbackFn>(
      dlsym(RTLD_DEFAULT, "ffplay_kit_unregister_frame_callback"));
  
  if (!g_register_fn || !g_unregister_fn) {
    const char* libs[] = { "libffmpegkit.so", "libffmpegkit.so.0", "libffmpegkit.so.1", nullptr};
    for (int i = 0; libs[i]; ++i) {
      void* h = dlopen(libs[i], RTLD_LAZY | RTLD_NOLOAD);
      if (!h) continue;
      if (!g_register_fn) g_register_fn = reinterpret_cast<RegisterFrameCallbackFn>(dlsym(h, "ffplay_kit_register_frame_callback"));
      if (!g_unregister_fn) g_unregister_fn = reinterpret_cast<UnregisterFrameCallbackFn>(dlsym(h, "ffplay_kit_unregister_frame_callback"));
      if (g_register_fn && g_unregister_fn) break;
    }
  }
  g_symbols_resolved = true;
  FFKIT_LOG_T("Symbols resolved: reg=%p, unreg=%p", g_register_fn, g_unregister_fn);
}

static void ffplay_kit_register_frame_callback(FFplayKitFrameCallback cb, void* ud) {
  ResolveFFplayProcs();
  if (g_register_fn)
    g_register_fn(cb, ud); 
}

static void ffplay_kit_unregister_frame_callback() {
  ResolveFFplayProcs();
  if (g_unregister_fn)
    g_unregister_fn(); 
}

// ─── TextureState (Double-Buffered & Thread-Safe) ────────────────────────────
struct TextureState {
  FlTextureRegistrar* registrar = nullptr;
  std::mutex mutex;
  
  std::vector<uint8_t> write_buf;
  std::vector<uint8_t> read_buf;
  uint32_t width = 1;
  uint32_t height = 1;
  
  bool has_pending_frame = false;
  bool destroyed = false;
  bool needs_gl_reset = false; // Deferred to render thread
  
  GLuint gl_texture_id = 0;
  int64_t fl_texture_id = 0;
  bool gl_initialized = false;
};

// ─── FfkitGlTexture (FlTextureGL subtype) ────────────────────────────────────
typedef struct _FfkitGlTexture FfkitGlTexture;
typedef struct _FfkitGlTextureClass FfkitGlTextureClass;
struct _FfkitGlTexture {
  FlTextureGL parent_instance;
  TextureState* state = nullptr;
};
struct _FfkitGlTextureClass {
  FlTextureGLClass parent_class;
};

#define FFKIT_GL_TEXTURE(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), ffkit_gl_texture_get_type(), FfkitGlTexture))

G_DEFINE_TYPE(FfkitGlTexture, ffkit_gl_texture, fl_texture_gl_get_type())

static gboolean
ffkit_gl_texture_populate_gl_texture(FlTextureGL *texture, uint32_t *target,
                                     uint32_t *name, uint32_t *width,
                                     uint32_t *height, GError **error) {
  if (error && *error) return FALSE;
  
  FfkitGlTexture* self = FFKIT_GL_TEXTURE(texture);
  if (!self || !self->state) return FALSE;
  TextureState* state = self->state;

  // Local copies for GL operations (minimize lock duration)
  std::vector<uint8_t> upload_buf;
  uint32_t w = 1, h = 1;
  bool has_frame = false;
  bool needs_reset = false;
  bool init_gl = false;

  {
    std::lock_guard<std::mutex> lock(state->mutex);
    if (state->destroyed) return FALSE;

    // 1. Handle deferred GL reset (SAFE: runs on render thread)
    if (state->needs_gl_reset) {
      needs_reset = true;
      state->needs_gl_reset = false;
    }

    // 2. Initialize or recreate GL texture
    if (needs_reset || !state->gl_initialized) {
      if (state->gl_initialized && state->gl_texture_id) {
        glDeleteTextures(1, &state->gl_texture_id);
      }
      glGenTextures(1, &state->gl_texture_id);
      glBindTexture(GL_TEXTURE_2D, state->gl_texture_id);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
      glBindTexture(GL_TEXTURE_2D, 0);
      state->gl_initialized = true;
      init_gl = true;
    }

    *target = GL_TEXTURE_2D;
    *name = state->gl_texture_id;
    *width = state->width > 0 ? state->width : 1;
    *height = state->height > 0 ? state->height : 1;

    // 3. Grab frame data if available
    if (state->has_pending_frame) {
      upload_buf = state->read_buf; // Copy to local
      w = state->width;
      h = state->height;
      has_frame = true;
      state->has_pending_frame = false; // Mark consumed
    }
  } // Mutex released

  // 4. Upload texture (outside lock to prevent blocking FFmpeg thread)
  if (has_frame && !upload_buf.empty()) {
    glBindTexture(GL_TEXTURE_2D, state->gl_texture_id);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, upload_buf.data());
    glBindTexture(GL_TEXTURE_2D, 0);
  }

  return TRUE;
}

static void ffkit_gl_texture_finalize(GObject* object) {
  FfkitGlTexture* self = FFKIT_GL_TEXTURE(object);
  if (self->state) {
    // GL cleanup is handled by populate or engine. Safe to delete state.
    delete self->state;
  }
  G_OBJECT_CLASS(ffkit_gl_texture_parent_class)->finalize(object);
}

static void ffkit_gl_texture_class_init(FfkitGlTextureClass *klass) {
  FL_TEXTURE_GL_CLASS(klass)->populate = ffkit_gl_texture_populate_gl_texture;
  G_OBJECT_CLASS(klass)->finalize = ffkit_gl_texture_finalize;
}

static void ffkit_gl_texture_init(FfkitGlTexture *self) {
  self->state = new TextureState();
}

static FfkitGlTexture *ffkit_gl_texture_new(FlTextureRegistrar* registrar) {
  auto tex = FFKIT_GL_TEXTURE(g_object_new(ffkit_gl_texture_get_type(), nullptr));
  tex->state->registrar = registrar;
  return tex;
}

// ─── Main Thread Callbacks ───────────────────────────────────────────────────
static gboolean mark_frame_idle_cb(gpointer user_data) {
  FfkitGlTexture* tex = FFKIT_GL_TEXTURE(user_data);
  if (!tex || !tex->state) {
    g_object_unref(tex);
    return G_SOURCE_REMOVE;
  }

  bool should_mark = false;
  FlTextureRegistrar* registrar = nullptr;

  {
    std::lock_guard<std::mutex> lock(tex->state->mutex);
    if (!tex->state->destroyed && tex->state->has_pending_frame) {
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

// ─── Frame callback (FFmpeg thread) ──────────────────────────────────────────
static void on_frame_callback(void* userdata, const uint8_t* pixels, int width,
                              int height, int linesize, const char* pixel_format) {
  if (!userdata || !pixels || width <= 0 || height <= 0) return;
  
  FfkitGlTexture* tex = FFKIT_GL_TEXTURE(userdata);
  if (!tex || !tex->state) return;
  TextureState* state = tex->state;

  bool schedule_mark = false;

  {
    std::lock_guard<std::mutex> lock(state->mutex);
    if (state->destroyed) return;

    size_t expected_size = static_cast<size_t>(linesize) * static_cast<size_t>(height);
    state->write_buf.assign(pixels, pixels + expected_size);
    state->width = width;
    state->height = height;

    // Fix alpha channel for rgb0
    bool is_rgb0 = pixel_format && (strcmp(pixel_format, "rgb0") == 0);
    if (is_rgb0) {
      uint8_t* buf = state->write_buf.data();
      size_t pixel_count = static_cast<size_t>(linesize / 4) * static_cast<size_t>(height);
      for (size_t i = 0; i < pixel_count; ++i) {
        if (buf[i * 4 + 3] == 0) buf[i * 4 + 3] = 0xFF;
      }
    }

    std::swap(state->write_buf, state->read_buf);
    state->has_pending_frame = true;
    schedule_mark = true;
  }

  if (schedule_mark) {
    g_object_ref(tex);
    g_idle_add(mark_frame_idle_cb, tex);
  }
}

// ─── Plugin Method Handlers ──────────────────────────────────────────────────
struct _FfmpegKitExtendedFlutterPlugin {
  GObject parent_instance;
  FlTextureRegistrar* texture_registrar;
  FlMethodChannel* channel;
  FfkitGlTexture* texture;
};

G_DEFINE_TYPE(FfmpegKitExtendedFlutterPlugin, ffmpeg_kit_extended_flutter_plugin, g_object_get_type())

static void release_texture(FfmpegKitExtendedFlutterPlugin *self, int64_t texture_id) {
  if (!self->texture || self->texture->state->fl_texture_id != texture_id) return;
  
  ffplay_kit_unregister_frame_callback();

  {
    std::lock_guard<std::mutex> lock(self->texture->state->mutex);
    self->texture->state->destroyed = true;
    self->texture->state->has_pending_frame = false;
    self->texture->state->read_buf.clear();
    self->texture->state->write_buf.clear();
    self->texture->state->needs_gl_reset = true; // Defer GL cleanup to render thread
  }
  // NOTE: Intentionally NOT unregistering from Flutter. Reuse same registration.
}

static void handle_create_texture(FfmpegKitExtendedFlutterPlugin* self, FlMethodCall* method_call) {
  // Reuse existing texture if available
  if (self->texture) {
    ffplay_kit_unregister_frame_callback();
    
    {
      std::lock_guard<std::mutex> lock(self->texture->state->mutex);
      self->texture->state->destroyed = false;
      self->texture->state->has_pending_frame = false;
      self->texture->state->read_buf.clear();
      self->texture->state->write_buf.clear();
      self->texture->state->needs_gl_reset = true; // Safe reset on next populate call
    }

    ffplay_kit_register_frame_callback(on_frame_callback, self->texture);
    
    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "textureId", fl_value_new_int(self->texture->state->fl_texture_id));
    fl_method_call_respond_success(method_call, result, nullptr);
    return;
  }

  // First time: Create & Register
  FfkitGlTexture* tex = ffkit_gl_texture_new(self->texture_registrar);
  fl_texture_registrar_register_texture(self->texture_registrar, FL_TEXTURE(tex));
  self->texture = tex;
  self->texture->state->fl_texture_id = fl_texture_get_id(FL_TEXTURE(tex));
  
  ffplay_kit_register_frame_callback(on_frame_callback, tex);
  
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
    // Only unregister when the plugin itself is destroyed
    ffplay_kit_unregister_frame_callback();
    fl_texture_registrar_unregister_texture(self->texture_registrar, FL_TEXTURE(self->texture));
    self->texture = nullptr;
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