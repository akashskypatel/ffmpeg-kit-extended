'use strict';

/* global globalThis */

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const net = require('node:net');
const path = require('node:path');
const {chromium} = require('playwright');
const {main: prepareWeb} = require('./prepare-web.js');

const appRoot = path.resolve(__dirname, '..', 'example');
const url = 'http://127.0.0.1:4173/';
const SMOKE_TIMEOUT_MS = 120000;
const taskTag = process.env.FFMPEG_KIT_TASK_TAG || 'ffmpeg-kit-rn-web-smoke';
const screenshotPath = process.env.FFMPEG_KIT_SURFACE_SCREENSHOT;

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
  await prepareWeb(['--app-root', appRoot, '--quiet', 'true']);

  const command = process.execPath;
  const viteEntry = path.join(appRoot, 'node_modules', 'vite', 'bin', 'vite.js');
  const server = childProcess.spawn(
    command,
    [viteEntry, '--host', '127.0.0.1', '--port', '4173', '--strictPort', '--config', 'web/vite.config.js'],
    {
      cwd: appRoot,
      stdio: ['ignore', 'pipe', 'pipe'],
      windowsHide: true,
      env: {...process.env, FFMPEG_KIT_TASK_TAG: taskTag},
    },
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
    await page.waitForFunction(
      () => document.querySelector('[data-testid="status"]')?.textContent?.startsWith('Initialized'),
      undefined,
      {timeout: SMOKE_TIMEOUT_MS},
    );
    const initialized = await page.getByTestId('status').textContent();
    assert.match(initialized || '', /^Initialized /);

    process.stdout.write('browser: repeated initialize\n');
    await page.getByRole('button', {name: 'Initialize'}).click();
    assert.match((await page.getByTestId('status').textContent()) || '', /^Initialized /);

    process.stdout.write('browser: ffmpeg\n');
    await page.getByRole('button', {name: 'Run FFmpeg'}).click();
    await page.waitForFunction(() => {
      const status = document.querySelector('[data-testid="status"]')?.textContent || '';
      return status.includes('FFmpeg state 2') && status.includes('statistics callbacks ');
    }, undefined, {timeout: SMOKE_TIMEOUT_MS});
    const ffmpegStatus = await page.getByTestId('status').textContent();
    assert.match(ffmpegStatus || '', /log callbacks [1-9]\d*/);
    assert.match(ffmpegStatus || '', /statistics callbacks [1-9]\d*/);
    process.stdout.write('browser: ffprobe\n');
    await page.getByRole('button', {name: 'Run FFprobe'}).click();
    await page.waitForFunction(
      () => document.querySelector('[data-testid="status"]')?.textContent?.includes('FFprobe state 2'),
      undefined,
      {timeout: SMOKE_TIMEOUT_MS},
    );
    process.stdout.write('browser: media info\n');
    await page.getByRole('button', {name: 'Run Media Info'}).click();
    await page.waitForFunction(
      () => document.querySelector('[data-testid="status"]')?.textContent?.startsWith('Media info streams '),
      undefined,
      {timeout: SMOKE_TIMEOUT_MS},
    );
    process.stdout.write('browser: ffplay\n');
    await page.getByRole('button', {name: 'Run FFplay'}).click();
    await page.waitForFunction(
      () => document.querySelector('[data-testid="status"]')?.textContent === 'Running FFplay',
      undefined,
      {timeout: SMOKE_TIMEOUT_MS},
    );

    const frameHandle = await page.waitForFunction(() => {
      const canvas = document.querySelector('canvas');
      if (!canvas || canvas.width !== 160 || canvas.height !== 90) return null;
      const context = canvas.getContext('2d');
      if (!context) return null;
      const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
      let nonBlackPixels = 0;
      let rgbMax = 0;
      for (let index = 0; index < pixels.length; index += 4) {
        const pixelMax = Math.max(pixels[index], pixels[index + 1], pixels[index + 2]);
        if (pixelMax > 0) nonBlackPixels += 1;
        rgbMax = Math.max(rgbMax, pixelMax);
      }
      return {width: canvas.width, height: canvas.height, nonBlackPixels, rgbMax};
    }, undefined, {timeout: SMOKE_TIMEOUT_MS});
    const frame = await frameHandle.jsonValue();
    await frameHandle.dispose();
    assert.equal(frame.width, 160);
    assert.equal(frame.height, 90);
    assert.ok(frame.nonBlackPixels > 0, `FFplay canvas is black: ${JSON.stringify(frame)}`);
    if (screenshotPath) {
      fs.mkdirSync(path.dirname(screenshotPath), {recursive: true});
      await page.screenshot({path: screenshotPath});
      process.stdout.write(`FFplay video surface screenshot: ${screenshotPath}\n`);
    }
    process.stdout.write(`WebAssembly video surface pixel check: ${JSON.stringify(frame)}\n`);

    process.stdout.write('browser: ffplay pause\n');
    await page.getByRole('button', {name: 'Pause'}).click();
    process.stdout.write('browser: ffplay resume\n');
    await page.getByRole('button', {name: 'Resume'}).click();
    process.stdout.write('browser: ffplay stop\n');
    await page.getByRole('button', {name: 'Stop'}).click();
    await page.waitForFunction(
      () => document.querySelector('[data-testid="status"]')?.textContent?.includes('FFplay state 2'),
      undefined,
      {timeout: SMOKE_TIMEOUT_MS},
    );
    try {
      await page.waitForFunction(
        () => document.querySelector('[data-testid="status"]')?.textContent?.includes('FFplay state 2'),
        undefined,
        {timeout: SMOKE_TIMEOUT_MS},
      );
    } catch (error) {
      const diagnostics = await page.evaluate(() => ({
        status: document.querySelector('[data-testid="status"]')?.textContent,
        output: document.querySelector('[data-testid="output"]')?.textContent,
      }));
      throw new Error(`${error.message}; diagnostics=${JSON.stringify(diagnostics)}`);
    }

    assert.deepEqual(errors, []);
    process.stdout.write('Headless WebAssembly smoke test passed.\n');
  } finally {
    await browser?.close();
    if (server.exitCode === null) {
      server.kill('SIGTERM');
      await new Promise(resolve => {
        const timer = setTimeout(resolve, 5000);
        server.once('exit', () => {
          clearTimeout(timer);
          resolve();
        });
      });
    }
    if (server.exitCode === null) server.kill('SIGKILL');
    if (serverOutput && process.env.DEBUG_WEB_SMOKE) process.stderr.write(serverOutput);
  }
}

main().catch(error => {
  console.error(error.message || String(error));
  process.exitCode = 1;
});
