#include "pch.h"
#include "FFmpegKitExtended.h"

#include "FFmpegKitDynamicApi.h"

#include <exception>
#include <string>
#include <utility>

namespace winrt::FFmpegKitExtended {
namespace {

[[noreturn]] void failFast(const char *method, const char *message) noexcept {
  std::string text = "FFmpegKitExtended Windows native call failed in ";
  text += method;
  text += ": ";
  text += message ? message : "unknown native error";
  text += "\n";
  OutputDebugStringA(text.c_str());
  RaiseFailFastException(nullptr, nullptr, 0);
  std::terminate();
}

template <typename Fn>
void invokeVoid(const char *method, Fn &&fn) noexcept {
  try {
    std::forward<Fn>(fn)();
  } catch (const std::exception &error) {
    failFast(method, error.what());
  } catch (...) {
    failFast(method, "non-standard exception");
  }
}

template <typename Result, typename Fn>
Result invoke(const char *method, Fn &&fn) noexcept {
  try {
    return std::forward<Fn>(fn)();
  } catch (const std::exception &error) {
    failFast(method, error.what());
  } catch (...) {
    failFast(method, "non-standard exception");
  }
}

} // namespace

namespace api = ffmpegkit::bridge;

void FFmpegKitExtended::initialize() noexcept {
  invokeVoid("initialize", [&] { api::initialize(); });
}

std::string FFmpegKitExtended::getBuildStamp() noexcept {
  return invoke<std::string>("getBuildStamp", [&] { return api::getBuildStamp(); });
}

double FFmpegKitExtended::createFFmpegSession(std::string command) noexcept {
  return invoke<double>("createFFmpegSession", [&] { return api::createFFmpegSession(command); });
}

double FFmpegKitExtended::createFFprobeSession(std::string command) noexcept {
  return invoke<double>("createFFprobeSession", [&] { return api::createFFprobeSession(command); });
}

double FFmpegKitExtended::createFFplaySession(std::string command) noexcept {
  return invoke<double>("createFFplaySession", [&] { return api::createFFplaySession(command); });
}

double FFmpegKitExtended::createMediaInformationSession(std::string command) noexcept {
  return invoke<double>("createMediaInformationSession", [&] { return api::createMediaInformationSession(command); });
}

void FFmpegKitExtended::executeSessionAsync(double sessionId, double timeoutMs) noexcept {
  invokeVoid("executeSessionAsync", [&] { api::executeSessionAsync(sessionId, timeoutMs); });
}

void FFmpegKitExtended::cancelSession(double sessionId) noexcept {
  invokeVoid("cancelSession", [&] { api::cancelSession(sessionId); });
}

std::string FFmpegKitExtended::getSessionJson(double sessionId) noexcept {
  return invoke<std::string>("getSessionJson", [&] { return api::getSessionJson(sessionId); });
}

void FFmpegKitExtended::releaseSessionHandle(double sessionId) noexcept {
  invokeVoid("releaseSessionHandle", [&] { api::releaseSessionHandle(sessionId); });
}

std::string FFmpegKitExtended::getSessionsJson(std::string kind) noexcept {
  return invoke<std::string>("getSessionsJson", [&] { return api::getSessionsJson(kind); });
}

std::string FFmpegKitExtended::getLastSessionJson(std::string kind) noexcept {
  return invoke<std::string>("getLastSessionJson", [&] { return api::getLastSessionJson(kind); });
}

std::string FFmpegKitExtended::getLogsJson(double sessionId, double fromIndex) noexcept {
  return invoke<std::string>("getLogsJson", [&] { return api::getLogsJson(sessionId, fromIndex); });
}

std::string FFmpegKitExtended::getStatisticsJson(double sessionId, double fromIndex) noexcept {
  return invoke<std::string>("getStatisticsJson", [&] { return api::getStatisticsJson(sessionId, fromIndex); });
}

std::string FFmpegKitExtended::getMediaInformationJson(double sessionId) noexcept {
  return invoke<std::string>("getMediaInformationJson", [&] { return api::getMediaInformationJson(sessionId); });
}

void FFmpegKitExtended::ffplayStart(double sessionId) noexcept {
  invokeVoid("ffplayStart", [&] { api::ffplayStart(sessionId); });
}

void FFmpegKitExtended::ffplayPause(double sessionId) noexcept {
  invokeVoid("ffplayPause", [&] { api::ffplayPause(sessionId); });
}

void FFmpegKitExtended::ffplayResume(double sessionId) noexcept {
  invokeVoid("ffplayResume", [&] { api::ffplayResume(sessionId); });
}

void FFmpegKitExtended::ffplayStop(double sessionId) noexcept {
  invokeVoid("ffplayStop", [&] { api::ffplayStop(sessionId); });
}

void FFmpegKitExtended::ffplaySeek(double sessionId, double seconds) noexcept {
  invokeVoid("ffplaySeek", [&] { api::ffplaySeek(sessionId, seconds); });
}

double FFmpegKitExtended::ffplayGetPosition(double sessionId) noexcept {
  return invoke<double>("ffplayGetPosition", [&] { return api::ffplayGetPosition(sessionId); });
}

void FFmpegKitExtended::ffplaySetPosition(double sessionId, double seconds) noexcept {
  invokeVoid("ffplaySetPosition", [&] { api::ffplaySetPosition(sessionId, seconds); });
}

double FFmpegKitExtended::ffplayGetDuration(double sessionId) noexcept {
  return invoke<double>("ffplayGetDuration", [&] { return api::ffplayGetDuration(sessionId); });
}

std::int32_t FFmpegKitExtended::ffplayGetVideoWidth(double sessionId) noexcept {
  return invoke<std::int32_t>("ffplayGetVideoWidth", [&] { return api::ffplayGetVideoWidth(sessionId); });
}

std::int32_t FFmpegKitExtended::ffplayGetVideoHeight(double sessionId) noexcept {
  return invoke<std::int32_t>("ffplayGetVideoHeight", [&] { return api::ffplayGetVideoHeight(sessionId); });
}

bool FFmpegKitExtended::ffplayIsPlaying(double sessionId) noexcept {
  return invoke<bool>("ffplayIsPlaying", [&] { return api::ffplayIsPlaying(sessionId); });
}

bool FFmpegKitExtended::ffplayIsPaused(double sessionId) noexcept {
  return invoke<bool>("ffplayIsPaused", [&] { return api::ffplayIsPaused(sessionId); });
}

void FFmpegKitExtended::ffplaySetVolume(double sessionId, double volume) noexcept {
  invokeVoid("ffplaySetVolume", [&] { api::ffplaySetVolume(sessionId, volume); });
}

double FFmpegKitExtended::ffplayGetVolume(double sessionId) noexcept {
  return invoke<double>("ffplayGetVolume", [&] { return api::ffplayGetVolume(sessionId); });
}

bool FFmpegKitExtended::ffplayHasVideoStream(std::string path) noexcept {
  return invoke<bool>("ffplayHasVideoStream", [&] { return api::ffplayHasVideoStream(path); });
}

void FFmpegKitExtended::enableRedirection() noexcept {
  invokeVoid("enableRedirection", [&] { api::enableRedirection(); });
}

void FFmpegKitExtended::disableRedirection() noexcept {
  invokeVoid("disableRedirection", [&] { api::disableRedirection(); });
}

void FFmpegKitExtended::setLogLevel(std::int32_t level) noexcept {
  invokeVoid("setLogLevel", [&] { api::setLogLevel(level); });
}

std::int32_t FFmpegKitExtended::getLogLevel() noexcept {
  return invoke<std::int32_t>("getLogLevel", [&] { return api::getLogLevel(); });
}

std::string FFmpegKitExtended::logLevelToString(std::int32_t level) noexcept {
  return invoke<std::string>("logLevelToString", [&] { return api::logLevelToString(level); });
}

void FFmpegKitExtended::setFontDirectory(std::string path, std::string mappingJson) noexcept {
  invokeVoid("setFontDirectory", [&] { api::setFontDirectory(path, mappingJson); });
}

void FFmpegKitExtended::setEnvironmentVariable(std::string name, std::string value) noexcept {
  invokeVoid("setEnvironmentVariable", [&] { api::setEnvironmentVariable(name, value); });
}

void FFmpegKitExtended::ignoreSignal(std::int32_t signal) noexcept {
  invokeVoid("ignoreSignal", [&] { api::ignoreSignal(signal); });
}

void FFmpegKitExtended::setAudioOutputDevice(std::string deviceName) noexcept {
  invokeVoid("setAudioOutputDevice", [&] { api::setAudioOutputDevice(deviceName); });
}

std::string FFmpegKitExtended::listAudioOutputDevices() noexcept {
  return invoke<std::string>("listAudioOutputDevices", [&] { return api::listAudioOutputDevices(); });
}

std::string FFmpegKitExtended::getFFmpegVersion() noexcept {
  return invoke<std::string>("getFFmpegVersion", [&] { return api::getFFmpegVersion(); });
}

std::string FFmpegKitExtended::getFFmpegArchitecture() noexcept {
  return invoke<std::string>("getFFmpegArchitecture", [&] { return api::getFFmpegArchitecture(); });
}

std::string FFmpegKitExtended::getVersion() noexcept {
  return invoke<std::string>("getVersion", [&] { return api::getVersion(); });
}

std::string FFmpegKitExtended::getPackageName() noexcept {
  return invoke<std::string>("getPackageName", [&] { return api::getPackageName(); });
}

std::string FFmpegKitExtended::getExternalLibraries() noexcept {
  return invoke<std::string>("getExternalLibraries", [&] { return api::getExternalLibraries(); });
}

std::string FFmpegKitExtended::getBundleType() noexcept {
  return invoke<std::string>("getBundleType", [&] { return api::getBundleType(); });
}

bool FFmpegKitExtended::isGpl() noexcept {
  return invoke<bool>("isGpl", [&] { return api::isGpl(); });
}

bool FFmpegKitExtended::isNonfree() noexcept {
  return invoke<bool>("isNonfree", [&] { return api::isNonfree(); });
}

std::string FFmpegKitExtended::getRegisteredCodecs() noexcept {
  return invoke<std::string>("getRegisteredCodecs", [&] { return api::getRegisteredCodecs(); });
}

std::string FFmpegKitExtended::getRegisteredEncoders() noexcept {
  return invoke<std::string>("getRegisteredEncoders", [&] { return api::getRegisteredEncoders(); });
}

std::string FFmpegKitExtended::getRegisteredDecoders() noexcept {
  return invoke<std::string>("getRegisteredDecoders", [&] { return api::getRegisteredDecoders(); });
}

std::string FFmpegKitExtended::getRegisteredMuxers() noexcept {
  return invoke<std::string>("getRegisteredMuxers", [&] { return api::getRegisteredMuxers(); });
}

std::string FFmpegKitExtended::getRegisteredDemuxers() noexcept {
  return invoke<std::string>("getRegisteredDemuxers", [&] { return api::getRegisteredDemuxers(); });
}

std::string FFmpegKitExtended::getRegisteredFilters() noexcept {
  return invoke<std::string>("getRegisteredFilters", [&] { return api::getRegisteredFilters(); });
}

std::string FFmpegKitExtended::getRegisteredProtocols() noexcept {
  return invoke<std::string>("getRegisteredProtocols", [&] { return api::getRegisteredProtocols(); });
}

std::string FFmpegKitExtended::getRegisteredBitstreamFilters() noexcept {
  return invoke<std::string>("getRegisteredBitstreamFilters", [&] { return api::getRegisteredBitstreamFilters(); });
}

std::string FFmpegKitExtended::getBuildConfiguration() noexcept {
  return invoke<std::string>("getBuildConfiguration", [&] { return api::getBuildConfiguration(); });
}

std::string FFmpegKitExtended::getBuildDate() noexcept {
  return invoke<std::string>("getBuildDate", [&] { return api::getBuildDate(); });
}

void FFmpegKitExtended::setSessionHistorySize(double size) noexcept {
  invokeVoid("setSessionHistorySize", [&] { api::setSessionHistorySize(size); });
}

double FFmpegKitExtended::getSessionHistorySize() noexcept {
  return invoke<double>("getSessionHistorySize", [&] { return api::getSessionHistorySize(); });
}

void FFmpegKitExtended::clearSessions() noexcept {
  invokeVoid("clearSessions", [&] { api::clearSessions(); });
}

std::string FFmpegKitExtended::registerNewFFmpegPipe() noexcept {
  return invoke<std::string>("registerNewFFmpegPipe", [&] { return api::registerNewFFmpegPipe(); });
}

void FFmpegKitExtended::closeFFmpegPipe(std::string path) noexcept {
  invokeVoid("closeFFmpegPipe", [&] { api::closeFFmpegPipe(path); });
}

double FFmpegKitExtended::messagesInTransmit(double sessionId) noexcept {
  return invoke<double>("messagesInTransmit", [&] { return api::messagesInTransmit(sessionId); });
}

void FFmpegKitExtended::enableDebugLog(double sessionId) noexcept {
  invokeVoid("enableDebugLog", [&] { api::enableDebugLog(sessionId); });
}

void FFmpegKitExtended::disableDebugLog(double sessionId) noexcept {
  invokeVoid("disableDebugLog", [&] { api::disableDebugLog(sessionId); });
}

bool FFmpegKitExtended::isDebugLogEnabled(double sessionId) noexcept {
  return invoke<bool>("isDebugLogEnabled", [&] { return api::isDebugLogEnabled(sessionId); });
}

std::string FFmpegKitExtended::getDebugLog(double sessionId) noexcept {
  return invoke<std::string>("getDebugLog", [&] { return api::getDebugLog(sessionId); });
}

void FFmpegKitExtended::clearDebugLog(double sessionId) noexcept {
  invokeVoid("clearDebugLog", [&] { api::clearDebugLog(sessionId); });
}

} // namespace winrt::FFmpegKitExtended
