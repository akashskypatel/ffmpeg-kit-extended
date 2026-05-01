# Quick Start Guide

Get up and running with FFmpeg Kit Extended Flutter in minutes!

## Installation

1. Install the package:

    ```bash
    flutter pub add ffmpeg_kit_extended_flutter
    ```

2. Add the `ffmpeg_kit_extended_config` section to your `pubspec.yaml`:

    ```yaml
    ffmpeg_kit_extended_config:
      type: "base" # pre-bundled builds: base, full, audio, video, streaming, video_hw
      gpl: true # enable to include GPL libraries
      small: true # enable to use smaller builds
      # == OR ==
      # -------------------------------------------------------------
      # You can specify remote or local path to libffmpegkit libraries for each platform
      # windows: "path/to/ffmpeg-kit/libraries"
      # ios: "https://path/to/bundle.xcframework.zip"
    ```

    **Note**: Native libraries are now automatically downloaded and bundled during the build process using [Dart Hooks](https://dart.dev/tools/hooks). No manual configuration step is required.

3. Import the package in your Dart code:

    ```dart
    import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
    ```

## Initialize the Plugin

**Before calling any FFmpeg, FFprobe, or FFplay API**, you must initialize the plugin once at application startup. This loads the native library and sets up the FFI bindings.

```dart
import 'package:flutter/widgets.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();
  runApp(MyApp());
}
```

> **Important**: Calling any API method before `FFmpegKitExtended.initialize()` completes will throw a `StateError`. Always `await` the call before proceeding.

## Your First FFmpeg Command

Let's convert a video file:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void convertVideo() {
  // Synchronous execution (blocking)
  final session = FFmpegKit.execute(
    '-i input.mp4 -c:v libx264 -crf 23 output.mp4'
  );
  
  if (ReturnCode.isSuccess(session.getReturnCode())) {
    print('✅ Video converted successfully!');
  } else {
    print('❌ Conversion failed');
    // Get full terminal output
    print('Output: ${session.getOutput()}');
    // Get all logs
    print('Logs: ${session.getLogs()}');
  }
}
```

## Synchronous vs Asynchronous

FFmpeg Kit Extended provides two primary ways to run commands:

### 1. Synchronous Execution (`execute`)

This call **blocks** the current thread until the command finishes. It is simple to use but will freeze your UI if called on the main thread.

**Capturing Output:** Even though it's synchronous, you can retrieve the terminal output and logs from the returned `Session` object.

```dart
final session = FFmpegKit.execute("-version");
print(session.getOutput()); // Prints standard output
```

### 2. Asynchronous Execution (`executeAsync`)

This call returns a `Future` immediately and handles the process in the background. It is ideal for long-running operations like video encoding.

**Capturing Output:** You can monitor logs in real-time or retrieve the full output once the future completes.

```dart
await FFmpegKit.executeAsync("-i input.mp4 output.mp4", 
  onLog: (log) => print(log.message),
  onComplete: (session) => print("Finished!")
);
```

## Common Tasks

### 1. Get Video Information

```dart
void getVideoInfo(String videoPath) {
  final session = FFprobeKit.getMediaInformation(videoPath);
  
  if (session is MediaInformationSession) {
    final info = session.getMediaInformation();
    
    if (info != null) {
      print('📹 Video Information:');
      print('  Duration: ${info.duration}s');
      print('  Format: ${info.format}');
      print('  Bitrate: ${info.bitrate} bps');
      print('  Size: ${info.size} bytes');
      
      // Get video stream details
      final videoStream = info.streams.firstWhere(
        (s) => s.type == 'video',
        orElse: () => throw Exception('No video stream'),
      );
      
      print('  Resolution: ${videoStream.width}x${videoStream.height}');
      print('  Codec: ${videoStream.codec}');
    }
  }
}
```

### 2. Compress a Video

```dart
Future<void> compressVideo(String inputPath, String outputPath) async {
  await FFmpegKit.executeAsync(
    '-i $inputPath -vf scale=1280:720 -c:v libx264 -crf 28 $outputPath',
    onStatistics: (stats) {
      print('⏳ Compressing... Speed: ${stats.speed}x');
    },
    onComplete: (session) {
      if (ReturnCode.isSuccess(session.getReturnCode())) {
        print('✅ Compression complete!');
      } else {
        print('❌ Compression failed');
      }
    },
  );
}
```

### 3. Extract Audio from Video

```dart
void extractAudio(String videoPath, String audioPath) {
  final session = FFmpegKit.execute(
    '-i $videoPath -vn -acodec copy $audioPath'
  );
  
  if (ReturnCode.isSuccess(session.getReturnCode())) {
    print('✅ Audio extracted to: $audioPath');
  }
}
```

### 4. Create a Thumbnail

```dart
void createThumbnail(String videoPath, String thumbnailPath) {
  // Extract frame at 5 seconds
  final session = FFmpegKit.execute(
    '-i $videoPath -ss 00:00:05 -vframes 1 $thumbnailPath'
  );
  
  if (ReturnCode.isSuccess(session.getReturnCode())) {
    print('✅ Thumbnail created: $thumbnailPath');
  }
}
```

### 5. Video Playback with Surface

```dart
class VideoPlayerWidget extends StatefulWidget {
  final String videoPath;
  
