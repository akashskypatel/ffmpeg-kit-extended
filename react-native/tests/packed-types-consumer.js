'use strict';

const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const ts = require('typescript');

const packageRoot = path.resolve(__dirname, '..');
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

function resolveTypes(fixture, conditions) {
  const containingFile = path.join(fixture, 'src', 'index.ts');
  const result = ts.resolveModuleName(
    'ffmpeg-kit-extended',
    containingFile,
    {
      module: ts.ModuleKind.ESNext,
      moduleResolution: ts.ModuleResolutionKind.Bundler,
      customConditions: conditions,
    },
    ts.sys,
  );
  assert.ok(result.resolvedModule, `TypeScript could not resolve ${conditions.join(', ')}`);
  return result.resolvedModule.resolvedFileName;
}

function assertQueueMarkerIsNotConsumerCallable(fixture) {
  const contracts = [
    {
      name: 'queue-marker-contract.ts',
      source: [
        "import {FFmpegSession} from 'ffmpeg-kit-extended';",
        "const session = new FFmpegSession(1, '-version');",
        'session.markCancelledBeforeExecution();',
        '',
      ].join('\n'),
      message: 'the queue-only cancellation marker must not be callable from packed consumer types',
    },
    {
      name: 'queue-marker-subclass-contract.ts',
      source: [
        "import {FFmpegSession} from 'ffmpeg-kit-extended';",
        'class ConsumerDerivedSession extends FFmpegSession {',
        '  forceQueueOnlyCancel(): void {',
        '    this.markCancelledBeforeExecution();',
        '  }',
        '}',
        '',
      ].join('\n'),
      message: 'the queue-only cancellation marker must not be callable from consumer subclasses',
    },
  ];

  for (const contract of contracts) {
    const contractFile = path.join(fixture, 'src', contract.name);
    write(contractFile, contract.source);
    const program = ts.createProgram([contractFile], {
      module: ts.ModuleKind.ESNext,
      moduleResolution: ts.ModuleResolutionKind.Bundler,
      customConditions: ['react-native'],
      strict: true,
      skipLibCheck: true,
      noEmit: true,
    });
    const diagnostics = ts.getPreEmitDiagnostics(program);
    assert.ok(
      diagnostics.some((diagnostic) =>
        ts
          .flattenDiagnosticMessageText(diagnostic.messageText, ' ')
          .includes('markCancelledBeforeExecution'),
      ),
      contract.message,
    );
  }
}

function assertQueueMarkerIsNotRuntimeCallable() {
  const emittedSession = path.join(packageRoot, 'lib', 'module', 'session.js');
  assert.ok(fs.existsSync(emittedSession), 'Run npm run prepare before runtime contract checks');
  const source = fs.readFileSync(emittedSession, 'utf8');
  assert.doesNotMatch(
    source,
    /(?:\.|\[['"])markCancelledBeforeExecution(?:['"]\])?/,
    'the emitted Session runtime must not expose an ordinary marker property',
  );
}

function main() {
  const declaration = path.join(packageRoot, 'lib', 'typescript', 'src', 'index.d.ts');
  assert.ok(fs.existsSync(declaration), 'Run npm run prepare before npm run test:pack-types');

  const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-packed-types-'));
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
      },
    }, null, 2));
    fs.mkdirSync(path.join(fixture, 'src'));
    write(
      path.join(fixture, 'src', 'index.ts'),
      "import {FFmpegKitExtended} from 'ffmpeg-kit-extended';\nvoid FFmpegKitExtended;\n",
    );

    run([
      'install',
      '--ignore-scripts',
      '--no-audit',
      '--no-fund',
      '--no-package-lock',
      '--legacy-peer-deps',
    ], fixture);

    const installedDeclaration = path.join(
      fixture,
      'node_modules',
      'ffmpeg-kit-extended',
      'lib',
      'typescript',
      'src',
      'index.d.ts',
    );
    for (const conditions of [['react-native'], ['browser', 'react-native']]) {
      const resolved = resolveTypes(fixture, conditions);
      assert.equal(
        fs.realpathSync.native(resolved),
        fs.realpathSync.native(installedDeclaration),
        `Unexpected declaration for conditions: ${conditions.join(', ')}`,
      );
      assert.doesNotMatch(resolved, /[/\\]src[/\\]index(?:\.web)?\.ts$/);
    }
    assertQueueMarkerIsNotConsumerCallable(fixture);
    assertQueueMarkerIsNotRuntimeCallable();
    process.stdout.write('Packed TypeScript declaration consumer passed.\n');
  } finally {
    fs.rmSync(fixture, {recursive: true, force: true});
  }
}

main();
