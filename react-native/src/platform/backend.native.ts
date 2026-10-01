import NativeFFmpegKitExtended from '../NativeFFmpegKitExtended';
import type {FFmpegKitBackend} from './backend-registry';
import {reconcileAbandonedSession} from './native-session-reconciliation';

const nativeModule = NativeFFmpegKitExtended as unknown as Record<string, unknown>;

const abandonedSessionIds = new Set<number>();

const cancellationIntentSessionIds = new Set<number>();

const asyncNativeMethods = new Set([
  'executeSessionAsync', 'cancelSession', 'installLogBridge',
  'uninstallLogBridge', 'releaseSessionHandle', 'abandonCreatedSession',
  'ffplayStart', 'ffplayPause', 'ffplayResume', 'ffplayStop',
  'ffplaySeek', 'ffplaySetPosition', 'ffplaySetVolume',
  'enableRedirection', 'disableRedirection', 'setLogLevel',
  'setFontDirectory', 'setEnvironmentVariable', 'ignoreSignal',
  'setAudioOutputDevice', 'setSessionHistorySize', 'clearSessions',
  'closeFFmpegPipe', 'enableDebugLog', 'disableDebugLog', 'clearDebugLog',
]);

function invokeSynchronousNative<TResult>(method: string, args: readonly unknown[]): TResult {
  const candidate = nativeModule[method];
  if (typeof candidate !== 'function') {
    throw new Error(`Native FFmpegKit method ${method} is unavailable.`);
  }

  const result = Reflect.apply(
    candidate as (...values: unknown[]) => TResult,
    NativeFFmpegKitExtended,
    args as unknown[],
  );
  const message = NativeFFmpegKitExtended.consumeSynchronousError();
  if (message) throw new Error(message);
  return result;
}

async function invokeAsyncNative(method: string, args: readonly unknown[]): Promise<void> {
  const candidate = nativeModule[method];
  if (typeof candidate !== 'function') {
    throw new Error(`Native FFmpegKit method ${method} is unavailable.`);
  }
  await Reflect.apply(candidate as (...values: unknown[]) => unknown,
    NativeFFmpegKitExtended, args as unknown[]);
}

function reconcileAbandonedSessionId(sessionId: number): void {
  reconcileAbandonedSession(
    sessionId,
    abandonedSessionIds,
    candidate => invokeSynchronousNative<string>('getSessionJson', [candidate]),
  );
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
          await invokeAsyncNative('initialize', []);
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
          const json = invokeSynchronousNative<string>('getMediaInformationJson', [sessionId]);
          return json
            ? (JSON.parse(json) as ReturnType<FFmpegKitBackend['getMediaInformationData']>)
            : undefined;
        };
      }
      if (property === 'getSessionState') {
        return (sessionId: number) =>
          invokeSynchronousNative<number>('getSessionState', [sessionId]);
      }
      if (property === 'isSessionAbandoned') {
        return (sessionId: number) => abandonedSessionIds.has(sessionId);
      }
      if (property === 'abandonCreatedSession') {
        return async (sessionId: number) => {
          const isNewCandidate = !abandonedSessionIds.has(sessionId);
          abandonedSessionIds.add(sessionId);
          await invokeAsyncNative('abandonCreatedSession', [sessionId]);
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
            : invokeSynchronousNative<string>('getSessionJson', [sessionId]);
      }
      if (property === 'getSessionsJson') {
        return (kind: string) =>
          filterAbandonedHistory(invokeSynchronousNative<string>('getSessionsJson', [kind]));
      }
      if (property === 'getLastSessionJson') {
        return (kind: string) =>
          filterAbandonedHistory(
            invokeSynchronousNative<string>('getLastSessionJson', [kind]),
          );
      }
      if (property === 'clearSessions') {
        return async () => {
          await invokeAsyncNative('clearSessions', []);
          abandonedSessionIds.clear();
          cancellationIntentSessionIds.clear();
        };
      }

      const nativeValue = Reflect.get(target, property, receiver);
      if (property === 'onLogEvent' || typeof nativeValue !== 'function') {
        return nativeValue;
      }
      return (...args: unknown[]) => {
        return asyncNativeMethods.has(String(property))
          ? invokeAsyncNative(String(property), args)
          : invokeSynchronousNative<unknown>(String(property), args);
      };
    },
  },
);
