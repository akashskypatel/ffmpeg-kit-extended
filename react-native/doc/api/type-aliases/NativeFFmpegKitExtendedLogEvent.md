[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / NativeFFmpegKitExtendedLogEvent

# Type Alias: NativeFFmpegKitExtendedLogEvent

> **NativeFFmpegKitExtendedLogEvent** = `object`

Stable consumer-facing type-only view of the structured v2 log event emitted
after the native message is copied. The native Codegen payload remains an
internal implementation contract while this public type uses ordinary
JavaScript numeric values.

## Properties

### level

> **level**: `number`

Native log severity.

***

### message

> **message**: `string`

Managed log message text.

***

### sequence

> **sequence**: `number`

Monotonic native insertion sequence for the entry.

***

### sessionId

> **sessionId**: `number`

Native process identity associated with the log entry.
