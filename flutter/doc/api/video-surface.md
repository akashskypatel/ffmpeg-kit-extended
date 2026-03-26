# Video Surface API Reference

The video surface API provides a unified cross-platform interface for video playback with FFplay.

## FFplaySurface

The main class for cross-platform video surface management.

### Overview

`FFplaySurface` automatically handles platform differences:
- **Android**: Uses `SurfaceTexture` backed `ANativeWindow`
- **Linux/Windows**: Uses pixel buffer textures with frame callbacks
- **Audio-only**: Safe surface creation with no display

### Static Methods

#### create

Creates a platform-appropriate video surface and wires it to FFplay.

```dart
static Future<FFplaySurface?> create({int width = 1, int height = 1})
```

**Parameters:**
- `width` (int): Android-only hint for initial buffer size (default: 1)
- `height` (int): Android-only hint for initial buffer size (default: 1)

**Returns:**
- `Future<FFplaySurface?>`: Surface instance or null if creation fails

**Example:**
```dart
// Create surface with default size
final surface = await FFplaySurface.create();

// Create with size hint (Android only)
final surface = await FFplaySurface.create(width: 1920, height: 1080);
```

### Instance Properties

#### textureId

The Flutter texture ID backing this surface.

```dart
final int textureId
```

**Example:**
```dart
final texture = Texture(textureId: surface.textureId);
```

### Instance Methods

#### toWidget

Returns a Widget that composites the current video frame into the widget tree.

```dart
Widget toWidget()
```

**Returns:**
- `Widget`: Flutter Texture widget

**Example:**
```dart
class VideoWidget extends StatelessWidget {
  final FFplaySurface surface;
  
  const VideoWidget({Key? key, required this.surface}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: surface.toWidget(),
    );
  }
}
```

#### release

Releases native resources and stops frame delivery.

```dart
Future<void> release()
```

**Important**: Call this method when done with the surface to prevent memory leaks.

**Example:**
```dart
@override
void dispose() {
  surface?.release();
  super.dispose();
}
```

## FFplayAndroidSurface

Platform-specific surface implementation for Android.

### Static Methods

#### create

Creates an Android-specific video surface.

```dart
static Future<FFplayAndroidSurface?> create({int width = 1, int height = 1})
```

**Returns:**
- `Future<FFplayAndroidSurface?>`: Android surface or null on non-Android platforms

### Instance Properties

#### textureId

Flutter texture ID for the SurfaceTexture.

```dart
final int textureId
```

#### nativeWindowPtr

Native ANativeWindow* pointer as a Dart int.

```dart
final int nativeWindowPtr
```

### Instance Methods

#### toWidget

Returns a Texture widget for Android video display.

```dart
Widget toWidget()
```

#### bindToFFplay

Registers surface as FFplay video output target.

```dart
void bindToFFplay()
```

**Important**: Must be called before `FFplayKit.executeAsync`.

#### release

Releases Android surface resources.

```dart
Future<void> release()
```

## FFplayDesktopTexture

Platform-specific texture implementation for Linux and Windows.

### Static Methods

#### create

Creates a desktop pixel buffer texture.

```dart
static Future<FFplayDesktopTexture?> create()
```

**Returns:**
- `Future<FFplayDesktopTexture?>`: Desktop texture or null on non-desktop platforms

### Instance Properties

#### textureId

Flutter texture ID for the pixel buffer.

```dart
final int textureId
```

### Instance Methods

#### toWidget

Returns a Texture widget for desktop video display.

```dart
Widget toWidget()
```

#### bindToFFplay

No-op on desktop - frame callback is wired automatically.

```dart
void bindToFFplay()
```

#### release

Releases desktop texture resources.

```dart
Future<void> release()
```

## FFplayKitAndroid

Android-specific FFplay utilities for surface management.

### Static Methods

#### setAndroidSurface

Sets Android ANativeWindow for FFplay video output.

```dart
static void setAndroidSurface(int nativeWindowPtr)
```

**Parameters:**
- `nativeWindowPtr` (int): ANativeWindow* pointer from native code

