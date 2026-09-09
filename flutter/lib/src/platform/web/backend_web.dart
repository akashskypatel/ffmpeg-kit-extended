import '../backend.dart';

FFmpegKitBackend createPlatformBackend() => WebFFmpegKitBackend();

/// Initial Web backend seam.
///
/// Web execution remains owned by the existing Web implementation until a
/// later packet migrates it. Keeping this adapter compile-safe lets shared
/// code select a backend without importing FFI or exposing JS pointer types.
final class WebFFmpegKitBackend implements FFmpegKitBackend {
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  bool get initialized => _initialized;

  @override
  void requireInitialized() {
    if (!_initialized) {
      throw StateError(
        'FFmpegKit is not initialized. Call FFmpegKitExtended.initialize() '
        'before using the backend.',
      );
    }
  }

  UnsupportedError _notMigrated() => UnsupportedError(
    'The Web FFmpegKit backend operation is not migrated yet.',
  );

  @override
  SessionHandle createFFmpegSession(String command) => throw _notMigrated();

  @override
  SessionHandle createFFmpegSessionFromArguments(List<String> arguments) =>
      throw _notMigrated();

  @override
  SessionHandle createFFprobeSession(String command) => throw _notMigrated();

  @override
  SessionHandle createFFprobeSessionFromArguments(List<String> arguments) =>
      throw _notMigrated();

  @override
  SessionHandle createMediaInformationSession(String command) =>
      throw _notMigrated();

  @override
  SessionHandle createMediaInformationSessionFromArguments(
    List<String> arguments,
  ) => throw _notMigrated();

  @override
  void configureFFmpegCallbacks() => throw _notMigrated();

  @override
  void enableFFmpegLogCallback() => throw _notMigrated();

  @override
  void configureFFprobeCallbacks() => throw _notMigrated();

  @override
  void configureMediaInformationCallbacks() => throw _notMigrated();

  @override
  void enableFFprobeLogCallback() => throw _notMigrated();

  @override
  void executeFFmpegSession(SessionHandle handle) => throw _notMigrated();

  @override
  void executeFFmpegSessionAsync(SessionHandle handle) => throw _notMigrated();

  @override
  void executeFFprobeSession(SessionHandle handle) => throw _notMigrated();

  @override
  void executeFFprobeSessionAsync(SessionHandle handle) => throw _notMigrated();

  @override
  void executeMediaInformationSession(SessionHandle handle, int timeout) =>
      throw _notMigrated();

  @override
  void executeMediaInformationSessionAsync(SessionHandle handle, int timeout) =>
      throw _notMigrated();

  @override
  MediaInformationSnapshot? getMediaInformation(SessionHandle handle) =>
      throw _notMigrated();

  @override
  PackageInformationSnapshot getPackageInformation() => throw _notMigrated();

  @override
  void setLogLevel(int level) => throw _notMigrated();

  @override
  int getLogLevel() => throw _notMigrated();

  @override
  void enableRedirection() => throw _notMigrated();

  @override
  void disableRedirection() => throw _notMigrated();

  @override
  void setFontDirectory(String path, {String? mapping}) => throw _notMigrated();

  @override
  void setAudioOutputDevice(String deviceName) => throw _notMigrated();

  @override
  String listAudioOutputDevices() => throw _notMigrated();

  @override
  void setEnvironmentVariable(String name, String value) =>
      throw _notMigrated();

  @override
  void ignoreSignal(int signal) => throw _notMigrated();

  @override
  void setSessionHistorySize(int size) => throw _notMigrated();

  @override
  int getSessionHistorySize() => throw _notMigrated();

  @override
  List<SessionHandle> getSessions() => throw _notMigrated();

  @override
  List<SessionHandle> getFFmpegSessions() => throw _notMigrated();

  @override
  List<SessionHandle> getFFprobeSessions() => throw _notMigrated();

  @override
  List<SessionHandle> getFFplaySessions() => throw _notMigrated();

  @override
  List<SessionHandle> getMediaInformationSessions() => throw _notMigrated();

  @override
  SessionHandle? getSessionById(int sessionId) => throw _notMigrated();

