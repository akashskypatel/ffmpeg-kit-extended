import { getBackend } from './platform/backend-registry';
import type {
  ExecuteOptions,
  FFmpegExecuteOptions,
  Log,
  SessionSnapshot,
  SessionType,
  Statistics,
} from './types';
import { SessionState } from './types';
import {
  MediaInformation,
  type MediaInformationData,
} from './media-information';
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
import { subscribeLogEvents } from './platform/log-event-router';
import type {
  LogEvent,
  LogEventSubscription,
} from './platform/backend-registry';
import {
  restoredSessionObserver,
} from './session-observation';
import {
  clearCancellationDispatch,
  dispatchCancellationSerialized,
} from './session-cancellation';
import {
  ensureRetainedReleaseRetry,
  releaseSessionHandleSerialized,
} from './session-lifetime';

const NativeFFmpegKitExtended = getBackend();

const DEFAULT_POLL_INTERVAL_MS = 50;

/** Non-destructive rejection for an identity that is no longer Created. */
class SessionNotCreatedError extends Error {
  constructor(sessionId: number, state: SessionState) {
    super(`Session ${sessionId} cannot start from state ${state}`);
    this.name = 'SessionNotCreatedError';
  }
}

type CallbackDemandProviders = {
  log: () => boolean;
  statistics?: () => boolean;
};

type RestoredCallbackReaders = {
  complete?: () => ((session: Session) => void) | undefined;
  log?: () => ((log: Log, session: Session) => void) | undefined;
  statistics?: () =>
    | ((statistics: Statistics, session: Session) => void)
    | undefined;
};

