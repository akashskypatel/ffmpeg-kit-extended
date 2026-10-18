const path = require('path');

const babelPreset =
  process.env.REACT_NATIVE_PLATFORM === 'appletvos'
    ? require.resolve('@react-native/babel-preset', {
        paths: [path.resolve(__dirname, '.appletvos-runtime', 'node_modules')],
      })
    : 'module:@react-native/babel-preset';

module.exports = {presets: [babelPreset]};
