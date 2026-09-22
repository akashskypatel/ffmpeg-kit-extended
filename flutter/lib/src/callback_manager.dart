/*
 * FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
 * Copyright (C) 2026 Akash Patel
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 */

import 'dart:developer' as developer;

import 'ffmpeg_session.dart';
import 'ffplay_session.dart';
import 'ffprobe_session.dart';
import 'log.dart';
import 'media_information_session.dart';
import 'session.dart';
import 'statistics.dart';

typedef FFmpegSessionCompleteCallback = void Function(FFmpegSession session);
typedef FFmpegLogCallback = void Function(Log log);
typedef FFmpegStatisticsCallback = void Function(Statistics statistics);
typedef FFprobeSessionCompleteCallback = void Function(FFprobeSession session);
typedef FFplaySessionCompleteCallback = void Function(FFplaySession session);
typedef MediaInformationSessionCompleteCallback =
    void Function(MediaInformationSession session);

/// Process-global native callback bridges that can be leased by sessions or
/// global consumers.
enum CallbackBridgeKind {
  log,
  statistics,
  ffmpegCompletion,
  ffprobeCompletion,
  ffplayCompletion,
  mediaInformationCompletion,
}

/// An idempotent lease on one process-global callback bridge.
final class CallbackBridgeLease {
  CallbackBridgeLease._(this._release);

  final void Function() _release;
  bool _released = false;

  /// Releases this lease once. Repeated calls are harmless.
  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}

final class _BridgeState {
  int leases = 0;
  void Function()? uninstall;
}

/// Routes platform callback events to registered Dart sessions and callbacks.
///
/// This class deliberately knows nothing about FFI, JavaScript interop, or
/// generated bindings. Platform callback bridges translate their event payloads
/// into the dispatch methods below.
class CallbackManager {
  static final _instance = CallbackManager._();
  CallbackManager._();

  factory CallbackManager() => _instance;

  final Map<int, FFmpegSession> ffmpegSessions = {};
  final Map<int, FFprobeSession> ffprobeSessions = {};
  final Map<int, FFplaySession> ffplaySessions = {};
  final Map<int, MediaInformationSession> mediaInformationSessions = {};

  final Map<CallbackBridgeKind, _BridgeState> _bridgeStates = {
    for (final kind in CallbackBridgeKind.values) kind: _BridgeState(),
  };

  FFmpegLogCallback? globalLogCallback;
  FFmpegStatisticsCallback? globalStatisticsCallback;
  FFmpegSessionCompleteCallback? globalFFmpegSessionCompleteCallback;
  FFprobeSessionCompleteCallback? globalFFprobeSessionCompleteCallback;
  FFplaySessionCompleteCallback? globalFFplaySessionCompleteCallback;
  MediaInformationSessionCompleteCallback?
  globalMediaInformationSessionCompleteCallback;

  CallbackBridgeLease? _globalLogLease;
  CallbackBridgeLease? _globalStatisticsLease;
  CallbackBridgeLease? _globalFFmpegCompletionLease;
  CallbackBridgeLease? _globalFFprobeCompletionLease;
  CallbackBridgeLease? _globalFFplayCompletionLease;
  CallbackBridgeLease? _globalMediaInformationCompletionLease;

  /// Returns whether a native bridge is currently installed.
  bool isBridgeActive(CallbackBridgeKind kind) =>
      _bridgeStates[kind]!.leases > 0;

  /// Returns the current number of owners for [kind].
  int bridgeLeaseCount(CallbackBridgeKind kind) => _bridgeStates[kind]!.leases;

  /// Acquires one process-global callback bridge lease.
  ///
  /// Installation happens only for the first owner. If installation throws,
  /// the count remains unchanged so callers can safely retry or roll back.
  CallbackBridgeLease acquireBridge(
    CallbackBridgeKind kind, {
    required void Function() install,
    required void Function() uninstall,
  }) {
    final state = _bridgeStates[kind]!;
    if (state.leases == 0) {
      install();
      state.uninstall = uninstall;
    }
    state.leases++;
    return CallbackBridgeLease._(() => _releaseBridge(kind));
  }

