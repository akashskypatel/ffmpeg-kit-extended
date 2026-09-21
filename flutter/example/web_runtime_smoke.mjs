import assert from 'node:assert/strict';
import {chromium} from 'playwright';

const url = process.argv[2] ?? 'http://127.0.0.1:8080';
const browser = await chromium.launch({headless: true});
const page = await browser.newPage();
const pageErrors = [];
const consoleErrors = [];
const runtimeRoot = process.argv[3];
const runtimeRequests = [];

page.on('pageerror', (error) => pageErrors.push(String(error)));
page.on('console', (message) => {
  if (message.type() === 'error') consoleErrors.push(message.text());
});
page.on('request', (request) => {
  if (request.url().includes('ffmpegkit')) runtimeRequests.push(request.url());
});

try {
  console.log('STARTING');
  await page.goto(url, {waitUntil: 'domcontentloaded', timeout: 30_000});
  await page.waitForFunction(
    () => /(?:PASS|FAIL:)/.test(document.title),
    null,
    {timeout: 120_000},
  );

  const status = await page.title();
  assert.match(status, /STARTING/);
  assert.match(status, /INITIALIZED/);
  assert.match(status, /FFMPEG_OK/);
  assert.match(status, /FFPROBE_OK/);
  assert.match(status, /MEDIA_INFO_OK/);
  assert.match(status, /PASS/);
  assert.doesNotMatch(status, /FAIL:/);
  assert.deepEqual(pageErrors, []);
  assert.deepEqual(consoleErrors, []);
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
}
