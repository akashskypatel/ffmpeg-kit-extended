#include "include/ffmpeg_kit_flutter/ffmpeg_kit_flutter_plugin.h"
#include "ffmpeg_kit_flutter_plugin_private.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>
#include <cstring>
#include <map>
#include <list>
#include <string>
#include <vector>
#include <memory>
#include <sstream>
#include <iostream>

// FFmpegKit Headers
#include <ffmpegkit/FFmpegKit.h>
#include <ffmpegkit/FFprobeKit.h>
#include <ffmpegkit/FFmpegKitConfig.h>
#include <ffmpegkit/FFmpegSession.h>
#include <ffmpegkit/FFprobeSession.h>
#include <ffmpegkit/MediaInformationSession.h>
#include <ffmpegkit/ArchDetect.h>

// -----------------------------------------------------------------------------
// Constants & Keys
// -----------------------------------------------------------------------------

static const char *const PLATFORM_NAME = "linux";
static const char *const METHOD_CHANNEL_NAME = "flutter.akashskypatel.com/ffmpeg_kit";
static const char *const EVENT_CHANNEL_NAME = "flutter.akashskypatel.com/ffmpeg_kit_event";

// Keys matching MacOS implementation
static const char *const KEY_SESSION_ID = "sessionId";
static const char *const KEY_SESSION_CREATE_TIME = "createTime";
static const char *const KEY_SESSION_START_TIME = "startTime";
static const char *const KEY_SESSION_END_TIME = "endTime";
static const char *const KEY_SESSION_COMMAND = "command";
static const char *const KEY_SESSION_TYPE = "type";
static const char *const KEY_SESSION_RETURN_CODE = "returnCode";
static const char *const KEY_SESSION_FAIL_STACK_TRACE = "failStackTrace";
static const char *const KEY_SESSION_MEDIA_INFORMATION = "mediaInformation";

// Media Information Keys
static const char *const KEY_FILENAME = "filename";
static const char *const KEY_FORMAT = "format";
static const char *const KEY_BITRATE = "bitrate";
static const char *const KEY_DURATION = "duration";
static const char *const KEY_TAGS = "tags";
static const char *const KEY_STREAMS = "streams";
static const char *const KEY_CHAPTERS = "chapters";
static const char *const KEY_SIZE = "size";

// Log Keys
static const char *const KEY_LOG_SESSION_ID = "sessionId";
static const char *const KEY_LOG_LEVEL = "level";
static const char *const KEY_LOG_MESSAGE = "message";

// Statistics Keys
static const char *const KEY_STATISTICS_SESSION_ID = "sessionId";
static const char *const KEY_STATISTICS_VIDEO_FRAME_NUMBER = "videoFrameNumber";
static const char *const KEY_STATISTICS_VIDEO_FPS = "videoFps";
static const char *const KEY_STATISTICS_VIDEO_QUALITY = "videoQuality";
static const char *const KEY_STATISTICS_SIZE = "size";
static const char *const KEY_STATISTICS_TIME = "time";
static const char *const KEY_STATISTICS_BITRATE = "bitrate";
static const char *const KEY_STATISTICS_SPEED = "speed";

// Events
static const char *const EVENT_LOG_CALLBACK = "FFmpegKitLogCallbackEvent";
static const char *const EVENT_STATISTICS_CALLBACK = "FFmpegKitStatisticsCallbackEvent";
static const char *const EVENT_COMPLETE_CALLBACK = "FFmpegKitCompleteCallbackEvent";

using namespace ffmpegkit;

// -----------------------------------------------------------------------------
// Plugin Structure
// -----------------------------------------------------------------------------

struct _FfmpegKitFlutterPlugin {
  GObject parent_instance;
  FlMethodChannel* method_channel;
  FlEventChannel* event_channel;
};

G_DEFINE_TYPE(FfmpegKitFlutterPlugin, ffmpeg_kit_flutter_plugin, g_object_get_type())

// -----------------------------------------------------------------------------
// Globals
// -----------------------------------------------------------------------------

// Global sink for Event Channel (accessed by static FFmpegKit callbacks)
// Note: In a production plugin, we might want to handle multiple plugin instances,
// but for now we follow the singleton pattern typical for these bridges.
static FlEventSink *global_event_sink = nullptr;
static bool logs_enabled = false;
static bool statistics_enabled = false;

// -----------------------------------------------------------------------------
// Helper Declarations
// -----------------------------------------------------------------------------