  void _releaseBridge(CallbackBridgeKind kind) {
    final state = _bridgeStates[kind]!;
    if (state.leases == 0) return;
    state.leases--;
    if (state.leases != 0) return;

    final uninstall = state.uninstall;
    state.uninstall = null;
    // Reset ownership even if the backend reports an uninstall failure. A
    // later acquire will reinstall the callback and cannot inherit a stale
    // refcount or an obsolete backend closure.
    uninstall?.call();
  }

  void setGlobalLogCallback(
    FFmpegLogCallback? callback, {
    required void Function() install,
    required void Function() uninstall,
  }) {
    if (callback == null) {
      globalLogCallback = null;
      final lease = _globalLogLease;
      _globalLogLease = null;
      lease?.release();
      return;
    }
    final wasUnset = globalLogCallback == null;
    globalLogCallback = callback;
    if (wasUnset) {
      try {
        _globalLogLease = acquireBridge(
          CallbackBridgeKind.log,
          install: install,
          uninstall: uninstall,
        );
      } catch (_) {
        globalLogCallback = null;
        rethrow;
      }
    }
  }

  void setGlobalStatisticsCallback(
    FFmpegStatisticsCallback? callback, {
    required void Function() install,
    required void Function() uninstall,
  }) {
    if (callback == null) {
      globalStatisticsCallback = null;
      final lease = _globalStatisticsLease;
      _globalStatisticsLease = null;
      lease?.release();
      return;
    }
    final wasUnset = globalStatisticsCallback == null;
    globalStatisticsCallback = callback;
    if (wasUnset) {
      try {
        _globalStatisticsLease = acquireBridge(
          CallbackBridgeKind.statistics,
          install: install,
          uninstall: uninstall,
        );
      } catch (_) {
        globalStatisticsCallback = null;
        rethrow;
      }
    }
  }

  void setGlobalFFmpegSessionCompleteCallback(
    FFmpegSessionCompleteCallback? callback, {
    required void Function() install,
    required void Function() uninstall,
  }) {
    if (callback == null) {
      globalFFmpegSessionCompleteCallback = null;
      final lease = _globalFFmpegCompletionLease;
      _globalFFmpegCompletionLease = null;
      lease?.release();
      return;
    }
    final wasUnset = globalFFmpegSessionCompleteCallback == null;
    globalFFmpegSessionCompleteCallback = callback;
    if (wasUnset) {
      try {
        _globalFFmpegCompletionLease = acquireBridge(
          CallbackBridgeKind.ffmpegCompletion,
          install: install,
          uninstall: uninstall,
        );
      } catch (_) {
        globalFFmpegSessionCompleteCallback = null;
        rethrow;
      }
    }
  }

  void setGlobalFFprobeSessionCompleteCallback(
    FFprobeSessionCompleteCallback? callback, {
    required void Function() install,
    required void Function() uninstall,
  }) {
    if (callback == null) {
      globalFFprobeSessionCompleteCallback = null;
      final lease = _globalFFprobeCompletionLease;
      _globalFFprobeCompletionLease = null;
      lease?.release();
      return;
    }
    final wasUnset = globalFFprobeSessionCompleteCallback == null;
    globalFFprobeSessionCompleteCallback = callback;
    if (wasUnset) {
      try {
        _globalFFprobeCompletionLease = acquireBridge(
          CallbackBridgeKind.ffprobeCompletion,
          install: install,
          uninstall: uninstall,
        );
      } catch (_) {
        globalFFprobeSessionCompleteCallback = null;
        rethrow;
      }
    }
  }

