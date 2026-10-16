const TERMINAL_STATES = new Set([2, 3]);
const SESSION_RUNNING = 1;
const SESSION_COMPLETED = 2;
const SESSION_FAILED = 3;
const COMPLETION_SIGNATURE = 'vii';
const USER_DATA_SENTINEL = 0x4b17;

const REQUIRED_EXPORTS = [
  '_ffmpeg_kit_initialize',
  '_ffmpeg_kit_config_get_version',
  '_ffmpeg_kit_config_get_log_level',
  '_ffmpeg_kit_config_set_log_level',
  '_ffprobe_kit_execute_async',
  '_ffprobe_kit_cancel_session',
  '_ffmpeg_kit_execute_async',
  '_ffmpeg_kit_cancel_session',
  '_ffmpeg_kit_session_get_state',
  '_ffmpeg_kit_session_get_return_code',
  '_ffmpeg_kit_session_get_session_id',
  '_ffmpeg_kit_session_get_output',
  '_ffmpeg_kit_session_get_logs_as_string',
  '_ffmpeg_kit_free',
  '_ffmpeg_kit_handle_release',
  '_malloc',
  '_free',
];

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function requireFunction(module, name) {
  const fn = module?.[name];
  assert(typeof fn === 'function', `Wasm export is unavailable: ${name}`);
  return fn.bind(module);
}

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function fixtureUrl(origin, path) {
  const base = new URL(origin);
  assert(base.protocol === 'http:' || base.protocol === 'https:',
    `Fixture origin must use HTTP or HTTPS: ${origin}`);
  return new URL(path, `${base.origin}/`).href;
}

function readOwnedString(module, pointer) {
  if (!pointer) return '';
  try {
    return module.UTF8ToString(pointer);
  } finally {
    requireFunction(module, '_ffmpeg_kit_free')(pointer);
  }
}

function allocateString(module, value) {
  const size = module.lengthBytesUTF8(value) + 1;
  const pointer = requireFunction(module, '_malloc')(size);
  assert(pointer, `Unable to allocate ${size} bytes for a native string.`);
  try {
    module.stringToUTF8(value, pointer, size);
    return pointer;
  } catch (error) {
    requireFunction(module, '_free')(pointer);
    throw error;
  }
}

function versionAndExports(module) {
  for (const name of REQUIRED_EXPORTS) requireFunction(module, name);
  assert(typeof module.lengthBytesUTF8 === 'function' &&
    typeof module.stringToUTF8 === 'function' &&
    typeof module.UTF8ToString === 'function',
  'The Wasm module string conversion shims are unavailable.');
  assert(typeof module.addFunction === 'function' &&
    typeof module.removeFunction === 'function',
  'The Wasm function table callbacks cannot be owned and released.');

  const versionPointer = requireFunction(module, '_ffmpeg_kit_config_get_version')();
  const version = readOwnedString(module, versionPointer);
  return { version, requiredExports: [...REQUIRED_EXPORTS] };
}

function sessionString(module, name, handle) {
  const pointer = requireFunction(module, name)(handle);
  return readOwnedString(module, pointer);
}

function parseProbeJson(output, label) {
  const start = output.indexOf('{');
  assert(start >= 0, `${label} FFprobe output did not contain JSON: ${output.slice(-500)}`);
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let index = start; index < output.length; index += 1) {
    const character = output[index];
    if (inString) {
      if (escaped) escaped = false;
      else if (character === '\\') escaped = true;
      else if (character === '"') inString = false;
    } else if (character === '"') {
      inString = true;
    } else if (character === '{') {
      depth += 1;
    } else if (character === '}' && --depth === 0) {
      try {
        return JSON.parse(output.slice(start, index + 1));
      } catch (error) {
        throw new Error(`${label} FFprobe returned invalid JSON: ${String(error)}; output=${output.slice(-500)}`);
      }
    }
  }
  throw new Error(`${label} FFprobe returned incomplete JSON: ${output.slice(start, start + 500)}`);
}

