'use strict';

const childProcess = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const {resolveConfig} = require('./resolve-ffmpeg-kit-config.js');
const {ensureArtifact} = require('./download-ffmpeg-kit-artifact.js');

function fail(message) {
  throw new Error(`FFmpegKit [Web]: ${message}`);
}

function parseArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (!key.startsWith('--')) fail(`Unknown argument: ${key}`);
    const value = argv[index + 1];
    if (value === undefined || value.startsWith('--')) fail(`Missing value for ${key}`);
    result[key.slice(2)] = value;
    index += 1;
  }
  return result;
}

function findRuntimeFiles(root) {
  const files = {};
  const visit = directory => {
    for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
      const fullPath = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(fullPath);
      else if (entry.name === 'ffmpegkit.mjs' || entry.name === 'ffmpegkit.wasm') files[entry.name] = fullPath;
    }
  };
  visit(root);
  return files;
}

function extractZip(zipFile, destination) {
  fs.mkdirSync(destination, {recursive: true});
  if (process.platform === 'win32') {
    childProcess.execFileSync('powershell.exe', [
      '-NoProfile', '-NonInteractive', '-Command',
      'Expand-Archive -LiteralPath $args[0] -DestinationPath $args[1] -Force',
      zipFile, destination,
    ], {stdio: 'inherit'});
  } else {
    childProcess.execFileSync('unzip', ['-q', '-o', zipFile, '-d', destination], {stdio: 'inherit'});
  }
}

function artifactCachePath(cacheDir, resolution) {
  return path.join(cacheDir, `${resolution.cacheKey}-${resolution.filename}`);
}

async function main(argv = process.argv.slice(2)) {
  const args = parseArgs(argv);
  const appRoot = path.resolve(args['app-root'] || process.cwd());
  const publicDir = path.resolve(args['public-dir'] || path.join(appRoot, 'public'));
  const target = path.join(publicDir, 'ffmpeg-kit-extended', 'wasm');
  const resolution = resolveConfig({appRoot, platform: 'web'});
  const cacheDir = path.join(appRoot, 'node_modules', '.cache', 'ffmpeg-kit-extended', 'wasm');
  fs.mkdirSync(cacheDir, {recursive: true});

  let sourceRoot;
  let temporaryRoot;
  try {
    if (resolution.override?.kind === 'local') {
      const overridePath = resolution.override.resolvedPath;
      if (!fs.existsSync(overridePath)) {
        fail(`Configured local Web runtime does not exist: ${overridePath}`);
      }
      if (fs.statSync(overridePath).isDirectory()) {
        sourceRoot = overridePath;
      } else {
        temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-web-'));
        extractZip(overridePath, temporaryRoot);
        sourceRoot = temporaryRoot;
      }
    } else {
      const artifact = await ensureArtifact({
        url: resolution.url,
        output: artifactCachePath(cacheDir, resolution),
        checksum: resolution.checksum,
        reuseCached: resolution.override?.kind !== 'remote' || Boolean(resolution.checksum),
        quiet: args.quiet === 'true',
      });
      temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-web-'));
      extractZip(artifact, temporaryRoot);
      sourceRoot = temporaryRoot;
    }

    const runtime = findRuntimeFiles(sourceRoot);
    if (!runtime['ffmpegkit.mjs'] || !runtime['ffmpegkit.wasm']) {
      fail(`Wasm artifact ${resolution.filename} must contain ffmpegkit.mjs and ffmpegkit.wasm`);
    }

    fs.rmSync(target, {recursive: true, force: true});
    fs.mkdirSync(target, {recursive: true});
    for (const name of ['ffmpegkit.mjs', 'ffmpegkit.wasm']) {
      fs.copyFileSync(runtime[name], path.join(target, name));
    }
    const webRoot = path.resolve(__dirname, '..', 'web');
    for (const name of ['ffmpegkit_bridge.mjs', 'ffmpegkit_loader.mjs', 'ffmpegkit_callback_runtime.mjs']) {
      fs.copyFileSync(path.join(webRoot, name), path.join(target, name));
    }
    process.stdout.write(`${JSON.stringify({target, filename: resolution.filename, version: resolution.version})}\n`);
  } finally {
    if (temporaryRoot) fs.rmSync(temporaryRoot, {recursive: true, force: true});
  }
}

if (require.main === module) {
  main().catch(error => {
    console.error(error.message || String(error));
    process.exitCode = 1;
  });
}

module.exports = {artifactCachePath, findRuntimeFiles, main};
