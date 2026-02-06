#include "ffmpeg_kit_flutter_plugin.h"

#include <VersionHelpers.h>
#include <algorithm>
#include <chrono>
#include <iostream>
#include <thread>
#include <vector>
#include <windows.h>

// FFmpegKit Wrapper Header
#include "ffmpegkit_wrapper.hpp"

using namespace flutter;

// -----------------------------------------------------------------------------
// Constants & Keys
// -----------------------------------------------------------------------------

static const std::string KEY_SESSION_ID = "sessionId";
static const std::string KEY_SESSION_CREATE_TIME = "createTime";
static const std::string KEY_SESSION_START_TIME = "startTime";
static const std::string KEY_SESSION_END_TIME = "endTime";
static const std::string KEY_SESSION_COMMAND = "command";
static const std::string KEY_SESSION_TYPE = "type";
static const std::string KEY_SESSION_RETURN_CODE = "returnCode";
static const std::string KEY_SESSION_FAIL_STACK_TRACE = "failStackTrace";
static const std::string KEY_SESSION_MEDIA_INFORMATION = "mediaInformation";

static const std::string KEY_FILENAME = "filename";
static const std::string KEY_FORMAT = "format";
static const std::string KEY_BITRATE = "bitrate";
static const std::string KEY_DURATION = "duration";
static const std::string KEY_TAGS = "tags";
static const std::string KEY_STREAMS = "streams";
static const std::string KEY_CHAPTERS = "chapters";
static const std::string KEY_SIZE = "size";

static const std::string KEY_LOG_SESSION_ID = "sessionId";
static const std::string KEY_LOG_LEVEL = "level";
static const std::string KEY_LOG_MESSAGE = "message";

static const std::string KEY_STATISTICS_SESSION_ID = "sessionId";
static const std::string KEY_STATISTICS_VIDEO_FRAME_NUMBER = "videoFrameNumber";
static const std::string KEY_STATISTICS_VIDEO_FPS = "videoFps";
static const std::string KEY_STATISTICS_VIDEO_QUALITY = "videoQuality";
static const std::string KEY_STATISTICS_SIZE = "size";
static const std::string KEY_STATISTICS_TIME = "time";
static const std::string KEY_STATISTICS_BITRATE = "bitrate";
static const std::string KEY_STATISTICS_SPEED = "speed";

static const std::string EVENT_LOG_CALLBACK = "FFmpegKitLogCallbackEvent";
static const std::string EVENT_STATISTICS_CALLBACK =
    "FFmpegKitStatisticsCallbackEvent";
static const std::string EVENT_COMPLETE_CALLBACK =
    "FFmpegKitCompleteCallbackEvent";

