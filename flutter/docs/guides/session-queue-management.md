# Session Queue Management

## Overview

FFmpegKit Extended provides a powerful session queue management system to handle concurrent execution requests. The underlying FFmpegKit C API uses mutex locking, which means only one session (FFmpeg, FFprobe, or FFplay) can execute at a time. The `SessionQueueManager` enforces this constraint at the Dart layer, providing better control and preventing blocking or deadlocks.

## Why Session Queue Management?

The FFmpegKit C API (`ffmpeg_lib.c`, `ffprobe_lib.c`, `ffplay_lib.c`) uses mutex locks to protect global state. This means:

- **Only one session can execute at a time** across all session types
- **Concurrent execution attempts** will block until the current session completes
- **Without proper management**, this can lead to UI freezes or unexpected behavior

The Session Queue Manager solves these issues by:

- Providing explicit control over how concurrent sessions are handled
- Offering multiple strategies for different use cases
- Preventing accidental blocking on the UI thread
- Enabling queue inspection and management

## Execution Strategies

The `SessionExecutionStrategy` enum defines three strategies for handling concurrent session requests:

### 1. Queue (Default)

Sessions are queued and executed sequentially in the order they were submitted.

```dart
// All three sessions will execute one after another
FFmpegKit.executeAsync(
  "-i input1.mp4 -c:v libx264 output1.mp4",
  strategy: SessionExecutionStrategy.queue, // Default
);

FFmpegKit.executeAsync(
  "-i input2.mp4 -c:v libx264 output2.mp4",
  strategy: SessionExecutionStrategy.queue,
);

FFmpegKit.executeAsync(
  "-i input3.mp4 -c:v libx264 output3.mp4",
  strategy: SessionExecutionStrategy.queue,
);
```

**Use when:**

- You want all operations to complete
- Order of execution matters
- You're batch processing multiple files

### 2. Cancel and Replace

Cancels the currently running session and any queued sessions, then executes the new session immediately.

```dart
// Start a long-running transcode
FFmpegKit.executeAsync(
  "-i large_video.mp4 -c:v libx264 -preset slow output.mp4",
  strategy: SessionExecutionStrategy.queue,
);

await Future.delayed(Duration(seconds: 2));

// User changes their mind - cancel the above and start a new one
FFmpegKit.executeAsync(
  "-i different_video.mp4 -c:v libx264 -preset ultrafast output.mp4",
  strategy: SessionExecutionStrategy.cancelAndReplace,
);
```

**Use when:**

- User initiates a new action that supersedes the current one
- You want to implement "cancel and retry" functionality
- Latest request is most important

### 3. Reject If Busy

Throws a `SessionBusyException` if a session is already running.

```dart
try {
  // Try to start a session
  await FFmpegKit.executeAsync(
    "-i input.mp4 -c:v libx264 output.mp4",
    strategy: SessionExecutionStrategy.rejectIfBusy,
  );
} catch (e) {
  if (e is SessionBusyException) {
    // Handle the busy state - maybe show a message to the user
    print("A session is already running. Please wait.");
  }
}
```

**Use when:**

- You want to prevent concurrent operations explicitly
- You need to inform users that an operation is in progress
- You're implementing a "one at a time" workflow

## Using the SessionQueueManager

### Accessing the Queue Manager

The `SessionQueueManager` is a singleton that manages all session execution:

```dart
final queueManager = SessionQueueManager();
```

### Checking Queue Status

```dart
// Check if a session is currently executing
if (queueManager.isBusy) {
  print("A session is running");
}

// Get the number of queued sessions
print("Queued sessions: ${queueManager.queueLength}");

// Get the currently executing session
final currentSession = queueManager.currentSession;
if (currentSession != null) {
  print("Current session ID: ${currentSession.sessionId}");
}
```

### Canceling Sessions

```dart
// Cancel the currently executing session
queueManager.cancelCurrent();

// Clear all queued sessions (doesn't affect the current session)
queueManager.clearQueue();

// Cancel everything - current session and queue
queueManager.cancelAll();
```

### Waiting for Completion

```dart
// Wait for the current session to complete
await queueManager.waitForCurrent();

// Wait for all sessions (current + queued) to complete
await queueManager.waitForAll();
```

## Practical Examples

### Example 1: Video Processing Queue

```dart
class VideoProcessor {
  final queueManager = SessionQueueManager();
  
  Future<void> processVideos(List<String> videoPaths) async {
    for (final path in videoPaths) {
      FFmpegKit.executeAsync(
        "-i $path -c:v libx264 -preset fast ${path}_processed.mp4",
        strategy: SessionExecutionStrategy.queue,
        onComplete: (session) {
          if (ReturnCode.isSuccess(session.getReturnCode())) {
            print("Processed: $path");
          }
        },
      );
    }
    
    // Wait for all to complete
    await queueManager.waitForAll();
    print("All videos processed!");
  }
}
```

### Example 2: Real-time Preview with Cancel

