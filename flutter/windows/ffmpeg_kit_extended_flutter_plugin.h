#ifndef FLUTTER_PLUGIN_FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN_H_
#define FLUTTER_PLUGIN_FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace ffmpeg_kit_extended_flutter {

class FfmpegKitExtendedFlutterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FfmpegKitExtendedFlutterPlugin();

  virtual ~FfmpegKitExtendedFlutterPlugin();

  // Disallow copy and assign.
  FfmpegKitExtendedFlutterPlugin(const FfmpegKitExtendedFlutterPlugin&) = delete;
  FfmpegKitExtendedFlutterPlugin& operator=(const FfmpegKitExtendedFlutterPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace ffmpeg_kit_extended_flutter

#endif  // FLUTTER_PLUGIN_FFMPEG_KIT_EXTENDED_FLUTTER_PLUGIN_H_
