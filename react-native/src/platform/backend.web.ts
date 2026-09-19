import type {MediaInformationData} from '../media-information';
import type {
  FFmpegKitBackend,
  FFmpegKitInitializeOptions,
  FFplayFrameCopyResult,
  StatisticsSnapshot,
} from './backend';
import {WasmSessionRegistry} from './web/session-registry';
import {
  initializeWasm,
  requireWasmModule,
  type WasmModule,
} from './web/wasm-loader';
import {beginFFplayPlayback} from './web/ffplay-frame-state';
import {SessionState} from '../types';

type WasmFunction = (...args: unknown[]) => unknown;

function fn<T extends WasmFunction>(module: WasmModule, name: string): T {
  const value = module[name] ?? module[`_${name}`];
  if (typeof value !== 'function') throw new Error(`Wasm export is unavailable: ${name}`);
  return value as T;
}

function numberResult(value: unknown): number {
  return typeof value === 'bigint' ? Number(value) : Number(value ?? 0);
}

function int64(value: number): bigint {
  return BigInt(Math.trunc(value));
}

function boolResult(value: unknown): boolean {
  return Boolean(value);
}

function jsonArray(value: unknown): string {
  return JSON.stringify(Array.isArray(value) ? value : []);
}

export class WebFFmpegKitBackend implements FFmpegKitBackend {
  private readonly sessions = new WasmSessionRegistry();
  private readonly executingSessions = new Set<number>();
  private readonly moduleOverride?: WasmModule;
  private initializeOptions?: FFmpegKitInitializeOptions;

  constructor(options?: FFmpegKitInitializeOptions, moduleOverride?: WasmModule) {
    this.initializeOptions = options;
    this.moduleOverride = moduleOverride;
  }

  private module(): WasmModule {
    return this.moduleOverride ?? requireWasmModule();
  }

  private call<T extends WasmFunction>(name: string): T {
    return fn<T>(this.module(), name);
  }

  private withString<T>(value: string, action: (pointer: number) => T): T {
    const module = this.module();
    const bytes = module.lengthBytesUTF8(value);
    const pointer = module._malloc(bytes + 1);
    try {
      module.stringToUTF8(value, pointer, bytes + 1);
      return action(pointer);
    } finally {
      module._free(pointer);
    }
  }

  private readString(pointer: unknown): string {
    const address = numberResult(pointer);
    if (!address) return '';
    try {
      return this.module().UTF8ToString(address);
    } finally {
      this.call('ffmpeg_kit_free')(address);
    }
  }

  private withArguments<T>(arguments_: readonly string[], action: (argv: number) => T): T {
    const module = this.module();
    const argv = module._malloc(Math.max(1, arguments_.length) * 4);
    const values: number[] = [];
    try {
      for (let index = 0; index < arguments_.length; index += 1) {
        const value = arguments_[index];
        const pointer = module._malloc(module.lengthBytesUTF8(value) + 1);
        values.push(pointer);
        module.stringToUTF8(value, pointer, module.lengthBytesUTF8(value) + 1);
        module.HEAPU32[argv / 4 + index] = pointer;
      }
      return action(argv);
    } finally {
      values.forEach(pointer => module._free(pointer));
      module._free(argv);
    }
  }

  private consumeCreatedSessionHandle(pointer: unknown): number {
    const address = numberResult(pointer);
    if (!address) throw new Error('Wasm returned an invalid session handle');

    let sessionId: number;
    try {
      sessionId = numberResult(this.call('ffmpeg_kit_session_get_session_id')(address));
      if (!sessionId) throw new Error('Wasm returned an invalid session handle');
    } catch (error) {
      try {
        this.call('ffmpeg_kit_handle_release')(address);
      } catch {
        // Preserve the creation failure as the primary error.
      }
      throw error;
    }

    // Keep ownership retryable until the native release commits.
    this.sessions.retain(address, sessionId);
    try {
      this.call('ffmpeg_kit_handle_release')(address);
      this.sessions.take(sessionId);
      return sessionId;
    } catch (error) {
      throw error;
    }
  }

  private pointerFor(sessionId: number): number {
    const retained = this.sessions.get(sessionId);
    if (retained) return retained;
    const pointer = numberResult(this.call('ffmpeg_kit_get_session')(int64(sessionId)));
    if (!pointer) throw new Error(`Session ${sessionId} no longer exists`);
    return pointer;
  }

