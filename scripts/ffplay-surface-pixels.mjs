import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {inflateSync} from 'node:zlib';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const CONTRACT_PATH = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  'ffplay-frame-pixel-contract.json',
);

function readContract() {
  return JSON.parse(readFileSync(CONTRACT_PATH, 'utf8'));
}

function paeth(a, b, c) {
  const estimate = a + b - c;
  const pa = Math.abs(estimate - a);
  const pb = Math.abs(estimate - b);
  const pc = Math.abs(estimate - c);
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

function unfilterPngRows(data, width, height, bytesPerPixel) {
  const rowLength = width * bytesPerPixel;
  const pixels = new Uint8Array(width * height * bytesPerPixel);
  let sourceOffset = 0;
  for (let y = 0; y < height; y += 1) {
    const filter = data[sourceOffset++];
    const rowOffset = y * rowLength;
    for (let x = 0; x < rowLength; x += 1) {
      const raw = data[sourceOffset++];
      const left = x >= bytesPerPixel ? pixels[rowOffset + x - bytesPerPixel] : 0;
      const above = y > 0 ? pixels[rowOffset - rowLength + x] : 0;
      const upperLeft =
        y > 0 && x >= bytesPerPixel
          ? pixels[rowOffset - rowLength + x - bytesPerPixel]
          : 0;
      let value;
      switch (filter) {
        case 0:
          value = raw;
          break;
        case 1:
          value = raw + left;
          break;
        case 2:
          value = raw + above;
          break;
        case 3:
          value = raw + Math.floor((left + above) / 2);
          break;
        case 4:
          value = raw + paeth(left, above, upperLeft);
          break;
        default:
          throw new Error(`Unsupported PNG filter ${filter} at row ${y}`);
      }
      pixels[rowOffset + x] = value & 0xff;
    }
  }
  return pixels;
}

export function readPngRgba(imagePath) {
  const input = readFileSync(imagePath);
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  assert.deepEqual(input.subarray(0, 8), signature, `${imagePath} is not a PNG`);

  let offset = 8;
  let width;
  let height;
  let bitDepth;
  let colorType;
  let interlace;
  const idat = [];
  while (offset < input.length) {
    const length = input.readUInt32BE(offset);
    const type = input.toString('ascii', offset + 4, offset + 8);
    const body = input.subarray(offset + 8, offset + 8 + length);
    offset += 12 + length;
    if (type === 'IHDR') {
      width = body.readUInt32BE(0);
      height = body.readUInt32BE(4);
      bitDepth = body[8];
      colorType = body[9];
      interlace = body[12];
    } else if (type === 'IDAT') {
      idat.push(body);
    } else if (type === 'IEND') {
      break;
    }
  }

  assert.equal(bitDepth, 8, 'Only 8-bit PNG screenshots are supported');
  assert.equal(interlace, 0, 'Interlaced PNG screenshots are unsupported');
  assert.ok(colorType === 2 || colorType === 6, `Unsupported PNG color type ${colorType}`);
  const sourceChannels = colorType === 6 ? 4 : 3;
  const filtered = inflateSync(Buffer.concat(idat));
  const source = unfilterPngRows(filtered, width, height, sourceChannels);
  const rgba = new Uint8Array(width * height * 4);
  for (let i = 0, j = 0; i < source.length; i += sourceChannels, j += 4) {
    rgba[j] = source[i];
    rgba[j + 1] = source[i + 1];
    rgba[j + 2] = source[i + 2];
    rgba[j + 3] = sourceChannels === 4 ? source[i + 3] : 255;
  }
  return {width, height, pixels: rgba};
}

function samplePixel(frame, x, y) {
  assert.ok(x >= 0 && x < frame.width, `sample x=${x} is outside ${frame.width}`);
  assert.ok(y >= 0 && y < frame.height, `sample y=${y} is outside ${frame.height}`);
  const offset = (y * frame.width + x) * 4;
  return Array.from(frame.pixels.subarray(offset, offset + 4));
}

function normalizedRect(frame, rect) {
  const result = rect ?? {x: 0, y: 0, width: frame.width, height: frame.height};
  assert.ok(result.width > 0 && result.height > 0, 'surface rectangle must be positive');
  assert.ok(result.x >= 0 && result.y >= 0, 'surface rectangle must be non-negative');
  assert.ok(result.x + result.width <= frame.width, 'surface rectangle exceeds screenshot width');
  assert.ok(result.y + result.height <= frame.height, 'surface rectangle exceeds screenshot height');
  return result;
}

export function evaluateFrameSamples({width, height, samples}, contract = readContract()) {
  assert.equal(width, contract.width, `expected frame width ${contract.width}, got ${width}`);
  assert.equal(height, contract.height, `expected frame height ${contract.height}, got ${height}`);
  const results = samples.map((actual, index) => {
    const expected = contract.samples[index];
    const tolerance = expected.tolerance ?? 0;
    const deltas = actual.rgba.map((value, channel) =>
      Math.abs(value - expected.rgba[channel]),
    );
    return {
      name: expected.name,
      expected: expected.rgba,
      actual: actual.rgba,
      deltas,
      tolerance,
      matches: deltas.every(delta => delta <= tolerance),
    };
  });
  assert.equal(results.length, contract.samples.length, 'sample count mismatch');
  assert.ok(
    results.every(result => result.matches),
    `FFplay frame pixel mismatch: ${JSON.stringify(results)}`,
  );
  return results;
}

export function assertFramePixels({imagePath, rect, label = 'FFplay surface'}, contract = readContract()) {
  const frame = readPngRgba(imagePath);
  const surface = normalizedRect(frame, rect);
  const samples = contract.samples.map(expected => {
    const x = surface.x + Math.min(
      surface.width - 1,
      Math.round((expected.x / contract.width) * surface.width),
    );
    const y = surface.y + Math.min(
      surface.height - 1,
      Math.round((expected.y / contract.height) * surface.height),
    );
    return {name: expected.name, rgba: samplePixel(frame, x, y)};
  });
  const results = evaluateFrameSamples(
    {width: contract.width, height: contract.height, samples},
    contract,
  );
  return {label, screenshot: imagePath, surface, results};
}

export function assertCanvasFramePixels({width, height, rgba, label = 'FFplay canvas'}, contract = readContract()) {
  const samples = contract.samples.map(expected => {
    const x = Math.min(width - 1, Math.round((expected.x / contract.width) * width));
    const y = Math.min(height - 1, Math.round((expected.y / contract.height) * height));
    const offset = (y * width + x) * 4;
    return {name: expected.name, rgba: Array.from(rgba.slice(offset, offset + 4))};
  });
  const results = evaluateFrameSamples({width: contract.width, height: contract.height, samples}, contract);
  return {label, width, height, results};
}

export {readContract};

function parseRect(value) {
  if (!value) return undefined;
  const [x, y, width, height] = value.split(',').map(Number);
  assert.ok([x, y, width, height].every(Number.isFinite), `invalid --rect ${value}`);
  return {x, y, width, height};
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const imageIndex = process.argv.indexOf('--image');
  assert.ok(imageIndex >= 0 && process.argv[imageIndex + 1], 'usage: --image <png> [--rect x,y,w,h]');
  const rectIndex = process.argv.indexOf('--rect');
  const result = assertFramePixels({
    imagePath: process.argv[imageIndex + 1],
    rect: rectIndex >= 0 ? parseRect(process.argv[rectIndex + 1]) : undefined,
  });
  console.log(JSON.stringify(result));
}
