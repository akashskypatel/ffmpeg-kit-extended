import NativeFFmpegKitExtended from './NativeFFmpegKitExtended';
import type {
  ExecuteOptions,
  FFmpegExecuteOptions,
  Log,
  SessionSnapshot,
  SessionType,
  Statistics,
} from './types';
import {SessionState} from './types';
import {MediaInformation, type MediaInformationData} from './media-information';
import {SessionQueueManager} from './session-queue-manager';

const DEFAULT_POLL_INTERVAL_MS = 50;

/**
 * Base wrapper for one native FFmpegKit session.
 *
 * Session getters read the latest native snapshot on each call. Keep history
 * entries available until you finish inspecting a completed session. Calling
 * `FFmpegKitConfig.clearSessions()` can make later getters throw because the
 * native session no longer exists.
 */
export abstract class Session {
  readonly sessionId: number;
  readonly command: string;
  readonly type: SessionType;
  private cancelled = false;

  protected constructor(sessionId: number, command: string, type: SessionType) {
    this.sessionId = sessionId;
    this.command = command;
    this.type = type;
  }

  /** Whether cancellation was requested through this JavaScript object. */
  get isCancelled(): boolean {
    return this.cancelled;
  }

  /** Returns the current native lifecycle state. */
  getState(): SessionState {
    return this.snapshot().state;
  }

  /** Returns the native exit code; inspect after completion. */
  getReturnCode(): number {
    return this.snapshot().returnCode;
  }

  /** Returns the process-unique native session ID. */
  getSessionId(): number {
    return this.sessionId;
  }

  /** Returns when the native session was created. */
  getCreateTime(): Date {
    return new Date(this.snapshot().createTime);
  }

  /** Returns when native execution started; may represent epoch before start. */
  getStartTime(): Date {
    return new Date(this.snapshot().startTime);
  }

  /** Returns when execution ended; may represent epoch before completion. */
  getEndTime(): Date {
    return new Date(this.snapshot().endTime);
  }

  /** Returns wall-clock execution duration in milliseconds. */
  getDuration(): number {
    return this.snapshot().duration;
  }

  /** Returns the command stored by the native session. */
  getCommand(): string {
    return this.snapshot().command || this.command;
  }

  /** Returns the session's combined native console output. */
  getOutput(): string {
    return this.snapshot().output;
  }

  /** Returns all retained session logs concatenated as text. */
  getLogsAsString(): string {
    return this.snapshot().logs;
  }

  /** Returns the native failure stack trace when one was recorded. */
  getFailStackTrace(): string {
    return this.snapshot().failStackTrace;
  }

  /** Returns the number of retained log entries. */
  getLogsCount(): number {
    return this.snapshot().logsCount;
  }

  /** Returns the number of retained statistics entries. */
  getStatisticsCount(): number {
    return this.snapshot().statisticsCount;
  }

  /** Requests native cancellation. The terminal state is observed asynchronously. */
  cancel(): void {
    NativeFFmpegKitExtended.cancelSession(this.sessionId);
    this.cancelled = true;
  }

  /** Enables additional native debug-log capture for this session. */
  enableDebugLog(): void {
    NativeFFmpegKitExtended.enableDebugLog(this.sessionId);
  }

  /** Disables additional native debug-log capture for this session. */
  disableDebugLog(): void {
    NativeFFmpegKitExtended.disableDebugLog(this.sessionId);
  }

  /** Whether additional debug-log capture is enabled for this session. */
  isDebugLogEnabled(): boolean {
    return NativeFFmpegKitExtended.isDebugLogEnabled(this.sessionId);
  }

  /** Returns the session-specific native debug log. */
  getDebugLog(): string {
    return NativeFFmpegKitExtended.getDebugLog(this.sessionId);
  }

  /** Clears the session-specific native debug log buffer. */
  clearDebugLog(): void {
    NativeFFmpegKitExtended.clearDebugLog(this.sessionId);
  }

  /** Type guard for FFmpeg processing sessions. */
  isFFmpegSession(): this is FFmpegSession {
    return this.type === 'ffmpeg';
  }

  /** Type guard for FFprobe command sessions. */
  isFFprobeSession(): this is FFprobeSession {
    return this.type === 'ffprobe';
  }

  /** Type guard for FFplay sessions. */
  isFFplaySession(): this is FFplaySession {
    return this.type === 'ffplay';
  }

  /** Type guard for structured media-information sessions. */
  isMediaInformationSession(): this is MediaInformationSession {
    return this.type === 'media-information';
  }

  protected snapshot(): SessionSnapshot {
    return parseRequiredJson<SessionSnapshot>(
      NativeFFmpegKitExtended.getSessionJson(this.sessionId),
      `Session ${this.sessionId} no longer exists`,
    );
  }

