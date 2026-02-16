# FFprobeKit API Reference

The `FFprobeKit` class provides a convenient interface for extracting media information using FFprobe.

## Overview

`FFprobeKit` allows you to:

- Extract detailed media information (duration, format, bitrate, etc.)
- Retrieve stream information (video, audio, subtitle streams)
- Execute custom FFprobe commands
- Get chapter and metadata information

## Class Methods

### getMediaInformation

Retrieves comprehensive media information for a file synchronously.

```dart
static MediaInformationSession getMediaInformation(String path)
```

**Parameters:**

- `path` (String): The path or URL to the media file

**Returns:**

- `MediaInformationSession`: A session containing the media information

**Example:**

```dart
final session = FFprobeKit.getMediaInformation('/path/to/video.mp4');

if (session is MediaInformationSession) {
  final info = session.getMediaInformation();
  
  if (info != null) {
    print('Duration: ${info.duration} seconds');
    print('Format: ${info.format}');
    print('Bitrate: ${info.bitrate} bps');
    print('Size: ${info.size} bytes');
    print('Number of streams: ${info.streams.length}');
  }
}
```

---

### getMediaInformationAsync

Retrieves media information asynchronously.

```dart
static Future<FFprobeSession> getMediaInformationAsync(
  String path, {
  FFprobeSessionCompleteCallback? onComplete,
})
```

**Parameters:**

- `path` (String): The path or URL to the media file
- `onComplete` (FFprobeSessionCompleteCallback?, optional): Callback invoked when complete

**Returns:**

- `Future<FFprobeSession>`: A Future that completes with the session

**Example:**

```dart
await FFprobeKit.getMediaInformationAsync(
  '/path/to/video.mp4',
  onComplete: (session) {
    if (session is MediaInformationSession) {
      final info = session.getMediaInformation();
      print('Media info retrieved: ${info?.format}');
    }
  },
);
```

---

### execute

Executes a custom FFprobe command synchronously.

```dart
static FFprobeSession execute(String command)
```

**Parameters:**

- `command` (String): The FFprobe command to execute (without the `ffprobe` prefix)

**Returns:**

- `FFprobeSession`: A session object containing execution results

**Example:**

```dart
// Get JSON output for all streams
final session = FFprobeKit.execute(
  '-v quiet -print_format json -show_streams input.mp4'
);

final output = session.getOutput();
print('FFprobe output: $output');
```

---

### executeAsync

Executes a custom FFprobe command asynchronously.

```dart
static Future<FFprobeSession> executeAsync(
  String command, {
  FFprobeSessionCompleteCallback? onComplete,
})
```

**Parameters:**

- `command` (String): The FFprobe command to execute
- `onComplete` (FFprobeSessionCompleteCallback?, optional): Callback invoked when complete

**Returns:**

- `Future<FFprobeSession>`: A Future that completes with the session

**Example:**

```dart
await FFprobeKit.executeAsync(
  '-v quiet -show_format input.mp4',
  onComplete: (session) {
    print('Output: ${session.getOutput()}');
  },
);
```

---

### cancel

Cancels a running FFprobe session.

```dart
static void cancel(FFprobeSession session)
```

**Parameters:**

- `session` (FFprobeSession): The session to cancel

**Example:**

```dart
final session = FFprobeKit.getMediaInformation('large-file.mp4');
// ... later
FFprobeKit.cancel(session);
```

---

### createSession

Creates a new FFprobe session without executing it.

```dart
static FFprobeSession createSession(
  String command, {
  FFprobeSessionCompleteCallback? onComplete,
})
```

**Parameters:**

- `command` (String): The FFprobe command for the session
- `onComplete` (FFprobeSessionCompleteCallback?, optional): Completion callback

**Returns:**

- `FFprobeSession`: A new session object (not yet executed)

**Example:**

```dart
final session = FFprobeKit.createSession(
  '-show_format input.mp4',
  onComplete: (session) => print('Done'),
);
// Execute later if needed
```

---

### getFFprobeSessions

Returns all active FFprobe sessions.

```dart
static List<FFprobeSession> getFFprobeSessions()
```

**Returns:**

- `List<FFprobeSession>`: A list of all active FFprobe sessions

**Example:**

```dart
final sessions = FFprobeKit.getFFprobeSessions();
print('Active FFprobe sessions: ${sessions.length}');
```

## Callback Types

### FFprobeSessionCompleteCallback

Called when an FFprobe session completes.

```dart
typedef FFprobeSessionCompleteCallback = void Function(FFprobeSession session);
```

**Example:**

```dart
void onComplete(FFprobeSession session) {
  if (ReturnCode.isSuccess(session.getReturnCode())) {
    print('FFprobe completed successfully');
    
    if (session is MediaInformationSession) {
      final info = session.getMediaInformation();
      // Process media information
    }
  }
}
```

