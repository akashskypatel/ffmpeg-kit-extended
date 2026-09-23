/** Compile the staged Wasm file before starting Emscripten. */
export async function fetchAndCompileWasm(url, fetchImpl = globalThis.fetch) {
  if (typeof fetchImpl !== "function")
    throw new TypeError("A fetch implementation is required to load Wasm.");
  const response = await fetchImpl(url, { credentials: "same-origin" });
  if (!response.ok)
    throw new Error(
      `Unable to load Wasm (${response.status}): ${response.url ?? url}`
    );
  return WebAssembly.compile(await response.arrayBuffer());
}

/** Connects asynchronous Wasm instantiation failures to the module promise. */
export function createModuleWithCompiledWasm({
  createModule,
  wasmModule,
  options = {},
  onInstance,
  instantiate = WebAssembly.instantiate,
}) {
  let rejectInstantiation;
  const instantiationFailure = new Promise((_, reject) => {
    rejectInstantiation = reject;
  });

  const modulePromise = Promise.resolve().then(() =>
    createModule({
      ...options,
      instantiateWasm: (imports, receiveInstance) => {
        Promise.resolve(instantiate(wasmModule, imports)).then(
          (instance) => {
            try {
              onInstance?.(instance, wasmModule);
              receiveInstance(instance, wasmModule);
            } catch (error) {
              rejectInstantiation(error);
            }
          },
          (error) => rejectInstantiation(error)
        );
        return {};
      },
    })
  );

  return Promise.race([modulePromise, instantiationFailure]);
}
