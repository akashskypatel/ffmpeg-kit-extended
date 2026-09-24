import {getBackend} from './platform/backend-registry';
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
import {
  SessionCancelledException,
  SessionQueueManager,
} from './session-queue-manager';
import {
  callbackDemandAuthority,
  type CallbackDemandHooks,
  type CallbackDemandKind,
  type CallbackDemandLease,
} from './callback-demand';
import {subscribeLogEvents} from './platform/log-event-router';
import type {LogEventSubscription} from './platform/backend-registry';

const NativeFFmpegKitExtended = getBackend();

const DEFAULT_POLL_INTERVAL_MS = 50;

type CallbackDemandProviders = {
  log: () => boolean;
  statistics?: () => boolean;
};

type MonitorOptions<T extends Session> = {
  completeCallback?: (session: T) => void;
  getLogCallback: () => ((log: Log, session: T) => void) | undefined;
  getStatisticsCallback?: () =>
    | ((statistics: Statistics, session: T) => void)
    | undefined;
  pollIntervalMs?: number;
  start?: () => void;
};

/**
 * Base wrapper for one native FFmpegKit session.
 *
 * Session getters read the latest native snapshot on each call. When the v2
 * event bridge is available, live log delivery is direct and sequence-based;
 * the monitor does not poll complete log history during steady state. At
 * terminal state it reads the retained count once and fetches only a bounded
 * missing range, while the indexed getters remain available for history and v1
 * compatibility. Keep history entries available until you finish inspecting a
 * completed session. Calling `FFmpegKitConfig.clearSessions()` while sessions
 * are running can cancel/invalidate active handles. Clearing sessions can also
 * make later getters throw because the native session no longer exists.
 *
 * A Session object may be submitted for execution once. Create a new session
 * for another execution.
 */
export abstract class Session {
  readonly sessionId: number;
  readonly command: string;
  readonly type: SessionType;
  private cancelled = false;
  private nativeCancellationDispatched = false;
  private submitted = false;
  private callbackDemandActive = false;
  private callbackDemandProviders?: CallbackDemandProviders;
  private readonly callbackDemandLeases = new Map<
    CallbackDemandKind,
    CallbackDemandLease
  >();
  private nextExpectedLogSequence = 0;
  private readonly pendingDirectLogEvents = new Map<number, Log>();

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
    const state = NativeFFmpegKitExtended.getSessionState?.(this.sessionId);
    if (state !== undefined) return state as SessionState;
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

  /** Returns the retained log count used for public inspection/reconciliation. */
  getLogsCount(): number {
    return this.snapshot().logsCount;
  }

  /** Returns the number of retained statistics entries. */
  getStatisticsCount(): number {
    return this.snapshot().statisticsCount;
  }

