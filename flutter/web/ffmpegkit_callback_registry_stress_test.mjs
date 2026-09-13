import assert from 'node:assert/strict';

import {createCallbackRegistry} from './ffmpegkit_callback_runtime.mjs';

const iterations = 10000;
const table = new WebAssembly.Table({element: 'anyfunc', initial: 1, maximum: 64});
const registry = createCallbackRegistry(table);
const initialTableSize = table.length;
let maximumTableSize = initialTableSize;
let maximumActiveSlots = 0;

for (let iteration = 0; iteration < iterations; iteration += 1) {
  const pointer = registry.addFunction(() => {}, 'v');
  maximumActiveSlots = Math.max(maximumActiveSlots, registry.ownedCount);
  maximumTableSize = Math.max(maximumTableSize, table.length);
  registry.removeFunction(pointer);
  assert.equal(registry.ownedCount, 0);
}

assert.equal(maximumTableSize, initialTableSize + 1);
assert.equal(maximumActiveSlots, 1);
assert.equal(registry.ownedCount, 0);
assert.equal(registry.freeSlotCount, 1);

console.log(JSON.stringify({
  iterations,
  initialTableSize,
  maximumTableSize,
  maximumActiveSlots,
  freeSlotCount: registry.freeSlotCount,
  status: 'PASS',
}));
