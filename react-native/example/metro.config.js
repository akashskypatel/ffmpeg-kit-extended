const path = require('path');
const {
  getDefaultConfig,
  mergeConfig,
} = require('@react-native/metro-config');

const libraryRoot = path.resolve(__dirname, '..');
const exampleNodeModules = path.resolve(__dirname, 'node_modules');

const reactNativePackage =
  process.env.REACT_NATIVE_PLATFORM === 'macos'
    ? 'react-native-macos'
    : 'react-native';

/**
 * The example consumes the plugin source from the parent directory while
 * keeping React and the selected React Native runtime single-instanced.
 *
 * @type {import('metro-config').MetroConfig}
 */
const config = {
  watchFolders: [libraryRoot],

  resolver: {
    disableHierarchicalLookup: true,

    nodeModulesPaths: [exampleNodeModules],

    extraNodeModules: {
      react: path.resolve(exampleNodeModules, 'react'),
      'react-native': path.resolve(
        exampleNodeModules,
        reactNativePackage,
      ),
    },
  },
};

module.exports = mergeConfig(
  getDefaultConfig(__dirname),
  config,
);