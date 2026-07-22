#include "FFmpegKitDynamicApi.h"

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <mutex>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

#if defined(_WIN32)
#include <windows.h>
#else
#include <dlfcn.h>
#endif

namespace ffmpegkit::bridge {
namespace {

using Handle = void *;
using HandleArray = void **;

std::once_flag initFlag;
#if defined(_WIN32)
HMODULE libraryHandle = nullptr;
#else
void *libraryHandle = nullptr;
#endif

// C API session handles are owning handles. Releasing a handle for a running
// session requests cancellation, so React Native must retain the handle created
// for each session until execution has actually completed.
std::mutex sessionHandlesMutex;
std::unordered_map<std::int64_t, Handle> retainedSessionHandles;
std::vector<std::int64_t> knownSessionIds;

void ensureLibraryLoaded() {
  if (libraryHandle != nullptr) {
    return;
  }

#if defined(__APPLE__)
  // iOS/macOS normally links the framework into the process. RTLD_DEFAULT is
  // sufficient for dlsym; these fallbacks also support a dynamically embedded
  // framework on macOS.
  libraryHandle =
      dlopen("@rpath/ffmpegkit.framework/ffmpegkit", RTLD_NOW | RTLD_LOCAL);
  if (libraryHandle == nullptr) {
    libraryHandle =
        dlopen("ffmpegkit.framework/ffmpegkit", RTLD_NOW | RTLD_LOCAL);
  }
  if (libraryHandle == nullptr) {
    libraryHandle = dlopen(
        "@rpath/ffmpegkit.framework/Versions/A/ffmpegkit",
        RTLD_NOW | RTLD_LOCAL);
  }
  if (libraryHandle == nullptr) {
    libraryHandle = dlopen(
        "ffmpegkit.framework/Versions/A/ffmpegkit", RTLD_NOW | RTLD_LOCAL);
  }
  if (libraryHandle == nullptr) {
    libraryHandle = dlopen("libffmpegkit.dylib", RTLD_NOW | RTLD_LOCAL);
  }
#elif defined(__ANDROID__)
  libraryHandle = dlopen("libffmpegkit.so", RTLD_NOW | RTLD_LOCAL);
#elif defined(_WIN32)
  libraryHandle = GetModuleHandleA("libffmpegkit.dll");
  if (libraryHandle == nullptr) {
    libraryHandle = GetModuleHandleA("ffmpegkit.dll");
  }
  if (libraryHandle == nullptr) {
    libraryHandle = LoadLibraryA("libffmpegkit.dll");
  }
  if (libraryHandle == nullptr) {
    libraryHandle = LoadLibraryA("ffmpegkit.dll");
  }
#else
  libraryHandle = dlopen("libffmpegkit.so", RTLD_NOW | RTLD_LOCAL);
#endif
}

#if defined(_WIN32)
using RawSymbol = FARPROC;
#else
using RawSymbol = void *;
#endif

RawSymbol resolveRaw(const char *name) {
  ensureLibraryLoaded();
#if defined(_WIN32)
  if (libraryHandle == nullptr) {
    throw std::runtime_error(
        "libffmpegkit.dll could not be loaded. Ensure the FFmpegKit Extended "
        "Windows runtime DLLs are next to the application executable.");
  }

  auto symbol = GetProcAddress(libraryHandle, name);
  if (symbol == nullptr) {
    throw std::runtime_error(std::string("libffmpegkit symbol not found: ") + name +
                             " (GetLastError=" +
                             std::to_string(static_cast<unsigned long>(GetLastError())) +
                             ")");
  }
  return symbol;
#else
  void *symbol = nullptr;
#if defined(__APPLE__)
  symbol = dlsym(RTLD_DEFAULT, name);
#endif
  if (symbol == nullptr && libraryHandle != nullptr) {
    symbol = dlsym(libraryHandle, name);
  }
  if (symbol == nullptr) {
    const char *error = dlerror();
    throw std::runtime_error(std::string("libffmpegkit symbol not found: ") +
                             name + (error ? std::string(" (") + error + ")" : ""));
  }
  return symbol;
#endif
}

template <typename Fn> Fn resolve(const char *name) {
  return reinterpret_cast<Fn>(resolveRaw(name));
}

void ensureInitialized() {
  std::call_once(initFlag, [] {
    using Fn = void (*)();
    resolve<Fn>("ffmpeg_kit_initialize")();
  });
}

void release(Handle handle) {
  if (handle == nullptr) return;
  using Fn = void (*)(Handle);
  resolve<Fn>("ffmpeg_kit_handle_release")(handle);
}

void freeNative(void *ptr) {
  if (ptr == nullptr) return;
  using Fn = void (*)(void *);
  resolve<Fn>("ffmpeg_kit_free")(ptr);
}

std::string takeString(char *value) {
  if (value == nullptr) return {};
  std::string result(value);
  freeNative(value);
  return result;
}

std::string jsonEscape(const std::string &value) {
  std::ostringstream out;
  for (unsigned char c : value) {
    switch (c) {
      case '"': out << "\\\""; break;
      case '\\': out << "\\\\"; break;
      case '\b': out << "\\b"; break;
      case '\f': out << "\\f"; break;
      case '\n': out << "\\n"; break;
      case '\r': out << "\\r"; break;
      case '\t': out << "\\t"; break;
      default:
        if (c < 0x20) {
          out << "\\u" << std::hex << std::setw(4) << std::setfill('0')
              << static_cast<int>(c) << std::dec;
        } else {
          out << static_cast<char>(c);
        }
    }
  }
  return out.str();
}

std::string quote(const std::string &value) {
  return "\"" + jsonEscape(value) + "\"";
}

std::int64_t toId(double sessionId) {
  return static_cast<std::int64_t>(sessionId);
}

Handle getSession(std::int64_t id) {
  using Fn = Handle (*)(std::int64_t);
  return resolve<Fn>("ffmpeg_kit_get_session")(id);
}

struct HandleGuard {
  Handle handle = nullptr;
  bool owned = true;

