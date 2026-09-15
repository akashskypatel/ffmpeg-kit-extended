export interface WasmModule {
  HEAPU8: Uint8Array;
  HEAPU32: Uint32Array;
  _malloc(size: number): number;
  _free(pointer: number): void;
  UTF8ToString(pointer: number): string;
  stringToUTF8(value: string, pointer: number, maxBytes: number): void;
  lengthBytesUTF8(value: string): number;
  [name: string]: unknown;
}

export interface WasmInitializeOptions {
  assetBaseUrl?: string;
}

let moduleValue: WasmModule | undefined;
let initialization: Promise<WasmModule> | undefined;

function normalizedBaseUrl(value?: string): string {
  const base = value ?? '/ffmpeg-kit-extended/wasm/';
  return base.endsWith('/') ? base : `${base}/`;
}

function requireIsolation(): void {
  const isolated = (globalThis as typeof globalThis & {crossOriginIsolated?: boolean})
    .crossOriginIsolated;
  if (!isolated || typeof SharedArrayBuffer === 'undefined') {
    throw new Error(
      'FFmpegKit Web requires cross-origin isolation (COOP same-origin and COEP require-corp) and SharedArrayBuffer.',
    );
  }
}

export function requireWasmModule(): WasmModule {
  if (!moduleValue) {
    throw new Error(
      'FFmpegKitExtended.initialize() must be awaited before using the Web backend.',
    );
  }
  return moduleValue;
}

export function isWasmModuleReady(): boolean {
  return moduleValue !== undefined;
}

export function initializeWasm(options?: WasmInitializeOptions): Promise<void> {
  if (moduleValue) return Promise.resolve();
  initialization ??= loadWasm(normalizedBaseUrl(options?.assetBaseUrl));
  return initialization.then(() => undefined);
}

async function loadWasm(baseUrl: string): Promise<WasmModule> {
  requireIsolation();
  const pageUrl = (globalThis as typeof globalThis & {location?: Location}).location?.href;
  const bridgeUrl = new URL('ffmpegkit_bridge.mjs', new URL(baseUrl, pageUrl ?? 'http://localhost/'));
  await import(/* @vite-ignore */ bridgeUrl.href);
  const promise = (globalThis as typeof globalThis & {
    ffmpegKitExtendedModulePromise?: Promise<WasmModule>;
  }).ffmpegKitExtendedModulePromise;
  if (!promise) throw new Error(`Wasm bridge did not publish a module promise: ${bridgeUrl.href}`);
  const loaded = await promise;
  moduleValue = loaded;
  return loaded;
}

export function resetWasmLoaderForTests(): void {
  moduleValue = undefined;
  initialization = undefined;
}
