<div align="center">

<img src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/assets/banner_react.png" alt="FFmpegKit Extended Banner" width="100%">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/npm/dm/ffmpeg-kit-extended?style=flat-square&logoColor=144DB3)](https://www.npmjs.com/package/ffmpeg-kit-extended) [![Npm version](https://img.shields.io/npm/v/ffmpeg-kit-extended?color=144DB3)](https://www.npmjs.com/package/ffmpeg-kit-extended) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

# React Native FFmpegKit Extended bindings

This package provides React Native bindings for ffmpeg-kit-extended: a comprehensive React Native plugin for executing FFmpeg, FFprobe, and FFplay 9.0.1 API commands on Android, iOS, macOS, tvOS, Windows, and React Native Web.

## Requirements

- React Native 0.81.6 or later
- React Native New Architecture must be enabled
- React Native Web requires `react-native-web`, `react-dom`, and a pthread-capable Wasm runtime.

Native targets use a Turbo Native Module and require React Native's New Architecture. The Web target uses the same TypeScript API over the staged Wasm runtime.

## Features

- **Cross-Platform Support**: Works on `Android`, `iOS`, `macOS`, `tvOS`, `Windows`, and React Native Web.
  - **Android**: Full video playback support with native surface rendering.
    - **x86**: `x86` architecture is not supported due to its legacy status.
  - **iOS & macOS**: High-performance video playback with `CVPixelBuffer` and Metal integration.
    - **iOS**: Supports both physical `devices` and `simulators`. `x86_64` architecture is not supported due to its legacy status.
