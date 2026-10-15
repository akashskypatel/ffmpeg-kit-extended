// Phase 3 headless runner for the Web sync-request policy (plan §P3.0a):
// W-F01 (direct HTTP/HLS through sync APIs), W-F02 (local playlist with remote
// segments) and W-F03 (local/MEMFS input). Usage:
//   node scripts/wasm-web-policy.mjs --record <path.json>
// Requires the Flutter fixture build at flutter/example/build/web, built with
// --base-href=/policy/ -t ../test/fixtures/web_sync_policy/main.dart.

import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readdir, readFile, writeFile } from 'node:fs/promises';
import http from 'node:http';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(path.join(root, 'react-native/package.json'));
const { chromium } = require('playwright');
const builders = process.env.FFMPEG_KIT_BUILDERS_ROOT
  || '\\\\wsl.localhost\\ManyLinux\\home\\vscode\\ffmpeg-kit-builders';
const buildRoot = path.join(root, 'flutter/example/build/web');
const expected = {
  'ffmpegkit.wasm': '7544659af661f4e716c98e28bb5545c9a8da28aba88012f7fd4ed9969ec99e7e',
  'ffmpegkit.mjs': 'fd21f1a1296790b18f284afa49d878ab730ad3bdd7f7e62dfeef6260ef0ec83b',
};
const recordFlag = process.argv.indexOf('--record');
const recordPath = recordFlag < 0 ? undefined : process.argv[recordFlag + 1];
const mime = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json', '.css': 'text/css',
  '.otf': 'font/otf', '.ttf': 'font/ttf', '.png': 'image/png',
};

async function findFiles(directory, name) {
  const found = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) found.push(...await findFiles(full, name));
    else if (entry.name === name) found.push(full);
  }
  return found;
}

// Hash the staged runtime that the Web build actually serves. A mismatch stops
// the run before any browser case, so no result can use an unpinned runtime.
const staged = {};
for (const name of Object.keys(expected)) {
  const matches = await findFiles(buildRoot, name);
  assert.equal(matches.length, 1, `expected exactly one staged ${name}, found ${matches.length}`);
  const digest = createHash('sha256').update(await readFile(matches[0])).digest('hex');
  staged[name] = { path: path.relative(root, matches[0]), sha256: digest };
  assert.equal(digest, expected[name], `staged ${name} does not match the Phase 2 pin`);
}

const { createStreamingFixtureServer } = await import(
  pathToFileURL(path.join(builders, 'FFmpegKit/tests/wasm_streaming/server.mjs')).href
);
const fixture = createStreamingFixtureServer({
  port: 0,
  fixtureDir: path.join(builders, 'FFmpegKit/tests/wasm_streaming/fixtures/h264-aac'),
});
const fixtureOrigin = await fixture.listen();

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    if (!url.pathname.startsWith('/policy/')) {
      res.writeHead(404).end();
      return;
    }
    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
    const relative = decodeURIComponent(url.pathname.slice('/policy/'.length)) || 'index.html';
    const target = path.resolve(buildRoot, relative);
    if (!target.startsWith(`${buildRoot}${path.sep}`)) {
      res.writeHead(400).end();
      return;
    }
    res.setHeader('Content-Type', mime[path.extname(target)] || 'application/octet-stream');
    res.end(await readFile(target));
  } catch (error) {
    res.writeHead(error.code === 'ENOENT' ? 404 : 500).end(String(error));
  }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const origin = `http://127.0.0.1:${server.address().port}`;

const record = {
  contract: 'flutter-web-sync-policy',
  buildRoot: path.relative(root, buildRoot),
  staged,
  fixtureOrigin,
  startedAt: new Date().toISOString(),
  result: null,
  errors: [],
};
let browser;
try {
  browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  page.on('pageerror', error => record.errors.push(`pageerror: ${error.message}`));
  await page.goto(`${origin}/policy/?fixture=${encodeURIComponent(fixtureOrigin)}`);
  await page.waitForFunction(
    () => typeof globalThis.CODEX_phase3PolicyResult === 'string',
    null,
    { timeout: 300_000, polling: 500 },
  );
  record.result = JSON.parse(await page.evaluate(() => globalThis.CODEX_phase3PolicyResult));
  record.finishedAt = new Date().toISOString();
} catch (error) {
  record.errors.push(String(error));
} finally {
  await browser?.close();
  server.close();
  await fixture.close();
}

const cases = record.result?.cases ?? [];
record.passed = record.result?.status === 'passed' && record.errors.length === 0
  && cases.length > 0 && cases.every(item => item.status === 'passed');
if (recordPath) await writeFile(recordPath, `${JSON.stringify(record, null, 2)}\n`);
for (const item of cases) console.log(`${item.status.toUpperCase()} ${item.name}: ${item.detail.slice(0, 160)}`);
if (record.errors.length) console.log(`errors: ${record.errors.join(' | ').slice(0, 400)}`);
console.log(record.passed ? 'WEB-POLICY PASS' : 'WEB-POLICY NOT PASSED');
process.exitCode = record.passed ? 0 : 1;
