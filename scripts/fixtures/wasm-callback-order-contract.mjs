import { copyLatestFrame } from './wasm-bridge-playback.mjs';

const TERMINAL_STATES = new Set([2, 3]);
const RUNNING = 1;
const COMPLETE = 'end';
const SETTLE_MS = 400;

function requireFunction(module, name) {
  const value = module[name];
  if (typeof value !== 'function') {
    throw new Error(`Wasm export is unavailable: ${name}`);
  }
  return value.bind(module);
}

function number(value) {
  return typeof value === 'bigint' ? Number(value) : Number(value ?? 0);
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

/** Validates that invocation precedes callbacks and completion is terminal. */
export function assertCallbackOrderTrace(trace, {
  expectedSessionId,
  expectedUserData,
  requireStatistics = false,
  requireFrames = false,
  requireSessionSettlement = false,
} = {}) {
  const events = trace?.events;
  assert(Array.isArray(events) && events.length > 0, 'Callback trace is empty.');
  assert(events[0].type === 'start', 'The first event must be the invocation boundary.');
  assert(events.filter((event) => event.type === 'start').length === 1,
    'Callback trace must contain exactly one invocation boundary.');

  const ends = events.reduce((indices, event, index) => {
    if (event.type === COMPLETE) indices.push(index);
    return indices;
  }, []);
  assert(ends.length === 1, `Expected exactly one terminal callback, received ${ends.length}.`);
  assert(ends[0] === events.length - 1, 'A callback or readback arrived after completion.');

  const callbacks = events.filter((event) =>
    ['log', 'statistics', COMPLETE].includes(event.type));
  for (const event of callbacks) {
    assert(String(event.sessionId) === String(expectedSessionId),
      `${event.type} callback session ID ${event.sessionId} did not match ${expectedSessionId}.`);
    assert(number(event.userData) === number(expectedUserData),
      `${event.type} callback user data did not match its owned token.`);
  }

  const logs = events.filter((event) => event.type === 'log');
  assert(logs.length > 0, 'No native log callbacks were observed.');
  for (let index = 1; index < logs.length; index += 1) {
    assert(Number.isInteger(logs[index].sequence) &&
      logs[index].sequence > logs[index - 1].sequence,
    `Native log sequence did not increase (${logs[index - 1].sequence} -> ${logs[index].sequence}).`);
  }
  assert(Number.isInteger(logs[0].sequence) && logs[0].sequence >= 0,
    `Invalid first native log sequence ${logs[0].sequence}.`);
  if (requireStatistics) {
    assert(events.some((event) => event.type === 'statistics'),
      'FFmpeg produced no native statistics callback.');
  }
  if (requireFrames) {
    const frames = events.filter((event) => event.type === 'frame');
    assert(frames.length >= 2, `Expected changing FFplay frames, received ${frames.length}.`);
    let changed = false;
    for (let index = 1; index < frames.length; index += 1) {
      const current = BigInt(frames[index].generation);
      const previous = BigInt(frames[index - 1].generation);
      assert(current >= previous, 'FFplay frame generations moved backwards.');
      changed ||= current > previous;
    }
    assert(changed, 'FFplay frame readbacks did not observe a new generation.');
    assert(frames.every((frame) => frame.signature.nonBlackSamples > 0),
      'FFplay frame readback contained only black pixels.');
  }
  if (requireSessionSettlement) {
    const samples = trace.messagesInTransmitSamples;
    assert(Array.isArray(samples) && samples.length > 0,
      'No native messages-in-transmit samples were recorded.');
    assert(samples.every((count) => Number.isInteger(count) && count >= 0),
      `Native messages-in-transmit counter was negative or invalid: ${JSON.stringify(samples)}.`);
    assert(samples[samples.length - 1] === 0 && trace.messagesInTransmit === 0,
      `Native callback counter did not drain to zero: ${JSON.stringify(samples)}.`);
    assert(trace.nativeState === 2,
      `Native session did not complete successfully (state=${trace.nativeState}).`);
    assert(trace.returnCode === 0,
      `Native session returned ${trace.returnCode}, expected success.`);
    assert(trace.handleReleased === true,
      'Native session handle was not released after callback drain.');
  }
  return trace;
}

async function waitFor(description, predicate, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const result = predicate();
    if (result) return result;
    await delay(25);
  }
  throw new Error(`Timed out waiting for ${description} after ${timeoutMs} ms.`);
}

