// FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
// Copyright (C) 2026 Akash Patel
//
// This library is free software; you can redistribute it and/or modify it
// under the terms of the GNU Lesser General Public License as published by the
// Free Software Foundation; either version 2.1 of the License, or (at your
// option) any later version.

#include "include/ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>
#include <mutex>
#include <vector>

// ─── FFmpegKit ABI ────────────────────────────────────────────────────────────
// Declare only the frame-callback symbols needed from libffmpegkit.so.
//
// These symbols are declared weak so the plugin .so and the final executable
// can link without a build-time reference to libffmpegkit.so.  The dynamic
// linker resolves them at runtime from libffmpegkit.so (which is bundled next
// to the plugin .so and present in the process's RPATH).  This mirrors the
// Windows GetProcAddress approach used in the Windows plugin.
extern "C" {
typedef void (*FFplayKitFrameCallback)(void* userdata, const uint8_t* pixels,
                                       int width, int height, int linesize);
__attribute__((weak)) void ffplay_kit_register_frame_callback(
    FFplayKitFrameCallback callback, void* userdata);
__attribute__((weak)) void ffplay_kit_unregister_frame_callback(void);
}

// ─── GObject boilerplate ──────────────────────────────────────────────────────
#define FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN(obj)                          \
  (G_TYPE_CHECK_INSTANCE_CAST(                                           \
      (obj), ffmpeg_kit_extended_flutter_plugin_get_type(),              \
      FfmpegKitExtendedFlutterPlugin))

// ─── Pixel-buffer state ───────────────────────────────────────────────────────
//
// Threading model
// ───────────────
// • on_frame_callback fires from the FFplay executor thread.
//   It copies decoded RGBA pixels into frame_buf under mutex and then signals
//   Flutter that a new frame is ready via mark_texture_frame_available.
//
// • copy_pixels fires from Flutter's render thread.
//   It copies frame_buf → render_buf under mutex so that the pointer it
//   returns to Flutter points to render_buf — a buffer that is ONLY written
//   here (on the render thread) and therefore stable during the OpenGL upload
//   that Flutter performs immediately after the callback returns.
struct TextureState {
  FlTextureRegistrar* registrar;  // not owned — plugin outlives texture
  std::mutex mutex;
  std::vector<uint8_t> frame_buf;   // latest decoded frame (frame cb writes)
  std::vector<uint8_t> render_buf;  // stable copy for GL upload (copy_pixels writes)
  uint32_t width = 0;
  uint32_t height = 0;
  uint32_t render_width = 0;
  uint32_t render_height = 0;
  bool has_video_frames = false;     // Track if we received any video frames
};

// ─── FfkitPixelTexture — FlPixelBufferTexture subtype ────────────────────────
//
// This Flutter Linux embedder version does not expose fl_pixel_buffer_texture_new().
// The only supported way to create an FlPixelBufferTexture is to subclass it
// and override the copy_pixels virtual method via the GObject class struct.

typedef struct _FfkitPixelTexture FfkitPixelTexture;
typedef struct _FfkitPixelTextureClass FfkitPixelTextureClass;

struct _FfkitPixelTexture {
  FlPixelBufferTexture parent_instance;
  TextureState* state;  // owned; deleted in finalize
};

struct _FfkitPixelTextureClass {
  FlPixelBufferTextureClass parent_class;
};

#define FFKIT_PIXEL_TEXTURE(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), ffkit_pixel_texture_get_type(), FfkitPixelTexture))

// Forward declarations required by G_DEFINE_TYPE
static void ffkit_pixel_texture_class_init(FfkitPixelTextureClass* klass);
static void ffkit_pixel_texture_init(FfkitPixelTexture* self);

G_DEFINE_TYPE(FfkitPixelTexture, ffkit_pixel_texture,
              fl_pixel_buffer_texture_get_type())

static gboolean ffkit_pixel_texture_copy_pixels(FlPixelBufferTexture* texture,
                                                 const uint8_t** out_buffer,
                                                 uint32_t* out_width,
                                                 uint32_t* out_height,
                                                 GError** /*error*/) {
  FfkitPixelTexture* self = FFKIT_PIXEL_TEXTURE(texture);
  TextureState* state = self->state;
  std::lock_guard<std::mutex> lock(state->mutex);
  
  // Return FALSE if no video frames have been received (audio-only case)
  if (!state->has_video_frames)
    return FALSE;

  // Copy latest frame into render_buf. render_buf is ONLY written here (on
  // the render thread) so the pointer we return is stable for the duration of
  // the glTexImage2D call Flutter makes immediately after we return.
  state->render_buf = state->frame_buf;
  state->render_width = state->width;
  state->render_height = state->height;

  *out_buffer = state->render_buf.data();
  *out_width = state->render_width;
  *out_height = state->render_height;

  return TRUE;
}

static void ffkit_pixel_texture_finalize(GObject* object) {
  FfkitPixelTexture* self = FFKIT_PIXEL_TEXTURE(object);
  delete self->state;
  self->state = nullptr;
  G_OBJECT_CLASS(ffkit_pixel_texture_parent_class)->finalize(object);
}

static void ffkit_pixel_texture_class_init(FfkitPixelTextureClass* klass) {
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels =
      ffkit_pixel_texture_copy_pixels;
  G_OBJECT_CLASS(klass)->finalize = ffkit_pixel_texture_finalize;
}

static void ffkit_pixel_texture_init(FfkitPixelTexture* self) {
  self->state = new TextureState();
}