**Important**: Must be called before executing an FFplay session.

#### clearAndroidSurface

Clears Android ANativeWindow, stopping video output.

```dart
static void clearAndroidSurface()
```

#### releaseNativeWindowPtr

Documentation-only method for native window pointer release.

```dart
static void releaseNativeWindowPtr(int nativeWindowPtr)
```

**Note**: This method must be called from the Kotlin/Java side, not Dart.

## Session Video Properties

### FFplaySession Video Methods

#### getVideoWidth

Returns the current video width in pixels.

```dart
int getVideoWidth()
```

**Returns:**
- `int`: Video width in pixels, or 0 if not yet known

#### getVideoHeight

Returns the current video height in pixels.

```dart
int getVideoHeight()
```

**Returns:**
- `int`: Video height in pixels, or 0 if not yet known

### Session Streams

#### positionStream

Stream of playback positions in seconds.

```dart
Stream<double> get positionStream
```

**Example:**
```dart
session.positionStream.listen((position) {
  print('Position: ${position.toStringAsFixed(1)}s');
});
```

#### videoSizeStream

Stream of video dimension changes.

```dart
Stream<(int, int)> get videoSizeStream
```

**Example:**
```dart
session.videoSizeStream.listen((size) {
  final (width, height) = size;
  print('Video size: ${width}x${height}');
});
```

## Usage Examples

### Basic Video Player

```dart
class VideoPlayer extends StatefulWidget {
  final String videoPath;
  
  const VideoPlayer({Key? key, required this.videoPath}) : super(key: key);
  
  @override
  _VideoPlayerState createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  FFplaySurface? _surface;
  FFplaySession? _session;
  bool _hasVideo = false;
  int _videoWidth = 0;
  int _videoHeight = 0;
  
  @override
  void dispose() {
    _surface?.release();
    super.dispose();
  }
  
  Future<void> _startPlayback() async {
    _surface = await FFplaySurface.create();
    if (_surface == null) return;
    
    _session = await FFplayKit.executeAsync('-i "${widget.videoPath}"');
    
    _session!.videoSizeStream.listen((size) {
      final (width, height) = size;
      if (mounted && width > 0 && height > 0) {
        setState(() {
          _videoWidth = width;
          _videoHeight = height;
          _hasVideo = true;
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_hasVideo && _surface != null)
          SizedBox(
            width: _videoWidth.toDouble(),
            height: _videoHeight.toDouble(),
            child: _surface!.toWidget(),
          ),
        ElevatedButton(
          onPressed: _startPlayback,
          child: const Text('Play Video'),
        ),
      ],
    );
  }
}
```

### Platform-Specific Implementation

```dart
// Android-specific setup
if (Platform.isAndroid) {
  final androidSurface = await FFplayAndroidSurface.create();
  androidSurface.bindToFFplay();
  final texture = androidSurface.toWidget();
}

// Desktop-specific setup
if (Platform.isLinux || Platform.isWindows) {
  final desktopTexture = await FFplayDesktopTexture.create();
  final texture = desktopTexture.toWidget();
}

// Cross-platform setup (recommended)
final surface = await FFplaySurface.create();
final texture = surface.toWidget();
```

## Error Handling

```dart
Future<void> _safeVideoPlayback(String path) async {
  try {
    final surface = await FFplaySurface.create();
    if (surface == null) {
      throw Exception('Failed to create video surface');
    }
    
    final session = await FFplayKit.executeAsync('-i "$path"');
    
    session.videoSizeStream.listen((size) {
      final (width, height) = size;
      if (width == 0 || height == 0) {
        print('Warning: Invalid video dimensions');
      }
    });
    
  } catch (e) {
    print('Video playback error: $e');
    // Handle error appropriately
  }
}
```

## Best Practices

1. **Always create surface before starting playback**
2. **Properly dispose resources in `dispose()` method**
3. **Handle audio-only content gracefully**
4. **Use streams for real-time updates**
5. **Test on all target platforms**
6. **Monitor memory usage on mobile devices**
