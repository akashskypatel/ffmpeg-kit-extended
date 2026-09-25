import NativeFFmpegKitExtended from '../NativeFFmpegKitExtended';
import type {FFmpegKitBackend} from './backend-registry';

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
        return (sessionId: number) => {
          const json = NativeFFmpegKitExtended.getSessionJson(sessionId);
          if (!json) throw new Error(`Session ${sessionId} no longer exists`);
          return (JSON.parse(json) as {state: number}).state;
        };
      }
      return Reflect.get(target, property, receiver);
    },
  },
);
