'use strict';

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const net = require('node:net');
const path = require('node:path');
const {chromium} = require('playwright');
const test = require('node:test');

const packageRoot = path.resolve(__dirname, '..');
const exampleRoot = path.join(packageRoot, 'example');

function waitForPort(port, timeoutMs = 30000) {
  const started = Date.now();
  return new Promise((resolve, reject) => {
    const probe = () => {
      const socket = net.createConnection({port, host: '127.0.0.1'});
      socket.once('connect', () => {
        socket.destroy();
        resolve();
      });
      socket.once('error', () => {
        socket.destroy();
        if (Date.now() - started >= timeoutMs) {
          reject(new Error(`Timed out waiting for port ${port}`));
        } else {
          setTimeout(probe, 100);
        }
      });
    };
    probe();
  });
}

function writeFixture(root, configPath) {
  fs.writeFileSync(
    path.join(root, 'index.html'),
    '<div id="root"></div><script type="module" src="./main.js"></script>',
  );
  fs.writeFileSync(
    path.join(root, 'main.js'),
    `import React, {useState} from 'react';
import {createRoot} from 'react-dom/client';
import {FFplayView} from '../../src/ffplay-view.web';
import {beginFFplayPlayback} from '../../src/platform/web/ffplay-frame-state';

window.__ffmpegKitAnimationFrameStats = {requested: 0, cancelled: 0};
const requestAnimationFrameImpl = window.requestAnimationFrame.bind(window);
const cancelAnimationFrameImpl = window.cancelAnimationFrame.bind(window);
window.requestAnimationFrame = callback => {
  window.__ffmpegKitAnimationFrameStats.requested += 1;
  return requestAnimationFrameImpl(callback);
};
window.cancelAnimationFrame = handle => {
  window.__ffmpegKitAnimationFrameStats.cancelled += 1;
  return cancelAnimationFrameImpl(handle);
};
window.__ffmpegKitAdvancePlaybackEpoch = beginFFplayPlayback;

function App() {
  const [mounted, setMounted] = useState(true);
  const [clicked, setClicked] = useState(false);
  return React.createElement(React.Fragment, null,
    mounted ? React.createElement(FFplayView, {
      testID: 'ffplay-surface',
      nativeID: 'ffplay-native-id',
      accessibilityLabel: 'FFplay preview',
      accessibilityRole: 'img',
      onClick: () => setClicked(true),
      style: [{width: 320}, {height: 180, aspectRatio: 16 / 9, backgroundColor: '#111'}],
    }) : null,
    React.createElement('button', {onClick: () => setMounted(false)}, 'Unmount'),
    React.createElement('output', {'data-testid': 'clicked'}, String(clicked)),
  );
}

createRoot(document.getElementById('root')).render(React.createElement(App));
`,
  );
  const reactRoot = path.dirname(require.resolve('react/package.json', {paths: [exampleRoot]}));
  const reactDomRoot = path.dirname(require.resolve('react-dom/package.json', {paths: [exampleRoot]}));
  const reactNativeWeb = path.dirname(require.resolve('react-native-web/package.json', {paths: [exampleRoot]}));
  fs.writeFileSync(
    configPath,
    `module.exports = {
  root: ${JSON.stringify(root)},
  resolve: {
    alias: [
      {find: 'react-native', replacement: ${JSON.stringify(reactNativeWeb)}},
      {find: 'react-dom', replacement: ${JSON.stringify(reactDomRoot)}},
      {find: 'react', replacement: ${JSON.stringify(reactRoot)}},
    ],
  },
  server: {fs: {allow: [${JSON.stringify(packageRoot)}]}},
};
`,
  );
}

