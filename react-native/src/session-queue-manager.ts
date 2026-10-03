/**
 * Rejection used when a session is removed from the JavaScript queue before its
 * native executor starts.
 */
export class SessionCancelledException extends Error {
  constructor(message = 'Session was removed from queue') {
    super(message);
    this.name = 'SessionCancelledException';
  }
}

type CancellableSession = {
  cancel(): void | Promise<void>;
  markCancelledBeforeExecution?: () => void;
  getSessionId?: () => number;
  prepareForExecution?: () => void;
};

type QueueItem<T> = {
  session: CancellableSession;
  executor: () => Promise<T>;
  resolve: (value: T) => void;
  reject: (reason?: unknown) => void;
  onDiscard?: () => void | Promise<void>;
};

type MaybePromise<T> = T | Promise<T>;

/**
 * Process-wide JavaScript queue that limits concurrent native sessions.
 *
 * `FFmpegSession`, `FFprobeSession`, `MediaInformationSession`, and
 * `FFplaySession` all use the shared instance. The default concurrency is 8.
 * Lower the limit for memory-constrained devices or workloads that saturate
 * storage, CPU, GPU, or network resources.
 */
export class SessionQueueManager {
  private static readonly instance = new SessionQueueManager();

  /** Singleton used by all high-level execution APIs. */
  static get shared(): SessionQueueManager {
    return this.instance;
  }

  private maxConcurrent = 8;
  private readonly active = new Set<CancellableSession>();
  private readonly queue: Array<QueueItem<unknown>> = [];
  private readonly reservedSessionIds = new Set<number>();

  /** Snapshot of sessions whose executors have started and not settled. */
  get activeSessions(): CancellableSession[] {
    return [...this.active];
  }

  /** Number of currently active session executors. */
  get activeSessionCount(): number {
    return this.active.size;
  }

  /** Number of sessions waiting for a concurrency slot. */
  get queueLength(): number {
    return this.queue.length;
  }

  /** Whether at least one session is actively executing. */
  get isBusy(): boolean {
    return this.active.size > 0;
  }

  /** Maximum number of active sessions permitted at once. */
  get maxConcurrentSessions(): number {
    return this.maxConcurrent;
  }

  /**
   * Sets the concurrency limit and immediately starts queued work when the
   * larger limit creates capacity.
   *
   * @throws `Error` unless `value` is an integer of at least 1.
   */
  set maxConcurrentSessions(value: number) {
    if (!Number.isInteger(value) || value < 1) {
      throw new Error('maxConcurrentSessions must be an integer of at least 1');
    }
    this.maxConcurrent = value;
    this.processQueue();
  }

  /**
   * Enqueues a session executor and resolves/rejects with that executor.
   *
   * Application code normally calls `session.executeAsync()` instead of this
   * lower-level method.
   */
  executeSession<T>(
    session: CancellableSession,
    executor: () => Promise<T>,
    onDiscard?: () => void
  ): Promise<T> {
    const sessionId = this.executionSessionId(session);
    if (
      this.active.has(session) ||
      this.queue.some((item) => item.session === session) ||
      (sessionId !== undefined && this.reservedSessionIds.has(sessionId))
    ) {
      return Promise.reject(
        new Error(
          sessionId === undefined
            ? 'Session is already queued or active'
            : `Session ${sessionId} is already queued or active`
        )
      );
    }

    if (sessionId !== undefined) this.reservedSessionIds.add(sessionId);
    return new Promise<T>((resolve, reject) => {
      this.queue.push({
        session,
        executor,
        resolve,
        reject,
        onDiscard,
      } as QueueItem<unknown>);
      try {
        this.processQueue();
      } catch (error) {
        // processQueue normalizes executor failures, but retain a defensive
        // rollback for an unexpected queue-internal exception.
        this.releaseSessionReservation(sessionId);
        reject(error);
      }
    });
  }

  /**
   * Requests cancellation of every currently active session.
   *
   * A single native cancellation failure must not prevent the remaining active
   * sessions from receiving the request. Preserve the first failure so callers
   * still receive deterministic error authority after all attempts complete.
   */
  cancelCurrent(): MaybePromise<void> {
    let firstError: unknown;
    const pending: Promise<void>[] = [];
    for (const session of [...this.active]) {
      try {
        const cancellation = session.cancel();
        if (cancellation instanceof Promise) {
          pending.push(
            cancellation.catch((error) => {
              if (firstError === undefined) firstError = error;
            })
          );
        }
      } catch (error) {
        if (firstError === undefined) firstError = error;
      }
    }
    if (pending.length === 0) {
      if (firstError !== undefined) throw firstError;
      return;
    }
    return Promise.all(pending).then(() => {
      if (firstError !== undefined) throw firstError;
    });
  }

  /**
   * Removes all waiting sessions and rejects their promises with
   * `SessionCancelledException`, or with a discard cleanup error when cleanup
   * fails. Active sessions continue running.
   */
  clearQueue(): MaybePromise<void> {
    const pending = this.queue.splice(0);
    const discards = pending
      .map((item) => this.discard(item))
      .filter(
        (discard): discard is Promise<void> => discard instanceof Promise
      );
    if (discards.length === 0) return;
    return Promise.all(discards).then(() => undefined);
  }

