/*
 * FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
 * Copyright (C) 2026 Akash Patel
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

import 'dart:async';
import 'dart:developer';

import 'package:meta/meta.dart';

import '../ffmpeg_kit_extended_flutter.dart'
    show
        FFmpegSession,
        FFplaySession,
        FFprobeSession,
        MediaInformationSession,
        FFmpegKitExtended;
import 'log.dart';
import 'platform/backend.dart';
import 'platform/backend_selector.dart';
import 'platform/session_finalizer.dart';
import 'statistics.dart';

typedef SessionExecutionErrorCallback =
    void Function(Object error, StackTrace stackTrace);

// ---------------------------------------------------------------------------
// Return-code sentinel values
// ---------------------------------------------------------------------------

/// Well-known exit codes returned by the native layer.
enum ReturnCode {
  success(0),
  cancel(255);

  final int value;
  const ReturnCode(this.value);

  /// Returns `true` if [code] represents successful completion.
  static bool isSuccess(int code) => code == success.value;

  /// Returns `true` if [code] represents a user-requested cancellation.
  static bool isCancel(int code) => code == cancel.value;
}

// ---------------------------------------------------------------------------
// Session lifecycle state
// ---------------------------------------------------------------------------

/// Lifecycle state of an FFmpegKit session
enum SessionState {
  created(0),
  running(1),
  completed(2),
  failed(3);

  final int value;
  const SessionState(this.value);

  /// Maps an integer value from the C layer to a [SessionState].
  ///
  /// Falls back to [SessionState.failed] for any unrecognised value so that
  /// callers always receive a valid enum member rather than a runtime error.
  static SessionState fromValue(int value) => SessionState.values.firstWhere(
    (e) => e.value == value,
    orElse: () => SessionState.failed,
  );
}

// ---------------------------------------------------------------------------
// Session base class
// ---------------------------------------------------------------------------

/// Base class for all FFmpegKit sessions.
///
/// Provides common access to session state, return code, output, logs,
/// statistics, timing, and debug utilities.  All concrete session types
/// ([FFmpegSession], [FFprobeSession], [FFplaySession],
/// [MediaInformationSession]) extend this class.
///
/// ### Native handle lifetime
/// Each session owns an opaque native C++ object exposed as a
/// [SessionHandle] ([handle]). A platform-specific finalizer is attached at
/// construction time, when supported, to release abandoned session resources.
///
/// ### Testing without a native library
/// Use the protected [Session.noFinalizer] constructor in test subclasses
/// or mock factories.  This sets an instance-level flag that suppresses
/// finalizer registration for that specific instance.  Unlike the previous
/// `static bool skipFinalizer` approach, this flag cannot leak between
/// tests or affect unrelated sessions.
abstract class Session {
  // ---- Core fields --------------------------------------------------------

  /// The platform-neutral opaque handle for this session.
  late SessionHandle _handle;

  /// The platform-neutral opaque handle for this session.
  ///
  /// Accessing the handle after [dispose] throws [StateError] instead of
  /// allowing a backend call to use a released native object.
  SessionHandle get handle {
    _ensureNotDisposed();
    return _handle;
  }

  set handle(SessionHandle value) {
    _ensureNotDisposed();
    _handle = value;
  }

  /// The C-layer session identifier.  Stable for the session's entire lifetime.
  late int sessionId;

  /// The command string that was (or will be) executed.
  late String command;

  /// Index of the next log entry not yet dispatched to Dart callbacks.
  ///
  /// Shared between [Session], `FFmpegSession`, and `CallbackManager` so
  /// that the log-polling loop and the completion flush both advance from the
  /// same cursor and never deliver the same entry twice.
  int logsProcessed = 0;

  // ---- Cancellation -------------------------------------------------------

  bool _isCancelled = false;

  /// Whether [cancel] has been called on this session.
  bool get isCancelled => _isCancelled;

  /// When `true`, [registerFinalizer] is a no-op for this specific instance.
  /// Set exclusively by [Session.noFinalizer]; immutable after construction.
  final bool _skipFinalizer;
  final SessionFinalizer _sessionFinalizer;

  bool _disposed = false;
  bool _disposing = false;
  final Set<Completer<void>> _executionCompleters = <Completer<void>>{};
  SessionExecutionErrorCallback? _executionErrorCallback;

  /// Standard constructor — [registerFinalizer] will attach the native
  /// finalizer after [handle] is assigned.
  Session({SessionFinalizer? finalizer})
    : _skipFinalizer = false,
      _sessionFinalizer = finalizer ?? sessionFinalizer;

  /// Constructor for use in test subclasses where no native library is loaded.
  ///
  /// Suppresses finalizer registration for *this instance only*; all other
  /// concurrently-live sessions are unaffected.
  ///
  /// **Production code must never call this constructor.**
  Session.noFinalizer({SessionFinalizer? finalizer})
    : _skipFinalizer = true,
      _sessionFinalizer = finalizer ?? sessionFinalizer;

  /// Attaches the platform finalizer to this session when supported.
  ///
  /// Must be called exactly once from every concrete subclass constructor,
  /// *after* both [handle] and [sessionId] have been assigned.
  ///
  /// Calling this more than once on the same session is safe — [_skipFinalizer]
  /// and the platform finalizer own duplicate-attachment behavior.
  void registerFinalizer() {
    if (_skipFinalizer) return;
    _sessionFinalizer.attach(this, handle.value, detachToken: this);
  }

  /// Whether this session has released its native handle.
  bool get isDisposed => _disposed;

  /// Releases this session's native handle and associated Dart resources.
  ///
  /// Disposal is deterministic, idempotent, and valid for sessions that have
  /// completed, been cancelled, or were never executed. Native finalizer
  /// attachment is detached before the handle is released, while Web uses
  /// this explicit path because it has no native-finalizer equivalent.
  ///
  /// Dispose a running session only when cancellation/release semantics of the
  /// selected backend are acceptable to the caller. The native wrapper cancels
  /// a running session before releasing it.
  void dispose() {
    if (_disposed || _disposing) return;
    _disposing = true;
    try {
      try {
        _sessionFinalizer.detach(this);
      } finally {
        clearExecutionErrorHandler();
        try {
          onDispose();
        } finally {
          try {
            releaseHandle(_handle);
          } finally {
            for (final completer in _executionCompleters) {
              if (!completer.isCompleted) completer.complete();
            }
            _executionCompleters.clear();
          }
        }
      }
    } finally {
      _disposed = true;
      _disposing = false;
    }
  }

  /// Gives concrete session types a hook to close Dart-side resources before
  /// the backend releases their native handle.
  @protected
  void onDispose() {}

  /// Releases the platform handle owned by this session.
  ///
  /// Kept as a protected seam so lifecycle tests can verify release ordering
  /// without loading a native or Web FFmpegKit library.
  @protected
  void releaseHandle(SessionHandle handle) {
    ffmpegKitBackend.releaseSession(handle);
  }

  /// Tracks an asynchronous execution so [dispose] can settle its internal
  /// wait even when disposal unregisters the completion callback first.
  @protected
  void trackExecution(Completer<void> completer) {
    _executionCompleters.add(completer);
  }

  /// Registers the handler used when the platform cannot deliver a normal
  /// completion event for an asynchronous execution.
  ///
  /// Platform backends route transport failures back to this shared execution
  /// layer. The concrete session owns cleanup and completes its execution
  /// Future with the original error.
  @protected
  void registerExecutionErrorHandler(SessionExecutionErrorCallback callback) {
    _executionErrorCallback = callback;
  }

  /// Clears the error handler for a settled execution.
  @protected
  void clearExecutionErrorHandler() {
    _executionErrorCallback = null;
  }

  /// Dispatches an asynchronous execution failure to the active execution.
  ///
  /// The fallback completes any tracked execution directly if a concrete
  /// session failed to install its cleanup handler. This keeps the queue from
  /// waiting forever even when the callback registration itself is missing.
  void dispatchExecutionError(Object error, StackTrace stackTrace) {
    final callback = _executionErrorCallback;
    _executionErrorCallback = null;
    if (callback == null) {
      _completeTrackedExecutionsWithError(error, stackTrace);
      return;
    }

    try {
      callback(error, stackTrace);
    } catch (handlerError, handlerStackTrace) {
      log(
        'Session: execution error handler failed for session $sessionId',
        error: handlerError,
        stackTrace: handlerStackTrace,
      );
      _completeTrackedExecutionsWithError(error, stackTrace);
    }
  }

  /// Cleans up an asynchronous execution and preserves its original failure.
  ///
  /// Cleanup failures are logged but do not replace the platform error that
  /// caused the execution to terminate. This keeps the Future useful to the
  /// caller while still making cleanup failures visible for diagnosis.
  @protected
  void completeExecutionWithError({
    required Completer<void> completer,
    required Object error,
    required StackTrace stackTrace,
    required void Function() cleanup,
  }) {
    try {
      cleanup();
    } catch (cleanupError, cleanupStackTrace) {
      log(
        'Session: error cleaning up failed execution for session $sessionId',
        error: cleanupError,
        stackTrace: cleanupStackTrace,
      );
    }
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
  }

  void _completeTrackedExecutionsWithError(
    Object error,
    StackTrace stackTrace,
  ) {
    for (final completer in _executionCompleters) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('Session $sessionId has already been disposed');
    }
  }

  // ---- State & return code ------------------------------------------------

  /// Returns the current lifecycle state of this session.
  SessionState getState() {
    FFmpegKitExtended.requireInitialized();
    try {
      return SessionState.fromValue(ffmpegKitBackend.getSessionState(handle));
    } catch (e, st) {
      log(
        'Session.getState: error getting state ffmpeg_kit_session_get_state',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns the native exit code.
  ///
  /// Meaningful only after [getState] returns [SessionState.completed] or
  /// [SessionState.failed].  Returns 0 while the session is still running.
  int getReturnCode() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.getReturnCode(handle);
    } catch (e, st) {
      log(
        'Session.getReturnCode: error getting return code ffmpeg_kit_session_get_return_code',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns the unique session ID assigned by the C layer.
  ///
  /// Equivalent to [sessionId]; provided as a method for API parity with
  /// the original FFmpegKit Java/ObjC SDK.
  int getSessionId() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.getSessionId(handle);
    } catch (e, st) {
      log(
        'Session.getSessionId: error getting session id ffmpeg_kit_session_get_session_id',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ---- Timing -------------------------------------------------------------

  /// Returns the time at which the session object was created.
  DateTime getCreateTime() {
    FFmpegKitExtended.requireInitialized();
    try {
      return DateTime.fromMillisecondsSinceEpoch(
        ffmpegKitBackend.getCreateTime(handle),
      );
    } catch (e, st) {
      log(
        'Session.getCreateTime: error getting create time ffmpeg_kit_session_get_create_time',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns the time at which execution started, or `null` if the session
  /// has not yet been executed.
  DateTime? getStartTime() {
    FFmpegKitExtended.requireInitialized();
    try {
      final ms = ffmpegKitBackend.getStartTime(handle);
      return ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (e, st) {
      log(
        'Session.getStartTime: error getting start time ffmpeg_kit_session_get_start_time',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns the time at which execution ended, or `null` if the session has
  /// not yet completed.
  DateTime? getEndTime() {
    FFmpegKitExtended.requireInitialized();
    try {
      final ms = ffmpegKitBackend.getEndTime(handle);
      return ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (e, st) {
      log(
        'Session.getEndTime: error getting end time ffmpeg_kit_session_get_end_time',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns the wall-clock execution duration in milliseconds.
  ///
  /// Returns 0 if the session has not yet completed.
  int getDuration() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.getDuration(handle);
    } catch (e, st) {
      log(
        'Session.getDuration: error getting duration ffmpeg_kit_session_get_duration',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ---- Output & logs ------------------------------------------------------

  /// Returns the combined output of the session as a string, or `null` if no
  /// output is available yet.
  String? getOutput() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.getOutput(handle);
    } catch (e, st) {
      log(
        'Session.getOutput: error getting output ffmpeg_kit_session_get_output',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns all buffered log entries concatenated into a single string, or
  /// `null` if no log entries exist.  Equivalent to [getLogsAsString].
  String? getLogs() {
    FFmpegKitExtended.requireInitialized();
    try {
      return getLogsAsString();
    } catch (e, st) {
      log(
        'Session.getLogs: error getting logs ffmpeg_kit_session_get_logs_as_string',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns all buffered log entries concatenated into a single string, or
  /// `null` if no log entries exist.
  String? getLogsAsString() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.getLogsAsString(handle);
    } catch (e, st) {
      log(
        'Session.getLogsAsString: error getting logs as string ffmpeg_kit_session_get_logs_as_string',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns the failure stack trace captured when the session failed, or
  /// `null` if the session did not fail or no trace is available.
  String? getFailStackTrace() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.getFailStackTrace(handle);
    } catch (e, st) {
      log(
        'Session.getFailStackTrace: error getting fail stack trace ffmpeg_kit_session_get_fail_stack_trace',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns the command string as reported by the C layer.
  String getCommand() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.getCommand(handle) ?? '';
    } catch (e, st) {
      log(
        'Session.getCommand: error getting command ffmpeg_kit_session_get_command',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns the number of log entries buffered for this session.
  int getLogsCount() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.getLogsCount(handle);
    } catch (e, st) {
      log(
        'Session.getLogsCount: error getting logs count ffmpeg_kit_session_get_logs_count',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns the log message at [index].
  ///
  /// Returns an empty string if [index] is out of range or the C layer
  /// returns a null pointer.
  String getLogAt(int index) {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.getLogAt(handle, index) ?? '';
    } catch (e, st) {
      log(
        'Session.getLogAt: error getting log at index $index ffmpeg_kit_session_get_log_at',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns the log level for the entry at [index].
  int getLogLevelAt(int index) {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.getLogLevelAt(handle, index);
    } catch (e, st) {
      log(
        'Session.getLogLevelAt: error getting log level at index $index ffmpeg_kit_session_get_log_level_at',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Dispatches all buffered log entries that have not yet been delivered.
  ///
  /// Concrete session types override [onLogsDispatched] to decide how these
  /// batches are surfaced to Dart listeners.
  void dispatchPendingLogs() {
    final count = getLogsCount();
    if (count <= logsProcessed) {
      return;
    }

    final batch = <Log>[];
    for (int i = logsProcessed; i < count; i++) {
      batch.add(Log(sessionId, getLogLevelAt(i), getLogAt(i)));
    }
    logsProcessed = count;
    onLogsDispatched(List<Log>.unmodifiable(batch));
  }

  /// Called after [dispatchPendingLogs] drains a batch from the native buffer.
  ///
  /// Subclasses can override this to push logs into streams and callbacks.
  void onLogsDispatched(List<Log> batch) {}

  // ---- Statistics ---------------------------------------------------------

  /// Returns the number of statistics snapshots buffered for this session.
  int getStatisticsCount() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.getStatisticsCount(handle);
    } catch (e, st) {
      log(
        'Session.getStatisticsCount: error getting statistics count ffmpeg_kit_session_get_statistics_count',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns the [Statistics] snapshot at [index], or `null` if the index is
  /// out of range.
  Statistics? getStatisticsAt(int index) {
    FFmpegKitExtended.requireInitialized();
    final snapshot = ffmpegKitBackend.getStatisticsAt(handle, index);
    if (snapshot == null) return null;

    try {
      final timeMs = snapshot.time;
      final transcodingProgress = this is FFmpegSession
          ? (this as FFmpegSession).calculateTranscodingProgress(timeMs)
          : null;

      return Statistics(
        sessionId,
        snapshot.timeElapsed,
        timeMs,
        snapshot.size,
        snapshot.bitrate,
        snapshot.speed,
        snapshot.videoFrameNumber,
        snapshot.videoFps,
        snapshot.videoQuality,
        snapshot.dupFrames,
        snapshot.dropFrames,
        transcodingProgress,
      );
    } catch (e, st) {
      log(
        'Session.getStatisticsAt: error converting statistics snapshot',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ---- Cancellation -------------------------------------------------------

  /// Requests cancellation of this session.
  ///
  /// Has no effect if the session has already completed, failed, or been
  /// previously cancelled.
  void cancel() {
    FFmpegKitExtended.requireInitialized();
    // Take a consistent snapshot before evaluating the guard.
    final currentState = getState();
    final currentReturnCode = getReturnCode();

    if (currentState == SessionState.completed ||
        currentState == SessionState.failed ||
        ReturnCode.isCancel(currentReturnCode) ||
        _isCancelled) {
      return;
    }
    try {
      ffmpegKitBackend.cancelSession(handle);
    } catch (e, st) {
      log(
        'Session.cancel: error cancelling session ffmpeg_kit_cancel_session',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    _isCancelled = true;
  }

  // ---- Session-type identity ----------------------------------------------
  //
  // Default implementations delegate to the C layer.  Concrete subclasses
  // override these with constant `true`/`false` returns to avoid unnecessary
  // FFI calls in the common case where the Dart type is already known.

  /// Returns `true` if this session is an [FFmpegSession].
  bool isFFmpegSession() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.isFFmpegSession(handle);
    } catch (e, st) {
      log(
        'Session.isFFmpegSession: error checking if session is ffmpeg session session_is_ffmpeg_session',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns `true` if this session is an [FFplaySession].
  bool isFFplaySession() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.isFFplaySession(handle);
    } catch (e, st) {
      log(
        'Session.isFFplaySession: error checking if session is ffplay session session_is_ffplay_session',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns `true` if this session is an [FFprobeSession].
  bool isFFprobeSession() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.isFFprobeSession(handle);
    } catch (e, st) {
      log(
        'Session.isFFprobeSession: error checking if session is ffprobe session session_is_ffprobe_session',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns `true` if this session is a [MediaInformationSession].
  bool isMediaInformationSession() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.isMediaInformationSession(handle);
    } catch (e, st) {
      log(
        'Session.isMediaInformationSession: error checking if session is media information session session_is_media_information_session',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ---- Debug log ----------------------------------------------------------

  /// Enables per-session debug logging in the C layer.
  void enableDebugLog() {
    FFmpegKitExtended.requireInitialized();
    try {
      ffmpegKitBackend.enableDebugLog(handle);
    } catch (e, st) {
      log(
        'Session.enableDebugLog: error enabling debug log session_enable_debug_log',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Disables per-session debug logging in the C layer.
  void disableDebugLog() {
    FFmpegKitExtended.requireInitialized();
    try {
      ffmpegKitBackend.disableDebugLog(handle);
    } catch (e, st) {
      log(
        'Session.disableDebugLog: error disabling debug log session_disable_debug_log',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns `true` if per-session debug logging is currently enabled.
  bool isDebugLogEnabled() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.isDebugLogEnabled(handle);
    } catch (e, st) {
      log(
        'Session.isDebugLogEnabled: error checking if debug log is enabled session_is_debug_log_enabled',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns the accumulated debug log for this session, or an empty string
  /// if none is available.
  String getDebugLog() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpegKitBackend.getDebugLog(handle) ?? '';
    } catch (e, st) {
      log(
        'Session.getDebugLog: error getting debug log session_get_debug_log',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Clears the accumulated debug log in the C layer.
  void clearDebugLog() {
    FFmpegKitExtended.requireInitialized();
    try {
      ffmpegKitBackend.clearDebugLog(handle);
    } catch (e, st) {
      log(
        'Session.clearDebugLog: error clearing debug log session_clear_debug_log',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
