import assert from 'node:assert/strict';

import {
  createCallbackRegistry,
  discoverWasmTable,
} from './ffmpegkit_callback_runtime.mjs';

const table = new WebAssembly.Table({element: 'anyfunc', initial: 1});
assert.equal(discoverWasmTable({indirect: table}), table);
assert.throws(
  () => discoverWasmTable({first: table, second: new WebAssembly.Table({element: 'anyfunc', initial: 1})}),
  /exactly one/,
);

const registry = createCallbackRegistry(table);
const calls = [];

const completionPointer = registry.addFunction((session, userData) => {
  calls.push(['completion', session, userData]);
}, 'vpp');
assert.equal(completionPointer, 1);
table.get(completionPointer)(0x11, 0x22);
assert.deepEqual(calls.pop(), ['completion', 0x11, 0x22]);

const logPointer = registry.addFunction((session, level, message) => {
  calls.push(['log', session, level, message]);
}, 'vppp');
table.get(logPointer)(0x31, 0x32, 0x33);
assert.deepEqual(calls.pop(), ['log', 0x31, 0x32, 0x33]);

const statisticsPointer = registry.addFunction((...values) => {
  calls.push(['statistics', ...values]);
}, 'vpjjjddjddjjp');
const statisticsArgs = [
  0x41, 1n, 2n, 3n, 4.5, 5.5, 6n, 7.5, 8.5, 9n, 10n, 0x42,
];
table.get(statisticsPointer)(...statisticsArgs);
assert.deepEqual(calls.pop(), ['statistics', ...statisticsArgs]);
assert.equal(registry.ownedCount, 3);

registry.removeFunction(logPointer);
assert.equal(table.get(logPointer), null);
assert.equal(registry.ownedCount, 2);
assert.throws(() => registry.removeFunction(logPointer), /not owned/);
const reusedPointer = registry.addFunction(() => {}, 'v');
assert.equal(reusedPointer, logPointer);
registry.removeFunction(reusedPointer);

const recycledPointer = registry.addFunction(() => {}, 'v');
registry.removeFunction(recycledPointer);
for (let cycle = 0; cycle < 10000; cycle += 1) {
  let received;
  const pointer = registry.addFunction((value) => {
    received = value;
  }, 'vi');
  assert.equal(pointer, recycledPointer);
  table.get(pointer)(cycle);
  assert.equal(received, cycle);
  registry.removeFunction(pointer);
  assert.equal(table.get(pointer), null);
}

registry.removeFunction(completionPointer);
registry.removeFunction(statisticsPointer);
assert.equal(registry.ownedCount, 0);

console.log(JSON.stringify({
  signatures: ['vpp', 'vppp', 'vpjjjddjddjjp'],
  cycles: 10000,
  recycledPointer,
  finalTableLength: table.length,
  status: 'PASS',
}));
