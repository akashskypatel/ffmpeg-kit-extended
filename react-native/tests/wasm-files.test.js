'use strict';

const assert = require('node:assert/strict');
const {afterEach, test} = require('node:test');

const loader = require('../.test-dist/platform/web/wasm-loader.js');
const {FFmpegKitWebFiles} = require('../.test-dist/platform/web/wasm-files.js');

const originalRequireWasmModule = loader.requireWasmModule;
const originalInitializeWasm = loader.initializeWasm;

function errnoError(code, errno, message) {
  const error = new Error(message);
  error.code = code;
  error.errno = errno;
  error.name = errno === 44 ? 'ErrnoError' : 'Error';
  return error;
}

function createMockFs() {
  const files = new Map();
  const directories = new Set(['/', '/tmp']);
  const calls = [];
  const missingError = () => errnoError('ENOENT', 44, 'No such file or directory');
  return {
    calls,
    files,
    fs: {
      writeFile(path, bytes) {
        calls.push(['writeFile', path]);
        files.set(path, new Uint8Array(bytes));
      },
      readFile(path) {
        calls.push(['readFile', path]);
        const bytes = files.get(path);
        if (!bytes) throw missingError();
        return bytes;
      },
      unlink(path) {
        calls.push(['unlink', path]);
        if (!files.delete(path)) throw missingError();
      },
      stat(path) {
        calls.push(['stat', path]);
        if (directories.has(path)) return {mode: 0x4000, size: 0};
        const bytes = files.get(path);
        if (!bytes) throw missingError();
        return {mode: 0x8000, size: bytes.length};
      },
    },
  };
}

function installRuntime(fs) {
  const module = {FS: fs};
  loader.requireWasmModule = () => module;
  return module;
}

afterEach(() => {
  loader.requireWasmModule = originalRequireWasmModule;
  loader.initializeWasm = originalInitializeWasm;
  loader.resetWasmLoaderForTests();
});

test('file helpers require awaited initialization and do not create a runtime', () => {
  loader.resetWasmLoaderForTests();
  assert.throws(
    () => FFmpegKitWebFiles.writeFile('/tmp/input.mp4', new Uint8Array([1])),
    /FFmpegKitExtended\.initialize\(\) must be awaited/,
  );
});

test('file helpers diagnose runtimes without the exported FS methods', () => {
  loader.requireWasmModule = () => ({});
  assert.throws(
    () => FFmpegKitWebFiles.readFile('/tmp/input.mp4'),
    /Local Wasm runtime lacks exported FS.*rebuild with FS in EXPORTED_RUNTIME_METHODS/,
  );

  loader.requireWasmModule = () => ({FS: {readFile() {}}});
  assert.throws(
    () => FFmpegKitWebFiles.readFile('/tmp/input.mp4'),
    /lacks exported FS methods: writeFile, unlink, stat/,
  );
});

test('binary bytes round-trip without text conversion or buffer aliasing', () => {
  const mock = createMockFs();
  installRuntime(mock.fs);
  const bytes = new Uint8Array([0x00, 0x80, 0xff, 0xc3, 0xa9]);

  FFmpegKitWebFiles.writeFile('/tmp/input.bin', bytes);
  const result = FFmpegKitWebFiles.readFile('/tmp/input.bin');
  assert.deepEqual(Array.from(result), Array.from(bytes));
  result[0] = 0x7f;
  assert.deepEqual(Array.from(FFmpegKitWebFiles.readFile('/tmp/input.bin')), Array.from(bytes));
});

test('empty and distinct files, overwrites, exists, and delete have deterministic behavior', () => {
  const mock = createMockFs();
  installRuntime(mock.fs);

  FFmpegKitWebFiles.writeFile('/tmp/empty.bin', new Uint8Array());
  FFmpegKitWebFiles.writeFile('/tmp/other.bin', new Uint8Array([1, 2]));
  assert.deepEqual(Array.from(FFmpegKitWebFiles.readFile('/tmp/empty.bin')), []);
  assert.deepEqual(Array.from(FFmpegKitWebFiles.readFile('/tmp/other.bin')), [1, 2]);
  FFmpegKitWebFiles.writeFile('/tmp/other.bin', new Uint8Array([9]));
  assert.deepEqual(Array.from(FFmpegKitWebFiles.readFile('/tmp/other.bin')), [9]);
  assert.equal(FFmpegKitWebFiles.exists('/tmp/other.bin'), true);
  FFmpegKitWebFiles.deleteFile('/tmp/other.bin');
  assert.equal(FFmpegKitWebFiles.exists('/tmp/other.bin'), false);
});

test('read and delete preserve missing-file errors; exists propagates unexpected errors', () => {
  const mock = createMockFs();
  installRuntime(mock.fs);
  assert.throws(() => FFmpegKitWebFiles.readFile('/tmp/missing.bin'), /No such file or directory/);
  assert.throws(() => FFmpegKitWebFiles.deleteFile('/tmp/missing.bin'), /No such file or directory/);
  assert.equal(FFmpegKitWebFiles.exists('/tmp/missing.bin'), false);

  const unexpected = new Error('filesystem I/O failure');
  mock.fs.stat = () => { throw unexpected; };
  assert.throws(() => FFmpegKitWebFiles.exists('/tmp/missing.bin'), error => error === unexpected);
});

test('paths are flat files directly under /tmp and reject invalid forms before FS access', () => {
  const mock = createMockFs();
  installRuntime(mock.fs);
  const invalidPaths = [
    '',
    'relative.bin',
    '/etc/passwd',
    '/tmp/',
    '/tmp/.',
    '/tmp/..',
    '/tmp/../escape.bin',
    '/tmp/sub/file.bin',
    '/tmp\\file.bin',
    '/tmp/bad\0name.bin',
  ];

  for (const path of invalidPaths) {
    assert.throws(() => FFmpegKitWebFiles.writeFile(path, new Uint8Array([1])), TypeError);
  }
  assert.equal(mock.calls.length, 0);
  assert.throws(() => FFmpegKitWebFiles.exists('/tmp'), TypeError);
});

test('exists rejects a directory instead of treating it as a file', () => {
  const mock = createMockFs();
  installRuntime(mock.fs);
  assert.throws(() => FFmpegKitWebFiles.exists('/tmp'), TypeError);
});

test('helpers reuse the loaded module and do not call initialization', () => {
  const mock = createMockFs();
  const module = installRuntime(mock.fs);
  let initializeCalls = 0;
  loader.initializeWasm = async () => { initializeCalls += 1; };

  FFmpegKitWebFiles.writeFile('/tmp/value.bin', new Uint8Array([4]));
  FFmpegKitWebFiles.readFile('/tmp/value.bin');
  FFmpegKitWebFiles.exists('/tmp/value.bin');
  FFmpegKitWebFiles.deleteFile('/tmp/value.bin');
  assert.equal(initializeCalls, 0);
  assert.equal(mock.calls.length, 4);
  assert.deepEqual(Object.keys(FFmpegKitWebFiles), ['writeFile', 'readFile', 'deleteFile', 'exists']);
  assert.equal(loader.requireWasmModule(), module);
});