  private withSession<T>(sessionId: number, action: (pointer: number) => T): T {
    const retained = this.sessions.get(sessionId);
    if (retained) return action(retained);
    return this.withTemporaryHandle(this.pointerFor(sessionId), action);
  }

  private withTemporaryHandle<T>(pointer: number, action: (pointer: number) => T): T {
    let result!: T;
    let primaryErrorSet = false;
    let primaryError: unknown;

    try {
      result = action(pointer);
    } catch (error) {
      primaryErrorSet = true;
      primaryError = error;
    }

    try {
      this.call('ffmpeg_kit_handle_release')(pointer);
    } catch (error) {
      if (!primaryErrorSet) {
        primaryErrorSet = true;
        primaryError = error;
      }
    }

    if (primaryErrorSet) throw primaryError;
    return result;
  }

  /** Retains a Created-state history handle for one async execution. */
  private retainForExecution(sessionId: number): number {
    if (this.executingSessions.has(sessionId)) {
      throw new Error(`Session ${sessionId} was already submitted for execution`);
    }

    const retained = this.sessions.get(sessionId);
    const pointer = retained ?? numberResult(this.call('ffmpeg_kit_get_session')(int64(sessionId)));
    if (!pointer) throw new Error(`Session ${sessionId} no longer exists`);

    let state: number;
    try {
      state = numberResult(this.call('ffmpeg_kit_session_get_state')(pointer));
    } catch (error) {
      if (!retained) this.withTemporaryHandle(pointer, () => { throw error; });
      throw error;
    }

    if (state !== SessionState.Created) {
      const error = new Error(`Session ${sessionId} cannot be executed from state ${state}`);
      if (!retained) this.withTemporaryHandle(pointer, () => { throw error; });
      throw error;
    }

    if (!retained) {
      try {
        this.sessions.retain(pointer, sessionId);
      } catch (error) {
        try {
          this.call('ffmpeg_kit_handle_release')(pointer);
        } catch {
          // Preserve the lookup or registration failure as the primary error.
        }
        throw error;
      }
    }
    this.executingSessions.add(sessionId);
    return pointer;
  }

  private sessionType(pointer: number): string {
    if (boolResult(this.call('session_is_ffmpeg_session')(pointer))) return 'ffmpeg';
    if (boolResult(this.call('session_is_ffprobe_session')(pointer))) return 'ffprobe';
    if (boolResult(this.call('session_is_ffplay_session')(pointer))) return 'ffplay';
    return 'media-information';
  }

  private snapshot(pointer: number): Record<string, unknown> {
    return {
      sessionId: numberResult(this.call('ffmpeg_kit_session_get_session_id')(pointer)),
      type: this.sessionType(pointer),
      state: numberResult(this.call('ffmpeg_kit_session_get_state')(pointer)),
      returnCode: numberResult(this.call('ffmpeg_kit_session_get_return_code')(pointer)),
      createTime: numberResult(this.call('ffmpeg_kit_session_get_create_time')(pointer)),
      startTime: numberResult(this.call('ffmpeg_kit_session_get_start_time')(pointer)),
      endTime: numberResult(this.call('ffmpeg_kit_session_get_end_time')(pointer)),
      duration: numberResult(this.call('ffmpeg_kit_session_get_duration')(pointer)),
      command: this.readString(this.call('ffmpeg_kit_session_get_command')(pointer)),
      output: this.readString(this.call('ffmpeg_kit_session_get_output')(pointer)),
      logs: this.readString(this.call('ffmpeg_kit_session_get_logs_as_string')(pointer)),
      failStackTrace: this.readString(this.call('ffmpeg_kit_session_get_fail_stack_trace')(pointer)),
      logsCount: numberResult(this.call('ffmpeg_kit_session_get_logs_count')(pointer)),
      statisticsCount: numberResult(this.call('ffmpeg_kit_session_get_statistics_count')(pointer)),
      debugLogEnabled: boolResult(this.call('session_is_debug_log_enabled')(pointer)),
    };
  }