  void setGlobalFFplaySessionCompleteCallback(
    FFplaySessionCompleteCallback? callback, {
    required void Function() install,
    required void Function() uninstall,
  }) {
    if (callback == null) {
      globalFFplaySessionCompleteCallback = null;
      final lease = _globalFFplayCompletionLease;
      _globalFFplayCompletionLease = null;
      lease?.release();
      return;
    }
    final wasUnset = globalFFplaySessionCompleteCallback == null;
    globalFFplaySessionCompleteCallback = callback;
    if (wasUnset) {
      try {
        _globalFFplayCompletionLease = acquireBridge(
          CallbackBridgeKind.ffplayCompletion,
          install: install,
          uninstall: uninstall,
        );
      } catch (_) {
        globalFFplaySessionCompleteCallback = null;
        rethrow;
      }
    }
  }

  void setGlobalMediaInformationSessionCompleteCallback(
    MediaInformationSessionCompleteCallback? callback, {
    required void Function() install,
    required void Function() uninstall,
  }) {
    if (callback == null) {
      globalMediaInformationSessionCompleteCallback = null;
      final lease = _globalMediaInformationCompletionLease;
      _globalMediaInformationCompletionLease = null;
      lease?.release();
      return;
    }
    final wasUnset = globalMediaInformationSessionCompleteCallback == null;
    globalMediaInformationSessionCompleteCallback = callback;
    if (wasUnset) {
      try {
        _globalMediaInformationCompletionLease = acquireBridge(
          CallbackBridgeKind.mediaInformationCompletion,
          install: install,
          uninstall: uninstall,
        );
      } catch (_) {
        globalMediaInformationSessionCompleteCallback = null;
        rethrow;
      }
    }
  }

  /// Returns the registered session for [sessionId], regardless of type.
  Session? sessionForId(int sessionId) =>
      ffmpegSessions[sessionId] ??
      ffprobeSessions[sessionId] ??
      ffplaySessions[sessionId] ??
      mediaInformationSessions[sessionId];

  void dispatchFFmpegComplete(int sessionId) {
    final session = ffmpegSessions[sessionId];
    if (session == null) {
      _warn('FFmpeg completion for unknown session $sessionId');
      return;
    }
    if (!session.claimCompletionDispatch()) return;
    _invoke('FFmpeg session completion', sessionId, () {
      session.completeCallback?.call(session);
    });
    _invoke('FFmpeg global completion', sessionId, () {
      globalFFmpegSessionCompleteCallback?.call(session);
    });
  }

  /// Media-information sessions are mirrored in the FFprobe map for lookup.
  void dispatchFFprobeComplete(int sessionId) {
    final session = ffprobeSessions[sessionId];
    if (session == null) {
      _warn('FFprobe completion for unknown session $sessionId');
      return;
    }
    if (!session.claimCompletionDispatch()) return;
    if (session is MediaInformationSession) {
      _invoke('Media-information session completion', sessionId, () {
        session.mediaInfoCompleteCallback?.call(session);
      });
      _invoke('Media-information global completion', sessionId, () {
        globalMediaInformationSessionCompleteCallback?.call(session);
      });
    } else {
      _invoke('FFprobe session completion', sessionId, () {
        session.completeCallback?.call(session);
      });
      _invoke('FFprobe global completion', sessionId, () {
        globalFFprobeSessionCompleteCallback?.call(session);
      });
    }
  }

  void dispatchFFplayComplete(int sessionId) {
    final session = ffplaySessions[sessionId];
    if (session == null) {
      _warn('FFplay completion for unknown session $sessionId');
      return;
    }
    if (!session.claimCompletionDispatch()) return;
    _invoke('FFplay session completion', sessionId, () {
      session.completeCallback?.call(session);
    });
    _invoke('FFplay global completion', sessionId, () {
      globalFFplaySessionCompleteCallback?.call(session);
    });
  }

  void dispatchMediaInformationComplete(int sessionId) {
    final session = mediaInformationSessions[sessionId];
    if (session == null) {
      _warn('Media-information completion for unknown session $sessionId');
      return;
    }
    if (!session.claimCompletionDispatch()) return;
    _invoke('Media-information session completion', sessionId, () {
      session.mediaInfoCompleteCallback?.call(session);
    });
    _invoke('Media-information global completion', sessionId, () {
      globalMediaInformationSessionCompleteCallback?.call(session);
    });
  }

