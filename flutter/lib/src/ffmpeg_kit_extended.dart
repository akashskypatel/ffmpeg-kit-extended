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

import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'callback_manager.dart' as callback_manager;
import 'ffmpeg_kit_flutter_loader.dart';
import 'ffmpeg_session.dart';
import 'ffplay_session.dart';
import 'ffprobe_session.dart';
import 'generated/ffmpeg_kit_bindings.dart';
import 'log.dart';
import 'media_information_session.dart';
import 'session.dart';
import 'signal.dart';

/// The main entry point for the FFmpegKit Extended plugin.
///
/// Use this class to create and manage various types of FFmpeg sessions,
/// configure global settings, and retrieve version information.
class FFmpegKitExtended {
  /// Creates a new [FFmpegSession] to execute an FFmpeg [command].
  ///
  /// Optional [completeCallback], [logCallback], and [statisticsCallback]
  /// can be provided to handle session events.
  static FFmpegSession createFFmpegSession(String command,
      {callback_manager.FFmpegSessionCompleteCallback? completeCallback,
      callback_manager.FFmpegLogCallback? logCallback,
      callback_manager.FFmpegStatisticsCallback? statisticsCallback}) {
    if (command.trim().isEmpty) {
      throw ArgumentError('Command cannot be empty');
    }
    return FFmpegSession(command,
        completeCallback: completeCallback,
        logCallback: logCallback,
        statisticsCallback: statisticsCallback);
  }

  /// Creates a new [FFprobeSession] to execute an FFprobe [command].
  ///
  /// Optional [completeCallback] can be provided to handle session completion.
  static FFprobeSession createFFprobeSession(String command,
      {callback_manager.FFprobeSessionCompleteCallback? completeCallback}) {
    if (command.trim().isEmpty) {
      throw ArgumentError('Command cannot be empty');
    }
    return FFprobeSession(command, completeCallback: completeCallback);
  }

  /// Creates a new [FFplaySession] to play media using an FFplay [command].
  ///
  /// - [timeout]: Connection timeout in milliseconds.
  /// - [completeCallback]: Optional callback when playback ends.
  static FFplaySession createFFplaySession(String command,
      {callback_manager.FFplaySessionCompleteCallback? completeCallback,
      int timeout = 500}) {
    if (command.trim().isEmpty) {
      throw ArgumentError('Command cannot be empty');
    }
    return FFplaySession(command,
        timeout: timeout, completeCallback: completeCallback);
  }

  /// Creates a new [MediaInformationSession] to retrieve media info using [command].
  ///
  /// - [timeout]: Connection timeout in milliseconds.
  /// - [completeCallback]: Optional callback when metadata is retrieved.
  static MediaInformationSession createMediaInformationSession(String command,
      {int timeout = 500,
      callback_manager.FFprobeSessionCompleteCallback? completeCallback}) {
    if (command.trim().isEmpty) {
      throw ArgumentError('Command cannot be empty');
    }
    return MediaInformationSession(command,
        timeout: timeout, completeCallback: completeCallback);
  }

  /// Cancels a specific session identified by [sessionId].
  static void cancelSession(int sessionId) {
    final session = getSession(sessionId);
    if (session != null) {
      session.cancel();
    }
  }

  /// Returns a list of all active or cached sessions.
  static List<Session> listSessions() => FFmpegKitExtended.getSessions();

  /// Cancels all currently running sessions.
  static void cancelAllSessions() {
    final sessions = listSessions();
    for (final session in sessions) {
      session.cancel();
    }
  }

  /// Sets the global [LogLevel] for FFmpeg output.
  static void setLogLevel(LogLevel level) {
    ffmpeg.ffmpeg_kit_config_set_log_level(
        FFmpegKitLogLevel.fromValue(level.value));
  }

  /// Retrieves the current global [LogLevel].
  static LogLevel getLogLevel() =>
      LogLevel.fromValue(ffmpeg.ffmpeg_kit_config_get_log_level().value);

  /// Enables global redirection of FFmpeg logs to the system console.
  static void enableRedirection() =>
      ffmpeg.ffmpeg_kit_config_enable_redirection();

  /// Disables global redirection of FFmpeg logs to the system console.
  static void disableRedirection() =>
      ffmpeg.ffmpeg_kit_config_disable_redirection();

