'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, test } = require('node:test');

const {
  setBackend,
} = require('../.test-dist/platform/backend-registry.js');
const {
  SessionCancelledException,
  SessionQueueManager,
} = require('../.test-dist/session-queue-manager.js');
const { SessionState } = require('../.test-dist/types.js');

const manager = SessionQueueManager.shared;
const states = new Map();
const snapshots = new Map();
const releases = [];
const releaseCalls = [];
const releasedSessionIds = new Set();
const abandonments = [];
const cancellations = [];
const cancellationIntents = new Set();
const bridgeInstalls = { completion: 0, log: 0, statistics: 0 };
const bridgeUninstalls = { completion: 0, log: 0, statistics: 0 };
const completedCallbacks = [];
const logHandlers = new Set();
let nextSessionId = 1000;
let executionStarts = 0;
let logs = [];
let statistics = [];
let stateReadError;
let logBridgeError;
let cancelFailure;
let deferredLogInstall;
let deferredStatisticsInstall;
let clearRequested = false;
let clearCalls = 0;
let clearFailure;
let releaseFailuresRemaining = 0;
let releaseFailureError;
let uninstallLogBridgeError;

function snapshotFor(
  sessionId,
  state = states.get(sessionId) ?? SessionState.Created
) {
  return {
    sessionId,
    type: 'ffmpeg',
    state,
    returnCode: 0,
    createTime: 0,
    startTime: state === SessionState.Created ? 0 : 1,
    endTime: state === SessionState.Completed ? 2 : 0,
    duration: state === SessionState.Completed ? 1 : 0,
    command: '-version',
    output: '',
    logs: '',
    failStackTrace: '',
    logsCount: logs.length,
    statisticsCount: statistics.length,
    debugLogEnabled: false,
  };
}

setBackend({
  initialize: async () => {},
  createFFmpegSession: () => {
    const sessionId = nextSessionId++;
    states.set(sessionId, SessionState.Created);
    return sessionId;
  },
  executeSessionAsync: (sessionId) => {
    executionStarts += 1;
    if (states.get(sessionId) === SessionState.Created)
      states.set(sessionId, SessionState.Running);
  },
  getSessionState: (sessionId) => {
    if (stateReadError) throw stateReadError;
    if (clearRequested) return SessionState.Completed;
    return states.get(sessionId) ?? SessionState.Created;
  },
  getSessionJson: (sessionId) => {
    if (!states.has(sessionId) && !snapshots.has(sessionId)) return '';
    const snapshot = snapshots.get(sessionId) ?? snapshotFor(sessionId);
    return states.has(sessionId)
      ? JSON.stringify({ ...snapshot, state: states.get(sessionId) })
      : JSON.stringify(snapshot);
  },
  getSessionsJson: () =>
    JSON.stringify(
      [...snapshots.values()].map((snapshot) => ({
        ...snapshot,
        state: states.get(snapshot.sessionId) ?? snapshot.state,
      }))
    ),
  getLastSessionJson: () => {
    const snapshot = [...snapshots.values()].at(-1);
    return snapshot
      ? JSON.stringify({ ...snapshot, state: states.get(snapshot.sessionId) })
      : '';
  },
  getLogsJson: (_sessionId, fromIndex) =>
    JSON.stringify(fromIndex === 0 ? logs : []),
  getStatisticsJson: (_sessionId, fromIndex) =>
    JSON.stringify(fromIndex === 0 ? statistics : []),
  getMediaInformationJson: () => '',
  cancelSession: (sessionId) => {
    cancellations.push(sessionId);
    if (cancelFailure) {
      const error = cancelFailure;
      cancelFailure = undefined;
      throw error;
    }
  },
  releaseSessionHandle: (sessionId) => {
    releaseCalls.push(sessionId);
    if (releaseFailuresRemaining > 0) {
      releaseFailuresRemaining -= 1;
      throw releaseFailureError ?? new Error('retained release failed');
    }
    if (releasedSessionIds.has(sessionId)) return;
    releasedSessionIds.add(sessionId);
    releases.push(sessionId);
  },
  abandonCreatedSession: (sessionId) => abandonments.push(sessionId),
  recordCancellationIntent: (sessionId) => cancellationIntents.add(sessionId),
  isCancellationRequested: (sessionId) => cancellationIntents.has(sessionId),
  clearCancellationIntent: (sessionId) => cancellationIntents.delete(sessionId),
  installCompletionBridge: () => {
    bridgeInstalls.completion += 1;
  },
  uninstallCompletionBridge: () => {
    bridgeUninstalls.completion += 1;
  },
  installLogBridge: () => {
    if (logBridgeError) throw logBridgeError;
    if (deferredLogInstall) {
      return deferredLogInstall.then(() => {
        bridgeInstalls.log += 1;
      });
    }
    bridgeInstalls.log += 1;
  },
  uninstallLogBridge: () => {
    bridgeUninstalls.log += 1;
    if (uninstallLogBridgeError) throw uninstallLogBridgeError;
  },
  onLogEvent: (handler) => {
    logHandlers.add(handler);
    return { remove: () => logHandlers.delete(handler) };
  },
  isDirectLogBridgeActive: () =>
    bridgeInstalls.log > bridgeUninstalls.log,
  installStatisticsBridge: () => {
    if (deferredStatisticsInstall) {
      return deferredStatisticsInstall.then(() => {
        bridgeInstalls.statistics += 1;
      });
    }
    bridgeInstalls.statistics += 1;
  },
  uninstallStatisticsBridge: () => {
    bridgeUninstalls.statistics += 1;
  },
  clearSessions: () => {
    clearCalls += 1;
    if (clearFailure) throw clearFailure;
    clearRequested = true;
    cancellationIntents.clear();
  },
});