function streamSummary(metadata) {
  return (metadata.streams ?? []).map(stream => ({
    codec: stream.codec_name,
    type: stream.codec_type,
    width: stream.width,
    height: stream.height,
    sampleRate: stream.sample_rate,
    channels: stream.channels,
  }));
}

async function waitForTerminal(module, handle, timeoutMs) {
  const getState = requireFunction(module, '_ffmpeg_kit_session_get_state');
  const deadline = performance.now() + timeoutMs;
  let state = getState(handle);
  while (!TERMINAL_STATES.has(state) && performance.now() < deadline) {
    await delay(25);
    state = getState(handle);
  }
  assert(TERMINAL_STATES.has(state),
    `Native session ${handle} did not reach a terminal state within ${timeoutMs} ms (state=${state}).`);
  return state;
}

async function waitForCompletionCount(callbacks, count, timeoutMs, label) {
  const deadline = performance.now() + timeoutMs;
  while (callbacks.length < count && performance.now() < deadline) await delay(20);
  assert(callbacks.length === count,
    `${label} completion callback count=${callbacks.length}, expected ${count}.`);
}

async function runAsyncCommand(module, command, {
  timeoutMs = 30000,
  cancelOnTimeout = true,
  executeExport = '_ffprobe_kit_execute_async',
  cancelExport = '_ffprobe_kit_cancel_session',
  label = 'FFprobe',
} = {}) {
  const allocate = allocateString(module, command);
  let callbackPointer;
  let handle = 0;
  let sessionId = 0n;
  let callback = null;
  let terminal = false;
  let callbackRemoved = false;
  let handleReleased = false;
  let result;
  let primaryError;
  const callbacks = [];

  try {
    callback = (...args) => {
      // Emscripten callbacks must not throw across the Wasm boundary.
      callbacks.push({ sessionHandle: Number(args[0]), userData: Number(args[1]) });
    };
    callbackPointer = module.addFunction(callback, COMPLETION_SIGNATURE);
    assert(Number.isInteger(callbackPointer) && callbackPointer > 0,
      `Emscripten did not allocate a valid ${label} completion callback slot.`);

    // Both native complete callbacks are (session handle, void *user_data),
    // declared in ffmpegkit_wrapper.h. Emscripten represents both pointers as i32.
    handle = requireFunction(module, executeExport)(
      allocate, callbackPointer, USER_DATA_SENTINEL);
    assert(handle, `${executeExport} returned a null session handle.`);
    sessionId = BigInt(requireFunction(module, '_ffmpeg_kit_session_get_session_id')(handle));
    assert(sessionId > 0n, `Native ${label} session has invalid identity ${sessionId}.`);

    const state = await waitForTerminal(module, handle, timeoutMs);
    terminal = true;
    const returnCode = Number(requireFunction(module, '_ffmpeg_kit_session_get_return_code')(handle));
    const output = sessionString(module, '_ffmpeg_kit_session_get_output', handle);
    const nativeLogs = sessionString(module, '_ffmpeg_kit_session_get_logs_as_string', handle);
    await waitForCompletionCount(callbacks, 1, 5000, `${label} session ${sessionId}`);
    assert(callbacks[0].sessionHandle === handle,
      `${label} completion callback handle ${callbacks[0].sessionHandle} did not match ${handle}.`);
    assert(callbacks[0].userData === USER_DATA_SENTINEL,
      `${label} completion callback user data ${callbacks[0].userData} did not match its sentinel.`);
    await delay(300);
    assert(callbacks.length === 1,
      `${label} session ${sessionId} invoked its completion callback ${callbacks.length} times.`);

    result = { handle, sessionId: sessionId.toString(), state, returnCode, output, nativeLogs };
  } catch (error) {
    primaryError = error;
  } finally {
    try {
      requireFunction(module, '_free')(allocate);
    } catch (cleanupError) {
      primaryError ??= new Error(`${label} command buffer cleanup failed: ${String(cleanupError)}`);
    }
    if (handle) {
      try {
        if (!terminal) {
          const state = Number(requireFunction(module, '_ffmpeg_kit_session_get_state')(handle));
          if (!TERMINAL_STATES.has(state) && cancelOnTimeout) {
            const id = BigInt(requireFunction(module, '_ffmpeg_kit_session_get_session_id')(handle));
            requireFunction(module, cancelExport)(id);
          }
          await waitForTerminal(module, handle, 5000);
          terminal = true;
        }
        await waitForCompletionCount(callbacks, 1, 5000, `cleanup for ${label} session ${sessionId}`);
        if (terminal) {
          requireFunction(module, '_ffmpeg_kit_handle_release')(handle);
          handleReleased = true;
        }
      } catch (cleanupError) {
        primaryError ??= new Error(`${label} session cleanup failed: ${String(cleanupError)}`);
      }
    } else if (callbackPointer) {
      try {
        module.removeFunction(callbackPointer);
        callbackRemoved = true;
      } catch (cleanupError) {
        primaryError ??= new Error(`${label} callback cleanup failed: ${String(cleanupError)}`);
      }
    }
    if (callbackPointer && terminal && handleReleased) {
      try {
        module.removeFunction(callbackPointer);
        callbackRemoved = true;
      } catch (cleanupError) {
        primaryError ??= new Error(`${label} callback cleanup failed: ${String(cleanupError)}`);
      }
    }
    if (handle && !handleReleased)
      primaryError ??= new Error(`${label} session handle ${handle} was not released safely.`);
    if (callbackPointer && !callbackRemoved)
      primaryError ??= new Error(`${label} completion callback ${callbackPointer} was not released safely.`);
  }

  if (primaryError) throw primaryError;
  return result;
}

