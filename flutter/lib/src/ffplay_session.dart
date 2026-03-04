/// FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
/// Copyright (C) 2026 Akash Patel
///
/// This library is free software; you can redistribute it and/or
/// modify it under the terms of the GNU Lesser General Public
/// License as published by the Free Software Foundation; either
/// version 2.1 of the License, or (at your option) any later version.
///
/// This library is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
/// Lesser General Public License for more details.
///
/// You should have received a copy of the GNU Lesser General Public
/// License along with this library; if not, write to the Free Software
/// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
library;

import 'dart:async';
import 'dart:developer';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'callback_manager.dart';
import 'ffmpeg_kit_flutter_loader.dart';
import 'ffplay_kit.dart';
import 'session.dart';
import 'session_queue_manager.dart';

/// A session for playing media using FFplay.
///
/// This class provides methods to control playback (start, pause, resume, stop)
/// and to query or set playback properties like position and volume.
class FFplaySession extends Session {
  FFplaySessionCompleteCallback? _completeCallback;

  /// Creates a new [FFplaySession] from a native [handle] and the executed [command].
  ///
  /// This constructor is typically used internally or when restoring sessions from history.
  FFplaySession.fromHandle(Pointer<Void> handle, String command) {
    this.handle = handle;
    this.command = command;
    sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
    registerFinalizer();
  }

  /// Creates a new [FFplaySession] to execute the given [command].
  ///
  /// **WARNING**: Direct instantiation is discouraged. Use [FFplayKit.createSession]
  /// or [FFplayKit.execute] instead to ensure proper global session management.
  /// Direct session creation bypasses the global session tracking and may lead
  /// to multiple concurrent sessions.
  ///
  /// - [command]: The FFplay command to run.
  /// - [completeCallback]: Optional callback invoked when playback ends.
  /// - [timeout]: Connection timeout in milliseconds (default 500).
  FFplaySession(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) {
    _timeout = timeout;

    final cmdPtr = command.toNativeUtf8();
    try {
      handle = ffmpeg.ffplay_kit_create_session(cmdPtr.cast());
      this.command = command;
      sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
      registerFinalizer();
    } finally {
      calloc.free(cmdPtr);
    }

    if (completeCallback != null) {
      _completeCallback = completeCallback;
      final int callbackId = CallbackManager().nextCallbackId++;
      CallbackManager().callbackIdToSessionId[callbackId] = sessionId;
      CallbackManager().ffplaySessions[sessionId] = this;
    }
  }

  /// Facilitates creating a new [FFplaySession].
  ///
  /// **DEPRECATED**: Use [FFplayKit.createSession] instead to ensure proper
  /// global session management. Direct session creation bypasses the global
  /// session tracking and may lead to multiple concurrent sessions.
  @Deprecated(
      'Use FFplayKit.createSession instead for proper global session management')
  static FFplaySession create(String command,
          {FFplaySessionCompleteCallback? completeCallback,
          int timeout = 500}) =>
      FFplaySession(command,
          timeout: timeout, completeCallback: completeCallback);

  /// Internal factory method for creating sessions through [FFplayKit].
  ///
  /// This method should only be called by [FFplayKit] to ensure proper
  /// global session management. Direct use of this method is discouraged.
  static FFplaySession createGlobal(String command,
          {FFplaySessionCompleteCallback? completeCallback,
          int timeout = 500}) =>
      FFplaySession(command,
          timeout: timeout, completeCallback: completeCallback);

  /// The callback invoked when the session is complete.
  FFplaySessionCompleteCallback? get completeCallback => _completeCallback;

  /// Sets or updates the [completeCallback] for this session.
  void setCompleteCallback(FFplaySessionCompleteCallback? completeCallback) {
    if (completeCallback != null) {
      _completeCallback = completeCallback;
      final int callbackId = CallbackManager().nextCallbackId++;
      CallbackManager().callbackIdToSessionId[callbackId] = sessionId;
      CallbackManager().ffplaySessions[sessionId] = this;
    }
  }

  /// Removes the [completeCallback] for this session.
  void removeCompleteCallback() {
    _completeCallback = null;
    CallbackManager().callbackIdToSessionId.remove(sessionId);
    CallbackManager().ffplaySessions.remove(sessionId);
  }

  int _timeout = 500;

  /// The connection timeout in milliseconds.
  int get timeout => _timeout;

  /// Sets the connection [timeout] in milliseconds.
  void setTimeout(int timeout) {
    _timeout = timeout;
  }

  /// Starts playback.
  void start() {
    log("FFplaySession.start handle=$handle");
    ffmpeg.ffplay_kit_session_start(handle);
  }

  /// Pauses playback.
  void pause() {
    log("FFplaySession.pause handle=$handle");
    ffmpeg.ffplay_kit_session_pause(handle);
  }

  /// Resumes paused playback.
  void resume() {
    log("FFplaySession.resume handle=$handle");
    ffmpeg.ffplay_kit_session_resume(handle);
  }

  /// Stops playback.
  void stop() {
    log("FFplaySession.stop handle=$handle");
    ffmpeg.ffplay_kit_session_stop(handle);
  }

  /// Closes the session and releases native resources.
  void close() {
    log("FFplaySession.close handle=$handle");
    ffmpeg.ffplay_kit_session_close(handle);
  }

