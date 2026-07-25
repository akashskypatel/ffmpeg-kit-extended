const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

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
