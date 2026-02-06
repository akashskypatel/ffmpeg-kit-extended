#ifndef FLUTTER_PLUGIN_FFMPEG_KIT_FLUTTER_PLUGIN_H_
#define FLUTTER_PLUGIN_FFMPEG_KIT_FLUTTER_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <mutex>
#include <string>

#include "ffmpegkit_wrapper.hpp"

namespace ffmpeg_kit_extended_flutter {

class FfmpegKitFlutterPlugin
    : public flutter::Plugin,
      public flutter::StreamHandler<flutter::EncodableValue> {
public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FfmpegKitFlutterPlugin(flutter::PluginRegistrarWindows *registrar);
  virtual ~FfmpegKitFlutterPlugin();

  // Disallow copy and assign.
  FfmpegKitFlutterPlugin(const FfmpegKitFlutterPlugin &) = delete;
  FfmpegKitFlutterPlugin &operator=(const FfmpegKitFlutterPlugin &) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

protected:
  // StreamHandler implementation
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
  OnListenInternal(const flutter::EncodableValue *arguments,
                   std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>
                       &&events) override;

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
  OnCancelInternal(const flutter::EncodableValue *arguments) override;

private:
  void RegisterGlobalCallbacks();
  void EmitEvent(const std::string &eventName,
                 const flutter::EncodableMap &payload);

  // Static Trampolines for C Callbacks
  static void FFmpegKitCompleteCallbackTrampoline(FFmpegSessionHandle session,
                                                  void *user_data);
  static void FFprobeKitCompleteCallbackTrampoline(FFprobeSessionHandle session,
                                                   void *user_data);
  static void MediaInformationSessionCompleteCallbackTrampoline(
      MediaInformationSessionHandle session, void *user_data);
  static void FFmpegKitLogCallbackTrampoline(FFmpegSessionHandle session,
                                             const char *log, void *user_data);
  static void FFmpegKitStatisticsCallbackTrampoline(
      FFmpegSessionHandle session, int time, int64_t size, double bitrate,
      double speed, int videoFrameNumber, float videoFps, float videoQuality,
      void *user_data);

  flutter::PluginRegistrarWindows *registrar_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  std::mutex event_sink_mutex_;

  bool logs_enabled_ = false;
  bool statistics_enabled_ = false;
};

} // namespace ffmpeg_kit_extended_flutter

#endif // FLUTTER_PLUGIN_FFMPEG_KIT_FLUTTER_PLUGIN_H_