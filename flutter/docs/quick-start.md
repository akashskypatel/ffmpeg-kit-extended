# Quick Start Guide

Get up and running with FFmpeg Kit Extended Flutter in minutes!

## Installation

1. Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  ffmpeg_kit_extended_flutter: ^1.0.0
```

1. Install the package:

```bash
flutter pub get
```

1. Import the package in your Dart code:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_flutter.dart';
```

## Your First FFmpeg Command

Let's convert a video file:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_flutter.dart';

void convertVideo() {
  final session = FFmpegKit.execute(
    '-i input.mp4 -c:v libx264 -crf 23 output.mp4'
  );
  
  if (ReturnCode.isSuccess(session.getReturnCode())) {
    print('✅ Video converted successfully!');
  } else {
    print('❌ Conversion failed');
    print('Error: ${session.getOutput()}');
  }
}
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

### 5. Play a Video

```dart
void playVideo(String videoPath) {
  FFplayKit.executeAsync(
    videoPath,
    onComplete: (session) {
      print('🎬 Playback finished');
    },
  );
  
  // Control playback
  Future.delayed(Duration(seconds: 5), () {
    FFplayKit.pause();
    print('⏸️ Paused');
  });
  
  Future.delayed(Duration(seconds: 7), () {
    FFplayKit.resume();
    print('▶️ Resumed');
  });
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

## Complete Example: Video Converter App

Here's a complete example of a simple video converter:

```dart
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_flutter.dart';
import 'package:file_picker/file_picker.dart';

class VideoConverterPage extends StatefulWidget {
  @override
  _VideoConverterPageState createState() => _VideoConverterPageState();
}

class _VideoConverterPageState extends State<VideoConverterPage> {
  String? _inputPath;
  String? _outputPath;
  double _progress = 0.0;
  bool _isConverting = false;
  String _status = 'Ready';
  
  Future<void> _pickInputFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );
    
    if (result != null) {
      setState(() {
        _inputPath = result.files.single.path;
        _outputPath = _inputPath!.replaceAll('.mp4', '_converted.mp4');
      });
    }
  }
  
  Future<void> _startConversion() async {
    if (_inputPath == null || _outputPath == null) return;
    
    setState(() {
      _isConverting = true;
      _progress = 0.0;
      _status = 'Getting video information...';
    });
    
    // Get video duration for progress calculation
    final probeSession = FFprobeKit.getMediaInformation(_inputPath!);
    double totalDuration = 0.0;
    
    if (probeSession is MediaInformationSession) {
      final info = probeSession.getMediaInformation();
      totalDuration = double.tryParse(info?.duration ?? '0') ?? 0.0;
    }
    
    setState(() => _status = 'Converting...');
    
    // Start conversion
    await FFmpegKit.executeAsync(
      '-i $_inputPath -c:v libx264 -preset medium -crf 23 $_outputPath',
      onStatistics: (stats) {
        if (totalDuration > 0) {
          setState(() {
            _progress = (stats.time / 1000 / totalDuration).clamp(0.0, 1.0);
            _status = 'Converting... ${(_progress * 100).toStringAsFixed(1)}%';
          });
        }
      },
      onComplete: (session) {
        setState(() {
          _isConverting = false;
          
          if (ReturnCode.isSuccess(session.getReturnCode())) {
            _status = 'Conversion complete!';
            _progress = 1.0;
          } else {
            _status = 'Conversion failed';
            _progress = 0.0;
          }
        });
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Video Converter')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input file
            ElevatedButton(
              onPressed: _isConverting ? null : _pickInputFile,
              child: Text('Select Video'),
            ),
            
            if (_inputPath != null) ...[
              SizedBox(height: 8),
              Text('Input: $_inputPath', style: TextStyle(fontSize: 12)),
              Text('Output: $_outputPath', style: TextStyle(fontSize: 12)),
            ],
            
            SizedBox(height: 24),
            
            // Convert button
            ElevatedButton(
              onPressed: (_inputPath != null && !_isConverting)
                  ? _startConversion
                  : null,
              child: Text('Convert'),
            ),
            
            SizedBox(height: 24),
            
            // Progress
            if (_isConverting) ...[
              LinearProgressIndicator(value: _progress),
              SizedBox(height: 8),
            ],
            
            // Status
            Text(
              _status,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