function runProbe(module, command, options) {
  return runAsyncCommand(module, command, options);
}

function assertMediaMetadata(result, label, expectedFormat) {
  assert(result.state === SESSION_COMPLETED && result.returnCode === 0,
    `${label} FFprobe state=${result.state}, return=${result.returnCode}; ` +
    `logs=${result.nativeLogs.slice(-800)}; output=${result.output.slice(-800)}`);
  const metadata = parseProbeJson(result.output, label);
  assert(String(metadata.format?.format_name ?? '').includes(expectedFormat),
    `${label} format=${JSON.stringify(metadata.format)}; expected ${expectedFormat}.`);
  const video = (metadata.streams ?? []).find(stream => stream.codec_name === 'h264');
  const audio = (metadata.streams ?? []).find(stream => stream.codec_name === 'aac');
  assert(video, `${label} did not report an H.264 stream: ${JSON.stringify(streamSummary(metadata))}`);
  assert(audio, `${label} did not report an AAC stream: ${JSON.stringify(streamSummary(metadata))}`);
  return { format: metadata.format.format_name, streams: streamSummary(metadata) };
}

async function runCase(cases, name, operation) {
  const startedAt = new Date().toISOString();
  const started = performance.now();
  try {
    const detail = await operation();
    cases.push({ name, status: 'passed', startedAt, elapsedMs: Math.round(performance.now() - started), ...detail });
  } catch (error) {
    cases.push({ name, status: 'failed', startedAt, elapsedMs: Math.round(performance.now() - started),
      error: { name: error?.name ?? 'Error', message: String(error?.message ?? error) } });
  }
}

async function fixtureRequests(origin) {
  const response = await fetch(fixtureUrl(origin, '/__requests'), {
    cache: 'no-store', signal: AbortSignal.timeout(5000),
  });
  assert(response.ok, `Fixture request log returned HTTP ${response.status}.`);
  const requests = await response.json();
  assert(Array.isArray(requests), 'Fixture /__requests response was not an array.');
  return requests;
}