  /// Sets the directory for font files and an optional font [mapping].
  static void setFontDirectory(String path, {String? mapping}) {
    final pathPtr = path.toNativeUtf8();
    final mappingPtr = mapping?.toNativeUtf8() ?? nullptr;
    try {
      ffmpeg.ffmpeg_kit_config_set_font_directory(
          pathPtr.cast(), mappingPtr.cast());
    } finally {
      malloc.free(pathPtr);
      if (mappingPtr != nullptr) malloc.free(mappingPtr);
    }
  }

  /// Sets an environment variable.
  static void setEnvironmentVariable(String name, String value) {
    final namePtr = name.toNativeUtf8();
    final valuePtr = value.toNativeUtf8();
    try {
      ffmpeg.ffmpeg_kit_config_set_environment_variable(
          namePtr.cast(), valuePtr.cast());
    } finally {
      malloc.free(namePtr);
      malloc.free(valuePtr);
    }
  }

  /// Ignores a specific signal.
  static void ignoreSignal(Signal signal) {
    ffmpeg.ffmpeg_kit_config_ignore_signal(
        FFmpegKitSignal.fromValue(signal.value));
  }

  /// Returns the FFmpeg version string.
  static String getFFmpegVersion() {
    final ptr = ffmpeg.ffmpeg_kit_config_get_ffmpeg_version();
    if (ptr == nullptr) return "";
    final res = ptr.cast<Utf8>().toDartString();
    ffmpeg.ffmpeg_kit_free(ptr.cast());
    return res;
  }

  /// Returns the architecture of the bundled FFmpeg library.
  static String getFFmpegArchitecture() {
    final ptr = ffmpeg.ffmpeg_kit_config_get_ffmpeg_architecture();
    if (ptr == nullptr) return "";
    final res = ptr.cast<Utf8>().toDartString();
    ffmpeg.ffmpeg_kit_free(ptr.cast());
    return res;
  }

  /// Returns the version of the FFmpegKit library.
  static String getVersion() {
    final ptr = ffmpeg.ffmpeg_kit_config_get_version();
    if (ptr == nullptr) return "";
    final res = ptr.cast<Utf8>().toDartString();
    ffmpeg.ffmpeg_kit_free(ptr.cast());
    return res;
  }

  /// Returns the package name of the FFmpegKit build.
  static String getPackageName() {
    final ptr = ffmpeg.ffmpeg_kit_packages_get_package_name();
    if (ptr == nullptr) return "";
    final res = ptr.cast<Utf8>().toDartString();
    ffmpeg.ffmpeg_kit_free(ptr.cast());
    return res;
  }

  /// Returns the external libraries bundled with FFmpegKit.
  static String getExternalLibraries() {
    final ptr = ffmpeg.ffmpeg_kit_packages_get_external_libraries();
    if (ptr == nullptr) return "";
    final res = ptr.cast<Utf8>().toDartString();
    ffmpeg.ffmpeg_kit_free(ptr.cast());
    return res;
  }

  /// Sets the maximum number of sessions to keep in history.
  static void setSessionHistorySize(int size) =>
      ffmpeg.ffmpeg_kit_set_session_history_size(size);

  /// Retrieves the current session history size.
  static int getSessionHistorySize() =>
      ffmpeg.ffmpeg_kit_get_session_history_size();

  /// Retrieves a list of all sessions currently managed by the native layer.
  static List<Session> getSessions() {
    final ptr = ffmpeg.ffmpeg_kit_get_sessions();
    if (ptr == nullptr) return [];

    final sessions = <Session>[];
    try {
      int i = 0;
      while (true) {
        final handle = ptr[i];
        if (handle == nullptr) break;

        final cmdPtr = ffmpeg.ffmpeg_kit_session_get_command(handle);
        String cmd = "";
        if (cmdPtr != nullptr) {
          cmd = cmdPtr.cast<Utf8>().toDartString();
          ffmpeg.ffmpeg_kit_free(cmdPtr.cast());
        }

        sessions.add(FFmpegSession.fromHandle(handle, cmd));
        i++;
      }
    } finally {
      ffmpeg.ffmpeg_kit_free(ptr.cast());
    }

    return sessions;
  }

  /// Retrieves a list of all active FFmpeg sessions.
  static List<FFmpegSession> getFFmpegSessions() {
    final ptr = ffmpeg.ffmpeg_kit_get_ffmpeg_sessions();
    if (ptr == nullptr) return [];

    final sessions = <FFmpegSession>[];
    try {
      int i = 0;
      while (true) {
        final handle = ptr[i];
        if (handle == nullptr) break;

        final cmdPtr = ffmpeg.ffmpeg_kit_session_get_command(handle);
        String cmd = "";
        if (cmdPtr != nullptr) {
          cmd = cmdPtr.cast<Utf8>().toDartString();
          ffmpeg.ffmpeg_kit_free(cmdPtr.cast());
        }

        sessions.add(FFmpegSession.fromHandle(handle, cmd));
        i++;
      }
    } finally {
      ffmpeg.ffmpeg_kit_free(ptr.cast());
    }
    return sessions;
  }

