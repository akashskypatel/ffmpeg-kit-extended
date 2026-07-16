const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

const projectRoot = __dirname;
const libraryRoot = path.resolve(projectRoot, '..');

const config = {
  watchFolders: [
    libraryRoot,
  ],

  resolver: {
    nodeModulesPaths: [
      path.resolve(projectRoot, 'node_modules'),
      path.resolve(libraryRoot, 'node_modules'),
    ],

    // Ensure the example's React/React Native instances are used
    // instead of potentially resolving duplicate copies from the library root.
    extraNodeModules: {
      react: path.resolve(projectRoot, 'node_modules/react'),
      'react-native': path.resolve(projectRoot, 'node_modules/react-native'),
    },
  },
};

module.exports = mergeConfig(
  getDefaultConfig(projectRoot),
  config
);