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

test('clearQueue settles every pending item after discard cleanup failure', async () => {
  manager.maxConcurrentSessions = 1;
  const activeGate = deferred();
  const active = manager.executeSession(createSession(), async () => {
    await activeGate.promise;
  });
  const cleanupError = new Error('discard cleanup failed');
  let pendingBCleanupCount = 0;
  const pendingA = manager.executeSession(
    createSession(),
    async () => 'pending A',
    () => {
      throw cleanupError;
    },
  );
  const pendingB = manager.executeSession(
    createSession(),
    async () => 'pending B',
    () => {
      pendingBCleanupCount += 1;
    },
  );

  assert.doesNotThrow(() => manager.clearQueue());

  await assert.rejects(pendingA, reason => reason === cleanupError);
  await assert.rejects(pendingB, SessionCancelledException);
  assert.equal(pendingBCleanupCount, 1);
  assert.equal(manager.queueLength, 0);

  activeGate.resolve();
  await active;
});

test('cancelQueued removes only the targeted session and preserves later work', async () => {
  manager.maxConcurrentSessions = 1;
  const activeGate = deferred();
  const starts = [];
  const active = manager.executeSession(createSession(), async () => {
    starts.push('A');
    await activeGate.promise;
  });
  const sessionB = createSession();
  const sessionC = createSession();
  const pendingB = manager.executeSession(sessionB, async () => {
    starts.push('B');
  });
  const pendingC = manager.executeSession(sessionC, async () => {
    starts.push('C');
    return 'C';
  });

  assert.equal(manager.cancelQueued(sessionB), true);
  await assert.rejects(pendingB, SessionCancelledException);
  assert.equal(manager.queueLength, 1);

  activeGate.resolve();
  await active;
  assert.equal(await pendingC, 'C');
  assert.deepEqual(starts, ['A', 'C']);
});

test('cancelQueued preserves later work when targeted discard cleanup fails', async () => {
  manager.maxConcurrentSessions = 1;
  const activeGate = deferred();
  const starts = [];
  const active = manager.executeSession(createSession(), async () => {
    starts.push('A');
    await activeGate.promise;
  });
  const cleanupError = new Error('targeted discard cleanup failed');
  const sessionB = createSession();
  const sessionC = createSession();
  const pendingB = manager.executeSession(
    sessionB,
    async () => {
      starts.push('B');
    },
    () => {
      throw cleanupError;
    },
  );
  const pendingC = manager.executeSession(sessionC, async () => {
    starts.push('C');
    return 'C';
  });

  assert.equal(manager.cancelQueued(sessionB), true);
  await assert.rejects(pendingB, reason => reason === cleanupError);
  assert.equal(manager.queueLength, 1);

  activeGate.resolve();
  await active;
  assert.equal(await pendingC, 'C');
  assert.deepEqual(starts, ['A', 'C']);
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

test('cancelCurrent attempts every active session before rethrowing the first error', async () => {
  manager.maxConcurrentSessions = 2;
  const firstError = new Error('first cancellation failed');
  const firstSession = createSession();
  firstSession.cancel = function cancel() {
    this.cancelCount += 1;
    throw firstError;
  };
  const secondSession = createSession();
  const firstGate = deferred();
  const secondGate = deferred();

  const first = manager.executeSession(firstSession, async () => firstGate.promise);
  const second = manager.executeSession(secondSession, async () => secondGate.promise);

  assert.throws(() => manager.cancelCurrent(), reason => reason === firstError);
  assert.equal(firstSession.cancelCount, 1);
  assert.equal(secondSession.cancelCount, 1);

  firstGate.resolve();
  secondGate.resolve();
  await Promise.all([first, second]);
});