  /**
   * Records cancellation immediately, then cancels queued work or requests
   * native cancellation once running. A state-read or native-dispatch failure
   * does not erase the recorded request, so an executing session can still
   * deliver it when Running is observed again.
   */
  cancel(): void {
    if (this.cancelled && this.nativeCancellationDispatched) return;

    this.cancelled = true;

    if (SessionQueueManager.shared.cancelQueued(this)) {
      return;
    }
    const state = this.getState();
    if (state === SessionState.Created) {
      return;
    }
    if (state === SessionState.Running) {
      this.dispatchNativeCancellation();
    }
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

  /** Starts native execution and releases the owning handle if start fails. */
  protected startNativeExecution(timeoutMs: number): void {
    try {
      NativeFFmpegKitExtended.executeSessionAsync(this.sessionId, timeoutMs);
    } catch (error) {
      try {
        this.releaseOwnedHandle();
      } catch {
        // Preserve the native start failure as the primary error.
      }
      throw error;
    }
  }

  /** Forwards cancellation and records successful native dispatch exactly once. */
  private dispatchNativeCancellation(): void {
    if (this.nativeCancellationDispatched) return;
    NativeFFmpegKitExtended.cancelSession(this.sessionId);
    this.nativeCancellationDispatched = true;
  }

  /**
   * Runs one submitted execution with mandatory completion demand and optional
   * log/statistics demand. The execution error always wins over bridge cleanup
   * errors, while a cleanup error remains observable when execution succeeds.
   */
  protected async runWithCallbackDemand<T>(
    providers: CallbackDemandProviders,
    operation: () => Promise<T>,
  ): Promise<T> {
    this.callbackDemandProviders = providers;
    this.callbackDemandActive = true;

    let result!: T;
    let primaryErrorSet = false;
    let primaryError: unknown;
    try {
      this.acquireCallbackDemand('completion');
      this.refreshCallbackDemand();
      result = await operation();
    } catch (error) {
      primaryErrorSet = true;
      primaryError = error;
    }

    const cleanupError = this.releaseAllCallbackDemand();
    this.callbackDemandActive = false;
    this.callbackDemandProviders = undefined;

    if (primaryErrorSet) throw primaryError;
    if (cleanupError !== undefined) throw cleanupError;
    return result;
  }

  /** Reconciles optional leases with the currently visible callback sinks. */
  protected refreshCallbackDemand(): void {
    if (!this.callbackDemandActive || !this.callbackDemandProviders) return;
    this.syncCallbackDemand('log', this.callbackDemandProviders.log());
    this.syncCallbackDemand(
      'statistics',
      this.callbackDemandProviders.statistics?.() ?? false,
    );
  }

  private syncCallbackDemand(kind: 'log' | 'statistics', needed: boolean): void {
    const existing = this.callbackDemandLeases.get(kind);
    if (needed) {
      if (!existing) this.acquireCallbackDemand(kind);
      return;
    }
    if (!existing) return;
    this.callbackDemandLeases.delete(kind);
    existing.release();
  }

  private acquireCallbackDemand(kind: CallbackDemandKind): void {
    if (this.callbackDemandLeases.has(kind)) return;
    this.callbackDemandLeases.set(
      kind,
      callbackDemandAuthority.acquire(kind, this.callbackDemandHooks(kind)),
    );
  }

  private callbackDemandHooks(kind: CallbackDemandKind): CallbackDemandHooks {
    switch (kind) {
      case 'completion':
        return {
          install: () => NativeFFmpegKitExtended.installCompletionBridge?.(),
          uninstall: () => NativeFFmpegKitExtended.uninstallCompletionBridge?.(),
        };
      case 'log':
        return {
          install: () => NativeFFmpegKitExtended.installLogBridge?.(),
          uninstall: () => NativeFFmpegKitExtended.uninstallLogBridge?.(),
        };
      case 'statistics':
        return {
          install: () => NativeFFmpegKitExtended.installStatisticsBridge?.(),
          uninstall: () => NativeFFmpegKitExtended.uninstallStatisticsBridge?.(),
        };
    }
  }

  private releaseAllCallbackDemand(): unknown {
    let firstError: unknown;
    for (const kind of [...this.callbackDemandLeases.keys()].reverse()) {
      const lease = this.callbackDemandLeases.get(kind);
      this.callbackDemandLeases.delete(kind);
      if (!lease) continue;
      try {
        lease.release();
      } catch (error) {
        if (firstError === undefined) firstError = error;
      }
    }
    return firstError;
  }

  protected async monitor<T extends Session>(
    self: T,
    options: MonitorOptions<T>,
  ): Promise<T> {
    const pollIntervalMs = Math.max(
      10,
      Math.floor(options.pollIntervalMs ?? DEFAULT_POLL_INTERVAL_MS),
    );
    let logsProcessed = 0;
    let statisticsProcessed = 0;
    let callbackFailed = false;
    let monitorFailed = false;
    let nativeCancellationFailed = false;
    let firstErrorSet = false;
    let firstError: unknown;
    const recordError = (error: unknown): void => {
      if (firstErrorSet) return;
      firstErrorSet = true;
      firstError = error;
    };
    const invokeCallback = (callback: (() => void) | undefined): void => {
      if (callbackFailed || !callback) return;
      try {
        callback();
      } catch (error) {
        callbackFailed = true;
        recordError(error);
      }
    };

    this.nextExpectedLogSequence = 0;
    this.pendingDirectLogEvents.clear();
    const directLogEvents = Boolean(
      options.getLogCallback() &&
      NativeFFmpegKitExtended.isDirectLogBridgeActive?.(),
    );
    let logEventSubscription: LogEventSubscription | undefined;
    const removeLogEventSubscription = (): void => {
      const subscription = logEventSubscription;
      logEventSubscription = undefined;
      subscription?.remove();
    };
    const drainDirectLogEvents = (
      callback: ((log: Log, session: T) => void) | undefined,
      invoke: (callback: (() => void) | undefined) => void,
    ): void => {
      if (!callback) {
        this.pendingDirectLogEvents.clear();
        return;
      }
      for (;;) {
        const next = this.pendingDirectLogEvents.get(this.nextExpectedLogSequence);
        if (!next) break;
        this.pendingDirectLogEvents.delete(this.nextExpectedLogSequence);
        this.nextExpectedLogSequence += 1;
        logsProcessed = Math.max(
          logsProcessed,
          this.nextExpectedLogSequence,
        );
        invoke(() => callback(next, self));
      }
    };
    const reconcileDirectLogEvents = (): void => {
      const callback = options.getLogCallback();
      if (!callback) {
        this.pendingDirectLogEvents.clear();
        return;
      }

      // The count is the terminal reconciliation authority. Steady-state
      // direct delivery never reads indexed history; only a terminal gap
      // causes the bounded missing range to be fetched.
      const count = NativeFFmpegKitExtended.getLogsCount
        ? Math.max(0, Math.trunc(NativeFFmpegKitExtended.getLogsCount(this.sessionId)))
        : parseRequiredJson<SessionSnapshot>(
            NativeFFmpegKitExtended.getSessionJson(this.sessionId),
            `Session ${this.sessionId} no longer exists`,
          ).logsCount;
      if (count > this.nextExpectedLogSequence) {
        const missing = parseJsonArray<Log>(
          NativeFFmpegKitExtended.getLogsJson(
            this.sessionId,
            this.nextExpectedLogSequence,
          ),
        );
        for (const entry of missing) {
          const sequence = this.nextExpectedLogSequence;
          const direct = this.pendingDirectLogEvents.get(sequence);
          this.pendingDirectLogEvents.delete(sequence);
          this.nextExpectedLogSequence += 1;
          logsProcessed = Math.max(
            logsProcessed,
            this.nextExpectedLogSequence,
          );
          invokeCallback(() => callback(direct ?? entry, self));
        }
      }
      drainDirectLogEvents(callback, invokeCallback);
      // A retained-history gap that cannot be recovered at terminal state is
      // intentionally dropped; exposing later direct events out of order is
      // less correct than ending with the last contiguous prefix.
      this.pendingDirectLogEvents.clear();
    };
    if (directLogEvents) {
      logEventSubscription = subscribeLogEvents(this.sessionId, event => {
        if (event.sessionId !== this.sessionId) return;
        if (event.sequence < this.nextExpectedLogSequence) return;
        if (this.pendingDirectLogEvents.has(event.sequence)) return;

        const callback = options.getLogCallback();
        if (!callback) {
          this.pendingDirectLogEvents.clear();
          this.nextExpectedLogSequence = event.sequence + 1;
          return;
        }

        this.pendingDirectLogEvents.set(event.sequence, {
          sessionId: event.sessionId,
          level: event.level,
          message: event.message,
        });
        drainDirectLogEvents(callback, invokeCallback);
      });
    }

    try {
      options.start?.();
    } catch (error) {
      try {
        removeLogEventSubscription();
      } catch {
        // Preserve the native start failure as the primary error.
      }
      throw error;
    }

    // Before terminal state is known, retain ownership and drain through state
    // reads if callback-buffer access fails. Terminal finalization remains the
    // only safe point for releasing the native handle.
    for (;;) {
      if (!monitorFailed) {
        try {
          this.refreshCallbackDemand();
          const logCallback = options.getLogCallback();
          if (logCallback && !directLogEvents) {
            const logs = parseJsonArray<Log>(
              NativeFFmpegKitExtended.getLogsJson(this.sessionId, logsProcessed),
            );
            for (const entry of logs) {
              invokeCallback(() => logCallback(entry, self));
            }
            logsProcessed += logs.length;
          }

          const statisticsCallback = options.getStatisticsCallback?.();
          if (statisticsCallback) {
            const statistics = parseJsonArray<Statistics>(
              NativeFFmpegKitExtended.getStatisticsJson(
                this.sessionId,
                statisticsProcessed,
              ),
            );
            for (const entry of statistics) {
              invokeCallback(() => statisticsCallback(entry, self));
            }
            statisticsProcessed += statistics.length;
          }
        } catch (error) {
          monitorFailed = true;
          recordError(error);
        }
      }

      let state: SessionState;
      try {
        state = this.getState();
      } catch (error) {
        // Callback-buffer failures can drain because terminal state remains
        // observable. A state failure removes that authority, so intentionally
        // release the owning handle to abandon/cancel the unmonitorable run.
        recordError(error);
        try {
          removeLogEventSubscription();
        } catch {
          // Preserve the state-read failure as the primary error.
        }
        try {
          this.releaseOwnedHandle();
        } catch {
          // Preserve the state-read failure as the primary error.
        }
        throw firstError;
      }
      if (
        state === SessionState.Running &&
        this.cancelled &&
        !this.nativeCancellationDispatched &&
        !nativeCancellationFailed
      ) {
        try {
          this.dispatchNativeCancellation();
        } catch (error) {
          nativeCancellationFailed = true;
          monitorFailed = true;
          recordError(error);
        }
      }
      if (state === SessionState.Completed || state === SessionState.Failed) {
        let terminalErrorSet = false;
        let terminalError: unknown;
        let releaseErrorSet = false;
        let releaseError: unknown;
        try {
          if (!monitorFailed) {
            try {
              this.refreshCallbackDemand();
              const logCallback = options.getLogCallback();
              if (directLogEvents) {
                reconcileDirectLogEvents();
              } else if (logCallback) {
                // Once terminal state is observed, all final callback-buffer
                // reads and completion delivery are covered by ownership cleanup.
                const finalLogs = parseJsonArray<Log>(
                  NativeFFmpegKitExtended.getLogsJson(this.sessionId, logsProcessed),
                );
                for (const entry of finalLogs) {
                  invokeCallback(() => logCallback(entry, self));
                }
              }
            } catch (error) {
              monitorFailed = true;
              recordError(error);
            }
          }

          const statisticsCallback = options.getStatisticsCallback?.();
          if (!monitorFailed && statisticsCallback) {
            try {
              const finalStatistics = parseJsonArray<Statistics>(
                NativeFFmpegKitExtended.getStatisticsJson(
                  this.sessionId,
                  statisticsProcessed,
                ),
              );
              for (const entry of finalStatistics) {
                invokeCallback(() => statisticsCallback(entry, self));
              }
            } catch (error) {
              monitorFailed = true;
              recordError(error);
            }
          }

          if (!monitorFailed) {
            invokeCallback(
              options.completeCallback ? () => options.completeCallback?.(self) : undefined,
            );
          }
          // The first observed callback/monitoring failure is authoritative;
          // later failures affect draining but do not replace its error.
          if (firstErrorSet) {
            terminalErrorSet = true;
            terminalError = firstError;
          }
        } catch (error) {
          terminalErrorSet = true;
          terminalError = error;
        } finally {
          try {
            removeLogEventSubscription();
          } catch (error) {
            releaseErrorSet = true;
            releaseError = error;
          }
          // Native C API session handles are owning. Keep the original handle
          // alive for the whole execution, then release it after every
          // terminal-state finalization exit.
          try {
            this.releaseOwnedHandle();
          } catch (error) {
            releaseErrorSet = true;
            releaseError = error;
          }
        }
        if (terminalErrorSet) throw terminalError;
        if (releaseErrorSet) throw releaseError;
        return self;
      }

      await sleep(pollIntervalMs);
    }
  }

  /** Releases this session's owning native handle at most once. */
  protected releaseOwnedHandle(): void {
    if (this.handleReleased) return;
    NativeFFmpegKitExtended.releaseSessionHandle(this.sessionId);
    this.handleReleased = true;
  }

  /** Submits this session once and rejects every later submission attempt. */
  protected submitOnce<T>(submit: () => Promise<T>): Promise<T> {
    if (this.submitted) {
      return Promise.reject(new Error(`Session ${this.sessionId} was already submitted for execution`));
    }
    if (this.cancelled) {
      this.submitted = true;
      return Promise.reject(
        new SessionCancelledException(
          `Session ${this.sessionId} was cancelled before execution`,
        ),
      );
    }
    this.submitted = true;
    return submit();
  }

  private handleReleased = false;
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
    this.refreshCallbackDemand();
  }

