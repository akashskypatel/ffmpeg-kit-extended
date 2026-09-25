'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const calls = {state: 0, json: 0, release: 0, start: 0};
let state = 0;
let completionTimer;

const {setBackend} = require('../.test-dist/platform/backend-registry.js');
setBackend({
  getSessionState: () => {
    calls.state += 1;
    return state;
  },
  getSessionJson: () => {
    calls.json += 1;
    throw new Error('monitor must not read full session JSON');
  },
  executeSessionAsync: () => {
    calls.start += 1;
    state = 1;
    completionTimer = setTimeout(() => {
      state = 2;
    }, 0);
  },
  releaseSessionHandle: () => {
    calls.release += 1;
  },
  installCompletionBridge: () => {},
  uninstallCompletionBridge: () => {},
  cancelSession: () => {},
  getLogsJson: () => '[]',
  getStatisticsJson: () => '[]',
});

const {FFmpegSession} = require('../.test-dist/session.js');
const {SessionQueueManager} = require('../.test-dist/session-queue-manager.js');

test.afterEach(async () => {
  clearTimeout(completionTimer);
  completionTimer = undefined;
  state = 0;
  calls.state = 0;
  calls.json = 0;
  calls.release = 0;
  calls.start = 0;
  SessionQueueManager.shared.clearQueue();
  await SessionQueueManager.shared.waitForAll();
});

test('monitor polls scalar state without serializing full session snapshots', async () => {
  const session = new FFmpegSession(901, '-version');

  await session.executeAsync({pollIntervalMs: 10});

  assert.equal(calls.start, 1);
  assert.ok(calls.state >= 2);
  assert.equal(calls.json, 0);
  assert.equal(calls.release, 1);
});
