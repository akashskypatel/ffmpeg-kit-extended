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

type CancellableSession = {cancel(): void};

type QueueItem<T> = {
  session: CancellableSession;
  executor: () => Promise<T>;
  resolve: (value: T) => void;
  reject: (reason?: unknown) => void;
};

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
  ): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      this.queue.push({
        session,
        executor,
        resolve,
        reject,
      } as QueueItem<unknown>);
      this.processQueue();
    });
  }

  /** Requests cancellation of every currently active session. */
  cancelCurrent(): void {
    for (const session of [...this.active]) session.cancel();
  }

  /**
   * Removes all waiting sessions and rejects their promises with
   * `SessionCancelledException`. Active sessions continue running.
   */
  clearQueue(): void {
    const pending = this.queue.splice(0);
    for (const item of pending) {
      item.reject(new SessionCancelledException());
    }
  }

  /** Clears waiting sessions and requests cancellation of active sessions. */
  cancelAll(): void {
    this.clearQueue();
    this.cancelCurrent();
  }

  /** Resolves after both the active set and pending queue become empty. */
  async waitForAll(): Promise<void> {
    while (this.isBusy || this.queue.length > 0) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }
  }

  private processQueue(): void {
    while (this.queue.length > 0 && this.active.size < this.maxConcurrent) {
      const item = this.queue.shift();
      if (!item) return;
      this.active.add(item.session);
      item
        .executor()
        .then(item.resolve, item.reject)
        .finally(() => {
          this.active.delete(item.session);
          this.processQueue();
        });
    }
  }
}
