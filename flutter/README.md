# FFmpeg Kit Extended Flutter

A powerful Flutter plugin that provides a complete wrapper for FFmpeg, FFprobe, and FFplay functionality. Execute multimedia commands, retrieve media information, and play media files directly from your Flutter applications.

[![License: LGPL v3](https://img.shields.io/badge/License-LGPL%20v3-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0.en.html)
[![Platform Support](https://img.shields.io/badge/platform-Linux%20|%20Windows-lightgrey.svg)](https://github.com/akashskypatel/ffmpeg-kit-extended)

## Features

- ✅ **FFmpeg Support** - Execute FFmpeg commands for video/audio processing
- ✅ **FFprobe Support** - Extract detailed media information
- ✅ **FFplay Support** - Play media files with playback controls
- ✅ **Synchronous & Asynchronous Execution** - Choose the execution model that fits your needs
- ✅ **Real-time Callbacks** - Monitor logs, statistics, and completion events
- ✅ **Session Management** - Track and control multiple concurrent operations
- ✅ **Cross-platform** - Works on Linux, and Windows

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Documentation](#documentation)
- [Examples](#examples)
- [License](#license)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  ffmpeg_kit_extended_flutter: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### Basic FFmpeg Command

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_flutter.dart';

// Execute a simple FFmpeg command
final session = FFmpegKit.execute('-i input.mp4 -c:v libx264 output.mp4');

// Check the result
if (ReturnCode.isSuccess(session.getReturnCode())) {
  print('Conversion successful!');
} else {
  print('Conversion failed: ${session.getOutput()}');
}
```

### Get Media Information

```dart
// Retrieve media information using FFprobe
final session = FFprobeKit.getMediaInformation('/path/to/video.mp4');

if (session is MediaInformationSession) {
  final info = session.getMediaInformation();
  print('Duration: ${info?.duration}');
  print('Format: ${info?.format}');
  print('Bitrate: ${info?.bitrate}');
  print('Streams: ${info?.streams.length}');
}
```

### Play Media with FFplay

```dart
// Play a media file
FFplayKit.execute('input.mp4');

// Control playback
FFplayKit.pause();
FFplayKit.resume();
FFplayKit.seek(30.0); // Seek to 30 seconds

// Get playback status
final position = FFplayKit.getPosition();
final duration = FFplayKit.getDuration();
print('Playing at $position / $duration seconds');
```

### Async Execution with Callbacks

```dart
// Execute asynchronously with callbacks
await FFmpegKit.executeAsync(
  '-i input.mp4 -vf scale=1280:720 output.mp4',
  onComplete: (session) {
    print('Command completed with return code: ${session.getReturnCode()}');
  },
  onLog: (log) {
    print('FFmpeg log: ${log.message}');
  },
  onStatistics: (statistics) {
    print('Progress: ${statistics.time}ms, Speed: ${statistics.speed}x');
  },
);
```

## Core Concepts

### Sessions

Every FFmpeg, FFprobe, or FFplay command creates a **Session** object that tracks:

- Execution state (created, running, completed, failed)
- Return code and output
- Logs and statistics
- Timing information (start time, end time, duration)

### Execution Modes

**Synchronous**: Blocks until the command completes

```dart
final session = FFmpegKit.execute('-i input.mp4 output.mp4');
```

**Asynchronous**: Returns immediately and notifies via callbacks

```dart
await FFmpegKit.executeAsync('-i input.mp4 output.mp4',
  onComplete: (session) => print('Done!'),
);
```

### Callbacks

Three types of callbacks are available for FFmpeg operations:

1. **Log Callback** - Receives log messages from FFmpeg
2. **Statistics Callback** - Receives real-time encoding statistics
3. **Complete Callback** - Called when the session finishes

Callbacks can be set globally or per-session.

## Documentation

Comprehensive guides are available in the `docs/` directory:

### Getting Started

- [Installation Guide](docs/installation.md) - Detailed setup instructions *(Coming soon)*
- [Quick Start Guide](docs/quick-start.md) - Get up and running quickly
- [Core Concepts](docs/core-concepts.md) - Understanding sessions, callbacks, and execution modes

### API Reference

- [FFmpegKit API](docs/api/ffmpeg-kit.md) - Video and audio processing
- [FFprobeKit API](docs/api/ffprobe-kit.md) - Media information extraction
- [FFplayKit API](docs/api/ffplay-kit.md) - Media playback
- [FFmpegKitConfig API](docs/api/config.md) - Global configuration *(Coming soon)*
- [Session API](docs/api/sessions.md) - Session management and control *(Coming soon)*
- [Data Models](docs/api/data-models.md) - MediaInformation, Log, Statistics, etc. *(Coming soon)*

### Guides

- [Video Processing](docs/guides/video-processing.md) - Common video operations *(Coming soon)*
- [Audio Processing](docs/guides/audio-processing.md) - Audio conversion and manipulation *(Coming soon)*
- [Media Information](docs/guides/media-information.md) - Extracting and using media metadata *(Coming soon)*
- [Playback Control](docs/guides/playback-control.md) - Using FFplay for media playback *(Coming soon)*
- [Callbacks and Monitoring](docs/guides/callbacks.md) - Real-time progress tracking
- [Error Handling](docs/guides/error-handling.md) - Handling failures and edge cases *(Coming soon)*
- [Advanced Usage](docs/guides/advanced.md) - Pipes, fonts, environment variables *(Coming soon)*

### Examples

- [Common Use Cases](docs/examples/common-use-cases.md) - Practical examples *(Coming soon)*
- [Complete Applications](docs/examples/complete-apps.md) - Full app examples *(Coming soon)*

## Examples

### Video Conversion with Progress

```dart
await FFmpegKit.executeAsync(
  '-i input.mp4 -c:v libx264 -preset medium -crf 23 output.mp4',
  onStatistics: (stats) {
    final progress = (stats.time / totalDuration) * 100;
    print('Progress: ${progress.toStringAsFixed(1)}%');
  },
  onComplete: (session) {
    if (ReturnCode.isSuccess(session.getReturnCode())) {
      print('Conversion complete!');
    }
  },
);
```

### Extract Video Thumbnail

```dart
final session = FFmpegKit.execute(
  '-i video.mp4 -ss 00:00:05 -vframes 1 thumbnail.jpg'
);

if (ReturnCode.isSuccess(session.getReturnCode())) {
  print('Thumbnail extracted successfully');
}
```

### Audio Extraction

```dart
FFmpegKit.execute('-i video.mp4 -vn -acodec copy audio.aac');
```

### Get All Video Streams

```dart
final session = FFprobeKit.getMediaInformation('video.mp4');

if (session is MediaInformationSession) {
  final info = session.getMediaInformation();
  final videoStreams = info?.streams
      .where((s) => s.type == 'video')
      .toList() ?? [];
  
  for (final stream in videoStreams) {
    print('Video stream: ${stream.codec}, ${stream.width}x${stream.height}');
  }
}
```

### Custom FFplay Session with Conflict Handling

```dart
// Terminate any existing playback before starting new one
FFplayKit.execute(
  'video.mp4',
  strategy: SessionConflictStrategy.terminate,
);

// Or wait for current playback to finish
FFplayKit.execute(
  'next-video.mp4',
  strategy: SessionConflictStrategy.waitForCompletion,
);
```

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Android  | Not Supported | API 21+ |
| iOS      | Not Supported | iOS 12+ |
| macOS    | Not Supported | macOS 10.13+ |
| Linux    | ✅ Supported | x86_64 |
| Windows  | ✅ Supported | x86_64 |

## Configuration

### Global Log Level

```dart
FFmpegKitConfig.setLogLevel(LogLevel.info);
```

### Font Directory (for subtitle rendering)

```dart
FFmpegKitConfig.setFontDirectory('/path/to/fonts');
```

### Session History

```dart
// Limit the number of sessions kept in history
FFmpegKitConfig.setSessionHistorySize(10);
```

### Global Callbacks

```dart
// Set global log callback for all sessions
FFmpegKitConfig.enableLogCallback((log) {
  print('[${log.logLevel}] ${log.message}');
});

// Set global statistics callback
FFmpegKitConfig.enableStatisticsCallback((stats) {
  print('Speed: ${stats.speed}x, Frame: ${stats.videoFrameNumber}');
});
```

## Troubleshooting

### Command Fails Silently

Check the session output and logs:

```dart
final session = FFmpegKit.execute('...');
print('Return code: ${session.getReturnCode()}');
print('Output: ${session.getOutput()}');
print('Logs: ${session.getLogs()}');
```

### Async Operations Not Completing

Ensure you're using `await` and handling the Future properly:

```dart
await FFmpegKit.executeAsync('...', onComplete: (session) {
  // This will be called when done
});
```

### FFplay Session Conflicts

Only one FFplay session can be active at a time. Use `SessionConflictStrategy`:

```dart
FFplayKit.execute('video.mp4', 
  strategy: SessionConflictStrategy.terminate
);
```

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to our repository.

## License

This library is licensed under the GNU Lesser General Public License v2.1 or later.

```
FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
Copyright (C) 2026 Akash Patel

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.
```

See the [LICENSE](../LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/akashskypatel/ffmpeg-kit-extended/issues)
- **Repository**: [GitHub](https://github.com/akashskypatel/ffmpeg-kit-extended)

## Acknowledgments

This plugin is built on top of FFmpeg, FFprobe, and FFplay. Special thanks to the FFmpeg team for their incredible work on these tools.
