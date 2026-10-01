/**
 * Removes an abandoned identity only when a synchronous native probe proves
 * that no session snapshot remains. Probe failures are fail-closed so a
 * transient transport diagnostic cannot turn an unknown identity into a
 * confirmed absence.
 */
export function reconcileAbandonedSession(
  sessionId: number,
  abandonedSessionIds: Set<number>,
  readSessionSnapshot: (sessionId: number) => string,
): void {
  try {
    if (!readSessionSnapshot(sessionId)) abandonedSessionIds.delete(sessionId);
  } catch {
    // Preserve the tombstone when the reconciliation oracle is unavailable.
  }
}
