import { WebFFmpegKitBackend } from '../../react-native/src/platform/backend.web';
import { SessionState } from '../../react-native/src/types';
import type { WasmModule } from '../../react-native/src/platform/web/wasm-loader';

type NativeSessionSnapshot = {
  sessionId: number;
  type: string;
  state: number;
  returnCode: number;
  output: string;
  logs: string;
};

type NativeContractCase = {
  name: string;
  sessionId: number;
  type: string;
  state: number;
  returnCode: number;
  primaryHandleReleaseCalls: number;
  nativeHandleAllocations: number;
  nativeHandleReleases: number;
  nativeHandleLedger: Array<{
    epoch: number;
    pointer: number;
    source: string;
    releaseCount: number;
  }>;
  format?: string;
  streams?: string[];
  failureLog?: string;
};

function requireCondition(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function isTerminal(state: number): boolean {
  return state === SessionState.Completed || state === SessionState.Failed;
}

async function waitForTerminal(
  backend: WebFFmpegKitBackend,
  sessionId: number,
  timeoutMs: number,
): Promise<number> {
  const deadline = Date.now() + timeoutMs;
  let state = backend.getSessionState(sessionId);
  while (!isTerminal(state) && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 50));
    state = backend.getSessionState(sessionId);
  }
  requireCondition(
    isTerminal(state),
    `FFprobe session ${sessionId} did not settle within ${timeoutMs} ms (state=${state}).`,
  );
  return state;
}

