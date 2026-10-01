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

void FFmpegKitExtended::initialize() noexcept {
  invokeRecoverably("initialize", [&] { api::initialize(); });
}

std::string FFmpegKitExtended::consumeLastError() noexcept {
  return consumeOperationalError();
}

std::string FFmpegKitExtended::getBuildStamp() noexcept {
  return invokeRecoverably<std::string>("getBuildStamp", [&] { return api::getBuildStamp(); });
}

double FFmpegKitExtended::createFFmpegSession(std::string command) noexcept {
  return invokeRecoverably<double>("createFFmpegSession", [&] { return api::createFFmpegSession(command); });
}

double FFmpegKitExtended::createFFmpegSessionFromArguments(std::vector<std::string> arguments) noexcept {
  return invokeRecoverably<double>("createFFmpegSessionFromArguments", [&] {
    return api::createFFmpegSessionFromArguments(arguments);
  });
}

double FFmpegKitExtended::createFFprobeSession(std::string command) noexcept {
  return invokeRecoverably<double>("createFFprobeSession", [&] { return api::createFFprobeSession(command); });
}

double FFmpegKitExtended::createFFplaySession(std::string command) noexcept {
  return invokeRecoverably<double>("createFFplaySession", [&] { return api::createFFplaySession(command); });
}

double FFmpegKitExtended::createFFplaySessionFromArguments(std::vector<std::string> arguments) noexcept {
  return invokeRecoverably<double>("createFFplaySessionFromArguments", [&] {
    return api::createFFplaySessionFromArguments(arguments);
  });
}

double FFmpegKitExtended::createMediaInformationSession(std::string command) noexcept {
  return invokeRecoverably<double>("createMediaInformationSession", [&] { return api::createMediaInformationSession(command); });
}

double FFmpegKitExtended::createMediaInformationSessionFromPath(std::string path) noexcept {
  return invokeRecoverably<double>("createMediaInformationSessionFromPath", [&] {
    return api::createMediaInformationSessionFromPath(path);
  });
}

void FFmpegKitExtended::executeSessionAsync(double sessionId, double timeoutMs) noexcept {
  invokeRecoverably("executeSessionAsync", [&] { api::executeSessionAsync(sessionId, timeoutMs); });
}

void FFmpegKitExtended::cancelSession(double sessionId) noexcept {
  invokeRecoverably("cancelSession", [&] { api::cancelSession(sessionId); });
}

