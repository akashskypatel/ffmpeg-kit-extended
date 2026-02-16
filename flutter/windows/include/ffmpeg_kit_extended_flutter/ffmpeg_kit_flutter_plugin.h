#ifndef FFMPEG_KIT_FLUTTER_PLUGIN_H_
#define FFMPEG_KIT_FLUTTER_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void FfmpegKitFlutterPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}
#endif


namespace ffmpeg_kit_extended_flutter {

class FfmpegKitFlutterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FfmpegKitFlutterPlugin();

  virtual ~FfmpegKitFlutterPlugin();

  // Disallow copy and assign.
  FfmpegKitFlutterPlugin(const FfmpegKitFlutterPlugin&) = delete;
  FfmpegKitFlutterPlugin& operator=(const FfmpegKitFlutterPlugin&) = delete;
};

}  // namespace ffmpeg_kit_extended_flutter

#endif // FFMPEG_KIT_FLUTTER_PLUGIN_H_
