'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const test = require('node:test');

const {
  initializeWasm,
  isWasmModuleReady,
  resetWasmLoaderForTests,
} = require('../.test-dist/platform/web/wasm-loader.js');

function assetBaseUrl(directory) {
  return pathToFileURL(`${directory}${path.sep}`).href;
}

function createBridge(directory, source) {
  fs.mkdirSync(directory, {recursive: true});
  fs.writeFileSync(path.join(directory, 'ffmpegkit_bridge.mjs'), source);
}

test('failed Wasm initialization retries with a corrected asset base URL', async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-wasm-init-'));
  const bad = path.join(root, 'bad');
  const good = path.join(root, 'good');
  try {
    createBridge(bad, "export function createFFmpegKitModule() { return Promise.reject(new Error('bad asset')); }\n");
    createBridge(good, `
      globalThis.__ffmpegKitFactoryCalls = (globalThis.__ffmpegKitFactoryCalls || 0) + 1;
      export async function createFFmpegKitModule() {
        return {};
      }
    `);
    delete global.__ffmpegKitFactoryCalls;
    global.crossOriginIsolated = true;
    resetWasmLoaderForTests();

    await assert.rejects(
      initializeWasm({assetBaseUrl: assetBaseUrl(bad)}),
      /bad asset/,
    );
    assert.equal(isWasmModuleReady(), false);

    await initializeWasm({assetBaseUrl: assetBaseUrl(good)});
    assert.equal(isWasmModuleReady(), true);
    assert.equal(global.__ffmpegKitFactoryCalls, 1);
  } finally {
    resetWasmLoaderForTests();
    delete global.__ffmpegKitFactoryCalls;
    delete global.crossOriginIsolated;
    fs.rmSync(root, {recursive: true, force: true});
  }
});

test('concurrent Wasm initialization shares one attempt and successful initialization is idempotent', async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-wasm-init-'));
  try {
    createBridge(root, `
      globalThis.__ffmpegKitFactoryCalls = (globalThis.__ffmpegKitFactoryCalls || 0) + 1;
      export async function createFFmpegKitModule() {
        await new Promise(resolve => setTimeout(resolve, 10));
        return {};
      }
    `);
    delete global.__ffmpegKitFactoryCalls;
    global.crossOriginIsolated = true;
    resetWasmLoaderForTests();
    const options = {assetBaseUrl: assetBaseUrl(root)};

    const first = initializeWasm(options);
    const second = initializeWasm(options);
    assert.strictEqual(first, second);
    await Promise.all([first, second]);
    await initializeWasm(options);

    assert.equal(global.__ffmpegKitFactoryCalls, 1);
    assert.equal(isWasmModuleReady(), true);
  } finally {
    resetWasmLoaderForTests();
    delete global.__ffmpegKitFactoryCalls;
    delete global.crossOriginIsolated;
    fs.rmSync(root, {recursive: true, force: true});
  }
});

test('public initialization clears a failed attempt and deduplicates the retry', async () => {
  const {setBackend} = require('../.test-dist/platform/backend.js');
  let attempts = 0;
  let shouldFail = true;
  const observedOptions = [];
  const failure = new Error('initialization failed');
  setBackend({
    initialize: options => {
      attempts += 1;
      observedOptions.push(options);
      return new Promise((resolve, reject) => {
        setTimeout(() => {
          if (shouldFail) reject(failure);
          else resolve();
        }, 10);
      });
    },
  });
  const {FFmpegKitExtended} = require('../.test-dist/ffmpeg-kit-extended.js');

  await assert.rejects(
    FFmpegKitExtended.initialize({assetBaseUrl: '/bad/'}),
    reason => reason === failure,
  );
  assert.equal(FFmpegKitExtended.initialized, false);

  shouldFail = false;
  const options = {assetBaseUrl: '/good/'};
  const first = FFmpegKitExtended.initialize(options);
  const second = FFmpegKitExtended.initialize(options);
  assert.strictEqual(first, second);
  await Promise.all([first, second]);
  await FFmpegKitExtended.initialize(options);

  assert.equal(attempts, 2);
  assert.equal(FFmpegKitExtended.initialized, true);
  assert.deepEqual(observedOptions, [
    {assetBaseUrl: '/bad/'},
    {assetBaseUrl: '/good/'},
  ]);
});
