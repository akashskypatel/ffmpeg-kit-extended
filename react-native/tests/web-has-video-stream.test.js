'use strict';

// W-R02: Web FFplayKit.hasVideoStream maps only the C value 1 to true, and
// rejects network-scheme inputs before any C call.

const assert = require('node:assert/strict');
const test = require('node:test');
const { WebFFmpegKitBackend } = require('../.test-dist/platform/backend.web.js');

// Fake Wasm module. `results` maps a path to the value the C probe returns.
function createProbeModule(results, calls) {
  const heap = new Uint8Array(4096);
  const encoder = new TextEncoder();
  let next = 16;
  return {
    lengthBytesUTF8: (value) => encoder.encode(value).length,
    stringToUTF8(value, pointer, size) {
      const bytes = encoder.encode(value).subarray(0, size - 1);
      heap.set(bytes, pointer);
      heap[pointer + bytes.length] = 0;
    },
    _malloc(size) {
      const pointer = next;
      next += size;
      return pointer;
    },
    _free() {},
    ffplay_kit_has_video_stream(pointer) {
      let end = pointer;
      while (heap[end] !== 0) end += 1;
      const path = new TextDecoder().decode(heap.subarray(pointer, end));
      calls.push(path);
      return results.has(path) ? results.get(path) : -1;
    },
  };
}

function createBackend(results) {
  const calls = [];
  const backend = new WebFFmpegKitBackend(
    undefined,
    createProbeModule(results, calls)
  );
  return { backend, calls };
}

test('hasVideoStream reports true only for the C result 1', () => {
  const { backend, calls } = createBackend(new Map([['/media/clip.mp4', 1]]));
  assert.equal(backend.ffplayHasVideoStream('/media/clip.mp4'), true);
  assert.deepEqual(calls, ['/media/clip.mp4']);
});

test('hasVideoStream is false for audio-only input and for C result -1', () => {
  const { backend } = createBackend(
    new Map([
      ['/media/audio-only.m4a', 0],
      ['/media/broken.mp4', -1],
    ])
  );
  assert.equal(backend.ffplayHasVideoStream('/media/audio-only.m4a'), false);
  // A missing or unreadable local path returns -1 from the probe; it must not
  // be mapped to true.
  assert.equal(backend.ffplayHasVideoStream('/media/missing.mp4'), false);
  assert.equal(backend.ffplayHasVideoStream('/media/broken.mp4'), false);
});

test('hasVideoStream rejects direct HTTP and HLS URLs before any C call', () => {
  const { backend, calls } = createBackend(new Map());
  for (const url of [
    'https://example.test/live/playlist.m3u8',
    'HTTP://example.test/clip.mp4',
    'hls+https://example.test/live/playlist.m3u8',
    'crypto+https://example.test/clip.mp4',
  ]) {
    assert.throws(
      () => backend.ffplayHasVideoStream(url),
      (error) =>
        error instanceof Error &&
        /FFprobeKit\.getMediaInformation\(\)/.test(error.message)
    );
  }
  assert.deepEqual(calls, []);
});
