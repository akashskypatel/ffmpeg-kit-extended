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

export class SessionQueueManager {
  private static readonly instance = new SessionQueueManager();

  static get shared(): SessionQueueManager {
    return this.instance;
  }

  private maxConcurrent = 8;
  private readonly active = new Set<CancellableSession>();
  private readonly queue: Array<QueueItem<unknown>> = [];

  get activeSessions(): CancellableSession[] {
    return [...this.active];
  }

  get activeSessionCount(): number {
    return this.active.size;
  }

  get queueLength(): number {
    return this.queue.length;
  }

  get isBusy(): boolean {
    return this.active.size > 0;
  }

  get maxConcurrentSessions(): number {
    return this.maxConcurrent;
  }

  set maxConcurrentSessions(value: number) {
    if (!Number.isInteger(value) || value < 1) {
      throw new Error('maxConcurrentSessions must be an integer of at least 1');
    }
    this.maxConcurrent = value;
    this.processQueue();
  }

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

  cancelCurrent(): void {
    for (const session of [...this.active]) session.cancel();
  }

  clearQueue(): void {
    const pending = this.queue.splice(0);
    for (const item of pending) {
      item.reject(new SessionCancelledException());
    }
  }

  cancelAll(): void {
    this.clearQueue();
    this.cancelCurrent();
  }

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
