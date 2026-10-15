import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import test from 'node:test';

import {createCallbackRegistry} from '../flutter/web/ffmpegkit_callback_runtime.mjs';
import {
  createInstantiateWasm,
  createModuleWithCompiledWasm,
  raceWasmModuleAttempt,
} from '../flutter/web/ffmpegkit_loader.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const helperNames = [
  'ffmpegkit_heap_runtime.mjs',
  'ffmpegkit_callback_runtime.mjs',
  'ffmpegkit_loader.mjs',
];
const locations = [
  'flutter/web',
  'flutter/assets/wasm',
  'react-native/web',
];

test('shared bridge runtime modules and Flutter mirrors are byte-identical', async () => {
  for (const name of helperNames) {
    const sources = await Promise.all(locations.map((directory) =>
      readFile(path.join(root, directory, name), 'utf8'),
    ));
    assert.equal(sources[1], sources[0], `Flutter asset mirror differs for ${name}`);
    assert.equal(sources[2], sources[0], `React Native runtime differs for ${name}`);
  }

  const flutterBridge = await readFile(path.join(root, locations[0], 'ffmpegkit_bridge.mjs'), 'utf8');
  const flutterAssetBridge = await readFile(path.join(root, locations[1], 'ffmpegkit_bridge.mjs'), 'utf8');
  assert.equal(flutterAssetBridge, flutterBridge, 'Flutter bridge asset mirror differs');
});

test('bridge sources expose one nonzero protocol version', async () => {
  const bridgeDirectories = ['flutter/web', 'flutter/assets/wasm', 'react-native/web'];
  const versions = await Promise.all(bridgeDirectories.map(async (directory) => {
    const source = await readFile(path.join(root, directory, 'ffmpegkit_bridge.mjs'), 'utf8');
    const match = /export const BRIDGE_PROTOCOL_VERSION = (\d+);/.exec(source);
    assert(match, `${directory} does not declare BRIDGE_PROTOCOL_VERSION`);
    return Number(match[1]);
  }));
  assert(versions[0] > 0, 'Bridge protocol version must be nonzero');
  assert.deepEqual(new Set(versions), new Set([versions[0]]));
});

test('framework callback policies preserve recycling and retained-slot behavior', async () => {
  const flutterBridge = await readFile(path.join(root, 'flutter/web/ffmpegkit_bridge.mjs'), 'utf8');
  const reactNativeBridge = await readFile(path.join(root, 'react-native/web/ffmpegkit_bridge.mjs'), 'utf8');
  assert.match(flutterBridge, /createCallbackRegistry\(wasmTable\)/);
  assert.match(reactNativeBridge, /createCallbackRegistry\(wasmTable,\s*\{\s*recycleRemoved:\s*false/);

  const flutterTable = new WebAssembly.Table({element: 'anyfunc', initial: 1});
  const flutter = createCallbackRegistry(flutterTable);
  const flutterSlot = flutter.addFunction(() => 17, 'i');
  assert.equal(flutterTable.get(flutterSlot)(), 17);
  flutter.removeFunction(flutterSlot);
  assert.equal(flutterTable.get(flutterSlot), null);
  assert.equal(flutter.addFunction(() => 18, 'i'), flutterSlot);

  const reactNativeTable = new WebAssembly.Table({element: 'anyfunc', initial: 1});
  const reactNative = createCallbackRegistry(reactNativeTable, {recycleRemoved: false});
  const reactNativeSlot = reactNative.addFunction(() => 23, 'i');
  reactNative.removeFunction(reactNativeSlot);
  assert.equal(reactNativeTable.get(reactNativeSlot)(), 23);
  assert.equal(reactNative.retainedSlotCount, 1);
});

test('shared loader rejects synchronous instantiation failures', {timeout: 1000}, async () => {
  const failure = new Error('synchronous instantiate failure');
  const modulePromise = createModuleWithCompiledWasm({
    createModule(options) {
      options.instantiateWasm({}, () => {});
      return new Promise(() => {});
    },
    wasmModule: {},
    instantiate() {
      throw failure;
    },
  });
  await assert.rejects(modulePromise, (error) => error === failure);
});

test('shared loader handles sync instantiation rejection when the factory also throws', {timeout: 1000}, async () => {
  const instantiationFailure = new Error('synchronous instantiate failure');
  const factoryFailure = new Error('synchronous module factory failure');
  const instantiator = createInstantiateWasm({}, () => {
    throw instantiationFailure;
  });
  const modulePromise = raceWasmModuleAttempt(() => {
    instantiator.instantiateWasm({}, () => {});
    throw factoryFailure;
  }, instantiator);

  await assert.rejects(modulePromise, (error) => error === factoryFailure);
  await new Promise((resolve) => setImmediate(resolve));
});

test('shared loader ignores instantiation callbacks after factory rejection', {timeout: 1000}, async () => {
  const failure = new Error('module factory failure');
  let resolveInstantiation;
  let received = 0;
  const modulePromise = createModuleWithCompiledWasm({
    createModule(options) {
      options.instantiateWasm({}, () => { received += 1; });
      return Promise.reject(failure);
    },
    wasmModule: {},
    instantiate() {
      return new Promise((resolve) => { resolveInstantiation = resolve; });
    },
  });

  await assert.rejects(modulePromise, (error) => error === failure);
  resolveInstantiation({exports: {}});
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(received, 0);
});
