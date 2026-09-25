'use strict';

const assert = require('node:assert/strict');
const {afterEach, beforeEach, test} = require('node:test');

const {getBackend, setBackend} = require('../.test-dist/platform/backend-registry.js');
const {WasmSessionRegistry} = require('../.test-dist/platform/web/session-registry.js');
const {
  SessionCancelledException,
  SessionQueueManager,
} = require('../.test-dist/session-queue-manager.js');

const registry = new WasmSessionRegistry();
const releases = [];
const cancelCalls = [];
let cancelAttempts = 0;
let logEntries = [];
let finalLogEntries = [];
let statisticsEntries = [];
let executionStarts = 0;
let sessionState = 2;
let stateError;
let startError;
let logReads = 0;
let logCountReads = 0;
let sessionLogCount = 0;
let redirectionEnabled = true;
let redirectionEnableCalls = 0;
let redirectionDisableCalls = 0;
let statisticsReads = 0;
const bridgeInstalls = {completion: 0, log: 0, statistics: 0};
const bridgeUninstalls = {completion: 0, log: 0, statistics: 0};
let preTerminalLogsError;
let preTerminalStatisticsError;
let finalLogsError;
let finalStatisticsError;
let releaseError;
let cancelError;
let useDirectLogBridge = false;
let directLogBridgeActive = false;
let logEventHandler;
let directLogEvents = [];
setBackend({
  executeSessionAsync: () => {
    if (startError) throw startError;
    executionStarts += 1;
    if (redirectionEnabled) {
      for (const event of directLogEvents) logEventHandler?.(event);
    }
  },
  getLogsJson: (_sessionId, fromIndex) => {
    logReads += 1;
    if (!redirectionEnabled) return JSON.stringify([]);
    if (preTerminalLogsError && logReads === 1) throw preTerminalLogsError;
    if (finalLogsError && logReads === 2) throw finalLogsError;
    return JSON.stringify(logReads === 1 && fromIndex === 0 ? logEntries : finalLogEntries);
  },
  getLogsCount: () => {
    logCountReads += 1;
    return redirectionEnabled ? sessionLogCount : 0;
  },
  getStatisticsJson: (_sessionId, fromIndex) => {
    statisticsReads += 1;
    if (!redirectionEnabled) return JSON.stringify([]);
    if (preTerminalStatisticsError && statisticsReads === 1) {
      throw preTerminalStatisticsError;
    }
    if (finalStatisticsError && statisticsReads === 2) throw finalStatisticsError;
    return JSON.stringify(fromIndex === 0 ? statisticsEntries : []);
  },
  installCompletionBridge: () => { bridgeInstalls.completion += 1; },
  uninstallCompletionBridge: () => { bridgeUninstalls.completion += 1; },
  installLogBridge: () => {
    bridgeInstalls.log += 1;
    directLogBridgeActive = useDirectLogBridge;
  },
  uninstallLogBridge: () => {
    bridgeUninstalls.log += 1;
    directLogBridgeActive = false;
  },
  isDirectLogBridgeActive: () => directLogBridgeActive,
  onLogEvent: handler => {
    logEventHandler = handler;
    return {
      // The router keeps one process-wide backend subscription; individual
      // session removals are handled by the router rather than this fixture.
      remove: () => {},
    };
  },
  installStatisticsBridge: () => { bridgeInstalls.statistics += 1; },
  uninstallStatisticsBridge: () => { bridgeUninstalls.statistics += 1; },
  enableRedirection: () => {
    redirectionEnableCalls += 1;
    redirectionEnabled = true;
  },
  disableRedirection: () => {
    redirectionDisableCalls += 1;
    redirectionEnabled = false;
  },
  getSessionState: () => {
    if (stateError) throw stateError;
    return sessionState;
  },
  getSessionJson: () => {
    throw new Error('full session snapshot must not be used by monitor state reads');
  },
  cancelSession: sessionId => {
    cancelAttempts += 1;
    if (cancelError) throw cancelError;
    cancelCalls.push(sessionId);
  },
  releaseSessionHandle: sessionId => {
    releases.push(sessionId);
    if (releaseError) throw releaseError;
    registry.take(sessionId);
  },
});

const {FFmpegSession} = require('../.test-dist/session.js');
const {FFmpegKitExtended} = require('../.test-dist/ffmpeg-kit-extended.js');
const manager = SessionQueueManager.shared;

