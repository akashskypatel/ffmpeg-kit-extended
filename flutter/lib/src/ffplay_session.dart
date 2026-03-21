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

import '../ffmpeg_kit_extended_flutter.dart';
import 'callback_manager.dart';
import 'ffmpeg_kit_flutter_loader.dart';

/// A session for playing media using FFplay.
///
/// Provides methods to control playback (start, pause, resume, stop, seek)
/// and to query or set playback properties such as position and volume.
///
/// ### Lifecycle
/// Use [FFplayKit] to create and execute sessions so that global session
/// tracking is maintained.  The deprecated [create] / [executeCommand] /
/// [executeCommandAsync] static helpers still work but bypass that tracking.
class FFplaySession extends Session {
  FFplaySessionCompleteCallback? _completeCallback;

  bool _registered = false;

  int _timeout;

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Restores an [FFplaySession] from an existing native [handle].
  ///
  /// Used internally when wrapping handles from the session-history API.
  /// No callbacks are registered; call [setCompleteCallback] if needed.
  FFplaySession.fromHandle(Pointer<Void> handle, String command)
      : _timeout = 500 {
    FFmpegKitExtended.requireInitialized();
    this.handle = handle;
    this.command = command;
    sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
    registerFinalizer();
  }

  /// Creates a new [FFplaySession] for [command].
  ///
  /// **Prefer [FFplayKit.createSession]** to ensure the global current-session
  /// reference is updated correctly.
  ///
  /// - [completeCallback]: Invoked once when playback ends.
  /// - [timeout]: Connection timeout in milliseconds (default 500).
  FFplaySession(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) : _timeout = timeout {
    FFmpegKitExtended.requireInitialized();
    // toNativeUtf8 uses the calloc allocator by default.
    final cmdPtr = command.toNativeUtf8(allocator: calloc);
    try {
      handle = ffmpeg.ffplay_kit_create_session(cmdPtr.cast());
      this.command = command;
      sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
      registerFinalizer();
    } finally {
      calloc.free(cmdPtr); // must match the allocator used by toNativeUtf8
    }

    _completeCallback = completeCallback;

    CallbackManager().registerFFplaySession(this);
    _registered = true;
  }

  // ---------------------------------------------------------------------------
  // Static helpers (deprecated wrappers kept for API compatibility)
  // ---------------------------------------------------------------------------

  /// @deprecated Use [FFplayKit.createSession] for proper global tracking.
  @Deprecated(
      'Use FFplayKit.createSession for proper global session management')
  static FFplaySession create(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) =>
      FFplaySession(command,
          timeout: timeout, completeCallback: completeCallback);

  /// Internal factory used by [FFplayKit] — not part of the public API.
  static FFplaySession createGlobal(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) =>
      FFplaySession(command,
          timeout: timeout, completeCallback: completeCallback);

  // ---------------------------------------------------------------------------
  // Callback accessors / mutators
  // ---------------------------------------------------------------------------

  /// The callback invoked once when playback ends.
  FFplaySessionCompleteCallback? get completeCallback => _completeCallback;

  /// Sets or replaces the completion callback.
  void setCompleteCallback(FFplaySessionCompleteCallback? completeCallback) {
    _completeCallback = completeCallback;
    _ensureRegistered();
  }

  /// Clears the completion callback and unregisters the session from
  /// [CallbackManager] if no other callbacks remain.
  void removeCompleteCallback() {
    _completeCallback = null;
    _unregister();
  }

  // ---------------------------------------------------------------------------
  // Playback configuration
  // ---------------------------------------------------------------------------

  /// The connection timeout in milliseconds.
  int get timeout => _timeout;

  /// Sets the connection [timeout] in milliseconds.
  void setTimeout(int timeout) => _timeout = timeout;

  // ---------------------------------------------------------------------------
  // Playback controls
  // ---------------------------------------------------------------------------

  /// Starts playback.
  void start() {
    FFmpegKitExtended.requireInitialized();
    log('FFplaySession.start handle=$handle');
    ffmpeg.ffplay_kit_session_start(handle);
  }

  /// Pauses playback.
  void pause() {
    FFmpegKitExtended.requireInitialized();
    log('FFplaySession.pause handle=$handle');
    ffmpeg.ffplay_kit_session_pause(handle);
  }

  /// Resumes paused playback.
  void resume() {
    FFmpegKitExtended.requireInitialized();
    log('FFplaySession.resume handle=$handle');
    ffmpeg.ffplay_kit_session_resume(handle);
  }

  /// Stops playback.
  void stop() {
    FFmpegKitExtended.requireInitialized();
    log('FFplaySession.stop handle=$handle');
    ffmpeg.ffplay_kit_session_stop(handle);
  }

  /// Closes the session and releases native resources.
  void close() {
    FFmpegKitExtended.requireInitialized();
    log('FFplaySession.close handle=$handle');
    ffmpeg.ffplay_kit_session_close(handle);
  }

  /// Cancels the session — stops playback then delegates to [Session.cancel].
  @override
  void cancel() {
    stop();
    super.cancel();
  }

