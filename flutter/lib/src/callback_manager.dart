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

import 'dart:developer';
import 'dart:ffi';
import 'dart:io';

import '../ffmpeg_kit_extended_flutter.dart';
import 'generated/ffmpeg_kit_bindings.dart';

/// Native callback function types for FFmpegKit
typedef FFmpegKitCompleteCallbackFunction =
    Void Function(FFmpegSessionHandle, Pointer<Void>);

/// Native callback function types for FFprobeKit
typedef FFprobeKitCompleteCallbackFunction =
    Void Function(FFprobeSessionHandle, Pointer<Void>);

/// Native callback function types for FFplayKit
typedef FFplayKitCompleteCallbackFunction =
    Void Function(FFplaySessionHandle, Pointer<Void>);

/// Native callback function types for MediaInformationSession
typedef MediaInformationSessionCompleteCallbackFunction =
    Void Function(MediaInformationSessionHandle, Pointer<Void>);

/// Native callback function types for FFmpegKit log callback
typedef FFmpegKitLogCallbackFunction =
    Void Function(FFmpegSessionHandle, Pointer<Char>, Pointer<Void>);

/// Native callback function types for FFmpegKit statistics callback
typedef FFmpegKitStatisticsCallbackFunction =
    Void Function(
      FFmpegSessionHandle,
      Int64,
      Int64,
      Double,
      Double,
      Int64,
      Double,
      Double,
      Pointer<Void>,
    );

// ---------------------------------------------------------------------------
// Dart-side callback typedefs (user-facing)
// ---------------------------------------------------------------------------

/// Callback for [FFmpegSession] completion.
typedef FFmpegSessionCompleteCallback = void Function(FFmpegSession session);

/// Callback for processing log messages.
typedef FFmpegLogCallback = void Function(Log log);

/// Callback for session [Statistics] updates.
typedef FFmpegStatisticsCallback = void Function(Statistics statistics);

/// Callback for [FFprobeSession] completion.
typedef FFprobeSessionCompleteCallback = void Function(FFprobeSession session);

/// Callback for [FFplaySession] completion.
typedef FFplaySessionCompleteCallback = void Function(FFplaySession session);

/// Callback for [MediaInformationSession] completion.
typedef MediaInformationSessionCompleteCallback =
    void Function(MediaInformationSession session);

// ---------------------------------------------------------------------------
// Native → Dart bridge functions
// ---------------------------------------------------------------------------

/// Handles the completion of an FFmpeg session.
///
/// [sessionHandle] is the native session handle; its session ID is resolved
/// through the C API.  [userData] is always nullptr (see [CallbackManager]).
void _onFFmpegComplete(
  FFmpegSessionHandle sessionHandle,
  Pointer<Void> userData,
) {
  FFmpegKitExtended.requireInitialized();
  final sessionId = _safeGetSessionId(sessionHandle, '_onFFmpegComplete');
  log('CallbackManager: _onFFmpegComplete sessionId=$sessionId');

  final session = sessionId > 0
      ? CallbackManager().ffmpegSessions[sessionId]
      : null;

  if (session != null) {
    log('CallbackManager: invoking completeCallback for session $sessionId');
    try {
      session.completeCallback?.call(session);
      CallbackManager().globalFFmpegSessionCompleteCallback?.call(session);
    } catch (e, st) {
      log(
        'CallbackManager: error in completeCallback for session $sessionId: '
        '$e\n$st',
      );
    }
  } else {
    stderr.writeln(
      'Warning: _onFFmpegComplete — no session found for sessionId=$sessionId',
    );
  }
  // The Dart FFmpegSession owns this handle via its NativeFinalizer; do NOT
  // call ffmpeg_kit_handle_release here.
}

/// Handles a log notification from an FFmpeg session.
void _onFFmpegLog(
  FFmpegSessionHandle sessionHandle,
  Pointer<Char> logPtr,
  Pointer<Void> userData,
) {
  if (logPtr == nullptr) return;

  final sessionId = _safeGetSessionId(sessionHandle, '_onFFmpegLog');
  final session = sessionId > 0
      ? CallbackManager().ffmpegSessions[sessionId]
      : null;

  if (session != null) {
    // Poll the session's buffered log entries since the last delivery.
    final count = session.getLogsCount();
    for (int i = session.logsProcessed; i < count; i++) {
      final message = session.getLogAt(i);
      final level = session.getLogLevelAt(i);
      final logObj = Log(session.sessionId, level, message);
      CallbackManager().globalLogCallback?.call(logObj);
      session.logCallback?.call(logObj);
    }
    session.logsProcessed = count;
  }
  // If no session is found there is nothing to route. Do NOT print a warning
  // here — this callback can legally fire for global log redirection where no
  // specific session is registered.

  // DO NOT free logPtr — it is owned by the C layer.
}

