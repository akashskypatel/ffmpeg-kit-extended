async function fetchWasmBytes(url, fetchImpl) {
  if (typeof fetchImpl !== 'function') {
    throw new TypeError('A fetch implementation is required to load Wasm.');
  }

  const response = await fetchImpl(url, {credentials: 'same-origin'});
  if (!response.ok) {
    throw new Error(`Unable to load Wasm (${response.status}): ${response.url ?? url}`);
  }
  return response.arrayBuffer();
}

/**
 * Fetches and compiles the Wasm artifact before the Emscripten module starts.
 * Keeping this operation outside instantiateWasm gives callers a normal
 * rejected promise for missing, invalid, or unavailable artifacts.
 */
export async function fetchAndCompileWasm(url, fetchImpl = globalThis.fetch) {
  return WebAssembly.compile(await fetchWasmBytes(url, fetchImpl));
}

/**
 * Fetches and compiles the Wasm artifact and returns the limits of its single
 * imported shared memory, so callers can create a matching WebAssembly.Memory.
 */
export async function fetchAndCompileWasmWithMemory(url, fetchImpl = globalThis.fetch) {
  const bytes = await fetchWasmBytes(url, fetchImpl);
  const memoryLimits = readImportedMemoryLimits(bytes);
  return { wasmModule: await WebAssembly.compile(bytes), memoryLimits };
}

/**
 * Reads the limits of the single imported shared memory from a Wasm binary.
 * WebAssembly.Module.imports() does not expose limits, so parse the import
 * section directly.
 */
export function readImportedMemoryLimits(bytes) {
  const data = new Uint8Array(bytes);
  let offset = 8;
  const fail = (reason) => {
    throw new Error(`Unsupported FFmpegKit Wasm memory import: ${reason}.`);
  };
  const byte = () => {
    if (offset >= data.length) fail('truncated binary');
    return data[offset++];
  };
  const u32 = () => {
    let result = 0;
    for (let shift = 0; shift < 35; shift += 7) {
      const value = byte();
      result += (value & 0x7f) * 2 ** shift;
      if ((value & 0x80) === 0) return result;
    }
    return fail('invalid LEB128 value');
  };
  const skipName = () => {
    const length = u32();
    if (offset + length > data.length) fail('truncated binary');
    offset += length;
  };
  const limits = () => {
    const flags = byte();
    const initial = u32();
    const maximum = flags & 0x01 ? u32() : undefined;
    return { flags, initial, maximum };
  };

  if (data.length < 8 || data[0] !== 0x00 || data[1] !== 0x61 ||
      data[2] !== 0x73 || data[3] !== 0x6d) {
    fail('not a Wasm binary');
  }
  while (offset < data.length) {
    const id = byte();
    const size = u32();
    const end = offset + size;
    if (end > data.length) fail('truncated binary');
    if (id !== 2) {
      offset = end;
      continue;
    }
    const memories = [];
    for (let count = u32(); count > 0; count--) {
      skipName();
      skipName();
      const kind = byte();
      if (kind === 0x00) u32();
      else if (kind === 0x01) { byte(); limits(); }
      else if (kind === 0x02) memories.push(limits());
      else if (kind === 0x03) { byte(); byte(); }
      else if (kind === 0x04) { byte(); u32(); }
      else fail(`unknown import kind ${kind}`);
    }
    if (memories.length !== 1) fail(`expected one memory import, found ${memories.length}`);
    const [memory] = memories;
    if (memory.flags & 0x04) fail('memory64 is not supported');
    if ((memory.flags & 0x02) === 0) fail('memory is not shared');
    if (memory.maximum === undefined) fail('shared memory has no maximum');
    return { initial: memory.initial, maximum: memory.maximum, shared: true };
  }
  return fail('expected one memory import, found 0');
}

export function createInstantiateWasm(
  wasmModule,
  instantiate = WebAssembly.instantiate,
) {
  let started = false;
  let settled = false;
  let rejectFailure;
  let resolveCompletion;
  let rejectCompletion;
  const failure = new Promise((_, reject) => {
    rejectFailure = reject;
  });
  failure.catch(() => {});
  const completion = new Promise((resolve, reject) => {
    resolveCompletion = resolve;
    rejectCompletion = reject;
  });
  completion.catch(() => {});

  const reject = (error) => {
    if (settled) return;
    settled = true;
    rejectFailure(error);
    rejectCompletion(error);
  };

  const instantiateWasm = (imports, receiveInstance) => {
    if (started || settled) return {};
    started = true;
    let attempt;
    try {
      attempt = instantiate(wasmModule, imports);
    } catch (error) {
      reject(error);
      return {};
    }
    Promise.resolve(attempt).then(
      (result) => {
        if (settled) return;
        try {
          const instance = result instanceof WebAssembly.Instance
            ? result
            : result?.instance ?? result;
          const module = result instanceof WebAssembly.Instance
            ? wasmModule
            : result?.module ?? wasmModule;
          receiveInstance(instance, module);
          settled = true;
          resolveCompletion(instance);
        } catch (error) {
          reject(error);
        }
      },
      reject,
    );
    return {};
  };

  return {
    completion,
    failure,
    instantiateWasm,
    cancel() {
      settled = true;
    },
  };
}

export async function raceWasmModuleAttempt(factory, instantiator) {
  try {
    return await Promise.race([factory(), instantiator.failure]);
  } finally {
    instantiator.cancel();
  }
}

/** Adapts the shared instantiation lifecycle to the React Native module factory. */
export function createModuleWithCompiledWasm({
  createModule,
  wasmModule,
  options = {},
  onInstance,
  instantiate = WebAssembly.instantiate,
}) {
  const instantiator = createInstantiateWasm(wasmModule, instantiate);
  return raceWasmModuleAttempt(
    () => createModule({
      ...options,
      instantiateWasm(imports, receiveInstance) {
        instantiator.instantiateWasm(imports, (instance, module) => {
          onInstance?.(instance, module);
          receiveInstance(instance, module);
        });
        return {};
      },
    }),
    instantiator,
  );
}
