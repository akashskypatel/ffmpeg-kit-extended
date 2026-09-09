import 'dart:developer' as developer;
import 'dart:js_interop';

import '../../callback_manager.dart';
import '../../generated/ffmpeg_kit_bindings_web.dart' as bindings;

void _onFFmpegComplete(
  bindings.DartFFmpegSessionHandle sessionHandle,
  bindings.Pointer<bindings.Void> userData,
) {
  _dispatch('FFmpeg completion', () {
    CallbackManager().dispatchFFmpegComplete(_sessionId(sessionHandle));
  });
}

void _onFFmpegLog(
  bindings.DartFFmpegSessionHandle sessionHandle,
  bindings.Pointer<bindings.Char> logPointer,
  bindings.Pointer<bindings.Void> userData,
) {
  if (logPointer.address == 0) return;
  _dispatch('FFmpeg log', () {
    CallbackManager().dispatchPendingLogs(_sessionId(sessionHandle));
  });
}

void _onFFmpegStatistics(
  bindings.DartFFmpegSessionHandle sessionHandle,
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
  bindings.Pointer<bindings.Void> userData,
) {
  _dispatch('FFmpeg statistics', () {
    CallbackManager().dispatchStatistics(
      sessionId: _sessionId(sessionHandle),
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

void _onFFprobeComplete(
  bindings.DartFFprobeSessionHandle sessionHandle,
  bindings.Pointer<bindings.Void> userData,
) {
  _dispatch('FFprobe completion', () {
    CallbackManager().dispatchFFprobeComplete(_sessionId(sessionHandle));
  });
}

void _onMediaInformationComplete(
  bindings.DartMediaInformationSessionHandle sessionHandle,
  bindings.Pointer<bindings.Void> userData,
) {
  _dispatch('Media-information completion', () {
    CallbackManager().dispatchMediaInformationComplete(
      _sessionId(sessionHandle),
    );
  });
}

void _onFFplayComplete(
  bindings.DartFFplaySessionHandle sessionHandle,
  bindings.Pointer<bindings.Void> userData,
) {
  _dispatch('FFplay completion', () {
    CallbackManager().dispatchFFplayComplete(_sessionId(sessionHandle));
  });
}

int _sessionId(bindings.Pointer<bindings.Void> sessionHandle) {
  if (sessionHandle.address == 0) return 0;
  return bindings.ffmpeg_kit_session_get_session_id(sessionHandle).toInt();
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
  late final bindings.DartFFmpegKitCompleteCallback ffmpegComplete = bindings
      .addFunction<bindings.DartFFmpegKitCompleteCallbackFunction>(
        _onFFmpegComplete.toJS,
        'vpp',
      )
      .cast();

  late final bindings.DartFFprobeKitCompleteCallback ffprobeComplete = bindings
      .addFunction<bindings.DartFFprobeKitCompleteCallbackFunction>(
        _onFFprobeComplete.toJS,
        'vpp',
      )
      .cast();

  late final bindings.DartFFmpegKitLogCallback log = bindings
      .addFunction<bindings.DartFFmpegKitLogCallbackFunction>(
        _onFFmpegLog.toJS,
        'vppp',
      )
      .cast();

  late final bindings.DartFFmpegKitStatisticsCallback statistics = bindings
      .addFunction<bindings.DartFFmpegKitStatisticsCallbackFunction>(
        _onFFmpegStatistics.toJS,
        'vpjjjddjddjjp',
      )
      .cast();

  late final bindings.DartFFplayKitCompleteCallback ffplayComplete = bindings
      .addFunction<bindings.DartFFplayKitCompleteCallbackFunction>(
        _onFFplayComplete.toJS,
        'vpp',
      )
      .cast();

  late final bindings.DartMediaInformationSessionCompleteCallback
  mediaInformationComplete = bindings
      .addFunction<
        bindings.DartMediaInformationSessionCompleteCallbackFunction
      >(_onMediaInformationComplete.toJS, 'vpp')
      .cast();

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