- **`FFmpeg`, `FFprobe` & `FFplay`**: [Latest `9.0.1 API`](https://www.ffmpeg.org/download.html) support for media manipulation, information retrieval, and audio/video playback.
- **Video Playback**: Complete cross-platform video playback with unified surface API.
- **Real-time Streaming**: Position and video dimension streams for live playback monitoring.
- **Asynchronous Execution**: Run long-running tasks without blocking the UI thread.
- **Parallel Execution**: Run multiple tasks in parallel.
- **Callback Support**: detailed hooks for logs, statistics, and session completion.
- **Session Management**: Full control over execution lifecycle (start, cancel, list).
- **Extensible**: Designed to allow custom native library loading and configuration.
- **Full package Introspection API**: Get detailed information about the package, including version, build date, and available muxers, demuxers, encoders, decoders, filters, etc.
- **Deploy Custom Builds**: You can deploy custom builds of ffmpeg-kit-extended. See: <https://github.com/akashskypatel/ffmpeg-kit-builders>

## Platform Support

| Platform                 | Status       | Architecture         | Minimum Requirements |
| ------------------------ | ------------ | -------------------- | -------------------- |
| Android (and Android TV) | ✅ Supported | armv7, arm64, x86_64 | API 26+              |
| iOS (and Simulator)      | ✅ Supported | arm64                | iOS 13+              |
| macOS                    | ✅ Supported | arm64, x86_64        | macOS 13+            |
| Apple tvOS               | ✅ Supported | arm64                | tvOS 13+             |
| Windows                  | ✅ Supported | x86_64               | Windows 8+           |
| React Native Web         | ✅ Supported | wasm32               | Cross-origin isolated browser |

## Feature Matrix

| Feature   | Base | Audio | Video | Video+Hardware | Full |
| --------- | ---- | ----- | ----- | -------------- | ---- |
| Video     |      |       | x     | x              | x    |
| Audio     |      | x     | x     | x              | x    |
| Streaming |      | x     | x     | x              | x    |
| Hardware  |      |       |       | x              | x    |
| AI*       |      |       |       |                | x*   |
| HTTPS     | *    | x     | x     | x              | x    |
| Platform* | x    | x     | x     | x              | x    |
| Other*    |      |       |       |                | x    |

1. AI features are not supported on all platforms. You must deploy your own custom build of ffmpeg-kit-extended to enable certain AI features.
   - See [Supported External Libraries](#libraries) for more information.

2. Platform features are built-in platform libraries that FFmpeg support like AVFounation, VideoToolbox, etc. on apple platforms or DirectX, MediaFoundation on Windows.

3. HTTPS features are enabled by default for Platforms that have built-in HTTPS support like Windows or Apple. For Linux and Android OpenSSL is enabled by default.

4. Other features are additional features that are not covered by the above categories. See [Supported External Libraries](#libraries) for more information.

5. To deploy a custom build see [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders).

#### GPL licensing

> ⚠️ **WARNING** ⚠️: Enabling GPL libraries makes your application GPL-licensed as well and may face additional challenges during app store approval. GPL license requires your application to be open-source and distributed under the same license.
>
> **It is recommended to use LGPL bundle if you are not familiar with GPL licensing.**

> - Libraries marked <sup>[10](#gpl-info)</sup> Enabling any GPL library makes the resulting FFmpeg binary GPL-licensed and **non-redistributable under a permissive license**.
>   - **Audio+**: libbs2b, libcdio, librubberband, libjack *(Linux)*
>   - **Video+**: libx264, libx265, libdavs2, libdvdnav, libdvdread, libxavs, libxavs2, libxvid *(Linux)*, frei0r, libvidstab
>   - **Video+HW+**: v4l2-m2m *(Linux)*
>   - **Video+ (Desktop only)**: avisynth

#### AI

> - **`libopenvino`** and **`libtensorflow`** are only available on Desktop builds (`MacOS`, `Linux`, and `Windows`).
> - **`libtorch`** is only available on `Linux` and `MacOs` builds (`Windows` not supported due ABI mismatch).
> - **`libonnxruntime`** is only available on Desktop builds (`MacOS`, `Linux`, and `Windows`) but not supported on `x86_64` `MacOS`.
> - Only CPU AI libraries are vendored with pre-built bundles. GPU libraries must be custom deployed.

## Bundle Sizes

**Note**: Values are uncompressed `libffmpegkit` binary sizes in decimal MB. Each range shows the measured LGPL minimum and GPL maximum for the v0.11.2 release assets.

See the bundle distribution page for the source release assets: https://github.com/akashskypatel/ffmpeg-kit-builders/releases

Apple table entries measure the uncompressed framework binaries and exclude debug-symbol files.

| Bundle Type | Android (MB) | iOS (MB)    | tvOS (MB)  | macOS (MB) | Linux (MB) | Windows (MB) |
|-------------|--------------|-------------|------------|------------|------------|--------------|
|             | (Universal)  | (Universal) | (Universal)| (Universal)|            |              |
| debug       | 81.2-82.0    | 37.8-38.2   | 37.6-38.1  | 41.6-42.0  | 133.5-139.6 | 480.4-490.8  |
| base        | 73.4-93.0    | 36.0-48.6   | 35.9-48.5  | 39.8-54.3  | 31.6-44.2   | 41.3-55.2    |
| audio       | 102.6-179.1  | 74.6-126.0  | 72.7-124.1 | 79.8-134.2 | 49.3-86.7   | 82.9-124.1   |
| video       | 233.0-353.0  | 160.7-227.4 | 142.2-208.7| 183.5-255.5| 164.6-232.1 | 215.0-281.1  |
| video_hw    | 239.4-359.9  | 163.8-230.7 | 145.4-212.1| 186.8-259.0| 171.3-239.2 | 219.0-285.4  |
| full        | 267.1-387.5  | 182.0-248.8 | 162.8-229.4| 223.3-295.4| 209.0-276.2 | 248.4-314.8  |

## Installation

```bash
npm install ffmpeg-kit-extended
```

## Configuration

The TurboModule does **not** compile FFmpegKit itself. Native builds read one shared configuration file from the consuming React Native application and fetch or use the requested `libffmpegkit` bundle.

Create `ffmpeg-kit-extended.config.json` beside the consuming application's `package.json`:

```json
{
  "type": "base",
  "gpl": false,
  "small": true
}
```

Supported pre-built bundle types are `debug`, `base`, `full`, `audio`, `video`, and `video_hw`. The pre-built `debug` bundle is supported on native platforms; the pre-built Web/Wasm debug artifact for FFmpegKit binary `0.11.2` is not browser-compatible. Use `base` for Web/Wasm or provide an explicit `web`/`wasm` custom override. When the configuration file is absent, the build defaults to the `base` LGPL small bundle. Native `debug` selects a debug variant and ignores `small`.

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

### React Native Web setup

Install the package with the React Native Web dependencies:

```bash
npm install ffmpeg-kit-extended react-native-web react-dom
```

Web uses the same configuration file with either a `web` or `wasm` override. The override may point to a local runtime directory containing `ffmpegkit.mjs` and `ffmpegkit.wasm`, a local Wasm bundle ZIP, or an `http://`/`https://` bundle URL. A custom Wasm ZIP must contain exactly one runtime directory containing both `ffmpegkit.mjs` and `ffmpegkit.wasm`:

```json
{
  "type": "base",
  "gpl": false,
  "small": true,
  "web": "./vendor/ffmpegkit-wasm"
}
```

Relative paths are resolved from the consuming application directory. Unsupported URL schemes are rejected. Stage a local or remote browser runtime during the application build:

```bash
npx ffmpeg-kit-extended prepare-web --app-root .
```

The command writes `public/ffmpeg-kit-extended/wasm/`, verifies release-selected artifacts before extraction, and copies the package Web bridge beside the runtime. Custom builds can be staged from a local directory or ZIP through the `web`/`wasm` override. Remote overrides are downloaded while staging; at runtime the browser loads the staged files from your application origin rather than downloading a release bundle.

For offline validation against a locally built native ABI, set
`FFMPEG_KIT_EXTENDED_LOCAL_ONLY=true` in the staging process environment. The
resolver then requires an explicit local `web` or `wasm` override and rejects
both default release resolution and HTTP(S) overrides. This fail-closed mode
prevents a local test from silently using a historical published runtime.

The Wasm bundle is pthread-enabled. The Web server must send these headers for the page and runtime assets:

```http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

The headers enable pthread Wasm through `SharedArrayBuffer` and must be sent for the page and runtime assets in development and production. The default runtime URL is `/ffmpeg-kit-extended/wasm/`. If the application serves the staged files below another path, pass that path during initialization:

```ts
await FFmpegKitExtended.initialize({
  assetBaseUrl: '/my-app/ffmpeg-kit-extended/wasm/',
});
```

The package's conditional exports select the Web entry for browser/Metro Web builds. Vite requires the standard `react-native` to `react-native-web` alias shown below; no FFmpegKit backend rewrite is required:

```js
const react = require('@vitejs/plugin-react');

module.exports = {
  plugins: [react()],
  resolve: {
    alias: [{find: 'react-native', replacement: require.resolve('react-native-web')}],
  },
  server: {
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    },
  },
};
```

## Execution model

React Native command execution is asynchronous. `execute()` and `executeAsync()` both return a `Promise` that resolves when the session finishes.

Call `FFmpegKitExtended.initialize()` and await it before using FFmpeg, FFprobe, or FFplay. Successful initialization is idempotent; a failed attempt can be retried, including with corrected `assetBaseUrl` options. Concurrent calls share the same initialization attempt.

The native session starts asynchronously. The TypeScript `Session` receives
structured log events directly through the single global callback ABI with the
native session ID, sequence, level, and copied message; it polls state and does
not poll the complete indexed log history during steady-state delivery. Native
history remains available for public getters and bounded terminal
reconciliation. There is no legacy callback-ABI fallback.

Callback activation is demand-driven: completion transport is retained for an
async execution, while log and statistics transport is leased only while a
matching consumer exists. Completion therefore remains independent of optional
log/statistics callbacks. `FFmpegKitConfig.disableRedirection()` is the
authoritative native capture/forwarding switch, and installing a TypeScript
bridge never calls `enableRedirection()` implicitly. The native/Web bridge
copies accepted messages into a JavaScript-owned string and releases its native
payload internally; no borrowed pointer crosses the public API.

Calling `cancel()` before execution begins prevents Created or queued work from starting. If cancellation is requested while asynchronous native startup is already in flight, the request is retained and forwarded when the session first reaches Running.
`isCancelled` records that cancellation was requested; the final native state and return code determine whether cancellation won a race with completion.

Session objects are single-use execution objects. Create a new `Session` object for another execution.

On React Native Web, a session reconstructed from history can be submitted only while its native state is `Created`. Running or terminal Web history sessions are intended for inspection and control rather than re-execution.

```ts
import {
  FFmpegKitExtended,
  FFmpegKit,
  ReturnCode,
} from 'ffmpeg-kit-extended';

await FFmpegKitExtended.initialize();

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

```ts
import {FFprobeKit} from 'ffmpeg-kit-extended';

const session = await FFprobeKit.getMediaInformation('/path/to/video.mp4');
const media = session.getMediaInformation();

console.log(media?.format);
console.log(media?.streams);
```

`FFprobeKit.getMediaInformation(path)` passes `path` as one FFprobe argument. Paths containing spaces or shell characters do not need shell quoting.

FFplay video and audio playback are supported on Android, iOS, Apple tvOS, macOS, Windows, and Web. Mount `FFplayView` before starting video playback so the platform rendering surface is ready. On Web, `FFplayView` is a canvas that receives copied RGBA frames and requires cross-origin isolation. Its layout is controlled with normal React Native `ViewProps` and styles, including `width`, `height`, and `aspectRatio`. Audio-only playback does not require a video surface.

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

## FFplay rendering

Android video rendering is implemented by `FFplayView` using a native `TextureView`. iOS, Apple tvOS, and macOS use the decoded-frame callback path and present frames with `AVSampleBufferDisplayLayer`. Windows uses the same desktop decoded-frame callback and presents BGRA frames through a WinUI 3 Composition drawing surface. Audio playback uses FFplay's native audio backend and does not require a video surface.

The public API keeps the process-wide native redirection controls explicit.
Internal completion/log/statistics bridge slots are leased by consumer demand;
they are not a second public callback-registration API. This keeps direct v2
events and the v1 history fallback from being delivered twice while preserving
the native `disableRedirection()` authority.

## Example applications

The React Native example under `example/` contains Android, iOS, Apple tvOS, macOS, and Windows host projects. It demos the following workflows: FFmpeg generation/custom commands, remote recording and cancellation, FFprobe media information, FFplay controls, transcoding statistics, log-level controls, build introspection, file picking, and an on-screen log console.

The unified React Native example contains Android, iOS, Apple tvOS, macOS, and Windows native hosts under `example/`. Apple tvOS uses an isolated `react-native-tvos` runtime, and macOS uses the React Native macOS toolchain to exercise the same C++ TurboModule and the native `FFplayView` implementation with FFmpeg/FFprobe execution, generated video/audio playback, pause/resume/stop/seek/volume controls, aspect-ratio-preserving video output, and a resizable log pane.

The example also has a React Native Web target. From `react-native/example`, configure a local or released Wasm runtime, stage it, and run the Vite app:

```sh
npm run prepare-web
npm run web
```

The Web example uses COOP/COEP headers, initializes the same public API, executes FFmpeg and FFprobe, and mounts the canvas-backed `FFplayView`. Its Vite configuration demonstrates the standard `react-native` to `react-native-web` alias without package-source or backend rewrites.

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
   - `SessionQueueManager` with default maximum concurrency of 8
   - `Log`, `Statistics`, `MediaInformation`, `StreamInformation`, and `ChapterInformation`
2. **React Native TurboModule** (`src/NativeFFmpegKitExtended.ts`, `cpp/FFmpegKitExtendedImpl.*`)
   - A typed Codegen boundary.
   - Only scalar values and JSON strings cross the JavaScript/native boundary.
3. **libffmpegkit adapter** (`cpp/FFmpegKitDynamicApi.*`)
   - Resolves `ffmpegkit_wrapper.h` exports with `dlsym` on Unix/Apple platforms and `LoadLibrary`/`GetProcAddress` on Windows.
   - Does not expose opaque native handles to JavaScript.
   - Temporary session/media/statistics handles are released with `ffmpeg_kit_handle_release`.
   - Native strings allocated by the wrapper are released with `ffmpeg_kit_free`.

The adapter deliberately does not include `ffmpegkit_wrapper.h`. The source snapshot does not contain `ffmpeg_tls.h`, which that header includes, and the React Native bridge only needs the stable exported C ABI.

## Supported External Libraries<a id="libraries"></a></br>

| Bundle Key | Description                          |
| ---------- | ------------------------------------ |
| `b+`       | Base bundle and above.               |
| `a+`       | Audio bundle and above.              |
| `v+`       | Video bundle and above.              |
| `h+`       | Video+Hardware bundle and above.     |
| `f`        | Full bundle only.                    |
| *(empty)*  | not available on this platform.      |

| Library                                                                                    | Android | Linux | Windows | tvOS | iOS | macOS |
| ---------------------------------------------------------------------                      | ------- | ----- | ------- | ---- | --- | ----- |
| **System**                                                                                 |         |       |         |      |     |       |
| bzlib, iconv, lzma, zlib                                                                   | a+      | a+    | a+      | a+   | a+  | a+    |
| **TLS / HTTPS**<sup>[4](#https-info)</sup> *(one selected per build)*                      |         |       |         |      |     |       |
| openssl *(default)*, gnutls, mbedtls, libtls                                               | a+      | a+    | a+      | a+   | a+  | a+    |
| schannel                                                                                   |         |       | a+      |      |     | a+    |
| **Streaming**                                                                              |         |       |         |      |     |       |
| libsrt, librist, librtmp                                                                   | a+      | a+    | a+      | a+   | a+  | a+    |
| **Audio Codecs**                                                                           |         |       |         |      |     |       |
| libcodec2, libgsm, libilbc, liblc3, libmodplug                                             | a+      | a+    | a+      | a+   | a+  | a+    |
| libmp3lame, libopencore-amrnb, libopencore-amrwb                                           | a+      | a+    | a+      | a+   | a+  | a+    |
| libopenmpt, libopus, libsoxr, libspeex, libtwolame                                         | a+      | a+    | a+      | a+   | a+  | a+    |
| libvo-amrwbenc, libvorbis, openal                                                          | a+      | a+    | a+      | a+   | a+  | a+    |
| alsa                                                                                       |         | a+    |         |      |     |       |
| libbs2b<sup>[10](#gpl-info)</sup>                                                          | a+      | a+    | a+      | a+   | a+  | a+    |
| libmpeghdec<sup>[9](#nonfree-info)</sup> *(custom deployment only)*                        | a+      | a+    | a+      | a+   | a+  | a+    |
| **Audio Extras** *(not in `small` builds)*                                                 |         |       |         |      |     |       |
| chromaprint, libflite, libgme, libmysofa, libshine, lv2                                    | a+      | a+    | a+      | a+   | a+  | a+    |
| libcdio, librubberband<sup>[10](#gpl-info)</sup>                                           | a+      | a+    | a+      | a+   | a+  | a+    |
| ladspa, libpulse, sndio                                                                    |         | a+    |         |      |     |       |
| libjack<sup>[10](#gpl-info)</sup>                                                          |         | a+    |         |      |     |       |
| **Video Libraries**                                                                        |         |       |         |      |     |       |
| lcms2, libaom, libaribcaption                                                              | v+      | v+    | v+      | v+   | v+  | v+    |
| libass, libbluray, libcaca, libdav1d                                                       | v+      | v+    | v+      | v+   | v+  | v+    |
| libdav1d, libfontconfig, libfreetype, libfribidi                                           | v+      | v+    | v+      | v+   | v+  | v+    |
| libharfbuzz, libjxl, libkvazaar, liblcevc-dec                                              | v+      | v+    | v+      | v+   | v+  | v+    |
| liboapv, libopenh264, libopenjpeg, librav1e                                                | v+      | v+    | v+      | v+   | v+  | v+    |
| librsvg, libsnappy, libsvtav1, libtheora                                                   | v+      | v+    | v+      | v+   | v+  | v+    |
| libuavs3d, libvpx, libvvenc, libwebp                                                       | v+      | v+    | v+      | v+   | v+  | v+    |
| libxevd, libxeve, libzimg, libzvbi, libxml2, sdl2                                          | v+      | v+    | v+      | v+   | v+  | v+    |
| libdavs2, libdvdnav, libdvdread, libx264<sup>[10](#gpl-info)</sup>                         | v+      | v+    | v+      | v+   | v+  | v+    |
| libx265, libxavs, libxavs2, libaribb24<sup>[10](#gpl-info)</sup>                           | v+      | v+    | v+      | v+   | v+  | v+    |
| libdc1394, libiec61883, libsvtjpegxs                                                       |         | v+    |         |      |     |       |
| libxvid<sup>[10](#gpl-info)</sup>                                                          |         | v+    |         |      |     |       |
| libopencolorio<sup>[15](#arch-info)</sup>                                                  | v+      | v+    | v+      | v+   | v+  | v+    |
| **Video Extras** *(not in `small` builds)*                                                 |         |       |         |      |     |       |
| libklvanc, liblensfun, libqrencode, libvmaf, vapoursynth                                   | v+      | v+    | v+      | v+   | v+  | v+    |
| frei0r, libvidstab<sup>[10](#gpl-info)</sup>                                               | v+      | v+    | v+      |      | v+  | v+    |
| libv4l2, libxcb, libxcb-shape, libxcb-shm, libxcb-xfixes, xlib                             |         | v+    |         |      |     |       |
| avisynth<sup>[10](#gpl-info)</sup>                                                         |         | v+    | v+      |      |     | v+    |
| decklink<sup>[9](#nonfree-info)</sup> *(custom deployment only)*                           | v+      | v+    | v+      | v+   | v+  | v+    |
| **Hardware Acceleration**                                                                  |         |       |         |      |     |       |
| amf, libmfx, libplacebo, libvpl                                                            | h+      | h+    | h+      | h+   | h+  | h+    |
| opencl, opengl, vulkan, vulkan-static                                                      | h+      | h+    | h+      | h+   | h+  | h+    |
| ffnvcodec, cuvid, nvdec, nvenc<sup>[12](#redist-info)</sup> *(custom deployment only)*     |         | h+    | h+      |      |     |       |
| cuda-llvm, cuda-nvcc<sup>[12](#redist-info)</sup> *(custom deployment only)*               |         | h+    | h+      |      |     |       |
| libdrm, vaapi, rkmpp, vdpau                                                                |         | h+    |         |      |     |       |
| v4l2-m2m<sup>[10](#gpl-info)</sup>                                                         |         | h+    |         |      |     |       |
| **AI** *(Full bundle only)*                                                                |         |       |         |      |     |       |
| pocketsphinx, whisper                                                                      | f       | f     | f       | f    | f   | f     |
| libopencv, libquirc, libtesseract<sup>[11](#compute-info)</sup>                            | f       | f     | f       | f    | f   | f     |
| libopenvino, libtensorflow<sup>[11](#compute-info)</sup>                                   |         | f     | f       |      |     | f     |
| libonnxruntime<sup>[11](#compute-info)</sup>                                               |         | f     | f       |      |     | f     |
| libtorch<sup>[11](#compute-info)</sup>                                                     |         | f     |         |      |     | f     |
| **Nonfree additions** *(custom deployment only)*                                           |         |       |         |      |     |       |
| libfdk-aac<sup>[9](#nonfree-info)</sup>                                                    | f       | f     | f       | f    | f   | f     |
| **Platform-specific** *(All bundles)*                                                      |         |       |         |      |     |       |
| jni, mediacodec                                                                            | b+      |       |         |      |     |       |
| appkit, avfoundation, audiotoolbox, coreimage, metal, securetransport                      |         |       |         | b+   | b+  | b+    |
| videotoolbox, schannel, dxva2, d3d12va, d3d11va, mediafoundation                           |         |       |         | b+   | b+  | b+    |
| appkit                                                                                     |         |       |         |      |     | b+    |
| schannel, dxva2, d3d12va, d3d11va, mediafoundation                                         |         |       | b+      |      |     |       |
| alsa                                                                                       |         | b+    |         |      |     |       |

> frei0r, liblensfun, librsvg, and pocketsphinx are not available on `tvOS`.

You can also get the full list of supported external libraries by running `--list-libraries`

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
| libonnxruntime<sup>[8](#install-info)</sup>  | Runs DNN-based filters using ONNX Runtime backend       |                                        |                                  |      |                    |                    |                    | [11](#compute-info) |
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
| libopencolorio<sup>[15](#arch-info)</sup>   | Color space conversion                                  |                                        |                                  |      |                    | [15](#arch-info)   | [15](#arch-info)   | [15](#arch-info)    |
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
