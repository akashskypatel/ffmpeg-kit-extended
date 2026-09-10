import 'dart:async';

import '../../callback_manager.dart';
import '../../generated/ffmpeg_kit_bindings_web.dart' as bindings;
import '../backend.dart';
import 'wasm_loader.dart';
import 'wasm_memory.dart';

FFmpegKitBackend createPlatformBackend() => WebFFmpegKitBackend();

enum _WebCompletionKind { ffmpeg, ffprobe, ffplay, mediaInformation }

/// Web/Wasm implementation of the platform-neutral FFmpegKit backend.
///
/// Every FFmpegKit C ABI call goes through the generated ffigen_js bindings.
/// The loader and memory helpers are the only code that knows about the
/// Emscripten module and its heap.
final class WebFFmpegKitBackend implements FFmpegKitBackend {
  final Set<int> _polledSessions = <int>{};

  void _startSessionPolling(
    SessionHandle handle,
    _WebCompletionKind completionKind,
  ) {
    final sessionId = getSessionId(handle);
    if (!_polledSessions.add(sessionId)) return;

    unawaited(
      _pollSession(handle, sessionId, completionKind).whenComplete(() {
        _polledSessions.remove(sessionId);
      }),
    );
  }

  Future<void> _pollSession(
    SessionHandle handle,
    int sessionId,
    _WebCompletionKind completionKind,
  ) async {
    var statisticsProcessed = 0;

    while (true) {
      CallbackManager().dispatchPendingLogs(sessionId);
      statisticsProcessed = _dispatchStatistics(
        handle,
        sessionId,
        statisticsProcessed,
      );

      if (getSessionState(handle) >= 2) break;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    // Drain anything emitted between the last poll and the terminal state.
    CallbackManager().dispatchPendingLogs(sessionId);
    _dispatchStatistics(handle, sessionId, statisticsProcessed);

    switch (completionKind) {
      case _WebCompletionKind.ffmpeg:
        CallbackManager().dispatchFFmpegComplete(sessionId);
      case _WebCompletionKind.ffprobe:
        CallbackManager().dispatchFFprobeComplete(sessionId);
      case _WebCompletionKind.ffplay:
        CallbackManager().dispatchFFplayComplete(sessionId);
      case _WebCompletionKind.mediaInformation:
        CallbackManager().dispatchMediaInformationComplete(sessionId);
    }
  }

  int _dispatchStatistics(
    SessionHandle handle,
    int sessionId,
    int statisticsProcessed,
  ) {
    if (!_isFfmpegSession(sessionId)) return statisticsProcessed;

    final count = getStatisticsCount(handle);
    for (var index = statisticsProcessed; index < count; index++) {
      final snapshot = getStatisticsAt(handle, index);
      if (snapshot == null) continue;
      CallbackManager().dispatchStatistics(
        sessionId: sessionId,
        timeElapsed: snapshot.timeElapsed,
        time: snapshot.time,
        size: snapshot.size,
        bitrate: snapshot.bitrate,
        speed: snapshot.speed,
        videoFrameNumber: snapshot.videoFrameNumber,
        videoFps: snapshot.videoFps,
        videoQuality: snapshot.videoQuality,
        dupFrames: snapshot.dupFrames,
        dropFrames: snapshot.dropFrames,
      );
    }
    return count;
  }

  bool _isFfmpegSession(int sessionId) =>
      CallbackManager().ffmpegSessions.containsKey(sessionId);

  bindings.Pointer<bindings.Void> _pointer(SessionHandle handle) =>
      handle.value as bindings.Pointer<bindings.Void>;

  SessionHandle _handle(bindings.Pointer<bindings.Void> pointer) =>
      SessionHandle(pointer);

  String? _stringAndFree(bindings.Pointer<bindings.Char> pointer) =>
      wasmMemory.readAndFree(pointer);

  String _requiredString(bindings.Pointer<bindings.Char> pointer) =>
      _stringAndFree(pointer) ?? '';

  T _withArguments<T>(
    List<String> arguments,
    T Function(bindings.Pointer<bindings.PointerClass<bindings.Char>> argv)
    action,
  ) => wasmMemory.withArguments(arguments, action);

  @override
  Future<void> initialize() => wasmLoader.initialize();

  @override
  bool get initialized => wasmLoader.initialized;

  @override
  void requireInitialized() => wasmLoader.requireInitialized();

  @override
  SessionHandle createFFmpegSession(String command) {
    requireInitialized();
    return wasmMemory.withUtf8(
      command,
      (pointer) => _handle(bindings.ffmpeg_kit_create_session(pointer)),
    );
  }

  @override
  SessionHandle createFFmpegSessionFromArguments(List<String> arguments) {
    requireInitialized();
    return _withArguments(
      arguments,
      (argv) => _handle(
        bindings.ffmpeg_kit_create_session_from_argv(arguments.length, argv),
      ),
    );
  }

  @override
  SessionHandle createFFprobeSession(String command) {
    requireInitialized();
    return wasmMemory.withUtf8(
      command,
      (pointer) => _handle(bindings.ffprobe_kit_create_session(pointer)),
    );
  }

  @override
  SessionHandle createFFprobeSessionFromArguments(List<String> arguments) {
    requireInitialized();
    return _withArguments(
      arguments,
      (argv) => _handle(
        bindings.ffprobe_kit_create_session_from_argv(arguments.length, argv),
      ),
    );
  }

  @override
  SessionHandle createFFplaySession(String command) {
    requireInitialized();
    return wasmMemory.withUtf8(
      command,
      (pointer) => _handle(bindings.ffplay_kit_create_session(pointer)),
    );
  }

  @override
  SessionHandle createFFplaySessionFromArguments(List<String> arguments) {
    requireInitialized();
    return _withArguments(
      arguments,
      (argv) => _handle(
        bindings.ffplay_kit_create_session_from_argv(arguments.length, argv),
      ),
    );
  }

  @override
  SessionHandle createMediaInformationSession(String command) {
    requireInitialized();
    return wasmMemory.withUtf8(
      command,
      (pointer) => _handle(bindings.media_information_create_session(pointer)),
    );
  }

  @override
  SessionHandle createMediaInformationSessionFromArguments(
    List<String> arguments,
  ) {
    requireInitialized();
    return _withArguments(
      arguments,
      (argv) => _handle(
        bindings.media_information_create_session_from_argv(
          arguments.length,
          argv,
        ),
      ),
    );
  }

  @override
  void configureFFmpegCallbacks() {
    // The published Wasm bundle has no growable callback table. Web async
    // completion is therefore delivered by _pollSession below, which routes
    // through the same CallbackManager used by native callbacks.
  }

  @override
  void enableFFmpegLogCallback() {}

  @override
  void configureFFprobeCallbacks() {}

  @override
  void configureMediaInformationCallbacks() {}

  @override
  void enableFFprobeLogCallback() {}

  @override
  void executeFFmpegSession(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_execute(_pointer(handle));

  @override
  void executeFFmpegSessionAsync(SessionHandle handle) {
    bindings.ffmpeg_kit_session_execute_async(_pointer(handle));
    _startSessionPolling(handle, _WebCompletionKind.ffmpeg);
  }

  @override
  void executeFFprobeSession(SessionHandle handle) =>
      bindings.ffprobe_kit_session_execute(_pointer(handle));

  @override
  void executeFFprobeSessionAsync(SessionHandle handle) {
    bindings.ffprobe_kit_session_execute_async(_pointer(handle));
    _startSessionPolling(handle, _WebCompletionKind.ffprobe);
  }

  @override
  void executeFFplaySession(SessionHandle handle, int timeout) => bindings
      .ffplay_kit_session_execute(_pointer(handle), BigInt.from(timeout));

  @override
  void executeFFplaySessionAsync(SessionHandle handle, int timeout) {
    bindings.ffplay_kit_session_execute_async(
      _pointer(handle),
      BigInt.from(timeout),
    );
    _startSessionPolling(handle, _WebCompletionKind.ffplay);
  }

  @override
  void startFFplaySession(SessionHandle handle) =>
      bindings.ffplay_kit_session_start(_pointer(handle));

  @override
  void pauseFFplaySession(SessionHandle handle) =>
      bindings.ffplay_kit_session_pause(_pointer(handle));

  @override
  void resumeFFplaySession(SessionHandle handle) =>
      bindings.ffplay_kit_session_resume(_pointer(handle));

  @override
  void stopFFplaySession(SessionHandle handle) =>
      bindings.ffplay_kit_session_stop(_pointer(handle));

  @override
  void closeFFplaySession(SessionHandle handle) =>
      bindings.ffplay_kit_session_close(_pointer(handle));

  @override
  void seekFFplaySession(SessionHandle handle, double seconds) =>
      bindings.ffplay_kit_session_seek(_pointer(handle), seconds);

  @override
  void setFFplayPosition(SessionHandle handle, double seconds) =>
      bindings.ffplay_kit_session_set_position(_pointer(handle), seconds);

  @override
  double getFFplayPosition(SessionHandle handle) =>
      bindings.ffplay_kit_session_get_position(_pointer(handle));

  @override
  double getFFplayDuration(SessionHandle handle) =>
      bindings.ffplay_kit_session_get_duration(_pointer(handle));

  @override
  bool isFFplayPlaying(SessionHandle handle) =>
      bindings.ffplay_kit_session_is_playing(_pointer(handle));

  @override
  bool isFFplayPaused(SessionHandle handle) =>
      bindings.ffplay_kit_session_is_paused(_pointer(handle));

  @override
  void setFFplayVolume(SessionHandle handle, double volume) =>
      bindings.ffplay_kit_session_set_volume(_pointer(handle), volume);

  @override
  double getFFplayVolume(SessionHandle handle) =>
      bindings.ffplay_kit_session_get_volume(_pointer(handle));

  @override
  int getFFplayVideoWidth(SessionHandle handle) =>
      bindings.ffplay_kit_session_get_video_width(_pointer(handle));

  @override
  int getFFplayVideoHeight(SessionHandle handle) =>
      bindings.ffplay_kit_session_get_video_height(_pointer(handle));

  @override
  void executeMediaInformationSession(SessionHandle handle, int timeout) =>
      bindings.media_information_session_execute(
        _pointer(handle),
        BigInt.from(timeout),
      );

  @override
  void executeMediaInformationSessionAsync(SessionHandle handle, int timeout) {
    bindings.media_information_session_execute_async(
      _pointer(handle),
      BigInt.from(timeout),
    );
    _startSessionPolling(handle, _WebCompletionKind.mediaInformation);
  }

  @override
  MediaInformationSnapshot? getMediaInformation(SessionHandle handle) {
    final mediaHandle = bindings
        .media_information_session_get_media_information(_pointer(handle));
    if (mediaHandle.address == 0) return null;

    final chapters = <ChapterInformationSnapshot>[];
    final chapterCount = bindings
        .media_information_get_chapters_count(mediaHandle)
        .toInt();
    for (var i = 0; i < chapterCount; i++) {
      final chapter = bindings.media_information_get_chapter_at(
        mediaHandle,
        BigInt.from(i),
      );
      if (chapter.address == 0) continue;
      try {
        chapters.add(
          ChapterInformationSnapshot(
            id: bindings.chapter_get_id(chapter).toInt(),
            timeBase: _stringAndFree(bindings.chapter_get_time_base(chapter)),
            start: bindings.chapter_get_start(chapter).toInt(),
            startTime: _stringAndFree(bindings.chapter_get_start_time(chapter)),
            end: bindings.chapter_get_end(chapter).toInt(),
            endTime: _stringAndFree(bindings.chapter_get_end_time(chapter)),
            tagsJson: _stringAndFree(bindings.chapter_get_tags_json(chapter)),
            allPropertiesJson: _stringAndFree(
              bindings.chapter_get_all_properties_json(chapter),
            ),
          ),
        );
      } finally {
        bindings.ffmpeg_kit_handle_release(chapter);
      }
    }

    final streams = <StreamInformationSnapshot>[];
    final streamCount = bindings
        .media_information_get_streams_count(mediaHandle)
        .toInt();
    for (var i = 0; i < streamCount; i++) {
      final stream = bindings.media_information_get_stream_at(
        mediaHandle,
        BigInt.from(i),
      );
      if (stream.address == 0) continue;
      try {
        streams.add(
          StreamInformationSnapshot(
            index: bindings.stream_information_get_index(stream).toInt(),
            type: _stringAndFree(bindings.stream_information_get_type(stream)),
            codec: _stringAndFree(
              bindings.stream_information_get_codec(stream),
            ),
            codecLong: _stringAndFree(
              bindings.stream_information_get_codec_long(stream),
            ),
            format: _stringAndFree(
              bindings.stream_information_get_format(stream),
            ),
            width: bindings.stream_information_get_width(stream).toInt(),
            height: bindings.stream_information_get_height(stream).toInt(),
            bitrate: _stringAndFree(
              bindings.stream_information_get_bitrate(stream),
            ),
            sampleRate: _stringAndFree(
              bindings.stream_information_get_sample_rate(stream),
            ),
            sampleFormat: _stringAndFree(
              bindings.stream_information_get_sample_format(stream),
            ),
            channelLayout: _stringAndFree(
              bindings.stream_information_get_channel_layout(stream),
            ),
            sampleAspectRatio: _stringAndFree(
              bindings.stream_information_get_sample_aspect_ratio(stream),
            ),
            displayAspectRatio: _stringAndFree(
              bindings.stream_information_get_display_aspect_ratio(stream),
            ),
            averageFrameRate: _stringAndFree(
              bindings.stream_information_get_average_frame_rate(stream),
            ),
            realFrameRate: _stringAndFree(
              bindings.stream_information_get_real_frame_rate(stream),
            ),
            timeBase: _stringAndFree(
              bindings.stream_information_get_time_base(stream),
            ),
            codecTimeBase: _stringAndFree(
              bindings.stream_information_get_codec_time_base(stream),
            ),
            tagsJson: _stringAndFree(
              bindings.stream_information_get_tags_json(stream),
            ),
            allPropertiesJson: _stringAndFree(
              bindings.stream_information_get_all_properties_json(stream),
            ),
          ),
        );
      } finally {
        bindings.ffmpeg_kit_handle_release(stream);
      }
    }

    try {
      return MediaInformationSnapshot(
        filename: _stringAndFree(
          bindings.media_information_get_filename(mediaHandle),
        ),
        format: _stringAndFree(
          bindings.media_information_get_format(mediaHandle),
        ),
        longFormat: _stringAndFree(
          bindings.media_information_get_long_format(mediaHandle),
        ),
        duration: _stringAndFree(
          bindings.media_information_get_duration(mediaHandle),
        ),
        startTime: _stringAndFree(
          bindings.media_information_get_start_time(mediaHandle),
        ),
        bitrate: _stringAndFree(
          bindings.media_information_get_bitrate(mediaHandle),
        ),
        size: _stringAndFree(bindings.media_information_get_size(mediaHandle)),
        tagsJson: _stringAndFree(
          bindings.media_information_get_tags_json(mediaHandle),
        ),
        allPropertiesJson: _stringAndFree(
          bindings.media_information_get_all_properties_json(mediaHandle),
        ),
        streams: streams,
        chapters: chapters,
      );
    } finally {
      bindings.ffmpeg_kit_handle_release(mediaHandle);
    }
  }

  @override
  int getSessionState(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_state(_pointer(handle)).value;

  @override
  int getReturnCode(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_return_code(_pointer(handle)).toInt();

  @override
  int getSessionId(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_session_id(_pointer(handle)).toInt();

  @override
  int getCreateTime(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_create_time(_pointer(handle)).toInt();

  @override
  int getStartTime(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_start_time(_pointer(handle)).toInt();

  @override
  int getEndTime(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_end_time(_pointer(handle)).toInt();

  @override
  int getDuration(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_duration(_pointer(handle)).toInt();

  @override
  String? getCommand(SessionHandle handle) =>
      _stringAndFree(bindings.ffmpeg_kit_session_get_command(_pointer(handle)));

  @override
  String? getOutput(SessionHandle handle) =>
      _stringAndFree(bindings.ffmpeg_kit_session_get_output(_pointer(handle)));

  @override
  String? getLogsAsString(SessionHandle handle) => _stringAndFree(
    bindings.ffmpeg_kit_session_get_logs_as_string(_pointer(handle)),
  );

  @override
  String? getFailStackTrace(SessionHandle handle) => _stringAndFree(
    bindings.ffmpeg_kit_session_get_fail_stack_trace(_pointer(handle)),
  );

  @override
  int getLogsCount(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_logs_count(_pointer(handle)).toInt();

  @override
  String? getLogAt(SessionHandle handle, int index) => _stringAndFree(
    bindings.ffmpeg_kit_session_get_log_at(
      _pointer(handle),
      BigInt.from(index),
    ),
  );

  @override
  int getLogLevelAt(SessionHandle handle, int index) => bindings
      .ffmpeg_kit_session_get_log_level_at(_pointer(handle), BigInt.from(index))
      .toInt();

  @override
  int getStatisticsCount(SessionHandle handle) => bindings
      .ffmpeg_kit_session_get_statistics_count(_pointer(handle))
      .toInt();

  @override
  StatisticsSnapshot? getStatisticsAt(SessionHandle handle, int index) {
    final statisticsHandle = bindings.ffmpeg_kit_session_get_statistics_at(
      _pointer(handle),
      BigInt.from(index),
    );
    if (statisticsHandle.address == 0) return null;
    try {
      return StatisticsSnapshot(
        timeElapsed: bindings
            .ffmpeg_kit_statistics_get_time_elapsed(statisticsHandle)
            .round(),
        time: bindings.ffmpeg_kit_statistics_get_time(statisticsHandle).round(),
        size: bindings.ffmpeg_kit_statistics_get_size(statisticsHandle).toInt(),
        bitrate: bindings.ffmpeg_kit_statistics_get_bitrate(statisticsHandle),
        speed: bindings.ffmpeg_kit_statistics_get_speed(statisticsHandle),
        videoFrameNumber: bindings
            .ffmpeg_kit_statistics_get_video_frame_number(statisticsHandle)
            .toInt(),
        videoFps: bindings.ffmpeg_kit_statistics_get_video_fps(
          statisticsHandle,
        ),
        videoQuality: bindings.ffmpeg_kit_statistics_get_video_quality(
          statisticsHandle,
        ),
        dupFrames: bindings
            .ffmpeg_kit_statistics_get_dup_frames(statisticsHandle)
            .toInt(),
        dropFrames: bindings
            .ffmpeg_kit_statistics_get_drop_frames(statisticsHandle)
            .toInt(),
      );
    } finally {
      bindings.ffmpeg_kit_handle_release(statisticsHandle);
    }
  }

  @override
  void cancelSession(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_cancel(_pointer(handle));

  @override
  void releaseSession(SessionHandle handle) =>
      bindings.ffmpeg_kit_handle_release(_pointer(handle));

  @override
  bool isFFmpegSession(SessionHandle handle) =>
      bindings.session_is_ffmpeg_session(_pointer(handle));

  @override
  bool isFFplaySession(SessionHandle handle) =>
      bindings.session_is_ffplay_session(_pointer(handle));

  @override
  bool isFFprobeSession(SessionHandle handle) =>
      bindings.session_is_ffprobe_session(_pointer(handle));

  @override
  bool isMediaInformationSession(SessionHandle handle) =>
      bindings.session_is_media_information_session(_pointer(handle));

  @override
  void enableDebugLog(SessionHandle handle) =>
      bindings.session_enable_debug_log(_pointer(handle));

  @override
  void disableDebugLog(SessionHandle handle) =>
      bindings.session_disable_debug_log(_pointer(handle));

  @override
  bool isDebugLogEnabled(SessionHandle handle) =>
      bindings.session_is_debug_log_enabled(_pointer(handle));

  @override
  String? getDebugLog(SessionHandle handle) =>
      _stringAndFree(bindings.session_get_debug_log(_pointer(handle)));

  @override
  void clearDebugLog(SessionHandle handle) =>
      bindings.session_clear_debug_log(_pointer(handle));

  @override
  PackageInformationSnapshot getPackageInformation() =>
      PackageInformationSnapshot(
        ffmpegVersion: _requiredString(
          bindings.ffmpeg_kit_config_get_ffmpeg_version(),
        ),
        architecture: _requiredString(
          bindings.ffmpeg_kit_config_get_ffmpeg_architecture(),
        ),
        version: _requiredString(bindings.ffmpeg_kit_config_get_version()),
        packageName: _requiredString(
          bindings.ffmpeg_kit_packages_get_package_name(),
        ),
        externalLibraries: _requiredString(
          bindings.ffmpeg_kit_packages_get_external_libraries(),
        ),
        bundleType: _requiredString(
          bindings.ffmpeg_kit_packages_get_bundle_type(),
        ),
        isGpl: bindings.ffmpeg_kit_packages_get_is_gpl(),
        isNonfree: bindings.ffmpeg_kit_packages_get_is_nonfree(),
        registeredCodecs: _requiredString(
          bindings.ffmpeg_kit_packages_get_registered_codecs(),
        ),
        registeredEncoders: _requiredString(
          bindings.ffmpeg_kit_packages_get_registered_encoders(),
        ),
        registeredDecoders: _requiredString(
          bindings.ffmpeg_kit_packages_get_registered_decoders(),
        ),
        registeredMuxers: _requiredString(
          bindings.ffmpeg_kit_packages_get_registered_muxers(),
        ),
        registeredDemuxers: _requiredString(
          bindings.ffmpeg_kit_packages_get_registered_demuxers(),
        ),
        registeredFilters: _requiredString(
          bindings.ffmpeg_kit_packages_get_registered_filters(),
        ),
        registeredProtocols: _requiredString(
          bindings.ffmpeg_kit_packages_get_registered_protocols(),
        ),
        registeredBitstreamFilters: _requiredString(
          bindings.ffmpeg_kit_packages_get_registered_bitstream_filters(),
        ),
        buildConfiguration: _requiredString(
          bindings.ffmpeg_kit_packages_get_build_configuration(),
        ),
        buildDate: _requiredString(bindings.ffmpeg_kit_config_get_build_date()),
      );

  @override
  void setLogLevel(int level) => bindings.ffmpeg_kit_config_set_log_level(
    bindings.FFmpegKitLogLevel.fromValue(level),
  );

  @override
  int getLogLevel() => bindings.ffmpeg_kit_config_get_log_level().value;

  @override
  void enableRedirection() => bindings.ffmpeg_kit_config_enable_redirection();

  @override
  void disableRedirection() => bindings.ffmpeg_kit_config_disable_redirection();

  @override
  void setFontDirectory(String path, {String? mapping}) {
    wasmMemory.withUtf8(path, (pathPointer) {
      wasmMemory.withUtf8(mapping ?? '', (mappingPointer) {
        bindings.ffmpeg_kit_config_set_font_directory(
          pathPointer,
          mappingPointer,
        );
      });
    });
  }

  @override
  void setAudioOutputDevice(String deviceName) => wasmMemory.withUtf8(
    deviceName,
    bindings.ffmpeg_kit_config_set_audio_output_device,
  );

  @override
  String listAudioOutputDevices() =>
      _requiredString(bindings.ffmpeg_kit_config_list_audio_output_devices());

  @override
  void setEnvironmentVariable(String name, String value) {
    wasmMemory.withUtf8(name, (namePointer) {
      wasmMemory.withUtf8(value, (valuePointer) {
        bindings.ffmpeg_kit_config_set_environment_variable(
          namePointer,
          valuePointer,
        );
      });
    });
  }

  @override
  void ignoreSignal(int signal) => bindings.ffmpeg_kit_config_ignore_signal(
    bindings.FFmpegKitSignal.fromValue(signal),
  );

  @override
  void setSessionHistorySize(int size) =>
      bindings.ffmpeg_kit_set_session_history_size(BigInt.from(size));

  @override
  int getSessionHistorySize() =>
      bindings.ffmpeg_kit_get_session_history_size().toInt();

  List<SessionHandle> _sessionList(
    bindings.Pointer<bindings.PointerClass<bindings.Void>> pointer,
  ) {
    if (pointer.address == 0) return const [];
    final result = <SessionHandle>[];
    try {
      for (var i = 0; ; i++) {
        final value = pointer[i];
        if (value.address == 0) break;
        result.add(_handle(value));
      }
      return result;
    } finally {
      bindings.ffmpeg_kit_free(pointer.cast());
    }
  }

  @override
  List<SessionHandle> getSessions() =>
      _sessionList(bindings.ffmpeg_kit_get_sessions());

  @override
  List<SessionHandle> getFFmpegSessions() =>
      _sessionList(bindings.ffmpeg_kit_get_ffmpeg_sessions());

  @override
  List<SessionHandle> getFFprobeSessions() =>
      _sessionList(bindings.ffmpeg_kit_get_ffprobe_sessions());

  @override
  List<SessionHandle> getFFplaySessions() =>
      _sessionList(bindings.ffmpeg_kit_get_ffplay_sessions());

  @override
  List<SessionHandle> getMediaInformationSessions() =>
      _sessionList(bindings.ffmpeg_kit_get_media_information_sessions());

  SessionHandle? _optionalHandle(bindings.Pointer<bindings.Void> pointer) =>
      pointer.address == 0 ? null : _handle(pointer);

  @override
  SessionHandle? getSessionById(int sessionId) =>
      _optionalHandle(bindings.ffmpeg_kit_get_session(BigInt.from(sessionId)));

  @override
  SessionHandle? getLastSession() =>
      _optionalHandle(bindings.ffmpeg_kit_get_last_session());

  @override
  SessionHandle? getLastFFmpegSession() =>
      _optionalHandle(bindings.ffmpeg_kit_get_last_ffmpeg_session());

  @override
  SessionHandle? getLastFFprobeSession() =>
      _optionalHandle(bindings.ffmpeg_kit_get_last_ffprobe_session());

  @override
  SessionHandle? getLastFFplaySession() =>
      _optionalHandle(bindings.ffmpeg_kit_get_last_ffplay_session());

  @override
  SessionHandle? getLastMediaInformationSession() =>
      _optionalHandle(bindings.ffmpeg_kit_get_last_media_information_session());

  @override
  SessionHandle? getLastCompletedSession() =>
      _optionalHandle(bindings.ffmpeg_kit_get_last_completed_session());

  @override
  void clearSessions() => bindings.ffmpeg_kit_clear_sessions();

  @override
  void configureLogCallback() {}

  @override
  void configureStatisticsCallback() {}

  @override
  void configureFFmpegSessionCompleteCallback() {}

  @override
  void configureFFprobeSessionCompleteCallback() {}

  @override
  void configureFFplaySessionCompleteCallback() {}

  @override
  void configureMediaInformationSessionCompleteCallback() {}

  @override
  String? registerNewFFmpegPipe() =>
      _stringAndFree(bindings.ffmpeg_kit_config_register_new_ffmpeg_pipe());

  @override
  void closeFFmpegPipe(String pipePath) => wasmMemory.withUtf8(
    pipePath,
    bindings.ffmpeg_kit_config_close_ffmpeg_pipe,
  );

  @override
  void setFontDirectoryList(List<String> directories, {String? mapping}) {
    _withArguments(directories, (list) {
      wasmMemory.withUtf8(mapping ?? '', (mappingPointer) {
        bindings.ffmpeg_kit_config_set_font_directory_list(
          list,
          BigInt.from(directories.length),
          mappingPointer,
        );
      });
    });
  }

  @override
  String sessionStateToString(int state) => _requiredString(
    bindings.ffmpeg_kit_config_session_state_to_string(
      bindings.FFmpegKitSessionState.fromValue(state),
    ),
  );

  @override
  String? logLevelToString(int level) => _stringAndFree(
    bindings.ffmpeg_kit_config_log_level_to_string(
      bindings.FFmpegKitLogLevel.fromValue(level),
    ),
  );

  @override
  List<String> parseArguments(String command) {
    final count = wasmMemory.allocate<bindings.Int64>(8);
    bindings.Pointer<bindings.PointerClass<bindings.Char>>? args;
    final result = <String>[];
    try {
      args = wasmMemory.withUtf8(
        command,
        (commandPointer) =>
            bindings.ffmpeg_kit_config_parse_arguments(commandPointer, count),
      );
      final argsPointer = args;
      if (argsPointer == null || argsPointer.address == 0) return result;

      final length = count.getValue();
      for (var i = 0; i < length; i++) {
        final value = argsPointer[i];
        try {
          result.add(value.toDartString());
        } finally {
          wasmMemory.free(value.cast());
        }
      }
      return result;
    } finally {
      if (args != null && args.address != 0) wasmMemory.free(args.cast());
      wasmMemory.free(count.cast());
    }
  }

  @override
  String argumentsToString(List<String> arguments) => _withArguments(
    arguments,
    (list) => _requiredString(
      bindings.ffmpeg_kit_config_arguments_to_string(
        list,
        BigInt.from(arguments.length),
      ),
    ),
  );

  @override
  int messagesInTransmit(int sessionId) => bindings
      .ffmpeg_kit_config_messages_in_transmit(BigInt.from(sessionId))
      .toInt();
}