  @override
  void cancel() {
    stop();
    super.cancel();
  }

  /// Seeks to the specified position in [seconds].
  void seek(double seconds) {
    log("FFplaySession.seek handle=$handle seconds=$seconds");
    ffmpeg.ffplay_kit_session_seek(handle, seconds);
  }

  /// Executes this session synchronously.
  FFplaySession execute() {
    log("FFplaySession.execute handle=$handle");
    final completer = Completer<void>();
    SessionQueueManager().executeSession(
      this,
      () async {
        ffmpeg.ffplay_kit_session_execute(handle, timeout);
        completer.complete();
      },
    ).catchError(completer.completeError);
    return this;
  }

  /// Creates and executes a [FFplaySession] synchronously.
  ///
  /// **DEPRECATED**: Use [FFplayKit.execute] instead to ensure proper
  /// global session management. Direct session execution bypasses the global
  /// session tracking and may lead to multiple concurrent sessions.
  @Deprecated(
      'Use FFplayKit.execute instead for proper global session management')
  static FFplaySession executeCommand(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) {
    final session = FFplaySession.create(command,
        timeout: timeout, completeCallback: completeCallback);
    return session.execute();
  }

  /// Creates and executes a [FFplaySession] asynchronously.
  ///
  /// **DEPRECATED**: Use [FFplayKit.executeAsync] instead to ensure proper
  /// global session management. Direct session execution bypasses the global
  /// session tracking and may lead to multiple concurrent sessions.
  @Deprecated(
      'Use FFplayKit.executeAsync instead for proper global session management')
  static Future<FFplaySession> executeCommandAsync(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) async {
    final session = FFplaySession.create(command,
        timeout: timeout, completeCallback: completeCallback);
    return await session.executeAsync();
  }

  /// Executes this session asynchronously.
  ///
  /// - [timeout]: Connection timeout in milliseconds.
  /// - [completeCallback]: Optional callback when playback ends.
  Future<FFplaySession> executeAsync(
      {int timeout = 500,
      FFplaySessionCompleteCallback? completeCallback}) async {
    if (completeCallback != null) _completeCallback = completeCallback;
    setTimeout(timeout);

    final startedCompleter = Completer<void>();

    final executionFuture = SessionQueueManager().executeSession(
      this,
      () async {
        final sessionCompleter = Completer<void>();

        // Store the original callback
        final originalCallback = _completeCallback;

        // Wrap the callback to complete our completer
        _completeCallback = (session) {
          originalCallback?.call(session);
          if (!sessionCompleter.isCompleted) {
            sessionCompleter.complete();
          }
        };

        ffmpeg.ffmpeg_kit_config_enable_ffplay_session_complete_callback(
            nativeFFplayComplete.nativeFunction, nullptr);
        CallbackManager().ffplaySessions[sessionId] = this;

        try {
          ffmpeg.ffplay_kit_session_execute_async(handle, _timeout);
        } catch (e) {
          if (!startedCompleter.isCompleted) startedCompleter.completeError(e);
          rethrow;
        }

        // Signal that the session has started and handle is valid
        if (!startedCompleter.isCompleted) {
          startedCompleter.complete();
        }

        // Wait for the session to complete (this keeps the queue blocked)
        await sessionCompleter.future;
      },
    );

    // Handle initialization errors or rejection
    executionFuture.catchError((e) {
      if (!startedCompleter.isCompleted) startedCompleter.completeError(e);
    });

    await startedCompleter.future;
    return this;
  }

  /// Gets the total duration of the media in seconds.
  double getMediaDuration() {
    final d = ffmpeg.ffplay_kit_session_get_duration(handle);
    log("FFplaySession.getMediaDuration handle=$handle val=$d");
    return d;
  }

  /// Gets the current playback position in seconds.
  double getPosition() {
    final p = ffmpeg.ffplay_kit_session_get_position(handle);
    log("FFplaySession.getPosition handle=$handle val=$p");
    return p;
  }

  /// Sets the current playback position to [seconds].
  void setPosition(double seconds) {
    log("FFplaySession.setPosition handle=$handle seconds=$seconds");
    ffmpeg.ffplay_kit_session_set_position(handle, seconds);
  }

  /// Gets the current playback volume (0.0 to 1.0).
  double getVolume() => ffmpeg.ffplay_kit_session_get_volume(handle) / 128.0;

  /// Sets the playback [volume] (0.0 to 1.0).
  void setVolume(double volume) =>
      ffmpeg.ffplay_kit_session_set_volume(handle, volume * 128.0);

  /// Returns true if the media is currently playing.
  bool isPlaying() {
    final playing = ffmpeg.ffplay_kit_session_is_playing(handle);
    log("FFplaySession.isPlaying handle=$handle val=$playing");
    return playing;
  }

  /// Returns true if the media is current paused.
  bool isPaused() {
    final paused = ffmpeg.ffplay_kit_session_is_paused(handle);
    log("FFplaySession.isPaused handle=$handle val=$paused");
    return paused;
  }

  @override
  bool isFFmpegSession() => false;

  @override
  bool isFFplaySession() => true;

  @override
  bool isFFprobeSession() => false;

  @override
  bool isMediaInformationSession() => false;
}
