// FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
// Copyright (C) 2026 Akash Patel
//
// This library is free software; you can redistribute it and/or modify it
// under the terms of the GNU Lesser General Public License as published by the
// Free Software Foundation; either version 2.1 of the License, or (at your
// option) any later version.

#include "include/ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter_plugin.h"
#include "../native/ffplay_owner_coordinator.h"
#include "../native/texture_registration_transaction.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <cstring>
#include <mutex>
#include <string>

// --- FFmpegKit ABI (runtime-resolved) ----------------------------------------
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
static std::mutex g_resolve_mutex;

static bool ResolveFFplayProcs() {
  std::lock_guard<std::mutex> lock(g_resolve_mutex);
  if (g_register_fn && g_unregister_fn) return true;

  RegisterFn resolved_register = nullptr;
  UnregisterFn resolved_unregister = nullptr;
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

    char dllPath[MAX_PATH] = {};
    ::GetModuleFileNameA(h, dllPath, MAX_PATH);
    ::OutputDebugStringA(
        ("[ffmpegkit_plugin] found DLL: " + std::string(dllPath) + "\n")
            .c_str());

    auto candidate_register = reinterpret_cast<RegisterFn>(
        ::GetProcAddress(h, "ffplay_kit_register_frame_callback"));
    auto candidate_unregister = reinterpret_cast<UnregisterFn>(
        ::GetProcAddress(h, "ffplay_kit_unregister_frame_callback"));
    if (candidate_register && candidate_unregister) {
      resolved_register = candidate_register;
      resolved_unregister = candidate_unregister;
      break;
    }
  }

  // Commit the pair atomically. A miss remains retryable and never publishes
  // one half of the frame API.
  if (!resolved_register || !resolved_unregister) {
    g_register_fn = nullptr;
    g_unregister_fn = nullptr;
    return false;
  }
  g_register_fn = resolved_register;
  g_unregister_fn = resolved_unregister;
  return true;
}

static bool ffplay_kit_register_frame_callback(FFplayKitFrameCallback cb,
                                               void* ud) {
  if (!ResolveFFplayProcs() || !g_register_fn) return false;
  g_register_fn(cb, ud);
  return true;
}

static bool ffplay_kit_unregister_frame_callback() {
  if (!ResolveFFplayProcs() || !g_unregister_fn) return false;
  g_unregister_fn();
  return true;
}

}  // namespace

namespace ffmpeg_kit_extended_flutter {

static FfplayOwnerCoordinator<TextureState> g_ffplay_owner;

// --- Frame callback (FFplay background thread) --------------------------------

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
    // Swap write_buf <-> read_buf so the render callback always gets the latest
    // complete frame without blocking the decoder thread.
    std::swap(state->write_buf, state->read_buf);
    state->texture_registrar->MarkTextureFrameAvailable(state->texture_id);
  }
}

// --- CopyPixelBuffer callback (Flutter render thread) ------------------------

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

// --- Plugin implementation ----------------------------------------------------

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
  if (!ResolveFFplayProcs()) {
    result->Error("FFPLAY_UNAVAILABLE",
                  "FFplay frame callback API is not available yet");
    return;
  }

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

  if (state->texture_id < 0) {
    result->Error("TEXTURE_REGISTRATION_FAILED",
                  "Flutter could not register the FFplay texture");
    return;
  }

  // Register frame callback - decoded frames will now flow into this texture.
  // Only the latest successful wrapper binding owns the process-global target.
  if (!InstallOwnerAfterTextureRegistration(
          state->texture_id,
          [state_ptr] {
            return g_ffplay_owner.install(
                state_ptr, [state_ptr] {
                  return ffplay_kit_register_frame_callback(OnFrameCallback,
                                                            state_ptr);
                });
          },
          [this](int64_t texture_id) {
            texture_registrar_->UnregisterTexture(texture_id);
          })) {
    result->Error("FFPLAY_OWNER", "Could not claim FFplay output ownership");
    return;
  }

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

  // 1. Stop frame delivery only if this exact state still owns the
  // process-global callback. A stale plugin must not clear a newer texture.
  g_ffplay_owner.uninstallIfOwned(
      state_to_release.get(), [] { ffplay_kit_unregister_frame_callback(); });

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
