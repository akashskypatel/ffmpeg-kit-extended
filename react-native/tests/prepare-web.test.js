'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const {CONFIG_FILE_NAME, resolveConfig} = require('../scripts/resolve-ffmpeg-kit-config.js');
const {artifactCachePath, main} = require('../scripts/prepare-web.js');

test('prepare-web stages the runtime and bridge assets from a local directory', async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-web-prepare-'));
  const runtime = path.join(root, 'runtime');
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
    ]) {
      assert.equal(fs.existsSync(path.join(target, name)), true, name);
    }
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
    const first = resolveConfig({appRoot: firstRoot, platform: 'web'});
    const second = resolveConfig({appRoot: secondRoot, platform: 'web'});

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
