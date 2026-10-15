import assert from 'node:assert/strict';
import test from 'node:test';
import { assertCallbackOrderTrace } from './fixtures/wasm-callback-order-contract.mjs';

const sessionId = '17';
const userData = 4096;
const frame = (generation) => ({
  type: 'frame',
  generation: String(generation),
  signature: {nonBlackSamples: 16},
});
const log = (sequence) => ({
  type: 'log',
  sessionId,
  userData,
  sequence,
  message: 'native log',
});
const end = () => ({type: 'end', sessionId, userData});
const options = {expectedSessionId: sessionId, expectedUserData: userData};

test('accepts native FFmpeg callback ordering with interleaved log and statistics', () => {
  const trace = {events: [
    {type: 'start', phase: 'invocation'},
    log(0),
    {type: 'statistics', sessionId, userData},
    log(1),
    end(),
  ]};
  assert.equal(assertCallbackOrderTrace(trace, {...options, requireStatistics: true}), trace);
});

test('accepts FFplay log and changing frame observations without statistics', () => {
  const trace = {events: [
    {type: 'start', phase: 'invocation'},
    log(0),
    frame(8),
    frame(8),
    frame(9),
    end(),
  ]};
  assert.equal(assertCallbackOrderTrace(trace, {...options, requireFrames: true}), trace);
});

test('rejects callbacks before the invocation boundary', () => {
  const trace = {events: [log(0), {type: 'start'}, end()]};
  assert.throws(() => assertCallbackOrderTrace(trace, options), /first event/);
});

test('rejects traces missing required native events', () => {
  const trace = {events: [{type: 'start'}, log(0), end()]};
  assert.throws(() => assertCallbackOrderTrace(trace, {
    ...options,
    requireStatistics: true,
  }), /no native statistics/);
  assert.throws(() => assertCallbackOrderTrace({events: [
    {type: 'start'}, log(0), end(),
  ]}, {...options, requireFrames: true}), /changing FFplay frames/);
});

test('rejects callbacks delivered after the terminal event', () => {
  const trace = {events: [{type: 'start'}, log(0), end(), log(1)]};
  assert.throws(() => assertCallbackOrderTrace(trace, options), /after completion/);
});

test('rejects duplicate completion events', () => {
  const trace = {events: [{type: 'start'}, log(0), end(), end()]};
  assert.throws(() => assertCallbackOrderTrace(trace, options), /exactly one terminal callback/);
});

test('rejects native callback ownership and sequence violations', () => {
  for (const invalid of [
    {...log(0), sessionId: '18'},
    {...log(0), userData: 0},
  ]) {
    assert.throws(() => assertCallbackOrderTrace({events: [
      {type: 'start'}, invalid, end(),
    ]}, options), /session ID|user data/);
  }
  assert.throws(() => assertCallbackOrderTrace({events: [
    {type: 'start'}, log(4), log(3), end(),
  ]}, options), /sequence did not increase/);
});

test('rejects frozen or black frame readbacks', () => {
  for (const frames of [
    [frame(8), frame(8)],
    [frame(8), {...frame(9), signature: {nonBlackSamples: 0}}],
  ]) {
    assert.throws(() => assertCallbackOrderTrace({events: [
      {type: 'start'}, log(0), ...frames, end(),
    ]}, {...options, requireFrames: true}), /new generation|black pixels/);
  }
});
