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
typedef FFmpegKitCompleteCallbackFunction = Void Function(
    FFmpegSessionHandle, Pointer<Void>);

/// Native callback function types for FFprobeKit
typedef FFprobeKitCompleteCallbackFunction = Void Function(
    FFprobeSessionHandle, Pointer<Void>);

/// Native callback function types for FFplayKit
typedef FFplayKitCompleteCallbackFunction = Void Function(
    FFplaySessionHandle, Pointer<Void>);

/// Native callback function types for MediaInformationSession
typedef MediaInformationSessionCompleteCallbackFunction = Void Function(
    MediaInformationSessionHandle, Pointer<Void>);

/// Native callback function types for FFmpegKit log callback
typedef FFmpegKitLogCallbackFunction = Void Function(
    FFmpegSessionHandle, Pointer<Char>, Pointer<Void>);

/// Native callback function types for FFmpegKit statistics callback
typedef FFmpegKitStatisticsCallbackFunction = Void Function(FFmpegSessionHandle,
    Int64, Int64, Double, Double, Int64, Double, Double, Pointer<Void>);

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
typedef MediaInformationSessionCompleteCallback = void Function(
    MediaInformationSession session);

// ---------------------------------------------------------------------------
// Native → Dart bridge functions
// ---------------------------------------------------------------------------

/// Handles the completion of an FFmpeg session.
///
/// [sessionHandle] is the native session handle; its session ID is resolved
/// through the C API (never by treating the pointer address as an ID).
///
/// [userData] carries the [CallbackManager] callback ID that was passed when
/// the native callback was registered. This is the primary lookup key; the
/// session-ID map is a fallback for global (non-per-session) callbacks.
void _onFFmpegComplete(
    FFmpegSessionHandle sessionHandle, Pointer<Void> userData) {
  FFmpegKitExtended.requireInitialized();
  // Always resolve the session ID through the C API.
  final sessionId = _safeGetSessionId(sessionHandle, '_onFFmpegComplete');
  log('CallbackManager: _onFFmpegComplete sessionId=$sessionId '
      'userData=0x${userData.address.toRadixString(16)}');

  FFmpegSession? session;

  // Primary lookup: callbackId encoded in userData.
  if (userData != nullptr && userData.address != 0) {
    session = CallbackManager().getFFmpegSession(userData.address);
    log('CallbackManager: resolved session from userData: $session');
  }

  // Fallback: look up by session ID (covers global-callback-only scenarios).
  if (session == null && sessionId > 0) {
    session = CallbackManager().ffmpegSessions[sessionId];
  }

  if (session != null) {
    log('CallbackManager: invoking completeCallback for session $sessionId');
    try {
      session.completeCallback?.call(session);
    } catch (e, st) {
      log('CallbackManager: error in completeCallback for session $sessionId: '
          '$e\n$st');
    }
    CallbackManager().globalFFmpegSessionCompleteCallback?.call(session);
  } else {
    stderr.writeln('Warning: _onFFmpegComplete — no session found for '
        'sessionId=$sessionId '
        'userData=0x${userData.address.toRadixString(16)}');
  }

  // The Dart FFmpegSession owns this handle via its NativeFinalizer; do NOT
  // call ffmpeg_kit_handle_release here.  Releasing in the callback would
  // invalidate session.handle before any awaiter (await executeAsync, etc.)
  // can read state/return-code from it, producing use-after-free reads that
  // return 0 / SessionState.created.  The NativeFinalizer fires when the Dart
  // session object is GC-collected, which is the correct and sole release point.
  if (userData != nullptr && userData.address != 0) {
    CallbackManager().unregisterFFmpegSession(userData.address);
  }
}

/// Handles a log notification from an FFmpeg session.
void _onFFmpegLog(FFmpegSessionHandle sessionHandle, Pointer<Char> logPtr,
    Pointer<Void> userData) {
  // logPtr being null means no text — nothing to dispatch.
  if (logPtr == nullptr) return;

  // Resolve session ID reliably through the C API.
  final sessionId = _safeGetSessionId(sessionHandle, '_onFFmpegLog');

  // Primary lookup via userData callback ID.
  FFmpegSession? session;
  if (userData != nullptr && userData.address != 0) {
    session = CallbackManager().getFFmpegSession(userData.address);
  }

  // Fallback to session-ID map.
  if (session == null && sessionId > 0) {
    session = CallbackManager().ffmpegSessions[sessionId];
  }

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
    Pointer<Void> userData) {
  // Resolve session ID reliably through the C API.
  final sessionId = _safeGetSessionId(sessionHandle, '_onFFmpegStatistics');

  final stats = Statistics(sessionId, time, size, bitrate, speed,
      videoFrameNumber, videoFps, videoQuality);

  // Global callback fires unconditionally (no session required).
  CallbackManager().globalStatisticsCallback?.call(stats);

  // Per-session callback: primary lookup via userData, fallback via sessionId.
  FFmpegSession? session;
  if (userData != nullptr && userData.address != 0) {
    session = CallbackManager().getFFmpegSession(userData.address);
  }
  if (session == null && sessionId > 0) {
    session = CallbackManager().ffmpegSessions[sessionId];
  }

  if (session != null) {
    session.statisticsCallback?.call(stats);
  } else {
    stderr.writeln('Warning: _onFFmpegStatistics — no session found for '
        'sessionId=$sessionId '
        'userData=0x${userData.address.toRadixString(16)}');
  }
}

