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

import 'dart:convert';
import 'dart:developer';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'callback_manager.dart' as callback_manager;
import 'ffmpeg_kit_extended_flutter_loader.dart';
import 'ffmpeg_session.dart';
import 'ffplay_session.dart';
import 'ffprobe_session.dart';
import 'generated/ffmpeg_kit_bindings.dart' as ffmpeg;
import 'log.dart';
import 'media_information_session.dart';
import 'session.dart';
import 'session_queue_manager.dart';
import 'signal.dart';

/// The main entry point for the FFmpegKit Extended plugin.
///
/// All methods are static.  Use this class to create and manage FFmpeg
/// sessions, configure global settings, and retrieve version information.
class FFmpegKitExtended {
  /// Throws [StateError] if [FFmpegKitExtended.initialize] has not been called.
  ///
  /// Call this at the top of every method that reaches the native layer.
  static void requireInitialized() {
    if (!isFFmpegKitInitialized) {
      throw StateError(
        'FFmpegKitExtended has not been initialized. '
        'Call await FFmpegKitExtended.initialize() from main() '
        'before using the plugin.',
      );
    }
  }

  /// Initializes the plugin by loading the native FFmpegKit library.
  ///
  /// Must be awaited once at application startup, **before** any other method
  /// on this class is called:
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await FFmpegKitExtended.initialize();
  ///   runApp(const MyApp());
  /// }
  /// ```
  ///
  /// Calling this more than once is safe (subsequent calls are no-ops).
  static Future<void> initialize() => initializeFFmpegKit();

  /// Returns `true` if [initialize] has been called successfully.
  static bool get initialized => isFFmpegKitInitialized;

  // ---------------------------------------------------------------------------
  // Session factories
  // ---------------------------------------------------------------------------

  /// Creates a new [FFmpegSession] for [command].
  ///
  /// Throws [ArgumentError] if [command] is blank.
  static FFmpegSession createFFmpegSession(
    String command, {
    callback_manager.FFmpegSessionCompleteCallback? completeCallback,
    callback_manager.FFmpegLogCallback? logCallback,
    callback_manager.FFmpegStatisticsCallback? statisticsCallback,
  }) {
    requireInitialized();
    _requireNonBlank(command, 'command');
    return FFmpegSession(
      command,
      completeCallback: completeCallback,
      logCallback: logCallback,
      statisticsCallback: statisticsCallback,
    );
  }

  /// Creates a new [FFprobeSession] for [command].
  ///
  /// Throws [ArgumentError] if [command] is blank.
  static FFprobeSession createFFprobeSession(
    String command, {
    callback_manager.FFprobeSessionCompleteCallback? completeCallback,
  }) {
    requireInitialized();
    _requireNonBlank(command, 'command');
    return FFprobeSession(command, completeCallback: completeCallback);
  }

