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
  private nextCreationOrder = 0;
  private capacity = -1;

  record(sessionId: number, type: SessionHistoryType): void {
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
  }

  clear(): void {
    this.recordsById.clear();
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
