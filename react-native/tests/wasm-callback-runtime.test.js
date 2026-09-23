"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const { before, test } = require("node:test");

let createCallbackRegistry;
let makeCallbackWrapper;

before(async () => {
  ({ createCallbackRegistry, makeCallbackWrapper } = await import(
    pathToFileURL(
      path.join(__dirname, "..", "web", "ffmpegkit_callback_runtime.mjs")
    ).href
  ));
});

test("Wasm callback wrappers preserve structured i64 and pointer arguments", () => {
  const table = new WebAssembly.Table({ element: "anyfunc", initial: 2 });
  let received;
  const wrapper = makeCallbackWrapper((...args) => {
    received = args;
  }, "vjjipp");

  table.set(1, wrapper);
  table.get(1)(11n, 12n, 13, 14, 15);

  assert.deepEqual(received, [11n, 12n, 13, 14, 15]);
});

test("Wasm callback registry owns and safely recycles registered slots", () => {
  const table = new WebAssembly.Table({ element: "anyfunc", initial: 2 });
  const registry = createCallbackRegistry(table);
  const index = registry.addFunction(() => {}, "vjp");

  assert.equal(index, 1);
  assert.equal(registry.ownedCount, 1);
  registry.removeFunction(index);
  assert.equal(table.get(index), null);
  assert.equal(registry.ownedCount, 0);
  assert.equal(registry.freeSlotCount, 1);
});