void FFmpegKitExtended::installLogBridge() noexcept {
  invokeRecoverably("installLogBridge", [&] {
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

void FFmpegKitExtended::uninstallLogBridge() noexcept {
  invokeRecoverably("uninstallLogBridge", [&] {
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
  return invokeRecoverably<std::string>("getSessionJson", [&] { return api::getSessionJson(sessionId); });
}

std::int32_t FFmpegKitExtended::getSessionState(double sessionId) noexcept {
  return invokeRecoverably<std::int32_t>("getSessionState", [&] { return api::getSessionState(sessionId); });
}

double FFmpegKitExtended::getLogsCount(double sessionId) noexcept {
  return invokeRecoverably<double>("getLogsCount", [&] { return api::getLogsCount(sessionId); });
}

void FFmpegKitExtended::releaseSessionHandle(double sessionId) noexcept {
  invokeRecoverably("releaseSessionHandle", [&] { api::releaseSessionHandle(sessionId); });
}

void FFmpegKitExtended::abandonCreatedSession(double sessionId) noexcept {
  invokeRecoverably("abandonCreatedSession", [&] { api::abandonCreatedSession(sessionId); });
}

std::string FFmpegKitExtended::getSessionsJson(std::string kind) noexcept {
  return invokeRecoverably<std::string>("getSessionsJson", [&] { return api::getSessionsJson(kind); });
}

std::string FFmpegKitExtended::getLastSessionJson(std::string kind) noexcept {
  return invokeRecoverably<std::string>("getLastSessionJson", [&] { return api::getLastSessionJson(kind); });
}

std::string FFmpegKitExtended::getLogsJson(double sessionId, double fromIndex) noexcept {
  return invokeRecoverably<std::string>("getLogsJson", [&] { return api::getLogsJson(sessionId, fromIndex); });
}

std::string FFmpegKitExtended::getStatisticsJson(double sessionId, double fromIndex) noexcept {
  return invokeRecoverably<std::string>("getStatisticsJson", [&] { return api::getStatisticsJson(sessionId, fromIndex); });
}

std::string FFmpegKitExtended::getMediaInformationJson(double sessionId) noexcept {
  return invokeRecoverably<std::string>("getMediaInformationJson", [&] { return api::getMediaInformationJson(sessionId); });
}

void FFmpegKitExtended::ffplayStart(double sessionId) noexcept {
  invokeRecoverably("ffplayStart", [&] { api::ffplayStart(sessionId); });
}

void FFmpegKitExtended::ffplayPause(double sessionId) noexcept {
  invokeRecoverably("ffplayPause", [&] { api::ffplayPause(sessionId); });
}

void FFmpegKitExtended::ffplayResume(double sessionId) noexcept {
  invokeRecoverably("ffplayResume", [&] { api::ffplayResume(sessionId); });
}

void FFmpegKitExtended::ffplayStop(double sessionId) noexcept {
  invokeRecoverably("ffplayStop", [&] { api::ffplayStop(sessionId); });
}

void FFmpegKitExtended::ffplaySeek(double sessionId, double seconds) noexcept {
  invokeRecoverably("ffplaySeek", [&] { api::ffplaySeek(sessionId, seconds); });
}

double FFmpegKitExtended::ffplayGetPosition(double sessionId) noexcept {
  return invokeRecoverably<double>("ffplayGetPosition", [&] { return api::ffplayGetPosition(sessionId); });
}

void FFmpegKitExtended::ffplaySetPosition(double sessionId, double seconds) noexcept {
  invokeRecoverably("ffplaySetPosition", [&] { api::ffplaySetPosition(sessionId, seconds); });
}

double FFmpegKitExtended::ffplayGetDuration(double sessionId) noexcept {
  return invokeRecoverably<double>("ffplayGetDuration", [&] { return api::ffplayGetDuration(sessionId); });
}

std::int32_t FFmpegKitExtended::ffplayGetVideoWidth(double sessionId) noexcept {
  return invokeRecoverably<std::int32_t>("ffplayGetVideoWidth", [&] { return api::ffplayGetVideoWidth(sessionId); });
}

std::int32_t FFmpegKitExtended::ffplayGetVideoHeight(double sessionId) noexcept {
  return invokeRecoverably<std::int32_t>("ffplayGetVideoHeight", [&] { return api::ffplayGetVideoHeight(sessionId); });
}

bool FFmpegKitExtended::ffplayIsPlaying(double sessionId) noexcept {
  return invokeRecoverably<bool>("ffplayIsPlaying", [&] { return api::ffplayIsPlaying(sessionId); });
}

bool FFmpegKitExtended::ffplayIsPaused(double sessionId) noexcept {
  return invokeRecoverably<bool>("ffplayIsPaused", [&] { return api::ffplayIsPaused(sessionId); });
}

void FFmpegKitExtended::ffplaySetVolume(double sessionId, double volume) noexcept {
  invokeRecoverably("ffplaySetVolume", [&] { api::ffplaySetVolume(sessionId, volume); });
}

double FFmpegKitExtended::ffplayGetVolume(double sessionId) noexcept {
  return invokeRecoverably<double>("ffplayGetVolume", [&] { return api::ffplayGetVolume(sessionId); });
}

bool FFmpegKitExtended::ffplayHasVideoStream(std::string path) noexcept {
  return invokeRecoverably<bool>("ffplayHasVideoStream", [&] { return api::ffplayHasVideoStream(path); });
}

void FFmpegKitExtended::enableRedirection() noexcept {
  invokeRecoverably("enableRedirection", [&] { api::enableRedirection(); });
}

void FFmpegKitExtended::disableRedirection() noexcept {
  invokeRecoverably("disableRedirection", [&] { api::disableRedirection(); });
}

void FFmpegKitExtended::setLogLevel(std::int32_t level) noexcept {
  invokeRecoverably("setLogLevel", [&] { api::setLogLevel(level); });
}

std::int32_t FFmpegKitExtended::getLogLevel() noexcept {
  return invokeRecoverably<std::int32_t>("getLogLevel", [&] { return api::getLogLevel(); });
}

std::string FFmpegKitExtended::logLevelToString(std::int32_t level) noexcept {
  return invokeRecoverably<std::string>("logLevelToString", [&] { return api::logLevelToString(level); });
}

void FFmpegKitExtended::setFontDirectory(std::string path, std::string mappingJson) noexcept {
  invokeRecoverably("setFontDirectory", [&] { api::setFontDirectory(path, mappingJson); });
}

void FFmpegKitExtended::setEnvironmentVariable(std::string name, std::string value) noexcept {
  invokeRecoverably("setEnvironmentVariable", [&] { api::setEnvironmentVariable(name, value); });
}

void FFmpegKitExtended::ignoreSignal(std::int32_t signal) noexcept {
  invokeRecoverably("ignoreSignal", [&] { api::ignoreSignal(signal); });
}

void FFmpegKitExtended::setAudioOutputDevice(std::string deviceName) noexcept {
  invokeRecoverably("setAudioOutputDevice", [&] { api::setAudioOutputDevice(deviceName); });
}

std::string FFmpegKitExtended::listAudioOutputDevices() noexcept {
  return invokeRecoverably<std::string>("listAudioOutputDevices", [&] { return api::listAudioOutputDevices(); });
}

std::string FFmpegKitExtended::getFFmpegVersion() noexcept {
  return invokeRecoverably<std::string>("getFFmpegVersion", [&] { return api::getFFmpegVersion(); });
}

std::string FFmpegKitExtended::getFFmpegArchitecture() noexcept {
  return invokeRecoverably<std::string>("getFFmpegArchitecture", [&] { return api::getFFmpegArchitecture(); });
}

std::string FFmpegKitExtended::getVersion() noexcept {
  return invokeRecoverably<std::string>("getVersion", [&] { return api::getVersion(); });
}

std::string FFmpegKitExtended::getPackageName() noexcept {
  return invokeRecoverably<std::string>("getPackageName", [&] { return api::getPackageName(); });
}

std::string FFmpegKitExtended::getExternalLibraries() noexcept {
  return invokeRecoverably<std::string>("getExternalLibraries", [&] { return api::getExternalLibraries(); });
}

std::string FFmpegKitExtended::getBundleType() noexcept {
  return invokeRecoverably<std::string>("getBundleType", [&] { return api::getBundleType(); });
}

bool FFmpegKitExtended::isGpl() noexcept {
  return invokeRecoverably<bool>("isGpl", [&] { return api::isGpl(); });
}

bool FFmpegKitExtended::isNonfree() noexcept {
  return invokeRecoverably<bool>("isNonfree", [&] { return api::isNonfree(); });
}

std::string FFmpegKitExtended::getRegisteredCodecs() noexcept {
  return invokeRecoverably<std::string>("getRegisteredCodecs", [&] { return api::getRegisteredCodecs(); });
}

std::string FFmpegKitExtended::getRegisteredEncoders() noexcept {
  return invokeRecoverably<std::string>("getRegisteredEncoders", [&] { return api::getRegisteredEncoders(); });
}

std::string FFmpegKitExtended::getRegisteredDecoders() noexcept {
  return invokeRecoverably<std::string>("getRegisteredDecoders", [&] { return api::getRegisteredDecoders(); });
}

std::string FFmpegKitExtended::getRegisteredMuxers() noexcept {
  return invokeRecoverably<std::string>("getRegisteredMuxers", [&] { return api::getRegisteredMuxers(); });
}

std::string FFmpegKitExtended::getRegisteredDemuxers() noexcept {
  return invokeRecoverably<std::string>("getRegisteredDemuxers", [&] { return api::getRegisteredDemuxers(); });
}

std::string FFmpegKitExtended::getRegisteredFilters() noexcept {
  return invokeRecoverably<std::string>("getRegisteredFilters", [&] { return api::getRegisteredFilters(); });
}

std::string FFmpegKitExtended::getRegisteredProtocols() noexcept {
  return invokeRecoverably<std::string>("getRegisteredProtocols", [&] { return api::getRegisteredProtocols(); });
}

std::string FFmpegKitExtended::getRegisteredBitstreamFilters() noexcept {
  return invokeRecoverably<std::string>("getRegisteredBitstreamFilters", [&] { return api::getRegisteredBitstreamFilters(); });
}

std::string FFmpegKitExtended::getBuildConfiguration() noexcept {
  return invokeRecoverably<std::string>("getBuildConfiguration", [&] { return api::getBuildConfiguration(); });
}

std::string FFmpegKitExtended::getBuildDate() noexcept {
  return invokeRecoverably<std::string>("getBuildDate", [&] { return api::getBuildDate(); });
}

void FFmpegKitExtended::setSessionHistorySize(double size) noexcept {
  invokeRecoverably("setSessionHistorySize", [&] { api::setSessionHistorySize(size); });
}

double FFmpegKitExtended::getSessionHistorySize() noexcept {
  return invokeRecoverably<double>("getSessionHistorySize", [&] { return api::getSessionHistorySize(); });
}

void FFmpegKitExtended::clearSessions() noexcept {
  invokeRecoverably("clearSessions", [&] { api::clearSessions(); });
}

std::string FFmpegKitExtended::registerNewFFmpegPipe() noexcept {
  return invokeRecoverably<std::string>("registerNewFFmpegPipe", [&] { return api::registerNewFFmpegPipe(); });
}

void FFmpegKitExtended::closeFFmpegPipe(std::string path) noexcept {
  invokeRecoverably("closeFFmpegPipe", [&] { api::closeFFmpegPipe(path); });
}

double FFmpegKitExtended::messagesInTransmit(double sessionId) noexcept {
  return invokeRecoverably<double>("messagesInTransmit", [&] { return api::messagesInTransmit(sessionId); });
}

void FFmpegKitExtended::enableDebugLog(double sessionId) noexcept {
  invokeRecoverably("enableDebugLog", [&] { api::enableDebugLog(sessionId); });
}

void FFmpegKitExtended::disableDebugLog(double sessionId) noexcept {
  invokeRecoverably("disableDebugLog", [&] { api::disableDebugLog(sessionId); });
}

bool FFmpegKitExtended::isDebugLogEnabled(double sessionId) noexcept {
  return invokeRecoverably<bool>("isDebugLogEnabled", [&] { return api::isDebugLogEnabled(sessionId); });
}

std::string FFmpegKitExtended::getDebugLog(double sessionId) noexcept {
  return invokeRecoverably<std::string>("getDebugLog", [&] { return api::getDebugLog(sessionId); });
}

void FFmpegKitExtended::clearDebugLog(double sessionId) noexcept {
  invokeRecoverably("clearDebugLog", [&] { api::clearDebugLog(sessionId); });
}

} // namespace winrt::FFmpegKitExtended
