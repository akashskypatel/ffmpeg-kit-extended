[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / NativeFFmpegKitExtendedLogEvent

# Type Alias: NativeFFmpegKitExtendedLogEvent

> **NativeFFmpegKitExtendedLogEvent** = `object`

Stable consumer-facing type-only view of the structured v2 log event emitted
after the native message is copied. The Codegen `LogEvent` spelling remains
unchanged for React Native's consumer-owned generation contract.

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
