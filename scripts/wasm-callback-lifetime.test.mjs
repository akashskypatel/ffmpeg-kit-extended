import assert from 'node:assert/strict';
import test from 'node:test';
import { assertCallbackLifetimeTrace } from './fixtures/wasm-callback-lifetime-contract.mjs';

const sessionId = '31';
const tokenA = 0x0a11ce;
const tokenB = 0x0b0b;
const completeToken = 0x0c0ffee;
const log = (owner, sequence, callbackId, callbackEntryAt,
  userData = owner === 'A' ? tokenA : tokenB, payloadReadAt = callbackEntryAt + 1,
  payloadFreedAt = callbackEntryAt + 2) => ({
  type: 'log', at: payloadFreedAt, owner, sequence, callbackId, callbackEntryAt, sessionId, userData,
  messageLength: 12, payloadReadAt, payloadFreedAt,
});
const validTrace = () => ({
  messagesInTransmit: 0,
  nativeStateBeforeSwap: 1,
  nativeStateAfterSwap: 1,
  events: [
    {type: 'invoke', at: 0},
    {type: 'callback-begin', owner: 'A', callbackId: 'a0', at: 10, entryAfterUnregister: false},
    log('A', 0, 'a0', 10),
    {type: 'callback-end', owner: 'A', callbackId: 'a0', at: 13},
    {type: 'transition-armed', at: 15},
    {type: 'callback-begin', owner: 'A', callbackId: 'a1', at: 20,
      transition: true, entryAfterUnregister: false},
    {type: 'state-before-swap', callbackId: 'a1', at: 21, state: 1},
    {type: 'payload-held', callbackId: 'a1', at: 22, hasPayload: true},
    {type: 'busy-start', callbackId: 'a1', at: 23},
    {type: 'busy-end', callbackId: 'a1', at: 623},
    {type: 'unregister', at: 624, slotA: 7, tokenA, callbackId: 'a1'},
    {type: 'register-b', at: 625, slotB: 8, tokenB, callbackId: 'a1'},
    {type: 'payload-read', at: 626, callbackId: 'a1'},
    {type: 'payload-free', at: 627, callbackId: 'a1'},
    log('A', 1, 'a1', 20, tokenA, 626, 627),
    {type: 'callback-end', owner: 'A', callbackId: 'a1', at: 629},
    {type: 'state-after-swap', at: 630, state: 1, mayDrainQueuedCallbacks: true},
    {type: 'callback-begin', owner: 'A', callbackId: 'a2', at: 640, entryAfterUnregister: true},
    log('A', 2, 'a2', 640),
    {type: 'callback-end', owner: 'A', callbackId: 'a2', at: 642},
    {type: 'callback-begin', owner: 'B', callbackId: 'b3', at: 650, entryAfterUnregister: true},
    log('B', 3, 'b3', 650),
    {type: 'callback-end', owner: 'B', callbackId: 'b3', at: 652},
    {type: 'end', at: 680, sessionId, userData: completeToken},
  ],
});
const options = {expectedSessionId: sessionId, tokenA, tokenB};
const findLog = (trace, callbackId) => trace.events.find((event) =>
  event.type === 'log' && event.callbackId === callbackId);

test('accepts an old queued callback after unregister and a new callback after replacement', () => {
  const trace = validTrace();
  assert.equal(assertCallbackLifetimeTrace(trace, options), trace);
});

test('accepts an empty log payload allowed by the native callback ABI', () => {
  const trace = validTrace();
  findLog(trace, 'a2').messageLength = 0;
  assert.equal(assertCallbackLifetimeTrace(trace, options), trace);
});

test('rejects when no queued old callback arrives after unregister', () => {
  const trace = validTrace();
  trace.events = trace.events.filter((event) => event.callbackId !== 'a2');
  assert.throws(() => assertCallbackLifetimeTrace(trace, options), /No queued callback/);
});

