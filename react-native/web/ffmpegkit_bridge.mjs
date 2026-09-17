import createFFmpegKit from './ffmpegkit.mjs';
import {fetchAndCompileWasm} from './ffmpegkit_loader.mjs';

export async function createFFmpegKitModule() {
  const wasmMemory = new WebAssembly.Memory({initial: 1024, maximum: 32768, shared: true});
  const wasmModule = await fetchAndCompileWasm(new URL('ffmpegkit.wasm', import.meta.url));
  return createFFmpegKit({
    wasmMemory,
    stdin: () => null,
    locateFile: file => new URL(file, import.meta.url).href,
    instantiateWasm: (imports, receiveInstance) => {
      WebAssembly.instantiate(wasmModule, imports).then(instance => {
        receiveInstance(instance, wasmModule);
      });
      return {};
    },
  });
}