  const VideoPlayerWidget({Key? key, required this.videoPath}) : super(key: key);
  
  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  FFplaySurface? _surface;
  FFplaySession? _session;
  bool _hasVideo = false;
  int _videoWidth = 0;
  int _videoHeight = 0;
  double _playbackPosition = 0.0;
  
  StreamSubscription<double>? _positionSub;
  StreamSubscription<(int, int)>? _videoSizeSub;
  
  @override
  void dispose() {
    _positionSub?.cancel();
    _videoSizeSub?.cancel();
    _surface?.release();
    super.dispose();
  }
  
  Future<void> _startPlayback() async {
    // Create surface before starting playback
    _surface = await FFplaySurface.create();
    if (_surface == null) return;
    
    // Start playback
    _session = await FFplayKit.executeAsync('-i "${widget.videoPath}"');
    
    // Listen for video dimensions
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
    
    // Listen for position updates
    _positionSub = _session!.positionStream.listen((position) {
      if (mounted) {
        setState(() => _playbackPosition = position);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Video display
        if (_hasVideo && _surface != null)
          SizedBox(
            width: _videoWidth.toDouble(),
            height: _videoHeight.toDouble(),
            child: _surface!.toWidget(),
          )
        else
          Container(
            height: 200,
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          
        // Controls
        Row(
          children: [
            IconButton(
              onPressed: () => FFplayKit.pause(),
              icon: const Icon(Icons.pause),
            ),
            IconButton(
              onPressed: () => FFplayKit.resume(),
              icon: const Icon(Icons.play_arrow),
            ),
            Expanded(
              child: Slider(
                value: _playbackPosition / (FFplayKit.duration > 0 ? FFplayKit.duration : 1.0),
                onChanged: (value) => FFplayKit.seek(value * FFplayKit.duration),
              ),
            ),
            Text('${_playbackPosition.toInt()}s'),
          ],
        ),
        
        ElevatedButton(
          onPressed: _startPlayback,
          child: const Text('Start Playback'),
        ),
      ],
    );
  }
}
```

## Monitoring Progress

Track the progress of long-running operations:

```dart
Future<void> convertWithProgress(String input, String output) async {
  // First, get the video duration
  final probeSession = FFprobeKit.getMediaInformation(input);
  double totalDuration = 0.0;
  
  if (probeSession is MediaInformationSession) {
    final info = probeSession.getMediaInformation();
    totalDuration = double.tryParse(info?.duration ?? '0') ?? 0.0;
  }
  
  // Now convert with progress tracking
  await FFmpegKit.executeAsync(
    '-i $input -c:v libx264 -preset medium $output',
    onStatistics: (stats) {
      if (totalDuration > 0) {
        final progress = (stats.time / 1000 / totalDuration) * 100;
        print('Progress: ${progress.toStringAsFixed(1)}%');
        print('Speed: ${stats.speed}x');
        print('Frame: ${stats.videoFrameNumber}');
      }
    },
    onComplete: (session) {
      if (ReturnCode.isSuccess(session.getReturnCode())) {
        print('✅ Conversion complete!');
      }
    },
  );
}
```

## Error Handling

Always check for errors and handle them appropriately:

```dart
void robustConversion(String input, String output) {
  try {
    final session = FFmpegKit.execute('-i $input $output');
    
    final returnCode = session.getReturnCode();
    
    if (ReturnCode.isSuccess(returnCode)) {
      print('✅ Success!');
    } else if (ReturnCode.isCancel(returnCode)) {
      print('⚠️ Operation was cancelled');
    } else {
      print('❌ Failed with return code: $returnCode');
      
      // Get detailed error information
      final output = session.getOutput();
      final logs = session.getLogs();
      
      print('Output: $output');
      print('Logs: $logs');
      
      // Check for common errors
      if (logs?.contains('No such file') ?? false) {
        print('Error: Input file not found');
      } else if (logs?.contains('Invalid') ?? false) {
        print('Error: Invalid command or parameters');
      }
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}
```

## Configuration

### Set Global Log Level

```dart
void main() {
  // Set log level before using FFmpeg
  FFmpegKitConfig.setLogLevel(LogLevel.info);
  
  runApp(MyApp());
}
```

### Enable Global Callbacks

```dart
void setupGlobalCallbacks() {
  // Log all FFmpeg output
  FFmpegKitConfig.enableLogCallback((log) {
    print('[FFmpeg ${log.logLevel}] ${log.message}');
  });
  
  // Track all statistics
  FFmpegKitConfig.enableStatisticsCallback((stats) {
    print('Global stats: ${stats.speed}x speed');
  });
}
```

## Next Steps

Now that you've got the basics, explore more advanced topics:

- **[Video Processing Guide](guides/video-processing.md)** - Learn common video operations
- **[Audio Processing Guide](guides/audio-processing.md)** - Audio conversion and manipulation
- **[Media Information Guide](guides/media-information.md)** - Extract and use metadata
- **[Callbacks Guide](guides/callbacks.md)** - Advanced callback usage
- **[API Reference](api/)** - Complete API documentation

## Common Issues

### Command Fails Silently

**Problem**: Command executes but doesn't produce expected output.

**Solution**: Check the session logs:

```dart
final session = FFmpegKit.execute('...');
print('Return code: ${session.getReturnCode()}');
print('Logs: ${session.getLogs()}');
```

### File Not Found

**Problem**: FFmpeg can't find the input file.

**Solution**: Use absolute paths:

```dart
import 'dart:io';

final absolutePath = File(relativePath).absolute.path;
FFmpegKit.execute('-i $absolutePath output.mp4');
```

### Async Not Completing

**Problem**: `executeAsync` doesn't call the completion callback.

**Solution**: Make sure you're using `await`:

```dart
await FFmpegKit.executeAsync('...', onComplete: (session) {
  // This will be called
});
```

## Tips

1. **Test Commands First**: Test your FFmpeg commands in the terminal before using them in your app
2. **Use Absolute Paths**: Always use absolute file paths to avoid path resolution issues
3. **Check Return Codes**: Always verify the return code before assuming success
4. **Monitor Logs**: Use log callbacks during development to understand what's happening
5. **Handle Errors**: Implement proper error handling for production apps

## Resources

- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [FFmpeg Wiki](https://trac.ffmpeg.org/wiki)
- [GitHub Repository](https://github.com/akashskypatel/ffmpeg-kit-extended)
- [Issue Tracker](https://github.com/akashskypatel/ffmpeg-kit-extended/issues)

Happy coding! 🚀
