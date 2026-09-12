import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import process from 'node:process';
import {pathToFileURL} from 'node:url';

import {
  createCallbackRegistry,
  discoverWasmTable,
} from './ffmpegkit_callback_runtime.mjs';

const artifactPath = process.argv[2];
const loaderPath = process.argv[3];
if (!artifactPath || !loaderPath) {
  throw new Error(
    'usage: ffmpegkit_callback_roundtrip_test.mjs <ffmpegkit.wasm> <ffmpegkit.mjs>',
  );
}

const createFFmpegKit = (await import(pathToFileURL(loaderPath).href)).default;
const wasmMemory = new WebAssembly.Memory({
  initial: 1024,
  maximum: 32768,
  shared: true,
});
let instance;
await createFFmpegKit({
  wasmMemory,
  instantiateWasm: (imports, receiveInstance) => {
    readFile(artifactPath)
      .then((bytes) => WebAssembly.instantiate(bytes, imports))
      .then(({instance: wasmInstance, module}) => {
        instance = wasmInstance;
        receiveInstance(wasmInstance, module);
      });
    return {};
  },
});
assert(instance, 'Emscripten loader did not expose the Wasm instance');
const requiredExports = [
  'ffmpeg_kit_initialize',
  'ffmpeg_kit_create_session',
  'ffmpeg_kit_session_execute_async',
  'ffmpeg_kit_session_get_session_id',
  'ffmpeg_kit_handle_release',
  'ffmpeg_kit_config_enable_log_callback_v2',
  'ffmpeg_kit_config_enable_statistics_callback_v2',
  'ffmpeg_kit_config_enable_ffmpeg_session_complete_callback_v2',
  'ffmpeg_kit_test_emit_v2_log_with_session_id',
  'ffmpeg_kit_test_emit_v2_statistics_with_session_id',
  'ffmpeg_kit_test_emit_v2_ffmpeg_completion_with_session_id',
  'ffmpeg_kit_test_process_wasm_callback_queue',
  'malloc',
  'free',
];
for (const name of requiredExports) {
  assert.equal(typeof instance.exports[name], 'function', `missing export ${name}`);
}

const table = discoverWasmTable(instance.exports);
const registry = createCallbackRegistry(table);
const memory = wasmMemory;
const userData = 0x7a00;
const sessionId = 0x102030405n;
const events = [];

const decodeString = (address) => {
  const bytes = new Uint8Array(memory.buffer);
  const end = bytes.indexOf(0, address);
  return new TextDecoder().decode(bytes.subarray(address, end));
};
const writeString = (value) => {
  const bytes = new TextEncoder().encode(value);
  const address = instance.exports.malloc(bytes.length + 1);
  new Uint8Array(memory.buffer).set(bytes, address);
  new Uint8Array(memory.buffer)[address + bytes.length] = 0;
  return address;
};

const logPointer = registry.addFunction((id, message, owner) => {
  events.push(['log', id, decodeString(message), owner]);
}, 'vjpp');
const statisticsPointer = registry.addFunction((id, timeElapsed, time, size,
                                                  bitrate, speed, frame,
                                                  fps, quality, dup, drop,
                                                  owner) => {
  events.push([
    'statistics', id, timeElapsed, time, size, bitrate, speed, frame, fps,
    quality, dup, drop, owner,
  ]);
}, 'vjjjjddjddjjp');
const completionPointer = registry.addFunction((id, owner) => {
  events.push(['completion', id, owner]);
}, 'vjp');

instance.exports.ffmpeg_kit_config_enable_log_callback_v2(logPointer, userData);
instance.exports.ffmpeg_kit_config_enable_statistics_callback_v2(
  statisticsPointer,
  userData,
);
instance.exports.ffmpeg_kit_config_enable_ffmpeg_session_complete_callback_v2(
  completionPointer,
  userData,
);

const messageAddress = writeString('g12-roundtrip');
instance.exports.ffmpeg_kit_test_emit_v2_log_with_session_id(
  sessionId,
  messageAddress,
);
instance.exports.free(messageAddress);
instance.exports.ffmpeg_kit_test_emit_v2_statistics_with_session_id(
  sessionId,
  1n,
  2n,
  3n,
  4.5,
  5.5,
  6n,
  7.5,
  8.5,
  9n,
  10n,
);
instance.exports.ffmpeg_kit_test_emit_v2_ffmpeg_completion_with_session_id(sessionId);
instance.exports.ffmpeg_kit_test_process_wasm_callback_queue();

assert.deepEqual(events, [
  ['log', sessionId, 'g12-roundtrip', userData],
  ['statistics', sessionId, 1n, 2n, 3n, 4.5, 5.5, 6n, 7.5, 8.5, 9n, 10n, userData],
  ['completion', sessionId, userData],
]);

events.length = 0;
instance.exports.ffmpeg_kit_initialize();
const commandAddress = writeString(
  '-loglevel info -f lavfi -i testsrc=duration=1:size=16x16:rate=5 -f null -',
);
const session = instance.exports.ffmpeg_kit_create_session(commandAddress);
instance.exports.free(commandAddress);
assert(session, 'FFmpegKit did not create the real async session');
const expectedSessionId = BigInt(
  instance.exports.ffmpeg_kit_session_get_session_id(session),
);
instance.exports.ffmpeg_kit_session_execute_async(session);

const deadline = Date.now() + 15000;
while (!events.some(([kind]) => kind === 'completion') && Date.now() < deadline) {
  instance.exports.ffmpeg_kit_test_process_wasm_callback_queue();
  await new Promise((resolve) => setTimeout(resolve, 1));
}
instance.exports.ffmpeg_kit_test_process_wasm_callback_queue();
instance.exports.ffmpeg_kit_handle_release(session);

const realLogs = events.filter(([kind]) => kind === 'log');
const realStatistics = events.filter(([kind]) => kind === 'statistics');
const realCompletions = events.filter(([kind]) => kind === 'completion');
assert.equal(realCompletions.length, 1, 'real session did not complete exactly once');
assert(realLogs.length > 0, 'real session did not deliver a log callback');
assert(realStatistics.length > 0, 'real session did not deliver a statistics callback');
for (const event of events) {
  assert.equal(event[1], expectedSessionId, `callback used the wrong session ID: ${event[1]}`);
}

instance.exports.ffmpeg_kit_config_enable_log_callback_v2(0, 0);
instance.exports.ffmpeg_kit_config_enable_statistics_callback_v2(0, 0);
instance.exports.ffmpeg_kit_config_enable_ffmpeg_session_complete_callback_v2(0, 0);
registry.removeFunction(logPointer);
registry.removeFunction(statisticsPointer);
registry.removeFunction(completionPointer);
assert.equal(registry.ownedCount, 0);

console.log(JSON.stringify({
  sessionId: sessionId.toString(),
  callbacks: events.map(([kind]) => kind),
  realLogCount: realLogs.length,
  realStatisticsCount: realStatistics.length,
  realCompletionCount: realCompletions.length,
  userData,
  status: 'PASS',
}));
