/**
 * Public entry point for `ffmpeg-kit-extended`.
 *
 * Initialize the native library once near application startup before creating
 * or executing sessions:
 *
 * ```ts
 * import {FFmpegKitExtended, FFmpegKit} from 'ffmpeg-kit-extended';
 *
 * FFmpegKitExtended.initialize();
 * const session = await FFmpegKit.executeAsync('-version');
 * ```
 *
 * Most applications should use the high-level `FFmpegKit`, `FFprobeKit`,
 * `FFplayKit`, `FFplayView`, and session classes. `NativeFFmpegKitExtended` is
 * exported for advanced integration and diagnostics, but its JSON/scalar API
 * is lower level and does not provide the lifecycle safeguards of the wrappers.
 */
export {default as NativeFFmpegKitExtended} from './NativeFFmpegKitExtended';
export * from './arguments';
export * from './ffmpeg-kit';
export * from './ffmpeg-kit-config';
export * from './ffmpeg-kit-extended';
export * from './ffplay-kit';
export * from './ffprobe-kit';
export * from './media-information';
export * from './session';
export * from './session-queue-manager';
export * from './types';
export * from './ffplay-view';
