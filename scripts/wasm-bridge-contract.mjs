import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, stat, writeFile } from 'node:fs/promises';
import http from 'node:http';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(path.join(root, 'react-native/package.json'));
const { chromium } = require('playwright');
const builders = process.env.FFMPEG_KIT_BUILDERS_ROOT
  || '\\\\wsl.localhost\\ManyLinux\\home\\vscode\\ffmpeg-kit-builders';
const expected = {
  'ffmpegkit.wasm': '7544659af661f4e716c98e28bb5545c9a8da28aba88012f7fd4ed9969ec99e7e',
  'ffmpegkit.mjs': 'fd21f1a1296790b18f284afa49d878ab730ad3bdd7f7e62dfeef6260ef0ec83b',
};
const directories = {
  flutter: path.join(root, 'flutter/example/web/assets/packages/ffmpeg_kit_extended_flutter/wasm'),
  rn: path.join(root, 'react-native/example/public/ffmpeg-kit-extended/wasm'),
};
const record = {
  zipSha256: 'fd51b8d749040529239fcf992c0f9f348ac07f3c102b4952e0133a42ab5d89fd',
  expected, staged: {}, cases: [], errors: [],
  supportModules: {},
  cleanSequence: process.env.CODEX_CLEAN_RECORD,
};
const full = process.argv.includes('--full');
const playback = process.argv.includes('--playback');
const rnAdapter = process.argv.includes('--rn-adapter');
const dartAdapter = process.argv.includes('--dart-adapter');
const callbackOrder = process.argv.includes('--callback-order');
const callbackLifetime = process.argv.includes('--callback-lifetime');
const debugMessageCounter = process.argv.includes('--debug-message-counter');
const heapFlag = process.argv.indexOf('--heap-diagnostic');
const diagnostic = heapFlag < 0 ? null : JSON.parse(await readFile(process.argv[heapFlag + 1], 'utf8'));
if (diagnostic) {
  assert.equal(diagnostic.artifactRole, 'same-source-diagnostic-heap-only');
  assert.equal(diagnostic.sourceCommit, '779cecd74bb7b10ab9f0d28c1e14e2a440eacd4a');
  assert.equal(diagnostic.productionWasmSha256, expected['ffmpegkit.wasm']);
  assert.equal(diagnostic.productionHashesUnchanged, true);
  assert.equal(diagnostic.hooks, 'ON');
  assert.ok(!full && !playback && !rnAdapter && !dartAdapter && !callbackOrder &&
    !callbackLifetime && !debugMessageCounter, 'Diagnostic heap evidence cannot replace production contracts');
  for (const name of Object.keys(expected)) {
    assert.match(diagnostic.hashes[name], /^[a-f0-9]{64}$/);
    const bytes = await readFile(path.join(diagnostic.directory, name));
    assert.equal(createHash('sha256').update(bytes).digest('hex'), diagnostic.hashes[name]);
  }
  record.artifactRole = 'diagnostic-heap-only';
  record.diagnostic = diagnostic;
}
const recordFlag = process.argv.indexOf('--record');
const recordPath = recordFlag < 0 ? undefined : process.argv[recordFlag + 1];
let fixture;
let browser;
let nativeBackendBundle;
async function evaluate(page, operation, argument) {
  let timeout;
  try {
    return await Promise.race([
      page.evaluate(operation, argument),
      new Promise((_, reject) => {
        timeout = setTimeout(() => reject(new Error('Bridge browser operation exceeded 180 seconds')), 180000);
      }),
    ]);
  } finally {
    clearTimeout(timeout);
  }
}
const mime = { '.mjs': 'text/javascript', '.js': 'text/javascript', '.wasm': 'application/wasm' };
const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    if (url.pathname !== '/unisolated') {
      res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
      res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
    }
    res.setHeader('Cache-Control', 'no-store');
    if (url.pathname === '/' || url.pathname === '/unisolated') {
      res.setHeader('Content-Type', 'text/html');
      res.end('<!doctype html><title>Wasm bridge contract</title>');
      return;
    }
    if (url.pathname === '/native-backend-contract.mjs' && nativeBackendBundle) {
      res.setHeader('Content-Type', 'text/javascript');
      res.end(nativeBackendBundle);
      return;
    }
    if (url.pathname === '/callback-order-contract.mjs') {
      res.setHeader('Content-Type', 'text/javascript');
      res.end(await readFile(path.join(root, 'scripts/fixtures/wasm-callback-order-contract.mjs')));
      return;
    }
    if (url.pathname === '/callback-lifetime-contract.mjs') {
      res.setHeader('Content-Type', 'text/javascript');
      res.end(await readFile(path.join(root, 'scripts/fixtures/wasm-callback-lifetime-contract.mjs')));
      return;
    }
    if (url.pathname === '/heap-baseline-contract.mjs') {
      res.setHeader('Content-Type', 'text/javascript');
      res.end(await readFile(path.join(root, 'scripts/fixtures/wasm-heap-baseline-contract.mjs')));
      return;
    }
    if (url.pathname.startsWith('/dart/')) {
      const buildRoot = path.join(root, 'flutter/example/build/web');
      const target = path.resolve(buildRoot, decodeURIComponent(url.pathname.slice('/dart/'.length)) || 'index.html');
      if (!target.startsWith(`${buildRoot}${path.sep}`)) throw new Error('Invalid Dart fixture path');
      res.setHeader('Content-Type', mime[path.extname(target)] || ({'.html': 'text/html', '.json': 'application/json'}[path.extname(target)]) || 'application/octet-stream');
      res.end(await readFile(target));
      return;
    }
    const match = /^\/(flutter|rn)\/([^/]+)$/.exec(url.pathname);
    const target = match
      ? path.join(diagnostic && Object.hasOwn(expected, match[2])
        ? diagnostic.directory : directories[match[1]], match[2])
      : ['/contract.mjs', '/playback-contract.mjs', '/wasm-bridge-playback.mjs'].includes(url.pathname)
        ? path.join(root, 'scripts/fixtures', url.pathname === '/contract.mjs'
          ? 'wasm-bridge-contract.mjs' : 'wasm-bridge-playback.mjs')
        : undefined;
    if (!target || !(await stat(target)).isFile()) {
      res.writeHead(404).end();
      return;
    }
    res.setHeader('Content-Type', mime[path.extname(target)] || 'application/octet-stream');
    res.end(await readFile(target));
  } catch (error) {
    res.writeHead(error.code === 'ENOENT' ? 404 : 500).end(String(error));
  }
});

