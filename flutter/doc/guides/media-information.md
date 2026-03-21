# Media Information Guide

Extracting and analyzing media metadata is a core feature of FFmpeg Kit Extended. This guide covers how to use `FFprobeKit` effectively.

## Table of Contents

- [Basic Info Extraction](#basic-info-extraction)
- [Analyzing Streams](#analyzing-streams)
- [Working with Tags](#working-with-tags)
- [Chapter Management](#chapter-management)
- [Advanced Probings](#advanced-probings)

## Basic Info Extraction

The simplest way to get information about a file is using `getMediaInformation`:

```dart
final session = FFprobeKit.getMediaInformation('path/to/media.mp4');

if (ReturnCode.isSuccess(session.getReturnCode())) {
  final info = session.getMediaInformation();
  print('Filename: ${info?.filename}');
  print('Duration: ${info?.duration}s');
  print('Format: ${info?.format}');
  print('Bitrate: ${info?.bitrate} bps');
}
```

## Analyzing Streams

Most media files contain multiple streams (usually one video and one audio, sometimes subtitles).

```dart
final info = session.getMediaInformation();
final streams = info?.streams ?? [];

for (final stream in streams) {
  print('Stream #${stream.index}:');
  print('  Type: ${stream.type}');
  print('  Codec: ${stream.codec}');
  
  if (stream.type == 'video') {
    print('  Resolution: ${stream.width}x${stream.height}');
    print('  FPS: ${stream.averageFrameRate}');
  } else if (stream.type == 'audio') {
    print('  Channel layout: ${stream.channelLayout}');
    print('  Sample Rate: ${stream.sampleRate} Hz');
  }
}
```

## Working with Tags

Tags contain metadata like Title, Artist, and Album.

```dart
final info = session.getMediaInformation();
final tags = info?.tags;

if (tags != null) {
  final title = tags['title'] ?? 'Unknown Title';
  final artist = tags['artist'] ?? 'Unknown Artist';
  print('Playing: $title by $artist');
}
```

### Stream-Specific Tags

Some tags are nested within specific streams (e.g., language info for audio streams).

```dart
for (final stream in info?.streams ?? []) {
  final streamTags = stream.tags;
  if (streamTags != null && streamTags.containsKey('language')) {
    print('Stream ${stream.index} language: ${streamTags['language']}');
  }
}
```

## Chapter Management

For files with chapters (like some MKV or MP4 files):

```dart
final chapters = info?.chapters ?? [];

for (final chapter in chapters) {
  print('Chapter #${chapter.id}: ${chapter.tags?['title']}');
  print('  Starts: ${chapter.startTime}s, Ends: ${chapter.endTime}s');
}
```

## Advanced Probings

If you need very specific JSON output or want to use custom FFprobe flags:

```dart
// Get only packet information for the first video stream
final command = '-v quiet -show_packets -select_streams v:0 -print_format json input.mp4';
final session = FFprobeKit.execute(command);

if (ReturnCode.isSuccess(session.getReturnCode())) {
  final jsonOutput = session.getOutput();
  // Parse jsonOutput manually
}
```

## Best Practices

1. **Check for Nulls**: Many fields in `MediaInformation` can be null if FFprobe cannot detect them. Always use null-aware operators.
2. **Use Async for Large Files/URLs**: When probing files over a network or very large files, use `getMediaInformationAsync` to keep the UI responsive.
3. **Validate Result Codes**: Always check `ReturnCode.isSuccess` before assuming the data in the session is valid.
4. **Cache Information**: If you are displaying a list of videos, consider caching the results of `FFprobeKit` to avoid redundant native calls.
