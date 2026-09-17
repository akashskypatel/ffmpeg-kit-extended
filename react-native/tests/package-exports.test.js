'use strict';

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {test} = require('node:test');

const packageRoot = path.resolve(__dirname, '..');
const packageJson = JSON.parse(fs.readFileSync(path.join(packageRoot, 'package.json'), 'utf8'));

function resolvePackage(conditions) {
  const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-exports-'));
  try {
    const nodeModules = path.join(fixture, 'node_modules');
    fs.mkdirSync(nodeModules);
    fs.symlinkSync(packageRoot, path.join(nodeModules, 'ffmpeg-kit-extended'), 'junction');

    const args = conditions.map(condition => `--conditions=${condition}`);
    args.push(
      '--input-type=module',
      '--eval',
      'process.stdout.write(import.meta.resolve("ffmpeg-kit-extended"));',
    );
    return childProcess.execFileSync(process.execPath, args, {
      cwd: fixture,
      encoding: 'utf8',
    });
  } finally {
    fs.rmSync(fixture, {recursive: true, force: true});
  }
}

test('conditional exports select the web or native entry by runtime conditions', () => {
  assert.match(
    resolvePackage(['react-native', 'browser']),
    /[/\\]src[/\\]index\.web\.ts$/,
  );
  assert.match(
    resolvePackage(['react-native']),
    /[/\\]src[/\\]index\.ts$/,
  );
  assert.match(
    resolvePackage(['browser']),
    /[/\\]src[/\\]index\.web\.ts$/,
  );
});

test('conditional exports prioritize the built declaration entry', () => {
  assert.deepEqual(
    Object.keys(packageJson.exports['.']),
    ['types', 'browser', 'react-native', 'default'],
  );
});
