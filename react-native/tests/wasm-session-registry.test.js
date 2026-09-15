'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {WasmSessionRegistry} = require('../.test-dist/platform/web/session-registry.js');

test('WasmSessionRegistry retains and releases pointers by public session ID', () => {
  const registry = new WasmSessionRegistry();
  registry.retain(101, 7);
  registry.retain(202, 8);

  assert.equal(registry.size, 2);
  assert.equal(registry.get(7), 101);
  assert.equal(registry.has(8), true);
  assert.equal(registry.take(7), 101);
  assert.equal(registry.get(7), undefined);
  assert.equal(registry.size, 1);
  assert.deepEqual(registry.clear(), [202]);
  assert.equal(registry.size, 0);
});

test('WasmSessionRegistry rejects invalid ownership entries', () => {
  const registry = new WasmSessionRegistry();
  assert.throws(() => registry.retain(0, 1), /invalid session handle/);
  assert.throws(() => registry.retain(1, 0), /invalid session handle/);
});
