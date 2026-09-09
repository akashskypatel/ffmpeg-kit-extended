import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'ffmpeg_kit_extended_flutter_loader.dart';
import '../../generated/ffmpeg_kit_bindings_native.dart' as bindings;
import '../backend.dart';
import 'callback_bridge_native.dart';

FFmpegKitBackend createPlatformBackend() => NativeFFmpegKitBackend();

final class NativeFFmpegKitBackend implements FFmpegKitBackend {
  @override
  Future<void> initialize() => initializeFFmpegKit();

  @override
  bool get initialized => isFFmpegKitInitialized;

  @override
  void requireInitialized() {
    if (!initialized) {
      throw StateError(
        'FFmpegKit is not initialized. Call FFmpegKitExtended.initialize() '
        'before using the backend.',
      );
    }
  }

  Pointer<Void> _pointer(SessionHandle handle) => handle.value as Pointer<Void>;

  String? _stringAndFree(Pointer<Char> pointer) {
    if (pointer.address == 0) return null;
    try {
      return pointer.cast<Utf8>().toDartString();
    } finally {
      bindings.ffmpeg_kit_free(pointer.cast());
    }
  }

  @override
  SessionHandle createFFmpegSession(String command) {
    requireInitialized();
    final commandPointer = command.toNativeUtf8(allocator: calloc);
    try {
      return SessionHandle(
        bindings.ffmpeg_kit_create_session(commandPointer.cast()),
      );
    } finally {
      calloc.free(commandPointer);
    }
  }

  @override
  SessionHandle createFFmpegSessionFromArguments(List<String> arguments) {
    requireInitialized();
    final argv = calloc<Pointer<Char>>(arguments.length);
    final strings = <Pointer<Utf8>>[];
    try {
      for (var i = 0; i < arguments.length; i++) {
        final value = arguments[i].toNativeUtf8(allocator: calloc);
        strings.add(value);
        argv[i] = value.cast();
      }
      return SessionHandle(
        bindings.ffmpeg_kit_create_session_from_argv(arguments.length, argv),
      );
    } finally {
      for (final value in strings) {
        calloc.free(value);
      }
      calloc.free(argv);
    }
  }

  @override
  SessionHandle createFFprobeSession(String command) {
    requireInitialized();
    final commandPointer = command.toNativeUtf8(allocator: calloc);
    try {
      return SessionHandle(
        bindings.ffprobe_kit_create_session(commandPointer.cast()),
      );
    } finally {
      calloc.free(commandPointer);
    }
  }

  @override
  SessionHandle createFFprobeSessionFromArguments(List<String> arguments) {
    requireInitialized();
    final argv = calloc<Pointer<Char>>(arguments.length);
    final strings = <Pointer<Utf8>>[];
    try {
      for (var i = 0; i < arguments.length; i++) {
        final value = arguments[i].toNativeUtf8(allocator: calloc);
        strings.add(value);
        argv[i] = value.cast();
      }
      return SessionHandle(
        bindings.ffprobe_kit_create_session_from_argv(arguments.length, argv),
      );
    } finally {
      for (final value in strings) {
        calloc.free(value);
      }
      calloc.free(argv);
    }
  }

  @override
  SessionHandle createFFplaySession(String command) {
    requireInitialized();
    final commandPointer = command.toNativeUtf8(allocator: calloc);
    try {
      return SessionHandle(
        bindings.ffplay_kit_create_session(commandPointer.cast()),
      );
    } finally {
      calloc.free(commandPointer);
    }
  }

  @override
  SessionHandle createFFplaySessionFromArguments(List<String> arguments) {
    requireInitialized();
    final argv = calloc<Pointer<Char>>(arguments.length);
    final strings = <Pointer<Utf8>>[];
    try {
      for (var i = 0; i < arguments.length; i++) {
        final value = arguments[i].toNativeUtf8(allocator: calloc);
        strings.add(value);
        argv[i] = value.cast();
      }
      return SessionHandle(
        bindings.ffplay_kit_create_session_from_argv(arguments.length, argv),
      );
    } finally {
      for (final value in strings) {
        calloc.free(value);
      }
      calloc.free(argv);
    }
  }

  @override
  SessionHandle createMediaInformationSession(String command) {
    requireInitialized();
    final commandPointer = command.toNativeUtf8(allocator: calloc);
    try {
      return SessionHandle(
        bindings.media_information_create_session(commandPointer.cast()),
      );
    } finally {
      calloc.free(commandPointer);
    }
  }

