import assert from 'node:assert/strict';
import {mkdtemp, readFile, rm, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import test from 'node:test';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const bridges = [
  {
    name: 'Flutter web',
    path: 'flutter/web/ffmpegkit_bridge.mjs',
    flutter: true,
  },
  {
    name: 'Flutter asset mirror',
    path: 'flutter/assets/wasm/ffmpegkit_bridge.mjs',
    flutter: true,
  },
  {
    name: 'React Native web',
    path: 'react-native/web/ffmpegkit_bridge.mjs',
    flutter: false,
  },
];

async function createHarness(bridge) {
  const directory = await mkdtemp(path.join(tmpdir(), 'CODEX_wasm_bridge_'));
  try {
    const bridgeDirectory = path.dirname(bridge.path);
    const [source, callbackRuntime, heapRuntime] = await Promise.all([
      readFile(path.join(root, bridge.path), 'utf8'),
      readFile(path.join(root, bridgeDirectory, 'ffmpegkit_callback_runtime.mjs'), 'utf8'),
      readFile(path.join(root, bridgeDirectory, 'ffmpegkit_heap_runtime.mjs'), 'utf8'),
    ]);
    const state = {
      fetches: 0,
      factoryCalls: 0,
      instantiations: 0,
      options: [],
      tables: [],
      missingExport: undefined,
      freedPointers: [],
    };
    const fixture = `globalThis.__wasmBridgeFixture`;

    await Promise.all([
      writeFile(path.join(directory, 'ffmpegkit_bridge.mjs'), source),
      writeFile(path.join(directory, 'ffmpegkit_callback_runtime.mjs'), callbackRuntime),
      writeFile(path.join(directory, 'ffmpegkit_heap_runtime.mjs'), heapRuntime),
      writeFile(path.join(directory, 'ffmpegkit.mjs'), `
        export default async function createFFmpegKit(options) {
          const state = ${fixture};
          state.factoryCalls++;
          state.options.push(options);
          state.tables.push(new WebAssembly.Table({element: 'anyfunc', initial: 1}));
          state.table = state.tables.at(-1);
          await options.instantiateWasm({}, () => {});
        const versionPointer = 128;
        const module = {
          _ffmpeg_kit_initialize() {},
          _ffmpeg_kit_session_execute_async() {},
          _ffprobe_kit_session_execute_async() {},
          _ffplay_kit_session_execute_async() {},
          _ffplay_kit_copy_frame() {},
          _ffmpeg_kit_session_cancel() {},
          _ffmpeg_kit_config_get_version() { return versionPointer; },
          _ffmpeg_kit_free(pointer) { state.freedPointers.push(pointer); },
          UTF8ToString(pointer) {
            const bytes = new Uint8Array(options.wasmMemory.buffer);
            let end = pointer;
            while (bytes[end]) end++;
            return new TextDecoder().decode(bytes.subarray(pointer, end));
          },
        };
        if (state.missingExport) delete module[state.missingExport];
        return module;
        }
      `),
      writeFile(path.join(directory, 'ffmpegkit_loader.mjs'), bridge.flutter ? `
        export async function fetchAndCompileWasmWithMemory() {
          ${fixture}.fetches++;
          return {
            wasmModule: {},
            memoryLimits: { initial: 1024, maximum: 32768, shared: true },
          };
        }
        export function createInstantiateWasm(wasmModule) {
          return {
            instantiateWasm(imports, receiveInstance) {
              ${fixture}.instantiations++;
              receiveInstance({exports: {table: ${fixture}.table}}, wasmModule);
            },
          };
        }
        export async function raceWasmModuleAttempt(factory) {
          return factory();
        }
      ` : `
        export async function fetchAndCompileWasmWithMemory() {
          ${fixture}.fetches++;
          return {
            wasmModule: {},
            memoryLimits: { initial: 1024, maximum: 32768, shared: true },
          };
        }
        export async function createModuleWithCompiledWasm({
          createModule, wasmModule, onInstance, options,
        }) {
          return createModule({
            ...options,
            instantiateWasm(imports, receiveInstance) {
              ${fixture}.instantiations++;
              const instance = {exports: {table: ${fixture}.table}};
              onInstance(instance, wasmModule);
              receiveInstance(instance, wasmModule);
              return {};
            },
          });
        }
      `),
    ]);

    delete globalThis.ffmpegKitExtendedModuleFactory;
    globalThis.__wasmBridgeFixture = state;
    const module = await import(pathToFileURL(
      path.join(directory, 'ffmpegkit_bridge.mjs'),
    ).href);
    return {
      directory,
      state,
      async createModule() {
        return bridge.flutter
          ? globalThis.ffmpegKitExtendedModuleFactory()
          : module.createFFmpegKitModule();
      },
    };
  } catch (error) {
    await rm(directory, {recursive: true, force: true});
    throw error;
  }
}

async function withGlobals(values, action) {
  const descriptors = [];
  for (const [name, value] of Object.entries(values)) {
    const target = name === 'Memory' ? WebAssembly : globalThis;
    descriptors.push([target, name, Object.getOwnPropertyDescriptor(target, name)]);
    Object.defineProperty(target, name, {
      configurable: true,
      writable: true,
      value,
    });
  }
  try {
    return await action();
  } finally {
    for (const [target, name, descriptor] of descriptors.reverse()) {
      if (descriptor) Object.defineProperty(target, name, descriptor);
      else delete target[name];
    }
  }
}

for (const bridge of bridges) {
  test(`${bridge.name} bridge bootstrap`, async (t) => {
    const harness = await createHarness(bridge);
    t.after(async () => {
      delete globalThis.ffmpegKitExtendedModuleFactory;
      delete globalThis.__wasmBridgeFixture;
      await rm(harness.directory, {recursive: true, force: true});
    });

    await t.test('rejects a non-isolated browser before allocating or loading', async () => {
      let memoryAllocations = 0;
      const Memory = WebAssembly.Memory;
      class CountedMemory extends Memory {
        constructor(options) {
          memoryAllocations++;
          super(options);
        }
      }
      await withGlobals({
        document: {createElement() { throw new Error('canvas should not be created'); }},
        crossOriginIsolated: false,
        Memory: CountedMemory,
      }, async () => {
        await assert.rejects(harness.createModule(), /cross-origin isolation/);
      });
      assert.equal(memoryAllocations, 0);
      assert.equal(harness.state.fetches, 0);
      assert.equal(harness.state.factoryCalls, 0);
      assert.equal(harness.state.instantiations, 0);
    });

    await t.test('rejects a browser without SharedArrayBuffer before loading', async () => {
      let memoryAllocations = 0;
      const Memory = WebAssembly.Memory;
      class CountedMemory extends Memory {
        constructor(options) {
          memoryAllocations++;
          super(options);
        }
      }
      await withGlobals({
        document: {createElement() { throw new Error('canvas should not be created'); }},
        crossOriginIsolated: true,
        SharedArrayBuffer: undefined,
        Memory: CountedMemory,
      }, async () => {
        await assert.rejects(harness.createModule(), /requires SharedArrayBuffer/);
      });
      assert.equal(memoryAllocations, 0);
      assert.equal(harness.state.fetches, 0);
      assert.equal(harness.state.factoryCalls, 0);
      assert.equal(harness.state.instantiations, 0);
    });

    await t.test('passes a private canvas and fresh shared memory per browser module', async () => {
      const canvases = [];
      await withGlobals({
        document: {createElement(name) {
          assert.equal(name, 'canvas');
          const canvas = {};
          canvases.push(canvas);
          return canvas;
        }},
        crossOriginIsolated: true,
      }, async () => {
        const first = await harness.createModule();
        const second = await harness.createModule();
        const [firstOptions, secondOptions] = harness.state.options;

        assert.notEqual(firstOptions.canvas, secondOptions.canvas);
        assert.notEqual(firstOptions.wasmMemory, secondOptions.wasmMemory);
        assert.equal(firstOptions.canvas, canvases[0]);
        assert.equal(secondOptions.canvas, canvases[1]);
        for (const [index, module, options] of [
          [0, first, firstOptions],
          [1, second, secondOptions],
        ]) {
          assert.equal(options.wasmMemory instanceof WebAssembly.Memory, true);
          assert.equal(options.wasmMemory.buffer instanceof SharedArrayBuffer, true);
          assert.equal(typeof options.instantiateWasm, 'function');
          assert.equal(typeof options.locateFile, 'function');
          assert.equal(typeof options.stdin, 'function');
          assert.equal(module.HEAPU8.buffer, options.wasmMemory.buffer);
          assert.equal(typeof module.addFunction, 'function');
          const slot = module.addFunction(() => 42, 'i');
          const table = harness.state.tables[index];
          assert.equal(table.get(slot)(), 42);
          module.removeFunction(slot);
          if (bridge.flutter) {
            assert.equal(table.get(slot), null);
          } else {
            assert.equal(typeof table.get(slot), 'function');
            assert.equal(table.get(slot)(), 42);
          }
        }
      });
      assert.equal(harness.state.fetches, 2);
      assert.equal(harness.state.factoryCalls, 2);
      assert.equal(harness.state.instantiations, 2);
      assert.deepEqual(harness.state.freedPointers, [128, 128]);
    });

    await t.test('keeps Node initialization usable without a document', async () => {
      await withGlobals({
        document: undefined,
        crossOriginIsolated: false,
      }, async () => {
        const module = await harness.createModule();
        const options = harness.state.options.at(-1);
        assert.equal('canvas' in options, false);
        assert.equal(module.HEAPU8.buffer, options.wasmMemory.buffer);
      });
      assert.equal(harness.state.fetches, 3);
      assert.equal(harness.state.factoryCalls, 3);
      assert.equal(harness.state.instantiations, 3);
    });

    await t.test('rejects a module missing a required ABI export', async () => {
      const freedBefore = harness.state.freedPointers.length;
      harness.state.missingExport = '_ffmpeg_kit_session_cancel';
      await assert.rejects(
        harness.createModule(),
        /missing required exports: _ffmpeg_kit_session_cancel/,
      );
      assert.equal(harness.state.freedPointers.length, freedBefore);
      harness.state.missingExport = undefined;
    });

  });
}
