# Data Models

This page describes the primary data structures used by FFmpeg Kit Extended Flutter.

## MediaInformation

The `MediaInformation` class contains comprehensive metadata about a media file, retrieved via `FFprobeKit`.

### Media Information Properties

- `filename` (String?): The path or URL of the media file.
- `format` (String?): The short name of the container format (e.g., "mp4", "mkv").
- `longFormat` (String?): The long descriptive name of the format.
- `duration` (String?): The total duration of the media in seconds.
- `startTime` (String?): The start time of the media in seconds.
- `bitrate` (String?): The bitrate of the media stream.
- `size` (String?): The size of the media file in bytes.
- `tagsJson` (String?): A JSON string containing media tags (metadata).
- `allPropertiesJson` (String?): A JSON string containing all media properties.
- `streams` (`List<StreamInformation>`): The list of streams contained in the media.
- `chapters` (`List<ChapterInformation>`): The list of chapters contained in the media.

### Media Information Computed Properties

- `tags` (Map<String, dynamic>?): Parsed map of tags from the `tagsJson` string.
- `allProperties` (Map<String, dynamic>?): Parsed map of all properties from the `allPropertiesJson` string.

---

## StreamInformation

Represents a single media stream (video, audio, subtitle, etc.) within a container format.

### Stream Information Properties

- `index` (int?): The index of the stream in the file.
- `type` (String?): The type of the stream (e.g., "video", "audio", "subtitle").
- `codec` (String?): The short name of the codec (e.g., "h264", "aac").
- `codecLong` (String?): The long descriptive name of the codec.
- `format` (String?): The format associated with the stream (e.g., "yuv420p").
- `width` (int?): The width of the video stream in pixels.
- `height` (int?): The height of the video stream in pixels.
- `bitrate` (String?): The bitrate of the stream in bits per second.
- `sampleRate` (String?): The audio sample rate in Hz.
- `sampleFormat` (String?): The audio sample format (e.g., "fltp").
- `channelLayout` (String?): The channel layout of the audio stream (e.g., "stereo").
- `sampleAspectRatio` (String?): The sample aspect ratio.
- `displayAspectRatio` (String?): The display aspect ratio (e.g., "16:9").
- `averageFrameRate` (String?): The average frame rate of the video stream.
- `realFrameRate` (String?): The real frame rate of the video stream.
- `pixelFormat` (String?): The pixel format of the video stream (e.g., "yuv420p").
- `level` (int?): The codec level.
- `profile` (String?): The codec profile.

---

## Video Surface Types

### FFplaySurface

Unified cross-platform video surface that automatically handles platform differences.

**Properties:**
- `textureId` (int): Flutter texture ID for the surface

**Key Methods:**
- `create()`: Creates platform-appropriate surface
- `toWidget()`: Returns Flutter Texture widget
- `release()`: Releases native resources

### FFplayAndroidSurface

Android-specific surface implementation using SurfaceTexture and ANativeWindow.

**Properties:**
- `textureId` (int): Flutter texture ID
- `nativeWindowPtr` (int): Native ANativeWindow* pointer

**Key Methods:**
- `bindToFFplay()`: Registers surface with FFplay
- `release()`: Releases Android surface resources

### FFplayDesktopTexture

Desktop texture implementation for Linux and Windows using pixel buffers.

**Properties:**
- `textureId` (int): Flutter texture ID

**Key Methods:**
- `create()`: Creates pixel buffer texture
- `release()`: Releases texture resources

---

## Session Stream Types

### Position Stream

Stream of playback position updates in seconds.

```dart
Stream<double> positionStream
```

**Example:**
```dart
session.positionStream.listen((position) {
  print('Position: ${position.toStringAsFixed(1)}s');
});
```

### Video Size Stream

Stream of video dimension changes as `(width, height)` tuples.

```dart
Stream<(int, int)> videoSizeStream
```

**Example:**
```dart
session.videoSizeStream.listen((size) {
  final (width, height) = size;
  print('Video size: ${width}x${height}');
});
```

---

## Related Documentation

- [Video Surface API](video-surface.md) - Complete video surface API reference
- [FFplayKit API](ffplay-kit.md) - FFplay session management
- [Sessions API](sessions.md) - Session base classes and lifecycle
- [Video Playback Guide](../guides/video-playback.md) - Complete video playback examples

---

## ChapterInformation

Represents a chapter within a media file.

### Chapter Information Properties

- `id` (int?): The unique ID of the chapter.
- `timeBase` (String?): The time base used for chapter timestamps.
- `start` (int?): The start time in `timeBase` units.
- `startTime` (String?): The start time in seconds as a string.
- `end` (int?): The end time in `timeBase` units.
- `endTime` (String?): The end time in seconds as a string.
- `tagsJson` (String?): A JSON string containing chapter tags.
- `allPropertiesJson` (String?): A JSON string containing all chapter properties.

---

## Log

Represents a single log entry emitted by FFmpeg.

### Log Properties

- `sessionId` (int): The ID of the session that produced this log.
- `level` (int): The raw integer log level.
- `message` (String): The log message content.

### Log Computed Properties

- `logLevel` (LogLevel): The `LogLevel` representation of the raw integer level.

---

## Statistics

Represents encoding/decoding statistics for an active `FFmpegSession`.

### Statistics Properties

- `sessionId` (int): The ID of the session these statistics belong to.
- `time` (int): The current time in milliseconds.
- `size` (int): The current size of the output in bytes.
- `bitrate` (double): The current bitrate in bits per second.
- `speed` (double): The processing speed (e.g., 2.0x).
- `videoFrameNumber` (int): The current video frame number being processed.
- `videoFps` (double): The current video processing speed in frames per second.
- `videoQuality` (double): The current video quality (quantizer value).