  private snapshots(kind: string): Record<string, unknown>[] {
    const exportName = kind === 'ffmpeg'
      ? 'ffmpeg_kit_get_ffmpeg_sessions'
      : kind === 'ffprobe'
        ? 'ffmpeg_kit_get_ffprobe_sessions'
        : kind === 'ffplay'
          ? 'ffmpeg_kit_get_ffplay_sessions'
          : kind === 'media-information'
            ? 'ffmpeg_kit_get_media_information_sessions'
            : 'ffmpeg_kit_get_sessions';
    const arrayPointer = numberResult(this.call(exportName)());
    if (!arrayPointer) return [];
    const result: Record<string, unknown>[] = [];
    const pointers: number[] = [];
    let firstErrorSet = false;
    let firstError: unknown;
    const recordError = (error: unknown): void => {
      if (firstErrorSet) return;
      firstErrorSet = true;
      firstError = error;
    };

    try {
      for (let index = 0; ; index += 1) {
        let pointer: number;
        try {
          pointer = this.module().HEAPU32[arrayPointer / 4 + index];
        } catch (error) {
          recordError(error);
          break;
        }
        if (!pointer) break;
        pointers.push(pointer);
      }

      for (const pointer of pointers) {
        try {
          result.push(this.snapshot(pointer));
        } catch (error) {
          recordError(error);
          break;
        }
      }
    } finally {
      for (const pointer of pointers) {
        try {
          this.call('ffmpeg_kit_handle_release')(pointer);
        } catch (error) {
          recordError(error);
        }
      }
      try {
        this.call('ffmpeg_kit_free')(arrayPointer);
      } catch (error) {
        recordError(error);
      }
    }

    if (firstErrorSet) throw firstError;
    return result;
  }

  async initialize(options?: FFmpegKitInitializeOptions): Promise<void> {
    this.initializeOptions = options ?? this.initializeOptions;
    await initializeWasm(this.initializeOptions);
    this.call('ffmpeg_kit_initialize')();
  }

  getBuildStamp(): string { return this.readString(this.call('ffmpeg_kit_get_build_stamp')()); }

  createFFmpegSession(command: string): number {
    return this.withString(command, pointer => this.consumeCreatedSessionHandle(this.call('ffmpeg_kit_create_session')(pointer)));
  }

  createFFmpegSessionFromArguments(arguments_: readonly string[]): number {
    return this.withArguments(arguments_, argv => this.consumeCreatedSessionHandle(this.call('ffmpeg_kit_create_session_from_argv')(arguments_.length, argv)));
  }

  createFFprobeSession(command: string): number {
    return this.withString(command, pointer => this.consumeCreatedSessionHandle(this.call('ffprobe_kit_create_session')(pointer)));
  }

  createFFprobeSessionFromArguments(arguments_: readonly string[]): number {
    return this.withArguments(arguments_, argv => this.consumeCreatedSessionHandle(this.call('ffprobe_kit_create_session_from_argv')(arguments_.length, argv)));
  }

  createFFplaySession(command: string): number {
    return this.withString(command, pointer => this.consumeCreatedSessionHandle(this.call('ffplay_kit_create_session')(pointer)));
  }

  createFFplaySessionFromArguments(arguments_: readonly string[]): number {
    return this.withArguments(arguments_, argv => this.consumeCreatedSessionHandle(this.call('ffplay_kit_create_session_from_argv')(arguments_.length, argv)));
  }

  createMediaInformationSession(command: string): number {
    return this.withString(command, pointer => this.consumeCreatedSessionHandle(this.call('media_information_create_session')(pointer)));
  }

  createMediaInformationSessionFromPath(path: string): number {
    const arguments_ = [
      '-v',
      'error',
      '-hide_banner',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      '-show_chapters',
      '-i',
      path,
    ];
    return this.withArguments(arguments_, argv => this.consumeCreatedSessionHandle(this.call('media_information_create_session_from_argv')(arguments_.length, argv)));
  }

  executeSessionAsync(sessionId: number, timeoutMs: number): void {
    const pointer = this.retainForExecution(sessionId);
    try {
      const type = this.sessionType(pointer);
      if (type === 'ffplay') {
        this.call('ffplay_kit_session_execute_async')(pointer, int64(timeoutMs));
        beginFFplayPlayback();
      }
      else if (type === 'ffprobe') this.call('ffprobe_kit_session_execute_async')(pointer);
      else if (type === 'media-information') this.call('media_information_session_execute_async')(pointer, int64(timeoutMs));
      else this.call('ffmpeg_kit_session_execute_async')(pointer);
    } catch (error) {
      try {
        this.releaseSessionHandle(sessionId);
      } catch {
        // Preserve the native start failure; the registry keeps retryable ownership.
      }
      throw error;
    }
  }

