const path = require('path');
const {
  getDefaultConfig,
  mergeConfig,
} = require('@react-native/metro-config');

const libraryRoot = path.resolve(__dirname, '..');
const exampleNodeModules = path.resolve(__dirname, 'node_modules');
const reactNativePlatform = process.env.REACT_NATIVE_PLATFORM;
const reactNativeNodeModules =
  reactNativePlatform === 'appletvos'
    ? path.resolve(__dirname, '.appletvos-runtime', 'node_modules')
    : exampleNodeModules;
const defaultConfig = getDefaultConfig(__dirname);

const reactNativePackage =
  reactNativePlatform === 'macos' ? 'react-native-macos' : 'react-native';

/**
 * The example consumes the plugin source from the parent directory while
 * keeping React and the selected React Native runtime single-instanced.
 *
 * @type {import('metro-config').MetroConfig}
 */
const resolver = {
  disableHierarchicalLookup: true,

  nodeModulesPaths: [reactNativeNodeModules],

  extraNodeModules: {
    react: path.resolve(reactNativeNodeModules, 'react'),
    'react-native': path.resolve(
      reactNativeNodeModules,
      reactNativePackage,
    ),
  },
};

if (reactNativePlatform === 'macos') {
  resolver.platforms = ['android', 'ios', 'macos'];
}
if (reactNativePlatform === 'appletvos') {
  resolver.sourceExts = defaultConfig.resolver.sourceExts.flatMap(ext => [
    `tv.${ext}`,
    ext,
  ]);
}

const config = {
  watchFolders: [libraryRoot],
  resolver,
};

module.exports = mergeConfig(
  defaultConfig,
  config,
);
