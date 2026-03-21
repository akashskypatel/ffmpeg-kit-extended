# Complete Application Examples

## Example App

The plugin ships with a fully functional example application located at [`flutter/example/`](../../example/). It is the best starting point for understanding real-world usage of the plugin.

### Running the Example

```bash
cd flutter/example
dart run ffmpeg_kit_extended_flutter:configure
flutter run -d windows   # or -d linux
```

### What It Demonstrates

The example is a tabbed desktop app with three sections, each covering a different tool:

#### FFmpeg Tab

- Generate test video and audio using FFmpeg filters (`testsrc`, `sine`)
- Execute commands synchronously and asynchronously
- Run arbitrary custom FFmpeg commands
- Display real-time log output in a terminal-style viewer

```dart
// From the example app: async execution with real-time logs
await FFmpegKit.executeAsync(
  command,
  onLog: (log) {
    setState(() => _logs.add(log.message));
  },
  onComplete: (session) {
    final code = session.getReturnCode();
    setState(() => _logs.add('Done. Return code: $code'));
  },
);
```

#### FFprobe Tab

- Pick a media file using a file picker
- Extract and display format information (duration, bitrate, format name, stream count)
- Show per-stream details: type, codec, resolution, sample rate, channel layout
- Execute arbitrary custom FFprobe commands

```dart
// From the example app: extract and display stream details
await FFprobeKit.getMediaInformationAsync(
  path,
  onComplete: (session) {
    if (session.isMediaInformationSession()) {
      final info = session.getMediaInformation();
      for (final stream in info?.streams ?? []) {
        print('${stream.type}: ${stream.codec}');
        if (stream.type == 'video') {
          print('  ${stream.width}x${stream.height} @ ${stream.averageFrameRate}');
        } else if (stream.type == 'audio') {
          print('  ${stream.sampleRate} Hz, ${stream.channelLayout}');
        }
      }
    }
  },
);
```

#### FFplay Tab

- Generate and play video/audio
- Interactive playback controls: pause, resume, stop
- Seek slider for scrubbing to any position
- Live position and duration display (updated every second)

```dart
// From the example app: playback with real-time position tracking
await FFplayKit.executeAsync(
  command,
  onComplete: (session) => setState(() => _playing = false),
);

// Periodic update (runs every 1 second via Timer)
_position = FFplayKit.position;   // double, seconds
_duration = FFplayKit.duration;   // double, seconds
_playing  = FFplayKit.playing;    // bool
```

### App-Level Initialization

The example shows the required initialization pattern:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();
  runApp(const MyApp());
}
```

### Integration Tests

The example includes a comprehensive integration test suite at [`flutter/example/integration_test/plugin_integration_test.dart`](../../example/integration_test/plugin_integration_test.dart) covering:

- `FFmpegKitConfig` — version, log level, session history, argument parsing
- `FFmpegKit` — sync/async execution, callbacks, cancellation, session timing, output capture
- `FFprobeKit` — media information extraction, stream details, session management
- `FFplayKit` — play/pause/stop/seek, volume, position/duration tracking
- `SessionQueueManager` — concurrency limits, queue cancellation
- Memory safety — stress tests with up to 500 iterations

Run the integration tests with:

```bash
cd flutter/example
flutter test integration_test/plugin_integration_test.dart -d <device-id>
```

---

## Architectural Patterns

The examples below illustrate patterns you can adapt from the example app for your own applications.

### Video Converter

```dart
class ConversionTask {
  final String input;
  final String output;
  double progress = 0;
  SessionState state = SessionState.created;

  Future<void> run(double totalDurationMs) async {
    await FFmpegKit.executeAsync(
      '-i $input $output',
      onStatistics: (s) {
        progress = (s.time / totalDurationMs).clamp(0.0, 1.0);
      },
      onComplete: (s) => state = s.getState(),
    );
  }
}
```

### Media Player with Metadata

```dart
Future<void> onLoadMedia(String path) async {
  // Extract metadata first
  final session = await FFprobeKit.getMediaInformationAsync(path);
  if (session.isMediaInformationSession()) {
    final info = session.getMediaInformation();
    setState(() {
      currentTitle = info?.tags?['title'] ?? 'Unknown';
      totalDuration = double.tryParse(info?.duration ?? '0') ?? 0.0;
    });
  }

  // Then start playback
  await FFplayKit.execute(path);
}
```

### Live Filter Preview (Video Editor)

```dart
Future<void> onBrightnessChanged(double value) async {
  await FFmpegKit.executeAsync(
    '-ss $currentTime -i $input -vf "eq=brightness=$value" -vframes 1 preview.jpg',
  );
  // Reload preview.jpg in your image widget
}
```

## Design Considerations

1. **Initialization**: Always call `await FFmpegKitExtended.initialize()` before any API call. See the example app's `main()` for the correct pattern.
2. **Power Management**: Media processing is CPU intensive. Use the `wakelock` plugin to prevent the device from sleeping during long conversions.
3. **Notification Integration**: For long-running background tasks, use `flutter_local_notifications` to show progress in the system tray.
4. **Storage Access**: On Android 11+, use Scoped Storage correctly or request `MANAGE_EXTERNAL_STORAGE` for arbitrary file access. The example app demonstrates permission handling for Android.
