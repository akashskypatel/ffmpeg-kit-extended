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

  record(sessionId: number, type: SessionHistoryType): void {
    if (this.recordsById.has(sessionId)) return;
    this.recordsById.set(sessionId, {
      sessionId,
      type,
      creationOrder: this.nextCreationOrder++,
      visible: true,
    });
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
}
