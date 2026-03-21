# FFplayKit API Reference

The `FFplayKit` class provides a convenient interface for media playback using FFplay.

## Overview

`FFplayKit` manages a single global FFplay session for media playback. Since FFplay typically involves a single active playback window, this class provides:

- Simple playback control (play, pause, resume, stop)
- Seek functionality
- Position and duration tracking

**Important**: Only one FFplay session can be active at a time. Starting a new session automatically replaces any existing one.

## Class Methods

### execute

Starts playback asynchronously with the specified command.

```dart
static Future<FFplaySession> execute(String command)
```

**Parameters:**

- `command` (String): The FFplay command to execute (without the `ffplay` prefix)

**Returns:**

- `Future<FFplaySession>`: A Future that completes with the session

**Example:**

```dart
// Play a video file
final session = await FFplayKit.execute('video.mp4');

// Play with custom options
await FFplayKit.execute('-loop 0 video.mp4'); // Loop playback
```

---

### executeAsync

Starts playback asynchronously with an optional completion callback.

```dart
static Future<FFplaySession> executeAsync(
  String command, {
  FFplaySessionCompleteCallback? onComplete,
})
```

**Parameters:**

- `command` (String): The FFplay command to execute
- `onComplete` (FFplaySessionCompleteCallback?, optional): Callback when playback ends

**Returns:**

- `Future<FFplaySession>`: A Future that completes with the session

**Example:**

```dart
await FFplayKit.executeAsync(
  'video.mp4',
  onComplete: (session) {
    print('Playback finished');
    print('Return code: ${session.getReturnCode()}');
  },
);
```

---

### createSession

Creates a new FFplay session without starting playback. Call `FFplayKit.start()` to begin execution.

```dart
static Future<FFplaySession> createSession(
  String command, {
  FFplaySessionCompleteCallback? onComplete,
})
```

**Parameters:**

- `command` (String): The FFplay command for the session
- `onComplete` (FFplaySessionCompleteCallback?, optional): Completion callback

**Returns:**

- `Future<FFplaySession>`: A Future that completes with the new session

**Example:**

```dart
final session = await FFplayKit.createSession(
  'video.mp4',
  onComplete: (session) => print('Done'),
);
// Start playback later
FFplayKit.start();
```

---

### Playback Control Methods

#### start

Starts or resumes playback.

```dart
static void start()
```

**Example:**

```dart
FFplayKit.start();
```

---

#### pause

Pauses playback.

```dart
static void pause()
```

**Example:**

```dart
FFplayKit.pause();
```

---

#### resume

Resumes playback if paused.

```dart
static void resume()
```

**Example:**

```dart
FFplayKit.resume();
```

---

#### stop

Stops playback and closes the session.

```dart
static void stop()
```

**Example:**

```dart
FFplayKit.stop();
```

---

#### seek

Seeks to a specific position in the media.

```dart
static void seek(double seconds)
```

**Parameters:**

- `seconds` (double): The position to seek to in seconds

**Example:**

```dart
// Seek to 30 seconds
FFplayKit.seek(30.0);

// Seek to 1 minute 30 seconds
FFplayKit.seek(90.0);
```

---

### Position and Duration Methods

#### getPosition

Gets the current playback position in seconds. Returns `0.0` if no active session.

```dart
static double getPosition()
```

**Returns:**

- `double`: Current position in seconds

**Example:**

```dart
final position = FFplayKit.getPosition();
print('Current position: ${position.toStringAsFixed(1)}s');
```

---

#### setPosition

Sets the playback position (same as seek).

```dart
static void setPosition(double seconds)
```

**Parameters:**

- `seconds` (double): The position to set in seconds

**Example:**

```dart
FFplayKit.setPosition(45.0);
```

---

#### getDuration

Gets the total duration of the media in seconds. Returns `0.0` if unavailable.

```dart
static double getDuration()
```

**Returns:**

- `double`: Total duration in seconds

**Example:**

```dart
final duration = FFplayKit.getDuration();
print('Total duration: ${duration.toStringAsFixed(1)}s');
```

---

### State Query Methods

#### isPlaying

Checks if media is currently playing.

```dart
static bool isPlaying()
```

**Returns:**

- `bool`: true if playing, false otherwise

**Example:**

