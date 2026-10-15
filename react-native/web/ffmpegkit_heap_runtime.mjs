const HEAP_VIEWS = [
  ['HEAPU8', Uint8Array],
  ['HEAPU32', Uint32Array],
  ['HEAPF32', Float32Array],
];

export function installHeapViews(module, wasmMemory) {
  if (!module || typeof module !== 'object') {
    throw new TypeError('The Emscripten module must be an object.');
  }
  if (!wasmMemory || !wasmMemory.buffer) {
    throw new TypeError('The WebAssembly memory must expose a buffer.');
  }

  for (const [name, View] of HEAP_VIEWS) {
    const descriptor = Object.getOwnPropertyDescriptor(module, name);
    if (
      descriptor &&
      'value' in descriptor &&
      descriptor.writable &&
      descriptor.value instanceof View &&
      descriptor.value.buffer === wasmMemory.buffer
    ) {
      // Emscripten owns and refreshes this writable data property on growth.
      continue;
    }

    if (descriptor && !descriptor.configurable) {
      throw new TypeError(
        `Cannot install ${name}: the existing Emscripten property is non-configurable and incompatible with the current WebAssembly memory.`,
      );
    }

    let view;
    Object.defineProperty(module, name, {
      configurable: true,
      enumerable: descriptor?.enumerable ?? true,
      get() {
        if (!view || view.buffer !== wasmMemory.buffer) {
          view = new View(wasmMemory.buffer);
        }
        return view;
      },
      set(value) {
        if (!(value instanceof View)) {
          throw new TypeError(`${name} must be assigned a ${View.name}.`);
        }
        if (value.buffer !== wasmMemory.buffer) {
          throw new TypeError(
            `${name} must be assigned a view of the current WebAssembly memory buffer.`,
          );
        }
        view = value;
      },
    });
  }
}
