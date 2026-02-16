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

import 'dart:ffi';

import 'callback_manager.dart' as callback_manager;
import 'ffmpeg_kit_extended.dart';
import 'log.dart';
import 'session.dart';
import 'signal.dart';

/// A convenience class for global FFmpegKit configuration.
class FFmpegKitConfig {
  /// Enables global log redirection.
  static void enableRedirection() => FFmpegKitExtended.enableRedirection();

  /// Disables global log redirection.
  static void disableRedirection() => FFmpegKitExtended.disableRedirection();

  /// Sets the global log [level].
  static void setLogLevel(LogLevel level) =>
      FFmpegKitExtended.setLogLevel(level);

  /// Gets the current global log level.
  static LogLevel getLogLevel() => FFmpegKitExtended.getLogLevel();

  /// Sets the directory for font files.
  static void setFontDirectory(String path, {String? mapping}) =>
      FFmpegKitExtended.setFontDirectory(path, mapping: mapping);

  /// Returns the FFmpeg version.
  static String getFFmpegVersion() => FFmpegKitExtended.getFFmpegVersion();

  /// Returns the FFmpegKit version.
  static String getVersion() => FFmpegKitExtended.getVersion();

  /// Returns the FFmpegKit package name.
  static String getPackageName() => FFmpegKitExtended.getPackageName();

  /// Sets the session history [size].
  static void setSessionHistorySize(int size) =>
      FFmpegKitExtended.setSessionHistorySize(size);

  /// Gets the session history size.
  static int getSessionHistorySize() =>
      FFmpegKitExtended.getSessionHistorySize();

  /// Converts log level to string.
  static String? logLevelToString(LogLevel level) =>
      FFmpegKitExtended.logLevelToString(level);

  /// Releases a native handle.
  static void handleRelease(Pointer<Void> handle) =>
      FFmpegKitExtended.handleRelease(handle);

  /// Clears all handled sessions.
  static void clearSessions() => FFmpegKitExtended.clearSessions();

  /// Enables global log callback.
  static void enableLogCallback(
          [callback_manager.FFmpegLogCallback? logCallback]) =>
      FFmpegKitExtended.enableLogCallback(logCallback);

  /// Enables global statistics callback.
  static void enableStatisticsCallback(
          [callback_manager.FFmpegStatisticsCallback? statisticsCallback]) =>
      FFmpegKitExtended.enableStatisticsCallback(statisticsCallback);

  /// Enables global FFmpeg session complete callback.
  static void enableFFmpegSessionCompleteCallback(
          [callback_manager.FFmpegSessionCompleteCallback? completeCallback]) =>
      FFmpegKitExtended.enableFFmpegSessionCompleteCallback(completeCallback);

  /// Enables global FFprobe session complete callback.
  static void enableFFprobeSessionCompleteCallback(
          [callback_manager.FFprobeSessionCompleteCallback?
              completeCallback]) =>
      FFmpegKitExtended.enableFFprobeSessionCompleteCallback(completeCallback);

  /// Enables global FFplay session complete callback.
  static void enableFFplaySessionCompleteCallback(
          [callback_manager.FFplaySessionCompleteCallback? completeCallback]) =>
      FFmpegKitExtended.enableFFplaySessionCompleteCallback(completeCallback);

  /// Enables global MediaInformation session complete callback.
  static void enableMediaInformationSessionCompleteCallback(
          [callback_manager.MediaInformationSessionCompleteCallback?
              completeCallback]) =>
      FFmpegKitExtended.enableMediaInformationSessionCompleteCallback(
          completeCallback);

  /// Registers a new FFmpeg pipe.
  static String? registerNewFFmpegPipe() =>
      FFmpegKitExtended.registerNewFFmpegPipe();

  /// Closes an FFmpeg pipe.
  static void closeFFmpegPipe(String pipePath) =>
      FFmpegKitExtended.closeFFmpegPipe(pipePath);

  /// Sets the list of font directories.
  static void setFontDirectoryList(List<String> fontDirectoryList,
          [Map<String, String>? fontMappings]) =>
      FFmpegKitExtended.setFontDirectoryList(fontDirectoryList, fontMappings);

  /// Returns the build date.
  static String getBuildDate() => FFmpegKitExtended.getBuildDate();

  /// Converts session state to string.
  static String sessionStateToString(SessionState state) =>
      FFmpegKitExtended.sessionStateToString(state);

  /// Parses a command into an argument array.
  static List<String> parseArguments(String command) =>
      FFmpegKitExtended.parseArguments(command);

  /// Converts an argument array to a command string.
  static String argumentsToString(List<String> arguments) =>
      FFmpegKitExtended.argumentsToString(arguments);

  /// Sets an environment variable.
  static void setEnvironmentVariable(String name, String value) =>
      FFmpegKitExtended.setEnvironmentVariable(name, value);

  /// Ignores a specific signal.
  static void ignoreSignal(Signal signal) =>
      FFmpegKitExtended.ignoreSignal(signal);

  /// Returns the number of messages in transmit for a session.
  static int messagesInTransmit(int sessionId) =>
      FFmpegKitExtended.messagesInTransmit(sessionId);
}
