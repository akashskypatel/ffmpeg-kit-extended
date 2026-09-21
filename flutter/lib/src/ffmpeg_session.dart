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

import '../ffmpeg_kit_extended_flutter.dart';
import 'callback_manager.dart';
import 'platform/backend.dart';
import 'platform/backend_selector.dart';

/// A session for executing FFmpeg commands.
///
/// ### Lifecycle
/// 1. Construct via [FFmpegSession.new] (or [create]) to allocate the native
///    session object. Sessions are registered with [CallbackManager] lazily
///    when a callback, log listener, or execution is attached.
/// 2. Call [execute] / [executeCommand] for a blocking result, or
///    [executeAsync] / [executeCommandAsync] to submit work to the managed
///    asynchronous queue.
/// 3. The session is automatically unregistered from [CallbackManager] after
///    execution settles.
///
/// ### execute() vs executeAsync()
/// [execute] blocks until native execution and Dart-side cleanup complete, so
/// its returned session has terminal state, output, and logs available without
/// calling `SessionQueueManager().waitForAll()`. Do not use it for long work on
/// the Flutter UI isolate. Use [executeAsync] for a [Future]-based,
/// queue-managed operation; the queue concurrency limit applies to that async
/// path.
class FFmpegSession extends Session {
  FFmpegSessionCompleteCallback? _completeCallback;
  FFmpegLogCallback? _logCallback;
  FFmpegStatisticsCallback? _statisticsCallback;
  StreamController<List<Log>>? _logBatchStreamController;
  Stream<Log>? _logStream;
  int? _expectedTranscodingDurationMs;

  // Whether this session is currently registered with CallbackManager.
  bool _registered = false;

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Creates an in-memory session for package tests.
  ///
  /// This constructor does not call the platform backend. It is intentionally
  /// kept in the package's internal source tree so callback-manager tests can
  /// exercise the real session type without requiring a native library.
  FFmpegSession.test({
    int sessionId = 1,
    String command = 'test',
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
    bool register = true,
  }) : super.noFinalizer() {
    handle = const SessionHandle(Object());
    this.sessionId = sessionId;
    this.command = command;
    _completeCallback = completeCallback;
    _logCallback = logCallback;
    _statisticsCallback = statisticsCallback;
    if (register) {
      CallbackManager().registerFFmpegSession(this);
      _registered = true;
    }
  }

  /// Restores an [FFmpegSession] from an existing native [handle].
  ///
  /// Used internally when wrapping handles returned by session-history APIs.
  /// No callbacks are registered; call [setCompleteCallback] /
  /// [setLogCallback] / [setStatisticsCallback] if callbacks are needed.
  FFmpegSession.fromHandle(SessionHandle handle, String command) {
    int? expectedDurationMs;
    adoptOwnedHandle(
      handle,
      readSessionId: ffmpegKitBackend.getSessionId,
      onBeforeCommit: () {
        expectedDurationMs = _deriveExpectedTranscodingDurationMs(
          FFmpegKitExtended.parseArguments(command),
        );
      },
    );
    this.command = command;
    _expectedTranscodingDurationMs = expectedDurationMs;
    // No registration: restored sessions are not expected to fire native
    // callbacks unless the caller explicitly sets callbacks and re-executes.
  }

