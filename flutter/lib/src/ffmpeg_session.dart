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
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffmpeg_kit_extended_flutter.dart';
import 'callback_manager.dart';
import 'ffmpeg_kit_flutter_loader.dart';

/// A session for executing FFmpeg commands.
///
/// ### Lifecycle
/// 1. Construct via [FFmpegSession.new] (or [create]) to allocate the native
///    session object and register it with [CallbackManager].
/// 2. Call [executeAsync] (or the static [executeCommandAsync]) to schedule
///    execution and await the result.
///    Use [execute] / [executeCommand] only when you deliberately want
///    fire-and-forget behaviour and observe completion through [completeCallback].
/// 3. The session is automatically unregistered from [CallbackManager] after
///    the completion callback fires.
///
/// ### execute() vs executeAsync()
/// [execute] enqueues the native call and returns `this` immediately —
/// *before* the session has necessarily started or finished.  It is therefore
/// **not** a true synchronous call from the caller's perspective.
/// Use [executeAsync] when you need a [Future] that resolves only after
/// execution finishes.
class FFmpegSession extends Session {
  FFmpegSessionCompleteCallback? _completeCallback;
  FFmpegLogCallback? _logCallback;
  FFmpegStatisticsCallback? _statisticsCallback;

  // CallbackManager.registerFFmpegSession(). Stored here so that:
  //   • execute/executeAsync can pass it as the userData pointer to the C
  //     layer, enabling O(1) session lookup in native callbacks.
  //   • remove* methods know exactly which registration entry to clean up
  //     without guessing or scanning maps.
  int? _callbackId;

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Restores an [FFmpegSession] from an existing native [handle].
  ///
  /// Used internally when wrapping handles returned by session-history APIs.
  /// No callbacks are registered; call [setCompleteCallback] /
  /// [setLogCallback] / [setStatisticsCallback] if callbacks are needed.
  FFmpegSession.fromHandle(Pointer<Void> handle, String command) {
    this.handle = handle;
    this.command = command;
    sessionId = FFmpegKitExtended.getSessionId(handle);
    registerFinalizer();
    // No registration: restored sessions are not expected to fire native
    // callbacks unless the caller explicitly sets callbacks and re-executes.
  }

  /// Creates a new [FFmpegSession] for [command].
  ///
  /// The session is immediately registered with [CallbackManager] so that
  /// global native callbacks (completion, log, statistics) can locate it by
  /// session ID even before [executeAsync] is called.  Registration is
  /// removed when the completion callback fires or when all per-session
  /// callbacks are cleared via the remove* methods.
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
    final cmdPtr = command.toNativeUtf8(allocator: calloc);
    try {
      handle = ffmpeg.ffmpeg_kit_create_session(cmdPtr.cast());
      this.command = command;
      sessionId = FFmpegKitExtended.getSessionId(handle);
      registerFinalizer();
    } finally {
      calloc.free(cmdPtr);
    }