  cancelSession(sessionId: number): void { this.withSession(sessionId, pointer => this.call('ffmpeg_kit_session_cancel')(pointer)); }

  getSessionState(sessionId: number): number {
    return this.withSession(
      sessionId,
      pointer => numberResult(this.call('ffmpeg_kit_session_get_state')(pointer)),
    );
  }

  getSessionJson(sessionId: number): string {
    return this.withSession(sessionId, pointer => JSON.stringify(this.snapshot(pointer)));
  }

  releaseSessionHandle(sessionId: number): void {
    const pointer = this.sessions.get(sessionId);
    if (!pointer) return;
    this.call('ffmpeg_kit_handle_release')(pointer);
    this.sessions.take(sessionId);
    this.executingSessions.delete(sessionId);
  }

  getSessionsJson(kind: string): string { return jsonArray(this.snapshots(kind)); }

  getLastSessionJson(kind: string): string {
    const exportName = kind === 'ffmpeg'
      ? 'ffmpeg_kit_get_last_ffmpeg_session'
      : kind === 'ffprobe'
        ? 'ffmpeg_kit_get_last_ffprobe_session'
        : kind === 'ffplay'
          ? 'ffmpeg_kit_get_last_ffplay_session'
          : kind === 'media-information'
            ? 'ffmpeg_kit_get_last_media_information_session'
            : 'ffmpeg_kit_get_last_session';
    const pointer = numberResult(this.call(exportName)());
    if (!pointer) return '';
    return this.withTemporaryHandle(pointer, value => JSON.stringify(this.snapshot(value)));
  }

  getLogsJson(sessionId: number, fromIndex: number): string {
    return this.withSession(sessionId, pointer => {
      const count = numberResult(this.call('ffmpeg_kit_session_get_logs_count')(pointer));
      const values: Record<string, unknown>[] = [];
      for (let index = fromIndex; index < count; index += 1) {
        values.push({
          sessionId,
          level: numberResult(this.call('ffmpeg_kit_session_get_log_level_at')(pointer, int64(index))),
          message: this.readString(this.call('ffmpeg_kit_session_get_log_at')(pointer, int64(index))),
        });
      }
      return JSON.stringify(values);
    });
  }

  getStatisticsJson(sessionId: number, fromIndex: number): string {
    return this.withSession(sessionId, pointer => {
      const count = numberResult(this.call('ffmpeg_kit_session_get_statistics_count')(pointer));
      const values: StatisticsSnapshot[] = [];
      for (let index = fromIndex; index < count; index += 1) {
        const statistics = numberResult(this.call('ffmpeg_kit_session_get_statistics_at')(pointer, int64(index)));
        if (!statistics) continue;
        values.push(this.withTemporaryHandle(statistics, handle => ({
            sessionId,
            timeElapsed: numberResult(this.call('ffmpeg_kit_statistics_get_time_elapsed')(handle)),
            time: numberResult(this.call('ffmpeg_kit_statistics_get_time')(handle)),
            size: numberResult(this.call('ffmpeg_kit_statistics_get_size')(handle)),
            bitrate: numberResult(this.call('ffmpeg_kit_statistics_get_bitrate')(handle)),
            speed: numberResult(this.call('ffmpeg_kit_statistics_get_speed')(handle)),
            videoFrameNumber: numberResult(this.call('ffmpeg_kit_statistics_get_video_frame_number')(handle)),
            videoFps: numberResult(this.call('ffmpeg_kit_statistics_get_video_fps')(handle)),
            videoQuality: numberResult(this.call('ffmpeg_kit_statistics_get_video_quality')(handle)),
            dupFrames: numberResult(this.call('ffmpeg_kit_statistics_get_dup_frames')(handle)),
            dropFrames: numberResult(this.call('ffmpeg_kit_statistics_get_drop_frames')(handle)),
          })));
      }
      return JSON.stringify(values);
    });
  }

  getMediaInformationJson(sessionId: number): string {
    const data = this.getMediaInformationData(sessionId);
    return data ? JSON.stringify(data) : '';
  }

