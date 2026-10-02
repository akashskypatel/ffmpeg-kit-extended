import { getBackend } from './platform/backend-registry';
import { SessionQueueManager } from './session-queue-manager';
import {
  clearCancellationDispatch,
  dispatchCancellationSerialized,
} from './session-cancellation';
import { releaseSessionHandleSerialized } from './session-lifetime';
import { SessionState } from './types';

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
  readonly callbackTargets: Set<RestoredSessionObservationTarget>;
  invalidated: boolean;
  terminalSettled: boolean;
  run?: Promise<void>;
};

const POLL_INTERVAL_MS = 50;

/** One non-executing terminal observer per restored native session ID. */
export class RestoredSessionObservationCoordinator {
  private readonly entries = new Map<number, ObservationEntry>();

  /** Ensures one lightweight lifetime observer exists for a native ID. */
  ensureObserved(sessionId: number): void {
    const entry = this.getOrCreateEntry(sessionId);
    if (!entry.run) entry.run = this.run(entry);
  }

  /** Retains a wrapper only while it owns a restored callback sink. */
  attachCallbackTarget(
    sessionId: number,
    target: RestoredSessionObservationTarget
  ): void {
    if (target.sessionId !== sessionId) {
      throw new Error(
        `Restored callback target ${target.sessionId} does not match ${sessionId}`
      );
    }
    const entry = this.getOrCreateEntry(sessionId);
    entry.callbackTargets.add(target);
    if (!entry.run) entry.run = this.run(entry);
  }

  /** Drops a wrapper target without stopping the ID-level lifetime observer. */
  detachCallbackTarget(
    sessionId: number,
    target: RestoredSessionObservationTarget
  ): void {
    this.entries.get(sessionId)?.callbackTargets.delete(target);
  }

  /** Internal test seam for bounded target-retention assertions. */
  getTargetCount(sessionId: number): number {
    return this.entries.get(sessionId)?.callbackTargets.size ?? 0;
  }

  /** Stops all restored observers after a successful backend-wide clear. */
  async invalidateAll(): Promise<void> {
    const entries = [...this.entries.values()];
    this.entries.clear();
    await Promise.all(
      entries.map(async (entry) => {
        entry.invalidated = true;
        const targets = [...entry.callbackTargets];
        entry.callbackTargets.clear();
        await Promise.all(
          targets.map((target) => target.invalidateRestoredObservation())
        );
      })
    );
  }

  get size(): number {
    return this.entries.size;
  }

  private getOrCreateEntry(sessionId: number): ObservationEntry {
    let entry = this.entries.get(sessionId);
    if (!entry) {
      entry = {
        sessionId,
        callbackTargets: new Set(),
        invalidated: false,
        terminalSettled: false,
      };
      this.entries.set(sessionId, entry);
    }
    return entry;
  }

  private async run(entry: ObservationEntry): Promise<void> {
    for (;;) {
      if (entry.invalidated || this.entries.get(entry.sessionId) !== entry)
        return;

      let state: SessionState;
      try {
        state = getBackend().getSessionState(entry.sessionId) as SessionState;
      } catch (error) {
        this.reportTargets(entry, error);
        await sleep(POLL_INTERVAL_MS);
        continue;
      }

      if (state === SessionState.Completed || state === SessionState.Failed) {
        await this.settleTerminalEntry(entry);
        return;
      }

      if (state === SessionState.Running) {
        try {
          if (getBackend().isCancellationRequested?.(entry.sessionId)) {
            await dispatchCancellationSerialized(entry.sessionId);
          }
        } catch (error) {
          // Keep durable intent and retry on the next Running observation.
          this.reportTargets(entry, error);
        }

        for (const target of [...entry.callbackTargets]) {
          try {
            await target.pollRestoredCallbacks();
          } catch (error) {
            this.reportTargetIfAttached(entry, target, error);
          }
        }
      }
      await sleep(POLL_INTERVAL_MS);
    }
  }

  private async settleTerminalEntry(entry: ObservationEntry): Promise<void> {
    if (!entry.terminalSettled) {
      entry.terminalSettled = true;
      for (const target of [...entry.callbackTargets]) {
        try {
          await target.settleRestoredObservation();
        } catch (error) {
          this.reportTargetIfAttached(entry, target, error);
        } finally {
          entry.callbackTargets.delete(target);
        }
      }
    }

    try {
      getBackend().clearCancellationIntent?.(entry.sessionId);
    } catch (error) {
      this.reportTargets(entry, error);
    }
    clearCancellationDispatch(entry.sessionId);

    // An active executor gets the first final-release attempt, but this
    // restored observation remains the fallback authority until that owner
    // settles. Release retries are iterative so one entry stays O(1) in
    // memory until retirement commits or a successful clear invalidates it.
    while (
      !entry.invalidated &&
      this.entries.get(entry.sessionId) === entry
    ) {
      if (SessionQueueManager.shared.isSessionActiveById(entry.sessionId)) {
        await sleep(POLL_INTERVAL_MS);
        continue;
      }

      try {
        await releaseSessionHandleSerialized(entry.sessionId);
        if (this.entries.get(entry.sessionId) === entry)
          this.entries.delete(entry.sessionId);
        return;
      } catch (error) {
        this.reportTargets(entry, error);
      await sleep(POLL_INTERVAL_MS);
      }
    }
  }

  private reportTargets(entry: ObservationEntry, error: unknown): void {
    for (const target of entry.callbackTargets)
      target.reportRestoredObserverError(error);
  }

  private reportTargetIfAttached(
    entry: ObservationEntry,
    target: RestoredSessionObservationTarget,
    error: unknown
  ): void {
    if (entry.callbackTargets.has(target))
      target.reportRestoredObserverError(error);
  }
}

export const restoredSessionObserver =
  new RestoredSessionObservationCoordinator();

function sleep(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