  /// Retrieves a list of all active FFprobe sessions.
  static List<FFprobeSession> getFFprobeSessions() {
    final ptr = ffmpeg.ffmpeg_kit_get_ffprobe_sessions();
    if (ptr == nullptr) return [];

    final sessions = <FFprobeSession>[];
    try {
      int i = 0;
      while (true) {
        final handle = ptr[i];
        if (handle == nullptr) break;

        final cmdPtr = ffmpeg.ffmpeg_kit_session_get_command(handle);
        String cmd = "";
        if (cmdPtr != nullptr) {
          cmd = cmdPtr.cast<Utf8>().toDartString();
          ffmpeg.ffmpeg_kit_free(cmdPtr.cast());
        }

        sessions.add(FFprobeSession.fromHandle(handle, cmd));
        i++;
      }
    } finally {
      ffmpeg.ffmpeg_kit_free(ptr.cast());
    }
    return sessions;
  }

  /// Retrieves a list of all active FFplay sessions.
  static List<FFplaySession> getFFplaySessions() {
    final ptr = ffmpeg.ffmpeg_kit_get_ffplay_sessions();
    if (ptr == nullptr) return [];

    final sessions = <FFplaySession>[];
    try {
      int i = 0;
      while (true) {
        final handle = ptr[i];
        if (handle == nullptr) break;

        final cmdPtr = ffmpeg.ffmpeg_kit_session_get_command(handle);
        String cmd = "";
        if (cmdPtr != nullptr) {
          cmd = cmdPtr.cast<Utf8>().toDartString();
          ffmpeg.ffmpeg_kit_free(cmdPtr.cast());
        }

        sessions.add(FFplaySession.fromHandle(handle, cmd));
        i++;
      }
    } finally {
      ffmpeg.ffmpeg_kit_free(ptr.cast());
    }
    return sessions;
  }

  /// Retrieves a list of all active MediaInformation sessions.
  static List<MediaInformationSession> getMediaInformationSessions() {
    final ptr = ffmpeg.ffmpeg_kit_get_media_information_sessions();
    if (ptr == nullptr) return [];

    final sessions = <MediaInformationSession>[];
    try {
      int i = 0;
      while (true) {
        final handle = ptr[i];
        if (handle == nullptr) break;

        final cmd = _getSessionCommand(handle);
        sessions.add(MediaInformationSession.fromHandle(handle, cmd));
        i++;
      }
    } finally {
      ffmpeg.ffmpeg_kit_free(ptr.cast());
    }
    return sessions;
  }

  /// Converts log level to string.
  static String? logLevelToString(LogLevel level) {
    final ptr = ffmpeg.ffmpeg_kit_config_log_level_to_string(
        FFmpegKitLogLevel.fromValue(level.value));
    if (ptr == nullptr) return null;
    final res = ptr.cast<Utf8>().toDartString();
    ffmpeg.ffmpeg_kit_free(ptr.cast());
    return res;
  }

  /// Releases a native handle.
  static void handleRelease(Pointer<Void> handle) =>
      ffmpeg.ffmpeg_kit_handle_release(handle);

  /// Retrieves a session by its ID.
  static Session? getSession(int sessionId) =>
      _wrapSession(ffmpeg.ffmpeg_kit_get_session(sessionId));

  /// Returns the last executed session.
  static Session? getLastSession() =>
      _wrapSession(ffmpeg.ffmpeg_kit_get_last_session());

  /// Returns the last executed FFmpeg session.
  static FFmpegSession? getLastFFmpegSession() {
    final handle = ffmpeg.ffmpeg_kit_get_last_ffmpeg_session();
    return handle == nullptr
        ? null
        : FFmpegSession.fromHandle(handle, _getSessionCommand(handle));
  }

  /// Returns the last executed FFprobe session.
  static FFprobeSession? getLastFFprobeSession() {
    final handle = ffmpeg.ffmpeg_kit_get_last_ffprobe_session();
    return handle == nullptr
        ? null
        : FFprobeSession.fromHandle(handle, _getSessionCommand(handle));
  }

