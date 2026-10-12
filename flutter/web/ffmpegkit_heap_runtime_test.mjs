import assert from 'node:assert/strict';
import test from 'node:test';
import { installHeapViews } from './ffmpegkit_heap_runtime.mjs';

test('heap views refresh after shared Wasm memory grows', () => {
  const memory = new WebAssembly.Memory({initial: 1, maximum: 3, shared: true});
  const module = {};
  installHeapViews(module, memory);
  const oldView = module.HEAPU8;

  memory.grow(1);

  assert.notEqual(module.HEAPU8, oldView);
  assert.equal(module.HEAPU8.buffer, memory.buffer);
  assert.equal(module.HEAPU32.buffer, memory.buffer);
  assert.equal(module.HEAPF32.buffer, memory.buffer);
  module.HEAPU8[65_536] = 0xa5;
  assert.equal(new Uint8Array(memory.buffer)[65_536], 0xa5);
});

test('preserves compatible writable Emscripten-owned data properties', () => {
  const memory = new WebAssembly.Memory({initial: 1, maximum: 2, shared: true});
  const module = {
    HEAPU8: new Uint8Array(memory.buffer),
    HEAPU32: new Uint32Array(memory.buffer),
    HEAPF32: new Float32Array(memory.buffer),
  };
  const original = module.HEAPU8;

  installHeapViews(module, memory);

  assert.equal(module.HEAPU8, original);
  memory.grow(1);
  module.HEAPU8 = new Uint8Array(memory.buffer);
  assert.equal(module.HEAPU8.buffer, memory.buffer);
});

test('validates heap assignments and rejects incompatible locked properties', () => {
  const memory = new WebAssembly.Memory({initial: 1, maximum: 2, shared: true});
  const module = {};
  installHeapViews(module, memory);
  assert.throws(() => { module.HEAPU8 = new Uint16Array(memory.buffer); }, /Uint8Array/);
  assert.throws(() => { module.HEAPU8 = new Uint8Array(8); }, /current WebAssembly memory buffer/);

  const lockedModule = {};
  Object.defineProperty(lockedModule, 'HEAPU8', {
    configurable: false,
    value: new Uint8Array(8),
  });
  assert.throws(
    () => installHeapViews(lockedModule, memory),
    /non-configurable and incompatible/,
  );
});
