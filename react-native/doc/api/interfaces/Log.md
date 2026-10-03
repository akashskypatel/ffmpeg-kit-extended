[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / Log

# Interface: Log

One native log message emitted by a session.

## Properties

### level

> **level**: `number`

Numeric FFmpeg log level; compare with `LogLevel` when applicable.

***

### message

> **message**: `string`

Message text exactly as buffered by the native wrapper.

***

### sessionId

> **sessionId**: `number`

ID of the session that emitted this message.
