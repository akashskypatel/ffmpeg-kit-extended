/**
 * Owns exported Wasm session handles whose native release is still
 * outstanding. Created-state handles are normally released immediately;
 * active execution handles remain retained through terminal monitoring.
 */
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

  entries(): Array<[number, number]> {
    return [...this.retained.entries()];
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
