import createFFmpegKit from './ffmpegkit.mjs';
import {
  createCallbackRegistry,
  discoverWasmTable,
} from './ffmpegkit_callback_runtime.mjs';

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

  defineRuntime('HEAPU8', {
    configurable: true,
    get: () => heap(Uint8Array),
  });
  defineRuntime('HEAPU32', {
    configurable: true,
    get: () => heap(Uint32Array),
  });
  defineRuntime('HEAPF32', {
    configurable: true,
    get: () => heap(Float32Array),
  });

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

globalThis.ffmpegKitExtendedModulePromise ??= (() => {
  const wasmMemory = new WebAssembly.Memory({
    initial: 1024,
    maximum: 32768,
    shared: true,
  });
  let wasmTable;

  const modulePromise = createFFmpegKit({
    wasmMemory,
    // Web execution is non-interactive. Return EOF instead of allowing the
    // Emscripten default to open a browser prompt when a command reads stdin.
    stdin: () => null,
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
