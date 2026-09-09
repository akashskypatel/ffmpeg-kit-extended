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

import 'callback_manager.dart' as callback_manager;
import 'ffmpeg_session.dart';
import 'ffplay_session.dart';
import 'ffprobe_session.dart';
import 'log.dart';
import 'media_information_session.dart';
import 'platform/backend.dart';
import 'platform/backend_selector.dart';
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
    ffmpegKitBackend.requireInitialized();
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
  static Future<void> initialize() => ffmpegKitBackend.initialize();

  /// Returns `true` if [initialize] has been called successfully.
  static bool get initialized => ffmpegKitBackend.initialized;

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
  /// IMPORTANT: passing a 0 will cancel all sessions.
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
    ffmpegKitBackend.setLogLevel(level.value);
  }

  /// Returns the current global log level.
  static LogLevel getLogLevel() {
    requireInitialized();
    return LogLevel.fromValue(ffmpegKitBackend.getLogLevel());
  }

  /// Enables redirection of FFmpeg logs to the system console.
  static void enableRedirection() {
    requireInitialized();
    ffmpegKitBackend.enableRedirection();
  }

  /// Disables redirection of FFmpeg logs to the system console.
  static void disableRedirection() {
    requireInitialized();
    ffmpegKitBackend.disableRedirection();
  }

  // ---------------------------------------------------------------------------
  // Font & audio configuration
  // ---------------------------------------------------------------------------

  /// Sets the font directory and optional name [mapping] JSON.
  static void setFontDirectory(String path, {String? mapping}) {
    requireInitialized();
    ffmpegKitBackend.setFontDirectory(path, mapping: mapping);
  }

  /// Sets [deviceName] as the audio output device.
  static void setAudioOutputDevice(String deviceName) {
    requireInitialized();
    ffmpegKitBackend.setAudioOutputDevice(deviceName);
  }

  /// Returns a semicolon-separated list of available audio output devices.
  static String listAudioOutputDevices() {
    requireInitialized();
    return ffmpegKitBackend.listAudioOutputDevices();
  }

  // ---------------------------------------------------------------------------
  // Environment & signals
  // ---------------------------------------------------------------------------

  /// Sets the environment variable [name] to [value].
  static void setEnvironmentVariable(String name, String value) {
    requireInitialized();
    ffmpegKitBackend.setEnvironmentVariable(name, value);
  }

  /// Configures FFmpegKit to ignore [signal].
  static void ignoreSignal(Signal signal) {
    requireInitialized();
    ffmpegKitBackend.ignoreSignal(signal.value);
  }

  // ---------------------------------------------------------------------------
  // Version & package information
  // ---------------------------------------------------------------------------

  /// Returns the bundled FFmpeg version string.
  static PackageInformationSnapshot _packageInformation() {
    requireInitialized();
    return ffmpegKitBackend.getPackageInformation();
  }

  static String getFFmpegVersion() => _packageInformation().ffmpegVersion;

  /// Returns the CPU architecture of the bundled FFmpeg binary.
  static String getFFmpegArchitecture() => _packageInformation().architecture;

  /// Returns the FFmpegKit library version string.
  static String getVersion() => _packageInformation().version;

  /// Returns the package name of this FFmpegKit build.
  static String getPackageName() => _packageInformation().packageName;

  /// Returns the external libraries bundled with this FFmpegKit build.
  static String getExternalLibraries() => _packageInformation().externalLibraries;

  /// Returns the FFmpegKit bundle type.
  static String getBundleType() => _packageInformation().bundleType;

  /// Returns whether this FFmpegKit build has GPL enabled.
  static bool isGpl() => _packageInformation().isGpl;

  /// Returns whether this FFmpegKit build has non-free libraries enabled.
  static bool isNonfree() => _packageInformation().isNonfree;

  /// Returns a comma-separated list of all registered codecs.
  static String getRegisteredCodecs() => _packageInformation().registeredCodecs;

  /// Returns a comma-separated list of all registered encoders.
  static String getRegisteredEncoders() => _packageInformation().registeredEncoders;

  /// Returns a comma-separated list of all registered decoders.
  static String getRegisteredDecoders() => _packageInformation().registeredDecoders;

  /// Returns a comma-separated list of all registered muxers.
  static String getRegisteredMuxers() => _packageInformation().registeredMuxers;

  /// Returns a comma-separated list of all registered demuxers.
  static String getRegisteredDemuxers() => _packageInformation().registeredDemuxers;

  /// Returns a comma-separated list of all registered filters.
  static String getRegisteredFilters() => _packageInformation().registeredFilters;

  /// Returns a comma-separated list of all registered protocols.
  static String getRegisteredProtocols() => _packageInformation().registeredProtocols;

  /// Returns a comma-separated list of all registered bitstream filters.
  static String getRegisteredBitstreamFilters() => _packageInformation().registeredBitstreamFilters;

  /// Returns the FFmpeg build configuration string.
  static String getBuildConfiguration() => _packageInformation().buildConfiguration;

  /// Returns the library build date.
  static String getBuildDate() => _packageInformation().buildDate;

  // ---------------------------------------------------------------------------
  // Session history
  // ---------------------------------------------------------------------------

  /// Sets the maximum number of sessions to retain in native-layer history.
  static void setSessionHistorySize(int size) {
    requireInitialized();
    ffmpegKitBackend.setSessionHistorySize(size);
  }

  /// Returns the current native-layer session history size.
  static int getSessionHistorySize() {
    requireInitialized();
    return ffmpegKitBackend.getSessionHistorySize();
  }

  /// Returns all sessions in native-layer history, correctly typed.
  static List<Session> getSessions() {
    requireInitialized();
    return ffmpegKitBackend.getSessions().map(_wrapSession).whereType<Session>().toList();
  }

  /// Returns all FFmpeg sessions in native-layer history.
  static List<FFmpegSession> getFFmpegSessions() {
    requireInitialized();
    return ffmpegKitBackend.getFFmpegSessions().map(_wrapSession).whereType<FFmpegSession>().toList();
  }

  /// Returns all FFprobe sessions in native-layer history.
  static List<FFprobeSession> getFFprobeSessions() {
    requireInitialized();
    return ffmpegKitBackend.getFFprobeSessions().map(_wrapSession).whereType<FFprobeSession>().toList();
  }

  /// Returns all FFplay sessions in native-layer history.
  static List<FFplaySession> getFFplaySessions() {
    requireInitialized();
    return ffmpegKitBackend.getFFplaySessions().map(_wrapSession).whereType<FFplaySession>().toList();
  }

  /// Returns all MediaInformation sessions in native-layer history.
  static List<MediaInformationSession> getMediaInformationSessions() {
    requireInitialized();
    return ffmpegKitBackend.getMediaInformationSessions().map(_wrapSession).whereType<MediaInformationSession>().toList();
  }

  // ---------------------------------------------------------------------------
  // Single-session lookups
  // ---------------------------------------------------------------------------

  /// Returns the session with [sessionId], or `null` if not found.
  static Session? getSession(int sessionId) {
    requireInitialized();
    final handle = ffmpegKitBackend.getSessionById(sessionId);
    return handle == null ? null : _wrapSession(handle);
  }

  /// Returns the most recently created session, or `null`.
  static Session? getLastSession() {
    requireInitialized();
    final handle = ffmpegKitBackend.getLastSession();
    return handle == null ? null : _wrapSession(handle);
  }

  /// Returns the most recently created [FFmpegSession], or `null`.
  static FFmpegSession? getLastFFmpegSession() {
    requireInitialized();
    final handle = ffmpegKitBackend.getLastFFmpegSession();
    return handle == null ? null : _wrapSession(handle) as FFmpegSession?;
  }

  /// Returns the most recently created [FFprobeSession], or `null`.
  static FFprobeSession? getLastFFprobeSession() {
    requireInitialized();
    final handle = ffmpegKitBackend.getLastFFprobeSession();
    return handle == null ? null : _wrapSession(handle) as FFprobeSession?;
  }

  /// Returns the most recently created [FFplaySession], or `null`.
  static FFplaySession? getLastFFplaySession() {
    requireInitialized();
    final handle = ffmpegKitBackend.getLastFFplaySession();
    return handle == null ? null : _wrapSession(handle) as FFplaySession?;
  }

  /// Returns the most recently created [MediaInformationSession], or `null`.
  static MediaInformationSession? getLastMediaInformationSession() {
    requireInitialized();
    final handle = ffmpegKitBackend.getLastMediaInformationSession();
    return handle == null
        ? null
        : _wrapSession(handle) as MediaInformationSession?;
  }

  /// Returns the most recently completed session, or `null`.
  static Session? getLastCompletedSession() {
    requireInitialized();
    final handle = ffmpegKitBackend.getLastCompletedSession();
    return handle == null ? null : _wrapSession(handle);
  }

  /// Gets the session ID for a given session handle.
  static int getSessionId(Object handle) {
    requireInitialized();
    final sessionHandle = handle is SessionHandle ? handle : SessionHandle(handle);
    return ffmpegKitBackend.getSessionId(sessionHandle);
  }

  /// Clears all sessions from the native layer's history store.
  ///
  /// ### Note on Dart-side maps
  /// This clears the C-side session history.  Active sessions tracked in
  /// [callback_manager.CallbackManager]'s runtime maps self-unregister when
  /// their completion callbacks fire.
  static void clearSessions() {
    requireInitialized();
    ffmpegKitBackend.clearSessions();
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
      ffmpegKitBackend.configureLogCallback();
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_enable_log_callback",
        error: e,
        stackTrace: stack,
      );
      rethrow;
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
      ffmpegKitBackend.configureStatisticsCallback();
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_enable_statistics_callback",
        error: e,
        stackTrace: stack,
      );
      rethrow;
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
      ffmpegKitBackend.configureFFmpegSessionCompleteCallback();
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_enable_ffmpeg_session_complete_callback",
        error: e,
        stackTrace: stack,
      );
      rethrow;
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
      ffmpegKitBackend.configureFFprobeSessionCompleteCallback();
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_enable_ffprobe_session_complete_callback",
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Sets [completeCallback] as the global FFplay session complete callback.
  static void enableFFplaySessionCompleteCallback([
    callback_manager.FFplaySessionCompleteCallback? completeCallback,
  ]) {
    requireInitialized();
    try {
      callback_manager.CallbackManager().globalFFplaySessionCompleteCallback =
          completeCallback;
      ffmpegKitBackend.configureFFplaySessionCompleteCallback();
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_enable_ffplay_session_complete_callback",
        error: e,
        stackTrace: stack,
      );
      rethrow;
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
      ffmpegKitBackend.configureMediaInformationSessionCompleteCallback();
    } catch (e, stack) {
      log(
        "FFmpegKitExtended: Failed to call native function ffmpeg_kit_config_enable_media_information_session_complete_callback",
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Pipes
  // ---------------------------------------------------------------------------

  /// Registers a new named FFmpeg pipe and returns its path, or `null` on
  /// failure.
  static String? registerNewFFmpegPipe() {
    requireInitialized();
    return ffmpegKitBackend.registerNewFFmpegPipe();
  }

  /// Closes the FFmpeg pipe at [pipePath].
  static void closeFFmpegPipe(String pipePath) {
    requireInitialized();
    ffmpegKitBackend.closeFFmpegPipe(pipePath);
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
    ffmpegKitBackend.setFontDirectoryList(
      fontDirectoryList,
      mapping: fontMappings == null || fontMappings.isEmpty
          ? null
          : jsonEncode(fontMappings),
    );
  }

  // ---------------------------------------------------------------------------
  // Miscellaneous config helpers
  // ---------------------------------------------------------------------------

  /// Converts [state] to its human-readable string name.
  static String sessionStateToString(SessionState state) {
    requireInitialized();
    return ffmpegKitBackend.sessionStateToString(state.value);
  }

  /// Converts [level] to its human-readable string name, or `null` if
  /// unrecognised.
  static String? logLevelToString(LogLevel level) {
    requireInitialized();
    return ffmpegKitBackend.logLevelToString(level.value);
  }

  /// Parses [command] into an argument list.
  static List<String> parseArguments(String command) {
    requireInitialized();
    return ffmpegKitBackend.parseArguments(command);
  }

  /// Joins [arguments] back into a single command string.
  static String argumentsToString(List<String> arguments) {
    requireInitialized();
    return ffmpegKitBackend.argumentsToString(arguments);
  }

  /// Returns the number of log/stats messages buffered for [sessionId].
  static int messagesInTransmit(int sessionId) {
    requireInitialized();
    return ffmpegKitBackend.messagesInTransmit(sessionId);
  }

  // ---------------------------------------------------------------------------
  // Per-session debug log (static API mirroring Session instance methods)
  // ---------------------------------------------------------------------------

  /// Enables per-session debug logging for [session].
  static void enableDebugLog(Session session) {
    requireInitialized();
    ffmpegKitBackend.enableDebugLog(session.handle);
  }

  /// Disables per-session debug logging for [session].
  static void disableDebugLog(Session session) {
    requireInitialized();
    ffmpegKitBackend.disableDebugLog(session.handle);
  }

  /// Returns `true` if per-session debug logging is enabled for [session].
  static bool isDebugLogEnabled(Session session) {
    requireInitialized();
    return ffmpegKitBackend.isDebugLogEnabled(session.handle);
  }

  /// Returns the accumulated debug log for [session].
  static String getDebugLog(Session session) {
    requireInitialized();
    return ffmpegKitBackend.getDebugLog(session.handle) ?? '';
  }

  /// Clears the debug log for [session].
  static void clearDebugLog(Session session) {
    requireInitialized();
    ffmpegKitBackend.clearDebugLog(session.handle);
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

  /// Reads the command string from a session [handle].
  ///
  /// Returns `''` for a null handle or a null command pointer.
  static String _getSessionCommand(SessionHandle handle) {
    requireInitialized();
    return ffmpegKitBackend.getCommand(handle) ?? '';
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
  static Session? _wrapSession(SessionHandle handle) {
    requireInitialized();
    final sessionId = ffmpegKitBackend.getSessionId(handle);
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
    final isMediaInfoSession = ffmpegKitBackend.isMediaInformationSession(handle);
    if (isMediaInfoSession) {
      return MediaInformationSession.fromHandle(handle, cmd);
    }
    final isFfmpegSession = ffmpegKitBackend.isFFmpegSession(handle);
    if (isFfmpegSession) {
      return FFmpegSession.fromHandle(handle, cmd);
    }
    final isFfprobeSession = ffmpegKitBackend.isFFprobeSession(handle);
    if (isFfprobeSession) {
      return FFprobeSession.fromHandle(handle, cmd);
    }
    final isFfplaySession = ffmpegKitBackend.isFFplaySession(handle);
    if (isFfplaySession) {
      return FFplaySession.fromHandle(handle, cmd);
    }

    // Unknown type — fall back to FFmpegSession as the most general wrapper.
      return FFmpegSession.fromHandle(handle, cmd);
  }

}
