import {getBackend} from '../backend';
import {isWasmModuleReady, requireWasmModule} from './wasm-loader';

export interface WasmVideoFrame {
  width: number;
  height: number;
  linesize: number;
  generation: number;
  bytes: Uint8ClampedArray;
}

/** Copies one complete RGBA frame out of Wasm-owned memory. */
export function readLatestFrame(): WasmVideoFrame | undefined {
  if (!isWasmModuleReady()) return undefined;
  const backend = getBackend();
  const size = backend.getFrameBufferSize();
  if (size <= 0) return undefined;
  const module = requireWasmModule();
  const destination = module._malloc(size);
  try {
    const metadata = backend.copyFrame(destination, size);
    if (metadata.width <= 0 || metadata.height <= 0) return undefined;
    const bytes = module.HEAPU8.slice(
      destination,
      destination + metadata.linesize * metadata.height,
    );
    return {
      ...metadata,
      bytes: new Uint8ClampedArray(bytes),
    };
  } finally {
    module._free(destination);
  }
}
