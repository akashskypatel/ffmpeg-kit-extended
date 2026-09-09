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
  void cancelSession(SessionHandle handle) => throw _notMigrated();

  @override
  void releaseSession(SessionHandle handle) => throw _notMigrated();
}
