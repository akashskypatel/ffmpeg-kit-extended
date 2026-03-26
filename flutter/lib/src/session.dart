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

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import '../ffmpeg_kit_extended_flutter.dart'
    show
        FFmpegSession,
        FFplaySession,
        FFprobeSession,
        MediaInformationSession,
        FFmpegKitExtended;
import 'ffmpeg_kit_flutter_loader.dart';
import 'statistics.dart';

// ---------------------------------------------------------------------------
// Return-code sentinel values
// ---------------------------------------------------------------------------

/// Well-known exit codes returned by the native layer.
enum ReturnCode {
  success(0),
  cancel(255);

  final int value;
  const ReturnCode(this.value);

  /// Returns `true` if [code] represents successful completion.
  static bool isSuccess(int code) => code == success.value;

  /// Returns `true` if [code] represents a user-requested cancellation.
  static bool isCancel(int code) => code == cancel.value;
}

// ---------------------------------------------------------------------------
// Session lifecycle state
// ---------------------------------------------------------------------------

/// Lifecycle state of an FFmpegKit session
enum SessionState {
  created(0),
  running(1),
  completed(2),
  failed(3);

  final int value;
  const SessionState(this.value);

  /// Maps an integer value from the C layer to a [SessionState].
  ///
  /// Falls back to [SessionState.failed] for any unrecognised value so that
  /// callers always receive a valid enum member rather than a runtime error.
  static SessionState fromValue(int value) => SessionState.values.firstWhere(
        (e) => e.value == value,
        orElse: () => SessionState.failed,
      );
}

// ---------------------------------------------------------------------------
// Session base class
// ---------------------------------------------------------------------------

/// Base class for all FFmpegKit sessions.
///
/// Provides common access to session state, return code, output, logs,
/// statistics, timing, and debug utilities.  All concrete session types
/// ([FFmpegSession], [FFprobeSession], [FFplaySession],
/// [MediaInformationSession]) extend this class.
///
/// ### Native handle lifetime
/// Each session owns an opaque native C++ object exposed as a
/// [Pointer<Void>] ([handle]).  A [NativeFinalizer] is attached at
/// construction time to call `ffmpeg_kit_handle_release` when the Dart
/// object is garbage-collected, preventing native memory leaks even when
/// the caller drops a reference without an explicit release.
///
/// ### Testing without a native library
/// Use the protected [Session.noFinalizer] constructor in test subclasses
/// or mock factories.  This sets an instance-level flag that suppresses
/// finalizer registration for that specific instance.  Unlike the previous
/// `static bool skipFinalizer` approach, this flag cannot leak between
/// tests or affect unrelated sessions.
abstract class Session implements Finalizable {
  // ---- Core fields --------------------------------------------------------

  /// The native opaque handle for this session.
  late Pointer<Void> handle;

  /// The C-layer session identifier.  Stable for the session's entire lifetime.
  late int sessionId;

  /// The command string that was (or will be) executed.
  late String command;

  /// Index of the next log entry not yet dispatched to Dart callbacks.
  ///
  /// Shared between [Session], `FFmpegSession`, and `CallbackManager` so
  /// that the log-polling loop and the completion flush both advance from the
  /// same cursor and never deliver the same entry twice.
  int logsProcessed = 0;

  // ---- Cancellation -------------------------------------------------------

  bool _isCancelled = false;

  /// Whether [cancel] has been called on this session.
  bool get isCancelled => _isCancelled;

  /// When `true`, [registerFinalizer] is a no-op for this specific instance.
  /// Set exclusively by [Session.noFinalizer]; immutable after construction.
  final bool _skipFinalizer;

  /// Standard constructor — [registerFinalizer] will attach the native
  /// finalizer after [handle] is assigned.
  Session() : _skipFinalizer = false;

  /// Constructor for use in test subclasses where no native library is loaded.
  ///
  /// Suppresses finalizer registration for *this instance only*; all other
  /// concurrently-live sessions are unaffected.
  ///
  /// **Production code must never call this constructor.**
  Session.noFinalizer() : _skipFinalizer = true;

  // Lazily-initialised shared NativeFinalizer.  The function pointer for
  // `ffmpeg_kit_handle_release` is resolved once from the loaded dynamic
  // library and reused for every subsequent [registerFinalizer] call.
  static NativeFinalizer? _sharedFinalizer;

  static NativeFinalizer _getFinalizer() {
    if (_sharedFinalizer != null) return _sharedFinalizer!;

    Pointer<NativeFunction<Void Function(Pointer<Void>)>> ptr;
    try {
      ptr = ffmpegLibrary
          .lookup<NativeFunction<Void Function(Pointer<Void>)>>(
              'ffmpeg_kit_handle_release')
          .cast();
    } catch (_) {
      // Library not loaded (unit-test environment with a stub / no-op lib).
      // A zero-address token is safe: NativeFinalizer will never invoke it
      // because it only runs on GC, and tests should not create sessions that
      // reach GC in this code path.
      ptr = Pointer.fromAddress(0);
    }
    _sharedFinalizer = NativeFinalizer(ptr);
    return _sharedFinalizer!;
  }

