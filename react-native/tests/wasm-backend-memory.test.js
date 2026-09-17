'use strict';

/* global BigUint64Array */

const assert = require('node:assert/strict');
const test = require('node:test');
const {WebFFmpegKitBackend} = require('../.test-dist/platform/backend.web.js');
const {getBackend} = require('../.test-dist/platform/backend.js');
const {webBackend} = require('../.test-dist/platform/backend.web.js');

require('../.test-dist/platform/backend.web.register.js');

test('Web backend registration selects the browser backend without native imports', () => {
  assert.strictEqual(getBackend(), webBackend);
});

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

test('Web backend creates media-information sessions from pre-tokenized arguments', () => {
  const memory = new ArrayBuffer(4096);
  const allocations = [];
  const freed = [];
  const observed = [];
  let pointer = 64;
  const module = {
    HEAPU8: new Uint8Array(memory),
    HEAPU32: new Uint32Array(memory),
    _malloc: size => {
      const result = Math.ceil(pointer / 8) * 8;
      pointer = result + size;
      allocations.push(result);
      return result;
    },
    _free: value => freed.push(value),
    lengthBytesUTF8: value => Buffer.byteLength(value, 'utf8'),
    stringToUTF8: (value, destination, size) => {
      const bytes = Buffer.from(value, 'utf8');
      module.HEAPU8.set(bytes.subarray(0, size - 1), destination);
      module.HEAPU8[destination + Math.min(bytes.length, size - 1)] = 0;
    },
    UTF8ToString: source => {
      const end = module.HEAPU8.indexOf(0, source);
      return Buffer.from(module.HEAPU8.subarray(source, end)).toString('utf8');
    },
    media_information_create_session_from_argv: (argc, argv) => {
      for (let index = 0; index < argc; index += 1) {
        observed.push(module.UTF8ToString(module.HEAPU32[argv / 4 + index]));
      }
      return 1024;
    },
    ffmpeg_kit_session_get_session_id: handle => {
      assert.equal(handle, 1024);
      return 77;
    },
    ffmpeg_kit_handle_release: handle => assert.equal(handle, 1024),
  };

  const backend = new WebFFmpegKitBackend(undefined, module);
  const path = '/tmp/my video "quoted" C:\\media\\clip.mkv';

  assert.equal(backend.createMediaInformationSessionFromPath(path), 77);
  assert.deepEqual(observed, [
    '-v',
    'error',
    '-hide_banner',
    '-print_format',
    'json',
    '-show_format',
    '-show_streams',
    '-show_chapters',
    '-i',
    path,
  ]);
  assert.deepEqual(
    [...freed].sort((left, right) => left - right),
    [...allocations].sort((left, right) => left - right),
  );

  backend.releaseSessionHandle(77);
});