async function runProbeCase(
  module: WasmModule,
  fixtureOrigin: string,
  path: string,
  name: string,
  expectSuccess: boolean,
): Promise<NativeContractCase> {
  type HandleAllocation = {
    pointer: number;
    epoch: number;
    source: string;
    releaseCount: number;
  };
  const allocations: HandleAllocation[] = [];
  const liveAllocations = new Map<number, HandleAllocation>();
  const releases: HandleAllocation[] = [];
  const instrumentationErrors: string[] = [];
  let retainedExecutionAllocation: HandleAllocation | undefined;
  const recordAllocation = (source: string, value: unknown): number => {
    const pointer = Number(value);
    if (!Number.isFinite(pointer) || pointer <= 0) {
      instrumentationErrors.push(`${source} returned invalid handle ${String(value)}.`);
      return pointer;
    }
    if (liveAllocations.has(pointer)) {
      instrumentationErrors.push(
        `${source} reused live pointer ${pointer} without a release.`,
      );
      return pointer;
    }
    const allocation = {pointer, epoch: allocations.length + 1, source, releaseCount: 0};
    allocations.push(allocation);
    liveAllocations.set(pointer, allocation);
    if (source === 'ffmpeg_kit_get_session') {
      retainedExecutionAllocation = allocation;
    }
    return pointer;
  };
  const observedModule = new Proxy(module, {
    get(target, property, receiver) {
      const value = Reflect.get(target, property, receiver);
      if (
        (property === '_ffprobe_kit_create_session' ||
          property === 'ffprobe_kit_create_session' ||
          property === '_ffmpeg_kit_get_session' ||
          property === 'ffmpeg_kit_get_session') &&
        typeof value === 'function'
      ) {
        return (...args: unknown[]) => {
          const pointer = Reflect.apply(value, target, args);
          recordAllocation(String(property).replace(/^_/, ''), pointer);
          return pointer;
        };
      }
      if (
        (property === '_ffmpeg_kit_handle_release' ||
          property === 'ffmpeg_kit_handle_release') &&
        typeof value === 'function'
      ) {
        return (pointer: number) => {
          const numericPointer = Number(pointer);
          const allocation = liveAllocations.get(numericPointer);
          if (!allocation) {
            const error = `Native handle ${numericPointer} was released without a live allocation.`;
            instrumentationErrors.push(error);
            throw new Error(error);
          }
          const result = Reflect.apply(value, target, [pointer]);
          allocation.releaseCount += 1;
          releases.push(allocation);
          liveAllocations.delete(numericPointer);
          return result;
        };
      }
      return value;
    },
  });
  const backend = new WebFFmpegKitBackend(undefined, observedModule);
  let sessionId: number | undefined;
  let terminalState: number | undefined;
  let snapshot: NativeSessionSnapshot | undefined;
  let result: NativeContractCase | undefined;
  let primaryError: unknown;
  let primaryHandleReleaseCalls = 0;

  try {
    const mediaUrl = new URL(path, fixtureOrigin).href;
    const command =
      `-v ${expectSuccess ? 'error' : 'debug'} ` +
      `-show_entries format=format_name:stream=codec_name,codec_type ` +
      `-of json ${mediaUrl}`;
    sessionId = backend.createFFprobeSession(command);
    backend.executeSessionAsync(sessionId, 0);
    terminalState = await waitForTerminal(backend, sessionId, 30_000);

    const serialized = backend.getSessionJson(sessionId);
    requireCondition(serialized.length > 0, `${name}: backend returned an empty session snapshot.`);
    snapshot = JSON.parse(serialized) as NativeSessionSnapshot;
    requireCondition(snapshot.sessionId === sessionId, `${name}: session identity changed.`);
    requireCondition(snapshot.type === 'ffprobe', `${name}: expected ffprobe, got ${snapshot.type}.`);
    requireCondition(snapshot.state === terminalState, `${name}: snapshot state did not match polling state.`);

    if (expectSuccess) {
      requireCondition(
        terminalState === SessionState.Completed && snapshot.returnCode === 0,
        `${name}: FFprobe failed (state=${terminalState}, return=${snapshot.returnCode}); logs=${snapshot.logs.slice(-800)}.`,
      );
      const metadata = JSON.parse(snapshot.output) as {
        format?: { format_name?: string };
        streams?: Array<{ codec_name?: string }>;
      };
      const format = String(metadata.format?.format_name ?? '');
      const streams = (metadata.streams ?? []).map((stream) => String(stream.codec_name ?? ''));
      requireCondition(format.includes('mp4'), `${name}: unexpected container format ${format}.`);
      requireCondition(streams.includes('h264'), `${name}: missing H.264 stream.`);
      requireCondition(streams.includes('aac'), `${name}: missing AAC stream.`);
      result = {
        name,
        sessionId,
        type: snapshot.type,
        state: snapshot.state,
        returnCode: snapshot.returnCode,
        primaryHandleReleaseCalls,
        nativeHandleAllocations: 0,
        nativeHandleReleases: 0,
        nativeHandleLedger: [],
        format,
        streams,
      };
    } else {
      requireCondition(
        isTerminal(terminalState) && snapshot.returnCode !== 0,
        `${name}: expected a terminal FFprobe failure (state=${terminalState}, return=${snapshot.returnCode}).`,
      );
      requireCondition(/403/.test(snapshot.logs), `${name}: native logs omitted HTTP 403.`);
      result = {
        name,
        sessionId,
        type: snapshot.type,
        state: snapshot.state,
        returnCode: snapshot.returnCode,
        primaryHandleReleaseCalls,
        nativeHandleAllocations: 0,
        nativeHandleReleases: 0,
        nativeHandleLedger: [],
        failureLog: snapshot.logs.slice(-800),
      };
    }
  } catch (error) {
    primaryError = error;
  } finally {
    if (sessionId !== undefined) {
      try {
        if (terminalState === undefined || !isTerminal(terminalState)) {
          try {
            backend.cancelSession(sessionId);
          } catch {
            // Keep the primary fixture failure; bounded polling decides cleanup safety.
          }
          terminalState = await waitForTerminal(backend, sessionId, 5_000);
        }
        const releasesBeforePrimaryHandle = releases.length;
        const executionReleaseCountBefore = retainedExecutionAllocation?.releaseCount ?? 0;
        try {
          backend.releaseSessionHandle(sessionId);
        } catch (error) {
          primaryError ??= error;
        }
        const releasesAfterFirstCall = releases.length;
        try {
          backend.releaseSessionHandle(sessionId);
        } catch (error) {
          primaryError ??= error;
        }
        const releasesAfterSecondCall = releases.length;
        primaryHandleReleaseCalls = releasesAfterFirstCall - releasesBeforePrimaryHandle;
        if (
          !retainedExecutionAllocation ||
          primaryHandleReleaseCalls !== 1 ||
          retainedExecutionAllocation.releaseCount - executionReleaseCountBefore !== 1
        ) {
          primaryError ??= new Error(
            `${name}: expected one release of the retained execution handle, observed total delta ${primaryHandleReleaseCalls}.`,
          );
        }
        if (
          releasesAfterSecondCall !== releasesAfterFirstCall ||
          retainedExecutionAllocation?.releaseCount !==
            (retainedExecutionAllocation ? executionReleaseCountBefore + 1 : undefined)
        ) {
          primaryError ??= new Error(
            `${name}: duplicate release changed native release count from ${releasesAfterFirstCall} to ${releasesAfterSecondCall}.`,
          );
        }
      } catch (error) {
        primaryError ??= new Error(`Session ${sessionId} cleanup failed: ${String(error)}`);
      }
    }
    if (liveAllocations.size !== 0) {
      primaryError ??= new Error(
        `${name}: ${liveAllocations.size} native handle allocation(s) remain live.`,
      );
    }
    if (
      allocations.length !== releases.length ||
      allocations.some((allocation) => allocation.releaseCount !== 1)
    ) {
      primaryError ??= new Error(
        `${name}: native handle ledger mismatch (${allocations.length} allocations, ${releases.length} releases).`,
      );
    }
    if (instrumentationErrors.length) {
      primaryError ??= new Error(instrumentationErrors.join(' '));
    }
  }

  if (primaryError !== undefined) throw primaryError;
  requireCondition(result, `${name}: fixture case did not produce a result.`);
  result.primaryHandleReleaseCalls = primaryHandleReleaseCalls;
  result.nativeHandleAllocations = allocations.length;
  result.nativeHandleReleases = releases.length;
  result.nativeHandleLedger = allocations.map((allocation) => ({
    epoch: allocation.epoch,
    pointer: allocation.pointer,
    source: allocation.source,
    releaseCount: allocation.releaseCount,
  }));
  return result;
}

