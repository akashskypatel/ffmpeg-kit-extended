'use strict';

/* global BigUint64Array */

const assert = require('node:assert/strict');
const test = require('node:test');
const {WebFFmpegKitBackend} = require('../.test-dist/platform/backend.web.js');
const {getBackend} = require('../.test-dist/platform/backend.js');
const {webBackend} = require('../.test-dist/platform/backend.web.js');

require('../.test-dist/platform/backend.web.register.js');

function createSnapshotModule({pointers, snapshotErrors = new Map(), releaseErrors = new Map()}) {
  const memory = new ArrayBuffer(4096);
  const heap = new Uint32Array(memory);
  const arrayPointer = 64;
  pointers.forEach((pointer, index) => {
    heap[arrayPointer / 4 + index] = pointer;
  });
  heap[arrayPointer / 4 + pointers.length] = 0;
  const releaseCalls = [];
  const freeCalls = [];
  const module = {
    HEAPU32: heap,
    ffmpeg_kit_get_sessions: () => arrayPointer,
    ffmpeg_kit_session_get_session_id: pointer => {
      const error = snapshotErrors.get(pointer);
      if (error) throw error;
      return pointer / 256;
    },
    session_is_ffmpeg_session: () => true,
    session_is_ffprobe_session: () => false,
    session_is_ffplay_session: () => false,
    ffmpeg_kit_session_get_state: () => 2,
    ffmpeg_kit_session_get_return_code: () => 0,
    ffmpeg_kit_session_get_create_time: () => 0,
    ffmpeg_kit_session_get_start_time: () => 0,
    ffmpeg_kit_session_get_end_time: () => 0,
    ffmpeg_kit_session_get_duration: () => 0,
    ffmpeg_kit_session_get_command: () => 0,
    ffmpeg_kit_session_get_output: () => 0,
    ffmpeg_kit_session_get_logs_as_string: () => 0,
    ffmpeg_kit_session_get_fail_stack_trace: () => 0,
    ffmpeg_kit_session_get_logs_count: () => 0,
    ffmpeg_kit_session_get_statistics_count: () => 0,
    session_is_debug_log_enabled: () => false,
    ffmpeg_kit_handle_release: pointer => {
      releaseCalls.push(pointer);
      const error = releaseErrors.get(pointer);
      if (error) throw error;
    },
    ffmpeg_kit_free: pointer => freeCalls.push(pointer),
  };
  return {module, releaseCalls, freeCalls};
}

test('Web backend registration selects the browser backend without native imports', () => {
  assert.strictEqual(getBackend(), webBackend);
});

