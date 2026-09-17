'use strict';

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const packageRoot = path.resolve(__dirname, '..');
const exampleDependencies = path.join(packageRoot, 'example', 'node_modules');
const npmCli = process.env.npm_execpath;

function run(args, cwd) {
  if (npmCli) {
    childProcess.execFileSync(process.execPath, [npmCli, ...args], {cwd, stdio: 'inherit'});
    return;
  }
  childProcess.execFileSync('npm', args, {cwd, stdio: 'inherit'});
}

function write(file, contents) {
  fs.writeFileSync(file, contents, 'utf8');
}

function main() {
  const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-packed-vite-'));
  const packs = path.join(fixture, 'packs');
  fs.mkdirSync(packs);
  try {
    run(['pack', '--ignore-scripts', '--pack-destination', packs], packageRoot);
    const tarballName = fs.readdirSync(packs).find(file => file.endsWith('.tgz'));
    assert.ok(tarballName, 'npm pack did not create a tarball');
    const tarball = path.join(packs, tarballName);
    write(path.join(fixture, 'package.json'), JSON.stringify({
      private: true,
      type: 'module',
      dependencies: {
        'ffmpeg-kit-extended': `file:${tarball}`,
        react: `file:${path.join(exampleDependencies, 'react')}`,
        'react-dom': `file:${path.join(exampleDependencies, 'react-dom')}`,
        'react-native-web': `file:${path.join(exampleDependencies, 'react-native-web')}`,
        vite: `file:${path.join(exampleDependencies, 'vite')}`,
      },
    }, null, 2));
    write(path.join(fixture, 'index.html'), '<div id="root"></div><script type="module" src="/src.js"></script>');
    write(path.join(fixture, 'src.js'), "import {FFmpegKitExtended} from 'ffmpeg-kit-extended';\nconsole.log(FFmpegKitExtended);\n");
    write(path.join(fixture, 'vite.config.js'), "import {defineConfig} from 'vite';\nexport default defineConfig({resolve: {alias: {'react-native': 'react-native-web'}}});\n");

    run(['install', '--ignore-scripts', '--no-audit', '--no-fund', '--no-package-lock', '--legacy-peer-deps'], fixture);
    run(['exec', 'vite', 'build'], fixture);

    const output = fs.readdirSync(path.join(fixture, 'dist', 'assets'))
      .filter(file => file.endsWith('.js'))
      .map(file => fs.readFileSync(path.join(fixture, 'dist', 'assets', file), 'utf8'))
      .join('\n');
    assert.doesNotMatch(output, /NativeFFmpegKitExtended|TurboModuleRegistry/);
    process.stdout.write('Packed Vite consumer build passed.\n');
  } finally {
    fs.rmSync(fixture, {recursive: true, force: true});
  }
}

main();
