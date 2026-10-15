const SESSION_RUNNING = 1;
const SESSION_COMPLETED = 2;
const SESSION_FAILED = 3;
const FRAME_METADATA_BYTES = 24;
const SESSION_TIMEOUT_MS = 30000;
const CALLBACK_TIMEOUT_MS = 5000;

function requireFunction(module, name) {
  const value = module[name];
  if (typeof value !== 'function') {
    throw new Error(`Wasm export is unavailable: ${name}`);
  }
  return value;
}

function numberResult(value) {
  return typeof value === 'bigint' ? Number(value) : Number(value ?? 0);
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitFor(description, predicate, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const result = await predicate();
    if (result) return result;
    await delay(40);
  }
  throw new Error(`Timed out waiting for ${description} after ${timeoutMs} ms.`);
}

function readOwnedString(module, exportName, handle) {
  const pointer = numberResult(requireFunction(module, exportName)(handle));
  if (!pointer) return '';
  try {
    return module.UTF8ToString(pointer);
  } finally {
    requireFunction(module, '_ffmpeg_kit_free')(pointer);
  }
}

function sessionDiagnostics(module, handle) {
  const details = {};
  for (const [key, name] of [
    ['output', '_ffmpeg_kit_session_get_output'],
    ['logs', '_ffmpeg_kit_session_get_logs_as_string'],
    ['failStackTrace', '_ffmpeg_kit_session_get_fail_stack_trace'],
  ]) {
    try {
      details[key] = readOwnedString(module, name, handle);
    } catch (error) {
      details[key] = `unavailable: ${String(error)}`;
    }
  }
  return details;
}

function allocateUtf8(module, value) {
  const bytes = requireFunction(module, 'lengthBytesUTF8')(value);
  const pointer = requireFunction(module, '_malloc')(bytes + 1);
  if (!pointer) throw new Error('Unable to allocate FFplay command memory.');
  try {
    requireFunction(module, 'stringToUTF8')(value, pointer, bytes + 1);
    return pointer;
  } catch (error) {
    requireFunction(module, '_free')(pointer);
    throw error;
  }
}

function frameMetadata(module, pointers) {
  const heap = module.HEAPU32;
  const view = new DataView(module.HEAPU8.buffer);
  return {
    width: heap[pointers.width >>> 2],
    height: heap[pointers.height >>> 2],
    linesize: heap[pointers.linesize >>> 2],
    generation: view.getBigUint64(pointers.generation, true),
  };
}

function pixelSignature(bytes, width, height, linesize) {
  let hash = 2166136261;
  let nonBlackSamples = 0;
  let samples = 0;
  for (let row = 1; row < 5; row += 1) {
    const y = Math.floor((height * row) / 5);
    for (let column = 1; column < 5; column += 1) {
      const x = Math.floor((width * column) / 5);
      const offset = y * linesize + x * 4;
      const red = bytes[offset];
      const green = bytes[offset + 1];
      const blue = bytes[offset + 2];
      if (red + green + blue > 24) nonBlackSamples += 1;
      for (const channel of [red, green, blue]) {
        hash ^= channel;
        hash = Math.imul(hash, 16777619);
      }
      samples += 1;
    }
  }
  return {
    hash: (hash >>> 0).toString(16).padStart(8, '0'),
    nonBlackSamples,
    samples,
  };
}

export function copyLatestFrame(module, pointers) {
  const copyFrame = requireFunction(module, '_ffplay_kit_copy_frame');
  const probeResult = numberResult(copyFrame(
    0,
    0,
    pointers.width,
    pointers.height,
    pointers.linesize,
    pointers.generation,
  ));
  const metadata = frameMetadata(module, pointers);
  const required = numberResult(
    requireFunction(module, '_ffplay_kit_get_frame_buffer_size')(),
  );
  if (required === 0 || metadata.width <= 0 || metadata.height <= 0) return null;
  if (probeResult !== -1) {
    throw new Error(
      `Frame metadata probe returned ${probeResult}; native copy_frame reports -1 when a frame exists but destination size is zero.`,
    );
  }
  if (metadata.linesize < metadata.width * 4 ||
      required !== metadata.linesize * metadata.height ||
      required > 64 * 1024 * 1024) {
    throw new Error(`Invalid FFplay frame metadata: ${JSON.stringify({
      ...metadata,
      generation: metadata.generation.toString(),
      required,
    })}.`);
  }

  const destination = requireFunction(module, '_malloc')(required);
  if (!destination) throw new Error('Unable to allocate FFplay frame buffer.');
  try {
    const result = numberResult(copyFrame(
      destination,
      required,
      pointers.width,
      pointers.height,
      pointers.linesize,
      pointers.generation,
    ));
    if (result !== 1) {
      throw new Error(`FFplay frame copy returned ${result}; expected 1.`);
    }
    const copied = frameMetadata(module, pointers);
    const bytes = module.HEAPU8.slice(destination, destination + required);
    return {
      ...copied,
      metadataProbeReturn: probeResult,
      signature: pixelSignature(bytes, copied.width, copied.height, copied.linesize),
    };
  } finally {
    requireFunction(module, '_free')(destination);
  }
}

