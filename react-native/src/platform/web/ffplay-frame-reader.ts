import {getBackend} from '../backend-registry';
import type {FFplayFrameMetadata} from '../backend-registry';
import {isWasmModuleReady, requireWasmModule} from './wasm-loader';
import {currentFFplayPlaybackEpoch, currentFFplayPlaybackSessionId} from './ffplay-frame-state';

export interface WasmVideoFrame extends FFplayFrameMetadata {
  epoch: number;
  bytes: Uint8ClampedArray;
}

function sameFrame(left: FFplayFrameMetadata, right: FFplayFrameMetadata): boolean {
  return left.generation === right.generation &&
    left.width === right.width &&
    left.height === right.height &&
    left.linesize === right.linesize;
}

/** Copies a newly decoded RGBA frame out of Wasm-owned memory. */
export function readLatestFrame(
  previousFrame?: WasmVideoFrame,
): WasmVideoFrame | undefined {
  if (!isWasmModuleReady()) return undefined;
  const backend = getBackend();
  const playbackSessionId = currentFFplayPlaybackSessionId();
  if (playbackSessionId !== undefined) {
    let readiness: number;
    try {
      readiness = backend.ffplayGetVolume(playbackSessionId);
    } catch {
      return undefined;
    }
    if (readiness < 0) return undefined;
  }
  const metadata = backend.copyFrame(0, 0);
  if (metadata.width <= 0 || metadata.height <= 0 || metadata.linesize <= 0) {
    return undefined;
  }
  const epoch = currentFFplayPlaybackEpoch();
  if (previousFrame && previousFrame.epoch === epoch && sameFrame(metadata, previousFrame)) {
    return undefined;
  }

  const size = metadata.linesize * metadata.height;
  const module = requireWasmModule();
  const destination = module._malloc(size);
  try {
    const copied = backend.copyFrame(destination, size);
    if (!copied.copied || copied.width <= 0 || copied.height <= 0 || copied.linesize <= 0) {
      return undefined;
    }
    const copiedSize = copied.linesize * copied.height;
    if (copiedSize > size) return undefined;
    const bytes = Uint8ClampedArray.from(
      module.HEAPU8.subarray(
        destination,
        destination + copiedSize,
      ),
    );
    return {
      epoch,
      width: copied.width,
      height: copied.height,
      linesize: copied.linesize,
      generation: copied.generation,
      bytes,
    };
  } finally {
    module._free(destination);
  }
}
