'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  SessionHistoryRegistry,
} = require('../.test-dist/platform/web/session-history-registry.js');

test('session history registry preserves semantic creation order and type filters', () => {
  const registry = new SessionHistoryRegistry();
  registry.record(11, 'ffmpeg');
  registry.record(12, 'ffprobe');
  registry.record(13, 'ffmpeg');

  assert.deepEqual(registry.entries().map(entry => entry.sessionId), [11, 12, 13]);
  assert.deepEqual(
    registry.entries('ffmpeg').map(entry => entry.sessionId),
    [11, 13],
  );
});

test('duplicate identity does not create a second retained record', () => {
  const registry = new SessionHistoryRegistry();
  registry.record(21, 'ffplay');
  registry.record(21, 'ffplay');

  assert.equal(registry.size, 1);
  assert.deepEqual(registry.entries().map(entry => entry.sessionId), [21]);
});

test('hidden and removed identities are excluded without owning pointers', () => {
  const registry = new SessionHistoryRegistry();
  registry.record(31, 'media-information');
  registry.entries()[0].visible = false;
  registry.record(32, 'ffmpeg');

  assert.deepEqual(registry.entries().map(entry => entry.sessionId), [32]);
  registry.remove(32);
  assert.equal(registry.size, 1);
  registry.clear();
  assert.equal(registry.size, 0);
});

test('completion pruning removes oldest terminal identities without a history read', () => {
  const registry = new SessionHistoryRegistry();
  registry.record(41, 'ffmpeg');
  registry.record(42, 'ffprobe');
  registry.record(43, 'ffplay');
  registry.markTerminal(41);
  registry.markTerminal(42);
  registry.setCapacity(1);

  assert.deepEqual(registry.entries().map(entry => entry.sessionId), [42, 43]);
  assert.equal(registry.entries()[0].terminal, true);
  assert.equal(registry.entries()[1].terminal, false);
});

test('discarding a created identity does not remove a completed identity', () => {
  const registry = new SessionHistoryRegistry();
  registry.record(51, 'ffmpeg');
  registry.removeNonTerminal(51);
  registry.record(52, 'ffmpeg');
  registry.markTerminal(52);
  registry.removeNonTerminal(52);

  assert.deepEqual(registry.entries().map(entry => entry.sessionId), [52]);
});
