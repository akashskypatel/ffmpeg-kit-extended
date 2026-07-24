# React Native FFmpegKit Extended bindings

This package is the React Native binding layer for the repository's `libffmpegkit` C API (`ffmpegkit_wrapper.h`). It mirrors the public structure already used by the Flutter package under `flutter/lib`, while adapting execution and callbacks to React Native's JavaScript runtime.

## Requirements

- React Native 0.76 or later
- React Native New Architecture must be enabled

FFmpegKit Extended is implemented as a Turbo Native Module and does not support
React Native's legacy Native Module architecture.

### Codegen lifecycle

The npm package ships TypeScript Codegen specs and handwritten native sources only. It does not ship generated React Native Codegen artifacts. Android uses the consuming app's React Native Gradle Plugin, iOS and Apple tvOS use the consuming app's CocoaPods/React Native Codegen integration, macOS uses the consuming app's React Native macOS Codegen integration, and Windows uses `react-native codegen-windows` through the consuming React Native Windows toolchain. This keeps generated interfaces aligned with the React Native version that actually builds the app.

## Platform Support

| Platform                 | Status       | Architecture         | Minimum Requirements |
| ------------------------ | ------------ | -------------------- | -------------------- |
| Android (and Android TV) | ✅ Supported | armv7, arm64, x86_64 | API 26+              |
| iOS (and Simulator)      | ✅ Supported | arm64                | iOS 13+              |
| macOS                    | ✅ Supported | arm64, x86_64        | macOS 13+            |
| Apple tvOS               | ✅ Supported | arm64                | tvOS 13+             |
| Windows                  | ✅ Supported | x86_64               | Windows 8+           |

## Feature Matrix

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

### GPL licensing