const { FFmpegKitExtended } = require('../.test-dist/ffmpeg-kit-extended.js');
const { FFmpegKitConfig } = require('../.test-dist/ffmpeg-kit-config.js');
const {
  FFmpegSession,
  sessionFromSnapshot,
} = require('../.test-dist/session.js');
const {
  restoredSessionObserver,
} = require('../.test-dist/session-observation.js');
const {
  releaseSessionHandleSerialized,
} = require('../.test-dist/session-lifetime.js');

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
}

function waitForObservation() {
  return new Promise((resolve) => setTimeout(resolve, 125));
}

beforeEach(async () => {
  states.clear();
  snapshots.clear();
  releases.length = 0;
  releaseCalls.length = 0;
  releasedSessionIds.clear();
  abandonments.length = 0;
  cancellations.length = 0;
  completedCallbacks.length = 0;
  executionStarts = 0;
  logs = [];
  statistics = [];
  stateReadError = undefined;
  logBridgeError = undefined;
  cancelFailure = undefined;
  deferredLogInstall = undefined;
  deferredStatisticsInstall = undefined;
  clearRequested = false;
  clearCalls = 0;
  clearFailure = undefined;
  releaseFailuresRemaining = 0;
  releaseFailureError = undefined;
  uninstallLogBridgeError = undefined;
  cancellationIntents.clear();
  logHandlers.clear();
  bridgeInstalls.completion = 0;
  bridgeInstalls.log = 0;
  bridgeInstalls.statistics = 0;
  bridgeUninstalls.completion = 0;
  bridgeUninstalls.log = 0;
  bridgeUninstalls.statistics = 0;
  manager.clearQueue();
  manager.maxConcurrentSessions = 8;
  await manager.waitForAll();
  await FFmpegKitExtended.initialize();
});

afterEach(async () => {
  clearFailure = undefined;
  manager.clearQueue();
  manager.maxConcurrentSessions = 8;
  await manager.waitForAll();
  await FFmpegKitExtended.clearSessions();
});

test('public ID cancellation finds queued and active sessions through one authority', async () => {
  manager.maxConcurrentSessions = 1;
  const blocker = new Promise((resolve) => setTimeout(resolve, 0));
  const active = manager.executeSession({ cancel() {} }, async () => blocker);
  const queued = new FFmpegSession(1001, '-version').executeAsync();

  await FFmpegKitExtended.cancelSession(1001);
  await assert.rejects(queued, SessionCancelledException);
  assert.equal(executionStarts, 0);
  assert.deepEqual(abandonments, [1001]);

  await active;
});

test('ID zero cancels queued and active managed sessions', async () => {
  manager.maxConcurrentSessions = 1;
  const activeSession = new FFmpegSession(1002, '-version');
  const active = activeSession.executeAsync({ pollIntervalMs: 10 });
  await new Promise((resolve) => setTimeout(resolve, 0));
  const queued = new FFmpegSession(1003, '-version').executeAsync();

  await FFmpegKitExtended.cancelSession(0);
  await assert.rejects(queued, SessionCancelledException);
  assert.equal(activeSession.isCancelled, true);
  states.set(1002, SessionState.Completed);
  await active;
});

