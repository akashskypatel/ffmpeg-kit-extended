import 'dart:developer' as developer;
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../callback_manager.dart';
import '../../generated/ffmpeg_kit_bindings_native.dart' as bindings;
import '../callback_log_event.dart';

typedef NativeFFmpegGlobalCompleteCallback =
    Void Function(Int64 sessionId, Pointer<Void>);
typedef NativeFFprobeGlobalCompleteCallback =
    Void Function(Int64 sessionId, Pointer<Void>);
typedef NativeFFplayGlobalCompleteCallback =
    Void Function(Int64 sessionId, Pointer<Void>);
typedef NativeMediaInformationGlobalCompleteCallback =
    Void Function(Int64 sessionId, Pointer<Void>);
typedef NativeFFmpegGlobalLogCallback =
    Void Function(Int64 sessionId, Pointer<Char>, Pointer<Void>);
typedef NativeFFmpegGlobalLogCallbackV2 = Void Function(
  Int64 sessionId,
  Int64 sequence,
  Int32 level,
  Pointer<Char> ownedMessage,
  Pointer<Void> userData,
);
typedef NativeFFmpegGlobalStatisticsCallback =
    Void Function(
      Int64 sessionId,
      Int64,
      Int64,
      Int64,
      Double,
      Double,
      Int64,
      Double,
      Double,
      Int64,
      Int64,
      Pointer<Void>,
    );

void _onFFmpegComplete(int sessionId, Pointer<Void> userData) {
  CallbackManager().dispatchFFmpegComplete(sessionId);
}

void _onFFmpegLog(int sessionId, Pointer<Char> logPtr, Pointer<Void> userData) {
  if (logPtr.address == 0) return;

  if (sessionId > 0) {
    CallbackManager().dispatchPendingLogs(sessionId);
  }
}

void _onFFmpegLogV2(
  int sessionId,
  int sequence,
  int level,
  Pointer<Char> ownedMessage,
  Pointer<Void> userData,
) {
  consumeOwnedLogEvent<Pointer<Char>>(
    payload: ownedMessage,
    isNull: ownedMessage.address == 0,
    decode: (payload) => payload.cast<Utf8>().toDartString(),
    dispatch: (message) => CallbackManager().dispatchDirectLog(
      sessionId: sessionId,
      sequence: sequence,
      level: level,
      message: message,
    ),
    release: (payload) => bindings.ffmpeg_kit_free(payload.cast()),
  );
}

void _onFFmpegStatistics(
  int sessionId,
  int timeElapsed,
  int time,
  int size,
  double bitrate,
  double speed,
  int videoFrameNumber,
  double videoFps,
  double videoQuality,
  int dupFrames,
  int dropFrames,
  Pointer<Void> userData,
) {
  CallbackManager().dispatchStatistics(
    sessionId: sessionId,
    timeElapsed: timeElapsed,
    time: time,
    size: size,
    bitrate: bitrate,
    speed: speed,
    videoFrameNumber: videoFrameNumber,
    videoFps: videoFps,
    videoQuality: videoQuality,
    dupFrames: dupFrames,
    dropFrames: dropFrames,
  );
}

void _onFFprobeComplete(int sessionId, Pointer<Void> userData) {
  CallbackManager().dispatchFFprobeComplete(sessionId);
}

void _onMediaInfoComplete(int sessionId, Pointer<Void> userData) {
  CallbackManager().dispatchMediaInformationComplete(sessionId);
}

void _onFFplayComplete(int sessionId, Pointer<Void> userData) {
  CallbackManager().dispatchFFplayComplete(sessionId);
}

final nativeFFmpegComplete =
    NativeCallable<NativeFFmpegGlobalCompleteCallback>.listener(
      _onFFmpegComplete,
    );

final nativeFFmpegLog = NativeCallable<NativeFFmpegGlobalLogCallback>.listener(
  _onFFmpegLog,
);

final nativeFFmpegLogV2 =
    NativeCallable<NativeFFmpegGlobalLogCallbackV2>.listener(
      _onFFmpegLogV2,
    );

final nativeFFmpegStatistics =
    NativeCallable<NativeFFmpegGlobalStatisticsCallback>.listener(
      _onFFmpegStatistics,
    );

final nativeFFprobeComplete =
    NativeCallable<NativeFFprobeGlobalCompleteCallback>.listener(
      _onFFprobeComplete,
    );

final nativeMediaInfoComplete =
    NativeCallable<NativeMediaInformationGlobalCompleteCallback>.listener(
      _onMediaInfoComplete,
    );

final nativeFFplayComplete =
    NativeCallable<NativeFFplayGlobalCompleteCallback>.listener(
      _onFFplayComplete,
    );

bool _nativeLogV2Unavailable = false;
bool _nativeLogV2Installed = false;

/// Installs v2 direct log delivery when the loaded runtime exposes it.
///
/// Older v1 runtimes fall back to the existing buffered callback. The failed
/// v2 lookup is recorded and logged so a missing symbol is never silently
/// treated as a successful v2 registration.
void configureNativeLogCallback() {
  if (!_nativeLogV2Unavailable) {
    try {
      bindings.ffmpeg_kit_config_enable_log_callback_v2(
        nativeFFmpegLogV2.nativeFunction,
        nullptr,
      );
      _nativeLogV2Installed = true;
      return;
    } catch (error, stackTrace) {
      _nativeLogV2Unavailable = true;
      developer.log(
        'Native v2 log callback unavailable; falling back to v1 polling',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  bindings.ffmpeg_kit_config_enable_log_callback(
    nativeFFmpegLog.nativeFunction,
    nullptr,
  );
  _nativeLogV2Installed = false;
}

/// Removes whichever log ABI was selected by [configureNativeLogCallback].
void disableNativeLogCallback() {
  if (_nativeLogV2Installed) {
    try {
      bindings.ffmpeg_kit_config_enable_log_callback_v2(nullptr, nullptr);
    } catch (error, stackTrace) {
      developer.log(
        'Native v2 log callback uninstall failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  bindings.ffmpeg_kit_config_enable_log_callback(nullptr, nullptr);
  _nativeLogV2Installed = false;
}