/** Exercises the React Native Web backend against a real initialized Wasm module. */
export async function runNativeBackendContract(
  module: WasmModule,
  fixtureOrigin: string,
): Promise<{ status: 'passed'; cases: NativeContractCase[] }> {
  const cases: NativeContractCase[] = [];
  const report = { status: 'passed' as const, cases };
  try {
    cases.push(await runProbeCase(
      module,
      fixtureOrigin,
      '/media/d2-same-h264-aac.mp4',
      'backend FFprobe session metadata and handle release',
      true,
    ));
    requireCondition(
      cases[0].primaryHandleReleaseCalls === 1,
      `Duplicate release invoked the native primary-handle release ${cases[0].primaryHandleReleaseCalls} times.`,
    );
    cases.push(await runProbeCase(
      module,
      fixtureOrigin,
      '/status/403',
      'backend FFprobe HTTP 403 failure context',
      false,
    ));
    requireCondition(
      cases[1].primaryHandleReleaseCalls === 1,
      `HTTP 403 session primary-handle release count was ${cases[1].primaryHandleReleaseCalls}.`,
    );
    return report;
  } catch (error) {
    const failure = new Error(
      `Native Wasm backend contract failed: ${JSON.stringify({
        ...report,
        status: 'failed',
        error: String((error as Error)?.stack ?? error),
      })}`,
    );
    failure.name = 'NativeBackendContractError';
    Object.assign(failure, { report: { ...report, status: 'failed', error: String(error) } });
    throw failure;
  }
}
