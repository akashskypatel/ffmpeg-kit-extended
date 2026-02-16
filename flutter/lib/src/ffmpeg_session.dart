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
import 'generated/ffmpeg_kit_bindings.dart';
import 'session.dart';
import 'session_queue_manager.dart';

/// A session for executing FFmpeg commands.
///
/// Use this class to run transcoding, filtering, and other FFmpeg tasks.
class FFmpegSession extends Session {
  FFmpegSessionCompleteCallback? _completeCallback;
  FFmpegLogCallback? _logCallback;
  FFmpegStatisticsCallback? _statisticsCallback;

  /// Creates a new [FFmpegSession] from a native [handle] and the executed [command].
  ///
  /// This constructor is typically used internally or when restoring sessions from history.
  FFmpegSession.fromHandle(Pointer<Void> handle, String command) {
    this.handle = handle;
    this.command = command;
    this.startTime = DateTime.now();
    this.sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
    this.registerFinalizer();
  }

  /// Creates a new [FFmpegSession] to execute the given [command].
  ///
  /// Optional callbacks can be provided:
  /// - [completeCallback]: Called when the session finishes execution.
  /// - [logCallback]: Called for each log line produced by FFmpeg.
  /// - [statisticsCallback]: Called periodically with encoding statistics.
  FFmpegSession(
    String command, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) {
    final cmdPtr = command.toNativeUtf8(allocator: calloc);
    try {
      this.handle = ffmpeg.ffmpeg_kit_create_session(cmdPtr.cast());
      this.command = command;
      this.startTime = DateTime.now();
      this.sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
      this.registerFinalizer();
    } finally {
      calloc.free(cmdPtr);
    }

    if (completeCallback != null ||
        logCallback != null ||
        statisticsCallback != null) {
      if (completeCallback != null) this._completeCallback = completeCallback;
      if (logCallback != null) this._logCallback = logCallback;
      if (statisticsCallback != null)
        this._statisticsCallback = statisticsCallback;
      final int callbackId = CallbackManager().nextCallbackId++;
      CallbackManager().callbackIdToSessionId[callbackId] = sessionId;
      CallbackManager().ffmpegSessions[sessionId] = this;
    }
  }

  /// Facilitates creating a new [FFmpegSession].
  ///
  /// Equivalent to the [FFmpegSession] constructor.
  static FFmpegSession create(String command,
          {FFmpegSessionCompleteCallback? completeCallback,
          FFmpegLogCallback? logCallback,
          FFmpegStatisticsCallback? statisticsCallback}) =>
      FFmpegSession(command,
          completeCallback: completeCallback,
          logCallback: logCallback,
          statisticsCallback: statisticsCallback);

  /// The callback invoked when the session is complete.
  FFmpegSessionCompleteCallback? get completeCallback => _completeCallback;

  /// The callback invoked for each log line.
  FFmpegLogCallback? get logCallback => _logCallback;

  /// The callback invoked for periodic statistics updates.
  FFmpegStatisticsCallback? get statisticsCallback => _statisticsCallback;

  /// Sets or updates the [completeCallback] for this session.
  void setCompleteCallback(FFmpegSessionCompleteCallback? completeCallback) {
    if (completeCallback != null) {
      _completeCallback = completeCallback;
      final int callbackId = CallbackManager().nextCallbackId++;
      CallbackManager().callbackIdToSessionId[callbackId] = sessionId;
      CallbackManager().ffmpegSessions[sessionId] = this;
    }
  }

  /// Removes the [completeCallback] for this session.
  void removeCompleteCallback() {
    _completeCallback = null;
    if (_logCallback == null && _statisticsCallback == null) {
      CallbackManager().callbackIdToSessionId.remove(sessionId);
      CallbackManager().ffmpegSessions.remove(sessionId);
    }
  }

  /// Sets or updates the [logCallback] for this session.
  void setLogCallback(FFmpegLogCallback? logCallback) {
    if (logCallback != null) {
      _logCallback = logCallback;
      final int callbackId = CallbackManager().nextCallbackId++;
      CallbackManager().callbackIdToSessionId[callbackId] = sessionId;
      CallbackManager().ffmpegSessions[sessionId] = this;
    }
  }

  /// Removes the [logCallback] for this session.
  void removeLogCallback() {
    _logCallback = null;
    if (_completeCallback == null && _statisticsCallback == null) {
      CallbackManager().callbackIdToSessionId.remove(sessionId);
      CallbackManager().ffmpegSessions.remove(sessionId);
    }
  }

  /// Sets or updates the [statisticsCallback] for this session.
  void setStatisticsCallback(FFmpegStatisticsCallback? statisticsCallback) {
    if (statisticsCallback != null) {
      _statisticsCallback = statisticsCallback;
      final int callbackId = CallbackManager().nextCallbackId++;
      CallbackManager().callbackIdToSessionId[callbackId] = sessionId;
      CallbackManager().ffmpegSessions[sessionId] = this;
    }
  }

