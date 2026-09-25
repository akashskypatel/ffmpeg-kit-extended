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
import 'session_history_index.dart';
import 'session_queue_manager.dart';
import 'signal.dart';

enum _ExpectedSessionKind { any, ffmpeg, ffprobe, ffplay, mediaInformation }

/// The main entry point for the FFmpegKit Extended plugin.
///
/// All methods are static.  Use this class to create and manage FFmpeg
/// sessions, configure global settings, and retrieve version information.
class FFmpegKitExtended {
  static final _sessionHistoryIndex = SessionHistoryIndex();

  /// Test-only access to the identity index; it does not expose ownership.
  static SessionHistoryIndex get sessionHistoryIndex => _sessionHistoryIndex;

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
  /// Calling this more than once is safe: concurrent calls share one attempt,
  /// successful initialization is idempotent, and a failed Web attempt can be
  /// retried by calling this method again.
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
    final session = FFmpegSession(
      command,
      completeCallback: completeCallback,
      logCallback: logCallback,
      statisticsCallback: statisticsCallback,
    );
    _rememberSession(session, SessionHistoryType.ffmpeg);
    return session;
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
    final session = FFprobeSession(command, completeCallback: completeCallback);
    _rememberSession(session, SessionHistoryType.ffprobe);
    return session;
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
    final session = FFplaySession(
      command,
      timeout: timeout,
      completeCallback: completeCallback,
    );
    _rememberSession(session, SessionHistoryType.ffplay);
    return session;
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
    final session = MediaInformationSession(
      command,
      timeout: timeout,
      completeCallback: completeCallback,
    );
    _rememberSession(session, SessionHistoryType.mediaInformation);
    return session;
  }

  // ---------------------------------------------------------------------------
  // Session management
  // ---------------------------------------------------------------------------

  /// Cancels the session identified by [sessionId].
  ///
  /// Passing `0` cancels all active and queued sessions managed by
  /// [SessionQueueManager], using the same all-attempts/first-error behavior
  /// as [cancelAllSessions]. A nonzero ID uses the current Dart object/history
  /// lookup and requests cancellation only when that session is available.
  static void cancelSession(int sessionId) {
    requireInitialized();
    if (sessionId == 0) {
      cancelAllSessions();
      return;
    }
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
  ///
  /// Every active session is attempted. If one or more cancellations fail, the
  /// first error is rethrown after all active sessions have been attempted.
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

  /// Enables process-wide redirection of FFmpeg logs to the system console.
  ///
  /// Callback bridge demand does not call this method implicitly.
  static void enableRedirection() {
    requireInitialized();
    ffmpegKitBackend.enableRedirection();
  }

  /// Disables process-wide redirection of FFmpeg logs to the system console.
  ///
  /// This setting remains authoritative while optional log or statistics
  /// consumers are active, and completion remains independent of them.
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
  static String getExternalLibraries() =>
      _packageInformation().externalLibraries;

  /// Returns the FFmpegKit bundle type.
  static String getBundleType() => _packageInformation().bundleType;

  /// Returns whether this FFmpegKit build has GPL enabled.
  static bool isGpl() => _packageInformation().isGpl;

  /// Returns whether this FFmpegKit build has non-free libraries enabled.
  static bool isNonfree() => _packageInformation().isNonfree;

  /// Returns a comma-separated list of all registered codecs.
  static String getRegisteredCodecs() => _packageInformation().registeredCodecs;

  /// Returns a comma-separated list of all registered encoders.
  static String getRegisteredEncoders() =>
      _packageInformation().registeredEncoders;

  /// Returns a comma-separated list of all registered decoders.
  static String getRegisteredDecoders() =>
      _packageInformation().registeredDecoders;

  /// Returns a comma-separated list of all registered muxers.
  static String getRegisteredMuxers() => _packageInformation().registeredMuxers;

  /// Returns a comma-separated list of all registered demuxers.
  static String getRegisteredDemuxers() =>
      _packageInformation().registeredDemuxers;

  /// Returns a comma-separated list of all registered filters.
  static String getRegisteredFilters() =>
      _packageInformation().registeredFilters;

  /// Returns a comma-separated list of all registered protocols.
  static String getRegisteredProtocols() =>
      _packageInformation().registeredProtocols;

  /// Returns a comma-separated list of all registered bitstream filters.
  static String getRegisteredBitstreamFilters() =>
      _packageInformation().registeredBitstreamFilters;

  /// Returns the FFmpeg build configuration string.
  static String getBuildConfiguration() =>
      _packageInformation().buildConfiguration;

  /// Returns the library build date.
  static String getBuildDate() => _packageInformation().buildDate;

  // ---------------------------------------------------------------------------
  // Session history
  // ---------------------------------------------------------------------------

  /// Sets the maximum number of sessions to retain in native-layer history.
  static void setSessionHistorySize(int size) {
    requireInitialized();
    ffmpegKitBackend.setSessionHistorySize(size);
    _pruneTerminalHistory(size);
  }

  /// Returns the current native-layer session history size.
  static int getSessionHistorySize() {
    requireInitialized();
    return ffmpegKitBackend.getSessionHistorySize();
  }

  /// Returns all sessions in native-layer history, correctly typed.
  static List<Session> getSessions() {
    requireInitialized();
    return _projectHistory<Session>();
  }

  /// Returns all FFmpeg sessions in native-layer history.
  static List<FFmpegSession> getFFmpegSessions() {
    requireInitialized();
    return _projectHistory<FFmpegSession>(
      expectedKind: _ExpectedSessionKind.ffmpeg,
    );
  }

  /// Returns all FFprobe sessions in native-layer history.
  static List<FFprobeSession> getFFprobeSessions() {
    requireInitialized();
    return _projectHistory<FFprobeSession>(
      expectedKind: _ExpectedSessionKind.ffprobe,
    );
  }

  /// Returns all FFplay sessions in native-layer history.
  static List<FFplaySession> getFFplaySessions() {
    requireInitialized();
    return _projectHistory<FFplaySession>(
      expectedKind: _ExpectedSessionKind.ffplay,
    );
  }

  /// Returns all MediaInformation sessions in native-layer history.
  static List<MediaInformationSession> getMediaInformationSessions() {
    requireInitialized();
    return _projectHistory<MediaInformationSession>(
      expectedKind: _ExpectedSessionKind.mediaInformation,
    );
  }

  // ---------------------------------------------------------------------------
  // Single-session lookups
  // ---------------------------------------------------------------------------

  /// Returns the session with [sessionId], or `null` if not found.
  static Session? getSession(int sessionId) {
    requireInitialized();
    _synchronizeLiveSessions();
    final entry = _sessionHistoryIndex[sessionId];
    if (entry == null || !entry.visible) return null;
    return _resolveHistoryEntry(entry);
  }

  /// Returns the most recently created session, or `null`.
  static Session? getLastSession() {
    requireInitialized();
    final sessions = _projectHistory<Session>();
    return sessions.isEmpty ? null : sessions.last;
  }

  /// Returns the most recently created [FFmpegSession], or `null`.
  static FFmpegSession? getLastFFmpegSession() {
    requireInitialized();
    final sessions = _projectHistory<FFmpegSession>(
      expectedKind: _ExpectedSessionKind.ffmpeg,
    );
    return sessions.isEmpty ? null : sessions.last;
  }

  /// Returns the most recently created [FFprobeSession], or `null`.
  static FFprobeSession? getLastFFprobeSession() {
    requireInitialized();
    final sessions = _projectHistory<FFprobeSession>(
      expectedKind: _ExpectedSessionKind.ffprobe,
    );
    return sessions.isEmpty ? null : sessions.last;
  }

  /// Returns the most recently created [FFplaySession], or `null`.
  static FFplaySession? getLastFFplaySession() {
    requireInitialized();
    final sessions = _projectHistory<FFplaySession>(
      expectedKind: _ExpectedSessionKind.ffplay,
    );
    return sessions.isEmpty ? null : sessions.last;
  }

  /// Returns the most recently created [MediaInformationSession], or `null`.
  static MediaInformationSession? getLastMediaInformationSession() {
    requireInitialized();
    final sessions = _projectHistory<MediaInformationSession>(
      expectedKind: _ExpectedSessionKind.mediaInformation,
    );
    return sessions.isEmpty ? null : sessions.last;
  }

  /// Returns the most recently completed session, or `null`.
  static Session? getLastCompletedSession() {
    requireInitialized();
    final sessions = _projectHistory<Session>().where((session) {
      final state = session.getState();
      return state == SessionState.completed || state == SessionState.failed;
    }).toList();
    return sessions.isEmpty ? null : sessions.last;
  }

  /// Gets the session ID for a given session handle.
  static int getSessionId(Object handle) {
    requireInitialized();
    final sessionHandle = handle is SessionHandle
        ? handle
        : SessionHandle(handle);
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
    _synchronizeLiveSessions();
    for (final entry in _sessionHistoryIndex.entries.toList()) {
      final live = _liveSession(entry.sessionId);
      if (live == null) {
        _sessionHistoryIndex.remove(entry.sessionId);
      } else {
        entry.visible = false;
      }
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
      callback_manager.CallbackManager().setGlobalLogCallback(
        logCallback,
        install: ffmpegKitBackend.configureLogCallback,
        uninstall: ffmpegKitBackend.disableLogCallback,
      );
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
      callback_manager.CallbackManager().setGlobalStatisticsCallback(
        statisticsCallback,
        install: ffmpegKitBackend.configureStatisticsCallback,
        uninstall: ffmpegKitBackend.disableStatisticsCallback,
      );
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
      callback_manager.CallbackManager().setGlobalFFmpegSessionCompleteCallback(
        completeCallback,
        install: ffmpegKitBackend.configureFFmpegSessionCompleteCallback,
        uninstall: ffmpegKitBackend.disableFFmpegSessionCompleteCallback,
      );
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
      callback_manager.CallbackManager()
          .setGlobalFFprobeSessionCompleteCallback(
            completeCallback,
            install: ffmpegKitBackend.configureFFprobeSessionCompleteCallback,
            uninstall: ffmpegKitBackend.disableFFprobeSessionCompleteCallback,
          );
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
      callback_manager.CallbackManager().setGlobalFFplaySessionCompleteCallback(
        completeCallback,
        install: ffmpegKitBackend.configureFFplaySessionCompleteCallback,
        uninstall: ffmpegKitBackend.disableFFplaySessionCompleteCallback,
      );
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
          .setGlobalMediaInformationSessionCompleteCallback(
            completeCallback,
            install: ffmpegKitBackend
                .configureMediaInformationSessionCompleteCallback,
            uninstall:
                ffmpegKitBackend.disableMediaInformationSessionCompleteCallback,
          );
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
    var ownershipDelegated = false;
    var duplicateReleaseAttempted = false;
    try {
      final sessionId = ffmpegKitBackend.getSessionId(handle);
      final manager = callback_manager.CallbackManager();

      // Prefer the live Dart object from CallbackManager when available — it
      // carries callbacks and execution state that a fresh fromHandle would lack.
      final existing =
          manager.ffmpegSessions[sessionId] ??
          manager.mediaInformationSessions[sessionId] ??
          manager.ffprobeSessions[sessionId] ??
          manager.ffplaySessions[sessionId];
      if (existing != null) {
        // History projection normally avoids acquiring a second handle for an
        // active session. Keep this defensive path ownership-safe as well:
        // terminal/Created handles can be released immediately, while a live
        // handle must remain deferred until its native state is terminal.
        final state = existing.getState();
        if (state == SessionState.created ||
            state == SessionState.completed ||
            state == SessionState.failed) {
          duplicateReleaseAttempted = true;
          ffmpegKitBackend.releaseSession(handle);
        } else {
          _deferredHistoryHandles[sessionId] = handle;
        }
        return existing;
      }

      final cmd = _getSessionCommand(handle);

      // MediaInformation must be checked before FFprobe because
      // MediaInformationSession IS-A FFprobeSession; the FFprobe flag would
      // also match for a MediaInformation handle.
      final isMediaInfoSession = ffmpegKitBackend.isMediaInformationSession(
        handle,
      );
      if (isMediaInfoSession) {
        ownershipDelegated = true;
        return MediaInformationSession.fromHandle(handle, cmd);
      }
      final isFfmpegSession = ffmpegKitBackend.isFFmpegSession(handle);
      if (isFfmpegSession) {
        ownershipDelegated = true;
        return FFmpegSession.fromHandle(handle, cmd);
      }
      final isFfprobeSession = ffmpegKitBackend.isFFprobeSession(handle);
      if (isFfprobeSession) {
        ownershipDelegated = true;
        return FFprobeSession.fromHandle(handle, cmd);
      }
      final isFfplaySession = ffmpegKitBackend.isFFplaySession(handle);
      if (isFfplaySession) {
        ownershipDelegated = true;
        return FFplaySession.fromHandle(handle, cmd);
      }

      // Unknown type is not safe to wrap as FFmpeg: the subclass controls
      // callback routing, cleanup, and native operations. Release the still-
      // untransferred token and fail closed with the classification evidence.
      duplicateReleaseAttempted = true;
      _releaseUntransferredHandle(handle);
      throw StateError(
        'Session $sessionId returned an unknown native session type; '
        'refusing to adopt its handle.',
      );
    } catch (error, stackTrace) {
      if (!ownershipDelegated && !duplicateReleaseAttempted) {
        _releaseUntransferredHandle(handle);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static final Map<int, SessionHandle> _deferredHistoryHandles = {};

  static void _rememberSession(Session session, SessionHistoryType type) {
    _sessionHistoryIndex.record(session.sessionId, type, wrapper: session);
  }

  static SessionHistoryType _historyType(Session session) {
    if (session is MediaInformationSession) {
      return SessionHistoryType.mediaInformation;
    }
    if (session is FFmpegSession) return SessionHistoryType.ffmpeg;
    if (session is FFprobeSession) return SessionHistoryType.ffprobe;
    return SessionHistoryType.ffplay;
  }

  static Session? _liveSession(int sessionId) =>
      callback_manager.CallbackManager().sessionForId(sessionId);

  static void _synchronizeLiveSessions() {
    final manager = callback_manager.CallbackManager();
    for (final session in [
      ...manager.ffmpegSessions.values,
      ...manager.ffprobeSessions.values,
      ...manager.ffplaySessions.values,
      ...manager.mediaInformationSessions.values,
    ]) {
      _rememberSession(session, _historyType(session));
    }
  }

  static void _pruneTerminalHistory(int capacity) {
    if (capacity < 0) return;
    final terminalEntries = <SessionHistoryEntry>[];
    for (final entry in _sessionHistoryIndex.entries) {
      if (!entry.visible) continue;
      final cached = entry.wrapper;
      final session = cached is Session && !cached.isDisposed
          ? cached
          : _liveSession(entry.sessionId);
      if (session == null) continue;
      try {
        final state = session.getState();
        if (state == SessionState.completed || state == SessionState.failed) {
          terminalEntries.add(entry);
        }
      } catch (_) {
        // An invalidated wrapper is reconciled by the next projection. It is
        // not safe to infer terminal ownership from a failed state read.
      }
    }
    final removeCount = terminalEntries.length - capacity;
    if (removeCount <= 0) return;
    for (final entry in terminalEntries.take(removeCount)) {
      entry.visible = false;
    }
  }

  static bool _matchesExpectedKind(
    SessionHistoryEntry entry,
    _ExpectedSessionKind expectedKind,
  ) {
    switch (expectedKind) {
      case _ExpectedSessionKind.any:
        return true;
      case _ExpectedSessionKind.ffmpeg:
        return entry.type == SessionHistoryType.ffmpeg;
      case _ExpectedSessionKind.ffprobe:
        return entry.type == SessionHistoryType.ffprobe;
      case _ExpectedSessionKind.ffplay:
        return entry.type == SessionHistoryType.ffplay;
      case _ExpectedSessionKind.mediaInformation:
        return entry.type == SessionHistoryType.mediaInformation;
    }
  }

  static Session? _resolveHistoryEntry(SessionHistoryEntry entry) {
    final cached = entry.wrapper;
    if (cached is Session && !cached.isDisposed) return cached;
    if (cached != null) entry.clearWrapper();

    final live = _liveSession(entry.sessionId);
    if (live != null) {
      entry.cacheWrapper(live);
      return live;
    }

    final handle = ffmpegKitBackend.getSessionById(entry.sessionId);
    if (handle == null) {
      _sessionHistoryIndex.remove(entry.sessionId);
      return null;
    }
    final session = _wrapSession(handle);
    if (session == null) {
      _sessionHistoryIndex.remove(entry.sessionId);
      return null;
    }
    entry.cacheWrapper(session);
    return session;
  }

  static List<T> _projectHistory<T extends Session>({
    _ExpectedSessionKind expectedKind = _ExpectedSessionKind.any,
  }) {
    _synchronizeLiveSessions();
    final sessions = <T>[];
    for (final entry in _sessionHistoryIndex.entries.toList()) {
      if (!entry.visible || !_matchesExpectedKind(entry, expectedKind)) {
        continue;
      }
      final session = _resolveHistoryEntry(entry);
      if (session == null) continue;
      if (session is! T) continue;
      sessions.add(session);
    }
    _releaseDeferredHistoryHandles();
    return sessions;
  }

  static void _releaseDeferredHistoryHandles() {
    for (final entry in _deferredHistoryHandles.entries.toList()) {
      final live = _liveSession(entry.key);
      if (live == null) {
        _deferredHistoryHandles.remove(entry.key);
        ffmpegKitBackend.releaseSession(entry.value);
        continue;
      }
      try {
        final state = live.getState();
        if (state == SessionState.completed || state == SessionState.failed) {
          _deferredHistoryHandles.remove(entry.key);
          ffmpegKitBackend.releaseSession(entry.value);
        }
      } catch (_) {
        // Keep the ownership deferred while the live session is still
        // authoritative; the next history read retries the terminal check.
      }
    }
  }

  static void _releaseUntransferredHandle(SessionHandle handle) {
    try {
      ffmpegKitBackend.releaseSession(handle);
    } catch (cleanupError, cleanupStackTrace) {
      log(
        'FFmpegKitExtended: failed to release an untransferred session handle',
        error: cleanupError,
        stackTrace: cleanupStackTrace,
      );
    }
  }
}