test('rejects a callback with the wrong registration owner token', () => {
  const trace = validTrace();
  findLog(trace, 'a2').userData = tokenB;
  assert.throws(() => assertCallbackLifetimeTrace(trace, options), /wrong user-data token/);

  const wrongOwner = validTrace();
  findLog(wrongOwner, 'a2').owner = 'B';
  findLog(wrongOwner, 'a2').userData = tokenB;
  assert.throws(() => assertCallbackLifetimeTrace(wrongOwner, options), /callback-entry record/);
});

test('rejects replacement table-slot aliasing', () => {
  const trace = validTrace();
  trace.events.find((event) => event.type === 'register-b').slotB =
    trace.events.find((event) => event.type === 'unregister').slotA;
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
  findLog(trace, 'b3').sequence = 0;
  assert.throws(() => assertCallbackLifetimeTrace(trace, options), /sequence did not increase/);
});

test('does not count an in-flight A callback as the queued old arrival', () => {
  const trace = validTrace();
  trace.events = trace.events.filter((event) => event.callbackId !== 'a2');
  assert.throws(() => assertCallbackLifetimeTrace(trace, options), /No queued callback/);
});

test('accepts equal callback timestamps while preserving event-order evidence', () => {
  const trace = validTrace();
  const busyEndIndex = trace.events.findIndex((event) => event.type === 'busy-end');
  trace.events.forEach((event, index) => { event.at = index > busyEndIndex ? 610 : 10; });
  for (const event of trace.events.filter((candidate) => candidate.type === 'log')) {
    const entry = trace.events.find((candidate) =>
      candidate.type === 'callback-begin' && candidate.callbackId === event.callbackId);
    event.callbackEntryAt = entry.at;
    event.payloadReadAt = 610;
    event.payloadFreedAt = 610;
  }
  trace.events.find((event) => event.type === 'busy-end').at = 610;
  trace.events.filter((event) => event.type === 'busy-start')
    .forEach((event) => { event.at = 10; });
  assert.equal(assertCallbackLifetimeTrace(trace, options), trace);
});

test('rejects a callback that began before unregister even if its log finishes afterward', () => {
  const trace = validTrace();
  const queuedBeginIndex = trace.events.findIndex((event) =>
    event.type === 'callback-begin' && event.callbackId === 'a2');
  const queuedBegin = trace.events.splice(queuedBeginIndex, 1)[0];
  const unregisterIndex = trace.events.findIndex((event) => event.type === 'unregister');
  queuedBegin.at = trace.events[unregisterIndex].at;
  queuedBegin.entryAfterUnregister = false;
  findLog(trace, 'a2').callbackEntryAt = queuedBegin.at;
  trace.events.splice(unregisterIndex, 0, queuedBegin);
  assert.throws(() => assertCallbackLifetimeTrace(trace, options), /No queued callback/);
});

test('requires transition callback payload copy and free after replacement registration', () => {
  const trace = validTrace();
  findLog(trace, 'a1').payloadReadAt = 624;
  assert.throws(() => assertCallbackLifetimeTrace(trace, options), /read and free its owned payload/);
});

test('requires Running state on both sides of the callback swap', () => {
  const before = validTrace();
  before.nativeStateBeforeSwap = 2;
  assert.throws(() => assertCallbackLifetimeTrace(before, options), /not Running at callback entry/);

  const after = validTrace();
  after.nativeStateAfterSwap = 2;
  after.events.find((event) => event.type === 'state-after-swap').state = 2;
  assert.throws(() => assertCallbackLifetimeTrace(after, options), /not Running after/);
});

test('rejects inactive work and undrained messages', () => {
  const inactive = validTrace();
  inactive.nativeStateBeforeSwap = 2;
  assert.throws(() => assertCallbackLifetimeTrace(inactive, options), /not Running/);
  const pending = validTrace();
  pending.messagesInTransmit = 1;
  assert.throws(() => assertCallbackLifetimeTrace(pending, options), /remain in transmit/);
});
