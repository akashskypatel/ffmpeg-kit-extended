const assert = require('node:assert/strict');
const { after, test } = require('node:test');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

const temporaryRoots = [];
const powershell = process.env.POWERSHELL_BINARY ||
  (process.platform === 'win32' ? 'powershell.exe' : 'pwsh');
const powershellAvailable = spawnSync(
  powershell,
  ['-NoProfile', '-Command', 'exit 0'],
  { encoding: 'utf8' },
).status === 0;

function createTemporaryRoot() {
  const directory = fs.mkdtempSync(
    path.join(os.tmpdir(), 'ffk27-windows-runtime-'),
  );
  temporaryRoots.push(directory);
  return directory;
}

function createRuntimeDirectory(root, files) {
  for (const [relativePath, contents] of Object.entries(files)) {
    const file = path.join(root, relativePath);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, contents);
  }
}

function powershellLiteral(value) {
  return `'${value.replaceAll("'", "''")}'`;
}

function createZip(source, archive) {
  const command = [
    '& { param([string]$source, [string]$archive);',
    '$items = @(Get-ChildItem -LiteralPath $source -Force | Select-Object -ExpandProperty FullName);',
    'Compress-Archive -LiteralPath $items -DestinationPath $archive -Force }',
    powershellLiteral(source),
    powershellLiteral(archive),
  ].join(' ');
  const result = spawnSync(
    powershell,
    ['-NoProfile', '-Command', command],
    {
      encoding: 'utf8',
      env: { ...process.env, FFK27_PROCESS_TAG: 'R27-P2-create-zip' },
    },
  );
  assert.equal(result.status, 0, result.stderr || result.stdout);
}

function prepareRuntime({ appRoot, destination, cacheRoot }) {
  return spawnSync(
    powershell,
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      path.join(root, 'scripts', 'prepare-windows-runtime.ps1'),
      '-Architecture',
      'x64',
      '-Destination',
      destination,
      '-AppRoot',
      appRoot,
      '-CacheRoot',
      cacheRoot,
    ],
    {
      encoding: 'utf8',
      maxBuffer: 4 * 1024 * 1024,
      env: { ...process.env, FFK27_PROCESS_TAG: 'R27-P2-prepare-runtime' },
    },
  );
}

function writeWindowsConfig(appRoot, override) {
  fs.writeFileSync(
    path.join(appRoot, 'ffmpeg-kit-extended.config.json'),
    JSON.stringify({ windows: override }),
  );
}

function stagedDlls(destination) {
  return fs.readdirSync(destination)
    .filter((file) => file.toLowerCase().endsWith('.dll'))
    .sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
}

