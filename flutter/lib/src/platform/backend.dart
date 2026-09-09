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

abstract interface class FFmpegKitBackend {
  Future<void> initialize();

  bool get initialized;

  void requireInitialized();

  SessionHandle createFFmpegSession(String command);

  SessionHandle createFFmpegSessionFromArguments(List<String> arguments);

  void configureFFmpegCallbacks();

  void enableFFmpegLogCallback();

  void executeFFmpegSession(SessionHandle handle);

  void executeFFmpegSessionAsync(SessionHandle handle);

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