  /// Returns the last executed FFplay session.
  static FFplaySession? getLastFFplaySession() {
    final handle = ffmpeg.ffmpeg_kit_get_last_ffplay_session();
    return handle == nullptr
        ? null
        : FFplaySession.fromHandle(handle, _getSessionCommand(handle));
  }

  /// Returns the last executed MediaInformation session.
  static MediaInformationSession? getLastMediaInformationSession() {
    final handle = ffmpeg.ffmpeg_kit_get_last_media_information_session();
    return handle == nullptr
        ? null
        : MediaInformationSession.fromHandle(
            handle, _getSessionCommand(handle));
  }

  /// Returns the last completed session.
  static Session? getLastCompletedSession() =>
      _wrapSession(ffmpeg.ffmpeg_kit_get_last_completed_session());

  /// Clears all managed sessions from the native layer.
  static void clearSessions() => ffmpeg.ffmpeg_kit_clear_sessions();

  /// Enables global log callback.
  static void enableLogCallback(
      [callback_manager.FFmpegLogCallback? logCallback]) {
    callback_manager.CallbackManager().globalLogCallback = logCallback;
    ffmpeg.ffmpeg_kit_config_enable_log_callback(
        callback_manager.nativeFFmpegLog.nativeFunction, nullptr);
  }

  /// Enables global statistics callback.
  static void enableStatisticsCallback(
      [callback_manager.FFmpegStatisticsCallback? statisticsCallback]) {
    callback_manager.CallbackManager().globalStatisticsCallback =
        statisticsCallback;
    ffmpeg.ffmpeg_kit_config_enable_statistics_callback(
        callback_manager.nativeFFmpegStatistics.nativeFunction, nullptr);
  }