after(() => {
  for (const directory of temporaryRoots.splice(0)) {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('Windows runtime deployment uses the project-reference copy contract', () => {
  const project = read(
    'windows/FFmpegKitExtended/FFmpegKitExtended.vcxproj',
  );

  assert.doesNotMatch(project, /<PropertyGroup Label="OutputPaths">/);
  assert.match(project, /FFmpegKitExtendedRuntimeStagingDir/);
  assert.match(project, /GetCopyToOutputDirectoryItemsDependsOn/);
  assert.match(project, /ContentWithTargetPath/);
  assert.doesNotMatch(project, /<CustomOutputGroupForPackagingDependsOn>/);
  assert.doesNotMatch(project, /<CustomOutputGroupForPackagingOutput/);
  assert.match(project, /CopyToOutputDirectory>PreserveNewest/);
  assert.match(project, /DestinationFolder="\$\(TargetDir\)"/);
});

test('Nested Windows example does not mask consumer deployment behavior', () => {
  const appProject = read(
    'example/windows/FFmpegKitExtendedExample/FFmpegKitExtendedExample.vcxproj',
  );
  const packageProject = read(
    'example/windows/FFmpegKitExtendedExample.Package/FFmpegKitExtendedExample.Package.wapproj',
  );
  const buildScript = read('build.sh');

  assert.doesNotMatch(appProject, /StageFFmpegKitExtendedWindowsRuntime/);
  assert.doesNotMatch(appProject, /<OutDir>/);
  assert.doesNotMatch(appProject, /<IntDir>/);
  assert.doesNotMatch(packageProject, /<PropertyGroup Label="OutputPaths">/);
  assert.doesNotMatch(packageProject, /build\\runtime\\\$\(Platform\)/);
  assert.doesNotMatch(buildScript, /runtime_stage_dir=/);
});

test('PowerShell staging refreshes same-path archives and removes stale DLLs', {
  skip: !powershellAvailable,
}, () => {
  const rootDirectory = createTemporaryRoot();
  const appRoot = path.join(rootDirectory, 'app');
  const sourceA = path.join(rootDirectory, 'source-a');
  const sourceB = path.join(rootDirectory, 'source-b');
  const archive = path.join(rootDirectory, 'runtime.zip');
  const destination = path.join(rootDirectory, 'staged');
  const cacheRoot = path.join(rootDirectory, 'cache');
  fs.mkdirSync(appRoot, { recursive: true });

  createRuntimeDirectory(sourceA, {
    'libffmpegkit.dll': 'A-main',
    'avcodec.dll': 'A-codec',
  });
  createZip(sourceA, archive);
  writeWindowsConfig(appRoot, archive);

  let result = prepareRuntime({ appRoot, destination, cacheRoot });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.deepEqual(stagedDlls(destination), ['avcodec.dll', 'libffmpegkit.dll']);

  createRuntimeDirectory(sourceB, {
    'libffmpegkit.dll': 'B-main',
    'avutil.dll': 'B-util',
  });
  createZip(sourceB, archive);
  result = prepareRuntime({ appRoot, destination, cacheRoot });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.deepEqual(stagedDlls(destination), ['avutil.dll', 'libffmpegkit.dll']);
  assert.equal(fs.readFileSync(path.join(destination, 'libffmpegkit.dll'), 'utf8'), 'B-main');
  assert.equal(fs.existsSync(path.join(destination, 'avcodec.dll')), false);
});

test('PowerShell staging rejects invalid runtime DLL manifests', {
  skip: !powershellAvailable,
}, () => {
  const cases = [
    {
      name: 'missing main DLL',
      files: { 'avcodec.dll': 'dependency' },
      message: /exactly one libffmpegkit\.dll; found 0/i,
    },
    {
      name: 'duplicate main DLL',
      files: {
        'one/libffmpegkit.dll': 'one',
        'two/LIBFFMPEGKIT.DLL': 'two',
      },
      message: /duplicate flattened DLL basenames/i,
    },
    {
      name: 'duplicate flattened basename',
      files: {
        'one/libffmpegkit.dll': 'main',
        'one/foo.dll': 'one',
        'two/foo.dll': 'two',
      },
      message: /duplicate flattened DLL basenames/i,
    },
  ];

  for (const testCase of cases) {
    const rootDirectory = createTemporaryRoot();
    const appRoot = path.join(rootDirectory, 'app');
    const source = path.join(rootDirectory, 'source');
    const archive = path.join(rootDirectory, `${testCase.name}.zip`);
    const destination = path.join(rootDirectory, 'staged');
    const cacheRoot = path.join(rootDirectory, 'cache');
    fs.mkdirSync(appRoot, { recursive: true });
    createRuntimeDirectory(source, testCase.files);
    createZip(source, archive);
    writeWindowsConfig(appRoot, archive);

    const result = prepareRuntime({ appRoot, destination, cacheRoot });
    assert.notEqual(result.status, 0, testCase.name);
    assert.match(`${result.stdout}\n${result.stderr}`, testCase.message);
  }
});

test('PowerShell staging refreshes a mutable local runtime directory', {
  skip: !powershellAvailable,
}, () => {
  const rootDirectory = createTemporaryRoot();
  const appRoot = path.join(rootDirectory, 'app');
  const source = path.join(rootDirectory, 'runtime');
  const destination = path.join(rootDirectory, 'staged');
  const cacheRoot = path.join(rootDirectory, 'cache');
  fs.mkdirSync(appRoot, { recursive: true });
  createRuntimeDirectory(source, {
    'libffmpegkit.dll': 'main',
    'old.dll': 'old',
  });
  writeWindowsConfig(appRoot, source);

  let result = prepareRuntime({ appRoot, destination, cacheRoot });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.deepEqual(stagedDlls(destination), ['libffmpegkit.dll', 'old.dll']);

  fs.rmSync(path.join(source, 'old.dll'));
  fs.writeFileSync(path.join(source, 'new.dll'), 'new');
  result = prepareRuntime({ appRoot, destination, cacheRoot });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.deepEqual(stagedDlls(destination), ['libffmpegkit.dll', 'new.dll']);
});