export async function runSession(module, callbackRecords, callbackTokens, callbackPointer, name, command, {
  stopAfterProgress = false,
  frames,
} = {}) {
  const record = {
    name,
    command,
    handle: null,
    sessionId: null,
    callbackToken: null,
    state: null,
    returnCode: null,
    callbackCount: 0,
    handleReleased: false,
  };
  let commandPointer;
  try {
    const userData = requireFunction(module, '_malloc')(1);
    if (!userData) throw new Error('Unable to allocate FFplay completion user data.');
    record.callbackToken = userData;
    callbackTokens.push(userData);
    callbackRecords.set(userData, {
      count: 0,
      expectedHandle: null,
      handles: [],
    });
    commandPointer = allocateUtf8(module, command);
    const handle = numberResult(requireFunction(module, '_ffplay_kit_execute_async')(
      commandPointer,
      callbackPointer,
      userData,
      0n,
    ));
    if (!handle) {
      throw new Error(
        'ffplay_kit_execute_async returned a null handle; the native wrapper returns null when command parsing or session creation fails.',
      );
    }
    record.handle = handle;
    const callbackRecord = callbackRecords.get(userData);
    if (!callbackRecord) throw new Error('FFplay completion token was lost.');
    callbackRecord.expectedHandle = handle;
  } finally {
    if (commandPointer) requireFunction(module, '_free')(commandPointer);
  }

  const getState = () => numberResult(
    requireFunction(module, '_ffmpeg_kit_session_get_state')(record.handle),
  );
  const terminal = (state) => state === SESSION_COMPLETED || state === SESSION_FAILED;
  const cleanupErrors = [];
  try {
    record.sessionId = String(
      requireFunction(module, '_ffmpeg_kit_session_get_session_id')(record.handle),
    );
    if (stopAfterProgress) {
      const running = await waitFor(`${name} to start`, () => {
        const state = getState();
        const position = numberResult(
          requireFunction(module, '_ffplay_kit_session_get_position')(record.handle),
        );
        return state === SESSION_RUNNING && position >= 0.05
          ? {state, position}
          : terminal(state)
            ? {state, position}
            : null;
      }, 10000);
      if (running.state !== SESSION_RUNNING) {
        throw new Error(
          `${name} reached terminal state ${running.state} before a stop could be requested.`,
        );
      }
      requireFunction(module, '_ffplay_kit_session_stop')(record.handle);
    }

    const metadataPointer = requireFunction(module, '_malloc')(FRAME_METADATA_BYTES);
    if (!metadataPointer) throw new Error('Unable to allocate FFplay frame metadata.');
    const pointers = {
      width: metadataPointer,
      height: metadataPointer + 4,
      linesize: metadataPointer + 8,
      generation: metadataPointer + 16,
    };
    try {
      const deadline = Date.now() + SESSION_TIMEOUT_MS;
      while (Date.now() < deadline) {
        const state = getState();
        if (frames && state === SESSION_RUNNING) {
          const frame = copyLatestFrame(module, pointers);
          if (frame) frames.push(frame);
        }
        if (terminal(state)) break;
        await delay(40);
      }
      record.state = getState();
      if (!terminal(record.state)) {
        requireFunction(module, '_ffplay_kit_session_stop')(record.handle);
        throw new Error(`${name} exceeded ${SESSION_TIMEOUT_MS} ms.`);
      }
    } finally {
      requireFunction(module, '_free')(metadataPointer);
    }

    await waitFor(
      `${name} completion callback`,
      () => callbackRecords.get(record.callbackToken)?.count === 1,
      CALLBACK_TIMEOUT_MS,
    );
    await delay(500);
    record.callbackCount = callbackRecords.get(record.callbackToken)?.count ?? 0;
    const callbackRecord = callbackRecords.get(record.callbackToken);
    if (record.callbackCount !== 1) {
      throw new Error(
        `${name} delivered ${record.callbackCount} completion callbacks; expected exactly one.`,
      );
    }
    if (callbackRecord.handles.some((handle) => handle !== record.handle)) {
      throw new Error(
        `${name} completion callback handle did not match its returned session handle (${callbackRecord.handles.join(', ')} vs ${record.handle}).`,
      );
    }
    record.state = getState();
    record.returnCode = numberResult(
      requireFunction(module, '_ffmpeg_kit_session_get_return_code')(record.handle),
    );
    if (record.state !== SESSION_COMPLETED && record.state !== SESSION_FAILED) {
      throw new Error(`${name} ended in non-terminal state ${record.state}.`);
    }
    if (!stopAfterProgress &&
        (record.state !== SESSION_COMPLETED || record.returnCode !== 0)) {
      throw new Error(
        `${name} did not finish naturally with success (state=${record.state}, returnCode=${record.returnCode}); native session details: ${JSON.stringify(sessionDiagnostics(module, record.handle))}.`,
      );
    }
  } catch (error) {
    record.error = String(error?.stack || error);
    try {
      record.state = getState();
      record.returnCode = numberResult(
        requireFunction(module, '_ffmpeg_kit_session_get_return_code')(record.handle),
      );
      record.nativeDetails = sessionDiagnostics(module, record.handle);
    } catch (diagnosticError) {
      record.diagnosticError = String(diagnosticError?.stack || diagnosticError);
    }
    const sessionError = new Error(String(error?.stack || error), {cause: error});
    sessionError.session = record;
    throw sessionError;
  } finally {
    try {
      const state = getState();
      if (!terminal(state)) {
        requireFunction(module, '_ffplay_kit_session_stop')(record.handle);
        await waitFor(`${name} cleanup to reach a terminal state`, () => {
          const current = getState();
          return terminal(current) ? current : null;
        }, 10000);
      }
    } catch (error) {
      cleanupErrors.push(String(error?.stack || error));
    }
    try {
      record.callbackCount = callbackRecords.get(record.callbackToken)?.count ?? 0;
    } catch (error) {
      cleanupErrors.push(String(error?.stack || error));
    }
    try {
      requireFunction(module, '_ffmpeg_kit_handle_release')(record.handle);
      record.handleReleased = true;
    } catch (error) {
      cleanupErrors.push(String(error?.stack || error));
    }
    if (cleanupErrors.length) record.cleanupErrors = cleanupErrors;
  }
  return record;
}

