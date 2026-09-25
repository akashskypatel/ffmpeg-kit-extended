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
  onDiscard?: () => void;
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
    onDiscard?: () => void,
  ): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      this.queue.push({
        session,
        executor,
        resolve,
        reject,
        onDiscard,
      } as QueueItem<unknown>);
      this.processQueue();
    });
  }

  /**
   * Requests cancellation of every currently active session.
   *
   * A single native cancellation failure must not prevent the remaining active
   * sessions from receiving the request. Preserve the first failure so callers
   * still receive deterministic error authority after all attempts complete.
   */
  cancelCurrent(): void {
    let firstError: unknown;
    for (const session of [...this.active]) {
      try {
        session.cancel();
      } catch (error) {
        if (firstError === undefined) firstError = error;
      }
    }
    if (firstError !== undefined) throw firstError;
  }

  /**
   * Removes all waiting sessions and rejects their promises with
   * `SessionCancelledException`, or with a discard cleanup error when cleanup
   * fails. Active sessions continue running.
   */
  clearQueue(): void {
    const pending = this.queue.splice(0);
    for (const item of pending) this.discard(item);
  }

  /** Clears waiting sessions and requests cancellation of active sessions. */
  cancelAll(): void {
    this.clearQueue();
    this.cancelCurrent();
  }

  /** Removes one waiting session and rejects its execution promise. */
  cancelQueued(session: CancellableSession): boolean {
    const index = this.queue.findIndex(item => item.session === session);
    if (index < 0) return false;
    const [item] = this.queue.splice(index, 1);
    if (!item) return false;
    this.discard(item);
    return true;
  }

  /** Resolves after both the active set and pending queue become empty. */
  async waitForAll(): Promise<void> {
    while (this.isBusy || this.queue.length > 0) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }
  }

  private discard(item: QueueItem<unknown>): void {
    let rejection: unknown = new SessionCancelledException();
    try {
      item.onDiscard?.();
    } catch (error) {
      rejection = error;
    }
    item.reject(rejection);
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
