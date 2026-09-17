const path = require('node:path');
const react = require('@vitejs/plugin-react');

module.exports = {
  root: __dirname,
  publicDir: path.resolve(__dirname, '..', 'public'),
  plugins: [react()],
  resolve: {
    alias: [
      {find: 'react-native', replacement: require.resolve('react-native-web')},
    ],
  },
  server: {
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    },
  },
  build: {
    outDir: path.resolve(__dirname, '..', 'build', 'web'),
    emptyOutDir: true,
  },
};
