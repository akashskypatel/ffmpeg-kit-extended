import createFFmpegKit from './ffmpegkit.mjs';
import {
  createModuleWithCompiledWasm,
  fetchAndCompileWasm,
} from './ffmpegkit_loader.mjs';

export async function createFFmpegKitModule() {
  const wasmMemory = new WebAssembly.Memory({initial: 1024, maximum: 32768, shared: true});
  const wasmModule = await fetchAndCompileWasm(new URL('ffmpegkit.wasm', import.meta.url));
  return createModuleWithCompiledWasm({
    createModule: createFFmpegKit,
    wasmModule,
    options: {
      wasmMemory,
      stdin: () => null,
      locateFile: file => new URL(file, import.meta.url).href,
    },
  });
}
