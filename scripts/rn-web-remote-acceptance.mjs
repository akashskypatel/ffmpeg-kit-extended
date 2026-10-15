// Phase 3 headless acceptance for the React Native Web remote URL panel (plan
// §P3.2, R01–R10). Usage:
//   node scripts/rn-web-remote-acceptance.mjs --record <path.json>
// Requires the RN example Web build at react-native/example/build/web, built by
// `npx vite build --config web/vite.config.js` in react-native/example after
// `prepare-web` staged the pinned Phase 2 runtime. Audible audio and subjective
// A/V sync stay PENDING-OWNER. R11 and R12 are reported separately in the tracker.

import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readdir, readFile, unlink, writeFile } from 'node:fs/promises';
import http from 'node:http';
import https from 'node:https';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(path.join(root, 'react-native/package.json'));
const { chromium } = require('playwright');
const builders = process.env.FFMPEG_KIT_BUILDERS_ROOT
  || '\\\\wsl.localhost\\ManyLinux\\home\\vscode\\ffmpeg-kit-builders';
const buildRoot = path.resolve(root, 'react-native/example/build/web');
const expected = {
  'ffmpegkit.wasm': '7544659af661f4e716c98e28bb5545c9a8da28aba88012f7fd4ed9969ec99e7e',
  'ffmpegkit.mjs': 'fd21f1a1296790b18f284afa49d878ab730ad3bdd7f7e62dfeef6260ef0ec83b',
};
const recordFlag = process.argv.indexOf('--record');
const recordPath = recordFlag < 0 ? undefined : process.argv[recordFlag + 1];
const caseFilter = process.env.CODEX_PHASE3_CASE_FILTER;
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

// Stop before any browser case when the staged runtime is not the pinned one.
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
const tlsCert = process.env.CODEX_PHASE3_TLS_CERT;
const tlsKey = process.env.CODEX_PHASE3_TLS_KEY;
const fixtureServer = tlsCert && tlsKey
  ? https.createServer({ cert: await readFile(tlsCert), key: await readFile(tlsKey) },
    (req, res) => fixture.server.emit('request', req, res))
  : fixture.server;
await new Promise((resolve, reject) => {
  fixtureServer.once('error', reject);
  fixtureServer.listen(0, '127.0.0.1', resolve);
});
const fixtureOrigin = `${tlsCert && tlsKey ? 'https' : 'http'}://127.0.0.1:${fixtureServer.address().port}`;

const app = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    const pathname = decodeURIComponent(url.pathname);
    const target = path.resolve(buildRoot, pathname === '/' ? 'index.html' : `.${pathname}`);
    if (!target.startsWith(`${buildRoot}${path.sep}`)) {
      res.writeHead(400).end();
      return;
    }
    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
    res.setHeader('Content-Type', mime[path.extname(target)] || 'application/octet-stream');
    res.end(await readFile(target));
  } catch (error) {
    res.writeHead(error.code === 'ENOENT' ? 404 : 500).end(String(error));
  }
});
await new Promise(resolve => app.listen(0, '127.0.0.1', resolve));
const appOrigin = process.env.CODEX_PHASE3_APP_ORIGIN || `http://127.0.0.1:${app.address().port}`;

const record = {
  contract: 'react-native-web-remote-acceptance',
  buildRoot: path.relative(root, buildRoot),
  staged,
  fixtureOrigin,
  localSelfSignedTls: Boolean(tlsCert && tlsKey),
  appOrigin,
  startedAt: new Date().toISOString(),
  cases: [],
  caseFilter: caseFilter || null,
  sources: Object.fromEntries(await Promise.all([
    'react-native/example/web/App.tsx',
    'react-native/example/web/vite.config.js',
    'react-native/src/platform/backend.web.ts',
    'scripts/rn-web-remote-acceptance.mjs',
  ].map(async file => [file, createHash('sha256').update(await readFile(path.join(root, file))).digest('hex')]))),
  consoleErrors: [],
  pageErrors: [],
  runtimeAssetResponses: [],
  pendingOwner: [
    'R04 audible audio: the owner must confirm sound plays from the FFplay panel for at least 30 seconds.',
    'R09 older runtime: no older Web bundle is available to this run; the owner must load an older bundle and confirm the ABI warning.',
    'R12 Vite dev server: the owner must run `npm run web` in react-native/example and confirm the Stream panel loads.',
  ],
};