test('Web backend reads session state without full snapshot getters', () => {
  const calls = [];
  const module = {
    ffmpeg_kit_get_session: sessionId => {
      calls.push(['get_session', sessionId]);
      return 1024;
    },
    ffmpeg_kit_session_get_state: handle => {
      calls.push(['get_state', handle]);
      return 1;
    },
    ffmpeg_kit_handle_release: handle => calls.push(['release', handle]),
    ffmpeg_kit_session_get_session_id: () => {
      throw new Error('full snapshot getter must not be called');
    },
  };

  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.equal(backend.getSessionState(77), 1);
  assert.deepEqual(calls, [
    ['get_session', 77n],
    ['get_state', 1024],
    ['release', 1024],
  ]);
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
      module.HEAPU32[width / 4] = 2;
      module.HEAPU32[height / 4] = 1;
      module.HEAPU32[linesize / 4] = 8;
      new BigUint64Array(memory, generation, 1)[0] = 4n;
      if (destination === 0) return -1;
      assert.equal(size, 32);
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
    copied: true,
  });
  assert.deepEqual(backend.copyFrame(0, 0), {
    width: 2,
    height: 1,
    linesize: 8,
    generation: 4,
    copied: false,
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

test('Web backend preserves created-handle cleanup when native release fails', () => {
  const releaseCalls = [];
  const releaseError = new Error('release failed');
  let shouldFail = true;
  const module = {
    _malloc: () => 64,
    _free: () => {},
    lengthBytesUTF8: () => 0,
    stringToUTF8: () => {},
    ffmpeg_kit_create_session: () => 1024,
    ffmpeg_kit_session_get_session_id: handle => {
      assert.equal(handle, 1024);
      return 77;
    },
    ffmpeg_kit_handle_release: handle => {
      releaseCalls.push(handle);
      if (shouldFail) throw releaseError;
    },
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.throws(() => backend.createFFmpegSession('-version'), error => error === releaseError);
  assert.deepEqual(releaseCalls, [1024]);

  shouldFail = false;
  backend.releaseSessionHandle(77);
  backend.releaseSessionHandle(77);
  assert.deepEqual(releaseCalls, [1024, 1024]);
});

test('Web backend clears tracked sessions transactionally', () => {
  const releaseCalls = [];
  const pointers = new Map([
    [1, 1024],
    [2, 2048],
    [3, 3072],
  ]);
  let shouldFail = true;
  let clearCalls = 0;
  const module = {
    _malloc: () => 64,
    _free: () => {},
    lengthBytesUTF8: () => 0,
    stringToUTF8: () => {},
    ffmpeg_kit_get_session: sessionId => pointers.get(Number(sessionId)),
    session_is_ffmpeg_session: () => true,
    ffmpeg_kit_session_execute_async: () => {},
    ffmpeg_kit_handle_release: handle => {
      releaseCalls.push(handle);
      if (shouldFail && handle === 2048) throw new Error('second release failed');
    },
    ffmpeg_kit_clear_sessions: () => {
      clearCalls += 1;
    },
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  backend.executeSessionAsync(1, 0);
  backend.executeSessionAsync(2, 0);
  backend.executeSessionAsync(3, 0);

  assert.throws(() => backend.clearSessions(), /second release failed/);
  assert.deepEqual(releaseCalls, [1024, 2048]);
  assert.equal(clearCalls, 0);

  shouldFail = false;
  backend.clearSessions();
  assert.deepEqual(releaseCalls, [1024, 2048, 2048, 3072]);
  assert.equal(clearCalls, 1);
});

test('Web backend frees every argument allocation when encoding fails', () => {
  const allocations = [];
  const freed = [];
  const encodingError = new Error('argument encoding failed');
  const memory = new ArrayBuffer(4096);
  let nextPointer = 64;
  const module = {
    HEAPU8: new Uint8Array(memory),
    HEAPU32: new Uint32Array(memory),
    _malloc: size => {
      const result = nextPointer;
      nextPointer += Math.max(8, size);
      allocations.push(result);
      return result;
    },
    _free: pointer => freed.push(pointer),
    lengthBytesUTF8: value => Buffer.byteLength(value, 'utf8'),
    stringToUTF8: value => {
      if (value === 'bad') throw encodingError;
    },
    ffmpeg_kit_create_session_from_argv: () => {
      throw new Error('session creation must not run');
    },
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.throws(
    () => backend.createFFmpegSessionFromArguments(['good', 'bad']),
    error => error === encodingError,
  );
  assert.deepEqual(
    [...freed].sort((left, right) => left - right),
    [...allocations].sort((left, right) => left - right),
  );
});

test('Web backend rolls back a handle when session ID extraction fails', () => {
  const releaseCalls = [];
  const sessionIdError = new Error('session ID extraction failed');
  const module = {
    _malloc: () => 64,
    _free: () => {},
    lengthBytesUTF8: () => 0,
    stringToUTF8: () => {},
    ffmpeg_kit_create_session: () => 1024,
    ffmpeg_kit_session_get_session_id: () => {
      throw sessionIdError;
    },
    ffmpeg_kit_handle_release: pointer => releaseCalls.push(pointer),
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.throws(
    () => backend.createFFmpegSession('-version'),
    error => error === sessionIdError,
  );
  assert.deepEqual(releaseCalls, [1024]);
});

test('Web backend rolls back a handle when registry validation fails', () => {
  const releaseCalls = [];
  const module = {
    _malloc: () => 64,
    _free: () => {},
    lengthBytesUTF8: () => 0,
    stringToUTF8: () => {},
    ffmpeg_kit_create_session: () => 1024,
    ffmpeg_kit_session_get_session_id: () => 0,
    ffmpeg_kit_handle_release: pointer => releaseCalls.push(pointer),
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.throws(
    () => backend.createFFmpegSession('-version'),
    /invalid session handle/,
  );
  assert.deepEqual(releaseCalls, [1024]);
});

test('Web backend releases a created handle before execution', () => {
  const releaseCalls = [];
  const module = {
    _malloc: () => 64,
    _free: () => {},
    lengthBytesUTF8: () => 0,
    stringToUTF8: () => {},
    ffmpeg_kit_create_session: () => 1024,
    ffmpeg_kit_session_get_session_id: () => 77,
    ffmpeg_kit_get_session: sessionId => {
      assert.equal(sessionId, 77n);
      return 2048;
    },
    ffmpeg_kit_session_get_state: handle => {
      assert.equal(handle, 2048);
      return 1;
    },
    ffmpeg_kit_handle_release: pointer => releaseCalls.push(pointer),
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.equal(backend.createFFmpegSession('-version'), 77);
  assert.deepEqual(releaseCalls, [1024]);
  assert.equal(backend.getSessionState(77), 1);
  assert.deepEqual(releaseCalls, [1024, 2048]);
  backend.releaseSessionHandle(77);
  assert.deepEqual(releaseCalls, [1024, 2048]);
});

test('Web backend releases a temporary session handle when snapshot construction fails', () => {
  const memory = new ArrayBuffer(4096);
  const releaseCalls = [];
  const freeCalls = [];
  const snapshotError = new Error('snapshot getter failed');
  const module = {
    HEAPU32: new Uint32Array(memory),
    ffmpeg_kit_get_sessions: () => 64,
    ffmpeg_kit_session_get_session_id: () => {
      throw snapshotError;
    },
    ffmpeg_kit_handle_release: pointer => releaseCalls.push(pointer),
    ffmpeg_kit_free: pointer => freeCalls.push(pointer),
  };
  module.HEAPU32[16] = 1024;
  module.HEAPU32[17] = 0;
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.throws(() => backend.getSessionsJson('all'), error => error === snapshotError);
  assert.deepEqual(releaseCalls, [1024]);
  assert.deepEqual(freeCalls, [64]);
});

test('Web backend releases every session-array handle after a snapshot failure', () => {
  const snapshotError = new Error('middle snapshot failed');
  const {module, releaseCalls, freeCalls} = createSnapshotModule({
    pointers: [1024, 2048, 3072],
    snapshotErrors: new Map([[2048, snapshotError]]),
  });
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.throws(() => backend.getSessionsJson('all'), error => error === snapshotError);
  assert.deepEqual(releaseCalls, [1024, 2048, 3072]);
  assert.deepEqual(freeCalls, [64]);
});

test('Web backend preserves a snapshot error over a later collection release error', () => {
  const snapshotError = new Error('snapshot failed first');
  const releaseError = new Error('release failed later');
  const {module, releaseCalls, freeCalls} = createSnapshotModule({
    pointers: [1024, 2048, 3072],
    snapshotErrors: new Map([[2048, snapshotError]]),
    releaseErrors: new Map([[3072, releaseError]]),
  });
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.throws(() => backend.getSessionsJson('all'), error => error === snapshotError);
  assert.deepEqual(releaseCalls, [1024, 2048, 3072]);
  assert.deepEqual(freeCalls, [64]);
});

test('Web backend reports a collection release error after successful snapshots', () => {
  const releaseError = new Error('collection release failed');
  const {module, releaseCalls, freeCalls} = createSnapshotModule({
    pointers: [1024, 2048, 3072],
    releaseErrors: new Map([[2048, releaseError]]),
  });
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.throws(() => backend.getSessionsJson('all'), error => error === releaseError);
  assert.deepEqual(releaseCalls, [1024, 2048, 3072]);
  assert.deepEqual(freeCalls, [64]);
});

test('Web backend preserves an action error over temporary session release failure', () => {
  const actionError = new Error('session action failed first');
  const releaseError = new Error('temporary release failed later');
  const releaseCalls = [];
  const module = {
    ffmpeg_kit_get_session: () => 1024,
    ffmpeg_kit_session_get_state: () => {
      throw actionError;
    },
    ffmpeg_kit_handle_release: pointer => {
      releaseCalls.push(pointer);
      throw releaseError;
    },
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.throws(() => backend.getSessionState(77), error => error === actionError);
  assert.deepEqual(releaseCalls, [1024]);
});

test('Web backend preserves a last-session snapshot error over release failure', () => {
  const snapshotError = new Error('last snapshot failed first');
  const releaseError = new Error('last session release failed later');
  const releaseCalls = [];
  const module = {
    ffmpeg_kit_get_last_session: () => 1024,
    ffmpeg_kit_session_get_session_id: () => {
      throw snapshotError;
    },
    ffmpeg_kit_handle_release: pointer => {
      releaseCalls.push(pointer);
      throw releaseError;
    },
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.throws(() => backend.getLastSessionJson('all'), error => error === snapshotError);
  assert.deepEqual(releaseCalls, [1024]);
});

test('Web backend preserves statistics errors over child-handle release errors', () => {
  const statisticsError = new Error('statistics getter failed');
  const releaseError = new Error('statistics release failed');
  const releaseCalls = [];
  const module = {
    ffmpeg_kit_get_session: () => 1024,
    ffmpeg_kit_session_get_statistics_count: () => 1,
    ffmpeg_kit_session_get_statistics_at: () => 2048,
    ffmpeg_kit_statistics_get_time_elapsed: () => { throw statisticsError; },
    ffmpeg_kit_handle_release: pointer => {
      releaseCalls.push(pointer);
      if (pointer === 2048) throw releaseError;
    },
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.throws(
    () => backend.getStatisticsJson(77, 0),
    error => error === statisticsError,
  );
  assert.deepEqual(releaseCalls, [2048, 1024]);
});

test('Web backend reports a statistics release error after successful serialization', () => {
  const releaseError = new Error('statistics release failed');
  const releaseCalls = [];
  const module = {
    ffmpeg_kit_get_session: () => 1024,
    ffmpeg_kit_session_get_statistics_count: () => 1,
    ffmpeg_kit_session_get_statistics_at: () => 2048,
    ffmpeg_kit_statistics_get_time_elapsed: () => 1,
    ffmpeg_kit_statistics_get_time: () => 2,
    ffmpeg_kit_statistics_get_size: () => 3,
    ffmpeg_kit_statistics_get_bitrate: () => 4,
    ffmpeg_kit_statistics_get_speed: () => 5,
    ffmpeg_kit_statistics_get_video_frame_number: () => 6,
    ffmpeg_kit_statistics_get_video_fps: () => 7,
    ffmpeg_kit_statistics_get_video_quality: () => 8,
    ffmpeg_kit_statistics_get_dup_frames: () => 9,
    ffmpeg_kit_statistics_get_drop_frames: () => 10,
    ffmpeg_kit_handle_release: pointer => {
      releaseCalls.push(pointer);
      if (pointer === 2048) throw releaseError;
    },
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.throws(
    () => backend.getStatisticsJson(77, 0),
    error => error === releaseError,
  );
  assert.deepEqual(releaseCalls, [2048, 1024]);
});

test('Web backend preserves media stream errors over child and info release errors', () => {
  const streamError = new Error('stream serialization failed');
  const streamReleaseError = new Error('stream release failed');
  const infoReleaseError = new Error('media info release failed');
  const releaseCalls = [];
  const module = {
    ffmpeg_kit_get_session: () => 1024,
    media_information_session_get_media_information: () => 2048,
    media_information_get_streams_count: () => 1,
    media_information_get_stream_at: () => 3072,
    stream_information_get_index: () => { throw streamError; },
    media_information_get_chapters_count: () => 0,
    ffmpeg_kit_handle_release: pointer => {
      releaseCalls.push(pointer);
      if (pointer === 3072) throw streamReleaseError;
      if (pointer === 2048) throw infoReleaseError;
    },
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.throws(
    () => backend.getMediaInformationData(77),
    error => error === streamError,
  );
  assert.deepEqual(releaseCalls, [3072, 2048, 1024]);
});

test('Web backend reacquires and retains ownership for async execution', () => {
  const calls = [];
  const module = {
    ffmpeg_kit_get_session: sessionId => {
      calls.push(['get_session', sessionId]);
      return 1024;
    },
    session_is_ffmpeg_session: () => true,
    ffmpeg_kit_session_execute_async: pointer => calls.push(['execute', pointer]),
    ffmpeg_kit_handle_release: pointer => calls.push(['release', pointer]),
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  backend.executeSessionAsync(77, 0);
  assert.deepEqual(calls, [
    ['get_session', 77n],
    ['execute', 1024],
  ]);
});

test('Web backend keeps the promoted execution handle through polling', () => {
  const calls = [];
  const module = {
    ffmpeg_kit_get_session: sessionId => {
      calls.push(['get_session', sessionId]);
      return 1024;
    },
    session_is_ffmpeg_session: () => true,
    ffmpeg_kit_session_execute_async: pointer => calls.push(['execute', pointer]),
    ffmpeg_kit_session_get_state: pointer => {
      calls.push(['get_state', pointer]);
      return 1;
    },
    ffmpeg_kit_handle_release: pointer => calls.push(['release', pointer]),
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  backend.executeSessionAsync(77, 0);
  assert.equal(backend.getSessionState(77), 1);
  assert.deepEqual(calls, [
    ['get_session', 77n],
    ['execute', 1024],
    ['get_state', 1024],
  ]);
});

test('Web backend releases a promoted execution handle exactly once at terminal cleanup', () => {
  const releaseCalls = [];
  const module = {
    ffmpeg_kit_get_session: () => 1024,
    session_is_ffmpeg_session: () => true,
    ffmpeg_kit_session_execute_async: () => {},
    ffmpeg_kit_handle_release: pointer => releaseCalls.push(pointer),
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  backend.executeSessionAsync(77, 0);
  backend.releaseSessionHandle(77);
  backend.releaseSessionHandle(77);
  assert.deepEqual(releaseCalls, [1024]);
});

test('Web backend promotes a history handle when executing an unretained session', () => {
  const calls = [];
  const module = {
    ffmpeg_kit_get_session: sessionId => {
      calls.push(['get_session', sessionId]);
      return 1024;
    },
    ffmpeg_kit_session_get_state: pointer => {
      calls.push(['get_state', pointer]);
      return 1;
    },
    session_is_ffmpeg_session: () => true,
    ffmpeg_kit_session_execute_async: pointer => calls.push(['execute', pointer]),
    ffmpeg_kit_handle_release: pointer => calls.push(['release', pointer]),
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.equal(backend.getSessionState(77), 1);
  backend.executeSessionAsync(77, 0);
  assert.deepEqual(calls, [
    ['get_session', 77n],
    ['get_state', 1024],
    ['release', 1024],
    ['get_session', 77n],
    ['execute', 1024],
  ]);
});

test('Web backend preserves async-start failure and rolls back execution ownership', () => {
  const startError = new Error('async start failed');
  const calls = [];
  const module = {
    ffmpeg_kit_get_session: () => 1024,
    session_is_ffmpeg_session: () => true,
    ffmpeg_kit_session_execute_async: () => {
      calls.push('execute');
      throw startError;
    },
    ffmpeg_kit_handle_release: pointer => calls.push(['release', pointer]),
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.throws(() => backend.executeSessionAsync(77, 0), error => error === startError);
  assert.deepEqual(calls, ['execute', ['release', 1024]]);
});

test('Web backend keeps failed async-start cleanup retryable', () => {
  const startError = new Error('async start failed');
  const releaseError = new Error('execution release failed');
  const releaseCalls = [];
  let shouldFailRelease = true;
  const module = {
    ffmpeg_kit_get_session: () => 1024,
    session_is_ffmpeg_session: () => true,
    ffmpeg_kit_session_execute_async: () => { throw startError; },
    ffmpeg_kit_handle_release: pointer => {
      releaseCalls.push(pointer);
      if (shouldFailRelease) throw releaseError;
    },
  };
  const backend = new WebFFmpegKitBackend(undefined, module);

  assert.throws(() => backend.executeSessionAsync(77, 0), error => error === startError);
  shouldFailRelease = false;
  backend.releaseSessionHandle(77);
  assert.deepEqual(releaseCalls, [1024, 1024]);
});
