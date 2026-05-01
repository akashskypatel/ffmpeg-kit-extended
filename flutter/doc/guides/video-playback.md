# Video Playback Guide

Complete guide to implementing video playback using FFmpegKit Extended Flutter.

## Overview

FFmpegKit Extended provides a unified cross-platform video playback API that works seamlessly across Android, Linux, and Windows. The `FFplaySurface` class handles platform-specific differences while providing a consistent Dart API.

## Platform Implementation Details

### Android
- Uses `SurfaceTexture` backed `ANativeWindow` for native rendering
- Leverages SDL2's Android backend for hardware-accelerated output
- Method channel for surface lifecycle management

### Linux & Windows  
- Uses pixel buffer textures with Flutter's texture system
- Frame callbacks deliver RGBA8888 pixels from FFplay decoder
- Double-buffered rendering for smooth playback

### Audio-only Content
- Surface creation is safe for audio-only files
- Texture widget only shown when video frames arrive
- Prevents crashes from empty pixel buffers

## Basic Video Player Implementation

### 1. Setup and Surface Creation

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoPath;
  
  const VideoPlayerWidget({Key? key, required this.videoPath}) : super(key: key);
  
  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}
```

### 2. State Management

```dart
class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  FFplaySurface? _surface;
  FFplaySession? _session;
  
  // Video state
  bool _hasVideo = false;
  int _videoWidth = 0;
  int _videoHeight = 0;
  
  // Playback state  
  double _playbackPosition = 0.0;
  bool _isPlaying = false;
  
  // Stream subscriptions
  StreamSubscription<double>? _positionSub;
  StreamSubscription<(int, int)>? _videoSizeSub;
  
  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
  
  Future<void> _cleanup() async {
    await _positionSub?.cancel();
    await _videoSizeSub?.cancel();
    await _surface?.release();
    _session = null;
    _surface = null;
  }
}
```

### 3. Surface Creation and Playback

```dart
Future<void> _startPlayback() async {
  // Clean up any existing playback
  await _cleanup();
  
  // Create new surface
  _surface = await FFplaySurface.create();
  if (_surface == null) {
    print('Failed to create video surface');
    return;
  }
  
  // Start playback
  _session = await FFplayKit.executeAsync('-i "${widget.videoPath}"');
  
  // Setup streams
  _setupStreams();
}

void _setupStreams() {
  if (_session == null) return;
  
  // Video dimension stream
  _videoSizeSub = _session!.videoSizeStream.listen((size) {
    final (width, height) = size;
    if (mounted && width > 0 && height > 0) {
      setState(() {
        _videoWidth = width;
        _videoHeight = height;
        _hasVideo = true;
      });
    }
  });
  
  // Position stream
  _positionSub = _session!.positionStream.listen((position) {
    if (mounted) {
      setState(() => _playbackPosition = position);
    }
  });
  
  // Session completion
  _session!.setCompleteCallback((session) {
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  });
  
  setState(() => _isPlaying = true);
}
```

### 4. UI Implementation

```dart
@override
Widget build(BuildContext context) {
  return Column(
    children: [
      // Video display area
      Container(
        color: Colors.black,
        child: _buildVideoDisplay(),
      ),
      
      // Playback controls
      _buildPlaybackControls(),
      
      // Status information
      _buildStatusInfo(),
    ],
  );
}

Widget _buildVideoDisplay() {
  if (_hasVideo && _surface != null) {
    return SizedBox(
      width: _videoWidth.toDouble(),
      height: _videoHeight.toDouble(),
      child: _surface!.toWidget(),
    );
  }
  
  // Placeholder for audio-only or loading
  return Container(
    width: double.infinity,
    height: 200,
    child: const Center(
      child: Icon(Icons.play_circle_outline, size: 64, color: Colors.white54),
    ),
  );
}

