# Session Queue Management

## Overview

FFmpegKit Extended provides an automated session queue management system to handle concurrent execution requests efficiently. While the underlying FFmpegKit C API uses mutex locking (limiting how many sessions can run at once based on CPU and memory), the `SessionQueueManager` at the Dart layer ensures system resources are not over-allocated by enforcing a configurable concurrency limit.

## Parallel Execution with Concurrency Limits

The updated `SessionQueueManager` has moved away from complex "strategies" to a simpler, more robust model:

1. **Parallel by Default**: All sessions submitted via `executeAsync` are treated as parallel tasks.
2. **Concurrency Gate**: The manager keeps track of active sessions and ensures that only a specific number of sessions (default: 8) execute simultaneously.
3. **Automatic Queuing**: If the concurrency limit is reached, new session requests are automatically queued and processed as soon as an active session completes.

## Configuring Concurrency

You can adjust the maximum number of concurrent sessions globally via `FFmpegKitConfig`:

```dart
// Set the maximum number of sessions that can run at once
FFmpegKitConfig.setMaxConcurrentSessions(4);

// Get the current limit
int limit = FFmpegKitConfig.getMaxConcurrentSessions();
```

**Recommended Settings:**

- **Low-end devices**: 1-2 concurrent sessions.
- **Mid-range devices**: 4-8 concurrent sessions.
- **High-end devices/Desktop**: 8-16 concurrent sessions.

## Execution Model

### Simple Execution

When you call `executeAsync`, the session is added to the internal queue and scheduled for execution.

```dart
// These sessions will run in parallel up to the maxConcurrentSessions limit
FFmpegKit.executeAsync("-i input1.mp4 -c:v libx264 output1.mp4");
FFmpegKit.executeAsync("-i input2.mp4 -c:v libx264 output2.mp4");
FFmpegKit.executeAsync("-i input3.mp4 -c:v libx264 output3.mp4");
```

### Resource Management

By limiting concurrent sessions, FFmpegKit Extended prevents:

- **OOM (Out of Memory) crashes**: Multiple high-resolution encodes can consume vast amounts of RAM.
- **CPU Starvation**: Prevents the UI from becoming unresponsive due to 100% CPU usage by background tasks.
- **Battery Drain**: Managing thread count helps in preserving battery life on mobile devices.

## Using the SessionQueueManager

### Accessing the Queue Manager

The `SessionQueueManager` is a singleton:

```dart
final queueManager = SessionQueueManager();
```

### Monitoring Status

```dart
// Check if the system is at full capacity
if (queueManager.isBusy) {
  print("Working at maximum concurrency");
}

// Get count of currently running sessions
print("Active sessions: ${queueManager.activeSessionCount}");

// Get count of sessions waiting in queue
print("Queued sessions: ${queueManager.queueLength}");
```

### Canceling Sessions

```dart
// Cancel the "current" session (most recent one added to active list)
queueManager.cancelCurrent();

// Clear all queued sessions (throws SessionCancelledException for each)
queueManager.clearQueue();

// Cancel everything (current running sessions and all queued ones)
queueManager.cancelAll();
```

### Waiting for Completion

```dart
// Wait for all active and queued sessions to complete
await queueManager.waitForAll();
print("All tasks finished!");
```

## Practical Example: Batch Processor

```dart
class BatchProcessor {
  Future<void> processBatch(List<String> paths) async {
    // Limit to 2 concurrent tasks for heavy transcoding
    FFmpegKitConfig.setMaxConcurrentSessions(2);
    
    for (final path in paths) {
      FFmpegKit.executeAsync(
        "-i $path -c:v libx264 ${path}_out.mp4",
        onComplete: (session) => print("Finished $path"),
      );
    }
    
    // Wait for everything to finish
    await SessionQueueManager().waitForAll();
  }
}
```

## API Reference

### SessionQueueManager

| Method / Property | Description |
| --- | --- |
| `maxConcurrentSessions` | Gets/Sets the concurrency limit (default 8). |
| `activeSessionCount` | Number of sessions currently executing. |
| `queueLength` | Number of sessions waiting for an available slot. |
| `isBusy` | Returns true if any sessions are active or queued. |
| `cancelCurrent()` | Cancels the latest active session. |
| `clearQueue()` | Removes all sessions from the waiting queue. |
| `cancelAll()` | Cancels all active and waiting sessions. |
| `waitForAll()` | Returns a Future that completes when the queue is empty. |

### Exceptions

- **SessionCancelledException**: Thrown when a session is removed from the queue before it could start (via `clearQueue` or `cancelAll`).

## Migration from Previous Versions

Previous versions used `SessionExecutionStrategy` (queue, cancelAndReplace, parallel). These have been removed for simplicity:

### Before

```dart
FFmpegKit.executeAsync(cmd, strategy: SessionExecutionStrategy.queue);
```

### After

```dart
// Just call it. Parallel execution with queuing is now the standard behavior.
FFmpegKit.executeAsync(cmd);
```

If you previously used `cancelAndReplace`, you should now manually cancel the previous session if needed:

```dart
// Old cancelAndReplace behavior
SessionQueueManager().cancelAll();
FFmpegKit.executeAsync(newCommand);
```

## See Also

- [FFmpegKit API Reference](../api/ffmpeg-kit.md)
- [FFprobeKit API Reference](../api/ffprobe-kit.md)
- [Error Handling Guide](error-handling.md)
