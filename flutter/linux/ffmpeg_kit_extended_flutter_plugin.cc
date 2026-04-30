// FFmpegKit Flutter Extended Plugin - Linux (Instrumented & Deadlock-Free)
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
  // with milliseconds
  time_t now = time(0);
  struct tm *timeinfo = localtime(&now);
  char buffer[80];
  strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", timeinfo);
  // add milliseconds
  struct timeval tv;
  gettimeofday(&tv, NULL);
  char milliseconds[4];
  snprintf(milliseconds, sizeof(milliseconds), "%03d", (int)(tv.tv_usec / 1000));
  std::string result = std::string(buffer) + "." + std::string(milliseconds);
  return result;
}

// ─── Debug Logging ───────────────────────────────────────────────────────────
// add date time to log
#define FFKIT_LOG_T(fmt, ...) \
  g_printerr("[%s] [FFKit] [%p] " fmt "\n", GetCurrentDateTime().c_str(), (void*)pthread_self(), ##__VA_ARGS__)

// ─── FFmpegKit ABI (runtime-resolved) ────────────────────────────────────────
typedef void (FFplayKitFrameCallback)(void* userdata, const uint8_t* pixels,
                                      int width, int height, int linesize,
                                      const char* format);
typedef void (RegisterFrameCallbackFn)(FFplayKitFrameCallback, void*);
typedef void (*UnregisterFrameCallbackFn)();

static RegisterFrameCallbackFn* g_register_fn = nullptr;
static UnregisterFrameCallbackFn g_unregister_fn = nullptr;
static bool g_symbols_resolved = false;

static void ResolveFFplayProcs() {
  if (g_symbols_resolved)
    return;
  //current date and time
  FFKIT_LOG_T("Resolving FFmpegKit symbols...");
  
  g_register_fn = reinterpret_cast<RegisterFrameCallbackFn*>(
      dlsym(RTLD_DEFAULT, "ffplay_kit_register_frame_callback"));
  g_unregister_fn = reinterpret_cast<UnregisterFrameCallbackFn>(
      dlsym(RTLD_DEFAULT, "ffplay_kit_unregister_frame_callback"));

  if (!g_register_fn || !g_unregister_fn) {
    const char* libs[] = {"libffmpegkit.so", "libffmpegkit.so.0", "libffmpegkit.so.1", nullptr};
    for (int i = 0; libs[i]; ++i) {
      void* h = dlopen(libs[i], RTLD_LAZY | RTLD_NOLOAD);
      if (!h) continue;
      if (!g_register_fn) g_register_fn = reinterpret_cast<RegisterFrameCallbackFn*>(dlsym(h, "ffplay_kit_register_frame_callback"));
      if (!g_unregister_fn) g_unregister_fn = reinterpret_cast<UnregisterFrameCallbackFn>(dlsym(h, "ffplay_kit_unregister_frame_callback"));
      if (g_register_fn && g_unregister_fn) break;
    }
  }
  g_symbols_resolved = true;
  FFKIT_LOG_T("Symbols resolved: reg=%p, unreg=%p", g_register_fn, g_unregister_fn);
}

static void ffplay_kit_register_frame_callback(FFplayKitFrameCallback cb, void* ud) {
  ResolveFFplayProcs();
  if (g_register_fn) { g_register_fn(cb, ud); FFKIT_LOG_T("Registered frame callback"); }
  else FFKIT_LOG_T("ERROR: register_fn is NULL");
}

static void ffplay_kit_unregister_frame_callback() {
  ResolveFFplayProcs();
  if (g_unregister_fn) { g_unregister_fn(); FFKIT_LOG_T("Unregistered frame callback"); }
}

// ─── TextureState (Double-Buffered) ──────────────────────────────────────────
struct TextureState {
  FlTextureRegistrar* registrar = nullptr;
  std::mutex mutex;
  
  // Double buffers
  std::vector<uint8_t> write_buf; // FFmpeg thread writes here
  std::vector<uint8_t> read_buf;  // Raster thread reads from here
  
  uint32_t width = 1;
  uint32_t height = 1;
  bool has_pending_frame = false;

  GLuint gl_texture_id = 0;
  int64_t fl_texture_id = 0;
  bool gl_initialized = false;
  bool destroyed = false;
  bool needs_gl_reset = false;
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

static void ffkit_gl_texture_class_init(FfkitGlTextureClass* klass);
static void ffkit_gl_texture_init(FfkitGlTexture* self);
G_DEFINE_TYPE(FfkitGlTexture, ffkit_gl_texture, fl_texture_gl_get_type())

static gboolean
ffkit_gl_texture_populate_gl_texture(FlTextureGL *texture, uint32_t *target,
                                     uint32_t *name, uint32_t *width,
                                     uint32_t *height, GError **error) {
  if(error && *error) {
    FFKIT_LOG_T("Error already set: %s", (*error)->message);
    return FALSE;
  }
  FfkitGlTexture* self = FFKIT_GL_TEXTURE(texture);
  if (!self || !self->state) {
    FFKIT_LOG_T("populate called with invalid texture/state");
    return FALSE;
  }
  TextureState *state = self->state;
  FFKIT_LOG_T("populate called (has_pending=%d, destroyed=%d, gl_init=%d, tex_id=%u, thread=%p)", 
              state->has_pending_frame, state->destroyed, state->gl_initialized, state->gl_texture_id, (void*)pthread_self());

  // Create GL texture if needed (first call or after reset)
  if (!state->gl_initialized) {
    glGenTextures(1, &state->gl_texture_id);
    GL_CHECK("glGenTextures");
    FFKIT_LOG_T("GL texture generated: %u", state->gl_texture_id);
    glBindTexture(GL_TEXTURE_2D, state->gl_texture_id);
    GL_CHECK("glBindTexture");
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    GL_CHECK("glTexParameteri MIN");
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    GL_CHECK("glTexParameteri MAG");
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    GL_CHECK("glTexParameteri WRAP_S");
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    GL_CHECK("glTexParameteri WRAP_T");
    glBindTexture(GL_TEXTURE_2D, 0);
    GL_CHECK("glBindTexture(0)");
    state->gl_initialized = true;
    FFKIT_LOG_T("GL texture initialized: %u", state->gl_texture_id);
  }

  *target = GL_TEXTURE_2D;
  *name = state->gl_texture_id;
  *width = state->width > 0 ? state->width : 1;
  *height = state->height > 0 ? state->height : 1;

  if (state->has_pending_frame && !state->destroyed) {
    // 1. Swap buffers
    std::vector<uint8_t> upload_buf;
    uint32_t w, h;
    {
      std::lock_guard<std::mutex> lock(state->mutex);
      upload_buf = std::move(state->read_buf);
      w = state->width;
      h = state->height;
      state->has_pending_frame = false;
    }

    // 2. IMPORTANT: Update the texture
    if (!upload_buf.empty()) {
      glBindTexture(GL_TEXTURE_2D, state->gl_texture_id);
      GL_CHECK("glBindTexture for update");
      // Use GL_RGBA/GL_UNSIGNED_BYTE as standard
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, upload_buf.data());
      GL_CHECK("glTexImage2D");
      glBindTexture(GL_TEXTURE_2D, 0);
      GL_CHECK("glBindTexture(0) after update");
      FFKIT_LOG_T("Texture updated successfully");
    }
  }
  return TRUE;
}

static void ffkit_gl_texture_finalize(GObject* object) {
  FFKIT_LOG_T("finalize called");
  FfkitGlTexture* self = FFKIT_GL_TEXTURE(object);
  if (self->state) {
    if (self->state->gl_initialized && self->state->gl_texture_id) {
      FFKIT_LOG_T("Deleting GL texture %u", self->state->gl_texture_id);
      glDeleteTextures(1, &self->state->gl_texture_id);
      GL_CHECK("glDeleteTextures");
    }
    delete self->state;
  }
  G_OBJECT_CLASS(ffkit_gl_texture_parent_class)->finalize(object);
}

static void ffkit_gl_texture_class_init(FfkitGlTextureClass *klass) {
  FFKIT_LOG_T("FfkitGlTextureClass init called");
  FL_TEXTURE_GL_CLASS(klass)->populate = ffkit_gl_texture_populate_gl_texture;
  G_OBJECT_CLASS(klass)->finalize = ffkit_gl_texture_finalize;
}

static void ffkit_gl_texture_init(FfkitGlTexture *self) {
  FFKIT_LOG_T("FfkitGlTexture init called");
  self->state = new TextureState();
}

static FfkitGlTexture *ffkit_gl_texture_new(FlTextureRegistrar *registrar) {
  FFKIT_LOG_T("FlTextureRegistrar new called");
  auto* tex = FFKIT_GL_TEXTURE(g_object_new(ffkit_gl_texture_get_type(), nullptr));
  tex->state->registrar = registrar;
  return tex;
}

static gboolean mark_frame_idle_cb(gpointer user_data) {
  FfkitGlTexture* tex = FFKIT_GL_TEXTURE(user_data);
  FFKIT_LOG_T("mark_frame_idle_cb invoked tex=%p", tex);
  if (tex && tex->state) {
    bool destroyed = false;
    FlTextureRegistrar* registrar = nullptr;
    FFKIT_LOG_T("mark_frame_idle_cb acquiring mutex...");
    {
      std::lock_guard<std::mutex> lock(tex->state->mutex);
      FFKIT_LOG_T("mark_frame_idle_cb mutex acquired");
      destroyed = tex->state->destroyed;
      registrar = tex->state->registrar;
    }
    FFKIT_LOG_T("mark_frame_idle_cb mutex released, destroyed=%d, registrar=%p", destroyed, registrar);
    // Only invoke Flutter APIs from the main thread
    if (!destroyed && registrar) {
      auto populate =
          FL_TEXTURE_GL_CLASS(g_type_class_peek(ffkit_gl_texture_get_type()))
              ->populate;
      FFKIT_LOG_T("Marking texture frame available for registrar %p, texture %ld, populate %p", registrar, tex->state->fl_texture_id, populate);
      fl_texture_registrar_mark_texture_frame_available(registrar, FL_TEXTURE(tex));
    }
  }
  g_object_unref(tex);
  return G_SOURCE_REMOVE;
}

// ─── Frame callback (FFmpeg thread) ──────────────────────────────────────────
static void on_frame_callback(void* userdata, const uint8_t* pixels, int width,
                              int height, int linesize, const char* pixel_format) {
  if (!userdata) return;
  
  FfkitGlTexture* tex = FFKIT_GL_TEXTURE(userdata);
  if (!tex || !tex->state) return;
  
  TextureState* state = tex->state;
  if (!pixels || width <= 0 || height <= 0) return;

  bool should_mark = false;
  FlTextureRegistrar* registrar = nullptr;
  int64_t gl_texture_id = 0;
  int64_t texture_id = state->fl_texture_id;

  {
    std::lock_guard<std::mutex> lock(state->mutex);
    if (!state->destroyed) {
      size_t expected_size = static_cast<size_t>(linesize) * static_cast<size_t>(height);
      state->write_buf.assign(pixels, pixels + expected_size);
      state->width = width > 0 ? width : 1;
      state->height = height > 0 ? height : 1;

      // Fix alpha channel for rgb0/rgba
      bool is_rgb0 = pixel_format && (strcmp(pixel_format, "rgb0") == 0 || strcmp(pixel_format, "rgba") == 0);
      if (is_rgb0) {
        uint8_t* buf = state->write_buf.data();
        size_t pixel_count = static_cast<size_t>(linesize / 4) * static_cast<size_t>(height);
        for (size_t i = 0; i < pixel_count; ++i) {
          if (buf[i * 4 + 3] == 0) buf[i * 4 + 3] = 0xFF;
        }
      }

      // Double-buffer swap
      std::swap(state->write_buf, state->read_buf);
      state->has_pending_frame = true;
      registrar = state->registrar;
      should_mark = true;
      FFKIT_LOG_T("Frame queued for raster thread - registrar: %p, texture_id: %ld", registrar, texture_id);
    }
  } // Mutex released
  if (should_mark) {
    g_object_ref(tex);
    FFKIT_LOG_T("Scheduling mark_frame_idle_cb via g_idle_add");
    g_idle_add(mark_frame_idle_cb, tex);
  } else {
    FFKIT_LOG_T("Not scheduling mark_frame_idle_cb - should_mark=false or destroyed");
  }
}

// ─── Plugin ──────────────────────────────────────────────────────────────────
struct _FfmpegKitExtendedFlutterPlugin {
  GObject parent_instance;
  FlTextureRegistrar* texture_registrar;
  FlMethodChannel* channel;
  FfkitGlTexture* texture;
};

G_DEFINE_TYPE(FfmpegKitExtendedFlutterPlugin,
              ffmpeg_kit_extended_flutter_plugin, g_object_get_type())

static gboolean reset_texture(FfmpegKitExtendedFlutterPlugin* self, int64_t texture_id) {
  if (!self->texture) return FALSE;
  int64_t current_texture_id = self->texture->state->fl_texture_id;
  if(current_texture_id != texture_id) {
    FFKIT_LOG_T("Texture ID mismatch: expected %ld, got %ld", current_texture_id, texture_id);
    return FALSE;
  }
  // Stop any ongoing frame delivery
  ffplay_kit_unregister_frame_callback();

  {
    std::lock_guard<std::mutex> lock(self->texture->state->mutex);
    self->texture->state->destroyed = false;
    self->texture->state->has_pending_frame = false;
    self->texture->state->read_buf.clear();
    self->texture->state->write_buf.clear();
    // Reset GL state as well so populate will recreate the texture
    self->texture->state->gl_initialized = false;
    if (self->texture->state->gl_texture_id != 0) {
      glDeleteTextures(1, &self->texture->state->gl_texture_id);
      GL_CHECK("glDeleteTextures on reset");
      self->texture->state->gl_texture_id = 0;
    }
  }

  FFKIT_LOG_T("Texture state reset (same GObject: %p, same texture ID: %ld)", self->texture, texture_id);
  return TRUE;
}

static void handle_reset_texture(FfmpegKitExtendedFlutterPlugin* self, FlMethodCall* method_call) {
  FFKIT_LOG_T("handle_reset_texture called");
  FlValue* args = fl_method_call_get_args(method_call);
  if (!args || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    FFKIT_LOG_T("Invalid arguments: expected map");
    fl_method_call_respond_error(method_call, "INVALID_ARGUMENT", "Expected map", nullptr, nullptr);
    return;
  }

  FlValue* val = fl_value_lookup_string(args, "textureId");
  if (!val || fl_value_get_type(val) != FL_VALUE_TYPE_INT) {
    FFKIT_LOG_T("Invalid arguments: expected textureId int");
    fl_method_call_respond_error(method_call, "INVALID_ARGUMENT", "Expected textureId int", nullptr, nullptr);
    return;
  }

  int64_t req = fl_value_get_int(val);
  if (self->texture && self->texture->state->fl_texture_id == req) {
    FFKIT_LOG_T("Resetting texture with ID: %ld", req);
    if(!reset_texture(self, req)) {
      fl_method_call_respond_error(method_call, "INVALID_ARGUMENT", "Failed to reset texture", nullptr, nullptr);
      return;
    }
  }
  fl_method_call_respond_success(method_call, nullptr, nullptr);

}

static void release_texture(FfmpegKitExtendedFlutterPlugin *self, int64_t texture_id) {
  if (!self->texture)
    return;
  FFKIT_LOG_T("Releasing texture %p id %ld", self->texture, texture_id);

  // 1. Stop FFmpeg frame delivery
  ffplay_kit_unregister_frame_callback();

  // 2. Mark destroyed to prevent race conditions (but keep Flutter registration)
  {
    std::lock_guard<std::mutex> lock(self->texture->state->mutex);
    self->texture->state->destroyed = true;
  }
  
  // NOTE: We intentionally do NOT call fl_texture_registrar_unregister_texture
  // because unregistering a texture breaks Flutter's render thread's ability
  // to render any subsequent external textures. The texture will be reused
  // when createTexture is called again.

  FFKIT_LOG_T("Texture released (frame delivery stopped, Flutter registration kept)");
}

static void handle_create_texture(FfmpegKitExtendedFlutterPlugin* self, FlMethodCall* method_call) {
  // If we already have a texture, REUSE it (do not re-register)
  if (self->texture) {
    FFKIT_LOG_T("Reusing existing texture %p", self->texture);
    ffplay_kit_unregister_frame_callback();
    
    {
      std::lock_guard<std::mutex> lock(self->texture->state->mutex);
      self->texture->state->destroyed = false;
      self->texture->state->has_pending_frame = false;
      self->texture->state->read_buf.clear();
      self->texture->state->write_buf.clear();
      // DO NOT reset GL state, DO NOT delete textures. 
    }
    
    ffplay_kit_register_frame_callback(on_frame_callback, self->texture);
    
    int64_t texture_id = self->texture->state->fl_texture_id;
    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "textureId", fl_value_new_int(texture_id));
    fl_method_call_respond_success(method_call, result, nullptr);
    
    FFKIT_LOG_T("Reused texture with SAME ID: %ld", texture_id);
    return;
  }

  // First time: Create and Register
  FfkitGlTexture* tex = ffkit_gl_texture_new(self->texture_registrar);
  fl_texture_registrar_register_texture(self->texture_registrar, FL_TEXTURE(tex));
  self->texture = tex;

  int64_t texture_id = fl_texture_get_id(FL_TEXTURE(tex));
  self->texture->state->fl_texture_id = texture_id;
  ffplay_kit_register_frame_callback(on_frame_callback, tex);

  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "textureId", fl_value_new_int(texture_id));
  fl_method_call_respond_success(method_call, result, nullptr);
  FFKIT_LOG_T("New texture created with ID: %ld", texture_id);
}

