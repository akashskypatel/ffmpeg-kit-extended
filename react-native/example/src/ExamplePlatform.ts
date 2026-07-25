import type {ExamplePlatformServices} from './ExampleApp';

/**
 * Fallback used only by tooling that does not apply React Native platform
 * extension resolution. Metro resolves ExamplePlatform.android.ts,
 * ExamplePlatform.ios.ts, or ExamplePlatform.macos.ts at runtime.
 */
export const examplePlatform: ExamplePlatformServices = {
  exampleDir: '/tmp',
  canPickFiles: false,
  canWriteTextFiles: false,
  async ensureDirectory() {},
  async fileExists() {
    return false;
  },
  async removeFile() {},
  async writeTextFile() {},
  async appendTextFile() {},
  basename(path) {
    const normalized = path.replace(/\\/g, '/').replace(/\/+$/, '');
    const slash = normalized.lastIndexOf('/');
    return slash >= 0 ? normalized.slice(slash + 1) : normalized;
  },
  async pickLocalFile() {
    return undefined;
  },
};