  @override
  SessionHandle? getLastSession() => throw _notMigrated();

  @override
  SessionHandle? getLastFFmpegSession() => throw _notMigrated();

  @override
  SessionHandle? getLastFFprobeSession() => throw _notMigrated();

  @override
  SessionHandle? getLastFFplaySession() => throw _notMigrated();

  @override
  SessionHandle? getLastMediaInformationSession() => throw _notMigrated();

  @override
  SessionHandle? getLastCompletedSession() => throw _notMigrated();

  @override
  void clearSessions() => throw _notMigrated();

  @override
  void configureLogCallback() => throw _notMigrated();

  @override
  void configureStatisticsCallback() => throw _notMigrated();

  @override
  void configureFFmpegSessionCompleteCallback() => throw _notMigrated();

  @override
  void configureFFprobeSessionCompleteCallback() => throw _notMigrated();

  @override
  void configureFFplaySessionCompleteCallback() => throw _notMigrated();

  @override
  void configureMediaInformationSessionCompleteCallback() =>
      throw _notMigrated();

  @override
  String? registerNewFFmpegPipe() => throw _notMigrated();

  @override
  void closeFFmpegPipe(String pipePath) => throw _notMigrated();

  @override
  void setFontDirectoryList(List<String> directories, {String? mapping}) =>
      throw _notMigrated();

  @override
  String sessionStateToString(int state) => throw _notMigrated();

  @override
  String? logLevelToString(int level) => throw _notMigrated();

  @override
  List<String> parseArguments(String command) => throw _notMigrated();

  @override
  String argumentsToString(List<String> arguments) => throw _notMigrated();

  @override
  int messagesInTransmit(int sessionId) => throw _notMigrated();

  @override
  int getSessionState(SessionHandle handle) => throw _notMigrated();

  @override
  int getReturnCode(SessionHandle handle) => throw _notMigrated();

  @override
  int getSessionId(SessionHandle handle) => throw _notMigrated();

  @override
  int getCreateTime(SessionHandle handle) => throw _notMigrated();

  @override
  int getStartTime(SessionHandle handle) => throw _notMigrated();

  @override
  int getEndTime(SessionHandle handle) => throw _notMigrated();

  @override
  int getDuration(SessionHandle handle) => throw _notMigrated();

  @override
  String? getCommand(SessionHandle handle) => throw _notMigrated();

  @override
  String? getOutput(SessionHandle handle) => throw _notMigrated();

  @override
  String? getLogsAsString(SessionHandle handle) => throw _notMigrated();

  @override
  String? getFailStackTrace(SessionHandle handle) => throw _notMigrated();

  @override
  int getLogsCount(SessionHandle handle) => throw _notMigrated();

  @override
  String? getLogAt(SessionHandle handle, int index) => throw _notMigrated();

  @override
  int getLogLevelAt(SessionHandle handle, int index) => throw _notMigrated();

  @override
  int getStatisticsCount(SessionHandle handle) => throw _notMigrated();

  @override
  StatisticsSnapshot? getStatisticsAt(SessionHandle handle, int index) =>
      throw _notMigrated();

  @override
  void cancelSession(SessionHandle handle) => throw _notMigrated();

  @override
  void releaseSession(SessionHandle handle) => throw _notMigrated();

  @override
  bool isFFmpegSession(SessionHandle handle) => throw _notMigrated();

  @override
  bool isFFplaySession(SessionHandle handle) => throw _notMigrated();

  @override
  bool isFFprobeSession(SessionHandle handle) => throw _notMigrated();

  @override
  bool isMediaInformationSession(SessionHandle handle) => throw _notMigrated();

  @override
  void enableDebugLog(SessionHandle handle) => throw _notMigrated();

  @override
  void disableDebugLog(SessionHandle handle) => throw _notMigrated();

  @override
  bool isDebugLogEnabled(SessionHandle handle) => throw _notMigrated();

  @override
  String? getDebugLog(SessionHandle handle) => throw _notMigrated();

  @override
  void clearDebugLog(SessionHandle handle) => throw _notMigrated();
}
