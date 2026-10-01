'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  reconcileAbandonedSession,
} = require('../.test-dist/platform/native-session-reconciliation.js');

test('a non-empty native snapshot keeps an abandoned identity', () => {
  const abandoned = new Set([101]);

  reconcileAbandonedSession(101, abandoned, () => '{"sessionId":101}');

  assert.deepEqual([...abandoned], [101]);
});

test('an empty snapshot removes an abandoned identity', () => {
  const abandoned = new Set([102]);

  reconcileAbandonedSession(102, abandoned, () => '');

  assert.equal(abandoned.has(102), false);
});

test('a synchronous diagnostic is consumed by the probe and preserves the tombstone', () => {
  const abandoned = new Set([103]);
  let pendingDiagnostic = 'native session lookup failed';
  let probeCalls = 0;

  reconcileAbandonedSession(103, abandoned, () => {
    probeCalls += 1;
    const diagnostic = pendingDiagnostic;
    pendingDiagnostic = '';
    if (diagnostic) throw new Error(diagnostic);
    return '';
  });

  assert.equal(probeCalls, 1);
  assert.equal(pendingDiagnostic, '');
  assert.equal(abandoned.has(103), true);
});

test('a thrown probe preserves the abandoned identity', () => {
  const abandoned = new Set([104]);

  reconcileAbandonedSession(104, abandoned, () => {
    throw new Error('probe unavailable');
  });

  assert.equal(abandoned.has(104), true);
});