test('submitted Created cancellation preserves the execution identity', async () => {
  const session = new FFmpegSession(1004, '-version');
  states.set(1004, SessionState.Created);
  const execution = session.executeAsync({ pollIntervalMs: 10 });
  await new Promise((resolve) => setTimeout(resolve, 0));

  await session.cancel();
  assert.deepEqual(abandonments, []);
  states.set(1004, SessionState.Completed);
  await execution;
  assert.deepEqual(abandonments, []);
});

test('restored Running wrappers share terminal release and deliver callbacks', async () => {
  const sessionId = 1005;
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  logs = [];
  statistics = [
    { sessionId, time: 1, timeElapsed: 1, size: 2, bitrate: 3, speed: 4 },
  ];

  const first = FFmpegKitExtended.getSession(sessionId);
  const second = sessionFromSnapshot(
    snapshotFor(sessionId, SessionState.Running)
  );
  await first.setCompleteCallback?.(() => completedCallbacks.push('first'));
  const receivedLogs = [];
  const receivedStatistics = [];
  await first.setLogCallback?.((_log) => receivedLogs.push(_log.message));
  await first.setStatisticsCallback?.((_statistics) =>
    receivedStatistics.push(_statistics)
  );
  for (const handler of logHandlers) {
    handler({ sessionId, sequence: 0, level: 1, message: 'live' });
  }
  statistics = [
    { sessionId, time: 1, timeElapsed: 1, size: 2, bitrate: 3, speed: 4 },
  ];
  states.set(sessionId, SessionState.Completed);
  await new Promise((resolve) => setTimeout(resolve, 100));

  assert.ok(first);
  assert.ok(second);
  assert.equal(executionStarts, 0);
  assert.deepEqual(releases, [sessionId]);
  assert.deepEqual(completedCallbacks, ['first']);
  assert.deepEqual(receivedLogs, ['live']);
  assert.equal(receivedStatistics.length, 1);
  assert.equal(bridgeInstalls.log, 1);
  assert.equal(bridgeUninstalls.log, 1);
});

test('restored callback setters roll back when state verification fails', async () => {
  const sessionId = 1007;
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  const session = FFmpegKitExtended.getSession(sessionId);

  stateReadError = new Error('state probe failed');
  await assert.rejects(
    session.setLogCallback?.(() => {}),
    /state probe failed/
  );
  stateReadError = undefined;
  states.set(sessionId, SessionState.Completed);
  await new Promise((resolve) => setTimeout(resolve, 100));

  assert.equal(bridgeInstalls.log, 0);
  assert.deepEqual(releases, [sessionId]);
});

test('restored callback setters roll back a failed bridge installation', async () => {
  const sessionId = 1008;
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  const session = FFmpegKitExtended.getSession(sessionId);

  logBridgeError = new Error('bridge install failed');
  await assert.rejects(
    session.setLogCallback?.(() => {}),
    /bridge install failed/
  );
  logBridgeError = undefined;
  states.set(sessionId, SessionState.Completed);
  await new Promise((resolve) => setTimeout(resolve, 100));

  assert.equal(bridgeInstalls.log, 0);
  assert.deepEqual(releases, [sessionId]);
});

test('successful clear invalidates a restored observer without releasing after clear', async () => {
  const sessionId = 1006;
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  FFmpegKitExtended.getSession(sessionId);

  await FFmpegKitExtended.clearSessions();
  await new Promise((resolve) => setTimeout(resolve, 75));
  assert.deepEqual(releases, []);
});

test('configuration clear invalidates restored observer state', async () => {
  const sessionId = 1024;
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  const session = FFmpegKitExtended.getSession(sessionId);
  session.setCompleteCallback?.(() => {});

  assert.equal(restoredSessionObserver.size, 1);
  assert.equal(restoredSessionObserver.getTargetCount(sessionId), 1);

  await FFmpegKitConfig.clearSessions();

  assert.equal(clearCalls, 1);
  assert.equal(restoredSessionObserver.size, 0);
  assert.equal(restoredSessionObserver.getTargetCount(sessionId), 0);
  assert.deepEqual(releases, []);
});

test('configuration and lifecycle clear share backend failure semantics', async () => {
  const sessionId = 1025;
  const clearError = new Error('configuration clear failed');
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  const session = FFmpegKitExtended.getSession(sessionId);
  session.setCompleteCallback?.(() => {});
  clearFailure = clearError;

  await assert.rejects(
    FFmpegKitConfig.clearSessions(),
    (error) => error === clearError
  );

  assert.equal(clearCalls, 1);
  assert.equal(clearRequested, false);
  assert.equal(restoredSessionObserver.size, 1);
  assert.equal(restoredSessionObserver.getTargetCount(sessionId), 1);
  assert.equal(bridgeUninstalls.completion, 0);
});

