/** Owns Wasm session pointers without exposing pointers as public IDs. */
export class WasmSessionRegistry {
  private readonly retained = new Map<number, number>();

  retain(pointer: number, sessionId: number): void {
    if (!pointer || !sessionId) throw new Error('Wasm returned an invalid session handle');
    this.retained.set(sessionId, pointer);
  }

  get(sessionId: number): number | undefined {
    return this.retained.get(sessionId);
  }

  take(sessionId: number): number | undefined {
    const pointer = this.retained.get(sessionId);
    this.retained.delete(sessionId);
    return pointer;
  }

  has(sessionId: number): boolean {
    return this.retained.has(sessionId);
  }

  clear(): number[] {
    const pointers = [...this.retained.values()];
    this.retained.clear();
    return pointers;
  }

  get size(): number {
    return this.retained.size;
  }
}