/// Handles statistics from an FFmpeg session.
void _onFFmpegStatistics(
  FFmpegSessionHandle sessionHandle,
  int time,
  int size,
  double bitrate,
  double speed,
  int videoFrameNumber,
  double videoFps,
  double videoQuality,
  Pointer<Void> userData,
) {
  // Resolve session ID reliably through the C API.
  final sessionId = _safeGetSessionId(sessionHandle, '_onFFmpegStatistics');

  final stats = Statistics(
    sessionId,
    time,
    size,
    bitrate,
    speed,
    videoFrameNumber,
    videoFps,
    videoQuality,
  );

  CallbackManager().globalStatisticsCallback?.call(stats);

  final session = sessionId > 0
      ? CallbackManager().ffmpegSessions[sessionId]
      : null;

  if (session != null) {
    session.statisticsCallback?.call(stats);
  } else {
    stderr.writeln(
      'Warning: _onFFmpegStatistics — no session found for '
      'sessionId=$sessionId '
      'userData=0x${userData.address.toRadixString(16)}',
    );
  }
}

/// Handles the completion of an FFprobe session.
void _onFFprobeComplete(
  FFprobeSessionHandle sessionHandle,
  Pointer<Void> userData,
) {
  FFmpegKitExtended.requireInitialized();
  final sessionId = _safeGetSessionId(sessionHandle, '_onFFprobeComplete');

  final session = sessionId > 0
      ? CallbackManager().ffprobeSessions[sessionId]
      : null;

  if (session != null) {
    try {
      if (session is MediaInformationSession) {
        session.completeCallback?.call(session);
        CallbackManager().globalMediaInformationSessionCompleteCallback?.call(
          session,
        );
      } else {
        session.completeCallback?.call(session);
        CallbackManager().globalFFprobeSessionCompleteCallback?.call(session);
      }
    } catch (e, st) {
      log(
        'CallbackManager: error in FFprobe completeCallback for session '
        '$sessionId: $e\n$st',
      );
    }
  } else {
    stderr.writeln(
      'Warning: _onFFprobeComplete — no session found for sessionId=$sessionId',
    );
  }
  // Do NOT release sessionHandle here — the Dart FFprobeSession owns it via
  // NativeFinalizer.  See _onFFmpegComplete for the full explanation.
}

/// Handles the completion of a MediaInformation session.
void _onMediaInfoComplete(
  MediaInformationSessionHandle sessionHandle,
  Pointer<Void> userData,
) {
  FFmpegKitExtended.requireInitialized();
  final sessionId = _safeGetSessionId(sessionHandle, '_onMediaInfoComplete');

  final session = sessionId > 0
      ? CallbackManager().mediaInformationSessions[sessionId]
      : null;

  if (session != null) {
    try {
      session.completeCallback?.call(session);
      CallbackManager().globalMediaInformationSessionCompleteCallback?.call(
        session,
      );
    } catch (e, st) {
      log(
        'CallbackManager: error in MediaInfo completeCallback for session '
        '$sessionId: $e\n$st',
      );
    }
  } else {
    stderr.writeln(
      'Warning: _onMediaInfoComplete — no session found for sessionId=$sessionId',
    );
  }
  // Do NOT release sessionHandle here — the Dart MediaInformationSession owns
  // it via NativeFinalizer.  See _onFFmpegComplete for the full explanation.
}

