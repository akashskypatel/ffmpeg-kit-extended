# FFmpegKit Extended for Flutter

<center>

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Downloads](https://img.shields.io/github/downloads/akashskypatel/ffmpeg-kit-extended/total?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/releases) [![GitHub release](https://img.shields.io/github/v/release/akashskypatel/ffmpeg-kit-extended?color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/releases) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</center>

`ffmpeg-kit-extended` is a comprehensive Flutter plugin for executing FFmpeg and FFprobe commands on Android, iOS, macOS, Windows, and Linux. It leverages Dart FFI to interact directly with native FFmpeg libraries, providing high performance and flexibility.

## Features

- **Cross-Platform Support**: Works on Windows, and Linux.
  - **Android, iOS, macOS**: Not yet supported.
- **FFmpeg, FFprobe & FFplay**: Full support for media manipulation and information retrieval.
- **Dart FFI**: Direct native bindings for optimal performance.
- **Asynchronous Execution**: Run long-running tasks without blocking the UI thread.
- **Parallel Execution**: Run multiple tasks in parallel.
- **Callback Support**: detailed hooks for logs, statistics, and session completion.
- **Session Management**: Full control over execution lifecycle (start, cancel, list).
- **Extensible**: Designed to allow custom native library loading and configuration.
- **Deploy Custom Builds**: You can deploy custom builds of ffmpeg-kit-extended. See: <https://github.com/akashskypatel/ffmpeg-kit-builders>

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Documentation](#documentation)
- [Examples](#examples)
- [License](#license)

## Installation

1. Install the package:

    ```bash
    flutter pub add ffmpeg_kit_extended_flutter
    ```

2. Add the dependency to your `pubspec.yaml` then add `ffmpeg_kit_extended_config` section to your `pubspec.yaml`:

    ```yaml
    dependencies:
      ffmpeg_kit_extended_flutter: ^0.1.0

    ffmpeg_kit_extended_config:
      version: "0.8.2" # version of the pre-bundled libffmpegkit libraries released at https://github.com/akashskypatel/ffmpeg-kit-builders/releases
      type: "base" # pre-bundled builds: base, full, audio, video, streaming, video_hw
      gpl: true # enable to include GPL libraries
      small: true # enable to use smaller builds
      # == OR ==
      # -------------------------------------------------------------
      # You can specify remote or local path to libffmpegkit libraries for each platform
      # This allows you to deploy custom builds of libffmpegkit.
      # See: https://github.com/akashskypatel/ffmpeg-kit-builders
      # Note: This will override all above options.
      # -------------------------------------------------------------
      # windows: "path/to/ffmpeg-kit/libraries"
      # linux: "https://path/to/ffmpeg-kit/libraries"
    ```

3. Run `dart run ffmpeg_kit_extended_flutter:configure` to generate the native libraries.

    ```bash
    dart run ffmpeg_kit_extended_flutter:configure
    ```

    **Configure Options**
    - `--help`: Show this help message.
    - `--platform=<platform1,platform2>`: Specify platforms to configure (e.g., `windows,linux`).
    - `--verbose`: Enable verbose output.
    - `--debug`: Enable debug mode. (Fetches remote bundles with debug symbols. Only base bundle is published with debug symbols. You can deploy your own using [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders))
    - `--app-root=<path>`: Specify the path to the app root.

4. Import the package in your Dart code:

    ```dart
    import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
    ```

## Quick Start

### Basic FFmpeg Command

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

// Execute a simple FFmpeg command asynchronously and wait for it to complete
final session = await FFmpegKit.executeAsync('-i input.mp4 -c:v libx264 output.mp4');

// Check the result
if (ReturnCode.isSuccess(session.getReturnCode())) {
  print('Conversion successful!');
} else {
  print('Conversion failed: ${session.getOutput()}');
}
```

### Get Media Information

```dart
// Retrieve media information using FFprobe asynchronously
final session = await FFprobeKit.getMediaInformationAsync('/path/to/video.mp4');

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
await FFplayKit.execute('-i input.mp4');

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

Comprehensive guides are available in the `flutter/doc/` directory:

### Getting Started

- [Installation Guide](flutter/doc/installation.md) - Detailed setup instructions *(Coming soon)*
- [Quick Start Guide](flutter/doc/quick-start.md) - Get up and running quickly
- [Core Concepts](flutter/doc/core-concepts.md) - Understanding sessions, callbacks, and execution modes

### API Reference

- [FFmpegKit API](flutter/doc/api/ffmpeg-kit.md) - Video and audio processing
- [FFprobeKit API](flutter/doc/api/ffprobe-kit.md) - Media information extraction
- [FFplayKit API](flutter/doc/api/ffplay-kit.md) - Media playback
- [FFmpegKitConfig API](flutter/doc/api/config.md) - Global configuration *(Coming soon)*
- [Session API](flutter/doc/api/sessions.md) - Session management and control *(Coming soon)*
- [Data Models](flutter/doc/api/data-models.md) - MediaInformation, Log, Statistics, etc. *(Coming soon)*

### Guides

- [Video Processing](flutter/doc/guides/video-processing.md) - Common video operations *(Coming soon)*
- [Audio Processing](flutter/doc/guides/audio-processing.md) - Audio conversion and manipulation *(Coming soon)*
- [Media Information](flutter/doc/guides/media-information.md) - Extracting and using media metadata *(Coming soon)*
- [Playback Control](flutter/doc/guides/playback-control.md) - Using FFplay for media playback *(Coming soon)*
- [Callbacks and Monitoring](flutter/doc/guides/callbacks.md) - Real-time progress tracking
- [Error Handling](flutter/doc/guides/error-handling.md) - Handling failures and edge cases *(Coming soon)*
- [Advanced Usage](flutter/doc/guides/advanced.md) - Pipes, fonts, environment variables *(Coming soon)*

### Examples

- [Common Use Cases](flutter/doc/examples/common-use-cases.md) - Practical examples
- [Complete Applications](flutter/doc/examples/complete-apps.md) - Full app examples

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
final session = await FFmpegKit.executeAsync(
  '-i video.mp4 -ss 00:00:05 -vframes 1 thumbnail.jpg'
);

if (ReturnCode.isSuccess(session.getReturnCode())) {
  print('Thumbnail extracted successfully');
}
```

### Audio Extraction

```dart
await FFmpegKit.executeAsync('-i video.mp4 -vn -acodec copy audio.aac');
```

### Get All Video Streams

```dart
final session = await FFprobeKit.getMediaInformationAsync('video.mp4');

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

### Custom FFplay Session

```dart
// Play a video file
await FFplayKit.execute('video.mp4');

// Check if currently playing
if (FFplayKit.isPlaying()) {
  print('Playback is active');
}
```

## Platform Support

| Platform | Status | Architecture |
|----------|--------|-------|
| Android  | 🚧 Planned | API 21+ |
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
final session = await FFmpegKit.executeAsync('...');
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

Only one FFplay session can be active at a time. Starting a new session with `FFplayKit.execute` will automatically handle the previous one.

```dart
await FFplayKit.execute('video.mp4');
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