type MonitorOptions<T extends Session> = {
  completeCallback?: (session: T) => void;
  getLogCallback: () => ((log: Log, session: T) => void) | undefined;
  getStatisticsCallback?: () =>
    | ((statistics: Statistics, session: T) => void)
    | undefined;
  pollIntervalMs?: number;
  start?: () => void | Promise<void>;
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
 *
 * @category Sessions
 */
export abstract class Session {
  /** Process-unique native identity; it is not persistent across restarts. */
  readonly sessionId: number;
  /** Normalized/original command representation associated with this wrapper. */
  readonly command: string;
  /** Session kind: `ffmpeg`, `ffprobe`, `ffplay`, or `media-information`. */
  readonly type: SessionType;
  private cancelled = false;
  private nativeCancellationDispatched = false;
  /** Whether the one-shot public execution submission opportunity was consumed. */
  private submitted = false;
  /** Whether the final preflight crossed into native startup. */
  private nativeStartAttempted = false;
  private createdSessionAbandoned = false;
  private callbackDemandActive = false;
  private callbackDemandProviders?: CallbackDemandProviders;
  private readonly callbackDemandLeases = new Map<
    CallbackDemandKind,
    CallbackDemandLease
  >();
  private nextExpectedLogSequence = 0;
  private readonly pendingDirectLogEvents = new Map<number, Log>();
  private restoredRunning = false;
  private restoredTerminalSettled = false;
  private restoredLogsProcessed = 0;
  private restoredStatisticsProcessed = 0;
  private restoredObserverErrorReported = false;
  private restoredCallbackReaders: RestoredCallbackReaders = {};
  private restoredLogEventSubscription?: LogEventSubscription;
  private restoredNextExpectedLogSequence = 0;
  private readonly restoredPendingLogEvents = new Map<number, Log>();
  private restoredTransition: Promise<void> = Promise.resolve();

  protected constructor(sessionId: number, command: string, type: SessionType) {
    this.sessionId = sessionId;
    this.command = command;
    this.type = type;
  }

  /** Whether cancellation was requested through this JavaScript object. */
  get isCancelled(): boolean {
    return (
      this.cancelled ||
      NativeFFmpegKitExtended.isCancellationRequested?.(this.sessionId) === true
    );
  }

  /**
   * Records queue cancellation without reading native state or dispatching a
   * cancellation request for work that has not started.
   */
  #markCancelledBeforeExecution(): void {
    this.cancelled = true;
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

  /**
   * Whether this wrapper observes an already-running history identity.
   * @internal
   */
  get isRestoredRunning(): boolean {
    return this.restoredRunning;
  }

  /**
   * Joins the shared non-executing observer for a Running history snapshot.
   * @internal
   */
  observeRestoredRunning(): void {
    if (this.restoredRunning) return;
    this.restoredRunning = true;
    this.callbackDemandActive = true;
    this.callbackDemandProviders = {
      log: () => Boolean(this.restoredCallbackReaders.log?.()),
      statistics: () => Boolean(this.restoredCallbackReaders.statistics?.()),
    };
    restoredSessionObserver.ensureObserved(this.sessionId);
  }

  /** Supplies callback readers without coupling the coordinator to subclasses. */
  protected setRestoredCallbackReaders(readers: RestoredCallbackReaders): void {
    this.restoredCallbackReaders = readers;
  }

  /** Verifies that a restored callback setter still has a live target. */
  protected assertRestoredCallbackState(): void {
    if (!this.restoredRunning) return;
    if (this.restoredTerminalSettled) {
      throw new Error(
        `Session ${this.sessionId} is no longer Running and cannot accept an observer callback`
      );
    }
    const state = this.getState();
    if (state !== SessionState.Running) {
      throw new Error(
        `Session ${this.sessionId} is no longer Running and cannot accept an observer callback`
      );
    }
  }

  /** Updates optional observer demand transactionally for restored wrappers. */
  protected async updateCallbackAtomically(
    update: () => void,
    rollback: () => void
  ): Promise<void> {
    if (!this.restoredRunning)
      return this.updateCallbackAtomicallyWithinTransition(update, rollback);
    return this.runRestoredTransition(() =>
      this.updateCallbackAtomicallyWithinTransition(update, rollback)
    );
  }

  private async updateCallbackAtomicallyWithinTransition(
    update: () => void,
    rollback: () => void
  ): Promise<void> {
    this.assertRestoredCallbackState();
    update();
    try {
      const demand = this.refreshCallbackDemand();
      if (demand instanceof Promise) await demand;
      this.assertRestoredCallbackState();
      this.syncRestoredLogEventSubscription();
      this.syncRestoredCallbackTarget();
    } catch (error) {
      rollback();
      try {
        const rollbackDemand = this.refreshCallbackDemand();
        if (rollbackDemand instanceof Promise) await rollbackDemand;
        this.syncRestoredLogEventSubscription();
        this.syncRestoredCallbackTarget();
      } catch {
        // Preserve the bridge-install failure as the primary setter error.
      }
      throw error;
    }
  }

  private runRestoredTransition<T>(operation: () => Promise<T>): Promise<T> {
    const next = this.restoredTransition.then(operation, operation);
    this.restoredTransition = next.then(
      () => undefined,
      () => undefined
    );
    return next;
  }

  private hasRestoredObserverSinks(): boolean {
    return Boolean(
      this.restoredCallbackReaders.complete?.() ||
        this.restoredCallbackReaders.log?.() ||
        this.restoredCallbackReaders.statistics?.()
    );
  }

  protected syncRestoredCallbackTarget(): void {
    if (
      this.restoredRunning &&
      !this.restoredTerminalSettled &&
      this.hasRestoredObserverSinks()
    ) {
      restoredSessionObserver.attachCallbackTarget(this.sessionId, this);
    } else {
      restoredSessionObserver.detachCallbackTarget(this.sessionId, this);
    }
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
   * deliver it when Running is observed again. Successful never-started
   * abandonment makes repeated cancellation a no-op; failed cancellation
   * remains retryable.
   */
  async cancel(): Promise<void> {
    const managed = SessionQueueManager.shared.findManagedSessionById(
      this.sessionId
    );
    if (managed && managed !== this) {
      // A different managed owner controls durable per-ID cancellation state.
      // This wrapper records only its local request before delegating.
      this.cancelled = true;
      const delegated = managed.cancel();
      if (delegated instanceof Promise) await delegated;
      return;
    }

    if (
      this.cancelled &&
      (this.nativeCancellationDispatched || this.preExecutionCleanupCommitted)
    ) {
      return;
    }

    this.cancelled = true;
    NativeFFmpegKitExtended.recordCancellationIntent?.(this.sessionId);

    const queuedCancellation = SessionQueueManager.shared.cancelQueued(this);
    if (queuedCancellation instanceof Promise) {
      if (await queuedCancellation) return;
    } else if (queuedCancellation) {
      return;
    }

    if (this.createdSessionAbandoned && !this.handleReleased) {
      await this.releaseOwnedHandle();
      if (this.preExecutionCleanupCommitted) return;
    }

    const state = this.getState();
    if (state === SessionState.Created && !this.nativeStartAttempted) {
      // Public submission may have been consumed before queue/native handoff;
      // only the native-start boundary makes Created abandonment destructive.
      await this.discardBeforeExecution();
      return;
    }
    if (state === SessionState.Running) {
      await this.dispatchNativeCancellation();
    } else if (
      state === SessionState.Completed ||
      state === SessionState.Failed
    ) {
      NativeFFmpegKitExtended.clearCancellationIntent?.(this.sessionId);
      clearCancellationDispatch(this.sessionId);
    }
  }

  /** Enables additional native debug-log capture for this session. */
  async enableDebugLog(): Promise<void> {
    await NativeFFmpegKitExtended.enableDebugLog(this.sessionId);
  }

  /** Disables additional native debug-log capture for this session. */
  async disableDebugLog(): Promise<void> {
    await NativeFFmpegKitExtended.disableDebugLog(this.sessionId);
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
  async clearDebugLog(): Promise<void> {
    await NativeFFmpegKitExtended.clearDebugLog(this.sessionId);
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
      `Session ${this.sessionId} no longer exists`
    );
  }

  /** Starts native execution and releases the owning handle if start fails. */
  protected startNativeExecution(timeoutMs: number): void | Promise<void> {
    try {
      // Queue handoff already performs this check. Keep a direct guard for the
      // executor seam, but validation rejection must not retire existing history
      // or restored ownership.
      this.prepareForExecution();
      // A Created observation is protected from destructive abandonment once
      // native startup has been attempted, even if the worker reports Created
      // until its startup handoff reaches Running.
      this.nativeStartAttempted = true;
      const completion = NativeFFmpegKitExtended.executeSessionAsync(
        this.sessionId,
        timeoutMs
      );
      if (completion instanceof Promise) {
        return completion.catch(async (error) => {
          this.nativeStartAttempted = false;
          try {
            await this.releaseOwnedHandle();
          } catch {
            // Preserve the native start failure as the primary error.
          }
          throw error;
        });
      }
      return;
    } catch (error) {
      if (
        error instanceof SessionNotCreatedError ||
        error instanceof SessionCancelledException
      ) {
        throw error;
      }
      this.nativeStartAttempted = false;
      let release: void | Promise<void>;
      try {
        release = this.releaseOwnedHandle();
      } catch {
        throw error;
      }
      if (release instanceof Promise) {
        return release.then(
          () => Promise.reject(error),
          () => Promise.reject(error)
        );
      }
      throw error;
    }
  }

  /** Performs the non-mutating authoritative preflight before queue admission. */
  protected validateInitialSubmission(): void {
    if (NativeFFmpegKitExtended.isSessionAbandoned?.(this.sessionId)) {
      throw new SessionCancelledException(
        `Session ${this.sessionId} was abandoned before execution`
      );
    }
    if (NativeFFmpegKitExtended.isCancellationRequested?.(this.sessionId)) {
      throw new SessionCancelledException(
        `Session ${this.sessionId} has a durable cancellation request`
      );
    }
    if (this.cancelled) {
      throw new SessionCancelledException(
        `Session ${this.sessionId} was cancelled before execution`
      );
    }
    const state = this.getState();
    if (state !== SessionState.Created) {
      throw new SessionNotCreatedError(this.sessionId, state);
    }
  }

  /**
   * Revalidates the native session immediately before async handoff.
   * @internal
   */
  prepareForExecution(): void {
    this.validateInitialSubmission();
  }

  /** Forwards cancellation through the shared per-ID delivery authority. */
  private async dispatchNativeCancellation(): Promise<void> {
    if (this.nativeCancellationDispatched) return;
    await dispatchCancellationSerialized(this.sessionId);
    this.nativeCancellationDispatched = true;
  }

  /**
   * Runs one submitted execution with mandatory completion demand and optional
   * log/statistics demand. The execution error always wins over bridge cleanup
   * errors, while a cleanup error remains observable when execution succeeds.
   */
  protected async runWithCallbackDemand<T>(
    providers: CallbackDemandProviders,
    operation: () => Promise<T>
  ): Promise<T> {
    this.callbackDemandProviders = providers;
    this.callbackDemandActive = true;

    let result!: T;
    let primaryErrorSet = false;
    let primaryError: unknown;
    try {
      const completionDemand = this.acquireCallbackDemand('completion');
      if (completionDemand instanceof Promise) await completionDemand;
      const callbackDemand = this.refreshCallbackDemand();
      if (callbackDemand instanceof Promise) await callbackDemand;
      result = await operation();
    } catch (error) {
      primaryErrorSet = true;
      primaryError = error;
    }

    const cleanupError = await this.releaseAllCallbackDemand();
    this.callbackDemandActive = false;
    this.callbackDemandProviders = undefined;

    if (primaryErrorSet) throw primaryError;
    if (cleanupError !== undefined) throw cleanupError;
    return result;
  }

  /** Reconciles optional leases with the currently visible callback sinks. */
  protected refreshCallbackDemand(): void | Promise<void> {
    if (!this.callbackDemandActive || !this.callbackDemandProviders) return;
    const logDemand = this.syncCallbackDemand(
      'log',
      this.callbackDemandProviders.log()
    );
    if (logDemand instanceof Promise) {
      return logDemand
        .then(() =>
          this.syncCallbackDemand(
            'statistics',
            this.callbackDemandProviders?.statistics?.() ?? false
          )
        )
        .then(() => undefined);
    }
    const statisticsDemand = this.syncCallbackDemand(
      'statistics',
      this.callbackDemandProviders.statistics?.() ?? false
    );
    return statisticsDemand;
  }

  private syncCallbackDemand(
    kind: 'log' | 'statistics',
    needed: boolean
  ): void | Promise<void> {
    const existing = this.callbackDemandLeases.get(kind);
    if (needed) {
      if (!existing) return this.acquireCallbackDemand(kind);
      return;
    }
    if (!existing) return;
    this.callbackDemandLeases.delete(kind);
    return existing.release();
  }

  private acquireCallbackDemand(
    kind: CallbackDemandKind
  ): void | Promise<void> {
    if (this.callbackDemandLeases.has(kind)) return;
    const acquired = callbackDemandAuthority.acquire(
      kind,
      this.callbackDemandHooks(kind)
    );
    if (acquired instanceof Promise) {
      return acquired.then((lease) => {
        this.callbackDemandLeases.set(kind, lease);
      });
    }
    this.callbackDemandLeases.set(kind, acquired);
  }

  private callbackDemandHooks(kind: CallbackDemandKind): CallbackDemandHooks {
    switch (kind) {
      case 'completion':
        return {
          install: () => NativeFFmpegKitExtended.installCompletionBridge?.(),
          uninstall: () =>
            NativeFFmpegKitExtended.uninstallCompletionBridge?.(),
        };
      case 'log':
        return {
          install: () => NativeFFmpegKitExtended.installLogBridge?.(),
          uninstall: () => NativeFFmpegKitExtended.uninstallLogBridge?.(),
        };
      case 'statistics':
        return {
          install: () => NativeFFmpegKitExtended.installStatisticsBridge?.(),
          uninstall: () =>
            NativeFFmpegKitExtended.uninstallStatisticsBridge?.(),
        };
    }
  }

  private async releaseAllCallbackDemand(): Promise<unknown> {
    let firstError: unknown;
    for (const kind of [...this.callbackDemandLeases.keys()].reverse()) {
      const lease = this.callbackDemandLeases.get(kind);
      this.callbackDemandLeases.delete(kind);
      if (!lease) continue;
      try {
        await lease.release();
      } catch (error) {
        if (firstError === undefined) firstError = error;
      }
    }
    return firstError;
  }

  /**
   * Polls callback buffers for an observer-owned Running history wrapper.
   * @internal
   */
  async pollRestoredCallbacks(): Promise<void> {
    return this.runRestoredTransition(() =>
      this.pollRestoredCallbacksWithinTransition()
    );
  }

  private async pollRestoredCallbacksWithinTransition(): Promise<void> {
    if (!this.restoredRunning || this.restoredTerminalSettled) return;
    const demand = this.refreshCallbackDemand();
    if (demand instanceof Promise) await demand;
    this.syncRestoredLogEventSubscription();

    const logCallback = this.restoredCallbackReaders.log?.();
    if (logCallback && !this.restoredLogEventSubscription) {
      const logs = parseJsonArray<Log>(
        NativeFFmpegKitExtended.getLogsJson(
          this.sessionId,
          this.restoredLogsProcessed
        )
      );
      for (const entry of logs) {
        try {
          logCallback(entry, this);
        } catch (error) {
          this.reportRestoredObserverError(error);
        }
      }
      this.restoredLogsProcessed += logs.length;
    }

    const statisticsCallback = this.restoredCallbackReaders.statistics?.();
    if (statisticsCallback) {
      const statistics = parseJsonArray<Statistics>(
        NativeFFmpegKitExtended.getStatisticsJson(
          this.sessionId,
          this.restoredStatisticsProcessed
        )
      );
      for (const entry of statistics) {
        try {
          statisticsCallback(entry, this);
        } catch (error) {
          this.reportRestoredObserverError(error);
        }
      }
      this.restoredStatisticsProcessed += statistics.length;
    }
  }

  /**
   * Settles callbacks and observer demand after terminal state is authoritative.
   * @internal
   */
  async settleRestoredObservation(): Promise<void> {
    return this.runRestoredTransition(() =>
      this.settleRestoredObservationWithinTransition()
    );
  }

  private async settleRestoredObservationWithinTransition(): Promise<void> {
    if (this.restoredTerminalSettled) return;
    let firstError: unknown;
    try {
      await this.pollRestoredCallbacksWithinTransition();
      const logCallback = this.restoredCallbackReaders.log?.();
      if (logCallback && this.restoredLogEventSubscription) {
        this.reconcileRestoredLogEvents(logCallback);
      }
    } catch (error) {
      firstError = error;
    }
    const completeCallback = this.restoredCallbackReaders.complete?.();
    if (completeCallback) {
      try {
        completeCallback(this);
      } catch (error) {
        firstError ??= error;
      }
    }
    NativeFFmpegKitExtended.clearCancellationIntent?.(this.sessionId);
    const cleanupError = await this.releaseAllCallbackDemand();
    this.removeRestoredLogEventSubscription();
    this.callbackDemandActive = false;
    this.callbackDemandProviders = undefined;
    this.restoredTerminalSettled = true;
    this.syncRestoredCallbackTarget();
    clearCancellationDispatch(this.sessionId);
    if (firstError !== undefined) throw firstError;
    if (cleanupError !== undefined) throw cleanupError;
  }

  /**
   * Releases this wrapper's share of restored ownership through the ID seam.
   * @internal
   */
  async releaseRestoredHandle(): Promise<void> {
    await this.releaseOwnedHandle();
  }

  /**
   * Stops observer callback demand after a successful global history clear.
   * @internal
   */
  async invalidateRestoredObservation(): Promise<void> {
    return this.runRestoredTransition(() =>
      this.invalidateRestoredObservationWithinTransition()
    );
  }

  private async invalidateRestoredObservationWithinTransition(): Promise<void> {
    if (!this.restoredRunning || this.restoredTerminalSettled) return;
    const cleanupError = await this.releaseAllCallbackDemand();
    this.removeRestoredLogEventSubscription();
    this.callbackDemandActive = false;
    this.callbackDemandProviders = undefined;
    this.restoredTerminalSettled = true;
    this.syncRestoredCallbackTarget();
    clearCancellationDispatch(this.sessionId);
    if (cleanupError !== undefined) throw cleanupError;
  }

  /**
   * Reports a retryable observer failure without abandoning retained ownership.
   * @internal
   */
  reportRestoredObserverError(error: unknown): void {
    if (this.restoredObserverErrorReported) return;
    this.restoredObserverErrorReported = true;
    console.warn(
      `Restored session observer failed for ${this.sessionId}`,
      error
    );
  }

  private syncRestoredLogEventSubscription(): void {
    const shouldSubscribe = Boolean(
      this.restoredRunning &&
        !this.restoredTerminalSettled &&
        this.restoredCallbackReaders.log?.() &&
        NativeFFmpegKitExtended.isDirectLogBridgeActive?.()
    );
    if (!shouldSubscribe) {
      this.removeRestoredLogEventSubscription();
      return;
    }
    if (this.restoredLogEventSubscription) return;
    this.restoredLogEventSubscription = subscribeLogEvents(
      this.sessionId,
      (event) => this.handleRestoredLogEvent(event)
    );
  }

  private handleRestoredLogEvent(event: LogEvent): void {
    if (event.sessionId !== this.sessionId) return;
    if (event.sequence < this.restoredNextExpectedLogSequence) return;
    if (this.restoredPendingLogEvents.has(event.sequence)) return;
    const callback = this.restoredCallbackReaders.log?.();
    if (!callback) return;
    this.restoredPendingLogEvents.set(event.sequence, {
      sessionId: event.sessionId,
      level: event.level,
      message: event.message,
    });
    this.drainRestoredLogEvents(callback);
  }

  private drainRestoredLogEvents(
    callback: (log: Log, session: Session) => void
  ): void {
    for (;;) {
      const entry = this.restoredPendingLogEvents.get(
        this.restoredNextExpectedLogSequence
      );
      if (!entry) return;
      this.restoredPendingLogEvents.delete(
        this.restoredNextExpectedLogSequence
      );
      this.restoredNextExpectedLogSequence += 1;
      this.restoredLogsProcessed = Math.max(
        this.restoredLogsProcessed,
        this.restoredNextExpectedLogSequence
      );
      try {
        callback(entry, this);
      } catch (error) {
        this.reportRestoredObserverError(error);
      }
    }
  }

  private reconcileRestoredLogEvents(
    callback: (log: Log, session: Session) => void
  ): void {
    const count = NativeFFmpegKitExtended.getLogsCount
      ? Math.max(
          0,
          Math.trunc(NativeFFmpegKitExtended.getLogsCount(this.sessionId))
        )
      : parseRequiredJson<SessionSnapshot>(
          NativeFFmpegKitExtended.getSessionJson(this.sessionId),
          `Session ${this.sessionId} no longer exists`
        ).logsCount;
    if (count > this.restoredNextExpectedLogSequence) {
      const missing = parseJsonArray<Log>(
        NativeFFmpegKitExtended.getLogsJson(
          this.sessionId,
          this.restoredNextExpectedLogSequence
        )
      );
      for (const entry of missing) {
        const sequence = this.restoredNextExpectedLogSequence;
        const direct = this.restoredPendingLogEvents.get(sequence);
        this.restoredPendingLogEvents.delete(sequence);
        this.restoredNextExpectedLogSequence += 1;
        this.restoredLogsProcessed = Math.max(
          this.restoredLogsProcessed,
          this.restoredNextExpectedLogSequence
        );
        try {
          callback(direct ?? entry, this);
        } catch (error) {
          this.reportRestoredObserverError(error);
        }
      }
    }
    this.drainRestoredLogEvents(callback);
    this.restoredPendingLogEvents.clear();
  }

  private removeRestoredLogEventSubscription(): void {
    this.restoredLogEventSubscription?.remove();
    this.restoredLogEventSubscription = undefined;
    this.restoredPendingLogEvents.clear();
  }

  protected async monitor<T extends Session>(
    self: T,
    options: MonitorOptions<T>
  ): Promise<T> {
    const pollIntervalMs = Math.max(
      10,
      Math.floor(options.pollIntervalMs ?? DEFAULT_POLL_INTERVAL_MS)
    );
    let logsProcessed = 0;
    let statisticsProcessed = 0;
    let callbackFailed = false;
    let monitorFailed = false;
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
        NativeFFmpegKitExtended.isDirectLogBridgeActive?.()
    );
    let logEventSubscription: LogEventSubscription | undefined;
    const removeLogEventSubscription = (): void => {
      const subscription = logEventSubscription;
      logEventSubscription = undefined;
      subscription?.remove();
    };
    const drainDirectLogEvents = (
      callback: ((log: Log, session: T) => void) | undefined,
      invoke: (callback: (() => void) | undefined) => void
    ): void => {
      if (!callback) {
        this.pendingDirectLogEvents.clear();
        return;
      }
      for (;;) {
        const next = this.pendingDirectLogEvents.get(
          this.nextExpectedLogSequence
        );
        if (!next) break;
        this.pendingDirectLogEvents.delete(this.nextExpectedLogSequence);
        this.nextExpectedLogSequence += 1;
        logsProcessed = Math.max(logsProcessed, this.nextExpectedLogSequence);
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
        ? Math.max(
            0,
            Math.trunc(NativeFFmpegKitExtended.getLogsCount(this.sessionId))
          )
        : parseRequiredJson<SessionSnapshot>(
            NativeFFmpegKitExtended.getSessionJson(this.sessionId),
            `Session ${this.sessionId} no longer exists`
          ).logsCount;
      if (count > this.nextExpectedLogSequence) {
        const missing = parseJsonArray<Log>(
          NativeFFmpegKitExtended.getLogsJson(
            this.sessionId,
            this.nextExpectedLogSequence
          )
        );
        for (const entry of missing) {
          const sequence = this.nextExpectedLogSequence;
          const direct = this.pendingDirectLogEvents.get(sequence);
          this.pendingDirectLogEvents.delete(sequence);
          this.nextExpectedLogSequence += 1;
          logsProcessed = Math.max(logsProcessed, this.nextExpectedLogSequence);
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
      logEventSubscription = subscribeLogEvents(this.sessionId, (event) => {
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
      const start = options.start?.();
      if (start instanceof Promise) await start;
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
          const callbackDemand = this.refreshCallbackDemand();
          if (callbackDemand instanceof Promise) await callbackDemand;
          const logCallback = options.getLogCallback();
          if (logCallback && !directLogEvents) {
            const logs = parseJsonArray<Log>(
              NativeFFmpegKitExtended.getLogsJson(this.sessionId, logsProcessed)
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
                statisticsProcessed
              )
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
          await this.releaseOwnedHandle();
        } catch {
          // Preserve the state-read failure as the primary error.
        }
        throw firstError;
      }
      if (
        state === SessionState.Running &&
        this.cancelled &&
        !this.nativeCancellationDispatched
      ) {
        try {
          await this.dispatchNativeCancellation();
        } catch (error) {
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
              const callbackDemand = this.refreshCallbackDemand();
              if (callbackDemand instanceof Promise) await callbackDemand;
              const logCallback = options.getLogCallback();
              if (directLogEvents) {
                reconcileDirectLogEvents();
              } else if (logCallback) {
                // Once terminal state is observed, all final callback-buffer
                // reads and completion delivery are covered by ownership cleanup.
                const finalLogs = parseJsonArray<Log>(
                  NativeFFmpegKitExtended.getLogsJson(
                    this.sessionId,
                    logsProcessed
                  )
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
                  statisticsProcessed
                )
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
              options.completeCallback
                ? () => options.completeCallback?.(self)
                : undefined
            );
          }
          // Terminal state is authoritative even when callback/log draining
          // reported an earlier error; do not leave cancellation intent live
          // after the native identity has settled.
          NativeFFmpegKitExtended.clearCancellationIntent?.(this.sessionId);
          clearCancellationDispatch(this.sessionId);
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
            await this.releaseOwnedHandle();
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
  protected releaseOwnedHandle(): void | Promise<void> {
    if (this.handleReleased) return;
    return releaseSessionHandleSerialized(this.sessionId).then(
      () => {
        this.handleReleased = true;
      },
      (error) => {
        ensureRetainedReleaseRetry(this.sessionId);
        throw error;
      }
    );
  }

  /** Removes history for an explicit pre-execution discard without releasing a handle. */
  protected abandonCreatedSession(): void | Promise<void> {
    if (this.createdSessionAbandoned) return;
    const completion = NativeFFmpegKitExtended.abandonCreatedSession(
      this.sessionId
    );
    if (completion instanceof Promise) {
      return completion.then(() => {
        this.createdSessionAbandoned = true;
      });
    }
    this.createdSessionAbandoned = true;
  }

  /** Tombstones and releases a retained handle when queued work is discarded. */
  protected async discardBeforeExecution(): Promise<void> {
    let firstError: unknown;
    try {
      await this.abandonCreatedSession();
    } catch (error) {
      firstError = error;
    }
    try {
      await this.releaseOwnedHandle();
    } catch (error) {
      if (firstError === undefined) firstError = error;
    }
    if (firstError !== undefined) throw firstError;
  }

  /** Whether both halves of pre-execution cleanup have committed. */
  private get preExecutionCleanupCommitted(): boolean {
    return this.createdSessionAbandoned && this.handleReleased;
  }

  /**
   * Enqueues this session while keeping queue-local cancellation mutation
   * private to the base Session implementation.
   */
  protected enqueueSessionExecution<T>(
    executor: () => Promise<T>,
    onDiscard: () => void | Promise<void>
  ): Promise<T> {
    return SessionQueueManager.shared.executeSession(
      this,
      executor,
      onDiscard,
      () => this.#markCancelledBeforeExecution()
    );
  }

  /** Submits this session once and rejects every later submission attempt. */
  protected submitOnce<T>(submit: () => Promise<T>): Promise<T> {
    if (this.submitted) {
      return Promise.reject(
        new Error(
          `Session ${this.sessionId} was already submitted for execution`
        )
      );
    }
    if (this.cancelled) {
      this.submitted = true;
      return Promise.reject(
        new SessionCancelledException(
          `Session ${this.sessionId} was cancelled before execution`
        )
      );
    }
    try {
      this.validateInitialSubmission();
    } catch (error) {
      // Admission never started. A failed state/runtime observation does not
      // own cleanup of an existing native or restored history identity.
      return Promise.reject(error);
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
    session: FFmpegSession
  ) => void;

  /**
   * Wraps an existing valid native FFmpeg session identity.
   *
   * Normal applications should obtain this wrapper from `FFmpegKit` factory,
   * execution, or history APIs. An arbitrary ID does not create a native
   * session and can make getters, execution, and control operations fail.
   */
  constructor(sessionId: number, command: string) {
    super(sessionId, command, 'ffmpeg');
    this.setRestoredCallbackReaders({
      complete: () =>
        this.completeCallback
          ? (session) => this.completeCallback?.(session as FFmpegSession)
          : undefined,
      log: () =>
        this.logCallback
          ? (log, session) => this.logCallback?.(log, session as FFmpegSession)
          : undefined,
      statistics: () =>
        this.statisticsCallback
          ? (statistics, session) =>
              this.statisticsCallback?.(statistics, session as FFmpegSession)
          : undefined,
    });
  }

  /** Sets the default callback invoked immediately before promise resolution. */
  setCompleteCallback(callback?: (session: FFmpegSession) => void): void {
    this.assertRestoredCallbackState();
    this.completeCallback = callback;
    this.syncRestoredCallbackTarget();
  }

  /** Removes the stored completion callback. */
  removeCompleteCallback(): void {
    this.completeCallback = undefined;
    this.syncRestoredCallbackTarget();
  }

  /** Sets the default callback for newly buffered log entries. */
  async setLogCallback(
    callback?: (log: Log, session: FFmpegSession) => void
  ): Promise<void> {
    const previous = this.logCallback;
    await this.updateCallbackAtomically(
      () => {
        this.logCallback = callback;
      },
      () => {
        this.logCallback = previous;
      }
    );
  }

  /** Removes the stored log callback. */
  async removeLogCallback(): Promise<void> {
    await this.setLogCallback(undefined);
  }

  /** Sets the default callback for FFmpeg progress/statistics updates. */
  async setStatisticsCallback(
    callback?: (statistics: Statistics, session: FFmpegSession) => void
  ): Promise<void> {
    const previous = this.statisticsCallback;
    await this.updateCallbackAtomically(
      () => {
        this.statisticsCallback = callback;
      },
      () => {
        this.statisticsCallback = previous;
      }
    );
  }

  /** Removes the stored statistics callback. */
  async removeStatisticsCallback(): Promise<void> {
    await this.setStatisticsCallback(undefined);
  }

  /**
   * Enqueues and starts this session, resolving after terminal state and final
   * callback delivery.
   *
   * A Session object may be submitted for execution once. Create a new session
   * for another execution.
   */
  executeAsync(
    options: FFmpegExecuteOptions<FFmpegSession> = {}
  ): Promise<this> {
    return this.submitOnce(() =>
      this.enqueueSessionExecution(
        () =>
          this.runWithCallbackDemand(
            {
              log: () => Boolean(options.logCallback ?? this.logCallback),
              statistics: () =>
                Boolean(options.statisticsCallback ?? this.statisticsCallback),
            },
            async () => {
              return this.monitor(this, {
                start: () => this.startNativeExecution(0),
                completeCallback:
                  options.completeCallback ?? this.completeCallback,
                getLogCallback: () => options.logCallback ?? this.logCallback,
                getStatisticsCallback: () =>
                  options.statisticsCallback ?? this.statisticsCallback,
                pollIntervalMs: options.pollIntervalMs,
              });
            }
          ),
        () => this.discardBeforeExecution()
      )
    );
  }
}

/** FFprobe command session with completion and log callbacks. */
export class FFprobeSession extends Session {
  private completeCallback?: (session: FFprobeSession) => void;
  private logCallback?: (log: Log, session: FFprobeSession) => void;

  /**
   * Wraps an existing valid native FFprobe session identity.
   *
   * Normal applications should obtain this wrapper from `FFprobeKit` factory,
   * execution, or history APIs. An arbitrary ID does not create a native
   * session and can make getters, execution, and control operations fail.
   */
  constructor(sessionId: number, command: string) {
    super(sessionId, command, 'ffprobe');
    this.setRestoredCallbackReaders({
      complete: () =>
        this.completeCallback
          ? (session) => this.completeCallback?.(session as FFprobeSession)
          : undefined,
      log: () =>
        this.logCallback
          ? (log, session) => this.logCallback?.(log, session as FFprobeSession)
          : undefined,
    });
  }

  /** Sets the default completion callback. */
  setCompleteCallback(callback?: (session: FFprobeSession) => void): void {
    this.assertRestoredCallbackState();
    this.completeCallback = callback;
    this.syncRestoredCallbackTarget();
  }

  /** Removes the stored completion callback. */
  removeCompleteCallback(): void {
    this.completeCallback = undefined;
    this.syncRestoredCallbackTarget();
  }

  /** Sets the default log callback. */
  async setLogCallback(
    callback?: (log: Log, session: FFprobeSession) => void
  ): Promise<void> {
    const previous = this.logCallback;
    await this.updateCallbackAtomically(
      () => {
        this.logCallback = callback;
      },
      () => {
        this.logCallback = previous;
      }
    );
  }

  /** Removes the stored log callback. */
  async removeLogCallback(): Promise<void> {
    await this.setLogCallback(undefined);
  }

  /**
   * Enqueues and executes this FFprobe session.
   *
   * A Session object may be submitted for execution once. Create a new session
   * for another execution.
   */
  executeAsync(options: ExecuteOptions<FFprobeSession> = {}): Promise<this> {
    return this.submitOnce(() =>
      this.enqueueSessionExecution(
        () =>
          this.runWithCallbackDemand(
            { log: () => Boolean(options.logCallback ?? this.logCallback) },
            async () => {
              return this.monitor(this, {
                start: () => this.startNativeExecution(0),
                completeCallback:
                  options.completeCallback ?? this.completeCallback,
                getLogCallback: () => options.logCallback ?? this.logCallback,
                pollIntervalMs: options.pollIntervalMs,
              });
            }
          ),
        () => this.discardBeforeExecution()
      )
    );
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

  /**
   * Wraps an existing valid native media-information session identity.
   *
   * Normal applications should obtain this wrapper from `FFprobeKit` factory,
   * execution, or history APIs. An arbitrary ID does not create a native
   * session and can make getters or execution fail. `timeoutMs` is measured in
   * milliseconds.
   */
  constructor(sessionId: number, command: string, timeoutMs = 500) {
    super(sessionId, command, 'media-information');
    this.timeoutMs = timeoutMs;
    this.setRestoredCallbackReaders({
      complete: () =>
        this.completeCallback
          ? (session) =>
              this.completeCallback?.(session as MediaInformationSession)
          : undefined,
      log: () =>
        this.logCallback
          ? (log, session) =>
              this.logCallback?.(log, session as MediaInformationSession)
          : undefined,
    });
  }

  /** Sets the default completion callback. */
  setCompleteCallback(
    callback?: (session: MediaInformationSession) => void
  ): void {
    this.assertRestoredCallbackState();
    this.completeCallback = callback;
    this.syncRestoredCallbackTarget();
  }

  /** Removes the stored completion callback. */
  removeCompleteCallback(): void {
    this.completeCallback = undefined;
    this.syncRestoredCallbackTarget();
  }

  /** Sets the default log callback. */
  async setLogCallback(
    callback?: (log: Log, session: MediaInformationSession) => void
  ): Promise<void> {
    const previous = this.logCallback;
    await this.updateCallbackAtomically(
      () => {
        this.logCallback = callback;
      },
      () => {
        this.logCallback = previous;
      }
    );
  }

  /** Removes the stored log callback. */
  async removeLogCallback(): Promise<void> {
    await this.setLogCallback(undefined);
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
    options: ExecuteOptions<MediaInformationSession> = {}
  ): Promise<this> {
    return this.submitOnce(() =>
      this.enqueueSessionExecution(
        () =>
          this.runWithCallbackDemand(
            { log: () => Boolean(options.logCallback ?? this.logCallback) },
            async () => {
              return this.monitor(this, {
                start: () => this.startNativeExecution(this.timeoutMs),
                completeCallback:
                  options.completeCallback ?? this.completeCallback,
                getLogCallback: () => options.logCallback ?? this.logCallback,
                pollIntervalMs: options.pollIntervalMs,
              });
            }
          ),
        () => this.discardBeforeExecution()
      )
    );
  }

  /**
   * Returns parsed media information after successful probing, or `undefined`
   * when the native session has no structured result.
   */
  getMediaInformation(): MediaInformation | undefined {
    const json = NativeFFmpegKitExtended.getMediaInformationJson(
      this.sessionId
    );
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

  /**
   * Wraps an existing valid native FFplay session identity.
   *
   * Normal applications should obtain this wrapper from `FFplayKit` factory,
   * execution, or history APIs. An arbitrary ID does not create a native
   * session and can make playback getters, execution, or controls fail.
   * `timeoutMs` is measured in milliseconds.
   */
  constructor(sessionId: number, command: string, timeoutMs = 500) {
    super(sessionId, command, 'ffplay');
    this.timeoutMs = timeoutMs;
    this.setRestoredCallbackReaders({
      complete: () =>
        this.completeCallback
          ? (session) => this.completeCallback?.(session as FFplaySession)
          : undefined,
      log: () =>
        this.logCallback
          ? (log, session) => this.logCallback?.(log, session as FFplaySession)
          : undefined,
    });
  }

  /** Sets the default completion callback. */
  setCompleteCallback(callback?: (session: FFplaySession) => void): void {
    this.assertRestoredCallbackState();
    this.completeCallback = callback;
    this.syncRestoredCallbackTarget();
  }

  /** Removes the stored completion callback. */
  removeCompleteCallback(): void {
    this.completeCallback = undefined;
    this.syncRestoredCallbackTarget();
  }

  /** Sets the default playback log callback. */
  async setLogCallback(
    callback?: (log: Log, session: FFplaySession) => void
  ): Promise<void> {
    const previous = this.logCallback;
    await this.updateCallbackAtomically(
      () => {
        this.logCallback = callback;
      },
      () => {
        this.logCallback = previous;
      }
    );
  }

  /** Removes the stored log callback. */
  async removeLogCallback(): Promise<void> {
    await this.setLogCallback(undefined);
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
    return this.submitOnce(() =>
      this.enqueueSessionExecution(
        () =>
          this.runWithCallbackDemand(
            { log: () => Boolean(options.logCallback ?? this.logCallback) },
            async () => {
              return this.monitor(this, {
                start: () => this.startNativeExecution(this.timeoutMs),
                completeCallback:
                  options.completeCallback ?? this.completeCallback,
                getLogCallback: () => options.logCallback ?? this.logCallback,
                pollIntervalMs: options.pollIntervalMs,
              });
            }
          ),
        () => this.discardBeforeExecution()
      )
    );
  }

  /** Starts native playback for this session. */
  async start(): Promise<void> {
    await NativeFFmpegKitExtended.ffplayStart(this.sessionId);
  }

  /** Pauses playback while retaining the current position. */
  async pause(): Promise<void> {
    await NativeFFmpegKitExtended.ffplayPause(this.sessionId);
  }

  /** Resumes a paused session. */
  async resume(): Promise<void> {
    await NativeFFmpegKitExtended.ffplayResume(this.sessionId);
  }

  /** Stops playback and drives the session toward completion. */
  async stop(): Promise<void> {
    await NativeFFmpegKitExtended.ffplayStop(this.sessionId);
  }

  /** Seeks relative/according to native FFplay semantics to seconds. */
  async seek(seconds: number): Promise<void> {
    await NativeFFmpegKitExtended.ffplaySeek(this.sessionId, seconds);
  }

  /** Returns the current playback position in seconds. */
  getPosition(): number {
    return NativeFFmpegKitExtended.ffplayGetPosition(this.sessionId);
  }

  /** Sets the playback position in seconds. */
  async setPosition(seconds: number): Promise<void> {
    await NativeFFmpegKitExtended.ffplaySetPosition(this.sessionId, seconds);
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
  async setVolume(volume: number): Promise<void> {
    const clamped = Math.max(0, Math.min(1, volume));
    this.cachedVolume = clamped;
    await NativeFFmpegKitExtended.ffplaySetVolume(this.sessionId, clamped);
  }

  /** Returns normalized volume, using the last set value if native state is unavailable. */
  getVolume(): number {
    const nativeVolume = NativeFFmpegKitExtended.ffplayGetVolume(
      this.sessionId
    );
    if (nativeVolume >= 0) {
      this.cachedVolume = nativeVolume;
    }
    return this.cachedVolume;
  }
}

/**
 * Reconstructs a typed wrapper from retained native history data.
 *
 * Normal application code should prefer the history methods on
 * `FFmpegKitExtended` when possible.
 *
 * @category Advanced / history
 */
export function sessionFromSnapshot(snapshot: SessionSnapshot): Session {
  let session: Session;
  switch (snapshot.type) {
    case 'ffmpeg':
      session = new FFmpegSession(snapshot.sessionId, snapshot.command);
      break;
    case 'ffprobe':
      session = new FFprobeSession(snapshot.sessionId, snapshot.command);
      break;
    case 'ffplay':
      session = new FFplaySession(snapshot.sessionId, snapshot.command);
      break;
    case 'media-information':
      session = new MediaInformationSession(
        snapshot.sessionId,
        snapshot.command
      );
      break;
  }
  if (snapshot.state === SessionState.Running) session.observeRestoredRunning();
  return session;
}

/**
 * Parses one native session snapshot, returning `undefined` for empty input.
 *
 * @category Advanced / history
 */
export function parseSessionJson(json: string): Session | undefined {
  if (!json) return undefined;
  return sessionFromSnapshot(JSON.parse(json) as SessionSnapshot);
}

/**
 * Parses a native array of session snapshots into typed wrappers.
 *
 * @category Advanced / history
 */
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
  return new Promise((resolve) => setTimeout(resolve, ms));
}