try {
  if (rnAdapter) {
    const exampleRequire = createRequire(path.join(root, 'react-native/example/package.json'));
    nativeBackendBundle = exampleRequire('esbuild').buildSync({
      entryPoints: [path.join(root, 'scripts/fixtures/wasm-native-backend-contract.ts')],
      bundle: true, write: false, format: 'esm', platform: 'browser', target: 'es2022',
    }).outputFiles[0].contents;
  }
  for (const [framework, directory] of Object.entries(directories)) {
    record.staged[framework] = {};
    for (const [name, hash] of Object.entries(expected)) {
      const actual = createHash('sha256').update(await readFile(path.join(directory, name))).digest('hex');
      record.staged[framework][name] = actual;
      assert.equal(actual, hash, `${framework}/${name}`);
    }
    record.supportModules[framework] = {};
    for (const name of ['ffmpegkit_bridge.mjs', 'ffmpegkit_loader.mjs', 'ffmpegkit_callback_runtime.mjs', 'ffmpegkit_heap_runtime.mjs']) {
      const hash = createHash('sha256').update(await readFile(path.join(directory, name))).digest('hex');
      const source = path.join(root, framework === 'flutter' ? 'flutter/web' : 'react-native/web', name);
      assert.equal(hash, createHash('sha256').update(await readFile(source)).digest('hex'), `Staged ${framework}/${name} is stale`);
      record.supportModules[framework][name] = hash;
    }
  }
  if (full || playback || rnAdapter || dartAdapter || callbackOrder || debugMessageCounter || diagnostic) {
    const { createStreamingFixtureServer } = await import(pathToFileURL(path.join(builders, 'FFmpegKit/tests/wasm_streaming/server.mjs')));
    fixture = createStreamingFixtureServer({
      port: 0,
      fixtureDir: path.join(builders, 'FFmpegKit/tests/wasm_streaming/fixtures/h264-aac'),
    });
    record.fixtureOrigin = await fixture.listen();
  }
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const origin = `http://127.0.0.1:${server.address().port}`;
  browser = await chromium.launch({ headless: true, args: ['--autoplay-policy=no-user-gesture-required'] });
  for (const framework of Object.keys(directories)) {
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => {
      if (message.text().startsWith('CODEX_contract')) console.log(`${framework}: ${message.text()}`);
    });
    console.log(`CODEX_contract ${framework}: loading staged bridge`);
    await page.goto(origin);
    const result = await evaluate(page, async ({ framework, full, playback, rnAdapter, callbackOrder, callbackLifetime, debugMessageCounter, heapIdentity, fixtureOrigin }) => {
      const bridge = await import(`/${framework}/ffmpegkit_bridge.mjs`);
      const factory = framework === 'flutter' ? globalThis.ffmpegKitExtendedModuleFactory : bridge.createFFmpegKitModule;
      const module = await factory();
      module._ffmpeg_kit_initialize();
      const pointer = module._ffmpeg_kit_config_get_version();
      let end = pointer;
      while (module.HEAPU8[end]) end++;
      const version = new TextDecoder().decode(module.HEAPU8.slice(pointer, end));
      module._ffmpeg_kit_free(pointer);
      const required = ['_ffprobe_kit_session_execute_async', '_ffmpeg_kit_session_execute_async', '_ffplay_kit_session_execute_async', '_ffplay_kit_copy_frame', '_ffmpeg_kit_session_cancel'];
      for (const name of required) if (typeof module[name] !== 'function') throw new Error(`Missing export ${name}`);
      let contract;
      let playbackContract;
      let memoryContract;
      let heapContract;
      if (heapIdentity) {
        try {
          heapContract = await (await import('/heap-baseline-contract.mjs')).runHeapBaselineContract(module, fixtureOrigin, {...heapIdentity, runtimeVersion: version});
        } catch (error) {
          heapContract = error.report || {status: 'failed', error: error.message};
        }
      }
      let nativeBackendContract;
      let callbackOrderContract;
      let callbackLifetimeContract;
      let debugMessageCounterContract;
      if (debugMessageCounter) {
        try {
          debugMessageCounterContract = await (await import('/callback-order-contract.mjs')).runDebugMessageCounterContract(module, fixtureOrigin);
        } catch (error) {
          debugMessageCounterContract = error.report || {status: 'failed', error: error.message};
        }
      }
      if (callbackOrder) {
        try {
          callbackOrderContract = await (await import('/callback-order-contract.mjs')).runCallbackOrderContract(module, fixtureOrigin);
        } catch (error) {
          callbackOrderContract = error.report || {status: 'failed', error: error.message};
        }
      }
      if (callbackLifetime) {
        try {
          callbackLifetimeContract = await (await import('/callback-lifetime-contract.mjs')).runCallbackLifetimeContract(module);
        } catch (error) {
          callbackLifetimeContract = error.report || {status: 'failed', error: error.message};
        }
      }
      if (full) {
        try {
          contract = await (await import('/contract.mjs')).runBridgeContract(module, fixtureOrigin);
        } catch (error) {
          contract = error.report || { status: 'failed', error: error.message };
        }
      }
      if (rnAdapter && framework === 'rn') {
        try {
          nativeBackendContract = await (await import('/native-backend-contract.mjs')).runNativeBackendContract(module, fixtureOrigin);
        } catch (error) {
          nativeBackendContract = error.report || {status: 'failed', error: error.message};
        }
      }
      if (full) {
        try {
          memoryContract = await (await import('/contract.mjs')).runMemoryFileContract(module);
        } catch (error) {
          memoryContract = error.report || { status: 'failed', error: error.message };
        }
      }
      if (playback) {
        try {
          playbackContract = await (await import('/playback-contract.mjs')).runPlaybackContract(module, fixtureOrigin);
        } catch (error) {
          playbackContract = error.report || { status: 'failed', error: error.message };
        }
      }
      return { framework, version, protocol: bridge.BRIDGE_PROTOCOL_VERSION,
        required, isolated: crossOriginIsolated, contract, playbackContract, memoryContract, heapContract, nativeBackendContract, callbackOrderContract, callbackLifetimeContract, debugMessageCounterContract };
    }, { framework, full, playback, rnAdapter, callbackOrder, callbackLifetime, debugMessageCounter,
      heapIdentity: diagnostic ? {artifactRole: diagnostic.artifactRole, sourceCommit: diagnostic.sourceCommit,
        wasmSha256: diagnostic.hashes['ffmpegkit.wasm'], loaderSha256: diagnostic.hashes['ffmpegkit.mjs'],
        productionPinUsed: false} : null, fixtureOrigin: record.fixtureOrigin });
    assert.deepEqual(errors, [], `${framework} page errors`);
    assert.equal(result.protocol, 1, 'staged bridge protocol');
    record.cases.push({ ...result, pageErrors: errors });
    if (result.contract?.status === 'failed') record.errors.push(`${framework} streaming contract failed`);
    if (result.playbackContract?.status === 'failed') record.errors.push(`${framework} playback contract failed`);
    if (result.memoryContract?.status === 'failed') record.errors.push(`${framework} MEMFS contract failed`);
    if (result.nativeBackendContract?.status === 'failed') record.errors.push(`${framework} native backend contract failed`);
    if (result.callbackOrderContract?.status === 'failed') record.errors.push(`${framework} callback ordering contract failed`);
    if (result.callbackLifetimeContract?.status === 'failed') record.errors.push(`${framework} callback lifetime contract failed`);
    if (result.debugMessageCounterContract?.status === 'failed') record.errors.push(`${framework} debug message counter contract failed`);
    if (result.heapContract?.status === 'failed') record.errors.push(`${framework} native heap baseline contract failed`);
    await page.reload();
    const reloaded = await evaluate(page, async framework => {
      const bridge = await import(`/${framework}/ffmpegkit_bridge.mjs`);
      const factory = framework === 'flutter' ? globalThis.ffmpegKitExtendedModuleFactory : bridge.createFFmpegKitModule;
      const module = await factory();
      module._ffmpeg_kit_initialize();
      return { protocol: bridge.BRIDGE_PROTOCOL_VERSION,
        sharedMemory: module.HEAPU8.buffer instanceof SharedArrayBuffer };
    }, framework);
    assert.deepEqual(reloaded, {protocol: 1, sharedMemory: true});
    assert.deepEqual(errors, [], `${framework} page errors after reload`);
    record.cases.push({ framework, case: 'module-reload-after-contracts', ...reloaded });
    await page.close();

    const unisolated = await browser.newPage();
    await unisolated.goto(`${origin}/unisolated`);
    let wasmRequests = 0;
    unisolated.on('request', request => { if (request.url().endsWith('.wasm')) wasmRequests++; });
    const isolationError = await evaluate(unisolated, async framework => {
      const bridge = await import(`/${framework}/ffmpegkit_bridge.mjs`);
      const factory = framework === 'flutter' ? globalThis.ffmpegKitExtendedModuleFactory : bridge.createFFmpegKitModule;
      try { await factory(); return null; } catch (error) { return error.message; }
    }, framework);
    assert.match(isolationError, /crossOriginIsolated|isolation/i);
    assert.equal(wasmRequests, 0, 'isolation must fail before loading Wasm');
    record.cases.push({ framework, case: 'isolation', error: isolationError, wasmRequests });
    await unisolated.close();

    const retry = await browser.newPage();
    await retry.goto(origin);
    await retry.route('**/ffmpegkit.wasm', route => route.fulfill({ status: 404, body: 'missing fixture' }));
    const missingError = await evaluate(retry, async framework => {
      const bridge = await import(`/${framework}/ffmpegkit_bridge.mjs`);
      globalThis.contractFactory = framework === 'flutter' ? globalThis.ffmpegKitExtendedModuleFactory : bridge.createFFmpegKitModule;
      try { await globalThis.contractFactory(); return null; } catch (error) { return error.message; }
    }, framework);
    assert.match(missingError, /Unable to load Wasm \(404\)/);
    await retry.unroute('**/ffmpegkit.wasm');
    assert.equal(await evaluate(retry, async () => typeof (await globalThis.contractFactory())._ffmpeg_kit_initialize), 'function');
    record.cases.push({ framework, case: 'missing-wasm-retry', error: missingError, retry: 'passed' });
    await retry.close();

    const mismatch = await browser.newPage();
    await mismatch.goto(origin);
    await mismatch.route('**/ffmpegkit.wasm', route => route.fulfill({
      contentType: 'application/wasm', body: Buffer.from([0, 97, 115, 109, 1, 0, 0, 0]),
    }));
    const mismatchError = await evaluate(mismatch, async framework => {
      const bridge = await import(`/${framework}/ffmpegkit_bridge.mjs`);
      const factory = framework === 'flutter' ? globalThis.ffmpegKitExtendedModuleFactory : bridge.createFFmpegKitModule;
      try { await factory(); return null; } catch (error) { return error.message; }
    }, framework);
    assert.match(mismatchError, /WebAssembly.Table|export|Wasm/i);
    record.cases.push({ framework, case: 'mismatched-wasm', error: mismatchError });
    await mismatch.close();

    for (const missingName of ['ffmpegkit.mjs', 'ffmpegkit_heap_runtime.mjs']) {
      const missing = await browser.newPage();
      await missing.goto(origin);
      await missing.route(`**/${missingName}`, route => route.fulfill({ status: 404, body: 'missing fixture' }));
      const importError = await evaluate(missing, async framework => {
        try { await import(`/${framework}/ffmpegkit_bridge.mjs`); return null; }
        catch (error) { return error.message; }
      }, framework);
      assert.match(importError, /failed|fetch|import/i);
      await missing.unroute(`**/${missingName}`);
      await missing.reload();
      assert.equal(await evaluate(missing, async framework => {
        const bridge = await import(`/${framework}/ffmpegkit_bridge.mjs`);
        const factory = framework === 'flutter' ? globalThis.ffmpegKitExtendedModuleFactory : bridge.createFFmpegKitModule;
        return typeof (await factory())._ffmpeg_kit_initialize;
      }, framework), 'function');
      record.cases.push({ framework, case: `missing-${missingName}`, error: importError, reloadRetry: 'passed' });
      await missing.close();
    }
  }
  if (dartAdapter) {
    const page = await browser.newPage();
    const errors = [];
    const externalRequests = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.route('**/*', route => {
      const url = new URL(route.request().url());
      if (['http:', 'https:'].includes(url.protocol) && !['127.0.0.1', 'localhost'].includes(url.hostname)) {
        externalRequests.push(url.href);
        return route.abort();
      }
      return route.continue();
    });
    await page.goto(`${origin}/dart/?fixture=${encodeURIComponent(record.fixtureOrigin)}`);
    await page.waitForFunction(() => typeof globalThis.CODEX_flutterAdapterResult === 'string', null, {timeout: 90000});
    const result = JSON.parse(await evaluate(page, () => globalThis.CODEX_flutterAdapterResult));
    record.cases.push({framework: 'flutter-dart', ...result, pageErrors: errors, externalRequests});
    if (result.status !== 'passed' || errors.length || externalRequests.length) record.errors.push('Flutter Dart backend contract failed');
    await page.close();
  }
  if (record.errors.length) process.exitCode = 1;
} catch (error) {
  record.errors.push(error.stack || String(error));
  process.exitCode = 1;
} finally {
  await browser?.close();
  server.closeAllConnections();
  await new Promise(resolve => server.close(resolve));
  await fixture?.close();
  if (recordPath) await writeFile(recordPath, JSON.stringify(record, null, 2));
  console.log(JSON.stringify({ recordPath, errors: record.errors, cases: record.cases.map(item => ({
    framework: item.framework, case: item.case || 'native-contract',
    version: item.version, probe: item.contract?.status,
    playback: item.playbackContract?.status, memfs: item.memoryContract?.status,
    callbacks: item.callbackOrderContract?.status,
    callbackLifetime: item.callbackLifetimeContract?.status,
    debugMessageCounter: item.debugMessageCounterContract?.status,
    heap: item.heapContract?.status,
  })) }, null, 2));
}
