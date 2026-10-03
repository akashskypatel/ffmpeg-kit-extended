[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / FFmpegKitInitializeOptions

# Interface: FFmpegKitInitializeOptions

Options used by `FFmpegKitExtended.initialize()` to configure package startup.
Native targets normally use their bundled runtime and do not need these
options. On Web/Wasm, `assetBaseUrl` overrides the browser directory that
contains the staged runtime assets. A failed initialization can be retried
through `FFmpegKitExtended.initialize()` with corrected options.

## Properties

### assetBaseUrl?

> `optional` **assetBaseUrl?**: `string`

Browser asset directory containing the staged Wasm runtime.
