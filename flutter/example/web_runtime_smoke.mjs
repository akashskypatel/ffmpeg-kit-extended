import assert from 'node:assert/strict';
import {mkdirSync, mkdtempSync, rmSync} from 'node:fs';
import {createRequire} from 'node:module';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {assertFramePixels} from '../../scripts/ffplay-surface-pixels.mjs';

const require = createRequire(import.meta.url);
let chromium;
try {
  ({chromium} = await import('playwright'));
} catch (error) {
  // The repository keeps the local Playwright installation with the RN Web
  // smoke tooling; do not download a second copy for the Flutter example.
  if (error?.code !== 'ERR_MODULE_NOT_FOUND') throw error;
  ({chromium} = require('../../react-native/node_modules/playwright'));
}

const url = process.argv[2] ?? 'http://127.0.0.1:8080';
const browser = await chromium.launch({headless: true});
const page = await browser.newPage({locale: 'en-US'});
const pageErrors = [];
const consoleErrors = [];
const runtimeRoot = process.argv[3];
const surfaceScreenshot = process.env.FFMPEG_KIT_SURFACE_SCREENSHOT;
const temporaryCaptureDirectory = surfaceScreenshot
  ? undefined
  : mkdtempSync(path.join(tmpdir(), 'ffmpeg-kit-flutter-web-'));
const pixelScreenshot =
  surfaceScreenshot ?? path.join(temporaryCaptureDirectory, 'ffplay-surface.png');
const runtimeRequests = [];
const failedAssetResponses = [];

page.on('pageerror', (error) => pageErrors.push(String(error)));
page.on('console', (message) => {
  if (message.type() === 'error') consoleErrors.push(message.text());
});
page.on('request', (request) => {
  if (request.url().includes('ffmpegkit')) runtimeRequests.push(request.url());
});
page.on('response', (response) => {
  if (response.url().includes('ffmpegkit') && response.status() >= 400) {
    failedAssetResponses.push(`${response.status()} ${response.url()}`);
  }
});

try {
  console.log('STARTING');
  await page.goto(url, {waitUntil: 'domcontentloaded', timeout: 30_000});
  await page.waitForFunction(
    () => document.title.includes('FFPLAY_STARTED'),
    null,
    {timeout: 120_000},
  );
  await page.waitForTimeout(500);
  mkdirSync(path.dirname(pixelScreenshot), {recursive: true});
  await page.screenshot({
    path: pixelScreenshot,
    clip: {x: 0, y: 0, width: 160, height: 90},
  });
  const frame = assertFramePixels({
    imagePath: pixelScreenshot,
    label: 'Flutter Web FFplay surface',
  });
  console.log(`Flutter Web FFplay surface pixel check: ${JSON.stringify(frame)}`);
  if (surfaceScreenshot) {
    console.log(`Flutter Web FFplay surface screenshot: ${surfaceScreenshot}`);
  }
  try {
    await page.waitForFunction(
      () => /(?:PASS|FAIL:)/.test(document.title),
      null,
      {timeout: 120_000},
    );
  } catch (error) {
    console.error(`Smoke timeout; title: ${await page.title()}`);
    console.error(`Runtime requests: ${runtimeRequests.join(', ')}`);
    console.error(`Page errors: ${pageErrors.join(' | ')}`);
    console.error(`Console errors: ${consoleErrors.join(' | ')}`);
    throw error;
  }

  const status = await page.title();
  assert.match(status, /STARTING/);
  assert.match(status, /INITIALIZED/);
  assert.match(status, /FFMPEG_OK/);
  assert.match(status, /LOG_OK/);
  assert.match(status, /FFPROBE_OK/);
  assert.match(status, /MEDIA_INFO_OK/);
  assert.match(status, /PASS/);
  assert.doesNotMatch(status, /FAIL:/);
  assert.deepEqual(
    pageErrors,
    [],
    `Page errors: ${pageErrors.join(' | ')}; ` +
        `Failed asset responses: ${failedAssetResponses.join(' | ')}; ` +
        `Runtime requests: ${runtimeRequests.join(', ')}`,
  );
  assert.deepEqual(
    consoleErrors,
    [],
    `Console errors: ${consoleErrors.join(' | ')}; ` +
        `Failed asset responses: ${failedAssetResponses.join(' | ')}; ` +
        `Runtime requests: ${runtimeRequests.join(', ')}`,
  );
  if (runtimeRoot) {
    assert.ok(
      runtimeRequests.some((url) =>
        url.includes(`/${runtimeRoot}/ffmpegkit_bridge.mjs`)),
      `Expected the ${runtimeRoot} bridge asset to load. Requests: ${runtimeRequests.join(', ')}`,
    );
    assert.ok(
      runtimeRequests.some((url) =>
        url.includes(`/${runtimeRoot}/ffmpegkit.wasm`)),
      `Expected the ${runtimeRoot} Wasm asset to load. Requests: ${runtimeRequests.join(', ')}`,
    );
    if (runtimeRoot === 'wasm') {
      assert.equal(
        runtimeRequests.some((url) =>
          url.includes('/wasm_override/ffmpegkit_bridge.mjs')),
        false,
        `The default smoke must not load the custom bridge. Requests: ${runtimeRequests.join(', ')}`,
      );
    }
  }
  console.log(status);
  console.log('PASS');
} finally {
  await browser.close();
  if (temporaryCaptureDirectory) {
    rmSync(temporaryCaptureDirectory, {recursive: true, force: true});
  }
}