  /// Attaches the native finalizer to this session.
  ///
  /// Must be called exactly once from every concrete subclass constructor,
  /// *after* both [handle] and [sessionId] have been assigned.
  ///
  /// Calling this more than once on the same session is safe — [_skipFinalizer]
  /// and the guard inside [NativeFinalizer.attach] prevent double-attachment.
  void registerFinalizer() {
    if (_skipFinalizer) return;
    _getFinalizer().attach(this, handle, detach: this);
  }

  // ---- State & return code ------------------------------------------------

  /// Returns the current lifecycle state of this session.
  SessionState getState() {
    FFmpegKitExtended.requireInitialized();
    return SessionState.fromValue(
        ffmpeg.ffmpeg_kit_session_get_state(handle).value);
  }

  /// Returns the native exit code.
  ///
  /// Meaningful only after [getState] returns [SessionState.completed] or
  /// [SessionState.failed].  Returns 0 while the session is still running.
  int getReturnCode() {
    FFmpegKitExtended.requireInitialized();
    return ffmpeg.ffmpeg_kit_session_get_return_code(handle);
  }

  /// Returns the unique session ID assigned by the C layer.
  ///
  /// Equivalent to [sessionId]; provided as a method for API parity with
  /// the original FFmpegKit Java/ObjC SDK.
  int getSessionId() {
    FFmpegKitExtended.requireInitialized();
    return ffmpeg.ffmpeg_kit_session_get_session_id(handle);
  }

  // ---- Timing -------------------------------------------------------------

  /// Returns the time at which the session object was created.
  DateTime getCreateTime() {
    FFmpegKitExtended.requireInitialized();
    return DateTime.fromMillisecondsSinceEpoch(
        ffmpeg.ffmpeg_kit_session_get_create_time(handle));
  }

