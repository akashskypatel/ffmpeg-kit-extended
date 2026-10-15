# Advanced Usage Guide

This guide covers advanced integration scenarios and power-user features of FFmpeg Kit Extended.

## Table of Contents

- [FFmpeg Pipes](#ffmpeg-pipes)
- [Subtitles and Fonts](#subtitles-and-fonts)
- [Environment Variables](#environment-variables)
- [Signal Handling](#signal-handling)
- [Direct Handle Access](#direct-handle-access)

## FFmpeg Pipes

Pipes allow you to feed data into FFmpeg or receive output without using physical files on disk. This is useful for streaming or processing in-memory data.

### Registering a Pipe

```dart
String? pipePath = FFmpegKitConfig.registerNewFFmpegPipe();

if (pipePath != null) {
  // Use 'pipePath' in your FFmpeg command as an input or output
  FFmpegKit.execute('-i $pipePath -vcodec copy output.mp4');
  
  // Later, close it
  FFmpegKitConfig.closeFFmpegPipe(pipePath);
}
```

## Subtitles and Fonts

When using filters like `drawtext` or `subtitles`, FFmpeg needs to know where your font files are located.

### Setting Font Directory

```dart
FFmpegKitConfig.setFontDirectory('/path/to/my/fonts', mapping: 'MyFontName');
```

### Multiple Font Directories

```dart
FFmpegKitConfig.setFontDirectoryList(
  ['/assets/fonts', '/system/fonts'],
  {'CustomFont': 'Roboto-Regular.ttf'}
);
```

## Environment Variables

Some FFmpeg plugins or encoders rely on specific environment variables (e.g., `FONTCONFIG_FILE` or path variables).

```dart
FFmpegKitConfig.setEnvironmentVariable('MY_VAR', 'value');
```

## Signal Handling

You can control how the underlying FFmpeg process handles system signals.

```dart
// Ignore the SIGINT signal (Ctrl+C equivalent)
FFmpegKitConfig.ignoreSignal(Signal.sigint);
```

## Direct Handle Access

For expert users who want to interact with the native FFmpeg Kit C++ layer directly via FFI, you can retrieve the raw pointer from any session.

```dart
final session = FFmpegKit.execute(command);
Pointer<Void> rawHandle = session.handle;

// Now you can pass this handle to your own custom native functions
```

## Best Practices for Advanced Usage

1. **Clean Up Pipes**: Always call `closeFFmpegPipe` when you are done to prevent resource leaks and hung processes.
2. **Path Encoding**: FFmpeg internally uses UTF-8. On Windows, ensure your paths are handled correctly if they contain non-ASCII characters.
3. **Threading**: Remember that `execute` blocks the current thread. Even though it's on a worker thread in the native layer, the Dart side will block until completion. Use `executeAsync` for non-blocking UI behavior.
4. **Memory Management**: When accessing raw pointers, you are responsible for ensuring the session object remains in scope (not garbage collected) while the native code is using the handle.

## Web Remote URLs (Direct HTTP and HLS)

On Web, direct `http://` and `https://` inputs run through the asynchronous
APIs only: `FFmpegKit.executeAsync`, `FFprobeKit.executeAsync`,
`FFprobeKit.getMediaInformationAsync` and `FFplayKit.executeAsync`. The
synchronous calls reject these inputs with `UnsupportedError` before any
native call, because a blocked browser main thread cannot complete a network
read. `FFplaySession.execute()` is deprecated and always throws on every
platform.

Copyable command strings (replace the placeholder URLs):

```dart
// Probe a progressive file or an HLS master playlist (async).
FFprobeKit.executeAsync(
  '-hide_banner -v error -show_format -show_streams -of json '
  '"https://example.com/media/clip.mp4"',
  onComplete: (session) => print(session.getOutput()),
);

// Play an HLS live playlist (async; video renders on the FFplay surface).
FFplayKit.executeAsync(
  '-hide_banner -loglevel info -i "https://example.com/live/playlist.m3u8"',
);

// Record 15 seconds to browser memory, then download it.
FFmpegKit.executeAsync(
  '-hide_banner -nostdin -y -t 15 -i "https://example.com/live/playlist.m3u8" '
  '-map 0:v:0 -map 0:a:0? -c copy -f matroska /tmp/hls-recording.mkv',
  statisticsCallback: (statistics) => print(
    'Recorded ${statistics.transcodingProgressPercent ?? 0}% '
    '(${statistics.size} bytes, ${statistics.time / 1000}s media)',
  ),
  onComplete: (session) {
    if (session.getReturnCode() == 0) {
      final bytes = FFmpegKitWebFiles.readFile('/tmp/hls-recording.mkv');
      // Hand the bytes to a browser download; see the example app.
    }
  },
);
```

Recording rules on Web:

- The output lives in the Wasm filesystem (`/tmp/...`) and occupies browser
  memory until it is read or deleted. Keep `-t` bounded.
- FFmpeg statistics update the example's media-time, percentage and bytes-written
  display while recording. The percentage is indeterminate if duration is unknown.
- Read the file with `FFmpegKitWebFiles.readFile` only after the session
  completes, and delete it when it is no longer needed.
- `session.cancel()` requests cancellation of a pending network request. Keep
  controls busy until completion and track the user's cancellation request
  separately: native cancellation can return zero. The completion callback runs
  once; a cancelled recording may be incomplete.

Requirements and limits:

- **CORS:** the server must allow the page origin. Range requests also need
  `Access-Control-Expose-Headers: Content-Range`. A blocked response fails the
  session with a CORS-style message; it never reports success.
- **Mixed content:** a page served over `https://` cannot read `http://` media.
- **Schemes:** only `http://` and `https://` are accepted. RTMP, RTSP, file and
  chained schemes such as `hls+https://` are rejected on Web.
- **Indirect network input:** a local playlist or concat list that points at
  remote segments cannot be checked before execution. Those opens fail with
  `EPERM` in the session state and logs.
- **Not supported:** RTSP, RTMP, raw sockets, DRM, and direct use of the native
  `<video>` element as a playback substitute.
- **Codecs and encryption:** support follows the codecs and muxers built into
  the bundle. Do not assume every HLS codec or encryption mode is available.

For the per-API support table, see `doc/api/ffmpeg-kit.md`,
`doc/api/ffprobe-kit.md` and `doc/api/ffplay-kit.md`.
