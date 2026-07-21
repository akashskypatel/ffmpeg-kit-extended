#pragma once

#include <cstdint>
#include <string>

namespace ffmpegkit::bridge {

void initialize();
std::string getBuildStamp();

double createFFmpegSession(const std::string &command);
double createFFprobeSession(const std::string &command);
double createFFplaySession(const std::string &command);
double createMediaInformationSession(const std::string &command);
void executeSessionAsync(double sessionId, double timeoutMs);
void cancelSession(double sessionId);

std::string getSessionJson(double sessionId);
void releaseSessionHandle(double sessionId);
std::string getSessionsJson(const std::string &kind);
std::string getLastSessionJson(const std::string &kind);
std::string getLogsJson(double sessionId, double fromIndex);
std::string getStatisticsJson(double sessionId, double fromIndex);
std::string getMediaInformationJson(double sessionId);

void ffplayStart(double sessionId);
void ffplayPause(double sessionId);
void ffplayResume(double sessionId);
void ffplayStop(double sessionId);
void ffplaySeek(double sessionId, double seconds);
double ffplayGetPosition(double sessionId);
void ffplaySetPosition(double sessionId, double seconds);
double ffplayGetDuration(double sessionId);
std::int32_t ffplayGetVideoWidth(double sessionId);
std::int32_t ffplayGetVideoHeight(double sessionId);
bool ffplayIsPlaying(double sessionId);
bool ffplayIsPaused(double sessionId);
void ffplaySetVolume(double sessionId, double volume);
double ffplayGetVolume(double sessionId);
bool ffplayHasVideoStream(const std::string &path);

void enableRedirection();
void disableRedirection();
void setLogLevel(std::int32_t level);
std::int32_t getLogLevel();
std::string logLevelToString(std::int32_t level);
void setFontDirectory(const std::string &path, const std::string &mappingJson);
void setEnvironmentVariable(const std::string &name, const std::string &value);
void ignoreSignal(std::int32_t signal);
void setAudioOutputDevice(const std::string &deviceName);
std::string listAudioOutputDevices();

std::string getFFmpegVersion();
std::string getFFmpegArchitecture();
std::string getVersion();
std::string getPackageName();
std::string getExternalLibraries();
std::string getBundleType();
bool isGpl();
bool isNonfree();
std::string getRegisteredCodecs();
std::string getRegisteredEncoders();
std::string getRegisteredDecoders();
std::string getRegisteredMuxers();
std::string getRegisteredDemuxers();
std::string getRegisteredFilters();
std::string getRegisteredProtocols();
std::string getRegisteredBitstreamFilters();
std::string getBuildConfiguration();
std::string getBuildDate();

void setSessionHistorySize(double size);
double getSessionHistorySize();
void clearSessions();
std::string registerNewFFmpegPipe();
void closeFFmpegPipe(const std::string &path);
double messagesInTransmit(double sessionId);

void enableDebugLog(double sessionId);
void disableDebugLog(double sessionId);
bool isDebugLogEnabled(double sessionId);
std::string getDebugLog(double sessionId);
void clearDebugLog(double sessionId);

} // namespace ffmpegkit::bridge