  /// Creates a new [FFplaySession] for [command].
  ///
  /// Throws [ArgumentError] if [command] is blank.
  static FFplaySession createFFplaySession(
    String command, {
    callback_manager.FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) {
    requireInitialized();
    _requireNonBlank(command, 'command');
    return FFplaySession(
      command,
      timeout: timeout,
      completeCallback: completeCallback,
    );
  }

  /// Creates a new [MediaInformationSession] for [command].
  ///
  /// [MediaInformationSession] completion event.  It is now correctly typed
  /// as [callback_manager.MediaInformationSessionCompleteCallback].
  ///
  /// Throws [ArgumentError] if [command] is blank.
  static MediaInformationSession createMediaInformationSession(
    String command, {
    int timeout = 500,
    callback_manager.MediaInformationSessionCompleteCallback? completeCallback,
  }) {
    requireInitialized();
    _requireNonBlank(command, 'command');
    return MediaInformationSession(
      command,
      timeout: timeout,
      completeCallback: completeCallback,
    );
  }

  // ---------------------------------------------------------------------------
  // Session management
  // ---------------------------------------------------------------------------

  /// Cancels the session identified by [sessionId].
  static void cancelSession(int sessionId) {
    requireInitialized();
    getSession(sessionId)?.cancel();
  }

  /// Returns all sessions currently tracked by the native layer.
  ///
  /// Equivalent to [getSessions].
  static List<Session> listSessions() {
    requireInitialized();
    return getSessions();
  }

  /// Cancels all active and queued sessions managed by [SessionQueueManager].
  static void cancelAllSessions() {
    requireInitialized();
    SessionQueueManager().cancelAll();
  }

  // ---------------------------------------------------------------------------
  // Log level & redirection
  // ---------------------------------------------------------------------------

  /// Sets the global log level for FFmpeg output.
  static void setLogLevel(LogLevel level) {
    requireInitialized();
    try {
      ffmpeg.ffmpeg_kit_config_set_log_level(
        ffmpeg.FFmpegKitLogLevel.fromValue(level.value),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_set_log_level",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the current global log level.
  static LogLevel getLogLevel() {
    requireInitialized();
    try {
      return LogLevel.fromValue(ffmpeg.ffmpeg_kit_config_get_log_level().value);
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_get_log_level",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Enables redirection of FFmpeg logs to the system console.
  static void enableRedirection() {
    requireInitialized();
    try {
      ffmpeg.ffmpeg_kit_config_enable_redirection();
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_enable_redirection",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Disables redirection of FFmpeg logs to the system console.
  static void disableRedirection() {
    requireInitialized();
    try {
      ffmpeg.ffmpeg_kit_config_disable_redirection();
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_disable_redirection",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Font & audio configuration
  // ---------------------------------------------------------------------------

  /// Sets the font directory and optional name [mapping] JSON.
  static void setFontDirectory(String path, {String? mapping}) {
    requireInitialized();
    final pathPtr = path.toNativeUtf8();
    final mappingPtr = mapping?.toNativeUtf8() ?? nullptr;
    try {
      ffmpeg.ffmpeg_kit_config_set_font_directory(
        pathPtr.cast(),
        mappingPtr.cast(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_set_font_directory",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    } finally {
      malloc.free(pathPtr);
      if (mappingPtr != nullptr) malloc.free(mappingPtr);
    }
  }

  /// Sets [deviceName] as the audio output device.
  static void setAudioOutputDevice(String deviceName) {
    requireInitialized();
    final ptr = deviceName.toNativeUtf8();
    try {
      ffmpeg.ffmpeg_kit_config_set_audio_output_device(ptr.cast());
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_set_audio_output_device",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    } finally {
      malloc.free(ptr);
    }
  }

  /// Returns a semicolon-separated list of available audio output devices.
  static String listAudioOutputDevices() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_config_list_audio_output_devices(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_list_audio_output_devices",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Environment & signals
  // ---------------------------------------------------------------------------

  /// Sets the environment variable [name] to [value].
  static void setEnvironmentVariable(String name, String value) {
    requireInitialized();
    final namePtr = name.toNativeUtf8();
    final valuePtr = value.toNativeUtf8();
    try {
      ffmpeg.ffmpeg_kit_config_set_environment_variable(
        namePtr.cast(),
        valuePtr.cast(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_set_environment_variable",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    } finally {
      malloc.free(namePtr);
      malloc.free(valuePtr);
    }
  }

  /// Configures FFmpegKit to ignore [signal].
  static void ignoreSignal(Signal signal) {
    requireInitialized();
    try {
      ffmpeg.ffmpeg_kit_config_ignore_signal(
        ffmpeg.FFmpegKitSignal.fromValue(signal.value),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_ignore_signal",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Version & package information
  // ---------------------------------------------------------------------------

  /// Returns the bundled FFmpeg version string.
  static String getFFmpegVersion() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_config_get_ffmpeg_version(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_get_ffmpeg_version",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the CPU architecture of the bundled FFmpeg binary.
  static String getFFmpegArchitecture() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_config_get_ffmpeg_architecture(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_get_ffmpeg_architecture",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the FFmpegKit library version string.
  static String getVersion() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(ffmpeg.ffmpeg_kit_config_get_version());
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_get_version",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the package name of this FFmpegKit build.
  static String getPackageName() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_packages_get_package_name(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_packages_get_package_name",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the external libraries bundled with this FFmpegKit build.
  static String getExternalLibraries() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_packages_get_external_libraries(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_packages_get_external_libraries",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the FFmpegKit bundle type.
  static String getBundleType() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(ffmpeg.ffmpeg_kit_packages_get_bundle_type());
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_packages_get_bundle_type",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns whether this FFmpegKit build has GPL enabled.
  static bool isGpl() {
    requireInitialized();
    try {
      return ffmpeg.ffmpeg_kit_packages_get_is_gpl();
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_packages_get_is_gpl",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns whether this FFmpegKit build has non-free libraries enabled.
  static bool isNonfree() {
    requireInitialized();
    try {
      return ffmpeg.ffmpeg_kit_packages_get_is_nonfree();
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_packages_get_is_nonfree",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns a comma-separated list of all registered codecs.
  static String getRegisteredCodecs() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_packages_get_registered_codecs(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_packages_get_registered_codecs",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns a comma-separated list of all registered encoders.
  static String getRegisteredEncoders() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_packages_get_registered_encoders(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_packages_get_registered_encoders",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns a comma-separated list of all registered decoders.
  static String getRegisteredDecoders() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_packages_get_registered_decoders(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_packages_get_registered_decoders",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns a comma-separated list of all registered muxers.
  static String getRegisteredMuxers() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_packages_get_registered_muxers(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_packages_get_registered_muxers",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns a comma-separated list of all registered demuxers.
  static String getRegisteredDemuxers() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_packages_get_registered_demuxers(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_packages_get_registered_demuxers",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns a comma-separated list of all registered filters.
  static String getRegisteredFilters() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_packages_get_registered_filters(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_packages_get_registered_filters",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns a comma-separated list of all registered protocols.
  static String getRegisteredProtocols() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_packages_get_registered_protocols(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_packages_get_registered_protocols",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns a comma-separated list of all registered bitstream filters.
  static String getRegisteredBitstreamFilters() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_packages_get_registered_bitstream_filters(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_packages_get_registered_bitstream_filters",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the FFmpeg build configuration string.
  static String getBuildConfiguration() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_packages_get_build_configuration(),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_packages_get_build_configuration",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the library build date.
  static String getBuildDate() {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(ffmpeg.ffmpeg_kit_config_get_build_date());
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_get_build_date",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Session history
  // ---------------------------------------------------------------------------

  /// Sets the maximum number of sessions to retain in native-layer history.
  static void setSessionHistorySize(int size) {
    requireInitialized();
    try {
      ffmpeg.ffmpeg_kit_set_session_history_size(size);
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_set_session_history_size",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the current native-layer session history size.
  static int getSessionHistorySize() {
    requireInitialized();
    try {
      return ffmpeg.ffmpeg_kit_get_session_history_size();
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_get_session_history_size",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns all sessions in native-layer history, correctly typed.
  static List<Session> getSessions() {
    requireInitialized();
    try {
      return _collectSessions(ffmpeg.ffmpeg_kit_get_sessions(), _wrapSession);
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_get_sessions",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns all FFmpeg sessions in native-layer history.
  static List<FFmpegSession> getFFmpegSessions() {
    requireInitialized();
    try {
      return _collectTypedSessions<FFmpegSession>(
        ffmpeg.ffmpeg_kit_get_ffmpeg_sessions(),
        FFmpegSession.fromHandle,
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_get_ffmpeg_sessions",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns all FFprobe sessions in native-layer history.
  static List<FFprobeSession> getFFprobeSessions() {
    requireInitialized();
    try {
      return _collectTypedSessions<FFprobeSession>(
        ffmpeg.ffmpeg_kit_get_ffprobe_sessions(),
        FFprobeSession.fromHandle,
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_get_ffprobe_sessions",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns all FFplay sessions in native-layer history.
  static List<FFplaySession> getFFplaySessions() {
    requireInitialized();
    try {
      return _collectTypedSessions<FFplaySession>(
        ffmpeg.ffmpeg_kit_get_ffplay_sessions(),
        FFplaySession.fromHandle,
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_get_ffplay_sessions",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns all MediaInformation sessions in native-layer history.
  static List<MediaInformationSession> getMediaInformationSessions() {
    requireInitialized();
    try {
      return _collectTypedSessions<MediaInformationSession>(
        ffmpeg.ffmpeg_kit_get_media_information_sessions(),
        MediaInformationSession.fromHandle,
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_get_media_information_sessions",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Single-session lookups
  // ---------------------------------------------------------------------------

  /// Returns the session with [sessionId], or `null` if not found.
  static Session? getSession(int sessionId) {
    requireInitialized();
    try {
      return _wrapSession(ffmpeg.ffmpeg_kit_get_session(sessionId));
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_get_session",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the most recently created session, or `null`.
  static Session? getLastSession() {
    requireInitialized();
    try {
      return _wrapSession(ffmpeg.ffmpeg_kit_get_last_session());
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_get_last_session",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the most recently created [FFmpegSession], or `null`.
  static FFmpegSession? getLastFFmpegSession() {
    requireInitialized();
    try {
      final h = ffmpeg.ffmpeg_kit_get_last_ffmpeg_session();
      if (h == nullptr) return null;
      final session = FFmpegSession.fromHandle(h, _getSessionCommand(h));
      // Release is handled by the NativeFinalizer attached inside fromHandle.
      return session;
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_get_last_ffmpeg_session",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the most recently created [FFprobeSession], or `null`.
  static FFprobeSession? getLastFFprobeSession() {
    requireInitialized();
    try {
      final h = ffmpeg.ffmpeg_kit_get_last_ffprobe_session();
      if (h == nullptr) return null;
      return FFprobeSession.fromHandle(h, _getSessionCommand(h));
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_get_last_ffprobe_session",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the most recently created [FFplaySession], or `null`.
  static FFplaySession? getLastFFplaySession() {
    requireInitialized();
    try {
      final h = ffmpeg.ffmpeg_kit_get_last_ffplay_session();
      if (h == nullptr) return null;
      return FFplaySession.fromHandle(h, _getSessionCommand(h));
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_get_last_ffplay_session",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the most recently created [MediaInformationSession], or `null`.
  static MediaInformationSession? getLastMediaInformationSession() {
    requireInitialized();
    try {
      final h = ffmpeg.ffmpeg_kit_get_last_media_information_session();
      if (h == nullptr) return null;
      return MediaInformationSession.fromHandle(h, _getSessionCommand(h));
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_get_last_media_information_session",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the most recently completed session, or `null`.
  static Session? getLastCompletedSession() {
    requireInitialized();
    try {
      return _wrapSession(ffmpeg.ffmpeg_kit_get_last_completed_session());
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_get_last_completed_session",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Gets the session ID for a given session handle.
  static int getSessionId(Pointer<Void> handle) {
    requireInitialized();
    try {
      return ffmpeg.ffmpeg_kit_session_get_session_id(handle);
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_session_get_session_id",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Clears all sessions from the native layer's history store.
  ///
  /// ### Note on Dart-side maps
  /// This clears the C-side session history.  Active sessions tracked in
  /// [callback_manager.CallbackManager]'s runtime maps self-unregister when
  /// their completion callbacks fire.
  static void clearSessions() {
    requireInitialized();
    try {
      ffmpeg.ffmpeg_kit_clear_sessions();
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_clear_sessions",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Global callbacks
  // ---------------------------------------------------------------------------

  /// Sets [logCallback] as the global log callback and registers it with the
  /// native layer.  Pass `null` to deregister.
  static void enableLogCallback([
    callback_manager.FFmpegLogCallback? logCallback,
  ]) {
    requireInitialized();
    try {
      callback_manager.CallbackManager().globalLogCallback = logCallback;
      ffmpeg.ffmpeg_kit_config_enable_log_callback(
        callback_manager.nativeFFmpegLog.nativeFunction,
        nullptr,
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_enable_log_callback",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Sets [statisticsCallback] as the global statistics callback.
  /// Pass `null` to deregister.
  static void enableStatisticsCallback([
    callback_manager.FFmpegStatisticsCallback? statisticsCallback,
  ]) {
    requireInitialized();
    try {
      callback_manager.CallbackManager().globalStatisticsCallback =
          statisticsCallback;
      ffmpeg.ffmpeg_kit_config_enable_statistics_callback(
        callback_manager.nativeFFmpegStatistics.nativeFunction,
        nullptr,
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_enable_statistics_callback",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Sets [completeCallback] as the global FFmpeg session complete callback.
  static void enableFFmpegSessionCompleteCallback([
    callback_manager.FFmpegSessionCompleteCallback? completeCallback,
  ]) {
    requireInitialized();
    try {
      callback_manager.CallbackManager().globalFFmpegSessionCompleteCallback =
          completeCallback;
      ffmpeg.ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
        callback_manager.nativeFFmpegComplete.nativeFunction,
        nullptr,
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_enable_ffmpeg_session_complete_callback",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Sets [completeCallback] as the global FFprobe session complete callback.
  static void enableFFprobeSessionCompleteCallback([
    callback_manager.FFprobeSessionCompleteCallback? completeCallback,
  ]) {
    requireInitialized();
    try {
      callback_manager.CallbackManager().globalFFprobeSessionCompleteCallback =
          completeCallback;
      ffmpeg.ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
        callback_manager.nativeFFprobeComplete.nativeFunction,
        nullptr,
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_enable_ffprobe_session_complete_callback",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
    ;
  }

  /// Sets [completeCallback] as the global FFplay session complete callback.
  static void enableFFplaySessionCompleteCallback([
    callback_manager.FFplaySessionCompleteCallback? completeCallback,
  ]) {
    requireInitialized();
    try {
      callback_manager.CallbackManager().globalFFplaySessionCompleteCallback =
          completeCallback;
      ffmpeg.ffmpeg_kit_config_enable_ffplay_session_complete_callback(
        callback_manager.nativeFFplayComplete.nativeFunction,
        nullptr,
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_enable_ffplay_session_complete_callback",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Sets [completeCallback] as the global MediaInformation session complete
  /// callback.
  static void enableMediaInformationSessionCompleteCallback([
    callback_manager.MediaInformationSessionCompleteCallback? completeCallback,
  ]) {
    requireInitialized();
    try {
      callback_manager.CallbackManager()
              .globalMediaInformationSessionCompleteCallback =
          completeCallback;
      ffmpeg
          .ffmpeg_kit_config_enable_media_information_session_complete_callback(
            callback_manager.nativeMediaInfoComplete.nativeFunction,
            nullptr,
          );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_enable_media_information_session_complete_callback",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Pipes
  // ---------------------------------------------------------------------------

  /// Registers a new named FFmpeg pipe and returns its path, or `null` on
  /// failure.
  static String? registerNewFFmpegPipe() {
    requireInitialized();
    try {
      final ptr = ffmpeg.ffmpeg_kit_config_register_new_ffmpeg_pipe();
      if (ptr == nullptr) return null;
      final result = ptr.cast<Utf8>().toDartString();
      ffmpeg.ffmpeg_kit_free(ptr.cast());
      return result;
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_register_new_ffmpeg_pipe",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Closes the FFmpeg pipe at [pipePath].
  static void closeFFmpegPipe(String pipePath) {
    requireInitialized();
    try {
      final ptr = pipePath.toNativeUtf8();
      try {
        ffmpeg.ffmpeg_kit_config_close_ffmpeg_pipe(ptr.cast());
      } finally {
        malloc.free(ptr);
      }
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_close_ffmpeg_pipe",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Font directory list
  // ---------------------------------------------------------------------------

  /// Sets the list of font directories and optional [fontMappings].
  static void setFontDirectoryList(
    List<String> fontDirectoryList, [
    Map<String, String>? fontMappings,
  ]) {
    requireInitialized();
    final count = fontDirectoryList.length;

    // Allocate everything upfront so the single outer finally block can free
    // all native memory unconditionally.
    final listPtr = malloc<Pointer<Char>>(count);
    final strings = <Pointer<Utf8>>[];
    Pointer<Char> mappingsPtr = nullptr;

    try {
      // Build the null-terminated (not required by C but defensive) string
      // pointer array.
      for (int i = 0; i < count; i++) {
        final s = fontDirectoryList[i].toNativeUtf8();
        strings.add(s);
        listPtr[i] = s.cast();
      }

      if (fontMappings != null) {
        mappingsPtr = jsonEncode(fontMappings).toNativeUtf8().cast();
      }

      ffmpeg.ffmpeg_kit_config_set_font_directory_list(
        listPtr.cast(),
        count,
        mappingsPtr,
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_set_font_directory_list",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    } finally {
      // Free in reverse allocation order.
      if (mappingsPtr != nullptr) malloc.free(mappingsPtr);
      for (final s in strings) {
        malloc.free(s);
      }
      malloc.free(listPtr);
    }
  }

  // ---------------------------------------------------------------------------
  // Miscellaneous config helpers
  // ---------------------------------------------------------------------------

  /// Converts [state] to its human-readable string name.
  static String sessionStateToString(SessionState state) {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_config_session_state_to_string(
          ffmpeg.FFmpegKitSessionState.fromValue(state.value),
        ),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_session_state_to_string",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Converts [level] to its human-readable string name, or `null` if
  /// unrecognised.
  static String? logLevelToString(LogLevel level) {
    requireInitialized();
    try {
      final ptr = ffmpeg.ffmpeg_kit_config_log_level_to_string(
        ffmpeg.FFmpegKitLogLevel.fromValue(level.value),
      );
      if (ptr == nullptr) return null;
      final result = ptr.cast<Utf8>().toDartString();
      ffmpeg.ffmpeg_kit_free(ptr.cast());
      return result;
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_log_level_to_string",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Parses [command] into an argument list.
  static List<String> parseArguments(String command) {
    requireInitialized();
    final cmdPtr = command.toNativeUtf8();
    final countPtr = malloc<Int64>();
    try {
      final argsPtr = ffmpeg.ffmpeg_kit_config_parse_arguments(
        cmdPtr.cast(),
        countPtr.cast(),
      );
      if (argsPtr == nullptr) return const [];

      final count = countPtr.value;
      final result = <String>[];
      for (int i = 0; i < count; i++) {
        final arg = argsPtr[i];
        if (arg != nullptr) {
          result.add(arg.cast<Utf8>().toDartString());
          ffmpeg.ffmpeg_kit_free(arg.cast());
        }
      }
      // Free the outer char** array (individual strings already freed above).
      ffmpeg.ffmpeg_kit_free(argsPtr.cast());
      return result;
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_parse_arguments",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    } finally {
      malloc.free(cmdPtr);
      malloc.free(countPtr);
    }
  }

  /// Joins [arguments] back into a single command string.
  static String argumentsToString(List<String> arguments) {
    requireInitialized();
    final count = arguments.length;
    final argsPtr = malloc<Pointer<Char>>(count);
    final strings = <Pointer<Utf8>>[];
    try {
      for (int i = 0; i < count; i++) {
        final s = arguments[i].toNativeUtf8();
        strings.add(s);
        argsPtr[i] = s.cast();
      }
      final resPtr = ffmpeg.ffmpeg_kit_config_arguments_to_string(
        argsPtr.cast(),
        count,
      );
      if (resPtr == nullptr) return '';
      final result = resPtr.cast<Utf8>().toDartString();
      ffmpeg.ffmpeg_kit_free(resPtr.cast());
      return result;
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_arguments_to_string",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    } finally {
      for (final s in strings) {
        malloc.free(s);
      }
      malloc.free(argsPtr);
    }
  }

  /// Returns the number of log/stats messages buffered for [sessionId].
  static int messagesInTransmit(int sessionId) {
    requireInitialized();
    try {
      return ffmpeg.ffmpeg_kit_config_messages_in_transmit(sessionId);
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_messages_in_transmit",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Per-session debug log (static API mirroring Session instance methods)
  // ---------------------------------------------------------------------------

  /// Enables per-session debug logging for [session].
  static void enableDebugLog(Session session) {
    requireInitialized();
    try {
      ffmpeg.ffmpeg_kit_config_enable_debug_log(session.handle);
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_enable_debug_log",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Disables per-session debug logging for [session].
  static void disableDebugLog(Session session) {
    requireInitialized();
    try {
      ffmpeg.ffmpeg_kit_config_disable_debug_log(session.handle);
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_disable_debug_log",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns `true` if per-session debug logging is enabled for [session].
  static bool isDebugLogEnabled(Session session) {
    requireInitialized();
    try {
      return ffmpeg.ffmpeg_kit_config_is_debug_log_enabled(session.handle);
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_is_debug_log_enabled",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Returns the accumulated debug log for [session].
  static String getDebugLog(Session session) {
    requireInitialized();
    try {
      return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_config_get_debug_log(session.handle),
      );
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_get_debug_log",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  /// Clears the debug log for [session].
  static void clearDebugLog(Session session) {
    requireInitialized();
    try {
      ffmpeg.ffmpeg_kit_config_clear_debug_log(session.handle);
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_clear_debug_log",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Throws [ArgumentError] if [value] is blank (empty or whitespace-only).
  static void _requireNonBlank(String value, String paramName) {
    requireInitialized();
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, paramName, 'must not be blank');
    }
  }

  /// Converts a heap-allocated `char*` to a Dart [String], frees it, and
  /// returns the string.  Returns `''` when [ptr] is the null pointer.
  ///
  /// Centralising this pattern eliminates the eight copies of the same
  /// three-line idiom that existed across the class.
  static String _nativeStringOrEmpty(Pointer<Char> ptr) {
    requireInitialized();
    if (ptr == nullptr) return '';
    final result = ptr.cast<Utf8>().toDartString();
    try {
      ffmpeg.ffmpeg_kit_free(ptr.cast());
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_free",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
    return result;
  }

  /// Reads the command string from a session [handle].
  ///
  /// Returns `''` for a null handle or a null command pointer.
  static String _getSessionCommand(Pointer<Void> handle) {
    requireInitialized();
    if (handle == nullptr) return '';
    final cmdPtr = ffmpeg.ffmpeg_kit_session_get_command(handle);
    if (cmdPtr == nullptr) return '';
    final cmd = cmdPtr.cast<Utf8>().toDartString();
    try {
      ffmpeg.ffmpeg_kit_free(cmdPtr.cast());
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_free",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
    return cmd;
  }

  /// Wraps [handle] into the most-specific [Session] subclass.
  ///
  /// Checks [callback_manager.CallbackManager] first to reuse an existing Dart object if the
  /// session is currently active.  Falls back to constructing a new
  /// `fromHandle` instance using the C type-flag API to determine the correct
  /// subclass.
  ///
  /// The priority order — MediaInformation before FFprobe — is deliberate:
  /// [MediaInformationSession] extends [FFprobeSession], so its type flag is
  /// checked first to avoid mis-classifying it as a plain [FFprobeSession].
  static Session? _wrapSession(Pointer<Void> handle) {
    requireInitialized();
    if (handle == nullptr) return null;

    final sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
    final manager = callback_manager.CallbackManager();

    // Prefer the live Dart object from CallbackManager when available — it
    // carries callbacks and execution state that a fresh fromHandle would lack.
    final existing =
        manager.ffmpegSessions[sessionId] ??
        manager.mediaInformationSessions[sessionId] ??
        manager.ffprobeSessions[sessionId] ??
        manager.ffplaySessions[sessionId];
    if (existing != null) return existing;

    final cmd = _getSessionCommand(handle);

    // MediaInformation must be checked before FFprobe because
    // MediaInformationSession IS-A FFprobeSession; the FFprobe flag would
    // also match for a MediaInformation handle.
    bool isMediaInfoSession;
    try {
      isMediaInfoSession = ffmpeg.session_is_media_information_session(handle);
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function session_is_media_information_session",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
    if (isMediaInfoSession) {
      return MediaInformationSession.fromHandle(handle, cmd);
    }
    bool isFfmpegSession;
    try {
      isFfmpegSession = ffmpeg.session_is_ffmpeg_session(handle);
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function session_is_ffmpeg_session",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
    if (isFfmpegSession) {
      return FFmpegSession.fromHandle(handle, cmd);
    }
    bool isFfprobeSession;
    try {
      isFfprobeSession = ffmpeg.session_is_ffprobe_session(handle);
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function session_is_ffprobe_session",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
    if (isFfprobeSession) {
      return FFprobeSession.fromHandle(handle, cmd);
    }
    bool isFfplaySession;
    try {
      isFfplaySession = ffmpeg.session_is_ffplay_session(handle);
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function session_is_ffplay_session",
        error: e,
        stackTrace: stack,
      );
      throw Exception(e);
    }
    if (isFfplaySession) {
      return FFplaySession.fromHandle(handle, cmd);
    }

    // Unknown type — fall back to FFmpegSession as the most general wrapper.
    return FFmpegSession.fromHandle(handle, cmd);
  }

  /// Iterates a null-terminated handle array returned by the C layer,
  /// wraps each entry using [wrap], releases each handle individually, then
  /// frees the array itself.
  static List<T> _collectTypedSessions<T extends Session>(
    Pointer<Pointer<Void>> ptr,
    T Function(Pointer<Void> handle, String cmd) wrap,
  ) {
    requireInitialized();
    if (ptr == nullptr) return const [];

    final result = <T>[];
    try {
      for (int i = 0; ; i++) {
        final handle = ptr[i];
        if (handle == nullptr) break;
        // fromHandle attaches a NativeFinalizer for this handle, so we do not
        // call [FFmpegKitExtended].releaseHandle here directly.
        result.add(wrap(handle, _getSessionCommand(handle)));
      }
    } finally {
      // Free only the array allocation; individual handles are owned by the
      // NativeFinalizer on each returned Session object.
      try {
        ffmpeg.ffmpeg_kit_free(ptr.cast());
      } catch (e, stack) {
        log(
          "FFmpegKitExtended: Failed to call native function ffmpeg_kit_free",
          error: e,
          stackTrace: stack,
        );
        throw Exception(e);
      }
    }
    return result;
  }

  /// Variant of [_collectTypedSessions] that uses [_wrapSession] to produce
  /// the most-specific [Session] subtype for each handle.
  static List<Session> _collectSessions(
    Pointer<Pointer<Void>> ptr,
    Session? Function(Pointer<Void>) wrap,
  ) {
    requireInitialized();
    if (ptr == nullptr) return const [];

    final result = <Session>[];
    try {
      for (int i = 0; ; i++) {
        final handle = ptr[i];
        if (handle == nullptr) break;
        final session = wrap(handle);
        if (session != null) result.add(session);
      }
    } finally {
      try {
        ffmpeg.ffmpeg_kit_free(ptr.cast());
      } catch (e, stack) {
        log(
          "FFmpegKitExtended: Failed to call native function ffmpeg_kit_free",
          error: e,
          stackTrace: stack,
        );
        throw Exception(e);
      }
    }
    return result;
  }
}
