# FFmpegKit API Reference

The `FFmpegKit` class provides a convenient interface for executing FFmpeg commands in your Flutter application.

## Overview

`FFmpegKit` is the primary class for video and audio processing operations. It allows you to:

- Execute FFmpeg commands synchronously or asynchronously
- Monitor execution progress through callbacks
- Manage and track FFmpeg sessions
- Cancel running operations

## Class Methods

### execute

Executes an FFmpeg command synchronously (blocking).

```dart
static FFmpegSession execute(String command)
```

**Parameters:**

- `command` (String): The FFmpeg command to execute (without the `ffmpeg` prefix)

**Returns:**

- `FFmpegSession`: A session object containing execution results

**Example:**

```dart
final session = FFmpegKit.execute('-i input.mp4 -c:v libx264 output.mp4');

if (ReturnCode.isSuccess(session.getReturnCode())) {
  print('Success!');
} else {
  print('Failed: ${session.getOutput()}');
}
```

---

### executeAsync

Executes an FFmpeg command asynchronously (non-blocking).

```dart
static Future<FFmpegSession> executeAsync(
  String command, {
  FFmpegSessionCompleteCallback? onComplete,
  FFmpegLogCallback? onLog,
  FFmpegStatisticsCallback? onStatistics,
})
```

**Parameters:**

- `command` (String): The FFmpeg command to execute
- `onComplete` (FFmpegSessionCompleteCallback?, optional): Callback invoked when execution completes
- `onLog` (FFmpegLogCallback?, optional): Callback invoked for each log message
- `onStatistics` (FFmpegStatisticsCallback?, optional): Callback invoked for statistics updates

**Returns:**

- `Future<FFmpegSession>`: A Future that completes with the session object

**Example:**

```dart
await FFmpegKit.executeAsync(
  '-i input.mp4 -vf scale=1280:720 output.mp4',
  onComplete: (session) {
    print('Completed with code: ${session.getReturnCode()}');
  },
  onLog: (log) {
    print('[${log.logLevel}] ${log.message}');
  },
  onStatistics: (stats) {
    print('Frame: ${stats.videoFrameNumber}, Speed: ${stats.speed}x');
  },
);
```

---

### cancel

Cancels a running FFmpeg session.

```dart
static void cancel(FFmpegSession session)
```

**Parameters:**

- `session` (FFmpegSession): The session to cancel

**Example:**

```dart
final session = FFmpegKit.execute('-i input.mp4 output.mp4');
// ... later
FFmpegKit.cancel(session);
```

---

### createSession

Creates a new FFmpeg session without executing it.

```dart
static FFmpegSession createSession(String command)
```

**Parameters:**

- `command` (String): The FFmpeg command for the session

**Returns:**

- `FFmpegSession`: A new session object (not yet executed)

**Example:**

```dart
final session = FFmpegKit.createSession('-i input.mp4 output.mp4');
// Configure or inspect the session before execution
// ... then execute it manually if needed
```

---

### getLastFFmpegSession

Returns the most recently executed FFmpeg session.

```dart
static FFmpegSession? getLastFFmpegSession()
```

**Returns:**

- `FFmpegSession?`: The last session, or null if no sessions have been executed

**Example:**

```dart
final lastSession = FFmpegKit.getLastFFmpegSession();
if (lastSession != null) {
  print('Last command: ${lastSession.getCommand()}');
  print('Return code: ${lastSession.getReturnCode()}');
}
```

---

### getFFmpegSessions

Returns all active FFmpeg sessions.

```dart
static List<FFmpegSession> getFFmpegSessions()
```

**Returns:**

- `List<FFmpegSession>`: A list of all active sessions

**Example:**

```dart
final sessions = FFmpegKit.getFFmpegSessions();
print('Active sessions: ${sessions.length}');

for (final session in sessions) {
  print('Session ${session.getSessionId()}: ${session.getState()}');
}
```

## Callback Types

### FFmpegSessionCompleteCallback

Called when an FFmpeg session completes.

```dart
typedef FFmpegSessionCompleteCallback = void Function(FFmpegSession session);
```

**Example:**

```dart
void onComplete(FFmpegSession session) {
  final code = session.getReturnCode();
  if (ReturnCode.isSuccess(code)) {
    print('Success!');
  } else if (ReturnCode.isCancel(code)) {
    print('Cancelled');
  } else {
    print('Failed with code: $code');
  }
}
```

---

### FFmpegLogCallback

Called for each log message emitted by FFmpeg.

