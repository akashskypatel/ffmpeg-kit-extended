'use strict';

const assert = require('node:assert/strict');
const {afterEach, beforeEach, test} = require('node:test');

const {setBackend} = require('../.test-dist/platform/backend.js');
const {WasmSessionRegistry} = require('../.test-dist/platform/web/session-registry.js');
const {
  SessionCancelledException,
  SessionQueueManager,
} = require('../.test-dist/session-queue-manager.js');

const registry = new WasmSessionRegistry();
const releases = [];
let logEntries = [];
let statisticsEntries = [];
let executionStarts = 0;
let sessionState = 2;
let startError;
setBackend({
  executeSessionAsync: () => {
    if (startError) throw startError;
    executionStarts += 1;
  },
  getLogsJson: (_sessionId, fromIndex) => JSON.stringify(fromIndex === 0 ? logEntries : []),
  getStatisticsJson: (_sessionId, fromIndex) => JSON.stringify(fromIndex === 0 ? statisticsEntries : []),
  getSessionJson: () => JSON.stringify({state: sessionState}),
  cancelSession: () => {},
  releaseSessionHandle: sessionId => {
    releases.push(sessionId);
    registry.take(sessionId);
  },
});

const {FFmpegSession} = require('../.test-dist/session.js');
const manager = SessionQueueManager.shared;

beforeEach(() => {
  registry.clear();
  releases.length = 0;
  logEntries = [];
  statisticsEntries = [];
  executionStarts = 0;
  sessionState = 2;
  startError = undefined;
});

afterEach(async () => {
  manager.clearQueue();
  manager.maxConcurrentSessions = 8;
  await manager.waitForAll();
});

test('discarded queued session releases its Wasm handle exactly once', async () => {
  manager.maxConcurrentSessions = 1;
  const activeGate = new Promise(resolve => {
    setTimeout(resolve, 0);
  });
  const active = manager.executeSession({cancel() {}}, async () => activeGate);
  registry.retain(1024, 42);
  const pending = new FFmpegSession(42, '-version').executeAsync();

  manager.clearQueue();

  await assert.rejects(pending, SessionCancelledException);
  assert.equal(executionStarts, 0);
  assert.deepEqual(releases, [42]);
  assert.equal(registry.has(42), false);

  manager.clearQueue();
  assert.deepEqual(releases, [42]);
  await active;
});

test('normally completed session releases its Wasm handle exactly once', async () => {
  registry.retain(2048, 7);
  await new FFmpegSession(7, '-version').executeAsync({pollIntervalMs: 10});

  assert.equal(executionStarts, 1);
  assert.deepEqual(releases, [7]);
  assert.equal(registry.has(7), false);
});

test('native start failure releases its Wasm handle exactly once', async () => {
  const error = new Error('native start failed');
  startError = error;
  registry.retain(3072, 8);

  const execution = new FFmpegSession(8, '-version').executeAsync();

  await assert.rejects(execution, reason => reason === error);
  await manager.waitForAll();
  assert.equal(executionStarts, 0);
  assert.deepEqual(releases, [8]);
  assert.equal(registry.has(8), false);
  assert.equal(manager.activeSessionCount, 0);
  assert.equal(manager.queueLength, 0);
});

test('active cancelled session keeps its handle until terminal state', async () => {
  sessionState = 1;
  const session = new FFmpegSession(10, '-version');
  registry.retain(4096, 10);
  const execution = session.executeAsync({pollIntervalMs: 10});
  await new Promise(resolve => setTimeout(resolve, 0));
  session.cancel();

  assert.deepEqual(releases, []);
  assert.equal(registry.has(10), true);
  sessionState = 2;
  await execution;
  assert.deepEqual(releases, [10]);
  assert.equal(registry.size, 0);
});

test('throwing log callback still releases the handle after terminal state', async () => {
  sessionState = 1;
  logEntries = [{sessionId: 11, level: 32, message: 'log'}];
  registry.retain(5120, 11);
  const error = new Error('log callback failed');

  const execution = new FFmpegSession(11, '-version').executeAsync({
    logCallback: () => {
      sessionState = 2;
      throw error;
    },
    pollIntervalMs: 10,
  });

  await assert.rejects(execution, reason => reason === error);
  assert.deepEqual(releases, [11]);
  assert.equal(registry.size, 0);
  assert.equal(manager.activeSessionCount, 0);
});

test('throwing statistics callback still releases the handle after terminal state', async () => {
  sessionState = 1;
  statisticsEntries = [{sessionId: 12, timeElapsed: 1}];
  registry.retain(6144, 12);
  const error = new Error('statistics callback failed');

  const execution = new FFmpegSession(12, '-version').executeAsync({
    statisticsCallback: () => {
      sessionState = 2;
      throw error;
    },
    pollIntervalMs: 10,
  });

  await assert.rejects(execution, reason => reason === error);
  assert.deepEqual(releases, [12]);
  assert.equal(registry.size, 0);
  assert.equal(manager.activeSessionCount, 0);
});

test('throwing completion callback releases the handle before rejecting', async () => {
  registry.retain(7168, 13);
  const error = new Error('completion callback failed');

  const execution = new FFmpegSession(13, '-version').executeAsync({
    completeCallback: () => {
      throw error;
    },
    pollIntervalMs: 10,
  });

  await assert.rejects(execution, reason => reason === error);
  assert.deepEqual(releases, [13]);
  assert.equal(registry.size, 0);
  assert.equal(manager.activeSessionCount, 0);
});

test('callback failure combined with cancellation still releases once', async () => {
  sessionState = 1;
  logEntries = [{sessionId: 14, level: 32, message: 'cancel'}];
  registry.retain(8192, 14);
  const error = new Error('cancelled callback failed');

  const session = new FFmpegSession(14, '-version');
  const execution = session.executeAsync({
    logCallback: () => {
      session.cancel();
      sessionState = 2;
      throw error;
    },
    pollIntervalMs: 10,
  });

  await assert.rejects(execution, reason => reason === error);
  assert.equal(session.isCancelled, true);
  assert.deepEqual(releases, [14]);
  assert.equal(registry.size, 0);
  assert.equal(manager.activeSessionCount, 0);
});

test('callback failure on a failed native session still releases once', async () => {
  sessionState = 3;
  registry.retain(9216, 15);
  const error = new Error('failed-session callback failed');

  const execution = new FFmpegSession(15, '-version').executeAsync({
    completeCallback: () => {
      throw error;
    },
    pollIntervalMs: 10,
  });

  await assert.rejects(execution, reason => reason === error);
  assert.deepEqual(releases, [15]);
  assert.equal(registry.size, 0);
  assert.equal(manager.activeSessionCount, 0);
});
