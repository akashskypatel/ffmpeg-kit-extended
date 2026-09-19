'use strict';

const assert = require('node:assert/strict');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {before, test} = require('node:test');

let createModuleWithCompiledWasm;

before(async () => {
  ({createModuleWithCompiledWasm} = await import(
    pathToFileURL(path.join(__dirname, '..', 'web', 'ffmpegkit_loader.mjs')).href
  ));
});

test('compiled Wasm instantiation rejection settles the module promise', {timeout: 1000}, async () => {
  const failure = new Error('instantiate failed');

  const modulePromise = createModuleWithCompiledWasm({
    createModule: options => {
      options.instantiateWasm({}, () => {});
      return new Promise(() => {});
    },
    wasmModule: {},
    instantiate: async () => {
      throw failure;
    },
  });

  await assert.rejects(modulePromise, error => error === failure);
});

test('compiled Wasm instantiation success reaches the factory once', {timeout: 1000}, async () => {
  const compiledModule = {};
  const instance = {exports: {}};
  const factoryModule = {ready: true};
  let receiveCount = 0;

  const result = await createModuleWithCompiledWasm({
    createModule: options => new Promise(resolve => {
      options.instantiateWasm({}, (receivedInstance, receivedModule) => {
        receiveCount += 1;
        assert.strictEqual(receivedInstance, instance);
        assert.strictEqual(receivedModule, compiledModule);
        resolve(factoryModule);
      });
    }),
    wasmModule: compiledModule,
    instantiate: async receivedModule => {
      assert.strictEqual(receivedModule, compiledModule);
      return instance;
    },
  });

  assert.strictEqual(result, factoryModule);
  assert.equal(receiveCount, 1);
});
