import assert from 'node:assert/strict';

import {createCallbackRegistry} from './ffmpegkit_callback_runtime.mjs';

const iterations = 10000;
const table = new WebAssembly.Table({element: 'anyfunc', initial: 1, maximum: 64});
const registry = createCallbackRegistry(table);
const initialTableSize = table.length;
let maximumTableSize = initialTableSize;
let maximumActiveSlots = 0;
let invokedCallbacks = 0;

for (let iteration = 0; iteration < iterations; iteration += 1) {
  const pending = [];
  const pointer = registry.addFunction(() => {
    invokedCallbacks += 1;
  }, 'v');
  maximumActiveSlots = Math.max(maximumActiveSlots, registry.ownedCount);
  maximumTableSize = Math.max(maximumTableSize, table.length);

  // Model a native event that was accepted before unregistering. Disable new
  // submissions, drain the accepted event, then remove the table slot.
  const callback = table.get(pointer);
  pending.push(() => callback());
  assert.equal(pending.length, 1);
  pending.shift()();
  registry.removeFunction(pointer);
  assert.equal(registry.ownedCount, 0);
}

assert.equal(maximumTableSize, initialTableSize + 1);
assert.equal(maximumActiveSlots, 1);
assert.equal(registry.ownedCount, 0);
assert.equal(registry.freeSlotCount, 1);
assert.equal(invokedCallbacks, iterations);

console.log(JSON.stringify({
  iterations,
  initialTableSize,
  maximumTableSize,
  maximumActiveSlots,
  freeSlotCount: registry.freeSlotCount,
  invokedCallbacks,
  status: 'PASS',
}));
