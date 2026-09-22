/**
 * Process-wide ownership for callback delivery in the React Native wrapper.
 *
 * The native log/statistics callbacks are process-global, so a session must
 * never uninstall one merely because its own consumer went away. Each active
 * consumer owns an idempotent lease and the first/last lease transitions own
 * bridge installation and removal.
 *
 * The current React Native monitor uses the backend's buffered transport. Its
 * install/uninstall hooks are therefore optional seams for the v2 event bridge;
 * they deliberately do not toggle native redirection. G61/G62 provide the
 * concrete direct-payload hooks without changing this ownership authority.
 */

export type CallbackDemandKind = 'completion' | 'log' | 'statistics';

export interface CallbackDemandHooks {
  install: () => void;
  uninstall: () => void;
}

type DemandState = {
  count: number;
  uninstall?: () => void;
};

/** An idempotent lease on one process-wide callback demand class. */
export class CallbackDemandLease {
  private released = false;

  constructor(private readonly releaseCallback: () => void) {}

  /** Releases this lease once; repeated calls are harmless. */
  release(): void {
    if (this.released) return;
    this.released = true;
    this.releaseCallback();
  }
}

/** Shared callback-demand/refcount authority used by all RN sessions. */
export class CallbackDemandAuthority {
  private readonly states: Record<CallbackDemandKind, DemandState> = {
    completion: {count: 0},
    log: {count: 0},
    statistics: {count: 0},
  };

  /** Returns the current number of owners for a callback class. */
  leaseCount(kind: CallbackDemandKind): number {
    return this.states[kind].count;
  }

  /** Returns whether the callback class currently has any demand. */
  isActive(kind: CallbackDemandKind): boolean {
    return this.leaseCount(kind) > 0;
  }

  /**
   * Acquires one callback-demand lease.
   *
   * Installation runs only for the first owner. If it throws, ownership is
   * unchanged so a caller can retry without a stale refcount.
   */
  acquire(
    kind: CallbackDemandKind,
    hooks: CallbackDemandHooks = {install: () => {}, uninstall: () => {}},
  ): CallbackDemandLease {
    const state = this.states[kind];
    if (state.count === 0) {
      hooks.install();
      state.uninstall = hooks.uninstall;
    }
    state.count += 1;
    return new CallbackDemandLease(() => this.release(kind));
  }

  /**
   * Releases one class owner. The count is reset before uninstall, including
   * when uninstall throws, so a failed cleanup cannot corrupt later ownership.
   */
  private release(kind: CallbackDemandKind): void {
    const state = this.states[kind];
    if (state.count === 0) return;
    state.count -= 1;
    if (state.count !== 0) return;

    const uninstall = state.uninstall;
    state.uninstall = undefined;
    uninstall?.();
  }
}

/** Process-wide authority shared by native and Web React Native sessions. */
export const callbackDemandAuthority = new CallbackDemandAuthority();