static FfkitPixelTexture* ffkit_pixel_texture_new(
    FlTextureRegistrar* registrar) {
  auto* tex = FFKIT_PIXEL_TEXTURE(
      g_object_new(ffkit_pixel_texture_get_type(), nullptr));
  tex->state->registrar = registrar;
  return tex;
}

// ─── Frame callback (FFplay background thread) ────────────────────────────────

static void on_frame_callback(void* userdata, const uint8_t* pixels, int width,
                               int height, int linesize) {
  FfkitPixelTexture* tex = FFKIT_PIXEL_TEXTURE(userdata);
  TextureState* state = tex->state;
  if (!state || !pixels || width <= 0 || height <= 0) return;

  {
    std::lock_guard<std::mutex> lock(state->mutex);
    size_t size = static_cast<size_t>(linesize) * static_cast<size_t>(height);
    state->frame_buf.resize(size);
    memcpy(state->frame_buf.data(), pixels, size);
    state->width = static_cast<uint32_t>(width);
    state->height = static_cast<uint32_t>(height);
    state->has_video_frames = true;  // Mark that we have video frames
  }

  fl_texture_registrar_mark_texture_frame_available(state->registrar,
                                                    FL_TEXTURE(tex));
}

// ─── GObject struct ───────────────────────────────────────────────────────────

struct _FfmpegKitExtendedFlutterPlugin {
  GObject parent_instance;
  FlTextureRegistrar* texture_registrar;
  FlMethodChannel* channel;
  FfkitPixelTexture* texture;  // currently active texture (nullptr if none)
};

G_DEFINE_TYPE(FfmpegKitExtendedFlutterPlugin,
              ffmpeg_kit_extended_flutter_plugin, g_object_get_type())

// ─── Release helper ───────────────────────────────────────────────────────────

static void release_texture(FfmpegKitExtendedFlutterPlugin* self) {
  if (!self->texture) return;
  FfkitPixelTexture* tex = self->texture;
  self->texture = nullptr;

  // 1. Stop frame delivery before any further cleanup.
  if (ffplay_kit_unregister_frame_callback)
    ffplay_kit_unregister_frame_callback();

  // 2. Reset video frame tracking
  {
    std::lock_guard<std::mutex> lock(tex->state->mutex);
    tex->state->has_video_frames = false;
    tex->state->frame_buf.clear();
    tex->state->render_buf.clear();
    tex->state->width = 0;
    tex->state->height = 0;
  }

  // 3. Unregister from Flutter.
  fl_texture_registrar_unregister_texture(self->texture_registrar,
                                          FL_TEXTURE(tex));

  // 4. Drop our GObject ref.  When refcount reaches 0, finalize() runs and
  //    deletes the TextureState.
  g_object_unref(tex);
}

// ─── Method handlers ──────────────────────────────────────────────────────────

static void handle_create_texture(FfmpegKitExtendedFlutterPlugin* self,
                                   FlMethodCall* method_call) {
  // Release any existing texture before creating a new one.
  release_texture(self);

  FfkitPixelTexture* tex = ffkit_pixel_texture_new(self->texture_registrar);
  fl_texture_registrar_register_texture(self->texture_registrar,
                                        FL_TEXTURE(tex));
  int64_t texture_id = fl_texture_get_id(FL_TEXTURE(tex));

  // Register the frame callback — decoded frames will now flow into this texture.
  if (ffplay_kit_register_frame_callback)
    ffplay_kit_register_frame_callback(on_frame_callback, tex);

  self->texture = tex;

  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "textureId", fl_value_new_int(texture_id));
  fl_method_call_respond_success(method_call, result, nullptr);
}

static void handle_release_texture(FfmpegKitExtendedFlutterPlugin* self,
                                    FlMethodCall* method_call) {
  release_texture(self);
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

// ─── GObject lifecycle ────────────────────────────────────────────────────────

static void ffmpeg_kit_extended_flutter_plugin_dispose(GObject* object) {
  auto* self = FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN(object);
  release_texture(self);
  // texture_registrar is a borrowed reference (fl_plugin_registrar_get_texture_registrar
  // transfers no ownership), so only null the pointer — do not unref.
  self->texture_registrar = nullptr;
  g_clear_object(&self->channel);
  G_OBJECT_CLASS(ffmpeg_kit_extended_flutter_plugin_parent_class)
      ->dispose(object);
}

static void ffmpeg_kit_extended_flutter_plugin_class_init(
    FfmpegKitExtendedFlutterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = ffmpeg_kit_extended_flutter_plugin_dispose;
}

static void ffmpeg_kit_extended_flutter_plugin_init(
    FfmpegKitExtendedFlutterPlugin* self) {
  self->texture = nullptr;
}

// ─── Registration ─────────────────────────────────────────────────────────────

static void method_call_cb(FlMethodChannel* /*channel*/,
                            FlMethodCall* method_call, gpointer user_data) {
  auto* plugin = FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN(user_data);
  ffmpeg_kit_extended_flutter_plugin_handle_method_call(plugin, method_call);
}

void ffmpeg_kit_extended_flutter_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  auto* plugin = FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN(
      g_object_new(ffmpeg_kit_extended_flutter_plugin_get_type(), nullptr));

  plugin->texture_registrar = FL_TEXTURE_REGISTRAR(
      fl_plugin_registrar_get_texture_registrar(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                             "ffplay_kit_desktop", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->channel, method_call_cb,
      g_object_ref(plugin),  // transferred to handler; unref'd on destroy
      g_object_unref);

  g_object_unref(plugin);
}
