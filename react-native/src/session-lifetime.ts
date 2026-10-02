import { getBackend } from './platform/backend-registry';

const releasesInFlight = new Map<number, Promise<void>>();

/** Internal diagnostic seam for bounded lifecycle tests. */
export function getRetainedReleaseInFlightCount(): number {
  return releasesInFlight.size;
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