  /** Clears waiting sessions and requests cancellation of active sessions. */
  cancelAll(): MaybePromise<void> {
    let firstError: unknown;
    const pending: Promise<void>[] = [];

    try {
      const cleared = this.clearQueue();
      if (cleared instanceof Promise) {
        pending.push(
          cleared.catch((error) => {
            if (firstError === undefined) firstError = error;
          })
        );
      }
    } catch (error) {
      firstError = error;
    }

    try {
      const cancelled = this.cancelCurrent();
      if (cancelled instanceof Promise) {
        pending.push(
          cancelled.catch((error) => {
            if (firstError === undefined) firstError = error;
          })
        );
      }
    } catch (error) {
      if (firstError === undefined) firstError = error;
    }

    if (pending.length === 0) {
      if (firstError !== undefined) throw firstError;
      return;
    }
    return Promise.all(pending).then(() => {
      if (firstError !== undefined) throw firstError;
    });
  }

  /** Removes one waiting session and rejects its execution promise. */
  cancelQueued(session: CancellableSession): MaybePromise<boolean> {
    const index = this.queue.findIndex((item) => item.session === session);
    if (index < 0) return false;
    const [item] = this.queue.splice(index, 1);
    if (!item) return false;
    const discarded = this.discard(item);
    if (discarded instanceof Promise) return discarded.then(() => true);
    return true;
  }

  /** Finds a queued or active session by its process-wide native ID. */
  findManagedSessionById(sessionId: number): CancellableSession | undefined {
    for (const session of this.active) {
      if (this.executionSessionId(session) === sessionId) return session;
    }
    return this.queue.find(
      (item) => this.executionSessionId(item.session) === sessionId
    )?.session;
  }

  /** Whether an executor is active for the requested native session ID. */
  isSessionActiveById(sessionId: number): boolean {
    for (const session of this.active) {
      if (this.executionSessionId(session) === sessionId) return true;
    }
    return false;
  }

  /** Cancels the managed session with the requested ID through its object API. */
  cancelBySessionId(sessionId: number): MaybePromise<boolean> {
    const session = this.findManagedSessionById(sessionId);
    if (!session) return false;
    const cancellation = session.cancel();
    if (cancellation instanceof Promise) return cancellation.then(() => true);
    return true;
  }

  /** Resolves after both the active set and pending queue become empty. */
  async waitForAll(): Promise<void> {
    while (this.isBusy || this.queue.length > 0) {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
  }

  private discard(item: QueueItem<unknown>): MaybePromise<void> {
    const rejection = new SessionCancelledException();
    const finish = (): void => {
      this.releaseSessionReservation(this.executionSessionId(item.session));
      item.reject(rejection);
    };
    try {
      item.session.markCancelledBeforeExecution?.();
      const cleanup = item.onDiscard?.();
      if (cleanup instanceof Promise) {
        return cleanup.then(finish, (error) => {
          console.warn('Session queue discard cleanup failed', error);
          finish();
        });
      }
    } catch (error) {
      // Cancellation is the primary queue outcome. Metadata cleanup is a
      // secondary diagnostic and must not strand later queue reservations.
      console.warn('Session queue discard cleanup failed', error);
    }
    finish();
  }

  private executionSessionId(session: CancellableSession): number | undefined {
    const value = session.getSessionId?.();
    return typeof value === 'number' && Number.isFinite(value)
      ? value
      : undefined;
  }

  private releaseSessionReservation(sessionId: number | undefined): void {
    if (sessionId !== undefined) this.reservedSessionIds.delete(sessionId);
  }

  private processQueue(): void {
    while (this.queue.length > 0 && this.active.size < this.maxConcurrent) {
      const item = this.queue.shift();
      if (!item) return;
      try {
        item.session.prepareForExecution?.();
      } catch (error) {
        void this.rejectPreparationFailure(item, error);
        continue;
      }

      this.active.add(item.session);
      let execution: Promise<unknown>;
      try {
        execution = Promise.resolve(item.executor());
      } catch (error) {
        execution = Promise.reject(error);
      }
      execution.then(
        (value) => {
          this.completeActiveItem(item);
          item.resolve(value);
        },
        (error) => {
          this.completeActiveItem(item);
          item.reject(error);
        }
      );
    }
  }

  /**
   * Rejects a race-time handoff validation failure without treating it as an
   * explicit queued discard. The native identity may already be Running or
   * terminal, so only the JavaScript reservation is released here.
   */
  private rejectPreparationFailure(
    item: QueueItem<unknown>,
    primaryError: unknown
  ): MaybePromise<void> {
    this.releaseSessionReservation(this.executionSessionId(item.session));
    item.reject(primaryError);
  }

  private completeActiveItem(item: QueueItem<unknown>): void {
    this.active.delete(item.session);
    this.releaseSessionReservation(this.executionSessionId(item.session));
    this.processQueue();
  }
}
