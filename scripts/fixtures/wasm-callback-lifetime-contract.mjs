const RUNNING = 1;
const TERMINAL_STATES = new Set([2, 3]);
const TOKEN_A = 0x0a11ce;
const TOKEN_B = 0x0b0b;
const COMPLETE_TOKEN = 0x0c0ffee;

function requireFunction(module, name) {
  const value = module[name];
  if (typeof value !== 'function') throw new Error(`Wasm export is unavailable: ${name}`);
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

export function assertCallbackLifetimeTrace(trace, {
  expectedSessionId,
  tokenA = TOKEN_A,
  tokenB = TOKEN_B,
} = {}) {
  const events = trace?.events;
  assert(Array.isArray(events) && events[0]?.type === 'invoke',
    'Callback lifetime trace must start with invocation.');
  assert(trace.nativeStateAtUnregister === RUNNING,
    'Native work was not running at the unregistration boundary.');
  const unregister = events.findIndex((event) => event.type === 'unregister');
  const registerB = events.findIndex((event) => event.type === 'register-b');
  assert(events.filter((event) => event.type === 'unregister').length === 1 &&
    events.filter((event) => event.type === 'register-b').length === 1,
  'Callback trace must contain one disable and one replacement registration.');
  assert(unregister > 0 && registerB > unregister,
    'The log callback must be disabled before the replacement is registered.');
  const unregistered = events[unregister];
  const registered = events[registerB];
  assert(unregistered.slotA !== registered.slotB,
    'The replacement callback aliased the still-owned old table slot.');
  assert(tokenA !== tokenB && unregistered.tokenA === tokenA &&
    registered.tokenB === tokenB, 'Callback user-data tokens are not distinct and owned.');

  const ends = events.reduce((items, event, index) => {
    if (event.type === 'end') items.push(index);
    return items;
  }, []);
  assert(ends.length === 1, `Expected one global completion callback, received ${ends.length}.`);
  assert(ends[0] === events.length - 1, 'An owned callback arrived after native completion.');

  const logs = events.filter((event) => event.type === 'log');
  const oldBefore = [];
  const oldAfter = [];
  const newAfter = [];
  for (let index = 0; index < events.length; index += 1) {
    const event = events[index];
    if (event.type !== 'log') continue;
    if (event.owner === 'A' && index < unregister) oldBefore.push(event);
    if (event.owner === 'A' && index > unregister) oldAfter.push(event);
    if (event.owner === 'B' && index > registerB) newAfter.push(event);
  }
  assert(oldBefore.length > 0, 'No owned log arrived through callback A before unregistration.');
  assert(oldAfter.length > 0,
    'No queued callback from the old registration arrived after unregistration.');
  assert(newAfter.length > 0, 'No owned log arrived through replacement callback B.');
  for (const event of logs) {
    assert(event.owner === 'A' || event.owner === 'B', `Unknown callback owner ${event.owner}.`);
    assert(String(event.sessionId) === String(expectedSessionId),
      `Log callback session ID ${event.sessionId} did not match ${expectedSessionId}.`);
    const expectedToken = event.owner === 'A' ? tokenA : tokenB;
    assert(event.userData === expectedToken,
      `Callback ${event.owner} received the wrong user-data token.`);
    assert(Number.isInteger(event.messageLength) && event.messageLength >= 0,
      'A native log payload length was invalid.');
  }
  for (let index = 1; index < logs.length; index += 1) {
    assert(logs[index].sequence > logs[index - 1].sequence,
      `Native log sequence did not increase (${logs[index - 1].sequence} -> ${logs[index].sequence}).`);
  }
  assert(String(events[ends[0]].sessionId) === String(expectedSessionId),
    'Completion callback session ID did not match the active session.');
  assert(events[ends[0]].userData === COMPLETE_TOKEN,
    'Completion callback received the wrong user-data token.');
  assert(trace.messagesInTransmit === 0,
    `Native messages remain in transmit: ${trace.messagesInTransmit}.`);
  return trace;
}

async function waitFor(description, predicate, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const value = predicate();
    if (value) return value;
    await delay(20);
  }
  throw new Error(`Timed out waiting for ${description} after ${timeoutMs} ms.`);
}

function allocateUtf8(module, value) {
  const size = requireFunction(module, 'lengthBytesUTF8')(value) + 1;
  const pointer = requireFunction(module, '_malloc')(size);
  if (!pointer) throw new Error('Unable to allocate FFmpeg command memory.');
  try {
    requireFunction(module, 'stringToUTF8')(value, pointer, size);
    return pointer;
  } catch (error) {
    requireFunction(module, '_free')(pointer);
    throw error;
  }
}