test('restored execution preflight rejects without destructive history cleanup', async () => {
  const sessionId = 1009;
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  const session = FFmpegKitExtended.getSession(sessionId);

  await assert.rejects(
    session.executeAsync(),
    /cannot start from state 1/
  );
  assert.equal(executionStarts, 0);
  assert.deepEqual(abandonments, []);
  assert.deepEqual(releases, []);
  assert.equal(restoredSessionObserver.size, 1);

  states.set(sessionId, SessionState.Completed);
  await waitForObservation();
  assert.deepEqual(releases, [sessionId]);
});

test('restored state probe failure before admission preserves observation ownership', async () => {
  const sessionId = 1018;
  const stateFailure = new Error('restored state probe failed');
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  const session = FFmpegKitExtended.getSession(sessionId);

  stateReadError = stateFailure;
  await assert.rejects(
    session.executeAsync(),
    (error) => error === stateFailure
  );
  assert.equal(executionStarts, 0);
  assert.deepEqual(abandonments, []);
  assert.deepEqual(releases, []);
  assert.equal(restoredSessionObserver.size, 1);
  assert.equal(restoredSessionObserver.getTargetCount(sessionId), 0);

  stateReadError = undefined;
  states.set(sessionId, SessionState.Completed);
  await waitForObservation();
  assert.deepEqual(releases, [sessionId]);
});

test('missing public cancellation remains a no-op without hiding real failures', async () => {
  await FFmpegKitExtended.cancelSession(1099);
  assert.deepEqual(cancellations, []);
  assert.deepEqual(abandonments, []);
  assert.deepEqual(releases, []);
});

test('restored cancellation survives a state-read failure and retries while Running', async () => {
  const sessionId = 1010;
  const stateError = new Error('state probe failed during cancellation');
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  const session = FFmpegKitExtended.getSession(sessionId);

  stateReadError = stateError;
  await assert.rejects(session.cancel(), (error) => error === stateError);
  assert.equal(cancellationIntents.has(sessionId), true);

  stateReadError = undefined;
  await waitForObservation();
  assert.deepEqual(cancellations, [sessionId]);
  assert.equal(cancellationIntents.has(sessionId), true);

  states.set(sessionId, SessionState.Completed);
  await waitForObservation();
  assert.equal(cancellationIntents.has(sessionId), false);
  assert.deepEqual(releases, [sessionId]);
});

test('restored cancellation retries a failed native dispatch exactly once after recovery', async () => {
  const sessionId = 1011;
  const cancelError = new Error('native cancellation failed');
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  const session = FFmpegKitExtended.getSession(sessionId);

  cancelFailure = cancelError;
  await assert.rejects(session.cancel(), (error) => error === cancelError);
  assert.equal(cancellationIntents.has(sessionId), true);

  cancelFailure = undefined;
  await waitForObservation();
  const successfulDispatchCount = cancellations.length;
  assert.ok(successfulDispatchCount >= 2);
  assert.equal(cancellations.every((id) => id === sessionId), true);
  await waitForObservation();
  assert.equal(cancellations.length, successfulDispatchCount);

  states.set(sessionId, SessionState.Completed);
  await waitForObservation();
  assert.equal(cancellationIntents.has(sessionId), false);
  assert.deepEqual(releases, [sessionId]);
});

test('active execution remains the sole owner while restored observation sees terminal state', async () => {
  const sessionId = 1012;
  const gate = deferred();
  states.set(sessionId, SessionState.Running);
  const activeSession = {
    getSessionId: () => sessionId,
    cancel() {},
  };
  const active = manager.executeSession(activeSession, async () => {
    await gate.promise;
    states.set(sessionId, SessionState.Completed);
    await releaseSessionHandleSerialized(sessionId);
  });

  await new Promise((resolve) => setImmediate(resolve));
  restoredSessionObserver.ensureObserved(sessionId);
  states.set(sessionId, SessionState.Completed);
  await waitForObservation();
  assert.deepEqual(releases, []);

  gate.resolve();
  await active;
  assert.deepEqual(releases, [sessionId]);
  await waitForObservation();
  assert.deepEqual(releaseCalls, [sessionId, sessionId]);
  assert.equal(restoredSessionObserver.size, 0);
});