function allocateUtf8(module, value) {
  const size = requireFunction(module, 'lengthBytesUTF8')(value) + 1;
  const pointer = requireFunction(module, '_malloc')(size);
  if (!pointer) throw new Error('Unable to allocate native command memory.');
  try {
    requireFunction(module, 'stringToUTF8')(value, pointer, size);
    return pointer;
  } catch (error) {
    requireFunction(module, '_free')(pointer);
    throw error;
  }
}

function makeTrace(label, command) {
  return {
    label,
    events: [{type: 'start', phase: 'invocation', command}],
    messagesInTransmitSamples: [],
  };
}

function readPendingMessages(module, trace) {
  const pending = number(requireFunction(module, '_ffmpeg_kit_config_messages_in_transmit')(
    BigInt(trace.sessionId),
  ));
  trace.messagesInTransmitSamples.push(pending);
  trace.messagesInTransmit = pending;
  assert(pending >= 0,
    `${trace.label}: native pending-message counter underflowed (${pending}).`);
  return pending;
}

async function assertCounterRemainsDrained(module, trace, durationMs = SETTLE_MS) {
  const deadline = Date.now() + durationMs;
  do {
    const pending = readPendingMessages(module, trace);
    assert(pending === 0,
      `${trace.label}: pending-message counter left zero after completion (${pending}).`);
    await delay(25);
  } while (Date.now() < deadline);
}

