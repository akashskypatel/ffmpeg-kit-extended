[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / LogLevel

# Enumeration: LogLevel

FFmpeg-compatible native log levels, ordered from least to most verbose.

## Enumeration Members

### Debug

> **Debug**: `48`

Debug output useful while diagnosing commands or integrations.

***

### Error

> **Error**: `16`

Processing errors.

***

### Fatal

> **Fatal**: `8`

Fatal errors that prevent the command from continuing.

***

### Info

> **Info**: `32`

Normal informational output.

***

### Panic

> **Panic**: `0`

Unrecoverable conditions that may terminate processing immediately.

***

### Quiet

> **Quiet**: `-8`

Disable native log output.

***

### Stderr

> **Stderr**: `-16`

Redirect only messages written to stderr.

***

### Trace

> **Trace**: `56`

Maximum native trace verbosity.

***

### Verbose

> **Verbose**: `40`

Additional operational detail.

***

### Warning

> **Warning**: `24`

Warnings that may not stop execution.