  /// Returns the time at which execution started, or `null` if the session
  /// has not yet been executed.
  DateTime? getStartTime() {
    FFmpegKitExtended.requireInitialized();
    final ms = ffmpeg.ffmpeg_kit_session_get_start_time(handle);
    return ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Returns the time at which execution ended, or `null` if the session has
  /// not yet completed.
  DateTime? getEndTime() {
    FFmpegKitExtended.requireInitialized();
    final ms = ffmpeg.ffmpeg_kit_session_get_end_time(handle);
    return ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Returns the wall-clock execution duration in milliseconds.
  ///
  /// Returns 0 if the session has not yet completed.
  int getDuration() {
    FFmpegKitExtended.requireInitialized();
    return ffmpeg.ffmpeg_kit_session_get_duration(handle);
  }

  // ---- Output & logs ------------------------------------------------------

  /// Returns the combined output of the session as a string, or `null` if no
  /// output is available yet.
  String? getOutput() {
    FFmpegKitExtended.requireInitialized();
    return _toDartStringAndFree(ffmpeg.ffmpeg_kit_session_get_output(handle));
  }

  /// Returns all buffered log entries concatenated into a single string, or
  /// `null` if no log entries exist.  Equivalent to [getLogsAsString].
  String? getLogs() {
    FFmpegKitExtended.requireInitialized();
    return getLogsAsString();
  }

  /// Returns all buffered log entries concatenated into a single string, or
  /// `null` if no log entries exist.
  String? getLogsAsString() {
    FFmpegKitExtended.requireInitialized();
    return _toDartStringAndFree(
        ffmpeg.ffmpeg_kit_session_get_logs_as_string(handle));
  }

  /// Returns the failure stack trace captured when the session failed, or
  /// `null` if the session did not fail or no trace is available.
  String? getFailStackTrace() {
    FFmpegKitExtended.requireInitialized();
    return _toDartStringAndFree(
        ffmpeg.ffmpeg_kit_session_get_fail_stack_trace(handle));
  }

  /// Returns the command string as reported by the C layer.
  String getCommand() {
    FFmpegKitExtended.requireInitialized();
    return _toDartStringAndFree(
            ffmpeg.ffmpeg_kit_session_get_command(handle)) ??
        '';
  }

  /// Returns the number of log entries buffered for this session.
  int getLogsCount() {
    FFmpegKitExtended.requireInitialized();
    return ffmpeg.ffmpeg_kit_session_get_logs_count(handle);
  }

  /// Returns the log message at [index].
  ///
  /// Returns an empty string if [index] is out of range or the C layer
  /// returns a null pointer.
  String getLogAt(int index) {
    FFmpegKitExtended.requireInitialized();
    return _toDartStringAndFree(
            ffmpeg.ffmpeg_kit_session_get_log_at(handle, index)) ??
        '';
  }

  /// Returns the log level for the entry at [index].
  int getLogLevelAt(int index) {
    FFmpegKitExtended.requireInitialized();
    return ffmpeg.ffmpeg_kit_session_get_log_level_at(handle, index);
  }

  // ---- Statistics ---------------------------------------------------------

  /// Returns the number of statistics snapshots buffered for this session.
  int getStatisticsCount() {
    FFmpegKitExtended.requireInitialized();
    return ffmpeg.ffmpeg_kit_session_get_statistics_count(handle);
  }

  /// Returns the [Statistics] snapshot at [index], or `null` if the index is
  /// out of range.
  Statistics? getStatisticsAt(int index) {
    FFmpegKitExtended.requireInitialized();
    final statsHandle =
        ffmpeg.ffmpeg_kit_session_get_statistics_at(handle, index);
    if (statsHandle == nullptr) return null;

    try {
      final videoFrameNumber =
          ffmpeg.ffmpeg_kit_statistics_get_video_frame_number(statsHandle);
      final videoFps = ffmpeg.ffmpeg_kit_statistics_get_video_fps(statsHandle);
      final videoQuality =
          ffmpeg.ffmpeg_kit_statistics_get_video_quality(statsHandle);
      final size = ffmpeg.ffmpeg_kit_statistics_get_size(statsHandle);
      // The C API returns time in milliseconds; Statistics.time is int (milliseconds).
      final timeMs = ffmpeg.ffmpeg_kit_statistics_get_time(statsHandle).round();
      final bitrate = ffmpeg.ffmpeg_kit_statistics_get_bitrate(statsHandle);
      final speed = ffmpeg.ffmpeg_kit_statistics_get_speed(statsHandle);

      return Statistics(
        sessionId,
        timeMs,
        size,
        bitrate,
        speed,
        videoFrameNumber,
        videoFps,
        videoQuality,
      );
    } finally {
      // Release after extraction, even if a getter call threw.
      ffmpeg.ffmpeg_kit_handle_release(statsHandle);
    }
  }

  // ---- Cancellation -------------------------------------------------------

  /// Requests cancellation of this session.
  ///
  /// Has no effect if the session has already completed, failed, or been
  /// previously cancelled.
  void cancel() {
    FFmpegKitExtended.requireInitialized();
    // Take a consistent snapshot before evaluating the guard.
    final currentState = getState();
    final currentReturnCode = getReturnCode();

    if (currentState == SessionState.completed ||
        currentState == SessionState.failed ||
        ReturnCode.isCancel(currentReturnCode) ||
        _isCancelled) {
      return;
    }

    ffmpeg.ffmpeg_kit_cancel_session(sessionId);
    _isCancelled = true;
  }

  // ---- Session-type identity ----------------------------------------------
  //
  // Default implementations delegate to the C layer.  Concrete subclasses
  // override these with constant `true`/`false` returns to avoid unnecessary
  // FFI calls in the common case where the Dart type is already known.

  /// Returns `true` if this session is an [FFmpegSession].
  bool isFFmpegSession() {
    FFmpegKitExtended.requireInitialized();
    return ffmpeg.session_is_ffmpeg_session(handle);
  }

  /// Returns `true` if this session is an [FFplaySession].
  bool isFFplaySession() {
    FFmpegKitExtended.requireInitialized();
    return ffmpeg.session_is_ffplay_session(handle);
  }

  /// Returns `true` if this session is an [FFprobeSession].
  bool isFFprobeSession() {
    FFmpegKitExtended.requireInitialized();
    return ffmpeg.session_is_ffprobe_session(handle);
  }

  /// Returns `true` if this session is a [MediaInformationSession].
  bool isMediaInformationSession() {
    FFmpegKitExtended.requireInitialized();
    return ffmpeg.session_is_media_information_session(handle);
  }

  // ---- Debug log ----------------------------------------------------------

  /// Enables per-session debug logging in the C layer.
  void enableDebugLog() {
    FFmpegKitExtended.requireInitialized();
    ffmpeg.session_enable_debug_log(handle);
  }

  /// Disables per-session debug logging in the C layer.
  void disableDebugLog() {
    FFmpegKitExtended.requireInitialized();
    ffmpeg.session_disable_debug_log(handle);
  }

  /// Returns `true` if per-session debug logging is currently enabled.
  bool isDebugLogEnabled() {
    FFmpegKitExtended.requireInitialized();
    return ffmpeg.session_is_debug_log_enabled(handle);
  }

  /// Returns the accumulated debug log for this session, or an empty string
  /// if none is available.
  String getDebugLog() {
    FFmpegKitExtended.requireInitialized();
    return _toDartStringAndFree(ffmpeg.session_get_debug_log(handle)) ?? '';
  }

  /// Clears the accumulated debug log in the C layer.
  void clearDebugLog() {
    FFmpegKitExtended.requireInitialized();
    ffmpeg.session_clear_debug_log(handle);
  }

  // ---- Private helpers ----------------------------------------------------

  /// Copies a heap-allocated `char*` from the C layer into a Dart [String]
  /// and immediately frees the native memory via `ffmpeg_kit_free`.
  ///
  /// Returns `null` when [ptr] is the null pointer, allowing callers to
  /// distinguish "no value" from an empty string.
  String? _toDartStringAndFree(Pointer<Char> ptr) {
    FFmpegKitExtended.requireInitialized();
    if (ptr == nullptr) return null;
    final result = ptr.cast<Utf8>().toDartString();
    ffmpeg.ffmpeg_kit_free(ptr.cast());
    return result;
  }
}
