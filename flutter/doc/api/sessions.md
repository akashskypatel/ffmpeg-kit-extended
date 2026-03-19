# Sessions

Sessions are the core abstraction for executing FFmpeg, FFprobe, and FFplay commands. Every execution in FFmpeg Kit Extended Flutter is tracked as a session.

## Session Types

There are three primary session types, all inheriting from the base `Session` class:

- **FFmpegSession**: Used for video and audio processing (FFmpeg commands).
- **FFprobeSession**: Used for extracting media metadata (FFprobe commands).
- **FFplaySession**: Used for media playback (FFplay commands).
- **MediaInformationSession**: A specialized `FFprobeSession` optimized for `MediaInformation` retrieval.

## Session Lifecycle

A session goes through several states during its lifecycle:

1. **Created**: The session object exists but execution hasn't started.
2. **Running**: The command is currently being executed.
3. **Completed**: Execution finished normally (success or failure).
4. **Failed**: Execution failed due to an error.

### SessionState Enum

```dart
enum SessionState {
  created,
  running,
  completed,
  failed,
}
```

## Base Session Methods

All session types provide the following methods:

- `getSessionId()`: Returns the unique identifier for the session.
- `getState()`: Returns the current `SessionState`.
- `getCommand()`: Returns the command associated with the session.
- `getReturnCode()`: Returns the exit code (available after completion).
- `getOutput()`: Returns the full console output of the session.
- `getLogs()`: Returns the session logs as a single string.
- `getFailStackTrace()`: Returns the stack trace if the session failed.
- `getStartTime()` / `getEndTime()`: Returns execution timestamps.
- `getDuration()`: Returns total execution time in milliseconds.
- `cancel()`: Terminates the session if it is currently running.

## Session Identification

You can identify the specific type of a session using these methods:

- `isFFmpegSession()`
- `isFFprobeSession()`
- `isFFplaySession()`
- `isMediaInformationSession()`

---

## FFmpegSession

An `FFmpegSession` is specifically for processing tasks. It supports progress tracking through statistics.

### FFmpegSession Features

- **Statistics**: Access real-time encoding stats via `onStatistics` when using `executeAsync`.
- **Logs**: Access detailed processing logs.

---

## FFprobeSession

An `FFprobeSession` is for metadata extraction.

### FFprobeSession Features

- **MediaInformation**: If the session is a `MediaInformationSession`, you can use `getMediaInformation()` to retrieve structured metadata.

---

## FFplaySession

An `FFplaySession` represents a playback instance.

### FFplaySession Features

- **Playback Control**: While `FFplayKit` provides global controls, individual `FFplaySession` objects also expose methods for `pause()`, `resume()`, and `stop()`.
- **Playback Stats**: Monitor current playback position and duration.

## Return Codes

The return code indicates why a session finished:

- `ReturnCode.success` (0): Execution finished successfully.
- `ReturnCode.cancel` (255): Execution was cancelled by the user.
- **Other values**: Indicate various FFmpeg/system error codes.

Check success using:

```dart
if (ReturnCode.isSuccess(session.getReturnCode())) {
  // Operation succeeded
}
```
