# Common Use Cases

Practical snippets for frequently requested media tasks.

## 1. Extract Metadata and Cover Art

```dart
Future<void> getSongMetadata(String path) async {
  final session = await FFprobeKit.getMediaInformationAsync(path);
  final info = session.getMediaInformation();
  
  print('Title: ${info?.tags?['title']}');
  
  // Extract cover art if present (mapped to a video stream)
  FFmpegKit.execute('-i $path -an -vcodec copy cover.jpg');
}
```

## 2. Speed up Video (Time Lapse)

```dart
void makeTimeLapse(String input, String output) {
  // 4x speed increase
  FFmpegKit.execute('-i $input -filter:v "setpts=0.25*PTS" -an $output');
}
```

## 3. Burn Subtitles into Video

```dart
void burnSubtitles(String video, String subtitles, String output) {
  // Requires 'subtitles' filter
  FFmpegKit.execute('-i $video -vf subtitles=$subtitles $output');
}
```

## 4. Draw Text Overlay

```dart
void addTimestamp(String video, String output) {
  FFmpegKit.execute(
    '-i $video -vf "drawtext=text=\'%{pts\\:hms}\':x=10:y=10:fontsize=24:fontcolor=white" $output'
  );
}
```

## 5. Reverse a Video

```dart
void reverseVideo(String input, String output) {
  FFmpegKit.execute('-i $input -vf reverse -af areverse $output');
}
```

## 6. Combine Images into Video (Slideshow)

```dart
void createSlideshow(String imagePattern, String output) {
  // Example: image_%03d.png
  FFmpegKit.execute('-framerate 1 -i $imagePattern -c:v libx264 -r 30 -pix_fmt yuv420p $output');
}
```

## 7. Change Aspect Ratio (with Padding)

```dart
void force16by9(String input, String output) {
  // Scale and pad to 16:9
  FFmpegKit.execute(
    '-i $input -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2" $output'
  );
}
```

## 8. Screen Recording (Platform Specific)

Note: This requires specific permissions and platform-dependent inputs (e.g., `gdigrab` on Windows).

```dart
// Windows example
void recordScreenWindows(String output) {
  FFmpegKit.execute('-f gdigrab -framerate 30 -i desktop $output');
}
```

## 9. Stream to RTMP (Live Streaming)

This example applies to supported native Flutter targets. Flutter Web/Wasm
builds do not support network stream I/O, including RTMP/RTMPE.

```dart
void startLiveStream(String input, String rtmpUrl) {
  FFmpegKit.executeAsync(
    '-re -i $input -c:v libx264 -preset veryfast -maxrate 3000k -bufsize 6000k -pix_fmt yuv420p -g 60 -c:a aac -b:a 128k -f flv $rtmpUrl'
  );
}
```
