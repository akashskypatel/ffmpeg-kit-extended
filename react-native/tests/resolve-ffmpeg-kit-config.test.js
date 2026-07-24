'use strict';

const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {afterEach, test} = require('node:test');

const {
  BINARY_VERSION,
  CONFIG_FILE_NAME,
  DEFAULT_CONFIG,
  resolveConfig,
} = require('../scripts/resolve-ffmpeg-kit-config.js');

const tempRoots = [];

function createApp(config) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-config-'));
  tempRoots.push(root);
  if (config !== undefined) {
    fs.writeFileSync(
      path.join(root, CONFIG_FILE_NAME),
      typeof config === 'string' ? config : JSON.stringify(config),
    );
  }
  const nested = path.join(root, 'native', 'project');
  fs.mkdirSync(nested, {recursive: true});
  return {root, nested};
}

afterEach(() => {
  for (const root of tempRoots.splice(0)) {
    fs.rmSync(root, {recursive: true, force: true});
  }
});

test('uses the documented default configuration when no config file exists', () => {
  const {nested} = createApp();
  const result = resolveConfig({appRoot: nested, platform: 'android'});

  assert.equal(result.usedDefaultConfig, true);
  assert.equal(result.configPath, null);
  assert.equal(result.type, DEFAULT_CONFIG.type);
  assert.equal(result.gpl, DEFAULT_CONFIG.gpl);
  assert.equal(result.small, DEFAULT_CONFIG.small);
  assert.equal(result.filename, 'bundle-base-shared-small-lgpl-release.aar');
  assert.equal(
    result.url,
    `https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download/v${BINARY_VERSION}-android/bundle-base-shared-small-lgpl-release.aar`,
  );
});

test('finds configuration by walking up from a nested native project directory', () => {
  const {root, nested} = createApp({type: 'audio', gpl: true, small: false});
  const result = resolveConfig({appRoot: nested, platform: 'android'});

  assert.equal(result.appRoot, root);
  assert.equal(result.configPath, path.join(root, CONFIG_FILE_NAME));
  assert.equal(result.usedDefaultConfig, false);
  assert.equal(result.filename, 'bundle-audio-shared-gpl-release.aar');
});

test('resolves Android debug bundles using base plus the debug suffix', () => {
  const {nested} = createApp({type: 'debug', gpl: true, small: true});
  const result = resolveConfig({appRoot: nested, platform: 'android'});

  assert.equal(result.artifact, 'bundle-base-shared-debug-gpl');
  assert.equal(result.filename, 'bundle-base-shared-debug-gpl-release.aar');
});

test('resolves all primary platform artifact naming schemes', () => {
  const {nested} = createApp({type: 'video_hw', gpl: false, small: true});

  const ios = resolveConfig({appRoot: nested, platform: 'ios'});
  const tvos = resolveConfig({appRoot: nested, platform: 'tvos'});
  const macos = resolveConfig({appRoot: nested, platform: 'macos'});
  const windows = resolveConfig({
    appRoot: nested,
    platform: 'windows',
    architecture: 'x64',
  });
  const linux = resolveConfig({
    appRoot: nested,
    platform: 'linux',
    architecture: 'aarch64',
  });

  assert.equal(
    ios.filename,
    'bundle-video_hw-ios-universal-small-lgpl.xcframework.zip',
  );
  assert.equal(tvos.platform, 'appletvos');
  assert.equal(
    tvos.filename,
    'bundle-video_hw-appletvos-universal-small-lgpl.xcframework.zip',
  );
  assert.equal(
    macos.filename,
    'bundle-video_hw-macos-universal-small-lgpl.xcframework.zip',
  );
  assert.equal(windows.architecture, 'x86_64');
  assert.equal(
    windows.filename,
    'bundle-video_hw-windows-x86_64-shared-small-lgpl.zip',
  );
  assert.equal(linux.architecture, 'arm64');
  assert.equal(
    linux.filename,
    'bundle-video_hw-linux-arm64-shared-small-lgpl.zip',
  );
});

test('maps the legacy streaming type alias to video', () => {
  const {nested} = createApp({type: 'streaming'});
  const result = resolveConfig({appRoot: nested, platform: 'android'});

  assert.equal(result.type, 'video');
  assert.equal(result.filename, 'bundle-video-shared-small-lgpl-release.aar');
});

test('resolves relative local overrides from the consuming app root', () => {
  const {root, nested} = createApp({android: './vendor/custom.aar'});
  const result = resolveConfig({appRoot: nested, platform: 'android'});

  assert.deepEqual(result.override, {
    kind: 'local',
    value: './vendor/custom.aar',
    resolvedPath: path.join(root, 'vendor', 'custom.aar'),
  });
  assert.equal(result.filename, 'custom.aar');
  assert.equal(result.url, null);
  assert.equal(result.cacheKey.length, 16);
});

test('preserves remote overrides and derives their filename', () => {
  const remote = 'https://example.com/releases/custom-bundle.aar?token=abc';
  const {nested} = createApp({android: remote});
  const result = resolveConfig({appRoot: nested, platform: 'android'});

  assert.deepEqual(result.override, {kind: 'remote', value: remote});
  assert.equal(result.filename, 'custom-bundle.aar');
  assert.equal(result.url, remote);
  assert.equal(result.cacheKey.length, 16);
});

test('rejects invalid configuration values', () => {
  const invalidType = createApp({type: 'unknown'});
  assert.throws(
    () => resolveConfig({appRoot: invalidType.nested, platform: 'android'}),
    /Invalid bundle type: unknown/,
  );

  const valid = createApp({type: 'base'});
  assert.throws(
    () => resolveConfig({appRoot: valid.nested, platform: 'beos'}),
    /Invalid platform: beos/,
  );
  assert.throws(
    () =>
      resolveConfig({
        appRoot: valid.nested,
        platform: 'windows',
        architecture: 'mips64',
      }),
    /Unsupported architecture: mips64/,
  );
});

test('rejects malformed config JSON', () => {
  const {nested} = createApp('{not-json');

  assert.throws(
    () => resolveConfig({appRoot: nested, platform: 'android'}),
    /Failed to parse/,
  );
});

test('CLI emits machine-readable resolution JSON in quiet mode', () => {
  const {nested} = createApp({type: 'full', gpl: true, small: false});
  const script = path.resolve(
    __dirname,
    '..',
    'scripts',
    'resolve-ffmpeg-kit-config.js',
  );
  const result = spawnSync(
    process.execPath,
    [script, '--app-root', nested, '--platform', 'android', '--quiet', 'true'],
    {encoding: 'utf8'},
  );

  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stderr, '');
  const resolution = JSON.parse(result.stdout);
  assert.equal(resolution.filename, 'bundle-full-shared-gpl-release.aar');
});

test('CLI fails clearly when the platform argument is missing', () => {
  const script = path.resolve(
    __dirname,
    '..',
    'scripts',
    'resolve-ffmpeg-kit-config.js',
  );
  const result = spawnSync(process.execPath, [script], {encoding: 'utf8'});

  assert.equal(result.status, 1);
  assert.match(result.stderr, /--platform is required/);
});
