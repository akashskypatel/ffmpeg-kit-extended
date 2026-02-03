#ifndef FLUTTER_PLUGIN_FFMPEG_KIT_FLUTTER_PLUGIN_H_
#define FLUTTER_PLUGIN_FFMPEG_KIT_FLUTTER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <map>
#include <mutex>

namespace ffmpeg_kit_flutter {

class FFmpegKitFlutterPlugin : public flutter::Plugin, public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FFmpegKitFlutterPlugin(flutter::PluginRegistrarWindows *registrar);
  virtual ~FFmpegKitFlutterPlugin();

  // Disallow copy and assign.
  FFmpegKitFlutterPlugin(const FFmpegKitFlutterPlugin&) = delete;
  FFmpegKitFlutterPlugin& operator=(const FFmpegKitFlutterPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 protected:
  // StreamHandler implementation
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListen(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override;

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancel(
      const flutter::EncodableValue* arguments) override;

 private:
  void RegisterGlobalCallbacks();
  void EmitEvent(const std::string& eventName, const flutter::EncodableMap& payload);

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  std::mutex event_sink_mutex_;
  
  bool logs_enabled_ = false;
  bool statistics_enabled_ = false;
};

}  // namespace ffmpeg_kit_flutter

#endif  // FLUTTER_PLUGIN_FFMPEG_KIT_FLUTTER_PLUGIN_H_