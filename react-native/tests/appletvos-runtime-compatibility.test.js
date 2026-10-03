const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const {
  patchAppletvosRuntime,
} = require('../scripts/patch-appletvos-runtime.js');

const virtualViewSource = `export default codegenNativeComponent<VirtualViewExperimentalNativeProps>(
  'VirtualViewExperimental',
  {
    interfaceOnly: true,
  },
) as HostComponent<VirtualViewExperimentalNativeProps>;`;

test('patches the disposable tvOS runtime VirtualView codegen cast idempotently', () => {
  const temporaryRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), 'ffmpeg-kit-appletvos-runtime-'),
  );
  const componentPath = path.join(
    temporaryRoot,
    'node_modules',
    'react-native',
    'src',
    'private',
    'components',
    'virtualview',
    'VirtualViewExperimentalNativeComponent.js',
  );

  try {
    fs.mkdirSync(path.dirname(componentPath), {recursive: true});
    fs.writeFileSync(componentPath, `${virtualViewSource}\n`, 'utf8');

    const first = patchAppletvosRuntime(temporaryRoot);
    assert.equal(first.changed, true);
    const patchedSource = fs.readFileSync(componentPath, 'utf8');
    assert.match(
      patchedSource,
      /export default \(codegenNativeComponent<VirtualViewExperimentalNativeProps>\(/,
    );
    assert.match(
      patchedSource,
      /\): HostComponent<VirtualViewExperimentalNativeProps>\);/,
    );

    const second = patchAppletvosRuntime(temporaryRoot);
    assert.equal(second.changed, false);
    assert.equal(fs.readFileSync(componentPath, 'utf8'), patchedSource);
  } finally {
    fs.rmSync(temporaryRoot, {recursive: true, force: true});
  }
});
