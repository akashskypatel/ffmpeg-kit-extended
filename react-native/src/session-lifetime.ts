import { getBackend } from './platform/backend-registry';

const releasesInFlight = new Map<number, Promise<void>>();
const releasesCompleted = new Set<number>();

/** Starts a new wrapper ownership epoch when a test or backend creates a new ID. */
export function registerSessionWrapper(sessionId: number): void {
  if (releasesCompleted.has(sessionId)) releasesCompleted.delete(sessionId);
}

/**
 * Serializes retained-handle release by native session ID. Execution monitors
 * and restored history observers share this authority so one wrapper cannot
 * race another wrapper's release transaction.
 */
export async function releaseSessionHandleSerialized(
  sessionId: number
): Promise<void> {
  if (releasesCompleted.has(sessionId)) return;
  const existing = releasesInFlight.get(sessionId);
  if (existing) return existing;

  const release = Promise.resolve().then(() =>
    getBackend().releaseSessionHandle(sessionId)
  );
  releasesInFlight.set(sessionId, release);
  try {
    await release;
    releasesCompleted.add(sessionId);
  } finally {
    if (releasesInFlight.get(sessionId) === release)
      releasesInFlight.delete(sessionId);
  }
}
