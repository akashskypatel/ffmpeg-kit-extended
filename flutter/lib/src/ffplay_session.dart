/// FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
/// Copyright (C) 2026 Akash Patel
///
/// This library is free software; you can redistribute it and/or
/// modify it under the terms of the GNU Lesser General Public
/// License as published by the Free Software Foundation; either
/// version 2.1 of the License, or (at your option) any later version.
///
/// This library is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
/// Lesser General Public License for more details.
///
/// You should have received a copy of the GNU Lesser General Public
/// License along with this library; if not, write to the Free Software
/// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
library;

import 'dart:async';
import 'dart:developer';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffmpeg_kit_extended_flutter.dart';
import 'callback_manager.dart';
import 'generated/ffmpeg_kit_bindings.dart' as ffmpeg;

/// Session for playing media using FFplay.
///
/// Provides methods to control playback (start, pause, resume, stop, seek)
/// and query/playback properties such as position and volume.
///
/// ### Lifecycle
/// Use [FFplayKit] to create and execute sessions for global tracking.
/// Deprecated static helpers still work but bypass tracking.
class FFplaySession extends Session {
  FFplaySessionCompleteCallback? _completeCallback;

  bool _registered = false;

  int _timeout;

  StreamController<double> _positionController =
      StreamController<double>.broadcast();
  Timer? _positionTimer;
  Timer? _positionSyncTimer;
  double _syncedPos = 0.0;
  double _cachedDuration = 0.0;
  bool _locallyPlaying = false;
  final Stopwatch _positionStopwatch = Stopwatch();

  // Set by seek() so the sync timer knows the next backwards move is
  // intentional and should be accepted rather than treated as jitter.
  bool _seekPending = false;

  // High-water mark for emitted positions — prevents apparent backwards
  // motion when the sync timer reanchors _syncedPos to a value that the
  // clamp had previously hidden from the output.  Reset on seek and stream start.
  double _lastEmittedPos = 0.0;

  // Last known valid volume (0.0–1.0).  Seeded to 1.0 because FFplay's
  // default startup_volume is 100 %.  Updated on every successful native
  // read and on every setVolume call so that getVolume() returns a
  // meaningful value even before the native context is ready (or after it
  // has been torn down).
  double _cachedVolume = 1.0;

  // Adaptive emit-rate state
  static const int _emitMinMs = 16; // ~60 fps ceiling
  static const int _emitMaxMs = 100; // 10 fps floor
  static const int _emitStepMs = 16; // step size when adapting
  int _currentEmitMs = _emitMinMs;
  int _lateCount = 0;
  int _onTimeCount = 0;
  // Separate stopwatch for emit lateness measurement so it is not disturbed
  // by the sync timer resetting _positionStopwatch.
  final Stopwatch _emitStopwatch = Stopwatch();