```dart
if (FFplayKit.isPlaying()) {
  print('Media is playing');
}
```

---

#### isPaused

Checks if playback is paused.

```dart
static bool isPaused()
```

**Returns:**

- `bool`: true if paused, false otherwise

**Example:**

```dart
if (FFplayKit.isPaused()) {
  print('Playback is paused');
}
```

---

#### isClosed

Checks if there is no active playback session.

```dart
static bool isClosed()
```

**Returns:**

- `bool`: true if no active session, false otherwise

**Example:**

```dart
if (FFplayKit.isClosed()) {
  print('No active playback');
}
```

---

### Session Management Methods

#### cancel

Cancels a specific FFplay session.

```dart
static void cancel(FFplaySession session)
```

**Parameters:**

- `session` (FFplaySession): The session to cancel

**Example:**

```dart
final session = await FFplayKit.execute('video.mp4');
// ... later
FFplayKit.cancel(session);
```

---

#### close

Closes the active session and releases resources.

```dart
static void close()
```

**Example:**

```dart
FFplayKit.close();
```

---

#### getCurrentSession

Returns the current active FFplay session.

```dart
static FFplaySession? getCurrentSession()
```

**Returns:**

- `FFplaySession?`: The active session, or null if none

**Example:**

```dart
final session = FFplayKit.getCurrentSession();
if (session != null) {
  print('Session ID: ${session.getSessionId()}');
  print('Command: ${session.getCommand()}');
}
```

---

#### getFFplaySessions

Returns all active FFplay sessions (always a single element or empty).

```dart
static List<FFplaySession> getFFplaySessions()
```

**Returns:**

- `List<FFplaySession>`: List with at most one session

**Example:**

```dart
final sessions = FFplayKit.getFFplaySessions();
if (sessions.isNotEmpty) {
  print('Active session: ${sessions.first.getCommand()}');
}
```

## Callback Types

### FFplaySessionCompleteCallback

Called when playback completes or is stopped.

```dart
typedef FFplaySessionCompleteCallback = void Function(FFplaySession session);
```

**Example:**

```dart
void onPlaybackComplete(FFplaySession session) {
  if (ReturnCode.isSuccess(session.getReturnCode())) {
    print('Playback finished normally');
  } else if (ReturnCode.isCancel(session.getReturnCode())) {
    print('Playback was cancelled');
  } else {
    print('Playback failed');
  }
}
```

## Common Use Cases

### Basic Video Playback

```dart
// Start playing a video
await FFplayKit.execute('video.mp4');

// Wait a bit, then pause
await Future.delayed(Duration(seconds: 5));
FFplayKit.pause();

// Resume after 2 seconds
await Future.delayed(Duration(seconds: 2));
FFplayKit.resume();

// Stop playback
FFplayKit.stop();
```

### Playback with Progress Tracking

```dart
await FFplayKit.execute('video.mp4');

// Poll for position updates
Timer.periodic(Duration(milliseconds: 500), (timer) {
  final position = FFplayKit.getPosition();
  final duration = FFplayKit.getDuration();

  if (duration > 0) {
    final progress = (position / duration) * 100;
    print('Progress: ${progress.toStringAsFixed(1)}%');
  }

  if (FFplayKit.isClosed()) {
    timer.cancel();
  }
});
```

### Play with Completion Callback

```dart
await FFplayKit.executeAsync(
  'video.mp4',
  onComplete: (session) {
    print('Video finished playing');
    // Play next video
    FFplayKit.execute('next-video.mp4');
  },
);
```

### Custom Playback Options

```dart
// Play in fullscreen
await FFplayKit.execute('-fs video.mp4');

// Play with loop
await FFplayKit.execute('-loop 0 video.mp4');

// Play audio only (no video window)
await FFplayKit.execute('-nodisp audio.mp3');

// Play with custom window size
await FFplayKit.execute('-x 800 -y 600 video.mp4');
```

### Seek to Specific Position

```dart
await FFplayKit.execute('video.mp4');

// Seek to 1 minute
FFplayKit.seek(60.0);

// Seek forward 10 seconds
final currentPos = FFplayKit.getPosition();
FFplayKit.seek(currentPos + 10.0);

// Seek backward 10 seconds
final pos = FFplayKit.getPosition();
FFplayKit.seek((pos - 10.0).clamp(0.0, double.infinity));
```

