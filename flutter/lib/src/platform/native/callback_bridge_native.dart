import 'dart:ffi';

import '../../callback_manager.dart';

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
