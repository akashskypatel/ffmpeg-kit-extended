import createFFmpegKit from './ffmpegkit.mjs';

globalThis.ffmpegKitExtendedModulePromise ??= createFFmpegKit({
  locateFile: (file) => new URL(file, import.meta.url).href,
});