Widget _buildPlaybackControls() {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Row(
      children: [
        IconButton(
          onPressed: _isPlaying ? _pause : _resume,
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
        ),
        IconButton(
          onPressed: _stop,
          icon: const Icon(Icons.stop),
        ),
        Expanded(
          child: Slider(
            value: _playbackPosition / (FFplayKit.duration > 0 ? FFplayKit.duration : 1.0),
            onChanged: _seek,
          ),
        ),
        Text('${_playbackPosition.toInt()}s / ${FFplayKit.duration.toInt()}s'),
      ],
    ),
  );
}

Widget _buildStatusInfo() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Video: ${_hasVideo ? "$_videoWidth×$_videoHeight" : "None"}'),
        Text('Position: ${_playbackPosition.toStringAsFixed(1)}s'),
        Text('State: ${_isPlaying ? "Playing" : "Stopped"}'),
      ],
    ),
  );
}
```

### 5. Control Methods

```dart
void _pause() {
  FFplayKit.pause();
  if (mounted) setState(() => _isPlaying = false);
}

void _resume() {
  FFplayKit.resume();
  if (mounted) setState(() => _isPlaying = true);
}

Future<void> _stop() async {
  FFplayKit.stop();
  await _cleanup();
  if (mounted) setState(() => _isPlaying = false);
}

void _seek(double value) {
  final position = value * FFplayKit.duration;
  FFplayKit.seek(position);
}
```

## Advanced Features

### Volume Control

```dart
Future<void> _setVolume(double volume) async {
  // Volume range: 0.0 to 1.0
  if (_session != null) {
    _session!.setVolume(volume.clamp(0.0, 1.0));
  }
}

double _getVolume() {
  return _session?.getVolume() ?? 0.0;
}
```

### Session Properties

```dart
void _printSessionInfo() {
  if (_session == null) return;
  
  print('Session ID: ${_session!.sessionId}');
  print('Video Width: ${_session!.getVideoWidth()}');
  print('Video Height: ${_session!.getVideoHeight()}');
  print('Is Playing: ${_session!.isPlaying()}');
  print('Is Paused: ${_session!.isPaused()}');
  print('Volume: ${_session!.getVolume()}');
}
```

### Error Handling

```dart
Future<void> _startPlaybackWithErrorHandling() async {
  try {
    await _startPlayback();
  } catch (e) {
    print('Playback failed: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start video: $e')),
      );
    }
  }
}
```

## Fullscreen Mode

`FFplayView` and `FFplayViewController` provide decoupled fullscreen control. The widget has no built-in button — the consuming widget decides how and when to trigger fullscreen (button, keyboard shortcut, gesture, etc.).

### Setup

```dart
import 'dart:io' show Platform;
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:window_manager/window_manager.dart'; // desktop only
```

Add `window_manager: ^0.4.3` to `pubspec.yaml` (desktop targets only), then initialise in `main()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
  }
  await FFmpegKitExtended.initialize();
  runApp(const MyApp());
}
```

### Controller Setup

```dart
class _VideoPlayerState extends State<VideoPlayerWidget> {
  FFplaySurface? _surface;
  late final FFplayViewController _fsController;
  int _videoWidth = 0;
  int _videoHeight = 0;
  bool _hasVideo = false;

