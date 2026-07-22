#pragma once

#include "pch.h"
#include "resource.h"

#include "codegen/NativeFFmpegKitExtendedSpec.g.h"
#include "NativeModules.h"

#include <cstdint>
#include <string>

namespace winrt::FFmpegKitExtended {

REACT_MODULE(FFmpegKitExtended)
struct FFmpegKitExtended {
  using ModuleSpec = FFmpegKitExtendedCodegen::FFmpegKitExtendedSpec;

  REACT_METHOD(initialize)
  void initialize() noexcept;

  REACT_SYNC_METHOD(getBuildStamp)
  std::string getBuildStamp() noexcept;

  REACT_SYNC_METHOD(createFFmpegSession)
  double createFFmpegSession(std::string command) noexcept;

  REACT_SYNC_METHOD(createFFprobeSession)
  double createFFprobeSession(std::string command) noexcept;

  REACT_SYNC_METHOD(createFFplaySession)
  double createFFplaySession(std::string command) noexcept;

  REACT_SYNC_METHOD(createMediaInformationSession)
  double createMediaInformationSession(std::string command) noexcept;

  REACT_METHOD(executeSessionAsync)
  void executeSessionAsync(double sessionId, double timeoutMs) noexcept;

  REACT_METHOD(cancelSession)
  void cancelSession(double sessionId) noexcept;

  REACT_SYNC_METHOD(getSessionJson)
  std::string getSessionJson(double sessionId) noexcept;

  REACT_METHOD(releaseSessionHandle)
  void releaseSessionHandle(double sessionId) noexcept;

  REACT_SYNC_METHOD(getSessionsJson)
  std::string getSessionsJson(std::string kind) noexcept;

  REACT_SYNC_METHOD(getLastSessionJson)
  std::string getLastSessionJson(std::string kind) noexcept;

  REACT_SYNC_METHOD(getLogsJson)
  std::string getLogsJson(double sessionId, double fromIndex) noexcept;

  REACT_SYNC_METHOD(getStatisticsJson)
  std::string getStatisticsJson(double sessionId, double fromIndex) noexcept;

  REACT_SYNC_METHOD(getMediaInformationJson)
  std::string getMediaInformationJson(double sessionId) noexcept;

  REACT_METHOD(ffplayStart)
  void ffplayStart(double sessionId) noexcept;

  REACT_METHOD(ffplayPause)
  void ffplayPause(double sessionId) noexcept;

  REACT_METHOD(ffplayResume)
  void ffplayResume(double sessionId) noexcept;

  REACT_METHOD(ffplayStop)
  void ffplayStop(double sessionId) noexcept;

  REACT_METHOD(ffplaySeek)
  void ffplaySeek(double sessionId, double seconds) noexcept;

  REACT_SYNC_METHOD(ffplayGetPosition)
  double ffplayGetPosition(double sessionId) noexcept;

  REACT_METHOD(ffplaySetPosition)
  void ffplaySetPosition(double sessionId, double seconds) noexcept;

  REACT_SYNC_METHOD(ffplayGetDuration)
  double ffplayGetDuration(double sessionId) noexcept;

  REACT_SYNC_METHOD(ffplayGetVideoWidth)
  std::int32_t ffplayGetVideoWidth(double sessionId) noexcept;

  REACT_SYNC_METHOD(ffplayGetVideoHeight)
  std::int32_t ffplayGetVideoHeight(double sessionId) noexcept;

  REACT_SYNC_METHOD(ffplayIsPlaying)
  bool ffplayIsPlaying(double sessionId) noexcept;

  REACT_SYNC_METHOD(ffplayIsPaused)
  bool ffplayIsPaused(double sessionId) noexcept;

  REACT_METHOD(ffplaySetVolume)
  void ffplaySetVolume(double sessionId, double volume) noexcept;

  REACT_SYNC_METHOD(ffplayGetVolume)
  double ffplayGetVolume(double sessionId) noexcept;

  REACT_SYNC_METHOD(ffplayHasVideoStream)
  bool ffplayHasVideoStream(std::string path) noexcept;

  REACT_METHOD(enableRedirection)
  void enableRedirection() noexcept;

  REACT_METHOD(disableRedirection)
  void disableRedirection() noexcept;

