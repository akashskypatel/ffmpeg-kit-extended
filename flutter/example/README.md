# FFmpegKit Extended Flutter Example

This example application demonstrates the core features of the `ffmpeg_kit_extended_flutter` plugin, providing a practical implementation of media processing and playback on Desktop platforms.

## Getting Started

### Prerequisites

- **Flutter SDK**
- **C++ Compiler** (GCC/Clang) for native library linking
- **Platform**: Windows or Linux (x86_64)

### 1. Install Dependencies

From the example directory, fetch the Flutter packages:

```bash
flutter pub get
```

### 2. Configure Native Libraries

This plugin requires a configuration step to download or link the native FFmpeg binaries specified in the `pubspec.yaml`. Run the following command:

```bash
dart run ffmpeg_kit_extended_flutter:configure
```

### 3. Run the App

```bash
flutter run
```

## Features Demonstrated

- **FFmpeg Execution**: Asynchronous video conversion with real-time statistics and log tracking.
- **FFprobe Integration**: Extracting detailed metadata, stream information, and chapters from media files.
- **FFplay Playback**: A functional media player implementation showing playback control (seek, pause, resume) and duration tracking.
- **Session Management**: Monitoring active tasks and handling session lifecycles.

## Implementation Details

- Look at `lib/main.dart` for the UI implementation and callback handling.
- Review how `FFmpegKit.executeAsync` is used to prevent UI blocking during heavy transcodes.
- See the `MediaInformation` parsing logic to understand how to handle FFprobe results.
