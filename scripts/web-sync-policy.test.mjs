// Phase 3 static contract for the Web sync-request policy (plan §P3.0a).
// W-F05: the native backend is untouched relative to the Phase 3 start commit.
// W-F01 (static part): every Web sync execute method runs the network guard
// before its blocking Wasm call, and no async method runs it.

import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const phaseStartCommit = '828d69fdca794d19647dadd686b9458181263f76';
const webBackend = path.join(root, 'flutter/lib/src/platform/web/backend_web.dart');

function methodBody(source, signature) {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1, `missing method: ${signature}`);
  const next = source.indexOf('@override', start + signature.length);
  return source.slice(start, next === -1 ? source.length : next);
}

test('Web backend guard pattern matches direct and chained network schemes only', async () => {
  const source = await readFile(webBackend, 'utf8');
  assert.match(
    source,
    /final _webNetworkInputPattern = RegExp\(\s*r'\^\(\[a-z\]\[a-z0-9\.-\]\*\\\+\)\*https\?:\/\/',\s*caseSensitive: false,\s*\);/
  );
});

test('synchronous Web execute methods run the guard before the blocking call', async () => {
  const source = await readFile(webBackend, 'utf8');
  const cases = [
    {
      signature: 'void executeFFmpegSession(SessionHandle handle)',
      blocking: 'bindings.ffmpeg_kit_session_execute(',
      api: "'FFmpegKit.execute'",
      replacement: "'FFmpegKit.executeAsync'",
    },
    {
      signature: 'void executeFFprobeSession(SessionHandle handle)',
      blocking: 'bindings.ffprobe_kit_session_execute(',
      api: "'FFprobeKit.execute'",
      replacement: "'FFprobeKit.executeAsync'",
    },
    {
      signature: 'void executeMediaInformationSession(SessionHandle handle, int timeout)',
      blocking: 'bindings.media_information_session_execute(',
      api: "'FFprobeKit.getMediaInformation'",
      replacement: "'FFprobeKit.getMediaInformationAsync'",
    },
  ];
  for (const item of cases) {
    const body = methodBody(source, item.signature);
    const guard = body.indexOf('_rejectNetworkInput(');
    const blocking = body.indexOf(item.blocking);
    assert.notEqual(guard, -1, `${item.signature} has no guard`);
    assert.notEqual(blocking, -1, `${item.signature} has no blocking call`);
    assert.ok(guard < blocking, `${item.signature} calls Wasm before the guard`);
    assert.ok(body.includes(item.api), `${item.signature} names the wrong API`);
    assert.ok(body.includes(item.replacement), `${item.signature} names the wrong replacement`);
  }
});

test('async Web execute methods do not run the sync guard', async () => {
  const source = await readFile(webBackend, 'utf8');
  for (const signature of [
    'void executeFFmpegSessionAsync(SessionHandle handle)',
    'void executeFFprobeSessionAsync(SessionHandle handle)',
    'void executeMediaInformationSessionAsync(SessionHandle handle, int timeout)',
  ]) {
    assert.doesNotMatch(methodBody(source, signature), /_rejectNetworkInput\(/);
  }
});

test('native backend and native sources are unchanged from the Phase 3 start commit (W-F05)', () => {
  const paths = [
    'flutter/lib/src/platform/native',
    'flutter/lib/src/platform/backend.dart',
    'flutter/lib/src/platform/backend_selector.dart',
    'react-native/src/platform/backend.native.ts',
    'react-native/src/platform/backend.native.register.ts',
    'react-native/src/NativeFFmpegKitExtended.ts',
  ];
  // `git diff --quiet` exits 1 when there is any difference, so a clean run
  // proves the native paths are byte-identical to the Phase 3 start commit.
  execFileSync('git', ['-C', root, 'diff', '--quiet', phaseStartCommit, '--', ...paths]);
});