  protected async monitor<T extends Session>(
    self: T,
    options: ExecuteOptions<T> & {
      statisticsCallback?: (statistics: Statistics, session: T) => void;
    },
  ): Promise<T> {
    const pollIntervalMs = Math.max(
      10,
      Math.floor(options.pollIntervalMs ?? DEFAULT_POLL_INTERVAL_MS),
    );
    let logsProcessed = 0;
    let statisticsProcessed = 0;

    for (;;) {
      const logs = parseJsonArray<Log>(
        NativeFFmpegKitExtended.getLogsJson(this.sessionId, logsProcessed),
      );
      for (const entry of logs) {
        options.logCallback?.(entry, self);
      }
      logsProcessed += logs.length;

      if (options.statisticsCallback) {
        const statistics = parseJsonArray<Statistics>(
          NativeFFmpegKitExtended.getStatisticsJson(
            this.sessionId,
            statisticsProcessed,
          ),
        );
        for (const entry of statistics) {
          options.statisticsCallback(entry, self);
        }
        statisticsProcessed += statistics.length;
      }

      const state = this.getState();
      if (state === SessionState.Completed || state === SessionState.Failed) {
        // One final pass closes the race between the last poll and completion.
        const finalLogs = parseJsonArray<Log>(
          NativeFFmpegKitExtended.getLogsJson(this.sessionId, logsProcessed),
        );
        for (const entry of finalLogs) options.logCallback?.(entry, self);

        if (options.statisticsCallback) {
          const finalStatistics = parseJsonArray<Statistics>(
            NativeFFmpegKitExtended.getStatisticsJson(
              this.sessionId,
              statisticsProcessed,
            ),
          );
          for (const entry of finalStatistics) {
            options.statisticsCallback(entry, self);
          }
        }

        try {
          options.completeCallback?.(self);
          return self;
        } finally {
          // Native C API session handles are owning. Keep the original handle
          // alive for the whole execution, then release it only after the
          // terminal state and final log/statistics pass have been observed.
          NativeFFmpegKitExtended.releaseSessionHandle(this.sessionId);
        }
      }

      await sleep(pollIntervalMs);
    }
  }
}

/**
 * FFmpeg processing session with completion, log, and progress callbacks.
 *
 * Callback setters provide reusable defaults for this session. Options passed
 * directly to `executeAsync()` take precedence for that execution.
 */
export class FFmpegSession extends Session {
  private completeCallback?: (session: FFmpegSession) => void;
  private logCallback?: (log: Log, session: FFmpegSession) => void;
  private statisticsCallback?: (
    statistics: Statistics,
    session: FFmpegSession,
  ) => void;

  constructor(sessionId: number, command: string) {
    super(sessionId, command, 'ffmpeg');
  }

  /** Sets the default callback invoked immediately before promise resolution. */
  setCompleteCallback(callback?: (session: FFmpegSession) => void): void {
    this.completeCallback = callback;
  }

  /** Removes the stored completion callback. */
  removeCompleteCallback(): void {
    this.completeCallback = undefined;
  }

  /** Sets the default callback for newly buffered log entries. */
  setLogCallback(callback?: (log: Log, session: FFmpegSession) => void): void {
    this.logCallback = callback;
  }

  /** Removes the stored log callback. */
  removeLogCallback(): void {
    this.logCallback = undefined;
  }

  /** Sets the default callback for FFmpeg progress/statistics updates. */
  setStatisticsCallback(
    callback?: (statistics: Statistics, session: FFmpegSession) => void,
  ): void {
    this.statisticsCallback = callback;
  }

  /** Removes the stored statistics callback. */
  removeStatisticsCallback(): void {
    this.statisticsCallback = undefined;
  }

  /**
   * Enqueues and starts this session, resolving after terminal state and final
   * callback delivery. A session object is intended for one execution.
   */
  executeAsync(options: FFmpegExecuteOptions<FFmpegSession> = {}): Promise<this> {
    return SessionQueueManager.shared.executeSession(this, async () => {
      NativeFFmpegKitExtended.executeSessionAsync(this.sessionId, 0);
      return this.monitor(this, {
        completeCallback: options.completeCallback ?? this.completeCallback,
        logCallback: options.logCallback ?? this.logCallback,
        statisticsCallback:
          options.statisticsCallback ?? this.statisticsCallback,
        pollIntervalMs: options.pollIntervalMs,
      }) as Promise<this>;
    });
  }
}

/** FFprobe command session with completion and log callbacks. */
export class FFprobeSession extends Session {
  private completeCallback?: (session: FFprobeSession) => void;
  private logCallback?: (log: Log, session: FFprobeSession) => void;

