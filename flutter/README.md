# FFmpegKit Extended for Flutter

<center>

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Downloads](https://img.shields.io/github/downloads/akashskypatel/ffmpeg-kit-extended/total?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/releases) [![GitHub release](https://img.shields.io/github/v/release/akashskypatel/ffmpeg-kit-extended?color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/releases) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</center>

`ffmpeg-kit-extended` is a comprehensive Flutter plugin for executing FFmpeg and FFprobe commands on Android, iOS, macOS, Windows, and Linux. It leverages Dart FFI to interact directly with native FFmpeg libraries, providing high performance and flexibility.

## 1. Features

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

## 2. Installation

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

3. Import the package in your Dart code:

    ```dart
    import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
    ```

4. Run `dart run ffmpeg_kit_extended_flutter:configure` to generate the native libraries.

    ```bash
    dart run ffmpeg_kit_extended_flutter:configure
    ```

    **Configure Options**
    - `--help`: Show this help message.
    - `--platform=<platform1,platform2>`: Specify platforms to configure (e.g., `windows,linux`).
    - `--verbose`: Enable verbose output.
    - `--debug`: Enable debug mode. (Fetches remote bundles with debug symbols. Only base bundle is published with debug symbols. You can deploy your own using [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders))
    - `--app-root=<path>`: Specify the path to the app root.

### 2.1 Pre-bundled Builds

- **base**: Basic build with core FFmpeg libraries. Does not contain any extra libraries.
- **full**: Full build with all platform-compatible FFmpeg libraries. See: <https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries>
- **audio**: Build with audio-only FFmpeg libraries.
- **video**: Build with video-only FFmpeg libraries.
- **streaming**: Build with streaming FFmpeg libraries.
- **video_hw**: Build with hardware-accelerated video FFmpeg libraries.

|Feature  |Audio   |Video   |Streaming|Video+Hardware|
|---------|--------|--------|-------- |--------------|
|Video    |        |x       |x        |              |
|Audio    |x       |x       |x        |              |
|Streaming|        |        |x        |              |
|Hardware |        |        |         |x             |
|AI       |        |        |         |              |
|HTTPS    |x       |x       |x        |x             |

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

## 4. Architecture

This plugin uses a modular architecture:

- **`ffmpeg_kit_extended.dart`**: The core FFI wrapper that interfaces with the native C library.
- **`ffmpeg_kit_config.dart`**: Manages global configurations (log levels, font directories, etc.).
- **`session.dart`**: Abstract base class for all session types (`FFmpegSession`, `FFprobeSession`, `FFplaySession`).
- **`callback_manager.dart`**: Handles the mapping between native function pointers and Dart callbacks.

## 5. License

This project is licensed under the LGPL v3.0 by default. However, depending on the underlying FFmpeg build configuration and external libraries used, the effective license may be GPL v3.0. Please review the licenses of the included libraries.