async function waitForRequest(origin, path, handle, module, timeoutMs) {
  const deadline = performance.now() + timeoutMs;
  while (performance.now() < deadline) {
    const state = Number(requireFunction(module, '_ffmpeg_kit_session_get_state')(handle));
    if (TERMINAL_STATES.has(state)) break;
    if ((await fixtureRequests(origin)).some(request => request.path === path)) return true;
    await delay(40);
  }
  return false;
}

/** Checks the pinned binary identity and the C entry points used by this fixture. */
export function verifyBridgeModule(module) {
  return versionAndExports(module);
}

/**
 * Runs bounded direct-C FFprobe checks against the read-only streaming fixture.
 * This deliberately exercises the Wasm ABI below the React Native adapter.
 */
export async function runBridgeContract(module, fixtureOrigin) {
  const cases = [];
  let previousLogLevel;
  let logLevelChanged = false;
  let primaryError;
  try {
    const identity = versionAndExports(module);
    const init = requireFunction(module, '_ffmpeg_kit_initialize');
    init();
    previousLogLevel = Number(requireFunction(module, '_ffmpeg_kit_config_get_log_level')());
    requireFunction(module, '_ffmpeg_kit_config_set_log_level')(48);
    logLevelChanged = true;

    cases.push({ name: 'pinned runtime identity and required C exports', status: 'passed', ...identity });

    await runCase(cases, 'async FFprobe progressive MP4 metadata and session identity', async () => {
      const url = fixtureUrl(fixtureOrigin, '/media/d2-same-h264-aac.mp4');
      const result = await runProbe(module,
        `-v debug -show_entries format=format_name,duration:stream=codec_name,codec_type,width,height,sample_rate,channels -of json ${url}`);
      const metadata = assertMediaMetadata(result, 'Progressive MP4', 'mp4');
      return { sessionId: result.sessionId, nativeLogs: result.nativeLogs.slice(-1200), ...metadata };
    });

    await runCase(cases, 'async FFprobe HLS VOD metadata and session identity', async () => {
      const url = fixtureUrl(fixtureOrigin, '/hls/three-segment.m3u8');
      const result = await runProbe(module,
        `-v debug -count_packets -show_entries format=format_name:stream=codec_name,codec_type,width,height,sample_rate,channels,nb_read_packets -of json ${url}`, {
          timeoutMs: 60000,
        });
      const metadata = assertMediaMetadata(result, 'HLS VOD', 'hls');
      const video = metadata.streams.find(stream => stream.codec === 'h264');
      const audio = metadata.streams.find(stream => stream.codec === 'aac');
      assert(video && audio, 'HLS VOD did not expose both H.264 and AAC streams.');
      return { sessionId: result.sessionId, nativeLogs: result.nativeLogs.slice(-1200), ...metadata };
    });

    for (const status of [403, 404, 500]) {
      await runCase(cases, `HTTP ${status} failure preserves native context`, async () => {
        const path = `/status/${status}`;
        const result = await runProbe(module,
          `-v debug -show_entries format=format_name -of json ${fixtureUrl(fixtureOrigin, path)}`);
        const logs = result.nativeLogs;
        assert(TERMINAL_STATES.has(result.state) && result.returnCode !== 0,
          `HTTP ${status} unexpectedly succeeded (state=${result.state}, return=${result.returnCode}).`);
        assert(new RegExp(`HTTP\\s+${status}\\b`).test(logs),
          `HTTP ${status} failure omitted its native status log; native logs=${result.nativeLogs.slice(-1000)}`);
        assert(logs.includes(path),
          `HTTP ${status} native diagnostics omitted the request path ${path}.`);
        return { sessionId: result.sessionId, returnCode: result.returnCode,
          nativeLogs: result.nativeLogs.slice(-1200) };
      });
    }

    await runCase(cases, 'cross-origin CORS failure between localhost and 127.0.0.1', async () => {
      const pageOrigin = globalThis.location?.origin;
      assert(pageOrigin, 'CORS contract requires a browser page origin.');
      const base = new URL(fixtureOrigin);
      const pageHost = globalThis.location.hostname;
      assert(pageHost === 'localhost' || pageHost === '127.0.0.1',
        `CORS contract requires a localhost or 127.0.0.1 page origin, received ${pageHost}.`);
      const otherHost = pageHost === 'localhost' ? '127.0.0.1' : 'localhost';
      const corsOrigin = `${base.protocol}//${otherHost}:${base.port}`;
      assert(corsOrigin !== pageOrigin,
        `CORS test origin ${corsOrigin} matches the browser page origin; use localhost vs 127.0.0.1.`);
      const path = '/cors/absent';
      const result = await runProbe(module,
        `-v debug -show_entries format=format_name -of json ${fixtureUrl(corsOrigin, path)}`);
      const logs = result.nativeLogs;
      assert(TERMINAL_STATES.has(result.state) && result.returnCode !== 0,
        `Cross-origin request without CORS unexpectedly succeeded (state=${result.state}, return=${result.returnCode}).`);
      assert(/cors|failed to fetch|network.?error|err_failed|fetch.*fail/i.test(logs),
        `CORS failure omitted contextual native diagnostics; native logs=${result.nativeLogs.slice(-1000)}`);
      return { sessionId: result.sessionId, returnCode: result.returnCode,
        requestOrigin: corsOrigin, pageOrigin, nativeLogs: result.nativeLogs.slice(-1200) };
    });

    await runCase(cases, 'cancel one active slow network request and settle once', async () => {
      const path = '/slow';
      const url = fixtureUrl(fixtureOrigin, path);
      const command = `-v debug -show_entries format=format_name -of json ${url}`;
      const commandPointer = allocateString(module, command);
      let callbackPointer;
      let handle = 0;
      let sessionId = 0n;
      let terminal = false;
      let handleReleased = false;
      let callbackRemoved = false;
      const callbacks = [];
      let cancelCalls = 0;
      let caseError;
      try {
        callbackPointer = module.addFunction((...args) => {
          callbacks.push({ sessionHandle: Number(args[0]), userData: Number(args[1]) });
        }, COMPLETION_SIGNATURE);
        assert(Number.isInteger(callbackPointer) && callbackPointer > 0,
          'Emscripten did not allocate a cancellation completion callback slot.');
        handle = requireFunction(module, '_ffprobe_kit_execute_async')(
          commandPointer, callbackPointer, USER_DATA_SENTINEL);
        assert(handle, 'Slow FFprobe did not return a session handle.');
        sessionId = BigInt(requireFunction(module, '_ffmpeg_kit_session_get_session_id')(handle));
        assert(sessionId > 0n, `Slow FFprobe session has invalid ID ${sessionId}.`);

        const requestSeen = await waitForRequest(fixtureOrigin, path, handle, module, 5000);
        assert(requestSeen,
          `Slow HTTP request ${path} did not reach the fixture while the session was running.`);
        assert(Number(requireFunction(module, '_ffmpeg_kit_session_get_state')(handle)) === SESSION_RUNNING,
          'Slow FFprobe was not running immediately before cancellation.');

        const cancelStarted = performance.now();
        cancelCalls += 1;
        requireFunction(module, '_ffprobe_kit_cancel_session')(sessionId);
        const state = await waitForTerminal(module, handle, 12000);
        terminal = true;
        const returnCode = Number(requireFunction(module, '_ffmpeg_kit_session_get_return_code')(handle));
        const output = sessionString(module, '_ffmpeg_kit_session_get_output', handle);
        const nativeLogs = sessionString(module, '_ffmpeg_kit_session_get_logs_as_string', handle);
        await waitForCompletionCount(callbacks, 1, 5000, `cancelled FFprobe session ${sessionId}`);
        assert(callbacks[0].sessionHandle === handle &&
          callbacks[0].userData === USER_DATA_SENTINEL,
        `Cancellation completion callback identity mismatch: ${JSON.stringify(callbacks[0])}.`);
        await delay(300);
        assert(callbacks.length === 1,
          `Cancelled FFprobe completion callback count=${callbacks.length}, expected exactly one.`);
        assert(cancelCalls === 1, `Targeted cancellation was invoked ${cancelCalls} times, expected once.`);
        assert(returnCode !== 0,
          `Cancelled FFprobe unexpectedly succeeded (state=${state}, output=${output.slice(-500)}).`);
        const logs = nativeLogs;
        assert(logs.includes('WASM HTTP request interrupted'),
          `Cancellation log did not confirm the pending request interruption; native logs=${nativeLogs.slice(-1000)}`);
        assert(logs.includes(path),
          `Cancellation diagnostics omitted the pending path ${path}.`);
        assert(performance.now() - cancelStarted < 12000,
          'Network cancellation exceeded its 12 second completion bound.');
        return { sessionId: sessionId.toString(), state, returnCode,
          cancellationCalls: cancelCalls, completionCallbacks: callbacks.length,
          elapsedAfterCancelMs: Math.round(performance.now() - cancelStarted),
          nativeLogs: nativeLogs.slice(-1200) };
      } catch (error) {
        caseError = error;
      } finally {
        try {
          requireFunction(module, '_free')(commandPointer);
        } catch (cleanupError) {
          caseError ??= new Error(`Cancellation command buffer cleanup failed: ${String(cleanupError)}`);
        }
        if (handle) {
          try {
            const state = Number(requireFunction(module, '_ffmpeg_kit_session_get_state')(handle));
            if (!TERMINAL_STATES.has(state)) {
              if (cancelCalls === 0) {
                cancelCalls += 1;
                const id = BigInt(requireFunction(module, '_ffmpeg_kit_session_get_session_id')(handle));
                requireFunction(module, '_ffprobe_kit_cancel_session')(id);
              }
              await waitForTerminal(module, handle, 5000);
              terminal = true;
            } else {
              terminal = true;
            }
            await waitForCompletionCount(callbacks, 1, 5000, `cancellation cleanup session ${sessionId}`);
            if (terminal) {
              requireFunction(module, '_ffmpeg_kit_handle_release')(handle);
              handleReleased = true;
            }
          } catch (cleanupError) {
            caseError ??= new Error(`Cancellation cleanup failed: ${String(cleanupError)}`);
          }
        } else if (callbackPointer) {
          try {
            module.removeFunction(callbackPointer);
            callbackRemoved = true;
          } catch (cleanupError) {
            caseError ??= new Error(`Cancellation callback cleanup failed: ${String(cleanupError)}`);
          }
        }
        if (callbackPointer && terminal && handleReleased) {
          try {
            module.removeFunction(callbackPointer);
            callbackRemoved = true;
          } catch (cleanupError) {
            caseError ??= new Error(`Cancellation callback cleanup failed: ${String(cleanupError)}`);
          }
        }
        if (handle && !handleReleased)
          caseError ??= new Error(`Cancelled FFprobe handle ${handle} was not released safely.`);
        if (callbackPointer && !callbackRemoved)
          caseError ??= new Error(`Cancellation callback ${callbackPointer} was not released safely.`);
      }
      if (caseError) throw caseError;
    });
  } catch (error) {
    primaryError = error;
  } finally {
    if (logLevelChanged) {
      try {
        requireFunction(module, '_ffmpeg_kit_config_set_log_level')(previousLogLevel);
      } catch (error) {
        primaryError ??= new Error(`Unable to restore FFmpegKit log level: ${String(error)}`);
      }
    }
  }

  const failed = cases.filter(testCase => testCase.status !== 'passed');
  const report = {
    status: failed.length === 0 && !primaryError ? 'passed' : 'failed',
    runtimeVersion: cases.find(testCase => testCase.name === 'pinned runtime identity and required C exports')?.version ?? null,
    cases,
    cleanupError: primaryError ? String(primaryError?.stack ?? primaryError) : null,
  };
  if (report.status !== 'passed') {
    const error = new Error(`Wasm bridge contract failed: ${JSON.stringify(report)}`);
    error.name = 'BridgeContractError';
    error.report = report;
    throw error;
  }
  return report;
}

