#!/usr/bin/env node

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');

const [packageRoot, destination] = process.argv.slice(2);

if (!packageRoot || !destination) {
  console.error('Usage: pack-local-package.js <package-root> <destination>');
  process.exit(2);
}

const packageJsonPath = path.join(packageRoot, 'package.json');
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
const stageRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-package-'));
const packageStage = path.join(stageRoot, 'package');
const archiveName = `${packageJson.name.replaceAll('/', '-')}-${packageJson.version}.tgz`;
const archivePath = path.join(destination, archiveName);

function copyEntry(relativePath) {
  const source = path.join(packageRoot, relativePath);
  if (!fs.existsSync(source)) {
    return;
  }

  const target = path.join(packageStage, relativePath);
  fs.mkdirSync(path.dirname(target), {recursive: true});
  fs.cpSync(source, target, {recursive: true, dereference: true});
}

try {
  fs.mkdirSync(packageStage, {recursive: true});
  fs.mkdirSync(destination, {recursive: true});
  copyEntry('package.json');

  for (const entry of packageJson.files ?? []) {
    if (entry === '*.podspec') {
      for (const file of fs.readdirSync(packageRoot)) {
        if (file.endsWith('.podspec')) {
          copyEntry(file);
        }
      }
      continue;
    }
    copyEntry(entry);
  }

  fs.rmSync(archivePath, {force: true});
  const tar =
    process.platform === 'win32'
      ? path.join(
          process.env.SystemRoot ?? 'C:\\Windows',
          'System32',
          'tar.exe',
        )
      : 'tar';
  const result = spawnSync(
    tar,
    ['-czf', archivePath, '-C', stageRoot, 'package'],
    {stdio: 'inherit', windowsHide: true},
  );
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0 || !fs.existsSync(archivePath)) {
    throw new Error(`tar failed with exit code ${result.status}`);
  }

  process.stdout.write(`${archiveName}\n`);
} finally {
  fs.rmSync(stageRoot, {recursive: true, force: true});
}
