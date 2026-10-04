const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const {
  patchAppletvosRuntime,
} = require('../scripts/patch-appletvos-runtime.js');

const virtualViewSources = {
  'VirtualViewNativeComponent.js': `export default codegenNativeComponent<VirtualViewNativeProps>('VirtualView', {
  interfaceOnly: true,
}) as HostComponent<VirtualViewNativeProps>;`,
  'VirtualViewExperimentalNativeComponent.js': `export default codegenNativeComponent<VirtualViewExperimentalNativeProps>(
  'VirtualViewExperimental',
  {
    interfaceOnly: true,
  },
) as HostComponent<VirtualViewExperimentalNativeProps>;`,
};

test('patches the disposable tvOS runtime VirtualView codegen cast idempotently', () => {
  const temporaryRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), 'ffmpeg-kit-appletvos-runtime-'),
  );
  const componentDirectory = path.join(
    temporaryRoot,
    'node_modules',
    'react-native',
    'src',
    'private',
    'components',
    'virtualview',
  );
  const devtoolsDirectory = path.join(
    temporaryRoot,
    'node_modules',
    'react-native',
    'src',
    'private',
    'devsupport',
    'rndevtools',
  );

  try {
    fs.mkdirSync(componentDirectory, {recursive: true});
    for (const [fileName, source] of Object.entries(virtualViewSources)) {
      fs.writeFileSync(
        path.join(componentDirectory, fileName),
        `${source}\n`,
        'utf8',
      );
    }
    fs.mkdirSync(devtoolsDirectory, {recursive: true});
    const devtoolsSource = '// iOS React DevTools settings implementation\n';
    fs.writeFileSync(
      path.join(devtoolsDirectory, 'ReactDevToolsSettingsManager.ios.js'),
      devtoolsSource,
      'utf8',
    );

    const first = patchAppletvosRuntime(temporaryRoot);
    assert.equal(first.changed, true);
    const patchedSources = Object.keys(virtualViewSources).map(fileName =>
      fs.readFileSync(path.join(componentDirectory, fileName), 'utf8'),
    );
    assert.match(patchedSources[0], /export default \(codegenNativeComponent/);
    assert.match(patchedSources[0], /\): HostComponent<VirtualViewNativeProps>\);/);
    assert.match(patchedSources[1], /export default \(codegenNativeComponent/);
    assert.match(
      patchedSources[1],
      /\): HostComponent<VirtualViewExperimentalNativeProps>\);/,
    );
    assert.equal(
      fs.readFileSync(
        path.join(devtoolsDirectory, 'ReactDevToolsSettingsManager.tvos.js'),
        'utf8',
      ),
      devtoolsSource,
    );

    const second = patchAppletvosRuntime(temporaryRoot);
    assert.equal(second.changed, false);
    assert.deepEqual(
      Object.keys(virtualViewSources).map(fileName =>
        fs.readFileSync(path.join(componentDirectory, fileName), 'utf8'),
      ),
      patchedSources,
    );
  } finally {
    fs.rmSync(temporaryRoot, {recursive: true, force: true});
  }
});