static void handle_release_texture(FfmpegKitExtendedFlutterPlugin* self,
                                   FlMethodCall* method_call) {
  FFKIT_LOG_T("handle_release_texture called");
  FlValue* args = fl_method_call_get_args(method_call);
  if (!args || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    FFKIT_LOG_T("Invalid arguments: expected map");
    fl_method_call_respond_error(method_call, "INVALID_ARGUMENT", "Expected map", nullptr, nullptr);
    return;
  }

  FlValue* val = fl_value_lookup_string(args, "textureId");
  if (!val || fl_value_get_type(val) != FL_VALUE_TYPE_INT) {
    FFKIT_LOG_T("Invalid arguments: expected textureId int");
    fl_method_call_respond_error(method_call, "INVALID_ARGUMENT", "Expected textureId int", nullptr, nullptr);
    return;
  }

  int64_t req = fl_value_get_int(val);
  if (self->texture && self->texture->state->fl_texture_id == req) {
    FFKIT_LOG_T("Releasing texture with ID: %ld", req);
    release_texture(self, req);
  }
  fl_method_call_respond_success(method_call, nullptr, nullptr);
}

static void ffmpeg_kit_extended_flutter_plugin_handle_method_call(
    FfmpegKitExtendedFlutterPlugin* self, FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
  if (strcmp(method, "createTexture") == 0) {
    FFKIT_LOG_T("Method channel createTexture called");
    handle_create_texture(self, method_call);
  } else if (strcmp(method, "releaseTexture") == 0) {
    FFKIT_LOG_T("Method channel releaseTexture called");
    handle_release_texture(self, method_call);
    // reset instead of release to reuse
    //handle_reset_texture(self, method_call);
  } else if(strcmp(method, "resetTexture") == 0) {
    handle_reset_texture(self, method_call);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  auto* plugin = FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN(user_data);
  ffmpeg_kit_extended_flutter_plugin_handle_method_call(plugin, method_call);
}

static void ffmpeg_kit_extended_flutter_plugin_dispose(GObject* object) {
  FFKIT_LOG_T("Plugin dispose");
  auto* self = FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN(object);
  if (self->texture) {
    release_texture(self, self->texture->state->fl_texture_id);
  }
  self->texture_registrar = nullptr;
  g_clear_object(&self->channel);
  G_OBJECT_CLASS(ffmpeg_kit_extended_flutter_plugin_parent_class)->dispose(object);
}

static void ffmpeg_kit_extended_flutter_plugin_class_init(
    FfmpegKitExtendedFlutterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = ffmpeg_kit_extended_flutter_plugin_dispose;
}

static void ffmpeg_kit_extended_flutter_plugin_init(
    FfmpegKitExtendedFlutterPlugin* self) {
  self->texture = nullptr;
}

void ffmpeg_kit_extended_flutter_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  FFKIT_LOG_T("Plugin registered");
  auto* plugin = FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN(
      g_object_new(ffmpeg_kit_extended_flutter_plugin_get_type(), nullptr));
  plugin->texture_registrar = FL_TEXTURE_REGISTRAR(
      fl_plugin_registrar_get_texture_registrar(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "ffplay_kit_desktop", FL_METHOD_CODEC(codec));

  fl_method_channel_set_method_call_handler(
      plugin->channel, method_call_cb,
      g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
