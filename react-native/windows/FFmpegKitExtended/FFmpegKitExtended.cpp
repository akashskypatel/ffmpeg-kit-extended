/*
 * Windows bridge implementation for the TypeScript FFmpegKit API.
 *
 * All methods delegate to the shared native adapter. Errors are converted at
 * the native boundary according to the module's invoke helpers; end users
 * observe results through typed sessions, return codes, output, and callbacks.
 */

#include "pch.h"
#include "FFmpegKitExtended.h"

#include "FFmpegKitDynamicApi.h"
#include "../../cpp/LogBridgeRegistrationCoordinator.h"
#include "operational_error_transport.h"
#include "recoverable_native_dispatch.h"

#include <exception>
#include <mutex>
#include <vector>
#include <string>
#include <utility>

namespace winrt::FFmpegKitExtended {
using LogEvent = FFmpegKitExtendedCodegen::FFmpegKitExtendedSpec_LogEvent;
namespace api = ffmpegkit::bridge;

struct LogBridgeState {
  std::mutex mutex;
  std::function<void(LogEvent)> emit;
};

namespace {

std::mutex retiredLogBridgeStatesMutex;
std::vector<std::shared_ptr<LogBridgeState>> retiredLogBridgeStates;
ffmpegkit::bridge::LogBridgeRegistrationCoordinator logBridgeRegistrationCoordinator;

void retainLogBridgeState(std::shared_ptr<LogBridgeState> state) noexcept {
  if (!state) return;
  std::lock_guard<std::mutex> lock(retiredLogBridgeStatesMutex);
  retiredLogBridgeStates.push_back(std::move(state));
}

class OwnedLogMessage final {
 public:
  explicit OwnedLogMessage(char *value) noexcept : value_(value) {}
  OwnedLogMessage(const OwnedLogMessage &) = delete;
  OwnedLogMessage &operator=(const OwnedLogMessage &) = delete;

  ~OwnedLogMessage() noexcept { release(); }

  std::string copy() const { return value_ ? std::string(value_) : std::string{}; }

  void release() noexcept {
    char *value = value_;
    value_ = nullptr;
    if (!value) return;
    try {
      api::releaseOwnedLogMessage(value);
    } catch (...) {
      // The native callback must not throw across the frozen ABI boundary.
    }
  }

