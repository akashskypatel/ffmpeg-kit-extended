'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const test = require('node:test');

const {setBackend} = require('../.test-dist/platform/backend-registry.js');
const {
  initializeWasm,
  requireWasmModule,
  resetWasmLoaderForTests,
} = require('../.test-dist/platform/web/wasm-loader.js');
const {readLatestFrame} = require('../.test-dist/platform/web/ffplay-frame-reader.js');
const {
  beginFFplayPlayback,
  resetFFplayPlaybackEpochForTests,
} = require('../.test-dist/platform/web/ffplay-frame-state.js');

function assetBaseUrl(directory) {
  return pathToFileURL(`${directory}${path.sep}`).href;
}

test('frame reader skips unchanged generations and preserves stride across changes', async () => {
  resetFFplayPlaybackEpochForTests();
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-frame-reader-'));
  let frame = {
    width: 2,
    height: 2,
    linesize: 12,
    generation: 1,
    bytes: Uint8Array.from([
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
      13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
    ]),
  };
  let preflightCalls = 0;
  let fullCopyCalls = 0;
  let allocations = 0;
  let releases = 0;
  let playbackSessionId;
  let playbackReady = 0;
  try {
    fs.writeFileSync(
      path.join(root, 'ffmpegkit_bridge.mjs'),
      `export function createFFmpegKitModule() {
        return {
          HEAPU8: new Uint8Array(4096),
          _malloc: () => { globalThis.__frameReaderAllocations += 1; return 64; },
          _free: () => { globalThis.__frameReaderReleases += 1; },
        };
      }
      `,
    );
    global.__frameReaderAllocations = 0;
    global.__frameReaderReleases = 0;
    global.crossOriginIsolated = true;
    resetWasmLoaderForTests();
    await initializeWasm({assetBaseUrl: assetBaseUrl(root)});
    const loadedModule = requireWasmModule();
    setBackend({
      copyFrame: (destination, destinationSize) => {
        if (destination === 0 && destinationSize === 0) {
          preflightCalls += 1;
          return {...frame, copied: false};
        }
        fullCopyCalls += 1;
        assert.ok(destinationSize >= frame.linesize * frame.height);
        loadedModule.HEAPU8.set(frame.bytes, destination);
        return {...frame, copied: true};
      },
      ffplayGetVolume: sessionId => {
        assert.equal(sessionId, playbackSessionId);
        return playbackReady;
      },
    });

    const first = readLatestFrame();
    assert.ok(first.bytes instanceof Uint8ClampedArray);
    assert.deepEqual(first, {
      epoch: 0,
      width: 2,
      height: 2,
      linesize: 12,
      generation: 1,
      bytes: new Uint8ClampedArray(frame.bytes),
    });
    loadedModule.HEAPU8.fill(255, 64, 88);
    assert.deepEqual(first.bytes, new Uint8ClampedArray(frame.bytes));
    assert.equal(readLatestFrame(first), undefined);
    assert.equal(preflightCalls, 2);
    assert.equal(fullCopyCalls, 1);
    playbackSessionId = 2;
    playbackReady = -1;
    beginFFplayPlayback(playbackSessionId);
    assert.equal(readLatestFrame(first), undefined);
    assert.equal(preflightCalls, 2);
    assert.equal(fullCopyCalls, 1);

    frame = {
      width: 2,
      height: 2,
      linesize: 12,
      generation: 1,
      bytes: Uint8Array.from([
        41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52,
        53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64,
      ]),
    };
    playbackReady = 0;
    const restarted = readLatestFrame(first);
    assert.ok(restarted.bytes instanceof Uint8ClampedArray);
    assert.deepEqual(restarted, {
      epoch: 1,
      width: 2,
      height: 2,
      linesize: 12,
      generation: 1,
      bytes: new Uint8ClampedArray(frame.bytes),
    });
    assert.equal(preflightCalls, 3);
    assert.equal(fullCopyCalls, 2);

    frame = {
      width: 1,
      height: 2,
      linesize: 8,
      generation: 2,
      bytes: Uint8Array.from([
        25, 26, 27, 28, 29, 30, 31, 32,
        33, 34, 35, 36, 37, 38, 39, 40,
      ]),
    };
    const changed = readLatestFrame(restarted);
    assert.ok(changed.bytes instanceof Uint8ClampedArray);
    assert.deepEqual(changed, {
      epoch: 1,
      width: 1,
      height: 2,
      linesize: 8,
      generation: 2,
      bytes: new Uint8ClampedArray(frame.bytes),
    });
    assert.equal(preflightCalls, 4);
    assert.equal(fullCopyCalls, 3);
    allocations = global.__frameReaderAllocations;
    releases = global.__frameReaderReleases;
    assert.equal(allocations, 3);
    assert.equal(releases, allocations);
  } finally {
    resetWasmLoaderForTests();
    delete global.__frameReaderAllocations;
    delete global.__frameReaderReleases;
    delete global.crossOriginIsolated;
    playbackSessionId = undefined;
    resetFFplayPlaybackEpochForTests();
    fs.rmSync(root, {recursive: true, force: true});
  }
});