  /// Routes a platform execution failure to the active session.
  ///
  /// This is intentionally separate from completion dispatch: a transport
  /// failure must settle the execution Future with an error and must
  /// never be represented as successful FFmpeg completion.
  bool dispatchSessionError(
    int sessionId,
    Object error,
    StackTrace stackTrace,
  ) {
    final session = sessionForId(sessionId);
    if (session == null) {
      _warn('Execution error for unknown session $sessionId: $error');
      return false;
    }
    _invoke('session execution error', sessionId, () {
      session.dispatchExecutionError(error, stackTrace);
    });
    return true;
  }

  /// Drains the platform session log buffer and dispatches its pending logs.
  void dispatchPendingLogs(int sessionId) {
    sessionForId(sessionId)?.dispatchPendingLogs();
  }

  /// Dispatches one already-decoded log event.
  void dispatchLog(int sessionId, int level, String message) {
    if (message.isEmpty) return;
    sessionForId(sessionId)?.onLogsDispatched([Log(sessionId, level, message)]);
  }

  /// Dispatches one already-decoded v2 log event with sequence authority.
  void dispatchDirectLog({
    required int sessionId,
    required int sequence,
    required int level,
    required String? message,
  }) {
    sessionForId(sessionId)?.dispatchDirectLogEvent(
      sequence: sequence,
      level: level,
      message: message,
    );
  }

  void dispatchStatistics({
    required int sessionId,
    required int timeElapsed,
    required int time,
    required int size,
    required double bitrate,
    required double speed,
    required int videoFrameNumber,
    required double videoFps,
    required double videoQuality,
    required int dupFrames,
    required int dropFrames,
  }) {
    final session = ffmpegSessions[sessionId];
    final statistics = Statistics(
      sessionId,
      timeElapsed,
      time,
      size,
      bitrate,
      speed,
      videoFrameNumber,
      videoFps,
      videoQuality,
      dupFrames,
      dropFrames,
      session?.calculateTranscodingProgress(time),
    );
    _invoke('global statistics callback', sessionId, () {
      globalStatisticsCallback?.call(statistics);
    });
    _invoke('session statistics callback', sessionId, () {
      session?.statisticsCallback?.call(statistics);
    });
  }

  void registerFFmpegSession(FFmpegSession session) {
    ffmpegSessions[session.sessionId] = session;
  }

  void registerFFprobeSession(FFprobeSession session) {
    ffprobeSessions[session.sessionId] = session;
  }

  void registerFFplaySession(FFplaySession session) {
    ffplaySessions[session.sessionId] = session;
  }

  void registerMediaInformationSession(MediaInformationSession session) {
    mediaInformationSessions[session.sessionId] = session;
    ffprobeSessions[session.sessionId] = session;
  }

  void unregisterFFmpegSession(int sessionId) {
    ffmpegSessions.remove(sessionId);
  }

  void unregisterFFprobeSession(int sessionId) {
    ffprobeSessions.remove(sessionId);
  }

  void unregisterFFplaySession(int sessionId) {
    ffplaySessions.remove(sessionId);
  }

  void unregisterMediaInformationSession(int sessionId) {
    mediaInformationSessions.remove(sessionId);
    ffprobeSessions.remove(sessionId);
  }

  void _invoke(String event, int sessionId, void Function() callback) {
    try {
      callback();
    } catch (error, stackTrace) {
      developer.log(
        'CallbackManager: error in $event for session $sessionId',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Invokes a user callback without allowing its exception to escape into
  /// native completion or queue-management code.
  void invokeSafely(String event, int sessionId, void Function() callback) {
    _invoke(event, sessionId, callback);
  }

  void _warn(String message) => developer.log('CallbackManager: $message');
}
