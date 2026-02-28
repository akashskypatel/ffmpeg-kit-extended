# Playback Control Guide

`FFplayKit` allows you to integrate full-featured media playback into your Flutter application. This guide covers how to control playback and sync it with your UI.

## Table of Contents

- [Basic Playback](#basic-playback)
- [Controlling State](#controlling-state)
- [Seeking](#seeking)
- [Syncing with UI](#syncing-with-ui)
- [Global Playback Management](#global-playback-management)

## Basic Playback

Start playing a file or URL with one command:

```dart
FFplayKit.execute('https://example.com/video.mp4');
```

By default, this will terminate any existing playback session. To change this behavior, use a `SessionConflictStrategy`:

```dart
FFplayKit.execute(
  'video.mp4', 
  strategy: SessionConflictStrategy.waitForCompletion
);
```

## Controlling State

Use global methods to control the current active playback session:

```dart
// Pause playback
FFplayKit.pause();

// Resume playback
FFplayKit.resume();

// Stop and close the player window
FFplayKit.stop();
```

## Seeking

Seek to any position in the media (in seconds):

```dart
// Seek to 45 seconds
FFplayKit.seek(45.0);

// Relative seek (forward 10s)
final current = FFplayKit.getPosition() ?? 0.0;
FFplayKit.seek(current + 10.0);
```

## Syncing with UI

To build a custom player UI, you need to track position, duration, and play/pause state.

### Position and Duration

Use a timer to poll the current position:

```dart
Timer? _timer;
double _position = 0.0;
double _duration = 0.0;

void startTimer() {
  _timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
    setState(() {
      _position = FFplayKit.getPosition() ?? 0.0;
      _duration = FFplayKit.getMediaDuration() ?? 1.0;
    });
  });
}
```

### Player State

Check if the player is currently playing or paused:

```dart
bool playing = FFplayKit.isPlaying();
bool paused = FFplayKit.isPaused();
```

## Global Playback Management

Because FFplay typically opens a separate native window, the plugin manages it as a singleton.

- **`FFplayKit.getCurrentSession()`**: Returns the session object for the currently playing media.
- **`FFplayKit.close()`**: Shuts down the entire FFplay environment and releases resources.

### Listening for Completion

Use the `onComplete` callback to handle the end of a video (e.g., to play the next one in a playlist):

```dart
FFplayKit.executeAsync(
  'video1.mp4',
  onComplete: (session) {
    print('Video 1 finished, starting Video 2...');
    FFplayKit.execute('video2.mp4');
  }
);
```

## Tips for a Better UX

1. **Handle Window Closing**: On desktop platforms, users might close the FFplay window manually. Monitor `FFplayKit.isClosed()` to update your UI accordingly.
2. **Handle Null Values**: `getPosition()` and `getMediaDuration()` return `null` if no session is active or if metadata hasn't been loaded yet.
3. **Volume and Audio**: You can pass additional FFplay flags during execution for audio control:

   ```dart
   // Start with 50% volume
   FFplayKit.execute('-volume 50 video.mp4');
   ```

4. **Window Title**:

   ```dart
   FFplayKit.execute('-window_title "My Custom Player" video.mp4');
   ```