  /// Seeks to [seconds] from the start of the media.
  void seek(double seconds) {
    FFmpegKitExtended.requireInitialized();
    log('FFplaySession.seek handle=$handle seconds=$seconds');
    ffmpeg.ffplay_kit_session_seek(handle, seconds);
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  /// Enqueues this session for synchronous native execution and returns `this`
  /// immediately.
  FFplaySession execute() {
    log('FFplaySession.execute handle=$handle');
    SessionQueueManager().executeSession(
      this,
      () async {
        FFmpegKitExtended.requireInitialized();
        ffmpeg.ffplay_kit_session_execute(handle, _timeout);
        try {
          _completeCallback?.call(this);
        } catch (e, st) {
          log('FFplaySession.execute: error in completeCallback: $e\n$st');
        }
        _unregister();
      },
    ).catchError((Object e, StackTrace st) {
      log('FFplaySession.execute: queue error: $e\n$st');
    });
    return this;
  }

  /// @deprecated Use [FFplayKit.execute] for proper global session management.
  @Deprecated('Use FFplayKit.execute for proper global session management')
  static FFplaySession executeCommand(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) =>
      FFplaySession.create(command,
              timeout: timeout, completeCallback: completeCallback)
          .execute();

  /// @deprecated Use [FFplayKit.executeAsync] for proper global session management.
  @Deprecated('Use FFplayKit.executeAsync for proper global session management')
  static Future<FFplaySession> executeCommandAsync(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) =>
      FFplaySession.create(command,
              timeout: timeout, completeCallback: completeCallback)
          .executeAsync();

  /// Executes this session asynchronously and returns a [Future] that
  /// resolves once playback finishes or is cancelled.
  Future<FFplaySession> executeAsync({
    int? timeout,
    FFplaySessionCompleteCallback? completeCallback,
  }) async {
    if (timeout != null) _timeout = timeout;
    if (completeCallback != null) _completeCallback = completeCallback;
    _ensureRegistered();

    await SessionQueueManager().executeSession(this, _runAsync);
    return this;
  }

  // ---------------------------------------------------------------------------
  // Playback properties
  // ---------------------------------------------------------------------------

  /// Returns the total duration of the media in seconds.
  double getMediaDuration() {
    FFmpegKitExtended.requireInitialized();
    final d = ffmpeg.ffplay_kit_session_get_duration(handle);
    log('FFplaySession.getMediaDuration handle=$handle val=$d');
    return d;
  }

  /// Returns the current playback position in seconds.
  double getPosition() {
    FFmpegKitExtended.requireInitialized();
    final p = ffmpeg.ffplay_kit_session_get_position(handle);
    log('FFplaySession.getPosition handle=$handle val=$p');
    return p;
  }

  /// Seeks to [seconds] from the start of the media.
  void setPosition(double seconds) {
    FFmpegKitExtended.requireInitialized();
    log('FFplaySession.setPosition handle=$handle seconds=$seconds');
    ffmpeg.ffplay_kit_session_set_position(handle, seconds);
  }

  /// Returns the current playback volume in the range [0.0, 1.0].
  ///
  /// The native layer stores volume as an integer in [0, 128] (SDL_MIX_MAXVOLUME).
  /// This getter normalises it to [0.0, 1.0] for a consistent API.
  double getVolume() {
    FFmpegKitExtended.requireInitialized();
    return ffmpeg.ffplay_kit_session_get_volume(handle) / 128.0;
  }

  /// Sets the playback [volume] in the range [0.0, 1.0].
  ///
  /// Values outside [0.0, 1.0] are clamped before being passed to the native
  /// layer to prevent SDL audio distortion.
  void setVolume(double volume) {
    FFmpegKitExtended.requireInitialized();
    final clamped = volume.clamp(0.0, 1.0);
    ffmpeg.ffplay_kit_session_set_volume(handle, clamped * 128.0);
  }

  /// Returns `true` if the media is currently playing.
  bool isPlaying() {
    FFmpegKitExtended.requireInitialized();
    final playing = ffmpeg.ffplay_kit_session_is_playing(handle);
    log('FFplaySession.isPlaying handle=$handle val=$playing');
    return playing;
  }

  /// Returns `true` if the media is currently paused.
  bool isPaused() {
    FFmpegKitExtended.requireInitialized();
    final paused = ffmpeg.ffplay_kit_session_is_paused(handle);
    log('FFplaySession.isPaused handle=$handle val=$paused');
    return paused;
  }

  // ---------------------------------------------------------------------------
  // Session type identity
  // ---------------------------------------------------------------------------

  /// Returns true if this is an FFmpeg session.
  @override
  bool isFFmpegSession() => false;

  /// Returns true if this is an FFplay session.
  @override
  bool isFFplaySession() => true;

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
    final sessionCompleter = Completer<void>();
    final userCompleteCallback = _completeCallback;

    _completeCallback = (FFplaySession s) {
      try {
        userCompleteCallback?.call(s);
      } catch (e, st) {
        log('FFplaySession: error in completeCallback: $e\n$st');
      }
      if (!sessionCompleter.isCompleted) sessionCompleter.complete();
      _unregister();
    };

    ffmpeg.ffmpeg_kit_config_enable_ffplay_session_complete_callback(
        nativeFFplayComplete.nativeFunction, nullptr);

    try {
      ffmpeg.ffplay_kit_session_execute_async(handle, _timeout);
    } catch (e, st) {
      log('FFplaySession: error starting async session $sessionId: $e\n$st');
      _completeCallback = userCompleteCallback;
      _unregister();
      if (!sessionCompleter.isCompleted) sessionCompleter.complete();
      rethrow;
    }

    await sessionCompleter.future;
  }

  /// Ensures this session is registered with the callback manager.
  void _ensureRegistered() {
    if (_registered) return;
    CallbackManager().registerFFplaySession(this);
    _registered = true;
  }

  /// Unregisters this session from the callback manager.
  void _unregister() {
    if (!_registered) return;
    _registered = false;
    CallbackManager().unregisterFFplaySession(sessionId);
  }
}