test('FFplayView preserves View props, styles, and unmount cleanup on Web', async () => {
  const fixtureRoot = fs.mkdtempSync(path.join(exampleRoot, '.ffmpeg-kit-ffplay-view-'));
  const configPath = path.join(exampleRoot, `.ffmpeg-kit-ffplay-view-${process.pid}.config.js`);
  const port = 4174;
  writeFixture(fixtureRoot, configPath);
  const viteEntry = path.join(exampleRoot, 'node_modules', 'vite', 'bin', 'vite.js');
  const server = childProcess.spawn(
    process.execPath,
    [viteEntry, '--host', '127.0.0.1', '--port', String(port), '--strictPort', '--config', configPath],
    {cwd: exampleRoot, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true},
  );
  let serverOutput = '';
  server.stdout.on('data', chunk => { serverOutput += chunk; });
  server.stderr.on('data', chunk => { serverOutput += chunk; });
  let browser;
  let page;
  const pageErrors = [];
  try {
    await waitForPort(port);
    browser = await chromium.launch({headless: true});
    page = await browser.newPage();
    page.on('console', message => {
      if (message.type() === 'error') pageErrors.push(`console: ${message.text()}`);
    });
    page.on('pageerror', error => pageErrors.push(error.message));
    await page.goto(`http://127.0.0.1:${port}/`, {waitUntil: 'networkidle'});

    const surface = page.getByTestId('ffplay-surface');
    await surface.waitFor({state: 'visible'});
    const details = await surface.evaluate(element => {
      const view = element.ownerDocument.defaultView;
      const child = element.firstElementChild;
      return {
        tagName: element.tagName,
        id: element.id,
        role: element.getAttribute('role'),
        label: element.getAttribute('aria-label'),
        width: view.getComputedStyle(element).width,
        height: view.getComputedStyle(element).height,
        aspectRatio: view.getComputedStyle(element).aspectRatio,
        childTagName: child?.tagName,
        childWidth: child && view.getComputedStyle(child).width,
        childHeight: child && view.getComputedStyle(child).height,
      };
    });
    assert.deepEqual(details, {
      tagName: 'DIV',
      id: 'ffplay-native-id',
      role: 'img',
      label: 'FFplay preview',
      width: '320px',
      height: '180px',
      aspectRatio: '1.77778 / 1',
      childTagName: 'CANVAS',
      childWidth: '320px',
      childHeight: '180px',
    });

    const drawnPixel = await surface.locator('canvas').evaluate(canvas => {
      const context = canvas.getContext('2d');
      if (!context) throw new Error('2D canvas context is unavailable');
      context.fillStyle = '#ff0000';
      context.fillRect(0, 0, 1, 1);
      return Array.from(context.getImageData(0, 0, 1, 1).data);
    });
    assert.deepEqual(drawnPixel, [255, 0, 0, 255]);
    await page.evaluate(() => window.__ffmpegKitAdvancePlaybackEpoch());
    await page.waitForFunction(() => {
      const canvas = document.querySelector('[data-testid="ffplay-surface"] canvas');
      if (!canvas || typeof canvas.getContext !== 'function') return false;
      const context = canvas.getContext('2d');
      return context ? context.getImageData(0, 0, 1, 1).data[3] === 0 : false;
    });
    assert.equal(await surface.isVisible(), true);

    await surface.click();
    assert.equal(await page.getByTestId('clicked').textContent(), 'true');
    await page.waitForTimeout(50);
    const beforeUnmount = await page.evaluate(() => ({...window.__ffmpegKitAnimationFrameStats}));
    await page.getByRole('button', {name: 'Unmount'}).click();
    await page.waitForTimeout(100);
    const afterUnmount = await page.evaluate(() => ({...window.__ffmpegKitAnimationFrameStats}));
    await page.waitForTimeout(100);
    const stableAfterUnmount = await page.evaluate(() => ({...window.__ffmpegKitAnimationFrameStats}));
    assert.ok(afterUnmount.cancelled >= beforeUnmount.cancelled + 1);
    assert.equal(stableAfterUnmount.requested, afterUnmount.requested);
    assert.deepEqual(pageErrors, []);
  } catch (error) {
    const diagnostics = page ? await page.evaluate(() => document.body.innerHTML).catch(() => '') : '';
    const details = [
      serverOutput && `server=${serverOutput}`,
      pageErrors.length && `page=${pageErrors.join(' | ')}`,
      diagnostics && `body=${diagnostics}`,
    ].filter(Boolean).join('; ');
    throw new Error(details ? `${error.message}; ${details}` : error.message, {cause: error});
  } finally {
    await browser?.close();
    if (!server.killed) server.kill('SIGTERM');
    fs.rmSync(configPath, {force: true});
    fs.rmSync(fixtureRoot, {recursive: true, force: true});
  }
});
