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

import 'package:meta/meta.dart';

import '../ffmpeg_kit_extended_flutter.dart';
import 'callback_manager.dart';
import 'platform/backend.dart';
import 'platform/backend_selector.dart';

/// Awaits a media-information execution and preserves the original backend
/// or transport error for the caller.
@visibleForTesting
Future<void> awaitMediaInformationExecution(
  Future<void> execution,
  int sessionId,
) async {
  try {
    await execution;
  } catch (e, st) {
    log(
      'MediaInformationSession: error awaiting session $sessionId',
      error: e,
      stackTrace: st,
    );
    rethrow;
  }
}

/// A specialised [FFprobeSession] for retrieving detailed media information.
///
/// Internally runs an ffprobe command with `-print_format json -show_format
/// -show_streams -show_chapters` and parses the result into a [MediaInformation]
/// object that can be retrieved via [getMediaInformation].
/// [execute] blocks until parsing and cleanup complete, so callers can inspect
/// media information immediately. Use [executeAsync] for long work on the
/// Flutter UI isolate; that path is managed by [SessionQueueManager].
class MediaInformationSession extends FFprobeSession {
  MediaInformationSessionCompleteCallback? _mediaInfoCompleteCallback;

  int _timeout;

  // ---------------------------------------------------------------------------
  // Default ffprobe command fragments
  // ---------------------------------------------------------------------------

  static const String _defaultCommandPrefix = '-v error -hide_banner';
  static const List<String> _defaultCommandPrefixArguments = [
    '-v',
    'error',
    '-hide_banner',
  ];
  static const List<String> _defaultMediaInformationArguments = [
    '-print_format',
    'json',
    '-show_format',
    '-show_streams',
    '-show_chapters',
    '-i',
  ];

  // ---------------------------------------------------------------------------
  // Callback accessors / mutators
  // ---------------------------------------------------------------------------

  /// The callback invoked once when information retrieval completes.
  MediaInformationSessionCompleteCallback? get mediaInfoCompleteCallback =>
      _mediaInfoCompleteCallback;

  /// Overrides the base [completeCallback] getter to surface the typed callback
  /// as a [FFprobeSessionCompleteCallback] so that shared session-management
  /// code that only knows about [FFprobeSession] can still invoke it.
  ///
  /// Safe because [MediaInformationSession] IS-A [FFprobeSession].
  @override
  FFprobeSessionCompleteCallback? get completeCallback =>
      _mediaInfoCompleteCallback != null
      ? (s) => _mediaInfoCompleteCallback!(s as MediaInformationSession)
      : null;

  /// Sets or replaces the completion callback.
  void setMediaInfoCompleteCallback(
    MediaInformationSessionCompleteCallback? cb,
  ) {
    final previous = _mediaInfoCompleteCallback;
    _mediaInfoCompleteCallback = cb;
    if (cb == null) {
      unregisterIfIdle();
    } else {
      try {
        ensureRegisteredForSinkDemand();
      } catch (_) {
        _mediaInfoCompleteCallback = previous;
        rethrow;
      }
    }
  }

  /// Clears the completion callback and unregisters from [CallbackManager]
  /// if no other log-delivery sinks remain attached.
  void removeMediaInfoCompleteCallback() {
    _mediaInfoCompleteCallback = null;
    unregisterIfIdle();
  }

  /// Kept for API compatibility with callers that hold an [FFprobeSession]
  /// reference; routes to [setMediaInfoCompleteCallback] with a safe cast.
  @override
  void setCompleteCallback(FFprobeSessionCompleteCallback? completeCallback) {
    if (completeCallback == null) {
      removeMediaInfoCompleteCallback();
    } else {
      setMediaInfoCompleteCallback((s) => completeCallback(s));
    }
  }

  /// Clears all completion callbacks.
  @override
  void removeCompleteCallback() => removeMediaInfoCompleteCallback();

  // ---------------------------------------------------------------------------
  // Timeout
  // ---------------------------------------------------------------------------

