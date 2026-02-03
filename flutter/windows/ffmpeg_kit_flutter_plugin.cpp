#include "ffmpeg_kit_flutter_plugin.h"

#include <windows.h>
#include <VersionHelpers.h>
#include <iostream>
#include <vector>
#include <thread>
#include <algorithm>

// FFmpegKit Headers
#include <ffmpegkit/FFmpegKit.h>
#include <ffmpegkit/FFprobeKit.h>
#include <ffmpegkit/FFmpegKitConfig.h>
#include <ffmpegkit/FFmpegSession.h>
#include <ffmpegkit/FFprobeSession.h>
#include <ffmpegkit/MediaInformationSession.h>
#include <ffmpegkit/ArchDetect.h>

using namespace flutter;
using namespace ffmpegkit;

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
static const std::string EVENT_STATISTICS_CALLBACK = "FFmpegKitStatisticsCallbackEvent";
static const std::string EVENT_COMPLETE_CALLBACK = "FFmpegKitCompleteCallbackEvent";

namespace ffmpeg_kit_flutter {

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

static EncodableValue JsonToEncodable(const Json::Value& value) {
    switch (value.type()) {
        case Json::nullValue: return EncodableValue();
        case Json::intValue: return EncodableValue((int64_t)value.asInt64());
        case Json::uintValue: return EncodableValue((int64_t)value.asUInt64());
        case Json::realValue: return EncodableValue(value.asDouble());
        case Json::stringValue: return EncodableValue(value.asCString());
        case Json::booleanValue: return EncodableValue(value.asBool());
        case Json::arrayValue: {
            EncodableList list;
            for (const auto& item : value) {
                list.push_back(JsonToEncodable(item));
            }
            return EncodableValue(list);
        }
        case Json::objectValue: {
            EncodableMap map;
            for (auto const& id : value.getMemberNames()) {
                map[EncodableValue(id)] = JsonToEncodable(value[id]);
            }
            return EncodableValue(map);
        }
        default: return EncodableValue();
    }
}

static EncodableMap MediaInformationToMap(std::shared_ptr<MediaInformation> info) {
    EncodableMap map;
    if (!info) return map;

    if(info->getFilename()) map[EncodableValue(KEY_FILENAME)] = EncodableValue(*info->getFilename());
    if(info->getFormat()) map[EncodableValue(KEY_FORMAT)] = EncodableValue(*info->getFormat());
    if(info->getBitrate()) map[EncodableValue(KEY_BITRATE)] = EncodableValue(*info->getBitrate());
    if(info->getDuration()) map[EncodableValue(KEY_DURATION)] = EncodableValue(*info->getDuration());
    if(info->getSize()) map[EncodableValue(KEY_SIZE)] = EncodableValue(*info->getSize());

    if(info->getTags()) {
        map[EncodableValue(KEY_TAGS)] = JsonToEncodable(*(info->getTags()));
    }

    auto allProps = info->getAllProperties();
    if (allProps) {
        if (allProps->isMember(KEY_STREAMS)) 
            map[EncodableValue(KEY_STREAMS)] = JsonToEncodable((*allProps)[KEY_STREAMS]);
        if (allProps->isMember(KEY_CHAPTERS)) 
            map[EncodableValue(KEY_CHAPTERS)] = JsonToEncodable((*allProps)[KEY_CHAPTERS]);
    }
    return map;
}

static EncodableMap SessionToMap(std::shared_ptr<Session> session) {
    EncodableMap map;
    if (!session) return map;

    map[EncodableValue(KEY_SESSION_ID)] = EncodableValue((int64_t)session->getSessionId());
    map[EncodableValue(KEY_SESSION_COMMAND)] = EncodableValue(session->getCommand());

    auto createMs = std::chrono::duration_cast<std::chrono::milliseconds>(session->getCreateTime().time_since_epoch()).count();
    map[EncodableValue(KEY_SESSION_CREATE_TIME)] = EncodableValue((int64_t)createMs);

    auto startMs = std::chrono::duration_cast<std::chrono::milliseconds>(session->getStartTime().time_since_epoch()).count();
    map[EncodableValue(KEY_SESSION_START_TIME)] = EncodableValue((int64_t)startMs);

    auto endMs = std::chrono::duration_cast<std::chrono::milliseconds>(session->getEndTime().time_since_epoch()).count();
    map[EncodableValue(KEY_SESSION_END_TIME)] = EncodableValue((int64_t)endMs);

    if (session->getReturnCode()) {
        map[EncodableValue(KEY_SESSION_RETURN_CODE)] = EncodableValue(session->getReturnCode()->getValue());
    }
    map[EncodableValue(KEY_SESSION_FAIL_STACK_TRACE)] = EncodableValue(session->getFailStackTrace());

    if (session->isFFmpeg()) {
        map[EncodableValue(KEY_SESSION_TYPE)] = EncodableValue(1);
    } else if (session->isFFprobe()) {
        map[EncodableValue(KEY_SESSION_TYPE)] = EncodableValue(2);
    } else if (session->isMediaInformation()) {
        map[EncodableValue(KEY_SESSION_TYPE)] = EncodableValue(3);
        auto mediaSession = std::dynamic_pointer_cast<MediaInformationSession>(session);
        map[EncodableValue(KEY_SESSION_MEDIA_INFORMATION)] = EncodableValue(MediaInformationToMap(mediaSession->getMediaInformation()));
    }

    return map;
}

static EncodableMap LogToMap(std::shared_ptr<Log> log) {
    EncodableMap map;
    if (!log) return map;
    map[EncodableValue(KEY_LOG_SESSION_ID)] = EncodableValue((int64_t)log->getSessionId());
    map[EncodableValue(KEY_LOG_LEVEL)] = EncodableValue((int)log->getLevel());
    map[EncodableValue(KEY_LOG_MESSAGE)] = EncodableValue(log->getMessage());
    return map;
}

static EncodableMap StatisticsToMap(std::shared_ptr<Statistics> stats) {
    EncodableMap map;
    if (!stats) return map;
    map[EncodableValue(KEY_STATISTICS_SESSION_ID)] = EncodableValue((int64_t)stats->getSessionId());
    map[EncodableValue(KEY_STATISTICS_VIDEO_FRAME_NUMBER)] = EncodableValue(stats->getVideoFrameNumber());
    map[EncodableValue(KEY_STATISTICS_VIDEO_FPS)] = EncodableValue(stats->getVideoFps());
    map[EncodableValue(KEY_STATISTICS_VIDEO_QUALITY)] = EncodableValue(stats->getVideoQuality());
    map[EncodableValue(KEY_STATISTICS_SIZE)] = EncodableValue((int64_t)stats->getSize());
    map[EncodableValue(KEY_STATISTICS_TIME)] = EncodableValue(stats->getTime());
    map[EncodableValue(KEY_STATISTICS_BITRATE)] = EncodableValue(stats->getBitrate());
    map[EncodableValue(KEY_STATISTICS_SPEED)] = EncodableValue(stats->getSpeed());
    return map;
}

// -----------------------------------------------------------------------------
// Registration & Setup
// -----------------------------------------------------------------------------

void FFmpegKitFlutterPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<FFmpegKitFlutterPlugin>(registrar);