  private streamInformationData(pointer: number): Record<string, unknown> {
    return {
      index: numberResult(this.call('stream_information_get_index')(pointer)),
      type: this.readString(this.call('stream_information_get_type')(pointer)),
      codec: this.readString(this.call('stream_information_get_codec')(pointer)),
      codecLong: this.readString(this.call('stream_information_get_codec_long')(pointer)),
      format: this.readString(this.call('stream_information_get_format')(pointer)),
      width: numberResult(this.call('stream_information_get_width')(pointer)),
      height: numberResult(this.call('stream_information_get_height')(pointer)),
      bitrate: this.readString(this.call('stream_information_get_bitrate')(pointer)),
      sampleRate: this.readString(this.call('stream_information_get_sample_rate')(pointer)),
      sampleFormat: this.readString(this.call('stream_information_get_sample_format')(pointer)),
      channelLayout: this.readString(this.call('stream_information_get_channel_layout')(pointer)),
      sampleAspectRatio: this.readString(this.call('stream_information_get_sample_aspect_ratio')(pointer)),
      displayAspectRatio: this.readString(this.call('stream_information_get_display_aspect_ratio')(pointer)),
      averageFrameRate: this.readString(this.call('stream_information_get_average_frame_rate')(pointer)),
      realFrameRate: this.readString(this.call('stream_information_get_real_frame_rate')(pointer)),
      timeBase: this.readString(this.call('stream_information_get_time_base')(pointer)),
      codecTimeBase: this.readString(this.call('stream_information_get_codec_time_base')(pointer)),
      tagsJson: this.readString(this.call('stream_information_get_tags_json')(pointer)),
      allPropertiesJson: this.readString(this.call('stream_information_get_all_properties_json')(pointer)),
    };
  }

  private chapterInformationData(pointer: number): Record<string, unknown> {
    return {
      id: numberResult(this.call('chapter_get_id')(pointer)),
      timeBase: this.readString(this.call('chapter_get_time_base')(pointer)),
      start: numberResult(this.call('chapter_get_start')(pointer)),
      startTime: this.readString(this.call('chapter_get_start_time')(pointer)),
      end: numberResult(this.call('chapter_get_end')(pointer)),
      endTime: this.readString(this.call('chapter_get_end_time')(pointer)),
      tagsJson: this.readString(this.call('chapter_get_tags_json')(pointer)),
      allPropertiesJson: this.readString(this.call('chapter_get_all_properties_json')(pointer)),
    };
  }

  getMediaInformationData(sessionId: number): MediaInformationData | undefined {
    return this.withSession(sessionId, session => {
      const info = numberResult(this.call('media_information_session_get_media_information')(session));
      if (!info) return undefined;
      return this.withTemporaryHandle(info, infoHandle => {
        const streams: Record<string, unknown>[] = [];
        const streamCount = numberResult(this.call('media_information_get_streams_count')(infoHandle));
        for (let index = 0; index < streamCount; index += 1) {
          const stream = numberResult(this.call('media_information_get_stream_at')(infoHandle, int64(index)));
          if (!stream) continue;
          streams.push(this.withTemporaryHandle(stream, handle => this.streamInformationData(handle)));
        }

        const chapters: Record<string, unknown>[] = [];
        const chapterCount = numberResult(this.call('media_information_get_chapters_count')(infoHandle));
        for (let index = 0; index < chapterCount; index += 1) {
          const chapter = numberResult(this.call('media_information_get_chapter_at')(infoHandle, int64(index)));
          if (!chapter) continue;
          chapters.push(this.withTemporaryHandle(chapter, handle => this.chapterInformationData(handle)));
        }

        return {
          filename: this.readString(this.call('media_information_get_filename')(info)),
          format: this.readString(this.call('media_information_get_format')(info)),
          longFormat: this.readString(this.call('media_information_get_long_format')(info)),
          duration: this.readString(this.call('media_information_get_duration')(info)),
          startTime: this.readString(this.call('media_information_get_start_time')(info)),
          bitrate: this.readString(this.call('media_information_get_bitrate')(info)),
          size: this.readString(this.call('media_information_get_size')(info)),
          tagsJson: this.readString(this.call('media_information_get_tags_json')(info)),
          allPropertiesJson: this.readString(this.call('media_information_get_all_properties_json')(info)),
          streams,
          chapters,
        };
      });
    });
  }