static FlValue* session_to_map(std::shared_ptr<Session> session);
static FlValue* log_to_map(std::shared_ptr<Log> log);
static FlValue* statistics_to_map(std::shared_ptr<Statistics> stats);
static FlValue* media_information_to_map(std::shared_ptr<MediaInformation> mediaInformation);

// -----------------------------------------------------------------------------
// Event Dispatcher (Background Thread -> Main Thread)
// -----------------------------------------------------------------------------

typedef struct {
    char* event_name;
    FlValue* payload;
} AsyncEventData;

static gboolean on_emit_event_main_thread(gpointer user_data) {
    AsyncEventData* data = (AsyncEventData*)user_data;
    
    if (global_event_sink) {
        FlValue* wrapper = fl_value_new_map();
        fl_value_set_string_take(wrapper, data->event_name, data->payload);
        fl_event_sink_success(global_event_sink, wrapper);
    } else {
        if (data->payload) fl_value_unref(data->payload);
    }

    g_free(data->event_name);
    g_free(data);
    return FALSE; // Remove source
}

static void emit_event(const char* event_name, FlValue* payload_map) {
    if (!global_event_sink) {
        if (payload_map) fl_value_unref(payload_map);
        return;
    }

    AsyncEventData* data = g_new0(AsyncEventData, 1);
    data->event_name = g_strdup(event_name);
    data->payload = payload_map;

    g_idle_add(on_emit_event_main_thread, data);
}

// -----------------------------------------------------------------------------
// FFmpegKit Global Callbacks
// -----------------------------------------------------------------------------

void register_global_callbacks() {
    
    // Session Complete
    FFmpegKitConfig::enableFFmpegSessionCompleteCallback([](std::shared_ptr<FFmpegSession> session){
        emit_event(EVENT_COMPLETE_CALLBACK, session_to_map(session));
    });

    FFmpegKitConfig::enableFFprobeSessionCompleteCallback([](std::shared_ptr<FFprobeSession> session){
        emit_event(EVENT_COMPLETE_CALLBACK, session_to_map(session));
    });

    FFmpegKitConfig::enableMediaInformationSessionCompleteCallback([](std::shared_ptr<MediaInformationSession> session){
        emit_event(EVENT_COMPLETE_CALLBACK, session_to_map(session));
    });

    // Logs
    FFmpegKitConfig::enableLogCallback([](std::shared_ptr<Log> log){
        if (logs_enabled) {
            emit_event(EVENT_LOG_CALLBACK, log_to_map(log));
        }
    });

    // Statistics
    FFmpegKitConfig::enableStatisticsCallback([](std::shared_ptr<Statistics> stats){
        if (statistics_enabled) {
            emit_event(EVENT_STATISTICS_CALLBACK, statistics_to_map(stats));
        }
    });
}

// -----------------------------------------------------------------------------
// Event Channel Handlers
// -----------------------------------------------------------------------------

static FlMethodErrorResponse* event_channel_listen_cb(FlEventChannel* channel,
                                                      FlValue* args,
                                                      FlEventSink* event_sink,
                                                      gpointer user_data) {
  if (global_event_sink) {
      g_object_unref(global_event_sink);
  }
  global_event_sink = event_sink;
  g_object_ref(global_event_sink);
  
  // Re-register callbacks to ensure they are active
  register_global_callbacks();
  return nullptr;
}

static FlMethodErrorResponse* event_channel_cancel_cb(FlEventChannel* channel,
                                                      FlValue* args,
                                                      gpointer user_data) {
  if (global_event_sink) {
    g_object_unref(global_event_sink);
    global_event_sink = nullptr;
  }
  return nullptr;
}

// -----------------------------------------------------------------------------
// Data Conversion Implementation
// -----------------------------------------------------------------------------

static FlValue* json_to_fl_value(const Json::Value& value) {
    switch (value.type()) {
        case Json::nullValue: return fl_value_new_null();
        case Json::intValue: return fl_value_new_int(value.asInt64());
        case Json::uintValue: return fl_value_new_int((int64_t)value.asUInt64());
        case Json::realValue: return fl_value_new_float(value.asDouble());
        case Json::stringValue: return fl_value_new_string(value.asCString());
        case Json::booleanValue: return fl_value_new_bool(value.asBool());
        case Json::arrayValue: {
            FlValue* list = fl_value_new_list();
            for (const auto& item : value) {
                fl_value_append_take(list, json_to_fl_value(item));
            }
            return list;
        }
        case Json::objectValue: {
            FlValue* map = fl_value_new_map();
            for (auto const& id : value.getMemberNames()) {
                fl_value_set_string_take(map, id.c_str(), json_to_fl_value(value[id]));
            }
            return map;
        }
        default: return fl_value_new_null();
    }
}