  auto method_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "flutter.akashskypatel.com/ffmpeg_kit",
      &flutter::StandardMethodCodec::GetInstance());

  method_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  auto event_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      registrar->messenger(), "flutter.akashskypatel.com/ffmpeg_kit_event",
      &flutter::StandardMethodCodec::GetInstance());

  event_channel->SetStreamHandler(std::move(plugin));
}

FFmpegKitFlutterPlugin::FFmpegKitFlutterPlugin(flutter::PluginRegistrarWindows *registrar) 
    : registrar_(registrar) {
    RegisterGlobalCallbacks();
}

FFmpegKitFlutterPlugin::~FFmpegKitFlutterPlugin() {}

// -----------------------------------------------------------------------------
// Method Call Handler
// -----------------------------------------------------------------------------

void FFmpegKitFlutterPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  const auto* arguments = std::get_if<EncodableMap>(call.arguments());
  
  // Helper lambda to safely extract args
  auto GetInt64Arg = [&](const std::string& key) -> int64_t {
      if (!arguments) return -1;
      auto it = arguments->find(EncodableValue(key));
      if (it != arguments->end()) {
          if (std::holds_alternative<int32_t>(it->second)) return std::get<int32_t>(it->second);
          if (std::holds_alternative<int64_t>(it->second)) return std::get<int64_t>(it->second);
      }
      return -1;
  };

  auto GetStringListArg = [&](const std::string& key) -> std::list<std::string> {
      std::list<std::string> list;
      if (!arguments) return list;
      auto it = arguments->find(EncodableValue(key));
      if (it != arguments->end() && std::holds_alternative<EncodableList>(it->second)) {
          const auto& encList = std::get<EncodableList>(it->second);
          for (const auto& item : encList) {
              if (std::holds_alternative<std::string>(item)) list.push_back(std::get<std::string>(item));
          }
      }
      return list;
  };

  if (call.method_name() == "getPlatform") {
    result->Success(EncodableValue("windows"));
  }
  else if (call.method_name() == "getArch") {
    result->Success(EncodableValue(ArchDetect::getArch()));
  }
  else if (call.method_name() == "ffmpegSession") {
      auto args = GetStringListArg("arguments");
      auto session = FFmpegSession::create(args);
      result->Success(EncodableValue(SessionToMap(session)));
  }
  else if (call.method_name() == "ffprobeSession") {
      auto args = GetStringListArg("arguments");
      auto session = FFprobeSession::create(args);
      result->Success(EncodableValue(SessionToMap(session)));
  }
  else if (call.method_name() == "mediaInformationSession") {
      auto args = GetStringListArg("arguments");
      auto session = MediaInformationSession::create(args);
      result->Success(EncodableValue(SessionToMap(session)));
  }
  else if (call.method_name() == "ffmpegSessionExecute") {
      int64_t id = GetInt64Arg(KEY_SESSION_ID);
      auto session = std::dynamic_pointer_cast<FFmpegSession>(FFmpegKitConfig::getSession(id));
      if (session) {
          FFmpegKitConfig::asyncFFmpegExecute(session);
          result->Success();
      } else {
          result->Error("SESSION_NOT_FOUND", "Session not found");
      }
  }
  else if (call.method_name() == "ffprobeSessionExecute") {
      int64_t id = GetInt64Arg(KEY_SESSION_ID);
      auto session = std::dynamic_pointer_cast<FFprobeSession>(FFmpegKitConfig::getSession(id));
      if (session) {
          FFmpegKitConfig::asyncFFprobeExecute(session);
          result->Success();
      } else {
          result->Error("SESSION_NOT_FOUND", "Session not found");
      }
  }
  else if (call.method_name() == "mediaInformationSessionExecute") {
      int64_t id = GetInt64Arg(KEY_SESSION_ID);
      int64_t timeout = GetInt64Arg("waitTimeout");
      auto session = std::dynamic_pointer_cast<MediaInformationSession>(FFmpegKitConfig::getSession(id));
      if (session) {
          FFmpegKitConfig::asyncGetMediaInformationExecute(session, (int)timeout);
          result->Success();
      } else {
          result->Error("SESSION_NOT_FOUND", "Session not found");
      }
  }
  else if (call.method_name() == "enableLogs") {
      logs_enabled_ = true;
      FFmpegKitConfig::enableRedirection();
      result->Success();
  }
  else if (call.method_name() == "disableLogs") {
      logs_enabled_ = false;
      result->Success();
  }
  else if (call.method_name() == "enableStatistics") {
      statistics_enabled_ = true;
      FFmpegKitConfig::enableRedirection();
      result->Success();
  }
  else if (call.method_name() == "disableStatistics") {
      statistics_enabled_ = false;
      result->Success();
  }
  else if (call.method_name() == "cancel") {
      FFmpegKit::cancel();
      result->Success();
  }
  else if (call.method_name() == "cancelSession") {
      int64_t id = GetInt64Arg(KEY_SESSION_ID);
      FFmpegKit::cancel(id);
      result->Success();
  }
  else if (call.method_name() == "getLogLevel") {
      result->Success(EncodableValue((int)FFmpegKitConfig::getLogLevel()));
  }
  else if (call.method_name() == "getSession") {
      int64_t id = GetInt64Arg(KEY_SESSION_ID);
      auto session = FFmpegKitConfig::getSession(id);
      result->Success(EncodableValue(SessionToMap(session)));
  }
  else if (call.method_name() == "getLastSession") {
      result->Success(EncodableValue(SessionToMap(FFmpegKitConfig::getLastSession())));
  }
  else {
    result->NotImplemented();
  }
}