async function runCase(module, context, {
  label,
  command,
  executeExport,
  executeArguments = [],
  executeCallbackArguments = [0, 0],
  sessionIdExport,
  cancel,
  requireStatistics = false,
  requireFrames = false,
}) {
  const trace = makeTrace(label, command);
  context.report.traces.push(trace);
  let commandPointer;
  let handle;
  let sessionId;
  let metadataPointer;
  let terminal = false;
  let primaryError;

  try {
    commandPointer = allocateUtf8(module, command);
    handle = number(requireFunction(module, executeExport)(
      commandPointer,
      ...executeCallbackArguments,
      ...executeArguments,
    ));
    assert(handle !== 0, `${label}: ${executeExport} returned a null handle.`);
    sessionId = String(requireFunction(module, sessionIdExport)(handle));
    assert(sessionId !== '0', `${label}: native session ID is zero.`);
    context.tracesBySessionId.set(sessionId, trace);
    trace.sessionId = sessionId;
    requireFunction(module, '_free')(commandPointer);
    commandPointer = undefined;

    const pointers = requireFrames
      ? (() => {
          metadataPointer = requireFunction(module, '_malloc')(24);
          assert(metadataPointer !== 0, 'Unable to allocate FFplay frame metadata.');
          return {
            width: metadataPointer,
            height: metadataPointer + 4,
            linesize: metadataPointer + 8,
            generation: metadataPointer + 16,
          };
        })()
      : undefined;
    const getState = requireFunction(module, '_ffmpeg_kit_session_get_state');
    const deadline = Date.now() + 15000;
    while (Date.now() < deadline &&
        !trace.events.some((event) => event.type === COMPLETE)) {
      readPendingMessages(module, trace);
      const state = number(getState(handle));
      if (requireFrames && state === RUNNING) {
        const frame = copyLatestFrame(module, pointers);
        if (frame) {
          const generation = BigInt(frame.generation);
          trace.events.push({
            type: 'frame',
            generation: generation.toString(),
            signature: frame.signature,
          });
        }
      }
      if (TERMINAL_STATES.has(state)) terminal = true;
      await delay(35);
    }
    await waitFor(`${label} native terminal state`, () => {
      const state = number(getState(handle));
      terminal ||= TERMINAL_STATES.has(state);
      return terminal ? state : null;
    }, 3000);
    await waitFor(`${label} completion callback`, () =>
      trace.events.some((event) => event.type === COMPLETE), 3000);
    trace.nativeState = number(getState(handle));
    assert(TERMINAL_STATES.has(trace.nativeState),
      `${label}: completion callback arrived before terminal native state.`);
    trace.returnCode = number(requireFunction(module, '_ffmpeg_kit_session_get_return_code')(handle));
    assert(trace.nativeState === 2 && trace.returnCode === 0,
      `${label}: representative command failed (state=${trace.nativeState}, return=${trace.returnCode}).`);
    await waitFor(`${label} callback queue to drain`, () => {
      return readPendingMessages(module, trace) === 0;
    }, 3000);

    await assertCounterRemainsDrained(module, trace);
    assertCallbackOrderTrace(trace, {
      expectedSessionId: sessionId,
      expectedUserData: context.userData,
      requireStatistics,
      requireFrames,
    });
  } catch (error) {
    primaryError = error;
  } finally {
    if (handle) {
      try {
        const state = number(requireFunction(module, '_ffmpeg_kit_session_get_state')(handle));
        if (!TERMINAL_STATES.has(state)) {
          cancel(sessionId, handle);
          await waitFor(`${label} cleanup to reach terminal state`, () => {
            const current = number(requireFunction(module, '_ffmpeg_kit_session_get_state')(handle));
            terminal ||= TERMINAL_STATES.has(current);
            return terminal ? current : null;
          }, 5000);
          await waitFor(`${label} cleanup completion callback`, () =>
            trace.events.some((event) => event.type === COMPLETE), 5000);
        }
        await assertCounterRemainsDrained(module, trace);
        const pending = readPendingMessages(module, trace);
        if (pending === 0) {
          requireFunction(module, '_ffmpeg_kit_handle_release')(handle);
          trace.handleReleased = true;
        } else {
          trace.handleRetainedForModuleTeardown = true;
          trace.messagesInTransmit = pending;
          primaryError ??= new Error(`${label}: cannot prove callback drain with pending count ${pending}.`);
        }
      } catch (cleanupError) {
        primaryError ??= cleanupError;
      }
    }
    if (metadataPointer) {
      try {
        requireFunction(module, '_free')(metadataPointer);
      } catch (cleanupError) {
        primaryError ??= cleanupError;
      }
    }
    if (commandPointer) {
      try {
        requireFunction(module, '_free')(commandPointer);
      } catch (cleanupError) {
        primaryError ??= cleanupError;
      }
    }
  }
  if (primaryError) throw primaryError;
  return trace;
}

