import { SessionState } from './types';
import { releaseSessionHandleSerialized } from './session-lifetime';

export interface RestoredSessionObservationTarget {
  readonly sessionId: number;
  getState(): SessionState;
  pollRestoredCallbacks(): Promise<void>;
  settleRestoredObservation(): Promise<void>;
  releaseRestoredHandle(): Promise<void>;
  invalidateRestoredObservation(): Promise<void>;
  reportRestoredObserverError(error: unknown): void;
}

type ObservationEntry = {
  readonly sessionId: number;
  readonly targets: Set<RestoredSessionObservationTarget>;
  invalidated: boolean;
  terminalSettled: boolean;
  run?: Promise<void>;
};

const POLL_INTERVAL_MS = 50;

/** One non-executing terminal observer per restored native session ID. */
export class RestoredSessionObservationCoordinator {
  private readonly entries = new Map<number, ObservationEntry>();

  observe(target: RestoredSessionObservationTarget): void {
    let entry = this.entries.get(target.sessionId);
    if (!entry) {
      entry = {
        sessionId: target.sessionId,
        targets: new Set(),
        invalidated: false,
        terminalSettled: false,
      };
      this.entries.set(target.sessionId, entry);
    }
    entry.targets.add(target);
    if (!entry.run) {
      entry.run = this.run(entry);
    }
  }

  /** Stops all restored observers after a successful backend-wide clear. */
  async invalidateAll(): Promise<void> {
    const entries = [...this.entries.values()];
    this.entries.clear();
    await Promise.all(
      entries.map(async (entry) => {
        entry.invalidated = true;
        await Promise.all(
          [...entry.targets].map((target) =>
            target.invalidateRestoredObservation()
          )
        );
      })
    );
  }

  get size(): number {
    return this.entries.size;
  }

  private async run(entry: ObservationEntry): Promise<void> {
    for (;;) {
      if (entry.invalidated || this.entries.get(entry.sessionId) !== entry)
        return;
      const target = [...entry.targets][0];
      if (!target) {
        this.entries.delete(entry.sessionId);
        return;
      }

      let state: SessionState;
      try {
        state = target.getState();
      } catch (error) {
        for (const observer of entry.targets)
          observer.reportRestoredObserverError(error);
        await sleep(POLL_INTERVAL_MS);
        continue;
      }

      if (state === SessionState.Completed || state === SessionState.Failed) {
        if (!entry.terminalSettled) {
          entry.terminalSettled = true;
          for (const observer of entry.targets) {
            try {
              await observer.settleRestoredObservation();
            } catch (error) {
              observer.reportRestoredObserverError(error);
            }
          }
        }
        try {
          await releaseSessionHandleSerialized(entry.sessionId);
          this.entries.delete(entry.sessionId);
          return;
        } catch (error) {
          for (const observer of entry.targets)
            observer.reportRestoredObserverError(error);
          await sleep(POLL_INTERVAL_MS);
          continue;
        }
      }

      if (state === SessionState.Running) {
        for (const observer of entry.targets) {
          try {
            await observer.pollRestoredCallbacks();
          } catch (error) {
            observer.reportRestoredObserverError(error);
          }
        }
      }
      await sleep(POLL_INTERVAL_MS);
    }
  }
}

export const restoredSessionObserver =
  new RestoredSessionObservationCoordinator();

function sleep(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