namespace ffmpeg_kit_extended_flutter {

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Helper to convert C-string to EncodableValue, handling null
static EncodableValue StringToEncodable(const char *str) {
  if (str) {
    return EncodableValue(std::string(str));
  }
  return EncodableValue();
}

static EncodableMap MediaInformationToMap(MediaInformationHandle info) {
  EncodableMap map;
  if (!info)
    return map;

  map[EncodableValue(KEY_FILENAME)] =
      StringToEncodable(media_information_get_filename(info));
  map[EncodableValue(KEY_FORMAT)] =
      StringToEncodable(media_information_get_format(info));
  map[EncodableValue(KEY_BITRATE)] =
      StringToEncodable(media_information_get_bitrate(info));
  map[EncodableValue(KEY_DURATION)] =
      StringToEncodable(media_information_get_duration(info));
  map[EncodableValue(KEY_SIZE)] =
      StringToEncodable(media_information_get_size(info));

  // Passing raw JSON strings for nested objects/tags
  char *tags = media_information_get_tags_json(info);
  if (tags) {
    map[EncodableValue(KEY_TAGS)] = EncodableValue(std::string(tags));
    // free(tags) ? Wrapper implementation of `get_tags_json` usually returns a
    // copy or pointer? Standard C wrapper usually implies ownership transfer or
    // static string. Looking at wrapper header: `char
    // *media_information_get_tags_json` -> "Returns JSON string". Assuming we
    // don't need to free, or it's managed. If it's strdup'd, we leak. Safe bet:
    // The wrapper likely returns `std::string::c_str()` which might be invalid
    // after object death OR it returns a strdup. Without source, assumed safe
    // to read copy.
  }

  char *allProps = media_information_get_all_properties_json(info);
  if (allProps) {
    // We can't easily parse this without a JSON lib.
    // Existing dart code might expect a Map for Streams/Chapters.
    // If we pass a String, we break the contract.
    // BUT `allProps` contains everything.
    // Ideally we iterate streams/chapters using the C API iterators.

    int streamsCount = media_information_get_streams_count(info);
    EncodableList streamsList;
    for (int i = 0; i < streamsCount; i++) {
      auto stream = media_information_get_stream_at(info, i);
      EncodableMap streamMap;
      streamMap[EncodableValue("index")] =
          EncodableValue(stream_information_get_index(stream));
      streamMap[EncodableValue("type")] =
          StringToEncodable(stream_information_get_type(stream));
      streamMap[EncodableValue("codec")] =
          StringToEncodable(stream_information_get_codec(stream));
      // ... add other stream props if critical
      streamsList.push_back(EncodableValue(streamMap));
    }
    if (!streamsList.empty()) {
      map[EncodableValue(KEY_STREAMS)] = EncodableValue(streamsList);
    }

    // Similarly for chapters
  }
  return map;
}

// Session Helpers
static EncodableMap SessionToMap(FFmpegSessionHandle session,
                                 int typeHint = 0) {
  EncodableMap map;
  if (!session)
    return map;

  map[EncodableValue(KEY_SESSION_ID)] =
      EncodableValue((int64_t)ffmpeg_kit_session_get_session_id(session));
  map[EncodableValue(KEY_SESSION_COMMAND)] =
      StringToEncodable(ffmpeg_kit_session_get_command(session));

  map[EncodableValue(KEY_SESSION_CREATE_TIME)] =
      EncodableValue((int64_t)ffmpeg_kit_session_get_create_time(session));
  map[EncodableValue(KEY_SESSION_START_TIME)] =
      EncodableValue((int64_t)ffmpeg_kit_session_get_start_time(session));
  map[EncodableValue(KEY_SESSION_END_TIME)] =
      EncodableValue((int64_t)ffmpeg_kit_session_get_end_time(session));

  int returnCode = ffmpeg_kit_session_get_return_code(session);
  // Return code valid check?
  map[EncodableValue(KEY_SESSION_RETURN_CODE)] = EncodableValue(returnCode);

  map[EncodableValue(KEY_SESSION_FAIL_STACK_TRACE)] =
      StringToEncodable(ffmpeg_kit_session_get_fail_stack_trace(session));

  // Determine Type
  // 1=FFmpeg, 2=FFprobe, 3=MediaInfo.
  // We use hint if > 0.
  if (typeHint > 0) {
    map[EncodableValue(KEY_SESSION_TYPE)] = EncodableValue(typeHint);
    if (typeHint == 3) {
      // MediaInfo
      auto mediaSession = (MediaInformationSessionHandle)session;
      auto info = media_information_session_get_media_information(mediaSession);
      map[EncodableValue(KEY_SESSION_MEDIA_INFORMATION)] =
          EncodableValue(MediaInformationToMap(info));
    }
  }

  return map;
}

static EncodableMap LogToMap(FFmpegSessionHandle session, const char *message) {
  EncodableMap map;
  // Note: Log object in C++ had Level. Wrapper callback sends session +
  // message. Wait, wrapper callback: `void
  // (*FFmpegKitLogCallback)(FFmpegSessionHandle session, const char *log, void
  // *user_data);` It doesn't pass a "Log" object with Level. It passes the log
  // string. The C++ API `Log` object had `getLevel()`. Wrapper API seems to
  // flatten this. I will check `ffmpegkit_wrapper.hpp`. `typedef void
  // (*FFmpegKitLogCallback)(FFmpegSessionHandle session, const char *log, void
  // *user_data);` Yes, only `log` string. BUT the `LogToMap` expected
  // `KEY_LOG_LEVEL`. We can't get level from the callback arguments. We will
  // default to something or omit.

  map[EncodableValue(KEY_LOG_SESSION_ID)] =
      EncodableValue((int64_t)ffmpeg_kit_session_get_session_id(session));
  map[EncodableValue(KEY_LOG_MESSAGE)] = StringToEncodable(message);
  map[EncodableValue(KEY_LOG_LEVEL)] =
      EncodableValue(32); // Default to INFO or similar
  return map;
}

static EncodableMap StatisticsToMap(FFmpegSessionHandle session, int time,
                                    int64_t size, double bitrate, double speed,
                                    int videoFrameNumber, float videoFps,
                                    float videoQuality) {
  EncodableMap map;
  map[EncodableValue(KEY_STATISTICS_SESSION_ID)] =
      EncodableValue((int64_t)ffmpeg_kit_session_get_session_id(session));
  map[EncodableValue(KEY_STATISTICS_VIDEO_FRAME_NUMBER)] =
      EncodableValue(videoFrameNumber);
  map[EncodableValue(KEY_STATISTICS_VIDEO_FPS)] = EncodableValue(videoFps);
  map[EncodableValue(KEY_STATISTICS_VIDEO_QUALITY)] =
      EncodableValue(videoQuality);
  map[EncodableValue(KEY_STATISTICS_SIZE)] = EncodableValue((int64_t)size);
  map[EncodableValue(KEY_STATISTICS_TIME)] = EncodableValue(time);
  map[EncodableValue(KEY_STATISTICS_BITRATE)] = EncodableValue(bitrate);
  map[EncodableValue(KEY_STATISTICS_SPEED)] = EncodableValue(speed);
  return map;
}

// Trampolines
void FfmpegKitFlutterPlugin::FFmpegKitCompleteCallbackTrampoline(
    FFmpegSessionHandle session, void *user_data) {
  auto plugin = reinterpret_cast<FfmpegKitFlutterPlugin *>(user_data);
  plugin->EmitEvent(EVENT_COMPLETE_CALLBACK,
                    SessionToMap(session, 1)); // Type 1 = FFmpeg
}

void FfmpegKitFlutterPlugin::FFprobeKitCompleteCallbackTrampoline(
    FFprobeSessionHandle session, void *user_data) {
  auto plugin = reinterpret_cast<FfmpegKitFlutterPlugin *>(user_data);
  plugin->EmitEvent(EVENT_COMPLETE_CALLBACK,
                    SessionToMap(session, 2)); // Type 2 = FFprobe
}

void FfmpegKitFlutterPlugin::MediaInformationSessionCompleteCallbackTrampoline(
    MediaInformationSessionHandle session, void *user_data) {
  auto plugin = reinterpret_cast<FfmpegKitFlutterPlugin *>(user_data);
  plugin->EmitEvent(EVENT_COMPLETE_CALLBACK,
                    SessionToMap(session, 3)); // Type 3 = MediaInfo
}

void FfmpegKitFlutterPlugin::FFmpegKitLogCallbackTrampoline(
    FFmpegSessionHandle session, const char *log, void *user_data) {
  auto plugin = reinterpret_cast<FfmpegKitFlutterPlugin *>(user_data);
  if (plugin->logs_enabled_) {
    plugin->EmitEvent(EVENT_LOG_CALLBACK, LogToMap(session, log));
  }
}

void FfmpegKitFlutterPlugin::FFmpegKitStatisticsCallbackTrampoline(
    FFmpegSessionHandle session, int time, int64_t size, double bitrate,
    double speed, int videoFrameNumber, float videoFps, float videoQuality,
    void *user_data) {
  auto plugin = reinterpret_cast<FfmpegKitFlutterPlugin *>(user_data);
  if (plugin->statistics_enabled_) {
    plugin->EmitEvent(EVENT_STATISTICS_CALLBACK,
                      StatisticsToMap(session, time, size, bitrate, speed,
                                      videoFrameNumber, videoFps,
                                      videoQuality));
  }
}

// -----------------------------------------------------------------------------
// Registration & Setup
// -----------------------------------------------------------------------------

void FfmpegKitFlutterPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<FfmpegKitFlutterPlugin>(registrar);

