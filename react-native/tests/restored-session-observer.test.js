'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, test } = require('node:test');

const {
  getBackend,
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
const abandonments = [];
const cancellations = [];
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
    return states.get(sessionId) ?? SessionState.Created;
  },
  getSessionJson: (sessionId) => {
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
  cancelSession: (sessionId) => cancellations.push(sessionId),
  releaseSessionHandle: (sessionId) => releases.push(sessionId),
  abandonCreatedSession: (sessionId) => abandonments.push(sessionId),
  recordCancellationIntent: () => {},
  isCancellationRequested: () => false,
  clearCancellationIntent: () => {},
  installCompletionBridge: () => {
    bridgeInstalls.completion += 1;
  },
  uninstallCompletionBridge: () => {
    bridgeUninstalls.completion += 1;
  },
  installLogBridge: () => {
    if (logBridgeError) throw logBridgeError;
    bridgeInstalls.log += 1;
  },
  uninstallLogBridge: () => {
    bridgeUninstalls.log += 1;
  },
  onLogEvent: (handler) => {
    logHandlers.add(handler);
    return { remove: () => logHandlers.delete(handler) };
  },
  isDirectLogBridgeActive: () =>
    bridgeInstalls.log > bridgeUninstalls.log,
  installStatisticsBridge: () => {
    bridgeInstalls.statistics += 1;
  },
  uninstallStatisticsBridge: () => {
    bridgeUninstalls.statistics += 1;
  },
  clearSessions: () => {},
});

const { FFmpegKitExtended } = require('../.test-dist/ffmpeg-kit-extended.js');
const {
  FFmpegSession,
  sessionFromSnapshot,
} = require('../.test-dist/session.js');

beforeEach(async () => {
  states.clear();
  snapshots.clear();
  releases.length = 0;
  abandonments.length = 0;
  cancellations.length = 0;
  completedCallbacks.length = 0;
  executionStarts = 0;
  logs = [];
  statistics = [];
  stateReadError = undefined;
  logBridgeError = undefined;
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
