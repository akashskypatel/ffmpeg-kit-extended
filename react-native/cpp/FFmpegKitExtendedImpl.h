#pragma once

#include <FFmpegKitExtendedSpecJSI.h>

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace facebook::react {

// RN 0.81 Codegen emits the event-object converter beside the generated
// struct, but does not register it with the generic bridging trait used by
// emitOnLogEvent. Register the generated converter at this module boundary so
// the consumer-owned Codegen header remains the source of the event shape.
template <typename P0, typename P1, typename P2, typename P3>
struct Bridging<NativeFFmpegKitExtendedLogEvent<P0, P1, P2, P3>>
    : NativeFFmpegKitExtendedLogEventBridging<
          NativeFFmpegKitExtendedLogEvent<P0, P1, P2, P3>> {};

struct LogBridgeState;

class FFmpegKitExtendedImpl
    : public NativeFFmpegKitExtendedCxxSpec<FFmpegKitExtendedImpl>,
      public std::enable_shared_from_this<FFmpegKitExtendedImpl> {
 public:
  explicit FFmpegKitExtendedImpl(std::shared_ptr<CallInvoker> jsInvoker);
  ~FFmpegKitExtendedImpl();

  /** Emits one copied v2 event on the React Native JS event emitter. */
  void emitLogEvent(double sessionId,
                    double sequence,
                    std::int32_t level,
                    std::string message);

  void initialize(jsi::Runtime &rt);
  std::string getBuildStamp(jsi::Runtime &rt);

  double createFFmpegSession(jsi::Runtime &rt, std::string command);
  double createFFmpegSessionFromArguments(jsi::Runtime &rt, std::vector<std::string> arguments);
  double createFFprobeSession(jsi::Runtime &rt, std::string command);
  double createFFplaySession(jsi::Runtime &rt, std::string command);
  double createFFplaySessionFromArguments(jsi::Runtime &rt, std::vector<std::string> arguments);
  double createMediaInformationSession(jsi::Runtime &rt, std::string command);
  double createMediaInformationSessionFromPath(jsi::Runtime &rt, std::string path);
  void executeSessionAsync(jsi::Runtime &rt, double sessionId, double timeoutMs);
  void cancelSession(jsi::Runtime &rt, double sessionId);
  void installLogBridge(jsi::Runtime &rt);
  void uninstallLogBridge(jsi::Runtime &rt);

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

 private:
  std::shared_ptr<CallInvoker> jsInvoker_;
  std::shared_ptr<LogBridgeState> activeLogBridge_;
};

} // namespace facebook::react