  @override
  SessionHandle createMediaInformationSessionFromArguments(
    List<String> arguments,
  ) {
    requireInitialized();
    final argv = calloc<Pointer<Char>>(arguments.length);
    final strings = <Pointer<Utf8>>[];
    try {
      for (var i = 0; i < arguments.length; i++) {
        final value = arguments[i].toNativeUtf8(allocator: calloc);
        strings.add(value);
        argv[i] = value.cast();
      }
      return SessionHandle(
        bindings.media_information_create_session_from_argv(
          arguments.length,
          argv,
        ),
      );
    } finally {
      for (final value in strings) {
        calloc.free(value);
      }
      calloc.free(argv);
    }
  }

  @override
  void configureFFmpegCallbacks() {
    bindings.ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
      nativeFFmpegComplete.nativeFunction,
      nullptr,
    );
    bindings.ffmpeg_kit_config_enable_statistics_callback(
      nativeFFmpegStatistics.nativeFunction,
      nullptr,
    );
  }

  @override
  void enableFFmpegLogCallback() {
    bindings.ffmpeg_kit_config_enable_log_callback(
      nativeFFmpegLog.nativeFunction,
      nullptr,
    );
  }

  @override
  void configureFFprobeCallbacks() {
    bindings.ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
      nativeFFprobeComplete.nativeFunction,
      nullptr,
    );
  }

  @override
  void configureMediaInformationCallbacks() {
    bindings
        .ffmpeg_kit_config_enable_media_information_session_complete_callback(
          nativeMediaInfoComplete.nativeFunction,
          nullptr,
        );
  }

  @override
  void enableFFprobeLogCallback() {
    bindings.ffmpeg_kit_config_enable_log_callback(
      nativeFFmpegLog.nativeFunction,
      nullptr,
    );
  }

  @override
  void executeFFmpegSession(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_execute(_pointer(handle));

  @override
  void executeFFmpegSessionAsync(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_execute_async(_pointer(handle));

  @override
  void executeFFprobeSession(SessionHandle handle) =>
      bindings.ffprobe_kit_session_execute(_pointer(handle));

  @override
  void executeFFprobeSessionAsync(SessionHandle handle) =>
      bindings.ffprobe_kit_session_execute_async(_pointer(handle));

  @override
  void executeFFplaySession(SessionHandle handle, int timeout) =>
      bindings.ffplay_kit_session_execute(_pointer(handle), timeout);

  @override
  void executeFFplaySessionAsync(SessionHandle handle, int timeout) =>
      bindings.ffplay_kit_session_execute_async(_pointer(handle), timeout);

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
      bindings.media_information_session_execute(_pointer(handle), timeout);

  @override
  void executeMediaInformationSessionAsync(SessionHandle handle, int timeout) =>
      bindings.media_information_session_execute_async(
        _pointer(handle),
        timeout,
      );

  @override
  MediaInformationSnapshot? getMediaInformation(SessionHandle handle) {
    final mediaHandle = bindings
        .media_information_session_get_media_information(_pointer(handle));
    if (mediaHandle.address == 0) return null;

    try {
      final chapters = <ChapterInformationSnapshot>[];
      final chapterCount = bindings.media_information_get_chapters_count(
        mediaHandle,
      );
      for (var i = 0; i < chapterCount; i++) {
        final chapter = bindings.media_information_get_chapter_at(
          mediaHandle,
          i,
        );
        if (chapter.address == 0) continue;
        try {
          chapters.add(
            ChapterInformationSnapshot(
              id: bindings.chapter_get_id(chapter),
              timeBase: _stringAndFree(bindings.chapter_get_time_base(chapter)),
              start: bindings.chapter_get_start(chapter),
              startTime: _stringAndFree(
                bindings.chapter_get_start_time(chapter),
              ),
              end: bindings.chapter_get_end(chapter),
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
      final streamCount = bindings.media_information_get_streams_count(
        mediaHandle,
      );
      for (var i = 0; i < streamCount; i++) {
        final stream = bindings.media_information_get_stream_at(mediaHandle, i);
        if (stream.address == 0) continue;
        try {
          streams.add(
            StreamInformationSnapshot(
              index: bindings.stream_information_get_index(stream),
              type: _stringAndFree(
                bindings.stream_information_get_type(stream),
              ),
              codec: _stringAndFree(
                bindings.stream_information_get_codec(stream),
              ),
              codecLong: _stringAndFree(
                bindings.stream_information_get_codec_long(stream),
              ),
              format: _stringAndFree(
                bindings.stream_information_get_format(stream),
              ),
              width: bindings.stream_information_get_width(stream),
              height: bindings.stream_information_get_height(stream),
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
  int getSessionState(SessionHandle handle) {
    requireInitialized();
    return bindings.ffmpeg_kit_session_get_state(_pointer(handle)).value;
  }

  @override
  int getReturnCode(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_return_code(_pointer(handle));

  @override
  int getSessionId(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_session_id(_pointer(handle));

  @override
  int getCreateTime(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_create_time(_pointer(handle));

  @override
  int getStartTime(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_start_time(_pointer(handle));

  @override
  int getEndTime(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_end_time(_pointer(handle));

  @override
  int getDuration(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_duration(_pointer(handle));

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
      bindings.ffmpeg_kit_session_get_logs_count(_pointer(handle));

  @override
  String? getLogAt(SessionHandle handle, int index) => _stringAndFree(
    bindings.ffmpeg_kit_session_get_log_at(_pointer(handle), index),
  );

  @override
  int getLogLevelAt(SessionHandle handle, int index) =>
      bindings.ffmpeg_kit_session_get_log_level_at(_pointer(handle), index);

  @override
  int getStatisticsCount(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_statistics_count(_pointer(handle));

  @override
  StatisticsSnapshot? getStatisticsAt(SessionHandle handle, int index) {
    final statisticsHandle = bindings.ffmpeg_kit_session_get_statistics_at(
      _pointer(handle),
      index,
    );
    if (statisticsHandle.address == 0) return null;

    try {
      return StatisticsSnapshot(
        timeElapsed: bindings
            .ffmpeg_kit_statistics_get_time_elapsed(statisticsHandle)
            .round(),
        time: bindings.ffmpeg_kit_statistics_get_time(statisticsHandle).round(),
        size: bindings.ffmpeg_kit_statistics_get_size(statisticsHandle),
        bitrate: bindings.ffmpeg_kit_statistics_get_bitrate(statisticsHandle),
        speed: bindings.ffmpeg_kit_statistics_get_speed(statisticsHandle),
        videoFrameNumber: bindings.ffmpeg_kit_statistics_get_video_frame_number(
          statisticsHandle,
        ),
        videoFps: bindings.ffmpeg_kit_statistics_get_video_fps(
          statisticsHandle,
        ),
        videoQuality: bindings.ffmpeg_kit_statistics_get_video_quality(
          statisticsHandle,
        ),
        dupFrames: bindings.ffmpeg_kit_statistics_get_dup_frames(
          statisticsHandle,
        ),
        dropFrames: bindings.ffmpeg_kit_statistics_get_drop_frames(
          statisticsHandle,
        ),
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

  String _requiredString(Pointer<Char> pointer) =>
      _stringAndFree(pointer) ?? '';

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
    final pathPtr = path.toNativeUtf8(allocator: calloc);
    final mappingPtr = (mapping ?? '').toNativeUtf8(allocator: calloc);
    try {
      bindings.ffmpeg_kit_config_set_font_directory(
        pathPtr.cast(),
        mappingPtr.cast(),
      );
    } finally {
      calloc.free(pathPtr);
      calloc.free(mappingPtr);
    }
  }

  @override
  void setAudioOutputDevice(String deviceName) {
    final ptr = deviceName.toNativeUtf8(allocator: calloc);
    try {
      bindings.ffmpeg_kit_config_set_audio_output_device(ptr.cast());
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  String listAudioOutputDevices() =>
      _requiredString(bindings.ffmpeg_kit_config_list_audio_output_devices());

  @override
  void setEnvironmentVariable(String name, String value) {
    final namePtr = name.toNativeUtf8(allocator: calloc);
    final valuePtr = value.toNativeUtf8(allocator: calloc);
    try {
      bindings.ffmpeg_kit_config_set_environment_variable(
        namePtr.cast(),
        valuePtr.cast(),
      );
    } finally {
      calloc.free(namePtr);
      calloc.free(valuePtr);
    }
  }

  @override
  void ignoreSignal(int signal) => bindings.ffmpeg_kit_config_ignore_signal(
    bindings.FFmpegKitSignal.fromValue(signal),
  );

  @override
  void setSessionHistorySize(int size) =>
      bindings.ffmpeg_kit_set_session_history_size(size);

  @override
  int getSessionHistorySize() => bindings.ffmpeg_kit_get_session_history_size();

  List<SessionHandle> _sessionList(Pointer<Pointer<Void>> pointer) {
    if (pointer == nullptr) return const [];
    final result = <SessionHandle>[];
    try {
      for (var i = 0; ; i++) {
        final value = pointer[i];
        if (value == nullptr) break;
        result.add(SessionHandle(value));
      }
      return result;
    } finally {
      bindings.ffmpeg_kit_free(pointer.cast());
    }
  }

  @override
  List<SessionHandle> getSessions() =>
      _sessionList(bindings.ffmpeg_kit_get_sessions().cast());

  @override
  List<SessionHandle> getFFmpegSessions() =>
      _sessionList(bindings.ffmpeg_kit_get_ffmpeg_sessions().cast());

  @override
  List<SessionHandle> getFFprobeSessions() =>
      _sessionList(bindings.ffmpeg_kit_get_ffprobe_sessions().cast());

  @override
  List<SessionHandle> getFFplaySessions() =>
      _sessionList(bindings.ffmpeg_kit_get_ffplay_sessions().cast());

  @override
  List<SessionHandle> getMediaInformationSessions() =>
      _sessionList(bindings.ffmpeg_kit_get_media_information_sessions().cast());

  SessionHandle? _optionalHandle(Pointer<Void> handle) =>
      handle == nullptr ? null : SessionHandle(handle);

  @override
  SessionHandle? getSessionById(int sessionId) =>
      _optionalHandle(bindings.ffmpeg_kit_get_session(sessionId));

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
  void configureLogCallback() => bindings.ffmpeg_kit_config_enable_log_callback(
    nativeFFmpegLog.nativeFunction,
    nullptr,
  );

  @override
  void configureStatisticsCallback() =>
      bindings.ffmpeg_kit_config_enable_statistics_callback(
        nativeFFmpegStatistics.nativeFunction,
        nullptr,
      );

  @override
  void configureFFmpegSessionCompleteCallback() =>
      bindings.ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
        nativeFFmpegComplete.nativeFunction,
        nullptr,
      );

  @override
  void configureFFprobeSessionCompleteCallback() =>
      bindings.ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
        nativeFFprobeComplete.nativeFunction,
        nullptr,
      );

  @override
  void configureFFplaySessionCompleteCallback() =>
      bindings.ffmpeg_kit_config_enable_ffplay_session_complete_callback(
        nativeFFplayComplete.nativeFunction,
        nullptr,
      );

  @override
  void configureMediaInformationSessionCompleteCallback() => bindings
      .ffmpeg_kit_config_enable_media_information_session_complete_callback(
        nativeMediaInfoComplete.nativeFunction,
        nullptr,
      );

  @override
  String? registerNewFFmpegPipe() =>
      _stringAndFree(bindings.ffmpeg_kit_config_register_new_ffmpeg_pipe());

  @override
  void closeFFmpegPipe(String pipePath) {
    final ptr = pipePath.toNativeUtf8(allocator: calloc);
    try {
      bindings.ffmpeg_kit_config_close_ffmpeg_pipe(ptr.cast());
    } finally {
      calloc.free(ptr);
    }
  }

  @override
  void setFontDirectoryList(List<String> directories, {String? mapping}) {
    final list = calloc<Pointer<Char>>(directories.length);
    final strings = <Pointer<Utf8>>[];
    final mappingPtr = mapping?.toNativeUtf8(allocator: calloc) ?? nullptr;
    try {
      for (var i = 0; i < directories.length; i++) {
        final value = directories[i].toNativeUtf8(allocator: calloc);
        strings.add(value);
        list[i] = value.cast();
      }
      bindings.ffmpeg_kit_config_set_font_directory_list(
        list,
        directories.length,
        mappingPtr.cast(),
      );
    } finally {
      for (final value in strings) {
        calloc.free(value);
      }
      calloc.free(list);
      if (mappingPtr != nullptr) calloc.free(mappingPtr);
    }
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
    final commandPtr = command.toNativeUtf8(allocator: calloc);
    final count = calloc<Int64>();
    try {
      final args = bindings.ffmpeg_kit_config_parse_arguments(
        commandPtr.cast(),
        count,
      );
      final result = <String>[];
      for (var i = 0; i < count.value; i++) {
        result.add(args[i].cast<Utf8>().toDartString());
        bindings.ffmpeg_kit_free(args[i].cast());
      }
      bindings.ffmpeg_kit_free(args.cast());
      return result;
    } finally {
      calloc.free(commandPtr);
      calloc.free(count);
    }
  }

  @override
  String argumentsToString(List<String> arguments) {
    final list = calloc<Pointer<Char>>(arguments.length);
    final strings = <Pointer<Utf8>>[];
    try {
      for (var i = 0; i < arguments.length; i++) {
        final value = arguments[i].toNativeUtf8(allocator: calloc);
        strings.add(value);
        list[i] = value.cast();
      }
      return _requiredString(
        bindings.ffmpeg_kit_config_arguments_to_string(list, arguments.length),
      );
    } finally {
      for (final value in strings) {
        calloc.free(value);
      }
      calloc.free(list);
    }
  }

  @override
  int messagesInTransmit(int sessionId) =>
      bindings.ffmpeg_kit_config_messages_in_transmit(sessionId);
}
