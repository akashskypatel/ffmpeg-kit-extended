import {FFprobeKit, ReturnCode} from 'ffmpeg-kit-extended';

import type {ExamplePlatformServices} from './ExampleApp';

const EXAMPLE_DIR = '/tmp';

function basename(path: string): string {
  const normalized = path.replace(/\\/g, '/').replace(/\/+$/, '');
  const slash = normalized.lastIndexOf('/');
  return slash >= 0 ? normalized.slice(slash + 1) : normalized;
}

export const examplePlatform: ExamplePlatformServices = {
  exampleDir: EXAMPLE_DIR,
  canPickFiles: false,
  canWriteTextFiles: false,
  async ensureDirectory() {
    // /tmp is available to the tvOS app sandbox. Keep generated media directly in
    // the system temporary directory because this JS-only platform adapter has
    // no filesystem dependency capable of creating a nested directory.
  },
  async fileExists(path) {
    try {
      const session = await FFprobeKit.getMediaInformation(path, 1000);
      return session.getReturnCode() === ReturnCode.Success;
    } catch {
      return false;
    }
  },
  async removeFile() {
    // Generated and transcoded commands use -y, which truncates/replaces outputs.
  },
  async writeTextFile() {
    // The shared UI keeps logs in memory on Apple tvOS.
  },
  async appendTextFile() {
    // The shared UI keeps logs in memory on Apple tvOS.
  },
  basename,
  async pickLocalFile() {
    return undefined;
  },
};
