import { getBackend } from './platform/backend-registry';

type CancellationDispatchState = {
  dispatched: boolean;
  inFlight?: Promise<void>;
};

const cancellationDispatches = new Map<number, CancellationDispatchState>();

/**
 * Delivers one durable cancellation request per native session ID.
 *
 * A failed delivery remains retryable: the in-flight marker is cleared, while
 * the successful-dispatch marker is set only after the backend action commits.
 */
export async function dispatchCancellationSerialized(
  sessionId: number
): Promise<void> {
  const state =
    cancellationDispatches.get(sessionId) ??
    ({dispatched: false} satisfies CancellationDispatchState);

  if (state.dispatched) return;
  if (state.inFlight) return state.inFlight;

  const operation = Promise.resolve().then(async () => {
    await getBackend().cancelSession(sessionId);
    state.dispatched = true;
  });
  state.inFlight = operation;
  cancellationDispatches.set(sessionId, state);

  try {
    await operation;
  } finally {
    if (state.inFlight === operation) state.inFlight = undefined;
  }
}

/** Removes retry bookkeeping after authoritative terminal cleanup. */
export function clearCancellationDispatch(sessionId: number): void {
  cancellationDispatches.delete(sessionId);
}

/** Removes all retry bookkeeping after a successful global clear. */
export function clearAllCancellationDispatches(): void {
  cancellationDispatches.clear();
}
