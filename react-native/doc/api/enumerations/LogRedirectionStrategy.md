[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / LogRedirectionStrategy

# Enumeration: LogRedirectionStrategy

Native log-printing strategies retained for API compatibility.

Per-session callbacks in React Native are delivered by polling buffered
native logs. Use `FFmpegKitConfig.enableRedirection()` and callback options
for normal application integration.

## Enumeration Members

### AlwaysPrintLogs

> **AlwaysPrintLogs**: `0`

Always print native log messages regardless of callback registration.

***

### NeverPrintLogs

> **NeverPrintLogs**: `4`

Never print native log messages through the native redirection path.

***

### PrintLogsWhenGlobalCallbackNotDefined

> **PrintLogsWhenGlobalCallbackNotDefined**: `2`

Print logs only when no process-wide callback is defined.

***

### PrintLogsWhenNoCallbackDefined

> **PrintLogsWhenNoCallbackDefined**: `1`

Print logs only when the session has no callback.

***

### PrintLogsWhenSessionCallbackNotDefined

> **PrintLogsWhenSessionCallbackNotDefined**: `3`

Print logs only when the individual session has no callback.
