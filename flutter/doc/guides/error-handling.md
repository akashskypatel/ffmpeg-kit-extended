# Error Handling Guide

Reliable error handling is critical when dealing with complex media operations. This guide explains how to detect, analyze, and resolve errors.

## Table of Contents

- [Return Codes](#return-codes)
- [Async Future errors versus terminal return codes](#async-future-errors-versus-terminal-return-codes)
- [Analyzing Logs](#analyzing-logs)
- [Session Failures](#session-failures)
- [Common Error Patterns](#common-error-patterns)
- [Debugging Strategies](#debugging-strategies)

## Return Codes

The `ReturnCode` is the primary way to check if a command finished successfully.

```dart
final session = FFmpegKit.execute(command);
final code = session.getReturnCode();

if (ReturnCode.isSuccess(code)) {
  // Command finished with exit code 0
} else if (ReturnCode.isCancel(code)) {
  // Command was stopped by the user (255)
} else {
  // Other error code (usually 1)
}
```

## Async Future errors versus terminal return codes

Return codes describe a native execution that reached a terminal session state.
An asynchronous Future can instead reject before a normal terminal result is
available, for example when a queued execution is cancelled before startup,
when admission or lifecycle validation fails, or when startup/state/backend or
cleanup ownership fails.

```dart
try {
  final session = await FFmpegKit.executeAsync(command);

  if (ReturnCode.isSuccess(session.getReturnCode())) {
    // Native execution reached a successful terminal state.
  } else if (ReturnCode.isCancel(session.getReturnCode())) {
    // Native execution reached a cancelled terminal state.
  }
} on SessionCancelledException {
  // Queue/pre-start execution was cancelled before a terminal native result.
} on StateError {
  // Common examples include admission, disposal, or lifecycle failures.
} catch (error) {
  // Other startup, state, backend, or cleanup failure propagated by the Future.
}
```

When native execution is already running, cancellation may produce a terminal
session with a cancel return code. That is different from
`SessionCancelledException`, which is the Future error for queue/pre-start
cancellation. Install callbacks for observation, but still await and handle
the returned Future when startup or execution failures matter to the caller.

## Analyzing Logs

FFmpeg provides detailed textual logs. These are essential for finding out *why* a command failed.

```dart
final logs = session.getLogs();

if (logs != null) {
  if (logs.contains('No such file or directory')) {
    print('Check your input/output paths.');
  } else if (logs.contains('Conversion failed!')) {
    print('Encoding error - check your codec settings.');
  }
}
```

### Real-time Log Monitoring

During execution, you can monitor logs as they come in:

```dart
FFmpegKit.executeAsync(
  command,
  onLog: (log) {
    if (log.logLevel == LogLevel.error) {
      print('FFmpeg Error: ${log.message}');
    }
  }
);
```

## Session Failures

If a session fails to even start or crashes in the native layer, you can retrieve the stack trace:

```dart
final stackTrace = session.getFailStackTrace();
if (stackTrace != null) {
  print('Native Crash Detected: $stackTrace');
}
```

## Common Error Patterns

### 1. File Not Found

- **Symptoms**: Return code 1, logs contain `No such file or directory`.
- **Cause**: Relative paths used in Flutter, or lack of storage permissions.
- **Fix**: Use absolute paths (`File(path).absolute.path`) and check permissions.

### 2. Invalid Argument

- **Symptoms**: Return code 1, logs contain `Invalid argument` or `Error splitting the argument list`.
- **Cause**: Spaces in file names not being escaped, or incorrect flag syntax.
- **Fix**: Use `FFmpegKitConfig.parseArguments(command)` to verify how the command is being interpreted.

### 3. Output File Already Exists

- **Symptoms**: FFmpeg hangs or fails.
- **Cause**: FFmpeg by default asks for confirmation to overwrite.
- **Fix**: Add the `-y` global flag to overwrite automatically: `FFmpegKit.execute('-y -i input.mp4 output.mp4');`

## Debugging Strategies

### 1. Enable Full Redirection

Redirect all native stdout/stderr to the Flutter console:

```dart
FFmpegKitConfig.enableRedirection();
```

### 2. Increase Log Level

Get more verbose output from FFmpeg:

```dart
FFmpegKitConfig.setLogLevel(LogLevel.debug);
```

### 3. Test in Terminal

Copy the command output from `session.getCommand()` and try running it in a standard terminal (CMD/Bash) with a standalone `ffmpeg` binary. This helps isolate if the issue is with the command syntax or the plugin integration.

### 4. Check Return Code vs. Output

Sometimes FFmpeg finishes with code 0 (success) but produce a zero-byte file or an unplayable file. Always verify the output file exists and has a non-zero size after completion.
