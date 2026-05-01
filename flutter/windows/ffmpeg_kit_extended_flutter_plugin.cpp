// FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
// Copyright (C) 2026 Akash Patel
//
// This library is free software; you can redistribute it and/or modify it
// under the terms of the GNU Lesser General Public License as published by the
// Free Software Foundation; either version 2.1 of the License, or (at your
// option) any later version.

#include "include/ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter_plugin.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <cstring>
#include <mutex>

// ─── FFmpegKit ABI (runtime-resolved) ────────────────────────────────────────
// Resolve the frame-callback symbols at runtime via GetProcAddress so that the
// plugin DLL has no link-time dependency on the libffmpegkit.dll import library
// for these symbols.  The DLL is already loaded in the process by the time any
// MethodChannel call arrives, so GetModuleHandle is sufficient.

typedef void (*FFplayKitFrameCallback)(void* userdata, const uint8_t* pixels,
                                       int width, int height, int linesize, const char *format);

namespace {

using RegisterFn   = void (*)(FFplayKitFrameCallback, void*);
using UnregisterFn = void (*)();

static RegisterFn   g_register_fn   = nullptr;
static UnregisterFn g_unregister_fn = nullptr;
static std::once_flag g_resolve_once;

static void ResolveFFplayProcs() {
  std::call_once(g_resolve_once, [] {
    static const char* kDllNames[] = {"libffmpegkit.dll", "ffmpegkit.dll",
                                      nullptr};
    for (const char** name = kDllNames; *name; ++name) {
      HMODULE h = ::GetModuleHandleA(*name);
      if (!h) {
        ::OutputDebugStringA(
            ("[ffmpegkit_plugin] GetModuleHandle(\"" + std::string(*name) +
             "\") -> not loaded\n").c_str());
        continue;
      }

      // Log the actual DLL path so we can confirm which file is in use.
      char dllPath[MAX_PATH] = {};
      ::GetModuleFileNameA(h, dllPath, MAX_PATH);
      ::OutputDebugStringA(
          ("[ffmpegkit_plugin] found DLL: " + std::string(dllPath) + "\n")
              .c_str());

      g_register_fn = reinterpret_cast<RegisterFn>(
          ::GetProcAddress(h, "ffplay_kit_register_frame_callback"));
      g_unregister_fn = reinterpret_cast<UnregisterFn>(
          ::GetProcAddress(h, "ffplay_kit_unregister_frame_callback"));

      // Probe additional symbols to confirm the DLL export table is complete.
      auto video_w_fn =
          ::GetProcAddress(h, "ffplay_kit_session_get_video_width");
      using BuildStampFn = const char* (*)();
      auto build_stamp_fn = reinterpret_cast<BuildStampFn>(
          ::GetProcAddress(h, "ffmpeg_kit_get_build_stamp"));

      char msg[512];
      ::snprintf(msg, sizeof(msg),
                 "[ffmpegkit_plugin] symbol probe — "
                 "register_frame_callback: %s  "
                 "unregister_frame_callback: %s  "
                 "session_get_video_width: %s  "
                 "get_build_stamp: %s  "
                 "build: %s\n",
                 g_register_fn ? "OK" : "MISSING",
                 g_unregister_fn ? "OK" : "MISSING",
                 video_w_fn ? "OK" : "MISSING",
                 build_stamp_fn ? "OK" : "MISSING",
                 build_stamp_fn ? build_stamp_fn() : "n/a");
      ::OutputDebugStringA(msg);

      if (g_register_fn && g_unregister_fn) break;
    }
  });
}

static void ffplay_kit_register_frame_callback(FFplayKitFrameCallback cb,
                                                void* ud) {
  ResolveFFplayProcs();
  if (g_register_fn) g_register_fn(cb, ud);
}

static void ffplay_kit_unregister_frame_callback() {
  ResolveFFplayProcs();
  if (g_unregister_fn) g_unregister_fn();
}

}  // namespace

namespace ffmpeg_kit_extended_flutter {

// ─── Frame callback (FFplay background thread) ────────────────────────────────

static void OnFrameCallback(void* userdata, const uint8_t* pixels, int width,
                             int height, int linesize, const char* pixel_format) {
  auto* state = reinterpret_cast<TextureState*>(userdata);
  if (!state || !pixels || width <= 0 || height <= 0) return;

  {
    std::lock_guard<std::mutex> lock(state->mutex);
    // Early exit if texture is being destroyed
    if (state->destroyed) {
      return;
    }
    size_t row_bytes = static_cast<size_t>(linesize);
    state->write_buf.resize(row_bytes * static_cast<size_t>(height));
    memcpy(state->write_buf.data(), pixels, state->write_buf.size());
    if (pixel_format && strcmp(pixel_format, "rgb0") == 0) {
      uint8_t* buf = state->write_buf.data();
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          buf[y * linesize + x * 4 + 3] = 0xFF;
        }
      }
    }
    state->width = static_cast<uint32_t>(width);
    state->height = static_cast<uint32_t>(height);
    // Swap write_buf ↔ read_buf so the render callback always gets the latest
    // complete frame without blocking the decoder thread.
    std::swap(state->write_buf, state->read_buf);
    state->texture_registrar->MarkTextureFrameAvailable(state->texture_id);
  }
}

// ─── CopyPixelBuffer callback (Flutter render thread) ────────────────────────

