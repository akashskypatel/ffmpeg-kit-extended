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
    return FFplaySession(command,
        timeout: timeout, completeCallback: completeCallback);
  }

  /// Creates a new [MediaInformationSession] for [command].
  ///
  /// [MediaInformationSession] completion event.  It is now correctly typed
  /// as [MediaInformationSessionCompleteCallback].
  ///
  /// Throws [ArgumentError] if [command] is blank.
  static MediaInformationSession createMediaInformationSession(
    String command, {
    int timeout = 500,
    callback_manager.MediaInformationSessionCompleteCallback? completeCallback,
  }) {
    requireInitialized();
    _requireNonBlank(command, 'command');
    return MediaInformationSession(command,
        timeout: timeout, completeCallback: completeCallback);
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
    ffmpeg.ffmpeg_kit_config_set_log_level(
        FFmpegKitLogLevel.fromValue(level.value));
  }

  /// Returns the current global log level.
  static LogLevel getLogLevel() {
    requireInitialized();
    return LogLevel.fromValue(ffmpeg.ffmpeg_kit_config_get_log_level().value);
  }

  /// Enables redirection of FFmpeg logs to the system console.
  static void enableRedirection() {
    requireInitialized();
    ffmpeg.ffmpeg_kit_config_enable_redirection();
  }

  /// Disables redirection of FFmpeg logs to the system console.
  static void disableRedirection() {
    requireInitialized();
    ffmpeg.ffmpeg_kit_config_disable_redirection();
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
          pathPtr.cast(), mappingPtr.cast());
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
    } finally {
      malloc.free(ptr);
    }
  }

  /// Returns a semicolon-separated list of available audio output devices.
  static String listAudioOutputDevices() {
    requireInitialized();
    return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_config_list_audio_output_devices());
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
          namePtr.cast(), valuePtr.cast());
    } finally {
      malloc.free(namePtr);
      malloc.free(valuePtr);
    }
  }

  /// Configures FFmpegKit to ignore [signal].
  static void ignoreSignal(Signal signal) {
    requireInitialized();
    ffmpeg.ffmpeg_kit_config_ignore_signal(
        FFmpegKitSignal.fromValue(signal.value));
  }

  // ---------------------------------------------------------------------------
  // Version & package information
  // ---------------------------------------------------------------------------

  /// Returns the bundled FFmpeg version string.
  static String getFFmpegVersion() {
    requireInitialized();
    return _nativeStringOrEmpty(ffmpeg.ffmpeg_kit_config_get_ffmpeg_version());
  }

  /// Returns the CPU architecture of the bundled FFmpeg binary.
  static String getFFmpegArchitecture() {
    requireInitialized();
    return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_config_get_ffmpeg_architecture());
  }

  /// Returns the FFmpegKit library version string.
  static String getVersion() {
    requireInitialized();
    return _nativeStringOrEmpty(ffmpeg.ffmpeg_kit_config_get_version());
  }

  /// Returns the package name of this FFmpegKit build.
  static String getPackageName() {
    requireInitialized();
    return _nativeStringOrEmpty(ffmpeg.ffmpeg_kit_packages_get_package_name());
  }

  /// Returns the external libraries bundled with this FFmpegKit build.
  static String getExternalLibraries() {
    requireInitialized();
    return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_packages_get_external_libraries());
  }

  /// Returns the library build date.
  static String getBuildDate() {
    requireInitialized();
    return _nativeStringOrEmpty(ffmpeg.ffmpeg_kit_config_get_build_date());
  }

  // ---------------------------------------------------------------------------
  // Session history
  // ---------------------------------------------------------------------------

  /// Sets the maximum number of sessions to retain in native-layer history.
  static void setSessionHistorySize(int size) {
    requireInitialized();
    ffmpeg.ffmpeg_kit_set_session_history_size(size);
  }

  /// Returns the current native-layer session history size.
  static int getSessionHistorySize() {
    requireInitialized();
    return ffmpeg.ffmpeg_kit_get_session_history_size();
  }

  /// Returns all sessions in native-layer history, correctly typed.
  static List<Session> getSessions() {
    requireInitialized();
    return _collectSessions(ffmpeg.ffmpeg_kit_get_sessions(), _wrapSession);
  }

  /// Returns all FFmpeg sessions in native-layer history.
  static List<FFmpegSession> getFFmpegSessions() {
    requireInitialized();
    return _collectTypedSessions<FFmpegSession>(
      ffmpeg.ffmpeg_kit_get_ffmpeg_sessions(),
      FFmpegSession.fromHandle,
    );
  }

  /// Returns all FFprobe sessions in native-layer history.
  static List<FFprobeSession> getFFprobeSessions() {
    requireInitialized();
    return _collectTypedSessions<FFprobeSession>(
      ffmpeg.ffmpeg_kit_get_ffprobe_sessions(),
      FFprobeSession.fromHandle,
    );
  }

  /// Returns all FFplay sessions in native-layer history.
  static List<FFplaySession> getFFplaySessions() {
    requireInitialized();
    return _collectTypedSessions<FFplaySession>(
      ffmpeg.ffmpeg_kit_get_ffplay_sessions(),
      FFplaySession.fromHandle,
    );
  }

  /// Returns all MediaInformation sessions in native-layer history.
  static List<MediaInformationSession> getMediaInformationSessions() {
    requireInitialized();
    return _collectTypedSessions<MediaInformationSession>(
      ffmpeg.ffmpeg_kit_get_media_information_sessions(),
      MediaInformationSession.fromHandle,
    );
  }

  // ---------------------------------------------------------------------------
  // Single-session lookups
  // ---------------------------------------------------------------------------

  /// Returns the session with [sessionId], or `null` if not found.
  static Session? getSession(int sessionId) {
    requireInitialized();
    return _wrapSession(ffmpeg.ffmpeg_kit_get_session(sessionId));
  }

  /// Returns the most recently created session, or `null`.
  static Session? getLastSession() {
    requireInitialized();
    return _wrapSession(ffmpeg.ffmpeg_kit_get_last_session());
  }

  /// Returns the most recently created [FFmpegSession], or `null`.
  static FFmpegSession? getLastFFmpegSession() {
    requireInitialized();
    final h = ffmpeg.ffmpeg_kit_get_last_ffmpeg_session();
    if (h == nullptr) return null;
    final session = FFmpegSession.fromHandle(h, _getSessionCommand(h));
    // Release is handled by the NativeFinalizer attached inside fromHandle.
    return session;
  }

  /// Returns the most recently created [FFprobeSession], or `null`.
  static FFprobeSession? getLastFFprobeSession() {
    requireInitialized();
    final h = ffmpeg.ffmpeg_kit_get_last_ffprobe_session();
    if (h == nullptr) return null;
    return FFprobeSession.fromHandle(h, _getSessionCommand(h));
  }

  /// Returns the most recently created [FFplaySession], or `null`.
  static FFplaySession? getLastFFplaySession() {
    requireInitialized();
    final h = ffmpeg.ffmpeg_kit_get_last_ffplay_session();
    if (h == nullptr) return null;
    return FFplaySession.fromHandle(h, _getSessionCommand(h));
  }

  /// Returns the most recently created [MediaInformationSession], or `null`.
  static MediaInformationSession? getLastMediaInformationSession() {
    requireInitialized();
    final h = ffmpeg.ffmpeg_kit_get_last_media_information_session();
    if (h == nullptr) return null;
    return MediaInformationSession.fromHandle(h, _getSessionCommand(h));
  }

  /// Returns the most recently completed session, or `null`.
  static Session? getLastCompletedSession() {
    requireInitialized();
    return _wrapSession(ffmpeg.ffmpeg_kit_get_last_completed_session());
  }

  /// Gets the session ID for a given session handle.
  static int getSessionId(Pointer<Void> handle) {
    requireInitialized();
    return ffmpeg.ffmpeg_kit_session_get_session_id(handle);
  }

  /// Clears all sessions from the native layer's history store.
  ///
  /// ### Note on Dart-side maps
  /// This clears the C-side session history.  To also evict sessions from
  /// [callback_manager.CallbackManager]'s runtime maps (which track *active* sessions, not
  /// history) use [callback_manager.CallbackManager.unregisterAny] or let sessions
  /// self-unregister when their completion callbacks fire.
  static void clearSessions() {
    requireInitialized();
    ffmpeg.ffmpeg_kit_clear_sessions();
  }

  // ---------------------------------------------------------------------------
  // Global callbacks
  // ---------------------------------------------------------------------------

  /// Sets [logCallback] as the global log callback and registers it with the
  /// native layer.  Pass `null` to deregister.
  static void enableLogCallback(
      [callback_manager.FFmpegLogCallback? logCallback]) {
    requireInitialized();
    callback_manager.CallbackManager().globalLogCallback = logCallback;
    ffmpeg.ffmpeg_kit_config_enable_log_callback(
        callback_manager.nativeFFmpegLog.nativeFunction, nullptr);
  }

  /// Sets [statisticsCallback] as the global statistics callback.
  /// Pass `null` to deregister.
  static void enableStatisticsCallback(
      [callback_manager.FFmpegStatisticsCallback? statisticsCallback]) {
    requireInitialized();
    callback_manager.CallbackManager().globalStatisticsCallback =
        statisticsCallback;
    ffmpeg.ffmpeg_kit_config_enable_statistics_callback(
        callback_manager.nativeFFmpegStatistics.nativeFunction, nullptr);
  }

  /// Sets [completeCallback] as the global FFmpeg session complete callback.
  static void enableFFmpegSessionCompleteCallback(
      [callback_manager.FFmpegSessionCompleteCallback? completeCallback]) {
    requireInitialized();
    callback_manager.CallbackManager().globalFFmpegSessionCompleteCallback =
        completeCallback;
    ffmpeg.ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
        callback_manager.nativeFFmpegComplete.nativeFunction, nullptr);
  }

  /// Sets [completeCallback] as the global FFprobe session complete callback.
  static void enableFFprobeSessionCompleteCallback(
      [callback_manager.FFprobeSessionCompleteCallback? completeCallback]) {
    requireInitialized();
    callback_manager.CallbackManager().globalFFprobeSessionCompleteCallback =
        completeCallback;
    ffmpeg.ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
        callback_manager.nativeFFprobeComplete.nativeFunction, nullptr);
  }

  /// Sets [completeCallback] as the global FFplay session complete callback.
  static void enableFFplaySessionCompleteCallback(
      [callback_manager.FFplaySessionCompleteCallback? completeCallback]) {
    requireInitialized();
    callback_manager.CallbackManager().globalFFplaySessionCompleteCallback =
        completeCallback;
    ffmpeg.ffmpeg_kit_config_enable_ffplay_session_complete_callback(
        callback_manager.nativeFFplayComplete.nativeFunction, nullptr);
  }

  /// Sets [completeCallback] as the global MediaInformation session complete
  /// callback.
  static void enableMediaInformationSessionCompleteCallback(
      [callback_manager.MediaInformationSessionCompleteCallback?
          completeCallback]) {
    requireInitialized();
    callback_manager.CallbackManager()
        .globalMediaInformationSessionCompleteCallback = completeCallback;
    ffmpeg.ffmpeg_kit_config_enable_media_information_session_complete_callback(
        callback_manager.nativeMediaInfoComplete.nativeFunction, nullptr);
  }

  // ---------------------------------------------------------------------------
  // Pipes
  // ---------------------------------------------------------------------------

  /// Registers a new named FFmpeg pipe and returns its path, or `null` on
  /// failure.
  static String? registerNewFFmpegPipe() {
    requireInitialized();
    final ptr = ffmpeg.ffmpeg_kit_config_register_new_ffmpeg_pipe();
    if (ptr == nullptr) return null;
    final result = ptr.cast<Utf8>().toDartString();
    ffmpeg.ffmpeg_kit_free(ptr.cast());
    return result;
  }

  /// Closes the FFmpeg pipe at [pipePath].
  static void closeFFmpegPipe(String pipePath) {
    requireInitialized();
    final ptr = pipePath.toNativeUtf8();
    try {
      ffmpeg.ffmpeg_kit_config_close_ffmpeg_pipe(ptr.cast());
    } finally {
      malloc.free(ptr);
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
          listPtr.cast(), count, mappingsPtr);
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
    return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_config_session_state_to_string(
            FFmpegKitSessionState.fromValue(state.value)));
  }

  /// Converts [level] to its human-readable string name, or `null` if
  /// unrecognised.
  static String? logLevelToString(LogLevel level) {
    requireInitialized();
    final ptr = ffmpeg.ffmpeg_kit_config_log_level_to_string(
        FFmpegKitLogLevel.fromValue(level.value));
    if (ptr == nullptr) return null;
    final result = ptr.cast<Utf8>().toDartString();
    ffmpeg.ffmpeg_kit_free(ptr.cast());
    return result;
  }

  /// Parses [command] into an argument list.
  static List<String> parseArguments(String command) {
    requireInitialized();
    final cmdPtr = command.toNativeUtf8();
    final countPtr = malloc<Int64>();
    try {
      final argsPtr = ffmpeg.ffmpeg_kit_config_parse_arguments(
          cmdPtr.cast(), countPtr.cast());
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
      final resPtr =
          ffmpeg.ffmpeg_kit_config_arguments_to_string(argsPtr.cast(), count);
      if (resPtr == nullptr) return '';
      final result = resPtr.cast<Utf8>().toDartString();
      ffmpeg.ffmpeg_kit_free(resPtr.cast());
      return result;
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
    return ffmpeg.ffmpeg_kit_config_messages_in_transmit(sessionId);
  }

  // ---------------------------------------------------------------------------
  // Per-session debug log (static API mirroring Session instance methods)
  // ---------------------------------------------------------------------------

  /// Enables per-session debug logging for [session].
  static void enableDebugLog(Session session) {
    requireInitialized();
    ffmpeg.ffmpeg_kit_config_enable_debug_log(session.handle);
  }

  /// Disables per-session debug logging for [session].
  static void disableDebugLog(Session session) {
    requireInitialized();
    ffmpeg.ffmpeg_kit_config_disable_debug_log(session.handle);
  }

  /// Returns `true` if per-session debug logging is enabled for [session].
  static bool isDebugLogEnabled(Session session) {
    requireInitialized();
    return ffmpeg.ffmpeg_kit_config_is_debug_log_enabled(session.handle);
  }

  /// Returns the accumulated debug log for [session].
  static String getDebugLog(Session session) {
    requireInitialized();
    return _nativeStringOrEmpty(
        ffmpeg.ffmpeg_kit_config_get_debug_log(session.handle));
  }

  /// Clears the debug log for [session].
  static void clearDebugLog(Session session) {
    requireInitialized();
    ffmpeg.ffmpeg_kit_config_clear_debug_log(session.handle);
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
    ffmpeg.ffmpeg_kit_free(ptr.cast());
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
    ffmpeg.ffmpeg_kit_free(cmdPtr.cast());
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
    final existing = manager.ffmpegSessions[sessionId] ??
        manager.mediaInformationSessions[sessionId] ??
        manager.ffprobeSessions[sessionId] ??
        manager.ffplaySessions[sessionId];
    if (existing != null) return existing;

    final cmd = _getSessionCommand(handle);

    // MediaInformation must be checked before FFprobe because
    // MediaInformationSession IS-A FFprobeSession; the FFprobe flag would
    // also match for a MediaInformation handle.
    if (ffmpeg.session_is_media_information_session(handle)) {
      return MediaInformationSession.fromHandle(handle, cmd);
    }
    if (ffmpeg.session_is_ffmpeg_session(handle)) {
      return FFmpegSession.fromHandle(handle, cmd);
    }
    if (ffmpeg.session_is_ffprobe_session(handle)) {
      return FFprobeSession.fromHandle(handle, cmd);
    }
    if (ffmpeg.session_is_ffplay_session(handle)) {
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
      for (int i = 0;; i++) {
        final handle = ptr[i];
        if (handle == nullptr) break;
        // fromHandle attaches a NativeFinalizer for this handle, so we do not
        // call [FFmpegKitExtended].releaseHandle here directly.
        result.add(wrap(handle, _getSessionCommand(handle)));
      }
    } finally {
      // Free only the array allocation; individual handles are owned by the
      // NativeFinalizer on each returned Session object.
      ffmpeg.ffmpeg_kit_free(ptr.cast());
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
      for (int i = 0;; i++) {
        final handle = ptr[i];
        if (handle == nullptr) break;
        final session = wrap(handle);
        if (session != null) result.add(session);
      }
    } finally {
      ffmpeg.ffmpeg_kit_free(ptr.cast());
    }
    return result;
  }
}