/** Proves queued owned logs retain callback A across global unregistration. */
export async function runCallbackLifetimeContract(module) {
  const report = {
    contract: 'wasm-callback-lifetime',
    status: 'running',
    limitations: ['Callback slots remain owned until module teardown.'],
  };
  const trace = {events: [{type: 'invoke', phase: 'native command invocation', at: performance.now()}]};
  report.trace = trace;
  const failures = [];
  let handle;
  let sessionId;
  let commandPointer;
  let oldLogPointer;
  let newLogPointer;
  let completePointer;
  let oldLogCount = 0;
  let newLogCount = 0;
  let completeCount = 0;
  let oldLevel;
  let levelChanged = false;
  let primaryError;
  const routeLog = (owner, sessionValue, sequence, messagePointer, userData, token) => {
    try {
      const message = messagePointer ? module.UTF8ToString(messagePointer) : '';
      if (number(userData) !== token) {
        failures.push(`Callback ${owner} received user data ${number(userData)} instead of ${token}.`);
      }
      if (String(sessionValue) !== String(sessionId)) {
        failures.push(`Callback ${owner} received session ${sessionValue} instead of ${sessionId}.`);
      }
      if (owner === 'A') oldLogCount += 1;
      else newLogCount += 1;
      trace.events.push({
        type: 'log',
        at: performance.now(),
        owner,
        sessionId: String(sessionValue),
        sequence: number(sequence),
        userData: number(userData),
        messageLength: message.length,
        messageSample: message.slice(0, 72),
      });
    } catch (error) {
      failures.push(String(error));
    } finally {
      if (messagePointer) {
        try {
          requireFunction(module, '_ffmpeg_kit_free')(messagePointer);
        } catch (error) {
          failures.push(`Unable to free owned log payload: ${String(error)}`);
        }
      }
    }
  };
  const oldLog = (sid, sequence, _level, message, userData) =>
    routeLog('A', sid, sequence, message, userData, TOKEN_A);
  const newLog = (sid, sequence, _level, message, userData) =>
    routeLog('B', sid, sequence, message, userData, TOKEN_B);
  const complete = (sid, userData) => {
    completeCount += 1;
    if (number(userData) !== COMPLETE_TOKEN) failures.push('Completion user-data token mismatch.');
    trace.events.push({
      type: 'end', at: performance.now(), sessionId: String(sid), userData: number(userData),
    });
  };

  try {
    oldLevel = requireFunction(module, '_ffmpeg_kit_config_get_log_level')();
    requireFunction(module, '_ffmpeg_kit_config_set_log_level')(48);
    levelChanged = true;
    oldLogPointer = requireFunction(module, 'addFunction')(oldLog, 'vjjipp');
    completePointer = requireFunction(module, 'addFunction')(complete, 'vjp');
    requireFunction(module, '_ffmpeg_kit_config_enable_log_callback')(oldLogPointer, TOKEN_A);
    requireFunction(module, '_ffmpeg_kit_config_enable_ffmpeg_session_complete_callback')(
      completePointer,
      COMPLETE_TOKEN,
    );

    const command =
      '-hide_banner -loglevel debug -debug_ts -re -f lavfi ' +
      '-i testsrc2=size=64x64:rate=20 -t 3 -f null -';
    commandPointer = allocateUtf8(module, command);
    handle = number(requireFunction(module, '_ffmpeg_kit_execute_async')(commandPointer, 0, 0));
    assert(handle !== 0, 'ffmpeg_kit_execute_async returned a null handle.');
    requireFunction(module, '_free')(commandPointer);
    commandPointer = undefined;
    sessionId = String(requireFunction(module, '_ffmpeg_kit_session_get_session_id')(handle));
    assert(sessionId !== '0', 'Native session ID is zero.');
    report.sessionId = sessionId;

    await waitFor('an owned log and Running state', () => {
      const state = number(requireFunction(module, '_ffmpeg_kit_session_get_state')(handle));
      return state === RUNNING && oldLogCount > 0;
    }, 5000);
    trace.events.push({type: 'busy-start', at: performance.now()});
    const pauseUntil = performance.now() + 600;
    while (performance.now() < pauseUntil) { /* Let the native worker queue callbacks. */ }
    trace.events.push({type: 'busy-end', at: performance.now()});

    trace.nativeStateAtUnregister = number(requireFunction(module, '_ffmpeg_kit_session_get_state')(handle));
    assert(trace.nativeStateAtUnregister === RUNNING,
      'Native work stopped before the unregistration boundary.');
    requireFunction(module, '_ffmpeg_kit_config_enable_log_callback')(0, 0);
    trace.events.push({
      type: 'unregister', at: performance.now(), slotA: oldLogPointer, tokenA: TOKEN_A,
    });
    newLogPointer = requireFunction(module, 'addFunction')(newLog, 'vjjipp');
    assert(newLogPointer !== oldLogPointer, 'The retained callback slot was reused.');
    trace.events.push({
      type: 'register-b', at: performance.now(), slotB: newLogPointer, tokenB: TOKEN_B,
    });
    requireFunction(module, '_ffmpeg_kit_config_enable_log_callback')(newLogPointer, TOKEN_B);

    await waitFor('native completion and post-swap callbacks', () =>
      completeCount === 1 && oldLogCount > 1 && newLogCount > 0, 10000);
    await delay(400);
    const state = number(requireFunction(module, '_ffmpeg_kit_session_get_state')(handle));
    assert(TERMINAL_STATES.has(state), `Completion arrived in nonterminal state ${state}.`);
    trace.nativeState = state;
    trace.returnCode = number(requireFunction(module, '_ffmpeg_kit_session_get_return_code')(handle));
    assert(state === 2 && trace.returnCode === 0,
      `Representative FFmpeg command failed (state=${state}, return=${trace.returnCode}).`);
    trace.messagesInTransmit = number(
      requireFunction(module, '_ffmpeg_kit_config_messages_in_transmit')(BigInt(sessionId)),
    );
    assertCallbackLifetimeTrace(trace, {expectedSessionId: sessionId});
    assert(failures.length === 0, failures.join('; '));
    report.nativeState = state;
    const unregisterIndex = trace.events.findIndex((event) => event.type === 'unregister');
    report.oldLogsBeforeUnregister = trace.events.filter((event, index) =>
      event.type === 'log' && event.owner === 'A' && index < unregisterIndex).length;
    report.oldLogsAfterUnregister = trace.events.filter((event, index) =>
      event.type === 'log' && event.owner === 'A' && index > unregisterIndex).length;
    report.newLogsAfterRegister = newLogCount;
    const sequences = trace.events.filter((event) => event.type === 'log')
      .map((event) => event.sequence);
    report.logSequence = {first: sequences[0], last: sequences.at(-1), count: sequences.length};
    report.timeline = trace.events.filter((event) =>
      ['invoke', 'busy-start', 'busy-end', 'unregister', 'register-b', 'end'].includes(event.type))
      .map(({type, at}) => ({type, at}));
  } catch (error) {
    primaryError = error;
    report.error = String(error?.stack || error);
  } finally {
    if (handle) {
      try {
        const state = number(requireFunction(module, '_ffmpeg_kit_session_get_state')(handle));
        if (!TERMINAL_STATES.has(state)) {
          requireFunction(module, '_ffmpeg_kit_cancel_session')(BigInt(sessionId));
          await waitFor('cancellation to reach terminal state', () => {
            const current = number(requireFunction(module, '_ffmpeg_kit_session_get_state')(handle));
            return TERMINAL_STATES.has(current) ? current : null;
          }, 7000);
        }
        if (completeCount === 0) await waitFor('completion during cleanup', () => completeCount === 1, 5000);
        await waitFor('native messages to drain', () =>
          number(requireFunction(module, '_ffmpeg_kit_config_messages_in_transmit')(BigInt(sessionId))) === 0,
        5000);
        trace.messagesInTransmit = number(
          requireFunction(module, '_ffmpeg_kit_config_messages_in_transmit')(BigInt(sessionId)),
        );
        requireFunction(module, '_ffmpeg_kit_handle_release')(handle);
        report.handleReleased = true;
      } catch (error) {
        report.cleanupError = String(error?.stack || error);
      }
    }
    try {
      requireFunction(module, '_ffmpeg_kit_config_enable_log_callback')(0, 0);
      requireFunction(module, '_ffmpeg_kit_config_enable_ffmpeg_session_complete_callback')(0, 0);
      if (levelChanged) requireFunction(module, '_ffmpeg_kit_config_set_log_level')(oldLevel);
    } catch (error) {
      report.cleanupError = String(error?.stack || error);
    }
    await delay(400);
    if (trace.events.some((event) => event.type === 'end')) {
      try {
        assertCallbackLifetimeTrace(trace, {expectedSessionId: sessionId});
      } catch (error) {
        report.lateCallbackError = String(error?.stack || error);
      }
    }
    if (commandPointer) {
      try {
        requireFunction(module, '_free')(commandPointer);
      } catch (error) {
        report.cleanupError = String(error?.stack || error);
      }
    }
    report.callbackErrors = failures;
    if (report.error || report.cleanupError || report.lateCallbackError || failures.length ||
        !report.handleReleased || trace.messagesInTransmit !== 0) {
      report.status = 'failed';
    } else {
      report.status = 'passed';
    }
  }
  if (report.status !== 'passed') {
    const message = report.error ?? report.cleanupError ?? report.lateCallbackError ??
      (failures.join('; ') || 'Callback lifetime contract failed.');
    throw Object.assign(new Error(message), {
      cause: primaryError,
      report,
    });
  }
  return report;
}
