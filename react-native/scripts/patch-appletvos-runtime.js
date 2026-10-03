#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');

const relativeComponentPath = path.join(
  'node_modules',
  'react-native',
  'src',
  'private',
  'components',
  'virtualview',
  'VirtualViewExperimentalNativeComponent.js',
);

const unpatchedFactory = `export default codegenNativeComponent<VirtualViewExperimentalNativeProps>(
  'VirtualViewExperimental',
  {
    interfaceOnly: true,
  },
) as HostComponent<VirtualViewExperimentalNativeProps>;`;

const patchedFactory = `export default (codegenNativeComponent<VirtualViewExperimentalNativeProps>(
  'VirtualViewExperimental',
  {
    interfaceOnly: true,
  },
): HostComponent<VirtualViewExperimentalNativeProps>);`;

function patchAppletvosRuntime(runtimeDirectory) {
  const componentPath = path.join(runtimeDirectory, relativeComponentPath);
  const source = fs.readFileSync(componentPath, 'utf8');

  if (source.includes(patchedFactory)) {
    return {changed: false, componentPath};
  }

  if (!source.includes(unpatchedFactory)) {
    throw new Error(
      `Unsupported React Native VirtualView component shape: ${componentPath}`,
    );
  }

  fs.writeFileSync(
    componentPath,
    source.replace(unpatchedFactory, patchedFactory),
    'utf8',
  );
  return {changed: true, componentPath};
}

if (require.main === module) {
  const runtimeDirectory = process.argv[2];
  if (!runtimeDirectory) {
    console.error('Usage: patch-appletvos-runtime.js <runtime-directory>');
    process.exit(2);
  }

  const result = patchAppletvosRuntime(runtimeDirectory);
  console.log(
    `${result.changed ? 'Patched' : 'Already patched'} tvOS VirtualView codegen compatibility: ${result.componentPath}`,
  );
}

module.exports = {patchAppletvosRuntime};
