'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const {pathToFileURL} = require('node:url');
const {CONFIG_FILE_NAME, resolveConfig} = require('../scripts/resolve-ffmpeg-kit-config.js');
const {artifactCachePath, main} = require('../scripts/prepare-web.js');

test('prepare-web stages a single nested runtime pair from a local directory', async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-web-prepare-'));
  const runtime = path.join(root, 'runtime', 'nested');
  try {
    fs.mkdirSync(runtime, {recursive: true});
    fs.writeFileSync(path.join(runtime, 'ffmpegkit.mjs'), 'export default {};');
    fs.writeFileSync(path.join(runtime, 'ffmpegkit.wasm'), 'wasm');
    fs.writeFileSync(
      path.join(root, CONFIG_FILE_NAME),
      JSON.stringify({web: './runtime'}),
    );

    await main(['--app-root', root, '--quiet', 'true']);
    const target = path.join(root, 'public', 'ffmpeg-kit-extended', 'wasm');
    for (const name of [
      'ffmpegkit.mjs',
      'ffmpegkit.wasm',
      'ffmpegkit_bridge.mjs',
      'ffmpegkit_loader.mjs',
      'ffmpegkit_callback_runtime.mjs',
      'ffmpegkit_heap_runtime.mjs',
    ]) {
      assert.equal(fs.existsSync(path.join(target, name)), true, name);
    }
    const webRoot = path.resolve(__dirname, '..', 'web');
    for (const name of [
      'ffmpegkit_bridge.mjs',
      'ffmpegkit_loader.mjs',
      'ffmpegkit_callback_runtime.mjs',
      'ffmpegkit_heap_runtime.mjs',
    ]) {
      assert.deepEqual(
        fs.readFileSync(path.join(target, name)),
        fs.readFileSync(path.join(webRoot, name)),
        `${name} must match its source module`,
      );
      const source = fs.readFileSync(path.join(target, name), 'utf8');
      for (const [, relativeImport] of source.matchAll(/(?:from\s*|import\s*)['"](\.\/[^'"]+)['"]/g)) {
        assert.equal(
          fs.existsSync(path.resolve(target, relativeImport)),
          true,
          `${name} imports missing staged module ${relativeImport}`,
        );
      }
    }
  } finally {
    fs.rmSync(root, {recursive: true, force: true});
  }
});

test('a staged Web module fails to import when one of its local imports is absent', async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-web-missing-import-'));
  try {
    const modulePath = path.join(root, 'bridge.mjs');
    fs.writeFileSync(modulePath, "import './ffmpegkit_heap_runtime.mjs';\n");
    await assert.rejects(
      import(pathToFileURL(modulePath).href),
      /ERR_MODULE_NOT_FOUND|Cannot find module/,
    );
  } finally {
    fs.rmSync(root, {recursive: true, force: true});
  }
});

test('prepare-web rejects a runtime split across directories', async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-web-prepare-'));
  const runtime = path.join(root, 'runtime');
  try {
    fs.mkdirSync(path.join(runtime, 'js'), {recursive: true});
    fs.mkdirSync(path.join(runtime, 'wasm'), {recursive: true});
    fs.writeFileSync(path.join(runtime, 'js', 'ffmpegkit.mjs'), 'export default {};');
    fs.writeFileSync(path.join(runtime, 'wasm', 'ffmpegkit.wasm'), 'wasm');
    fs.writeFileSync(path.join(root, CONFIG_FILE_NAME), JSON.stringify({web: './runtime'}));

    await assert.rejects(
      () => main(['--app-root', root, '--quiet', 'true']),
      /must contain exactly one runtime directory containing ffmpegkit\.mjs and ffmpegkit\.wasm/,
    );
  } finally {
    fs.rmSync(root, {recursive: true, force: true});
  }
});

test('prepare-web rejects multiple complete runtime directories as ambiguous', async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-web-prepare-'));
  const runtime = path.join(root, 'runtime');
  try {
    for (const name of ['first', 'second']) {
      const directory = path.join(runtime, name);
      fs.mkdirSync(directory, {recursive: true});
      fs.writeFileSync(path.join(directory, 'ffmpegkit.mjs'), 'export default {};');
      fs.writeFileSync(path.join(directory, 'ffmpegkit.wasm'), 'wasm');
    }
    fs.writeFileSync(path.join(root, CONFIG_FILE_NAME), JSON.stringify({web: './runtime'}));

    await assert.rejects(
      () => main(['--app-root', root, '--quiet', 'true']),
      /found 2 runtime directories/,
    );
  } finally {
    fs.rmSync(root, {recursive: true, force: true});
  }
});

test('prepare-web cache paths distinguish remote URLs with the same filename', () => {
  const cacheDir = path.join(os.tmpdir(), 'ffmpeg-kit-web-cache');
  const firstRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-web-config-'));
  const secondRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-web-config-'));
  try {
    fs.writeFileSync(
      path.join(firstRoot, CONFIG_FILE_NAME),
      JSON.stringify({web: 'https://example.com/one/build.zip'}),
    );
    fs.writeFileSync(
      path.join(secondRoot, CONFIG_FILE_NAME),
      JSON.stringify({web: 'https://example.com/two/build.zip'}),
    );
    // URL identity is independent of the caller's local-only staging policy.
    const first = resolveConfig({appRoot: firstRoot, platform: 'web', localOnly: false});
    const second = resolveConfig({appRoot: secondRoot, platform: 'web', localOnly: false});

    assert.equal(first.filename, second.filename);
    assert.notEqual(first.cacheKey, second.cacheKey);
    assert.notEqual(artifactCachePath(cacheDir, first), artifactCachePath(cacheDir, second));
    assert.match(artifactCachePath(cacheDir, first), new RegExp(`${first.cacheKey}-build\\.zip$`));
    assert.match(artifactCachePath(cacheDir, second), new RegExp(`${second.cacheKey}-build\\.zip$`));
  } finally {
    fs.rmSync(firstRoot, {recursive: true, force: true});
    fs.rmSync(secondRoot, {recursive: true, force: true});
  }
});