test('restored terminal release retries after an active owner fails first', async () => {
  const sessionId = 1019;
  const gate = deferred();
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  const releaseError = new Error('active owner release failed');
  releaseFailuresRemaining = 1;
  releaseFailureError = releaseError;

  const active = manager.executeSession(
    { getSessionId: () => sessionId, cancel() {} },
    async () => {
      await gate.promise;
      states.set(sessionId, SessionState.Completed);
      await releaseSessionHandleSerialized(sessionId);
    }
  );
  restoredSessionObserver.ensureObserved(sessionId);
  states.set(sessionId, SessionState.Completed);
  await waitForObservation();
  assert.equal(restoredSessionObserver.size, 1);

  gate.resolve();
  await assert.rejects(active, (error) => error === releaseError);
  await waitForObservation();
  await waitForObservation();

  assert.deepEqual(releaseCalls, [sessionId, sessionId]);
  assert.deepEqual(releases, [sessionId]);
  assert.equal(restoredSessionObserver.size, 0);
});

test('history-only terminal release retries iteratively without repeating callbacks', async () => {
  const sessionId = 1020;
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  const session = FFmpegKitExtended.getSession(sessionId);
  session.setCompleteCallback?.(() => completedCallbacks.push(sessionId));
  releaseFailuresRemaining = 5;

  states.set(sessionId, SessionState.Completed);
  for (
    let attempt = 0;
    attempt < 10 && restoredSessionObserver.size > 0;
    attempt++
  ) {
    await waitForObservation();
    if (releaseCalls.length < 6) assert.equal(restoredSessionObserver.size, 1);
  }

  assert.equal(completedCallbacks.filter((id) => id === sessionId).length, 1);
  assert.equal(releaseCalls.length, 6);
  assert.deepEqual(releases, [sessionId]);
  assert.equal(restoredSessionObserver.size, 0);
});

test('clear invalidates a terminal release retry without repeating callbacks', async () => {
  const sessionId = 1021;
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  const session = FFmpegKitExtended.getSession(sessionId);
  session.setCompleteCallback?.(() => completedCallbacks.push(sessionId));
  releaseFailuresRemaining = Number.MAX_SAFE_INTEGER;

  states.set(sessionId, SessionState.Completed);
  await waitForObservation();
  const attemptsBeforeClear = releaseCalls.length;
  assert.ok(attemptsBeforeClear > 0);
  assert.equal(restoredSessionObserver.size, 1);

  await FFmpegKitExtended.clearSessions();
  await waitForObservation();
  const attemptsAfterClear = releaseCalls.length;
  await waitForObservation();

  assert.equal(restoredSessionObserver.size, 0);
  assert.equal(releaseCalls.length, attemptsAfterClear);
  assert.equal(completedCallbacks.filter((id) => id === sessionId).length, 1);
  assert.equal(releases.includes(sessionId), false);
  assert.equal(attemptsAfterClear, attemptsBeforeClear);
});

test('repeated clear cycles release observer entries without historical tombstones', async () => {
  for (let offset = 0; offset < 100; offset += 1) {
    const sessionId = 3000 + offset;
    states.set(sessionId, SessionState.Running);
    snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
    const session = FFmpegKitExtended.getSession(sessionId);
    session.setCompleteCallback?.(() => {});

    await FFmpegKitExtended.clearSessions();
    assert.equal(restoredSessionObserver.size, 0);
    assert.equal(restoredSessionObserver.getTargetCount(sessionId), 0);
    states.delete(sessionId);
    snapshots.delete(sessionId);
    clearRequested = false;
  }
});

test('terminal completion errors are reported after callback target detachment', async () => {
  const sessionId = 1022;
  const completionError = new Error('restored completion failed');
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  const session = FFmpegKitExtended.getSession(sessionId);
  let callbackCount = 0;
  session.setCompleteCallback?.(() => {
    callbackCount += 1;
    throw completionError;
  });
  const warnings = [];
  const originalWarn = console.warn;
  console.warn = (...args) => warnings.push(args);
  try {
    states.set(sessionId, SessionState.Completed);
    await waitForObservation();
    assert.equal(callbackCount, 1);
    assert.equal(warnings.length, 1);
    assert.equal(warnings[0][1], completionError);
    assert.equal(restoredSessionObserver.getTargetCount(sessionId), 0);
    assert.equal(restoredSessionObserver.size, 0);
    assert.deepEqual(releases, [sessionId]);
  } finally {
    console.warn = originalWarn;
  }
});