```dart
class VideoPreview {
  Future<void> updatePreview(String videoPath, String filterCommand) async {
    // Cancel any existing preview generation
    await FFmpegKit.executeAsync(
      "-i $videoPath $filterCommand -f null -",
      strategy: SessionExecutionStrategy.cancelAndReplace,
      onStatistics: (stats) {
        // Update preview in real-time
        updateUI(stats);
      },
    );
  }
}
```

### Example 3: Single-Operation Enforcement

```dart
class SingleTaskProcessor {
  Future<bool> startProcessing(String command) async {
    try {
      await FFmpegKit.executeAsync(
        command,
        strategy: SessionExecutionStrategy.rejectIfBusy,
      );
      return true;
    } on SessionBusyException {
      // Show user feedback
      showSnackbar("Another operation is in progress");
      return false;
    }
  }
}
```

### Example 4: Mixed Session Types

```dart
// Queue works across all session types
FFmpegKit.executeAsync(
  "-i video.mp4 -c:v libx264 output.mp4",
  strategy: SessionExecutionStrategy.queue,
);

// This will wait for the FFmpeg session to complete
FFprobeKit.executeAsync(
  "-i video.mp4",
  strategy: SessionExecutionStrategy.queue,
  onComplete: (session) {
    final mediaInfo = session.getMediaInformation();
    print("Duration: ${mediaInfo?.duration}");
  },
);
```

## Best Practices

### 1. Use Async Execution for Long Operations

```dart
// ✅ Good - Non-blocking
FFmpegKit.executeAsync(
  "-i large_file.mp4 -c:v libx264 output.mp4",
  strategy: SessionExecutionStrategy.queue,
);

// ❌ Avoid - Blocks the UI thread
FFmpegKit.execute(
  "-i large_file.mp4 -c:v libx264 output.mp4",
  strategy: SessionExecutionStrategy.queue,
);
```

### 2. Choose the Right Strategy

- **Queue**: Default choice for most scenarios
- **CancelAndReplace**: User-initiated actions that supersede previous ones
- **RejectIfBusy**: When you need explicit control and user feedback

### 3. Monitor Queue Status

```dart
// Show queue status to users
StreamBuilder(
  stream: Stream.periodic(Duration(milliseconds: 500)),
  builder: (context, snapshot) {
    final manager = SessionQueueManager();
    return Text(
      'Processing: ${manager.isBusy ? "Yes" : "No"}\n'
      'Queued: ${manager.queueLength}',
    );
  },
);
```

### 4. Handle Exceptions

```dart
try {
  await FFmpegKit.executeAsync(
    command,
    strategy: SessionExecutionStrategy.rejectIfBusy,
  );
} on SessionBusyException catch (e) {
  // Handle busy state
  print(e.message);
} on SessionCancelledException catch (e) {
  // Handle cancellation
  print(e.message);
}
```

## API Reference

### SessionExecutionStrategy

```dart
enum SessionExecutionStrategy {
  /// Queue the session for execution
  queue,
  
  /// Cancel current session and execute immediately
  cancelAndReplace,
  
  /// Throw exception if a session is running
  rejectIfBusy,
}
```

### SessionQueueManager

```dart
class SessionQueueManager {
  /// Singleton instance
  factory SessionQueueManager();
  
  /// Currently executing session
  Session? get currentSession;
  
  /// Number of queued sessions
  int get queueLength;
  
  /// Whether a session is currently executing
  bool get isBusy;
  
  /// Cancel the current session
  void cancelCurrent();
  
  /// Clear all queued sessions
  void clearQueue();
  
  /// Cancel current and clear queue
  void cancelAll();
  
  /// Wait for current session to complete
  Future<void> waitForCurrent();
  
  /// Wait for all sessions to complete
  Future<void> waitForAll();
}
```

### Exceptions

```dart
/// Thrown when rejectIfBusy strategy is used and a session is running
class SessionBusyException implements Exception {
  final String message;
}

/// Thrown when a session is cancelled from the queue
class SessionCancelledException implements Exception {
  final String message;
}
```

## Migration Guide

If you're upgrading from a version without session queue management:

### Before

```dart
// Sessions could block or behave unexpectedly
FFmpegKit.executeAsync("-i input1.mp4 output1.mp4");
FFmpegKit.executeAsync("-i input2.mp4 output2.mp4");
```

### After

```dart
// Explicit control over execution
FFmpegKit.executeAsync(
  "-i input1.mp4 output1.mp4",
  strategy: SessionExecutionStrategy.queue, // Default
);

FFmpegKit.executeAsync(
  "-i input2.mp4 output2.mp4",
  strategy: SessionExecutionStrategy.queue,
);
```

The default behavior is `SessionExecutionStrategy.queue`, so existing code will continue to work but with better reliability.

## See Also

- [FFmpegKit API Reference](api/ffmpeg_kit.md)
- [FFprobeKit API Reference](api/ffprobe_kit.md)
- [Session Management Guide](guides/session-management.md)
- [Error Handling Guide](guides/error-handling.md)
