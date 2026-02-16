// ignore_for_file: non_constant_identifier_names, camel_case_types

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_flutter.dart';
import 'package:ffmpeg_kit_extended_flutter/src/generated/ffmpeg_kit_bindings.dart'
    as gen;
import 'mock_data.dart';

class MockFFmpegKitBindings extends gen.FFmpegKitBindings {
  final DynamicLibrary dynamicLibrary;
  MockFFmpegKitBindings() : this._internal(_openDummyLib());
  MockFFmpegKitBindings._internal(DynamicLibrary lib)
      : dynamicLibrary = lib,
        super(lib);

  static DynamicLibrary _openDummyLib() {
    try {
      if (Platform.isWindows) return DynamicLibrary.open('kernel32.dll');
      if (Platform.isLinux) return DynamicLibrary.open('libc.so.6');
      if (Platform.isMacOS)
        return DynamicLibrary.open('/usr/lib/libSystem.dylib');
    } catch (e) {}
    return DynamicLibrary.process();
  }

  // State
  final Map<int, MockSessionData> _sessions = {};
  int _nextSessionId = 1000;
  List<int> _sessionHistory = [];
  int _sessionHistorySize = 10;

  // FFplay global state
  bool _ffplayGlobalPaused = false;
  double _ffplayGlobalPosition = 0.0;

  // Config state
  final Map<String, String> _environmentVariables = {};
  final Set<int> _ignoredSignals = {};
  final Set<String> _ffmpegPipes = {};

  // Global Callbacks
  gen.FFmpegKitLogCallback globalLogCb = nullptr;
  Pointer<Void> globalLogUserData = nullptr;
  gen.FFmpegKitStatisticsCallback globalStatsCb = nullptr;
  Pointer<Void> globalStatsUserData = nullptr;
  gen.FFmpegKitCompleteCallback globalFFmpegCompleteCb = nullptr;
  Pointer<Void> globalFFmpegCompleteUserData = nullptr;
  gen.FFmpegKitCompleteCallback globalFFprobeCompleteCb = nullptr;
  Pointer<Void> globalFFprobeCompleteUserData = nullptr;
  gen.FFplayKitCompleteCallback globalFFplayCompleteCb = nullptr;
  Pointer<Void> globalFFplayCompleteUserData = nullptr;
  gen.MediaInformationSessionCompleteCallback globalMediaInfoCompleteCb =
      nullptr;
  Pointer<Void> globalMediaInfoCompleteUserData = nullptr;

  // Media Info State
  final Map<int, MockMediaInformation> _mediaInfoMap = {};
  int _nextMediaInfoHandle = 2000;
  final Map<String, int> _pathToMediaInfoHandle = {};

  // Handles for sub-objects
  final Map<int, MockStreamInformation> _streamHandles = {};
  final Map<int, MockChapterInformation> _chapterHandles = {};

  void setMockMediaInformation(String path, MockMediaInformation info) {
    final handle = _nextMediaInfoHandle++;
    _mediaInfoMap[handle] = info;
    _pathToMediaInfoHandle[path] = handle;
  }

  MockSessionData getSessionData(int id) =>
      _sessions.putIfAbsent(id, () => MockSessionData(id));

  MockSessionData? getSessionByHandle(Pointer<Void> handle) {
    if (handle == nullptr || !_sessions.containsKey(handle.address))
      return null;
    return _sessions[handle.address];
  }

  // --- Version / Package ---
  @override
  Pointer<Char> ffmpeg_kit_config_get_ffmpeg_version() =>
      "6.0-mock".toNativeUtf8().cast();

  @override
  Pointer<Char> ffmpeg_kit_packages_get_package_name() =>
      "ffmpeg-kit-mock".toNativeUtf8().cast();

  @override
  Pointer<Char> ffmpeg_kit_config_get_version() =>
      "6.0.0-mock".toNativeUtf8().cast();

  @override
  Pointer<Char> ffmpeg_kit_config_get_build_date() =>
      "20260101".toNativeUtf8().cast();

  @override
  Pointer<Char> ffmpeg_kit_packages_get_external_libraries() =>
      "libx264 zlib".toNativeUtf8().cast();

  @override
  Pointer<Char> ffmpeg_kit_config_get_ffmpeg_architecture() =>
      "arm64".toNativeUtf8().cast();

  // --- Session Management ---

  @override
  int ffmpeg_kit_session_get_session_id(Pointer<Void> handle) => handle.address;