test('terminal cleanup errors are reported while release continues', async () => {
  const sessionId = 1023;
  const cleanupError = new Error('restored bridge cleanup failed');
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  const session = FFmpegKitExtended.getSession(sessionId);
  await session.setLogCallback?.(() => {});
  uninstallLogBridgeError = cleanupError;
  const warnings = [];
  const originalWarn = console.warn;
  console.warn = (...args) => warnings.push(args);
  try {
    states.set(sessionId, SessionState.Completed);
    await waitForObservation();
    assert.equal(warnings.length, 1);
    assert.equal(warnings[0][1], cleanupError);
    assert.equal(restoredSessionObserver.getTargetCount(sessionId), 0);
    assert.equal(restoredSessionObserver.size, 0);
    assert.deepEqual(releases, [sessionId]);
  } finally {
    console.warn = originalWarn;
  }
});

test('history reconstruction keeps one ID observer and no retained callback targets', async () => {
  const sessionId = 1013;
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));

  for (let index = 0; index < 1000; index += 1)
    FFmpegKitExtended.getSession(sessionId);

  assert.equal(restoredSessionObserver.size, 1);
  assert.equal(restoredSessionObserver.getTargetCount(sessionId), 0);

  states.set(sessionId, SessionState.Completed);
  await waitForObservation();
  assert.deepEqual(releases, [sessionId]);
});

test('restored callback targets attach only for live sinks and detach independently', async () => {
  const sessionId = 1014;
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  const first = FFmpegKitExtended.getSession(sessionId);
  const second = FFmpegKitExtended.getSession(sessionId);

  first.setCompleteCallback?.(() => {});
  await second.setLogCallback?.(() => {});
  assert.equal(restoredSessionObserver.getTargetCount(sessionId), 2);

  first.removeCompleteCallback?.();
  await second.setLogCallback?.(undefined);
  assert.equal(restoredSessionObserver.getTargetCount(sessionId), 0);

  states.set(sessionId, SessionState.Completed);
  await waitForObservation();
  assert.deepEqual(releases, [sessionId]);
});

test('deferred restored log setup rolls back after terminal transition', async () => {
  const sessionId = 1015;
  const installGate = deferred();
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  deferredLogInstall = installGate.promise;
  const session = FFmpegKitExtended.getSession(sessionId);
  const update = session.setLogCallback?.(() => {});

  await new Promise((resolve) => setImmediate(resolve));
  states.set(sessionId, SessionState.Completed);
  installGate.resolve();
  await assert.rejects(update, /no longer Running/);
  await waitForObservation();

  assert.equal(bridgeInstalls.log, 1);
  assert.equal(bridgeUninstalls.log, 1);
  assert.equal(restoredSessionObserver.getTargetCount(sessionId), 0);
  assert.deepEqual(releases, [sessionId]);
});

test('deferred restored statistics setup rolls back after terminal transition', async () => {
  const sessionId = 1016;
  const installGate = deferred();
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  deferredStatisticsInstall = installGate.promise;
  const session = FFmpegKitExtended.getSession(sessionId);
  const update = session.setStatisticsCallback?.(() => {});

  await new Promise((resolve) => setImmediate(resolve));
  states.set(sessionId, SessionState.Completed);
  installGate.resolve();
  await assert.rejects(update, /no longer Running/);
  await waitForObservation();

  assert.equal(bridgeInstalls.statistics, 1);
  assert.equal(bridgeUninstalls.statistics, 1);
  assert.equal(restoredSessionObserver.getTargetCount(sessionId), 0);
  assert.deepEqual(releases, [sessionId]);
});

test('clear invalidates a callback setup that is still awaiting bridge installation', async () => {
  const sessionId = 1017;
  const installGate = deferred();
  states.set(sessionId, SessionState.Running);
  snapshots.set(sessionId, snapshotFor(sessionId, SessionState.Running));
  deferredLogInstall = installGate.promise;
  const session = FFmpegKitExtended.getSession(sessionId);
  const update = session.setLogCallback?.(() => {});

  await new Promise((resolve) => setImmediate(resolve));
  const clear = FFmpegKitExtended.clearSessions();
  installGate.resolve();
  await clear;
  await assert.rejects(update, /no longer Running/);
  assert.equal(restoredSessionObserver.size, 0);
  assert.equal(restoredSessionObserver.getTargetCount(sessionId), 0);
});