static const FlutterDesktopPixelBuffer* CopyPixelBuffer(size_t /*width*/,
                                                         size_t /*height*/,
                                                         void* userdata) {
  auto* state = reinterpret_cast<TextureState*>(userdata);
  std::lock_guard<std::mutex> lock(state->mutex);
  if (state->read_buf.empty() || state->width == 0 || state->height == 0)
    return nullptr;

  // Copy under the mutex so render_buf.data() remains stable after we return
  // and the mutex is released (OnFrameCallback may swap read_buf at any time).
  state->render_buf = state->read_buf;
  state->pixel_buffer.buffer = state->render_buf.data();
  state->pixel_buffer.width = state->width;
  state->pixel_buffer.height = state->height;
  state->pixel_buffer.release_callback = nullptr;
  state->pixel_buffer.release_context = nullptr;
  return &state->pixel_buffer;
}

// ─── Plugin implementation ────────────────────────────────────────────────────

// static
void FfmpegKitExtendedFlutterPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<FfmpegKitExtendedFlutterPlugin>();
  plugin->texture_registrar_ = registrar->texture_registrar();

  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "ffplay_kit_desktop",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [plugin_ptr = plugin.get()](const auto& call, auto result) {
        plugin_ptr->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FfmpegKitExtendedFlutterPlugin::FfmpegKitExtendedFlutterPlugin() = default;

FfmpegKitExtendedFlutterPlugin::~FfmpegKitExtendedFlutterPlugin() {
  ReleaseTextureState();
}

void FfmpegKitExtendedFlutterPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "createTexture") {
    HandleCreateTexture(std::move(result));
  } else if (method_call.method_name() == "releaseTexture") {
    HandleReleaseTexture(method_call, std::move(result));
  } else {
    result->NotImplemented();
  }
}

void FfmpegKitExtendedFlutterPlugin::HandleCreateTexture(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Release any existing texture before creating a new one.
  ReleaseTextureState();

  auto state = std::make_unique<TextureState>();
  state->texture_registrar = texture_registrar_;

  // Build the TextureVariant with a PixelBufferTexture.  The lambda captures
  // the raw state pointer; the TextureVariant is owned by the TextureState so
  // it is always destroyed before the state itself.
  TextureState* state_ptr = state.get();
  state->texture_variant = std::make_unique<flutter::TextureVariant>(
      flutter::PixelBufferTexture(
          [state_ptr](size_t w, size_t h) -> const FlutterDesktopPixelBuffer* {
            return CopyPixelBuffer(w, h, state_ptr);
          }));

  state->texture_id =
      texture_registrar_->RegisterTexture(state->texture_variant.get());

  // Register frame callback — decoded frames will now flow into this texture.
  ffplay_kit_register_frame_callback(OnFrameCallback, state_ptr);

  texture_state_ = std::move(state);

  flutter::EncodableMap reply;
  reply[flutter::EncodableValue("textureId")] =
      flutter::EncodableValue(static_cast<int64_t>(texture_state_->texture_id));
  result->Success(flutter::EncodableValue(reply));
}

void FfmpegKitExtendedFlutterPlugin::HandleReleaseTexture(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Extract textureId from method call arguments
  const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
  if (!args) {
    result->Error("INVALID_ARGUMENT", "Expected map with textureId");
    return;
  }
  
  auto it = args->find(flutter::EncodableValue("textureId"));
  if (it == args->end()) {
    result->Error("INVALID_ARGUMENT", "Expected textureId in map");
    return;
  }
  
  const auto* texture_id_value = std::get_if<int64_t>(&it->second);
  if (!texture_id_value) {
    result->Error("INVALID_ARGUMENT", "Expected textureId to be integer");
    return;
  }
  
  int64_t requested_texture_id = *texture_id_value;
  
  // Only release if the texture ID matches the currently active texture
  if (texture_state_ && texture_state_->texture_id == requested_texture_id) {
    ReleaseTextureState();
  }
  
  result->Success();
}

void FfmpegKitExtendedFlutterPlugin::ReleaseTextureState() {
  if (!texture_state_) return;

  // Store a local copy of the state pointer to avoid race conditions
  auto state_to_release = std::move(texture_state_);
  texture_state_ = nullptr;

  // 1. Stop frame delivery before touching the texture.
  ffplay_kit_unregister_frame_callback();

  // 2. Drain any in-flight callback: acquire then immediately release the mutex
  //    to guarantee the callback (which now holds the mutex for its entire
  //    duration) has fully exited before we destroy the state.
  { 
    std::lock_guard<std::mutex> lock(state_to_release->mutex);
    // Mark as destroyed while holding the mutex to ensure no concurrent access
    state_to_release->destroyed = true;
    // Clear state while holding the mutex to ensure no concurrent access
    state_to_release->write_buf.clear();
    state_to_release->read_buf.clear();
    state_to_release->render_buf.clear();
    state_to_release->width = 0;
    state_to_release->height = 0;
  }

  // 3. Unregister the texture from Flutter's TextureRegistrar.
  if (state_to_release->texture_id >= 0) {
    texture_registrar_->UnregisterTexture(state_to_release->texture_id);
    state_to_release->texture_id = -1;
  }

  // 4. Destroy the state (and the TextureVariant inside it).
  // state_to_release goes out of scope here, automatically destroying the TextureState
}

}  // namespace ffmpeg_kit_extended_flutter
