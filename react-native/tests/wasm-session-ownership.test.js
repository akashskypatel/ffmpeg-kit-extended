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
let executionStarts = 0;
let sessionState = 2;
setBackend({
  executeSessionAsync: () => {
    executionStarts += 1;
  },
  getLogsJson: () => '[]',
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
  executionStarts = 0;
  sessionState = 2;
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
