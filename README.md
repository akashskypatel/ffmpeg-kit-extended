<center>

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Downloads](https://img.shields.io/github/downloads/akashskypatel/ffmpeg-kit-extended/total?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/releases) [![GitHub release](https://img.shields.io/github/v/release/akashskypatel/ffmpeg-kit-extended?color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/releases) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</center>

# FFmpegKit Extended for Flutter

`ffmpeg-kit-extended` is a comprehensive Flutter plugin for executing FFmpeg and FFprobe commands on Android, iOS, macOS, Windows, and Linux. It leverages Dart FFI to interact directly with native FFmpeg libraries, providing high performance and flexibility.

### 1. Features

- **Cross-Platform Support**: Works on Android, iOS, macOS, Windows, and Linux.
- **FFmpeg & FFprobe**: Full support for media manipulation and information retrieval.
- **Dart FFI**: Direct native bindings for optimal performance.
- **Asynchronous Execution**: Run long-running tasks without blocking the UI thread.
- **Callback Support**: detailed hooks for logs, statistics, and session completion.
- **Session Management**: Full control over execution lifecycle (start, cancel, list).
- **Extensible**: Designed to allow custom native library loading and configuration.

### 2. Installation

Add `ffmpeg_kit_extended_flutter` as a dependency in your `pubspec.yaml` file.

```yaml
dependencies:
  ffmpeg_kit_extended_flutter: ^1.0.0
```

### 3. Usage

#### 3.1 Basic Command Execution

Execute an FFmpeg command asynchronously:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_extended_flutter/session.dart';

FFmpegKit.executeAsync('-i input.mp4 -c:v libx264 output.mp4', (session) async {
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

#### 3.2 Retrieving Media Information

Use `FFprobeKit` to get detailed metadata about a media file:

```dart
import 'package:ffmpeg_kit_extended_flutter/ffprobe_kit.dart';

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

#### 3.3 Handling Logs and Statistics

You can register logs and statistics callbacks for improved monitoring:

```dart
FFmpegKit.executeAsync(
  '-i input.mp4 output.mkv',
  (session) { /* Complete Callback */ },
  (log) {
    print("Log: ${log.message}");
  },
  (statistics) {
    print("Progress: ${statistics.time} ms, size: ${statistics.size}");
  },
);
```

#### 3.4 Session Management

All executions return a `Session` object which can be used to control the task:

```dart
// Cancel a specific session
FFmpegKit.cancelSession(sessionId);

// Cancel all active sessions
FFmpegKit.cancel();

// List all sessions
final sessions = FFmpegKit.getSessions();
```

### 4. Architecture

This plugin uses a modular architecture:

- **`ffmpeg_kit_extended.dart`**: The core FFI wrapper that interfaces with the native C library.
- **`ffmpeg_kit_config.dart`**: Manages global configurations (log levels, font directories, etc.).
- **`session.dart`**: Abstract base class for all session types (`FFmpegSession`, `FFprobeSession`, `FFplaySession`).
- **`callback_manager.dart`**: Handles the mapping between native function pointers and Dart callbacks.

### 5. License

This project is licensed under the LGPL v3.0 by default. However, depending on the underlying FFmpeg build configuration and external libraries used, the effective license may be GPL v3.0. Please review the licenses of the included libraries.
