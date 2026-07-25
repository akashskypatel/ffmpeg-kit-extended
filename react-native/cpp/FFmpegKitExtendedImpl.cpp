#include "FFmpegKitExtendedImpl.h"
#include "FFmpegKitDynamicApi.h"

namespace facebook::react {
namespace api = ffmpegkit::bridge;

FFmpegKitExtendedImpl::FFmpegKitExtendedImpl(std::shared_ptr<CallInvoker> jsInvoker)
    : NativeFFmpegKitExtendedCxxSpec(std::move(jsInvoker)) {}

void FFmpegKitExtendedImpl::initialize(jsi::Runtime &) { api::initialize(); }
std::string FFmpegKitExtendedImpl::getBuildStamp(jsi::Runtime &) { return api::getBuildStamp(); }

double FFmpegKitExtendedImpl::createFFmpegSession(jsi::Runtime &, std::string command) { return api::createFFmpegSession(command); }
double FFmpegKitExtendedImpl::createFFprobeSession(jsi::Runtime &, std::string command) { return api::createFFprobeSession(command); }
double FFmpegKitExtendedImpl::createFFplaySession(jsi::Runtime &, std::string command) { return api::createFFplaySession(command); }
double FFmpegKitExtendedImpl::createMediaInformationSession(jsi::Runtime &, std::string command) { return api::createMediaInformationSession(command); }
void FFmpegKitExtendedImpl::executeSessionAsync(jsi::Runtime &, double sessionId, double timeoutMs) { api::executeSessionAsync(sessionId, timeoutMs); }
void FFmpegKitExtendedImpl::cancelSession(jsi::Runtime &, double sessionId) { api::cancelSession(sessionId); }

std::string FFmpegKitExtendedImpl::getSessionJson(jsi::Runtime &, double sessionId) { return api::getSessionJson(sessionId); }
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
