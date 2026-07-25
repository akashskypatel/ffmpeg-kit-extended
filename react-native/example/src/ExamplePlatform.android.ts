import {
  errorCodes,
  isErrorWithCode,
  keepLocalCopy,
  pick,
  types,
} from '@react-native-documents/picker';
import {Dirs, FileSystem, Util} from 'react-native-file-access';

import type {ExamplePlatformServices} from './ExampleApp';

function localPathFromUri(uri: string): string {
  const withoutScheme = uri.replace(/^file:\/\//, '');
  try {
    return decodeURIComponent(withoutScheme);
  } catch {
    return withoutScheme;
  }
}

export const examplePlatform: ExamplePlatformServices = {
  exampleDir: `${Dirs.CacheDir}/ffmpeg_kit_extended_react_native_example`,
  canPickFiles: true,
  canWriteTextFiles: true,
  async ensureDirectory(path) {
    if (!(await FileSystem.exists(path))) {
      await FileSystem.mkdir(path);
    }
  },
  fileExists: path => FileSystem.exists(path),
  async removeFile(path) {
    if (await FileSystem.exists(path)) {
      await FileSystem.unlink(path);
    }
  },
  writeTextFile: (path, contents) => FileSystem.writeFile(path, contents),
  appendTextFile: (path, contents) => FileSystem.appendFile(path, contents),
  basename: path => Util.basename(path),
  async pickLocalFile(videoOnly) {
    try {
      const [picked] = await pick({
        mode: 'import',
        type: videoOnly ? [types.video] : undefined,
      });
      const [copy] = await keepLocalCopy({
        destination: 'cachesDirectory',
        files: [{uri: picked.uri, fileName: picked.name ?? 'picked-media'}],
      });
      if (copy.status !== 'success') {
        throw new Error(copy.copyError);
      }
      return localPathFromUri(copy.localUri);
    } catch (error) {
      if (isErrorWithCode(error) && error.code === errorCodes.OPERATION_CANCELED) {
        return undefined;
      }
      throw error;
    }
  },
};