beforeEach(() => {
  registry.clear();
  cancelCalls.length = 0;
  cancelAttempts = 0;
  releases.length = 0;
  logEntries = [];
  finalLogEntries = [];
  statisticsEntries = [];
  executionStarts = 0;
  sessionState = 2;
  stateError = undefined;
  startError = undefined;
  logReads = 0;
  logCountReads = 0;
  sessionLogCount = 0;
  redirectionEnabled = true;
  redirectionEnableCalls = 0;
  redirectionDisableCalls = 0;
  statisticsReads = 0;
  bridgeInstalls.completion = 0;
  bridgeInstalls.log = 0;
  bridgeInstalls.statistics = 0;
  bridgeUninstalls.completion = 0;
  bridgeUninstalls.log = 0;
  bridgeUninstalls.statistics = 0;
  preTerminalLogsError = undefined;
  preTerminalStatisticsError = undefined;
  finalLogsError = undefined;
  finalStatisticsError = undefined;
  releaseError = undefined;
  cancelError = undefined;
  useDirectLogBridge = false;
  directLogBridgeActive = false;
  directLogEvents = [];
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

test('the same session cannot be submitted twice while active', async () => {
  sessionState = 1;
  registry.retain(2048, 30);
  const session = new FFmpegSession(30, '-version');
  const execution = session.executeAsync({pollIntervalMs: 10});
  await new Promise(resolve => setTimeout(resolve, 0));

  await assert.rejects(
    session.executeAsync(),
    /already submitted for execution/,
  );
  assert.equal(executionStarts, 1);
  sessionState = 2;
  await execution;
});

test('the same session cannot be submitted twice while queued', async () => {
  manager.maxConcurrentSessions = 1;
  let releaseActive;
  const active = manager.executeSession({cancel() {}}, () => new Promise(resolve => {
    releaseActive = resolve;
  }));
  registry.retain(3072, 31);
  const session = new FFmpegSession(31, '-version');
  const pending = session.executeAsync();

  assert.equal(manager.queueLength, 1);
  await assert.rejects(session.executeAsync(), /already submitted for execution/);
  releaseActive();
  await active;
  await pending;
  assert.equal(executionStarts, 1);
});

test('the same session cannot be submitted again after successful completion', async () => {
  registry.retain(4096, 32);
  const session = new FFmpegSession(32, '-version');
  await session.executeAsync({pollIntervalMs: 10});

  await assert.rejects(
    session.executeAsync(),
    /already submitted for execution/,
  );
  assert.equal(executionStarts, 1);
});

test('clearing a queued session consumes its one-shot submission', async () => {
  manager.maxConcurrentSessions = 1;
  let releaseActive;
  const active = manager.executeSession({cancel() {}}, () => new Promise(resolve => {
    releaseActive = resolve;
  }));
  registry.retain(5120, 33);
  const session = new FFmpegSession(33, '-version');
  const pending = session.executeAsync();

  manager.clearQueue();
  await assert.rejects(pending, SessionCancelledException);
  await assert.rejects(session.executeAsync(), /already submitted for execution/);
  assert.equal(executionStarts, 0);
  assert.deepEqual(releases, [33]);
  releaseActive();
  await active;
});

test('normally completed session releases its Wasm handle exactly once', async () => {
  registry.retain(2048, 7);
  await new FFmpegSession(7, '-version').executeAsync({pollIntervalMs: 10});

  assert.equal(executionStarts, 1);
  assert.deepEqual(releases, [7]);
  assert.equal(registry.has(7), false);
});
test('Created cancellation prevents later submission', async () => {
  sessionState = 0;
  registry.retain(1024, 6);
  const session = new FFmpegSession(6, '-version');

  session.cancel();

  assert.equal(session.isCancelled, true);
  await assert.rejects(session.executeAsync(), SessionCancelledException);
  assert.equal(executionStarts, 0);
  assert.equal(manager.queueLength, 0);
  assert.deepEqual(cancelCalls, []);
});

test('state-read failure latches cancellation before exposing the error', async () => {
  const error = new Error('state read failed during cancellation');
  stateError = error;
  registry.retain(1024, 20);
  const session = new FFmpegSession(20, '-version');

  assert.throws(() => session.cancel(), reason => reason === error);
  assert.equal(session.isCancelled, true);

  stateError = undefined;
  await assert.rejects(session.executeAsync(), SessionCancelledException);
  assert.equal(executionStarts, 0);
  assert.equal(manager.queueLength, 0);
  assert.deepEqual(cancelCalls, []);
});

test('queued cancellation removes work without native cancellation and releases ownership', async () => {
  manager.maxConcurrentSessions = 1;
  let releaseActive;
  const active = manager.executeSession({cancel() {}}, () => new Promise(resolve => {
    releaseActive = resolve;
  }));
  registry.retain(2048, 7);
  const session = new FFmpegSession(7, '-version');
  const pending = session.executeAsync();

  assert.equal(manager.queueLength, 1);
  session.cancel();

  await assert.rejects(pending, SessionCancelledException);
  assert.equal(executionStarts, 0);
  assert.deepEqual(cancelCalls, []);
  assert.deepEqual(releases, [7]);
  assert.equal(registry.has(7), false);

  releaseActive();
  await active;
});

test('a running history wrapper forwards cancellation despite not being submitted', () => {
  sessionState = 1;
  const session = new FFmpegSession(16, '-version');

  session.cancel();
  session.cancel();

  assert.equal(session.isCancelled, true);
  assert.deepEqual(cancelCalls, [16]);
});

test('immediate native cancellation failure preserves intent and allows monitor retry', async () => {
  const error = new Error('immediate native cancellation failed');
  sessionState = 1;
  cancelError = error;
  registry.retain(14336, 20);
  const session = new FFmpegSession(20, '-version');
  const execution = session.executeAsync({pollIntervalMs: 10});

  await new Promise(resolve => setTimeout(resolve, 0));
  assert.equal(executionStarts, 1);

  assert.throws(() => session.cancel(), reason => reason === error);
  assert.equal(session.isCancelled, true);
  assert.equal(cancelAttempts, 1);
  assert.deepEqual(cancelCalls, []);

  cancelError = undefined;
  await new Promise(resolve => setTimeout(resolve, 25));
  assert.equal(cancelAttempts, 2);
  assert.deepEqual(cancelCalls, [20]);

  sessionState = 2;
  await execution;
  await manager.waitForAll();
  assert.deepEqual(releases, [20]);
  assert.equal(manager.activeSessionCount, 0);
});

test('startup-handoff cancellation waits for Running and dispatches once', async () => {
  sessionState = 0;
  registry.retain(11264, 17);
  const session = new FFmpegSession(17, '-version');
  const execution = session.executeAsync({pollIntervalMs: 10});

  await new Promise(resolve => setTimeout(resolve, 0));
  assert.equal(executionStarts, 1);

  session.cancel();

  assert.equal(session.isCancelled, true);
  assert.equal(cancelAttempts, 0);
  assert.deepEqual(cancelCalls, []);
  assert.equal(manager.activeSessionCount, 1);

  sessionState = 1;
  await new Promise(resolve => setTimeout(resolve, 25));
  assert.equal(cancelAttempts, 1);
  assert.deepEqual(cancelCalls, [17]);

  await new Promise(resolve => setTimeout(resolve, 25));
  assert.equal(cancelAttempts, 1);
  assert.deepEqual(cancelCalls, [17]);

  sessionState = 2;
  await execution;
  await manager.waitForAll();
  assert.deepEqual(releases, [17]);
  assert.equal(manager.activeSessionCount, 0);
});

test('deferred native cancellation failure preserves ownership and error authority', async () => {
  const error = new Error('deferred native cancellation failed');
  sessionState = 0;
  cancelError = error;
  registry.retain(12288, 18);
  const session = new FFmpegSession(18, '-version');
  const execution = session.executeAsync({pollIntervalMs: 10});

  await new Promise(resolve => setTimeout(resolve, 0));
  session.cancel();
  sessionState = 1;
  await new Promise(resolve => setTimeout(resolve, 25));

  assert.equal(cancelAttempts, 1);
  assert.deepEqual(releases, []);
  assert.equal(registry.has(18), true);

  cancelError = undefined;
  await new Promise(resolve => setTimeout(resolve, 25));
  assert.equal(cancelAttempts, 2);
  assert.deepEqual(cancelCalls, [18]);
  assert.deepEqual(releases, []);
  assert.equal(registry.has(18), true);

  sessionState = 2;
  await assert.rejects(execution, reason => reason === error);
  assert.deepEqual(releases, [18]);
  assert.equal(registry.has(18), false);
  assert.equal(manager.activeSessionCount, 0);
});

test('completion before Running observation wins without late cancellation', async () => {
  sessionState = 0;
  registry.retain(13312, 19);
  const session = new FFmpegSession(19, '-version');
  const execution = session.executeAsync({pollIntervalMs: 10});

  await new Promise(resolve => setTimeout(resolve, 0));
  session.cancel();
  sessionState = 2;

  await execution;
  assert.equal(session.isCancelled, true);
  assert.equal(cancelAttempts, 0);
  assert.deepEqual(cancelCalls, []);
  assert.deepEqual(releases, [19]);
  assert.equal(registry.has(19), false);
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
  assert.deepEqual(cancelCalls, [10]);

  assert.deepEqual(releases, []);
  assert.equal(registry.has(10), true);
  sessionState = 2;
  await execution;
  assert.deepEqual(releases, [10]);
  assert.equal(registry.size, 0);
});

test('no optional consumers skip log/statistics traffic but keep completion demand', async () => {
  registry.retain(4096, 26);
  await new FFmpegSession(26, '-version').executeAsync({pollIntervalMs: 10});

  assert.equal(logReads, 0);
  assert.equal(statisticsReads, 0);
  assert.deepEqual(bridgeInstalls, {completion: 1, log: 0, statistics: 0});
  assert.deepEqual(bridgeUninstalls, {completion: 1, log: 0, statistics: 0});
  assert.deepEqual(releases, [26]);
  assert.equal(registry.size, 0);
});

test('removing the last session log sink releases optional demand immediately', async () => {
  sessionState = 1;
  logEntries = [{sessionId: 27, level: 32, message: 'remove-me'}];
  registry.retain(5120, 27);
  const session = new FFmpegSession(27, '-version');
  let callbacks = 0;
  session.setLogCallback(() => {
    callbacks += 1;
    session.removeLogCallback();
    sessionState = 2;
  });

  await session.executeAsync({pollIntervalMs: 10});

  assert.equal(callbacks, 1);
  assert.equal(logReads, 1);
  assert.equal(bridgeInstalls.log, 1);
  assert.equal(bridgeUninstalls.log, 1);
  assert.deepEqual(releases, [27]);
});

test('disabled redirection preserves completion without log or statistics delivery', async () => {
  useDirectLogBridge = true;
  sessionState = 1;
  sessionLogCount = 1;
  directLogEvents = [{sessionId: 29, sequence: 0, level: 32, message: 'hidden'}];
  statisticsEntries = [{time: 1}];
  registry.retain(17920, 29);
  const logs = [];
  const statistics = [];

  FFmpegKitExtended.disableRedirection();
  try {
    const execution = new FFmpegSession(29, '-version').executeAsync({
      logCallback: log => logs.push(log),
      statisticsCallback: value => statistics.push(value),
      pollIntervalMs: 10,
    });

    await new Promise(resolve => setTimeout(resolve, 0));
    sessionState = 2;
    await execution;

    assert.deepEqual(logs, []);
    assert.deepEqual(statistics, []);
    assert.equal(redirectionDisableCalls, 1);
    assert.equal(redirectionEnableCalls, 0);
  } finally {
    FFmpegKitExtended.enableRedirection();
  }
});

test('explicitly enabled redirection delivers direct logs without wrapper reconfiguration', async () => {
  useDirectLogBridge = true;
  sessionState = 1;
  directLogEvents = [{sessionId: 32, sequence: 0, level: 32, message: 'visible'}];
  registry.retain(18432, 32);
  const logs = [];

  FFmpegKitExtended.enableRedirection();
  const execution = new FFmpegSession(32, '-version').executeAsync({
    logCallback: log => logs.push(log),
    pollIntervalMs: 10,
  });

  await new Promise(resolve => setTimeout(resolve, 0));
  sessionState = 2;
  await execution;

  assert.deepEqual(logs, [{sessionId: 32, level: 32, message: 'visible'}]);
  assert.equal(redirectionEnableCalls, 1);
  assert.equal(redirectionDisableCalls, 0);
});

test('direct v2 logs preserve sequence order without live history reads', async () => {
  useDirectLogBridge = true;
  sessionState = 1;
  sessionLogCount = 2;
  directLogEvents = [
    {sessionId: 28, sequence: 1, level: 33, message: 'second'},
    {sessionId: 28, sequence: 0, level: 32, message: 'first'},
    {sessionId: 28, sequence: 0, level: 34, message: 'duplicate'},
  ];
  registry.retain(17408, 28);
  const received = [];
  const execution = new FFmpegSession(28, '-version').executeAsync({
    logCallback: log => received.push(log),
    pollIntervalMs: 10,
  });

  await new Promise(resolve => setTimeout(resolve, 0));
  assert.deepEqual(received, [
    {sessionId: 28, level: 32, message: 'first'},
    {sessionId: 28, level: 33, message: 'second'},
  ]);
  assert.equal(logReads, 0);
  assert.equal(bridgeInstalls.log, 1);

  sessionState = 2;
  await execution;
  assert.equal(logCountReads, 1);
  assert.equal(bridgeUninstalls.log, 1);
  assert.deepEqual(releases, [28]);
});

test('terminal reconciliation recovers a direct-log gap with one bounded history read', async () => {
  useDirectLogBridge = true;
  sessionState = 1;
  sessionLogCount = 3;
  directLogEvents = [{sessionId: 30, sequence: 2, level: 34, message: 'third'}];
  finalLogEntries = [
    {sessionId: 30, level: 32, message: 'first'},
    {sessionId: 30, level: 33, message: 'second'},
    {sessionId: 30, level: 34, message: 'third'},
  ];
  logEntries = finalLogEntries;
  registry.retain(19456, 30);
  const received = [];
  const execution = new FFmpegSession(30, '-version').executeAsync({
    logCallback: log => received.push(log),
    pollIntervalMs: 10,
  });

  await new Promise(resolve => setTimeout(resolve, 0));
  sessionState = 2;
  await execution;

  assert.deepEqual(received, [
    {sessionId: 30, level: 32, message: 'first'},
    {sessionId: 30, level: 33, message: 'second'},
    {sessionId: 30, level: 34, message: 'third'},
  ]);
  assert.equal(logCountReads, 1);
  assert.equal(logReads, 1);
  assert.deepEqual(releases, [30]);
});

test('terminal reconciliation preserves a getter error as the first failure', async () => {
  useDirectLogBridge = true;
  sessionState = 1;
  sessionLogCount = 1;
  const reconciliationError = new Error('terminal log count failed');
  const originalGetLogsCount = getBackend().getLogsCount;
  getBackend().getLogsCount = () => {
    throw reconciliationError;
  };
  registry.retain(19968, 31);
  const execution = new FFmpegSession(31, '-version').executeAsync({
    logCallback: () => {},
    pollIntervalMs: 10,
  });

  await new Promise(resolve => setTimeout(resolve, 0));
  sessionState = 2;
  await assert.rejects(execution, error => error === reconciliationError);
  getBackend().getLogsCount = originalGetLogsCount;
  assert.deepEqual(releases, [31]);
});

test('direct v2 callback failure keeps the existing first-error policy', async () => {
  useDirectLogBridge = true;
  sessionState = 1;
  const callbackError = new Error('direct callback failed');
  directLogEvents = [{sessionId: 29, sequence: 0, level: 32, message: 'throws'}];
  registry.retain(18432, 29);

  const execution = new FFmpegSession(29, '-version').executeAsync({
    logCallback: () => {
      throw callbackError;
    },
    pollIntervalMs: 10,
  });

  await new Promise(resolve => setTimeout(resolve, 0));
  assert.equal(logReads, 0);
  sessionState = 2;
  await assert.rejects(execution, error => error === callbackError);
  assert.deepEqual(releases, [29]);
  assert.equal(bridgeUninstalls.log, 1);
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

test('state retrieval failure releases the owning handle and rejects', async () => {
  sessionState = 1;
  const error = new Error('state read failed');
  stateError = error;
  registry.retain(10240, 20);

  const execution = new FFmpegSession(20, '-version').executeAsync({pollIntervalMs: 10});

  await assert.rejects(execution, reason => reason === error);
  assert.deepEqual(releases, [20]);
  assert.equal(registry.has(20), false);
  assert.equal(manager.activeSessionCount, 0);
  assert.equal(manager.queueLength, 0);
});

test('state failure remains primary when handle release fails and can be retried', async () => {
  sessionState = 1;
  const stateFailure = new Error('state read failed first');
  const releaseFailure = new Error('release failed second');
  stateError = stateFailure;
  releaseError = releaseFailure;
  registry.retain(14336, 23);
  const session = new FFmpegSession(23, '-version');

  await assert.rejects(
    session.executeAsync({pollIntervalMs: 10}),
    error => error === stateFailure,
  );
  assert.deepEqual(releases, [23]);
  assert.equal(registry.has(23), true);

  stateError = undefined;
  releaseError = undefined;
  sessionState = 2;
  getBackend().releaseSessionHandle(23);
  assert.deepEqual(releases, [23, 23]);
  assert.equal(registry.has(23), false);
});

test('release failure after terminal state remains observable and retryable', async () => {
  const releaseFailure = new Error('terminal release failed');
  releaseError = releaseFailure;
  registry.retain(15360, 24);
  const session = new FFmpegSession(24, '-version');

  await assert.rejects(
    session.executeAsync({pollIntervalMs: 10}),
    error => error === releaseFailure,
  );
  assert.deepEqual(releases, [24]);
  assert.equal(registry.has(24), true);

  releaseError = undefined;
  getBackend().releaseSessionHandle(24);
  assert.deepEqual(releases, [24, 24]);
  assert.equal(registry.has(24), false);
});

test('callback failure remains primary when terminal release fails', async () => {
  sessionState = 1;
  logEntries = [{sessionId: 25, level: 32, message: 'callback-first'}];
  const callbackFailure = new Error('callback failed first');
  releaseError = new Error('release failed second');
  registry.retain(16384, 25);
  const session = new FFmpegSession(25, '-version');

  await assert.rejects(
    session.executeAsync({
      logCallback: () => {
        sessionState = 2;
        throw callbackFailure;
      },
      pollIntervalMs: 10,
    }),
    error => error === callbackFailure,
  );
  assert.deepEqual(releases, [25]);
  assert.equal(registry.has(25), true);
});

test('first callback failure wins over a later pre-terminal monitor failure', async () => {
  sessionState = 1;
  logEntries = [{sessionId: 21, level: 32, message: 'callback-first'}];
  const callbackError = new Error('callback failure first');
  const monitorError = new Error('statistics failure later');
  preTerminalStatisticsError = monitorError;
  registry.retain(11264, 21);
  let statisticsCallbacks = 0;
  let completionCallbacks = 0;

  const execution = new FFmpegSession(21, '-version').executeAsync({
    logCallback: () => {
      throw callbackError;
    },
    statisticsCallback: () => statisticsCallbacks++,
    completeCallback: () => completionCallbacks++,
    pollIntervalMs: 10,
  });

  let settled = false;
  execution.then(
    () => {
      settled = true;
    },
    () => {
      settled = true;
    },
  );
  await new Promise(resolve => setTimeout(resolve, 25));
  assert.equal(settled, false);
  assert.deepEqual(releases, []);
  assert.equal(registry.has(21), true);

  sessionState = 2;
  await assert.rejects(execution, reason => reason === callbackError);
  assert.deepEqual(releases, [21]);
  assert.equal(registry.has(21), false);
  assert.equal(manager.activeSessionCount, 0);
  assert.equal(statisticsCallbacks, 0);
  assert.equal(completionCallbacks, 0);
});

test('first final callback failure wins over a later final monitor failure', async () => {
  finalLogEntries = [{sessionId: 22, level: 32, message: 'final-callback-first'}];
  const callbackError = new Error('final callback failure first');
  const monitorError = new Error('final statistics failure later');
  finalStatisticsError = monitorError;
  registry.retain(12288, 22);
  let statisticsCallbacks = 0;
  let completionCallbacks = 0;

  const execution = new FFmpegSession(22, '-version').executeAsync({
    logCallback: () => {
      throw callbackError;
    },
    statisticsCallback: () => statisticsCallbacks++,
    completeCallback: () => completionCallbacks++,
    pollIntervalMs: 10,
  });

  await assert.rejects(execution, reason => reason === callbackError);
  assert.deepEqual(releases, [22]);
  assert.equal(registry.has(22), false);
  assert.equal(manager.activeSessionCount, 0);
  assert.equal(statisticsCallbacks, 0);
  assert.equal(completionCallbacks, 0);
});

test('pre-terminal log retrieval failure drains to terminal before releasing', async () => {
  sessionState = 1;
  const error = new Error('pre-terminal log read failed');
  preTerminalLogsError = error;
  logEntries = [{sessionId: 18, level: 32, message: 'suppressed'}];
  statisticsEntries = [{sessionId: 18, timeElapsed: 1}];
  registry.retain(12288, 18);
  let logCallbacks = 0;
  let statisticsCallbacks = 0;
  let completionCallbacks = 0;

  const execution = new FFmpegSession(18, '-version').executeAsync({
    logCallback: () => logCallbacks++,
    statisticsCallback: () => statisticsCallbacks++,
    completeCallback: () => completionCallbacks++,
    pollIntervalMs: 10,
  });
  let settled = false;
  execution.then(
    () => {
      settled = true;
    },
    () => {
      settled = true;
    },
  );

  await new Promise(resolve => setTimeout(resolve, 25));
  assert.equal(settled, false);
  assert.deepEqual(releases, []);
  assert.equal(registry.has(18), true);
  assert.equal(manager.activeSessionCount, 1);

  sessionState = 2;
  await assert.rejects(execution, reason => reason === error);
  assert.deepEqual(releases, [18]);
  assert.equal(registry.has(18), false);
  assert.equal(manager.activeSessionCount, 0);
  assert.equal(logCallbacks, 0);
  assert.equal(statisticsCallbacks, 0);
  assert.equal(completionCallbacks, 0);
});

test('pre-terminal statistics retrieval failure drains to terminal before releasing', async () => {
  sessionState = 1;
  const error = new Error('pre-terminal statistics read failed');
  preTerminalStatisticsError = error;
  statisticsEntries = [{sessionId: 19, timeElapsed: 1}];
  registry.retain(13312, 19);
  let logCallbacks = 0;
  let statisticsCallbacks = 0;
  let completionCallbacks = 0;

  const execution = new FFmpegSession(19, '-version').executeAsync({
    logCallback: () => logCallbacks++,
    statisticsCallback: () => statisticsCallbacks++,
    completeCallback: () => completionCallbacks++,
    pollIntervalMs: 10,
  });
  let settled = false;
  execution.then(
    () => {
      settled = true;
    },
    () => {
      settled = true;
    },
  );

  await new Promise(resolve => setTimeout(resolve, 25));
  assert.equal(settled, false);
  assert.deepEqual(releases, []);
  assert.equal(registry.has(19), true);
  assert.equal(manager.activeSessionCount, 1);

  sessionState = 2;
  await assert.rejects(execution, reason => reason === error);
  assert.deepEqual(releases, [19]);
  assert.equal(registry.has(19), false);
  assert.equal(manager.activeSessionCount, 0);
  assert.equal(logCallbacks, 0);
  assert.equal(statisticsCallbacks, 0);
  assert.equal(completionCallbacks, 0);
});

test('final log retrieval failure releases the handle exactly once', async () => {
  const error = new Error('final log read failed');
  finalLogsError = error;
  registry.retain(10240, 16);

  const execution = new FFmpegSession(16, '-version').executeAsync({
    logCallback: () => {},
    pollIntervalMs: 10,
  });

  await assert.rejects(execution, reason => reason === error);
  await manager.waitForAll();
  assert.deepEqual(releases, [16]);
  assert.equal(registry.has(16), false);
  assert.equal(manager.activeSessionCount, 0);
});

test('final statistics retrieval failure releases the handle exactly once', async () => {
  const error = new Error('final statistics read failed');
  finalStatisticsError = error;
  registry.retain(11264, 17);

  const execution = new FFmpegSession(17, '-version').executeAsync({
    statisticsCallback: () => {},
    pollIntervalMs: 10,
  });

  await assert.rejects(execution, reason => reason === error);
  await manager.waitForAll();
  assert.deepEqual(releases, [17]);
  assert.equal(registry.has(17), false);
  assert.equal(manager.activeSessionCount, 0);
});
