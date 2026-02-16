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

import '../ffmpeg_kit_flutter.dart';
import 'callback_manager.dart' as callback_manager;
import 'session_queue_manager.dart';

/// A convenience class for executing FFprobe commands.
class FFprobeKit {
  /// Cancels a [session] if it is currently running.
  static void cancel(FFprobeSession session) => session.cancel();

  /// Retrieves media information for the given [path].
  static MediaInformationSession getMediaInformation(String path) =>
      FFprobeSession.createMediaInformationSession(path).execute();

  /// Retrieves media information for the given [path] asynchronously.
  static Future<FFprobeSession> getMediaInformationAsync(String path,
          {callback_manager.FFprobeSessionCompleteCallback? onComplete}) =>
      FFprobeSession.createMediaInformationSessionAsync(path,
              onComplete: onComplete)
          .executeAsync();

  /// Executes an FFprobe [command] synchronously.
  ///
  /// [strategy] determines how to handle concurrent sessions.
  static FFprobeSession execute(String command,
          {SessionExecutionStrategy strategy =
              SessionExecutionStrategy.queue}) =>
      FFprobeSession.executeCommand(command, strategy: strategy);

  /// Executes an FFprobe [command] asynchronously.
  ///
  /// [strategy] determines how to handle concurrent sessions.
  static Future<FFprobeSession> executeAsync(String command,
          {callback_manager.FFprobeSessionCompleteCallback? onComplete,
          SessionExecutionStrategy strategy =
              SessionExecutionStrategy.queue}) =>
      FFprobeSession.executeCommandAsync(command,
          completeCallback: onComplete, strategy: strategy);

  /// Creates a new [FFprobeSession] without executing it.
  /// Use [execute] or [executeAsync] to execute the session.
  static FFprobeSession createSession(String command,
          {callback_manager.FFprobeSessionCompleteCallback? onComplete}) =>
      FFprobeSession(command, completeCallback: onComplete);

  /// Lists all active FFprobe sessions.
  static List<FFprobeSession> getFFprobeSessions() =>
      FFmpegKitExtended.getFFprobeSessions();
}