  REACT_METHOD(setLogLevel)
  void setLogLevel(std::int32_t level) noexcept;

  REACT_SYNC_METHOD(getLogLevel)
  std::int32_t getLogLevel() noexcept;

  REACT_SYNC_METHOD(logLevelToString)
  std::string logLevelToString(std::int32_t level) noexcept;

  REACT_METHOD(setFontDirectory)
  void setFontDirectory(std::string path, std::string mappingJson) noexcept;

  REACT_METHOD(setEnvironmentVariable)
  void setEnvironmentVariable(std::string name, std::string value) noexcept;

  REACT_METHOD(ignoreSignal)
  void ignoreSignal(std::int32_t signal) noexcept;

  REACT_METHOD(setAudioOutputDevice)
  void setAudioOutputDevice(std::string deviceName) noexcept;

  REACT_SYNC_METHOD(listAudioOutputDevices)
  std::string listAudioOutputDevices() noexcept;

  REACT_SYNC_METHOD(getFFmpegVersion)
  std::string getFFmpegVersion() noexcept;

  REACT_SYNC_METHOD(getFFmpegArchitecture)
  std::string getFFmpegArchitecture() noexcept;

  REACT_SYNC_METHOD(getVersion)
  std::string getVersion() noexcept;

  REACT_SYNC_METHOD(getPackageName)
  std::string getPackageName() noexcept;

  REACT_SYNC_METHOD(getExternalLibraries)
  std::string getExternalLibraries() noexcept;

  REACT_SYNC_METHOD(getBundleType)
  std::string getBundleType() noexcept;

  REACT_SYNC_METHOD(isGpl)
  bool isGpl() noexcept;

  REACT_SYNC_METHOD(isNonfree)
  bool isNonfree() noexcept;

  REACT_SYNC_METHOD(getRegisteredCodecs)
  std::string getRegisteredCodecs() noexcept;

  REACT_SYNC_METHOD(getRegisteredEncoders)
  std::string getRegisteredEncoders() noexcept;

  REACT_SYNC_METHOD(getRegisteredDecoders)
  std::string getRegisteredDecoders() noexcept;

  REACT_SYNC_METHOD(getRegisteredMuxers)
  std::string getRegisteredMuxers() noexcept;

  REACT_SYNC_METHOD(getRegisteredDemuxers)
  std::string getRegisteredDemuxers() noexcept;

  REACT_SYNC_METHOD(getRegisteredFilters)
  std::string getRegisteredFilters() noexcept;

  REACT_SYNC_METHOD(getRegisteredProtocols)
  std::string getRegisteredProtocols() noexcept;

  REACT_SYNC_METHOD(getRegisteredBitstreamFilters)
  std::string getRegisteredBitstreamFilters() noexcept;

  REACT_SYNC_METHOD(getBuildConfiguration)
  std::string getBuildConfiguration() noexcept;

  REACT_SYNC_METHOD(getBuildDate)
  std::string getBuildDate() noexcept;

  REACT_METHOD(setSessionHistorySize)
  void setSessionHistorySize(double size) noexcept;

  REACT_SYNC_METHOD(getSessionHistorySize)
  double getSessionHistorySize() noexcept;

  REACT_METHOD(clearSessions)
  void clearSessions() noexcept;

  REACT_SYNC_METHOD(registerNewFFmpegPipe)
  std::string registerNewFFmpegPipe() noexcept;

  REACT_METHOD(closeFFmpegPipe)
  void closeFFmpegPipe(std::string path) noexcept;

  REACT_SYNC_METHOD(messagesInTransmit)
  double messagesInTransmit(double sessionId) noexcept;

  REACT_METHOD(enableDebugLog)
  void enableDebugLog(double sessionId) noexcept;

  REACT_METHOD(disableDebugLog)
  void disableDebugLog(double sessionId) noexcept;

  REACT_SYNC_METHOD(isDebugLogEnabled)
  bool isDebugLogEnabled(double sessionId) noexcept;

  REACT_SYNC_METHOD(getDebugLog)
  std::string getDebugLog(double sessionId) noexcept;

  REACT_METHOD(clearDebugLog)
  void clearDebugLog(double sessionId) noexcept;
};

} // namespace winrt::FFmpegKitExtended
