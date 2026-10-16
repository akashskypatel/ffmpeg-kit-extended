import {runSession} from './wasm-bridge-playback.mjs';

const ARTIFACT_ROLE = 'same-source-diagnostic-heap-only';
const SOURCE_COMMIT = '779cecd74bb7b10ab9f0d28c1e14e2a440eacd4a';
const HEAP_EXPORT = '_ffmpeg_kit_test_http_io_heap_snapshot';
const METRIC = 'mallinfo().uordblks';
const FIXTURE_PATH = '/tmp/wasm-heap-baseline.ts';
const COMMAND = `-autoexit ${FIXTURE_PATH}`;
const POLICY = Object.freeze({
  warmupCycles: 3,
  measuredCycles: 10,
  settleMs: 500,
  samplesPerSettlement: 5,
  sampleIntervalMs: 50,
  maxAboveBaselineBytes: 64 * 1024,
  maxTailDriftBytes: 16 * 1024,
  tailDriftDefinition: 'mean last three cycle maxima minus mean first three cycle maxima',
  metric: METRIC,
});

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function requireFunction(module, name) {
  const value = module?.[name];
  assert(typeof value === 'function', `Wasm export is unavailable: ${name}`);
  return value.bind(module);
}

function isFiniteHeapSample(value) {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0;
}

function maximum(values) {
  return Math.max(...values);
}

