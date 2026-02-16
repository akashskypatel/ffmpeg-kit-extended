/**
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

import '../ffmpeg_kit_flutter.dart';

/// Strategy for handling conflicts when creating a new FFplay session
/// while another session is already active.
enum SessionConflictStrategy {
  /// Terminate the existing session immediately and start the new one
  terminate,

  /// Wait for the existing session to complete before starting the new one
  waitForCompletion,
}

// Only one FFplay session can be active at a time.
FFplaySession? _activeFFplaySession;

// Completer to track when the active session completes
Completer<void>? _sessionCompleter;

/// A utility class for managing global FFplay playback.
///
/// Since FFplay typically involves a single active playback window/session,
/// [FFplayKit] provides a convenient way to execute commands and control
/// the current active session.
class FFplayKit {
  /// Executes an FFplay [command] and starts playback.
  ///
  /// [strategy] determines how to handle an existing active session:
  /// - [SessionConflictStrategy.terminate]: Terminates the existing session immediately (default)
  /// - [SessionConflictStrategy.waitForCompletion]: Waits for the existing session to complete
  static Future<FFplaySession> execute(
    String command, {
    SessionConflictStrategy strategy = SessionConflictStrategy.terminate,
  }) =>
      executeAsync(command, strategy: strategy);

  /// Executes an FFplay [command] asynchronously and starts playback.
  ///
  /// [onComplete] is called when playback ends.
  /// [strategy] determines how to handle an existing active session:
  /// - [SessionConflictStrategy.terminate]: Terminates the existing session immediately (default)
  /// - [SessionConflictStrategy.waitForCompletion]: Waits for the existing session to complete
  static Future<FFplaySession> executeAsync(
    String command, {
    FFplaySessionCompleteCallback? onComplete,
    SessionConflictStrategy strategy = SessionConflictStrategy.terminate,
  }) async {
    await _handleExistingSession(strategy);

    // Create a new completer for this session
    _sessionCompleter = Completer<void>();

    // Wrap the user's callback to complete our internal completer
    void wrappedCallback(FFplaySession session) {
      if (onComplete != null) {
        onComplete(session);
      }

      // Only clear if this session is still the active one
      if (_activeFFplaySession == session) {
        _activeFFplaySession = null;
        _sessionCompleter?.complete();
        _sessionCompleter = null;
      } else {
        // Just complete the secondary completer if it exists
        // (though this shouldn't happen much with the check above)
      }
    }

    _activeFFplaySession = FFplaySession.createGlobal(
      command,
      completeCallback: wrappedCallback,
    );
    await _activeFFplaySession!.executeAsync();
    return _activeFFplaySession!;
  }

  /// Creates a new [FFplaySession] without executing it.
  ///
  /// [strategy] determines how to handle an existing active session:
  /// - [SessionConflictStrategy.terminate]: Terminates the existing session immediately (default)
  /// - [SessionConflictStrategy.waitForCompletion]: Waits for the existing session to complete
  ///
  /// Use [execute] or [executeAsync] to execute the session.
  static Future<FFplaySession> createSession(
    String command, {
    FFplaySessionCompleteCallback? onComplete,
    SessionConflictStrategy strategy = SessionConflictStrategy.terminate,
  }) async {
    await _handleExistingSession(strategy);

    // Create a new completer for this session
    _sessionCompleter = Completer<void>();

    // Wrap the user's callback to complete our internal completer
    void wrappedCallback(FFplaySession session) {
      if (onComplete != null) {
        onComplete(session);
      }

      // Only clear if this session is still the active one
      if (_activeFFplaySession == session) {
        _activeFFplaySession = null;
        _sessionCompleter?.complete();
        _sessionCompleter = null;
      }
    }

    _activeFFplaySession = FFplaySession.createGlobal(
      command,
      completeCallback: wrappedCallback,
    );
    return _activeFFplaySession!;
  }

  /// Internal method to handle existing sessions based on the conflict strategy.
  static Future<void> _handleExistingSession(
      SessionConflictStrategy strategy) async {
    if (_activeFFplaySession == null) {
      return;
    }

    switch (strategy) {
      case SessionConflictStrategy.terminate:
        final sessionToStop = _activeFFplaySession;
        _activeFFplaySession = null;
        _sessionCompleter = null;

        if (sessionToStop != null) {
          sessionToStop.stop();
        }
        break;

      case SessionConflictStrategy.waitForCompletion:
        if (_sessionCompleter != null && !_sessionCompleter!.isCompleted) {
          await _sessionCompleter!.future;
        }
        _activeFFplaySession = null;
        _sessionCompleter = null;
        break;
    }
  }

  /// Cancels a [session] if it is currently running.
  static void cancel(FFplaySession session) => session.cancel();

  /// Returns the current active [FFplaySession], if any.
  static FFplaySession? getCurrentSession() => _activeFFplaySession;

  /// Returns all active FFplay sessions. Always returns single element
  /// since FFplay can only have one active session.
  static List<FFplaySession> getFFplaySessions() =>
      FFmpegKitExtended.getFFplaySessions();

  /// Returns the current active [FFplaySession], if any.
  static FFplaySession? get currentSession => _activeFFplaySession;

  /// Returns true if the current session is playing.
  static bool get playing => _activeFFplaySession?.isPlaying() ?? false;

  /// Returns true if the current session is paused.
  static bool get paused => _activeFFplaySession?.isPaused() ?? false;

  /// Returns the current playback position in seconds.
  static double get position => _activeFFplaySession?.getPosition() ?? 0;

  /// Returns the total duration of the media in seconds.
  static double get duration => _activeFFplaySession?.getDuration() ?? 0;

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
    if (_activeFFplaySession != null) {
      _activeFFplaySession!.executeAsync();
    }
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
    if (_activeFFplaySession != null) {
      _activeFFplaySession!.close();
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
      return _activeFFplaySession!.getDuration();
    }
    return 0;
  }
}
