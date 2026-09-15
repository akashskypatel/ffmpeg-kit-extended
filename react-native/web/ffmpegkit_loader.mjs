/** Compile the staged Wasm file before starting Emscripten. */
export async function fetchAndCompileWasm(url, fetchImpl = globalThis.fetch) {
  if (typeof fetchImpl !== 'function') throw new TypeError('A fetch implementation is required to load Wasm.');
  const response = await fetchImpl(url, {credentials: 'same-origin'});
  if (!response.ok) throw new Error(`Unable to load Wasm (${response.status}): ${response.url ?? url}`);
  return WebAssembly.compile(await response.arrayBuffer());
}