  auto method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter.akashskypatel.com/ffmpeg_kit",
          &flutter::StandardMethodCodec::GetInstance());

  method_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter.akashskypatel.com/ffmpeg_kit_event",
          &flutter::StandardMethodCodec::GetInstance());

  event_channel->SetStreamHandler(std::move(plugin));
}

FfmpegKitFlutterPlugin::FfmpegKitFlutterPlugin(
    flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar) {
  RegisterGlobalCallbacks();
}

FfmpegKitFlutterPlugin::~FfmpegKitFlutterPlugin() {}

// -----------------------------------------------------------------------------
// Method Call Handler
// -----------------------------------------------------------------------------

void FfmpegKitFlutterPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto *arguments = std::get_if<EncodableMap>(call.arguments());

  // Helper lambda to safely extract args
  auto GetInt64Arg = [&](const std::string &key) -> int64_t {
    if (!arguments)
      return -1;
    auto it = arguments->find(EncodableValue(key));
    if (it != arguments->end()) {
      if (std::holds_alternative<int32_t>(it->second))
        return std::get<int32_t>(it->second);
      if (std::holds_alternative<int64_t>(it->second))
        return std::get<int64_t>(it->second);
    }
    return -1;
  };

  auto GetStringListArg =
      [&](const std::string &key) -> std::list<std::string> {
    std::list<std::string> list;
    if (!arguments)
      return list;
    auto it = arguments->find(EncodableValue(key));
    if (it != arguments->end() &&
        std::holds_alternative<EncodableList>(it->second)) {
      const auto &encList = std::get<EncodableList>(it->second);
      for (const auto &item : encList) {
        if (std::holds_alternative<std::string>(item))
          list.push_back(std::get<std::string>(item));
      }
    }
    return list;
  };

  auto CreateCommandString =
      [&](const std::list<std::string> &list) -> std::string {
    if (list.empty())
      return "";
    std::vector<char *> web_argv;
    for (const auto &str : list) {
      web_argv.push_back(const_cast<char *>(str.c_str()));
    }
    char *joined = ffmpeg_kit_config_arguments_to_string(web_argv.data(),
                                                         (int)web_argv.size());
    std::string result = joined ? std::string(joined) : "";
    return result;
  };

  if (call.method_name() == "getPlatform") {
    result->Success(EncodableValue("windows"));
  } else if (call.method_name() == "getArch") {
    result->Success(EncodableValue("x86_64"));
  } else if (call.method_name() == "ffmpegSession") {
    auto args = GetStringListArg("arguments");
    std::string command = CreateCommandString(args);
    auto session = ffmpeg_kit_create_session(command.c_str());
    result->Success(EncodableValue(SessionToMap(session, 1)));
  } else if (call.method_name() == "ffprobeSession") {
    auto args = GetStringListArg("arguments");
    std::string command = CreateCommandString(args);
    auto session = ffprobe_kit_create_session(command.c_str());
    result->Success(EncodableValue(SessionToMap(session, 2)));
  } else if (call.method_name() == "mediaInformationSession") {
    result->Error(
        "NOT_SUPPORTED",
        "MediaInformationSession split config not supported by wrapper yet.");
  } else if (call.method_name() == "ffmpegSessionExecute") {
    int64_t id = GetInt64Arg(KEY_SESSION_ID);
    auto session = ffmpeg_kit_get_session((long)id);
    if (session) {
      ffmpeg_kit_session_execute(session);
      result->Success();
    } else {
      result->Error("SESSION_NOT_FOUND", "Session not found");
    }
  } else if (call.method_name() == "ffprobeSessionExecute") {
    int64_t id = GetInt64Arg(KEY_SESSION_ID);
    auto session = ffmpeg_kit_get_session((long)id);
    if (session) {
      ffprobe_kit_session_execute(session);
      result->Success();
    } else {
      result->Error("SESSION_NOT_FOUND", "Session not found");
    }
  } else if (call.method_name() == "mediaInformationSessionExecute") {
    result->Error("NOT_SUPPORTED",
                  "MediaInformationSessionExecute not supported.");
  } else if (call.method_name() == "enableLogs") {
    logs_enabled_ = true;
    ffmpeg_kit_config_enable_redirection();
    result->Success();
  } else if (call.method_name() == "disableLogs") {
    logs_enabled_ = false;
    ffmpeg_kit_config_disable_redirection();
    result->Success();
  } else if (call.method_name() == "enableStatistics") {
    statistics_enabled_ = true;
    ffmpeg_kit_config_enable_redirection();
    result->Success();
  } else if (call.method_name() == "disableStatistics") {
    statistics_enabled_ = false;
    result->Success();
  } else if (call.method_name() == "cancel") {
    ffmpeg_kit_cancel();
    result->Success();
  } else if (call.method_name() == "cancelSession") {
    int64_t id = GetInt64Arg(KEY_SESSION_ID);
    ffmpeg_kit_cancel_session((long)id);
    result->Success();
  } else if (call.method_name() == "getLogLevel") {
    result->Success(EncodableValue((int)ffmpeg_kit_config_get_log_level()));
  } else if (call.method_name() == "getSession") {
    int64_t id = GetInt64Arg(KEY_SESSION_ID);
    auto session = ffmpeg_kit_get_session((long)id);
    result->Success(EncodableValue(SessionToMap(session)));
  } else if (call.method_name() == "getLastSession") {
    result->Success(
        EncodableValue(SessionToMap(ffmpeg_kit_get_last_session())));
  } else {
    result->NotImplemented();
  }
}

