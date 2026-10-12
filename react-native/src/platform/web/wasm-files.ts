import {requireWasmModule, type WasmFileSystem} from './wasm-loader';

function validateFilePath(path: string): void {
  if (typeof path !== 'string' || !path.startsWith('/tmp/')) {
    throw new TypeError('Web file paths must be absolute files directly under /tmp/.');
  }

  const name = path.slice('/tmp/'.length);
  if (!name || name === '.' || name === '..' || name.includes('/') || /[\\\0]/.test(name)) {
    throw new TypeError('Web file paths must be absolute files directly under /tmp/.');
  }
}

function requireFs(): WasmFileSystem {
  const fs = requireWasmModule().FS;
  if (!fs) {
    throw new Error(
      'Local Wasm runtime lacks exported FS; rebuild with FS in EXPORTED_RUNTIME_METHODS.',
    );
  }
  const missing = ['writeFile', 'readFile', 'unlink', 'stat'].filter(
    (name) => typeof fs?.[name as keyof WasmFileSystem] !== 'function',
  );
  if (missing.length > 0) {
    throw new Error(
      `Local Wasm runtime lacks exported FS${fs ? ` methods: ${missing.join(', ')}` : ''}; ` +
        'rebuild with FS in EXPORTED_RUNTIME_METHODS.',
    );
  }
  return fs;
}

function isNotFoundError(error: unknown): boolean {
  if (typeof error !== 'object' || error === null) return false;
  const details = error as {code?: unknown; errno?: unknown; name?: unknown};
  return details.code === 'ENOENT' || (details.name === 'ErrnoError' && details.errno === 44);
}

function isRegularFile(mode: number): boolean {
  return (mode & 0xf000) === 0x8000;
}

/** Web-only access to files in the initialized FFmpegKit Wasm module's `/tmp/`. */
export const FFmpegKitWebFiles = {
  /** Writes a copy of the supplied binary bytes to an absolute `/tmp/` file path. */
  writeFile(path: string, bytes: Uint8Array): void {
    validateFilePath(path);
    if (!(bytes instanceof Uint8Array)) throw new TypeError('Web file contents must be a Uint8Array.');
    requireFs().writeFile(path, new Uint8Array(bytes));
  },

  /** Reads an independent byte copy from an absolute `/tmp/` file path. */
  readFile(path: string): Uint8Array {
    validateFilePath(path);
    return new Uint8Array(requireFs().readFile(path));
  },

  /** Deletes an absolute `/tmp/` file path and preserves Emscripten errors. */
  deleteFile(path: string): void {
    validateFilePath(path);
    requireFs().unlink(path);
  },

  /** Returns false only when the `/tmp/` file does not exist. */
  exists(path: string): boolean {
    validateFilePath(path);
    try {
      const stat = requireFs().stat(path);
      if (!isRegularFile(stat.mode)) {
        throw new TypeError('Web file paths must identify files directly under /tmp/.');
      }
      return true;
    } catch (error) {
      if (isNotFoundError(error)) return false;
      throw error;
    }
  },
};
