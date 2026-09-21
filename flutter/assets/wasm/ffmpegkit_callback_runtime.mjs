function encodeU32(value) {
  const bytes = [];
  do {
    let byte = value & 0x7f;
    value >>>= 7;
    if (value !== 0) byte |= 0x80;
    bytes.push(byte);
  } while (value !== 0);
  return bytes;
}

function encodeString(value) {
  const bytes = Array.from(new TextEncoder().encode(value));
  return [...encodeU32(bytes.length), ...bytes];
}

function wasmType(type) {
  switch (type) {
    case 'p':
    case 'i': return 0x7f;
    case 'j': return 0x7e;
    case 'f': return 0x7d;
    case 'd': return 0x7c;
    default: throw new TypeError(`Unsupported callback type: ${type}`);
  }
}

export function makeCallbackWrapper(fn, signature) {
  if (typeof fn !== 'function') {
    throw new TypeError('Callback must be a function.');
  }
  if (typeof signature !== 'string' || !/^[vifdjp]+$/.test(signature)) {
    throw new TypeError(`Unsupported callback signature: ${signature}`);
  }

  const parameterTypes = Array.from(signature.slice(1), wasmType);
  const resultType = signature[0] === 'v' ? [] : [wasmType(signature[0])];
  const functionType = [
    0x60,
    ...encodeU32(parameterTypes.length),
    ...parameterTypes,
    ...encodeU32(resultType.length),
    ...resultType,
  ];
  const body = [
    0x00,
    ...parameterTypes.map((_, index) => [0x20, ...encodeU32(index)]).flat(),
    0x10, 0x00,
    0x0b,
  ];
  const importSection = [
    0x01,
    ...encodeString('env'),
    ...encodeString('callback'),
    0x00, 0x00,
  ];
  const functionSection = [0x01, 0x00];
  const exportName = encodeString('wrapper');
  const exportSection = [
    0x01,
    ...exportName,
    0x00, 0x01,
  ];
  const codeBody = [...encodeU32(body.length), ...body];
  const codeSection = [0x01, ...codeBody];
  const section = (id, payload) => [id, ...encodeU32(payload.length), ...payload];
  const binary = new Uint8Array([
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    ...section(1, [0x01, ...functionType]),
    ...section(2, importSection),
    ...section(3, functionSection),
    ...section(7, exportSection),
    ...section(10, codeSection),
  ]);
  const instance = new WebAssembly.Instance(
    new WebAssembly.Module(binary),
    {env: {callback: fn}},
  );
  return instance.exports.wrapper;
}

export function discoverWasmTable(exports) {
  const tables = Object.values(exports).filter(
    (value) => value instanceof WebAssembly.Table,
  );
  if (tables.length !== 1) {
    throw new Error(`Expected exactly one exported WebAssembly.Table, found ${tables.length}.`);
  }
  return tables[0];
}

export function createCallbackRegistry(table) {
  if (!(table instanceof WebAssembly.Table)) {
    throw new TypeError('Callback registry requires a WebAssembly.Table.');
  }

  const freeSlots = [];
  const owners = new Map();

  const allocateSlot = () => {
    while (freeSlots.length > 0) {
      const index = freeSlots.pop();
      if (table.get(index) === null) return index;
    }
    for (let index = 1; index < table.length; index += 1) {
      if (table.get(index) === null) return index;
    }
    const index = table.length;
    table.grow(1);
    return index;
  };

  const addFunction = (fn, signature) => {
    const wrapper = makeCallbackWrapper(fn, signature);
    const index = allocateSlot();
    try {
      table.set(index, wrapper);
    } catch (error) {
      throw new Error(`Unable to register callback in Wasm table slot ${index}: ${error}`);
    }
    owners.set(index, {fn, signature, wrapper});
    return index;
  };

  const removeFunction = (index) => {
    if (!Number.isInteger(index) || index <= 0) {
      throw new RangeError(`Invalid callback table index: ${index}`);
    }
    const owner = owners.get(index);
    if (!owner) {
      throw new Error(`Callback table slot ${index} is not owned by this registry.`);
    }
    if (table.get(index) !== owner.wrapper) {
      throw new Error(`Callback table slot ${index} no longer contains its registered function.`);
    }
    table.set(index, null);
    owners.delete(index);
    freeSlots.push(index);
  };

  return {
    addFunction,
    removeFunction,
    get ownedCount() { return owners.size; },
    get freeSlotCount() { return freeSlots.length; },
  };
}
