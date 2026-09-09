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

  FFmpegLogCallback? globalLogCallback;
  FFmpegStatisticsCallback? globalStatisticsCallback;
  FFmpegSessionCompleteCallback? globalFFmpegSessionCompleteCallback;
  FFprobeSessionCompleteCallback? globalFFprobeSessionCompleteCallback;
  FFplaySessionCompleteCallback? globalFFplaySessionCompleteCallback;
  MediaInformationSessionCompleteCallback?
  globalMediaInformationSessionCompleteCallback;

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
    _invoke('FFmpeg completion', sessionId, () {
      session.completeCallback?.call(session);
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
    _invoke('FFprobe completion', sessionId, () {
      if (session is MediaInformationSession) {
        session.mediaInfoCompleteCallback?.call(session);
        globalMediaInformationSessionCompleteCallback?.call(session);
      } else {
        session.completeCallback?.call(session);
        globalFFprobeSessionCompleteCallback?.call(session);
      }
    });
  }

  void dispatchFFplayComplete(int sessionId) {
    final session = ffplaySessions[sessionId];
    if (session == null) {
      _warn('FFplay completion for unknown session $sessionId');
      return;
    }
    _invoke('FFplay completion', sessionId, () {
      session.completeCallback?.call(session);
      globalFFplaySessionCompleteCallback?.call(session);
    });
  }

  void dispatchMediaInformationComplete(int sessionId) {
    final session = mediaInformationSessions[sessionId];
    if (session == null) {
      _warn('Media-information completion for unknown session $sessionId');
      return;
    }
    _invoke('Media-information completion', sessionId, () {
      session.mediaInfoCompleteCallback?.call(session);
      globalMediaInformationSessionCompleteCallback?.call(session);
    });
  }

  /// Drains the platform session log buffer and dispatches its pending logs.
  void dispatchPendingLogs(int sessionId) {
    sessionForId(sessionId)?.dispatchPendingLogs();
  }

  /// Dispatches one already-decoded log event.
  void dispatchLog(int sessionId, int level, String message) {
    if (message.isEmpty) return;
    sessionForId(sessionId)?.onLogsDispatched([
      Log(sessionId, level, message),
    ]);
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
    globalStatisticsCallback?.call(statistics);
    session?.statisticsCallback?.call(statistics);
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

  void _warn(String message) => developer.log('CallbackManager: $message');
}
