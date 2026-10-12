"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");
const { before, test } = require("node:test");
const { pathToFileURL } = require("node:url");

let installHeapViews;

before(async () => {
  ({ installHeapViews } = await import(
    pathToFileURL(path.join(__dirname, "..", "web", "ffmpegkit_heap_runtime.mjs"))
      .href
  ));
});

function sharedMemory() {
  return new WebAssembly.Memory({ initial: 1, maximum: 4, shared: true });
}

test("preserves writable Emscripten heap properties that already match memory", () => {
  const memory = sharedMemory();
  const module = {
    HEAPU8: new Uint8Array(memory.buffer),
    HEAPU32: new Uint32Array(memory.buffer),
    HEAPF32: new Float32Array(memory.buffer),
  };

  installHeapViews(module, memory);
  memory.grow(1);
  module.HEAPU8 = new Uint8Array(memory.buffer);
  module.HEAPU32 = new Uint32Array(memory.buffer);
  module.HEAPF32 = new Float32Array(memory.buffer);

  assert.equal(module.HEAPU8.buffer, memory.buffer);
  assert.equal(module.HEAPU32.buffer, memory.buffer);
  assert.equal(module.HEAPF32.buffer, memory.buffer);
  assert.equal(module.HEAPU8.byteLength, 2 * 64 * 1024);
});

test("fallback heap accessors accept generated-runtime updates and follow growth", () => {
  const memory = sharedMemory();
  const module = {};

  installHeapViews(module, memory);
  assert.equal(module.HEAPU8.buffer, memory.buffer);
  memory.grow(1);
  assert.equal(module.HEAPU8.buffer, memory.buffer);
  assert.equal(module.HEAPU8.byteLength, 2 * 64 * 1024);

  module.HEAPU8 = new Uint8Array(memory.buffer);
  module.HEAPU32 = new Uint32Array(memory.buffer);
  module.HEAPF32 = new Float32Array(memory.buffer);
  assert.equal(module.HEAPU8.buffer, memory.buffer);
  assert.equal(module.HEAPU32.buffer, memory.buffer);
  assert.equal(module.HEAPF32.buffer, memory.buffer);
});

test("fallback setters reject wrong view types and stale memory buffers", () => {
  const memory = sharedMemory();
  const module = {};
  installHeapViews(module, memory);
  const oldView = module.HEAPU8;
  memory.grow(1);

  assert.throws(() => {
    module.HEAPU8 = new Uint32Array(memory.buffer);
  }, /HEAPU8 must be assigned a Uint8Array/);
  assert.throws(() => {
    module.HEAPU8 = oldView;
  }, /current WebAssembly memory buffer/);
});

test("fails loudly for an incompatible non-configurable heap property", () => {
  const memory = sharedMemory();
  const module = {};
  Object.defineProperty(module, "HEAPU8", {
    configurable: false,
    get: () => new Uint8Array(memory.buffer),
  });

  assert.throws(
    () => installHeapViews(module, memory),
    /HEAPU8.*non-configurable and incompatible/,
  );
});
