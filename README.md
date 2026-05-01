# FFmpegKit Extended for Flutter

<div align="center">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/pub/dm/ffmpeg_kit_extended_flutter?style=flat-square&logoColor=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub version](https://img.shields.io/pub/v/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub likes](https://img.shields.io/pub/likes/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub points](https://img.shields.io/pub/points/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

`ffmpeg-kit-extended` is a comprehensive Flutter plugin for executing FFmpeg, FFprobe, and FFplay commands on Android, iOS, macOS, Linux, and Windows. It leverages Dart FFI to interact directly with native FFmpeg libraries, providing high performance, flexibility, and complete video playback capabilities.

## 1. Features

- **Cross-Platform Support**: Works on Android, iOS, macOS, Linux, and Windows.
  - **Android**: Full video playback support with native surface rendering.
    - **x86**: x86 architecture is not supported due to its legacy status.
  - **iOS & macOS**: High-performance video playback with `CVPixelBuffer` and Metal integration.
    - **iOS**: Supports both physical devices and simulators. x86_64 architecture is not supported due to its legacy status.
  - **Linux**: Full video playback support with OpenGL integration.
    - **arm64**: arm64 architecture currently not supported, coming soon!
  - **tvOS**: Coming soon!
- **FFmpeg, FFprobe & FFplay**: Full support for media manipulation, information retrieval, and audio/video playback.
- **Video Playback**: Complete cross-platform video playback with unified surface API.
- **Real-time Streaming**: Position and video dimension streams for live playback monitoring.
- **Dart FFI**: Direct native bindings for optimal performance.
- **Asynchronous Execution**: Run long-running tasks without blocking the UI thread.
- **Parallel Execution**: Run multiple tasks in parallel.
- **Callback Support**: detailed hooks for logs, statistics, and session completion.
- **Session Management**: Full control over execution lifecycle (start, cancel, list).
- **Extensible**: Designed to allow custom native library loading and configuration.
- **Deploy Custom Builds**: You can deploy custom builds of ffmpeg-kit-extended. See: <https://github.com/akashskypatel/ffmpeg-kit-builders>

### Platform Support

| Platform | Status      | Video Playback | Architecture         | Minimum Requirements |
| -------- | ----------- | -------------- | -------------------- | -------------------- |
| Android (including Android TV) | ✅ Supported | ✅ Native       | armv7, arm64, x86_64 | API 26+              |
| iOS      | ✅ Supported | ✅ Texture      | arm64                | iOS 13+              |
| macOS    | ✅ Supported | ✅ Texture      | arm64, x86_64        | macOS 13+            |
| Linux    | ✅ Supported | ✅ Texture      | x86_64               | glibc 2.28+          |
| Windows  | ✅ Supported | ✅ Texture      | x86_64               | Windows 8+           |
| tvOS     | Coming Soon! |                |                      |             |

You will have to update your app's minimum requirements on your own to match the requirements above.

## 🎬 Demo

<div align="center">
<a href="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif">Click here if the image doesn't load</a>
<br>
<img width="378" height="672" src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif?raw=true" alt="Demo" style="border-radius: 10px;" />
<br>

[_Video demonstration of FFmpegKit Extended Flutter plugin showing real-time video playback, FFmpeg command execution, and the comprehensive introspection API interface._](https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif)

</div>

## 2. Installation

1. Install the package:

   ```bash
   flutter pub add ffmpeg_kit_extended_flutter
   ```

2. Add the `ffmpeg_kit_extended_config` section to your `pubspec.yaml`:

   ```yaml
   ffmpeg_kit_extended_config:
     type: "base" # pre-bundled builds: debug, base, full, audio, video, video_hw
     gpl: true # enable to include GPL libraries
     small: true # enable to use smaller builds
     # == OR ==
     # -------------------------------------------------------------
     # You can specify remote or local path to libffmpegkit libraries for each platform
     # This allows you to deploy custom builds of libffmpegkit.
     # See: https://github.com/akashskypatel/ffmpeg-kit-builders
     # -------------------------------------------------------------
     # windows: "path/to/ffmpeg-kit/libraries"
     # ios: "https://path/to/bundle.xcframework.zip"
   ```

   **Note**: Native libraries are now automatically downloaded and bundled during the build process using [Dart Hooks](https://dart.dev/tools/hooks). No manual configuration script is required.

3. Import the package in your Dart code:

   ```dart
   import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
   ```

4. Initialize the plugin at application startup **before** calling any API:

   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await FFmpegKitExtended.initialize();
     runApp(MyApp());
   }
   ```

   > **Important**: Any FFmpeg, FFprobe, or FFplay API call made before `initialize()` completes will throw a `StateError`.

### 2.1 Platform specific configuration

1. **iOS and iOS Simulator** - Your app's Podfile will need to be updated to add post-install hooks to exclude building for architectures that aren't supported Add the following to your Podfile:

    ```ruby
    post_install do |installer|
      installer.pods_project.targets.each do |target|
        flutter_additional_ios_build_settings(target)
        target.build_configurations.each do |config|
          config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'i386 x86_64'
          config.build_settings['EXCLUDED_ARCHS[sdk=iphoneos*]'] = 'i386 x86_64'
        end
      end

      installer.generated_projects.each do |project|
        project.targets.each do |target|
          target.build_configurations.each do |config|
            config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'i386 x86_64'
            config.build_settings['EXCLUDED_ARCHS[sdk=iphoneos*]'] = 'i386 x86_64'
            config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
          end
        end
        project.save
      end
    end
    ```

### 2.2 Pre-bundled Builds

- **base**: Basic build with core FFmpeg libraries. Does not contain any extra libraries.
- **full**: Full build with all platform-compatible FFmpeg libraries. See: <https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries>
- **audio**: Build with audio-only FFmpeg libraries.
- **video**: Build with video-only FFmpeg libraries.
- **streaming**: Build with streaming FFmpeg libraries.
- **video_hw**: Build with hardware-accelerated video FFmpeg libraries.

### 2.2 Feature Matrix

| Feature   | Base | Audio | Video | Video+Hardware | Full |
| --------- | ---- | ----- | ----- | -------------- | ---- |
| Video     |      |       | x     |                | x    |
| Audio     |      | x     | x     |                | x    |
| Streaming |      | x     | x     | x              | x    |
| Hardware  |      |       |       | x              | x    |
| AI\*      |      |       |       |                | x\*  |
| HTTPS     |      | x     | x     | x              | x    |

- AI features are not supported on all platforms. You must deploy your own custom build of ffmpeg-kit-extended to enable certain AI features.
- See [Supported External Libraries](https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries) for more information.

## 3. Usage

### 3.1 Basic Command Execution

Execute an FFmpeg command asynchronously:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

FFmpegKit.executeAsync('-i input.mp4 -c:v libx264 output.mp4', onComplete: (session) async {
  final returnCode = session.getReturnCode();

  if (ReturnCode.isSuccess(returnCode)) {
    print("Command success");
  } else if (ReturnCode.isCancel(returnCode)) {
    print("Command cancelled");
  } else {
    print("Command failed with state ${session.getState()}");
    final failStackTrace = session.getFailStackTrace();
    print("Stack trace: $failStackTrace");
  }
});
```

### 3.2 Retrieving Media Information

Use `FFprobeKit` to get detailed metadata about a media file:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

FFprobeKit.getMediaInformationAsync('path/to/video.mp4', onComplete: (session) {
  final info = session.getMediaInformation();
  if (info != null) {
      print("Duration: ${info.duration}");
      print("Format: ${info.format}");
      for (var stream in info.streams) {
          print("Stream type: ${stream.type}, codec: ${stream.codec}");
      }
  }
});
```

### 3.3 Handling Logs and Statistics

You can register logs and statistics callbacks for improved monitoring:

```dart
FFmpegKit.executeAsync(
  '-i input.mp4 output.mkv',
  onComplete: (session) { /* Complete Callback */ },
  onLog: (log) {
    print("Log: ${log.message}");
  },
  onStatistics: (statistics) {
    print("Progress: ${statistics.time} ms, size: ${statistics.size}");
  },
);
```

### 3.4 Session Management

All executions return a `Session` object which can be used to control the task:

```dart
// Cancel a specific session
FFmpegKit.cancel(session);

// Cancel all active sessions
FFmpegKitExtended.cancelAllSessions();

// List all sessions
final sessions = FFmpegKitExtended.getSessions();
// OR list only FFmpeg sessions
final ffmpegSessions = FFmpegKit.getFFmpegSessions();
```

### 3.5 FFplay Video Playback

The plugin supports complete video playback with a unified cross-platform surface API.

#### Basic Video Playback

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

class VideoPlayerWidget extends StatefulWidget {
  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  FFplaySurface? _surface;
  bool _hasVideo = false;
  int _videoWidth = 0;
  int _videoHeight = 0;
  double _playbackPosition = 0.0;

  @override
  void dispose() {
    _surface?.release();
    super.dispose();
  }

  Future<void> _startPlayback(String filePath) async {
    // Create surface before starting playback
    _surface = await FFplaySurface.create();

    final session = await FFplayKit.executeAsync('-i "$filePath"');

    // Listen for video dimensions
    session.videoSizeStream.listen((size) {
      final (width, height) = size;
      if (mounted && width > 0 && height > 0) {
        setState(() {
          _videoWidth = width;
          _videoHeight = height;
          _hasVideo = true;
        });
      }
    });

    // Listen for position updates
    session.positionStream.listen((position) {
      if (mounted) {
        setState(() => _playbackPosition = position);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Video display (only when video frames are available)
        if (_hasVideo && _surface != null)
          SizedBox(
            width: _videoWidth.toDouble(),
            height: _videoHeight.toDouble(),
            child: _surface!.toWidget(),
          ),

        // Playback controls
        Row(
          children: [
            IconButton(
              onPressed: () => FFplayKit.pause(),
              icon: Icon(Icons.pause),
            ),
            IconButton(
              onPressed: () => FFplayKit.resume(),
              icon: Icon(Icons.play_arrow),
            ),
            Expanded(
              child: Slider(
                value: _playbackPosition / (FFplayKit.duration > 0 ? FFplayKit.duration : 1.0),
                onChanged: (value) => FFplayKit.seek(value * FFplayKit.duration),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

#### Platform-Specific Usage

The `FFplaySurface` class automatically handles platform differences:

- **Android**: Uses `SurfaceTexture` backed `ANativeWindow` for native rendering
- **iOS/macOS**: Uses `CVPixelBuffer` textures with Metal optimization
- **Linux/Windows**: Uses pixel buffer textures with frame callbacks
- **Audio-only**: Surface is created but not displayed, preventing crashes

#### Advanced Features

```dart
// Get session-specific properties
final session = await FFplayKit.executeAsync('-i video.mp4');

// Video dimensions (available when first frame is decoded)
final width = session.getVideoWidth();
final height = session.getVideoHeight();

// Real-time streams
session.positionStream.listen((pos) => print('Position: ${pos}s'));
session.videoSizeStream.listen((size) => print('Size: ${size}'));

// Volume control
session.setVolume(0.8); // 0.0 to 1.0
print('Volume: ${session.getVolume()}');

// Session state
print('Playing: ${session.isPlaying()}');
print('Paused: ${session.isPaused()}');
```

## 4. Architecture

This plugin uses a modular architecture:

- **`ffmpeg_kit_extended.dart`**: The core FFI wrapper that interfaces with the native C library.
- **`ffmpeg_kit_config.dart`**: Manages global configurations (log levels, font directories, etc.).
- **`session.dart`**: Abstract base class for all session types (`FFmpegSession`, `FFprobeSession`, `FFplaySession`).
- **`callback_manager.dart`**: Handles the mapping between native function pointers and Dart callbacks.

## 5. Requirements

- **Dart SDK**: >= 3.10.0
- **Flutter SDK**: with native assets support (experimental)

## 6. License

This project is licensed under the LGPL v3.0 by default. However, depending on the underlying FFmpeg build configuration and external libraries used, the effective license may be GPL v3.0. Please review the licenses of the included libraries.