async function step(id, action) {
  if (caseFilter && !new RegExp(caseFilter).test(id)) return;
  const started = Date.now();
  try {
    const detail = (await action()) ?? '';
    record.cases.push({ id, status: 'passed', detail: String(detail).slice(0, 400), elapsedMs: Date.now() - started });
    console.log(`PASSED ${id}: ${String(detail).slice(0, 160)}`);
  } catch (error) {
    record.cases.push({ id, status: 'failed', detail: String(error).slice(0, 500), elapsedMs: Date.now() - started });
    console.log(`FAILED ${id}: ${String(error).slice(0, 300)}`);
  }
}

// Records every change of the "State:" line with the visible page text at that moment.
function installTransitionLog() {
  window.__transitions = [];
  let last = '';
  const check = () => {
    const text = document.body.innerText || '';
    const match = /State: (\w+)/.exec(text);
    const state = match ? `State: ${match[1]}` : '';
    if (state && text !== last) {
      last = text;
      window.__transitions.push({ state, joined: text });
    }
  };
  new MutationObserver(check).observe(document.body, { subtree: true, childList: true, characterData: true });
  check();
}

const browser = await chromium.launch({
  headless: true,
  executablePath: process.env.CODEX_PHASE3_BROWSER_EXECUTABLE,
  args: ['--CODEX_PHASE3_RN'],
});
let page;
try {
  page = await browser.newPage({ viewport: { width: 1280, height: 900 }, acceptDownloads: true, ignoreHTTPSErrors: Boolean(tlsCert && tlsKey) });
  record.browser = browser.version();
  const liveRequests = [];
  page.on('console', message => {
    if (message.type() === 'error') record.consoleErrors.push(message.text().slice(0, 300));
  });
  page.on('pageerror', error => record.pageErrors.push(String(error).slice(0, 300)));
  page.on('response', response => {
    const name = new URL(response.url()).pathname.split('/').at(-1);
    if (name === 'ffmpegkit.wasm' || name === 'ffmpegkit.mjs') {
      record.runtimeAssetResponses.push({ name, status: response.status() });
    }
  });
  page.on('request', request => {
    if (request.url().includes('/hls/live.m3u8')) liveRequests.push(Date.now());
  });

  await page.goto(`${appOrigin}/`, { waitUntil: 'load' });
  await page.getByRole('tab', { name: 'Stream' }).waitFor({ timeout: 120_000 });
  await page.getByRole('tab', { name: 'Stream' }).click();
  await page.getByRole('button', { name: 'Probe', exact: true }).waitFor({ timeout: 120_000 });
  await page.evaluate(installTransitionLog);

  const field = page.getByLabel('Direct media URL');
  const button = name => page.getByRole('button', { name, exact: true });
  const pageText = () => page.evaluate(() => document.body.innerText || '');
  const mark = () => page.evaluate(() => window.__transitions.length);
  const waitTransition = async (from, states, timeoutMs) => {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      const hit = await page.evaluate(([start, wanted]) => window.__transitions.slice(start)
        .find(item => wanted.includes(item.state.slice('State: '.length))) ?? null, [from, states]);
      if (hit) return hit;
      await page.waitForTimeout(300);
    }
    const seen = await page.evaluate(start => window.__transitions.slice(start).map(item => item.state.slice(7)), from);
    throw new Error(`no transition to ${states.join('|')} within ${timeoutMs} ms; transitions after the action: [${seen.join(', ')}]`);
  };
  const run = async (name, states, timeoutMs) => {
    const from = await mark();
    await button(name).click();
    return waitTransition(from, states, timeoutMs);
  };
  const setUrl = async url => {
    await field.fill(url);
    await page.waitForTimeout(300);
  };
  const surfaceChecksum = () => page.evaluate(() => {
    const canvas = Array.from(document.querySelectorAll('canvas')).find(item => {
      if (item.width <= 0 || item.height <= 0) return false;
      return item.getContext('2d') !== null;
    });
    const context = canvas?.getContext('2d');
    if (!context) return null;
    const data = context.getImageData(0, 0, canvas.width, canvas.height).data;
    let sum = 0;
    for (let index = 0; index < data.length; index += 997) sum = (sum * 31 + data[index]) % 2147483647;
    return sum;
  });

  // Waits until the runtime allows Probe, so no case starts before the Wasm runtime is ready.
  await step('R00 runtime ready and Probe enabled', async () => {
    const deadline = Date.now() + 120_000;
    while (Date.now() < deadline) {
      if ((await button('Probe').getAttribute('disabled')) === null && (await button('Probe').getAttribute('aria-disabled')) !== 'true') {
        return 'Probe enabled';
      }
      await page.waitForTimeout(500);
    }
    throw new Error('Probe stayed disabled; the runtime did not become ready');
  });

  // R01: an unsupported scheme shows a finite message and disables Probe; a direct URL clears it.
  await step('R01 unsupported scheme rejected with a finite message', async () => {
    await setUrl('rtmp://127.0.0.1/live/stream');
    assert.ok((await pageText()).includes('Only direct http:// and https:// URLs run on Web'), 'validation message must show');
    assert.ok(await button('Probe').isDisabled(), 'Probe must be disabled for rtmp://');
    await setUrl(`${fixtureOrigin}/media/progressive.mp4`);
    assert.ok(!(await pageText()).includes('Only direct http:// and https:// URLs run on Web'), 'a direct URL must clear the message');
    assert.ok(await button('Probe').isEnabled(), 'Probe must be enabled for a direct URL');
    return 'rtmp:// rejected with a finite message; direct http URL enables Probe';
  });

  // R02: progressive HTTP FFprobe reports the container.
  await step('R02 progressive FFprobe metadata', async () => {
    await setUrl(`${fixtureOrigin}/media/progressive.mp4`);
    const done = await run('Probe', ['completed', 'failed'], 90_000);
    assert.equal(done.state, 'State: completed', `probe failed: ${done.joined.slice(0, 300)}`);
    assert.match(done.joined, /"format_name": "mov,mp4/, 'progressive probe must report mov,mp4');
    return 'format_name reports mov,mp4';
  });

  // R03: HLS master playlist reports its streams.
  await step('R03 HLS master FFprobe streams', async () => {
    await setUrl(`${fixtureOrigin}/hls/master.m3u8`);
    const done = await run('Probe', ['completed', 'failed'], 90_000);
    assert.equal(done.state, 'State: completed', `HLS probe failed: ${done.joined.slice(0, 300)}`);
    assert.match(done.joined, /"codec_type": "video"/, 'HLS probe must report a video stream');
    return 'HLS probe reports a video stream';
  });

  // R04 (partial): live HLS playback runs, the playlist refreshes and the surface changes. Audio is PENDING-OWNER.
  await step('R04 live HLS playback refreshes the playlist and advances the surface', async () => {
    await setUrl(`${fixtureOrigin}/hls/live.m3u8`);
    liveRequests.length = 0;
    const started = await run('Play', ['playing', 'failed'], 60_000);
    assert.equal(started.state, 'State: playing', `playback did not start: ${started.joined.slice(0, 300)}`);
    const canvasDeadline = Date.now() + 60_000;
    while (Date.now() < canvasDeadline && (await surfaceChecksum()) === null) await page.waitForTimeout(500);
    const first = await surfaceChecksum();
    await page.waitForTimeout(30_000);
    const second = await surfaceChecksum();
    assert.notEqual(first, null, 'the FFplay canvas must exist');
    assert.notEqual(second, first, 'surface pixels must change over 30 seconds');
    assert.ok(liveRequests.length >= 3, `expected at least 3 playlist refreshes, saw ${liveRequests.length}`);
    const stopped = await run('Stop', ['cancelled', 'completed', 'failed'], 30_000);
    assert.equal(stopped.state, 'State: cancelled', 'Stop must cancel playback');
    return `playlist refreshes=${liveRequests.length}; surface checksum changed after 30 s`;
  });

  // R05 and R06 share one page: the recording is downloaded and reprobed in place.
  let recorded = false;
  let recordingProgressReported = false;
  let downloadedRecordingBytes = 0;
  await step('R05 HLS 15 s recording produces a nonempty output', async () => {
    await setUrl(`${fixtureOrigin}/hls/live.m3u8`);
    const from = await mark();
    await button('Record 15 s').click();
    const started = await waitTransition(from, ['recording', 'completed', 'failed'], 120_000);
    assert.equal(started.state, 'State: recording', 'recording must enter its active state');
    const progressHandle = await page.waitForFunction(() => {
      const text = document.body.innerText || '';
      return text.includes('State: recording')
        ? text.match(/Recording: (\d+)% · ([^·]+) · ([\d.]+) \/ 15 s media/)
        : null;
    }, null, {timeout: 120_000});
    const progressDetail = await progressHandle.jsonValue();
    assert.ok(progressDetail, 'statistics must report progress, output size and media time');
    assert.ok(Number(progressDetail[1]) > 0 || progressDetail[2].trim() !== '0 B' || Number(progressDetail[3]) > 0,
      'reported media time, percentage or bytes must advance');
    recordingProgressReported = true;
    record.recordingProgress = progressDetail[0];
    const done = await waitTransition(await mark(), ['completed', 'failed'], 120_000);
    assert.equal(done.state, 'State: completed', `recording failed: ${done.joined.slice(0, 300)}`);
    assert.match(done.joined, /Recorded \d+ bytes/, 'recording must report a nonzero byte count');
    recorded = true;
    return done.joined.split('\n').find(line => line.includes('Recorded')) ?? 'recorded';
  });

  await step('R06 downloaded recording is valid and reprobes as Matroska', async () => {
    assert.ok(recorded, 'R05 must pass first');
    const downloadPromise = page.waitForEvent('download', { timeout: 60_000 });
    await button('Download Recording').click();
    const download = await downloadPromise;
    const savedPath = path.join(root, '.agent', 'evidence', 'phase-3', `CODEX_r06-${process.pid}-${Date.now()}.mkv`);
    try {
      await download.saveAs(savedPath);
      const bytes = await readFile(savedPath);
      assert.ok(bytes.length > 0, 'downloaded recording must be nonempty');
      assert.deepEqual([...bytes.subarray(0, 4)], [0x1a, 0x45, 0xdf, 0xa3], 'downloaded file must start with an EBML header');
      downloadedRecordingBytes = bytes.length;
      const done = await run('Probe Recording', ['completed', 'failed'], 60_000);
      assert.equal(done.state, 'State: completed', `reprobe failed: ${done.joined.slice(0, 300)}`);
      assert.match(done.joined, /matroska/, 'reprobe must report a Matroska container');
      await page.getByRole('tab', { name: 'FFprobe', exact: true }).click();
      await page.getByTestId('import-media-input').setInputFiles(savedPath);
      await page.waitForTimeout(500);
      await button('Get Media Info').click();
      await page.waitForFunction(() => /matroska/.test(document.querySelector('.metadata-output')?.textContent || ''), null, { timeout: 60_000 });
      await page.getByRole('tab', { name: 'Stream', exact: true }).click();
      return `downloaded ${bytes.length} bytes, reimported the saved file and probed Matroska metadata`;
    } finally {
      await unlink(savedPath).catch(() => {});
    }
  });

  // R07: Stop during a pending GET aborts once without a hang.
  await step('R07 stop during a pending GET cancels once', async () => {
    await setUrl(`${fixtureOrigin}/slow`);
    const from = await mark();
    const pendingGet = page.waitForRequest(request => request.url() === `${fixtureOrigin}/slow`);
    await button('Probe').click();
    await pendingGet;
    await waitTransition(from, ['loading'], 30_000);
    const stopped = await run('Stop', ['cancelled', 'completed', 'failed'], 15_000);
    assert.equal(stopped.state, 'State: cancelled', 'Stop must cancel the pending probe');
    assert.match(stopped.joined, /Probe cancelled\./, 'wait for probe completion, not just the cancellation request');
    assert.ok(await button('Probe').isEnabled(), 'Probe must be enabled after cancel');
    return 'cancelled within 15 seconds and controls re-enabled';
  });

  // R08: VOD natural end completes without an SDL JavaScript exception.
  await step('R08 VOD EOF completes cleanly', async () => {
    await setUrl(`${fixtureOrigin}/hls/one-segment.m3u8`);
    const done = await run('Play', ['completed', 'failed'], 120_000);
    assert.equal(done.state, 'State: completed', `playback failed: ${done.joined.slice(0, 300)}`);
    assert.match(done.joined, /end of the media/, 'EOF must report normal completion');
    return 'playback completed at the end of the media';
  });

  // R09: HTTP 403, 404, no-CORS and offline fail finitely.
  await step('R09 HTTP 403 is a clear failure', async () => {
    await setUrl(`${fixtureOrigin}/status/403`);
    const done = await run('Probe', ['failed', 'completed'], 60_000);
    assert.equal(done.state, 'State: failed', 'a 403 must not report success');
    assert.match(done.joined, /HTTP 403/, 'must classify HTTP 403');
    return 'HTTP 403 classified as failed';
  });
  await step('R09 HTTP 404 is a clear failure', async () => {
    await setUrl(`${fixtureOrigin}/status/404`);
    const done = await run('Probe', ['failed', 'completed'], 60_000);
    assert.equal(done.state, 'State: failed', 'a 404 must not report success');
    assert.match(done.joined, /HTTP 404/, 'must classify HTTP 404');
    return 'HTTP 404 classified as failed';
  });
  await step('R09 response without CORS grant fails without false success', async () => {
    await setUrl(`${fixtureOrigin}/cors/absent`);
    const done = await run('Probe', ['failed', 'completed'], 60_000);
    assert.equal(done.state, 'State: failed', 'a blocked response must not report success');
    return 'no-CORS response failed';
  });
  await step('R09 offline host fails finitely', async () => {
    await setUrl('http://127.0.0.1:1/offline.mp4');
    const done = await run('Probe', ['failed', 'completed'], 60_000);
    assert.equal(done.state, 'State: failed', 'an unreachable host must not report success');
    return 'unreachable host failed';
  });

  // R10: ten play-to-EOF cycles produce no stale callback error and no SDL audio exception.
  await step('R10 ten stop/restart/EOF cycles without stale callbacks', async () => {
    await setUrl(`${fixtureOrigin}/hls/one-segment.m3u8`);
    const consoleBefore = record.consoleErrors.length;
    const pageBefore = record.pageErrors.length;
    for (let cycle = 1; cycle <= 10; cycle += 1) {
      if (cycle % 2 === 1) {
        const started = await run('Play', ['playing', 'failed'], 60_000);
        assert.equal(started.state, 'State: playing');
        await page.waitForTimeout(500);
        const stopped = await run('Stop', ['cancelled', 'failed'], 30_000);
        assert.equal(stopped.state, 'State: cancelled', `stop cycle ${cycle} failed`);
        assert.match(stopped.joined, /Playback stopped\./);
      } else {
        const done = await run('Play', ['completed', 'failed'], 120_000);
        assert.equal(done.state, 'State: completed', `EOF cycle ${cycle} failed: ${done.joined.slice(0, 200)}`);
      }
    }
    await page.waitForTimeout(500);
    const newErrors = [...record.consoleErrors.slice(consoleBefore), ...record.pageErrors.slice(pageBefore)];
    const audioErrors = newErrors.filter(text => text.includes('currentOutputBuffer'));
    assert.equal(audioErrors.length, 0, `SDL audio exception seen: ${audioErrors[0]}`);
    assert.deepEqual(record.pageErrors.slice(pageBefore), [], 'playback must not throw an uncaught page exception');
    const unexpected = newErrors.filter(text => !text.includes('[ffplay-wasm] event='));
    assert.deepEqual(unexpected, [], 'repeat playback must not emit errors other than native lifecycle diagnostics');
    const starts = newErrors.filter(text => text.includes('event=playback_start ')).length;
    const closes = newErrors.filter(text => text.includes('event=playback_close ')).length;
    assert.equal(starts, 10, 'all ten native playbacks must start');
    assert.equal(closes, starts, 'every native playback must close');
    return `5 stop + 5 EOF cycles; ${starts} native starts/${closes} closes; no unexpected errors`;
  });

  await step('R11 generated and imported MP4/TS and audio finish playback', async () => {
    await page.getByRole('tab', { name: 'FFplay', exact: true }).click();
    const playToClose = async action => {
      const from = record.consoleErrors.length;
      await action();
      const deadline = Date.now() + 60_000;
      while (!record.consoleErrors.slice(from).some(text => text.includes('event=playback_close '))) {
        assert.ok(Date.now() < deadline, 'local-media playback must reach native close');
        await page.waitForTimeout(100);
      }
      const events = record.consoleErrors.slice(from);
      assert.ok(events.some(text => text.includes('event=audio_open ')), 'audio must open for this media');
      assert.ok(events.some(text => text.includes('event=audio_close ')), 'audio must close at EOF');
      await page.waitForTimeout(250);
    };
    await playToClose(() => button('Play Video').click());
    await playToClose(() => button('Play Audio').click());
    for (const file of ['same-h264-aac.mp4', 'segment-1.ts', 'segment-audio-only.ts']) {
      await page.getByTestId('import-media-input').setInputFiles(path.join(builders, 'FFmpegKit/tests/wasm_streaming/fixtures/h264-aac', file));
      await page.waitForTimeout(500);
      await playToClose(() => button('Play Imported File').click());
    }
    return 'generated AV MP4 + WAV; imported AV MP4 + AV TS + audio-only TS reached audio close and playback close';
  });
  await step('R12 Vite Web assets, heap, callbacks and download', async () => {
    for (const name of Object.keys(record.staged)) {
      assert.ok(record.runtimeAssetResponses.some(asset => asset.name === name && asset.status === 200),
        `${name} must load successfully in the browser`);
    }
    assert.ok(recordingProgressReported, 'recording statistics callback must report progress');
    const playbackCloses = record.consoleErrors.filter(text => text.includes('event=playback_close ')).length;
    assert.ok(playbackCloses > 0, 'FFplay completion callbacks must run');
    assert.ok(record.consoleErrors.some(text => text.includes('event=audio_close ')), 'audio close callback must run');
    const heap = await page.evaluate(() => performance.memory
      ? { used: performance.memory.usedJSHeapSize, total: performance.memory.totalJSHeapSize, limit: performance.memory.jsHeapSizeLimit }
      : null);
    assert.ok(heap && heap.used > 0 && heap.used <= heap.limit, 'Chrome must report a valid JavaScript heap sample');
    record.jsHeapAtEnd = heap;
    assert.ok(downloadedRecordingBytes > 0, 'the downloaded recording must be nonempty');
    return `pinned assets loaded; heap ${heap.used}/${heap.limit}; ${playbackCloses} playback closes; ${downloadedRecordingBytes} downloaded bytes`;
  });
  await step('no uncaught page or SDL callback exception', () => {
    assert.deepEqual(record.pageErrors, []);
    assert.ok(!record.consoleErrors.some(text => text.includes('currentOutputBuffer')));
  });
} catch (error) {
  record.cases.push({ id: 'browser setup or unhandled failure', status: 'failed', detail: String(error) });
  record.visibleText = await page?.evaluate(() => document.body.innerText).catch(() => undefined);
  console.error('RN browser failure:', error, record.pageErrors, record.consoleErrors);
} finally {
  record.jsHeapAtEnd = await page?.evaluate(() => performance.memory
    ? { used: performance.memory.usedJSHeapSize, total: performance.memory.totalJSHeapSize, limit: performance.memory.jsHeapSizeLimit }
    : null).catch(() => null);
  await browser.close();
  app.close();
  await new Promise(resolve => fixtureServer.close(resolve));
}

record.finishedAt = new Date().toISOString();
record.passed = record.cases.length > 0 && record.cases.every(item => item.status === 'passed');
if (recordPath) await writeFile(recordPath, `${JSON.stringify(record, null, 2)}\n`);
console.log(record.passed ? 'RN-WEB-REMOTE-ACCEPTANCE PASS' : 'RN-WEB-REMOTE-ACCEPTANCE NOT PASSED');
process.exitCode = record.passed ? 0 : 1;
