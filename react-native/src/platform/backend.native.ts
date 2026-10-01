import NativeFFmpegKitExtended from '../NativeFFmpegKitExtended';
import type {FFmpegKitBackend} from './backend-registry';

const nativeModule = NativeFFmpegKitExtended as unknown as Record<string, unknown>;

const abandonedSessionIds = new Set<number>();

const cancellationIntentSessionIds = new Set<number>();

function invokeNative<TResult>(method: string, args: readonly unknown[]): TResult {
  const candidate = nativeModule[method];
  if (typeof candidate !== 'function') {
    throw new Error(`Native FFmpegKit method ${method} is unavailable.`);
  }

  const result = Reflect.apply(
    candidate as (...values: unknown[]) => TResult,
    NativeFFmpegKitExtended,
    args as unknown[],
  );
  const message = NativeFFmpegKitExtended.consumeLastError();
  if (message) throw new Error(message);
  return result;
}

function reconcileAbandonedSessionId(sessionId: number): void {
  try {
    // This direct native lookup intentionally bypasses the JS tombstone gate.
    // A non-empty snapshot proves the ID still exists and must remain
    // fail-closed; an empty snapshot proves safe reclamation.
    const json = NativeFFmpegKitExtended.getSessionJson(sessionId);
    if (!json) abandonedSessionIds.delete(sessionId);
  } catch {
    // Preserve the tombstone when the reconciliation oracle is unavailable.
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
          invokeNative<void>('initialize', []);
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
          const json = invokeNative<string>('getMediaInformationJson', [sessionId]);
          return json
            ? (JSON.parse(json) as ReturnType<FFmpegKitBackend['getMediaInformationData']>)
            : undefined;
        };
      }
      if (property === 'getSessionState') {
        return (sessionId: number) =>
          invokeNative<number>('getSessionState', [sessionId]);
      }
      if (property === 'isSessionAbandoned') {
        return (sessionId: number) => abandonedSessionIds.has(sessionId);
      }
      if (property === 'abandonCreatedSession') {
        return (sessionId: number) => {
          const isNewCandidate = !abandonedSessionIds.has(sessionId);
          abandonedSessionIds.add(sessionId);
          invokeNative<void>('abandonCreatedSession', [sessionId]);
          if (isNewCandidate) reconcileAbandonedSessionId(sessionId);
        };
      }
      if (property === 'recordCancellationIntent') {
        return (sessionId: number) => cancellationIntentSessionIds.add(sessionId);
      }
      if (property === 'isCancellationRequested') {
        return (sessionId: number) => cancellationIntentSessionIds.has(sessionId);
      }
      if (property === 'clearCancellationIntent') {
        return (sessionId: number) => cancellationIntentSessionIds.delete(sessionId);
      }
      if (property === 'getSessionJson') {
        return (sessionId: number) =>
          abandonedSessionIds.has(sessionId)
            ? ''
            : invokeNative<string>('getSessionJson', [sessionId]);
      }
      if (property === 'getSessionsJson') {
        return (kind: string) =>
          filterAbandonedHistory(invokeNative<string>('getSessionsJson', [kind]));
      }
      if (property === 'getLastSessionJson') {
        return (kind: string) =>
          filterAbandonedHistory(
            invokeNative<string>('getLastSessionJson', [kind]),
          );
      }
      if (property === 'clearSessions') {
        return () => {
          invokeNative<void>('clearSessions', []);
          abandonedSessionIds.clear();
          cancellationIntentSessionIds.clear();
        };
      }

      const nativeValue = Reflect.get(target, property, receiver);
      if (property === 'onLogEvent' || typeof nativeValue !== 'function') {
        return nativeValue;
      }
      return (...args: unknown[]) =>
        invokeNative<unknown>(String(property), args);
    },
  },
);
