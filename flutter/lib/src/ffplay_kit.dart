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
import 'callback_manager.dart' as callback_manager;

// Only one FFplay session can be active at a time.
FFplaySession? _activeFFplaySession;
final Set<FFplaySession> _trackedExecutions = <FFplaySession>{};

/// A utility class for managing global FFplay playback.
///
/// Since FFplay typically involves a single active playback window/session,
/// [FFplayKit] provides a convenient way to execute commands and control
/// the current active session.
class FFplayKit {
  /// Executes an FFplay [command] and starts playback.
  static Future<FFplaySession> execute(String command) => executeAsync(command);

  /// Executes an FFplay [command] asynchronously and starts playback.
  ///
  /// [onComplete] is called when playback ends.
  static Future<FFplaySession> executeAsync(
    String command, {
    FFplaySessionCompleteCallback? onComplete,
    callback_manager.FFmpegLogCallback? onLog,
  }) async {
    _activeFFplaySession = FFplaySession.createGlobal(
      command,
      completeCallback: onComplete,
    );
    if (onLog != null) {
      _activeFFplaySession!.setLogCallback(onLog);
    }
    final session = _activeFFplaySession!;
    await _startTrackedExecution(session, propagateStartupError: true);
    return session;
  }

  /// Creates a new [FFplaySession] without executing it.
  /// Use [execute] or [executeAsync] to execute the session.
  static Future<FFplaySession> createSession(
    String command, {
    FFplaySessionCompleteCallback? onComplete,
    callback_manager.FFmpegLogCallback? onLog,
  }) async {
    _activeFFplaySession = FFplaySession.createGlobal(
      command,
      completeCallback: onComplete,
    );
    if (onLog != null) {
      _activeFFplaySession!.setLogCallback(onLog);
    }
    return _activeFFplaySession!;
  }

  /// Creates a new [FFplaySession] from pre-tokenized [arguments].
  static Future<FFplaySession> createSessionFromArguments(
    List<String> arguments, {
    FFplaySessionCompleteCallback? onComplete,
    callback_manager.FFmpegLogCallback? onLog,
  }) async {
    _activeFFplaySession = FFplaySession.createGlobalFromArguments(
      arguments,
      completeCallback: onComplete,
    );
    if (onLog != null) {
      _activeFFplaySession!.setLogCallback(onLog);
    }
    return _activeFFplaySession!;
  }

  /// Requests cancellation of a [session].
  ///
  /// The request is recorded before playback stop is attempted. Queued or
  /// pre-start sessions do not invoke the playback stop control, and a failed
  /// stop can be retried without losing the cancellation request.
  ///
  /// An untracked session that was never handed to an executor is no longer
  /// current after cancellation succeeds. Tracked executions retain global
  /// ownership until their execution Future settles.
  static void cancel(FFplaySession session) {
    session.cancel();
    _clearCurrentIfUntracked(session);
  }

  /// Returns the current active [FFplaySession], if any.
  static FFplaySession? getCurrentSession() => _activeFFplaySession;

  /// Returns all active FFplay sessions.
  static List<FFplaySession> getFFplaySessions() =>
      FFmpegKitExtended.getFFplaySessions();

  /// Returns the current active [FFplaySession], if any.
  static FFplaySession? get currentSession => _activeFFplaySession;

  /// Returns true if the current session is playing.
  static bool get playing => _activeFFplaySession?.isPlaying() ?? false;

  /// Returns true if the current session is paused.
  static bool get paused => _activeFFplaySession?.isPaused() ?? false;

  /// Returns the current playback position in seconds.
  static double get position => _activeFFplaySession?.getPosition() ?? 0.0;

  /// Returns the total duration of the media in seconds.
  static double get duration => _activeFFplaySession?.getMediaDuration() ?? 0.0;

  /// Returns true if there is no active playback session.
  static bool get closed => _activeFFplaySession == null;

  /// Seeks to the specified position in [seconds].
  static void seek(double seconds) {
    if (_activeFFplaySession != null) {
      _activeFFplaySession!.seek(seconds);
    }
  }

