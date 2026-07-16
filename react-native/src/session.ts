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

  get isCancelled(): boolean {
    return this.cancelled;
  }

  getState(): SessionState {
    return this.snapshot().state;
  }

  getReturnCode(): number {
    return this.snapshot().returnCode;
  }

  getSessionId(): number {
    return this.sessionId;
  }

  getCreateTime(): Date {
    return new Date(this.snapshot().createTime);
  }

  getStartTime(): Date {
    return new Date(this.snapshot().startTime);
  }

  getEndTime(): Date {
    return new Date(this.snapshot().endTime);
  }

  getDuration(): number {
    return this.snapshot().duration;
  }

  getCommand(): string {
    return this.snapshot().command || this.command;
  }

  getOutput(): string {
    return this.snapshot().output;
  }

  getLogsAsString(): string {
    return this.snapshot().logs;
  }

  getFailStackTrace(): string {
    return this.snapshot().failStackTrace;
  }

  getLogsCount(): number {
    return this.snapshot().logsCount;
  }

  getStatisticsCount(): number {
    return this.snapshot().statisticsCount;
  }

  cancel(): void {
    NativeFFmpegKitExtended.cancelSession(this.sessionId);
    this.cancelled = true;
  }

  enableDebugLog(): void {
    NativeFFmpegKitExtended.enableDebugLog(this.sessionId);
  }

  disableDebugLog(): void {
    NativeFFmpegKitExtended.disableDebugLog(this.sessionId);
  }

  isDebugLogEnabled(): boolean {
    return NativeFFmpegKitExtended.isDebugLogEnabled(this.sessionId);
  }

  getDebugLog(): string {
    return NativeFFmpegKitExtended.getDebugLog(this.sessionId);
  }

  clearDebugLog(): void {
    NativeFFmpegKitExtended.clearDebugLog(this.sessionId);
  }

  isFFmpegSession(): this is FFmpegSession {
    return this.type === 'ffmpeg';
  }

  isFFprobeSession(): this is FFprobeSession {
    return this.type === 'ffprobe';
  }

  isFFplaySession(): this is FFplaySession {
    return this.type === 'ffplay';
  }

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

        options.completeCallback?.(self);
        return self;
      }

      await sleep(pollIntervalMs);
    }
  }
}

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

  setCompleteCallback(callback?: (session: FFmpegSession) => void): void {
    this.completeCallback = callback;
  }

  removeCompleteCallback(): void {
    this.completeCallback = undefined;
  }

  setLogCallback(callback?: (log: Log, session: FFmpegSession) => void): void {
    this.logCallback = callback;
  }

  removeLogCallback(): void {
    this.logCallback = undefined;
  }

  setStatisticsCallback(
    callback?: (statistics: Statistics, session: FFmpegSession) => void,
  ): void {
    this.statisticsCallback = callback;
  }

  removeStatisticsCallback(): void {
    this.statisticsCallback = undefined;
  }

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

export class FFprobeSession extends Session {
  private completeCallback?: (session: FFprobeSession) => void;
  private logCallback?: (log: Log, session: FFprobeSession) => void;

  constructor(sessionId: number, command: string) {
    super(sessionId, command, 'ffprobe');
  }

  setCompleteCallback(callback?: (session: FFprobeSession) => void): void {
    this.completeCallback = callback;
  }

  removeCompleteCallback(): void {
    this.completeCallback = undefined;
  }

  setLogCallback(callback?: (log: Log, session: FFprobeSession) => void): void {
    this.logCallback = callback;
  }

  removeLogCallback(): void {
    this.logCallback = undefined;
  }

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

export class MediaInformationSession extends Session {
  private completeCallback?: (session: MediaInformationSession) => void;
  private logCallback?: (log: Log, session: MediaInformationSession) => void;
  private timeoutMs: number;

  constructor(sessionId: number, command: string, timeoutMs = 500) {
    super(sessionId, command, 'media-information');
    this.timeoutMs = timeoutMs;
  }

  setCompleteCallback(
    callback?: (session: MediaInformationSession) => void,
  ): void {
    this.completeCallback = callback;
  }

  removeCompleteCallback(): void {
    this.completeCallback = undefined;
  }

  setLogCallback(
    callback?: (log: Log, session: MediaInformationSession) => void,
  ): void {
    this.logCallback = callback;
  }

  removeLogCallback(): void {
    this.logCallback = undefined;
  }

  setTimeout(timeoutMs: number): void {
    this.timeoutMs = timeoutMs;
  }

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

  getMediaInformation(): MediaInformation | undefined {
    const json = NativeFFmpegKitExtended.getMediaInformationJson(this.sessionId);
    if (!json) return undefined;
    return new MediaInformation(JSON.parse(json) as MediaInformationData);
  }
}

export class FFplaySession extends Session {
  private completeCallback?: (session: FFplaySession) => void;
  private logCallback?: (log: Log, session: FFplaySession) => void;
  private timeoutMs: number;

  constructor(sessionId: number, command: string, timeoutMs = 500) {
    super(sessionId, command, 'ffplay');
    this.timeoutMs = timeoutMs;
  }

  setCompleteCallback(callback?: (session: FFplaySession) => void): void {
    this.completeCallback = callback;
  }

  removeCompleteCallback(): void {
    this.completeCallback = undefined;
  }

  setLogCallback(callback?: (log: Log, session: FFplaySession) => void): void {
    this.logCallback = callback;
  }

  removeLogCallback(): void {
    this.logCallback = undefined;
  }

  setTimeout(timeoutMs: number): void {
    this.timeoutMs = timeoutMs;
  }

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

  start(): void {
    NativeFFmpegKitExtended.ffplayStart(this.sessionId);
  }

  pause(): void {
    NativeFFmpegKitExtended.ffplayPause(this.sessionId);
  }

  resume(): void {
    NativeFFmpegKitExtended.ffplayResume(this.sessionId);
  }

  stop(): void {
    NativeFFmpegKitExtended.ffplayStop(this.sessionId);
  }

  seek(seconds: number): void {
    NativeFFmpegKitExtended.ffplaySeek(this.sessionId, seconds);
  }

  getPosition(): number {
    return NativeFFmpegKitExtended.ffplayGetPosition(this.sessionId);
  }

  setPosition(seconds: number): void {
    NativeFFmpegKitExtended.ffplaySetPosition(this.sessionId, seconds);
  }

  getMediaDuration(): number {
    return NativeFFmpegKitExtended.ffplayGetDuration(this.sessionId);
  }

  getVideoWidth(): number {
    return NativeFFmpegKitExtended.ffplayGetVideoWidth(this.sessionId);
  }

  getVideoHeight(): number {
    return NativeFFmpegKitExtended.ffplayGetVideoHeight(this.sessionId);
  }

  isPlaying(): boolean {
    return NativeFFmpegKitExtended.ffplayIsPlaying(this.sessionId);
  }

  isPaused(): boolean {
    return NativeFFmpegKitExtended.ffplayIsPaused(this.sessionId);
  }

  setVolume(volume: number): void {
    NativeFFmpegKitExtended.ffplaySetVolume(this.sessionId, volume);
  }

  getVolume(): number {
    return NativeFFmpegKitExtended.ffplayGetVolume(this.sessionId);
  }
}

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

export function parseSessionJson(json: string): Session | undefined {
  if (!json) return undefined;
  return sessionFromSnapshot(JSON.parse(json) as SessionSnapshot);
}

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