  /// Creates a new [FFmpegSession] for [command].
  ///
  /// The session is registered with [CallbackManager] when a callback or log
  /// listener is supplied, and otherwise on first execution or log-listener
  /// attachment. Registration is removed when execution completes or when all
  /// per-session callbacks and listeners are cleared.
  ///
  /// - [completeCallback]: Invoked once when execution finishes.
  /// - [logCallback]: Invoked for each buffered log line during execution.
  /// - [statisticsCallback]: Invoked periodically with encoding statistics.
  FFmpegSession(
    String command, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) {
    FFmpegKitExtended.requireInitialized();
    final expectedDurationMs = _deriveExpectedTranscodingDurationMs(
      FFmpegKitExtended.parseArguments(command),
    );
    try {
      final ownedHandle = ffmpegKitBackend.createFFmpegSession(command);
      this.command = command;
      adoptOwnedHandle(
        ownedHandle,
        readSessionId: ffmpegKitBackend.getSessionId,
      );
    } catch (e, stack) {
      log(
        "FFmpegSession: Failed to call native function ffmpeg_kit_create_session",
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }

    _expectedTranscodingDurationMs = expectedDurationMs;
    _completeCallback = completeCallback;
    _logCallback = logCallback;
    _statisticsCallback = statisticsCallback;
    if (completeCallback != null ||
        logCallback != null ||
        statisticsCallback != null) {
      _ensureRegistered();
    }
  }

  /// Creates a new [FFmpegSession] from an explicit argument list.
  ///
  /// This bypasses command-string reparsing and is the safest way to build
  /// Windows paths and other arguments that should be passed to FFmpeg
  /// verbatim.
  FFmpegSession.fromArguments(
    List<String> arguments, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) {
    FFmpegKitExtended.requireInitialized();
    final displayCommand = FFmpegKitExtended.argumentsToString(arguments);
    final expectedDurationMs = _deriveExpectedTranscodingDurationMs(arguments);
    final ownedHandle = ffmpegKitBackend.createFFmpegSessionFromArguments(
      arguments,
    );

    command = displayCommand;
    adoptOwnedHandle(ownedHandle, readSessionId: ffmpegKitBackend.getSessionId);
    _expectedTranscodingDurationMs = expectedDurationMs;

    _completeCallback = completeCallback;
    _logCallback = logCallback;
    _statisticsCallback = statisticsCallback;
    if (completeCallback != null ||
        logCallback != null ||
        statisticsCallback != null) {
      _ensureRegistered();
    }
  }

  // ---------------------------------------------------------------------------
  // Factory / static helpers
  // ---------------------------------------------------------------------------

  /// Equivalent to [FFmpegSession.new]; provided for API symmetry.
  static FFmpegSession create(
    String command, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) => FFmpegSession(
    command,
    completeCallback: completeCallback,
    logCallback: logCallback,
    statisticsCallback: statisticsCallback,
  );

  /// Equivalent to [FFmpegSession.fromArguments]; provided for API symmetry.
  static FFmpegSession createFromArguments(
    List<String> arguments, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) => FFmpegSession.fromArguments(
    arguments,
    completeCallback: completeCallback,
    logCallback: logCallback,
    statisticsCallback: statisticsCallback,
  );

  // ---------------------------------------------------------------------------
  // Callback accessors
  // ---------------------------------------------------------------------------

  /// The callback invoked once when execution completes.
  FFmpegSessionCompleteCallback? get completeCallback => _completeCallback;

  /// The callback invoked for each log line produced by FFmpeg.
  FFmpegLogCallback? get logCallback => _logCallback;

  /// The callback invoked periodically with encoding statistics.
  FFmpegStatisticsCallback? get statisticsCallback => _statisticsCallback;

  /// The best-known effective media duration for progress estimation.
  int? get expectedTranscodingDurationMs => _expectedTranscodingDurationMs;

  /// A batched stream of buffered logs drained from the native session.
  ///
  /// Each event contains every log line that accumulated since the previous
  /// drain. This is the preferred API for high-volume sessions because it keeps
  /// Dart-side dispatch and UI work off the per-line hot path.
  Stream<List<Log>> get logBatchStream {
    final controller = _logBatchStreamController ??=
        StreamController<List<Log>>.broadcast(
          onListen: () {
            _ensureRegistered();
            dispatchPendingLogs();
          },
        );
    return controller.stream;
  }

  /// A per-log view over [logBatchStream].
  ///
  /// This is convenient when call sites still prefer line-by-line handling,
  /// but [logBatchStream] is more efficient for UI and file sinks.
  Stream<Log> get logStream =>
      _logStream ??= logBatchStream.expand((batch) => batch);

  /// Overrides the effective duration used to compute transcoding progress.
  void setExpectedTranscodingDuration(Duration? duration) {
    _expectedTranscodingDurationMs = duration?.inMilliseconds;
  }

  /// Computes normalized transcoding progress from processed media time.
  double? calculateTranscodingProgress(int processedTimeMs) {
    final expected = _expectedTranscodingDurationMs;
    if (expected == null || expected <= 0) {
      return null;
    }
    final normalized = processedTimeMs / expected;
    if (normalized.isNaN || normalized.isInfinite) {
      return null;
    }
    return normalized.clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // Callback mutators
  // ---------------------------------------------------------------------------

  /// Sets or replaces the completion callback.
  ///
  /// If the session is already registered the callback reference is updated
  /// in-place (no new registration entry is created).
  void setCompleteCallback(FFmpegSessionCompleteCallback? completeCallback) {
    _completeCallback = completeCallback;
    if (completeCallback == null) {
      _unregisterIfIdle();
    } else {
      _ensureRegistered();
    }
  }

  /// Clears the completion callback.
  ///
  /// If no other callbacks remain the session is unregistered from
  /// [CallbackManager] to prevent memory leaks.
  void removeCompleteCallback() {
    _completeCallback = null;
    _unregisterIfIdle();
  }

  /// Sets or replaces the log callback.
  void setLogCallback(FFmpegLogCallback? logCallback) {
    _logCallback = logCallback;
    if (logCallback == null) {
      _unregisterIfIdle();
    } else {
      _ensureRegistered();
    }
  }

  /// Clears the log callback.
  void removeLogCallback() {
    _logCallback = null;
    _unregisterIfIdle();
  }

  /// Sets or replaces the statistics callback.
  void setStatisticsCallback(FFmpegStatisticsCallback? statisticsCallback) {
    _statisticsCallback = statisticsCallback;
    if (statisticsCallback == null) {
      _unregisterIfIdle();
    } else {
      _ensureRegistered();
    }
  }

  /// Clears the statistics callback.
  void removeStatisticsCallback() {
    _statisticsCallback = null;
    _unregisterIfIdle();
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  /// Executes this session synchronously and returns only after native work
  /// and Dart-side completion cleanup have finished.
  ///
  /// Unlike [executeAsync], this path is deliberately not queue-managed. The
  /// queue limit applies only to asynchronous execution. Backend failures are
  /// rethrown with their original stack trace after cleanup.
  FFmpegSession execute() {
    claimExecutionSubmission();
    requireInitializedForExecution();
    _ensureRegistered();

    Object? primaryError;
    StackTrace? primaryStackTrace;
    void recordCleanupFailure(Object error, StackTrace stackTrace) {
      if (primaryError == null) {
        primaryError = error;
        primaryStackTrace = stackTrace;
      } else {
        log(
          'FFmpegSession.execute: cleanup failed after primary error for session $sessionId',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    try {
      enableNativeLogCallback();
      configureSynchronousNativeCallbacks();
      // Mark the handoff immediately before the blocking native call.
      markExecutionStarted();
      executeSynchronously();
      dispatchPendingLogs();
      CallbackManager().dispatchFFmpegComplete(sessionId);
    } catch (error, stackTrace) {
      primaryError = error;
      primaryStackTrace = stackTrace;
      log(
        'FFmpegSession.execute: synchronous execution failed for session $sessionId',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      try {
        _closeLogStreams();
      } catch (error, stackTrace) {
        recordCleanupFailure(error, stackTrace);
      }
      try {
        _unregister();
      } catch (error, stackTrace) {
        recordCleanupFailure(error, stackTrace);
      } finally {
        markExecutionSettled();
      }
    }

    if (primaryError != null) {
      Error.throwWithStackTrace(primaryError!, primaryStackTrace!);
    }
    return this;
  }

  /// Creates and executes a session synchronously.
  ///
  /// Returns after the blocking execution has completed.
  static FFmpegSession executeCommand(
    String command, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) => FFmpegSession.create(
    command,
    completeCallback: completeCallback,
    logCallback: logCallback,
    statisticsCallback: statisticsCallback,
  ).execute();

  /// Creates and executes a session asynchronously.
  ///
  /// Returns a [Future] that resolves after native execution completes.
  static Future<FFmpegSession> executeCommandAsync(
    String command, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) => FFmpegSession.create(
    command,
    completeCallback: completeCallback,
    logCallback: logCallback,
    statisticsCallback: statisticsCallback,
  ).executeAsync();

  /// Executes this session asynchronously and returns a [Future] that
  /// resolves only after native execution finishes (or is cancelled).
  ///
  /// Any callback arguments supplied here override the callbacks set at
  /// construction time for this execution only; the original callbacks are
  /// restored after execution completes.
  Future<FFmpegSession> executeAsync({
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) async {
    claimExecutionSubmission();
    if (completeCallback != null) _completeCallback = completeCallback;
    if (logCallback != null) _logCallback = logCallback;
    if (statisticsCallback != null) _statisticsCallback = statisticsCallback;

    // Ensure registration is current after any callback mutations above.
    _ensureRegistered();

    await SessionQueueManager().executeSession(this, _runAsync);

    return this;
  }

  // ---------------------------------------------------------------------------
  // Session type identity
  // ---------------------------------------------------------------------------

  /// Returns true if this is an FFmpeg session.
  @override
  bool isFFmpegSession() => true;

  /// Returns true if this is an FFplay session.
  @override
  bool isFFplaySession() => false;

  /// Returns true if this is an FFprobe session.
  @override
  bool isFFprobeSession() => false;

  /// Returns true if this is a media information session.
  @override
  bool isMediaInformationSession() => false;

  // ---------------------------------------------------------------------------
  // Private implementation
  // ---------------------------------------------------------------------------

  /// Core async execution body, called by [executeAsync] through the queue.
  Future<void> _runAsync() async {
    FFmpegKitExtended.requireInitialized();
    final sessionCompleter = Completer<void>();
    trackExecution(sessionCompleter);

    // Capture the user-supplied callback before we install the internal
    // wrapper so we can restore it after execution.
    final userCompleteCallback = _completeCallback;

    // Install an internal completion wrapper that:
    //   1. Flushes any remaining buffered log entries.
    //   2. Restores the original callback and unregisters — fully settling the
    //      session BEFORE the user callback or completer fire, so any awaiter
    //      sees a completely torn-down session.
    //   3. Invokes the original user callback.
    //   4. Completes sessionCompleter last — guaranteeing that by the time
    //      `await executeAsync` resumes, the session is fully settled.
    //
    // This wrapper is visible to the native _onFFmpegComplete handler via
    // CallbackManager (the session is keyed by sessionId).
    var completionHandled = false;
    void handleExecutionError(Object error, StackTrace stackTrace) {
      if (completionHandled) return;
      completionHandled = true;
      clearExecutionErrorHandler();
      _completeCallback = userCompleteCallback;
      completeExecutionWithError(
        completer: sessionCompleter,
        error: error,
        stackTrace: stackTrace,
        cleanup: () {
          try {
            _closeLogStreams();
          } finally {
            _unregister();
          }
        },
      );
    }

    registerExecutionErrorHandler(handleExecutionError);
    _completeCallback = (FFmpegSession s) {
      if (completionHandled) return;
      completionHandled = true;
      clearExecutionErrorHandler();

      try {
        dispatchPendingLogs();
      } catch (e, st) {
        log(
          'FFmpegSession: error flushing logs for session $sessionId',
          error: e,
          stackTrace: st,
        );
      } finally {
        // Restore and unregister before calling user code or completing the
        // future, so the session is fully settled from any observer's
        // perspective.
        _completeCallback = userCompleteCallback;
        try {
          _closeLogStreams();
        } finally {
          try {
            _unregister();
          } finally {
            CallbackManager().invokeSafely(
              'FFmpeg completion callback',
              sessionId,
              () => userCompleteCallback?.call(s),
            );
            // Complete last — callback failures are reported separately and
            // never prevent the execution future from settling.
            if (!sessionCompleter.isCompleted) sessionCompleter.complete();
          }
        }
      }
    };

    try {
      enableNativeLogCallback();
      // Enable the global native completion and statistics callbacks so the C
      // layer can post events back to Dart. These calls are idempotent.
      ffmpegKitBackend.configureFFmpegCallbacks();
      ffmpegKitBackend.executeFFmpegSessionAsync(handle);
    } catch (e, st) {
      log(
        'FFmpegSession: error starting async execution for session $sessionId',
        error: e,
        stackTrace: st,
      );
      clearExecutionErrorHandler();
      _completeCallback = userCompleteCallback;
      _closeLogStreams();
      _unregister();
      if (!sessionCompleter.isCompleted) sessionCompleter.complete();
      rethrow;
    }

    // Hold the queue slot open until the completion wrapper fires.
    try {
      await sessionCompleter.future;
    } catch (e, st) {
      log('FFmpegSession: error awaiting session $sessionId: $e\n$st');
      rethrow;
    }
    // No post-await restore needed — already done inside the callback above.
  }

  @override
  void onLogsDispatched(List<Log> batch) {
    if (batch.isEmpty) {
      return;
    }

    final controller = _logBatchStreamController;
    if (controller != null && !controller.isClosed && controller.hasListener) {
      controller.add(List<Log>.unmodifiable(batch));
    }

    for (final logObj in batch) {
      CallbackManager().invokeSafely(
        'FFmpeg global log callback',
        sessionId,
        () => CallbackManager().globalLogCallback?.call(logObj),
      );
      CallbackManager().invokeSafely(
        'FFmpeg session log callback',
        sessionId,
        () => _logCallback?.call(logObj),
      );
    }
  }

  /// Configures native completion and statistics callbacks for sync execution.
  @protected
  void configureSynchronousNativeCallbacks() {
    ffmpegKitBackend.configureFFmpegSessionCompleteCallback();
    ffmpegKitBackend.configureStatisticsCallback();
  }

  /// Invokes the blocking FFmpeg backend operation.
  @protected
  void executeSynchronously() {
    ffmpegKitBackend.executeFFmpegSession(handle);
  }

  @protected
  void enableNativeLogCallback() {
    try {
      ffmpegKitBackend.enableFFmpegLogCallback();
    } catch (e, st) {
      log(
        'FFmpegSession: error enabling ffmpeg log callback for session $sessionId',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  void _closeLogStreams() {
    final controller = _logBatchStreamController;
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
  }

  @override
  void onDispose() {
    _completeCallback = null;
    _logCallback = null;
    _statisticsCallback = null;
    _closeLogStreams();
    _unregister();
  }

  @override
  void onCancelledBeforeStart() {
    _closeLogStreams();
    _unregister();
  }

  /// Ensures the session is registered with [CallbackManager].
  ///
  /// No-op if already registered. Re-registers if the session was previously
  /// fully unregistered (e.g. after all callbacks were removed and a new
  /// callback is set).
  void _ensureRegistered() {
    if (isDisposed) return;
    if (_registered) return;
    CallbackManager().registerFFmpegSession(this);
    _registered = true;
  }

  /// Unregisters this session from [CallbackManager].
  void _unregister() {
    if (!_registered) return;
    _registered = false;
    CallbackManager().unregisterFFmpegSession(sessionId);
  }

  /// Unregisters the session only when no callbacks remain.
  ///
  /// Guards against premature eviction: if the caller clears one callback but
  /// others are still active, the registration is kept so those callbacks
  /// continue to work.
  void _unregisterIfIdle() {
    if (_completeCallback == null &&
        _logCallback == null &&
        _statisticsCallback == null &&
        !(_logBatchStreamController?.hasListener ?? false)) {
      _unregister();
    }
  }

  static int? _deriveExpectedTranscodingDurationMs(List<String> arguments) {
    int? startMs;
    int? endMs;
    int? durationMs;

    for (var i = 0; i < arguments.length; i++) {
      if (i + 1 >= arguments.length) {
        break;
      }

      switch (arguments[i]) {
        case '-ss':
          startMs = _parseFfmpegTimeToMs(arguments[i + 1]);
          i++;
          break;
        case '-to':
          endMs = _parseFfmpegTimeToMs(arguments[i + 1]);
          i++;
          break;
        case '-t':
          durationMs = _parseFfmpegTimeToMs(arguments[i + 1]);
          i++;
          break;
      }
    }

    if (durationMs != null && durationMs > 0) {
      return durationMs;
    }
    if (startMs != null && endMs != null && endMs > startMs) {
      return endMs - startMs;
    }
    if (endMs != null && endMs > 0) {
      return endMs;
    }
    return null;
  }

  static int? _parseFfmpegTimeToMs(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final sexagesimal = RegExp(
      r'^(-)?(?:(\d+):)?(\d+):(\d+(?:\.\d+)?)$',
    ).firstMatch(trimmed);
    if (sexagesimal != null) {
      final sign = sexagesimal.group(1) == '-' ? -1 : 1;
      final hours = int.tryParse(sexagesimal.group(2) ?? '0') ?? 0;
      final minutes = int.tryParse(sexagesimal.group(3) ?? '0') ?? 0;
      final seconds = double.tryParse(sexagesimal.group(4) ?? '');
      if (seconds == null) {
        return null;
      }
      final totalMs =
          ((hours * 3600) + (minutes * 60)) * 1000 + (seconds * 1000).round();
      return sign * totalMs;
    }

    final unitMatch = RegExp(
      r'^(-?\d+(?:\.\d+)?)(us|ms|s|m|h)?$',
    ).firstMatch(trimmed);
    if (unitMatch == null) {
      return null;
    }

    final magnitude = double.tryParse(unitMatch.group(1)!);
    if (magnitude == null) {
      return null;
    }

    switch (unitMatch.group(2) ?? 's') {
      case 'us':
        return (magnitude / 1000).round();
      case 'ms':
        return magnitude.round();
      case 's':
        return (magnitude * 1000).round();
      case 'm':
        return (magnitude * 60 * 1000).round();
      case 'h':
        return (magnitude * 60 * 60 * 1000).round();
      default:
        return null;
    }
  }
}
