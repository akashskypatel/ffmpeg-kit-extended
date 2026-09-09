library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import '../generated/ffmpeg_kit_bindings_web.dart' as bindings;
import '../log.dart';
import '../media_information.dart';
import '../platform/web/callback_bridge_web.dart';
import '../platform/web/wasm_loader.dart';
import '../platform/web/wasm_memory.dart';
import '../signal.dart';
import 'ffplay_surface_web.dart';

export '../chapter_information.dart';
export '../log.dart';
export '../media_information.dart';
export '../signal.dart';
export '../stream_information.dart';
export 'ffplay_surface_web.dart';

typedef FFmpegSessionCompleteCallback = void Function(FFmpegSession session);
typedef FFprobeSessionCompleteCallback = void Function(FFprobeSession session);
typedef FFplaySessionCompleteCallback = void Function(FFplaySession session);
typedef MediaInformationSessionCompleteCallback =
    void Function(MediaInformationSession session);
typedef FFmpegLogCallback = void Function(Log log);
typedef FFmpegStatisticsCallback = void Function(Statistics statistics);

enum ReturnCode {
  success(0),
  cancel(255);

  const ReturnCode(this.value);
  final int value;
  static bool isSuccess(int code) => code == success.value;
  static bool isCancel(int code) => code == cancel.value;
}

enum SessionState {
  created(0),
  running(1),
  completed(2),
  failed(3);

  const SessionState(this.value);
  final int value;
  static SessionState fromValue(int value) => SessionState.values.firstWhere(
    (state) => state.value == value,
    orElse: () => SessionState.failed,
  );
}

class Statistics {
  Statistics(
    this.sessionId,
    this.timeElapsed,
    this.time,
    this.size,
    this.bitrate,
    this.speed,
    this.videoFrameNumber,
    this.videoFps,
    this.videoQuality,
    this.dupFrames,
    this.dropFrames,
    this.transcodingProgress,
  );

  final int sessionId;
  final int timeElapsed;
  final int time;
  final int size;
  final double bitrate;
  final double speed;
  final int videoFrameNumber;
  final double videoFps;
  final double videoQuality;
  final int dupFrames;
  final int dropFrames;
  final double? transcodingProgress;
  int? get transcodingProgressPercent => transcodingProgress == null
      ? null
      : (transcodingProgress! * 100).round().clamp(0, 100);
}

class SessionCancelledException implements Exception {
  SessionCancelledException([this.message = 'Session was cancelled']);
  final String message;
  @override
  String toString() => 'SessionCancelledException: $message';
}

class _WasmRuntime {
  _WasmRuntime._();
  static final instance = _WasmRuntime._();

  bool get initialized => wasmLoader.initialized;

  Future<void> initialize() => wasmLoader.initialize();

  void requireInitialized() {
    if (!initialized) {
      wasmLoader.requireInitialized();
    }
  }

  int _argInt(JSAny? value) {
    if (value == null) return 0;
    return globalContext.callMethodVarArgs<JSNumber>('Number'.toJS, [
      value,
    ]).toDartInt;
  }

  bindings.Pointer<bindings.Void> _handle(int address) =>
      bindings.Pointer<bindings.Void>.fromAddress(address);

  bindings.Pointer<bindings.Char> _charPointer(int address) =>
      bindings.Pointer<bindings.Char>.fromAddress(address);

  int _callInt(String name, [List<JSAny?> args = const []]) {
    requireInitialized();
    switch (name) {
      case '_malloc':
        return wasmMemory.allocate(_argInt(args[0])).address;
      case '_ffmpeg_kit_session_get_state':
        return bindings
            .ffmpeg_kit_session_get_state(_handle(_argInt(args[0])))
            .value;
      case '_ffmpeg_kit_session_get_return_code':
        return bindings
            .ffmpeg_kit_session_get_return_code(_handle(_argInt(args[0])))
            .toInt();
      case '_ffmpeg_kit_session_get_logs_count':
        return bindings
            .ffmpeg_kit_session_get_logs_count(_handle(_argInt(args[0])))
            .toInt();
      case '_ffmpeg_kit_session_get_log_level_at':
        return bindings
            .ffmpeg_kit_session_get_log_level_at(
              _handle(_argInt(args[0])),
              BigInt.from(_argInt(args[1])),
            )
            .toInt();
      case '_ffmpeg_kit_session_get_create_time':
        return bindings
            .ffmpeg_kit_session_get_create_time(_handle(_argInt(args[0])))
            .toInt();
      case '_ffmpeg_kit_session_get_start_time':
        return bindings
            .ffmpeg_kit_session_get_start_time(_handle(_argInt(args[0])))
            .toInt();
      case '_ffmpeg_kit_session_get_end_time':
        return bindings
            .ffmpeg_kit_session_get_end_time(_handle(_argInt(args[0])))
            .toInt();
      case '_ffmpeg_kit_session_get_duration':
        return bindings
            .ffmpeg_kit_session_get_duration(_handle(_argInt(args[0])))
            .toInt();
      case '_ffmpeg_kit_session_get_session_id':
        return bindings
            .ffmpeg_kit_session_get_session_id(_handle(_argInt(args[0])))
            .toInt();
      case '_ffplay_kit_session_is_playing':
        return bindings.ffplay_kit_session_is_playing(_handle(_argInt(args[0])))
            ? 1
            : 0;
      case '_ffplay_kit_session_is_paused':
        return bindings.ffplay_kit_session_is_paused(_handle(_argInt(args[0])))
            ? 1
            : 0;
      case '_ffplay_kit_session_get_video_width':
        return bindings.ffplay_kit_session_get_video_width(
          _handle(_argInt(args[0])),
        );
      case '_ffplay_kit_session_get_video_height':
        return bindings.ffplay_kit_session_get_video_height(
          _handle(_argInt(args[0])),
        );
      case '_ffmpeg_kit_packages_get_is_gpl':
        return bindings.ffmpeg_kit_packages_get_is_gpl() ? 1 : 0;
      case '_ffmpeg_kit_packages_get_is_nonfree':
        return bindings.ffmpeg_kit_packages_get_is_nonfree() ? 1 : 0;
      default:
        throw UnsupportedError('Unsupported generated int binding: $name');
    }
  }

