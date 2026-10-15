/**
 * Fetches and compiles the Wasm artifact before the Emscripten module starts.
 * Keeping this operation outside instantiateWasm gives callers a normal
 * rejected promise for missing, invalid, or unavailable artifacts.
 */
export async function fetchAndCompileWasm(url, fetchImpl = globalThis.fetch) {
  if (typeof fetchImpl !== 'function') {
    throw new TypeError('A fetch implementation is required to load Wasm.');
  }

  const response = await fetchImpl(url, {credentials: 'same-origin'});
  if (!response.ok) {
    throw new Error(`Unable to load Wasm (${response.status}): ${response.url ?? url}`);
  }
  const bytes = await response.arrayBuffer();
  return WebAssembly.compile(bytes);
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
