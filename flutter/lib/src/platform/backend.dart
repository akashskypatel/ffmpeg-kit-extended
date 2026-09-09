/// Platform-neutral operations needed by the shared FFmpegKit API.
///
/// This file intentionally has no native or JavaScript imports. Platform
/// backends wrap the generated bindings and expose ordinary Dart values here.
final class SessionHandle {
  final Object value;

  const SessionHandle(this.value);
}

final class StatisticsSnapshot {
  final int timeElapsed;
  final int time;
  final int size;
  final double bitrate;
  final double speed;
  final int videoFrameNumber;
  final double videoFps;
  final double videoQuality;
  final int dupFrames;
  final int dropFrames;

  const StatisticsSnapshot({
    required this.timeElapsed,
    required this.time,
    required this.size,
    required this.bitrate,
    required this.speed,
    required this.videoFrameNumber,
    required this.videoFps,
    required this.videoQuality,
    required this.dupFrames,
    required this.dropFrames,
  });
}

final class PackageInformationSnapshot {
  final String ffmpegVersion;
  final String architecture;
  final String version;
  final String packageName;
  final String externalLibraries;
  final String bundleType;
  final bool isGpl;
  final bool isNonfree;
  final String registeredCodecs;
  final String registeredEncoders;
  final String registeredDecoders;
  final String registeredMuxers;
  final String registeredDemuxers;
  final String registeredFilters;
  final String registeredProtocols;
  final String registeredBitstreamFilters;
  final String buildConfiguration;
  final String buildDate;

  const PackageInformationSnapshot({
    required this.ffmpegVersion,
    required this.architecture,
    required this.version,
    required this.packageName,
    required this.externalLibraries,
    required this.bundleType,
    required this.isGpl,
    required this.isNonfree,
    required this.registeredCodecs,
    required this.registeredEncoders,
    required this.registeredDecoders,
    required this.registeredMuxers,
    required this.registeredDemuxers,
    required this.registeredFilters,
    required this.registeredProtocols,
    required this.registeredBitstreamFilters,
    required this.buildConfiguration,
    required this.buildDate,
  });
}

final class ChapterInformationSnapshot {
  final int id;
  final String? timeBase;
  final int start;
  final String? startTime;
  final int end;
  final String? endTime;
  final String? tagsJson;
  final String? allPropertiesJson;

  const ChapterInformationSnapshot({
    required this.id,
    required this.timeBase,
    required this.start,
    required this.startTime,
    required this.end,
    required this.endTime,
    required this.tagsJson,
    required this.allPropertiesJson,
  });
}

final class StreamInformationSnapshot {
  final int index;
  final String? type;
  final String? codec;
  final String? codecLong;
  final String? format;
  final int width;
  final int height;
  final String? bitrate;
  final String? sampleRate;
  final String? sampleFormat;
  final String? channelLayout;
  final String? sampleAspectRatio;
  final String? displayAspectRatio;
  final String? averageFrameRate;
  final String? realFrameRate;
  final String? timeBase;
  final String? codecTimeBase;
  final String? tagsJson;
  final String? allPropertiesJson;

  const StreamInformationSnapshot({
    required this.index,
    required this.type,
    required this.codec,
    required this.codecLong,
    required this.format,
    required this.width,
    required this.height,
    required this.bitrate,
    required this.sampleRate,
    required this.sampleFormat,
    required this.channelLayout,
    required this.sampleAspectRatio,
    required this.displayAspectRatio,
    required this.averageFrameRate,
    required this.realFrameRate,
    required this.timeBase,
    required this.codecTimeBase,
    required this.tagsJson,
    required this.allPropertiesJson,
  });
}

final class MediaInformationSnapshot {
  final String? filename;
  final String? format;
  final String? longFormat;
  final String? duration;
  final String? startTime;
  final String? bitrate;
  final String? size;
  final String? tagsJson;
  final String? allPropertiesJson;
  final List<StreamInformationSnapshot> streams;
  final List<ChapterInformationSnapshot> chapters;

  const MediaInformationSnapshot({
    required this.filename,
    required this.format,
    required this.longFormat,
    required this.duration,
    required this.startTime,
    required this.bitrate,
    required this.size,
    required this.tagsJson,
    required this.allPropertiesJson,
    required this.streams,
    required this.chapters,
  });
}

abstract interface class FFmpegKitBackend {
  Future<void> initialize();

  bool get initialized;

  void requireInitialized();

  SessionHandle createFFmpegSession(String command);

  SessionHandle createFFmpegSessionFromArguments(List<String> arguments);

  SessionHandle createFFprobeSession(String command);

  SessionHandle createFFprobeSessionFromArguments(List<String> arguments);

  SessionHandle createFFplaySession(String command);

  SessionHandle createFFplaySessionFromArguments(List<String> arguments);

  SessionHandle createMediaInformationSession(String command);

