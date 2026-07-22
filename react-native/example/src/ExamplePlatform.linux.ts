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
    // /tmp is available on the Linux host. Generated media is kept directly in
    // the system temporary directory so the unified example needs no extra
    // filesystem dependency in the isolated React Native Skia runtime.
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
    // The shared UI keeps logs in memory on Linux.
  },
  async appendTextFile() {
    // The shared UI keeps logs in memory on Linux.
  },
  basename,
  async pickLocalFile() {
    return undefined;
  },
};