  @override
  gen.FFmpegKitSessionState ffmpeg_kit_session_get_state(
          Pointer<Void> handle) =>
      gen.FFmpegKitSessionState.fromValue(
          getSessionByHandle(handle)?.state ?? 0);

  @override
  int ffmpeg_kit_session_get_return_code(Pointer<Void> handle) =>
      getSessionByHandle(handle)?.returnCode ?? -1;

  @override
  Pointer<Char> ffmpeg_kit_session_get_output(Pointer<Void> handle) {
    final out = getSessionByHandle(handle)?.output ?? "";
    return out.toNativeUtf8().cast();
  }

  @override
  Pointer<Char> ffmpeg_kit_session_get_command(Pointer<Void> handle) {
    final cmd = getSessionByHandle(handle)?.command ?? "";
    return cmd.toNativeUtf8().cast();
  }

  @override
  int ffmpeg_kit_session_get_create_time(Pointer<Void> handle) =>
      getSessionByHandle(handle)?.createTime ?? 0;

  @override
  int ffmpeg_kit_session_get_start_time(Pointer<Void> handle) =>
      getSessionByHandle(handle)?.startTime ?? 0;

  @override
  int ffmpeg_kit_session_get_end_time(Pointer<Void> handle) =>
      getSessionByHandle(handle)?.endTime ?? 0;

  @override
  int ffmpeg_kit_session_get_duration(Pointer<Void> handle) =>
      getSessionByHandle(handle)?.duration ?? 0;

  @override
  int ffmpeg_kit_session_get_logs_count(Pointer<Void> handle) =>
      getSessionByHandle(handle)?.logs.length ?? 0;

  @override
  Pointer<Char> ffmpeg_kit_session_get_log_at(Pointer<Void> handle, int index) {
    final s = getSessionByHandle(handle);
    if (s == null || index < 0 || index >= s.logs.length) return nullptr;
    return s.logs[index].toNativeUtf8().cast();
  }

  @override
  int ffmpeg_kit_session_get_log_level_at(Pointer<Void> handle, int index) =>
      gen.FFmpegKitLogLevel.FFMPEG_KIT_LOG_LEVEL_INFO.value;

  @override
  int ffmpeg_kit_session_get_statistics_count(Pointer<Void> handle) => 0;

  @override
  Pointer<Void> ffmpeg_kit_session_get_statistics_at(
          Pointer<Void> handle, int index) =>
      nullptr;

  @override
  Pointer<Char> ffmpeg_kit_session_get_logs_as_string(Pointer<Void> handle) {
    final logs = getSessionByHandle(handle)?.logs.join("\n") ?? "";
    return logs.toNativeUtf8().cast();
  }

  @override
  Pointer<Char> ffmpeg_kit_session_get_fail_stack_trace(Pointer<Void> handle) =>
      nullptr;

  @override
  void ffmpeg_kit_handle_release(Pointer<Void> handle) {}

  @override
  void ffmpeg_kit_cancel_session(int sessionId) {
    final session = _sessions[sessionId];
    if (session != null && session.state == SessionState.running.value) {
      session.state = SessionState.completed.value;
      session.returnCode = ReturnCode.cancel.value;
    }
  }

  @override
  void ffmpeg_kit_cancel() {
    for (var session in _sessions.values) {
      if (session.state == SessionState.running.value) {
        session.state = SessionState.completed.value;
        session.returnCode = ReturnCode.cancel.value;
        session.endTime = DateTime.now().millisecondsSinceEpoch;
        _triggerFFmpegComplete(Pointer.fromAddress(session.id), nullptr);
      }
    }
  }

  void _triggerFFmpegComplete(Pointer<Void> handle, Pointer<Void> userData) {
    if (userData == nullptr) {
      userData = globalFFmpegCompleteUserData;
      if (globalFFmpegCompleteCb != nullptr) {
        final dartCb = globalFFmpegCompleteCb
            .asFunction<gen.DartFFmpegKitCompleteCallbackFunction>();
        dartCb(handle, userData);
      }
    } else {
      // Per-session callback (if any was passed to execute_async_full handled elsewhere)
    }
  }

  @override
  void ffmpeg_kit_clear_sessions() {
    _sessions.clear();
    _sessionHistory.clear();
  }

  gen.FFmpegKitLogLevel _logLevel =
      gen.FFmpegKitLogLevel.FFMPEG_KIT_LOG_LEVEL_DEBUG;