  HandleGuard() = default;
  explicit HandleGuard(Handle value, bool owns = true) : handle(value), owned(owns) {}
  HandleGuard(const HandleGuard &) = delete;
  HandleGuard &operator=(const HandleGuard &) = delete;
  HandleGuard(HandleGuard &&other) noexcept
      : handle(other.handle), owned(other.owned) {
    other.handle = nullptr;
    other.owned = false;
  }
  HandleGuard &operator=(HandleGuard &&other) noexcept {
    if (this != &other) {
      if (owned) release(handle);
      handle = other.handle;
      owned = other.owned;
      other.handle = nullptr;
      other.owned = false;
    }
    return *this;
  }
  ~HandleGuard() {
    if (owned) release(handle);
  }
};

std::int64_t sessionIdOf(Handle handle) {
  using Fn = std::int64_t (*)(Handle);
  return resolve<Fn>("ffmpeg_kit_session_get_session_id")(handle);
}

HandleGuard acquireSession(std::int64_t id) {
  {
    std::lock_guard<std::mutex> lock(sessionHandlesMutex);
    const auto it = retainedSessionHandles.find(id);
    if (it != retainedSessionHandles.end()) {
      // Borrow the retained handle. Releasing it while Running would cancel
      // the underlying native session.
      return HandleGuard(it->second, false);
    }
  }
  return HandleGuard(getSession(id), true);
}

HandleGuard ensureRetainedSession(std::int64_t id) {
  std::lock_guard<std::mutex> lock(sessionHandlesMutex);
  const auto existing = retainedSessionHandles.find(id);
  if (existing != retainedSessionHandles.end()) {
    return HandleGuard(existing->second, false);
  }

  Handle handle = getSession(id);
  if (handle == nullptr) {
    return HandleGuard(nullptr, false);
  }
  retainedSessionHandles.emplace(id, handle);
  if (std::find(knownSessionIds.begin(), knownSessionIds.end(), id) ==
      knownSessionIds.end()) {
    knownSessionIds.push_back(id);
  }
  return HandleGuard(handle, false);
}

void recordKnownSessionId(std::int64_t id) {
  std::lock_guard<std::mutex> lock(sessionHandlesMutex);
  if (std::find(knownSessionIds.begin(), knownSessionIds.end(), id) ==
      knownSessionIds.end()) {
    knownSessionIds.push_back(id);
  }
}

void releaseRetainedSession(std::int64_t id) {
  Handle handle = nullptr;
  {
    std::lock_guard<std::mutex> lock(sessionHandlesMutex);
    const auto it = retainedSessionHandles.find(id);
    if (it == retainedSessionHandles.end()) return;
    handle = it->second;
    retainedSessionHandles.erase(it);
  }
  // Called by the JS monitor only after a terminal session state has been
  // observed and final logs/statistics have been drained.
  release(handle);
}

std::vector<std::int64_t> sessionIdsSnapshot() {
  std::lock_guard<std::mutex> lock(sessionHandlesMutex);
  return knownSessionIds;
}

std::string sessionType(Handle handle) {
  using Pred = bool (*)(Handle);
  if (resolve<Pred>("session_is_media_information_session")(handle)) return "media-information";
  if (resolve<Pred>("session_is_ffmpeg_session")(handle)) return "ffmpeg";
  if (resolve<Pred>("session_is_ffprobe_session")(handle)) return "ffprobe";
  if (resolve<Pred>("session_is_ffplay_session")(handle)) return "ffplay";
  return "ffmpeg";
}

std::string sessionJson(Handle handle) {
  if (handle == nullptr) return {};
  using GetI64 = std::int64_t (*)(Handle);
  using GetInt = int (*)(Handle);
  using GetString = char *(*)(Handle);
  using GetBool = bool (*)(Handle);

  const auto id = resolve<GetI64>("ffmpeg_kit_session_get_session_id")(handle);
  const auto state = resolve<GetInt>("ffmpeg_kit_session_get_state")(handle);
  const auto returnCode = resolve<GetI64>("ffmpeg_kit_session_get_return_code")(handle);
  const auto createTime = resolve<GetI64>("ffmpeg_kit_session_get_create_time")(handle);
  const auto startTime = resolve<GetI64>("ffmpeg_kit_session_get_start_time")(handle);
  const auto endTime = resolve<GetI64>("ffmpeg_kit_session_get_end_time")(handle);
  const auto duration = resolve<GetI64>("ffmpeg_kit_session_get_duration")(handle);
  const auto logsCount = resolve<GetI64>("ffmpeg_kit_session_get_logs_count")(handle);
  const auto statisticsCount = resolve<GetI64>("ffmpeg_kit_session_get_statistics_count")(handle);
  const auto command = takeString(resolve<GetString>("ffmpeg_kit_session_get_command")(handle));
  const auto output = takeString(resolve<GetString>("ffmpeg_kit_session_get_output")(handle));
  const auto logs = takeString(resolve<GetString>("ffmpeg_kit_session_get_logs_as_string")(handle));
  const auto failStack = takeString(resolve<GetString>("ffmpeg_kit_session_get_fail_stack_trace")(handle));
  const auto debugEnabled = resolve<GetBool>("session_is_debug_log_enabled")(handle);

  std::ostringstream out;
  out << '{'
      << "\"sessionId\":" << id << ','
      << "\"type\":" << quote(sessionType(handle)) << ','
      << "\"state\":" << state << ','
      << "\"returnCode\":" << returnCode << ','
      << "\"createTime\":" << createTime << ','
      << "\"startTime\":" << startTime << ','
      << "\"endTime\":" << endTime << ','
      << "\"duration\":" << duration << ','
      << "\"command\":" << quote(command) << ','
      << "\"output\":" << quote(output) << ','
      << "\"logs\":" << quote(logs) << ','
      << "\"failStackTrace\":" << quote(failStack) << ','
      << "\"logsCount\":" << logsCount << ','
      << "\"statisticsCount\":" << statisticsCount << ','
      << "\"debugLogEnabled\":" << (debugEnabled ? "true" : "false")
      << '}';
  return out.str();
}

std::string stringCall(const char *symbol) {
  using Fn = char *(*)();
  return takeString(resolve<Fn>(symbol)());
}

HandleGuard getFFplaySession(std::int64_t id) {
  HandleGuard guard = acquireSession(id);
  if (guard.handle == nullptr) throw std::runtime_error("FFplay session not found");
  using Pred = bool (*)(Handle);
  if (!resolve<Pred>("session_is_ffplay_session")(guard.handle)) {
    throw std::runtime_error("Session is not an FFplay session");
  }
  return guard;
}

std::string serializeStream(Handle stream) {
  auto str = [stream](const char *name) {
    using Fn = char *(*)(Handle);
    return takeString(resolve<Fn>(name)(stream));
  };
  auto num = [stream](const char *name) {
    using Fn = std::int64_t (*)(Handle);
    return resolve<Fn>(name)(stream);
  };

  std::ostringstream out;
  out << '{'
      << "\"index\":" << num("stream_information_get_index") << ','
      << "\"type\":" << quote(str("stream_information_get_type")) << ','
      << "\"codec\":" << quote(str("stream_information_get_codec")) << ','
      << "\"codecLong\":" << quote(str("stream_information_get_codec_long")) << ','
      << "\"format\":" << quote(str("stream_information_get_format")) << ','
      << "\"width\":" << num("stream_information_get_width") << ','
      << "\"height\":" << num("stream_information_get_height") << ','
      << "\"bitrate\":" << quote(str("stream_information_get_bitrate")) << ','
      << "\"sampleRate\":" << quote(str("stream_information_get_sample_rate")) << ','
      << "\"sampleFormat\":" << quote(str("stream_information_get_sample_format")) << ','
      << "\"channelLayout\":" << quote(str("stream_information_get_channel_layout")) << ','
      << "\"sampleAspectRatio\":" << quote(str("stream_information_get_sample_aspect_ratio")) << ','
      << "\"displayAspectRatio\":" << quote(str("stream_information_get_display_aspect_ratio")) << ','
      << "\"averageFrameRate\":" << quote(str("stream_information_get_average_frame_rate")) << ','
      << "\"realFrameRate\":" << quote(str("stream_information_get_real_frame_rate")) << ','
      << "\"timeBase\":" << quote(str("stream_information_get_time_base")) << ','
      << "\"codecTimeBase\":" << quote(str("stream_information_get_codec_time_base")) << ','
      << "\"tagsJson\":" << quote(str("stream_information_get_tags_json")) << ','
      << "\"allPropertiesJson\":" << quote(str("stream_information_get_all_properties_json"))
      << '}';
  return out.str();
}

std::string serializeChapter(Handle chapter) {
  auto str = [chapter](const char *name) {
    using Fn = char *(*)(Handle);
    return takeString(resolve<Fn>(name)(chapter));
  };
  auto num = [chapter](const char *name) {
    using Fn = std::int64_t (*)(Handle);
    return resolve<Fn>(name)(chapter);
  };

  std::ostringstream out;
  out << '{'
      << "\"id\":" << num("chapter_get_id") << ','
      << "\"timeBase\":" << quote(str("chapter_get_time_base")) << ','
      << "\"start\":" << num("chapter_get_start") << ','
      << "\"startTime\":" << quote(str("chapter_get_start_time")) << ','
      << "\"end\":" << num("chapter_get_end") << ','
      << "\"endTime\":" << quote(str("chapter_get_end_time")) << ','
      << "\"tagsJson\":" << quote(str("chapter_get_tags_json")) << ','
      << "\"allPropertiesJson\":" << quote(str("chapter_get_all_properties_json"))
      << '}';
  return out.str();
}

} // namespace

void initialize() { ensureInitialized(); }

std::string getBuildStamp() {
  ensureInitialized();
  using Fn = const char *(*)();
  const char *value = resolve<Fn>("ffmpeg_kit_get_build_stamp")();
  return value ? value : "";
}

static double createSessionWith(const char *symbol, const std::string &command) {
  ensureInitialized();
  using Fn = Handle (*)(const char *);
  HandleGuard guard(resolve<Fn>(symbol)(command.c_str()));
  if (guard.handle == nullptr) throw std::runtime_error("Failed to create FFmpegKit session");
  const auto id = sessionIdOf(guard.handle);
  recordKnownSessionId(id);
  // The session is still in Created state, so releasing this temporary handle is
  // safe. executeSessionAsync() obtains and retains a fresh owning handle before
  // starting the native worker.
  return static_cast<double>(id);
}

double createFFmpegSession(const std::string &command) { return createSessionWith("ffmpeg_kit_create_session", command); }
double createFFprobeSession(const std::string &command) { return createSessionWith("ffprobe_kit_create_session", command); }
double createFFplaySession(const std::string &command) { return createSessionWith("ffplay_kit_create_session", command); }
double createMediaInformationSession(const std::string &command) { return createSessionWith("media_information_create_session", command); }

void executeSessionAsync(double sessionId, double timeoutMs) {
  ensureInitialized();
  HandleGuard guard = ensureRetainedSession(toId(sessionId));
  if (guard.handle == nullptr) throw std::runtime_error("Session not found");
  const std::string type = sessionType(guard.handle);
  if (type == "ffmpeg") {
    using Fn = void (*)(Handle);
    resolve<Fn>("ffmpeg_kit_session_execute_async")(guard.handle);
  } else if (type == "ffprobe") {
    using Fn = void (*)(Handle);
    resolve<Fn>("ffprobe_kit_session_execute_async")(guard.handle);
  } else if (type == "ffplay") {
    using Fn = void (*)(Handle, std::int64_t);
    resolve<Fn>("ffplay_kit_session_execute_async")(guard.handle, static_cast<std::int64_t>(timeoutMs));
  } else {
    using Fn = void (*)(Handle, std::int64_t);
    resolve<Fn>("media_information_session_execute_async")(guard.handle, static_cast<std::int64_t>(timeoutMs));
  }
}

void cancelSession(double sessionId) {
  ensureInitialized();
  using Fn = void (*)(std::int64_t);
  resolve<Fn>("ffmpeg_kit_cancel_session")(toId(sessionId));
}

std::string getSessionJson(double sessionId) {
  ensureInitialized();
  HandleGuard guard = acquireSession(toId(sessionId));
  return sessionJson(guard.handle);
}

void releaseSessionHandle(double sessionId) {
  ensureInitialized();
  releaseRetainedSession(toId(sessionId));
}

std::string getSessionsJson(const std::string &kind) {
  ensureInitialized();
  const auto ids = sessionIdsSnapshot();
  std::ostringstream out;
  out << '[';
  bool first = true;
  for (const auto id : ids) {
    HandleGuard guard = acquireSession(id);
    if (guard.handle == nullptr) continue;
    if (!kind.empty() && kind != "all" && sessionType(guard.handle) != kind) continue;
    if (!first) out << ',';
    first = false;
    out << sessionJson(guard.handle);
  }
  out << ']';
  return out.str();
}

std::string getLastSessionJson(const std::string &kind) {
  ensureInitialized();
  const auto ids = sessionIdsSnapshot();
  for (auto it = ids.rbegin(); it != ids.rend(); ++it) {
    HandleGuard guard = acquireSession(*it);
    if (guard.handle == nullptr) continue;
    if (!kind.empty() && kind != "all" && sessionType(guard.handle) != kind) continue;
    return sessionJson(guard.handle);
  }
  return {};
}

std::string getLogsJson(double sessionId, double fromIndex) {
  ensureInitialized();
  HandleGuard guard = acquireSession(toId(sessionId));
  if (guard.handle == nullptr) return "[]";
  using CountFn = std::int64_t (*)(Handle);
  using LogFn = char *(*)(Handle, std::int64_t);
  using LevelFn = std::int64_t (*)(Handle, std::int64_t);
  const auto count = resolve<CountFn>("ffmpeg_kit_session_get_logs_count")(guard.handle);
  const auto start = std::max<std::int64_t>(0, static_cast<std::int64_t>(fromIndex));
  std::ostringstream out;
  out << '[';
  bool first = true;
  for (auto i = start; i < count; ++i) {
    if (!first) out << ',';
    first = false;
    const auto message = takeString(resolve<LogFn>("ffmpeg_kit_session_get_log_at")(guard.handle, i));
    const auto level = resolve<LevelFn>("ffmpeg_kit_session_get_log_level_at")(guard.handle, i);
    out << "{\"sessionId\":" << toId(sessionId)
        << ",\"level\":" << level
        << ",\"message\":" << quote(message) << '}';
  }
  out << ']';
  return out.str();
}

std::string getStatisticsJson(double sessionId, double fromIndex) {
  ensureInitialized();
  HandleGuard guard = acquireSession(toId(sessionId));
  if (guard.handle == nullptr || sessionType(guard.handle) != "ffmpeg") return "[]";
  using CountFn = std::int64_t (*)(Handle);
  using AtFn = Handle (*)(Handle, std::int64_t);
  using I64Fn = std::int64_t (*)(Handle);
  using DoubleFn = double (*)(Handle);
  const auto count = resolve<CountFn>("ffmpeg_kit_session_get_statistics_count")(guard.handle);
  const auto start = std::max<std::int64_t>(0, static_cast<std::int64_t>(fromIndex));
  std::ostringstream out;
  out << '[';
  bool first = true;
  for (auto i = start; i < count; ++i) {
    HandleGuard stats{resolve<AtFn>("ffmpeg_kit_session_get_statistics_at")(guard.handle, i)};
    if (stats.handle == nullptr) continue;
    if (!first) out << ',';
    first = false;
    out << "{\"sessionId\":" << toId(sessionId)
        << ",\"videoFrameNumber\":" << resolve<I64Fn>("ffmpeg_kit_statistics_get_video_frame_number")(stats.handle)
        << ",\"videoFps\":" << resolve<DoubleFn>("ffmpeg_kit_statistics_get_video_fps")(stats.handle)
        << ",\"videoQuality\":" << resolve<DoubleFn>("ffmpeg_kit_statistics_get_video_quality")(stats.handle)
        << ",\"size\":" << resolve<I64Fn>("ffmpeg_kit_statistics_get_size")(stats.handle)
        << ",\"time\":" << resolve<DoubleFn>("ffmpeg_kit_statistics_get_time")(stats.handle)
        << ",\"timeElapsed\":" << resolve<DoubleFn>("ffmpeg_kit_statistics_get_time_elapsed")(stats.handle)
        << ",\"bitrate\":" << resolve<DoubleFn>("ffmpeg_kit_statistics_get_bitrate")(stats.handle)
        << ",\"speed\":" << resolve<DoubleFn>("ffmpeg_kit_statistics_get_speed")(stats.handle)
        << ",\"dupFrames\":" << resolve<I64Fn>("ffmpeg_kit_statistics_get_dup_frames")(stats.handle)
        << ",\"dropFrames\":" << resolve<I64Fn>("ffmpeg_kit_statistics_get_drop_frames")(stats.handle)
        << '}';
  }
  out << ']';
  return out.str();
}

std::string getMediaInformationJson(double sessionId) {
  ensureInitialized();
  HandleGuard session = acquireSession(toId(sessionId));
  if (session.handle == nullptr || sessionType(session.handle) != "media-information") return {};
  using InfoFn = Handle (*)(Handle);
  HandleGuard info{resolve<InfoFn>("media_information_session_get_media_information")(session.handle)};
  if (info.handle == nullptr) return {};

  auto str = [h = info.handle](const char *name) {
    using Fn = char *(*)(Handle);
    return takeString(resolve<Fn>(name)(h));
  };
  using CountFn = std::int64_t (*)(Handle);
  using AtFn = Handle (*)(Handle, std::int64_t);
  const auto streamCount = resolve<CountFn>("media_information_get_streams_count")(info.handle);
  const auto chapterCount = resolve<CountFn>("media_information_get_chapters_count")(info.handle);

  std::ostringstream out;
  out << '{'
      << "\"filename\":" << quote(str("media_information_get_filename")) << ','
      << "\"format\":" << quote(str("media_information_get_format")) << ','
      << "\"longFormat\":" << quote(str("media_information_get_long_format")) << ','
      << "\"duration\":" << quote(str("media_information_get_duration")) << ','
      << "\"startTime\":" << quote(str("media_information_get_start_time")) << ','
      << "\"bitrate\":" << quote(str("media_information_get_bitrate")) << ','
      << "\"size\":" << quote(str("media_information_get_size")) << ','
      << "\"tagsJson\":" << quote(str("media_information_get_tags_json")) << ','
      << "\"allPropertiesJson\":" << quote(str("media_information_get_all_properties_json")) << ','
      << "\"streams\":[";
  for (std::int64_t i = 0; i < streamCount; ++i) {
    if (i) out << ',';
    HandleGuard stream{resolve<AtFn>("media_information_get_stream_at")(info.handle, i)};
    out << (stream.handle ? serializeStream(stream.handle) : "{}");
  }
  out << "],\"chapters\":[";
  for (std::int64_t i = 0; i < chapterCount; ++i) {
    if (i) out << ',';
    HandleGuard chapter{resolve<AtFn>("media_information_get_chapter_at")(info.handle, i)};
    out << (chapter.handle ? serializeChapter(chapter.handle) : "{}");
  }
  out << "]}";
  return out.str();
}

#define WITH_FFPLAY_VOID(name, symbol) \
  void name(double sessionId) { \
    ensureInitialized(); HandleGuard h = getFFplaySession(toId(sessionId)); \
    using Fn = void (*)(Handle); resolve<Fn>(symbol)(h.handle); \
  }
WITH_FFPLAY_VOID(ffplayStart, "ffplay_kit_session_start")
WITH_FFPLAY_VOID(ffplayPause, "ffplay_kit_session_pause")
WITH_FFPLAY_VOID(ffplayResume, "ffplay_kit_session_resume")
WITH_FFPLAY_VOID(ffplayStop, "ffplay_kit_session_stop")
#undef WITH_FFPLAY_VOID

void ffplaySeek(double sessionId, double seconds) { ensureInitialized(); HandleGuard h = getFFplaySession(toId(sessionId)); using Fn = void (*)(Handle,double); resolve<Fn>("ffplay_kit_session_seek")(h.handle,seconds); }
double ffplayGetPosition(double sessionId) { ensureInitialized(); HandleGuard h = getFFplaySession(toId(sessionId)); using Fn = double (*)(Handle); return resolve<Fn>("ffplay_kit_session_get_position")(h.handle); }
void ffplaySetPosition(double sessionId, double seconds) { ensureInitialized(); HandleGuard h = getFFplaySession(toId(sessionId)); using Fn = void (*)(Handle,double); resolve<Fn>("ffplay_kit_session_set_position")(h.handle,seconds); }
double ffplayGetDuration(double sessionId) { ensureInitialized(); HandleGuard h = getFFplaySession(toId(sessionId)); using Fn = double (*)(Handle); return resolve<Fn>("ffplay_kit_session_get_duration")(h.handle); }
std::int32_t ffplayGetVideoWidth(double sessionId) { ensureInitialized(); HandleGuard h = getFFplaySession(toId(sessionId)); using Fn = int (*)(Handle); return resolve<Fn>("ffplay_kit_session_get_video_width")(h.handle); }
std::int32_t ffplayGetVideoHeight(double sessionId) { ensureInitialized(); HandleGuard h = getFFplaySession(toId(sessionId)); using Fn = int (*)(Handle); return resolve<Fn>("ffplay_kit_session_get_video_height")(h.handle); }
bool ffplayIsPlaying(double sessionId) { ensureInitialized(); HandleGuard h = getFFplaySession(toId(sessionId)); using Fn = bool (*)(Handle); return resolve<Fn>("ffplay_kit_session_is_playing")(h.handle); }
bool ffplayIsPaused(double sessionId) { ensureInitialized(); HandleGuard h = getFFplaySession(toId(sessionId)); using Fn = bool (*)(Handle); return resolve<Fn>("ffplay_kit_session_is_paused")(h.handle); }
void ffplaySetVolume(double sessionId, double volume) { ensureInitialized(); HandleGuard h = getFFplaySession(toId(sessionId)); using Fn = void (*)(Handle,double); resolve<Fn>("ffplay_kit_session_set_volume")(h.handle,volume); }
double ffplayGetVolume(double sessionId) { ensureInitialized(); HandleGuard h = getFFplaySession(toId(sessionId)); using Fn = double (*)(Handle); return resolve<Fn>("ffplay_kit_session_get_volume")(h.handle); }
bool ffplayHasVideoStream(const std::string &path) { ensureInitialized(); using Fn = int (*)(const char*); return resolve<Fn>("ffplay_kit_has_video_stream")(path.c_str()) != 0; }

void enableRedirection() { ensureInitialized(); using Fn = void (*)(); resolve<Fn>("ffmpeg_kit_config_enable_redirection")(); }
void disableRedirection() { ensureInitialized(); using Fn = void (*)(); resolve<Fn>("ffmpeg_kit_config_disable_redirection")(); }
void setLogLevel(std::int32_t level) { ensureInitialized(); using Fn = void (*)(int); resolve<Fn>("ffmpeg_kit_config_set_log_level")(level); }
std::int32_t getLogLevel() { ensureInitialized(); using Fn = int (*)(); return resolve<Fn>("ffmpeg_kit_config_get_log_level")(); }
std::string logLevelToString(std::int32_t level) { ensureInitialized(); using Fn = char *(*)(int); return takeString(resolve<Fn>("ffmpeg_kit_config_log_level_to_string")(level)); }
void setFontDirectory(const std::string &path, const std::string &mappingJson) { ensureInitialized(); using Fn = void (*)(const char*,const char*); resolve<Fn>("ffmpeg_kit_config_set_font_directory")(path.c_str(), mappingJson.empty() ? nullptr : mappingJson.c_str()); }
void setEnvironmentVariable(const std::string &name, const std::string &value) { ensureInitialized(); using Fn = std::int64_t (*)(const char*,const char*); (void)resolve<Fn>("ffmpeg_kit_config_set_environment_variable")(name.c_str(),value.c_str()); }
void ignoreSignal(std::int32_t signal) { ensureInitialized(); using Fn = void (*)(int); resolve<Fn>("ffmpeg_kit_config_ignore_signal")(signal); }
void setAudioOutputDevice(const std::string &deviceName) { ensureInitialized(); using Fn = void (*)(const char*); resolve<Fn>("ffmpeg_kit_config_set_audio_output_device")(deviceName.c_str()); }
std::string listAudioOutputDevices() { ensureInitialized(); return stringCall("ffmpeg_kit_config_list_audio_output_devices"); }

std::string getFFmpegVersion() { ensureInitialized(); return stringCall("ffmpeg_kit_config_get_ffmpeg_version"); }
std::string getFFmpegArchitecture() { ensureInitialized(); return stringCall("ffmpeg_kit_config_get_ffmpeg_architecture"); }
std::string getVersion() { ensureInitialized(); return stringCall("ffmpeg_kit_config_get_version"); }
std::string getPackageName() { ensureInitialized(); return stringCall("ffmpeg_kit_packages_get_package_name"); }
std::string getExternalLibraries() { ensureInitialized(); return stringCall("ffmpeg_kit_packages_get_external_libraries"); }
std::string getBundleType() { ensureInitialized(); return stringCall("ffmpeg_kit_packages_get_bundle_type"); }
bool isGpl() { ensureInitialized(); using Fn = bool (*)(); return resolve<Fn>("ffmpeg_kit_packages_get_is_gpl")(); }
bool isNonfree() { ensureInitialized(); using Fn = bool (*)(); return resolve<Fn>("ffmpeg_kit_packages_get_is_nonfree")(); }
std::string getRegisteredCodecs() { ensureInitialized(); return stringCall("ffmpeg_kit_packages_get_registered_codecs"); }
std::string getRegisteredEncoders() { ensureInitialized(); return stringCall("ffmpeg_kit_packages_get_registered_encoders"); }
std::string getRegisteredDecoders() { ensureInitialized(); return stringCall("ffmpeg_kit_packages_get_registered_decoders"); }
std::string getRegisteredMuxers() { ensureInitialized(); return stringCall("ffmpeg_kit_packages_get_registered_muxers"); }
std::string getRegisteredDemuxers() { ensureInitialized(); return stringCall("ffmpeg_kit_packages_get_registered_demuxers"); }
std::string getRegisteredFilters() { ensureInitialized(); return stringCall("ffmpeg_kit_packages_get_registered_filters"); }
std::string getRegisteredProtocols() { ensureInitialized(); return stringCall("ffmpeg_kit_packages_get_registered_protocols"); }
std::string getRegisteredBitstreamFilters() { ensureInitialized(); return stringCall("ffmpeg_kit_packages_get_registered_bitstream_filters"); }
std::string getBuildConfiguration() { ensureInitialized(); return stringCall("ffmpeg_kit_packages_get_build_configuration"); }
std::string getBuildDate() { ensureInitialized(); return stringCall("ffmpeg_kit_config_get_build_date"); }

void setSessionHistorySize(double size) { ensureInitialized(); using Fn = void (*)(std::int64_t); resolve<Fn>("ffmpeg_kit_set_session_history_size")(static_cast<std::int64_t>(size)); }
double getSessionHistorySize() { ensureInitialized(); using Fn = std::int64_t (*)(); return static_cast<double>(resolve<Fn>("ffmpeg_kit_get_session_history_size")()); }
void clearSessions() {
  ensureInitialized();
  using Fn = void (*)();
  resolve<Fn>("ffmpeg_kit_clear_sessions")();
  // The core clear operation removes all wrapper handles from its registry and
  // cancels/drains active sessions. The raw keys retained here are therefore no
  // longer releasable and can simply be forgotten.
  std::lock_guard<std::mutex> lock(sessionHandlesMutex);
  retainedSessionHandles.clear();
  knownSessionIds.clear();
}
std::string registerNewFFmpegPipe() { ensureInitialized(); return stringCall("ffmpeg_kit_config_register_new_ffmpeg_pipe"); }
void closeFFmpegPipe(const std::string &path) { ensureInitialized(); using Fn = void (*)(const char*); resolve<Fn>("ffmpeg_kit_config_close_ffmpeg_pipe")(path.c_str()); }
double messagesInTransmit(double sessionId) { ensureInitialized(); using Fn = std::int64_t (*)(std::int64_t); return static_cast<double>(resolve<Fn>("ffmpeg_kit_config_messages_in_transmit")(toId(sessionId))); }

void enableDebugLog(double sessionId) { ensureInitialized(); HandleGuard h = acquireSession(toId(sessionId)); if (!h.handle) throw std::runtime_error("Session not found"); using Fn = void (*)(Handle); resolve<Fn>("session_enable_debug_log")(h.handle); }
void disableDebugLog(double sessionId) { ensureInitialized(); HandleGuard h = acquireSession(toId(sessionId)); if (!h.handle) throw std::runtime_error("Session not found"); using Fn = void (*)(Handle); resolve<Fn>("session_disable_debug_log")(h.handle); }
bool isDebugLogEnabled(double sessionId) { ensureInitialized(); HandleGuard h = acquireSession(toId(sessionId)); if (!h.handle) return false; using Fn = bool (*)(Handle); return resolve<Fn>("session_is_debug_log_enabled")(h.handle); }
std::string getDebugLog(double sessionId) { ensureInitialized(); HandleGuard h = acquireSession(toId(sessionId)); if (!h.handle) return {}; using Fn = char *(*)(Handle); return takeString(resolve<Fn>("session_get_debug_log")(h.handle)); }
void clearDebugLog(double sessionId) { ensureInitialized(); HandleGuard h = acquireSession(toId(sessionId)); if (!h.handle) return; using Fn = void (*)(Handle); resolve<Fn>("session_clear_debug_log")(h.handle); }

} // namespace ffmpegkit::bridge
