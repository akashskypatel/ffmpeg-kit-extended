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

function summarizeTrace(report, trace) {
  const events = trace.events;
  const unregisterIndex = events.findIndex((event) => event.type === 'unregister');
  const registerIndex = events.findIndex((event) => event.type === 'register-b');
  const transitionIndex = events.findIndex((event) =>
    event.type === 'callback-begin' && event.owner === 'A' && event.transition);
  const transition = events[transitionIndex];
  const transitionEndIndex = transition && events.findIndex((event) =>
    event.type === 'callback-end' && event.callbackId === transition.callbackId);
  const payloadFreeIndex = transition && events.findIndex((event) =>
    event.type === 'payload-free' && event.callbackId === transition.callbackId);
  const logs = events.filter((event) => event.type === 'log');
  const callbackEntryIndex = (callbackId) => events.findIndex((event) =>
    event.type === 'callback-begin' && event.callbackId === callbackId);
  report.oldLogsBeforeUnregister = unregisterIndex >= 0
    ? logs.filter((event) => event.owner === 'A' &&
      !events[callbackEntryIndex(event.callbackId)]?.entryAfterUnregister &&
      callbackEntryIndex(event.callbackId) < unregisterIndex).length
    : 0;
  report.queuedOldLogsAfterUnregister = unregisterIndex >= 0
    ? logs.filter((event) => event.owner === 'A' &&
      events[callbackEntryIndex(event.callbackId)]?.entryAfterUnregister === true &&
      callbackEntryIndex(event.callbackId) > unregisterIndex).length
    : 0;
  report.newLogsAfterRegister = registerIndex >= 0
    ? logs.filter((event) => event.owner === 'B' &&
      callbackEntryIndex(event.callbackId) > registerIndex).length
    : 0;
  report.inFlightAFrameSpannedSwap = Boolean(transition && transitionEndIndex > transitionIndex &&
    transitionIndex < unregisterIndex && unregisterIndex < registerIndex &&
    registerIndex < transitionEndIndex);
  report.inFlightPayloadFreedAfterReplacement = Boolean(transition && payloadFreeIndex > registerIndex &&
    payloadFreeIndex < transitionEndIndex);
  report.nativeStateBeforeSwap = trace.nativeStateBeforeSwap ?? null;
  report.nativeStateAfterSwap = trace.nativeStateAfterSwap ?? null;
  report.timeline = trace.events.filter((event) =>
    ['invoke', 'transition-armed', 'callback-begin', 'state-before-swap', 'busy-start',
      'busy-end', 'unregister', 'register-b', 'payload-held', 'payload-read', 'payload-free',
      'callback-end', 'state-after-swap', 'end'].includes(event.type))
    .map(({type, at, owner, state, callbackId, callbackEntryAt, mayDrainQueuedCallbacks}) =>
      ({type, at, owner, state, callbackId, callbackEntryAt, mayDrainQueuedCallbacks}));
}

function hasQueuedOldCallback(trace) {
  const events = trace.events;
  const unregisterIndex = events.findIndex((event) => event.type === 'unregister');
  if (unregisterIndex < 0) return false;
  return events.some((event) => {
    if (event.type !== 'log' || event.owner !== 'A') return false;
    const entryIndex = events.findIndex((candidate) =>
      candidate.type === 'callback-begin' && candidate.callbackId === event.callbackId);
    return entryIndex > unregisterIndex && events[entryIndex]?.entryAfterUnregister === true;
  });
}