  /// The connection timeout in milliseconds.
  int get timeout => _timeout;

  /// Sets the connection [timeout] in milliseconds.
  void setTimeout(int timeout) => _timeout = timeout;

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Creates an in-memory media-information session for lifecycle tests.
  @visibleForTesting
  MediaInformationSession.test({
    int sessionId = 1,
    String command = 'test',
    MediaInformationSessionCompleteCallback? completeCallback,
    this._timeout = 500,
  }) : super.internal() {
    handle = const SessionHandle(Object());
    this.sessionId = sessionId;
    this.command = command;
    _mediaInfoCompleteCallback = completeCallback;
  }

  /// Creates a [MediaInformationSession] from a custom ffprobe [command].
  ///
  /// [command] is prefixed with `-v error -hide_banner` before being sent to
  /// the native layer.
  MediaInformationSession(
    String command, {
    MediaInformationSessionCompleteCallback? completeCallback,
    this._timeout = 500,
  }) : super.internal() {
    FFmpegKitExtended.requireInitialized();
    final finalCommand = '$_defaultCommandPrefix $command';
    this.command = finalCommand;

    try {
      final ownedHandle = ffmpegKitBackend.createMediaInformationSession(
        finalCommand,
      );
      adoptOwnedHandle(
        ownedHandle,
        readSessionId: ffmpegKitBackend.getSessionId,
      );
    } catch (e, st) {
      log(
        'MediaInformationSession: error creating session $finalCommand',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    _mediaInfoCompleteCallback = completeCallback;
    if (completeCallback != null) {
      ensureRegisteredForSinkDemand();
    }
  }

  // ---------------------------------------------------------------------------
  // Named constructors
  // ---------------------------------------------------------------------------

  /// Creates a [MediaInformationSession] from individual ffprobe [arguments].
  ///
  /// The default `-v error -hide_banner` arguments are prepended. Each supplied
  /// argument is passed to the native layer verbatim, so callers do not need to
  /// quote or escape whitespace or literal quote characters inside values.
  MediaInformationSession.fromArguments(
    List<String> arguments, {
    MediaInformationSessionCompleteCallback? completeCallback,
    this._timeout = 500,
  }) : super.internal() {
    FFmpegKitExtended.requireInitialized();
    final finalArguments = <String>[
      ..._defaultCommandPrefixArguments,
      ...arguments,
    ];
    command = finalArguments.join(' ');

    try {
      final ownedHandle = ffmpegKitBackend
          .createMediaInformationSessionFromArguments(finalArguments);
      adoptOwnedHandle(
        ownedHandle,
        readSessionId: ffmpegKitBackend.getSessionId,
      );
    } catch (e, st) {
      log(
        'MediaInformationSession.fromArguments: error getting session id '
        'for ffmpeg_kit_session_get_session_id $command',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    _mediaInfoCompleteCallback = completeCallback;
    if (completeCallback != null) {
      ensureRegisteredForSinkDemand();
    }
  }

  /// Restores a [MediaInformationSession] from a native [handle].
  MediaInformationSession.fromHandle(Object handle, String command)
    : _timeout = 500,
      super.internal() {
    FFmpegKitExtended.requireInitialized();
    final ownedHandle = handle is SessionHandle
        ? handle
        : SessionHandle(handle);
    this.command = command;

    try {
      adoptOwnedHandle(
        ownedHandle,
        readSessionId: ffmpegKitBackend.getSessionId,
        restoredSession: true,
      );
    } catch (e, st) {
      log(
        'MediaInformationSession.fromHandle: error getting session id for ffmpeg_kit_session_get_session_id $command',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    // No callback registration: restored sessions have no active callbacks.
  }

  /// Creates a [MediaInformationSession] for a local [file].
  ///
  /// The file path is passed as one native argument, so whitespace and literal
  /// quote characters in the filename require no caller-side escaping.
  factory MediaInformationSession.fromFile(
    Object file, {
    MediaInformationSessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) {
    final path = file is String ? file : (file as dynamic).path as String;
    return MediaInformationSession.fromArguments(
      [..._defaultMediaInformationArguments, path],
      completeCallback: completeCallback,
      timeout: timeout,
    );
  }

  /// Creates a [MediaInformationSession] for a network [uri].
  ///
  /// The URI is passed as one native argument and is not reparsed as command
  /// text.
  factory MediaInformationSession.fromUri(
    Uri uri, {
    MediaInformationSessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) => MediaInformationSession.fromArguments(
    [..._defaultMediaInformationArguments, uri.toString()],
    completeCallback: completeCallback,
    timeout: timeout,
  );

  // ---------------------------------------------------------------------------
  // Static factories
  // ---------------------------------------------------------------------------

  /// Creates a [MediaInformationSession] from a file path or URI string.
  static MediaInformationSession fromPath(
    String path, {
    MediaInformationSessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) {
    if (_hasUriScheme(path)) {
      return MediaInformationSession.fromUri(
        Uri.parse(path),
        completeCallback: completeCallback,
        timeout: timeout,
      );
    }
    return MediaInformationSession.fromFile(
      path,
      completeCallback: completeCallback,
      timeout: timeout,
    );
  }

  /// Returns `true` when [path] appears to contain an explicit URI scheme
  /// (e.g. `http://`, `rtmp://`, `file://`).
  static bool _hasUriScheme(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null) return false;
    return uri.hasScheme &&
        const {
          'http',
          'https',
          'rtmp',
          'rtsp',
          'ftp',
          'file',
        }.contains(uri.scheme.toLowerCase());
  }

  /// Equivalent to [MediaInformationSession.new].
  static MediaInformationSession create(
    String command, {
    MediaInformationSessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) => MediaInformationSession(
    command,
    timeout: timeout,
    completeCallback: completeCallback,
  );

  /// Creates a session from individual ffprobe [arguments].
  static MediaInformationSession createWithArguments(
    List<String> arguments, {
    MediaInformationSessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) => MediaInformationSession.fromArguments(
    arguments,
    timeout: timeout,
    completeCallback: completeCallback,
  );

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  /// Executes this session synchronously and returns only after native work and
  /// cleanup have completed. Backend failures are rethrown after cleanup.
  @override
  MediaInformationSession execute() {
    claimExecutionSubmission();
    requireInitializedForExecution();
    ensureRegistered();

    Object? primaryError;
    StackTrace? primaryStackTrace;
    void recordCleanupFailure(Object error, StackTrace stackTrace) {
      if (primaryError == null) {
        primaryError = error;
        primaryStackTrace = stackTrace;
      } else {
        log(
          'MediaInformationSession.execute: cleanup failed after primary error for session $sessionId',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    try {
      enableNativeLogCallback();
      configureSynchronousNativeCallbacks();
      markExecutionStarted();
      executeSynchronously();
      dispatchPendingLogs();
      CallbackManager().dispatchMediaInformationComplete(sessionId);
    } catch (error, stackTrace) {
      primaryError = error;
      primaryStackTrace = stackTrace;
      log(
        'MediaInformationSession.execute: synchronous execution failed for session $sessionId',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      try {
        closeLogStreams();
      } catch (error, stackTrace) {
        recordCleanupFailure(error, stackTrace);
      }
      try {
        unregister();
      } catch (error, stackTrace) {
        recordCleanupFailure(error, stackTrace);
      } finally {
        markExecutionSettled();
      }
    }

    if (primaryError != null) {
      Error.throwWithStackTrace(primaryError!, primaryStackTrace!);
    }
    return this;
  }

  /// Creates and executes a session synchronously.
  static MediaInformationSession executeCommand(
    String command, {
    MediaInformationSessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) => MediaInformationSession.create(
    command,
    timeout: timeout,
    completeCallback: completeCallback,
  ).execute();

  /// Executes this session asynchronously and returns a [Future] that
  /// resolves when information retrieval finishes.
  @override
  Future<MediaInformationSession> executeAsync({
    FFprobeSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
  }) async {
    claimExecutionSubmission();
    // Accept the base-class typed callback for call-site compatibility;
    // wrap it into the correct MediaInformation type.
    if (completeCallback != null) {
      _mediaInfoCompleteCallback = (s) => completeCallback(s);
    }
    if (logCallback != null) {
      setLogCallback(logCallback);
    }
    ensureRegistered();

    await SessionQueueManager().executeSession(this, _runAsyncMediaInfo);
    return this;
  }

  // ---------------------------------------------------------------------------
  // Media information extraction
  // ---------------------------------------------------------------------------

  /// Retrieves the [MediaInformation] parsed from the ffprobe output.
  ///
  /// Returns `null` if the session has not completed or the output could not
  /// be parsed.
  @override
  MediaInformation? getMediaInformation() {
    FFmpegKitExtended.requireInitialized();
    final snapshot = ffmpegKitBackend.getMediaInformation(handle);
    if (snapshot == null) return null;
    return MediaInformation(
      filename: snapshot.filename,
      format: snapshot.format,
      longFormat: snapshot.longFormat,
      duration: snapshot.duration,
      startTime: snapshot.startTime,
      bitrate: snapshot.bitrate,
      size: snapshot.size,
      tagsJson: snapshot.tagsJson,
      allPropertiesJson: snapshot.allPropertiesJson,
      streams: snapshot.streams
          .map(
            (stream) => StreamInformation(
              index: stream.index,
              type: stream.type,
              codec: stream.codec,
              codecLong: stream.codecLong,
              format: stream.format,
              width: stream.width,
              height: stream.height,
              bitrate: stream.bitrate,
              sampleRate: stream.sampleRate,
              sampleFormat: stream.sampleFormat,
              channelLayout: stream.channelLayout,
              sampleAspectRatio: stream.sampleAspectRatio,
              displayAspectRatio: stream.displayAspectRatio,
              averageFrameRate: stream.averageFrameRate,
              realFrameRate: stream.realFrameRate,
              timeBase: stream.timeBase,
              codecTimeBase: stream.codecTimeBase,
              tagsJson: stream.tagsJson,
              allPropertiesJson: stream.allPropertiesJson,
            ),
          )
          .toList(),
      chapters: snapshot.chapters
          .map(
            (chapter) => ChapterInformation(
              id: chapter.id,
              timeBase: chapter.timeBase,
              start: chapter.start,
              startTime: chapter.startTime,
              end: chapter.end,
              endTime: chapter.endTime,
              tagsJson: chapter.tagsJson,
              allPropertiesJson: chapter.allPropertiesJson,
            ),
          )
          .toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Session type identity
  // ---------------------------------------------------------------------------

  /// Returns true if this is an FFmpeg session.
  @override
  bool isFFmpegSession() => false;

  /// Returns true if this is an FFplay session.
  @override
  bool isFFplaySession() => false;

  /// Returns true if this is an FFprobe session.
  @override
  bool isFFprobeSession() => false;

  /// Returns true if this is a media information session.
  @override
  bool isMediaInformationSession() => true;

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Configures the media-information completion callback for sync execution.
  @override
  @protected
  void configureSynchronousNativeCallbacks() {
    // Synchronous completion is dispatched by the blocking return path and
    // does not need a process-global native completion callback.
  }

  @override
  @protected
  CallbackBridgeKind get completionBridgeKind =>
      CallbackBridgeKind.mediaInformationCompletion;

  /// Invokes the blocking media-information backend operation.
  @override
  @protected
  void executeSynchronously() {
    ffmpegKitBackend.executeMediaInformationSession(handle, _timeout);
  }

  /// Executes this session asynchronously and invokes the complete callback when done.
  Future<void> _runAsyncMediaInfo() async {
    FFmpegKitExtended.requireInitialized();
    final sessionCompleter = Completer<void>();
    trackExecution(sessionCompleter);
    final userCb = _mediaInfoCompleteCallback;

    var completionHandled = false;
    void handleExecutionError(Object error, StackTrace stackTrace) {
      if (completionHandled) return;
      completionHandled = true;
      clearExecutionErrorHandler();
      _mediaInfoCompleteCallback = userCb;
      completeExecutionWithError(
        completer: sessionCompleter,
        error: error,
        stackTrace: stackTrace,
        cleanup: () {
          try {
            closeLogStreams();
          } finally {
            try {
              unregister();
            } finally {
              releaseAllBridgeLeases();
            }
          }
        },
      );
    }

    registerExecutionErrorHandler(handleExecutionError);
    _mediaInfoCompleteCallback = (MediaInformationSession s) {
      if (completionHandled) return;
      completionHandled = true;
      clearExecutionErrorHandler();

      try {
        if (hasLogDemand) dispatchPendingLogs();
      } catch (e, st) {
        log(
          'MediaInformationSession: error flushing logs for session $sessionId',
          error: e,
          stackTrace: st,
        );
      } finally {
        // Restore and unregister before calling user code or completing the
        // future, so the session is fully settled from any observer's
        // perspective.
        _mediaInfoCompleteCallback = userCb;
        try {
          closeLogStreams();
        } finally {
          try {
            unregister();
          } finally {
            releaseAllBridgeLeases();
            CallbackManager().invokeSafely(
              'Media-information completion callback',
              sessionId,
              () => userCb?.call(s),
            );
            // Complete last — callback failures are reported separately and
            // never prevent the execution future from settling.
            if (!sessionCompleter.isCompleted) sessionCompleter.complete();
          }
        }
      }
    };

    try {
      acquireExecutionBridgeLeases();
      ffmpegKitBackend.executeMediaInformationSessionAsync(handle, _timeout);
    } catch (e, st) {
      log(
        'MediaInformationSession: error starting async session for media_information_session_execute_async '
        '$sessionId',
        error: e,
        stackTrace: st,
      );
      clearExecutionErrorHandler();
      _mediaInfoCompleteCallback = userCb;
      closeLogStreams();
      try {
        unregister();
      } finally {
        releaseAllBridgeLeases();
      }
      if (!sessionCompleter.isCompleted) sessionCompleter.complete();
      rethrow;
    }

    await awaitMediaInformationExecution(sessionCompleter.future, sessionId);
    // No post-await restore needed — already done inside the callback above.
  }

  @override
  void onDispose() {
    _mediaInfoCompleteCallback = null;
    super.onDispose();
  }

  @override
  @protected
  void onCancelledBeforeStart() {
    closeLogStreams();
    unregister();
  }

  /// Routes registration through [CallbackManager.registerMediaInformationSession]
  /// so the session lands in both the media-information and ffprobe maps.
  ///
  /// Overrides [FFprobeSession.ensureRegistered] to keep the inherited
  /// `_registered` flag and both maps in sync.
  @override
  @protected
  void ensureRegistered() {
    if (isDisposed) return;
    if (isRegistered) return;
    CallbackManager().registerMediaInformationSession(this);
    markRegistered(true);
  }

  /// Routes unregistration through
  /// [CallbackManager.unregisterMediaInformationSession] so both maps are
  /// cleaned regardless of which inherited path (log callback removal, complete
  /// callback removal, async completion) triggered it.
  @override
  @protected
  void unregister() {
    if (!isRegistered) return;
    markRegistered(false);
    CallbackManager().unregisterMediaInformationSession(sessionId);
  }

  /// Unregisters this session only if no complete callback or log-delivery
  /// sink (log callback / batch stream listener) remains attached.
  @override
  @protected
  void unregisterIfIdle() {
    if (_mediaInfoCompleteCallback == null &&
        !hasActiveLogDelivery &&
        !hasPendingExecutionRouting) {
      unregister();
    }
  }
}
