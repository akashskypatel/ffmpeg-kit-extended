import 'dart:developer' as developer;
import 'dart:ffi';

import '../../callback_manager.dart';
import '../../generated/ffmpeg_kit_bindings_native.dart' as bindings;

typedef FFmpegKitCompleteCallbackFunction =
    Void Function(bindings.FFmpegSessionHandle, Pointer<Void>);
typedef FFprobeKitCompleteCallbackFunction =
    Void Function(bindings.FFprobeSessionHandle, Pointer<Void>);
typedef FFplayKitCompleteCallbackFunction =
    Void Function(bindings.FFplaySessionHandle, Pointer<Void>);
typedef MediaInformationSessionCompleteCallbackFunction =
    Void Function(bindings.MediaInformationSessionHandle, Pointer<Void>);
typedef FFmpegKitLogCallbackFunction =
    Void Function(bindings.FFmpegSessionHandle, Pointer<Char>, Pointer<Void>);
typedef FFmpegKitStatisticsCallbackFunction =
    Void Function(
      bindings.FFmpegSessionHandle,
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

void _onFFmpegComplete(
  bindings.FFmpegSessionHandle sessionHandle,
  Pointer<Void> userData,
) {
  CallbackManager().dispatchFFmpegComplete(
    _safeGetSessionId(sessionHandle, '_onFFmpegComplete'),
  );
}

void _onFFmpegLog(
  bindings.FFmpegSessionHandle sessionHandle,
  Pointer<Char> logPtr,
  Pointer<Void> userData,
) {
  if (logPtr.address == 0) return;

  // Native global log callbacks use the first pointer-sized argument as the
  // numeric session ID. Drain the session buffer so log ordering and the
  // shared cursor remain consistent with polling and completion flushes.
  final sessionId = sessionHandle.address;
  if (sessionId > 0) {
    CallbackManager().dispatchPendingLogs(sessionId);
  }
}

void _onFFmpegStatistics(
  bindings.FFmpegSessionHandle sessionHandle,
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
    sessionId: _safeGetSessionId(sessionHandle, '_onFFmpegStatistics'),
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

void _onFFprobeComplete(
  bindings.FFprobeSessionHandle sessionHandle,
  Pointer<Void> userData,
) {
  CallbackManager().dispatchFFprobeComplete(
    _safeGetSessionId(sessionHandle, '_onFFprobeComplete'),
  );
}

void _onMediaInfoComplete(
  bindings.MediaInformationSessionHandle sessionHandle,
  Pointer<Void> userData,
) {
  CallbackManager().dispatchMediaInformationComplete(
    _safeGetSessionId(sessionHandle, '_onMediaInfoComplete'),
  );
}

void _onFFplayComplete(
  bindings.FFplaySessionHandle sessionHandle,
  Pointer<Void> userData,
) {
  CallbackManager().dispatchFFplayComplete(
    _safeGetSessionId(sessionHandle, '_onFFplayComplete'),
  );
}

int _safeGetSessionId(Pointer<Void> handle, String caller) {
  if (handle.address == 0) return 0;
  try {
    return bindings.ffmpeg_kit_session_get_session_id(handle);
  } catch (error, stackTrace) {
    developer.log(
      '$caller: failed to resolve session ID from native handle',
      error: error,
      stackTrace: stackTrace,
    );
    return 0;
  }
}

final nativeFFmpegComplete =
    NativeCallable<FFmpegKitCompleteCallbackFunction>.listener(
      _onFFmpegComplete,
    );

final nativeFFmpegLog = NativeCallable<FFmpegKitLogCallbackFunction>.listener(
  _onFFmpegLog,
);

final nativeFFmpegStatistics =
    NativeCallable<FFmpegKitStatisticsCallbackFunction>.listener(
      _onFFmpegStatistics,
    );

final nativeFFprobeComplete =
    NativeCallable<FFprobeKitCompleteCallbackFunction>.listener(
      _onFFprobeComplete,
    );

final nativeMediaInfoComplete =
    NativeCallable<MediaInformationSessionCompleteCallbackFunction>.listener(
      _onMediaInfoComplete,
    );

final nativeFFplayComplete =
    NativeCallable<FFplayKitCompleteCallbackFunction>.listener(
      _onFFplayComplete,
    );