static FlValue* media_information_to_map(std::shared_ptr<MediaInformation> info) {
    if (!info) return fl_value_new_null();
    FlValue* map = fl_value_new_map();

    if(info->getFilename()) fl_value_set_string(map, KEY_FILENAME, info->getFilename()->c_str());
    if(info->getFormat()) fl_value_set_string(map, KEY_FORMAT, info->getFormat()->c_str());
    if(info->getBitrate()) fl_value_set_string(map, KEY_BITRATE, info->getBitrate()->c_str());
    if(info->getDuration()) fl_value_set_string(map, KEY_DURATION, info->getDuration()->c_str());
    if(info->getSize()) fl_value_set_string(map, KEY_SIZE, info->getSize()->c_str());

    if(info->getTags()) {
        fl_value_set_string_take(map, KEY_TAGS, json_to_fl_value(*(info->getTags())));
    }
    
    std::shared_ptr<Json::Value> allProps = info->getAllProperties();
    if (allProps) {
        if (allProps->isMember(KEY_STREAMS)) 
            fl_value_set_string_take(map, KEY_STREAMS, json_to_fl_value((*allProps)[KEY_STREAMS]));
        if (allProps->isMember(KEY_CHAPTERS)) 
            fl_value_set_string_take(map, KEY_CHAPTERS, json_to_fl_value((*allProps)[KEY_CHAPTERS]));
    }

    return map;
}

static FlValue* session_to_map(std::shared_ptr<Session> session) {
    if (!session) return fl_value_new_null();
    FlValue* map = fl_value_new_map();

    fl_value_set_string_take(map, KEY_SESSION_ID, fl_value_new_int(session->getSessionId()));
    fl_value_set_string(map, KEY_SESSION_COMMAND, session->getCommand().c_str());
    
    // Times
    auto createMs = std::chrono::duration_cast<std::chrono::milliseconds>(session->getCreateTime().time_since_epoch()).count();
    fl_value_set_string_take(map, KEY_SESSION_CREATE_TIME, fl_value_new_int(createMs));
    
    auto startMs = std::chrono::duration_cast<std::chrono::milliseconds>(session->getStartTime().time_since_epoch()).count();
    fl_value_set_string_take(map, KEY_SESSION_START_TIME, fl_value_new_int(startMs));
    
    auto endMs = std::chrono::duration_cast<std::chrono::milliseconds>(session->getEndTime().time_since_epoch()).count();
    fl_value_set_string_take(map, KEY_SESSION_END_TIME, fl_value_new_int(endMs));

    // Return Code
    if (session->getReturnCode()) {
        fl_value_set_string_take(map, KEY_SESSION_RETURN_CODE, fl_value_new_int(session->getReturnCode()->getValue()));
    }
    
    // Stack Trace
    fl_value_set_string(map, KEY_SESSION_FAIL_STACK_TRACE, session->getFailStackTrace().c_str());

    // Type
    if (session->isFFmpeg()) {
        fl_value_set_string_take(map, KEY_SESSION_TYPE, fl_value_new_int(1));
    } else if (session->isFFprobe()) {
         fl_value_set_string_take(map, KEY_SESSION_TYPE, fl_value_new_int(2));
    } else if (session->isMediaInformation()) {
         fl_value_set_string_take(map, KEY_SESSION_TYPE, fl_value_new_int(3));
         auto mediaSession = std::dynamic_pointer_cast<MediaInformationSession>(session);
         fl_value_set_string_take(map, KEY_SESSION_MEDIA_INFORMATION, media_information_to_map(mediaSession->getMediaInformation()));
    }

    return map;
}

static FlValue* log_to_map(std::shared_ptr<Log> log) {
    if (!log) return fl_value_new_null();
    FlValue* map = fl_value_new_map();
    fl_value_set_string_take(map, KEY_LOG_SESSION_ID, fl_value_new_int(log->getSessionId()));
    fl_value_set_string_take(map, KEY_LOG_LEVEL, fl_value_new_int((int)log->getLevel()));
    fl_value_set_string(map, KEY_LOG_MESSAGE, log->getMessage().c_str());
    return map;
}