/// Handles the completion of an FFplay session.
void _onFFplayComplete(
  FFplaySessionHandle sessionHandle,
  Pointer<Void> userData,
) {
  FFmpegKitExtended.requireInitialized();
  final sessionId = _safeGetSessionId(sessionHandle, '_onFFplayComplete');

  final session = sessionId > 0
      ? CallbackManager().ffplaySessions[sessionId]
      : null;

  if (session != null) {
    try {
      session.completeCallback?.call(session);
      CallbackManager().globalFFplaySessionCompleteCallback?.call(session);
    } catch (e, st) {
      log(
        'CallbackManager: error in FFplay completeCallback for session '
        '$sessionId: $e\n$st',
      );
    }
  } else {
    stderr.writeln(
      'Warning: _onFFplayComplete — no session found for sessionId=$sessionId',
    );
  }
  // Do NOT release sessionHandle here — the Dart FFplaySession owns it via
  // NativeFinalizer.  See _onFFmpegComplete for the full explanation.
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Resolves a session ID from a native handle by calling the C API.
///
/// Returns 0 on failure and logs a diagnostic message to stderr.
int _safeGetSessionId(Pointer<Void> handle, String caller) {
  if (handle.address == 0) return 0;
  try {
    return FFmpegKitExtended.getSessionId(handle);
  } catch (e) {
    stderr.writeln(
      '$caller: failed to resolve session ID from handle '
      '(address=0x${handle.address.toRadixString(16)}): $e',
    );
    return 0;
  }
}

// ---------------------------------------------------------------------------
// Long-lived NativeCallable instances
//
// These must be top-level (or otherwise GC-rooted) so the Dart GC never
// collects them while native threads still hold the function pointers.
// ---------------------------------------------------------------------------

/// Native-callable for [_onFFmpegComplete]. Kept alive for the process
/// lifetime so the C layer can always invoke it safely.
final nativeFFmpegComplete =
    NativeCallable<FFmpegKitCompleteCallbackFunction>.listener(
      _onFFmpegComplete,
    );

/// Native-callable for [_onFFmpegLog].
final nativeFFmpegLog = NativeCallable<FFmpegKitLogCallbackFunction>.listener(
  _onFFmpegLog,
);

/// Native-callable for [_onFFmpegStatistics].
final nativeFFmpegStatistics =
    NativeCallable<FFmpegKitStatisticsCallbackFunction>.listener(
      _onFFmpegStatistics,
    );

/// Native-callable for [_onFFprobeComplete].
final nativeFFprobeComplete =
    NativeCallable<FFprobeKitCompleteCallbackFunction>.listener(
      _onFFprobeComplete,
    );

/// Native-callable for [_onMediaInfoComplete].
final nativeMediaInfoComplete =
    NativeCallable<MediaInformationSessionCompleteCallbackFunction>.listener(
      _onMediaInfoComplete,
    );

/// Native-callable for [_onFFplayComplete].
final nativeFFplayComplete =
    NativeCallable<FFplayKitCompleteCallbackFunction>.listener(
      _onFFplayComplete,
    );

// ---------------------------------------------------------------------------
// CallbackManager
// ---------------------------------------------------------------------------

/// Internal manager for bridging native-to-Dart callbacks.
///
/// Maintains maps of active sessions keyed by session ID (assigned by the C
/// layer).  Native callbacks receive `userData = nullptr`; session lookup
/// always uses the session ID resolved via the C API.
///
/// ### Thread safety
/// All mutations occur on the Dart isolate thread. [NativeCallable.listener]
/// posts native invocations onto the Dart event loop, so there is no
/// concurrent mutation risk for these maps.
class CallbackManager {
  static final _instance = CallbackManager._();
  CallbackManager._();

  /// Returns the singleton instance.
  factory CallbackManager() => _instance;

  // ---- Session-ID maps ----------------------------------------------------

  /// Active FFmpeg sessions indexed by C-layer session ID.
  final Map<int, FFmpegSession> ffmpegSessions = {};

  /// Active FFprobe sessions indexed by C-layer session ID.
  final Map<int, FFprobeSession> ffprobeSessions = {};

  /// Active FFplay sessions indexed by C-layer session ID.
  final Map<int, FFplaySession> ffplaySessions = {};

  /// Active MediaInformation sessions indexed by C-layer session ID.
  final Map<int, MediaInformationSession> mediaInformationSessions = {};

  // ---- Global callbacks ---------------------------------------------------

  /// Receives log events from all FFmpeg sessions.
  FFmpegLogCallback? globalLogCallback;

  /// Receives statistics from all FFmpeg sessions.
  FFmpegStatisticsCallback? globalStatisticsCallback;

  /// Fires on completion of any FFmpeg session.
  FFmpegSessionCompleteCallback? globalFFmpegSessionCompleteCallback;

  /// Fires on completion of any FFprobe session.
  FFprobeSessionCompleteCallback? globalFFprobeSessionCompleteCallback;

  /// Fires on completion of any FFplay session.
  FFplaySessionCompleteCallback? globalFFplaySessionCompleteCallback;

  /// Fires on completion of any MediaInformation session.
  MediaInformationSessionCompleteCallback?
  globalMediaInformationSessionCompleteCallback;

  // ---- Registration -------------------------------------------------------

  /// Registers [session] so native completion callbacks can locate it by ID.
  void registerFFmpegSession(FFmpegSession session) {
    ffmpegSessions[session.sessionId] = session;
  }

  /// Registers [session] so native completion callbacks can locate it by ID.
  void registerFFprobeSession(FFprobeSession session) {
    ffprobeSessions[session.sessionId] = session;
  }

  /// Registers [session] so native completion callbacks can locate it by ID.
  void registerFFplaySession(FFplaySession session) {
    ffplaySessions[session.sessionId] = session;
  }

  /// Registers [session] in both [mediaInformationSessions] and the
  /// [ffprobeSessions] mirror so [_onFFprobeComplete] can also find it.
  void registerMediaInformationSession(MediaInformationSession session) {
    mediaInformationSessions[session.sessionId] = session;
    ffprobeSessions[session.sessionId] = session;
  }

  // ---- Unregistration -----------------------------------------------------

  /// Removes the [FFmpegSession] with [sessionId] from all maps.
  void unregisterFFmpegSession(int sessionId) {
    ffmpegSessions.remove(sessionId);
  }

  /// Removes the [FFprobeSession] with [sessionId] from all maps.
  void unregisterFFprobeSession(int sessionId) {
    ffprobeSessions.remove(sessionId);
  }

  /// Removes the [FFplaySession] with [sessionId] from all maps.
  void unregisterFFplaySession(int sessionId) {
    ffplaySessions.remove(sessionId);
  }

  /// Removes the [MediaInformationSession] with [sessionId] from all maps,
  /// including the [ffprobeSessions] mirror.
  void unregisterMediaInformationSession(int sessionId) {
    mediaInformationSessions.remove(sessionId);
    ffprobeSessions.remove(sessionId);
  }
}
