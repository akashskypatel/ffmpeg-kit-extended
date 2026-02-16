# Documentation Index

Complete documentation for FFmpeg Kit Extended Flutter plugin.

## Getting Started

- **[README](../README.md)** - Main overview and quick examples
- **[Quick Start Guide](quick-start.md)** - Get up and running in minutes

## API Reference

Complete API documentation for all classes and methods:

- **[FFmpegKit API](api/ffmpeg-kit.md)** - Video and audio processing
  - Execute FFmpeg commands synchronously and asynchronously
  - Monitor progress with callbacks
  - Session management
  - Common video operations

- **[FFprobeKit API](api/ffprobe-kit.md)** - Media information extraction
  - Get media metadata (duration, format, bitrate, etc.)
  - Extract stream information (video, audio, subtitle)
  - Parse chapter and tag information
  - Custom FFprobe commands

- **[FFplayKit API](api/ffplay-kit.md)** - Media playback
  - Play media files
  - Playback controls (play, pause, seek, stop)
  - Position and duration tracking
  - Session conflict resolution

- **[FFmpegKitConfig API](api/config.md)** - Global configuration *(Coming soon)*
  - Log level settings
  - Font directory configuration
  - Global callbacks
  - Session history management

- **[Session API](api/sessions.md)** - Session management *(Coming soon)*
  - FFmpegSession, FFprobeSession, FFplaySession
  - Session state and lifecycle
  - Return codes and error handling
  - Logs and statistics retrieval

- **[Data Models](api/data-models.md)** - Data structures *(Coming soon)*
  - MediaInformation
  - StreamInformation
  - ChapterInformation
  - Log and Statistics

## User Guides

Comprehensive guides for common tasks:

- **[Video Processing](guides/video-processing.md)** - Complete video operations guide
  - Video conversion and compression
  - Resolution and scaling
  - Trimming and cutting
  - Concatenation
  - Watermarks and overlays
  - Frame extraction
  - Format conversion
  - Advanced filters (rotate, flip, crop, blur, etc.)

- **[Audio Processing](guides/audio-processing.md)** - Audio operations *(Coming soon)*
  - Audio extraction and conversion
  - Audio compression
  - Volume adjustment
  - Audio mixing
  - Format conversion

- **[Media Information](guides/media-information.md)** - Working with metadata *(Coming soon)*
  - Extracting media information
  - Parsing stream details
  - Reading metadata tags
  - Analyzing video properties

- **[Playback Control](guides/playback-control.md)** - FFplay usage *(Coming soon)*
  - Basic playback
  - Playback controls
  - Custom player UI
  - Session management

- **[Callbacks and Monitoring](guides/callbacks.md)** - Real-time monitoring
  - Log callbacks
  - Statistics callbacks
  - Complete callbacks
  - Progress tracking
  - Real-time logging
  - Statistics monitoring
  - UI integration

- **[Error Handling](guides/error-handling.md)** - Handling failures *(Coming soon)*
  - Return code checking
  - Log analysis
  - Common errors and solutions
  - Debugging strategies

- **[Advanced Usage](guides/advanced.md)** - Advanced topics *(Coming soon)*
  - FFmpeg pipes
  - Font configuration for subtitles
  - Environment variables
  - Custom build configurations

## Examples

- **[Common Use Cases](examples/common-use-cases.md)** - Practical examples *(Coming soon)*
  - Video thumbnail generation
  - Video compression
  - Audio extraction
  - Format conversion
  - Watermarking

- **[Complete Applications](examples/complete-apps.md)** - Full app examples *(Coming soon)*
  - Video converter app
  - Media player app
  - Video editor app

## Quick Reference

### Installation

```yaml
dependencies:
  ffmpeg_kit_extended_flutter: ^1.0.0
```

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_flutter.dart';
```

### Basic Usage

```dart
// Execute FFmpeg command
final session = FFmpegKit.execute('-i input.mp4 output.mp4');

// Get media information
final session = FFprobeKit.getMediaInformation('video.mp4');

// Play media
FFplayKit.execute('video.mp4');
```

### Async with Callbacks

```dart
await FFmpegKit.executeAsync(
  '-i input.mp4 output.mp4',
  onStatistics: (stats) => print('Progress: ${stats.time}ms'),
  onComplete: (session) => print('Done!'),
);
```

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Android  | ✅ Supported | API 21+ |
| iOS      | ✅ Supported | iOS 12+ |
| macOS    | ✅ Supported | macOS 10.13+ |
| Linux    | ✅ Supported | x86_64 |
| Windows  | ✅ Supported | x86_64 |

## Additional Resources

- **Repository**: [GitHub](https://github.com/akashskypatel/ffmpeg-kit-extended)
- **Issues**: [Issue Tracker](https://github.com/akashskypatel/ffmpeg-kit-extended/issues)
- **FFmpeg Documentation**: [ffmpeg.org](https://ffmpeg.org/documentation.html)
- **FFmpeg Wiki**: [trac.ffmpeg.org/wiki](https://trac.ffmpeg.org/wiki)

## Contributing

Contributions are welcome! Please see the repository for contribution guidelines.

## License

This library is licensed under the GNU Lesser General Public License v2.1 or later. See the [LICENSE](../LICENSE) file for details.

---

**Note**: Documentation marked with *(Coming soon)* is planned for future releases. The core API documentation and essential guides are already available.