function mean(values) {
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function validateIdentity(identity) {
  assert(identity && typeof identity === 'object', 'Diagnostic artifact identity is required.');
  assert(identity.artifactRole === ARTIFACT_ROLE,
    `Expected artifact role ${ARTIFACT_ROLE}, received ${identity.artifactRole}.`);
  assert(identity.sourceCommit === SOURCE_COMMIT,
    `Expected same-source commit ${SOURCE_COMMIT}, received ${identity.sourceCommit}.`);
  for (const key of ['wasmSha256', 'loaderSha256']) {
    assert(typeof identity[key] === 'string' && /^[a-f0-9]{64}$/i.test(identity[key]),
      `Diagnostic artifact identity has an invalid ${key}.`);
  }
  assert(identity.productionPinUsed === false,
    'Heap measurements must use the separate diagnostic artifact, not the production pin.');
}

function validateSession(run, label, expectedCommand) {
  assert(run && run.name, `${label} is missing its native FFplay session record.`);
  assert(run.command === expectedCommand, `${label} used a different FFplay command.`);
  assert(String(run.sessionId) !== '0' && Number(run.handle) > 0,
    `${label} has no native session identity or handle.`);
  assert(run.state === 2 && run.returnCode === 0,
    `${label} failed (state=${run.state}, return=${run.returnCode}).`);
  assert(run.callbackCount === 1 && run.callbackObservedCount === 1 &&
    Array.isArray(run.callbackHandles) && run.callbackHandles.length === 1 &&
    Number(run.callbackHandles[0]) === Number(run.handle),
  `${label} did not settle exactly one completion callback for its returned handle.`);
  assert(run.handleReleased === true && (!run.cleanupErrors || run.cleanupErrors.length === 0),
    `${label} native handle was not released cleanly.`);
  assert(run.messagesInTransmit === 0,
    `${label} left ${run.messagesInTransmit} native messages in transmit.`);
  assert(run.callbackTokenFreed === true,
    `${label} per-session callback token was not freed after callback drain.`);
  assert(run.sessionHistoryCleared === true && run.historyCountAfterClear === 0,
    `${label} native session history was not cleared before measurement.`);
}

/** Pure acceptance oracle for the fixed diagnostic-artifact heap policy. */
export function assertNativeHeapBaseline(report) {
  assert(report && report.status === 'passed',
    `Heap report is not a completed successful run (status=${report?.status}).`);
  validateIdentity(report.artifactIdentity);
  assert(report.heapSnapshotExport === HEAP_EXPORT && report.hookPresent === true,
    `The existing diagnostic hook ${HEAP_EXPORT} was not used.`);
  assert(report.metric === METRIC, `Expected native heap metric ${METRIC}.`);
  for (const [key, value] of Object.entries(POLICY)) {
    assert(report.policy?.[key] === value,
      `Heap policy ${key} was ${report.policy?.[key]}, expected ${value}.`);
  }
  assert(report.fixture?.path === FIXTURE_PATH &&
    Number.isInteger(report.fixture.bytes) && report.fixture.bytes > 0 &&
    report.fixture.importedBeforeWarmupAndBaseline === true,
  'One nonempty imported TS fixture must be held constant before warmup and baseline.');
  assert(report.callbackSlotRetained === true,
    'The single Wasm completion callback slot was not retained across all cycles.');
  assert(Array.isArray(report.warmups) && report.warmups.length === POLICY.warmupCycles,
    `Expected exactly ${POLICY.warmupCycles} warm-up cycles.`);
  assert(Array.isArray(report.baselineSamples) &&
    report.baselineSamples.length === POLICY.samplesPerSettlement,
  `Expected ${POLICY.samplesPerSettlement} native baseline samples.`);
  assert(report.baselineSamples.every(isFiniteHeapSample),
    'Baseline samples must be finite nonnegative native allocation values.');
  assert(Array.isArray(report.cycles) && report.cycles.length === POLICY.measuredCycles,
    `Expected exactly ${POLICY.measuredCycles} measured cycles.`);
  assert(report.cleanup?.fileUnlinked === true && report.cleanup?.finalHistoryCleared === true &&
    report.cleanup?.historyCountAfterClear === 0 &&
    report.cleanup?.callbackTokensFreed === POLICY.warmupCycles + POLICY.measuredCycles &&
    report.cleanup?.callbackSlotRetained === true,
  'Final fixture, native history, callback-token, or callback-slot cleanup was incomplete.');
  assert(Array.isArray(report.callbackViolations) && report.callbackViolations.length === 0,
    `Unexpected completion callback ownership events: ${JSON.stringify(report.callbackViolations)}.`);

  const baselineMaximum = maximum(report.baselineSamples);
  assert(report.baselineMaximumBytes === baselineMaximum,
    'Recorded baseline maximum does not match its five samples.');
  const baselineMaximumBytes = report.baselineMaximumBytes;

  const allRuns = [...report.warmups, ...report.cycles.map((cycle) => cycle.run)];
  assert(allRuns.length === POLICY.warmupCycles + POLICY.measuredCycles,
    'Warm-up and measured run records are incomplete.');
  allRuns.forEach((run, index) => validateSession(run, `FFplay cycle ${index + 1}`, COMMAND));

  const cycleMaxima = [];
  for (let index = 0; index < report.cycles.length; index += 1) {
    const cycle = report.cycles[index];
    assert(cycle.index === index + 1, `Measured cycle index ${cycle.index} is out of order.`);
    assert(Array.isArray(cycle.samples) && cycle.samples.length === POLICY.samplesPerSettlement,
      `Measured cycle ${cycle.index} does not contain exactly five samples.`);
    assert(cycle.samples.every(isFiniteHeapSample),
      `Measured cycle ${cycle.index} has a nonfinite or negative sample.`);
    const cycleMaximum = maximum(cycle.samples);
    assert(cycle.maximumBytes === cycleMaximum,
      `Measured cycle ${cycle.index} maximum does not match its samples.`);
    assert(cycleMaximum <= baselineMaximumBytes + POLICY.maxAboveBaselineBytes,
      `Measured cycle ${cycle.index} exceeded the baseline band by ` +
      `${cycleMaximum - baselineMaximumBytes} bytes (limit ${POLICY.maxAboveBaselineBytes}).`);
    cycleMaxima.push(cycleMaximum);
  }

  const tailDrift = mean(cycleMaxima.slice(-3)) - mean(cycleMaxima.slice(0, 3));
  assert(Number.isFinite(report.tailDriftBytes) &&
    Math.abs(report.tailDriftBytes - tailDrift) < 1e-7,
  'Recorded tail drift does not match the first and last three cycle maxima.');
  assert(tailDrift <= POLICY.maxTailDriftBytes,
    `Ten-cycle tail drift was ${tailDrift} bytes (limit ${POLICY.maxTailDriftBytes}).`);

  assert(Array.isArray(report.callbackEvents) && report.callbackEvents.length === allRuns.length,
    'Expected one recorded native completion callback for each FFplay cycle.');
  for (let index = 0; index < allRuns.length; index += 1) {
    const run = allRuns[index];
    const event = report.callbackEvents[index];
    assert(event.runIndex === index && Number(event.handle) === Number(run.handle) &&
      Number(event.userData) === Number(run.callbackToken),
    `Completion callback ${index + 1} did not match its run, handle, and user-data token.`);
  }
  return report;
}

function isNotFound(error) {
  return error?.code === 'ENOENT' ||
    (error?.name === 'ErrnoError' && error?.errno === 44);
}

async function waitFor(description, predicate, timeoutMs = 5000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const value = await predicate();
    if (value) return value;
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error(`Timed out waiting for ${description} after ${timeoutMs} ms.`);
}

function sampleHeap(module) {
  const value = numberResult(requireFunction(module, HEAP_EXPORT)());
  assert(isFiniteHeapSample(value), `Native heap snapshot returned invalid value ${value}.`);
  return value;
}

function numberResult(value) {
  return typeof value === 'bigint' ? Number(value) : Number(value ?? 0);
}

async function sampleAfterSettlement(module) {
  await new Promise((resolve) => setTimeout(resolve, POLICY.settleMs));
  const samples = [];
  for (let index = 0; index < POLICY.samplesPerSettlement; index += 1) {
    samples.push(sampleHeap(module));
    if (index + 1 < POLICY.samplesPerSettlement) {
      await new Promise((resolve) => setTimeout(resolve, POLICY.sampleIntervalMs));
    }
  }
  return samples;
}

function freeCallbackToken(module, callbackTokens, callbackRecords, run) {
  const token = numberResult(run.callbackToken);
  requireFunction(module, '_free')(token);
  const index = callbackTokens.indexOf(token);
  if (index >= 0) callbackTokens.splice(index, 1);
  callbackRecords.delete(token);
  run.callbackTokenFreed = true;
  return true;
}

/** Verifies the void clear operation through its owned, null-terminated readback. */
export function clearNativeSessionHistory(module) {
  requireFunction(module, '_ffmpeg_kit_clear_sessions')();
  const array = numberResult(requireFunction(module, '_ffmpeg_kit_get_sessions')());
  assert(array > 0, 'Native session-history readback failed.');
  let count = 0;
  try {
    // Native history is capped at 1000 entries. Release any unexpected handles
    // before rejecting nonempty history, as well as the array itself.
    for (; count <= 1000; count += 1) {
      const handle = module.HEAPU32[(array >>> 2) + count];
      if (handle === 0) break;
      requireFunction(module, '_ffmpeg_kit_handle_release')(handle);
    }
    assert(count === 0, `Native session history was not empty after clear (${count} entries).`);
    return count;
  } finally {
    requireFunction(module, '_ffmpeg_kit_free')(array);
  }
}

/** Runs the fixed B08 policy on one imported local TS and the test-only mallinfo hook. */
export async function runHeapBaselineContract(module, fixtureOrigin, artifactIdentity) {
  const report = {
    contract: 'wasm-heap-baseline',
    status: 'running',
    artifactIdentity: {...artifactIdentity},
    heapSnapshotExport: HEAP_EXPORT,
    hookPresent: typeof module?.[HEAP_EXPORT] === 'function',
    metric: METRIC,
    policy: {...POLICY},
    fixture: {path: FIXTURE_PATH, bytes: 0, importedBeforeWarmupAndBaseline: false},
    callbackSlotRetained: false,
    nativeRuntimeVersion: null,
    warmups: [],
    baselineSamples: [],
    baselineMaximumBytes: null,
    cycles: [],
    tailDriftBytes: null,
    sessions: [],
    callbackEvents: [],
    callbackViolations: [],
    cleanup: {
      fileUnlinked: false,
      finalHistoryCleared: false,
      callbackTokensFreed: 0,
      callbackSlotRetained: false,
    },
    cleanupErrors: [],
  };
  const callbackRecords = new Map();
  const callbackTokens = [];
  let callbackPointer;
  let importedPathWritten = false;
  let activeRunIndex = null;
  let failure;

  const callback = (handleValue, userDataValue) => {
    const handle = numberResult(handleValue);
    const userData = numberResult(userDataValue);
    const record = callbackRecords.get(userData);
    if (!record) {
      report.callbackViolations.push({runIndex: activeRunIndex, handle, userData, error: 'unknown token'});
    } else {
      record.count += 1;
      record.handles.push(handle);
    }
    report.callbackEvents.push({runIndex: activeRunIndex, handle, userData});
  };

  async function settleAndClear(run) {
    if (run.sessionId !== null && run.sessionId !== undefined) {
      await waitFor(
        `${run.name} callback messages to drain`,
        () => {
          const pending = numberResult(requireFunction(module, '_ffmpeg_kit_config_messages_in_transmit')(
            BigInt(run.sessionId),
          ));
          assert(pending >= 0, `${run.name} pending-message counter underflowed (${pending}).`);
          return pending === 0;
        },
      );
      run.messagesInTransmit = 0;
    } else {
      run.messagesInTransmit = 0;
    }

    const record = callbackRecords.get(numberResult(run.callbackToken));
    run.callbackObservedCount = record?.count ?? 0;
    run.callbackHandles = record ? [...record.handles] : [];
    const canReleaseToken = run.handleReleased === true && run.messagesInTransmit === 0 &&
      run.callbackObservedCount === 1 && run.callbackHandles.length === 1 &&
      Number(run.callbackHandles[0]) === Number(run.handle);
    if (canReleaseToken) {
      if (freeCallbackToken(module, callbackTokens, callbackRecords, run)) {
        report.cleanup.callbackTokensFreed += 1;
      }
    } else {
      run.callbackTokenFreed = false;
    }

    if (run.handleReleased === true && run.messagesInTransmit === 0 && canReleaseToken) {
      run.historyCountAfterClear = clearNativeSessionHistory(module);
      run.sessionHistoryCleared = true;
    } else {
      run.sessionHistoryCleared = false;
    }
  }

  async function executeCycle(name, runIndex) {
    activeRunIndex = runIndex;
    let run;
    try {
      run = await runSession(
        module,
        callbackRecords,
        callbackTokens,
        callbackPointer,
        name,
        COMMAND,
        {stopAfterProgress: true},
      );
    } catch (error) {
      run = error?.session;
      if (run && !report.sessions.includes(run)) report.sessions.push(run);
      activeRunIndex = null;
      if (run) {
        try {
          await settleAndClear(run);
        } catch (cleanupError) {
          run.heapCleanupError = String(cleanupError?.stack || cleanupError);
        }
      }
      throw error;
    }
    activeRunIndex = null;
    report.sessions.push(run);
    await settleAndClear(run);
    validateSession(run, name, COMMAND);
    return run;
  }

  try {
    validateIdentity(artifactIdentity);
    assert(typeof fixtureOrigin === 'string', 'A local fixture origin is required.');
    const origin = new URL(fixtureOrigin);
    assert(origin.protocol === 'http:' || origin.protocol === 'https:',
      `Unsupported fixture origin protocol ${origin.protocol}.`);
    assert(report.hookPresent,
      `The diagnostic artifact must export ${HEAP_EXPORT}; production-pin fallback is not allowed.`);
    validateIdentity(report.artifactIdentity);

    const fs = module.FS;
    assert(fs && typeof fs.writeFile === 'function' && typeof fs.unlink === 'function' &&
      typeof fs.stat === 'function', 'The diagnostic module lacks required MEMFS operations.');
    try {
      fs.stat(FIXTURE_PATH);
      throw new Error(`Refusing to overwrite existing heap fixture ${FIXTURE_PATH}.`);
    } catch (error) {
      if (String(error?.message).startsWith('Refusing to overwrite')) throw error;
      if (!isNotFound(error)) throw error;
    }

    const response = await fetch(new URL('/hls/segment-1.ts?token=wasm-heap-baseline', origin), {
      signal: AbortSignal.timeout(10000),
    });
    assert(response.ok, `Unable to fetch the local TS fixture (HTTP ${response.status}).`);
    const bytes = new Uint8Array(await response.arrayBuffer());
    assert(bytes.byteLength > 0, 'The local TS fixture is empty.');
    fs.writeFile(FIXTURE_PATH, bytes);
    importedPathWritten = true;
    report.fixture.bytes = bytes.byteLength;
    report.fixture.importedBeforeWarmupAndBaseline = true;
    report.fixture.sha256 = [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))]
      .map((value) => value.toString(16).padStart(2, '0')).join('');
    bytes.fill(0);

    callbackPointer = requireFunction(module, 'addFunction')(callback, 'vpp');
    assert(callbackPointer > 0, 'Unable to register the module-lifetime FFplay callback.');
    report.callbackSlotRetained = true;
    report.cleanup.callbackSlotRetained = true;

    for (let index = 0; index < POLICY.warmupCycles; index += 1) {
      const run = await executeCycle(`heap warm-up ${index + 1}`, report.sessions.length);
      report.warmups.push(run);
    }

    report.baselineSamples = await sampleAfterSettlement(module);
    report.baselineMaximumBytes = maximum(report.baselineSamples);

    for (let index = 0; index < POLICY.measuredCycles; index += 1) {
      const run = await executeCycle(`heap measured cycle ${index + 1}`, report.sessions.length);
      const samples = await sampleAfterSettlement(module);
      report.cycles.push({index: index + 1, run, samples, maximumBytes: maximum(samples)});
    }
    const maxima = report.cycles.map((cycle) => cycle.maximumBytes);
    report.tailDriftBytes = mean(maxima.slice(-3)) - mean(maxima.slice(0, 3));
    report.status = 'passed';
  } catch (error) {
    failure = error;
    report.status = 'failed';
    report.error = String(error?.stack || error);
  } finally {
    activeRunIndex = null;
    if (importedPathWritten) {
      try {
        module.FS.unlink(FIXTURE_PATH);
        report.cleanup.fileUnlinked = true;
      } catch (error) {
        report.cleanupErrors.push(`Unable to unlink ${FIXTURE_PATH}: ${String(error?.stack || error)}`);
      }
    }
    // A token whose session never reached a known terminal callback boundary stays
    // allocated: freeing it would risk a native callback using stale user data.
    for (const token of [...callbackTokens]) {
      const record = callbackRecords.get(token);
      if (record?.expectedHandle == null && record.count === 0) {
        try {
          requireFunction(module, '_free')(token);
          callbackTokens.splice(callbackTokens.indexOf(token), 1);
          callbackRecords.delete(token);
          report.cleanup.callbackTokensFreed += 1;
        } catch (error) {
          report.cleanupErrors.push(`Unable to free unused callback token ${token}: ${String(error?.stack || error)}`);
        }
      }
    }
    try {
      report.cleanup.historyCountAfterClear = clearNativeSessionHistory(module);
      report.cleanup.finalHistoryCleared = true;
    } catch (error) {
      report.cleanupErrors.push(`Unable to clear final native session history: ${String(error?.stack || error)}`);
    }
    report.cleanup.retainedCallbackTokens = callbackTokens.length;
    if (report.status === 'passed' && report.cleanupErrors.length === 0) {
      try {
        assertNativeHeapBaseline(report);
      } catch (error) {
        report.status = 'failed';
        report.error = String(error?.stack || error);
      }
    } else if (report.status === 'passed') {
      report.status = 'failed';
      report.error = report.cleanupErrors.join(' | ');
    }
  }

  if (report.status !== 'passed') {
    const error = new Error(report.error ?? report.cleanupErrors.join(' | ') ?? 'Native heap baseline contract failed.');
    error.name = 'NativeHeapBaselineError';
    error.report = report;
    error.cause = failure;
    throw error;
  }
  return report;
}