export function assertCallbackLifetimeTrace(trace, {
  expectedSessionId,
  tokenA = TOKEN_A,
  tokenB = TOKEN_B,
} = {}) {
  const events = trace?.events;
  assert(Array.isArray(events) && events[0]?.type === 'invoke',
    'Callback lifetime trace must start with invocation.');
  assert(trace.nativeStateBeforeSwap === RUNNING,
    'Native work was not Running at callback entry before the swap.');
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
  let previousTimestamp = -Infinity;
  for (const event of events) {
    assert(Number.isFinite(event.at) && event.at >= previousTimestamp,
      'Callback lifetime timestamps must be finite and nondecreasing.');
    previousTimestamp = event.at;
  }

  const logs = events.filter((event) => event.type === 'log');
  const oldBefore = [];
  const oldAfter = [];
  const newAfter = [];
  const callbackBeginIndex = (callbackId) => events.findIndex((event) =>
    event.type === 'callback-begin' && event.callbackId === callbackId);
  for (const event of logs) {
    assert(Number.isFinite(event.callbackEntryAt) && event.callbackId !== undefined,
      'Each log must identify its callback entry time and invocation.');
    const entry = events.find((candidate) =>
      candidate.type === 'callback-begin' && candidate.callbackId === event.callbackId);
    assert(entry && entry.owner === event.owner && entry.at === event.callbackEntryAt,
      'Log arrival did not match its callback-entry record.');
    const entryIndex = callbackBeginIndex(event.callbackId);
    if (event.owner === 'A' && entry.entryAfterUnregister !== true && entryIndex < unregister) oldBefore.push(event);
    if (event.owner === 'A' && entry.entryAfterUnregister === true && entryIndex > unregister) oldAfter.push(event);
    if (event.owner === 'B' && entryIndex > registerB) newAfter.push(event);
  }
  assert(oldBefore.length > 0, 'No owned log arrived through callback A before unregistration.');
  assert(oldAfter.length > 0,
    'No queued callback from the old registration arrived after unregistration.');
  assert(newAfter.length > 0, 'No owned log arrived through replacement callback B.');

  const transitionBeginIndex = events.findIndex((event) =>
    event.type === 'callback-begin' && event.owner === 'A' && event.transition === true);
  const transitionBegin = events[transitionBeginIndex];
  assert(transitionBegin, 'The transition was not requested inside a real callback A invocation.');
  const armed = events.find((event) => event.type === 'transition-armed');
  const armedIndex = events.findIndex((event) => event.type === 'transition-armed');
  assert(armed && armedIndex < transitionBeginIndex && armed.at <= transitionBegin.at &&
    !events.some((event) => event.type === 'callback-begin' && event.owner === 'A' &&
      events.indexOf(event) > armedIndex && events.indexOf(event) < transitionBeginIndex),
  'The transition did not run inside the next A callback after it was armed.');
  const transitionId = transitionBegin.callbackId;
  for (const begin of events.filter((event) => event.type === 'callback-begin')) {
    const matchingEnds = events.filter((event) =>
      event.type === 'callback-end' && event.callbackId === begin.callbackId);
    const beginIndex = events.indexOf(begin);
    const endIndex = events.indexOf(matchingEnds[0]);
    assert(matchingEnds.length === 1 && endIndex > beginIndex && begin.at <= matchingEnds[0].at,
      `Callback ${begin.callbackId} did not have one ordered begin/end pair.`);
  }
  const transitionEndIndex = events.findIndex((event) =>
    event.type === 'callback-end' && event.callbackId === transitionId);
  const transitionEnd = events[transitionEndIndex];
  const stateBefore = events.find((event) =>
    event.type === 'state-before-swap' && event.callbackId === transitionId);
  const payloadHeld = events.find((event) =>
    event.type === 'payload-held' && event.callbackId === transitionId);
  const payloadRead = events.find((event) =>
    event.type === 'payload-read' && event.callbackId === transitionId);
  const payloadFree = events.find((event) =>
    event.type === 'payload-free' && event.callbackId === transitionId);
  const transitionLog = logs.find((event) => event.callbackId === transitionId);
  const busyStartIndex = events.findIndex((event) =>
    event.type === 'busy-start' && event.callbackId === transitionId);
  const busyEndIndex = events.findIndex((event) =>
    event.type === 'busy-end' && event.callbackId === transitionId);
  const stateAfterIndex = events.findIndex((event) => event.type === 'state-after-swap');
  const busyStart = events[busyStartIndex];
  const busyEnd = events[busyEndIndex];
  const stateAfter = events[stateAfterIndex];
  assert(transitionEnd && stateBefore && payloadHeld && payloadRead && payloadFree && transitionLog &&
    busyStart && busyEnd && stateAfter,
  'The callback transition is missing a begin/end, state, payload, or busy-frame observation.');
  assert(stateBefore.state === RUNNING && trace.nativeStateBeforeSwap === RUNNING,
    'Native state was not Running at callback entry before the busy interval.');
  assert(stateAfter.state === RUNNING && trace.nativeStateAfterSwap === RUNNING,
    'Native state was not Running after the callback registration swap.');
  const orderedTransition = [
    transitionBegin, stateBefore, payloadHeld, busyStart, busyEnd, unregistered,
    registered, payloadRead, payloadFree, transitionLog, transitionEnd, stateAfter,
  ];
  const transitionIndices = orderedTransition.map((event) => events.indexOf(event));
  assert(transitionIndices.every((index, position) =>
    index >= 0 && (position === 0 || index > transitionIndices[position - 1])),
  'Callback entry, busy interval, unregister/register boundary, payload, or state read ordering was invalid.');
  assert(orderedTransition.every((event, index) =>
    index === 0 || event.at >= orderedTransition[index - 1].at),
  'Callback transition timestamps moved backwards.');
  assert(busyEnd.at - busyStart.at >= 600,
    `The A callback did not hold the main JS frame for 600 ms (${busyEnd.at - busyStart.at} ms).`);
  assert(payloadHeld.hasPayload === true && transitionLog.payloadReadAt >= registered.at &&
    transitionLog.payloadFreedAt >= transitionLog.payloadReadAt &&
    transitionLog.payloadFreedAt >= registered.at &&
    transitionLog.payloadReadAt === payloadRead.at &&
    transitionLog.payloadFreedAt === payloadFree.at &&
    transitionLog.payloadFreedAt <= transitionEnd.at,
  'The in-flight A callback did not read and free its owned payload after replacement registration.');
  assert(!events.slice(busyEndIndex + 1, unregister).some((event) =>
    event.type === 'state-before-swap' || event.type === 'state-after-swap') &&
    stateAfter.mayDrainQueuedCallbacks === true,
  'The state read must happen before busy work and only after the unregister boundary.');

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
  let oldCallbackDisabled = false;
  let oldLevel;
  let levelChanged = false;
  let primaryError;
  const routeLog = (owner, sessionValue, sequence, messagePointer, userData, token,
      callbackId, callbackEntryAt) => {
    let message = '';
    let payloadReadAt;
    let payloadFreedAt;
    try {
      message = messagePointer ? module.UTF8ToString(messagePointer) : '';
      payloadReadAt = performance.now();
      trace.events.push({type: 'payload-read', at: payloadReadAt, callbackId});
      if (number(userData) !== token) {
        failures.push(`Callback ${owner} received user data ${number(userData)} instead of ${token}.`);
      }
      if (String(sessionValue) !== String(sessionId)) {
        failures.push(`Callback ${owner} received session ${sessionValue} instead of ${sessionId}.`);
      }
      if (owner === 'A') oldLogCount += 1;
      else newLogCount += 1;
    } catch (error) {
      failures.push(String(error));
    } finally {
      if (messagePointer) {
        try {
          requireFunction(module, '_ffmpeg_kit_free')(messagePointer);
          payloadFreedAt = performance.now();
          trace.events.push({type: 'payload-free', at: payloadFreedAt, callbackId});
        } catch (error) {
          failures.push(`Unable to free owned log payload: ${String(error)}`);
        }
      }
    }
    trace.events.push({
      type: 'log',
      at: performance.now(),
      callbackEntryAt,
      callbackId,
      owner,
      sessionId: String(sessionValue),
      sequence: number(sequence),
      userData: number(userData),
      messageLength: message.length,
      messageSample: message.slice(0, 72),
      payloadReadAt: payloadReadAt ?? Number.NaN,
      payloadFreedAt: payloadFreedAt ?? Number.NaN,
    });
  };
  let callbackId = 0;
  let transitionOnNextA = false;
  const oldLog = (sid, sequence, _level, message, userData) => {
    const currentId = ++callbackId;
    const callbackEntryAt = performance.now();
    const transition = transitionOnNextA;
    trace.events.push({
      type: 'callback-begin', owner: 'A', callbackId: currentId,
      at: callbackEntryAt, transition, entryAfterUnregister: oldCallbackDisabled,
    });
    let stateBefore;
    if (transition) {
      transitionOnNextA = false;
      try {
        // This is the first native getter at the real A callback entry. The
        // subsequent main-thread busy interval lets the worker queue more A work.
        stateBefore = number(requireFunction(module, '_ffmpeg_kit_session_get_state')(handle));
        trace.nativeStateBeforeSwap = stateBefore;
        trace.events.push({type: 'state-before-swap', at: performance.now(), state: stateBefore, callbackId: currentId});
      } catch (error) {
        failures.push(`Unable to read native state at A callback entry: ${String(error)}`);
      }
      trace.events.push({
        type: 'payload-held', at: performance.now(), callbackId: currentId,
        hasPayload: message !== 0,
      });
    }
    if (transition) {
      try {
        trace.events.push({type: 'busy-start', at: performance.now(), callbackId: currentId});
        const busyUntil = performance.now() + 600;
        while (performance.now() < busyUntil) { /* Hold the main callback frame. */ }
        trace.events.push({type: 'busy-end', at: performance.now(), callbackId: currentId});

        // Keep these C calls adjacent: a state getter between them could pump
        // the main-thread dispatcher and change the scheduling under test.
        requireFunction(module, '_ffmpeg_kit_config_enable_log_callback')(0, 0);
        oldCallbackDisabled = true;
        trace.events.push({
          type: 'unregister', at: performance.now(), slotA: oldLogPointer,
          tokenA: TOKEN_A, callbackId: currentId,
        });
        newLogPointer = requireFunction(module, 'addFunction')(newLog, 'vjjipp');
        assert(newLogPointer !== oldLogPointer, 'The retained callback slot was reused.');
        requireFunction(module, '_ffmpeg_kit_config_enable_log_callback')(newLogPointer, TOKEN_B);
        trace.events.push({
          type: 'register-b', at: performance.now(), slotB: newLogPointer,
          tokenB: TOKEN_B, callbackId: currentId,
        });
      } catch (error) {
        failures.push(`A callback transition failed: ${String(error)}`);
      }
    }
    routeLog('A', sid, sequence, message, userData, TOKEN_A, currentId, callbackEntryAt);
    trace.events.push({type: 'callback-end', owner: 'A', callbackId: currentId, at: performance.now()});
  };
  const newLog = (sid, sequence, _level, message, userData) => {
    const currentId = ++callbackId;
    const callbackEntryAt = performance.now();
    trace.events.push({
      type: 'callback-begin', owner: 'B', callbackId: currentId,
      at: callbackEntryAt, entryAfterUnregister: oldCallbackDisabled,
    });
    routeLog('B', sid, sequence, message, userData, TOKEN_B, currentId, callbackEntryAt);
    trace.events.push({type: 'callback-end', owner: 'B', callbackId: currentId, at: performance.now()});
  };
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
    trace.events.push({type: 'transition-armed', at: performance.now()});
    transitionOnNextA = true;

    await waitFor('the next A callback to unregister and register B', () =>
      trace.events.some((event) => event.type === 'register-b'), 5000);
    trace.nativeStateAfterSwap = number(
      requireFunction(module, '_ffmpeg_kit_session_get_state')(handle),
    );
    trace.events.push({
      type: 'state-after-swap', at: performance.now(),
      state: trace.nativeStateAfterSwap, mayDrainQueuedCallbacks: true,
    });
    assert(trace.nativeStateAfterSwap === RUNNING,
      'Native work stopped before the post-swap state read.');

    await waitFor('native completion and a queued old A callback plus new B callbacks', () =>
      completeCount === 1 && hasQueuedOldCallback(trace) && newLogCount > 0, 10000);
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
    const sequences = trace.events.filter((event) => event.type === 'log')
      .map((event) => event.sequence);
    report.logSequence = {first: sequences[0], last: sequences.at(-1), count: sequences.length};
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
    summarizeTrace(report, trace);
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
