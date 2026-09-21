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

export function createInstantiateWasm(wasmModule) {
  let started = false;
  let settled = false;
  let rejectFailure;
  let resolveCompletion;
  let rejectCompletion;
  const failure = new Promise((_, reject) => {
    rejectFailure = reject;
  });
  const completion = new Promise((resolve, reject) => {
    resolveCompletion = resolve;
    rejectCompletion = reject;
  });
  completion.catch(() => {});

  const instantiateWasm = (imports, receiveInstance) => {
    if (started || settled) return {};
    started = true;
    WebAssembly.instantiate(wasmModule, imports).then(
      (result) => {
        if (settled) return;
        settled = true;
        try {
          const instance = result instanceof WebAssembly.Instance
            ? result
            : result.instance;
          const module = result instanceof WebAssembly.Instance
            ? wasmModule
            : result.module;
          receiveInstance(instance, module);
          resolveCompletion(instance);
        } catch (error) {
          rejectFailure(error);
          rejectCompletion(error);
        }
      },
      (error) => {
        if (settled) return;
        settled = true;
        rejectFailure(error);
        rejectCompletion(error);
      },
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
