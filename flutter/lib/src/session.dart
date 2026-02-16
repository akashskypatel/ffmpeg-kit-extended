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

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'ffmpeg_kit_flutter_loader.dart';

/// Return code for a session.
enum ReturnCode {
  success(0),
  cancel(255);

  final int value;
  const ReturnCode(this.value);

  static bool isSuccess(int code) => code == success.value;
  static bool isCancel(int code) => code == cancel.value;
}

/// Session state.
enum SessionState {
  created(0),
  running(1),
  completed(2),
  failed(3);

  final int value;
  const SessionState(this.value);

  static SessionState fromValue(int value) => SessionState.values.firstWhere(
        (e) => e.value == value,
        orElse: () => SessionState.failed,
      );
}

/// Base class for all FFmpegKit sessions.
///
/// This class provides common functionality for managing session state,
/// retrieving output, logs, and timing information.
abstract class Session implements Finalizable {
  /// The native handle to the session.
  late Pointer<Void> handle;

  // Session(String command) {
  //   final commandChar = command.toNativeUtf8();
  //   handle = ffmpeg.ffmpeg_kit_create_session(commandChar.cast());
  //   malloc.free(commandChar);
  // }

  /// The unique identifier for this session.
  late int sessionId;

  /// The FFmpeg command associated with this session.
  late String command;

  /// The time when this session was created.
  late DateTime startTime;

  /// The time when this session finished execution.
  DateTime? endTime;

  /// Internal state: whether this session was cancelled.
  bool _isCancelled = false;

  /// Whether this session was cancelled.
  bool get isCancelled => _isCancelled;

  static bool skipFinalizer = false;
  static NativeFinalizer? __finalizer;
  static NativeFinalizer get _finalizer {
    if (__finalizer == null) {
      Pointer<NativeFunction<Void Function(Pointer<Void>)>> ptr;
      try {
        ptr = ffmpegLibrary
            .lookup<NativeFunction<Void Function(Pointer<Void>)>>(
                'ffmpeg_kit_handle_release')
            .cast();
      } catch (e) {
        // Fallback for tests if library or symbol is missing
        ptr = Pointer.fromAddress(0);
      }
      __finalizer = NativeFinalizer(ptr);
    }
    return __finalizer!;
  }

  /// Registers a finalizer to release the native handle when this object is garbage collected.
  void registerFinalizer() {
    if (skipFinalizer) return;
    _finalizer.attach(this, handle, detach: this);
  }

  /// Gets the current session state.
  ///
  /// Returns a [SessionState] enum value.
  SessionState getState() {
    final stateEnum = ffmpeg.ffmpeg_kit_session_get_state(handle);
    return SessionState.fromValue(stateEnum.value);
  }

  /// Gets the session return code.
  ///
  /// Returns the exit code of the process.
  int getReturnCode() => ffmpeg.ffmpeg_kit_session_get_return_code(handle);

  /// Gets the session output.
  ///
  /// Returns the full output of the session as a string, or null if not available.
  String? getOutput() {
    final ptr = ffmpeg.ffmpeg_kit_session_get_output(handle);
    return _toDartStringAndFree(ptr);
  }

  /// Gets the session logs as a single string.
  ///
  /// Returns the logs, or null if not available.
  String? getLogs() {
    final ptr = ffmpeg.ffmpeg_kit_session_get_logs_as_string(handle);
    return _toDartStringAndFree(ptr);
  }

  /// Gets the stack trace if the session failed.
  ///
  /// Returns the stack trace as a string, or null if no failure occurred.
  String? getFailStackTrace() {
    final ptr = ffmpeg.ffmpeg_kit_session_get_fail_stack_trace(handle);
    return _toDartStringAndFree(ptr);
  }

  /// Gets the time when the session was created in the native layer (timestamp).
  int getCreateTime() => ffmpeg.ffmpeg_kit_session_get_create_time(handle);

  /// Gets the time when the session execution started (timestamp).
  int getStartTime() => ffmpeg.ffmpeg_kit_session_get_start_time(handle);

  /// Gets the time when the session execution ended (timestamp).
  int getEndTime() => ffmpeg.ffmpeg_kit_session_get_end_time(handle);

  /// Gets the total duration of the session in milliseconds.
  int getSessionDuration() => ffmpeg.ffmpeg_kit_session_get_duration(handle);

  /// Gets the command executed by this session.
  String getCommand() {
    final commandChar = ffmpeg.ffmpeg_kit_session_get_command(handle);
    return _toDartStringAndFree(commandChar) ?? "";
  }

  /// Gets the number of log entries available for this session.
  int getLogsCount() => ffmpeg.ffmpeg_kit_session_get_logs_count(handle);

  /// Gets the log entry at the specified [index].
  String getLogAt(int index) {
    final logChar = ffmpeg.ffmpeg_kit_session_get_log_at(handle, index);
    return _toDartStringAndFree(logChar) ?? "";
  }

  /// Gets the log level for the log entry at the specified [index].
  int getLogLevelAt(int index) =>
      ffmpeg.ffmpeg_kit_session_get_log_level_at(handle, index);

  /// Gets the number of statistics entries available for this session.
  int getStatisticsCount() =>
      ffmpeg.ffmpeg_kit_session_get_statistics_count(handle);

  /// Gets the statistics entry at the specified [index] as a string.
  ///
  /// Note: This currently returns an empty string as the C API returns complex objects
  /// that need further parsing, which is handled in specialized subclasses or methods.
  String getStatisticsAt(int index) {
    final handle =
        ffmpeg.ffmpeg_kit_session_get_statistics_at(this.handle, index);
    if (handle != nullptr) {
      ffmpeg.ffmpeg_kit_handle_release(handle);
    }
    return "";
  }

  /// Gets the unique session ID.
  int getSessionId() => ffmpeg.ffmpeg_kit_session_get_session_id(handle);

  String? _toDartStringAndFree(Pointer<Char> ptr) {
    if (ptr == nullptr) return null;
    final res = ptr.cast<Utf8>().toDartString();
    ffmpeg.ffmpeg_kit_free(ptr.cast());
    return res;
  }

  /// Cancels this session execution if it is currently running.
  void cancel() {
    if (getState() == SessionState.completed ||
        getState() == SessionState.failed ||
        ReturnCode.isCancel(getReturnCode())) {
      return;
    }
    ffmpeg.ffmpeg_kit_cancel_session(sessionId);
    _isCancelled = true;
  }

  /// Returns true if this is an [FFmpegSession].
  bool isFFmpegSession() => false;

  /// Returns true if this is an [FFplaySession].
  bool isFFplaySession() => false;

  /// Returns true if this is an [FFprobeSession].
  bool isFFprobeSession() => false;

  /// Returns true if this is a [MediaInformationSession].
  bool isMediaInformationSession() => false;
}
