[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / NativeFFmpegKitExtended

# Variable: NativeFFmpegKitExtended

> **NativeFFmpegKitExtended**: `Spec`

Enforced native module instance. Importing the package on a host where the
native library was not linked causes React Native to report a missing module
rather than silently returning `null`.

## Remarks

This export exists on native `src/index.ts` only and is intentionally
absent from `src/index.web.ts`. Prefer the high-level wrappers for
cross-platform application code.
