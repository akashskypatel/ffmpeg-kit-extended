import assert from 'node:assert/strict';
import {chromium} from 'playwright';

const url = process.argv[2] ?? 'http://127.0.0.1:8080';
const browser = await chromium.launch({headless: true});
const page = await browser.newPage();
const pageErrors = [];
const consoleErrors = [];

page.on('pageerror', (error) => pageErrors.push(String(error)));
page.on('console', (message) => {
  if (message.type() === 'error') consoleErrors.push(message.text());
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
  console.log(status);
  console.log('PASS');
} finally {
  await browser.close();
}
