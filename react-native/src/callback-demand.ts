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
 * they deliberately do not toggle native redirection. Direct-payload hooks
 * remain separate seams without changing this ownership authority.
 */

export type CallbackDemandKind = 'completion' | 'log' | 'statistics';

export interface CallbackDemandHooks {
  install: () => void | Promise<void>;
  uninstall: () => void | Promise<void>;
}

type DemandState = {
  count: number;
  uninstall?: () => void | Promise<void>;
  transition: Promise<void>;
  pending: boolean;
};

type MaybePromise<T> = T | Promise<T>;

/** An idempotent lease on one process-wide callback demand class. */
export class CallbackDemandLease {
  private released = false;
  private releasePromise?: Promise<void>;

  constructor(private readonly releaseCallback: () => Promise<void>) {}

  /** Releases this lease once; repeated calls are harmless. */
  release(): Promise<void> {
    if (this.released) return this.releasePromise ?? Promise.resolve();
    this.released = true;
    this.releasePromise = this.releaseCallback();
    return this.releasePromise;
  }
}

/** Shared callback-demand/refcount authority used by all RN sessions. */
export class CallbackDemandAuthority {
  private readonly states: Record<CallbackDemandKind, DemandState> = {
    completion: {count: 0, transition: Promise.resolve(), pending: false},
    log: {count: 0, transition: Promise.resolve(), pending: false},
    statistics: {count: 0, transition: Promise.resolve(), pending: false},
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
  ): MaybePromise<CallbackDemandLease> {
    const state = this.states[kind];
    if (state.pending) {
      return this.enqueue(kind, async () => {
        if (state.count === 0) {
          await hooks.install();
          state.uninstall = hooks.uninstall;
        }
        state.count += 1;
      }).then(() => new CallbackDemandLease(() => this.release(kind)));
    }
    try {
      const installation = state.count === 0 ? hooks.install() : undefined;
      if (installation && typeof installation.then === 'function') {
        return this.enqueue(kind, async () => {
          await installation;
          state.uninstall = hooks.uninstall;
          state.count += 1;
        }).then(() => new CallbackDemandLease(() => this.release(kind)));
      }
      if (state.count === 0) state.uninstall = hooks.uninstall;
      state.count += 1;
      return new CallbackDemandLease(() => this.release(kind));
    } catch (error) {
      return Promise.reject(error);
    }
  }

  /**
   * Releases one class owner. The count is reset before uninstall, including
   * when uninstall throws, so a failed cleanup cannot corrupt later ownership.
   */
  private release(kind: CallbackDemandKind): Promise<void> {
    const state = this.states[kind];
    return this.enqueue(kind, async () => {
      if (state.count === 0) return;
      state.count -= 1;
      if (state.count !== 0) return;

      const uninstall = state.uninstall;
      state.uninstall = undefined;
      await uninstall?.();
    });
  }

  private enqueue(
    kind: CallbackDemandKind,
    action: () => Promise<void>,
  ): Promise<void> {
    const state = this.states[kind];
    const transition = state.transition.then(action, action);
    const recovered = transition.catch(() => {});
    state.pending = true;
    state.transition = recovered;
    void recovered.finally(() => {
      if (state.transition === recovered) state.pending = false;
    });
    return transition;
  }
}

/** Process-wide authority shared by native and Web React Native sessions. */
export const callbackDemandAuthority = new CallbackDemandAuthority();
