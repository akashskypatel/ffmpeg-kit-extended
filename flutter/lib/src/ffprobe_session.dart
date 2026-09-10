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

/// A session for executing FFprobe commands.
///
/// Use this class to retrieve media metadata and stream information.
class FFprobeSession extends Session {
  FFprobeSessionCompleteCallback? _completeCallback;
  FFmpegLogCallback? _logCallback;
  StreamController<List<Log>>? _logBatchStreamController;
  Stream<Log>? _logStream;

  bool _registered = false;

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Creates a new [FFprobeSession] for [command].
  ///
  /// - [completeCallback]: Invoked once when the command finishes.
  FFprobeSession(
    String command, {
    FFprobeSessionCompleteCallback? completeCallback,
  }) {
    FFmpegKitExtended.requireInitialized();
    try {
      handle = ffmpegKitBackend.createFFprobeSession(command);
      this.command = command;
      sessionId = ffmpegKitBackend.getSessionId(handle);
      registerFinalizer();
    } catch (e, st) {
      log(
        'FFprobeSession: error creating session $command',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    _completeCallback = completeCallback;
    CallbackManager().registerFFprobeSession(this);
    _registered = true;
  }

  /// Restores an [FFprobeSession] from an existing native [handle].
  ///
  /// Used internally when wrapping handles from the session-history API.
  FFprobeSession.fromHandle(Object handle, String command) {
    FFmpegKitExtended.requireInitialized();
    this.handle = handle is SessionHandle ? handle : SessionHandle(handle);
    this.command = command;
    sessionId = ffmpegKitBackend.getSessionId(this.handle);
    registerFinalizer();
  }

  /// Internal constructor used exclusively by [MediaInformationSession].
  ///
  /// Leaves [handle], [sessionId], and [command] uninitialised; the subclass
  /// constructor is responsible for filling them in before any method is called.
  FFprobeSession.internal() : super();

  // ---------------------------------------------------------------------------
  // Static helpers
  // ---------------------------------------------------------------------------

  /// Equivalent to [FFprobeSession.new].
  static FFprobeSession create(
    String command, {
    FFprobeSessionCompleteCallback? completeCallback,
  }) => FFprobeSession(command, completeCallback: completeCallback);

  // ---------------------------------------------------------------------------
  // Callback accessors / mutators
  // ---------------------------------------------------------------------------

  /// The callback invoked once when execution completes.
  FFprobeSessionCompleteCallback? get completeCallback => _completeCallback;

  /// The callback invoked for each log line produced by FFprobe.
  FFmpegLogCallback? get logCallback => _logCallback;

  /// A batched stream of buffered logs drained from the native session.
  Stream<List<Log>> get logBatchStream {
    final controller = _logBatchStreamController ??=
        StreamController<List<Log>>.broadcast(
          onListen: () {
            _ensureRegistered();
            dispatchPendingLogs();
          },
        );
    return controller.stream;
  }

  /// A per-log view over [logBatchStream].
  Stream<Log> get logStream =>
      _logStream ??= logBatchStream.expand((batch) => batch);

  /// Sets or replaces the completion callback.
  void setCompleteCallback(FFprobeSessionCompleteCallback? completeCallback) {
    _completeCallback = completeCallback;
    _ensureRegistered();
  }

  /// Sets or replaces the log callback.
  void setLogCallback(FFmpegLogCallback? logCallback) {
    _logCallback = logCallback;
    _ensureRegistered();
  }

  /// Clears the completion callback and unregisters from [CallbackManager].
  void removeCompleteCallback() {
    _completeCallback = null;
    _unregisterIfIdle();
  }

  /// Clears the log callback.
  void removeLogCallback() {
    _logCallback = null;
    _unregisterIfIdle();
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  /// Enqueues this session for synchronous native execution and returns `this`
  /// immediately (fire-and-forget).
  FFprobeSession execute() {
    SessionQueueManager()
        .executeSession(this, () async {
          FFmpegKitExtended.requireInitialized();
          enableNativeLogCallback();
          try {
            ffmpegKitBackend.executeFFprobeSession(handle);
          } catch (e, st) {
            log(
              'FFprobeSession.execute: error executing session ffprobe_kit_session_execute $command',
              error: e,
              stackTrace: st,
            );
            rethrow;
          }
          dispatchPendingLogs();
          CallbackManager().invokeSafely(
            'FFprobe completion callback',
            sessionId,
            () => _completeCallback?.call(this),
          );
          closeLogStreams();
          _unregister();
        })
        .catchError((Object e, StackTrace st) {
          log('FFprobeSession.execute: queue error: $e\n$st');
        });
    return this;
  }

  /// Creates and enqueues a session for synchronous execution.
  static FFprobeSession executeCommand(
    String command, {
    FFprobeSessionCompleteCallback? completeCallback,
  }) => FFprobeSession.create(
    command,
    completeCallback: completeCallback,
  ).execute();

  /// Creates and executes a session asynchronously.
  static Future<FFprobeSession> executeCommandAsync(
    String command, {
    FFprobeSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
  }) => FFprobeSession.create(
    command,
    completeCallback: completeCallback,
  ).executeAsync(logCallback: logCallback);

  /// Executes this session asynchronously and returns a [Future] that
  /// resolves when execution finishes.
  Future<FFprobeSession> executeAsync({
    FFprobeSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
  }) async {
    if (completeCallback != null) _completeCallback = completeCallback;
    if (logCallback != null) _logCallback = logCallback;
    _ensureRegistered();

    await SessionQueueManager().executeSession(this, _runAsync);
    return this;
  }

  // ---------------------------------------------------------------------------
  // Media information
  // ---------------------------------------------------------------------------

  /// Returns [MediaInformation] if this is a [MediaInformationSession].
  ///
  /// Always returns `null` for plain [FFprobeSession] instances.
  MediaInformation? getMediaInformation() => null;

  /// Creates a [MediaInformationSession] for [path].
  static MediaInformationSession createMediaInformationSession(String path) =>
      MediaInformationSession.fromPath(path);

  /// Creates a [MediaInformationSession] for [path] with an optional callback.
  ///
  /// Note: the returned session is not yet executed; call [executeAsync] on it.
  static MediaInformationSession createMediaInformationSessionAsync(
    String path, {
    MediaInformationSessionCompleteCallback? onComplete,
  }) => MediaInformationSession.fromPath(path, completeCallback: onComplete);

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
  bool isFFprobeSession() => true;

  /// Returns true if this is a media information session.
  @override
  bool isMediaInformationSession() => false;

  // ---------------------------------------------------------------------------
  // Private implementation
  // ---------------------------------------------------------------------------

  /// Core async execution body, called by [executeAsync] through the queue.
  Future<void> _runAsync() async {
    FFmpegKitExtended.requireInitialized();
    final sessionCompleter = Completer<void>();
    trackExecution(sessionCompleter);
    final userCompleteCallback = _completeCallback;

    var completionHandled = false;
    void handleExecutionError(Object error, StackTrace stackTrace) {
      if (completionHandled) return;
      completionHandled = true;
      clearExecutionErrorHandler();
      _completeCallback = userCompleteCallback;
      completeExecutionWithError(
        completer: sessionCompleter,
        error: error,
        stackTrace: stackTrace,
        cleanup: () {
          try {
            closeLogStreams();
          } finally {
            _unregister();
          }
        },
      );
    }

    registerExecutionErrorHandler(handleExecutionError);
    _completeCallback = (FFprobeSession s) {
      if (completionHandled) return;
      completionHandled = true;
      clearExecutionErrorHandler();

      try {
        dispatchPendingLogs();
      } catch (e, st) {
        log(
          'FFprobeSession: error flushing logs for session $sessionId',
          error: e,
          stackTrace: st,
        );
      } finally {
        // Restore and unregister before calling user code or completing the
        // future, so the session is fully settled from any observer's
        // perspective.
        _completeCallback = userCompleteCallback;
        try {
          closeLogStreams();
        } finally {
          try {
            _unregister();
          } finally {
            CallbackManager().invokeSafely(
              'FFprobe completion callback',
              sessionId,
              () => userCompleteCallback?.call(s),
            );
            // Complete last — callback failures are reported separately and
            // never prevent the execution future from settling.
            if (!sessionCompleter.isCompleted) sessionCompleter.complete();
          }
        }
      }
    };
    try {
      enableNativeLogCallback();
      ffmpegKitBackend.configureFFprobeCallbacks();
      ffmpegKitBackend.executeFFprobeSessionAsync(handle);
    } catch (e, st) {
      log(
        'FFprobeSession: error starting async session $sessionId',
        error: e,
        stackTrace: st,
      );
      clearExecutionErrorHandler();
      _completeCallback = userCompleteCallback;
      closeLogStreams();
      _unregister();
      if (!sessionCompleter.isCompleted) sessionCompleter.complete();
      rethrow;
    }

    try {
      await sessionCompleter.future;
    } catch (e, st) {
      log('FFprobeSession: error awaiting session $sessionId: $e\n$st');
      rethrow;
    }
    // No post-await restore needed — already done inside the callback above.
  }

  /// Ensures this session is registered with the callback manager.
  ///
  /// Exposed as protected so subclasses (e.g. [MediaInformationSession]) can
  /// route registration through the correct [CallbackManager] map.
  @protected
  void ensureRegistered() {
    if (isDisposed) return;
    if (_registered) return;
    CallbackManager().registerFFprobeSession(this);
    _registered = true;
  }

  /// Backwards-compatible alias used throughout this file.
  void _ensureRegistered() => ensureRegistered();

  /// Whether this session is currently registered with the [CallbackManager].
  ///
  /// Exposed as protected so subclasses can override [ensureRegistered] /
  /// [unregister] while keeping a single source of truth for the flag.
  @protected
  bool get isRegistered => _registered;

  /// Updates the registration flag from a subclass override.
  @protected
  void markRegistered(bool value) {
    _registered = value;
  }

  @override
  void onLogsDispatched(List<Log> batch) {
    if (batch.isEmpty) {
      return;
    }

    final controller = _logBatchStreamController;
    if (controller != null && !controller.isClosed && controller.hasListener) {
      controller.add(batch);
    }

    for (final logObj in batch) {
      CallbackManager().invokeSafely(
        'FFprobe global log callback',
        sessionId,
        () => CallbackManager().globalLogCallback?.call(logObj),
      );
      CallbackManager().invokeSafely(
        'FFprobe session log callback',
        sessionId,
        () => _logCallback?.call(logObj),
      );
    }
  }

  /// Enables the native FFmpeg log callback for this session.
  ///
  /// Exposed as protected so that subclasses (e.g. [MediaInformationSession])
  /// in other library files can wire log delivery into their own execution
  /// paths.
  @protected
  void enableNativeLogCallback() {
    try {
      ffmpegKitBackend.enableFFprobeLogCallback();
    } catch (e, st) {
      log(
        'FFprobeSession: error enabling ffmpeg log callback for session $sessionId',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Closes any open log stream controllers for this session.
  ///
  /// Exposed as protected for subclass use.
  @protected
  void closeLogStreams() {
    final controller = _logBatchStreamController;
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
  }

  @override
  void onDispose() {
    _completeCallback = null;
    _logCallback = null;
    closeLogStreams();
    unregister();
  }

  /// Returns `true` while any log-delivery sink (callback or batch stream
  /// listener) is still attached to this session.
  ///
  /// Exposed as protected so subclasses that maintain their own complete
  /// callback (e.g. [MediaInformationSession]) can implement an idle check
  /// that considers inherited log-delivery state.
  @protected
  bool get hasActiveLogDelivery =>
      _logCallback != null || (_logBatchStreamController?.hasListener ?? false);

  /// Unregisters this session from the callback manager.
  ///
  /// Exposed as protected so subclasses can route unregistration through the
  /// correct [CallbackManager] map.
  @protected
  void unregister() {
    if (!_registered) return;
    _registered = false;
    CallbackManager().unregisterFFprobeSession(sessionId);
  }

  /// Backwards-compatible alias used throughout this file.
  void _unregister() => unregister();

  void _unregisterIfIdle() {
    if (_completeCallback == null &&
        _logCallback == null &&
        !(_logBatchStreamController?.hasListener ?? false)) {
      _unregister();
    }
  }
}