  /** Removes the stored log callback. */
  removeLogCallback(): void {
    this.logCallback = undefined;
    this.refreshCallbackDemand();
  }

  /** Sets the default callback for FFmpeg progress/statistics updates. */
  setStatisticsCallback(
    callback?: (statistics: Statistics, session: FFmpegSession) => void,
  ): void {
    this.statisticsCallback = callback;
    this.refreshCallbackDemand();
  }

  /** Removes the stored statistics callback. */
  removeStatisticsCallback(): void {
    this.statisticsCallback = undefined;
    this.refreshCallbackDemand();
  }

  /**
   * Enqueues and starts this session, resolving after terminal state and final
   * callback delivery.
   *
   * A Session object may be submitted for execution once. Create a new session
   * for another execution.
   */
  executeAsync(options: FFmpegExecuteOptions<FFmpegSession> = {}): Promise<this> {
    return this.submitOnce(() => SessionQueueManager.shared.executeSession(
      this,
      () => this.runWithCallbackDemand(
        {
          log: () => Boolean(options.logCallback ?? this.logCallback),
          statistics: () => Boolean(options.statisticsCallback ?? this.statisticsCallback),
        },
        async () => {
          return this.monitor(this, {
            start: () => this.startNativeExecution(0),
            completeCallback: options.completeCallback ?? this.completeCallback,
            getLogCallback: () => options.logCallback ?? this.logCallback,
            getStatisticsCallback: () =>
              options.statisticsCallback ?? this.statisticsCallback,
            pollIntervalMs: options.pollIntervalMs,
          });
        },
      ),
      () => this.releaseOwnedHandle(),
    ));
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
    this.refreshCallbackDemand();
  }

