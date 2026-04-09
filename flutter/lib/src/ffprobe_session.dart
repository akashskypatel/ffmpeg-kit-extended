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
import 'ffmpeg_kit_extended_flutter_loader.dart';

/// A session for executing FFprobe commands.
///
/// Use this class to retrieve media metadata and stream information.
class FFprobeSession extends Session {
  FFprobeSessionCompleteCallback? _completeCallback;

  bool _registered = false;

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Creates a new [FFprobeSession] for [command].
  ///
  /// - [completeCallback]: Invoked once when the command finishes.
  FFprobeSession(
    String command, {
    FFprobeSessionCompleteCallback? completeCallback,
  }) {
    FFmpegKitExtended.requireInitialized();
    final cmdPtr = command.toNativeUtf8(allocator: calloc);
    try {
      handle = ffmpeg.ffprobe_kit_create_session(cmdPtr.cast());
      this.command = command;
      sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
      registerFinalizer();
    } finally {
      calloc.free(cmdPtr);
    }

    _completeCallback = completeCallback;
    CallbackManager().registerFFprobeSession(this);
    _registered = true;
  }

  /// Restores an [FFprobeSession] from an existing native [handle].
  ///
  /// Used internally when wrapping handles from the session-history API.
  FFprobeSession.fromHandle(Pointer<Void> handle, String command) {
    FFmpegKitExtended.requireInitialized();
    this.handle = handle;
    this.command = command;
    sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
    registerFinalizer();
  }

  /// Internal constructor used exclusively by [MediaInformationSession].
  ///
  /// Leaves [handle], [sessionId], and [command] uninitialised; the subclass
  /// constructor is responsible for filling them in before any method is called.
  FFprobeSession.internal() : super();

  // ---------------------------------------------------------------------------
  // Static helpers
  // ---------------------------------------------------------------------------

  /// Equivalent to [FFprobeSession.new].
  static FFprobeSession create(
    String command, {
    FFprobeSessionCompleteCallback? completeCallback,
  }) =>
      FFprobeSession(command, completeCallback: completeCallback);

  // ---------------------------------------------------------------------------
  // Callback accessors / mutators
  // ---------------------------------------------------------------------------

  /// The callback invoked once when execution completes.
  FFprobeSessionCompleteCallback? get completeCallback => _completeCallback;

  /// Sets or replaces the completion callback.
  void setCompleteCallback(FFprobeSessionCompleteCallback? completeCallback) {
    _completeCallback = completeCallback;
    _ensureRegistered();
  }

  /// Clears the completion callback and unregisters from [CallbackManager].
  void removeCompleteCallback() {
    _completeCallback = null;
    _unregister();
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  /// Enqueues this session for synchronous native execution and returns `this`
  /// immediately (fire-and-forget).
  FFprobeSession execute() {
    SessionQueueManager().executeSession(
      this,
      () async {
        FFmpegKitExtended.requireInitialized();
        ffmpeg.ffprobe_kit_session_execute(handle);
        try {
          _completeCallback?.call(this);
        } catch (e, st) {
          log('FFprobeSession.execute: error in completeCallback: $e\n$st');
        }
        _unregister();
      },
    ).catchError((Object e, StackTrace st) {
      log('FFprobeSession.execute: queue error: $e\n$st');
    });
    return this;
  }

  /// Creates and enqueues a session for synchronous execution.
  static FFprobeSession executeCommand(
    String command, {
    FFprobeSessionCompleteCallback? completeCallback,
  }) =>
      FFprobeSession.create(command, completeCallback: completeCallback)
          .execute();

  /// Creates and executes a session asynchronously.
  static Future<FFprobeSession> executeCommandAsync(
    String command, {
    FFprobeSessionCompleteCallback? completeCallback,
  }) =>
      FFprobeSession.create(command, completeCallback: completeCallback)
          .executeAsync();

  /// Executes this session asynchronously and returns a [Future] that
  /// resolves when execution finishes.
  Future<FFprobeSession> executeAsync({
    FFprobeSessionCompleteCallback? completeCallback,
  }) async {
    if (completeCallback != null) _completeCallback = completeCallback;
    _ensureRegistered();

    await SessionQueueManager().executeSession(this, _runAsync);
    return this;
  }

  // ---------------------------------------------------------------------------
  // Media information
  // ---------------------------------------------------------------------------

  /// Returns [MediaInformation] if this is a [MediaInformationSession].
  ///
  /// Always returns `null` for plain [FFprobeSession] instances.
  MediaInformation? getMediaInformation() => null;

  /// Creates a [MediaInformationSession] for [path].
  static MediaInformationSession createMediaInformationSession(String path) =>
      MediaInformationSession.fromPath(path);

  /// Creates a [MediaInformationSession] for [path] with an optional callback.
  ///
  /// Note: the returned session is not yet executed; call [executeAsync] on it.
  static MediaInformationSession createMediaInformationSessionAsync(
    String path, {
    MediaInformationSessionCompleteCallback? onComplete,
  }) =>
      MediaInformationSession.fromPath(path, completeCallback: onComplete);

  // ---------------------------------------------------------------------------
  // Session type identity
  // ---------------------------------------------------------------------------

  /// Returns true if this is an FFmpeg session.
  @override
  bool isFFmpegSession() => false;

  /// Returns true if this is an FFplay session.
  @override
  bool isFFplaySession() => false;

  /// Returns true if this is an FFprobe session.
  @override
  bool isFFprobeSession() => true;

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
    final userCompleteCallback = _completeCallback;

    _completeCallback = (FFprobeSession s) {
      // Restore and unregister before calling user code or completing the
      // future, so the session is fully settled from any observer's perspective.
      _completeCallback = userCompleteCallback;
      _unregister();

      try {
        userCompleteCallback?.call(s);
      } catch (e, st) {
        log('FFprobeSession: error in completeCallback for session $sessionId: $e\n$st');
      }

      // Complete last — everything is torn down, so any awaiter gets a fully
      // settled session.
      if (!sessionCompleter.isCompleted) sessionCompleter.complete();
    };

    ffmpeg.ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
        nativeFFprobeComplete.nativeFunction, nullptr);

    try {
      ffmpeg.ffprobe_kit_session_execute_async(handle);
    } catch (e, st) {
      log('FFprobeSession: error starting async session $sessionId: $e\n$st');
      _unregister();
      if (!sessionCompleter.isCompleted) sessionCompleter.complete();
      rethrow;
    }

    try {
      await sessionCompleter.future;
    } catch (e, st) {
      log('FFprobeSession: error awaiting session $sessionId: $e\n$st');
    }
    // No post-await restore needed — already done inside the callback above.
  }

  /// Ensures this session is registered with the callback manager.
  void _ensureRegistered() {
    if (_registered) return;
    CallbackManager().registerFFprobeSession(this);
    _registered = true;
  }

  /// Unregisters this session from the callback manager.
  void _unregister() {
    if (!_registered) return;
    _registered = false;
    CallbackManager().unregisterFFprobeSession(sessionId);
  }
}
