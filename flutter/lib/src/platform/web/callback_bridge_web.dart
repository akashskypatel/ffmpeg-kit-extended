import 'dart:developer' as developer;
import 'dart:js_interop';

import '../../callback_manager.dart';
import '../../generated/ffmpeg_kit_bindings_web.dart' as bindings;

void _onFFmpegComplete(JSBigInt sessionId, int userData) {
  _dispatch('FFmpeg completion', () {
    CallbackManager().dispatchFFmpegComplete(sessionId.toDart.toInt());
  });
}

void _onFFmpegLog(JSBigInt sessionId, int logPointer, int userData) {
  if (logPointer == 0) return;
  _dispatch('FFmpeg log', () {
    CallbackManager().dispatchPendingLogs(sessionId.toDart.toInt());
  });
}

void _onFFmpegStatistics(
  JSBigInt sessionId,
  JSBigInt timeElapsed,
  JSBigInt time,
  JSBigInt size,
  double bitrate,
  double speed,
  JSBigInt videoFrameNumber,
  double videoFps,
  double videoQuality,
  JSBigInt dupFrames,
  JSBigInt dropFrames,
  int userData,
) {
  _dispatch('FFmpeg statistics', () {
    CallbackManager().dispatchStatistics(
      sessionId: sessionId.toDart.toInt(),
      timeElapsed: timeElapsed.toDart.toInt(),
      time: time.toDart.toInt(),
      size: size.toDart.toInt(),
      bitrate: bitrate,
      speed: speed,
      videoFrameNumber: videoFrameNumber.toDart.toInt(),
      videoFps: videoFps,
      videoQuality: videoQuality,
      dupFrames: dupFrames.toDart.toInt(),
      dropFrames: dropFrames.toDart.toInt(),
    );
  });
}

void _onFFprobeComplete(JSBigInt sessionId, int userData) {
  _dispatch('FFprobe completion', () {
    CallbackManager().dispatchFFprobeComplete(sessionId.toDart.toInt());
  });
}

void _onMediaInformationComplete(JSBigInt sessionId, int userData) {
  _dispatch('Media-information completion', () {
    CallbackManager().dispatchMediaInformationComplete(
      sessionId.toDart.toInt(),
    );
  });
}

void _onFFplayComplete(JSBigInt sessionId, int userData) {
  _dispatch('FFplay completion', () {
    CallbackManager().dispatchFFplayComplete(sessionId.toDart.toInt());
  });
}

void _dispatch(String event, void Function() callback) {
  try {
    callback();
  } catch (error, stackTrace) {
    developer.log(
      'WebCallbackBridge: failed to dispatch $event',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Owns the Web-generated callback values passed to the C ABI.
///
/// Function pointers are created lazily because `NativeLibrary.instance` is
/// populated by the Web Wasm loader during initialization. The pointers are retained
/// for the lifetime of the bridge because the C runtime stores them globally.
final class WebCallbackBridge {
  bool _disposed = false;

  bindings.DartFFmpegKitGlobalCompleteCallback? _ffmpegComplete;
  bindings.DartFFprobeKitGlobalCompleteCallback? _ffprobeComplete;
  bindings.DartFFmpegKitGlobalLogCallback? _log;
  bindings.DartFFmpegKitGlobalStatisticsCallback? _statistics;
  bindings.DartFFplayKitGlobalCompleteCallback? _ffplayComplete;
  bindings.DartMediaInformationSessionGlobalCompleteCallback?
  _mediaInformationComplete;

  bindings.DartFFmpegKitGlobalCompleteCallback get ffmpegComplete {
    _checkActive();
    return _ffmpegComplete ??= bindings
        .addFunction<bindings.DartFFmpegKitGlobalCompleteCallbackFunction>(
          _onFFmpegComplete.toJS,
          'vjp',
        )
        .cast();
  }

  bindings.DartFFprobeKitGlobalCompleteCallback get ffprobeComplete {
    _checkActive();
    return _ffprobeComplete ??= bindings
        .addFunction<bindings.DartFFprobeKitGlobalCompleteCallbackFunction>(
          _onFFprobeComplete.toJS,
          'vjp',
        )
        .cast();
  }

  bindings.DartFFmpegKitGlobalLogCallback get log {
    _checkActive();
    return _log ??= bindings
        .addFunction<bindings.DartFFmpegKitGlobalLogCallbackFunction>(
          _onFFmpegLog.toJS,
          'vjpp',
        )
        .cast();
  }

  bindings.DartFFmpegKitGlobalStatisticsCallback get statistics {
    _checkActive();
    return _statistics ??= bindings
        .addFunction<bindings.DartFFmpegKitGlobalStatisticsCallbackFunction>(
          _onFFmpegStatistics.toJS,
          'vjjjjddjddjjp',
        )
        .cast();
  }

  bindings.DartFFplayKitGlobalCompleteCallback get ffplayComplete {
    _checkActive();
    return _ffplayComplete ??= bindings
        .addFunction<bindings.DartFFplayKitGlobalCompleteCallbackFunction>(
          _onFFplayComplete.toJS,
          'vjp',
        )
        .cast();
  }

  bindings.DartMediaInformationSessionGlobalCompleteCallback
  get mediaInformationComplete {
    _checkActive();
    return _mediaInformationComplete ??= bindings
        .addFunction<
          bindings.DartMediaInformationSessionGlobalCompleteCallbackFunction
        >(_onMediaInformationComplete.toJS, 'vjp')
        .cast();
  }

  void _checkActive() {
    if (_disposed) {
      throw StateError('The Web callback bridge has been disposed.');
    }
  }

  /// Disables new native callback registrations.
  ///
  /// Callback table slots are intentionally retained for the lifetime of the
  /// loaded Wasm module. Disabling the C registrations does not drain events
  /// already accepted by the native callback queue, so removing the slots here
  /// would permit a queued event to call a recycled function-table entry.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final nullCallback = nullPointer;
    bindings.ffmpeg_kit_config_enable_log_callback(
      nullCallback.cast(),
      nullCallback,
    );
    bindings.ffmpeg_kit_config_enable_statistics_callback(
      nullCallback.cast(),
      nullCallback,
    );
    bindings.ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
      nullCallback.cast(),
      nullCallback,
    );
    bindings.ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
      nullCallback.cast(),
      nullCallback,
    );
    bindings.ffmpeg_kit_config_enable_ffplay_session_complete_callback(
      nullCallback.cast(),
      nullCallback,
    );
    bindings
        .ffmpeg_kit_config_enable_media_information_session_complete_callback(
          nullCallback.cast(),
          nullCallback,
        );
  }

  // Compatibility values for the legacy Web API. The shared backend above
  // never uses these; the legacy API is removed by the public-API migration.
  @Deprecated('Use the generated callback pointers on the shared backend.')
  bindings.DartFFmpegKitCompleteCallback get nullFFmpegComplete =>
      const bindings.Pointer<
        bindings.NativeFunction<bindings.FFmpegKitCompleteCallbackFunction>
      >.fromAddress(0);

  @Deprecated('Use the generated callback pointers on the shared backend.')
  bindings.DartFFprobeKitCompleteCallback get nullFFprobeComplete =>
      const bindings.Pointer<
        bindings.NativeFunction<bindings.FFprobeKitCompleteCallbackFunction>
      >.fromAddress(0);

  bindings.Pointer<bindings.Void> get nullPointer =>
      const bindings.Pointer<bindings.Void>.fromAddress(0);
}

final webCallbackBridge = WebCallbackBridge();
