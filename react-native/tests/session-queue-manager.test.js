'use strict';

const assert = require('node:assert/strict');
const {afterEach, test} = require('node:test');

const {
  SessionCancelledException,
  SessionQueueManager,
} = require('../.test-dist/session-queue-manager.js');

const manager = SessionQueueManager.shared;

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return {promise, resolve, reject};
}

function createSession() {
  return {
    cancelCount: 0,
    cancel() {
      this.cancelCount += 1;
    },
  };
}

afterEach(async () => {
  manager.cancelAll();
  manager.maxConcurrentSessions = 8;
  await manager.waitForAll();
});

test('maxConcurrentSessions rejects invalid values', () => {
  assert.throws(
    () => {
      manager.maxConcurrentSessions = 0;
    },
    /integer of at least 1/,
  );
  assert.throws(
    () => {
      manager.maxConcurrentSessions = 1.5;
    },
    /integer of at least 1/,
  );
});

test('executeSession respects the configured concurrency limit', async () => {
  manager.maxConcurrentSessions = 1;
  const firstGate = deferred();
  const executionOrder = [];

  const first = manager.executeSession(createSession(), async () => {
    executionOrder.push('first:start');
    await firstGate.promise;
    executionOrder.push('first:end');
    return 'first';
  });
  const second = manager.executeSession(createSession(), async () => {
    executionOrder.push('second:start');
    return 'second';
  });

  assert.deepEqual(executionOrder, ['first:start']);
  assert.equal(manager.activeSessionCount, 1);
  assert.equal(manager.queueLength, 1);

  firstGate.resolve();

  assert.equal(await first, 'first');
  assert.equal(await second, 'second');
  assert.deepEqual(executionOrder, [
    'first:start',
    'first:end',
    'second:start',
  ]);
});

test('clearQueue rejects pending work without cancelling the active session', async () => {
  manager.maxConcurrentSessions = 1;
  const activeSession = createSession();
  const pendingSession = createSession();
  const gate = deferred();

  const active = manager.executeSession(activeSession, async () => {
    await gate.promise;
    return 'active';
  });
  const pending = manager.executeSession(pendingSession, async () => 'pending');

  manager.clearQueue();

  await assert.rejects(pending, SessionCancelledException);
  assert.equal(activeSession.cancelCount, 0);
  assert.equal(pendingSession.cancelCount, 0);

  gate.resolve();
  assert.equal(await active, 'active');
});

test('cancelCurrent cancels every active session', async () => {
  manager.maxConcurrentSessions = 2;
  const firstSession = createSession();
  const secondSession = createSession();
  const firstGate = deferred();
  const secondGate = deferred();

  const first = manager.executeSession(firstSession, async () => {
    await firstGate.promise;
  });
  const second = manager.executeSession(secondSession, async () => {
    await secondGate.promise;
  });

  manager.cancelCurrent();

  assert.equal(firstSession.cancelCount, 1);
  assert.equal(secondSession.cancelCount, 1);

  firstGate.resolve();
  secondGate.resolve();
  await Promise.all([first, second]);
});