  /** Removes the stored log callback. */
  removeLogCallback(): void {
    this.logCallback = undefined;
    this.refreshCallbackDemand();
  }

  /**
   * Enqueues and executes this FFprobe session.
   *
   * A Session object may be submitted for execution once. Create a new session
   * for another execution.
   */
  executeAsync(options: ExecuteOptions<FFprobeSession> = {}): Promise<this> {
    return this.submitOnce(() => SessionQueueManager.shared.executeSession(
      this,
      () => this.runWithCallbackDemand(
        {log: () => Boolean(options.logCallback ?? this.logCallback)},
        async () => {
          return this.monitor(this, {
            start: () => this.startNativeExecution(0),
            completeCallback: options.completeCallback ?? this.completeCallback,
            getLogCallback: () => options.logCallback ?? this.logCallback,
            pollIntervalMs: options.pollIntervalMs,
          });
        },
      ),
      () => this.releaseOwnedHandle(),
    ));
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
    this.refreshCallbackDemand();
  }

  /** Removes the stored log callback. */
  removeLogCallback(): void {
    this.logCallback = undefined;
    this.refreshCallbackDemand();
  }

  /** Sets the native probe timeout in milliseconds before execution. */
  setTimeout(timeoutMs: number): void {
    this.timeoutMs = timeoutMs;
  }

