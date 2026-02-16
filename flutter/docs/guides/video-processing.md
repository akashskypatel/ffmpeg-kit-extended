# Video Processing Guide

This guide covers common video processing tasks using FFmpeg Kit Extended Flutter.

## Table of Contents

- [Video Conversion](#video-conversion)
- [Video Compression](#video-compression)
- [Resolution and Scaling](#resolution-and-scaling)
- [Trimming and Cutting](#trimming-and-cutting)
- [Concatenation](#concatenation)
- [Watermarks and Overlays](#watermarks-and-overlays)
- [Frame Extraction](#frame-extraction)
- [Format Conversion](#format-conversion)
- [Advanced Filters](#advanced-filters)

## Video Conversion

### Basic Conversion

Convert between different video formats:

```dart
// MP4 to AVI
FFmpegKit.execute('-i input.mp4 output.avi');

// AVI to MP4
FFmpegKit.execute('-i input.avi -c:v libx264 -c:a aac output.mp4');

// MOV to MP4
FFmpegKit.execute('-i input.mov -c:v libx264 -c:a aac output.mp4');

// MKV to MP4
FFmpegKit.execute('-i input.mkv -c copy output.mp4');
```

### Conversion with Quality Control

```dart
// High quality (lower CRF = better quality)
FFmpegKit.execute('-i input.mp4 -c:v libx264 -crf 18 -preset slow output.mp4');

// Medium quality (balanced)
FFmpegKit.execute('-i input.mp4 -c:v libx264 -crf 23 -preset medium output.mp4');

// Lower quality (smaller file size)
FFmpegKit.execute('-i input.mp4 -c:v libx264 -crf 28 -preset fast output.mp4');
```

**CRF Values:**

- 0-17: Visually lossless
- 18-23: High quality
- 24-28: Medium quality
- 29+: Low quality

**Presets:**

- `ultrafast`: Fastest encoding, largest file
- `fast`: Fast encoding
- `medium`: Balanced (default)
- `slow`: Better compression
- `veryslow`: Best compression, slowest

## Video Compression

### Reduce File Size

```dart
// Compress by reducing resolution and bitrate
FFmpegKit.execute(
  '-i input.mp4 '
  '-vf scale=1280:720 '
  '-c:v libx264 -crf 28 '
  '-c:a aac -b:a 128k '
  'compressed.mp4'
);
```

### Two-Pass Encoding (Better Quality)

```dart
// First pass
await FFmpegKit.executeAsync(
  '-i input.mp4 -c:v libx264 -b:v 1M -pass 1 -f mp4 /dev/null'
);

// Second pass
await FFmpegKit.executeAsync(
  '-i input.mp4 -c:v libx264 -b:v 1M -pass 2 output.mp4'
);
```

### Compress with Progress Tracking

```dart
Future<void> compressWithProgress(String input, String output) async {
  // Get duration first
  final probeSession = FFprobeKit.getMediaInformation(input);
  double duration = 0.0;
  
  if (probeSession is MediaInformationSession) {
    final info = probeSession.getMediaInformation();
    duration = double.tryParse(info?.duration ?? '0') ?? 0.0;
  }
  
  // Compress with progress
  await FFmpegKit.executeAsync(
    '-i $input -vf scale=1280:720 -c:v libx264 -crf 28 $output',
    onStatistics: (stats) {
      final progress = (stats.time / 1000 / duration) * 100;
      print('Compressing: ${progress.toStringAsFixed(1)}%');
      print('Speed: ${stats.speed}x');
      print('Bitrate: ${stats.bitrate} kbps');
    },
    onComplete: (session) {
      if (ReturnCode.isSuccess(session.getReturnCode())) {
        print('Compression complete!');
      }
    },
  );
}
```

## Resolution and Scaling

### Scale to Specific Resolution

```dart
// Scale to 1280x720 (720p)
FFmpegKit.execute('-i input.mp4 -vf scale=1280:720 output.mp4');

// Scale to 1920x1080 (1080p)
FFmpegKit.execute('-i input.mp4 -vf scale=1920:1080 output.mp4');

// Scale to 640x480
FFmpegKit.execute('-i input.mp4 -vf scale=640:480 output.mp4');
```

### Maintain Aspect Ratio

```dart
// Scale width to 1280, height auto-calculated
FFmpegKit.execute('-i input.mp4 -vf scale=1280:-1 output.mp4');

// Scale height to 720, width auto-calculated
FFmpegKit.execute('-i input.mp4 -vf scale=-1:720 output.mp4');

// Scale to fit within 1280x720, maintaining aspect ratio
FFmpegKit.execute(
  '-i input.mp4 -vf "scale=1280:720:force_original_aspect_ratio=decrease" output.mp4'
);
```

### Scale by Percentage

```dart
// Scale to 50% of original size
FFmpegKit.execute('-i input.mp4 -vf scale=iw/2:ih/2 output.mp4');

// Scale to 75% of original size
FFmpegKit.execute('-i input.mp4 -vf scale=iw*0.75:ih*0.75 output.mp4');
```

### High-Quality Scaling

```dart
// Use Lanczos algorithm for better quality
FFmpegKit.execute(
  '-i input.mp4 -vf scale=1920:1080:flags=lanczos output.mp4'
);
```

## Trimming and Cutting

### Trim by Time

```dart
// Extract 10 seconds starting at 00:00:30
FFmpegKit.execute('-i input.mp4 -ss 00:00:30 -t 10 -c copy output.mp4');

// Extract from 00:01:00 to 00:02:00
FFmpegKit.execute('-i input.mp4 -ss 00:01:00 -to 00:02:00 -c copy output.mp4');

// Extract last 30 seconds (requires knowing duration)
FFmpegKit.execute('-i input.mp4 -sseof -30 -c copy output.mp4');
```

### Fast Seeking (Copy Codec)

```dart
// Fast but less precise (use -c copy)
FFmpegKit.execute('-i input.mp4 -ss 00:00:30 -t 10 -c copy output.mp4');
```

### Accurate Seeking (Re-encode)

```dart
// Slower but frame-accurate
FFmpegKit.execute('-i input.mp4 -ss 00:00:30 -t 10 -c:v libx264 -c:a aac output.mp4');
```

### Trim with User Input

```dart
Future<void> trimVideo({
  required String inputPath,
  required String outputPath,
  required Duration startTime,
  required Duration duration,
}) async {
  final startSeconds = startTime.inSeconds;
  final durationSeconds = duration.inSeconds;
  
  await FFmpegKit.executeAsync(
    '-i $inputPath -ss $startSeconds -t $durationSeconds -c copy $outputPath',
    onComplete: (session) {
      if (ReturnCode.isSuccess(session.getReturnCode())) {
        print('Video trimmed successfully');
      }
    },
  );
}

// Usage
await trimVideo(
  inputPath: 'input.mp4',
  outputPath: 'output.mp4',
  startTime: Duration(minutes: 1, seconds: 30),
  duration: Duration(seconds: 45),
);
```

## Concatenation

### Concatenate Videos (Same Format)

```dart
// Create a file list
final fileList = '''
file 'video1.mp4'
file 'video2.mp4'
file 'video3.mp4'
''';

// Save to a temporary file
final listFile = File('filelist.txt');
await listFile.writeAsString(fileList);

// Concatenate
FFmpegKit.execute('-f concat -safe 0 -i filelist.txt -c copy output.mp4');

// Clean up
await listFile.delete();
```

### Concatenate with Re-encoding

```dart
FFmpegKit.execute(
  '-f concat -safe 0 -i filelist.txt '
  '-c:v libx264 -c:a aac '
  'output.mp4'
);
```

### Concatenate Different Formats

```dart
// Convert and concatenate
FFmpegKit.execute(
  '-i video1.avi -i video2.mp4 -i video3.mkv '
  '-filter_complex "[0:v][0:a][1:v][1:a][2:v][2:a]concat=n=3:v=1:a=1[outv][outa]" '
  '-map "[outv]" -map "[outa]" '
  'output.mp4'
);
```

### Programmatic Concatenation

```dart
Future<void> concatenateVideos(List<String> videoPaths, String outputPath) async {
  // Create file list
  final fileListContent = videoPaths
      .map((path) => "file '$path'")
      .join('\n');
  
  final listFile = File('${outputPath}_list.txt');
  await listFile.writeAsString(fileListContent);
  
  // Concatenate
  await FFmpegKit.executeAsync(
    '-f concat -safe 0 -i ${listFile.path} -c copy $outputPath',
    onComplete: (session) async {
      // Clean up list file
      await listFile.delete();
      
      if (ReturnCode.isSuccess(session.getReturnCode())) {
        print('Videos concatenated successfully');
      }
    },
  );
}
```

## Watermarks and Overlays

### Add Image Watermark

```dart
// Bottom-right corner with 10px padding
FFmpegKit.execute(
  '-i video.mp4 -i watermark.png '
  '-filter_complex "overlay=W-w-10:H-h-10" '
  'output.mp4'
);

// Top-left corner
FFmpegKit.execute(
  '-i video.mp4 -i watermark.png '
  '-filter_complex "overlay=10:10" '
  'output.mp4'
);

// Center
FFmpegKit.execute(
  '-i video.mp4 -i watermark.png '
  '-filter_complex "overlay=(W-w)/2:(H-h)/2" '
  'output.mp4'
);
```

### Add Text Watermark

```dart
// Simple text overlay
FFmpegKit.execute(
  '-i input.mp4 '
  '-vf "drawtext=text=\'Copyright 2026\':fontsize=24:fontcolor=white:x=10:y=10" '
  'output.mp4'
);

// Text with background
FFmpegKit.execute(
  '-i input.mp4 '
  '-vf "drawtext=text=\'My Video\':fontsize=30:fontcolor=white:box=1:boxcolor=black@0.5:boxborderw=5:x=(w-text_w)/2:y=h-th-10" '
  'output.mp4'
);
```

### Transparent Watermark

```dart
// 50% opacity watermark
FFmpegKit.execute(
  '-i video.mp4 -i watermark.png '
  '-filter_complex "[1:v]format=rgba,colorchannelmixer=aa=0.5[logo];[0:v][logo]overlay=W-w-10:H-h-10" '
  'output.mp4'
);
```

## Frame Extraction

### Extract Single Frame

```dart
// Extract frame at 5 seconds
FFmpegKit.execute('-i video.mp4 -ss 00:00:05 -vframes 1 frame.jpg');

// Extract frame at specific time with high quality
FFmpegKit.execute('-i video.mp4 -ss 00:01:30 -vframes 1 -q:v 2 frame.jpg');
```

### Extract Multiple Frames

```dart
// Extract one frame per second
FFmpegKit.execute('-i video.mp4 -vf fps=1 frame_%04d.png');

// Extract one frame every 10 seconds
FFmpegKit.execute('-i video.mp4 -vf fps=1/10 frame_%04d.png');

// Extract 10 frames evenly distributed
FFmpegKit.execute('-i video.mp4 -vf "select=not(mod(n\\,10))" -vsync 0 frame_%04d.png');
```

### Extract All Frames

```dart
// Extract every frame
FFmpegKit.execute('-i video.mp4 frame_%06d.png');

// Extract frames with specific quality
FFmpegKit.execute('-i video.mp4 -q:v 1 frame_%06d.jpg');
```

### Create Thumbnail Grid

```dart
// Create a grid of thumbnails
FFmpegKit.execute(
  '-i video.mp4 -vf "select=not(mod(n\\,100)),scale=320:180,tile=4x3" '
  'thumbnail_grid.png'
);
```

## Format Conversion

### Convert to GIF

```dart
// Basic GIF conversion
FFmpegKit.execute('-i video.mp4 output.gif');

// High-quality GIF with palette
await FFmpegKit.executeAsync(
  '-i video.mp4 -vf "fps=10,scale=320:-1:flags=lanczos,palettegen" palette.png'
);

await FFmpegKit.executeAsync(
  '-i video.mp4 -i palette.png '
  '-filter_complex "fps=10,scale=320:-1:flags=lanczos[x];[x][1:v]paletteuse" '
  'output.gif'
);
```

### Convert to WebM

```dart
// VP9 codec (better quality)
FFmpegKit.execute(
  '-i input.mp4 -c:v libvpx-vp9 -crf 30 -b:v 0 output.webm'
);

// VP8 codec (better compatibility)
FFmpegKit.execute(
  '-i input.mp4 -c:v libvpx -crf 10 -b:v 1M output.webm'
);
```

### Convert to Different Container

```dart
// MP4 to MKV (copy streams, no re-encoding)
FFmpegKit.execute('-i input.mp4 -c copy output.mkv');

// MKV to MP4
FFmpegKit.execute('-i input.mkv -c copy output.mp4');
```

## Advanced Filters

### Rotate Video

```dart
// Rotate 90 degrees clockwise
FFmpegKit.execute('-i input.mp4 -vf "transpose=1" output.mp4');

// Rotate 90 degrees counter-clockwise
FFmpegKit.execute('-i input.mp4 -vf "transpose=2" output.mp4');

// Rotate 180 degrees
FFmpegKit.execute('-i input.mp4 -vf "transpose=1,transpose=1" output.mp4');
```

### Flip Video

```dart
// Flip horizontally
FFmpegKit.execute('-i input.mp4 -vf hflip output.mp4');

// Flip vertically
FFmpegKit.execute('-i input.mp4 -vf vflip output.mp4');
```

### Crop Video

```dart
// Crop to 640x480 from top-left
FFmpegKit.execute('-i input.mp4 -vf "crop=640:480:0:0" output.mp4');

// Crop to center 16:9 area
FFmpegKit.execute('-i input.mp4 -vf "crop=ih*16/9:ih" output.mp4');

// Crop 10% from all sides
FFmpegKit.execute('-i input.mp4 -vf "crop=iw*0.8:ih*0.8" output.mp4');
```

### Adjust Brightness and Contrast

```dart
// Increase brightness
FFmpegKit.execute('-i input.mp4 -vf "eq=brightness=0.1" output.mp4');

// Increase contrast
FFmpegKit.execute('-i input.mp4 -vf "eq=contrast=1.5" output.mp4');

// Both brightness and contrast
FFmpegKit.execute('-i input.mp4 -vf "eq=brightness=0.1:contrast=1.2" output.mp4');
```

### Apply Blur

```dart
// Gaussian blur
FFmpegKit.execute('-i input.mp4 -vf "gblur=sigma=5" output.mp4');

// Box blur
FFmpegKit.execute('-i input.mp4 -vf "boxblur=5:1" output.mp4');
```

### Speed Up / Slow Down

```dart
// Speed up 2x (video only)
FFmpegKit.execute('-i input.mp4 -vf "setpts=0.5*PTS" output.mp4');

// Slow down 0.5x (video only)
FFmpegKit.execute('-i input.mp4 -vf "setpts=2.0*PTS" output.mp4');

// Speed up 2x (video and audio)
FFmpegKit.execute(
  '-i input.mp4 -filter_complex "[0:v]setpts=0.5*PTS[v];[0:a]atempo=2.0[a]" '
  '-map "[v]" -map "[a]" output.mp4'
);
```

### Fade In / Fade Out

```dart
// Fade in (first 2 seconds)
FFmpegKit.execute('-i input.mp4 -vf "fade=in:0:60" output.mp4');

// Fade out (last 2 seconds, assuming 30fps and 10s video)
FFmpegKit.execute('-i input.mp4 -vf "fade=out:240:60" output.mp4');

// Both fade in and out
FFmpegKit.execute(
  '-i input.mp4 -vf "fade=in:0:60,fade=out:240:60" output.mp4'
);
```

## Best Practices

1. **Use `-c copy` When Possible**: Avoid re-encoding if you're just trimming or concatenating:

   ```dart
   FFmpegKit.execute('-i input.mp4 -ss 10 -t 20 -c copy output.mp4');
   ```

2. **Check Input Before Processing**: Verify files exist and are valid:

   ```dart
   if (!File(inputPath).existsSync()) {
     print('Input file not found');
     return;
   }
   ```

3. **Monitor Progress for Long Operations**: Use statistics callbacks:

   ```dart
   await FFmpegKit.executeAsync(
     command,
     onStatistics: (stats) => print('Progress: ${stats.time}ms'),
   );
   ```

4. **Handle Errors Gracefully**: Always check return codes:

   ```dart
   if (!ReturnCode.isSuccess(session.getReturnCode())) {
     print('Error: ${session.getLogs()}');
   }
   ```

5. **Use Appropriate Quality Settings**: Balance quality and file size based on your needs.

## See Also

- [FFmpegKit API Reference](../api/ffmpeg-kit.md)
- [Audio Processing Guide](audio-processing.md)
- [Callbacks Guide](callbacks.md)
- [Error Handling Guide](error-handling.md)