## MediaInformation Class

The `MediaInformation` class contains comprehensive metadata about a media file.

### Properties

```dart
class MediaInformation {
  final String? filename;        // File path or URL
  final String? format;          // Format name (e.g., "mp4", "mkv")
  final String? longFormat;      // Long format description
  final String? duration;        // Duration in seconds
  final String? startTime;       // Start time in seconds
  final String? bitrate;         // Bitrate in bits per second
  final String? size;            // File size in bytes
  final String? tagsJson;        // JSON string of tags
  final String? allPropertiesJson; // JSON string of all properties
  
  Map<String, dynamic>? get tags;        // Parsed tags
  Map<String, dynamic>? get allProperties; // Parsed properties
  
  final List<StreamInformation> streams;  // Media streams
  final List<ChapterInformation> chapters; // Media chapters
}
```

### Example Usage

```dart
final session = FFprobeKit.getMediaInformation('video.mp4');

if (session is MediaInformationSession) {
  final info = session.getMediaInformation();
  
  if (info != null) {
    // Basic information
    print('File: ${info.filename}');
    print('Format: ${info.format} (${info.longFormat})');
    print('Duration: ${info.duration}s');
    print('Bitrate: ${info.bitrate} bps');
    print('Size: ${info.size} bytes');
    
    // Tags (metadata)
    final tags = info.tags;
    if (tags != null) {
      print('Title: ${tags['title']}');
      print('Artist: ${tags['artist']}');
      print('Album: ${tags['album']}');
    }
    
    // Streams
    for (final stream in info.streams) {
      print('Stream ${stream.index}: ${stream.type}');
      if (stream.type == 'video') {
        print('  Resolution: ${stream.width}x${stream.height}');
        print('  Codec: ${stream.codec}');
        print('  FPS: ${stream.frameRate}');
      } else if (stream.type == 'audio') {
        print('  Codec: ${stream.codec}');
        print('  Sample rate: ${stream.sampleRate}');
        print('  Channels: ${stream.channels}');
      }
    }
    
    // Chapters
    for (final chapter in info.chapters) {
      print('Chapter ${chapter.id}: ${chapter.title}');
      print('  Start: ${chapter.start}, End: ${chapter.end}');
    }
  }
}
```

## StreamInformation Class

Represents a single stream (video, audio, subtitle, etc.) within a media file.

### Properties

```dart
class StreamInformation {
  final int index;           // Stream index
  final String type;         // Stream type: "video", "audio", "subtitle", etc.
  final String? codec;       // Codec name
  final String? codecLong;   // Long codec description
  final String? format;      // Pixel format or sample format
  
  // Video-specific
  final int? width;          // Video width in pixels
  final int? height;         // Video height in pixels
  final String? aspectRatio; // Display aspect ratio
  final String? frameRate;   // Frame rate (e.g., "30/1")
  
  // Audio-specific
  final String? sampleRate;  // Sample rate in Hz
  final int? channels;       // Number of audio channels
  final String? channelLayout; // Channel layout (e.g., "stereo")
  
  final String? bitrate;     // Stream bitrate
  final String? language;    // Language code
  final String? tagsJson;    // JSON string of stream tags
  
  Map<String, dynamic>? get tags; // Parsed tags
}
```

## Common Use Cases

### Check Video Resolution

```dart
final session = FFprobeKit.getMediaInformation('video.mp4');

if (session is MediaInformationSession) {
  final info = session.getMediaInformation();
  final videoStream = info?.streams.firstWhere(
    (s) => s.type == 'video',
    orElse: () => throw Exception('No video stream found'),
  );
  
  print('Resolution: ${videoStream.width}x${videoStream.height}');
}
```

### Get Video Duration

```dart
final session = FFprobeKit.getMediaInformation('video.mp4');

if (session is MediaInformationSession) {
  final info = session.getMediaInformation();
  final duration = double.tryParse(info?.duration ?? '0') ?? 0.0;
  
  final minutes = (duration / 60).floor();
  final seconds = (duration % 60).floor();
  
  print('Duration: $minutes:${seconds.toString().padLeft(2, '0')}');
}
```

### List All Audio Streams

```dart
final session = FFprobeKit.getMediaInformation('video.mp4');

if (session is MediaInformationSession) {
  final info = session.getMediaInformation();
  final audioStreams = info?.streams.where((s) => s.type == 'audio').toList() ?? [];
  
  print('Found ${audioStreams.length} audio stream(s):');
  for (final stream in audioStreams) {
    print('  Stream ${stream.index}: ${stream.codec}');
    print('    Language: ${stream.language ?? "unknown"}');
    print('    Channels: ${stream.channels}');
    print('    Sample rate: ${stream.sampleRate} Hz');
  }
}
```