> - Libraries marked <sup>[10](#gpl-info)</sup> Enabling any GPL library makes the resulting FFmpeg binary GPL-licensed and **non-redistributable under a permissive license**.
>   - **Audio+**: libbs2b, libcdio, librubberband, libjack *(Linux)*
>   - **Video+**: libx264, libx265, libdavs2, libdvdnav, libdvdread, libxavs, libxavs2, libxvid *(Linux)*, frei0r, libvidstab
>   - **Video+HW+**: v4l2-m2m *(Linux)*
>   - **Video+ (Desktop only)**: avisynth

### AI

> - **`libopenvino`** and **`libtensorflow`** are only available on Desktop builds (`MacOS`, `Linux`, and `Windows`).
> - **`libtorch`** is only available on `Linux` and `MacOs` builds (`Windows` not supported due ABI mismatch).

## Execution model

React Native command execution is asynchronous. `execute()` and `executeAsync()` both return a `Promise` that resolves when the session finishes.

The native session starts asynchronously, while the TypeScript `Session` polls buffered native logs, statistics, and state. This keeps C callbacks and JavaScript callback lifetime management out of the C ABI boundary while preserving per-session completion/log/statistics callbacks.

```ts
import {
  FFmpegKitExtended,
  FFmpegKit,
  ReturnCode,
} from 'ffmpeg-kit-extended';

FFmpegKitExtended.initialize();

const session = await FFmpegKit.executeAsync(
  '-i input.mp4 -c:v libx264 output.mp4',
  {
    logCallback: log => console.log(log.message),
    statisticsCallback: stats => console.log(stats.time, stats.speed),
  },
);

if (session.getReturnCode() === ReturnCode.Success) {
  console.log('Completed');
}
```

Media information follows the same abstraction as Flutter:

```ts
import {FFprobeKit} from 'ffmpeg-kit-extended';

const session = await FFprobeKit.getMediaInformation('/path/to/video.mp4');
const media = session.getMediaInformation();

console.log(media?.format);
console.log(media?.streams);
```

FFplay video and audio playback are supported on Android, iOS, Apple tvOS, macOS, and Windows. Mount `FFplayView` before starting video playback so the platform-native rendering surface is ready. Audio-only playback does not require a video surface.

```tsx
import {FFplayKit, FFplayView} from 'ffmpeg-kit-extended';

export function Player() {
  const play = async () => {
    const session = FFplayKit.createSession(
      '-hide_banner -autoexit -i "/path/to/video.mp4"',
    );
    await session.executeAsync();
  };

  return (
    <>
      <FFplayView style={{width: '100%', aspectRatio: 16 / 9}} />
      {/* Call play() after the view is mounted. */}
    </>
  );
}
```

Playback controls remain session based:

```ts
session.pause();
session.seek(10);
session.resume();
session.setVolume(0.5);
```

## Native runtime packaging

The TurboModule does **not** compile FFmpegKit itself. Native builds read one shared configuration file from the consuming React Native application and fetch or use the requested `libffmpegkit` bundle.

Create `ffmpeg-kit-extended.config.json` beside the consuming application's `package.json`:

```json
{
  "type": "base",
  "gpl": false,
  "small": true
}
```

Supported pre-built bundle types are `debug`, `base`, `full`, `audio`, `video`, and `video_hw`. When the configuration file is absent, the build defaults to the `base` LGPL small bundle. `debug` maps to the base bundle and ignores `small`, matching the Flutter package resolver.

A platform-specific remote URL or local path overrides the pre-built bundle selection for that platform. Relative local paths are resolved from the consuming application directory:

```json
{
  "type": "base",
  "gpl": true,
  "small": true,
  "android": "./native/ffmpeg-kit-custom.aar",
  "ios": "https://example.com/bundle-custom-ios.xcframework.zip",
  "appletvos": "./native/bundle-custom-appletvos.xcframework.zip",
  "macos": "./native/bundle-custom-macos.xcframework",
  "windows": "./native/bundle-custom-windows.zip",
  "linux": "./native/bundle-custom-linux.zip"
}
```

Platform override formats are:

- Android: an `.aar` file or URL.
- iOS, Apple tvOS, and macOS: an `.xcframework` directory, a local XCFramework zip, or a remote XCFramework zip URL.
- Windows: an extracted runtime directory, a local bundle zip, or a remote bundle zip URL.
- Linux: reserved by the shared resolver for the Linux React Native build integration.

The bundle naming and download URL rules are implemented once in `scripts/resolve-ffmpeg-kit-config.js` and shared by the native build integrations.

## FFplay rendering

Android video rendering is implemented by `FFplayView` using a native `TextureView`. iOS, Apple tvOS, and macOS use the decoded-frame callback path and present frames with `AVSampleBufferDisplayLayer`. Windows uses the same desktop decoded-frame callback and presents BGRA frames through a WinUI 3 Composition drawing surface. Audio playback uses FFplay's native audio backend and does not require a video surface.

Global native callback registration is also not exposed because per-session callbacks are dispatched by the TypeScript polling layer. This avoids duplicate callback paths and cross-thread JavaScript invocation.

## Example applications

The React Native example under `example/` contains Android, iOS, Apple tvOS, macOS, and Windows host projects. It demos the following workflows: FFmpeg generation/custom commands, remote recording and cancellation, FFprobe media information, FFplay controls, transcoding statistics, log-level controls, build introspection, file picking, and an on-screen log console.

The unified React Native example contains Android, iOS, Apple tvOS, macOS, and Windows native hosts under `example/`. Apple tvOS uses an isolated `react-native-tvos` runtime, and macOS uses the React Native macOS toolchain to exercise the same C++ TurboModule and the native `FFplayView` implementation with FFmpeg/FFprobe execution, generated video/audio playback, pause/resume/stop/seek/volume controls, aspect-ratio-preserving video output, and a resizable log pane.

The repository scripts prepare the matching native binary, native dependencies, and host application. Codegen is not pre-generated or shipped by this package: each consuming React Native app generates the required artifacts with its own platform toolchain during the native build.

```sh
./build.sh android
./build.sh ios
./build.sh appletvos
./build.sh macos
./build.sh windows

./launch.sh android
./launch.sh ios
./launch.sh appletvos
./launch.sh macos
./launch.sh windows
```

`./launch.sh appletvos` and `./launch.sh macos` open the matching platform-specific Metro server in a visible Terminal window. Because the Apple tvOS and macOS examples use different React Native runtimes, the launcher will stop a Metro process owned by another runtime in this repository before switching platforms. An unrelated process already using port 8081 is left untouched and reported as an error instead of serving an incompatible JavaScript bundle.

On Android, `FFplayView` supplies the native Android surface used by FFplay. On iOS, Apple tvOS, and macOS, `FFplayView` receives FFplay's decoded frame callback and presents frames through `AVSampleBufferDisplayLayer`. On Windows, it receives the desktop frame callback and draws frames into a WinUI 3 Composition surface. Audio playback continues through FFplay's native SDL audio backend.

## Architecture

The binding has three layers:

1. **TypeScript API** (`src/`)
   - `FFmpegKit`, `FFprobeKit`, and `FFplayKit`
   - `FFmpegKitExtended` and `FFmpegKitConfig`
   - `Session`, `FFmpegSession`, `FFprobeSession`, `FFplaySession`, and `MediaInformationSession`
   - `SessionQueueManager` with the same default maximum concurrency of 8 as the Flutter implementation
   - `Log`, `Statistics`, `MediaInformation`, `StreamInformation`, and `ChapterInformation`
2. **React Native TurboModule** (`src/NativeFFmpegKitExtended.ts`, `cpp/FFmpegKitExtendedImpl.*`)
   - A typed Codegen boundary.
   - Only scalar values and JSON strings cross the JavaScript/native boundary.
3. **libffmpegkit adapter** (`cpp/FFmpegKitDynamicApi.*`)
   - Resolves `ffmpegkit_wrapper.h` exports with `dlsym` on Unix/Apple platforms and `LoadLibrary`/`GetProcAddress` on Windows.
   - Does not expose opaque native handles to JavaScript.
   - Temporary session/media/statistics handles are released with `ffmpeg_kit_handle_release`.
   - Native strings allocated by the wrapper are released with `ffmpeg_kit_free`.

The adapter deliberately does not include `ffmpegkit_wrapper.h`. The source snapshot does not contain `ffmpeg_tls.h`, which that header includes, and the React Native bridge only needs the stable exported C ABI. Resolving the exported symbols directly also matches the runtime-loading approach used by the Flutter Apple targets.

## Supported External Libraries<a id="libraries"></a></br>

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

To deploy a custom build see [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders).

<sup>1</sup> Platform specific libraries are enabled by default for target platform and bundle.<a id="platform-info"></a></br>
<sup>2</sup> Extra libraries are enabled on non-small bundles.<a id="extra-info"></a></br>
<sup>3</sup> RTMP(T)E support requires either gcrypt or gmp if the requires SSL library is not selected in the bundle.<a id="rtmpte-info"></a></br>
<sup>4</sup> HTTPS feature in FFmpeg supports multiple SSL libraries. By default OpenSSL is selected unless you build a custom bundle with a specific supported library.<a id="https-info"></a></br>
<sup>5</sup> MQ libraries are not enabled by default in any bundle. A custom build must be deployed to enable them using `--enable-mq` OR `--enable-librabbitmq` and `--enable-libzmq`.<a id="mq-info"></a></br>
<sup>6</sup> SAMBA (SMB protocol) library is not enabled by default in any bundle (except on Windows, which supports SMB by default). A custom build must be deployed to enable them using `--enable-smb` OR `--enable-libsmbclient`.<a id="smb-info"></a></br>
<sup>7</sup> SSH library is not enabled by default in any bundle. A custom build must be deployed to enable them using `--enable-ssh` OR `--enable-libssh`.<a id="ssh-info"></a></br>
<sup>8</sup> These libraries cannot be built statically. If you deploy a static build with these libraries they will not be bundled with FFmpegKit wrapper bundle. The target system will need these libraries installed or running the wrapper may crash immediately. <a id="install-info"></a></br>
<sup>9</sup> These libraries have restrictive licenses that may make the binaries non-redistributable, are not compatible with GPL and require a custom build and deployment with `--enable-nonfree`.<a id="nonfree-info"></a></br>
<sup>10</sup> These libraries are GPL and only included with `--enable-gpl`.<a id="gpl-info"></a></br>
<sup>11</sup> These libraries can either be selected with GPU support or CPU only. Note that some of them do not support AMD ROCm framework. These libraries are not available on Mobile platforms due to platform limitations.<a id="compute-info"></a></br>
<sup>12</sup> while these libraries are not compatible with GPL and have a more restrictive license, they are redistributable and will be bundled with non-gpl ffmpeg-kit bundle.<a id="redist-info"></a></br>
<sup>13</sup> These libraries have been deprecated and will be auto-disabled and repalced by modern library if available.<a id="deprecated-info"></a></br>
<sup>14</sup> These libraries conflict with other libraries with overlapping functionality. If both conflicting libraries are enabled, the preferred library, indicated by an * will be enabled and the other library will be disabled:<a id="conflict-info"></a>

>   - libmfx -> libvpl*</br>
>   - libglslang -> libshaderc*</br>

<sup>15</sup> These libraries are only supported on specific CPU architectures.<a id="arch-info"></a></br>

>   - libsvtjpegxs -> x86_64 only</br>
