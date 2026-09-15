const path = require('node:path');
const react = require('@vitejs/plugin-react');
const packageRoot = path.resolve(__dirname, '..', '..');
const webBackend = `/@fs/${path.join(packageRoot, 'src', 'platform', 'backend.web.ts').replaceAll('\\', '/')}`;
const webBackendFile = path.join(packageRoot, 'src', 'platform', 'backend.web.ts');
const backend = path.join(packageRoot, 'src', 'platform', 'backend.ts');
const nativeBackend = path.join(packageRoot, 'src', 'platform', 'backend.native.ts');
const backendNoExtension = backend.slice(0, -3);
const nativeBackendNoExtension = nativeBackend.slice(0, -3);

module.exports = {
  root: __dirname,
  publicDir: path.resolve(__dirname, '..', 'public'),
  plugins: [
    react(),
    {
      name: 'resolve-react-native-web-platform-files',
      resolveId(source, importer) {
        if (
          importer &&
          (source.endsWith('/platform/backend') ||
            source.endsWith('/platform/backend.ts') ||
            source.endsWith('/platform/backend.native') ||
            source.endsWith('/platform/backend.native.ts'))
        ) {
          return webBackendFile;
        }
        return null;
      },
      load(id) {
        const file = id.split('?')[0].replaceAll('\\', '/');
        if (file.endsWith('/src/platform/backend.ts')) {
          return "export {getBackend} from './backend.web.ts';";
        }
        return null;
      },
      transform(code, id) {
        const file = id.split('?')[0].replaceAll('\\', '/');
        if (
          file.endsWith('/src/platform/backend.ts') ||
          code.includes("export {getBackend} from './backend.native';")
        ) {
          return code.replace("export {getBackend} from './backend.native';", "export {getBackend} from './backend.web';");
        }
        return null;
      },
    },
  ],
  resolve: {
    alias: [
      {find: 'react-native', replacement: require.resolve('react-native-web')},
      {find: 'ffmpeg-kit-extended', replacement: path.join(packageRoot, 'src', 'index.web.ts')},
      {find: backend, replacement: webBackend},
      {find: nativeBackend, replacement: webBackend},
      {find: backendNoExtension, replacement: webBackend},
      {find: nativeBackendNoExtension, replacement: webBackend},
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
