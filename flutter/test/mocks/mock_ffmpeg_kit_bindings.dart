// ignore_for_file: non_constant_identifier_names, camel_case_types

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:ffmpeg_kit_extended_flutter/src/callback_manager.dart';
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
      if (Platform.isMacOS) {
        return DynamicLibrary.open('/usr/lib/libSystem.dylib');
      }
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
  double _ffplayGlobalVolume = 128.0;

  // Config state
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
    if (handle == nullptr || !_sessions.containsKey(handle.address)) {
      return null;
    }
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
  Pointer<Char> ffmpeg_kit_session_get_logs_as_string(Pointer<Void> handle) {
    final logs = getSessionByHandle(handle)?.logs.join("\n") ?? "";
    return logs.toNativeUtf8().cast();
  }

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
      }
    }
  }

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

  Pointer<Void> _createSession(String command) {
    final id = _nextSessionId++;
    final session = MockSessionData(id);
    session.command = command;
    session.createTime = DateTime.now().millisecondsSinceEpoch;
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
    }
  }

  @override
  void ffmpeg_kit_session_execute_async(gen.FFmpegSessionHandle session) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.state = SessionState.running.value;
      Future.delayed(const Duration(milliseconds: 100), () {
        if (globalLogCb != nullptr) {
          final dartCb =
              globalLogCb.asFunction<gen.DartFFmpegKitLogCallbackFunction>();
          final msg = "Mock Session Log".toNativeUtf8();
          dartCb(session, msg.cast(), globalLogUserData);
        }
        s.state = SessionState.completed.value;
        s.returnCode = ReturnCode.success.value;
        if (globalFFmpegCompleteCb != nullptr) {
          final dartCb = globalFFmpegCompleteCb
              .asFunction<gen.DartFFmpegKitCompleteCallbackFunction>();
          dartCb(session, globalFFmpegCompleteUserData);
        }
      });
    }
  }

  @override
  gen.FFmpegSessionHandle ffmpeg_kit_execute(Pointer<Char> command) {
    final handle = ffmpeg_kit_create_session(command);
    ffmpeg_kit_session_execute(handle);
    return handle;
  }

  @override
  gen.FFmpegSessionHandle ffmpeg_kit_execute_async_full(
      Pointer<Char> command,
      gen.FFmpegKitCompleteCallback completeCb,
      gen.FFmpegKitLogCallback logCb,
      gen.FFmpegKitStatisticsCallback statsCb,
      Pointer<Void> userData,
      int waitTimeout) {
    final handle = ffmpeg_kit_create_session(command);
    final s = getSessionData(handle.address);
    s.state = SessionState.running.value;
    Future.delayed(const Duration(milliseconds: 100), () {
      final callbackId = userData.address;
      final session = CallbackManager().getFFmpegSession(callbackId);

      if (session != null) {
        // Trigger log callback if session is valid
        // We create a Log object manually or if logCallback is exposed...
        // Session.logCallback is exposed.
        session.logCallback?.call(
            Log(handle.address, LogLevel.info.value, "Mock Log Message"));

        s.state = SessionState.completed.value;
        s.returnCode = ReturnCode.success.value;

        session.completeCallback?.call(session);
      }
    });
    return handle;
  }

  @override
  gen.FFprobeSessionHandle ffprobe_kit_create_session(Pointer<Char> command) =>
      _createSession(command.cast<Utf8>().toDartString());

  @override
  void ffprobe_kit_session_execute(gen.FFprobeSessionHandle session) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.state = SessionState.completed.value;
      s.returnCode = ReturnCode.success.value;
    }
  }

  @override
  void ffprobe_kit_session_execute_async(gen.FFprobeSessionHandle session) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.state = SessionState.running.value;
      Future.delayed(const Duration(milliseconds: 100), () {
        s.state = SessionState.completed.value;
        s.returnCode = ReturnCode.success.value;
        if (globalFFprobeCompleteCb != nullptr) {
          final dartCb = globalFFprobeCompleteCb
              .asFunction<gen.DartFFmpegKitCompleteCallbackFunction>();
          dartCb(session, globalFFprobeCompleteUserData);
        }
      });
    }
  }

  @override
  gen.FFprobeSessionHandle ffprobe_kit_execute_async(Pointer<Char> command,
      gen.FFprobeKitCompleteCallback complete_cb, Pointer<Void> user_data) {
    final handle = ffprobe_kit_create_session(command);
    final s = getSessionData(handle.address);
    s.state = SessionState.running.value;
    Future.delayed(const Duration(milliseconds: 100), () {
      s.state = SessionState.completed.value;
      s.returnCode = ReturnCode.success.value;

      final callbackId = user_data.address;
      final session = CallbackManager().getFFprobeSession(callbackId);
      if (session != null) {
        session.completeCallback?.call(session);
      }
    });
    return handle;
  }

  @override
  gen.MediaInformationSessionHandle ffprobe_kit_get_media_information(
          Pointer<Char> path) =>
      _createSession(
          "get_media_information ${path.cast<Utf8>().toDartString()}");

  @override
  gen.MediaInformationSessionHandle ffprobe_kit_get_media_information_async(
      Pointer<Char> path,
      gen.MediaInformationSessionCompleteCallback completeCb,
      Pointer<Void> userData) {
    final handle = ffprobe_kit_get_media_information(path);
    Future.delayed(const Duration(milliseconds: 50), () {
      final callbackId = userData.address;
      // MediaInfo sessions are registered as FFprobe sessions in CallbackManager
      final session = CallbackManager().getFFprobeSession(callbackId);
      if (session != null) {
        if (session is MediaInformationSession) {
          (session.completeCallback as MediaInformationSessionCompleteCallback?)
              ?.call(session);
        } else {
          session.completeCallback?.call(session);
        }
      }
    });
    return handle;
  }

  @override
  gen.MediaInformationSessionHandle media_information_create_session(
          Pointer<Char> command) =>
      _createSession(command.cast<Utf8>().toDartString());

  @override
  void media_information_session_execute(
      gen.MediaInformationSessionHandle session, int timeout) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.state = SessionState.completed.value;
      s.returnCode = ReturnCode.success.value;
    }
  }

  @override
  gen.MediaInformationHandle media_information_session_get_media_information(
      gen.MediaInformationSessionHandle session) {
    final s = getSessionByHandle(session);
    if (s == null) return nullptr;
    final parts = s.command.split(" ");
    final path = parts.last;
    final handle = _pathToMediaInfoHandle[path];
    return handle != null ? Pointer.fromAddress(handle) : nullptr;
  }

  MockMediaInformation? _getMockMediaInfoFromHandle(
          gen.MediaInformationHandle handle) =>
      handle != nullptr ? _mediaInfoMap[handle.address] : null;

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
  Pointer<Char> media_information_get_duration(
          gen.MediaInformationHandle handle) =>
      _str(_getMockMediaInfoFromHandle(handle)?.duration);
  @override
  Pointer<Char> media_information_get_bitrate(
          gen.MediaInformationHandle handle) =>
      _str(_getMockMediaInfoFromHandle(handle)?.bitrate);
  @override
  Pointer<Char> media_information_get_size(gen.MediaInformationHandle handle) =>
      _str(_getMockMediaInfoFromHandle(handle)?.size);

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
  int stream_information_get_width(gen.StreamInformationHandle handle) =>
      _getStream(handle)?.width ?? 0;
  @override
  int stream_information_get_height(gen.StreamInformationHandle handle) =>
      _getStream(handle)?.height ?? 0;
  @override
  Pointer<Char> stream_information_get_sample_rate(
          gen.StreamInformationHandle handle) =>
      _str(_getStream(handle)?.sampleRate);

  @override
  int chapter_get_id(gen.ChapterHandle handle) =>
      _chapterHandles[handle.address]?.id ?? 0;
  @override
  Pointer<Char> chapter_get_start_time(gen.ChapterHandle handle) =>
      _str(_chapterHandles[handle.address]?.startTime);

  // --- FFplay ---
  @override
  gen.FFplaySessionHandle ffplay_kit_create_session(Pointer<Char> command) =>
      _createSession(command.cast<Utf8>().toDartString());

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
  gen.FFplaySessionHandle ffplay_kit_execute(
      Pointer<Char> command, int timeout) {
    final handle = ffplay_kit_create_session(command);
    ffplay_kit_session_execute(handle, timeout);
    return handle;
  }

  @override
  gen.FFplaySessionHandle ffplay_kit_execute_async(
      Pointer<Char> command,
      gen.FFplayKitCompleteCallback complete_cb,
      Pointer<Void> user_data,
      int timeout) {
    final handle = ffplay_kit_create_session(command);
    final s = getSessionData(handle.address);
    s.state = SessionState.running.value;
    s.isPlaying = true;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (complete_cb != nullptr) {
        final dartCb =
            complete_cb.asFunction<gen.DartFFplayKitCompleteCallbackFunction>();
        dartCb(handle, user_data);
      }
    });
    return handle;
  }

  @override
  double ffplay_kit_session_get_duration(gen.FFplaySessionHandle session) =>
      60.0;
  @override
  double ffplay_kit_session_get_position(gen.FFplaySessionHandle session) =>
      getSessionByHandle(session)?.position ?? 0.0;
  @override
  void ffplay_kit_session_pause(gen.FFplaySessionHandle session) =>
      _ffplayGlobalPaused = true;
  @override
  void ffplay_kit_session_resume(gen.FFplaySessionHandle session) =>
      _ffplayGlobalPaused = false;
  @override
  void ffplay_kit_session_stop(gen.FFplaySessionHandle session) {
    final s = getSessionByHandle(session);
    if (s != null) s.isPlaying = false;
  }

  @override
  void ffplay_kit_session_seek(
      gen.FFplaySessionHandle session, double position) {
    final s = getSessionByHandle(session);
    if (s != null) s.position = position;
  }

  @override
  bool ffplay_kit_session_is_playing(gen.FFplaySessionHandle session) =>
      getSessionByHandle(session)?.isPlaying ?? false;
  @override
  bool ffplay_kit_session_is_paused(gen.FFplaySessionHandle session) =>
      _ffplayGlobalPaused;
  @override
  double ffplay_kit_session_get_volume(gen.FFplaySessionHandle session) =>
      _ffplayGlobalVolume;
  @override
  void ffplay_kit_session_set_volume(
          gen.FFplaySessionHandle session, double volume) =>
      _ffplayGlobalVolume = volume;

  @override
  void ffplay_kit_session_start(gen.FFplaySessionHandle session) {
    final s = getSessionByHandle(session);
    if (s != null) s.isPlaying = true;
  }

  @override
  void ffplay_kit_session_close(gen.FFplaySessionHandle session) {
    final s = getSessionByHandle(session);
    if (s != null) {
      s.isPlaying = false;
      s.state = SessionState.completed.value;
    }
  }

  @override
  void ffplay_kit_pause() => _ffplayGlobalPaused = true;
  @override
  void ffplay_kit_resume() => _ffplayGlobalPaused = false;
  @override
  void ffplay_kit_stop() {
    for (var s in _sessions.values) s.isPlaying = false;
  }

  @override
  void ffmpeg_kit_free(Pointer<Void> ptr) {
    if (ptr != nullptr) calloc.free(ptr);
  }

  // session size history
  @override
  void ffmpeg_kit_set_session_history_size(int size) {
    _sessionHistorySize = size;
  }

  @override
  int ffmpeg_kit_get_session_history_size() => _sessionHistorySize;

  // signals and pipes
  @override
  void ffmpeg_kit_config_ignore_signal(gen.FFmpegKitSignal signal) =>
      _ignoredSignals.add(signal.value);
  @override
  Pointer<Char> ffmpeg_kit_config_register_new_ffmpeg_pipe() {
    final pipe = "pipe:${_ffmpegPipes.length}";
    _ffmpegPipes.add(pipe);
    return pipe.toNativeUtf8().cast();
  }

  @override
  void ffmpeg_kit_clear_sessions() {
    _sessions.clear();
    _sessionHistory.clear();
  }

  Pointer<gen.FFmpegSessionHandle> _toHandleArray(
      Iterable<MockSessionData> sessions) {
    final list = sessions.toList();
    final count = list.length;
    // Allocate array of pointers (count + 1 for null terminator)
    final array = calloc<gen.FFmpegSessionHandle>(count + 1);

    for (int i = 0; i < count; i++) {
      array[i] = Pointer.fromAddress(list[i].id);
    }
    array[count] = nullptr;

    return array;
  }

  @override
  Pointer<gen.FFmpegSessionHandle> ffmpeg_kit_get_sessions() =>
      _toHandleArray(_sessions.values);

  @override
  Pointer<gen.FFmpegSessionHandle> ffmpeg_kit_get_ffmpeg_sessions() =>
      _toHandleArray(_sessions.values.where((s) =>
          !s.command.contains("ffprobe") &&
          !s.command.contains("get_media_information") &&
          !s.isPlaying));

  @override
  Pointer<gen.FFprobeSessionHandle> ffmpeg_kit_get_ffprobe_sessions() =>
      _toHandleArray(_sessions.values.where((s) =>
          s.command.contains("ffprobe") ||
          s.command.contains("get_media_information")));

  @override
  Pointer<gen.FFplaySessionHandle> ffmpeg_kit_get_ffplay_sessions() =>
      _toHandleArray(_sessions.values.where((s) => s.isPlaying));

  @override
  Pointer<gen.MediaInformationSessionHandle>
      ffmpeg_kit_get_media_information_sessions() =>
          _toHandleArray(_sessions.values
              .where((s) => s.command.contains("get_media_information")));
}
