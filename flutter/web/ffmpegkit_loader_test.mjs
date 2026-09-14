import assert from 'node:assert/strict';

import {fetchAndCompileWasm} from './ffmpegkit_loader.mjs';

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

console.log(JSON.stringify({missing: 'rejected', corrupt: 'rejected', status: 'PASS'}));
