[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / NativeFFmpegKitExtendedSpec

# Type Alias: NativeFFmpegKitExtendedSpec

> **NativeFFmpegKitExtendedSpec** = `{ [Key in keyof Spec]: Spec[Key] }`

Stable native-only contract for advanced integrations and diagnostics.

This public name is a type-only view backed by the React Native Codegen
`Spec` declaration above. It exposes the complete native method inventory
without adding a JavaScript export or changing Codegen's required `Spec`
pattern. Representative methods include `initialize`,
`createFFmpegSession`, `getSessionJson`, `ffplayPause`, and `clearSessions`.
The runtime module is exported from the native entry point only; Web has no
native module value.
