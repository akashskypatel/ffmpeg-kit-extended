import NativeFFmpegKitExtended from '../NativeFFmpegKitExtended';
import type {FFmpegKitBackend} from './backend-registry';

const abandonedSessionIds = new Set<number>();
const abandonmentReconciliationThreshold = 32;
let abandonmentEventsSinceReconciliation = 0;

function reconcileAbandonedSessionIds(): void {
  for (const sessionId of [...abandonedSessionIds]) {
    try {
      // This direct native lookup intentionally bypasses the JS tombstone
      // gate. A non-empty snapshot proves the ID still exists and therefore
      // must remain fail-closed; an empty snapshot proves safe reclamation.
      const json = NativeFFmpegKitExtended.getSessionJson(sessionId);
      if (!json) abandonedSessionIds.delete(sessionId);
    } catch {
      // Preserve the tombstone when the reconciliation oracle is unavailable.
    }
  }
}

function filterAbandonedHistory(json: string): string {
  if (!json) return json;
  try {
    const parsed: unknown = JSON.parse(json);
    if (Array.isArray(parsed)) {
      return JSON.stringify(
        parsed.filter(value => {
          if (!value || typeof value !== 'object') return true;
          return !abandonedSessionIds.has(
            Number((value as {sessionId?: unknown}).sessionId),
          );
        }),
      );
    }
    if (
      parsed &&
      typeof parsed === 'object' &&
      abandonedSessionIds.has(
        Number((parsed as {sessionId?: unknown}).sessionId),
      )
    ) {
      return '';
    }
  } catch {
    // Preserve the native payload when it is not a session-history JSON value.
  }
  return json;
}

/**
 * TurboModule methods are exposed through a proxy and are not guaranteed to
 * be enumerable. Delegating through a proxy keeps the full generated native
 * surface intact; spreading the module silently dropped methods such as
 * `logLevelToString` on Android.
 */
export const nativeBackend: FFmpegKitBackend = new Proxy(
  NativeFFmpegKitExtended as unknown as FFmpegKitBackend,
  {
    get(target, property, receiver) {
      if (property === 'initialize') {
        return async () => {
          NativeFFmpegKitExtended.initialize();
        };
      }
      if (property === 'isDirectLogBridgeActive') {
        return () =>
          typeof NativeFFmpegKitExtended.installLogBridge === 'function' &&
          typeof NativeFFmpegKitExtended.uninstallLogBridge === 'function' &&
          typeof NativeFFmpegKitExtended.onLogEvent === 'function';
      }
      if (property === 'getFrameBufferSize') {
        return () => 0;
      }
      if (property === 'copyFrame') {
        return () => ({
          width: 0,
          height: 0,
          linesize: 0,
          generation: 0,
          copied: false,
        });
      }
      if (property === 'getMediaInformationData') {
        return (sessionId: number) => {
          const json = NativeFFmpegKitExtended.getMediaInformationJson(sessionId);
          return json
            ? (JSON.parse(json) as ReturnType<FFmpegKitBackend['getMediaInformationData']>)
            : undefined;
        };
      }
      if (property === 'getSessionState') {
        return (sessionId: number) => NativeFFmpegKitExtended.getSessionState(sessionId);
      }
      if (property === 'isSessionAbandoned') {
        return (sessionId: number) => abandonedSessionIds.has(sessionId);
      }
      if (property === 'abandonCreatedSession') {
        return (sessionId: number) => {
          abandonedSessionIds.add(sessionId);
          NativeFFmpegKitExtended.abandonCreatedSession(sessionId);
          abandonmentEventsSinceReconciliation++;
          if (abandonmentEventsSinceReconciliation >= abandonmentReconciliationThreshold) {
            abandonmentEventsSinceReconciliation = 0;
            reconcileAbandonedSessionIds();
          }
        };
      }
      if (property === 'getSessionJson') {
        return (sessionId: number) =>
          abandonedSessionIds.has(sessionId)
            ? ''
            : NativeFFmpegKitExtended.getSessionJson(sessionId);
      }
      if (property === 'getSessionsJson') {
        return (kind: string) =>
          filterAbandonedHistory(NativeFFmpegKitExtended.getSessionsJson(kind));
      }
      if (property === 'getLastSessionJson') {
        return (kind: string) =>
          filterAbandonedHistory(NativeFFmpegKitExtended.getLastSessionJson(kind));
      }
      if (property === 'clearSessions') {
        return () => {
          NativeFFmpegKitExtended.clearSessions();
          abandonedSessionIds.clear();
          abandonmentEventsSinceReconciliation = 0;
        };
      }
      return Reflect.get(target, property, receiver);
    },
  },
);
