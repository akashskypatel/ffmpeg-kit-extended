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
}
