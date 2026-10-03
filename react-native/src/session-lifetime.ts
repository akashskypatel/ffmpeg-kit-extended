import { getBackend } from './platform/backend-registry';

const releasesInFlight = new Map<number, Promise<void>>();
const retainedReleaseRetries = new Map<number, Promise<void>>();
const RETAINED_RELEASE_RETRY_DELAY_MS = 50;

/** Internal diagnostic seam for bounded lifecycle tests. */
export function getRetainedReleaseInFlightCount(): number {
  return releasesInFlight.size;
}

/** Internal diagnostic seam for bounded lifecycle tests. */
export function getRetainedReleaseRetryCount(): number {
  return retainedReleaseRetries.size;
}

/**
 * Serializes retained-handle release by native session ID. Execution monitors
 * and restored history observers share this authority so one wrapper cannot
 * race another wrapper's release transaction.
 */
export async function releaseSessionHandleSerialized(
  sessionId: number
): Promise<void> {
  const existing = releasesInFlight.get(sessionId);
  if (existing) return existing;

  const release = Promise.resolve().then(() =>
    getBackend().releaseSessionHandle(sessionId)
  );
  releasesInFlight.set(sessionId, release);
  try {
    await release;
  } finally {
    if (releasesInFlight.get(sessionId) === release)
      releasesInFlight.delete(sessionId);
  }
}

/**
 * Keeps one release authority alive after a semantically safe release attempt
 * fails. The coordinator retains only the native ID, never a Session wrapper.
 */
export function ensureRetainedReleaseRetry(sessionId: number): void {
  if (retainedReleaseRetries.has(sessionId)) return;

  let retry!: Promise<void>;
  retry = (async () => {
    for (;;) {
      try {
        await releaseSessionHandleSerialized(sessionId);
        return;
      } catch {
        await sleep(RETAINED_RELEASE_RETRY_DELAY_MS);
      }
    }
  })();
  retainedReleaseRetries.set(sessionId, retry);
  void retry.then(
    () => {
      if (retainedReleaseRetries.get(sessionId) === retry)
        retainedReleaseRetries.delete(sessionId);
    },
    () => {
      if (retainedReleaseRetries.get(sessionId) === retry)
        retainedReleaseRetries.delete(sessionId);
    }
  );
}

function sleep(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