/** Runs pinned public-ABI FFmpeg and FFplay cases with real global callbacks. */
export async function runCallbackOrderContract(module, fixtureOrigin, {includeFFprobe = false} = {}) {
  const report = {
    contract: 'wasm-callback-order',
    status: 'running',
    fixtureOrigin,
    traces: [],
    coverageGaps: [
      'Callback unregistration while native work is still emitting events is not exercised.',
      'Global callback function-table slots stay owned for the module lifetime by contract.',
    ],
  };
  const context = {
    report,
    tracesBySessionId: new Map(),
    unexpectedEvents: [],
    callbackErrors: [],
  };
  let userData;
  let logPointer;
  let statisticsPointer;
  let completePointer;
  let failure;

  const route = (type, sessionIdValue, fields = {}) => {
    const sessionId = String(sessionIdValue);
    const trace = context.tracesBySessionId.get(sessionId);
    const event = {type, sessionId, ...fields};
    if (trace) trace.events.push(event);
    else context.unexpectedEvents.push(event);
  };
  const logCallback = (sessionId, sequence, level, messagePointer, callbackUserData) => {
    try {
      const message = messagePointer ? module.UTF8ToString(messagePointer) : '';
      route('log', sessionId, {
        sequence: number(sequence),
        level: number(level),
        message,
        userData: callbackUserData,
      });
    } catch (error) {
      context.callbackErrors.push(String(error));
    } finally {
      if (messagePointer) {
        try {
          requireFunction(module, '_ffmpeg_kit_free')(messagePointer);
        } catch (error) {
          context.callbackErrors.push(String(error));
        }
      }
    }
  };
  const statisticsCallback = (sessionId, ...args) => {
    try {
      const callbackUserData = args.pop();
      route('statistics', sessionId, {userData: callbackUserData});
    } catch (error) {
      context.callbackErrors.push(String(error));
    }
  };
  const completeCallback = (sessionId, callbackUserData) => {
    // The native global completion dispatcher drains this session's pending
    // log/statistics callbacks before it invokes completion.
    route(COMPLETE, sessionId, {userData: callbackUserData});
  };

  try {
    assert(fixtureOrigin, 'A fixtureOrigin URL is required.');
    const origin = new URL(fixtureOrigin);
    assert(['http:', 'https:'].includes(origin.protocol),
      `Unsupported fixture origin protocol: ${origin.protocol}`);
    userData = requireFunction(module, '_malloc')(1);
    assert(userData !== 0, 'Unable to allocate global callback user data.');
    context.userData = userData;
    logPointer = requireFunction(module, 'addFunction')(logCallback, 'vjjipp');
    statisticsPointer = requireFunction(module, 'addFunction')(statisticsCallback, 'vjjjjddjddjjp');
    completePointer = requireFunction(module, 'addFunction')(completeCallback, 'vjp');

    requireFunction(module, '_ffmpeg_kit_config_enable_log_callback')(logPointer, userData);
    requireFunction(module, '_ffmpeg_kit_config_enable_statistics_callback')(statisticsPointer, userData);
    requireFunction(module, '_ffmpeg_kit_config_enable_ffmpeg_session_complete_callback')(completePointer, userData);
    const ffmpegCommand =
      '-hide_banner -loglevel info -stats_period 0.2 -re -f lavfi ' +
      '-i testsrc2=size=64x64:rate=12 -t 1.5 -f null -';
    const ffmpegTrace = await runCase(module, context, {
      label: 'realtime local lavfi FFmpeg',
      command: ffmpegCommand,
      executeExport: '_ffmpeg_kit_execute_async',
      sessionIdExport: '_ffmpeg_kit_session_get_session_id',
      cancel: (sessionId) => requireFunction(module, '_ffmpeg_kit_cancel_session')(BigInt(sessionId)),
      requireStatistics: true,
    });
    report.ffmpegSessionId = ffmpegTrace.sessionId;

    if (includeFFprobe) {
      const mp4Url = new URL('/media/progressive.mp4', origin).href;
      requireFunction(module, '_ffmpeg_kit_config_enable_ffprobe_session_complete_callback')(
        completePointer,
        userData,
      );
      const ffprobeTrace = await runCase(module, context, {
        label: 'remote progressive MP4 FFprobe',
        command: `-v debug -show_entries format=format_name -of json ${mp4Url}`,
        executeExport: '_ffprobe_kit_execute_async',
        sessionIdExport: '_ffmpeg_kit_session_get_session_id',
        cancel: (sessionId) => requireFunction(module, '_ffprobe_kit_cancel_session')(BigInt(sessionId)),
      });
      requireFunction(module, '_ffmpeg_kit_config_enable_ffprobe_session_complete_callback')(0, 0);
      report.ffprobeSessionId = ffprobeTrace.sessionId;
    }

    requireFunction(module, '_ffmpeg_kit_config_enable_statistics_callback')(0, 0);
    requireFunction(module, '_ffmpeg_kit_config_enable_ffmpeg_session_complete_callback')(0, 0);
    requireFunction(module, '_ffmpeg_kit_config_enable_ffplay_session_complete_callback')(completePointer, userData);
    const hlsUrl = new URL('/redirect/master.m3u8?token=callback-order', origin).href;
    const ffplayTrace = await runCase(module, context, {
      label: 'remote HLS FFplay',
      command: `-autoexit ${hlsUrl}`,
      executeExport: '_ffplay_kit_execute_async',
      executeArguments: [0n],
      sessionIdExport: '_ffmpeg_kit_session_get_session_id',
      cancel: (_sessionId, handle) => requireFunction(module, '_ffplay_kit_session_stop')(handle),
      requireFrames: true,
    });
    report.ffplaySessionId = ffplayTrace.sessionId;

    assert(context.unexpectedEvents.length === 0,
      `Callbacks arrived for untracked session IDs: ${JSON.stringify(context.unexpectedEvents)}.`);
    assert(context.callbackErrors.length === 0,
      `Callback adapter errors: ${context.callbackErrors.join('; ')}`);
    report.status = 'passed';
  } catch (error) {
    report.status = 'failed';
    report.error = String(error?.stack || error);
    failure = error;
  } finally {
    try {
      requireFunction(module, '_ffmpeg_kit_config_enable_log_callback')(0, 0);
      requireFunction(module, '_ffmpeg_kit_config_enable_statistics_callback')(0, 0);
      requireFunction(module, '_ffmpeg_kit_config_enable_ffmpeg_session_complete_callback')(0, 0);
      requireFunction(module, '_ffmpeg_kit_config_enable_ffplay_session_complete_callback')(0, 0);
    } catch (error) {
      report.cleanupError = String(error?.stack || error);
      report.status = 'failed';
    }
    for (const trace of report.traces) {
      try {
        if (trace.sessionId) {
          await waitFor(`session ${trace.sessionId} callback queue cleanup`, () =>
            readPendingMessages(module, trace) === 0, 5000);
          await assertCounterRemainsDrained(module, trace);
        }
        assertCallbackOrderTrace(trace, {
          expectedSessionId: trace.sessionId,
          expectedUserData: userData,
          requireStatistics: trace.label.startsWith('realtime local lavfi'),
          requireFrames: trace.label === 'remote HLS FFplay',
          requireSessionSettlement: true,
        });
      } catch (error) {
        report.lateOrInvalidTrace = String(error?.stack || error);
        report.status = 'failed';
      }
    }
    if (context.unexpectedEvents.length) {
      report.lateOrUnexpectedEvents = context.unexpectedEvents;
      report.status = 'failed';
    }
    if (context.callbackErrors.length) {
      report.callbackErrors = context.callbackErrors;
      report.status = 'failed';
    }
    const drained = report.traces.every((trace) => trace.messagesInTransmit === 0);
    if (userData && drained) {
      try {
        requireFunction(module, '_free')(userData);
      } catch (error) {
        report.cleanupError = String(error?.stack || error);
        report.status = 'failed';
      }
    } else if (userData) {
      report.userDataRetainedForModuleTeardown = true;
    }
  }
  if (report.status === 'failed') {
    const message = report.error ?? report.cleanupError ?? report.lateOrInvalidTrace ??
      JSON.stringify(report);
    throw Object.assign(new Error(message, {cause: failure}), {report});
  }
  return report;
}

/** Isolates debug startup accounting without changing registrations in flight. */
export async function runDebugMessageCounterContract(module, fixtureOrigin) {
  const previous = requireFunction(module, '_ffmpeg_kit_config_get_log_level')();
  requireFunction(module, '_ffmpeg_kit_config_set_log_level')(48);
  try {
    const report = await runCallbackOrderContract(module, fixtureOrigin, {includeFFprobe: true});
    report.contract = 'wasm-debug-message-counter';
    report.debugLogLevel = 48;
    return report;
  } finally {
    requireFunction(module, '_ffmpeg_kit_config_set_log_level')(previous);
  }
}