async function resetRequests(fixtureOrigin) {
  const response = await fetch(new URL('/__reset', fixtureOrigin), {
    method: 'POST', signal: AbortSignal.timeout(5000),
  });
  if (!response.ok) throw new Error(`Fixture request reset returned HTTP ${response.status}.`);
}

async function readRequests(fixtureOrigin) {
  const response = await fetch(new URL('/__requests', fixtureOrigin), {
    signal: AbortSignal.timeout(5000),
  });
  if (!response.ok) throw new Error(`Fixture request log returned HTTP ${response.status}.`);
  return response.json();
}

function assertPrivateCanvas(module) {
  if (!(module.canvas instanceof HTMLCanvasElement)) {
    throw new Error('The initialized Wasm module has no HTMLCanvasElement in module.canvas.');
  }
  if (module.canvas === document.getElementById('canvas') || module.canvas.isConnected) {
    throw new Error('The FFplay canvas is not private to its Wasm module.');
  }
}

function assertChangingFrames(name, frames) {
  const visible = frames.filter((frame) => frame.signature.nonBlackSamples > 0);
  if (visible.some((frame) => frame.width !== 320 || frame.height !== 240)) {
    throw new Error(
      `${name} returned unexpected frame dimensions: ${visible.map((frame) => `${frame.width}x${frame.height}`).join(', ')}; expected 320x240.`,
    );
  }
  const signatures = new Set(visible.map((frame) => frame.signature.hash));
  const generations = new Set(visible.map((frame) => frame.generation.toString()));
  if (visible.length < 2 || signatures.size < 2 || generations.size < 2) {
    throw new Error(
      `${name} did not produce changing nonblack frames (samples=${visible.length}, signatures=${signatures.size}, generations=${generations.size}).`,
    );
  }
  return {
    frameSamples: visible.length,
    uniquePixelSignatures: signatures.size,
    generations: generations.size,
    dimensions: `${visible[0].width}x${visible[0].height}`,
    expectedDimensions: '320x240',
    signatures: [...signatures].slice(0, 8),
  };
}

