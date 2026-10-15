'use strict';

// W-R01: the React Native Web backend has no synchronous execute path. Every
// execute call it makes into Wasm is the async variant, and no sync
// FFplay/FFmpeg/FFprobe execute method exists on the backend.

const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const source = readFileSync(
  path.join(__dirname, '..', 'src', 'platform', 'backend.web.ts'),
  'utf8'
);

test('Web backend calls only async Wasm execute exports', () => {
  const calls = [...source.matchAll(/this\.call\('([a-z0-9_]+)'\)/g)].map(
    (match) => match[1]
  );
  const executeCalls = calls.filter((name) => name.includes('_execute'));
  assert.ok(executeCalls.length > 0, 'expected async execute calls');
  for (const name of executeCalls) {
    assert.match(name, /_execute_async$/, `sync execute export: ${name}`);
  }
});

test('Web backend has no sync FFplay execute export', () => {
  assert.doesNotMatch(source, /'ffplay_kit_execute'/);
  assert.doesNotMatch(source, /'ffplay_kit_session_execute'/);
});

test('Web backend defines no synchronous executeSession method', () => {
  assert.doesNotMatch(source, /^\s+executeSession\(/m);
  assert.match(source, /^\s+executeSessionAsync\(/m);
});
