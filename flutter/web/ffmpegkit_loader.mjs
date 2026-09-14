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