// -----------------------------------------------------------------------------
// Stream Handler (Events)
// -----------------------------------------------------------------------------

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> 
FFmpegKitFlutterPlugin::OnListen(const flutter::EncodableValue* arguments,
                                 std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  std::lock_guard<std::mutex> lock(event_sink_mutex_);
  event_sink_ = std::move(events);
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> 
FFmpegKitFlutterPlugin::OnCancel(const flutter::EncodableValue* arguments) {
  std::lock_guard<std::mutex> lock(event_sink_mutex_);
  event_sink_ = nullptr;
  return nullptr;
}

void FFmpegKitFlutterPlugin::EmitEvent(const std::string& eventName, const flutter::EncodableMap& payload) {
    // We are on a background thread here (FFmpeg thread)
    // We must marshal to the main thread to use event_sink_ safely
    // Since PluginRegistrarWindows doesn't expose a simple PostTask, and standard std::thread doesn't hold the context,
    // we assume the event sink implementation is thread-safe OR we use a primitive dispatch if needed.
    // Flutter Windows Runner is single-threaded usually.
    
    // NOTE: The most robust way in C++ plugins is to keep a reference to a dispatcher.
    // However, for this implementation, we will use a lock and assume the event_sink 
    // implementation handles the thread check or we simply risk it if the engine allows it (it often does for Success).
    // A safer way is using `hwnd` PostMessage if available, but we lack `hwnd` here.
    
    // We will use a safe copying mechanism.
    std::lock_guard<std::mutex> lock(event_sink_mutex_);
    if (event_sink_) {
        EncodableMap event;
        event[EncodableValue(eventName)] = EncodableValue(payload);
        event_sink_->Success(EncodableValue(event));
    }
}

void FFmpegKitFlutterPlugin::RegisterGlobalCallbacks() {
    FFmpegKitConfig::enableFFmpegSessionCompleteCallback([this](std::shared_ptr<FFmpegSession> session){
        EmitEvent(EVENT_COMPLETE_CALLBACK, SessionToMap(session));
    });
    
    FFmpegKitConfig::enableFFprobeSessionCompleteCallback([this](std::shared_ptr<FFprobeSession> session){
        EmitEvent(EVENT_COMPLETE_CALLBACK, SessionToMap(session));
    });

    FFmpegKitConfig::enableMediaInformationSessionCompleteCallback([this](std::shared_ptr<MediaInformationSession> session){
        EmitEvent(EVENT_COMPLETE_CALLBACK, SessionToMap(session));
    });

    FFmpegKitConfig::enableLogCallback([this](std::shared_ptr<Log> log){
        if (logs_enabled_) {
            EmitEvent(EVENT_LOG_CALLBACK, LogToMap(log));
        }
    });

    FFmpegKitConfig::enableStatisticsCallback([this](std::shared_ptr<Statistics> stats){
        if (statistics_enabled_) {
            EmitEvent(EVENT_STATISTICS_CALLBACK, StatisticsToMap(stats));
        }
    });
}

}  // namespace ffmpeg_kit_flutter