  constructor(sessionId: number, command: string) {
    super(sessionId, command, 'ffprobe');
  }

  /** Sets the default completion callback. */
  setCompleteCallback(callback?: (session: FFprobeSession) => void): void {
    this.completeCallback = callback;
  }

  /** Removes the stored completion callback. */
  removeCompleteCallback(): void {
    this.completeCallback = undefined;
  }

  /** Sets the default log callback. */
  setLogCallback(callback?: (log: Log, session: FFprobeSession) => void): void {
    this.logCallback = callback;
  }

  /** Removes the stored log callback. */
  removeLogCallback(): void {
    this.logCallback = undefined;
  }

  /** Enqueues and executes this FFprobe session. */
  executeAsync(options: ExecuteOptions<FFprobeSession> = {}): Promise<this> {
    return SessionQueueManager.shared.executeSession(this, async () => {
      NativeFFmpegKitExtended.executeSessionAsync(this.sessionId, 0);
      return this.monitor(this, {
        completeCallback: options.completeCallback ?? this.completeCallback,
        logCallback: options.logCallback ?? this.logCallback,
        pollIntervalMs: options.pollIntervalMs,
      }) as Promise<this>;
    });
  }
}

/**
 * Specialized FFprobe session that exposes typed `MediaInformation` after
 * completion.
 */
export class MediaInformationSession extends Session {
  private completeCallback?: (session: MediaInformationSession) => void;
  private logCallback?: (log: Log, session: MediaInformationSession) => void;
  private timeoutMs: number;

  constructor(sessionId: number, command: string, timeoutMs = 500) {
    super(sessionId, command, 'media-information');
    this.timeoutMs = timeoutMs;
  }

  /** Sets the default completion callback. */
  setCompleteCallback(
    callback?: (session: MediaInformationSession) => void,
  ): void {
    this.completeCallback = callback;
  }

  /** Removes the stored completion callback. */
  removeCompleteCallback(): void {
    this.completeCallback = undefined;
  }

  /** Sets the default log callback. */
  setLogCallback(
    callback?: (log: Log, session: MediaInformationSession) => void,
  ): void {
    this.logCallback = callback;
  }

  /** Removes the stored log callback. */
  removeLogCallback(): void {
    this.logCallback = undefined;
  }

  /** Sets the native probe timeout in milliseconds before execution. */
  setTimeout(timeoutMs: number): void {
    this.timeoutMs = timeoutMs;
  }

  /** Enqueues and executes this structured probe. */
  executeAsync(
    options: ExecuteOptions<MediaInformationSession> = {},
  ): Promise<this> {
    return SessionQueueManager.shared.executeSession(this, async () => {
      NativeFFmpegKitExtended.executeSessionAsync(this.sessionId, this.timeoutMs);
      return this.monitor(this, {
        completeCallback: options.completeCallback ?? this.completeCallback,
        logCallback: options.logCallback ?? this.logCallback,
        pollIntervalMs: options.pollIntervalMs,
      }) as Promise<this>;
    });
  }

  /**
   * Returns parsed media information after successful probing, or `undefined`
   * when the native session has no structured result.
   */
  getMediaInformation(): MediaInformation | undefined {
    const json = NativeFFmpegKitExtended.getMediaInformationJson(this.sessionId);
    if (!json) return undefined;
    return new MediaInformation(JSON.parse(json) as MediaInformationData);
  }
}

/**
 * Native FFplay session with playback controls and state queries.
 *
 * For video, mount `FFplayView` before execution. Position, seek, and media
 * duration values are expressed in seconds. Volume is normalized to `0..1`.
 */
export class FFplaySession extends Session {
  private completeCallback?: (session: FFplaySession) => void;
  private cachedVolume = 1.0;
  private logCallback?: (log: Log, session: FFplaySession) => void;
  private timeoutMs: number;

  constructor(sessionId: number, command: string, timeoutMs = 500) {
    super(sessionId, command, 'ffplay');
    this.timeoutMs = timeoutMs;
  }

  /** Sets the default completion callback. */
  setCompleteCallback(callback?: (session: FFplaySession) => void): void {
    this.completeCallback = callback;
  }

  /** Removes the stored completion callback. */
  removeCompleteCallback(): void {
    this.completeCallback = undefined;
  }

  /** Sets the default playback log callback. */
  setLogCallback(callback?: (log: Log, session: FFplaySession) => void): void {
    this.logCallback = callback;
  }

  /** Removes the stored log callback. */
  removeLogCallback(): void {
    this.logCallback = undefined;
  }

  /** Sets the native playback timeout in milliseconds before execution. */
  setTimeout(timeoutMs: number): void {
    this.timeoutMs = timeoutMs;
  }

