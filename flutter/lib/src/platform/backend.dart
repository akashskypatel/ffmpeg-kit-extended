/// Platform-neutral operations needed by the shared FFmpegKit API.
///
/// This file intentionally has no native or JavaScript imports. Platform
/// backends wrap the generated bindings and expose ordinary Dart values here.
final class SessionHandle {
  final Object value;

  const SessionHandle(this.value);
}

abstract interface class FFmpegKitBackend {
  Future<void> initialize();

  bool get initialized;

  void requireInitialized();

  SessionHandle createFFmpegSession(String command);

  SessionHandle createFFmpegSessionFromArguments(List<String> arguments);

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

  void cancelSession(SessionHandle handle);

  void releaseSession(SessionHandle handle);
}
