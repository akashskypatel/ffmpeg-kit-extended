# FFmpegKit Extended for Flutter

<div align="center">

<img src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/assets/banner.png" alt="FFmpegKit Extended Banner" width="100%">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/pub/dm/ffmpeg_kit_extended_flutter?style=flat-square&logoColor=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub version](https://img.shields.io/pub/v/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub likes](https://img.shields.io/pub/likes/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub points](https://img.shields.io/pub/points/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

## Translations

<div align="center">

[English](README.md) | [Español](flutter/doc/README.es.md) | [简体中文](flutter/doc/README.zh-CN.md) | [हिन्दी](flutter/doc/README.hi.md) | [العربية](flutter/doc/README.ar.md) | [Français](flutter/doc/README.fr.md) | [Português (Brasil)](flutter/doc/README.pt-BR.md) | [日本語](flutter/doc/README.ja.md)

</div>

`ffmpeg-kit-extended` is a comprehensive Flutter plugin for executing `FFmpeg`, `FFprobe`, and `FFplay` `8.1.2 API` commands on `Android`, `iOS`, `macOS`, `Linux`, and `Windows`. It leverages Dart `FFI` to interact directly with native FFmpeg libraries, providing high performance, flexibility, and complete video playback capabilities.

If you like the project and are using it in your app give it a ⭐ on [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) and [ffmpeg-kit-extended](https://github.com/akashskypatel/ffmpeg-kit-extended), and a 👍 on [pub.dev](https://pub.dev/packages/ffmpeg_kit_extended_flutter). It helps a lot 🙏! Happy coding 🚀!

## 1. Features

- **Cross-Platform Support**: Works on `Android`, `iOS`, `macOS`, `Linux`, and `Windows`.
  - **Android**: Full video playback support with native surface rendering.
    - **x86**: `x86` architecture is not supported due to its legacy status.
  - **iOS & macOS**: High-performance video playback with `CVPixelBuffer` and Metal integration.
    - **iOS**: Supports both physical `devices` and `simulators`. `x86_64` architecture is not supported due to its legacy status.
  - **Linux**: Full video playback support with `OpenGL` integration.
    - **arm64**: `arm64` architecture currently not supported, coming soon!
- **`FFmpeg`, `FFprobe` & `FFplay`**: [Latest `8.1.2 API`](https://www.ffmpeg.org/download.html#release_8.1) support for media manipulation, information retrieval, and audio/video playback.
- **Video Playback**: Complete cross-platform video playback with unified surface API.
- **Real-time Streaming**: Position and video dimension streams for live playback monitoring.
- **Dart FFI**: Direct native bindings for optimal performance.
- **Asynchronous Execution**: Run long-running tasks without blocking the UI thread.
- **Parallel Execution**: Run multiple tasks in parallel.
- **Callback Support**: detailed hooks for logs, statistics, and session completion.
- **Session Management**: Full control over execution lifecycle (start, cancel, list).
- **Extensible**: Designed to allow custom native library loading and configuration.
- **Full package Introspection API**: Get detailed information about the package, including version, build date, and available muxers, demuxers, encoders, decoders, filters, etc.
- **Deploy Custom Builds**: You can deploy custom builds of ffmpeg-kit-extended. See: <https://github.com/akashskypatel/ffmpeg-kit-builders>

### Platform Support

| Platform                 | Status      | Video Playback | Architecture         | Minimum Requirements |
| ------------------------ | ----------- | -------------- | -------------------- | -------------------- |
| Android (and Android TV) | ✅ Supported | ✅ Native       | armv7, arm64, x86_64 | API 26+              |
| iOS (and Simulator)      | ✅ Supported | ✅ Texture      | arm64                | iOS 13+              |
| macOS                    | ✅ Supported | ✅ Texture      | arm64, x86_64        | macOS 13+            |
| Linux                    | ✅ Supported | ✅ Texture      | x86_64               | glibc 2.28+          |
| Windows                  | ✅ Supported | ✅ Texture      | x86_64               | Windows 8+           |

You will have to update your app's minimum requirements on your own to match the requirements above.

## 🎬 Demo

<div align="center">
<a href="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif">Click here if the image doesn't load</a>
<br>
<img width="378" height="672" src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif?raw=true" alt="Demo" style="border-radius: 10px;" />
<br>

[_Video demonstration of FFmpegKit Extended Flutter plugin showing real-time video playback, FFmpeg command execution, and the comprehensive introspection API interface._](https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/flutter/doc/demo.gif)

</div>

## 2. Installation

1. Install the package:

   ```bash
   flutter pub add ffmpeg_kit_extended_flutter
   ```

2. Add the `ffmpeg_kit_extended_config` section to your `pubspec.yaml`:

   ```yaml
   ffmpeg_kit_extended_config:
     type: "base" # pre-bundled builds: debug, base, full, audio, video, video_hw
     gpl: true # enable to include GPL libraries. WARNING: Make sure you understand what GPL license means before enabling. Check https://www.ffmpeg.org/legal.html for more information.
     small: true # enable to use smaller builds
     # == OR ==
     # -------------------------------------------------------------
     # You can specify remote or local path to libffmpegkit libraries for each platform
     # This allows you to deploy custom builds of libffmpegkit.
     # See: https://github.com/akashskypatel/ffmpeg-kit-builders
     # Example:
     # windows: "path/to/ffmpeg-kit/libraries"
     # ios: "https://path/to/bundle.xcframework.zip"
   ```

   **Note**: Native libraries are now automatically downloaded and bundled during the build process using [Dart Hooks](https://dart.dev/tools/hooks). No manual configuration script is required.

**Important**: If you change the bundle after you have already created a build with another bundle, you must `flutter clean` and `flutter build` to re-run the build hook and download updated binaries for the new bundle selection.

3. Import the package in your Dart code:

   ```dart
   import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
   ```

4. Initialize the plugin at application startup **before** calling any API:

   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await FFmpegKitExtended.initialize();
     runApp(MyApp());
   }
   ```

   > **Important**: Any FFmpeg, FFprobe, or FFplay API call made before `initialize()` completes will throw a `StateError`.

### 2.1 Platform specific configuration

1. **iOS and iOS Simulator** - Your app's Podfile will need to be updated to add post-install hooks to exclude building for architectures that aren't supported Add the following to your Podfile:

    ```ruby
    post_install do |installer|
      installer.pods_project.targets.each do |target|
        flutter_additional_ios_build_settings(target)
        target.build_configurations.each do |config|
          config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'i386 x86_64'
          config.build_settings['EXCLUDED_ARCHS[sdk=iphoneos*]'] = 'i386 x86_64'
        end
      end

      installer.generated_projects.each do |project|
        project.targets.each do |target|
          target.build_configurations.each do |config|
            config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'i386 x86_64'
            config.build_settings['EXCLUDED_ARCHS[sdk=iphoneos*]'] = 'i386 x86_64'
            config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
          end
        end
        project.save
      end
    end
    ```

### 2.2 Pre-bundled Builds

- **base**: Basic build with core FFmpeg libraries. Does not contain any extra libraries.
- **full**: Full build with all platform-compatible FFmpeg libraries. See: <https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries>
- **audio**: Build with audio-only FFmpeg libraries.
- **video**: Build with video-only FFmpeg libraries.
- **video_hw**: Build with hardware-accelerated video FFmpeg libraries.

### 2.2 Feature Matrix

| Feature   | Base | Audio | Video | Video+Hardware | Full |
| --------- | ---- | ----- | ----- | -------------- | ---- |
| Video     |      |       | x     | x              | x    |
| Audio     |      | x     | x     | x              | x    |
| Streaming |      | x     | x     | x              | x    |
| Hardware  |      |       |       | x              | x    |
| AI*       |      |       |       |                |      |
| HTTPS     | *    | x     | x     | x              | x    |
| Platform* | x    | x     | x     | x              | x    |
| Other*    |      |       |       |                | x    |

1. AI features are not supported on all platforms. You must deploy your own custom build of ffmpeg-kit-extended to enable certain AI features.
   - See [Supported External Libraries](#libraries) for more information.

2. Platform features are built-in platform libraries that FFmpeg support like AVFounation, VideoToolbox, etc. on apple platforms or DirectX, MediaFoundation on Windows.

3. HTTPS features are enabled by default for Platforms that have built-in HTTPS support like Windows or Apple. For Linux and Android OpenSSL is enabled by default.

4. Other features are additional features that are not covered by the above categories. See [Supported External Libraries](#libraries) for more information.

5. To deploy a custom build see [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders).

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

### 3.5 FFplay Video Playback

The plugin supports complete video playback with a unified cross-platform surface API.

#### Basic Video Playback

```dart
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

class VideoPlayerWidget extends StatefulWidget {
  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  FFplaySurface? _surface;
  bool _hasVideo = false;
  int _videoWidth = 0;
  int _videoHeight = 0;
  double _playbackPosition = 0.0;

  @override
  void dispose() {
    _surface?.release();
    super.dispose();
  }

  Future<void> _startPlayback(String filePath) async {
    // Create surface before starting playback
    _surface = await FFplaySurface.create();

    final session = await FFplayKit.executeAsync('-i "$filePath"');

    // Listen for video dimensions
    session.videoSizeStream.listen((size) {
      final (width, height) = size;
      if (mounted && width > 0 && height > 0) {
        setState(() {
          _videoWidth = width;
          _videoHeight = height;
          _hasVideo = true;
        });
      }
    });

    // Listen for position updates
    session.positionStream.listen((position) {
      if (mounted) {
        setState(() => _playbackPosition = position);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Video display (only when video frames are available)
        if (_hasVideo && _surface != null)
          SizedBox(
            width: _videoWidth.toDouble(),
            height: _videoHeight.toDouble(),
            child: _surface!.toWidget(),
          ),

        // Playback controls
        Row(
          children: [
            IconButton(
              onPressed: () => FFplayKit.pause(),
              icon: Icon(Icons.pause),
            ),
            IconButton(
              onPressed: () => FFplayKit.resume(),
              icon: Icon(Icons.play_arrow),
            ),
            Expanded(
              child: Slider(
                value: _playbackPosition / (FFplayKit.duration > 0 ? FFplayKit.duration : 1.0),
                onChanged: (value) => FFplayKit.seek(value * FFplayKit.duration),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

#### Platform-Specific Usage

The `FFplaySurface` class automatically handles platform differences:

- **Android**: Uses `SurfaceTexture` backed `ANativeWindow` for native rendering
- **iOS/macOS**: Uses `CVPixelBuffer` textures with Metal optimization
- **Linux/Windows**: Uses pixel buffer textures with frame callbacks
- **Audio-only**: Surface is created but not displayed, preventing crashes

#### Advanced Features

```dart
// Get session-specific properties
final session = await FFplayKit.executeAsync('-i video.mp4');

// Video dimensions (available when first frame is decoded)
final width = session.getVideoWidth();
final height = session.getVideoHeight();

// Real-time streams
session.positionStream.listen((pos) => print('Position: ${pos}s'));
session.videoSizeStream.listen((size) => print('Size: ${size}'));

// Volume control
session.setVolume(0.8); // 0.0 to 1.0
print('Volume: ${session.getVolume()}');

// Session state
print('Playing: ${session.isPlaying()}');
print('Paused: ${session.isPaused()}');
```
## 4. Supported External Libraries<a id="libraries"></a></br>

#### GPL licensing

> - Libraries marked <sup>[10](#gpl-info)</sup> Enabling any GPL library makes the resulting FFmpeg binary GPL-licensed and **non-redistributable under a permissive license**.
>   - **Audio+**: libbs2b, libcdio, librubberband, libjack *(Linux)*
>   - **Video+**: libx264, libx265, libdavs2, libdvdnav, libdvdread, libxavs, libxavs2, libxvid *(Linux)*, frei0r, libvidstab
>   - **Video+HW+**: v4l2-m2m *(Linux)*
>   - **Video+ (Desktop only)**: avisynth

#### AI

> - **`libopenvino`** and **`libtensorflow`** are only available on Desktop builds (`MacOS`, `Linux`, and `Windows`).
> - **`libtorch`** is only available on `Linux` and `MacOs` builds (`Windows` not supported due ABI mismatch).

| Bundle Key | Description                          |
| ---------- | ------------------------------------ |
| `b+`       | Base bundle and above.               |
| `a+`       | Audio bundle and above.              |
| `v+`       | Video bundle and above.              |
| `h+`       | Video+Hardware bundle and above.     |
| `f`        | Full bundle only.                    |
| *(empty)*  | not available on this platform.      |

| Library                                                               | Android | Linux | Windows | iOS | macOS |
| --------------------------------------------------------------------- | ------- | ----- | ------- | --- | ----- |
| **System**                                                            |         |       |         |     |       |
| bzlib, iconv, lzma, zlib                                              | a+      | a+    | a+      | a+  | a+    |
| **TLS / HTTPS**                                                       |         |       |         |     |       |
| openssl                                                               | b+      | b+    |         |     |       |
| schannel                                                              |         |       | b+      |     |       |
| securetransport                                                       |         |       |         | b+  | b+    |
| **Streaming**                                                         |         |       |         |     |       |
| libsrt, librist, librtmp                                              | a+      | a+    | a+      | a+  | a+    |
| **Audio Codecs**                                                      |         |       |         |     |       |
| libcodec2, libgsm, libilbc, liblc3, libmodplug                        | a+      | a+    | a+      | a+  | a+    |
| libmp3lame, libopencore-amrnb, libopencore-amrwb                      | a+      | a+    | a+      | a+  | a+    |
| libopenmpt, libopus, libsoxr, libspeex, libtwolame                    | a+      | a+    | a+      | a+  | a+    |
| libvo-amrwbenc, libvorbis, openal                                     | a+      | a+    | a+      | a+  | a+    |
| alsa                                                                  |         | a+    |         |     |       |
| libbs2b<sup>[10](#gpl-info)</sup>                                     | a+      | a+    | a+      | a+  | a+    |
| libmpeghdec                                                           | a+      | a+    | a+      | a+  | a+    |
| **Audio Extras** *(not in `small` builds)*                            |         |       |         |     |       |
| chromaprint, libflite, libgme, libmysofa, libshine, lv2               | a+      | a+    | a+      | a+  | a+    |
| libcdio, librubberband<sup>[10](#gpl-info)</sup>                      | a+      | a+    | a+      | a+  | a+    |
| ladspa, libpulse, sndio                                               |         | a+    |         |     |       |
| libjack<sup>[10](#gpl-info)</sup>                                     |         | a+    |         |     |       |
| **Video Libraries**                                                   |         |       |         |     |       |
| lcms2, libaom, libaribcaption                                         | v+      | v+    | v+      | v+  | v+    |
| libass, libbluray, libcaca, libdav1d                                  | v+      | v+    | v+      | v+  | v+    |
| libdav1d, libfontconfig, libfreetype, libfribidi                      | v+      | v+    | v+      | v+  | v+    |
| libharfbuzz, libjxl, libkvazaar, liblcevc-dec                         | v+      | v+    | v+      | v+  | v+    |
| liboapv, libopenh264, libopenjpeg, librav1e                           | v+      | v+    | v+      | v+  | v+    |
| librsvg, libsnappy, libsvtav1, libtheora                              | v+      | v+    | v+      | v+  | v+    |
| libuavs3d, libvpx, libvvenc, libwebp                                  | v+      | v+    | v+      | v+  | v+    |
| libxevd, libxeve, libzimg, libzvbi, libxml2, sdl2                     | v+      | v+    | v+      | v+  | v+    |
| libdavs2, libdvdnav, libdvdread, libx264<sup>[10](#gpl-info)</sup>    | v+      | v+    | v+      | v+  | v+    |
| libx265, libxavs, libxavs2, libaribb24<sup>[10](#gpl-info)</sup>      | v+      | v+    | v+      | v+  | v+    |
| libdc1394, libiec61883, libsvtjpegxs                                  |         | v+    |         |     |       |
| libxvid<sup>[10](#gpl-info)</sup>                                     |         | v+    |         |     |       |
| libopencolorio<sup>[15](#arch-info)</sup>                             | v+      | v+    | v+      | v+  | v+    |
| **Video Extras** *(not in `small` builds)*                            |         |       |         |     |       |
| libklvanc, liblensfun, libqrencode, libvmaf, vapoursynth              | v+      | v+    | v+      | v+  | v+    |
| frei0r, libvidstab<sup>[10](#gpl-info)</sup>                          | v+      | v+    | v+      | v+  | v+    |
| libv4l2, libxcb, libxcb-shape, libxcb-shm, libxcb-xfixes, xlib        |         | v+    |         |     |       |
| avisynth<sup>[10](#gpl-info)</sup>                                    |         | v+    | v+      |     | v+    |
| **Hardware Acceleration**                                             |         |       |         |     |       |
| amf, libglslang, libmfx, libplacebo, libshaderc, libvpl               | h+      | h+    | h+      | h+  | h+    |
| opencl, opengl, vulkan, vulkan-static                                 | h+      | h+    | h+      | h+  | h+    |
| libdrm, vaapi, rkmpp, vdpau                                           |         | h+    |         |     |       |
| v4l2-m2m<sup>[10](#gpl-info)</sup>                                    |         | h+    |         |     |       |
| **AI** *(Full bundle only)*                                           |         |       |         |     |       |
| pocketsphinx, whisper                                                 | f       | f     | f       | f   | f     |
| libopencv, libquirc, libtesseract<sup>[11](#compute-info)</sup>       | f       | f     | f       | f   | f     |
| libopenvino, libtensorflow<sup>[11](#compute-info)</sup>              |         | f     | f       |     | f     |
| libtorch<sup>[11](#compute-info)</sup>                                |         | f     |         |     | f     |
| **Platform-specific** *(All bundles)*                                 |         |       |         |     |       |
| jni, mediacodec                                                       | b+      |       |         |     |       |
| appkit, avfoundation, audiotoolbox, coreimage, metal, securetransport |         |       |         | b+  | b+    |
| videotoolbox, schannel, dxva2, d3d12va, d3d11va, mediafoundation      |         |       |         | b+  | b+    |
| appkit                                                                |         |       |         |     | b+    |
| schannel, dxva2, d3d12va, d3d11va, mediafoundation                    |         |       | b+      |     |       |
| alsa                                                                  |         | b+    |         |     |       |



| Library                                      | Description                                             | Platform<sup>[1](#platform-info)</sup> | Extra<sup>[2](#extra-info)</sup> | Base | Audio              | Video              | Video+Hardware     | Full                |
| -------------------------------------------- | ------------------------------------------------------- | -------------------------------------- | -------------------------------- | ---- | ------------------ | ------------------ | ------------------ | ------------------- |
| jni<sup>[8](#install-info)</sup>             | Enables Java Native Interface interactions on Android   | Android                                |                                  | x    | x                  | x                  | x                  | x                   |
| appkit<sup>[8](#install-info)</sup>          | Accesses AppKit for screen and window capture           | Apple                                  |                                  | x    | [9](#nonfree-info) | [9](#nonfree-info) | [9](#nonfree-info) | [9](#nonfree-info)  |
| avfoundation<sup>[8](#install-info)</sup>    | Captures input from AVFoundation devices (cameras/mics) | Apple                                  |                                  | x    | [9](#nonfree-info) | [9](#nonfree-info) | [9](#nonfree-info) | [9](#nonfree-info)  |
| pocketsphinx                                 | Performs offline speech-to-text conversion              |                                        |                                  |      |                    |                    |                    | x                   |
| whisper                                      | Integrates OpenAI Whisper for speech recognition        |                                        |                                  |      |                    |                    |                    | x                   |
| audiotoolbox<sup>[8](#install-info)</sup>    | Accesses AudioToolbox for native codec support          | Apple                                  |                                  | x    | [9](#nonfree-info) | [9](#nonfree-info) | [9](#nonfree-info) | [9](#nonfree-info)  |
| alsa                                         | Accesses ALSA for audio input and output                | Linux                                  |                                  | x    | x                  | x                  | x                  | x                   |
| chromaprint                                  | Calculates audio fingerprints for identification        |                                        | x                                |      | x                  | x                  | x                  | x                   |
| ladspa                                       | Loads LADSPA plugins for audio filtering                | Linux                                  | x                                |      | x                  | x                  | x                  | x                   |
| libbs2b                                      | Simulates binaural audio via DSP                        |                                        |                                  |      | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libcdio                                      | Reads and extracts audio from CDs                       |                                        | [10](#gpl-info)                  |      | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libcelt<sup>[13](#deprecated-info)</sup>     | Decodes CELT audio streams                              |                                        |                                  |      |                    |                    |                    |                     |
| libcodec2                                    | Encodes and decodes Codec2 speech format                |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libfdk-aac                                   | Encodes and decodes high-quality AAC audio              |                                        |                                  |      | [9](#nonfree-info) | [9](#nonfree-info) | [9](#nonfree-info) | [9](#nonfree-info)  |
| libflite                                     | Synthesizes speech from text (TTS) filter               |                                        | x                                |      | x                  | x                  | x                  | x                   |
| libgme                                       | Emulates and plays video game music formats             |                                        | x                                |      | x                  | x                  | x                  | x                   |
| libgsm                                       | Encodes and decodes GSM audio                           |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libilbc                                      | Encodes and decodes iLBC audio                          |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libjack<sup>[8](#install-info)</sup>         | Connects to the JACK audio connection kit               | Linux                                  | [10](#gpl-info)                  |      | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| liblc3                                       | Encodes and decodes LC3 (Bluetooth LE) audio            |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libmodplug                                   | Decodes module music formats (MOD, etc.)                |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libmp3lame                                   | Encodes MP3 audio                                       |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libmysofa                                    | Reads HRTF files for the sofalizer filter               |                                        | x                                |      | x                  | x                  | x                  | x                   |
| libopencore-amrnb                            | Encodes and decodes AMR-NB audio                        |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libopencore-amrwb                            | Decodes AMR-WB audio                                    |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libopenmpt                                   | Decodes tracked music files (OpenMPT based)             |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libopus                                      | Encodes and decodes Opus audio                          |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libpulse<sup>[8](#install-info)</sup>        | Captures audio via PulseAudio server                    | Linux                                  | x                                |      | x                  | x                  | x                  | x                   |
| librubberband                                | Performs high-quality time stretching/pitch shifting    |                                        | [10](#gpl-info)                  |      | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libshine                                     | Encodes MP3 using fixed-point math                      |                                        | x                                |      | x                  | x                  | x                  | x                   |
| libsoxr                                      | Resamples audio using the SoX library                   |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libspeex                                     | Encodes and decodes Speex audio                         |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libtwolame                                   | Encodes MP2 audio                                       |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libvo-amrwbenc                               | Encodes AMR-WB audio                                    |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libvorbis                                    | Encodes and decodes Vorbis audio                        |                                        |                                  |      | x                  | x                  | x                  | x                   |
| lv2                                          | Loads LV2 plugins for audio filtering                   |                                        | x                                |      | x                  | x                  | x                  | x                   |
| openal                                       | Captures audio via OpenAL 1.1                           |                                        |                                  |      | x                  | x                  | x                  | x                   |
| sndio                                        | Accesses sndio for audio I/O on OpenBSD                 | Linux                                  | x                                |      | x                  | x                  | x                  | x                   |
| gcrypt                                       | Provides crypto functions for RTMP/RTMPE                | [3](#rtmpte-info)                      |                                  |      |                    |                    |                    |                     |
| gmp                                          | Provides math functions for crypto contexts             | [3](#rtmpte-info)                      |                                  |      |                    |                    |                    |                     |
| bzlib                                        | Compresses and decompresses bzip2 streams               |                                        |                                  |      | x                  | x                  | x                  | x                   |
| iconv                                        | Converts character encodings for text/subtitles         |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libxml2                                      | Parses XML for DASH, IMF, and other formats             |                                        |                                  |      |                    | x                  | x                  | x                   |
| lzma                                         | Provides LZMA lossless data compression                 |                                        |                                  |      | x                  | x                  | x                  | x                   |
| zlib                                         | Provides Deflate/zlib lossless data compression         |                                        |                                  |      | x                  | x                  | x                  | x                   |
| amf                                          | Accesses AMD Advanced Media Framework (GPU encoding)    |                                        |                                  |      |                    |                    | x                  | x                   |
| mediacodec<sup>[8](#install-info)</sup>      | Accesses Android MediaCodec hardware acceleration       | Android                                |                                  | x    |                    |                    | x                  | x                   |
| coreimage<sup>[8](#install-info)</sup>       | Applies video filters via Apple CoreImage               | Apple                                  |                                  | x    |                    |                    | [9](#nonfree-info) | [9](#nonfree-info)  |
| metal<sup>[8](#install-info)</sup>           | Utilizes Apple Metal for GPU acceleration               | Apple                                  |                                  | x    |                    |                    | [9](#nonfree-info) | [9](#nonfree-info)  |
| videotoolbox<sup>[8](#install-info)</sup>    | Accesses VideoToolbox for hardware encoding/decoding    | Apple                                  |                                  | x    |                    |                    | [9](#nonfree-info) | [9](#nonfree-info)  |
| cuda-llvm<sup>[8](#install-info)</sup>       | Compiles CUDA kernels at runtime using Clang            | Nvidia                                 |                                  |      |                    |                    | [12](#redist-info) | [12](#redist-info)  |
| cuda-nvcc<sup>[8](#install-info)</sup>       | Compiles CUDA kernels using NVCC                        | Nvidia                                 |                                  |      |                    |                    | [12](#redist-info) | [12](#redist-info)  |
| cuvid<sup>[8](#install-info)</sup>           | Accesses Nvidia CUVID for decoding (Legacy)             | Nvidia                                 |                                  |      |                    |                    | [12](#redist-info) | [12](#redist-info)  |
| ffnvcodec                                    | Provides headers for Nvidia codec API integration       | Nvidia                                 |                                  |      |                    |                    | [12](#redist-info) | [12](#redist-info)  |
| libdrm                                       | Accesses Direct Rendering Manager for Linux GPU buffer  | Linux                                  |                                  |      |                    |                    | x                  | x                   |
| libglslang<sup>[14](#conflict-info)</sup>    | Compiles GLSL shaders to SPIR-V for Vulkan filters      |                                        |                                  |      |                    |                    | x                  | x                   |
| libmfx<sup>[14](#conflict-info)</sup>        | Accesses Intel Quick Sync Video (QSV) via MediaSDK      |                                        |                                  |      |                    |                    | x                  | x                   |
| libnpp<sup>[13](#deprecated-info)</sup>      | Uses Nvidia Performance Primitives for image processing | Nvidia                                 |                                  |      |                    |                    |                    |                     |
| libplacebo                                   | Applies high-quality GPU video processing filters       |                                        |                                  |      |                    |                    | x                  | x                   |
| libshaderc<sup>[14](#conflict-info)</sup>    | Compiles GLSL shaders to SPIR-V (Google implementation) |                                        |                                  |      |                    |                    | x                  | x                   |
| libvpl<sup>[14](#conflict-info)</sup>        | Accesses Intel oneVPL video processing library          |                                        |                                  |      |                    |                    | x                  | x                   |
| nvdec<sup>[8](#install-info)</sup>           | Accesses Nvidia NVDEC for hardware decoding             | Nvidia                                 |                                  |      |                    |                    | [12](#redist-info) | [12](#redist-info)  |
| nvenc<sup>[8](#install-info)</sup>           | Accesses Nvidia NVENC for hardware encoding             | Nvidia                                 |                                  |      |                    |                    | [12](#redist-info) | [12](#redist-info)  |
| opencl                                       | Enables OpenCL-based video filtering                    |                                        |                                  |      |                    |                    | x                  | x                   |
| rkmpp                                        | Accesses Rockchip Media Process Platform for HW codecs  | Linux                                  |                                  |      |                    |                    | x                  | x                   |
| v4l2-m2m                                     | Accesses V4L2 Memory-to-Memory hardware codecs          | Linux                                  |                                  |      |                    |                    | [10](#gpl-info)    | [10](#gpl-info)     |
| vaapi                                        | Accesses Video Acceleration API for HW codecs           | Linux                                  |                                  |      |                    |                    | x                  | x                   |
| vdpau<sup>[8](#install-info)</sup>           | Accesses VDPAU for hardware decoding on Unix            | Linux+Nvidia                           |                                  |      |                    |                    | x                  | x                   |
| vulkan                                       | Enables Vulkan-based filtering and rendering            |                                        |                                  |      |                    |                    | x                  | x                   |
| vulkan-static                                | Links libvulkan statically                              |                                        |                                  |      |                    |                    | x                  | x                   |
| opengl                                       | Enables OpenGL-based rendering and filtering            |                                        |                                  |      |                    |                    | x                  | x                   |
| d3d11va<sup>[8](#install-info)</sup>         | Accesses Direct3D 11 for video acceleration             | Windows                                |                                  | x    |                    |                    | [9](#nonfree-info) | [9](#nonfree-info)  |
| d3d12va<sup>[8](#install-info)</sup>         | Accesses Direct3D 12 for video acceleration             | Windows                                |                                  | x    |                    |                    | [9](#nonfree-info) | [9](#nonfree-info)  |
| dxva2<sup>[8](#install-info)</sup>           | Accesses DirectX 9 for video acceleration               | Windows                                |                                  | x    |                    |                    | [9](#nonfree-info) | [9](#nonfree-info)  |
| mediafoundation<sup>[8](#install-info)</sup> | Accesses Windows Media Foundation for encoding          | Windows                                |                                  | x    |                    |                    | [9](#nonfree-info) | [9](#nonfree-info)  |
| ohcodec<sup>[8](#install-info)</sup>         | Accesses OpenHarmony multimedia codec capabilities      | HarmonyOS                              |                                  |      |                    |                    | [9](#nonfree-info) | [9](#nonfree-info)  |
| mmal                                         | Accesses Broadcom MMAL for Raspberry Pi multimedia      | Raspberry Pi                           |                                  |      |                    |                    | [9](#nonfree-info) | [9](#nonfree-info)  |
| omx                                          | Accesses OpenMAX IL for hardware acceleration           | Raspberry Pi                           |                                  |      |                    |                    | [9](#nonfree-info) | [9](#nonfree-info)  |
| omx-rpi                                      | Accesses OpenMAX IL implementation for Raspberry Pi     | Raspberry Pi                           |                                  |      |                    |                    | [9](#nonfree-info) | [9](#nonfree-info)  |
| securetransport<sup>[8](#install-info)</sup> | Provides TLS/SSL support via Apple Secure Transport     | Apple                                  |                                  | x    | [4](#https-info)   | [4](#https-info)   | [4](#https-info)   | [4](#https-info)    |
| gnutls                                       | Provides TLS/SSL support via GnuTLS                     |                                        |                                  |      | [4](#https-info)   | [4](#https-info)   | [4](#https-info)   | [4](#https-info)    |
| libtls                                       | Provides TLS/SSL support via LibreSSL                   |                                        |                                  |      | [4](#https-info)   | [4](#https-info)   | [4](#https-info)   | [4](#https-info)    |
| mbedtls                                      | Provides TLS/SSL support via mbedTLS                    |                                        |                                  |      | [4](#https-info)   | [4](#https-info)   | [4](#https-info)   | [4](#https-info)    |
| openssl                                      | Provides TLS/SSL support via OpenSSL                    |                                        |                                  |      | [4](#https-info)   | [4](#https-info)   | [4](#https-info)   | [4](#https-info)    |
| schannel<sup>[8](#install-info)</sup>        | Provides TLS/SSL support via Windows SChannel           | Windows                                |                                  | x    | [4](#https-info)   | [4](#https-info)   | [4](#https-info)   | [4](#https-info)    |
| librabbitmq                                  | Enables AMQP protocol support (RabbitMQ)                |                                        | [5](#mq-info)                    |      |                    |                    |                    |                     |
| libzmq                                       | Enables ZeroMQ message passing protocol                 |                                        | [5](#mq-info)                    |      |                    |                    |                    |                     |
| libsmbclient                                 | Enables SMB/CIFS protocol support                       |                                        | [6](#smb-info) & [10](#gpl-info) |      |                    |                    |                    |                     |
| libssh                                       | Enables SFTP protocol support                           |                                        | [7](#ssh-info)                   |      |                    |                    |                    |                     |
| librist                                      | Enables Reliable Internet Stream Transport (RIST)       |                                        |                                  |      | x                  | x                  | x                  | x                   |
| librtmp                                      | Enables RTMP and RTMPE stream support                   |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libsrt                                       | Enables Secure Reliable Transport (SRT) protocol        |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libopencv                                    | Applies computer vision filters via OpenCV              |                                        |                                  |      |                    |                    |                    | x                   |
| libopenvino<sup>[8](#install-info)</sup>     | Runs DNN-based filters using Intel OpenVINO backend     |                                        |                                  |      |                    |                    |                    | [11](#compute-info) |
| libtensorflow<sup>[8](#install-info)</sup>   | Runs DNN-based filters using TensorFlow backend         |                                        |                                  |      |                    |                    |                    | [11](#compute-info) |
| libtorch<sup>[8](#install-info)</sup>        | Runs DNN-based filters using PyTorch backend            |                                        |                                  |      |                    |                    |                    | [11](#compute-info) |
| libquirc                                     | Decodes QR codes from video streams                     |                                        |                                  |      |                    |                    |                    | x                   |
| libtesseract                                 | Performs Optical Character Recognition (OCR)            |                                        |                                  |      |                    |                    |                    | x                   |
| sdl2                                         | Outputs audio/video to window using SDL2                |                                        |                                  |      | x                  | x                  | x                  | x                   |
| avisynth                                     | Reads and demuxes AviSynth script files                 |                                        | [10](#gpl-info)                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| decklink                                     | Captures/Outputs via Blackmagic DeckLink devices        |                                        |                                  |      |                    | [9](#nonfree-info) | [9](#nonfree-info) | [9](#nonfree-info)  |
| frei0r                                       | Loads Frei0r plugins for video filtering                |                                        | [10](#gpl-info)                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| lcms2                                        | Applies ICC color profiles using LittleCMS 2            |                                        |                                  |      |                    | x                  | x                  | x                   |
| libaom                                       | Encodes and decodes AV1 video                           |                                        |                                  |      |                    | x                  | x                  | x                   |
| libaribb24                                   | Decodes ARIB STD-B24 captions                           |                                        |                                  |      |                    | x                  | x                  | x                   |
| libaribcaption                               | Decodes ARIB captions (alternative library)             |                                        |                                  |      |                    | x                  | x                  | x                   |
| libass                                       | Renders ASS/SSA subtitles                               |                                        |                                  |      |                    | x                  | x                  | x                   |
| libbluray                                    | Reads Blu-ray playlists and protocols                   |                                        |                                  |      |                    | x                  | x                  | x                   |
| libcaca                                      | Renders video as ASCII characters                       |                                        |                                  |      |                    | x                  | x                  | x                   |
| libdav1d                                     | Decodes AV1 video (high performance)                    |                                        |                                  |      |                    | x                  | x                  | x                   |
| libdavs2                                     | Decodes AVS2 video                                      |                                        |                                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libdc1394                                    | Captures video from FireWire cameras                    | Linux                                  |                                  |      |                    | x                  | x                  | x                   |
| libdvdnav                                    | Navigates and demuxes DVD menus/content                 |                                        |                                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libdvdread                                   | Reads DVD filesystem structures                         |                                        |                                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libfontconfig                                | Configures and locates fonts for text rendering         |                                        |                                  |      |                    | x                  | x                  | x                   |
| libfreetype                                  | Renders fonts for text overlays                         |                                        |                                  |      |                    | x                  | x                  | x                   |
| libfribidi                                   | Handles bi-directional text logic                       |                                        |                                  |      |                    | x                  | x                  | x                   |
| libharfbuzz                                  | Shapes complex text for subtitles                       |                                        |                                  |      |                    | x                  | x                  | x                   |
| libiec61883                                  | Captures DV/HDV via FireWire                            | Linux                                  |                                  |      |                    | x                  | x                  | x                   |
| libjxl                                       | Encodes and decodes JPEG XL images                      |                                        |                                  |      |                    | x                  | x                  | x                   |
| libklvanc                                    | Processes Vertical Ancillary Data (VANC)                |                                        | x                                |      |                    | x                  | x                  | x                   |
| libkvazaar                                   | Encodes HEVC video                                      |                                        |                                  |      |                    | x                  | x                  | x                   |
| liblcevc-dec                                 | Decodes LCEVC video enhancement layers                  |                                        |                                  |      |                    | x                  | x                  | x                   |
| liblensfun                                   | Corrects lens distortion using Lensfun                  |                                        | x                                |      |                    | x                  | x                  | x                   |
| liboapv                                      | Encodes OAPV (Open Advanced Photos/Video)               |                                        |                                  |      |                    | x                  | x                  | x                   |
| libopenh264                                  | Encodes H.264 video (Cisco implementation)              |                                        |                                  |      |                    | x                  | x                  | x                   |
| libopenjpeg                                  | Encodes and decodes JPEG 2000 images                    |                                        |                                  |      |                    | x                  | x                  | x                   |
| libqrencode                                  | Generates QR codes as video sources                     |                                        | x                                |      |                    | x                  | x                  | x                   |
| librav1e                                     | Encodes AV1 video (Rust implementation)                 |                                        |                                  |      |                    | x                  | x                  | x                   |
| librsvg                                      | Renders SVG files for overlays                          |                                        |                                  |      |                    | x                  | x                  | x                   |
| libsnappy                                    | Compresses data for the Hap codec                       |                                        |                                  |      |                    | x                  | x                  | x                   |
| libsvtav1                                    | Encodes AV1 video (SVT implementation)                  |                                        |                                  |      |                    | x                  | x                  | x                   |
| libtheora                                    | Encodes Theora video                                    |                                        |                                  |      |                    | x                  | x                  | x                   |
| libuavs3d                                    | Decodes AVS3 video                                      |                                        |                                  |      |                    | x                  | x                  | x                   |
| libv4l2                                      | Accesses V4L2 devices and utilities                     | Linux                                  | x                                |      |                    | x                  | x                  | x                   |
| libvidstab                                   | Stabilizes video using motion analysis                  |                                        | [10](#gpl-info)                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libvmaf                                      | Calculates VMAF video quality scores                    |                                        | x                                |      |                    | x                  | x                  | x                   |
| libvpx                                       | Encodes and decodes VP8 and VP9 video                   |                                        |                                  |      |                    | x                  | x                  | x                   |
| libvvenc                                     | Encodes H.266/VVC video                                 |                                        |                                  |      |                    | x                  | x                  | x                   |
| libwebp                                      | Encodes WebP images                                     |                                        |                                  |      |                    | x                  | x                  | x                   |
| libx264                                      | Encodes H.264/AVC video                                 |                                        |                                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libx265                                      | Encodes HEVC/H.265 video                                |                                        |                                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libxavs                                      | Encodes AVS video                                       |                                        |                                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libxavs2                                     | Encodes AVS2 video                                      |                                        |                                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libxcb                                       | Captures screen content via XCB                         | Linux                                  | x                                |      |                    | x                  | x                  | x                   |
| libxcb-shape                                 | Handles X11 shapes during capture                       | Linux                                  | x                                |      |                    | x                  | x                  | x                   |
| libxcb-shm                                   | Uses shared memory for X11 capture                      | Linux                                  | x                                |      |                    | x                  | x                  | x                   |
| libxcb-xfixes                                | Fixes cursor rendering in X11 capture                   | Linux                                  | x                                |      |                    | x                  | x                  | x                   |
| libxevd                                      | Decodes EVC video                                       |                                        |                                  |      |                    | x                  | x                  | x                   |
| libxeve                                      | Encodes EVC video                                       |                                        |                                  |      |                    | x                  | x                  | x                   |
| libxvid                                      | Encodes MPEG-4 video (Xvid)                             | Linux                                  |                                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libzimg                                      | Performs scaling and color conversion (zscale)          |                                        |                                  |      |                    | x                  | x                  | x                   |
| libzvbi                                      | Decodes VBI teletext data                               |                                        |                                  |      |                    | x                  | x                  | x                   |
| vapoursynth                                  | Demuxes VapourSynth script frames                       |                                        | x                                |      |                    | x                  | x                  | x                   |
| xlib                                         | Captures screen content via Xlib                        | Linux                                  | x                                |      |                    | x                  | x                  | x                   |
| libsvtjpegxs                                 | Encodes JPEG XS video                                   |                                        |                                  |      |                    | x                  | x                  | x                   |
| libopencolorio<sup>[15](#arch-info)</sup>    | Color space conversion                                  |                                        |                                  |      |                    | x                  | x                  | x                   |
| libmpeghdec                                  | Decodes MPEG-H 3D Audio                                 |                                        |                                  |      | [9](#nonfree-info) | [9](#nonfree-info) | [9](#nonfree-info) | [9](#nonfree-info)  |

<sup>1</sup> Platform specific libraries are enabled by default for target platform and bundle.<a id="platform-info"></a></br>
<sup>2</sup> Extra libraries are enabled on non-small bundles.<a id="extra-info"></a></br>
<sup>3</sup> RTMP(T)E support requires either gcrypt or gmp if the requires SSL library is not selected in the bundle.<a id="rtmpte-info"></a></br>
<sup>4</sup> HTTPS feature in FFmpeg supports multiple SSL libraries. By default OpenSSL is selected unless you build a custom bundle with a specific supported library.<a id="https-info"></a></br>
<sup>5</sup> MQ libraries are not enabled by default in any bundle. A custom build must be deployed to enable them using `--enable-mq` OR `--enable-librabbitmq` and `--enable-libzmq`.<a id="mq-info"></a></br>
<sup>6</sup> SAMBA (SMB protocol) library is not enabled by default in any bundle (except on Windows, which supports SMB by default). A custom build must be deployed to enable them using `--enable-smb` OR `--enable-libsmbclient`.<a id="smb-info"></a></br>
<sup>7</sup> SSH library is not enabled by default in any bundle. A custom build must be deployed to enable them using `--enable-ssh` OR `--enable-libssh`.<a id="ssh-info"></a></br>
<sup>8</sup> These libraries cannot be built statically. If you deploy a static build with these libraries they will not be bundled with FFmpegKit wrapper bundle. The target system will need these libraries installed or running the wrapper may crash immediately. <a id="install-info"></a></br>
<sup>9</sup> These libraries have restrictive licenses that may make the binaries non-redistributable, are not compatible with GPL and only included with `--enable-nonfree`.<a id="nonfree-info"></a></br>
<sup>10</sup> These libraries are GPL and only included with `--enable-gpl`.<a id="gpl-info"></a></br>
<sup>11</sup> These libraries can either be selected with GPU support or CPU only. Note that some of them do not support AMD ROCm framework. These libraries are not available on Mobile platforms due to platform limitations.<a id="compute-info"></a></br>
<sup>12</sup> while these libraries are not compatible with GPL and have a more restrictive license, they are redistributable and will be bundled with non-gpl ffmpeg-kit bundle.<a id="redist-info"></a></br>
<sup>13</sup> These libraries have been deprecated and will be auto-disabled and repalced by modern library if available.<a id="deprecated-info"></a></br>
<sup>14</sup> These libraries conflict with other libraries with overlapping functionality. If both conflicting libraries are enabled, the preferred library, indicated by an * will be enabled and the other library will be disabled:<a id="conflict-info"></a>

>   - libmfx -> libvpl*</br>
>   - libglslang -> libshaderc*</br>

<sup>15</sup> These libraries are only supported on specific CPU architectures.<a id="arch-info"></a></br>

>   - libsvtjpegxs -> x86_64 only</br>

## 5. License

This project is licensed under the LGPL v3.0 by default. However, depending on the underlying FFmpeg build configuration and external libraries used, the effective license may be GPL v3.0. Please review the licenses of the included libraries.

Understand the difference between LGPL and GPL licenses before using this plugin in your project.

Using GPL licensed components in your application may require your application to also be licensed under GPL.