### Extract Metadata Tags

```dart
final session = FFprobeKit.getMediaInformation('music.mp3');

if (session is MediaInformationSession) {
  final info = session.getMediaInformation();
  final tags = info?.tags;
  
  if (tags != null) {
    print('Title: ${tags['title'] ?? 'Unknown'}');
    print('Artist: ${tags['artist'] ?? 'Unknown'}');
    print('Album: ${tags['album'] ?? 'Unknown'}');
    print('Year: ${tags['date'] ?? 'Unknown'}');
    print('Genre: ${tags['genre'] ?? 'Unknown'}');
  }
}
```

### Check if File Has Subtitles

```dart
final session = FFprobeKit.getMediaInformation('video.mp4');

if (session is MediaInformationSession) {
  final info = session.getMediaInformation();
  final hasSubtitles = info?.streams.any((s) => s.type == 'subtitle') ?? false;
  
  if (hasSubtitles) {
    final subtitleStreams = info!.streams.where((s) => s.type == 'subtitle').toList();
    print('Found ${subtitleStreams.length} subtitle stream(s)');
    
    for (final sub in subtitleStreams) {
      print('  ${sub.language ?? "unknown"}: ${sub.codec}');
    }
  } else {
    print('No subtitles found');
  }
}
```

### Get Video Codec Information

```dart
final session = FFprobeKit.getMediaInformation('video.mp4');

if (session is MediaInformationSession) {
  final info = session.getMediaInformation();
  final videoStream = info?.streams.firstWhere(
    (s) => s.type == 'video',
    orElse: () => throw Exception('No video stream'),
  );
  
  print('Codec: ${videoStream.codec}');
  print('Description: ${videoStream.codecLong}');
  print('Pixel format: ${videoStream.format}');
  print('Bitrate: ${videoStream.bitrate} bps');
}
```

### Calculate Video Bitrate

```dart
final session = FFprobeKit.getMediaInformation('video.mp4');

if (session is MediaInformationSession) {
  final info = session.getMediaInformation();
  
  final bitrate = int.tryParse(info?.bitrate ?? '0') ?? 0;
  final bitrateKbps = (bitrate / 1000).round();
  final bitrateMbps = (bitrate / 1000000).toStringAsFixed(2);
  
  print('Bitrate: $bitrateKbps kbps ($bitrateMbps Mbps)');
}
```

### Custom FFprobe Command (JSON Output)

```dart
final session = FFprobeKit.execute(
  '-v quiet -print_format json -show_format -show_streams input.mp4'
);

if (ReturnCode.isSuccess(session.getReturnCode())) {
  final jsonOutput = session.getOutput();
  
  if (jsonOutput != null) {
    final data = jsonDecode(jsonOutput);
    print('Format: ${data['format']['format_name']}');
    print('Streams: ${data['streams'].length}');
  }
}
```

## Error Handling

```dart
final session = FFprobeKit.getMediaInformation('/path/to/file.mp4');

if (ReturnCode.isSuccess(session.getReturnCode())) {
  if (session is MediaInformationSession) {
    final info = session.getMediaInformation();
    
    if (info != null) {
      // Process media information
      print('Successfully retrieved media info');
    } else {
      print('Media information is null');
    }
  }
} else {
  print('FFprobe failed with code: ${session.getReturnCode()}');
  print('Output: ${session.getOutput()}');
  print('Logs: ${session.getLogs()}');
}
```

## Best Practices

1. **Check Return Codes**: Always verify the session completed successfully before accessing media information.

2. **Handle Null Values**: Media information fields can be null, so use null-aware operators:

   ```dart
   final duration = info?.duration ?? '0';
   final format = info?.format ?? 'unknown';
   ```

3. **Use Type Checks**: When working with sessions, check if it's a `MediaInformationSession`:

   ```dart
   if (session is MediaInformationSession) {
     final info = session.getMediaInformation();
   }
   ```

4. **Parse Numeric Values Safely**: Use `tryParse` for converting string values:

   ```dart
   final duration = double.tryParse(info?.duration ?? '0') ?? 0.0;
   final bitrate = int.tryParse(info?.bitrate ?? '0') ?? 0;
   ```

5. **Filter Streams by Type**: Use `where` to filter streams:

   ```dart
   final videoStreams = info?.streams.where((s) => s.type == 'video').toList();
   ```

## See Also

- [FFprobeSession API](sessions.md) - Session management details
- [Data Models](data-models.md) - MediaInformation, StreamInformation, etc.
- [Media Information Guide](../guides/media-information.md) - Comprehensive guide
- [Error Handling Guide](../guides/error-handling.md) - Error handling strategies
