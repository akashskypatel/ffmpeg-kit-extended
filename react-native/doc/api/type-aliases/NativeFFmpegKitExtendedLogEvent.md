[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / NativeFFmpegKitExtendedLogEvent

# Type Alias: NativeFFmpegKitExtendedLogEvent

> **NativeFFmpegKitExtendedLogEvent** = `object`

Structured v2 log payload emitted after the native message is copied.
`sequence` is the native insertion order. The bridge owns and releases the
native payload before exposing this managed string to JavaScript.

## Properties

### level

> **level**: `Int32`

Native log severity.

***

### message

> **message**: `string`

Managed log message text.

***

### sequence

> **sequence**: `Double`

Monotonic native insertion sequence for the entry.

***

### sessionId

> **sessionId**: `Double`

Native process identity associated with the log entry.
