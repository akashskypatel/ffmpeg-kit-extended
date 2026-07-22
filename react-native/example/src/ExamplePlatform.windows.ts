import {NativeModules} from 'react-native';

import type {ExamplePlatformServices} from './ExampleApp';

type NativeExamplePlatform = {
  getExampleDirectory(): string;
  ensureDirectory(path: string): void;
  fileExists(path: string): boolean;
  removeFile(path: string): void;
  writeTextFile(path: string, contents: string): void;
  appendTextFile(path: string, contents: string): void;
  basename(path: string): string;
  pickLocalFile(videoOnly: boolean): string;
};

const NativePlatform = NativeModules
  .FFmpegKitExtendedExamplePlatform as NativeExamplePlatform;

export const examplePlatform: ExamplePlatformServices = {
  exampleDir: NativePlatform.getExampleDirectory(),
  canPickFiles: true,
  canWriteTextFiles: true,
  async ensureDirectory(path) {
    NativePlatform.ensureDirectory(path);
  },
  async fileExists(path) {
    return NativePlatform.fileExists(path);
  },
  async removeFile(path) {
    NativePlatform.removeFile(path);
  },
  async writeTextFile(path, contents) {
    NativePlatform.writeTextFile(path, contents);
  },
  async appendTextFile(path, contents) {
    NativePlatform.appendTextFile(path, contents);
  },
  basename: path => NativePlatform.basename(path),
  async pickLocalFile(videoOnly) {
    return NativePlatform.pickLocalFile(videoOnly) || undefined;
  },
};
