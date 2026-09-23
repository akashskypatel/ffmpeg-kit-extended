import createFFmpegKit from "./ffmpegkit.mjs";
import {
  createModuleWithCompiledWasm,
  fetchAndCompileWasm,
} from "./ffmpegkit_loader.mjs";
import {
  createCallbackRegistry,
  discoverWasmTable,
} from "./ffmpegkit_callback_runtime.mjs";

function installFfigenRuntime(module, wasmMemory, wasmTable) {
  const heap = (View) => new View(wasmMemory.buffer);
  const defineRuntime = (name, descriptor) => {
    try {
      Object.defineProperty(module, name, descriptor);
    } catch (error) {
      if (!Object.prototype.hasOwnProperty.call(module, name)) throw error;
    }
  };

  defineRuntime("HEAPU8", { configurable: true, get: () => heap(Uint8Array) });
  defineRuntime("HEAPU32", {
    configurable: true,
    get: () => heap(Uint32Array),
  });
  defineRuntime("HEAPF32", {
    configurable: true,
    get: () => heap(Float32Array),
  });
  defineRuntime("getValue", {
    configurable: true,
    value: (address, type = "i8") => {
      switch (type.endsWith("*") ? "*" : type) {
        case "i8":
          return heap(Int8Array)[address];
        case "i16":
          return heap(Int16Array)[address >> 1];
        case "i32":
          return heap(Int32Array)[address >> 2];
        case "i64":
          return Number(heap(BigInt64Array)[address >> 3]);
        case "float":
          return heap(Float32Array)[address >> 2];
        case "double":
          return heap(Float64Array)[address >> 3];
        case "*":
          return heap(Uint32Array)[address >> 2];
        default:
          throw new TypeError(`Unsupported getValue type: ${type}`);
      }
    },
  });
  defineRuntime("getValueBigInt", {
    configurable: true,
    value: (address, type) => {
      if (type !== "i64")
        throw new TypeError(`Unsupported getValueBigInt type: ${type}`);
      return heap(BigInt64Array)[address >> 3];
    },
  });
  defineRuntime("setValue", {
    configurable: true,
    value: (address, value, type = "i8") => {
      switch (type.endsWith("*") ? "*" : type) {
        case "i8":
          heap(Int8Array)[address] = Number(value);
          break;
        case "i16":
          heap(Int16Array)[address >> 1] = Number(value);
          break;
        case "i32":
          heap(Int32Array)[address >> 2] = Number(value);
          break;
        case "i64":
          heap(BigInt64Array)[address >> 3] = BigInt(value);
          break;
        case "float":
          heap(Float32Array)[address >> 2] = Number(value);
          break;
        case "double":
          heap(Float64Array)[address >> 3] = Number(value);
          break;
        case "*":
          heap(Uint32Array)[address >> 2] = Number(value);
          break;
        default:
          throw new TypeError(`Unsupported setValue type: ${type}`);
      }
    },
  });
  defineRuntime("lengthBytesUTF8", {
    configurable: true,
    value: (value) => new TextEncoder().encode(value).length,
  });
  defineRuntime("stringToUTF8", {
    configurable: true,
    value: (value, address, maxBytesToWrite) => {
      const bytes = new TextEncoder().encode(value);
      const output = heap(Uint8Array);
      const length = Math.max(0, Math.min(bytes.length, maxBytesToWrite - 1));
      output.set(bytes.subarray(0, length), address);
      output[address + length] = 0;
      return length;
    },
  });

  const callbackRegistry = createCallbackRegistry(wasmTable);
  defineRuntime("addFunction", {
    configurable: true,
    value: callbackRegistry.addFunction,
  });
  defineRuntime("removeFunction", {
    configurable: true,
    value: callbackRegistry.removeFunction,
  });
}

export async function createFFmpegKitModule() {
  const wasmMemory = new WebAssembly.Memory({
    initial: 1024,
    maximum: 32768,
    shared: true,
  });
  const wasmModule = await fetchAndCompileWasm(
    new URL("ffmpegkit.wasm", import.meta.url)
  );
  let wasmTable;
  const module = await createModuleWithCompiledWasm({
    createModule: createFFmpegKit,
    wasmModule,
    onInstance: (instance) => {
      wasmTable = discoverWasmTable(instance.exports);
    },
    options: {
      wasmMemory,
      stdin: () => null,
      locateFile: (file) => new URL(file, import.meta.url).href,
    },
  });
  if (!wasmTable)
    throw new Error("Emscripten did not expose the Wasm callback table.");
  installFfigenRuntime(module, wasmMemory, wasmTable);
  return module;
}