/** Generates and inspects one native FFmpeg frame through the C ABI. */
export async function runMemoryFileContract(module) {
  const path = '/tmp/CODEX_bridge_frame.rgba';
  const fs = module?.FS;
  assert(fs && typeof fs.readFile === 'function' &&
    typeof fs.unlink === 'function' && typeof fs.stat === 'function',
  'The Wasm module does not expose the required MEMFS operations.');

  const cases = [];
  let attemptedOutput = false;
  await runCase(cases, 'async FFmpeg raw RGBA frame is written to and removed from MEMFS', async () => {
    requireFunction(module, '_ffmpeg_kit_initialize')();
    try {
      fs.stat(path);
      throw new Error(`Refusing to overwrite an existing fixture output: ${path}`);
    } catch (error) {
      if (/Refusing to overwrite/.test(String(error?.message))) throw error;
      if (error?.errno !== 44 && error?.code !== 'ENOENT' && !/ENOENT/i.test(String(error?.message)))
        throw error;
    }

    const command = `-f lavfi -i color=c=red:s=16x16:r=1 -frames:v 1 ` +
      `-c:v rawvideo -pix_fmt rgba -f rawvideo ${path}`;
    attemptedOutput = true;
    const result = await runAsyncCommand(module, command, {
      executeExport: '_ffmpeg_kit_execute_async',
      cancelExport: '_ffmpeg_kit_cancel_session',
      label: 'FFmpeg',
      timeoutMs: 15000,
    });
    assert(result.state === SESSION_COMPLETED && result.returnCode === 0,
      `Lavfi/rawvideo generation state=${result.state}, return=${result.returnCode}; ` +
      `native logs=${result.nativeLogs.slice(-1600)}; output=${result.output.slice(-500)}`);

    const frame = new Uint8Array(fs.readFile(path));
    assert(frame.byteLength === 16 * 16 * 4,
      `Generated frame has ${frame.byteLength} bytes, expected 1024.`);
    for (let offset = 0; offset < frame.byteLength; offset += 4) {
      assert(frame[offset] >= 250 && frame[offset + 1] <= 3 &&
        frame[offset + 2] <= 3 && frame[offset + 3] === 255,
      `RGBA pixel ${offset / 4} was ${[...frame.subarray(offset, offset + 4)]}, ` +
        'expected opaque red (R>=250, G/B<=3, A=255).');
    }
    return { sessionId: result.sessionId, state: result.state,
      returnCode: result.returnCode, bytes: frame.byteLength,
      pixels: frame.byteLength / 4,
      expectedPixel: 'opaque red (R>=250, G/B<=3, A=255)',
      nativeLogs: result.nativeLogs.slice(-1600) };
  });

  if (attemptedOutput) {
    try {
      fs.unlink(path);
    } catch (error) {
      if (error?.errno !== 44 && error?.code !== 'ENOENT' && !/ENOENT/i.test(String(error?.message))) {
        cases.push({ name: 'MEMFS output cleanup', status: 'failed',
          error: { name: error?.name ?? 'Error', message: String(error?.message ?? error) } });
      }
    }
  }

  const failed = cases.filter(testCase => testCase.status !== 'passed');
  const report = { status: failed.length ? 'failed' : 'passed', cases };
  if (report.status !== 'passed') {
    const error = new Error(`Wasm MEMFS contract failed: ${JSON.stringify(report)}`);
    error.name = 'BridgeContractError';
    error.report = report;
    throw error;
  }
  return report;
}