  ffplayStart(sessionId: number): void { this.withSession(sessionId, p => this.call('ffplay_kit_session_start')(p)); }
  ffplayPause(sessionId: number): void { this.withSession(sessionId, p => this.call('ffplay_kit_session_pause')(p)); }
  ffplayResume(sessionId: number): void { this.withSession(sessionId, p => this.call('ffplay_kit_session_resume')(p)); }
  ffplayStop(sessionId: number): void { this.withSession(sessionId, p => this.call('ffplay_kit_session_stop')(p)); }
  ffplaySeek(sessionId: number, seconds: number): void { this.withSession(sessionId, p => this.call('ffplay_kit_session_seek')(p, seconds)); }
  ffplayGetPosition(sessionId: number): number { return this.withSession(sessionId, p => numberResult(this.call('ffplay_kit_session_get_position')(p))); }
  ffplaySetPosition(sessionId: number, seconds: number): void { this.withSession(sessionId, p => this.call('ffplay_kit_session_set_position')(p, seconds)); }
  ffplayGetDuration(sessionId: number): number { return this.withSession(sessionId, p => numberResult(this.call('ffplay_kit_session_get_duration')(p))); }
  ffplayGetVideoWidth(sessionId: number): number { return this.withSession(sessionId, p => numberResult(this.call('ffplay_kit_session_get_video_width')(p))); }
  ffplayGetVideoHeight(sessionId: number): number { return this.withSession(sessionId, p => numberResult(this.call('ffplay_kit_session_get_video_height')(p))); }
  ffplayIsPlaying(sessionId: number): boolean { return this.withSession(sessionId, p => boolResult(this.call('ffplay_kit_session_is_playing')(p))); }
  ffplayIsPaused(sessionId: number): boolean { return this.withSession(sessionId, p => boolResult(this.call('ffplay_kit_session_is_paused')(p))); }
  ffplaySetVolume(sessionId: number, volume: number): void { this.withSession(sessionId, p => this.call('ffplay_kit_session_set_volume')(p, volume)); }
  ffplayGetVolume(sessionId: number): number { return this.withSession(sessionId, p => numberResult(this.call('ffplay_kit_session_get_volume')(p))); }
  ffplayHasVideoStream(path: string): boolean { return this.withString(path, p => boolResult(this.call('ffplay_kit_has_video_stream')(p))); }

  getFrameBufferSize(): number { return numberResult(this.call('ffplay_kit_get_frame_buffer_size')()); }

  copyFrame(destination: number, destinationSize: number): FFplayFrameCopyResult {
    const module = this.module();
    const width = module._malloc(4);
    const height = module._malloc(4);
    const linesize = module._malloc(4);
    const generation = module._malloc(8);
    try {
      const result = numberResult(this.call('ffplay_kit_copy_frame')(destination, destinationSize, width, height, linesize, generation));
      return {
        width: module.HEAPU32[width / 4],
        height: module.HEAPU32[height / 4],
        linesize: module.HEAPU32[linesize / 4],
        generation: Number(new BigUint64Array(module.HEAPU8.buffer, generation, 1)[0]),
        copied: result === 1,
      };
    } finally { module._free(width); module._free(height); module._free(linesize); module._free(generation); }
  }