### Play/Pause Toggle

```dart
void togglePlayPause() {
  if (FFplayKit.isPlaying()) {
    FFplayKit.pause();
  } else if (FFplayKit.isPaused()) {
    FFplayKit.resume();
  } else {
    // Start new playback
    FFplayKit.execute('video.mp4');
  }
}
```

### Custom Video Player UI

```dart
class VideoPlayerWidget extends StatefulWidget {
  final String videoPath;
  
  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  Timer? _positionTimer;
  double _position = 0.0;
  double _duration = 0.0;
  bool _isPlaying = false;
  
  @override
  void initState() {
    super.initState();
    _startPlayback();
  }
  
  void _startPlayback() {
    FFplayKit.executeAsync(
      widget.videoPath,
      onComplete: (session) {
        setState(() => _isPlaying = false);
        _positionTimer?.cancel();
      },
    );

    setState(() => _isPlaying = true);

    // Update position periodically
    _positionTimer = Timer.periodic(Duration(milliseconds: 500), (_) {
      setState(() {
        _position = FFplayKit.getPosition();
        _duration = FFplayKit.getDuration();
        _isPlaying = FFplayKit.isPlaying();
      });
    });
  }
  
  void _togglePlayPause() {
    if (_isPlaying) {
      FFplayKit.pause();
    } else {
      FFplayKit.resume();
    }
  }
  
  void _seek(double seconds) {
    FFplayKit.seek(seconds);
  }
  
  @override
  void dispose() {
    _positionTimer?.cancel();
    FFplayKit.stop();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress slider
        Slider(
          value: _position,
          max: _duration > 0 ? _duration : 1.0,
          onChanged: _seek,
        ),
        
        // Position display
        Text('${_formatTime(_position)} / ${_formatTime(_duration)}'),
        
        // Play/Pause button
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: _togglePlayPause,
        ),
      ],
    );
  }
  
  String _formatTime(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}
```

## Error Handling

```dart
final session = await FFplayKit.execute('video.mp4');

// Check if playback started successfully
if (ReturnCode.isSuccess(session.getReturnCode())) {
  print('Playback started');
} else {
  print('Failed to start playback');
  print('Return code: ${session.getReturnCode()}');
  print('Output: ${session.getOutput()}');
}

// Handle playback completion
await FFplayKit.executeAsync(
  'video.mp4',
  onComplete: (session) {
    final code = session.getReturnCode();
    
    if (ReturnCode.isSuccess(code)) {
      print('Playback completed normally');
    } else if (ReturnCode.isCancel(code)) {
      print('Playback was cancelled by user');
    } else {
      print('Playback failed with code: $code');
      print('Logs: ${session.getLogs()}');
    }
  },
);
```

## Best Practices

1. **Single Session**: Only one FFplay session can be active at a time. Starting a new session automatically replaces the previous one.

2. **Resource Cleanup**: Always stop or close sessions when done:

   ```dart
   @override
   void dispose() {
     FFplayKit.stop();
     super.dispose();
   }
   ```

3. **Check State**: Before controlling playback, check the current state:

   ```dart
   if (FFplayKit.isPlaying()) {
     FFplayKit.pause();
   }
   ```

4. **Position and Duration**: `getPosition()` and `getDuration()` return `0.0` when no session is active — no null check needed.

5. **Use Async for UI**: Use `executeAsync` to avoid blocking the UI thread:

   ```dart
   await FFplayKit.executeAsync('video.mp4');
   ```

6. **Periodic Updates**: Use timers for smooth progress updates:

   ```dart
   Timer.periodic(Duration(milliseconds: 500), (timer) {
     final pos = FFplayKit.getPosition();
     // Update UI
   });
   ```

## Limitations

- **Single Session**: Only one FFplay session can be active at a time
- **Platform Windows**: FFplay creates a native window that may not integrate seamlessly with Flutter UI
- **Limited Control**: Some advanced playback features may require custom FFplay command options

## See Also

- [FFplaySession API](sessions.md) - Session management details
- [Playback Control Guide](../guides/playback-control.md) - Comprehensive playback guide
- [Error Handling Guide](../guides/error-handling.md) - Error handling strategies
