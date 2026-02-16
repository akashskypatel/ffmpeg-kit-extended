/**
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
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'ffmpeg_kit_flutter_loader.dart';
import 'ffmpeg_session.dart';
import 'ffplay_session.dart';
import 'ffprobe_session.dart';
import 'generated/ffmpeg_kit_bindings.dart';
import 'log.dart';
import 'media_information_session.dart';
import 'statistics.dart';

// --- Typedefs for Native Callbacks that are not exported by bindings ---
// C: Implementations
// typedef void (*FFmpegKitCompleteCallback)(FFmpegSessionHandle session,
//                                           void *user_data);
// typedef void (*FFmpegKitLogCallback)(FFmpegSessionHandle session,
//                                      const char *log, void *user_data);
// typedef void (*FFmpegKitStatisticsCallback)(FFmpegSessionHandle session,
//                                             int time, int64_t size,
//                                             double bitrate, double speed,
//                                             int videoFrameNumber,
//                                             float videoFps, float videoQuality,
//                                             void *user_data);
// typedef void (*FFprobeKitCompleteCallback)(FFprobeSessionHandle session,
//                                            void *user_data);
// typedef void (*FFplayKitCompleteCallback)(FFplaySessionHandle session,
//                                           void *user_data);
// typedef void (*MediaInformationSessionCompleteCallback)(
//     MediaInformationSessionHandle session, void *user_data);
typedef FFmpegKitCompleteCallbackFunction = Void Function(
    FFmpegSessionHandle, Pointer<Void>);
typedef FFprobeKitCompleteCallbackFunction = Void Function(
    FFprobeSessionHandle, Pointer<Void>);
typedef FFplayKitCompleteCallbackFunction = Void Function(
    FFplaySessionHandle, Pointer<Void>);
// just using FFprobeKitCompleteCallbackFunction for MediaInformationSessionCompleteCallbackFunction
// typedef MediaInformationSessionCompleteCallbackFunction = Void Function(
//     MediaInformationSessionHandle, Pointer<Void>);
typedef FFmpegKitLogCallbackFunction = Void Function(
    FFmpegSessionHandle, Pointer<Char>, Pointer<Void>);

// Note: Ensure types match exactly with C API
// C: void (*FFmpegKitStatisticsCallback)(FFmpegSessionHandle session,
//                                         int time, int64_t size,
//                                         double bitrate, double speed,
//                                         int videoFrameNumber,
//                                         float videoFps, float videoQuality,
//                                         void *user_data);
typedef FFmpegKitStatisticsCallbackFunction = Void Function(FFmpegSessionHandle,
    Int, Int64, Double, Double, Int, Float, Float, Pointer<Void>);

// --- Callback Types (Dart side) ---
typedef FFmpegSessionCompleteCallback = void Function(FFmpegSession session);
typedef FFmpegLogCallback = void Function(Log log);
typedef FFmpegStatisticsCallback = void Function(Statistics statistics);
typedef FFprobeSessionCompleteCallback = void Function(FFprobeSession session);
typedef FFplaySessionCompleteCallback = void Function(FFplaySession session);
typedef MediaInformationSessionCompleteCallback = void Function(
    MediaInformationSession session);

/// Handles the completion of an FFmpeg session.
///
/// This function is called when an FFmpeg session is completed. It retrieves
/// the session ID from the session handle and looks up the corresponding
/// [FFmpegSession] object in the callback manager. If a session object is
/// found, it is used; otherwise, the session is retrieved from the
/// callback manager's map of sessions.
void _onFFmpegComplete(
    FFmpegSessionHandle sessionHandle, Pointer<Void> userData) {
  final sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(sessionHandle);

  // If we have an existing session object, use it.
  FFmpegSession? session;
  if (userData != nullptr) {
    final callbackId = userData.address;
    session = CallbackManager().getFFmpegSession(callbackId);
  }

  // Fallback to searching by sessionId if userData not provided (unlikely for specialized sessions but possible for global)
  session ??= CallbackManager().ffmpegSessions[sessionId];

  if (session != null) {
    session.endTime = DateTime.now();
    session.completeCallback?.call(session);
  } else {
    stderr.writeln(
        "Warning: FFmpeg session complete callback for unknown session $sessionId (userData: ${userData.address})");
  }

  // Always check global callback
  if (session != null) {
    CallbackManager().globalFFmpegSessionCompleteCallback?.call(session);
  }

  if (userData != nullptr) {
    CallbackManager().unregisterSession(userData.address);
  }
  ffmpeg.ffmpeg_kit_handle_release(sessionHandle);
}

/// Handles a log message from an FFmpeg session.
///
/// This function is called when a log message is generated by an FFmpeg session.
/// It retrieves the session ID from the session handle and looks up the
/// corresponding [FFmpegSession] object in the callback manager. If a session
/// object is found, it is used; otherwise, the session is retrieved from the
/// callback manager's map of sessions.
void _onFFmpegLog(FFmpegSessionHandle sessionHandle, Pointer<Char> logPtr,
    Pointer<Void> userData) {
  if (logPtr == nullptr) return;
  int sessionId = 0;
  final address = sessionHandle.address;
  if (address != 0) {
    // Heuristic: Real pointers are usually large (> 0x100000).
    // Session IDs are small integers.
    if (address < 0x100000) {
      sessionId = address;
    } else {
      // Assume Real Handle
      try {
        sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(sessionHandle);
      } catch (e) {
        stderr.writeln("Error getting session ID from handle: $e");
      }
    }
  }

  String message;
  try {
    message = logPtr.cast<Utf8>().toDartString();
  } on FormatException {
    int length = 0;
    while (logPtr.elementAt(length).value != 0) {
      length++;
    }
    message = utf8.decode(logPtr.cast<Uint8>().asTypedList(length),
        allowMalformed: true);
  }

  final log = Log(sessionId, LogLevel.info.value, message);

  // Global callback
  CallbackManager().globalLogCallback?.call(log);

  // Session specific
  FFmpegSession? session;
  if (userData != nullptr && userData.address != 0) {
    final callbackId = userData.address;
    session = CallbackManager().getFFmpegSession(callbackId);
  }

  // Fallback to sessionId lookup
  if (session == null && sessionId > 0) {
    session = CallbackManager().ffmpegSessions[sessionId];
  }

  if (session != null) {
    session.logCallback?.call(log);
  } else {
    // Only print if not quiet
    if (CallbackManager().globalLogCallback == null) {
      // Optional: stderr.writeln("Warning: No session for log: $message");
    }
  }

  // Free log string (Standard wrapper strdup)
  ffmpeg.ffmpeg_kit_free(logPtr.cast());
}

/// Handles statistics from an FFmpeg session.
///
/// This function is called when statistics are generated by an FFmpeg session.
/// It retrieves the session ID from the session handle and looks up the
/// corresponding [FFmpegSession] object in the callback manager. If a session
/// object is found, it is used; otherwise, the session is retrieved from the
/// callback manager's map of sessions.
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
  int sessionId = 0;
  final address = sessionHandle.address;
  if (address != 0) {
    if (address < 0x100000) {
      sessionId = address;
    } else {
      try {
        sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(sessionHandle);
      } catch (e) {
        stderr.writeln("Error getting session ID from handle: $e");
      }
    }
  }

  final stats = Statistics(sessionId, time, size, bitrate, speed,
      videoFrameNumber, videoFps, videoQuality);

  // Global callback
  CallbackManager().globalStatisticsCallback?.call(stats);

  // Session specific
  FFmpegSession? session;
  if (userData != nullptr && userData.address != 0) {
    final callbackId = userData.address;
    session = CallbackManager().getFFmpegSession(callbackId);
  }
  if (session == null && sessionId > 0) {
    session = CallbackManager().ffmpegSessions[sessionId];
  }

  if (session != null) {
    session.statisticsCallback?.call(stats);
  } else {
    stderr.writeln(
        "Warning: Statistics received for unknown session $sessionId (userData: ${userData.address})");
  }
}

/// Handles the completion of an FFprobe session.
///
/// This function is called when an FFprobe session is completed. It retrieves
/// the session ID from the session handle and looks up the corresponding
/// [FFprobeSession] object in the callback manager. If a session object is
/// found, it is used; otherwise, the session is retrieved from the
/// callback manager's map of sessions.
void _onFFprobeComplete(
    FFprobeSessionHandle sessionHandle, Pointer<Void> userData) {
  final sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(sessionHandle);
  FFprobeSession? session;

  if (userData != nullptr) {
    final callbackId = userData.address;
    session = CallbackManager().getFFprobeSession(callbackId);
  }

  session ??= CallbackManager().ffprobeSessions[sessionId];

  if (session != null) {
    session.endTime = DateTime.now();
    if (session is MediaInformationSession) {
      (session.completeCallback as MediaInformationSessionCompleteCallback?)
          ?.call(session);
      CallbackManager()
          .globalMediaInformationSessionCompleteCallback
          ?.call(session);
    } else {
      session.completeCallback?.call(session);
      CallbackManager().globalFFprobeSessionCompleteCallback?.call(session);
    }
  }

  if (userData != nullptr) {
    CallbackManager().unregisterSession(userData.address);
  }
  ffmpeg.ffmpeg_kit_handle_release(sessionHandle);
}

/// Handles the completion of an FFplay session.
///
/// This function is called when an FFplay session is completed. It retrieves
/// the session ID from the session handle and looks up the corresponding
/// [FFplaySession] object in the callback manager. If a session object is
/// found, it is used; otherwise, the session is retrieved from the
/// callback manager's map of sessions.
void _onFFplayComplete(
    FFplaySessionHandle sessionHandle, Pointer<Void> userData) {
  final sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(sessionHandle);
  FFplaySession? session;

  if (userData != nullptr) {
    final callbackId = userData.address;
    session = CallbackManager().getFFplaySession(callbackId);
  }

  session ??= CallbackManager().ffplaySessions[sessionId];

  if (session != null) {
    session.endTime = DateTime.now();
    session.completeCallback?.call(session);
    CallbackManager().globalFFplaySessionCompleteCallback?.call(session);
  }

  if (userData != nullptr) {
    CallbackManager().unregisterSession(userData.address);
  }
  ffmpeg.ffmpeg_kit_handle_release(sessionHandle);
}

// Keep static references to listeners to prevent GC
final nativeFFmpegComplete =
    NativeCallable<FFmpegKitCompleteCallbackFunction>.listener(
        _onFFmpegComplete);
final nativeFFmpegLog =
    NativeCallable<FFmpegKitLogCallbackFunction>.listener(_onFFmpegLog);
final nativeFFmpegStatistics =
    NativeCallable<FFmpegKitStatisticsCallbackFunction>.listener(
        _onFFmpegStatistics);
final nativeFFprobeComplete =
    NativeCallable<FFprobeKitCompleteCallbackFunction>.listener(
        _onFFprobeComplete);
final nativeMediaInfoComplete = NativeCallable<
        MediaInformationSessionCompleteCallbackFunction>.listener(
    _onFFprobeComplete); // Note: Re-use FFprobe handler as signature works (Handle, void*)
final nativeFFplayComplete =
    NativeCallable<FFplayKitCompleteCallbackFunction>.listener(
        _onFFplayComplete);

/// Internal manager for handling native-to-Dart callbacks.
///
/// This class maintains maps of active sessions and bridges native callback
/// invocations (which pass a `userData` pointer) back to the corresponding
/// Dart session objects and their callbacks.
class CallbackManager {
  static final _instance = CallbackManager._();
  CallbackManager._();

  /// Returns the singleton instance of [CallbackManager].
  factory CallbackManager() => _instance;

  /// Active FFmpeg sessions indexed by their session ID.
  final Map<int, FFmpegSession> ffmpegSessions = {};

  /// Active FFprobe sessions indexed by their session ID.
  final Map<int, FFprobeSession> ffprobeSessions = {};

  /// Active FFplay sessions indexed by their session ID.
  final Map<int, FFplaySession> ffplaySessions = {};

  /// Active MediaInformation sessions indexed by their session ID.
  final Map<int, MediaInformationSession> mediaInformationSessions = {};

  /// Counter for generating unique callback IDs.
  int nextCallbackId = 1;

  /// Map associating unique callback IDs (pointer addresses) with session IDs.
  final Map<int, int> callbackIdToSessionId = {};

  /// Map associating unique callback IDs directly with FFmpegSession objects.
  final Map<int, FFmpegSession> callbackIdToFFmpegSession = {};

  /// Map associating unique callback IDs directly with FFprobeSession objects.
  final Map<int, FFprobeSession> callbackIdToFFprobeSession = {};

  /// Map associating unique callback IDs directly with FFplaySession objects.
  final Map<int, FFplaySession> callbackIdToFFplaySession = {};

  /// Map associating unique callback IDs directly with MediaInformationSession objects.
  final Map<int, MediaInformationSession> callbackIdToMediaInformationSession =
      {};

  /// Global FFmpeg log callback.
  FFmpegLogCallback? globalLogCallback;

  /// Global FFmpeg statistics callback.
  FFmpegStatisticsCallback? globalStatisticsCallback;

  /// Global FFmpeg session complete callback.
  FFmpegSessionCompleteCallback? globalFFmpegSessionCompleteCallback;

  /// Global FFprobe session complete callback.
  FFprobeSessionCompleteCallback? globalFFprobeSessionCompleteCallback;

  /// Global FFplay session complete callback.
  FFplaySessionCompleteCallback? globalFFplaySessionCompleteCallback;

  /// Global MediaInformation session complete callback.
  MediaInformationSessionCompleteCallback?
      globalMediaInformationSessionCompleteCallback;

  /// Registers an [FFmpegSession] and generates a unique callback ID.
  ///
  /// The ID is used as the `userData` pointer in native calls.
  int registerFFmpegSession(FFmpegSession session) {
    final id = nextCallbackId++;
    ffmpegSessions[session.sessionId] = session;
    callbackIdToSessionId[id] = session.sessionId;
    callbackIdToFFmpegSession[id] = session;
    return id;
  }

  /// Registers an [FFprobeSession] and generates a unique callback ID.
  int registerFFprobeSession(FFprobeSession session) {
    final id = nextCallbackId++;
    ffprobeSessions[session.sessionId] = session;
    callbackIdToSessionId[id] = session.sessionId;
    callbackIdToFFprobeSession[id] = session;
    return id;
  }

  /// Registers an [FFplaySession] and generates a unique callback ID.
  int registerFFplaySession(FFplaySession session) {
    final id = nextCallbackId++;
    ffplaySessions[session.sessionId] = session;
    callbackIdToSessionId[id] = session.sessionId;
    callbackIdToFFplaySession[id] = session;
    return id;
  }

  /// Registers a [MediaInformationSession] and generates a unique callback ID.
  int registerMediaInformationSession(MediaInformationSession session) {
    final id = nextCallbackId++;
    mediaInformationSessions[session.sessionId] = session;
    callbackIdToSessionId[id] = session.sessionId;
    callbackIdToMediaInformationSession[id] = session;
    return id;
  }

  /// Removes a session from registration using its [callbackId].
  void unregisterSession(int callbackId) {
    callbackIdToFFmpegSession.remove(callbackId);
    callbackIdToFFprobeSession.remove(callbackId);
    callbackIdToFFplaySession.remove(callbackId);
    callbackIdToMediaInformationSession.remove(callbackId);

    final sessionId = callbackIdToSessionId.remove(callbackId);
    if (sessionId != null) {
      ffmpegSessions.remove(sessionId);
      ffprobeSessions.remove(sessionId);
      ffplaySessions.remove(sessionId);
      mediaInformationSessions.remove(sessionId);
    }
  }

  /// Retrieves the [FFmpegSession] associated with the given [callbackId].
  FFmpegSession? getFFmpegSession(int callbackId) {
    if (callbackIdToFFmpegSession.containsKey(callbackId)) {
      return callbackIdToFFmpegSession[callbackId];
    }
    final sessionId = callbackIdToSessionId[callbackId];
    if (sessionId == null) return null;
    return ffmpegSessions[sessionId];
  }

  /// Retrieves the [FFprobeSession] associated with the given [callbackId].
  FFprobeSession? getFFprobeSession(int callbackId) {
    if (callbackIdToFFprobeSession.containsKey(callbackId)) {
      return callbackIdToFFprobeSession[callbackId];
    }
    final sessionId = callbackIdToSessionId[callbackId];
    if (sessionId == null) return null;
    return ffprobeSessions[sessionId];
  }

  /// Retrieves the [FFplaySession] associated with the given [callbackId].
  FFplaySession? getFFplaySession(int callbackId) {
    if (callbackIdToFFplaySession.containsKey(callbackId)) {
      return callbackIdToFFplaySession[callbackId];
    }
    final sessionId = callbackIdToSessionId[callbackId];
    if (sessionId == null) return null;
    return ffplaySessions[sessionId];
  }

  /// Retrieves the [MediaInformationSession] associated with the given [callbackId].
  MediaInformationSession? getMediaInformationSession(int callbackId) {
    if (callbackIdToMediaInformationSession.containsKey(callbackId)) {
      return callbackIdToMediaInformationSession[callbackId];
    }
    final sessionId = callbackIdToSessionId[callbackId];
    if (sessionId == null) return null;
    return mediaInformationSessions[sessionId];
  }
}