  enableRedirection(): void { this.call('ffmpeg_kit_config_enable_redirection')(); }
  disableRedirection(): void { this.call('ffmpeg_kit_config_disable_redirection')(); }
  setLogLevel(level: number): void { this.call('ffmpeg_kit_config_set_log_level')(level); }
  getLogLevel(): number { return numberResult(this.call('ffmpeg_kit_config_get_log_level')()); }
  logLevelToString(level: number): string { return this.readString(this.call('ffmpeg_kit_config_log_level_to_string')(level)); }
  setFontDirectory(path: string, mappingJson: string): void { this.withString(path, p => this.withString(mappingJson, m => this.call('ffmpeg_kit_config_set_font_directory')(p, m))); }
  setEnvironmentVariable(name: string, value: string): void { this.withString(name, n => this.withString(value, v => this.call('ffmpeg_kit_config_set_environment_variable')(n, v))); }
  ignoreSignal(signal: number): void { this.call('ffmpeg_kit_config_ignore_signal')(signal); }
  setAudioOutputDevice(deviceName: string): void { this.withString(deviceName, p => this.call('ffmpeg_kit_config_set_audio_output_device')(p)); }
  listAudioOutputDevices(): string { return this.readString(this.call('ffmpeg_kit_config_list_audio_output_devices')()); }
  getFFmpegVersion(): string { return this.readString(this.call('ffmpeg_kit_config_get_ffmpeg_version')()); }
  getFFmpegArchitecture(): string { return this.readString(this.call('ffmpeg_kit_config_get_ffmpeg_architecture')()); }
  getVersion(): string { return this.readString(this.call('ffmpeg_kit_config_get_version')()); }
  getPackageName(): string { return this.readString(this.call('ffmpeg_kit_packages_get_package_name')()); }
  getExternalLibraries(): string { return this.readString(this.call('ffmpeg_kit_packages_get_external_libraries')()); }
  getBundleType(): string { return this.readString(this.call('ffmpeg_kit_packages_get_bundle_type')()); }
  isGpl(): boolean { return boolResult(this.call('ffmpeg_kit_packages_get_is_gpl')()); }
  isNonfree(): boolean { return boolResult(this.call('ffmpeg_kit_packages_get_is_nonfree')()); }
  getRegisteredCodecs(): string { return this.readString(this.call('ffmpeg_kit_packages_get_registered_codecs')()); }
  getRegisteredEncoders(): string { return this.readString(this.call('ffmpeg_kit_packages_get_registered_encoders')()); }
  getRegisteredDecoders(): string { return this.readString(this.call('ffmpeg_kit_packages_get_registered_decoders')()); }
  getRegisteredMuxers(): string { return this.readString(this.call('ffmpeg_kit_packages_get_registered_muxers')()); }
  getRegisteredDemuxers(): string { return this.readString(this.call('ffmpeg_kit_packages_get_registered_demuxers')()); }
  getRegisteredFilters(): string { return this.readString(this.call('ffmpeg_kit_packages_get_registered_filters')()); }
  getRegisteredProtocols(): string { return this.readString(this.call('ffmpeg_kit_packages_get_registered_protocols')()); }
  getRegisteredBitstreamFilters(): string { return this.readString(this.call('ffmpeg_kit_packages_get_registered_bitstream_filters')()); }
  getBuildConfiguration(): string { return this.readString(this.call('ffmpeg_kit_packages_get_build_configuration')()); }
  getBuildDate(): string { return this.readString(this.call('ffmpeg_kit_config_get_build_date')()); }
  setSessionHistorySize(size: number): void { this.call('ffmpeg_kit_set_session_history_size')(int64(size)); }
  getSessionHistorySize(): number { return numberResult(this.call('ffmpeg_kit_get_session_history_size')()); }
  clearSessions(): void {
    for (const [sessionId, pointer] of this.sessions.entries()) {
      this.call('ffmpeg_kit_handle_release')(pointer);
      this.sessions.take(sessionId);
      this.executingSessions.delete(sessionId);
    }
    this.call('ffmpeg_kit_clear_sessions')();
  }
  registerNewFFmpegPipe(): string { return this.readString(this.call('ffmpeg_kit_config_register_new_ffmpeg_pipe')()); }
  closeFFmpegPipe(path: string): void { this.withString(path, p => this.call('ffmpeg_kit_config_close_ffmpeg_pipe')(p)); }
  messagesInTransmit(sessionId: number): number { return numberResult(this.call('ffmpeg_kit_config_messages_in_transmit')(int64(sessionId))); }
  enableDebugLog(sessionId: number): void { this.withSession(sessionId, p => this.call('session_enable_debug_log')(p)); }
  disableDebugLog(sessionId: number): void { this.withSession(sessionId, p => this.call('session_disable_debug_log')(p)); }
  isDebugLogEnabled(sessionId: number): boolean { return this.withSession(sessionId, p => boolResult(this.call('session_is_debug_log_enabled')(p))); }
  getDebugLog(sessionId: number): string { return this.withSession(sessionId, p => this.readString(this.call('session_get_debug_log')(p))); }
  clearDebugLog(sessionId: number): void { this.withSession(sessionId, p => this.call('session_clear_debug_log')(p)); }
}

export const webBackend: FFmpegKitBackend = new WebFFmpegKitBackend();