  double _callDouble(String name, [List<JSAny?> args = const []]) {
    requireInitialized();
    switch (name) {
      case '_ffplay_kit_session_get_position':
        return bindings.ffplay_kit_session_get_position(
          _handle(_argInt(args[0])),
        );
      case '_ffplay_kit_session_get_duration':
        return bindings.ffplay_kit_session_get_duration(
          _handle(_argInt(args[0])),
        );
      case '_ffplay_kit_session_get_volume':
        return bindings.ffplay_kit_session_get_volume(
          _handle(_argInt(args[0])),
        );
      default:
        throw UnsupportedError('Unsupported generated double binding: $name');
    }
  }

  void _callVoid(String name, [List<JSAny?> args = const []]) {
    requireInitialized();
    switch (name) {
      case '_free':
        wasmMemory.free(
          bindings.Pointer<bindings.Uint8>.fromAddress(_argInt(args[0])),
        );
        return;
      case '_ffmpeg_kit_cancel_session':
        bindings.ffmpeg_kit_cancel_session(BigInt.from(_argInt(args[0])));
        return;
      case '_ffmpeg_kit_handle_release':
        bindings.ffmpeg_kit_handle_release(_handle(_argInt(args[0])));
        return;
      case '_ffplay_kit_session_execute_async':
        bindings.ffplay_kit_session_execute_async(
          _handle(_argInt(args[0])),
          BigInt.from(_argInt(args[1])),
        );
        return;
      case '_ffplay_kit_session_pause':
        bindings.ffplay_kit_session_pause(_handle(_argInt(args[0])));
        return;
      case '_ffplay_kit_session_resume':
        bindings.ffplay_kit_session_resume(_handle(_argInt(args[0])));
        return;
      case '_ffplay_kit_session_stop':
        bindings.ffplay_kit_session_stop(_handle(_argInt(args[0])));
        return;
      case '_ffplay_kit_session_seek':
        bindings.ffplay_kit_session_seek(
          _handle(_argInt(args[0])),
          (args[1] as JSNumber).toDartDouble,
        );
        return;
      case '_ffplay_kit_session_set_volume':
        bindings.ffplay_kit_session_set_volume(
          _handle(_argInt(args[0])),
          (args[1] as JSNumber).toDartDouble,
        );
        return;
      case '_ffplay_kit_session_close':
        bindings.ffplay_kit_session_close(_handle(_argInt(args[0])));
        return;
      case '_ffmpeg_kit_config_set_log_level':
        bindings.ffmpeg_kit_config_set_log_level(
          bindings.FFmpegKitLogLevel.fromValue(_argInt(args[0])),
        );
        return;
      case '_ffmpeg_kit_set_session_history_size':
        bindings.ffmpeg_kit_set_session_history_size(
          BigInt.from(_argInt(args[0])),
        );
        return;
      default:
        throw UnsupportedError('Unsupported generated void binding: $name');
    }
  }

  String _readAndFree(int pointer) =>
      wasmMemory.readAndFree(
        bindings.Pointer<bindings.Char>.fromAddress(pointer),
      ) ??
      '';