  /// Starts or resumes playback for the active global session.
  ///
  /// This method only has an effect if there is an active session
  /// that was created but not yet executed, or was paused.
  static void start() {
    final session = _activeFFplaySession;
    if (session == null) return;

    try {
      switch (session.getState()) {
        case SessionState.created:
          unawaited(_startTrackedExecution(session));
        case SessionState.running:
          if (session.isPaused()) session.resume();
        case SessionState.completed:
        case SessionState.failed:
          break;
      }
    } catch (error, stackTrace) {
      log(
        'FFplayKit.start: unable to inspect current session',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _startTrackedExecution(
    FFplaySession session, {
    bool propagateStartupError = false,
  }) async {
    if (!_trackedExecutions.add(session)) return;

    late final Future<FFplaySession> execution;
    Future<void>? terminalObserver;
    try {
      execution = session.executeAsync();
      // Attach the terminal owner before awaiting startup. A startup failure
      // is also an execution failure, so one observer must own cleanup and
      // logging for both paths.
      terminalObserver = _finishTrackedExecution(session, execution);
      final startup = session.startupFutureForTracking;
      await (startup ?? execution);
    } catch (error, stackTrace) {
      final observer = terminalObserver;
      if (observer != null) {
        await observer;
      } else {
        // A non-async test double or an unexpected synchronous throw can fail
        // before executeAsync returns a Future for the terminal observer.
        log(
          'FFplayKit: tracked startup failed before terminal observation for '
          'session ${session.sessionId}',
          error: error,
          stackTrace: stackTrace,
        );
        _releaseTrackedExecution(session);
      }
      if (propagateStartupError) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      return;
    }

    unawaited(terminalObserver);
  }

  static Future<void> _finishTrackedExecution(
    FFplaySession session,
    Future<FFplaySession> completion,
  ) async {
    try {
      await completion;
    } catch (error, stackTrace) {
      log(
        'FFplayKit: tracked execution failed for session ${session.sessionId}',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _releaseTrackedExecution(session);
    }
  }

  static void _releaseTrackedExecution(FFplaySession session) {
    _trackedExecutions.remove(session);
    _removeCurrentOwner(session);
  }

  static void _clearCurrentIfUntracked(FFplaySession session) {
    if (identical(_activeFFplaySession, session) &&
        !_trackedExecutions.contains(session)) {
      _removeCurrentOwner(session);
    }
  }

  static void _removeCurrentOwner(FFplaySession session) {
    if (!identical(_activeFFplaySession, session)) return;
    _activeFFplaySession = _trackedExecutions.isEmpty
        ? null
        : _trackedExecutions.last;
  }

  /// Installs a test session and tracks a supplied execution Future.
  @visibleForTesting
  static void trackExecutionForTest(
    FFplaySession session,
    Future<void> Function() execution,
  ) {
    _activeFFplaySession = session;
    if (!_trackedExecutions.add(session)) return;
    unawaited(() async {
      try {
        await execution();
      } catch (error, stackTrace) {
        log(
          'FFplayKit test tracked execution failed for session ${session.sessionId}',
          error: error,
          stackTrace: stackTrace,
        );
      } finally {
        _releaseTrackedExecution(session);
      }
    }());
  }

  /// Sets the current session for [start] lifecycle tests.
  @visibleForTesting
  static void setCurrentSessionForTest(FFplaySession? session) {
    _activeFFplaySession = session;
  }

  /// Pauses playback if there is an active global session.
  static void pause() {
    if (_activeFFplaySession != null) {
      _activeFFplaySession!.pause();
    }
  }

  /// Resumes playback if there is an active session.
  static void resume() {
    if (_activeFFplaySession != null) {
      _activeFFplaySession!.resume();
    }
  }

  /// Stops playback for the active global session.
  static void stop() {
    if (_activeFFplaySession != null) {
      _activeFFplaySession!.stop();
    }
  }

  /// Returns true if the active session is currently playing.
  static bool isPlaying() {
    if (_activeFFplaySession != null) {
      return _activeFFplaySession!.isPlaying();
    }
    return false;
  }

  /// Returns true if the active session is currently paused.
  static bool isPaused() {
    if (_activeFFplaySession != null) {
      return _activeFFplaySession!.isPaused();
    }
    return false;
  }

  /// Closes the active session and releases resources.
  static void close() {
    final session = _activeFFplaySession;
    if (session != null) {
      session.close();
      _clearCurrentIfUntracked(session);
    }
  }

  /// Returns true if there is no active playback session.
  static bool isClosed() => _activeFFplaySession == null;

  /// Sets the current playback position to [seconds].
  static void setPosition(double seconds) {
    if (_activeFFplaySession != null) {
      _activeFFplaySession!.setPosition(seconds);
    }
  }

  /// Gets the current playback position in seconds.
  static double getPosition() {
    if (_activeFFplaySession != null) {
      return _activeFFplaySession!.getPosition();
    }
    return 0;
  }

  /// Gets the total duration of the media in seconds.
  static double getDuration() {
    if (_activeFFplaySession != null) {
      return _activeFFplaySession!.getMediaDuration();
    }
    return 0.0;
  }
}
