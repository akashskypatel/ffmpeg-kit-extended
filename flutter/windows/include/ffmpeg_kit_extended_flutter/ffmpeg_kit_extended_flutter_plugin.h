#ifndef FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN_H_
#define FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/texture_registrar.h>

#include <cstdint>
#include <memory>
#include <mutex>
#include <vector>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void FfmpegKitExtendedFlutterPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}
#endif

namespace ffmpeg_kit_extended_flutter {

// ─── Pixel-buffer texture state ───────────────────────────────────────────────

// Holds the mutable state shared between the FFplay frame callback (background
// thread) and Flutter's CopyPixelBuffer callback (render thread).
//
// Double-buffer strategy: the frame callback writes into write_buf then swaps
// with read_buf under the mutex, so the render callback always reads the latest
// complete frame without blocking the decoder thread.
struct TextureState {
  flutter::TextureRegistrar* texture_registrar;  // not owned
  std::unique_ptr<flutter::TextureVariant> texture_variant;
  int64_t texture_id = -1;

  std::mutex mutex;
  std::vector<uint8_t> write_buf;
  std::vector<uint8_t> read_buf;
  // render_buf is written only on the render thread (CopyPixelBuffer) so the
  // pointer returned to Flutter remains stable after the mutex is released.
  std::vector<uint8_t> render_buf;
  uint32_t width = 0;
  uint32_t height = 0;

  // Stable FlutterDesktopPixelBuffer returned by CopyPixelBuffer.
  FlutterDesktopPixelBuffer pixel_buffer{};
};

// ─── Plugin class ─────────────────────────────────────────────────────────────

class FfmpegKitExtendedFlutterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows* registrar);

  FfmpegKitExtendedFlutterPlugin();
  virtual ~FfmpegKitExtendedFlutterPlugin();

  // Disallow copy and assign.
  FfmpegKitExtendedFlutterPlugin(const FfmpegKitExtendedFlutterPlugin&) =
      delete;
  FfmpegKitExtendedFlutterPlugin& operator=(
      const FfmpegKitExtendedFlutterPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandleCreateTexture(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleReleaseTexture(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ReleaseTextureState();

  flutter::TextureRegistrar* texture_registrar_ = nullptr;
  std::unique_ptr<TextureState> texture_state_;
};

}  // namespace ffmpeg_kit_extended_flutter

#endif  // FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN_H_
