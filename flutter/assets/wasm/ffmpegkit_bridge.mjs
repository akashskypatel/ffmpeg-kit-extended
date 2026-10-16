import createFFmpegKit from './ffmpegkit.mjs';
import {
  createCallbackRegistry,
  discoverWasmTable,
} from './ffmpegkit_callback_runtime.mjs';
import {
  createInstantiateWasm,
  fetchAndCompileWasmWithMemory,
  raceWasmModuleAttempt,
} from './ffmpegkit_loader.mjs';
import { installHeapViews } from './ffmpegkit_heap_runtime.mjs';

export const BRIDGE_PROTOCOL_VERSION = 1;

function createBrowserModuleOptions() {
  const runningInNode = typeof process !== 'undefined' &&
    process.versions?.node;
  if (typeof document === 'undefined' && runningInNode) return {};
  if (globalThis.crossOriginIsolated !== true) {
    throw new Error(
      'FFmpegKit Web requires cross-origin isolation (crossOriginIsolated).',
    );
  }
  if (typeof globalThis.SharedArrayBuffer !== 'function') {
    throw new Error(
      'FFmpegKit Web requires SharedArrayBuffer for shared Wasm memory.',
    );
  }
  return typeof document === 'undefined'
    ? {}
    : { canvas: document.createElement('canvas') };
}

function validateFFmpegKitModule(module) {
  const requiredExports = [
    '_ffmpeg_kit_initialize',
    '_ffmpeg_kit_session_execute_async',
    '_ffprobe_kit_session_execute_async',
    '_ffplay_kit_session_execute_async',
    '_ffplay_kit_copy_frame',
    '_ffmpeg_kit_session_cancel',
    '_ffmpeg_kit_config_get_version',
    '_ffmpeg_kit_free',
    'UTF8ToString',
  ];
  const missing = requiredExports.filter((name) => typeof module[name] !== 'function');
  if (missing.length) {
    throw new Error(`FFmpegKit Web runtime is missing required exports: ${missing.join(', ')}.`);
  }

  let versionPointer;
  let version;
  try {
    versionPointer = module._ffmpeg_kit_config_get_version();
    if (!versionPointer) {
      throw new Error('version getter returned a null pointer');
    }
    version = module.UTF8ToString(versionPointer);
  } catch (error) {
    throw new Error(`FFmpegKit Web runtime version could not be read: ${String(error?.message ?? error)}`);
  } finally {
    if (versionPointer) module._ffmpeg_kit_free(versionPointer);
  }
}

  // ffigen_js uses a small subset of Emscripten runtime helpers for
  // pointer/string and callback marshalling. Some runtimes expose these
  // helpers as read-only module properties, while others keep them private.
  // Extend only the missing surface so both runtime shapes remain supported.
function installFfigenRuntime(module, wasmMemory, wasmTable) {
  const heap = (View) => new View(wasmMemory.buffer);

  const defineRuntime = (name, descriptor) => {
    try {
      Object.defineProperty(module, name, descriptor);
    } catch (error) {
      // A runtime may expose a non-configurable implementation. Keep it when
      // it cannot be replaced; the generated binding can use the native
      // implementation in that case.
      if (!Object.prototype.hasOwnProperty.call(module, name)) throw error;
    }
  };

  installHeapViews(module, wasmMemory);

  defineRuntime('getValue', { configurable: true, value: (address, type = 'i8') => {
    switch (type.endsWith('*') ? '*' : type) {
      case 'i8': return heap(Int8Array)[address];
      case 'i16': return heap(Int16Array)[address >> 1];
      case 'i32': return heap(Int32Array)[address >> 2];
      // ffigen_js declares getValue as JSNumber even for int64 memory
      // reads. Keep the explicit getValueBigInt path below for bindings that
      // need a BigInt result, but return a number here to match that ABI.
      case 'i64': return Number(heap(BigInt64Array)[address >> 3]);
      case 'float': return heap(Float32Array)[address >> 2];
      case 'double': return heap(Float64Array)[address >> 3];
      case '*': return heap(Uint32Array)[address >> 2];
      default: throw new TypeError(`Unsupported getValue type: ${type}`);
    }
  } });

  defineRuntime('getValueBigInt', { configurable: true, value: (address, type) => {
    if (type !== 'i64') {
      throw new TypeError(`Unsupported getValueBigInt type: ${type}`);
    }
    return heap(BigInt64Array)[address >> 3];
  } });

  defineRuntime('setValue', { configurable: true, value: (address, value, type = 'i8') => {
    switch (type.endsWith('*') ? '*' : type) {
      case 'i8': heap(Int8Array)[address] = Number(value); break;
      case 'i16': heap(Int16Array)[address >> 1] = Number(value); break;
      case 'i32': heap(Int32Array)[address >> 2] = Number(value); break;
      case 'i64': heap(BigInt64Array)[address >> 3] = BigInt(value); break;
      case 'float': heap(Float32Array)[address >> 2] = Number(value); break;
      case 'double': heap(Float64Array)[address >> 3] = Number(value); break;
      case '*': heap(Uint32Array)[address >> 2] = Number(value); break;
      default: throw new TypeError(`Unsupported setValue type: ${type}`);
    }
  } });

  defineRuntime('lengthBytesUTF8', {
    configurable: true,
    value: (value) => new TextEncoder().encode(value).length,
  });
  defineRuntime('stringToUTF8', { configurable: true, value: (value, address, maxBytesToWrite) => {
    const bytes = new TextEncoder().encode(value);
    const output = heap(Uint8Array);
    const length = Math.max(0, Math.min(bytes.length, maxBytesToWrite - 1));
    output.set(bytes.subarray(0, length), address);
    output[address + length] = 0;
    return length;
  } });
  defineRuntime('writeArrayToMemory', { configurable: true, value: (array, address) => {
    heap(Int8Array).set(array, address);
  } });

  // Keep callback ownership local to this initialized module so slots can be
  // recycled only after the caller has unregistered the C callback.
  const callbackRegistry = createCallbackRegistry(wasmTable);
  defineRuntime('addFunction', {
    configurable: true,
    value: callbackRegistry.addFunction,
  });
  defineRuntime('removeFunction', {
    configurable: true,
    value: callbackRegistry.removeFunction,
  });
}

async function loadFFmpegKitModule() {
  const browserOptions = createBrowserModuleOptions();
  const wasmUrl = new URL('ffmpegkit.wasm', import.meta.url);
  const { wasmModule, memoryLimits } = await fetchAndCompileWasmWithMemory(wasmUrl);
  const wasmMemory = new WebAssembly.Memory(memoryLimits);
  let wasmTable;
  const instantiator = createInstantiateWasm(wasmModule);
  const module = await raceWasmModuleAttempt(
    () =>
        createFFmpegKit({
          ...browserOptions,
          wasmMemory,
          // Web execution is non-interactive. Return EOF instead of allowing
          // the Emscripten default to open a browser prompt.
          stdin: () => null,
          locateFile: (file) => new URL(file, import.meta.url).href,
          instantiateWasm: (imports, receiveInstance) => {
            instantiator.instantiateWasm(imports, (instance, module) => {
              wasmTable = discoverWasmTable(instance.exports);
              receiveInstance(instance, module);
            });
            return {};
          },
        }),
    instantiator,
  );

  if (!wasmTable) {
    throw new Error('Emscripten did not expose the Wasm callback table.');
  }
  installFfigenRuntime(module, wasmMemory, wasmTable);
  validateFFmpegKitModule(module);
  return module;
}

globalThis.ffmpegKitExtendedModuleFactory ??= loadFFmpegKitModule;