  SessionHandle createMediaInformationSessionFromArguments(
    List<String> arguments,
  );

  void configureFFmpegCallbacks();

  void enableFFmpegLogCallback();

  void configureFFprobeCallbacks();

  void configureMediaInformationCallbacks();

  void enableFFprobeLogCallback();

  void executeFFmpegSession(SessionHandle handle);

  void executeFFmpegSessionAsync(SessionHandle handle);

  void executeFFprobeSession(SessionHandle handle);

  void executeFFprobeSessionAsync(SessionHandle handle);

  void executeFFplaySession(SessionHandle handle, int timeout);

  void executeFFplaySessionAsync(SessionHandle handle, int timeout);

  void startFFplaySession(SessionHandle handle);

  void pauseFFplaySession(SessionHandle handle);

  void resumeFFplaySession(SessionHandle handle);

  void stopFFplaySession(SessionHandle handle);

  void closeFFplaySession(SessionHandle handle);

  void seekFFplaySession(SessionHandle handle, double seconds);

  void setFFplayPosition(SessionHandle handle, double seconds);

  double getFFplayPosition(SessionHandle handle);

  double getFFplayDuration(SessionHandle handle);

  bool isFFplayPlaying(SessionHandle handle);

  bool isFFplayPaused(SessionHandle handle);

  void setFFplayVolume(SessionHandle handle, double volume);

  double getFFplayVolume(SessionHandle handle);

  int getFFplayVideoWidth(SessionHandle handle);

  int getFFplayVideoHeight(SessionHandle handle);

  void executeMediaInformationSession(SessionHandle handle, int timeout);

  void executeMediaInformationSessionAsync(SessionHandle handle, int timeout);

  MediaInformationSnapshot? getMediaInformation(SessionHandle handle);

  int getSessionState(SessionHandle handle);

  int getReturnCode(SessionHandle handle);

  int getSessionId(SessionHandle handle);

  int getCreateTime(SessionHandle handle);

  int getStartTime(SessionHandle handle);

  int getEndTime(SessionHandle handle);

  int getDuration(SessionHandle handle);

  String? getCommand(SessionHandle handle);

  String? getOutput(SessionHandle handle);

  String? getLogsAsString(SessionHandle handle);

  String? getFailStackTrace(SessionHandle handle);

  int getLogsCount(SessionHandle handle);

  String? getLogAt(SessionHandle handle, int index);

  int getLogLevelAt(SessionHandle handle, int index);

  int getStatisticsCount(SessionHandle handle);

  StatisticsSnapshot? getStatisticsAt(SessionHandle handle, int index);

  void cancelSession(SessionHandle handle);

  void releaseSession(SessionHandle handle);

  bool isFFmpegSession(SessionHandle handle);

  bool isFFplaySession(SessionHandle handle);

  bool isFFprobeSession(SessionHandle handle);

  bool isMediaInformationSession(SessionHandle handle);

  void enableDebugLog(SessionHandle handle);

  void disableDebugLog(SessionHandle handle);

  bool isDebugLogEnabled(SessionHandle handle);

  String? getDebugLog(SessionHandle handle);

  void clearDebugLog(SessionHandle handle);

  PackageInformationSnapshot getPackageInformation();

  void setLogLevel(int level);

  int getLogLevel();

  void enableRedirection();

  void disableRedirection();

  void setFontDirectory(String path, {String? mapping});

  void setAudioOutputDevice(String deviceName);

  String listAudioOutputDevices();

  void setEnvironmentVariable(String name, String value);

  void ignoreSignal(int signal);

  void setSessionHistorySize(int size);

  int getSessionHistorySize();

  List<SessionHandle> getSessions();

  List<SessionHandle> getFFmpegSessions();

  List<SessionHandle> getFFprobeSessions();

  List<SessionHandle> getFFplaySessions();

  List<SessionHandle> getMediaInformationSessions();

  SessionHandle? getSessionById(int sessionId);

  SessionHandle? getLastSession();

  SessionHandle? getLastFFmpegSession();

  SessionHandle? getLastFFprobeSession();

  SessionHandle? getLastFFplaySession();

  SessionHandle? getLastMediaInformationSession();

  SessionHandle? getLastCompletedSession();

  void clearSessions();

  void configureLogCallback();

  void configureStatisticsCallback();

  void configureFFmpegSessionCompleteCallback();

  void configureFFprobeSessionCompleteCallback();

  void configureFFplaySessionCompleteCallback();

  void configureMediaInformationSessionCompleteCallback();

  String? registerNewFFmpegPipe();

  void closeFFmpegPipe(String pipePath);

  void setFontDirectoryList(List<String> directories, {String? mapping});

  String sessionStateToString(int state);

  String? logLevelToString(int level);

  List<String> parseArguments(String command);

  String argumentsToString(List<String> arguments);

  int messagesInTransmit(int sessionId);
}