  /// Enables global FFmpeg session complete callback.
  static void enableFFmpegSessionCompleteCallback(
      [callback_manager.FFmpegSessionCompleteCallback? completeCallback]) {
    callback_manager.CallbackManager().globalFFmpegSessionCompleteCallback =
        completeCallback;
    ffmpeg.ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
        callback_manager.nativeFFmpegComplete.nativeFunction, nullptr);
  }

  /// Enables global FFprobe session complete callback.
  static void enableFFprobeSessionCompleteCallback(
      [callback_manager.FFprobeSessionCompleteCallback? completeCallback]) {
    callback_manager.CallbackManager().globalFFprobeSessionCompleteCallback =
        completeCallback;
    ffmpeg.ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
        callback_manager.nativeFFprobeComplete.nativeFunction, nullptr);
  }

  /// Enables global FFplay session complete callback.
  static void enableFFplaySessionCompleteCallback(
      [callback_manager.FFplaySessionCompleteCallback? completeCallback]) {
    callback_manager.CallbackManager().globalFFplaySessionCompleteCallback =
        completeCallback;
    ffmpeg.ffmpeg_kit_config_enable_ffplay_session_complete_callback(
        callback_manager.nativeFFplayComplete.nativeFunction, nullptr);
  }

  /// Enables global MediaInformation session complete callback.
  static void enableMediaInformationSessionCompleteCallback(
      [callback_manager.MediaInformationSessionCompleteCallback?
          completeCallback]) {
    callback_manager.CallbackManager()
        .globalMediaInformationSessionCompleteCallback = completeCallback;
    ffmpeg.ffmpeg_kit_config_enable_media_information_session_complete_callback(
        callback_manager.nativeMediaInfoComplete.nativeFunction, nullptr);
  }

  /// Registers a new FFmpeg pipe.
  static String? registerNewFFmpegPipe() {
    final ptr = ffmpeg.ffmpeg_kit_config_register_new_ffmpeg_pipe();
    if (ptr == nullptr) return null;
    final res = ptr.cast<Utf8>().toDartString();
    ffmpeg.ffmpeg_kit_free(ptr.cast());
    return res;
  }

  /// Closes an FFmpeg pipe.
  static void closeFFmpegPipe(String pipePath) {
    final ptr = pipePath.toNativeUtf8();
    try {
      ffmpeg.ffmpeg_kit_config_close_ffmpeg_pipe(ptr.cast());
    } finally {
      malloc.free(ptr);
    }
  }

  /// Sets the list of font directories.
  static void setFontDirectoryList(List<String> fontDirectoryList,
      [Map<String, String>? fontMappings]) {
    final count = fontDirectoryList.length;
    final listPtr = malloc<Pointer<Char>>(count);
    final strings = <Pointer<Utf8>>[];
    try {
      for (int i = 0; i < count; i++) {
        final s = fontDirectoryList[i].toNativeUtf8();
        strings.add(s);
        listPtr[i] = s.cast();
      }

      Pointer<Char> mappingsPtr = nullptr;
      if (fontMappings != null) {
        mappingsPtr = jsonEncode(fontMappings).toNativeUtf8().cast();
      }

      try {
        ffmpeg.ffmpeg_kit_config_set_font_directory_list(
            listPtr.cast(), count, mappingsPtr);
      } finally {
        if (mappingsPtr != nullptr) malloc.free(mappingsPtr);
      }
    } finally {
      for (final s in strings) malloc.free(s);
      malloc.free(listPtr);
    }
  }

  /// Returns the build date of the library.
  static String getBuildDate() {
    final ptr = ffmpeg.ffmpeg_kit_config_get_build_date();
    if (ptr == nullptr) return "";
    final res = ptr.cast<Utf8>().toDartString();
    ffmpeg.ffmpeg_kit_free(ptr.cast());
    return res;
  }

  /// Converts session state to string.
  static String sessionStateToString(SessionState state) {
    final ptr = ffmpeg.ffmpeg_kit_config_session_state_to_string(
        FFmpegKitSessionState.fromValue(state.value));
    if (ptr == nullptr) return "";
    final res = ptr.cast<Utf8>().toDartString();
    ffmpeg.ffmpeg_kit_free(ptr.cast());
    return res;
  }

  /// Parses a command into an argument array.
  static List<String> parseArguments(String command) {
    final cmdPtr = command.toNativeUtf8();
    final countPtr = malloc<Long>();
    try {
      final argsPtr = ffmpeg.ffmpeg_kit_config_parse_arguments(
          cmdPtr.cast(), countPtr.cast());
      if (argsPtr == nullptr) return [];

      final count = countPtr.value;
      final result = <String>[];
      for (int i = 0; i < count; i++) {
        final arg = argsPtr[i];
        if (arg != nullptr) {
          result.add(arg.cast<Utf8>().toDartString());
          ffmpeg.ffmpeg_kit_free(arg.cast());
        }
      }
      ffmpeg.ffmpeg_kit_free(argsPtr.cast());
      return result;
    } finally {
      malloc.free(cmdPtr);
      malloc.free(countPtr);
    }
  }

  /// Converts an argument array to a command string.
  static String argumentsToString(List<String> arguments) {
    final count = arguments.length;
    final argsPtr = malloc<Pointer<Char>>(count);
    final strings = <Pointer<Utf8>>[];
    try {
      for (int i = 0; i < count; i++) {
        final s = arguments[i].toNativeUtf8();
        strings.add(s);
        argsPtr[i] = s.cast();
      }
      final resPtr =
          ffmpeg.ffmpeg_kit_config_arguments_to_string(argsPtr.cast(), count);
      if (resPtr == nullptr) return "";
      final res = resPtr.cast<Utf8>().toDartString();
      ffmpeg.ffmpeg_kit_free(resPtr.cast());
      return res;
    } finally {
      for (final s in strings) malloc.free(s);
      malloc.free(argsPtr);
    }
  }

  /// Returns the number of messages in transmit for a session.
  static int messagesInTransmit(int sessionId) =>
      ffmpeg.ffmpeg_kit_config_messages_in_transmit(sessionId);

  // --- Private Helpers ---

  /// Retrieves the command associated with a session.
  static String _getSessionCommand(Pointer<Void> handle) {
    if (handle == nullptr) return "";
    final cmdPtr = ffmpeg.ffmpeg_kit_session_get_command(handle);
    String cmd = "";
    if (cmdPtr != nullptr) {
      cmd = cmdPtr.cast<Utf8>().toDartString();
      ffmpeg.ffmpeg_kit_free(cmdPtr.cast());
    }
    return cmd;
  }

  /// Wraps a session handle into a [Session] object.
  static Session? _wrapSession(Pointer<Void> handle) {
    if (handle == nullptr) return null;
    final sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);

    // Check CallbackManager first for existing objects
    final manager = callback_manager.CallbackManager();
    final existing = manager.ffmpegSessions[sessionId] ??
        manager.ffprobeSessions[sessionId] ??
        manager.ffplaySessions[sessionId] ??
        manager.mediaInformationSessions[sessionId];
    if (existing != null) return existing;

    // Fallback to generic Session based on command guessing or default
    final cmd = _getSessionCommand(handle);
    return FFmpegSession.fromHandle(handle, cmd);
  }
}