  /// Removes the [statisticsCallback] for this session.
  void removeStatisticsCallback() {
    _statisticsCallback = null;
    if (_completeCallback == null && _logCallback == null) {
      CallbackManager().callbackIdToSessionId.remove(sessionId);
      CallbackManager().ffmpegSessions.remove(sessionId);
    }
  }

  /// Executes this session synchronously.
  ///
  /// [strategy] determines how to handle concurrent sessions:
  /// - [SessionExecutionStrategy.queue]: Queue this session (default)
  /// - [SessionExecutionStrategy.cancelAndReplace]: Cancel current and execute immediately
  /// - [SessionExecutionStrategy.rejectIfBusy]: Throw exception if busy
  ///
  /// Returns the current session object.
  FFmpegSession execute({
    SessionExecutionStrategy strategy = SessionExecutionStrategy.queue,
  }) {
    // Truly synchronous execution blocks the current isolate
    ffmpeg.ffmpeg_kit_session_execute(handle);
    return this;
  }

  /// Creates and executes a [FFmpegSession] synchronously.
  ///
  /// [strategy] determines how to handle concurrent sessions.
  static FFmpegSession executeCommand(
    String command, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
    SessionExecutionStrategy strategy = SessionExecutionStrategy.queue,
  }) {
    final session = FFmpegSession.create(command,
        completeCallback: completeCallback,
        logCallback: logCallback,
        statisticsCallback: statisticsCallback);
    return session.execute(strategy: strategy);
  }

  /// Creates and executes a [FFmpegSession] asynchronously.
  ///
  /// [strategy] determines how to handle concurrent sessions.
  static Future<FFmpegSession> executeCommandAsync(
    String command, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
    SessionExecutionStrategy strategy = SessionExecutionStrategy.queue,
  }) async {
    final session = FFmpegSession.create(command,
        completeCallback: completeCallback,
        logCallback: logCallback,
        statisticsCallback: statisticsCallback);
    return await session.executeAsync(strategy: strategy);
  }

  /// Executes this session asynchronously.
  ///
  /// Callbacks can be optionally overridden here.
  ///
  /// [strategy] determines how to handle concurrent sessions:
  /// - [SessionExecutionStrategy.queue]: Queue this session (default)
  /// - [SessionExecutionStrategy.cancelAndReplace]: Cancel current and execute immediately
  /// - [SessionExecutionStrategy.rejectIfBusy]: Throw exception if busy
  Future<FFmpegSession> executeAsync({
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
    SessionExecutionStrategy strategy = SessionExecutionStrategy.queue,
  }) async {
    if (completeCallback != null) this._completeCallback = completeCallback;
    if (logCallback != null) this._logCallback = logCallback;
    if (statisticsCallback != null)
      this._statisticsCallback = statisticsCallback;

    // Start execution through queue manager
    // The queue manager needs to wait for the session to complete
    await SessionQueueManager().executeSession(
      this,
      () async {
        final sessionCompleter = Completer<void>();

        // Store the original callback
        final originalCallback = this._completeCallback;

        // Wrap the callback to complete our completer
        this._completeCallback = (session) {
          // Call the original callback if it exists
          originalCallback?.call(session);
          // Complete our completer to signal the queue manager
          if (!sessionCompleter.isCompleted) {
            sessionCompleter.complete();
          }
        };

        final cmdPtr = command.toNativeUtf8(allocator: calloc);
        final int callbackId = CallbackManager().nextCallbackId++;
        CallbackManager().callbackIdToFFmpegSession[callbackId] = this;

        // Remove old session mapping
        CallbackManager().ffmpegSessions.remove(sessionId);

        FFmpegSessionHandle newHandle;
        try {
          newHandle = ffmpeg.ffmpeg_kit_execute_async_full(
              cmdPtr.cast(),
              nativeFFmpegComplete.nativeFunction,
              nativeFFmpegLog.nativeFunction,
              nativeFFmpegStatistics.nativeFunction,
              Pointer<Void>.fromAddress(callbackId),
              0);
        } finally {
          calloc.free(cmdPtr);
        }

        this.handle = newHandle;
        this.sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
        this.registerFinalizer();

        CallbackManager().callbackIdToSessionId[callbackId] = sessionId;
        CallbackManager().ffmpegSessions[sessionId] = this;

        // Wait for the session to complete
        await sessionCompleter.future;
      },
      strategy: strategy,
    );

    return this;
  }

  @override
  bool isFFmpegSession() => true;

  @override
  bool isFFplaySession() => false;

  @override
  bool isFFprobeSession() => false;

  @override
  bool isMediaInformationSession() => false;
}
