import createFFmpegKit from './ffmpegkit.mjs';
import {
  createCallbackRegistry,
  discoverWasmTable,
} from './ffmpegkit_callback_runtime.mjs';

// The release bundles export the FFmpegKit C ABI, but intentionally keep most
// Emscripten runtime helpers private. ffigen_js uses a small subset of those
// helpers for pointer/string and callback marshalling, so provide the same
// surface on the module object after it has been initialized.
function installFfigenRuntime(module, wasmMemory, wasmTable) {
  const heap = (View) => new View(wasmMemory.buffer);

  Object.defineProperties(module, {
    HEAPU8: { configurable: true, get: () => heap(Uint8Array) },
    HEAPU32: { configurable: true, get: () => heap(Uint32Array) },
    HEAPF32: { configurable: true, get: () => heap(Float32Array) },
  });

  module.getValue = (address, type = 'i8') => {
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
  };

  module.getValueBigInt = (address, type) => {
    if (type !== 'i64') {
      throw new TypeError(`Unsupported getValueBigInt type: ${type}`);
    }
    return heap(BigInt64Array)[address >> 3];
  };

  module.setValue = (address, value, type = 'i8') => {
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
  };

  module.lengthBytesUTF8 = (value) => new TextEncoder().encode(value).length;
  module.stringToUTF8 = (value, address, maxBytesToWrite) => {
    const bytes = new TextEncoder().encode(value);
    const output = heap(Uint8Array);
    const length = Math.max(0, Math.min(bytes.length, maxBytesToWrite - 1));
    output.set(bytes.subarray(0, length), address);
    output[address + length] = 0;
    return length;
  };
  module.writeArrayToMemory = (array, address) => {
    heap(Int8Array).set(array, address);
  };

  // Keep callback ownership local to this initialized module so slots can be
  // recycled only after the caller has unregistered the C callback.
  const callbackRegistry = createCallbackRegistry(wasmTable);
  module.addFunction = callbackRegistry.addFunction;
  module.removeFunction = callbackRegistry.removeFunction;
}

globalThis.ffmpegKitExtendedModulePromise ??= (() => {
  const wasmMemory = new WebAssembly.Memory({
    initial: 1024,
    maximum: 32768,
    shared: true,
  });
  let wasmTable;

  const modulePromise = createFFmpegKit({
    wasmMemory,
    locateFile: (file) => new URL(file, import.meta.url).href,
    instantiateWasm: (imports, receiveInstance) => {
      const wasmUrl = new URL('ffmpegkit.wasm', import.meta.url);
      fetch(wasmUrl, { credentials: 'same-origin' })
        .then((response) => {
          if (!response.ok) {
            throw new Error(`${response.status}: ${response.url}`);
          }
          return response.arrayBuffer();
        })
        .then((bytes) => WebAssembly.instantiate(bytes, imports))
        .then(({ instance, module }) => {
          wasmTable = discoverWasmTable(instance.exports);
          receiveInstance(instance, module);
        });
      return {};
    },
  });

  return modulePromise.then((module) => {
    installFfigenRuntime(module, wasmMemory, wasmTable);
    return module;
  });
})();