  /** Enqueues playback and resolves after playback ends, stops, or fails. */
  executeAsync(options: ExecuteOptions<FFplaySession> = {}): Promise<this> {
    return SessionQueueManager.shared.executeSession(this, async () => {
      NativeFFmpegKitExtended.executeSessionAsync(this.sessionId, this.timeoutMs);
      return this.monitor(this, {
        completeCallback: options.completeCallback ?? this.completeCallback,
        logCallback: options.logCallback ?? this.logCallback,
        pollIntervalMs: options.pollIntervalMs,
      }) as Promise<this>;
    });
  }

  /** Starts native playback for this session. */
  start(): void {
    NativeFFmpegKitExtended.ffplayStart(this.sessionId);
  }

  /** Pauses playback while retaining the current position. */
  pause(): void {
    NativeFFmpegKitExtended.ffplayPause(this.sessionId);
  }

  /** Resumes a paused session. */
  resume(): void {
    NativeFFmpegKitExtended.ffplayResume(this.sessionId);
  }

  /** Stops playback and drives the session toward completion. */
  stop(): void {
    NativeFFmpegKitExtended.ffplayStop(this.sessionId);
  }

  /** Seeks relative/according to native FFplay semantics to seconds. */
  seek(seconds: number): void {
    NativeFFmpegKitExtended.ffplaySeek(this.sessionId, seconds);
  }

  /** Returns the current playback position in seconds. */
  getPosition(): number {
    return NativeFFmpegKitExtended.ffplayGetPosition(this.sessionId);
  }

  /** Sets the playback position in seconds. */
  setPosition(seconds: number): void {
    NativeFFmpegKitExtended.ffplaySetPosition(this.sessionId, seconds);
  }

  /** Returns the detected media duration in seconds. */
  getMediaDuration(): number {
    return NativeFFmpegKitExtended.ffplayGetDuration(this.sessionId);
  }

  /** Returns the decoded video width in pixels, or a non-positive value if absent. */
  getVideoWidth(): number {
    return NativeFFmpegKitExtended.ffplayGetVideoWidth(this.sessionId);
  }

  /** Returns the decoded video height in pixels, or a non-positive value if absent. */
  getVideoHeight(): number {
    return NativeFFmpegKitExtended.ffplayGetVideoHeight(this.sessionId);
  }

  /** Whether native playback is currently active. */
  isPlaying(): boolean {
    return NativeFFmpegKitExtended.ffplayIsPlaying(this.sessionId);
  }

  /** Whether native playback is currently paused. */
  isPaused(): boolean {
    return NativeFFmpegKitExtended.ffplayIsPaused(this.sessionId);
  }

  /** Sets volume; values are clamped to the inclusive `0..1` range. */
  setVolume(volume: number): void {
    const clamped = Math.max(0, Math.min(1, volume));
    this.cachedVolume = clamped;
    NativeFFmpegKitExtended.ffplaySetVolume(this.sessionId, clamped);
  }

  /** Returns normalized volume, using the last set value if native state is unavailable. */
  getVolume(): number {
    const nativeVolume = NativeFFmpegKitExtended.ffplayGetVolume(this.sessionId);
    if (nativeVolume >= 0) {
      this.cachedVolume = nativeVolume;
    }
    return this.cachedVolume;
  }
}

/** Reconstructs the correct typed session wrapper from native history data. */
export function sessionFromSnapshot(snapshot: SessionSnapshot): Session {
  switch (snapshot.type) {
    case 'ffmpeg':
      return new FFmpegSession(snapshot.sessionId, snapshot.command);
    case 'ffprobe':
      return new FFprobeSession(snapshot.sessionId, snapshot.command);
    case 'ffplay':
      return new FFplaySession(snapshot.sessionId, snapshot.command);
    case 'media-information':
      return new MediaInformationSession(snapshot.sessionId, snapshot.command);
  }
}

/** Parses one native session snapshot, returning `undefined` for empty input. */
export function parseSessionJson(json: string): Session | undefined {
  if (!json) return undefined;
  return sessionFromSnapshot(JSON.parse(json) as SessionSnapshot);
}

/** Parses a native array of session snapshots into typed wrappers. */
export function parseSessionsJson(json: string): Session[] {
  return parseJsonArray<SessionSnapshot>(json).map(sessionFromSnapshot);
}

function parseRequiredJson<T>(json: string, errorMessage: string): T {
  if (!json) throw new Error(errorMessage);
  return JSON.parse(json) as T;
}

function parseJsonArray<T>(json: string): T[] {
  if (!json) return [];
  const parsed: unknown = JSON.parse(json);
  return Array.isArray(parsed) ? (parsed as T[]) : [];
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}
