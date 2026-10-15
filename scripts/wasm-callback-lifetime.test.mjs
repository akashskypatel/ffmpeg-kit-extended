import assert from 'node:assert/strict';
import test from 'node:test';
import { assertCallbackLifetimeTrace } from './fixtures/wasm-callback-lifetime-contract.mjs';

const sessionId = '31';
const tokenA = 0x0a11ce;
const tokenB = 0x0b0b;
const completeToken = 0x0c0ffee;
const log = (owner, sequence, userData = owner === 'A' ? tokenA : tokenB) => ({
  type: 'log', owner, sequence, sessionId, userData, messageLength: 12,
});
const validTrace = () => ({messagesInTransmit: 0, nativeStateAtUnregister: 1, events: [
  {type: 'invoke'},
  log('A', 0),
  {type: 'busy-start'},
  {type: 'busy-end'},
  {type: 'unregister', slotA: 7, tokenA},
  log('A', 1),
  {type: 'register-b', slotB: 8, tokenB},
  log('B', 2),
  {type: 'end', sessionId, userData: completeToken},
]});
const options = {expectedSessionId: sessionId, tokenA, tokenB};

test('accepts an old queued callback after unregister and a new callback after replacement', () => {
  const trace = validTrace();
  assert.equal(assertCallbackLifetimeTrace(trace, options), trace);
});

test('accepts an empty log payload allowed by the native callback ABI', () => {
  const trace = validTrace();
  trace.events[5].messageLength = 0;
  assert.equal(assertCallbackLifetimeTrace(trace, options), trace);
});

test('rejects when no queued old callback arrives after unregister', () => {
  const trace = validTrace();
  trace.events.splice(5, 1);
  assert.throws(() => assertCallbackLifetimeTrace(trace, options), /No queued callback/);
});

test('rejects a callback with the wrong registration owner token', () => {
  const trace = validTrace();
  trace.events[5].userData = tokenB;
  assert.throws(() => assertCallbackLifetimeTrace(trace, options), /wrong user-data token/);

  const wrongOwner = validTrace();
  wrongOwner.events[5].owner = 'B';
  wrongOwner.events[5].userData = tokenB;
  assert.throws(() => assertCallbackLifetimeTrace(wrongOwner, options), /No queued callback/);
});

test('rejects replacement table-slot aliasing', () => {
  const trace = validTrace();
  trace.events[6].slotB = trace.events[4].slotA;
  assert.throws(() => assertCallbackLifetimeTrace(trace, options), /aliased/);
});

test('rejects duplicate completion and late callbacks', () => {
  const duplicate = validTrace();
  duplicate.events.push({type: 'end', sessionId, userData: completeToken});
  assert.throws(() => assertCallbackLifetimeTrace(duplicate, options), /one global completion/);

  const late = validTrace();
  late.events.push(log('B', 3));
  assert.throws(() => assertCallbackLifetimeTrace(late, options), /after native completion/);
});

test('rejects non-monotonic native log sequence values', () => {
  const trace = validTrace();
  trace.events[7].sequence = 0;
  assert.throws(() => assertCallbackLifetimeTrace(trace, options), /sequence did not increase/);
});

test('rejects inactive work and undrained messages', () => {
  const inactive = validTrace();
  inactive.nativeStateAtUnregister = 2;
  assert.throws(() => assertCallbackLifetimeTrace(inactive, options), /not running/);
  const pending = validTrace();
  pending.messagesInTransmit = 1;
  assert.throws(() => assertCallbackLifetimeTrace(pending, options), /remain in transmit/);
});