  String callString(String name, [List<JSAny?> args = const []]) {
    requireInitialized();
    final pointer = switch (name) {
      '_ffmpeg_kit_session_get_output' =>
        bindings
            .ffmpeg_kit_session_get_output(_handle(_argInt(args[0])))
            .address,
      '_ffmpeg_kit_session_get_logs_as_string' =>
        bindings
            .ffmpeg_kit_session_get_logs_as_string(_handle(_argInt(args[0])))
            .address,
      '_ffmpeg_kit_session_get_fail_stack_trace' =>
        bindings
            .ffmpeg_kit_session_get_fail_stack_trace(_handle(_argInt(args[0])))
            .address,
      '_ffmpeg_kit_session_get_log_at' =>
        bindings
            .ffmpeg_kit_session_get_log_at(
              _handle(_argInt(args[0])),
              BigInt.from(_argInt(args[1])),
            )
            .address,
      '_ffmpeg_kit_config_get_ffmpeg_version' =>
        bindings.ffmpeg_kit_config_get_ffmpeg_version().address,
      '_ffmpeg_kit_config_get_version' =>
        bindings.ffmpeg_kit_config_get_version().address,
      '_ffmpeg_kit_packages_get_package_name' =>
        bindings.ffmpeg_kit_packages_get_package_name().address,
      '_ffmpeg_kit_packages_get_external_libraries' =>
        bindings.ffmpeg_kit_packages_get_external_libraries().address,
      '_ffmpeg_kit_packages_get_bundle_type' =>
        bindings.ffmpeg_kit_packages_get_bundle_type().address,
      '_ffmpeg_kit_packages_get_registered_codecs' =>
        bindings.ffmpeg_kit_packages_get_registered_codecs().address,
      '_ffmpeg_kit_packages_get_registered_encoders' =>
        bindings.ffmpeg_kit_packages_get_registered_encoders().address,
      '_ffmpeg_kit_packages_get_registered_decoders' =>
        bindings.ffmpeg_kit_packages_get_registered_decoders().address,
      '_ffmpeg_kit_packages_get_registered_muxers' =>
        bindings.ffmpeg_kit_packages_get_registered_muxers().address,
      '_ffmpeg_kit_packages_get_registered_demuxers' =>
        bindings.ffmpeg_kit_packages_get_registered_demuxers().address,
      '_ffmpeg_kit_packages_get_registered_filters' =>
        bindings.ffmpeg_kit_packages_get_registered_filters().address,
      '_ffmpeg_kit_packages_get_registered_protocols' =>
        bindings.ffmpeg_kit_packages_get_registered_protocols().address,
      '_ffmpeg_kit_packages_get_registered_bitstream_filters' =>
        bindings.ffmpeg_kit_packages_get_registered_bitstream_filters().address,
      '_ffmpeg_kit_packages_get_build_configuration' =>
        bindings.ffmpeg_kit_packages_get_build_configuration().address,
      '_ffmpeg_kit_config_get_build_date' =>
        bindings.ffmpeg_kit_config_get_build_date().address,
      _ => throw UnsupportedError(
        'Unsupported generated string binding: $name',
      ),
    };
    return _readAndFree(pointer);
  }

  int _newUtf8(String value) => wasmMemory.allocateUtf8(value).address;

  int execute(
    String entryPoint,
    String command, [
    List<JSAny?> additionalArguments = const [],
  ]) {
    requireInitialized();
    final commandPointer = _newUtf8(command);
    final nativeCommand = _charPointer(commandPointer);
    try {
      switch (entryPoint) {
        case '_ffmpeg_kit_execute':
          return bindings.ffmpeg_kit_execute(nativeCommand).address;
        case '_ffmpeg_kit_execute_async':
          return bindings
              .ffmpeg_kit_execute_async(
                nativeCommand,
                webCallbackBridge.nullFFmpegComplete,
                webCallbackBridge.nullPointer,
              )
              .address;
        case '_ffprobe_kit_execute':
          return bindings.ffprobe_kit_execute(nativeCommand).address;
        case '_ffprobe_kit_execute_async':
          return bindings
              .ffprobe_kit_execute_async(
                nativeCommand,
                webCallbackBridge.nullFFprobeComplete,
                webCallbackBridge.nullPointer,
              )
              .address;
        case '_ffplay_kit_create_session':
          return bindings.ffplay_kit_create_session(nativeCommand).address;
        default:
          throw UnsupportedError(
            'Unsupported generated execute binding: $entryPoint',
          );
      }
    } finally {
      wasmMemory.free(nativeCommand);
    }
  }

  void release(int handle) =>
      bindings.ffmpeg_kit_handle_release(_handle(handle));
}

abstract class Session {
  Session(this.command);

  final String command;
  int handle = 0;
  int sessionId = 0;
  bool _cancelled = false;
  bool _debug = false;
  String _debugLog = '';
  FFmpegLogCallback? logCallback;

