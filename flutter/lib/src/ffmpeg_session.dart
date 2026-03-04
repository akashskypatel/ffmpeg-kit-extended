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

import 'callback_manager.dart';
import 'ffmpeg_kit_flutter_loader.dart';
import 'log.dart';
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
    sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
    registerFinalizer();
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
      handle = ffmpeg.ffmpeg_kit_create_session(cmdPtr.cast());
      this.command = command;
      sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
      registerFinalizer();
    } finally {
      calloc.free(cmdPtr);
    }

    if (completeCallback != null ||
        logCallback != null ||
        statisticsCallback != null) {
      if (completeCallback != null) _completeCallback = completeCallback;
      if (logCallback != null) _logCallback = logCallback;
      if (statisticsCallback != null) {
        _statisticsCallback = statisticsCallback;
      }
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
  /// Returns the current session object.
  FFmpegSession execute() {
    // Synchronous execution must also be serialized
    final completer = Completer<void>();
    SessionQueueManager().executeSession(
      this,
      () async {
        ffmpeg.ffmpeg_kit_session_execute(handle);
        completer.complete();
      },
    ).catchError(completer.completeError);
    return this;
  }

  /// Creates and executes a [FFmpegSession] synchronously.
  static FFmpegSession executeCommand(
    String command, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) {
    final session = FFmpegSession.create(command,
        completeCallback: completeCallback,
        logCallback: logCallback,
        statisticsCallback: statisticsCallback);
    return session.execute();
  }

  /// Creates and executes a [FFmpegSession] asynchronously.
  static Future<FFmpegSession> executeCommandAsync(
    String command, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) async {
    final session = FFmpegSession.create(command,
        completeCallback: completeCallback,
        logCallback: logCallback,
        statisticsCallback: statisticsCallback);
    return await session.executeAsync();
  }

  /// Executes this session asynchronously.
  ///
  /// Callbacks can be optionally overridden here.
  Future<FFmpegSession> executeAsync({
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) async {
    if (completeCallback != null) _completeCallback = completeCallback;
    if (logCallback != null) _logCallback = logCallback;
    if (statisticsCallback != null) {
      _statisticsCallback = statisticsCallback;
    }

    // Start execution through queue manager
    await SessionQueueManager().executeSession(
      this,
      () async {
        final sessionCompleter = Completer<void>();

        // Store the original callback
        final originalCallback = _completeCallback;

        Timer? logPoller;

        // Wrap the callback to complete our completer
        _completeCallback = (session) {
          if (logPoller != null) {
            logPoller.cancel();
            final count = getLogsCount();
            for (int i = logsProcessed; i < count; i++) {
              final message = getLogAt(i);
              final level = getLogLevelAt(i);
              final logObj = Log(sessionId, level, message);
              CallbackManager().globalLogCallback?.call(logObj);
              _logCallback?.call(logObj);
            }
            logsProcessed = count;
          }

          // Call the original callback if it exists
          originalCallback?.call(session);
          // Complete our completer to signal the queue manager
          if (!sessionCompleter.isCompleted) {
            sessionCompleter.complete();
          }
        };

        if (_logCallback != null ||
            CallbackManager().globalLogCallback != null) {
          logPoller =
              Timer.periodic(const Duration(milliseconds: 100), (timer) {
            final count = getLogsCount();
            for (int i = logsProcessed; i < count; i++) {
              final message = getLogAt(i);
              final level = getLogLevelAt(i);
              final logObj = Log(sessionId, level, message);
              CallbackManager().globalLogCallback?.call(logObj);
              _logCallback?.call(logObj);
            }
            logsProcessed = count;

            final state = getState();
            if (state == SessionState.completed ||
                state == SessionState.failed ||
                isCancelled) {
              timer.cancel();
            }
          });
        }

        // Enable global native callbacks to ensure Dart receives completion, log, and stats events
        ffmpeg.ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
            nativeFFmpegComplete.nativeFunction, nullptr);
        ffmpeg.ffmpeg_kit_config_enable_statistics_callback(
            nativeFFmpegStatistics.nativeFunction, nullptr);

        CallbackManager().ffmpegSessions[sessionId] = this;

        try {
          ffmpeg.ffmpeg_kit_session_execute_async(handle);
        } catch (e, stack) {
          log("FFmpegSession: Error executing async session: $e\n$stack");
          if (!sessionCompleter.isCompleted) sessionCompleter.complete();
          rethrow;
        }

        try {
          // Wait for the session to complete
          await sessionCompleter.future;
        } catch (e) {
          log("FFmpegSession: Error waiting for session completion: $e");
        }
      },
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
