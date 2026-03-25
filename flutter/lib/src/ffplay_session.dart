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
import 'ffmpeg_kit_flutter_loader.dart';

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

  // Adaptive emit-rate state
  static const int _emitMinMs = 16;   // ~60 fps ceiling
  static const int _emitMaxMs = 100;  // 10 fps floor
  static const int _emitStepMs = 16;  // step size when adapting
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
    sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
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
      handle = ffmpeg.ffplay_kit_create_session(cmdPtr.cast());
      this.command = command;
      sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
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
      'Use FFplayKit.createSession for proper global session management')
  static FFplaySession create(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) =>
      FFplaySession(command,
          timeout: timeout, completeCallback: completeCallback);

  /// Internal factory used by [FFplayKit] — not part of the public API.
  static FFplaySession createGlobal(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) =>
      FFplaySession(command,
          timeout: timeout, completeCallback: completeCallback);

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
    log('FFplaySession.start handle=$handle');
    ffmpeg.ffplay_kit_session_start(handle);
  }

  /// Pauses playback.
  void pause() {
    FFmpegKitExtended.requireInitialized();
    log('FFplaySession.pause handle=$handle');
    ffmpeg.ffplay_kit_session_pause(handle);
    _syncedPos = ffmpeg.ffplay_kit_session_get_position(handle);
    _positionStopwatch.reset();
    _locallyPlaying = false;
  }

  /// Resumes paused playback.
  void resume() {
    FFmpegKitExtended.requireInitialized();
    log('FFplaySession.resume handle=$handle');
    ffmpeg.ffplay_kit_session_resume(handle);
    _syncedPos = ffmpeg.ffplay_kit_session_get_position(handle);
    _positionStopwatch.reset();
    _locallyPlaying = true;
  }

  /// Stops playback.
  void stop() {
    FFmpegKitExtended.requireInitialized();
    log('FFplaySession.stop handle=$handle');
    ffmpeg.ffplay_kit_session_stop(handle);
  }

  /// Closes the session and releases native resources.
  void close() {
    FFmpegKitExtended.requireInitialized();
    log('FFplaySession.close handle=$handle');
    ffmpeg.ffplay_kit_session_close(handle);
  }

  /// Cancels session — stops playback then delegates to [Session.cancel].
  @override
  void cancel() {
    stop();
    super.cancel();
  }

  /// Seeks to [seconds] from the start of the media.
  void seek(double seconds) {
    FFmpegKitExtended.requireInitialized();
    log('FFplaySession.seek handle=$handle seconds=$seconds');
    ffmpeg.ffplay_kit_session_seek(handle, seconds);
    // Optimistically update local position so interpolation restarts from the
    // seek target immediately, before the next native sync fires.
    _syncedPos = seconds.clamp(0.0, _cachedDuration > 0 ? _cachedDuration : seconds);
    _positionStopwatch.reset();
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  /// Enqueues session for synchronous native execution and returns `this` immediately.
  FFplaySession execute() {
    log('FFplaySession.execute handle=$handle');
    SessionQueueManager().executeSession(
      this,
      () async {
        FFmpegKitExtended.requireInitialized();
        ffmpeg.ffplay_kit_session_execute(handle, _timeout);
        try {
          _completeCallback?.call(this);
        } catch (e, st) {
          log('FFplaySession.execute: error in completeCallback: $e\n$st');
        }
        _unregister();
      },
    ).catchError((Object e, StackTrace st) {
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
  }) =>
      FFplaySession.create(command,
              timeout: timeout, completeCallback: completeCallback)
          .execute();

  /// @deprecated Use [FFplayKit.executeAsync] for proper global session management.
  @Deprecated('Use FFplayKit.executeAsync for proper global session management')
  static Future<FFplaySession> executeCommandAsync(
    String command, {
    FFplaySessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) =>
      FFplaySession.create(command,
              timeout: timeout, completeCallback: completeCallback)
          .executeAsync();

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
    final d = ffmpeg.ffplay_kit_session_get_duration(handle);
    log('FFplaySession.getMediaDuration handle=$handle val=$d');
    return d;
  }

  /// Returns the current playback position in seconds.
  double getPosition() {
    FFmpegKitExtended.requireInitialized();
    final p = ffmpeg.ffplay_kit_session_get_position(handle);
    log('FFplaySession.getPosition handle=$handle val=$p');
    return p;
  }

  /// Seeks to [seconds] from the start of the media.
  void setPosition(double seconds) {
    FFmpegKitExtended.requireInitialized();
    log('FFplaySession.setPosition handle=$handle seconds=$seconds');
    ffmpeg.ffplay_kit_session_set_position(handle, seconds);
  }

  /// Returns current playback volume in range [0.0, 1.0].
  /// Native layer stores volume as integer in [0, 128] (SDL_MIX_MAXVOLUME).
  /// This getter normalizes to [0.0, 1.0] for consistent API.
  double getVolume() {
    FFmpegKitExtended.requireInitialized();
    return ffmpeg.ffplay_kit_session_get_volume(handle) / 128.0;
  }

  /// Sets playback [volume] in range [0.0, 1.0].
  /// Values outside range are clamped to prevent SDL audio distortion.
  void setVolume(double volume) {
    FFmpegKitExtended.requireInitialized();
    final clamped = volume.clamp(0.0, 1.0);
    ffmpeg.ffplay_kit_session_set_volume(handle, clamped * 128.0);
  }

  /// Returns `true` if the media is currently playing.
  bool isPlaying() {
    FFmpegKitExtended.requireInitialized();
    final playing = ffmpeg.ffplay_kit_session_is_playing(handle);
    log('FFplaySession.isPlaying handle=$handle val=$playing');
    return playing;
  }

  /// Returns the current video width in pixels, or 0 if not yet known.
  int getVideoWidth() {
    FFmpegKitExtended.requireInitialized();
    return ffmpeg.ffplay_kit_session_get_video_width(handle);
  }

  /// Returns the current video height in pixels, or 0 if not yet known.
  int getVideoHeight() {
    FFmpegKitExtended.requireInitialized();
    return ffmpeg.ffplay_kit_session_get_video_height(handle);
  }

  /// Returns `true` if the media is currently paused.
  bool isPaused() {
    FFmpegKitExtended.requireInitialized();
    final paused = ffmpeg.ffplay_kit_session_is_paused(handle);
    log('FFplaySession.isPaused handle=$handle val=$paused');
    return paused;
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
      }
      if (!sessionCompleter.isCompleted) sessionCompleter.complete();
      _unregister();
      _stopPositionStream();
      _stopVideoSizeStream();
    };

    ffmpeg.ffmpeg_kit_config_enable_ffplay_session_complete_callback(
        nativeFFplayComplete.nativeFunction, nullptr);

    try {
      ffmpeg.ffplay_kit_session_execute_async(handle, _timeout);
    } catch (e, st) {
      log('FFplaySession: error starting async session $sessionId: $e\n$st');
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

    // Initial ground truth.
    _syncedPos = ffmpeg.ffplay_kit_session_get_position(handle);
    _cachedDuration = ffmpeg.ffplay_kit_session_get_duration(handle);
    _locallyPlaying = ffmpeg.ffplay_kit_session_is_playing(handle);
    _positionStopwatch..reset()..start();
    _emitStopwatch..reset()..start();
    _currentEmitMs = _emitMinMs;
    _lateCount = 0;
    _onTimeCount = 0;

    // Periodic native sync — corrects drift at low, fixed overhead.
    _positionSyncTimer = Timer.periodic(Duration(milliseconds: syncMs), (_) {
      _syncedPos = ffmpeg.ffplay_kit_session_get_position(handle);
      _locallyPlaying = ffmpeg.ffplay_kit_session_is_playing(handle);
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
            _currentEmitMs =
                (_currentEmitMs + _emitStepMs).clamp(_emitMinMs, _emitMaxMs);
            _lateCount = 0;
          }
        } else {
          _onTimeCount++;
          _lateCount = 0;
          if (_onTimeCount >= 5 && _currentEmitMs > _emitMinMs) {
            // Event loop recovered — step back up, with hysteresis.
            _currentEmitMs =
                (_currentEmitMs - _emitStepMs).clamp(_emitMinMs, _emitMaxMs);
            _onTimeCount = 0;
          }
        }

        // Interpolate position locally between native syncs.
        double pos = _syncedPos;
        if (_locallyPlaying) {
          pos += _positionStopwatch.elapsed.inMicroseconds / 1e6;
        }
        if (_cachedDuration > 0.0 && pos > _cachedDuration) {
          pos = _cachedDuration;
        }
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
      final w = ffmpeg.ffplay_kit_session_get_video_width(handle);
      final h = ffmpeg.ffplay_kit_session_get_video_height(handle);
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
