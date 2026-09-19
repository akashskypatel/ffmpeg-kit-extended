'use strict';

const assert = require('node:assert/strict');
const {afterEach, beforeEach, test} = require('node:test');

const {setBackend} = require('../.test-dist/platform/backend.js');
const {SessionCancelledException, SessionQueueManager} = require('../.test-dist/session-queue-manager.js');
const {SessionState} = require('../.test-dist/types.js');

let nextSessionId = 1;
let nextStartError;
let nextStateError;
let completeOnStart = false;
const sessionStates = new Map();
const stateErrors = new Map();
const releases = [];

setBackend({
  createFFplaySession: () => {
    const sessionId = nextSessionId++;
    sessionStates.set(sessionId, SessionState.Created);
    return sessionId;
  },
  executeSessionAsync: sessionId => {
    if (nextStartError) {
      const error = nextStartError;
      nextStartError = undefined;
      throw error;
    }
    if (nextStateError) {
      stateErrors.set(sessionId, nextStateError);
      nextStateError = undefined;
    }
    sessionStates.set(
      sessionId,
      completeOnStart ? SessionState.Completed : SessionState.Running,
    );
  },
  getSessionState: sessionId => {
    const error = stateErrors.get(sessionId);
    if (error) throw error;
    return sessionStates.get(sessionId) ?? SessionState.Failed;
  },
  getLogsJson: () => '[]',
  getStatisticsJson: () => '[]',
  releaseSessionHandle: sessionId => releases.push(sessionId),
  cancelSession: () => {},
  ffplayIsPlaying: sessionId => sessionStates.get(sessionId) === SessionState.Running,
  ffplayIsPaused: () => false,
});

const {FFplayKit} = require('../.test-dist/ffplay-kit.js');
const manager = SessionQueueManager.shared;

beforeEach(() => {
  nextSessionId = 1;
  nextStartError = undefined;
  nextStateError = undefined;
  completeOnStart = false;
  sessionStates.clear();
  stateErrors.clear();
  releases.length = 0;
});

afterEach(async () => {
  manager.clearQueue();
  for (const [sessionId, state] of sessionStates) {
    if (state === SessionState.Running) sessionStates.set(sessionId, SessionState.Completed);
  }
  manager.maxConcurrentSessions = 8;
  await manager.waitForAll();
});

test('successful FFplay execution remains current until its Promise settles', async () => {
  const execution = FFplayKit.executeAsync('-version', {}, 500);
  const session = FFplayKit.currentSession;

  assert.ok(session);
  assert.equal(FFplayKit.getCurrentSession(), session);
  assert.equal(FFplayKit.playing, true);
  sessionStates.set(session.sessionId, SessionState.Completed);

  assert.equal(await execution, session);
  assert.equal(FFplayKit.currentSession, undefined);
  assert.equal(FFplayKit.playing, false);
  assert.equal(FFplayKit.paused, false);
});

test('native-start failure clears the active FFplay session and preserves the error', async () => {
  const error = new Error('native start failed');
  nextStartError = error;

  const execution = FFplayKit.executeAsync('-version');
  assert.ok(FFplayKit.currentSession);

  await assert.rejects(execution, reason => reason === error);
  assert.equal(FFplayKit.currentSession, undefined);
  assert.equal(FFplayKit.playing, false);
  assert.equal(FFplayKit.paused, false);
});

test('monitor state failure clears the active FFplay session and preserves the error', async () => {
  const error = new Error('state read failed');
  nextStateError = error;

  const execution = FFplayKit.executeAsync('-version');
  assert.ok(FFplayKit.currentSession);

  await assert.rejects(execution, reason => reason === error);
  assert.equal(FFplayKit.currentSession, undefined);
  assert.equal(FFplayKit.playing, false);
  assert.equal(FFplayKit.paused, false);
});