  /**
   * Enqueues and executes this structured probe.
   *
   * A Session object may be submitted for execution once. Create a new session
   * for another execution.
   */
  executeAsync(
    options: ExecuteOptions<MediaInformationSession> = {},
  ): Promise<this> {
    return this.submitOnce(() => SessionQueueManager.shared.executeSession(
      this,
      () => this.runWithCallbackDemand(
        {log: () => Boolean(options.logCallback ?? this.logCallback)},
        async () => {
          return this.monitor(this, {
            start: () => this.startNativeExecution(this.timeoutMs),
            completeCallback: options.completeCallback ?? this.completeCallback,
            getLogCallback: () => options.logCallback ?? this.logCallback,
            pollIntervalMs: options.pollIntervalMs,
          });
        },
      ),
      () => this.releaseOwnedHandle(),
    ));
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
    this.refreshCallbackDemand();
  }

  /** Removes the stored log callback. */
  removeLogCallback(): void {
    this.logCallback = undefined;
    this.refreshCallbackDemand();
  }

  /** Sets the native playback timeout in milliseconds before execution. */
  setTimeout(timeoutMs: number): void {
    this.timeoutMs = timeoutMs;
  }

  /**
   * Enqueues playback and resolves after playback ends, stops, or fails.
   *
   * A Session object may be submitted for execution once. Create a new session
   * for another execution.
   */
  executeAsync(options: ExecuteOptions<FFplaySession> = {}): Promise<this> {
    return this.submitOnce(() => SessionQueueManager.shared.executeSession(
      this,
      () => this.runWithCallbackDemand(
        {log: () => Boolean(options.logCallback ?? this.logCallback)},
        async () => {
          return this.monitor(this, {
            start: () => this.startNativeExecution(this.timeoutMs),
            completeCallback: options.completeCallback ?? this.completeCallback,
            getLogCallback: () => options.logCallback ?? this.logCallback,
            pollIntervalMs: options.pollIntervalMs,
          });
        },
      ),
      () => this.releaseOwnedHandle(),
    ));
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