    _completeCallback = completeCallback;
    _logCallback = logCallback;
    _statisticsCallback = statisticsCallback;
    _callbackId = CallbackManager().registerFFmpegSession(this);
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
  }) =>
      FFmpegSession(
        command,
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

  // ---------------------------------------------------------------------------
  // Callback mutators
  // ---------------------------------------------------------------------------

  /// Sets or replaces the completion callback.
  ///
  /// If the session is already registered the callback reference is updated
  /// in-place (no new registration entry is created).
  void setCompleteCallback(FFmpegSessionCompleteCallback? completeCallback) {
    _completeCallback = completeCallback;
    _ensureRegistered();
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
    _ensureRegistered();
  }

  /// Clears the log callback.
  void removeLogCallback() {
    _logCallback = null;
    _unregisterIfIdle();
  }

  /// Sets or replaces the statistics callback.
  void setStatisticsCallback(FFmpegStatisticsCallback? statisticsCallback) {
    _statisticsCallback = statisticsCallback;
    _ensureRegistered();
  }

  /// Clears the statistics callback.
  void removeStatisticsCallback() {
    _statisticsCallback = null;
    _unregisterIfIdle();
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  /// Enqueues this session for synchronous (blocking) native execution via
  /// [SessionQueueManager] and returns `this` immediately.
  ///
  /// This method returns as soon as the session is *enqueued*, not when it
  /// has *finished*.  Depending on queue depth the native call may not have
  /// started yet when this returns.  [getState()] immediately after [execute]
  /// may still return [SessionState.created].
  ///
  /// If you need to await the result, use [executeAsync] instead.
  FFmpegSession execute() {
    SessionQueueManager().executeSession(
      this,
      () async {
        FFmpegKitExtended.requireInitialized();
        // Blocking native call — returns only after FFmpeg finishes.
        ffmpeg.ffmpeg_kit_session_execute(handle);
        // Flush any remaining log entries before invoking the callback.
        _deliverPendingLogs();
        // Invoke the completion callback so callers using fire-and-forget
        // still receive the notification.
        try {
          _completeCallback?.call(this);
        } catch (e, st) {
          log('FFmpegSession.execute: error in completeCallback for session '
              '$sessionId: $e\n$st');
        }
        _unregister();
      },
    ).catchError((Object e, StackTrace st) {
      log('FFmpegSession.execute: queue error for session $sessionId: '
          '$e\n$st');
    });
    return this;
  }

  /// Creates and enqueues a session for synchronous execution.
  ///
  /// See [execute] for the return-before-completion caveat.
  static FFmpegSession executeCommand(
    String command, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) =>
      FFmpegSession.create(
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
  }) =>
      FFmpegSession.create(
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

  @override
  bool isFFmpegSession() => true;

  @override
  bool isFFplaySession() => false;

  @override
  bool isFFprobeSession() => false;

  @override
  bool isMediaInformationSession() => false;

  // ---------------------------------------------------------------------------
  // Private implementation
  // ---------------------------------------------------------------------------

  /// Core async execution body, called by [executeAsync] through the queue.
  Future<void> _runAsync() async {
    FFmpegKitExtended.requireInitialized();
    final sessionCompleter = Completer<void>();

    // Capture the user-supplied callback before we install the internal
    // wrapper so we can restore it after execution.
    final userCompleteCallback = _completeCallback;

    Timer? logPoller;

    // Install an internal completion wrapper that:
    //   1. Cancels the log poller.
    //   2. Flushes any remaining buffered log entries.
    //   3. Invokes the original user callback.
    //   4. Completes sessionCompleter so the queue slot is released.
    //   5. Unregisters the session from CallbackManager.
    //
    // This wrapper is visible to the native _onFFmpegComplete handler via
    // CallbackManager (the session is keyed by _callbackId / sessionId).
    _completeCallback = (FFmpegSession s) {
      logPoller?.cancel();
      logPoller = null;

      _deliverPendingLogs();

      try {
        userCompleteCallback?.call(s);
      } catch (e, st) {
        log('FFmpegSession: error in completeCallback for session '
            '$sessionId: $e\n$st');
      }

      if (!sessionCompleter.isCompleted) {
        sessionCompleter.complete();
      }

      // Unregister after the callback fires; any subsequent call on the
      // native side for this session ID will find nothing in the maps,
      // which is the correct post-completion state.
      _unregister();
    };

    // Start the log poller only if there is a listener.
    if (_logCallback != null || CallbackManager().globalLogCallback != null) {
      logPoller = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        _deliverPendingLogs();

        final state = getState();
        if (state == SessionState.completed ||
            state == SessionState.failed ||
            isCancelled) {
          timer.cancel();
        }
      });
    }

    // Enable the global native completion and statistics callbacks so the C
    // layer can post events back to Dart.  These calls are idempotent.
    ffmpeg.ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
        nativeFFmpegComplete.nativeFunction, nullptr);
    ffmpeg.ffmpeg_kit_config_enable_statistics_callback(
        nativeFFmpegStatistics.nativeFunction, nullptr);

    // Start async native execution.
    try {
      ffmpeg.ffmpeg_kit_session_execute_async(handle);
    } catch (e, st) {
      log('FFmpegSession: error starting async session $sessionId: $e\n$st');
      logPoller?.cancel();
      if (!sessionCompleter.isCompleted) sessionCompleter.complete();
      rethrow;
    }

    // Hold the queue slot open until the completion wrapper fires.
    try {
      await sessionCompleter.future;
    } catch (e, st) {
      log('FFmpegSession: error awaiting session $sessionId: $e\n$st');
    }

    // Restore the original user callback so the session object is left in a
    // predictable state (e.g. if the caller re-executes it).
    _completeCallback = userCompleteCallback;
  }

  /// Dispatches all buffered log entries that have not yet been delivered.
  ///
  /// Called by the log poller (every 100 ms) and as a final flush inside the
  /// completion wrapper to ensure no entries are dropped if the poller races
  /// with the completion event.
  void _deliverPendingLogs() {
    final count = getLogsCount();
    for (int i = logsProcessed; i < count; i++) {
      final message = getLogAt(i);
      final level = getLogLevelAt(i);
      final logObj = Log(sessionId, level, message);
      try {
        CallbackManager().globalLogCallback?.call(logObj);
        _logCallback?.call(logObj);
      } catch (e, st) {
        log('FFmpegSession: error dispatching log [$i] for session '
            '$sessionId: $e\n$st');
      }
    }
    logsProcessed = count;
  }

  /// Ensures the session is registered with [CallbackManager].
  ///
  /// If [_callbackId] is already set the existing registration is reused —
  /// the session object reference in the maps is always `this`, so no
  /// re-insertion is needed.  A new ID is allocated only when the session
  /// was previously fully unregistered (e.g. after all callbacks were removed
  /// and then a new callback is set).
  void _ensureRegistered() {
    if (_callbackId != null) return;
    _callbackId = CallbackManager().registerFFmpegSession(this);
  }

  /// Unregisters the session from [CallbackManager] and clears [_callbackId].
  ///
  /// After this call, [_callbackId] is null and the session is invisible to
  /// native callbacks.  Calling [_ensureRegistered] afterwards allocates a
  /// fresh registration entry.
  void _unregister() {
    final id = _callbackId;
    if (id == null) return;
    _callbackId = null;
    CallbackManager().unregisterFFmpegSession(id);
  }

  /// Unregisters the session only when no callbacks remain.
  ///
  /// Guards against premature eviction: if the caller clears one callback but
  /// others are still active, the registration is kept so those callbacks
  /// continue to work.
  void _unregisterIfIdle() {
    if (_completeCallback == null &&
        _logCallback == null &&
        _statisticsCallback == null) {
      _unregister();
    }
  }
}