  @override
  void ffmpeg_kit_config_set_log_level(gen.FFmpegKitLogLevel level) {
    _logLevel = level;
  }

  @override
  gen.FFmpegKitLogLevel ffmpeg_kit_config_get_log_level() => _logLevel;

  @override
  void ffmpeg_kit_config_enable_log_callback(
      gen.FFmpegKitLogCallback log_cb, Pointer<Void> user_data) {
    globalLogCb = log_cb;
    globalLogUserData = user_data;
  }

  @override
  void ffmpeg_kit_config_enable_statistics_callback(
      gen.FFmpegKitStatisticsCallback stats_cb, Pointer<Void> user_data) {
    globalStatsCb = stats_cb;
    globalStatsUserData = user_data;
  }

  @override
  void ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
      gen.FFmpegKitCompleteCallback complete_cb, Pointer<Void> user_data) {
    globalFFmpegCompleteCb = complete_cb;
    globalFFmpegCompleteUserData = user_data;
  }

  @override
  void ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
      gen.FFmpegKitCompleteCallback complete_cb, Pointer<Void> user_data) {
    globalFFprobeCompleteCb = complete_cb;
    globalFFprobeCompleteUserData = user_data;
  }

  @override
  void ffmpeg_kit_config_enable_ffplay_session_complete_callback(
      gen.FFplayKitCompleteCallback complete_cb, Pointer<Void> user_data) {
    globalFFplayCompleteCb = complete_cb;
    globalFFplayCompleteUserData = user_data;
  }

  @override
  void ffmpeg_kit_config_enable_media_information_session_complete_callback(
      gen.MediaInformationSessionCompleteCallback complete_cb,
      Pointer<Void> user_data) {
    globalMediaInfoCompleteCb = complete_cb;
    globalMediaInfoCompleteUserData = user_data;
  }

  // --- Creation & Execution ---

  Pointer<Void> _createSession(String command, {bool isFFmpeg = true}) {
    final id = _nextSessionId++;
    final session = MockSessionData(id);
    session.command = command;
    session.createTime = DateTime.now().millisecondsSinceEpoch;
    session.startTime = DateTime.now().millisecondsSinceEpoch;
    session.state = SessionState.created.value;
    _sessions[id] = session;
    _sessionHistory.add(id);
    if (_sessionHistory.length > _sessionHistorySize) {
      _sessionHistory.removeAt(0);
    }
    return Pointer.fromAddress(id);
  }

  @override
  gen.FFmpegSessionHandle ffmpeg_kit_create_session(Pointer<Char> command) =>
      _createSession(command.cast<Utf8>().toDartString());

  @override
  void ffmpeg_kit_session_execute(gen.FFmpegSessionHandle session) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.state = SessionState.running.value;
      s.state = SessionState.completed.value;
      s.returnCode = ReturnCode.success.value;
      s.endTime = DateTime.now().millisecondsSinceEpoch;
      s.logs.add("Executed synchronously");
    }
  }

  @override
  void ffmpeg_kit_session_execute_async(gen.FFmpegSessionHandle session) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.state = SessionState.running.value;
      Future.microtask(() {
        if (globalLogCb != nullptr) {
          final dartCb =
              globalLogCb.asFunction<gen.DartFFmpegKitLogCallbackFunction>();
          final msg = "Mock Session Log".toNativeUtf8();
          dartCb(session, msg.cast(), globalLogUserData);
        }
        if (globalStatsCb != nullptr) {
          final dartCb = globalStatsCb
              .asFunction<gen.DartFFmpegKitStatisticsCallbackFunction>();
          dartCb(session, 100, 100, 1.0, 1.0, 1, 1.0, 1.0, globalStatsUserData);
        }

        s.state = SessionState.completed.value;
        s.returnCode = ReturnCode.success.value;
        s.endTime = DateTime.now().millisecondsSinceEpoch;

        if (globalFFmpegCompleteCb != nullptr) {
          final dartCb = globalFFmpegCompleteCb
              .asFunction<gen.DartFFmpegKitCompleteCallbackFunction>();
          dartCb(session, globalFFmpegCompleteUserData);
        }
      });
    } else {
    }
  }

  @override
  gen.FFmpegSessionHandle ffmpeg_kit_execute(Pointer<Char> command) {
    final handle = ffmpeg_kit_create_session(command);
    ffmpeg_kit_session_execute(handle);
    return handle;
  }

  @override
  gen.FFmpegSessionHandle ffmpeg_kit_execute_async(Pointer<Char> command,
      gen.FFmpegKitCompleteCallback complete_cb, Pointer<Void> user_data) => ffmpeg_kit_execute_async_full(
        command, complete_cb, nullptr, nullptr, user_data, 0);

  @override
  gen.FFmpegSessionHandle ffmpeg_kit_execute_async_full(
      Pointer<Char> command,
      gen.FFmpegKitCompleteCallback completeCb,
      gen.FFmpegKitLogCallback logCb,
      gen.FFmpegKitStatisticsCallback statsCb,
      Pointer<Void> userData,
      int waitTimeout) {
    final handle = ffmpeg_kit_create_session(command);
    final id = handle.address;
    final s = getSessionData(id);

    s.state = SessionState.running.value;

    Future.microtask(() {
      if (logCb != nullptr) {
        final dartLogCallback =
            logCb.asFunction<gen.DartFFmpegKitLogCallbackFunction>();
        final logMsg = "Mock Log Message".toNativeUtf8();
        dartLogCallback(handle, logMsg.cast(), userData);
        // Do not free logMsg here as NativeCallable.listener is async
      }

      if (statsCb != nullptr) {
        final dartStatsCallback =
            statsCb.asFunction<gen.DartFFmpegKitStatisticsCallbackFunction>();
        dartStatsCallback(
            handle, 1000, 500, 128.0, 1.0, 30, 30.0, 1.0, userData);
      }

      s.state = SessionState.completed.value;
      s.returnCode = ReturnCode.success.value;
      s.endTime = DateTime.now().millisecondsSinceEpoch;
      if (s.command.contains("-version")) {
        s.output = "ffmpeg version mock async";
      }

      if (completeCb != nullptr) {
        final dartCallback =
            completeCb.asFunction<gen.DartFFmpegKitCompleteCallbackFunction>();
        dartCallback(handle, userData);
      }
    });

    return handle;
  }

  @override
  int ffmpeg_kit_config_messages_in_transmit(int sessionId) => 0;

  // --- Session History ---
  @override
  void ffmpeg_kit_set_session_history_size(int size) {
    _sessionHistorySize = size;
  }

  @override
  int ffmpeg_kit_get_session_history_size() => _sessionHistorySize;

  @override
  Pointer<gen.FFmpegSessionHandle> ffmpeg_kit_get_sessions() {
    final list = _sessions.keys.toList();
    final ptr = calloc<gen.FFmpegSessionHandle>(list.length + 1);
    for (int i = 0; i < list.length; i++) {
      ptr[i] = Pointer.fromAddress(list[i]);
    }
    ptr[list.length] = nullptr;
    return ptr;
  }

  @override
  Pointer<gen.FFmpegSessionHandle> ffmpeg_kit_get_ffmpeg_sessions() =>
      ffmpeg_kit_get_sessions();

  @override
  Pointer<gen.FFprobeSessionHandle> ffmpeg_kit_get_ffprobe_sessions() =>
      nullptr;

  @override
  Pointer<gen.FFplaySessionHandle> ffmpeg_kit_get_ffplay_sessions() => nullptr;

  @override
  Pointer<gen.MediaInformationSessionHandle>
      ffmpeg_kit_get_media_information_sessions() => nullptr;

  @override
  gen.FFmpegSessionHandle ffmpeg_kit_get_session(int sessionId) {
    if (_sessions.containsKey(sessionId)) {
      return Pointer.fromAddress(sessionId);
    }
    return nullptr;
  }

  @override
  gen.FFmpegSessionHandle ffmpeg_kit_get_last_session() =>
      _sessionHistory.isNotEmpty
          ? Pointer.fromAddress(_sessionHistory.last)
          : nullptr;

  @override
  gen.FFmpegSessionHandle ffmpeg_kit_get_last_completed_session() {
    for (final id in _sessionHistory.reversed) {
      if (_sessions[id]?.state == SessionState.completed.value) {
        return Pointer.fromAddress(id);
      }
    }
    return nullptr;
  }

  @override
  gen.FFmpegSessionHandle ffmpeg_kit_get_last_ffmpeg_session() =>
      ffmpeg_kit_get_last_session();
  @override
  gen.FFprobeSessionHandle ffmpeg_kit_get_last_ffprobe_session() => nullptr;
  @override
  gen.FFplaySessionHandle ffmpeg_kit_get_last_ffplay_session() => nullptr;
  @override
  gen.MediaInformationSessionHandle
      ffmpeg_kit_get_last_media_information_session() => nullptr;

  // --- FFprobe ---
  @override
  gen.FFprobeSessionHandle ffprobe_kit_create_session(Pointer<Char> command) =>
      _createSession(command.cast<Utf8>().toDartString(), isFFmpeg: false);

  @override
  void ffprobe_kit_session_execute(gen.FFprobeSessionHandle session) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.state = SessionState.completed.value;
      s.returnCode = ReturnCode.success.value;
      s.endTime = DateTime.now().millisecondsSinceEpoch;
    }
  }

  @override
  void ffprobe_kit_session_execute_async(gen.FFprobeSessionHandle session) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.state = SessionState.running.value;
      Future.microtask(() {
        s.state = SessionState.completed.value;
        s.returnCode = ReturnCode.success.value;
        s.endTime = DateTime.now().millisecondsSinceEpoch;

        if (globalFFprobeCompleteCb != nullptr) {
          final dartCb = globalFFprobeCompleteCb
              .asFunction<gen.DartFFmpegKitCompleteCallbackFunction>();
          dartCb(session, globalFFprobeCompleteUserData);
        }
      });
    }
  }

  @override
  void ffprobe_kit_cancel_session(int sessionId) {
    ffmpeg_kit_cancel_session(sessionId);
  }

  @override
  gen.FFprobeSessionHandle ffprobe_kit_execute(Pointer<Char> command) {
    final handle = ffprobe_kit_create_session(command);
    ffprobe_kit_session_execute(handle);
    return handle;
  }

  @override
  gen.MediaInformationSessionHandle ffprobe_kit_get_media_information(
      Pointer<Char> path) {
    final pathStr = path.cast<Utf8>().toDartString();
    final handle =
        _createSession("get_media_information $pathStr", isFFmpeg: false);
    final s = getSessionData(handle.address);
    s.state = SessionState.completed.value;
    s.returnCode = ReturnCode.success.value;
    s.endTime = DateTime.now().millisecondsSinceEpoch;
    return handle;
  }

  @override
  gen.MediaInformationSessionHandle media_information_create_session(
          Pointer<Char> command) =>
      _createSession(command.cast<Utf8>().toDartString(), isFFmpeg: false);

  @override
  void media_information_session_execute(
      gen.MediaInformationSessionHandle session, int timeout) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.state = SessionState.completed.value;
      s.returnCode = ReturnCode.success.value;
      s.endTime = DateTime.now().millisecondsSinceEpoch;
    }
  }

  @override
  gen.MediaInformationSessionHandle ffprobe_kit_get_media_information_async(
      Pointer<Char> path,
      gen.MediaInformationSessionCompleteCallback completeCb,
      Pointer<Void> userData) {
    final handle = ffprobe_kit_get_media_information(path);

    Future.microtask(() {
      if (completeCb != nullptr) {
        final dartCallback = completeCb.asFunction<
            gen.DartMediaInformationSessionCompleteCallbackFunction>();
        dartCallback(handle, userData);
      }
    });

    return handle;
  }

  @override
  void media_information_session_execute_async(
      gen.MediaInformationSessionHandle session, int timeout) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.state = SessionState.running.value;
      Future.microtask(() {
        s.state = SessionState.completed.value;
        s.returnCode = ReturnCode.success.value;
        s.endTime = DateTime.now().millisecondsSinceEpoch;

        if (globalMediaInfoCompleteCb != nullptr) {
          final dartCb = globalMediaInfoCompleteCb.asFunction<
              gen.DartMediaInformationSessionCompleteCallbackFunction>();
          dartCb(session, globalMediaInfoCompleteUserData);
        }
      });
    }
  }

  MockMediaInformation? _getMockMediaInfoFromHandle(
      gen.MediaInformationHandle handle) {
    if (handle == nullptr) return null;
    return _mediaInfoMap[handle.address];
  }

  @override
  gen.MediaInformationHandle media_information_session_get_media_information(
      gen.MediaInformationSessionHandle session) {
    final s = getSessionByHandle(session);
    if (s == null) return nullptr;
    final parts = s.command.split(" ");
    if (parts.length < 2) return nullptr;
    final path = parts.sublist(1).join(" ");

    final handle = _pathToMediaInfoHandle[path];
    if (handle != null) {
      return Pointer.fromAddress(handle);
    }
    return nullptr;
  }

  // MediaInfo Getters

  Pointer<Char> _str(String? s) => (s ?? "").toNativeUtf8().cast();

  @override
  Pointer<Char> media_information_get_filename(
          gen.MediaInformationHandle handle) =>
      _str(_getMockMediaInfoFromHandle(handle)?.filename);

  @override
  Pointer<Char> media_information_get_format(
          gen.MediaInformationHandle handle) =>
      _str(_getMockMediaInfoFromHandle(handle)?.format);

  @override
  Pointer<Char> media_information_get_long_format(
          gen.MediaInformationHandle handle) =>
      _str(_getMockMediaInfoFromHandle(handle)?.longFormat);

  @override
  Pointer<Char> media_information_get_duration(
          gen.MediaInformationHandle handle) =>
      _str(_getMockMediaInfoFromHandle(handle)?.duration);

  @override
  Pointer<Char> media_information_get_start_time(
          gen.MediaInformationHandle handle) =>
      _str(_getMockMediaInfoFromHandle(handle)?.startTime);

  @override
  Pointer<Char> media_information_get_bitrate(
          gen.MediaInformationHandle handle) =>
      _str(_getMockMediaInfoFromHandle(handle)?.bitrate);

  @override
  Pointer<Char> media_information_get_size(gen.MediaInformationHandle handle) =>
      _str(_getMockMediaInfoFromHandle(handle)?.size);

  @override
  Pointer<Char> media_information_get_tags_json(
          gen.MediaInformationHandle handle) =>
      _str(_getMockMediaInfoFromHandle(handle)?.tagsJson);

  @override
  Pointer<Char> media_information_get_all_properties_json(
          gen.MediaInformationHandle handle) =>
      _str(_getMockMediaInfoFromHandle(handle)?.allPropertiesJson);

  // Streams
  @override
  int media_information_get_streams_count(gen.MediaInformationHandle handle) =>
      _getMockMediaInfoFromHandle(handle)?.streams.length ?? 0;

  @override
  gen.StreamInformationHandle media_information_get_stream_at(
      gen.MediaInformationHandle handle, int index) {
    final info = _getMockMediaInfoFromHandle(handle);
    if (info == null || index < 0 || index >= info.streams.length)
      return nullptr;
    final stream = info.streams[index];
    final streamHandle = 5000 + (handle.address % 1000) * 10 + index;
    _streamHandles[streamHandle] = stream;
    return Pointer.fromAddress(streamHandle);
  }

  MockStreamInformation? _getStream(gen.StreamInformationHandle handle) =>
      _streamHandles[handle.address];

  @override
  int stream_information_get_index(gen.StreamInformationHandle handle) =>
      _getStream(handle)?.index ?? 0;

  @override
  Pointer<Char> stream_information_get_type(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.type);

  @override
  Pointer<Char> stream_information_get_codec(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.codec);

  @override
  Pointer<Char> stream_information_get_codec_long(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.codecLong);

  @override
  Pointer<Char> stream_information_get_format(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.format);

  @override
  int stream_information_get_width(gen.StreamInformationHandle handle) =>
      _getStream(handle)?.width ?? 0;

  @override
  int stream_information_get_height(gen.StreamInformationHandle handle) =>
      _getStream(handle)?.height ?? 0;

  @override
  Pointer<Char> stream_information_get_bitrate(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.bitrate);

  @override
  Pointer<Char> stream_information_get_sample_rate(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.sampleRate);

  @override
  Pointer<Char> stream_information_get_sample_format(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.sampleFormat);

  @override
  Pointer<Char> stream_information_get_channel_layout(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.channelLayout);

  @override
  Pointer<Char> stream_information_get_sample_aspect_ratio(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.sampleAspectRatio);

  @override
  Pointer<Char> stream_information_get_display_aspect_ratio(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.displayAspectRatio);

  @override
  Pointer<Char> stream_information_get_average_frame_rate(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.averageFrameRate);

  @override
  Pointer<Char> stream_information_get_real_frame_rate(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.realFrameRate);

  @override
  Pointer<Char> stream_information_get_time_base(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.timeBase);

  @override
  Pointer<Char> stream_information_get_codec_time_base(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.codecTimeBase);

  @override
  Pointer<Char> stream_information_get_tags_json(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.tagsJson);

  @override
  Pointer<Char> stream_information_get_all_properties_json(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.allPropertiesJson);

  // Chapters
  @override
  int media_information_get_chapters_count(gen.MediaInformationHandle handle) =>
      _getMockMediaInfoFromHandle(handle)?.chapters.length ?? 0;

  @override
  gen.ChapterHandle media_information_get_chapter_at(
      gen.MediaInformationHandle handle, int index) {
    final info = _getMockMediaInfoFromHandle(handle);
    if (info == null || index < 0 || index >= info.chapters.length)
      return nullptr;
    final chapter = info.chapters[index];
    final chapterHandle = 6000 + (handle.address % 1000) * 10 + index;
    _chapterHandles[chapterHandle] = chapter;
    return Pointer.fromAddress(chapterHandle);
  }

  MockChapterInformation? _getChapter(gen.ChapterHandle handle) =>
      _chapterHandles[handle.address];

  @override
  int chapter_get_id(gen.ChapterHandle handle) => _getChapter(handle)?.id ?? 0;

  @override
  Pointer<Char> chapter_get_time_base(gen.ChapterHandle handle) =>
      _str(_getChapter(handle)?.timeBase);

  @override
  int chapter_get_start(gen.ChapterHandle handle) =>
      _getChapter(handle)?.start ?? 0;

  @override
  Pointer<Char> chapter_get_start_time(gen.ChapterHandle handle) =>
      _str(_getChapter(handle)?.startTime);

  @override
  int chapter_get_end(gen.ChapterHandle handle) =>
      _getChapter(handle)?.end ?? 0;

  @override
  Pointer<Char> chapter_get_end_time(gen.ChapterHandle handle) =>
      _str(_getChapter(handle)?.endTime);

  @override
  Pointer<Char> chapter_get_tags_json(gen.ChapterHandle handle) =>
      _str(_getChapter(handle)?.tagsJson);

  @override
  Pointer<Char> chapter_get_all_properties_json(gen.ChapterHandle handle) =>
      _str(_getChapter(handle)?.allPropertiesJson);

  // --- FFplay ---

  @override
  gen.FFplaySessionHandle ffplay_kit_create_session(Pointer<Char> command) =>
      _createSession(command.cast<Utf8>().toDartString(), isFFmpeg: false);

  @override
  gen.FFplaySessionHandle ffplay_kit_execute(
      Pointer<Char> command, int timeout) {
    final handle = ffplay_kit_create_session(command);
    ffplay_kit_session_execute(handle, timeout);
    return handle;
  }

  @override
  gen.FFplaySessionHandle ffplay_kit_execute_async(
      Pointer<Char> command,
      gen.FFplayKitCompleteCallback cb,
      Pointer<Void> userData,
      int waitTimeout) {
    final handle = ffplay_kit_create_session(command);
    final s = getSessionData(handle.address);
    s.state = SessionState.running.value;
    s.isPlaying = true;

    for (var other in _sessions.values) {
      if (other.id != s.id && other.isPlaying) {
        other.isPlaying = false;
        other.isPaused = false;
      }
    }

    Future.microtask(() {
      if (cb != nullptr) {
        final dartCallback =
            cb.asFunction<gen.DartFFplayKitCompleteCallbackFunction>();
        dartCallback(handle, userData);
      }
    });

    return handle;
  }

  @override
  void ffplay_kit_session_execute(
      gen.FFplaySessionHandle session, int timeout) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.state = SessionState.running.value;
      s.isPlaying = true;
    }
  }

  @override
  int ffplay_kit_session_is_playing(gen.FFplaySessionHandle session) =>
      (getSessionByHandle(session)?.isPlaying ?? false) ? 1 : 0;

  @override
  int ffplay_kit_session_is_paused(gen.FFplaySessionHandle session) =>
      (getSessionByHandle(session)?.isPaused ?? false) ? 1 : 0;

  @override
  void ffplay_kit_session_pause(gen.FFplaySessionHandle session) {
    getSessionByHandle(session)?.isPaused = true;
  }

  @override
  void ffplay_kit_session_resume(gen.FFplaySessionHandle session) {
    getSessionByHandle(session)?.isPaused = false;
  }

  @override
  void ffplay_kit_session_stop(gen.FFplaySessionHandle session) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.isPlaying = false;
      s.state = SessionState.completed.value;
    }
  }

  @override
  void ffplay_kit_session_seek(
      gen.FFplaySessionHandle session, double position) {
    final s = getSessionByHandle(session);
    if (s != null) s.position = position;
  }

  @override
  double ffplay_kit_session_get_position(gen.FFplaySessionHandle session) =>
      getSessionByHandle(session)?.position ?? 0.0;

  @override
  double ffplay_kit_session_get_duration(gen.FFplaySessionHandle session) =>
      10.0;

  @override
  void ffplay_kit_pause() {
    _ffplayGlobalPaused = true;
  }

  @override
  void ffplay_kit_resume() {
    _ffplayGlobalPaused = false;
  }

  @override
  void ffplay_kit_stop() {
    for (var s in _sessions.values) {
      if (s.isPlaying) {
        s.isPlaying = false;
        s.state = SessionState.completed.value;
      }
    }
  }

  @override
  int ffplay_kit_is_paused() => _ffplayGlobalPaused ? 1 : 0;

  @override
  void ffplay_kit_set_position(double position) {
    _ffplayGlobalPosition = position;
  }

  @override
  double ffplay_kit_get_position() => _ffplayGlobalPosition;

  @override
  double ffplay_kit_get_duration() => 10.0;

  @override
  void ffplay_kit_session_execute_async(
      gen.FFplaySessionHandle session, int timeout) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.state = SessionState.running.value;
      s.isPlaying = true;

      Future.microtask(() {
        if (globalFFplayCompleteCb != nullptr) {
          final dartCb = globalFFplayCompleteCb
              .asFunction<gen.DartFFplayKitCompleteCallbackFunction>();
          dartCb(session, globalFFplayCompleteUserData);
        }
      });
    }
  }

  @override
  void ffplay_kit_session_set_position(
      gen.FFplaySessionHandle session, double seconds) {
    final s = getSessionByHandle(session);
    if (s != null) s.position = seconds;
  }

  @override
  double ffplay_kit_session_get_volume(gen.FFplaySessionHandle session) => 1.0;

  @override
  void ffplay_kit_session_set_volume(
      gen.FFplaySessionHandle session, double volume) {}

  @override
  void ffplay_kit_session_start(gen.FFplaySessionHandle session) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.isPaused = false;
      s.isPlaying = true;
    }
  }

  @override
  void ffplay_kit_session_close(gen.FFplaySessionHandle session) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.state = SessionState.completed.value;
    }
  }

  @override
  gen.FFplaySessionHandle ffplay_kit_get_current_session() {
    if (_sessionHistory.isNotEmpty) {
      return Pointer.fromAddress(_sessionHistory.last);
    }
    return nullptr;
  }

  // --- config redirection / fonts / env ---
  @override
  void ffmpeg_kit_config_enable_redirection() {}

  @override
  void ffmpeg_kit_config_disable_redirection() {}

  @override
  void ffmpeg_kit_config_set_font_directory(
      Pointer<Char> path, Pointer<Char> mapping) {}

  @override
  void ffmpeg_kit_config_set_font_directory_list(
      Pointer<Pointer<Char>> fontDirectoryList,
      int fontDirectoryListCount,
      Pointer<Char> mapping) {}

  @override
  Pointer<Char> ffmpeg_kit_config_register_new_ffmpeg_pipe() {
    final pipe = "\\\\.\\pipe\\ffmpegkit_${_ffmpegPipes.length}";
    _ffmpegPipes.add(pipe);
    return pipe.toNativeUtf8().cast();
  }

  @override
  void ffmpeg_kit_config_close_ffmpeg_pipe(Pointer<Char> ffmpegPipePath) {}

  @override
  int ffmpeg_kit_config_set_environment_variable(
      Pointer<Char> name, Pointer<Char> value) {
    final n = name.cast<Utf8>().toDartString();
    final v = value.cast<Utf8>().toDartString();
    _environmentVariables[n] = v;
    return 0; // Success
  }

  @override
  void ffmpeg_kit_config_ignore_signal(gen.FFmpegKitSignal signal) {
    _ignoredSignals.add(signal.value);
  }

  @override
  Pointer<Char> ffmpeg_kit_config_log_level_to_string(
      gen.FFmpegKitLogLevel level) => "DEBUG".toNativeUtf8().cast();

  @override
  Pointer<Char> ffmpeg_kit_config_session_state_to_string(
      gen.FFmpegKitSessionState state) => "CREATED".toNativeUtf8().cast();
}
