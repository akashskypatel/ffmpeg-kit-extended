'use strict';

/* global globalThis */

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const net = require('node:net');
const path = require('node:path');
const {chromium} = require('playwright');

const appRoot = path.resolve(__dirname, '..', 'example');
const url = 'http://127.0.0.1:4173/';

function waitForPort(port, host, timeoutMs = 30000) {
  const started = Date.now();
  return new Promise((resolve, reject) => {
    const probe = () => {
      const socket = net.createConnection({port, host});
      socket.once('connect', () => {
        socket.destroy();
        resolve();
      });
      socket.once('error', () => {
        socket.destroy();
        if (Date.now() - started >= timeoutMs) {
          reject(new Error(`Timed out waiting for ${host}:${port}`));
        } else {
          setTimeout(probe, 200);
        }
      });
    };
    probe();
  });
}

async function main() {
  const command = process.execPath;
  const viteEntry = path.join(appRoot, 'node_modules', 'vite', 'bin', 'vite.js');
  const server = childProcess.spawn(
    command,
    [viteEntry, '--host', '127.0.0.1', '--port', '4173', '--strictPort', '--config', 'web/vite.config.js'],
    {cwd: appRoot, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true},
  );
  let serverOutput = '';
  server.stdout.on('data', chunk => { serverOutput += chunk; });
  server.stderr.on('data', chunk => { serverOutput += chunk; });

  let browser;
  try {
    await waitForPort(4173, '127.0.0.1');
    browser = await chromium.launch({headless: true});
    const page = await browser.newPage();
    const errors = [];
    page.on('console', message => {
      if (message.type() === 'error') errors.push(`console: ${message.text()}`);
    });
    page.on('pageerror', error => errors.push(`page: ${error.message}`));

    await page.goto(url, {waitUntil: 'networkidle'});
    assert.equal(await page.evaluate(() => globalThis.crossOriginIsolated), true);
    assert.equal(await page.evaluate(() => typeof SharedArrayBuffer), 'function');

    process.stdout.write('browser: initialize\n');
    await page.getByRole('button', {name: 'Initialize'}).click();
    await page.getByTestId('status').waitFor({state: 'visible'});
    await page.waitForFunction(() => document.querySelector('[data-testid="status"]')?.textContent?.startsWith('Initialized'));
    const initialized = await page.getByTestId('status').textContent();
    assert.match(initialized || '', /^Initialized /);

    process.stdout.write('browser: repeated initialize\n');
    await page.getByRole('button', {name: 'Initialize'}).click();
    assert.match((await page.getByTestId('status').textContent()) || '', /^Initialized /);

    process.stdout.write('browser: ffmpeg\n');
    await page.getByRole('button', {name: 'Run FFmpeg'}).click();
    await page.waitForFunction(() => document.querySelector('[data-testid="status"]')?.textContent?.includes('FFmpeg state 2'));
    process.stdout.write('browser: ffprobe\n');
    await page.getByRole('button', {name: 'Run FFprobe'}).click();
    await page.waitForFunction(() => document.querySelector('[data-testid="status"]')?.textContent?.includes('FFprobe state 2'));
    process.stdout.write('browser: media info\n');
    await page.getByRole('button', {name: 'Run Media Info'}).click();
    await page.waitForFunction(() => document.querySelector('[data-testid="status"]')?.textContent?.startsWith('Media info streams '), {timeout: 30000});
    process.stdout.write('browser: ffplay\n');
    await page.getByRole('button', {name: 'Run FFplay'}).click();
    await page.waitForFunction(() => document.querySelector('[data-testid="status"]')?.textContent === 'Running FFplay');
    process.stdout.write('browser: ffplay pause\n');
    await page.getByRole('button', {name: 'Pause'}).click();
    process.stdout.write('browser: ffplay resume\n');
    await page.getByRole('button', {name: 'Resume'}).click();
    process.stdout.write('browser: ffplay stop\n');
    await page.getByRole('button', {name: 'Stop'}).click();
    await page.waitForFunction(() => document.querySelector('[data-testid="status"]')?.textContent?.includes('FFplay state 2'), {timeout: 30000});
    try {
      await page.waitForFunction(() => document.querySelector('[data-testid="status"]')?.textContent?.includes('FFplay state 2'), {timeout: 30000});
    } catch (error) {
      const diagnostics = await page.evaluate(() => ({
        status: document.querySelector('[data-testid="status"]')?.textContent,
        output: document.querySelector('[data-testid="output"]')?.textContent,
      }));
      throw new Error(`${error.message}; diagnostics=${JSON.stringify(diagnostics)}`);
    }

    const frame = await page.evaluate(() => {
      const canvas = document.querySelector('canvas');
      if (!canvas || canvas.width === 0 || canvas.height === 0) return null;
      const context = canvas.getContext('2d');
      if (!context) return null;
      const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
      return {
        width: canvas.width,
        height: canvas.height,
        hasPixels: [...pixels].some(value => value !== 0),
      };
    });
    assert.deepEqual(frame, {width: 160, height: 90, hasPixels: true});

    assert.deepEqual(errors, []);
    process.stdout.write('Headless WebAssembly smoke test passed.\n');
  } finally {
    await browser?.close();
    if (!server.killed) server.kill('SIGTERM');
    if (serverOutput && process.env.DEBUG_WEB_SMOKE) process.stderr.write(serverOutput);
  }
}

main().catch(error => {
  console.error(error.message || String(error));
  process.exitCode = 1;
});
