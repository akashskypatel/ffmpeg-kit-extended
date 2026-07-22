const path = require('path');
const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

const runtimeRoot = __dirname;
const exampleRoot = path.resolve(runtimeRoot, '..');
const libraryRoot = path.resolve(exampleRoot, '..');
const runtimeNodeModules = path.resolve(runtimeRoot, 'node_modules');

const config = {
  projectRoot: exampleRoot,
  watchFolders: [libraryRoot],
  resolver: {
    disableHierarchicalLookup: true,
    nodeModulesPaths: [runtimeNodeModules],
    extraNodeModules: {
      react: path.resolve(runtimeNodeModules, 'react'),
      'react-native': path.resolve(runtimeNodeModules, 'react-native'),
      'react-native-macos': path.resolve(runtimeNodeModules, 'react-native-macos'),
      'ffmpeg-kit-extended': path.resolve(runtimeNodeModules, 'ffmpeg-kit-extended'),
    },
  },
};

module.exports = mergeConfig(getDefaultConfig(exampleRoot), config);