test('completion callback errors reject execution and still clear the active session', async () => {
  const error = new Error('completion callback failed');
  completeOnStart = true;
  let callbackSession;

  const execution = FFplayKit.executeAsync('-version', {
    completeCallback: session => {
      callbackSession = session;
      throw error;
    },
  });
  const session = FFplayKit.currentSession;

  assert.ok(session);
  await assert.rejects(execution, reason => reason === error);
  assert.equal(callbackSession, session);
  assert.equal(FFplayKit.currentSession, undefined);
});

test('an older FFplay settlement cannot clear a newer active session', async () => {
  const firstExecution = FFplayKit.executeAsync('first', {pollIntervalMs: 10});
  const firstSession = FFplayKit.currentSession;
  assert.ok(firstSession);

  const secondExecution = FFplayKit.executeAsync('second', {pollIntervalMs: 10});
  const secondSession = FFplayKit.currentSession;
  assert.ok(secondSession);
  assert.notEqual(firstSession.sessionId, secondSession.sessionId);

  sessionStates.set(firstSession.sessionId, SessionState.Completed);
  await firstExecution;
  assert.equal(FFplayKit.currentSession, secondSession);

  sessionStates.set(secondSession.sessionId, SessionState.Completed);
  await secondExecution;
  assert.equal(FFplayKit.currentSession, undefined);
});

test('newer FFplay settlement falls back to the older unsettled session', async () => {
  const firstExecution = FFplayKit.executeAsync('first', {pollIntervalMs: 10});
  const firstSession = FFplayKit.currentSession;
  const secondExecution = FFplayKit.executeAsync('second', {pollIntervalMs: 10});
  const secondSession = FFplayKit.currentSession;

  assert.ok(firstSession);
  assert.ok(secondSession);
  sessionStates.set(secondSession.sessionId, SessionState.Completed);
  assert.equal(await secondExecution, secondSession);
  assert.equal(FFplayKit.currentSession, firstSession);

  sessionStates.set(firstSession.sessionId, SessionState.Completed);
  assert.equal(await firstExecution, firstSession);
  assert.equal(FFplayKit.currentSession, undefined);
});

test('newer FFplay start failure preserves the older unsettled session', async () => {
  const firstExecution = FFplayKit.executeAsync('first', {pollIntervalMs: 10});
  const firstSession = FFplayKit.currentSession;
  assert.ok(firstSession);

  const error = new Error('newer native start failed');
  nextStartError = error;
  const secondExecution = FFplayKit.executeAsync('second');
  await assert.rejects(secondExecution, reason => reason === error);
  assert.equal(FFplayKit.currentSession, firstSession);
  assert.equal(FFplayKit.playing, true);

  sessionStates.set(firstSession.sessionId, SessionState.Completed);
  await firstExecution;
  assert.equal(FFplayKit.currentSession, undefined);
});

test('discarding newer queued FFplay work falls back to the active session', async () => {
  manager.maxConcurrentSessions = 1;
  const firstExecution = FFplayKit.executeAsync('first', {pollIntervalMs: 10});
  const firstSession = FFplayKit.currentSession;
  assert.ok(firstSession);

  const secondExecution = FFplayKit.executeAsync('second');
  const secondSession = FFplayKit.currentSession;
  assert.ok(secondSession);
  assert.equal(manager.queueLength, 1);

  manager.clearQueue();
  await assert.rejects(secondExecution, SessionCancelledException);
  assert.equal(FFplayKit.currentSession, firstSession);

  sessionStates.set(firstSession.sessionId, SessionState.Completed);
  await firstExecution;
  assert.equal(FFplayKit.currentSession, undefined);
});
test('discarding a queued high-level FFplay execution clears its active session', async () => {
  manager.maxConcurrentSessions = 1;
  let releaseBlocker;
  const blocker = manager.executeSession({cancel() {}}, () => new Promise(resolve => {
    releaseBlocker = resolve;
  }));

  const execution = FFplayKit.executeAsync('queued');
  assert.ok(FFplayKit.currentSession);
  assert.equal(manager.queueLength, 1);

  manager.clearQueue();
  await assert.rejects(execution, SessionCancelledException);
  assert.equal(FFplayKit.currentSession, undefined);

  releaseBlocker();
  await blocker;
});
