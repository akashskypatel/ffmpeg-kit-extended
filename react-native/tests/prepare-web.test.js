'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const {CONFIG_FILE_NAME} = require('../scripts/resolve-ffmpeg-kit-config.js');
const {main} = require('../scripts/prepare-web.js');

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