 private:
  char *value_;
};

void handleLogEvent(
    std::int64_t sessionId,
    std::int64_t sequence,
    std::int32_t level,
    char *ownedMessage,
    void *userData) noexcept {
  OwnedLogMessage owned{ownedMessage};
  std::string message;
  try {
    // Copy the native-owned payload before releasing it. The EventEmitter then
    // serializes the copied std::string asynchronously on the JS invoker.
    message = owned.copy();
  } catch (...) {
    return;
  }
  owned.release();

  auto *state = static_cast<LogBridgeState *>(userData);
  if (!state) return;

  std::function<void(LogEvent)> emit;
  try {
    std::lock_guard<std::mutex> lock(state->mutex);
    emit = state->emit;
  } catch (...) {
    return;
  }
  if (!emit) return;

  try {
    emit(LogEvent{
        static_cast<double>(sessionId),
        static_cast<double>(sequence),
        static_cast<int>(level),
        std::move(message),
    });
  } catch (...) {
    // JS callback failures are handled by the wrapper's first-error policy;
    // never propagate them back through the native callback ABI.
  }
}

} // namespace

namespace {
template <typename Fn>
void completeAction(const char *method, FFmpegKitExtended::Completion &&result,
                    Fn &&fn) noexcept {
  invokeWithCompletion(
      method, std::forward<Fn>(fn), [&result] { result.Resolve(); },
      [&result](const char *message) { result.Reject(message); });
}
} // namespace

FFmpegKitExtended::~FFmpegKitExtended() noexcept {
  auto state = std::move(activeLogBridge_);
  if (!state) return;

  try {
    logBridgeRegistrationCoordinator.uninstallIfOwned(
        state.get(), [&] { api::enableLogCallback(nullptr, nullptr); });
  } catch (...) {
    // Destruction cannot report an error. Retain the callback state even when
    // the runtime DLL is already unavailable so an in-flight callback cannot
    // observe freed user data.
  }
  {
    std::lock_guard<std::mutex> lock(state->mutex);
    state->emit = {};
  }
  retainLogBridgeState(std::move(state));
}

void FFmpegKitExtended::initialize(Completion &&result) noexcept {
  completeAction("initialize", std::move(result), [&] { api::initialize(); });
}

std::string FFmpegKitExtended::consumeSynchronousError() noexcept {
  return consumeSynchronousErrorValue();
}

std::string FFmpegKitExtended::getBuildStamp() noexcept {
  return invokeSynchronous<std::string>("getBuildStamp", [&] { return api::getBuildStamp(); });
}

double FFmpegKitExtended::createFFmpegSession(std::string command) noexcept {
  return invokeSynchronous<double>("createFFmpegSession", [&] { return api::createFFmpegSession(command); });
}

double FFmpegKitExtended::createFFmpegSessionFromArguments(std::vector<std::string> arguments) noexcept {
  return invokeSynchronous<double>("createFFmpegSessionFromArguments", [&] {
    return api::createFFmpegSessionFromArguments(arguments);
  });
}

double FFmpegKitExtended::createFFprobeSession(std::string command) noexcept {
  return invokeSynchronous<double>("createFFprobeSession", [&] { return api::createFFprobeSession(command); });
}

double FFmpegKitExtended::createFFplaySession(std::string command) noexcept {
  return invokeSynchronous<double>("createFFplaySession", [&] { return api::createFFplaySession(command); });
}

double FFmpegKitExtended::createFFplaySessionFromArguments(std::vector<std::string> arguments) noexcept {
  return invokeSynchronous<double>("createFFplaySessionFromArguments", [&] {
    return api::createFFplaySessionFromArguments(arguments);
  });
}

double FFmpegKitExtended::createMediaInformationSession(std::string command) noexcept {
  return invokeSynchronous<double>("createMediaInformationSession", [&] { return api::createMediaInformationSession(command); });
}

double FFmpegKitExtended::createMediaInformationSessionFromPath(std::string path) noexcept {
  return invokeSynchronous<double>("createMediaInformationSessionFromPath", [&] {
    return api::createMediaInformationSessionFromPath(path);
  });
}

void FFmpegKitExtended::executeSessionAsync(double sessionId, double timeoutMs,
                                             Completion &&result) noexcept {
  completeAction("executeSessionAsync", std::move(result),
                 [&] { api::executeSessionAsync(sessionId, timeoutMs); });
}

void FFmpegKitExtended::cancelSession(double sessionId, Completion &&result) noexcept {
  completeAction("cancelSession", std::move(result),
                 [&] { api::cancelSession(sessionId); });
}

void FFmpegKitExtended::installLogBridge(Completion &&result) noexcept {
  completeAction("installLogBridge", std::move(result), [&] {
    if (!activeLogBridge_) {
      activeLogBridge_ = std::make_shared<LogBridgeState>();
    }
    const auto state = activeLogBridge_;
    {
      std::lock_guard<std::mutex> lock(state->mutex);
      state->emit = onLogEvent;
    }
    try {
      logBridgeRegistrationCoordinator.install(
          state.get(), [&] { api::enableLogCallback(&handleLogEvent, state.get()); });
    } catch (...) {
      std::lock_guard<std::mutex> lock(state->mutex);
      state->emit = {};
      throw;
    }
  });
}

void FFmpegKitExtended::uninstallLogBridge(Completion &&result) noexcept {
  completeAction("uninstallLogBridge", std::move(result), [&] {
    const auto state = activeLogBridge_;
    if (!state) return;

    logBridgeRegistrationCoordinator.uninstallIfOwned(
        state.get(), [&] { api::enableLogCallback(nullptr, nullptr); });
    {
      std::lock_guard<std::mutex> lock(state->mutex);
      state->emit = {};
    }
  });
}

std::string FFmpegKitExtended::getSessionJson(double sessionId) noexcept {
  return invokeSynchronous<std::string>("getSessionJson", [&] { return api::getSessionJson(sessionId); });
}

std::int32_t FFmpegKitExtended::getSessionState(double sessionId) noexcept {
  return invokeSynchronous<std::int32_t>("getSessionState", [&] { return api::getSessionState(sessionId); });
}

double FFmpegKitExtended::getLogsCount(double sessionId) noexcept {
  return invokeSynchronous<double>("getLogsCount", [&] { return api::getLogsCount(sessionId); });
}

void FFmpegKitExtended::releaseSessionHandle(double sessionId,
                                               Completion &&result) noexcept {
  completeAction("releaseSessionHandle", std::move(result),
                 [&] { api::releaseSessionHandle(sessionId); });
}

void FFmpegKitExtended::abandonCreatedSession(double sessionId,
                                                Completion &&result) noexcept {
  completeAction("abandonCreatedSession", std::move(result),
                 [&] { api::abandonCreatedSession(sessionId); });
}

std::string FFmpegKitExtended::getSessionsJson(std::string kind) noexcept {
  return invokeSynchronous<std::string>("getSessionsJson", [&] { return api::getSessionsJson(kind); });
}

std::string FFmpegKitExtended::getLastSessionJson(std::string kind) noexcept {
  return invokeSynchronous<std::string>("getLastSessionJson", [&] { return api::getLastSessionJson(kind); });
}

std::string FFmpegKitExtended::getLogsJson(double sessionId, double fromIndex) noexcept {
  return invokeSynchronous<std::string>("getLogsJson", [&] { return api::getLogsJson(sessionId, fromIndex); });
}

std::string FFmpegKitExtended::getStatisticsJson(double sessionId, double fromIndex) noexcept {
  return invokeSynchronous<std::string>("getStatisticsJson", [&] { return api::getStatisticsJson(sessionId, fromIndex); });
}

std::string FFmpegKitExtended::getMediaInformationJson(double sessionId) noexcept {
  return invokeSynchronous<std::string>("getMediaInformationJson", [&] { return api::getMediaInformationJson(sessionId); });
}

void FFmpegKitExtended::ffplayStart(double sessionId, Completion &&result) noexcept {
  completeAction("ffplayStart", std::move(result),
                 [&] { api::ffplayStart(sessionId); });
}

void FFmpegKitExtended::ffplayPause(double sessionId, Completion &&result) noexcept {
  completeAction("ffplayPause", std::move(result),
                 [&] { api::ffplayPause(sessionId); });
}

void FFmpegKitExtended::ffplayResume(double sessionId, Completion &&result) noexcept {
  completeAction("ffplayResume", std::move(result),
                 [&] { api::ffplayResume(sessionId); });
}

void FFmpegKitExtended::ffplayStop(double sessionId, Completion &&result) noexcept {
  completeAction("ffplayStop", std::move(result),
                 [&] { api::ffplayStop(sessionId); });
}

void FFmpegKitExtended::ffplaySeek(double sessionId, double seconds,
                                   Completion &&result) noexcept {
  completeAction("ffplaySeek", std::move(result),
                 [&] { api::ffplaySeek(sessionId, seconds); });
}

double FFmpegKitExtended::ffplayGetPosition(double sessionId) noexcept {
  return invokeSynchronous<double>("ffplayGetPosition", [&] { return api::ffplayGetPosition(sessionId); });
}

void FFmpegKitExtended::ffplaySetPosition(double sessionId, double seconds,
                                           Completion &&result) noexcept {
  completeAction("ffplaySetPosition", std::move(result),
                 [&] { api::ffplaySetPosition(sessionId, seconds); });
}

double FFmpegKitExtended::ffplayGetDuration(double sessionId) noexcept {
  return invokeSynchronous<double>("ffplayGetDuration", [&] { return api::ffplayGetDuration(sessionId); });
}

std::int32_t FFmpegKitExtended::ffplayGetVideoWidth(double sessionId) noexcept {
  return invokeSynchronous<std::int32_t>("ffplayGetVideoWidth", [&] { return api::ffplayGetVideoWidth(sessionId); });
}

std::int32_t FFmpegKitExtended::ffplayGetVideoHeight(double sessionId) noexcept {
  return invokeSynchronous<std::int32_t>("ffplayGetVideoHeight", [&] { return api::ffplayGetVideoHeight(sessionId); });
}

bool FFmpegKitExtended::ffplayIsPlaying(double sessionId) noexcept {
  return invokeSynchronous<bool>("ffplayIsPlaying", [&] { return api::ffplayIsPlaying(sessionId); });
}

bool FFmpegKitExtended::ffplayIsPaused(double sessionId) noexcept {
  return invokeSynchronous<bool>("ffplayIsPaused", [&] { return api::ffplayIsPaused(sessionId); });
}

void FFmpegKitExtended::ffplaySetVolume(double sessionId, double volume,
                                         Completion &&result) noexcept {
  completeAction("ffplaySetVolume", std::move(result),
                 [&] { api::ffplaySetVolume(sessionId, volume); });
}

double FFmpegKitExtended::ffplayGetVolume(double sessionId) noexcept {
  return invokeSynchronous<double>("ffplayGetVolume", [&] { return api::ffplayGetVolume(sessionId); });
}

bool FFmpegKitExtended::ffplayHasVideoStream(std::string path) noexcept {
  return invokeSynchronous<bool>("ffplayHasVideoStream", [&] { return api::ffplayHasVideoStream(path); });
}

void FFmpegKitExtended::enableRedirection(Completion &&result) noexcept {
  completeAction("enableRedirection", std::move(result),
                 [&] { api::enableRedirection(); });
}

void FFmpegKitExtended::disableRedirection(Completion &&result) noexcept {
  completeAction("disableRedirection", std::move(result),
                 [&] { api::disableRedirection(); });
}

void FFmpegKitExtended::setLogLevel(std::int32_t level,
                                    Completion &&result) noexcept {
  completeAction("setLogLevel", std::move(result),
                 [&] { api::setLogLevel(level); });
}

std::int32_t FFmpegKitExtended::getLogLevel() noexcept {
  return invokeSynchronous<std::int32_t>("getLogLevel", [&] { return api::getLogLevel(); });
}

std::string FFmpegKitExtended::logLevelToString(std::int32_t level) noexcept {
  return invokeSynchronous<std::string>("logLevelToString", [&] { return api::logLevelToString(level); });
}

void FFmpegKitExtended::setFontDirectory(std::string path, std::string mappingJson,
                                         Completion &&result) noexcept {
  completeAction("setFontDirectory", std::move(result),
                 [&] { api::setFontDirectory(path, mappingJson); });
}

void FFmpegKitExtended::setEnvironmentVariable(std::string name, std::string value,
                                               Completion &&result) noexcept {
  completeAction("setEnvironmentVariable", std::move(result),
                 [&] { api::setEnvironmentVariable(name, value); });
}

void FFmpegKitExtended::ignoreSignal(std::int32_t signal,
                                     Completion &&result) noexcept {
  completeAction("ignoreSignal", std::move(result),
                 [&] { api::ignoreSignal(signal); });
}

void FFmpegKitExtended::setAudioOutputDevice(std::string deviceName,
                                              Completion &&result) noexcept {
  completeAction("setAudioOutputDevice", std::move(result),
                 [&] { api::setAudioOutputDevice(deviceName); });
}

std::string FFmpegKitExtended::listAudioOutputDevices() noexcept {
  return invokeSynchronous<std::string>("listAudioOutputDevices", [&] { return api::listAudioOutputDevices(); });
}

std::string FFmpegKitExtended::getFFmpegVersion() noexcept {
  return invokeSynchronous<std::string>("getFFmpegVersion", [&] { return api::getFFmpegVersion(); });
}

std::string FFmpegKitExtended::getFFmpegArchitecture() noexcept {
  return invokeSynchronous<std::string>("getFFmpegArchitecture", [&] { return api::getFFmpegArchitecture(); });
}

std::string FFmpegKitExtended::getVersion() noexcept {
  return invokeSynchronous<std::string>("getVersion", [&] { return api::getVersion(); });
}

std::string FFmpegKitExtended::getPackageName() noexcept {
  return invokeSynchronous<std::string>("getPackageName", [&] { return api::getPackageName(); });
}

std::string FFmpegKitExtended::getExternalLibraries() noexcept {
  return invokeSynchronous<std::string>("getExternalLibraries", [&] { return api::getExternalLibraries(); });
}

std::string FFmpegKitExtended::getBundleType() noexcept {
  return invokeSynchronous<std::string>("getBundleType", [&] { return api::getBundleType(); });
}

bool FFmpegKitExtended::isGpl() noexcept {
  return invokeSynchronous<bool>("isGpl", [&] { return api::isGpl(); });
}

bool FFmpegKitExtended::isNonfree() noexcept {
  return invokeSynchronous<bool>("isNonfree", [&] { return api::isNonfree(); });
}

std::string FFmpegKitExtended::getRegisteredCodecs() noexcept {
  return invokeSynchronous<std::string>("getRegisteredCodecs", [&] { return api::getRegisteredCodecs(); });
}

std::string FFmpegKitExtended::getRegisteredEncoders() noexcept {
  return invokeSynchronous<std::string>("getRegisteredEncoders", [&] { return api::getRegisteredEncoders(); });
}

std::string FFmpegKitExtended::getRegisteredDecoders() noexcept {
  return invokeSynchronous<std::string>("getRegisteredDecoders", [&] { return api::getRegisteredDecoders(); });
}

std::string FFmpegKitExtended::getRegisteredMuxers() noexcept {
  return invokeSynchronous<std::string>("getRegisteredMuxers", [&] { return api::getRegisteredMuxers(); });
}

std::string FFmpegKitExtended::getRegisteredDemuxers() noexcept {
  return invokeSynchronous<std::string>("getRegisteredDemuxers", [&] { return api::getRegisteredDemuxers(); });
}

std::string FFmpegKitExtended::getRegisteredFilters() noexcept {
  return invokeSynchronous<std::string>("getRegisteredFilters", [&] { return api::getRegisteredFilters(); });
}

std::string FFmpegKitExtended::getRegisteredProtocols() noexcept {
  return invokeSynchronous<std::string>("getRegisteredProtocols", [&] { return api::getRegisteredProtocols(); });
}

std::string FFmpegKitExtended::getRegisteredBitstreamFilters() noexcept {
  return invokeSynchronous<std::string>("getRegisteredBitstreamFilters", [&] { return api::getRegisteredBitstreamFilters(); });
}

std::string FFmpegKitExtended::getBuildConfiguration() noexcept {
  return invokeSynchronous<std::string>("getBuildConfiguration", [&] { return api::getBuildConfiguration(); });
}

std::string FFmpegKitExtended::getBuildDate() noexcept {
  return invokeSynchronous<std::string>("getBuildDate", [&] { return api::getBuildDate(); });
}

void FFmpegKitExtended::setSessionHistorySize(double size,
                                               Completion &&result) noexcept {
  completeAction("setSessionHistorySize", std::move(result),
                 [&] { api::setSessionHistorySize(size); });
}

double FFmpegKitExtended::getSessionHistorySize() noexcept {
  return invokeSynchronous<double>("getSessionHistorySize", [&] { return api::getSessionHistorySize(); });
}

void FFmpegKitExtended::clearSessions(Completion &&result) noexcept {
  completeAction("clearSessions", std::move(result), [&] { api::clearSessions(); });
}

std::string FFmpegKitExtended::registerNewFFmpegPipe() noexcept {
  return invokeSynchronous<std::string>("registerNewFFmpegPipe", [&] { return api::registerNewFFmpegPipe(); });
}

void FFmpegKitExtended::closeFFmpegPipe(std::string path,
                                         Completion &&result) noexcept {
  completeAction("closeFFmpegPipe", std::move(result),
                 [&] { api::closeFFmpegPipe(path); });
}

double FFmpegKitExtended::messagesInTransmit(double sessionId) noexcept {
  return invokeSynchronous<double>("messagesInTransmit", [&] { return api::messagesInTransmit(sessionId); });
}

void FFmpegKitExtended::enableDebugLog(double sessionId,
                                        Completion &&result) noexcept {
  completeAction("enableDebugLog", std::move(result),
                 [&] { api::enableDebugLog(sessionId); });
}

void FFmpegKitExtended::disableDebugLog(double sessionId,
                                         Completion &&result) noexcept {
  completeAction("disableDebugLog", std::move(result),
                 [&] { api::disableDebugLog(sessionId); });
}

bool FFmpegKitExtended::isDebugLogEnabled(double sessionId) noexcept {
  return invokeSynchronous<bool>("isDebugLogEnabled", [&] { return api::isDebugLogEnabled(sessionId); });
}

std::string FFmpegKitExtended::getDebugLog(double sessionId) noexcept {
  return invokeSynchronous<std::string>("getDebugLog", [&] { return api::getDebugLog(sessionId); });
}

void FFmpegKitExtended::clearDebugLog(double sessionId,
                                       Completion &&result) noexcept {
  completeAction("clearDebugLog", std::move(result),
                 [&] { api::clearDebugLog(sessionId); });
}

} // namespace winrt::FFmpegKitExtended
