#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');

const componentDefinitions = [
  {
    relativePath: path.join(
      'node_modules',
      'react-native',
      'src',
      'private',
      'components',
      'virtualview',
      'VirtualViewNativeComponent.js',
    ),
    unpatchedFactory: `export default codegenNativeComponent<VirtualViewNativeProps>('VirtualView', {
  interfaceOnly: true,
}) as HostComponent<VirtualViewNativeProps>;`,
    patchedFactory: `export default (codegenNativeComponent<VirtualViewNativeProps>('VirtualView', {
  interfaceOnly: true,
}): HostComponent<VirtualViewNativeProps>);`,
  },
  {
    relativePath: path.join(
      'node_modules',
      'react-native',
      'src',
      'private',
      'components',
      'virtualview',
      'VirtualViewExperimentalNativeComponent.js',
    ),
    unpatchedFactory: `export default codegenNativeComponent<VirtualViewExperimentalNativeProps>(
  'VirtualViewExperimental',
  {
    interfaceOnly: true,
  },
) as HostComponent<VirtualViewExperimentalNativeProps>;`,
    patchedFactory: `export default (codegenNativeComponent<VirtualViewExperimentalNativeProps>(
  'VirtualViewExperimental',
  {
    interfaceOnly: true,
  },
): HostComponent<VirtualViewExperimentalNativeProps>);`,
  },
];

function patchVirtualViewComponent(runtimeDirectory, definition) {
  const componentPath = path.join(runtimeDirectory, definition.relativePath);
  const source = fs.readFileSync(componentPath, 'utf8');

  if (source.includes(definition.patchedFactory)) {
    return {changed: false, componentPath};
  }

  if (!source.includes(definition.unpatchedFactory)) {
    throw new Error(
      `Unsupported React Native VirtualView component shape: ${componentPath}`,
    );
  }

  fs.writeFileSync(
    componentPath,
    source.replace(definition.unpatchedFactory, definition.patchedFactory),
    'utf8',
  );
  return {changed: true, componentPath};
}

function patchAppletvosRuntime(runtimeDirectory) {
  const results = componentDefinitions.map(definition =>
    patchVirtualViewComponent(runtimeDirectory, definition),
  );
  return {
    changed: results.some(result => result.changed),
    componentPaths: results.map(result => result.componentPath),
  };
}

if (require.main === module) {
  const runtimeDirectory = process.argv[2];
  if (!runtimeDirectory) {
    console.error('Usage: patch-appletvos-runtime.js <runtime-directory>');
    process.exit(2);
  }

  const result = patchAppletvosRuntime(runtimeDirectory);
  console.log(
    `${result.changed ? 'Patched' : 'Already patched'} tvOS VirtualView codegen compatibility: ${result.componentPaths.join(', ')}`,
  );
}

module.exports = {patchAppletvosRuntime};