  StreamController<(int, int)> _videoSizeController =
      StreamController<(int, int)>.broadcast();
  Timer? _videoSizeTimer;

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Restores an [FFplaySession] from existing native [handle].
  /// Used internally when wrapping handles from session-history API.
  /// No callbacks registered; call [setCompleteCallback] if needed.
  FFplaySession.fromHandle(Pointer<Void> handle, String command)
    : _timeout = 500 {
    FFmpegKitExtended.requireInitialized();
    this.handle = handle;
    this.command = command;
    try {
      sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffmpeg_kit_session_get_session_id',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    registerFinalizer();
  }

  /// Creates a new [FFplaySession] for [command].
  /// **Prefer [FFplayKit.createSession]** for proper global tracking.
  /// - [completeCallback]: Invoked once when playback ends.
  /// - [timeout]: Connection timeout in milliseconds (default 500).
  FFplaySession(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) : _timeout = timeout {
    FFmpegKitExtended.requireInitialized();
    // toNativeUtf8 uses the calloc allocator by default.
    final cmdPtr = command.toNativeUtf8(allocator: calloc);
    try {
      try {
        handle = ffmpeg.ffplay_kit_create_session(cmdPtr.cast());
      } catch (e, st) {
        log(
          'FFplaySession: error in native function ffplay_kit_create_session',
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
      this.command = command;
      try {
        sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
      } catch (e, st) {
        log(
          'FFplaySession: error in native function ffmpeg_kit_session_get_session_id',
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
      registerFinalizer();
    } finally {
      calloc.free(cmdPtr); // must match the allocator used by toNativeUtf8
    }

    _completeCallback = completeCallback;

    CallbackManager().registerFFplaySession(this);
    _registered = true;
  }

  // ---------------------------------------------------------------------------
  // Static helpers (deprecated wrappers for API compatibility)
  // ---------------------------------------------------------------------------

  /// @deprecated Use [FFplayKit.createSession] for proper global tracking.
  @Deprecated(
    'Use FFplayKit.createSession for proper global session management',
  )
  static FFplaySession create(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) => FFplaySession(
    command,
    timeout: timeout,
    completeCallback: completeCallback,
  );

  /// Internal factory used by [FFplayKit] — not part of the public API.
  static FFplaySession createGlobal(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) => FFplaySession(
    command,
    timeout: timeout,
    completeCallback: completeCallback,
  );

  // ---------------------------------------------------------------------------
  // Callback accessors / mutators
  // ---------------------------------------------------------------------------

  /// The callback invoked once when playback ends.
  FFplaySessionCompleteCallback? get completeCallback => _completeCallback;

  /// Sets or replaces the completion callback.
  void setCompleteCallback(FFplaySessionCompleteCallback? completeCallback) {
    _completeCallback = completeCallback;
    _ensureRegistered();
  }

  /// Clears completion callback and unregisters session from
  /// [CallbackManager] if no other callbacks remain.
  void removeCompleteCallback() {
    _completeCallback = null;
    _unregister();
  }

  // ---------------------------------------------------------------------------
  // Playback configuration
  // ---------------------------------------------------------------------------

  /// The connection timeout in milliseconds.
  int get timeout => _timeout;

  /// Sets the connection [timeout] in milliseconds.
  void setTimeout(int timeout) => _timeout = timeout;

  // ---------------------------------------------------------------------------
  // Playback controls
  // ---------------------------------------------------------------------------

  /// Starts playback.
  void start() {
    FFmpegKitExtended.requireInitialized();
    try {
      ffmpeg.ffplay_kit_session_start(handle);
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_start',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Pauses playback.
  void pause() {
    FFmpegKitExtended.requireInitialized();
    try {
      ffmpeg.ffplay_kit_session_pause(handle);
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_pause',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    try {
      final pausePos = ffmpeg.ffplay_kit_session_get_position(handle);
      _syncedPos = pausePos.isNaN ? _lastEmittedPos : pausePos;
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_get_position',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    _positionStopwatch.reset();
    _locallyPlaying = false;
  }

  /// Resumes paused playback.
  void resume() {
    FFmpegKitExtended.requireInitialized();
    try {
      ffmpeg.ffplay_kit_session_resume(handle);
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_resume',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    try {
      final resumePos = ffmpeg.ffplay_kit_session_get_position(handle);
      _syncedPos = resumePos.isNaN ? _lastEmittedPos : resumePos;
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_get_position',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    _positionStopwatch.reset();
    _locallyPlaying = true;
  }

  /// Stops playback.
  void stop() {
    FFmpegKitExtended.requireInitialized();
    try {
      ffmpeg.ffplay_kit_session_stop(handle);
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_stop',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Closes the session and releases native resources.
  void close() {
    FFmpegKitExtended.requireInitialized();
    try {
      ffmpeg.ffplay_kit_session_close(handle);
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_close',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Cancels session — stops playback then delegates to [Session.cancel].
  @override
  void cancel() {
    stop();
    super.cancel();
  }

  /// Seeks to [seconds] from the start of the media.
  void seek(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) return;
    FFmpegKitExtended.requireInitialized();
    try {
      ffmpeg.ffplay_kit_session_seek(handle, seconds);
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_seek',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    // Optimistically update local position so interpolation restarts from the
    // seek target immediately, before the next native sync fires.
    _syncedPos = seconds.clamp(
      0.0,
      _cachedDuration > 0 ? _cachedDuration : seconds,
    );
    _lastEmittedPos = _syncedPos;
    _positionStopwatch.reset();
    // Allow the next sync tick to accept a lower native value if the seek
    // target is earlier than the current position.
    _seekPending = true;
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  /// Enqueues session for synchronous native execution and returns `this` immediately.
  FFplaySession execute() {
    SessionQueueManager()
        .executeSession(this, () async {
          FFmpegKitExtended.requireInitialized();
          try {
            ffmpeg.ffplay_kit_session_execute(handle, _timeout);
          } catch (e, st) {
            log(
              'FFplaySession: error in native function ffplay_kit_session_execute',
              error: e,
              stackTrace: st,
            );
            rethrow;
          }
          try {
            _completeCallback?.call(this);
          } catch (e, st) {
            log('FFplaySession.execute: error in completeCallback: $e\n$st');
            rethrow;
          }
          _unregister();
        })
        .catchError((Object e, StackTrace st) {
          log('FFplaySession.execute: queue error: $e\n$st');
        });
    return this;
  }

  /// @deprecated Use [FFplayKit.execute] for proper global session management.
  @Deprecated('Use FFplayKit.execute for proper global session management')
  static FFplaySession executeCommand(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) => FFplaySession.create(
    command,
    timeout: timeout,
    completeCallback: completeCallback,
  ).execute();

  /// @deprecated Use [FFplayKit.executeAsync] for proper global session management.
  @Deprecated('Use FFplayKit.executeAsync for proper global session management')
  static Future<FFplaySession> executeCommandAsync(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) => FFplaySession.create(
    command,
    timeout: timeout,
    completeCallback: completeCallback,
  ).executeAsync();

  /// Executes this session asynchronously and returns a [Future] that
  /// resolves once playback finishes or is cancelled.
  Future<FFplaySession> executeAsync({
    int? timeout,
    FFplaySessionCompleteCallback? completeCallback,
  }) async {
    if (timeout != null) _timeout = timeout;
    if (completeCallback != null) _completeCallback = completeCallback;
    _ensureRegistered();

    await SessionQueueManager().executeSession(this, _runAsync);
    return this;
  }

  // ---------------------------------------------------------------------------
  // Playback properties
  // ---------------------------------------------------------------------------

  /// Returns the total duration of the media in seconds.
  double getMediaDuration() {
    FFmpegKitExtended.requireInitialized();
    try {
      final d = ffmpeg.ffplay_kit_session_get_duration(handle);
      return d;
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_get_duration',
        error: e,
        stackTrace: st,
      );
      return 0.0;
    }
  }

  /// Returns the current playback position in seconds.
  double getPosition() {
    FFmpegKitExtended.requireInitialized();
    try {
      final p = ffmpeg.ffplay_kit_session_get_position(handle);
      return p;
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_get_position',
        error: e,
        stackTrace: st,
      );
      return 0.0;
    }
  }

  /// Seeks to [seconds] from the start of the media.
  void setPosition(double seconds) {
    FFmpegKitExtended.requireInitialized();
    try {
      ffmpeg.ffplay_kit_session_set_position(handle, seconds);
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_set_position',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns current playback volume in range [0.0, 1.0].
  /// Falls back to the last known value (default 1.0) when the native
  /// context is not yet ready or has already been torn down.
  double getVolume() {
    FFmpegKitExtended.requireInitialized();
    // ffplay_get_volume already normalizes to 0.0–1.0 by dividing by
    // SDL_MIX_MAXVOLUME internally — do NOT divide again here.
    // Native returns -1.0 as a sentinel when the context is not yet ready
    // (or has been torn down); any value >= 0 is a real reading, including 0.0
    // for a legitimately muted session.
    try {
      final v = ffmpeg.ffplay_kit_session_get_volume(handle);
      if (v >= 0) _cachedVolume = v;
      return _cachedVolume;
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_get_volume',
        error: e,
        stackTrace: st,
      );
      return _cachedVolume;
    }
  }

  /// Sets playback [volume] in range [0.0, 1.0].
  /// Values outside range are clamped to prevent SDL audio distortion.
  void setVolume(double volume) {
    FFmpegKitExtended.requireInitialized();
    final clamped = volume.clamp(0.0, 1.0);
    _cachedVolume = clamped;
    // The FF_PLAY_VOLUME_EVENT handler in ffplay_lib.c interprets the value
    // as a 0.0–1.0 fraction (multiplies by 100 to get a percentage).
    // Do NOT pre-scale to SDL_MIX_MAXVOLUME (0–128) here.
    try {
      ffmpeg.ffplay_kit_session_set_volume(handle, clamped);
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_set_volume',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns `true` if the media is currently playing.
  bool isPlaying() {
    FFmpegKitExtended.requireInitialized();
    try {
      final playing = ffmpeg.ffplay_kit_session_is_playing(handle);
      return playing;
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_is_playing',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Returns the current video width in pixels, or 0 if not yet known.
  int getVideoWidth() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpeg.ffplay_kit_session_get_video_width(handle);
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_get_video_width',
        error: e,
        stackTrace: st,
      );
      return 0;
    }
  }

  /// Returns the current video height in pixels, or 0 if not yet known.
  int getVideoHeight() {
    FFmpegKitExtended.requireInitialized();
    try {
      return ffmpeg.ffplay_kit_session_get_video_height(handle);
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_get_video_height',
        error: e,
        stackTrace: st,
      );
      return 0;
    }
  }

  /// Returns `true` if the media is currently paused.
  bool isPaused() {
    FFmpegKitExtended.requireInitialized();
    try {
      final paused = ffmpeg.ffplay_kit_session_is_paused(handle);
      return paused;
    } catch (e, st) {
      log(
        'FFplaySession: error in native function ffplay_kit_session_is_paused',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Session type identity
  // ---------------------------------------------------------------------------

  /// Returns true if this is an FFmpeg session.
  @override
  bool isFFmpegSession() => false;

  /// Returns true if this is an FFplay session.
  @override
  bool isFFplaySession() => true;

  /// Returns true if this is an FFprobe session.
  @override
  bool isFFprobeSession() => false;

  /// Returns true if this is a media information session.
  @override
  bool isMediaInformationSession() => false;

  // ---------------------------------------------------------------------------
  // Position stream
  // ---------------------------------------------------------------------------

  /// Stream of playback positions in seconds, polled every 200 ms by default.
  /// Subscribe before calling [executeAsync]. Stream emits positions at
  /// configured interval and closes automatically when playback ends.
  Stream<double> get positionStream => _positionController.stream;

  /// Stream of `(width, height)` video dimension records, polled every 500 ms.
  /// Emits new value only when dimensions change (e.g., when first frame
  /// is decoded and video size becomes known). Closes when playback ends.
  /// Subscribe before calling [executeAsync] to receive initial dimensions.
  Stream<(int, int)> get videoSizeStream => _videoSizeController.stream;

  // ---------------------------------------------------------------------------
  // Private implementation
  // ---------------------------------------------------------------------------

  /// Core async execution body, called by [executeAsync] through the queue.
  Future<void> _runAsync() async {
    final sessionCompleter = Completer<void>();
    final userCompleteCallback = _completeCallback;

    _completeCallback = (FFplaySession s) {
      try {
        userCompleteCallback?.call(s);
      } catch (e, st) {
        log('FFplaySession: error in completeCallback: $e\n$st');
        rethrow;
      }
      if (!sessionCompleter.isCompleted) sessionCompleter.complete();
      _unregister();
      _stopPositionStream();
      _stopVideoSizeStream();
    };

    try {
      ffmpeg.ffmpeg_kit_config_enable_ffplay_session_complete_callback(
        nativeFFplayComplete.nativeFunction,
        nullptr,
      );
    } catch (e, st) {
      log('FFplaySession: error enabling complete callback: $e\n$st');
      _completeCallback = userCompleteCallback;
      _unregister();
      _stopPositionStream();
      _stopVideoSizeStream();
      if (!sessionCompleter.isCompleted) sessionCompleter.complete();
      rethrow;
    }

    try {
      ffmpeg.ffplay_kit_session_execute_async(handle, _timeout);
    } catch (e, st) {
      log(
        'FFplaySession: error starting async session ffplay_kit_session_execute_async $sessionId',
        error: e,
        stackTrace: st,
      );
      _completeCallback = userCompleteCallback;
      _unregister();
      _stopPositionStream();
      _stopVideoSizeStream();
      if (!sessionCompleter.isCompleted) sessionCompleter.complete();
      rethrow;
    }

    // Start polling only after the native session is executing so timers never
    // fire against a not-yet-started session during SessionQueueManager delays.
    _startPositionStream();
    _startVideoSizeStream();

    await sessionCompleter.future;
  }

  /// Ensures session is registered with the callback manager.
  void _ensureRegistered() {
    if (_registered) return;
    CallbackManager().registerFFplaySession(this);
    _registered = true;
  }

  /// Unregisters session from the callback manager.
  void _unregister() {
    if (!_registered) return;
    _registered = false;
    CallbackManager().unregisterFFplaySession(sessionId);
  }

  /// Starts the position stream.
  ///
  /// Emits interpolated position at an adaptive rate (starting at ~60 fps,
  /// backing off toward 10 fps if the event loop is saturated) by advancing a
  /// local [Stopwatch] since the last native sync.  A separate
  /// [Timer.periodic] calls the native layer every [syncMs] milliseconds
  /// (default 200 ms) to correct for drift from buffering stalls or seeks.
  ///
  /// The emit timer is a recursive [Timer] (not [Timer.periodic]) so its
  /// interval can be adjusted without cancelling and recreating from outside.
  /// Lateness is measured by comparing the wall-clock gap between consecutive
  /// fires against the scheduled interval.  Three consecutive late fires step
  /// the interval up by [_emitStepMs]; five consecutive on-time fires step it
  /// back down, with hysteresis to prevent thrashing.
  void _startPositionStream({int syncMs = 200}) {
    _positionTimer?.cancel();
    _positionSyncTimer?.cancel();
    if (_positionController.isClosed) {
      _positionController = StreamController<double>.broadcast();
    }

    // Initial ground truth.  Guard NaN in case the native context isn't ready
    // yet (e.g., called before the first frame is decoded).  A NaN here would
    // poison _lastEmittedPos and cause ArgumentError inside .clamp() later.
    try {
      _syncedPos = ffmpeg.ffplay_kit_session_get_position(handle);
    } catch (e, st) {
      log(
        'FFplaySession: error getting position ffplay_kit_session_get_position $sessionId',
        error: e,
        stackTrace: st,
      );
      _syncedPos = 0.0;
    }
    if (_syncedPos.isNaN) _syncedPos = 0.0;
    try {
      _cachedDuration = ffmpeg.ffplay_kit_session_get_duration(handle);
    } catch (e, st) {
      log(
        'FFplaySession: error getting duration ffplay_kit_session_get_duration $sessionId',
        error: e,
        stackTrace: st,
      );
      _cachedDuration = 0;
    }
    try {
      _locallyPlaying = ffmpeg.ffplay_kit_session_is_playing(handle);
    } catch (e, st) {
      log(
        'FFplaySession: error checking playing state ffplay_kit_session_is_playing $sessionId',
        error: e,
        stackTrace: st,
      );
      _locallyPlaying = false;
    }
    _lastEmittedPos = _syncedPos;
    _positionStopwatch
      ..reset()
      ..start();
    _emitStopwatch
      ..reset()
      ..start();
    _currentEmitMs = _emitMinMs;
    _lateCount = 0;
    _onTimeCount = 0;

    // Periodic native sync — corrects drift at low, fixed overhead.
    _positionSyncTimer = Timer.periodic(Duration(milliseconds: syncMs), (_) {
      final prevPos = _syncedPos;
      final prevPlaying = _locallyPlaying;
      double newPos;
      bool newPlaying;
      try {
        newPos = ffmpeg.ffplay_kit_session_get_position(handle);
        newPlaying = ffmpeg.ffplay_kit_session_is_playing(handle);
      } catch (e, st) {
        log(
          'FFplaySession: error getting position or playing state ffplay_kit_session_get_position/ffplay_kit_session_is_playing $sessionId',
          error: e,
          stackTrace: st,
        );
        return;
      }

      // Duration is unavailable until the file is opened by the native layer.
      // Keep retrying until we get a valid value so the Dart clamp activates.
      if (_cachedDuration <= 0.0 || _cachedDuration.isNaN) {
        try {
          _cachedDuration = ffmpeg.ffplay_kit_session_get_duration(handle);
        } catch (e, st) {
          log(
            'FFplaySession: error getting duration ffplay_kit_session_get_duration $sessionId',
            error: e,
            stackTrace: st,
          );
          _cachedDuration = 0.0;
        }
      }

      // During seek the native clock is undefined; FFplay reports nan.
      // Skip the entire update to avoid poisoning _syncedPos.
      if (newPos.isNaN) return;

      _locallyPlaying = newPlaying;

      if (prevPlaying && !newPlaying) {
        // Playback just ended. The native context may already have reset to 0;
        // freeze at duration so the UI lands on the final frame, not the start.
        _syncedPos = _cachedDuration > 0.0 ? _cachedDuration : prevPos;
      } else if (_seekPending || newPos >= _syncedPos) {
        // Normal forward progress, or a user seek allows backwards movement.
        _syncedPos = newPos;
        _seekPending = false;
      } else {
        // Native position went backwards without a seek — clock jitter near
        // EOF or a buffer stall. Ignore and keep the last good position.
      }

      _positionStopwatch.reset();
    });

    // Adaptive recursive emit timer.
    void scheduleEmit() {
      _emitStopwatch.reset();
      _positionTimer = Timer(Duration(milliseconds: _currentEmitMs), () {
        if (_positionController.isClosed) return;

        // Measure lateness against _emitStopwatch, which is independent of
        // the sync timer and only reset at the start of each emit tick.
        final actualMs = _emitStopwatch.elapsedMilliseconds;
        final thresholdMs = (_currentEmitMs * 1.5).round();

        if (actualMs > thresholdMs) {
          _lateCount++;
          _onTimeCount = 0;
          if (_lateCount >= 3) {
            // Event loop is struggling — step down emit rate.
            _currentEmitMs = (_currentEmitMs + _emitStepMs).clamp(
              _emitMinMs,
              _emitMaxMs,
            );
            _lateCount = 0;
          }
        } else {
          _onTimeCount++;
          _lateCount = 0;
          if (_onTimeCount >= 5 && _currentEmitMs > _emitMinMs) {
            // Event loop recovered — step back up, with hysteresis.
            _currentEmitMs = (_currentEmitMs - _emitStepMs).clamp(
              _emitMinMs,
              _emitMaxMs,
            );
            _onTimeCount = 0;
          }
        }

        // Interpolate position locally between native syncs.
        final rawPos =
            _syncedPos +
            (_locallyPlaying
                ? _positionStopwatch.elapsed.inMicroseconds / 1e6
                : 0.0);
        // Skip emit if rawPos is NaN (defensive guard — sync timer normally
        // catches nan from the native layer, but guard here as a safety net).
        if (rawPos.isNaN) {
          scheduleEmit();
          return;
        }
        final clamped = _cachedDuration > 0.0 && rawPos > _cachedDuration;
        // Apply high-water mark: never emit a value lower than what was
        // previously emitted.  This prevents apparent backwards jitter when
        // the sync timer reanchors _syncedPos to a native value that the
        // duration clamp had already masked from the output.
        final pos = (clamped ? _cachedDuration : rawPos).clamp(
          _lastEmittedPos,
          double.infinity,
        );
        _lastEmittedPos = pos;

        _positionController.add(pos);

        scheduleEmit();
      });
    }

    scheduleEmit();
  }

  /// Cancels both timers and closes [positionStream].
  void _stopPositionStream() {
    _positionTimer?.cancel();
    _positionTimer = null;
    _positionSyncTimer?.cancel();
    _positionSyncTimer = null;
    _positionStopwatch.stop();
    _emitStopwatch.stop();
    if (!_positionController.isClosed) _positionController.close();
  }

  /// Starts polling [getVideoWidth]/[getVideoHeight] every 500 ms and pushes
  /// `(width, height)` onto [videoSizeStream] whenever dimensions change.
  void _startVideoSizeStream({int intervalMs = 500}) {
    _videoSizeTimer?.cancel();
    if (_videoSizeController.isClosed) {
      _videoSizeController = StreamController<(int, int)>.broadcast();
    }
    int lastW = 0, lastH = 0;
    _videoSizeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      int w;
      int h;
      try {
        w = ffmpeg.ffplay_kit_session_get_video_width(handle);
        h = ffmpeg.ffplay_kit_session_get_video_height(handle);
      } catch (e, st) {
        log(
          'FFplaySession: error getting video width or height ffplay_kit_session_get_video_width/ffplay_kit_session_get_video_height $sessionId',
          error: e,
          stackTrace: st,
        );
        return;
      }
      if ((w != lastW || h != lastH) && w > 0 && h > 0) {
        lastW = w;
        lastH = h;
        if (!_videoSizeController.isClosed) _videoSizeController.add((w, h));
      }
    });
  }

  /// Cancels video-size polling timer and closes [videoSizeStream].
  void _stopVideoSizeStream() {
    _videoSizeTimer?.cancel();
    _videoSizeTimer = null;
    if (!_videoSizeController.isClosed) _videoSizeController.close();
  }
}