/// Handles the completion of an FFprobe session.
void _onFFprobeComplete(
    FFprobeSessionHandle sessionHandle, Pointer<Void> userData) {
  FFmpegKitExtended.requireInitialized();
  final sessionId = _safeGetSessionId(sessionHandle, '_onFFprobeComplete');

  FFprobeSession? session;
  if (userData != nullptr && userData.address != 0) {
    session = CallbackManager().getFFprobeSession(userData.address);
  }
  session ??= CallbackManager().ffprobeSessions[sessionId];

  if (session != null) {
    try {
      // FFprobeSession and MediaInformationSession are separate registrations
      // now, so the is-check here is a safety net rather than the primary path.
      if (session is MediaInformationSession) {
        session.completeCallback?.call(session);
        CallbackManager()
            .globalMediaInformationSessionCompleteCallback
            ?.call(session);
      } else {
        session.completeCallback?.call(session);
        CallbackManager().globalFFprobeSessionCompleteCallback?.call(session);
      }
    } catch (e, st) {
      log('CallbackManager: error in FFprobe completeCallback for session '
          '$sessionId: $e\n$st');
    }
  } else {
    stderr.writeln('Warning: _onFFprobeComplete — no session found for '
        'sessionId=$sessionId '
        'userData=0x${userData.address.toRadixString(16)}');
  }

  // Do NOT release sessionHandle here — the Dart FFprobeSession owns it via
  // NativeFinalizer.  See _onFFmpegComplete for the full explanation.
  if (userData != nullptr && userData.address != 0) {
    CallbackManager().unregisterFFprobeSession(userData.address);
  }
}

/// Handles the completion of a MediaInformation session.
void _onMediaInfoComplete(
    MediaInformationSessionHandle sessionHandle, Pointer<Void> userData) {
  FFmpegKitExtended.requireInitialized();
  final sessionId = _safeGetSessionId(sessionHandle, '_onMediaInfoComplete');

  MediaInformationSession? session;
  if (userData != nullptr && userData.address != 0) {
    session = CallbackManager().getMediaInformationSession(userData.address);
  }
  session ??= CallbackManager().mediaInformationSessions[sessionId];

  if (session != null) {
    try {
      session.completeCallback?.call(session);
      CallbackManager()
          .globalMediaInformationSessionCompleteCallback
          ?.call(session);
    } catch (e, st) {
      log('CallbackManager: error in MediaInfo completeCallback for session '
          '$sessionId: $e\n$st');
    }
  } else {
    stderr.writeln('Warning: _onMediaInfoComplete — no session found for '
        'sessionId=$sessionId '
        'userData=0x${userData.address.toRadixString(16)}');
  }

  // Do NOT release sessionHandle here — the Dart MediaInformationSession owns
  // it via NativeFinalizer.  See _onFFmpegComplete for the full explanation.
  if (userData != nullptr && userData.address != 0) {
    CallbackManager().unregisterMediaInformationSession(userData.address);
  }
}

/// Handles the completion of an FFplay session.
void _onFFplayComplete(
    FFplaySessionHandle sessionHandle, Pointer<Void> userData) {
  FFmpegKitExtended.requireInitialized();
  final sessionId = _safeGetSessionId(sessionHandle, '_onFFplayComplete');

  FFplaySession? session;
  if (userData != nullptr && userData.address != 0) {
    session = CallbackManager().getFFplaySession(userData.address);
  }
  session ??= CallbackManager().ffplaySessions[sessionId];

  if (session != null) {
    try {
      session.completeCallback?.call(session);
      CallbackManager().globalFFplaySessionCompleteCallback?.call(session);
    } catch (e, st) {
      log('CallbackManager: error in FFplay completeCallback for session '
          '$sessionId: $e\n$st');
    }
  } else {
    stderr.writeln('Warning: _onFFplayComplete — no session found for '
        'sessionId=$sessionId '
        'userData=0x${userData.address.toRadixString(16)}');
  }

  // Do NOT release sessionHandle here — the Dart FFplaySession owns it via
  // NativeFinalizer.  See _onFFmpegComplete for the full explanation.
  if (userData != nullptr && userData.address != 0) {
    CallbackManager().unregisterFFplaySession(userData.address);
  }
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
    stderr.writeln('$caller: failed to resolve session ID from handle '
        '(address=0x${handle.address.toRadixString(16)}): $e');
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
        _onFFmpegComplete);

