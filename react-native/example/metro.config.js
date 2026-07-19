const path = require('path');
const {
  getDefaultConfig,
  mergeConfig,
} = require('@react-native/metro-config');

const libraryRoot = path.resolve(__dirname, '..');
const exampleNodeModules = path.resolve(__dirname, 'node_modules');

/**
 * Metro configuration
 *
 * The example consumes source files directly from the parent library.
 * Force both the library and example app to share the example app's
 * React and React Native runtime instances.
 *
 * @type {import('metro-config').MetroConfig}
 */
const config = {
  watchFolders: [
    libraryRoot,
  ],

  resolver: {
    // Do not let imports from ../src resolve against
    // ../node_modules before reaching example/node_modules.
    disableHierarchicalLookup: true,

    nodeModulesPaths: [
      exampleNodeModules,
    ],

    extraNodeModules: {
      react: path.resolve(
        exampleNodeModules,
        'react',
      ),
      'react-native': path.resolve(
        exampleNodeModules,
        'react-native',
      ),
    },
  },
};

module.exports = mergeConfig(
  getDefaultConfig(__dirname),
  config,
);