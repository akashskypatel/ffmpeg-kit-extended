import createFFmpegKit from './ffmpegkit.mjs';

// The release bundles export the FFmpegKit C ABI, but intentionally keep most
// Emscripten runtime helpers private. ffigen_js uses a small subset of those
// helpers for pointer/string and callback marshalling, so provide the same
// surface on the module object after it has been initialized.
function installFfigenRuntime(module, wasmMemory, wasmTable) {
  const heap = (View) => new View(wasmMemory.buffer);

  const encodeU32 = (value) => {
    const bytes = [];
    do {
      let byte = value & 0x7f;
      value >>>= 7;
      if (value !== 0) byte |= 0x80;
      bytes.push(byte);
    } while (value !== 0);
    return bytes;
  };
  const encodeString = (value) => {
    const bytes = Array.from(new TextEncoder().encode(value));
    return [...encodeU32(bytes.length), ...bytes];
  };
  const wasmType = (type) => {
    switch (type) {
      case 'p':
      case 'i': return 0x7f; // i32
      case 'j': return 0x7e; // i64
      case 'f': return 0x7d; // f32
      case 'd': return 0x7c; // f64
      default: throw new TypeError(`Unsupported callback type: ${type}`);
    }
  };
  const makeCallbackWrapper = (fn, signature) => {
    const parameterTypes = Array.from(signature.slice(1), wasmType);
    const resultType = signature[0] === 'v' ? [] : [wasmType(signature[0])];
    const functionType = [
      0x60,
      ...encodeU32(parameterTypes.length),
      ...parameterTypes,
      ...encodeU32(resultType.length),
      ...resultType,
    ];
    const body = [
      0x00, // no local declarations
      ...parameterTypes.map((_, index) => [0x20, ...encodeU32(index)]).flat(),
      0x10, 0x00, // call imported callback
      0x0b, // end
    ];
    const importSection = [
      0x01,
      ...encodeString('env'),
      ...encodeString('callback'),
      0x00, 0x00, // imported function, type 0
    ];
    const functionSection = [0x01, 0x00];
    const exportName = encodeString('wrapper');
    const exportSection = [
      0x01,
      ...exportName,
      0x00, 0x01, // function export, function index 1
    ];
    const codeBody = [...encodeU32(body.length), ...body];
    const codeSection = [0x01, ...codeBody];
    const section = (id, payload) => [id, ...encodeU32(payload.length), ...payload];
    const binary = new Uint8Array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
      ...section(1, [0x01, ...functionType]),
      ...section(2, importSection),
      ...section(3, functionSection),
      ...section(7, exportSection),
      ...section(10, codeSection),
    ]);
    const instance = new WebAssembly.Instance(
      new WebAssembly.Module(binary),
      { env: { callback: fn } },
    );
    return instance.exports.wrapper;
  };

  Object.defineProperties(module, {
    HEAPU8: { configurable: true, get: () => heap(Uint8Array) },
    HEAPU32: { configurable: true, get: () => heap(Uint32Array) },
    HEAPF32: { configurable: true, get: () => heap(Float32Array) },
  });

  // The generated Dart bindings call stackAlloc for temporary UTF-8 values.
  // The C wrapper copies those values synchronously while creating a session,
  // so the module allocator is a safe fallback for bundles without an
  // exported Emscripten stack API.
  module.stackAlloc = (byteCount) => module._malloc(byteCount);
  module.stackSave = () => 0;
  module.stackRestore = () => {};

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

  // addFunction is a runtime helper in a normal Emscripten export. The
  // generated Wasm module still exports its function table, so retain the
  // same table-index contract for Dart callback pointers.
  module.addFunction = (fn, signature) => {
    // Table index zero is the C null function pointer and must never be used
    // for a callback, even if the corresponding table slot is empty.
    for (let index = 1; index < wasmTable.length; index++) {
      if (wasmTable.get(index) === null) {
        wasmTable.set(index, makeCallbackWrapper(fn, signature));
        return index;
      }
    }
    throw new RangeError(
      'The FFmpegKit Wasm function table has no free callback slots.',
    );
  };
  module.removeFunction = (index) => wasmTable.set(index, null);
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
          wasmTable = instance.exports.jj;
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