  @override
  void initState() {
    super.initState();
    _fsController = FFplayViewController(
      onEnterFullscreen: (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
          ? () => windowManager.setFullScreen(true)
          : null,
      onExitFullscreen: (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
          ? () => windowManager.setFullScreen(false)
          : null,
    );
  }

  @override
  void dispose() {
    _fsController.dispose();
    _surface?.release();
    super.dispose();
  }
}
```

### Widget Layout

Wrap `FFplayView` in a `Stack` and place the fullscreen button via `Positioned`. This anchors the button to the video's actual rendered dimensions, not the app window:

```dart
Widget _buildVideoDisplay() {
  if (!_hasVideo || _surface == null) return const SizedBox.shrink();

  return Center(
    child: Stack(
      children: [
        FFplayView(
          surface: _surface!,
          controller: _fsController,
          aspectRatio: _videoWidth > 0 && _videoHeight > 0
              ? _videoWidth / _videoHeight
              : null,
          videoWidth: _videoWidth > 0 ? _videoWidth : null,
          videoHeight: _videoHeight > 0 ? _videoHeight : null,
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: ListenableBuilder(
            listenable: _fsController,
            builder: (ctx, _) => IconButton(
              icon: Icon(
                _fsController.isFullscreen
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
              ),
              color: Colors.white,
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
              onPressed: () => _fsController.isFullscreen
                  ? _fsController.exitFullscreen()
                  : _fsController.enterFullscreen(ctx),
              tooltip: _fsController.isFullscreen
                  ? 'Exit fullscreen'
                  : 'Fullscreen',
            ),
          ),
        ),
      ],
    ),
  );
}
```

### Keyboard Shortcut (Desktop)

```dart
// Inside a Focus widget or using keyboard shortcuts:
shortcuts: {
  const SingleActivator(LogicalKeyboardKey.keyF): EnterFullscreenIntent(),
},
actions: {
  EnterFullscreenIntent: CallbackAction<EnterFullscreenIntent>(
    onInvoke: (_) => _fsController.isFullscreen
        ? _fsController.exitFullscreen()
        : _fsController.enterFullscreen(context),
  ),
},
```

### Fullscreen Page Behaviour

When in fullscreen:
- The video fills the screen maintaining its aspect ratio (letterboxed / pillarboxed as needed)
- Tap anywhere to reveal an exit button (top-right corner)
- Press back / Escape to exit
- On mobile: status bar and navigation bar are hidden (`SystemUiMode.immersiveSticky`)
- On desktop: the OS window goes truly fullscreen when `onEnterFullscreen` is wired to `window_manager`

---

## Platform-Specific Considerations

### Android Performance Tips

1. **Surface Size**: Provide initial size hints for better performance
   ```dart
   _surface = await FFplaySurface.create(width: 1920, height: 1080);
   ```

2. **Lifecycle Management**: Properly release surface in `dispose()`
3. **Memory Management**: Surface resources are limited on mobile devices

### Desktop Performance Tips

1. **Frame Rate**: Desktop plugins deliver frames at native frame rate
2. **Memory Usage**: RGBA8888 format uses 4 bytes per pixel
3. **Thread Safety**: Frame callbacks come from FFplay decoder thread

## Troubleshooting

### Common Issues

**Surface creation fails**
- Check platform support (iOS/macOS not supported)
- Verify native libraries are properly loaded
- Ensure `FFmpegKitExtended.initialize()` completed

**Video not displaying**
- Verify video has frames (not audio-only)
- Check `_hasVideo` flag from video size stream
- Ensure surface is created before starting playback

**Performance issues**
- Lower video resolution for testing
- Check system resources on desktop
- Monitor memory usage on Android

### Debug Information

```dart
void _debugPlaybackState() {
  print('=== Playback Debug Info ===');
  print('Surface exists: ${_surface != null}');
  print('Session exists: ${_session != null}');
  print('Has video: $_hasVideo');
  print('Video size: ${_videoWidth}x$_videoHeight');
  print('Position: $_playbackPosition');
  print('Duration: ${FFplayKit.duration}');
  print('Playing: $_isPlaying');
  print('Platform: ${Platform.operatingSystem}');
}
```

## Best Practices

1. **Always create surface before starting playback**
2. **Properly dispose resources in `dispose()` method**
3. **Handle audio-only content gracefully**
4. **Use streams for real-time updates**
5. **Implement proper error handling**
6. **Test on all target platforms**
7. **Monitor memory usage on mobile devices**

## Complete Example

See the `flutter/example/` directory for a complete working video player implementation that demonstrates all features discussed in this guide.
