#include "FFmpegKitExtendedImpl.h"
#include "FFmpegKitDynamicApi.h"
#include "LogBridgeRegistrationCoordinator.h"

#include <mutex>
#include <utility>
#include <vector>

namespace facebook::react {
namespace api = ffmpegkit::bridge;

struct LogBridgeState {
  std::mutex mutex;
  std::weak_ptr<FFmpegKitExtendedImpl> owner;
  std::shared_ptr<CallInvoker> jsInvoker;
};

namespace {

std::mutex retiredLogBridgeStatesMutex;
std::vector<std::shared_ptr<LogBridgeState>> retiredLogBridgeStates;
ffmpegkit::bridge::LogBridgeRegistrationCoordinator logBridgeRegistrationCoordinator;

void retainRetiredLogBridgeState(std::shared_ptr<LogBridgeState> state) noexcept {
  if (state == nullptr) return;
  std::lock_guard<std::mutex> lock(retiredLogBridgeStatesMutex);
  retiredLogBridgeStates.push_back(std::move(state));
}

struct OwnedLogMessage {
  char *value;

  ~OwnedLogMessage() noexcept {
    if (value == nullptr) return;
    try {
      api::releaseOwnedLogMessage(value);
    } catch (...) {
      // The native payload has one release obligation. There is no safe
      // recovery path if the dynamically loaded allocator is already gone.
    }
  }
};

void handleLogEvent(std::int64_t sessionId,
                    std::int64_t sequence,
                    std::int32_t level,
                    char *ownedMessage,
                    void *userData) noexcept {
  OwnedLogMessage owned{ownedMessage};

  try {
    auto *state = static_cast<LogBridgeState *>(userData);
    if (state == nullptr) return;

    std::shared_ptr<CallInvoker> jsInvoker;
    std::shared_ptr<FFmpegKitExtendedImpl> owner;
    {
      std::lock_guard<std::mutex> lock(state->mutex);
      jsInvoker = state->jsInvoker;
      owner = state->owner.lock();
    }
    if (jsInvoker == nullptr || owner == nullptr) return;

    std::string message = owned.value == nullptr ? std::string{} : std::string{owned.value};
    jsInvoker->invokeAsync(
        [owner = std::move(owner), sessionId, sequence, level,
         message = std::move(message)](jsi::Runtime &) mutable {
          owner->emitLogEvent(static_cast<double>(sessionId),
                              static_cast<double>(sequence),
                              level,
                              std::move(message));
        });
  } catch (...) {
    // The callback is invoked by native worker threads. Never allow a JS or
    // allocation failure to cross the ABI boundary; OwnedLogMessage still
    // releases the payload exactly once.
  }
}

void deactivateLogBridge(const std::shared_ptr<LogBridgeState> &state) noexcept {
  if (state == nullptr) return;
  std::lock_guard<std::mutex> lock(state->mutex);
  state->owner.reset();
  state->jsInvoker.reset();
}

} // namespace

FFmpegKitExtendedImpl::FFmpegKitExtendedImpl(std::shared_ptr<CallInvoker> jsInvoker)
    : NativeFFmpegKitExtendedCxxSpec(jsInvoker), jsInvoker_(std::move(jsInvoker)) {}

FFmpegKitExtendedImpl::~FFmpegKitExtendedImpl() {
  const auto state = std::move(activeLogBridge_);
  if (state == nullptr) return;

  try {
    logBridgeRegistrationCoordinator.uninstallIfOwned(
        state.get(), [&] { api::enableLogCallback(nullptr, nullptr); });
  } catch (...) {
    // Destruction must not throw through the TurboModule lifetime boundary.
  }
  deactivateLogBridge(state);
  retainRetiredLogBridgeState(state);
}

void FFmpegKitExtendedImpl::initialize(jsi::Runtime &) { api::initialize(); }
std::string FFmpegKitExtendedImpl::getBuildStamp(jsi::Runtime &) { return api::getBuildStamp(); }

double FFmpegKitExtendedImpl::createFFmpegSession(jsi::Runtime &, std::string command) { return api::createFFmpegSession(command); }
double FFmpegKitExtendedImpl::createFFmpegSessionFromArguments(jsi::Runtime &, std::vector<std::string> arguments) { return api::createFFmpegSessionFromArguments(arguments); }
double FFmpegKitExtendedImpl::createFFprobeSession(jsi::Runtime &, std::string command) { return api::createFFprobeSession(command); }
double FFmpegKitExtendedImpl::createFFplaySession(jsi::Runtime &, std::string command) { return api::createFFplaySession(command); }
double FFmpegKitExtendedImpl::createFFplaySessionFromArguments(jsi::Runtime &, std::vector<std::string> arguments) { return api::createFFplaySessionFromArguments(arguments); }
double FFmpegKitExtendedImpl::createMediaInformationSession(jsi::Runtime &, std::string command) { return api::createMediaInformationSession(command); }
double FFmpegKitExtendedImpl::createMediaInformationSessionFromPath(jsi::Runtime &, std::string path) { return api::createMediaInformationSessionFromPath(path); }
void FFmpegKitExtendedImpl::executeSessionAsync(jsi::Runtime &, double sessionId, double timeoutMs) { api::executeSessionAsync(sessionId, timeoutMs); }
void FFmpegKitExtendedImpl::cancelSession(jsi::Runtime &, double sessionId) { api::cancelSession(sessionId); }

void FFmpegKitExtendedImpl::emitLogEvent(double sessionId,
                                         double sequence,
                                         std::int32_t level,
                                         std::string message) {
  emitOnLogEvent(NativeFFmpegKitExtendedLogEvent<double, double, int, std::string>{
      sessionId, sequence, level, std::move(message)});
}

void FFmpegKitExtendedImpl::installLogBridge(jsi::Runtime &) {
  if (activeLogBridge_ == nullptr) {
    activeLogBridge_ = std::make_shared<LogBridgeState>();
  }

  const auto state = activeLogBridge_;
  {
    std::lock_guard<std::mutex> lock(state->mutex);
    state->owner = shared_from_this();
    state->jsInvoker = jsInvoker_;
  }
  try {
    logBridgeRegistrationCoordinator.install(
        state.get(), [&] { api::enableLogCallback(&handleLogEvent, state.get()); });
  } catch (...) {
    deactivateLogBridge(state);
    throw;
  }
}

void FFmpegKitExtendedImpl::uninstallLogBridge(jsi::Runtime &) {
  const auto state = activeLogBridge_;
  if (state == nullptr) return;

  try {
    logBridgeRegistrationCoordinator.uninstallIfOwned(
        state.get(), [&] { api::enableLogCallback(nullptr, nullptr); });
  } catch (...) {
    deactivateLogBridge(state);
    throw;
  }
  deactivateLogBridge(state);
}

std::string FFmpegKitExtendedImpl::getSessionJson(jsi::Runtime &, double sessionId) { return api::getSessionJson(sessionId); }
std::int32_t FFmpegKitExtendedImpl::getSessionState(jsi::Runtime &, double sessionId) { return api::getSessionState(sessionId); }
double FFmpegKitExtendedImpl::getLogsCount(jsi::Runtime &, double sessionId) { return api::getLogsCount(sessionId); }
void FFmpegKitExtendedImpl::releaseSessionHandle(jsi::Runtime &, double sessionId) { api::releaseSessionHandle(sessionId); }
std::string FFmpegKitExtendedImpl::getSessionsJson(jsi::Runtime &, std::string kind) { return api::getSessionsJson(kind); }
std::string FFmpegKitExtendedImpl::getLastSessionJson(jsi::Runtime &, std::string kind) { return api::getLastSessionJson(kind); }
std::string FFmpegKitExtendedImpl::getLogsJson(jsi::Runtime &, double sessionId, double fromIndex) { return api::getLogsJson(sessionId, fromIndex); }
std::string FFmpegKitExtendedImpl::getStatisticsJson(jsi::Runtime &, double sessionId, double fromIndex) { return api::getStatisticsJson(sessionId, fromIndex); }
std::string FFmpegKitExtendedImpl::getMediaInformationJson(jsi::Runtime &, double sessionId) { return api::getMediaInformationJson(sessionId); }

void FFmpegKitExtendedImpl::ffplayStart(jsi::Runtime &, double sessionId) { api::ffplayStart(sessionId); }
void FFmpegKitExtendedImpl::ffplayPause(jsi::Runtime &, double sessionId) { api::ffplayPause(sessionId); }
void FFmpegKitExtendedImpl::ffplayResume(jsi::Runtime &, double sessionId) { api::ffplayResume(sessionId); }
void FFmpegKitExtendedImpl::ffplayStop(jsi::Runtime &, double sessionId) { api::ffplayStop(sessionId); }
void FFmpegKitExtendedImpl::ffplaySeek(jsi::Runtime &, double sessionId, double seconds) { api::ffplaySeek(sessionId, seconds); }
double FFmpegKitExtendedImpl::ffplayGetPosition(jsi::Runtime &, double sessionId) { return api::ffplayGetPosition(sessionId); }
void FFmpegKitExtendedImpl::ffplaySetPosition(jsi::Runtime &, double sessionId, double seconds) { api::ffplaySetPosition(sessionId, seconds); }
double FFmpegKitExtendedImpl::ffplayGetDuration(jsi::Runtime &, double sessionId) { return api::ffplayGetDuration(sessionId); }
std::int32_t FFmpegKitExtendedImpl::ffplayGetVideoWidth(jsi::Runtime &, double sessionId) { return api::ffplayGetVideoWidth(sessionId); }
std::int32_t FFmpegKitExtendedImpl::ffplayGetVideoHeight(jsi::Runtime &, double sessionId) { return api::ffplayGetVideoHeight(sessionId); }
bool FFmpegKitExtendedImpl::ffplayIsPlaying(jsi::Runtime &, double sessionId) { return api::ffplayIsPlaying(sessionId); }
bool FFmpegKitExtendedImpl::ffplayIsPaused(jsi::Runtime &, double sessionId) { return api::ffplayIsPaused(sessionId); }
void FFmpegKitExtendedImpl::ffplaySetVolume(jsi::Runtime &, double sessionId, double volume) { api::ffplaySetVolume(sessionId, volume); }
double FFmpegKitExtendedImpl::ffplayGetVolume(jsi::Runtime &, double sessionId) { return api::ffplayGetVolume(sessionId); }
bool FFmpegKitExtendedImpl::ffplayHasVideoStream(jsi::Runtime &, std::string path) { return api::ffplayHasVideoStream(path); }

void FFmpegKitExtendedImpl::enableRedirection(jsi::Runtime &) { api::enableRedirection(); }
void FFmpegKitExtendedImpl::disableRedirection(jsi::Runtime &) { api::disableRedirection(); }
void FFmpegKitExtendedImpl::setLogLevel(jsi::Runtime &, std::int32_t level) { api::setLogLevel(level); }
std::int32_t FFmpegKitExtendedImpl::getLogLevel(jsi::Runtime &) { return api::getLogLevel(); }
std::string FFmpegKitExtendedImpl::logLevelToString(jsi::Runtime &, std::int32_t level) { return api::logLevelToString(level); }
void FFmpegKitExtendedImpl::setFontDirectory(jsi::Runtime &, std::string path, std::string mappingJson) { api::setFontDirectory(path, mappingJson); }
void FFmpegKitExtendedImpl::setEnvironmentVariable(jsi::Runtime &, std::string name, std::string value) { api::setEnvironmentVariable(name, value); }
void FFmpegKitExtendedImpl::ignoreSignal(jsi::Runtime &, std::int32_t signal) { api::ignoreSignal(signal); }
void FFmpegKitExtendedImpl::setAudioOutputDevice(jsi::Runtime &, std::string deviceName) { api::setAudioOutputDevice(deviceName); }
std::string FFmpegKitExtendedImpl::listAudioOutputDevices(jsi::Runtime &) { return api::listAudioOutputDevices(); }

std::string FFmpegKitExtendedImpl::getFFmpegVersion(jsi::Runtime &) { return api::getFFmpegVersion(); }
std::string FFmpegKitExtendedImpl::getFFmpegArchitecture(jsi::Runtime &) { return api::getFFmpegArchitecture(); }
std::string FFmpegKitExtendedImpl::getVersion(jsi::Runtime &) { return api::getVersion(); }
std::string FFmpegKitExtendedImpl::getPackageName(jsi::Runtime &) { return api::getPackageName(); }
std::string FFmpegKitExtendedImpl::getExternalLibraries(jsi::Runtime &) { return api::getExternalLibraries(); }
std::string FFmpegKitExtendedImpl::getBundleType(jsi::Runtime &) { return api::getBundleType(); }
bool FFmpegKitExtendedImpl::isGpl(jsi::Runtime &) { return api::isGpl(); }
bool FFmpegKitExtendedImpl::isNonfree(jsi::Runtime &) { return api::isNonfree(); }
std::string FFmpegKitExtendedImpl::getRegisteredCodecs(jsi::Runtime &) { return api::getRegisteredCodecs(); }
std::string FFmpegKitExtendedImpl::getRegisteredEncoders(jsi::Runtime &) { return api::getRegisteredEncoders(); }
std::string FFmpegKitExtendedImpl::getRegisteredDecoders(jsi::Runtime &) { return api::getRegisteredDecoders(); }
std::string FFmpegKitExtendedImpl::getRegisteredMuxers(jsi::Runtime &) { return api::getRegisteredMuxers(); }
std::string FFmpegKitExtendedImpl::getRegisteredDemuxers(jsi::Runtime &) { return api::getRegisteredDemuxers(); }
std::string FFmpegKitExtendedImpl::getRegisteredFilters(jsi::Runtime &) { return api::getRegisteredFilters(); }
std::string FFmpegKitExtendedImpl::getRegisteredProtocols(jsi::Runtime &) { return api::getRegisteredProtocols(); }
std::string FFmpegKitExtendedImpl::getRegisteredBitstreamFilters(jsi::Runtime &) { return api::getRegisteredBitstreamFilters(); }
std::string FFmpegKitExtendedImpl::getBuildConfiguration(jsi::Runtime &) { return api::getBuildConfiguration(); }
std::string FFmpegKitExtendedImpl::getBuildDate(jsi::Runtime &) { return api::getBuildDate(); }

void FFmpegKitExtendedImpl::setSessionHistorySize(jsi::Runtime &, double size) { api::setSessionHistorySize(size); }
double FFmpegKitExtendedImpl::getSessionHistorySize(jsi::Runtime &) { return api::getSessionHistorySize(); }
void FFmpegKitExtendedImpl::clearSessions(jsi::Runtime &) { api::clearSessions(); }
std::string FFmpegKitExtendedImpl::registerNewFFmpegPipe(jsi::Runtime &) { return api::registerNewFFmpegPipe(); }
void FFmpegKitExtendedImpl::closeFFmpegPipe(jsi::Runtime &, std::string path) { api::closeFFmpegPipe(path); }
double FFmpegKitExtendedImpl::messagesInTransmit(jsi::Runtime &, double sessionId) { return api::messagesInTransmit(sessionId); }

void FFmpegKitExtendedImpl::enableDebugLog(jsi::Runtime &, double sessionId) { api::enableDebugLog(sessionId); }
void FFmpegKitExtendedImpl::disableDebugLog(jsi::Runtime &, double sessionId) { api::disableDebugLog(sessionId); }
bool FFmpegKitExtendedImpl::isDebugLogEnabled(jsi::Runtime &, double sessionId) { return api::isDebugLogEnabled(sessionId); }
std::string FFmpegKitExtendedImpl::getDebugLog(jsi::Runtime &, double sessionId) { return api::getDebugLog(sessionId); }
void FFmpegKitExtendedImpl::clearDebugLog(jsi::Runtime &, double sessionId) { api::clearDebugLog(sessionId); }

} // namespace facebook::react