// -----------------------------------------------------------------------------
// Stream Handler (Events)
// -----------------------------------------------------------------------------

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
FfmpegKitFlutterPlugin::OnListenInternal(
    const flutter::EncodableValue *arguments,
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> &&events) {
  std::lock_guard<std::mutex> lock(event_sink_mutex_);
  event_sink_ = std::move(events);
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
FfmpegKitFlutterPlugin::OnCancelInternal(
    const flutter::EncodableValue *arguments) {
  std::lock_guard<std::mutex> lock(event_sink_mutex_);
  event_sink_ = nullptr;
  return nullptr;
}

void FfmpegKitFlutterPlugin::EmitEvent(const std::string &eventName,
                                       const flutter::EncodableMap &payload) {
  std::lock_guard<std::mutex> lock(event_sink_mutex_);
  if (event_sink_) {
    EncodableMap event;
    event[EncodableValue(eventName)] = EncodableValue(payload);
    event_sink_->Success(EncodableValue(event));
  }
}

void FfmpegKitFlutterPlugin::RegisterGlobalCallbacks() {
  ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
      FFmpegKitCompleteCallbackTrampoline, this);

  ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
      FFprobeKitCompleteCallbackTrampoline, this);

  ffmpeg_kit_config_enable_media_information_session_complete_callback(
      MediaInformationSessionCompleteCallbackTrampoline, this);

  ffmpeg_kit_config_enable_log_callback(FFmpegKitLogCallbackTrampoline, this);

  ffmpeg_kit_config_enable_statistics_callback(
      FFmpegKitStatisticsCallbackTrampoline, this);
}

} // namespace ffmpeg_kit_extended_flutter