```dart
typedef FFmpegLogCallback = void Function(Log log);
```

**Example:**

```dart
void onLog(Log log) {
  // Filter by log level
  if (log.logLevel == LogLevel.error) {
    print('ERROR: ${log.message}');
  }
}
```

---

### FFmpegStatisticsCallback

Called periodically with encoding/decoding statistics.

```dart
typedef FFmpegStatisticsCallback = void Function(Statistics statistics);
```

**Example:**

```dart
void onStatistics(Statistics stats) {
  final progressPercent = (stats.time / totalDuration) * 100;
  print('Progress: ${progressPercent.toStringAsFixed(1)}%');
  print('Speed: ${stats.speed}x');
  print('Bitrate: ${stats.bitrate} kbps');
}
```

## Common Use Cases

### Video Conversion

```dart
final session = FFmpegKit.execute(
  '-i input.mp4 -c:v libx264 -preset medium -crf 23 output.mp4'
);
```

### Video Compression

```dart
await FFmpegKit.executeAsync(
  '-i input.mp4 -vf scale=1280:720 -c:v libx264 -crf 28 compressed.mp4',
  onStatistics: (stats) {
    print('Compressing... ${stats.speed}x speed');
  },
);
```

### Extract Audio from Video

```dart
FFmpegKit.execute('-i video.mp4 -vn -acodec copy audio.aac');
```

### Trim Video

```dart
// Extract 10 seconds starting at 00:00:30
FFmpegKit.execute('-i input.mp4 -ss 00:00:30 -t 10 -c copy output.mp4');
```

### Add Watermark

```dart
FFmpegKit.execute(
  '-i video.mp4 -i watermark.png '
  '-filter_complex "overlay=W-w-10:H-h-10" '
  'output.mp4'
);
```

### Concatenate Videos

```dart
// Create a file list first
final fileList = 'file1.mp4\nfile2.mp4\nfile3.mp4';
// Then concatenate
FFmpegKit.execute('-f concat -safe 0 -i filelist.txt -c copy output.mp4');
```

### Convert to GIF

```dart
FFmpegKit.execute(
  '-i input.mp4 -vf "fps=10,scale=320:-1:flags=lanczos" '
  '-c:v gif output.gif'
);
```

### Extract Frames

```dart
// Extract one frame per second
FFmpegKit.execute('-i video.mp4 -vf fps=1 frame_%04d.png');
```

## Error Handling

Always check the return code and handle errors appropriately:

```dart
final session = FFmpegKit.execute('-i input.mp4 output.mp4');

final returnCode = session.getReturnCode();

if (ReturnCode.isSuccess(returnCode)) {
  print('Command executed successfully');
} else if (ReturnCode.isCancel(returnCode)) {
  print('Command was cancelled');
} else {
  print('Command failed with return code: $returnCode');
  print('Output: ${session.getOutput()}');
  print('Logs: ${session.getLogs()}');
  
  // Check for specific errors in logs
  final logs = session.getLogs() ?? '';
  if (logs.contains('No such file')) {
    print('Input file not found');
  } else if (logs.contains('Invalid')) {
    print('Invalid command or parameters');
  }
}
```

## Best Practices

1. **Use Async for Long Operations**: For operations that take more than a few seconds, use `executeAsync` to avoid blocking the UI.

2. **Monitor Progress**: Use the statistics callback to show progress to users:

   ```dart
   await FFmpegKit.executeAsync(
     command,
     onStatistics: (stats) {
       setState(() {
         progress = stats.time / totalDuration;
       });
     },
   );
   ```

3. **Handle Cancellation**: Allow users to cancel long-running operations:

   ```dart
   FFmpegSession? currentSession;
   
   void startConversion() {
     currentSession = FFmpegKit.execute(command);
   }
   
   void cancelConversion() {
     if (currentSession != null) {
       FFmpegKit.cancel(currentSession!);
     }
   }
   ```

4. **Check File Paths**: Ensure input files exist and output paths are writable before executing commands.

5. **Use Appropriate Presets**: Choose FFmpeg presets based on your needs:
   - `ultrafast`: Fastest encoding, larger file size
   - `medium`: Balanced (default)
   - `slow` or `veryslow`: Best compression, slower encoding

## See Also

- [FFmpegSession API](sessions.md) - Session management details
- [Video Processing Guide](../guides/video-processing.md) - Common video operations
- [Callbacks Guide](../guides/callbacks.md) - Working with callbacks
- [Error Handling Guide](../guides/error-handling.md) - Comprehensive error handling