  SessionState getState() => handle == 0
      ? SessionState.created
      : SessionState.fromValue(
          _WasmRuntime.instance._callInt('_ffmpeg_kit_session_get_state', [
            handle.toJS,
          ]),
        );
  int getReturnCode() => handle == 0
      ? 0
      : _WasmRuntime.instance._callInt('_ffmpeg_kit_session_get_return_code', [
          handle.toJS,
        ]);
  int getSessionId() => sessionId;
  String getCommand() => command;
  String? getOutput() => handle == 0
      ? null
      : _WasmRuntime.instance.callString('_ffmpeg_kit_session_get_output', [
          handle.toJS,
        ]);
  String? getLogs() => getLogsAsString();
  String? getLogsAsString() => handle == 0
      ? null
      : _WasmRuntime.instance.callString(
          '_ffmpeg_kit_session_get_logs_as_string',
          [handle.toJS],
        );
  String? getFailStackTrace() => handle == 0
      ? null
      : _WasmRuntime.instance.callString(
          '_ffmpeg_kit_session_get_fail_stack_trace',
          [handle.toJS],
        );
  int getLogsCount() => handle == 0
      ? 0
      : _WasmRuntime.instance._callInt('_ffmpeg_kit_session_get_logs_count', [
          handle.toJS,
        ]);
  String getLogAt(int index) => _WasmRuntime.instance.callString(
    '_ffmpeg_kit_session_get_log_at',
    [handle.toJS, index.toJS],
  );
  int getLogLevelAt(int index) => _WasmRuntime.instance._callInt(
    '_ffmpeg_kit_session_get_log_level_at',
    [handle.toJS, index.toJS],
  );
  DateTime getCreateTime() => DateTime.fromMillisecondsSinceEpoch(
    handle == 0
        ? DateTime.now().millisecondsSinceEpoch
        : _WasmRuntime.instance._callInt(
            '_ffmpeg_kit_session_get_create_time',
            [handle.toJS],
          ),
  );
  DateTime? getStartTime() => _time('_ffmpeg_kit_session_get_start_time');
  DateTime? getEndTime() => _time('_ffmpeg_kit_session_get_end_time');
  DateTime? _time(String function) {
    if (handle == 0) return null;
    final value = _WasmRuntime.instance._callInt(function, [handle.toJS]);
    return value == 0 ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  int getDuration() => handle == 0
      ? 0
      : _WasmRuntime.instance._callInt('_ffmpeg_kit_session_get_duration', [
          handle.toJS,
        ]);
  void cancel() {
    _cancelled = true;
    if (sessionId != 0) {
      _WasmRuntime.instance._callVoid('_ffmpeg_kit_cancel_session', [
        sessionId.toJS,
      ]);
    }
  }

  bool get isCancelled => _cancelled;
  void close() {
    if (handle != 0) {
      _WasmRuntime.instance.release(handle);
    }
    handle = 0;
  }

  void enableDebugLog() => _debug = true;
  void disableDebugLog() => _debug = false;
  bool isDebugLogEnabled() => _debug;
  String getDebugLog() => _debugLog;
  void clearDebugLog() => _debugLog = '';
  bool isFFmpegSession() => false;
  bool isFFprobeSession() => false;
  bool isFFplaySession() => false;
  bool isMediaInformationSession() => false;

  void _capture() {
    sessionId = _WasmRuntime.instance._callInt(
      '_ffmpeg_kit_session_get_session_id',
      [handle.toJS],
    );
    final text = getLogsAsString() ?? '';
    _debugLog = text;
    if (logCallback != null && text.isNotEmpty) {
      for (final line in const LineSplitter().convert(text)) {
        logCallback!(Log(sessionId, LogLevel.info.value, line));
      }
    }
  }

  Future<void> _waitForCompletion() async {
    if (handle == 0) {
      throw StateError('FFmpeg Kit failed to create a session.');
    }
    sessionId = _WasmRuntime.instance._callInt(
      '_ffmpeg_kit_session_get_session_id',
      [handle.toJS],
    );
    while (true) {
      final state = getState();
      if (state == SessionState.completed || state == SessionState.failed) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }
}

class FFmpegSession extends Session {
  FFmpegSession(
    super.command, {
    this.completeCallback,
    this.statisticsCallback,
    FFmpegLogCallback? logCallback,
  }) {
    this.logCallback = logCallback;
  }

  FFmpegSessionCompleteCallback? completeCallback;
  FFmpegStatisticsCallback? statisticsCallback;
  Duration? expectedTranscodingDuration;
  final _logController = StreamController<Log>.broadcast();
  Stream<Log> get logStream => _logController.stream;
  Stream<List<Log>> get logBatchStream => logStream.map((log) => [log]);

  static FFmpegSession create(
    String command, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) => FFmpegSession(
    command,
    completeCallback: completeCallback,
    logCallback: logCallback,
    statisticsCallback: statisticsCallback,
  );
  static FFmpegSession createFromArguments(
    List<String> arguments, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) => create(
    FFmpegKitExtended.argumentsToString(arguments),
    completeCallback: completeCallback,
    logCallback: logCallback,
    statisticsCallback: statisticsCallback,
  );
  static FFmpegSession executeCommand(
    String command, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) => create(
    command,
    completeCallback: completeCallback,
    logCallback: logCallback,
    statisticsCallback: statisticsCallback,
  ).execute();
  static Future<FFmpegSession> executeCommandAsync(
    String command, {
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) => create(
    command,
    completeCallback: completeCallback,
    logCallback: logCallback,
    statisticsCallback: statisticsCallback,
  ).executeAsync();
  FFmpegSession execute() {
    handle = _WasmRuntime.instance.execute('_ffmpeg_kit_execute', command);
    _capture();
    FFmpegKitExtended._remember(this);
    completeCallback?.call(this);
    return this;
  }

  Future<FFmpegSession> executeAsync({
    FFmpegSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
    FFmpegStatisticsCallback? statisticsCallback,
  }) async {
    if (completeCallback != null) this.completeCallback = completeCallback;
    if (logCallback != null) this.logCallback = logCallback;
    if (statisticsCallback != null) {
      this.statisticsCallback = statisticsCallback;
    }
    handle = _WasmRuntime.instance.execute(
      '_ffmpeg_kit_execute_async',
      command,
      [0.toJS, 0.toJS],
    );
    FFmpegKitExtended._remember(this);
    await _waitForCompletion();
    _capture();
    this.completeCallback?.call(this);
    return this;
  }

  void setCompleteCallback(FFmpegSessionCompleteCallback? value) =>
      completeCallback = value;
  void setLogCallback(FFmpegLogCallback? value) => logCallback = value;
  void setStatisticsCallback(FFmpegStatisticsCallback? value) =>
      statisticsCallback = value;
  void setExpectedTranscodingDuration(Duration? value) =>
      expectedTranscodingDuration = value;
  @override
  bool isFFmpegSession() => true;
}

class FFprobeSession extends Session {
  FFprobeSession(
    super.command, {
    this.completeCallback,
    FFmpegLogCallback? logCallback,
  }) {
    this.logCallback = logCallback;
  }
  FFprobeSessionCompleteCallback? completeCallback;
  static FFprobeSession create(
    String command, {
    FFprobeSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
  }) => FFprobeSession(
    command,
    completeCallback: completeCallback,
    logCallback: logCallback,
  );
  static FFprobeSession executeCommand(
    String command, {
    FFprobeSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
  }) => create(
    command,
    completeCallback: completeCallback,
    logCallback: logCallback,
  ).execute();
  static Future<FFprobeSession> executeCommandAsync(
    String command, {
    FFprobeSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
  }) => create(
    command,
    completeCallback: completeCallback,
    logCallback: logCallback,
  ).executeAsync();
  FFprobeSession execute() {
    handle = _WasmRuntime.instance.execute('_ffprobe_kit_execute', command);
    _capture();
    FFmpegKitExtended._remember(this);
    completeCallback?.call(this);
    return this;
  }

  Future<FFprobeSession> executeAsync({
    FFprobeSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
  }) async {
    if (completeCallback != null) this.completeCallback = completeCallback;
    if (logCallback != null) this.logCallback = logCallback;
    handle = _WasmRuntime.instance.execute(
      '_ffprobe_kit_execute_async',
      command,
      [0.toJS, 0.toJS],
    );
    FFmpegKitExtended._remember(this);
    await _waitForCompletion();
    _capture();
    this.completeCallback?.call(this);
    return this;
  }

  void setCompleteCallback(FFprobeSessionCompleteCallback? value) =>
      completeCallback = value;
  void setLogCallback(FFmpegLogCallback? value) => logCallback = value;
  MediaInformation? getMediaInformation() => null;
  @override
  bool isFFprobeSession() => true;
}

class MediaInformationSession extends FFprobeSession {
  MediaInformationSession(
    super.command, {
    this.mediaInfoCompleteCallback,
    super.logCallback,
  });
  MediaInformationSessionCompleteCallback? mediaInfoCompleteCallback;
  MediaInformation? _mediaInformation;
  @override
  MediaInformationSession execute() {
    super.execute();
    _mediaInformation = _parseMediaInformation(getOutput());
    mediaInfoCompleteCallback?.call(this);
    return this;
  }

  @override
  Future<MediaInformationSession> executeAsync({
    FFprobeSessionCompleteCallback? completeCallback,
    FFmpegLogCallback? logCallback,
  }) async => execute();
  @override
  MediaInformation? getMediaInformation() => _mediaInformation;
  @override
  bool isFFprobeSession() => false;
  @override
  bool isMediaInformationSession() => true;
}

MediaInformation? _parseMediaInformation(String? output) {
  if (output == null || output.isEmpty) return null;
  try {
    final json = jsonDecode(output) as Map<String, dynamic>;
    final format = json['format'] as Map<String, dynamic>? ?? const {};
    return MediaInformation(
      filename: format['filename']?.toString(),
      format: format['format_name']?.toString(),
      longFormat: format['format_long_name']?.toString(),
      duration: format['duration']?.toString(),
      startTime: format['start_time']?.toString(),
      bitrate: format['bit_rate']?.toString(),
      size: format['size']?.toString(),
      tagsJson: jsonEncode(format['tags'] ?? const {}),
      allPropertiesJson: output,
    );
  } catch (_) {
    return null;
  }
}

class FFplaySession extends Session {
  FFplaySession(
    super.command, {
    this.completeCallback,
    FFmpegLogCallback? logCallback,
  }) {
    this.logCallback = logCallback;
  }
  FFplaySessionCompleteCallback? completeCallback;
  final _positionController = StreamController<double>.broadcast();
  final _videoSizeController = StreamController<(int, int)>.broadcast();
  Timer? _positionTimer;
  (int, int)? _lastVideoSize;
  Stream<double> get positionStream => _positionController.stream;
  Stream<(int, int)> get videoSizeStream => _videoSizeController.stream;

  Future<FFplaySession> executeAsync() async {
    final runtime = _WasmRuntime.instance;
    if (handle == 0) {
      handle = runtime.execute('_ffplay_kit_create_session', command);
      sessionId = runtime._callInt('_ffmpeg_kit_session_get_session_id', [
        handle.toJS,
      ]);
    }
    runtime._callVoid('_ffplay_kit_session_execute_async', [
      handle.toJS,
      globalContext.callMethodVarArgs<JSAny?>('BigInt'.toJS, ['500'.toJS]),
    ]);
    FFmpegKitExtended._remember(this);
    _positionTimer ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (handle == 0) return;
      _positionController.add(getPosition());
      final size = (getVideoWidth(), getVideoHeight());
      if (size != _lastVideoSize && size.$1 > 0 && size.$2 > 0) {
        _lastVideoSize = size;
        _videoSizeController.add(size);
      }
    });
    while (true) {
      if (handle == 0) break;
      final state = getState();
      if (state == SessionState.completed || state == SessionState.failed) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _positionTimer?.cancel();
    _positionTimer = null;
    _capture();
    completeCallback?.call(this);
    return this;
  }

  bool isPlaying() =>
      handle != 0 &&
      _WasmRuntime.instance._callInt('_ffplay_kit_session_is_playing', [
            handle.toJS,
          ]) !=
          0;
  bool isPaused() =>
      handle != 0 &&
      _WasmRuntime.instance._callInt('_ffplay_kit_session_is_paused', [
            handle.toJS,
          ]) !=
          0;
  void pause() => _WasmRuntime.instance._callVoid('_ffplay_kit_session_pause', [
    handle.toJS,
  ]);
  void resume() => _WasmRuntime.instance._callVoid(
    '_ffplay_kit_session_resume',
    [handle.toJS],
  );
  void stop() => _WasmRuntime.instance._callVoid('_ffplay_kit_session_stop', [
    handle.toJS,
  ]);
  void seek(double seconds) => _WasmRuntime.instance._callVoid(
    '_ffplay_kit_session_seek',
    [handle.toJS, seconds.toJS],
  );
  void setPosition(double seconds) => seek(seconds);
  double getPosition() => handle == 0
      ? 0
      : _WasmRuntime.instance._callDouble('_ffplay_kit_session_get_position', [
          handle.toJS,
        ]);
  double getMediaDuration() => handle == 0
      ? 0
      : _WasmRuntime.instance._callDouble('_ffplay_kit_session_get_duration', [
          handle.toJS,
        ]);
  int getVideoWidth() => handle == 0
      ? 0
      : _WasmRuntime.instance._callInt('_ffplay_kit_session_get_video_width', [
          handle.toJS,
        ]);
  int getVideoHeight() => handle == 0
      ? 0
      : _WasmRuntime.instance._callInt('_ffplay_kit_session_get_video_height', [
          handle.toJS,
        ]);
  void setVolume(double value) => _WasmRuntime.instance._callVoid(
    '_ffplay_kit_session_set_volume',
    [handle.toJS, value.toJS],
  );
  double getVolume() => handle == 0
      ? 0
      : _WasmRuntime.instance._callDouble('_ffplay_kit_session_get_volume', [
          handle.toJS,
        ]);
  void setCompleteCallback(FFplaySessionCompleteCallback? value) =>
      completeCallback = value;
  void setLogCallback(FFmpegLogCallback? value) => logCallback = value;
  @override
  void close() {
    _positionTimer?.cancel();
    _positionController.close();
    _videoSizeController.close();
    if (handle != 0) {
      _WasmRuntime.instance._callVoid('_ffplay_kit_session_close', [
        handle.toJS,
      ]);
      handle = 0;
    }
  }

  @override
  bool isFFplaySession() => true;
}

class FFmpegKit {
  static FFmpegSession execute(String command) =>
      FFmpegSession.executeCommand(command);
  static Future<FFmpegSession> executeAsync(
    String command, {
    FFmpegSessionCompleteCallback? onComplete,
    FFmpegLogCallback? onLog,
    FFmpegStatisticsCallback? onStatistics,
  }) => FFmpegSession.executeCommandAsync(
    command,
    completeCallback: onComplete,
    logCallback: onLog,
    statisticsCallback: onStatistics,
  );
  static void cancel(FFmpegSession session) => session.cancel();
  static FFmpegSession createSession(String command) => FFmpegSession(command);
  static FFmpegSession createSessionFromArguments(List<String> arguments) =>
      FFmpegSession.createFromArguments(arguments);
  static FFmpegSession? getLastFFmpegSession() =>
      FFmpegKitExtended.getLastFFmpegSession();
  static List<FFmpegSession> getFFmpegSessions() =>
      FFmpegKitExtended.getFFmpegSessions();
}

class FFprobeKit {
  static FFprobeSession execute(String command) =>
      FFprobeSession.executeCommand(command);
  static Future<FFprobeSession> executeAsync(
    String command, {
    FFprobeSessionCompleteCallback? onComplete,
    FFmpegLogCallback? onLog,
  }) => FFprobeSession.executeCommandAsync(
    command,
    completeCallback: onComplete,
    logCallback: onLog,
  );
  static FFprobeSession createSession(
    String command, {
    FFprobeSessionCompleteCallback? onComplete,
    FFmpegLogCallback? onLog,
  }) =>
      FFprobeSession(command, completeCallback: onComplete, logCallback: onLog);
  static void cancel(FFprobeSession session) => session.cancel();
  static List<FFprobeSession> getFFprobeSessions() =>
      FFmpegKitExtended.getFFprobeSessions();
  static MediaInformationSession getMediaInformation(String path) =>
      MediaInformationSession(
        '-v error -show_format -show_streams -show_chapters -of json "$path"',
      ).execute();
  static Future<MediaInformationSession> getMediaInformationAsync(
    String path, {
    FFprobeSessionCompleteCallback? onComplete,
  }) async {
    final session = getMediaInformation(path);
    onComplete?.call(session);
    return session;
  }
}

class FFplayKit {
  static FFplaySession? _current;
  static Future<FFplaySession> execute(String command) => executeAsync(command);
  static Future<FFplaySession> executeAsync(
    String command, {
    FFplaySessionCompleteCallback? onComplete,
    FFmpegLogCallback? onLog,
  }) async {
    _current = FFplaySession(
      command,
      completeCallback: onComplete,
      logCallback: onLog,
    );
    final session = _current!;
    unawaited(session.executeAsync());
    await Future<void>.delayed(Duration.zero);
    return session;
  }

  static Future<FFplaySession> createSession(
    String command, {
    FFplaySessionCompleteCallback? onComplete,
    FFmpegLogCallback? onLog,
  }) async => _current = FFplaySession(
    command,
    completeCallback: onComplete,
    logCallback: onLog,
  );
  static FFplaySession? getCurrentSession() => _current;
  static List<FFplaySession> getFFplaySessions() =>
      FFmpegKitExtended.getFFplaySessions();
  static bool get playing => _current?.isPlaying() ?? false;
  static bool get paused => _current?.isPaused() ?? false;
  static double get position => _current?.getPosition() ?? 0;
  static double get duration => _current?.getMediaDuration() ?? 0;
  static void seek(double seconds) => _current?.seek(seconds);
  static void pause() => _current?.pause();
  static void resume() => _current?.resume();
  static void stop() => _current?.stop();
  static void close() {
    _current?.close();
    _current = null;
  }

  static bool isPlaying() => playing;
  static bool isPaused() => paused;
}

class FFmpegKitExtended {
  static final List<Session> _sessions = [];
  static Future<void> initialize() => _WasmRuntime.instance.initialize();
  static bool get initialized => _WasmRuntime.instance.initialized;
  static void requireInitialized() =>
      _WasmRuntime.instance.requireInitialized();
  static void _remember(Session session) {
    _sessions.remove(session);
    _sessions.add(session);
  }

  static List<Session> listSessions() => List.unmodifiable(_sessions);
  static List<Session> getSessions() => listSessions();
  static List<FFmpegSession> getFFmpegSessions() =>
      _sessions.whereType<FFmpegSession>().toList();
  static List<FFprobeSession> getFFprobeSessions() => _sessions
      .whereType<FFprobeSession>()
      .where((s) => s is! MediaInformationSession)
      .toList();
  static List<FFplaySession> getFFplaySessions() =>
      _sessions.whereType<FFplaySession>().toList();
  static FFmpegSession? getLastFFmpegSession() =>
      getFFmpegSessions().lastOrNull;
  static FFprobeSession? getLastFFprobeSession() =>
      getFFprobeSessions().lastOrNull;
  static FFplaySession? getLastFFplaySession() =>
      getFFplaySessions().lastOrNull;
  static void clearSessions() {
    for (final session in _sessions) {
      session.close();
    }
    _sessions.clear();
  }

  static void cancelSession(int id) {
    for (final session in _sessions.where((s) => s.sessionId == id)) {
      session.cancel();
    }
  }

  static LogLevel _logLevel = LogLevel.info;
  static void setLogLevel(LogLevel level) {
    _logLevel = level;
    _WasmRuntime.instance._callVoid('_ffmpeg_kit_config_set_log_level', [
      level.value.toJS,
    ]);
  }

  static LogLevel getLogLevel() => _logLevel;
  static String getFFmpegVersion() =>
      _WasmRuntime.instance.callString('_ffmpeg_kit_config_get_ffmpeg_version');
  static String getFFmpegArchitecture() => 'wasm32';
  static String getVersion() =>
      _WasmRuntime.instance.callString('_ffmpeg_kit_config_get_version');
  static String getPackageName() =>
      _WasmRuntime.instance.callString('_ffmpeg_kit_packages_get_package_name');
  static String getExternalLibraries() => _WasmRuntime.instance.callString(
    '_ffmpeg_kit_packages_get_external_libraries',
  );
  static String getBundleType() =>
      _WasmRuntime.instance.callString('_ffmpeg_kit_packages_get_bundle_type');
  static bool isGpl() =>
      _WasmRuntime.instance._callInt('_ffmpeg_kit_packages_get_is_gpl') != 0;
  static bool isNonfree() =>
      _WasmRuntime.instance._callInt('_ffmpeg_kit_packages_get_is_nonfree') !=
      0;
  static String getRegisteredCodecs() => _WasmRuntime.instance.callString(
    '_ffmpeg_kit_packages_get_registered_codecs',
  );
  static String getRegisteredEncoders() => _WasmRuntime.instance.callString(
    '_ffmpeg_kit_packages_get_registered_encoders',
  );
  static String getRegisteredDecoders() => _WasmRuntime.instance.callString(
    '_ffmpeg_kit_packages_get_registered_decoders',
  );
  static String getRegisteredMuxers() => _WasmRuntime.instance.callString(
    '_ffmpeg_kit_packages_get_registered_muxers',
  );
  static String getRegisteredDemuxers() => _WasmRuntime.instance.callString(
    '_ffmpeg_kit_packages_get_registered_demuxers',
  );
  static String getRegisteredFilters() => _WasmRuntime.instance.callString(
    '_ffmpeg_kit_packages_get_registered_filters',
  );
  static String getRegisteredProtocols() => _WasmRuntime.instance.callString(
    '_ffmpeg_kit_packages_get_registered_protocols',
  );
  static String getRegisteredBitstreamFilters() => _WasmRuntime.instance
      .callString('_ffmpeg_kit_packages_get_registered_bitstream_filters');
  static String getBuildConfiguration() => _WasmRuntime.instance.callString(
    '_ffmpeg_kit_packages_get_build_configuration',
  );
  static String getBuildDate() =>
      _WasmRuntime.instance.callString('_ffmpeg_kit_config_get_build_date');
  static int _historySize = 10;
  static void setSessionHistorySize(int size) {
    _historySize = size;
    _WasmRuntime.instance._callVoid('_ffmpeg_kit_set_session_history_size', [
      size.toJS,
    ]);
  }

  static int getSessionHistorySize() => _historySize;
  static void enableRedirection() {}
  static void disableRedirection() {}
  static void setEnvironmentVariable(String name, String value) {}
  static void ignoreSignal(Signal signal) {}
  static String sessionStateToString(SessionState state) =>
      state.name.toUpperCase();
  static String? logLevelToString(LogLevel level) => level.name.toUpperCase();
  static List<String> parseArguments(String command) =>
      RegExp(r'''(?:[^\s"']+|"[^"]*"|'[^']*')+''')
          .allMatches(command)
          .map((m) => m.group(0)!.replaceAll(RegExp(r'''^["']|["']$'''), ''))
          .toList();
  static String argumentsToString(List<String> args) => args
      .map(
        (arg) => arg.contains(RegExp(r'\s'))
            ? '"${arg.replaceAll('"', '\\"')}"'
            : arg,
      )
      .join(' ');
}

class FFmpegKitConfig {
  static void enableRedirection() => FFmpegKitExtended.enableRedirection();
  static void disableRedirection() => FFmpegKitExtended.disableRedirection();
  static void setLogLevel(LogLevel level) =>
      FFmpegKitExtended.setLogLevel(level);
  static LogLevel getLogLevel() => FFmpegKitExtended.getLogLevel();
  static String getFFmpegVersion() => FFmpegKitExtended.getFFmpegVersion();
  static String getVersion() => FFmpegKitExtended.getVersion();
  static String getPackageName() => FFmpegKitExtended.getPackageName();
  static String getBuildDate() => FFmpegKitExtended.getBuildDate();
  static void setSessionHistorySize(int size) =>
      FFmpegKitExtended.setSessionHistorySize(size);
  static int getSessionHistorySize() =>
      FFmpegKitExtended.getSessionHistorySize();
  static void clearSessions() => FFmpegKitExtended.clearSessions();
  static String sessionStateToString(SessionState state) =>
      FFmpegKitExtended.sessionStateToString(state);
  static String? logLevelToString(LogLevel level) =>
      FFmpegKitExtended.logLevelToString(level);
  static List<String> parseArguments(String command) =>
      FFmpegKitExtended.parseArguments(command);
  static String argumentsToString(List<String> arguments) =>
      FFmpegKitExtended.argumentsToString(arguments);
  static void setEnvironmentVariable(String name, String value) =>
      FFmpegKitExtended.setEnvironmentVariable(name, value);
}

class SessionQueueManager {
  static final SessionQueueManager _instance = SessionQueueManager._();
  SessionQueueManager._();
  factory SessionQueueManager() => _instance;
  int maxConcurrentSessions = 1;
}

class FFplayViewController extends ChangeNotifier {
  FFplayViewController({this.onEnterFullscreen, this.onExitFullscreen});
  final Future<void> Function()? onEnterFullscreen;
  final Future<void> Function()? onExitFullscreen;
  bool get isFullscreen => false;
  Future<void> enterFullscreen(BuildContext context) async =>
      onEnterFullscreen?.call();
  Future<void> exitFullscreen() async => onExitFullscreen?.call();
}

class FFplayView extends StatelessWidget {
  const FFplayView({
    required this.surface,
    this.controller,
    this.aspectRatio,
    this.videoWidth,
    this.videoHeight,
    this.backgroundColor = Colors.black,
    super.key,
  });
  final FFplaySurface surface;
  final FFplayViewController? controller;
  final double? aspectRatio;
  final int? videoWidth;
  final int? videoHeight;
  final Color backgroundColor;
  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: backgroundColor, child: surface.toWidget());
}