/// Native-callable for [_onFFmpegLog].
final nativeFFmpegLog =
    NativeCallable<FFmpegKitLogCallbackFunction>.listener(_onFFmpegLog);

/// Native-callable for [_onFFmpegStatistics].
final nativeFFmpegStatistics =
    NativeCallable<FFmpegKitStatisticsCallbackFunction>.listener(
        _onFFmpegStatistics);

/// Native-callable for [_onFFprobeComplete].
final nativeFFprobeComplete =
    NativeCallable<FFprobeKitCompleteCallbackFunction>.listener(
        _onFFprobeComplete);

/// Native-callable for [_onMediaInfoComplete].
final nativeMediaInfoComplete =
    NativeCallable<MediaInformationSessionCompleteCallbackFunction>.listener(
        _onMediaInfoComplete);

/// Native-callable for [_onFFplayComplete].
final nativeFFplayComplete =
    NativeCallable<FFplayKitCompleteCallbackFunction>.listener(
        _onFFplayComplete);

// ---------------------------------------------------------------------------
// CallbackManager
// ---------------------------------------------------------------------------

/// Internal manager for bridging native-to-Dart callbacks.
///
/// Maintains maps of active sessions keyed by:
///   - **session ID** — assigned by the C layer, stable for the session's
///     lifetime; used as a fallback lookup key.
///   - **callback ID** — a Dart-owned auto-increment integer assigned here
///     at registration time and passed as the `userData` void* to the C layer.
///     When the native callback fires, `userData.address` equals the callback
///     ID, enabling O(1) lookup without pointer arithmetic or heuristics.
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

  // ---- Session-ID maps (authoritative session store) ----------------------

  /// Active FFmpeg sessions indexed by C-layer session ID.
  final Map<int, FFmpegSession> ffmpegSessions = {};

  /// Active FFprobe sessions indexed by C-layer session ID.
  final Map<int, FFprobeSession> ffprobeSessions = {};

  /// Active FFplay sessions indexed by C-layer session ID.
  final Map<int, FFplaySession> ffplaySessions = {};

  /// Active MediaInformation sessions indexed by C-layer session ID.
  final Map<int, MediaInformationSession> mediaInformationSessions = {};

  // ---- Callback-ID maps (userData → session, fast path) ------------------

  /// Auto-incrementing counter. Starts at 1 so address 0 (nullptr) is invalid.
  int _nextCallbackId = 1;

  /// callback ID → session ID (used during type-specific unregistration).
  final Map<int, int> _callbackIdToSessionId = {};

  /// callback ID → FFmpegSession.
  final Map<int, FFmpegSession> _callbackIdToFFmpegSession = {};

  /// callback ID → FFprobeSession.
  final Map<int, FFprobeSession> _callbackIdToFFprobeSession = {};

  /// callback ID → FFplaySession.
  final Map<int, FFplaySession> _callbackIdToFFplaySession = {};

  /// callback ID → MediaInformationSession.
  final Map<int, MediaInformationSession> _callbackIdToMediaInformationSession =
      {};

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

  /// Registers [FFmpegSession] in all relevant maps and returns the callback ID.
  int registerFFmpegSession(FFmpegSession session) {
    final id = _nextCallbackId++;
    ffmpegSessions[session.sessionId] = session;
    _callbackIdToSessionId[id] = session.sessionId;
    _callbackIdToFFmpegSession[id] = session;
    return id;
  }

  /// Registers [FFprobeSession] and returns the callback ID for `userData`.
  int registerFFprobeSession(FFprobeSession session) {
    final id = _nextCallbackId++;
    ffprobeSessions[session.sessionId] = session;
    _callbackIdToSessionId[id] = session.sessionId;
    _callbackIdToFFprobeSession[id] = session;
    return id;
  }

  /// Registers [FFplaySession] and returns the callback ID for `userData`.
  int registerFFplaySession(FFplaySession session) {
    final id = _nextCallbackId++;
    ffplaySessions[session.sessionId] = session;
    _callbackIdToSessionId[id] = session.sessionId;
    _callbackIdToFFplaySession[id] = session;
    return id;
  }

  /// Registers [MediaInformationSession] and returns the callback ID for `userData`.
  ///
  /// [MediaInformationSession] extends [FFprobeSession], so the session is
  /// stored in both [mediaInformationSessions] and [ffprobeSessions] to
  /// support both lookup paths.
  int registerMediaInformationSession(MediaInformationSession session) {
    final id = _nextCallbackId++;
    mediaInformationSessions[session.sessionId] = session;
    ffprobeSessions[session.sessionId] = session; // mirror for fallback lookup
    _callbackIdToSessionId[id] = session.sessionId;
    _callbackIdToMediaInformationSession[id] = session;
    _callbackIdToFFprobeSession[id] = session; // mirror for fallback lookup
    return id;
  }

  // ---- Type-specific unregistration --------------------------------------

  /// Removes the [FFmpegSession] registration for [callbackId].
  void unregisterFFmpegSession(int callbackId) {
    _callbackIdToFFmpegSession.remove(callbackId);
    final sessionId = _callbackIdToSessionId.remove(callbackId);
    if (sessionId != null) {
      ffmpegSessions.remove(sessionId);
    }
  }

  /// Removes the [FFprobeSession] registration for [callbackId].
  ///
  /// If the session was a [MediaInformationSession], call
  /// [unregisterMediaInformationSession] instead so both mirror maps are
  /// cleaned up correctly.
  void unregisterFFprobeSession(int callbackId) {
    _callbackIdToFFprobeSession.remove(callbackId);
    final sessionId = _callbackIdToSessionId.remove(callbackId);
    if (sessionId != null) {
      ffprobeSessions.remove(sessionId);
    }
  }

  /// Removes the [FFplaySession] registration for [callbackId].
  void unregisterFFplaySession(int callbackId) {
    _callbackIdToFFplaySession.remove(callbackId);
    final sessionId = _callbackIdToSessionId.remove(callbackId);
    if (sessionId != null) {
      ffplaySessions.remove(sessionId);
    }
  }

  /// Removes the [MediaInformationSession] registration for [callbackId].
  ///
  /// Cleans up both [mediaInformationSessions] and the [ffprobeSessions]
  /// mirror entry that was created by [registerMediaInformationSession].
  void unregisterMediaInformationSession(int callbackId) {
    _callbackIdToMediaInformationSession.remove(callbackId);
    _callbackIdToFFprobeSession.remove(callbackId); // remove mirror
    final sessionId = _callbackIdToSessionId.remove(callbackId);
    if (sessionId != null) {
      mediaInformationSessions.remove(sessionId);
      ffprobeSessions.remove(sessionId); // remove mirror
    }
  }

  /// Removes all registrations for [callbackId] regardless of session type.
  ///
  /// Prefer the type-specific methods above. This is provided as a convenience
  /// for bulk-clear operations that do not know the session type.
  void unregisterAny(int callbackId) {
    _callbackIdToFFmpegSession.remove(callbackId);
    _callbackIdToFFprobeSession.remove(callbackId);
    _callbackIdToFFplaySession.remove(callbackId);
    _callbackIdToMediaInformationSession.remove(callbackId);
    final sessionId = _callbackIdToSessionId.remove(callbackId);
    if (sessionId != null) {
      ffmpegSessions.remove(sessionId);
      ffprobeSessions.remove(sessionId);
      ffplaySessions.remove(sessionId);
      mediaInformationSessions.remove(sessionId);
    }
  }

  // ---- Lookup (callback ID → session) ------------------------------------

  /// Returns the [FFmpegSession] for [callbackId], or `null`.
  FFmpegSession? getFFmpegSession(int callbackId) =>
      _callbackIdToFFmpegSession[callbackId] ??
      _bySessionId(callbackId, ffmpegSessions);

  /// Returns the [FFprobeSession] for [callbackId], or `null`.
  FFprobeSession? getFFprobeSession(int callbackId) =>
      _callbackIdToFFprobeSession[callbackId] ??
      _bySessionId(callbackId, ffprobeSessions);

  /// Returns the [FFplaySession] for [callbackId], or `null`.
  FFplaySession? getFFplaySession(int callbackId) =>
      _callbackIdToFFplaySession[callbackId] ??
      _bySessionId(callbackId, ffplaySessions);

  /// Returns the [MediaInformationSession] for [callbackId], or `null`.
  MediaInformationSession? getMediaInformationSession(int callbackId) =>
      _callbackIdToMediaInformationSession[callbackId] ??
      _bySessionId(callbackId, mediaInformationSessions);

  // ---- Private helpers ----------------------------------------------------

  /// Resolves callbackId → sessionId → session in [map].
  T? _bySessionId<T>(int callbackId, Map<int, T> map) {
    final sessionId = _callbackIdToSessionId[callbackId];
    if (sessionId == null) return null;
    return map[sessionId];
  }
}
