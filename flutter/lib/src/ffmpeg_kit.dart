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

import 'callback_manager.dart' as callback_manager;
import 'ffmpeg_kit_extended.dart';
import 'ffmpeg_session.dart';
import 'session_queue_manager.dart';

/// A convenience class for executing FFmpeg commands.
class FFmpegKit {
  /// Executes an FFmpeg [command] synchronously.
  ///
  /// [strategy] determines how to handle concurrent sessions.
  static FFmpegSession execute(String command,
          {SessionExecutionStrategy strategy =
              SessionExecutionStrategy.queue}) =>
      FFmpegSession.executeCommand(command, strategy: strategy);

  /// Executes an FFmpeg [command] asynchronously.
  ///
  /// - [command]: The FFmpeg command to execute.
  /// - [onComplete]: Optional callback invoked when execution completes.
  /// - [onLog]: Optional callback invoked for each log message.
  /// - [onStatistics]: Optional callback invoked for each statistics update.
  /// - [strategy]: Determines how to handle concurrent sessions.
  static Future<FFmpegSession> executeAsync(String command,
          {callback_manager.FFmpegSessionCompleteCallback? onComplete,
          callback_manager.FFmpegLogCallback? onLog,
          callback_manager.FFmpegStatisticsCallback? onStatistics,
          SessionExecutionStrategy strategy =
              SessionExecutionStrategy.queue}) =>
      FFmpegSession.executeCommandAsync(command,
          completeCallback: onComplete,
          logCallback: onLog,
          statisticsCallback: onStatistics,
          strategy: strategy);

  /// Cancels a [session] if it is currently running.
  static void cancel(FFmpegSession session) => session.cancel();

  /// Creates a new [FFmpegSession] without executing it.
  static FFmpegSession createSession(String command) =>
      FFmpegKitExtended.createFFmpegSession(command);

  /// Returns the last executed FFmpeg session.
  static FFmpegSession? getLastFFmpegSession() =>
      FFmpegKitExtended.getLastFFmpegSession();

  /// Returns all active FFmpeg sessions.
  static List<FFmpegSession> getFFmpegSessions() =>
      FFmpegKitExtended.getFFmpegSessions();
}
