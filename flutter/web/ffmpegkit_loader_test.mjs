import assert from 'node:assert/strict';

import {
  createInstantiateWasm,
  fetchAndCompileWasm,
  raceWasmModuleAttempt,
} from './ffmpegkit_loader.mjs';

function response({ok, status, url, bytes}) {
  return {
    ok,
    status,
    url,
    async arrayBuffer() {
      return bytes;
    },
  };
}

await assert.rejects(
  fetchAndCompileWasm('missing.wasm', async () => response({
    ok: false,
    status: 404,
    url: 'missing.wasm',
    bytes: new ArrayBuffer(0),
  })),
  /Unable to load Wasm \(404\)/,
);

await assert.rejects(
  fetchAndCompileWasm('corrupt.wasm', async () => response({
    ok: true,
    status: 200,
    url: 'corrupt.wasm',
    bytes: new TextEncoder().encode('not wasm').buffer,
  })),
  WebAssembly.CompileError,
);

const wasmModule = await WebAssembly.compile(
  new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0]),
);
const successfulInstantiation = createInstantiateWasm(wasmModule);
let received = 0;
successfulInstantiation.instantiateWasm({}, (instance, module) => {
  received++;
  assert(instance instanceof WebAssembly.Instance);
  assert(module instanceof WebAssembly.Module);
});
successfulInstantiation.instantiateWasm({}, () => {
  received++;
});
await successfulInstantiation.completion;
assert.equal(received, 1);

const instantiateError = new Error('instantiate failed');
const factoryError = new Error('factory failed');
const originalInstantiate = WebAssembly.instantiate;
try {
  let rejectInstantiate;
  WebAssembly.instantiate = () => new Promise((_, reject) => {
    rejectInstantiate = reject;
  });
  const failedInstantiation = createInstantiateWasm(wasmModule);
  const failure = raceWasmModuleAttempt(
    () => {
      failedInstantiation.instantiateWasm({}, () => {});
      return new Promise(() => {});
    },
    failedInstantiation,
  );
  rejectInstantiate(instantiateError);
  await assert.rejects(failure, (error) => error === instantiateError);

  let lateRejectInstantiate;
  WebAssembly.instantiate = () => new Promise((_, reject) => {
    lateRejectInstantiate = reject;
  });
  const factoryRejected = createInstantiateWasm(wasmModule);
  const factoryFailure = raceWasmModuleAttempt(
    () => {
      factoryRejected.instantiateWasm({}, () => {});
      return Promise.reject(factoryError);
    },
    factoryRejected,
  );
  await assert.rejects(factoryFailure, (error) => error === factoryError);
  lateRejectInstantiate(new Error('late instantiate failure'));
  await new Promise((resolve) => setImmediate(resolve));
} finally {
  WebAssembly.instantiate = originalInstantiate;
}

console.log(JSON.stringify({missing: 'rejected', corrupt: 'rejected', status: 'PASS'}));
