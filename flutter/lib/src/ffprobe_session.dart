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
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'callback_manager.dart';
import 'ffmpeg_kit_flutter_loader.dart';
import 'media_information.dart';
import 'media_information_session.dart';
import 'session.dart';
import 'session_queue_manager.dart';

/// A session for executing FFprobe commands.
///
/// Use this class to retrieve media metadata and stream information.
class FFprobeSession extends Session {
  FFprobeSessionCompleteCallback? _completeCallback;

  /// Creates a new [FFprobeSession] to execute the given [command].
  ///
  /// - [command]: The FFprobe command to run.
  /// - [completeCallback]: Optional callback invoked when the command finishes.
  FFprobeSession(
    String command, {
    FFprobeSessionCompleteCallback? completeCallback,
  }) {
    final cmdPtr = command.toNativeUtf8();
    try {
      this.handle = ffmpeg.ffprobe_kit_create_session(cmdPtr.cast());
      this.command = command;
      this.sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
      this.registerFinalizer();
    } finally {
      calloc.free(cmdPtr);
    }

    if (completeCallback != null) {
      this._completeCallback = completeCallback;
      final int callbackId = CallbackManager().nextCallbackId++;
      CallbackManager().callbackIdToSessionId[callbackId] = sessionId;
      CallbackManager().ffprobeSessions[sessionId] = this;
    }
  }

  /// The callback invoked when the session is complete.
  FFprobeSessionCompleteCallback? get completeCallback => _completeCallback;

  /// Sets or updates the [completeCallback] for this session.
  void setCompleteCallback(FFprobeSessionCompleteCallback? completeCallback) {
    if (completeCallback != null) {
      _completeCallback = completeCallback;
      final int callbackId = CallbackManager().nextCallbackId++;
      CallbackManager().callbackIdToSessionId[callbackId] = sessionId;
      CallbackManager().ffprobeSessions[sessionId] = this;
    }
  }

  /// Removes the [completeCallback] for this session.
  void removeCompleteCallback() {
    _completeCallback = null;
    CallbackManager().callbackIdToSessionId.remove(sessionId);
    CallbackManager().ffprobeSessions.remove(sessionId);
  }

  /// Creates a new [FFprobeSession] from a native [handle] and the executed [command].
  ///
  /// This constructor is typically used internally or when restoring sessions from history.
  FFprobeSession.fromHandle(Pointer<Void> handle, String command) {
    this.handle = handle;
    this.command = command;
    this.sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
    this.registerFinalizer();
  }

  /// Internal constructor for subclasses to initialize without creating a new session.
  FFprobeSession.internal();

  /// Facilitates creating a new [FFprobeSession].
  static FFprobeSession create(String command,
          {FFprobeSessionCompleteCallback? completeCallback}) =>
      FFprobeSession(command, completeCallback: completeCallback);

  /// Executes this session synchronously.
  FFprobeSession execute() {
    final completer = Completer<void>();

    SessionQueueManager().executeSession(
      this,
      () async {
        ffmpeg.ffprobe_kit_session_execute(handle);
        completer.complete();
      },
    ).catchError(completer.completeError);

    return this;
  }

  /// Creates and executes a [FFprobeSession] synchronously.
  static FFprobeSession executeCommand(String command,
      {FFprobeSessionCompleteCallback? completeCallback}) {
    final session =
        FFprobeSession.create(command, completeCallback: completeCallback);
    return session.execute();
  }

  /// Creates and executes a [FFprobeSession] asynchronously.
  static Future<FFprobeSession> executeCommandAsync(String command,
      {FFprobeSessionCompleteCallback? completeCallback}) async {
    final session =
        FFprobeSession.create(command, completeCallback: completeCallback);
    return await session.executeAsync();
  }

  /// Executes this session asynchronously.
  Future<FFprobeSession> executeAsync(
      {FFprobeSessionCompleteCallback? completeCallback}) async {
    if (completeCallback != null) this._completeCallback = completeCallback;

    // Start execution through queue manager
    await SessionQueueManager().executeSession(
      this,
      () async {
        final sessionCompleter = Completer<void>();

        // Store the original callback
        final originalCallback = this._completeCallback;

        // Wrap the callback to complete our completer
        this._completeCallback = (session) {
          originalCallback?.call(session);
          if (!sessionCompleter.isCompleted) {
            sessionCompleter.complete();
          }
        };

        ffmpeg.ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
            nativeFFprobeComplete.nativeFunction, nullptr);
        CallbackManager().ffprobeSessions[sessionId] = this;

        try {
          ffmpeg.ffprobe_kit_session_execute_async(handle);
        } catch (e, stack) {
          print("FFprobeSession: Error executing async session: $e\n$stack");
          if (!sessionCompleter.isCompleted) sessionCompleter.complete();
          rethrow;
        }

        try {
          // Wait for the session to complete
          await sessionCompleter.future;
        } catch (e) {
          print("FFprobeSession: Error waiting for session completion: $e");
        }
      },
    );

    return this;
  }

  /// Returns [MediaInformation] if this is a media information session.
  ///
  /// Subclasses like [MediaInformationSession] override this to provide data.
  MediaInformation? getMediaInformation() => null;

  /// Convenience method to create a [MediaInformationSession] for the given [path].
  static MediaInformationSession createMediaInformationSession(String path) =>
      MediaInformationSession.fromPath(path);

  /// Convenience method to create a [MediaInformationSession] for the given [path] asynchronously.
  static MediaInformationSession createMediaInformationSessionAsync(
    String path, {
    FFprobeSessionCompleteCallback? onComplete,
  }) {
    final session =
        MediaInformationSession.fromPath(path, completeCallback: onComplete);
    return session;
  }

  @override
  bool isFFmpegSession() => false;

  @override
  bool isFFplaySession() => false;

  @override
  bool isFFprobeSession() => true;

  @override
  bool isMediaInformationSession() => false;
}
