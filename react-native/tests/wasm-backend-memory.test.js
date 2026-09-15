'use strict';

/* global BigUint64Array */

const assert = require('node:assert/strict');
const test = require('node:test');
const {WebFFmpegKitBackend} = require('../.test-dist/platform/backend.web.js');

test('Web backend copies FFplay frame metadata through mocked Wasm memory', () => {
  const memory = new ArrayBuffer(4096);
  const module = {
    HEAPU8: new Uint8Array(memory),
    HEAPU32: new Uint32Array(memory),
    _malloc: (() => {
      let pointer = 64;
      return size => {
        const result = Math.ceil(pointer / 8) * 8;
        pointer = result + size;
        return result;
      };
    })(),
    _free: () => {},
    ffplay_kit_get_frame_buffer_size: () => 32,
    ffplay_kit_copy_frame: (destination, size, width, height, linesize, generation) => {
      assert.equal(size, 32);
      module.HEAPU32[width / 4] = 2;
      module.HEAPU32[height / 4] = 1;
      module.HEAPU32[linesize / 4] = 8;
      new BigUint64Array(memory, generation, 1)[0] = 4n;
      module.HEAPU8.set([1, 2, 3, 4, 5, 6, 7, 8], destination);
      return 1;
    },
  };

  const backend = new WebFFmpegKitBackend(undefined, module);
  assert.equal(backend.getFrameBufferSize(), 32);
  assert.deepEqual(backend.copyFrame(128, 32), {
    width: 2,
    height: 1,
    linesize: 8,
    generation: 4,
  });
});