static FlValue* statistics_to_map(std::shared_ptr<Statistics> stats) {
    if (!stats) return fl_value_new_null();
    FlValue* map = fl_value_new_map();
    fl_value_set_string_take(map, KEY_STATISTICS_SESSION_ID, fl_value_new_int(stats->getSessionId()));
    fl_value_set_string_take(map, KEY_STATISTICS_VIDEO_FRAME_NUMBER, fl_value_new_int(stats->getVideoFrameNumber()));
    fl_value_set_string_take(map, KEY_STATISTICS_VIDEO_FPS, fl_value_new_float(stats->getVideoFps()));
    fl_value_set_string_take(map, KEY_STATISTICS_VIDEO_QUALITY, fl_value_new_float(stats->getVideoQuality()));
    fl_value_set_string_take(map, KEY_STATISTICS_SIZE, fl_value_new_int(stats->getSize()));
    fl_value_set_string_take(map, KEY_STATISTICS_TIME, fl_value_new_float(stats->getTime()));
    fl_value_set_string_take(map, KEY_STATISTICS_BITRATE, fl_value_new_float(stats->getBitrate()));
    fl_value_set_string_take(map, KEY_STATISTICS_SPEED, fl_value_new_float(stats->getSpeed()));
    return map;
}

// -----------------------------------------------------------------------------
// Method Call Handler
// -----------------------------------------------------------------------------

static std::vector<std::string> fl_value_to_str_vector(FlValue* args, const char* key) {
    std::vector<std::string> list;
    if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
        FlValue* val = fl_value_lookup_string(args, key);
        if (val && fl_value_get_type(val) == FL_VALUE_TYPE_LIST) {
            size_t len = fl_value_get_length(val);
            for(size_t i=0; i<len; i++) {
                FlValue* item = fl_value_get_list_value(val, i);
                if (fl_value_get_type(item) == FL_VALUE_TYPE_STRING) {
                    list.push_back(fl_value_get_string(item));
                }
            }
        }
    }
    return list;
}

static int64_t fl_value_to_long(FlValue* args, const char* key) {
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) return -1;
    FlValue* val = fl_value_lookup_string(args, key);
    if (val && fl_value_get_type(val) == FL_VALUE_TYPE_INT) return fl_value_get_int(val);
    return -1;
}