export async function runPlaybackContract(module, fixtureOrigin) {
  const report = {
    contract: 'wasm-bridge-playback',
    status: 'running',
    fixtureOrigin,
    coverageGaps: [
      'Heap baseline and bounded-growth bands are not measured by this fixture.',
      'Fresh module reload validation is owned by the browser runner.',
    ],
    outcomes: [],
    callbackEvents: [],
    handles: [],
  };
  const callbackRecords = new Map();
  const callbackTokens = [];
  const callback = (handle, userData) => {
    const pointer = numberResult(handle);
    const token = numberResult(userData);
    const record = callbackRecords.get(token);
    if (record) {
      record.count += 1;
      record.handles.push(pointer);
    } else {
      report.callbackViolations ??= [];
      report.callbackViolations.push({handle: pointer, userData: token, error: 'unknown callback token'});
    }
    report.callbackEvents.push({handle: pointer, userData: token});
  };
  let callbackPointer;
  let importedPath;
  let importedPathWritten = false;
  let contractError;

  const runCase = async (name, action) => {
    const outcome = {name, status: 'running'};
    report.outcomes.push(outcome);
    try {
      Object.assign(outcome, await action());
      outcome.status = 'passed';
    } catch (error) {
      outcome.status = 'failed';
      outcome.error = String(error?.stack || error);
      if (error?.session) {
        outcome.session = error.session;
        if (!report.handles.includes(error.session)) report.handles.push(error.session);
      }
      throw error;
    }
  };

  try {
    assertPrivateCanvas(module);
    if (!fixtureOrigin) throw new Error('A fixtureOrigin URL is required.');
    const fixtureUrl = new URL(fixtureOrigin);
    if (fixtureUrl.protocol !== 'http:' && fixtureUrl.protocol !== 'https:') {
      throw new Error(`Unsupported fixture origin protocol: ${fixtureUrl.protocol}`);
    }
    requireFunction(module, 'addFunction');
    callbackPointer = module.addFunction(callback, 'vpp');
    report.callbackSlotRetained = true;

    const hlsFrames = [];
    await runCase('remote HLS VOD natural EOF', async () => {
      await resetRequests(fixtureUrl.origin);
      const url = new URL('/redirect/master.m3u8?token=bridge-hls-vod', fixtureUrl.origin).href;
      const session = await runSession(
        module,
        callbackRecords,
        callbackTokens,
        callbackPointer,
        'remote HLS VOD',
        `-autoexit ${url}`,
        {frames: hlsFrames},
      );
      report.handles.push(session);
      if (!session.handleReleased || session.cleanupErrors?.length) {
        throw new Error(`Remote HLS session cleanup failed: ${JSON.stringify(session)}.`);
      }
      const requests = await readRequests(fixtureUrl.origin);
      const segments = [...new Set(requests
        .filter((request) => /^\/hls\/segment-[1-3]\.ts$/.test(request.path))
        .map((request) => request.path))].sort();
      if (!requests.some((request) => request.path === '/hls/master.m3u8') ||
          !requests.some((request) => request.path === '/hls/variant.m3u8') ||
          segments.length < 3) {
        throw new Error(
          `Remote HLS did not fetch the master, variant, and all VOD segments: ${JSON.stringify(segments)}.`,
        );
      }
      const frameEvidence = assertChangingFrames('remote HLS VOD', hlsFrames);
      return {
        sessionId: session.sessionId,
        state: session.state,
        returnCode: session.returnCode,
        callbackCount: session.callbackCount,
        handleReleased: session.handleReleased,
        segmentRequests: segments,
        ...frameEvidence,
      };
    });

    const response = await fetch(
      new URL('/hls/segment-1.ts?token=bridge-downloaded-ts', fixtureUrl.origin),
      {signal: AbortSignal.timeout(10000)},
    );
    if (!response.ok) {
      throw new Error(`Unable to download the TS fixture (HTTP ${response.status}).`);
    }
    const tsBytes = new Uint8Array(await response.arrayBuffer());
    if (!tsBytes.byteLength) throw new Error('The downloaded TS fixture is empty.');
    if (typeof module.FS?.writeFile !== 'function' ||
        typeof module.FS?.unlink !== 'function') {
      throw new Error('The Wasm module does not expose MEMFS writeFile/unlink.');
    }
    importedPath = '/tmp/wasm-bridge-playback.ts';
    module.FS.writeFile(importedPath, tsBytes);
    importedPathWritten = true;
    report.importedTs = {path: importedPath, bytes: tsBytes.byteLength};

    const tsFrames = [];
    await runCase('downloaded MEMFS TS natural EOF', async () => {
      const session = await runSession(
        module,
        callbackRecords,
        callbackTokens,
        callbackPointer,
        'downloaded TS natural EOF',
        `-autoexit ${importedPath}`,
        {frames: tsFrames},
      );
      report.handles.push(session);
      if (!session.handleReleased || session.cleanupErrors?.length) {
        throw new Error(`Downloaded TS session cleanup failed: ${JSON.stringify(session)}.`);
      }
      const frameEvidence = assertChangingFrames('downloaded TS natural EOF', tsFrames);
      return {
        sessionId: session.sessionId,
        state: session.state,
        returnCode: session.returnCode,
        callbackCount: session.callbackCount,
        handleReleased: session.handleReleased,
        ...frameEvidence,
      };
    });

    await runCase('ten downloaded MEMFS TS play-stop cycles', async () => {
      const sessions = [];
      for (let index = 0; index < 10; index += 1) {
        const session = await runSession(
          module,
          callbackRecords,
          callbackTokens,
          callbackPointer,
          `downloaded TS stop cycle ${index + 1}`,
          `-autoexit -loop 0 ${importedPath}`,
          {stopAfterProgress: true},
        );
        report.handles.push(session);
        sessions.push({
          sessionId: session.sessionId,
          state: session.state,
          returnCode: session.returnCode,
          callbackCount: session.callbackCount,
          handleReleased: session.handleReleased,
        });
        if (!session.handleReleased || session.cleanupErrors?.length) {
          throw new Error(`Stop cycle ${index + 1} cleanup failed: ${JSON.stringify(session)}.`);
        }
      }
      return {cycles: sessions.length, sessions};
    });

    await runCase('completion callbacks remain unique across all session handles', async () => {
      await delay(500);
      const callbacks = [...callbackRecords.entries()].map(([token, record]) => ({
        token,
        count: record.count,
        expectedHandle: record.expectedHandle,
        handles: record.handles,
      }));
      const invalid = callbacks.filter((record) =>
        record.count !== 1 ||
        record.expectedHandle === null ||
        record.handles.some((handle) => handle !== record.expectedHandle),
      );
      if (report.callbackViolations?.length || invalid.length) {
        throw new Error(
          `Completion callback ledger has violations: ${JSON.stringify({
            violations: report.callbackViolations ?? [],
            invalid,
          })}.`,
        );
      }
      return {callbacks: callbacks.length, uniqueUserDataTokens: true};
    });

  } catch (error) {
    report.status = 'failed';
    report.error = String(error?.stack || error);
    contractError = error;
  } finally {
    if (importedPath && importedPathWritten) {
      try {
        module.FS.unlink(importedPath);
        report.importedTs.cleaned = true;
      } catch (error) {
        report.cleanupErrors ??= [];
        report.cleanupErrors.push(`MEMFS unlink: ${String(error?.stack || error)}`);
      }
    }
    const callbacksSettled = !report.callbackViolations?.length &&
      [...callbackRecords.values()].every((record) =>
        record.count === 1 &&
        record.expectedHandle !== null &&
        record.handles.every((handle) => handle === record.expectedHandle),
      );
    if (callbacksSettled) {
      let freed = 0;
      for (const token of callbackTokens) {
        try {
          requireFunction(module, '_free')(token);
          freed += 1;
        } catch (error) {
          report.cleanupErrors ??= [];
          report.cleanupErrors.push(`completion user-data free: ${String(error?.stack || error)}`);
        }
      }
      report.callbackTokensFreed = freed;
    } else {
      report.callbackTokensRetained = callbackTokens.length;
    }
  }
  if (contractError || report.cleanupErrors?.length) {
    report.status = 'failed';
    if (!report.error) report.error = report.cleanupErrors.join(' | ');
    const failure = new Error('FFplay Wasm bridge playback contract failed.');
    failure.report = report;
    if (contractError) failure.cause = contractError;
    throw failure;
  }
  report.status = 'passed';
  return report;
}
