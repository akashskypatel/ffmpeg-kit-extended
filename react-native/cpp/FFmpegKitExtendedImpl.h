#pragma once

#include <FFmpegKitExtendedSpecJSI.h>

#include <cstdint>
#include <memory>
#include <string>

namespace facebook::react {

class FFmpegKitExtendedImpl
    : public NativeFFmpegKitExtendedCxxSpec<FFmpegKitExtendedImpl> {
 public:
  explicit FFmpegKitExtendedImpl(std::shared_ptr<CallInvoker> jsInvoker);

  void initialize(jsi::Runtime &rt);
  std::string getBuildStamp(jsi::Runtime &rt);

  double createFFmpegSession(jsi::Runtime &rt, std::string command);
  double createFFprobeSession(jsi::Runtime &rt, std::string command);
  double createFFplaySession(jsi::Runtime &rt, std::string command);
  double createMediaInformationSession(jsi::Runtime &rt, std::string command);
  void executeSessionAsync(jsi::Runtime &rt, double sessionId, double timeoutMs);
  void cancelSession(jsi::Runtime &rt, double sessionId);

  std::string getSessionJson(jsi::Runtime &rt, double sessionId);
  void releaseSessionHandle(jsi::Runtime &rt, double sessionId);
  std::string getSessionsJson(jsi::Runtime &rt, std::string kind);
  std::string getLastSessionJson(jsi::Runtime &rt, std::string kind);
  std::string getLogsJson(jsi::Runtime &rt, double sessionId, double fromIndex);
  std::string getStatisticsJson(jsi::Runtime &rt, double sessionId, double fromIndex);
  std::string getMediaInformationJson(jsi::Runtime &rt, double sessionId);

  void ffplayStart(jsi::Runtime &rt, double sessionId);
  void ffplayPause(jsi::Runtime &rt, double sessionId);
  void ffplayResume(jsi::Runtime &rt, double sessionId);
  void ffplayStop(jsi::Runtime &rt, double sessionId);
  void ffplaySeek(jsi::Runtime &rt, double sessionId, double seconds);
  double ffplayGetPosition(jsi::Runtime &rt, double sessionId);
  void ffplaySetPosition(jsi::Runtime &rt, double sessionId, double seconds);
  double ffplayGetDuration(jsi::Runtime &rt, double sessionId);
  std::int32_t ffplayGetVideoWidth(jsi::Runtime &rt, double sessionId);
  std::int32_t ffplayGetVideoHeight(jsi::Runtime &rt, double sessionId);
  bool ffplayIsPlaying(jsi::Runtime &rt, double sessionId);
  bool ffplayIsPaused(jsi::Runtime &rt, double sessionId);
  void ffplaySetVolume(jsi::Runtime &rt, double sessionId, double volume);
  double ffplayGetVolume(jsi::Runtime &rt, double sessionId);
  bool ffplayHasVideoStream(jsi::Runtime &rt, std::string path);

  void enableRedirection(jsi::Runtime &rt);
  void disableRedirection(jsi::Runtime &rt);
  void setLogLevel(jsi::Runtime &rt, std::int32_t level);
  std::int32_t getLogLevel(jsi::Runtime &rt);
  std::string logLevelToString(jsi::Runtime &rt, std::int32_t level);
  void setFontDirectory(jsi::Runtime &rt, std::string path, std::string mappingJson);
  void setEnvironmentVariable(jsi::Runtime &rt, std::string name, std::string value);
  void ignoreSignal(jsi::Runtime &rt, std::int32_t signal);
  void setAudioOutputDevice(jsi::Runtime &rt, std::string deviceName);
  std::string listAudioOutputDevices(jsi::Runtime &rt);

  std::string getFFmpegVersion(jsi::Runtime &rt);
  std::string getFFmpegArchitecture(jsi::Runtime &rt);
  std::string getVersion(jsi::Runtime &rt);
  std::string getPackageName(jsi::Runtime &rt);
  std::string getExternalLibraries(jsi::Runtime &rt);
  std::string getBundleType(jsi::Runtime &rt);
  bool isGpl(jsi::Runtime &rt);
  bool isNonfree(jsi::Runtime &rt);
  std::string getRegisteredCodecs(jsi::Runtime &rt);
  std::string getRegisteredEncoders(jsi::Runtime &rt);
  std::string getRegisteredDecoders(jsi::Runtime &rt);
  std::string getRegisteredMuxers(jsi::Runtime &rt);
  std::string getRegisteredDemuxers(jsi::Runtime &rt);
  std::string getRegisteredFilters(jsi::Runtime &rt);
  std::string getRegisteredProtocols(jsi::Runtime &rt);
  std::string getRegisteredBitstreamFilters(jsi::Runtime &rt);
  std::string getBuildConfiguration(jsi::Runtime &rt);
  std::string getBuildDate(jsi::Runtime &rt);

  void setSessionHistorySize(jsi::Runtime &rt, double size);
  double getSessionHistorySize(jsi::Runtime &rt);
  void clearSessions(jsi::Runtime &rt);
  std::string registerNewFFmpegPipe(jsi::Runtime &rt);
  void closeFFmpegPipe(jsi::Runtime &rt, std::string path);
  double messagesInTransmit(jsi::Runtime &rt, double sessionId);

  void enableDebugLog(jsi::Runtime &rt, double sessionId);
  void disableDebugLog(jsi::Runtime &rt, double sessionId);
  bool isDebugLogEnabled(jsi::Runtime &rt, double sessionId);
  std::string getDebugLog(jsi::Runtime &rt, double sessionId);
  void clearDebugLog(jsi::Runtime &rt, double sessionId);
};

} // namespace facebook::react