static void ffmpeg_kit_flutter_plugin_handle_method_call(
    FfmpegKitFlutterPlugin* self,
    FlMethodCall* method_call) {
  
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "getPlatform") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string(PLATFORM_NAME)));
  } 
  else if (strcmp(method, "getArch") == 0) {
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string(ArchDetect::getArch().c_str())));
  }
  else if (strcmp(method, "ffmpegSession") == 0) {
      std::vector<std::string> arguments = fl_value_to_str_vector(args, "arguments");
      std::list<std::string> argsList(arguments.begin(), arguments.end());
      auto session = FFmpegSession::create(argsList);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(session_to_map(session)));
  }
  else if (strcmp(method, "ffprobeSession") == 0) {
      std::vector<std::string> arguments = fl_value_to_str_vector(args, "arguments");
      std::list<std::string> argsList(arguments.begin(), arguments.end());
      auto session = FFprobeSession::create(argsList);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(session_to_map(session)));
  }
  else if (strcmp(method, "mediaInformationSession") == 0) {
      std::vector<std::string> arguments = fl_value_to_str_vector(args, "arguments");
      std::list<std::string> argsList(arguments.begin(), arguments.end());
      auto session = MediaInformationSession::create(argsList);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(session_to_map(session)));
  }
  else if (strcmp(method, "ffmpegSessionExecute") == 0) {
      int64_t sessionId = fl_value_to_long(args, KEY_SESSION_ID);
      auto session = std::dynamic_pointer_cast<FFmpegSession>(FFmpegKitConfig::getSession(sessionId));
      if (session) {
          FFmpegKitConfig::asyncFFmpegExecute(session);
          response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
      } else {
          response = FL_METHOD_RESPONSE(fl_method_error_response_new("SESSION_NOT_FOUND", "Session not found", nullptr));
      }
  }
  else if (strcmp(method, "ffprobeSessionExecute") == 0) {
      int64_t sessionId = fl_value_to_long(args, KEY_SESSION_ID);
      auto session = std::dynamic_pointer_cast<FFprobeSession>(FFmpegKitConfig::getSession(sessionId));
      if (session) {
          FFmpegKitConfig::asyncFFprobeExecute(session);
          response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
      } else {
          response = FL_METHOD_RESPONSE(fl_method_error_response_new("SESSION_NOT_FOUND", "Session not found", nullptr));
      }
  }
  else if (strcmp(method, "mediaInformationSessionExecute") == 0) {
      int64_t sessionId = fl_value_to_long(args, KEY_SESSION_ID);
      int64_t timeout = fl_value_to_long(args, "waitTimeout");
      auto session = std::dynamic_pointer_cast<MediaInformationSession>(FFmpegKitConfig::getSession(sessionId));
      if (session) {
          FFmpegKitConfig::asyncGetMediaInformationExecute(session, (int)timeout);
          response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
      } else {
          response = FL_METHOD_RESPONSE(fl_method_error_response_new("SESSION_NOT_FOUND", "Session not found", nullptr));
      }
  }
  else if (strcmp(method, "enableLogs") == 0) {
      logs_enabled = true;
      FFmpegKitConfig::enableRedirection();
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "disableLogs") == 0) {
      logs_enabled = false;
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "enableStatistics") == 0) {
      statistics_enabled = true;
      FFmpegKitConfig::enableRedirection();
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "disableStatistics") == 0) {
      statistics_enabled = false;
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "cancel") == 0) {
      FFmpegKit::cancel();
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "cancelSession") == 0) {
      int64_t sessionId = fl_value_to_long(args, KEY_SESSION_ID);
      FFmpegKit::cancel(sessionId);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "getLogLevel") == 0) {
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_int((int)FFmpegKitConfig::getLogLevel())));
  }
  else if (strcmp(method, "setLogLevel") == 0) {
      if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
         FlValue* val = fl_value_lookup_string(args, "level");
         if (val && fl_value_get_type(val) == FL_VALUE_TYPE_INT) {
             FFmpegKitConfig::setLogLevel((Level)fl_value_get_int(val));
         }
      }
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "getSession") == 0) {
      int64_t sessionId = fl_value_to_long(args, KEY_SESSION_ID);
      auto session = FFmpegKitConfig::getSession(sessionId);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(session_to_map(session)));
  }
  else if (strcmp(method, "getLastSession") == 0) {
       response = FL_METHOD_RESPONSE(fl_method_success_response_new(session_to_map(FFmpegKitConfig::getLastSession())));
  }
  else if (strcmp(method, "getLastCompletedSession") == 0) {
       response = FL_METHOD_RESPONSE(fl_method_success_response_new(session_to_map(FFmpegKitConfig::getLastCompletedSession())));
  }
  else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

// -----------------------------------------------------------------------------
// Boilerplate
// -----------------------------------------------------------------------------

static void ffmpeg_kit_flutter_plugin_dispose(GObject* object) {
  FfmpegKitFlutterPlugin* self = FFMPEG_KIT_FLUTTER_PLUGIN(object);
  if (self->method_channel) g_object_unref(self->method_channel);
  if (self->event_channel) g_object_unref(self->event_channel);
  G_OBJECT_CLASS(ffmpeg_kit_flutter_plugin_parent_class)->dispose(object);
}

static void ffmpeg_kit_flutter_plugin_class_init(FfmpegKitFlutterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = ffmpeg_kit_flutter_plugin_dispose;
}

static void ffmpeg_kit_flutter_plugin_init(FfmpegKitFlutterPlugin* self) {
    register_global_callbacks();
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  FfmpegKitFlutterPlugin* plugin = FFMPEG_KIT_FLUTTER_PLUGIN(user_data);
  ffmpeg_kit_flutter_plugin_handle_method_call(plugin, method_call);
}

void ffmpeg_kit_flutter_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FfmpegKitFlutterPlugin* plugin = FFMPEG_KIT_FLUTTER_PLUGIN(
      g_object_new(ffmpeg_kit_flutter_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->method_channel = fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                                                 METHOD_CHANNEL_NAME,
                                                 FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(plugin->method_channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_autoptr(FlStandardMethodCodec) event_codec = fl_standard_method_codec_new();
  plugin->event_channel = fl_event_channel_new(fl_plugin_registrar_get_messenger(registrar),
                                               EVENT_CHANNEL_NAME,
                                               FL_METHOD_CODEC(event_codec));
  
  fl_event_channel_set_stream_handler(plugin->event_channel,
                                      event_channel_listen_cb,
                                      event_channel_cancel_cb,
                                      nullptr, nullptr);

  g_object_unref(plugin);
}