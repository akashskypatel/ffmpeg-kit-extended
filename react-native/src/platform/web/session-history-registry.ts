export type SessionHistoryType =
  | 'ffmpeg'
  | 'ffprobe'
  | 'ffplay'
  | 'media-information';

export type SessionHistoryRecord = {
  readonly sessionId: number;
  readonly type: SessionHistoryType;
  readonly creationOrder: number;
  visible: boolean;
  terminal: boolean;
};

/**
 * Native-history identity metadata for the Web backend.
 *
 * The registry never owns a Wasm pointer. Active pointer ownership remains in
 * WasmSessionRegistry, while Created and terminal snapshots borrow temporary
 * pointers for one read.
 */
export class SessionHistoryRegistry {
  private readonly recordsById = new Map<number, SessionHistoryRecord>();
  private readonly abandonedCreatedIds = new Set<number>();
  private readonly cancellationIntentIds = new Set<number>();
  private nextCreationOrder = 0;
  private capacity = -1;

  record(sessionId: number, type: SessionHistoryType): void {
    if (this.abandonedCreatedIds.has(sessionId)) return;
    if (this.recordsById.has(sessionId)) return;
    this.recordsById.set(sessionId, {
      sessionId,
      type,
      creationOrder: this.nextCreationOrder++,
      visible: true,
      terminal: false,
    });
  }

  markTerminal(sessionId: number): void {
    const record = this.recordsById.get(sessionId);
    if (record) record.terminal = true;
    this.pruneTerminal();
  }

  removeNonTerminal(sessionId: number): void {
    const record = this.recordsById.get(sessionId);
    if (record && !record.terminal) this.recordsById.delete(sessionId);
  }

  /** Removes a Created identity explicitly abandoned before execution. */
  abandonCreated(sessionId: number): boolean {
    const record = this.recordsById.get(sessionId);
    if (record?.terminal || this.abandonedCreatedIds.has(sessionId)) return false;
    this.abandonedCreatedIds.add(sessionId);
    this.removeNonTerminal(sessionId);
    return true;
  }

  isAbandoned(sessionId: number): boolean {
    return this.abandonedCreatedIds.has(sessionId);
  }

  recordCancellationIntent(sessionId: number): void {
    this.cancellationIntentIds.add(sessionId);
  }

  isCancellationRequested(sessionId: number): boolean {
    return this.cancellationIntentIds.has(sessionId);
  }

  clearCancellationIntent(sessionId: number): void {
    this.cancellationIntentIds.delete(sessionId);
  }

  /** Returns a bounded maintenance snapshot of Created tombstone IDs. */
  abandonedIds(): number[] {
    return [...this.abandonedCreatedIds];
  }

  /** Removes a tombstone only after an independent native absence proof. */
  removeAbandoned(sessionId: number): void {
    this.abandonedCreatedIds.delete(sessionId);
  }

  setCapacity(capacity: number): void {
    this.capacity = capacity;
    this.pruneTerminal();
  }

  entries(kind?: SessionHistoryType): SessionHistoryRecord[] {
    return [...this.recordsById.values()]
      .filter(record => record.visible && (!kind || record.type === kind))
      .sort((left, right) => left.creationOrder - right.creationOrder);
  }

  remove(sessionId: number): void {
    this.recordsById.delete(sessionId);
    this.abandonedCreatedIds.delete(sessionId);
    this.cancellationIntentIds.delete(sessionId);
  }

  clear(): void {
    this.recordsById.clear();
    this.abandonedCreatedIds.clear();
    this.cancellationIntentIds.clear();
    this.nextCreationOrder = 0;
  }

  get size(): number {
    return this.recordsById.size;
  }

  private pruneTerminal(): void {
    if (this.capacity < 0) return;
    const terminal = [...this.recordsById.values()]
      .filter(record => record.visible && record.terminal)
      .sort((left, right) => left.creationOrder - right.creationOrder);
    const removeCount = terminal.length - this.capacity;
    for (const record of terminal.slice(0, Math.max(0, removeCount))) {
      this.recordsById.delete(record.sessionId);
    }
  }
}
