# FFmpegKit Extended for Flutter & React-native

<div align="center">

<img src="https://github.com/akashskypatel/ffmpeg-kit-extended/raw/master/assets/banner_combined.png" alt="FFmpegKit Extended Banner" width="100%">

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Issues](https://img.shields.io/github/issues/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/issues) [![Downloads](https://img.shields.io/pub/dm/ffmpeg_kit_extended_flutter?style=flat-square&logoColor=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub version](https://img.shields.io/pub/v/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub likes](https://img.shields.io/pub/likes/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Pub points](https://img.shields.io/pub/points/ffmpeg_kit_extended_flutter?color=144DB3)](https://pub.dev/packages/ffmpeg_kit_extended_flutter) [![Downloads](https://img.shields.io/npm/dm/ffmpeg-kit-extended?style=flat-square&logoColor=144DB3)](https://www.npmjs.com/package/ffmpeg-kit-extended) [![Npm version](https://img.shields.io/npm/v/ffmpeg-kit-extended?color=144DB3)](https://www.npmjs.com/package/ffmpeg-kit-extended) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</div>

## Translations

<div align="center">

[English](README.md) | [Español](flutter/doc/README.es.md) | [简体中文](flutter/doc/README.zh-CN.md) | [हिन्दी](flutter/doc/README.hi.md) | [العربية](flutter/doc/README.ar.md) | [Français](flutter/doc/README.fr.md) | [Português (Brasil)](flutter/doc/README.pt-BR.md) | [日本語](flutter/doc/README.ja.md)

</div>

`ffmpeg-kit-extended` is a comprehensive Flutter and React-native plugin for executing `FFmpeg`, `FFprobe`, and `FFplay` `9.0.1 API` commands on `Android`, `iOS`, `macOS`, `Linux`, `Windows`, and Flutter WebAssembly builds. Flutter Web uses the same Dart SDK and public API as native platforms; only the platform integration layer differs. Native Flutter platforms use Dart `FFI`, while Web uses generated Wasm bindings and Emscripten memory.

If you like the project and are using it in your app give it a ⭐ on [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) and [ffmpeg-kit-extended](https://github.com/akashskypatel/ffmpeg-kit-extended), and a 👍 on [pub.dev](https://pub.dev/packages/ffmpeg_kit_extended_flutter). It helps a lot 🙏! Happy coding 🚀!

## Features

- **Cross-Platform Support**: Works on `Android`, `iOS`, `macOS`, `Linux`, `Windows`, and Flutter Web Wasm builds.
  - **Android**: Full video playback support with native surface rendering.
    - **x86**: `x86` architecture is not supported due to its legacy status.
  - **iOS & macOS**: High-performance video playback with `CVPixelBuffer` and Metal integration.
    - **iOS**: Supports physical devices and simulators. Simulator `x86_64` is
      conditional on the selected artifact containing that slice; do not
      blanket-exclude it when the slice is available.
  - **Linux**: Full video playback support with `OpenGL` integration.
    - **arm64**: `arm64` architecture currently not supported, coming soon!
  - **Flutter Web**: FFmpeg, FFprobe, and FFplay run from the staged `wasm32` bundle. FFplay renders RGBA frames through the unified Flutter surface API.
- **`FFmpeg`, `FFprobe` & `FFplay`**: [Latest `9.0.1 API`](https://www.ffmpeg.org/download.html) support for media manipulation, information retrieval, and audio/video playback.
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

| Platform                 | Status       | Flutter               | React-native         | Architecture         | Minimum Requirements |
| ------------------------ | ------------ | --------------------- | -------------------- | -------------------- | -------------------- |
| Android (and Android TV) | ✅ Supported | ✅ Supported          | ✅ Supported         | armv7, arm64, x86_64 | API 26+              |
| iOS (and Simulator)      | ✅ Supported | ✅ Supported          | ✅ Supported         | arm64; x86_64 when present | iOS 13+          |
| tvOS (and Simulator)     | ✅ Supported | ❌ Not Supported      | ✅ Supported         | arm64                | tvOS 13+             |
| macOS                    | ✅ Supported | ✅ Supported          | ✅ Supported         | arm64, x86_64        | macOS 13+            |
| Linux                    | ✅ Supported | ✅ Supported          | ❌ Not Supported     | x86_64               | glibc 2.28+          |
| Windows                  | ✅ Supported | ✅ Supported          | ✅ Supported         | x86_64               | Windows 8+           |
| Web (Flutter Wasm)       | ✅ Supported | ✅ Supported          | ✅ Supported         | wasm32               | Cross-origin isolation required |

Flutter currently does not natively support tvOS, so tvOS support is not available for Flutter.

React-native currently does not natively support Linux, so Linux support is not available for React-native.

Note that the WebAssembly bundle has pthread support by default. For a `non-pthread` build, a custom build of the WebAssembly dependencies and bundle is required using <https://github.com/akashskypatel/ffmpeg-kit-builders>.

Flutter Web requires `flutter build web --wasm`. Deployments using pthread-enabled Wasm bundles must provide cross-origin isolation headers:

```http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Verify `window.crossOriginIsolated === true` in the browser. See the [Flutter architecture and maintenance handoff](flutter/doc/architecture.md) for platform boundaries, initialization, callback routing, memory ownership, and Web limitations.

Wasm browser-runtime checks are performed locally against the served Web output;
a workflow compile/build result does not replace a local browser smoke check.

You will have to update your app's minimum requirements on your own to match the requirements above.

## 🎬 Demo

<div align="center">
<a href="https://raw.githubusercontent.com/akashskypatel/ffmpeg-kit-extended/master/flutter/doc/demo.gif">Click here if the image doesn't load</a>
<br>
<img width="378" height="672" src="https://raw.githubusercontent.com/akashskypatel/ffmpeg-kit-extended/master/flutter/doc/demo.gif" alt="Demo" style="border-radius: 10px;" />
<br>

[_Video demonstration of FFmpegKit Extended Flutter and React-native plugin showing real-time video playback, FFmpeg command execution, and the comprehensive introspection API interface._](https://raw.githubusercontent.com/akashskypatel/ffmpeg-kit-extended/master/flutter/doc/demo.gif)

</div>

### Pre-bundled Builds

- **base**: Basic build with core FFmpeg libraries, libjsoncpp, SDL2, and platform defaults.
- **full**: Full build with all platform-compatible FFmpeg libraries. See: <https://github.com/akashskypatel/ffmpeg-kit-builders?tab=readme-ov-file#supported-external-libraries>
- **audio**: Build with audio-only FFmpeg libraries.
- **video**: Build with video-only FFmpeg libraries.
- **video_hw**: Build with hardware-accelerated video FFmpeg libraries.

### Feature Matrix

| Feature   | Base | Audio | Video | Video+Hardware | Full |
| --------- | ---- | ----- | ----- | -------------- | ---- |
| Video     |      |       | x     | x              | x    |
| Audio     |      | x     | x     | x              | x    |
| Streaming (native bundle support) |      | x     | x     | x              | x    |
| Hardware  |      |       |       | x              | x    |
| AI*       |      |       |       |                | x*   |
| HTTPS     | *    | x     | x     | x              | x    |
| Platform* | x    | x     | x     | x              | x    |
| Other*    |      |       |       |                | x    |

1. AI features are not supported on all platforms. You must deploy your own custom build of ffmpeg-kit-extended to enable certain AI features.
   - See [Supported External Libraries](#libraries) for more information.

| Runtime | Network stream input/recording |
| --- | --- |
| Web (Wasm) | Not supported, including RTMP/RTMPE |

The bundle-level Streaming row applies to native targets; it does not imply Web/Wasm network streaming support.

2. Platform features are built-in platform libraries that FFmpeg support like AVFounation, VideoToolbox, etc. on apple platforms or DirectX, MediaFoundation on Windows.

3. HTTPS features are enabled by default for Platforms that have built-in HTTPS support like Windows or Apple. For Linux and Android OpenSSL is enabled by default.

4. Other features are additional features that are not covered by the above categories. See [Supported External Libraries](#libraries) for more information.

5. To deploy a custom build see [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders).

## Supported External Libraries<a id="libraries"></a></br>

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
> - **`libonnxruntime`** is not available on `x86_64` `MacOS`.
> - Only CPU AI libraries are vendored with pre-built bundles. GPU libraries must be custom deployed.

Platform availability follows the `CONFIG_*` and `CONFIG_*_UNSUPPORTED` definitions in [`variable.sh`](libs/libffmpegkit/scripts/variable.sh). A grouped row contains only libraries with identical platform availability and bundle keys.

| Bundle Key | Description |
| --- | --- |
| `b+` | Base bundle and above. |
| `a+` | Audio bundle and above. |
| `v+` | Video bundle and above. |
| `h+` | Video+Hardware bundle and above. |
| `f` | Full bundle only. |
| `c` | Custom selection; not enabled by the standard bundle categories. |
| ` ` | Explicitly disabled for this platform. |

| Library | Android | Linux | Windows | tvOS | iOS | macOS | Web (Wasm) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Base dependencies** |  |  |  |  |  |  |  |
| libjsoncpp, sdl2 | b+ | b+ | b+ | b+ | b+ | b+ | b+ |
| **System** |  |  |  |  |  |  |  |
| bzlib, iconv, lzma, zlib | a+ | a+ | a+ | a+ | a+ | a+ | a+ |
| **TLS / HTTPS (one selected per build)** |  |  |  |  |  |  |  |
| gnutls, libtls, mbedtls | a+ | a+ | a+ | a+ | a+ | a+ | a+ |
| openssl | b+ | b+ | a+ | a+ | a+ | a+ | b+ |
| **Streaming** |  |  |  |  |  |  |  |
| libsrt, librist, librtmp | a+ | a+ | a+ | a+ | a+ | a+ |   |
| **Audio Codecs** |  |  |  |  |  |  |  |
| alsa |   | b+ |   |   |   |   |   |
| libbs2b<sup>[10](#gpl-info)</sup> | a+ | a+ | a+ | a+ | a+ | a+ | a+ |
| libcodec2, libgsm, libilbc, liblc3, libmodplug | a+ | a+ | a+ | a+ | a+ | a+ | a+ |
| libmp3lame, libopencore-amrnb, libopencore-amrwb, libopenmpt, libopus | a+ | a+ | a+ | a+ | a+ | a+ | a+ |
| libsoxr, libspeex, libtwolame, libvo-amrwbenc, libvorbis | a+ | a+ | a+ | a+ | a+ | a+ | a+ |
| openal | a+ | a+ | a+ | a+ | a+ | a+ | a+ |
| **Audio Extras (not in `small` builds)** |  |  |  |  |  |  |  |
| chromaprint | a+ | a+ | a+ | a+ | a+ | a+ | a+ |
| ladspa |   | a+ |   |   |   |   |   |
| libcdio<sup>[10](#gpl-info)</sup> |   | a+ | a+ |   |   | a+ |   |
| libflite, libgme | a+ | a+ | a+ | a+ | a+ | a+ | a+ |
| libjack<sup>[10](#gpl-info)</sup> |   | a+ |   |   |   |   |   |
| libmysofa | a+ | a+ | a+ | a+ | a+ | a+ | a+ |
| libpulse |   | a+ |   |   |   |   |   |
| librubberband<sup>[10](#gpl-info)</sup> | a+ | a+ | a+ | a+ | a+ | a+ | a+ |
| libshine | a+ | a+ | a+ | a+ | a+ | a+ | a+ |
| lv2 | a+ | a+ | a+ | a+ | a+ | a+ |   |
| sndio |   | a+ |   |   |   |   |   |
| **Audio Nonfree (custom deployment only)** |  |  |  |  |  |  |  |
| libfdk-aac, libmpeghdec<sup>[9](#nonfree-info)</sup> *(custom deployment only)* | a+ | a+ | a+ | a+ | a+ | a+ | a+ |
| **Video Libraries** |  |  |  |  |  |  |  |
| lcms2, libaom | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| libaribb24<sup>[10](#gpl-info)</sup> | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| libaribcaption, libass | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| libbluray |   | v+ | v+ |   |   | v+ | v+ |
| libcaca, libdav1d | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| libdavs2<sup>[10](#gpl-info)</sup> | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| libdc1394 |   | v+ |   |   |   |   |   |
| libdvdnav, libdvdread<sup>[10](#gpl-info)</sup> |   | v+ | v+ |   |   | v+ | v+ |
| libfontconfig, libfreetype, libfribidi, libharfbuzz | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| libiec61883 |   | v+ |   |   |   |   |   |
| libjxl, libkvazaar, liblcevc-dec, liboapv, libopenh264 | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| libopenjpeg | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| libsvtjpegxs<sup>[15](#arch-info)</sup> | v+ | v+ | v+ |   |   | v+ |   |
| libopencolorio<sup>[15](#arch-info)</sup> | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| librav1e | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| librsvg | v+ | v+ | v+ |   | v+ | v+ | v+ |
| libsnappy | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| libsvtav1 | v+ | v+ | v+ | v+ | v+ | v+ |   |
| libtheora, libuavs3d, libvpx, libvvenc, libwebp | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| libx264, libx265, libxavs, libxavs2<sup>[10](#gpl-info)</sup> | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| libxevd, libxeve | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| libxvid<sup>[10](#gpl-info)</sup> |   | v+ |   |   |   |   |   |
| libzimg, libzvbi, libxml2 | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| **Video Extras (not in `small` builds)** |  |  |  |  |  |  |  |
| avisynth<sup>[10](#gpl-info)</sup> |   | v+ | v+ |   |   | v+ |   |
| frei0r<sup>[10](#gpl-info)</sup> | v+ | v+ | v+ |   | v+ | v+ |   |
| libklvanc | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| liblensfun | v+ | v+ | v+ |   | v+ | v+ | v+ |
| libqrencode | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| libv4l2 |   | v+ |   |   |   |   |   |
| libvidstab<sup>[10](#gpl-info)</sup> | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| libvmaf | v+ | v+ | v+ | v+ | v+ | v+ | v+ |
| libxcb, libxcb-shape, libxcb-shm, libxcb-xfixes |   | v+ |   |   |   |   |   |
| vapoursynth | v+ | v+ | v+ | v+ | v+ | v+ |   |
| xlib |   | v+ |   |   |   |   |   |
| **Video Nonfree (custom deployment only)** |  |  |  |  |  |  |  |
| decklink<sup>[9](#nonfree-info)</sup> *(custom deployment only)* | v+ | v+ | v+ | v+ | v+ | v+ |   |
| **Hardware Acceleration** |  |  |  |  |  |  |  |
| amf, libmfx, libplacebo | h+ | h+ | h+ | h+ | h+ | h+ |   |
| libvpl | h+ | h+ | h+ |   |   |   |   |
| opencl, opengl, vulkan | h+ | h+ | h+ | h+ | h+ | h+ |   |
| vdpau |   | h+ |   |   |   |   |   |
| ffnvcodec<sup>[12](#redist-info)</sup> *(custom deployment only)* |   | h+ | h+ |   |   |   |   |
| cuda-llvm<sup>[12](#redist-info)</sup> *(custom deployment only)* |   |   | h+ |   |   |   |   |
| cuvid, nvdec, nvenc<sup>[12](#redist-info)</sup> *(custom deployment only)* |   | h+ | h+ |   |   |   |   |
| libdrm, vaapi, rkmpp |   | h+ |   |   |   |   |   |
| v4l2-m2m<sup>[10](#gpl-info)</sup> |   | h+ |   |   |   |   |   |
| vulkan-static | h+ | h+ | h+ | h+ | h+ | h+ |   |
| **Hardware Nonfree (custom deployment only)** |  |  |  |  |  |  |  |
| mmal<sup>[9](#nonfree-info)</sup> *(custom deployment only)* |   |   |   |   |   |   |   |
| cuda-nvcc<sup>[12](#redist-info)</sup> *(custom deployment only)* |   | h+ |   |   |   |   |   |
| **AI (Full bundle only)** |  |  |  |  |  |  |  |
| pocketsphinx | f | f | f |   | f | f | f |
| whisper | f | f | f | f | f | f | f |
| **AI Video (Full bundle only)** |  |  |  |  |  |  |  |
| libopencv | f | f | f | f | f | f | f |
| libopenvino<sup>[11](#compute-info)</sup> |   | f | f |   |   | f |   |
| libquirc | f | f | f | f | f | f | f |
| libtensorflow<sup>[11](#compute-info)</sup> |   | f | f |   |   | f |   |
| libtesseract | f | f | f | f | f | f | f |
| libonnxruntime<sup>[11](#compute-info)</sup> |   | f | f |   |   | f |   |
| libtorch<sup>[11](#compute-info)</sup> |   | f |   |   |   | f |   |
| **Crypto (custom selection)** |  |  |  |  |  |  |  |
| gcrypt, gmp | c | c | c | c | c | c | c |
| **MQ (custom deployment only)** |  |  |  |  |  |  |  |
| librabbitmq, libzmq | c | c | c | c | c | c |   |
| **SMB (custom deployment only)** |  |  |  |  |  |  |  |
| libsmbclient<sup>[10](#gpl-info)</sup> |   | c |   |   |   | c |   |
| **SSH (custom deployment only)** |  |  |  |  |  |  |  |
| libssh | c | c | c | c | c | c |   |
| **Platform-specific (all bundles)** |  |  |  |  |  |  |  |
| appkit |   |   |   |   |   | b+ |   |
| audiotoolbox, avfoundation, coreimage |   |   |   | b+ | b+ | b+ |   |
| d3d11va, d3d12va, dxva2 |   |   | b+ |   |   |   |   |
| jni, mediacodec | b+ |   |   |   |   |   |   |
| mediafoundation |   |   | b+ |   |   |   |   |
| metal |   |   |   | b+ | b+ | b+ |   |
| schannel |   |   | b+ |   |   |   |   |
| securetransport, videotoolbox |   |   |   | b+ | b+ | b+ |   |

These entries describe build configuration support, not the contents of a particular release binary or runtime hardware availability. GPL, nonfree, `small`, architecture, and conflicting-library restrictions still apply; TLS alternatives require selection. OpenSSL is a platform default on Android, Linux, and Web/Wasm. Apple Secure Transport and Windows SChannel are platform defaults. `ohcodec` is specific to OpenHarmony, which is not a column in this matrix; `mmal` is disabled on every platform shown.

The Web column describes external library configuration only. Browser protocol support depends on the selected runtime; disabling `librtmp` does not establish whether HTTP(S)/HLS is supported.

You can also get the full list of supported external libraries by running `--list-libraries`

| Library                                      | Description                                             | Platform<sup>[1](#platform-info)</sup> | Extra<sup>[2](#extra-info)</sup> | Base | Audio              | Video              | Video+Hardware     | Full                |
| -------------------------------------------- | ------------------------------------------------------- | -------------------------------------- | -------------------------------- | ---- | ------------------ | ------------------ | ------------------ | ------------------- |
| jni<sup>[8](#install-info)</sup>             | Enables Java Native Interface interactions on Android   | Android                                |                                  | x    | x                  | x                  | x                  | x                   |
| appkit<sup>[8](#install-info)</sup>          | Accesses AppKit for screen and window capture           | macOS                                  |                                  | x    | x                  | x                  | x                  | x                   |
| avfoundation<sup>[8](#install-info)</sup>    | Captures input from AVFoundation devices (cameras/mics) | tvOS, iOS, macOS                       |                                  | x    | x                  | x                  | x                  | x                   |
| pocketsphinx                                 | Performs offline speech-to-text conversion              | Android, Linux, Windows, iOS, macOS, Web (Wasm) |                                  |      |                    |                    |                    | x                   |
| whisper                                      | Integrates OpenAI Whisper for speech recognition        |                                        |                                  |      |                    |                    |                    | x                   |
| audiotoolbox<sup>[8](#install-info)</sup>    | Accesses AudioToolbox for native codec support          | tvOS, iOS, macOS                       |                                  | x    | x                  | x                  | x                  | x                   |
| alsa                                         | Accesses ALSA for audio input and output                | Linux                                  |                                  | x    | x                  | x                  | x                  | x                   |
| chromaprint                                  | Calculates audio fingerprints for identification        |                                        | x                                |      | x                  | x                  | x                  | x                   |
| ladspa                                       | Loads LADSPA plugins for audio filtering                | Linux                                  | x                                |      | x                  | x                  | x                  | x                   |
| libbs2b                                      | Simulates binaural audio via DSP                        |                                        |                                  |      | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libcdio                                      | Reads and extracts audio from CDs                       | Linux, Windows, macOS                  | [10](#gpl-info)                  |      | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
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
| lv2                                          | Loads LV2 plugins for audio filtering                   | Android, Linux, Windows, tvOS, iOS, macOS | x                                |      | x                  | x                  | x                  | x                   |
| openal                                       | Captures audio via OpenAL 1.1                           |                                        |                                  |      | x                  | x                  | x                  | x                   |
| sndio                                        | Accesses sndio for audio I/O on OpenBSD                 | Linux                                  | x                                |      | x                  | x                  | x                  | x                   |
| gcrypt                                       | Provides crypto functions for RTMP/RTMPE                | [3](#rtmpte-info)                      |                                  |      |                    |                    |                    |                     |
| gmp                                          | Provides math functions for crypto contexts             | [3](#rtmpte-info)                      |                                  |      |                    |                    |                    |                     |
| bzlib                                        | Compresses and decompresses bzip2 streams               |                                        |                                  |      | x                  | x                  | x                  | x                   |
| iconv                                        | Converts character encodings for text/subtitles         |                                        |                                  |      | x                  | x                  | x                  | x                   |
| libxml2                                      | Parses XML for DASH, IMF, and other formats             |                                        |                                  |      |                    | x                  | x                  | x                   |
| lzma                                         | Provides LZMA lossless data compression                 |                                        |                                  |      | x                  | x                  | x                  | x                   |
| zlib                                         | Provides Deflate/zlib lossless data compression         |                                        |                                  |      | x                  | x                  | x                  | x                   |
| amf                                          | Accesses AMD Advanced Media Framework (GPU encoding)    | Android, Linux, Windows, tvOS, iOS, macOS |                                  |      |                    |                    | x                  | x                   |
| mediacodec<sup>[8](#install-info)</sup>      | Accesses Android MediaCodec hardware acceleration       | Android                                |                                  | x    | x                  | x                  | x                  | x                   |
| coreimage<sup>[8](#install-info)</sup>       | Applies video filters via Apple CoreImage               | tvOS, iOS, macOS                       |                                  | x    | x                  | x                  | x                  | x                   |
| metal<sup>[8](#install-info)</sup>           | Utilizes Apple Metal for GPU acceleration               | tvOS, iOS, macOS                       |                                  | x    | x                  | x                  | x                  | x                   |
| videotoolbox<sup>[8](#install-info)</sup>    | Accesses VideoToolbox for hardware encoding/decoding    | tvOS, iOS, macOS                       |                                  | x    | x                  | x                  | x                  | x                   |
| cuda-llvm<sup>[8](#install-info)</sup>       | Compiles CUDA kernels at runtime using Clang            | Windows                                |                                  |      |                    |                    | [12](#redist-info) | [12](#redist-info)  |
| cuda-nvcc<sup>[8](#install-info)</sup>       | Compiles CUDA kernels using NVCC                        | Linux                                  |                                  |      |                    |                    | [12](#redist-info) | [12](#redist-info)  |
| cuvid<sup>[8](#install-info)</sup>           | Accesses Nvidia CUVID for decoding (Legacy)             | Linux, Windows                         |                                  |      |                    |                    | [12](#redist-info) | [12](#redist-info)  |
| ffnvcodec                                    | Provides headers for Nvidia codec API integration       | Linux, Windows                         |                                  |      |                    |                    | [12](#redist-info) | [12](#redist-info)  |
| libdrm                                       | Accesses Direct Rendering Manager for Linux GPU buffer  | Linux                                  |                                  |      |                    |                    | x                  | x                   |
| libglslang<sup>[14](#conflict-info)</sup>    | Compiles GLSL shaders to SPIR-V for Vulkan filters      |                                        |                                  |      |                    |                    | x                  | x                   |
| libmfx<sup>[14](#conflict-info)</sup>        | Accesses Intel Quick Sync Video (QSV) via MediaSDK      | Android, Linux, Windows, tvOS, iOS, macOS |                                  |      |                    |                    | x                  | x                   |
| libnpp<sup>[13](#deprecated-info)</sup>      | Uses Nvidia Performance Primitives for image processing | Nvidia                                 |                                  |      |                    |                    |                    |                     |
| libplacebo                                   | Applies high-quality GPU video processing filters       | Android, Linux, Windows, tvOS, iOS, macOS |                                  |      |                    |                    | x                  | x                   |
| libshaderc<sup>[14](#conflict-info)</sup>    | Compiles GLSL shaders to SPIR-V (Google implementation) |                                        |                                  |      |                    |                    | x                  | x                   |
| libvpl<sup>[14](#conflict-info)</sup>        | Accesses Intel oneVPL video processing library          | Android, Linux, Windows                |                                  |      |                    |                    | x                  | x                   |
| nvdec<sup>[8](#install-info)</sup>           | Accesses Nvidia NVDEC for hardware decoding             | Linux, Windows                         |                                  |      |                    |                    | [12](#redist-info) | [12](#redist-info)  |
| nvenc<sup>[8](#install-info)</sup>           | Accesses Nvidia NVENC for hardware encoding             | Linux, Windows                         |                                  |      |                    |                    | [12](#redist-info) | [12](#redist-info)  |
| opencl                                       | Enables OpenCL-based video filtering                    | Android, Linux, Windows, tvOS, iOS, macOS |                                  |      |                    |                    | x                  | x                   |
| rkmpp                                        | Accesses Rockchip Media Process Platform for HW codecs  | Linux                                  |                                  |      |                    |                    | x                  | x                   |
| v4l2-m2m                                     | Accesses V4L2 Memory-to-Memory hardware codecs          | Linux                                  |                                  |      |                    |                    | [10](#gpl-info)    | [10](#gpl-info)     |
| vaapi                                        | Accesses Video Acceleration API for HW codecs           | Linux                                  |                                  |      |                    |                    | x                  | x                   |
| vdpau<sup>[8](#install-info)</sup>           | Accesses VDPAU for hardware decoding on Unix            | Linux                                  |                                  |      |                    |                    | x                  | x                   |
| vulkan                                       | Enables Vulkan-based filtering and rendering            | Android, Linux, Windows, tvOS, iOS, macOS |                                  |      |                    |                    | x                  | x                   |
| vulkan-static                                | Links libvulkan statically                              | Android, Linux, Windows, tvOS, iOS, macOS |                                  |      |                    |                    | x                  | x                   |
| opengl                                       | Enables OpenGL-based rendering and filtering            | Android, Linux, Windows, tvOS, iOS, macOS |                                  |      |                    |                    | x                  | x                   |
| d3d11va<sup>[8](#install-info)</sup>         | Accesses Direct3D 11 for video acceleration             | Windows                                |                                  | x    | x                  | x                  | x                  | x                   |
| d3d12va<sup>[8](#install-info)</sup>         | Accesses Direct3D 12 for video acceleration             | Windows                                |                                  | x    | x                  | x                  | x                  | x                   |
| dxva2<sup>[8](#install-info)</sup>           | Accesses DirectX 9 for video acceleration               | Windows                                |                                  | x    | x                  | x                  | x                  | x                   |
| mediafoundation<sup>[8](#install-info)</sup> | Accesses Windows Media Foundation for encoding          | Windows                                |                                  | x    | x                  | x                  | x                  | x                   |
| ohcodec<sup>[8](#install-info)</sup>         | Accesses OpenHarmony multimedia codec capabilities      | OpenHarmony (not shown above)          |                                  | x    | x                  | x                  | x                  | x                   |
| mmal                                         | Accesses Broadcom MMAL for Raspberry Pi multimedia      | Disabled on all platforms shown        |                                  |      |                    |                    | [9](#nonfree-info) | [9](#nonfree-info)  |
| securetransport<sup>[8](#install-info)</sup> | Provides TLS/SSL support via Apple Secure Transport     | tvOS, iOS, macOS                       |                                  | x    | x                  | x                  | x                  | x                   |
| gnutls                                       | Provides TLS/SSL support via GnuTLS                     |                                        |                                  |      | [4](#https-info)   | [4](#https-info)   | [4](#https-info)   | [4](#https-info)    |
| libtls                                       | Provides TLS/SSL support via LibreSSL                   |                                        |                                  |      | [4](#https-info)   | [4](#https-info)   | [4](#https-info)   | [4](#https-info)    |
| mbedtls                                      | Provides TLS/SSL support via mbedTLS                    |                                        |                                  |      | [4](#https-info)   | [4](#https-info)   | [4](#https-info)   | [4](#https-info)    |
| openssl                                      | Provides TLS/SSL support via OpenSSL                    |                                        |                                  | Android, Linux, Web/Wasm | [4](#https-info)   | [4](#https-info)   | [4](#https-info)   | [4](#https-info)    |
| schannel<sup>[8](#install-info)</sup>        | Provides TLS/SSL support via Windows SChannel           | Windows                                |                                  | x    | x                  | x                  | x                  | x                   |
| librabbitmq                                  | Enables AMQP protocol support (RabbitMQ)                | Android, Linux, Windows, tvOS, iOS, macOS | [5](#mq-info)                    |      |                    |                    |                    |                     |
| libzmq                                       | Enables ZeroMQ message passing protocol                 | Android, Linux, Windows, tvOS, iOS, macOS | [5](#mq-info)                    |      |                    |                    |                    |                     |
| libsmbclient                                 | Enables SMB/CIFS protocol support                       | Linux, macOS                           | [6](#smb-info) & [10](#gpl-info) |      |                    |                    |                    |                     |
| libssh                                       | Enables SFTP protocol support                           | Android, Linux, Windows, tvOS, iOS, macOS | [7](#ssh-info)                   |      |                    |                    |                    |                     |
| librist                                      | Enables Reliable Internet Stream Transport (RIST)       | Android, Linux, Windows, tvOS, iOS, macOS |                                  |      | x                  | x                  | x                  | x                   |
| librtmp                                      | Enables RTMP and RTMPE stream support                   | Android, Linux, Windows, tvOS, iOS, macOS |                                  |      | x                  | x                  | x                  | x                   |
| libsrt                                       | Enables Secure Reliable Transport (SRT) protocol        | Android, Linux, Windows, tvOS, iOS, macOS |                                  |      | x                  | x                  | x                  | x                   |
| libopencv                                    | Applies computer vision filters via OpenCV              |                                        |                                  |      |                    |                    |                    | x                   |
| libopenvino<sup>[8](#install-info)</sup>     | Runs DNN-based filters using Intel OpenVINO backend     | Linux, Windows, macOS                  |                                  |      |                    |                    |                    | [11](#compute-info) |
| libtensorflow<sup>[8](#install-info)</sup>   | Runs DNN-based filters using TensorFlow backend         | Linux, Windows, macOS                  |                                  |      |                    |                    |                    | [11](#compute-info) |
| libtorch<sup>[8](#install-info)</sup>        | Runs DNN-based filters using PyTorch backend            | Linux, macOS                           |                                  |      |                    |                    |                    | [11](#compute-info) |
| libonnxruntime<sup>[8](#install-info)</sup>  | Runs DNN-based filters using ONNX Runtime backend       | Linux, Windows, macOS                  |                                  |      |                    |                    |                    | [11](#compute-info) |
| libquirc                                     | Decodes QR codes from video streams                     |                                        |                                  |      |                    |                    |                    | x                   |
| libtesseract                                 | Performs Optical Character Recognition (OCR)            |                                        |                                  |      |                    |                    |                    | x                   |
| sdl2                                         | Outputs audio/video to window using SDL2                |                                        |                                  | x    | x                  | x                  | x                  | x                   |
| libjsoncpp | Provides JSON support for FFmpegKit |  |  | x | x | x | x | x |
| avisynth                                     | Reads and demuxes AviSynth script files                 | Linux, Windows, macOS                  | [10](#gpl-info)                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| decklink                                     | Captures/Outputs via Blackmagic DeckLink devices        | Android, Linux, Windows, tvOS, iOS, macOS |                                  |      |                    | [9](#nonfree-info) | [9](#nonfree-info) | [9](#nonfree-info)  |
| frei0r                                       | Loads Frei0r plugins for video filtering                | Android, Linux, Windows, iOS, macOS    | [10](#gpl-info)                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| lcms2                                        | Applies ICC color profiles using LittleCMS 2            |                                        |                                  |      |                    | x                  | x                  | x                   |
| libaom                                       | Encodes and decodes AV1 video                           |                                        |                                  |      |                    | x                  | x                  | x                   |
| libaribb24                                   | Decodes ARIB STD-B24 captions                           |                                        |                                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libaribcaption                               | Decodes ARIB captions (alternative library)             |                                        |                                  |      |                    | x                  | x                  | x                   |
| libass                                       | Renders ASS/SSA subtitles                               |                                        |                                  |      |                    | x                  | x                  | x                   |
| libbluray                                    | Reads Blu-ray playlists and protocols                   | Linux, Windows, macOS, Web (Wasm)      |                                  |      |                    | x                  | x                  | x                   |
| libcaca                                      | Renders video as ASCII characters                       |                                        |                                  |      |                    | x                  | x                  | x                   |
| libdav1d                                     | Decodes AV1 video (high performance)                    |                                        |                                  |      |                    | x                  | x                  | x                   |
| libdavs2                                     | Decodes AVS2 video                                      |                                        |                                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libdc1394                                    | Captures video from FireWire cameras                    | Linux                                  |                                  |      |                    | x                  | x                  | x                   |
| libdvdnav                                    | Navigates and demuxes DVD menus/content                 | Linux, Windows, macOS, Web (Wasm)      |                                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libdvdread                                   | Reads DVD filesystem structures                         | Linux, Windows, macOS, Web (Wasm)      |                                  |      |                    | [10](#gpl-info)    | [10](#gpl-info)    | [10](#gpl-info)     |
| libfontconfig                                | Configures and locates fonts for text rendering         |                                        |                                  |      |                    | x                  | x                  | x                   |
| libfreetype                                  | Renders fonts for text overlays                         |                                        |                                  |      |                    | x                  | x                  | x                   |
| libfribidi                                   | Handles bi-directional text logic                       |                                        |                                  |      |                    | x                  | x                  | x                   |
| libharfbuzz                                  | Shapes complex text for subtitles                       |                                        |                                  |      |                    | x                  | x                  | x                   |
| libiec61883                                  | Captures DV/HDV via FireWire                            | Linux                                  |                                  |      |                    | x                  | x                  | x                   |
| libjxl                                       | Encodes and decodes JPEG XL images                      |                                        |                                  |      |                    | x                  | x                  | x                   |
| libklvanc                                    | Processes Vertical Ancillary Data (VANC)                |                                        | x                                |      |                    | x                  | x                  | x                   |
| libkvazaar                                   | Encodes HEVC video                                      |                                        |                                  |      |                    | x                  | x                  | x                   |
| liblcevc-dec                                 | Decodes LCEVC video enhancement layers                  |                                        |                                  |      |                    | x                  | x                  | x                   |
| liblensfun                                   | Corrects lens distortion using Lensfun                  | Android, Linux, Windows, iOS, macOS, Web (Wasm) | x                                |      |                    | x                  | x                  | x                   |
| liboapv                                      | Encodes OAPV (Open Advanced Photos/Video)               |                                        |                                  |      |                    | x                  | x                  | x                   |
| libopenh264                                  | Encodes H.264 video (Cisco implementation)              |                                        |                                  |      |                    | x                  | x                  | x                   |
| libopenjpeg                                  | Encodes and decodes JPEG 2000 images                    |                                        |                                  |      |                    | x                  | x                  | x                   |
| libqrencode                                  | Generates QR codes as video sources                     |                                        | x                                |      |                    | x                  | x                  | x                   |
| librav1e                                     | Encodes AV1 video (Rust implementation)                 |                                        |                                  |      |                    | x                  | x                  | x                   |
| librsvg                                      | Renders SVG files for overlays                          | Android, Linux, Windows, iOS, macOS, Web (Wasm) |                                  |      |                    | x                  | x                  | x                   |
| libsnappy                                    | Compresses data for the Hap codec                       |                                        |                                  |      |                    | x                  | x                  | x                   |
| libsvtav1                                    | Encodes AV1 video (SVT implementation)                  | Android, Linux, Windows, tvOS, iOS, macOS |                                  |      |                    | x                  | x                  | x                   |
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
| vapoursynth                                  | Demuxes VapourSynth script frames                       | Android, Linux, Windows, tvOS, iOS, macOS | x                                |      |                    | x                  | x                  | x                   |
| xlib                                         | Captures screen content via Xlib                        | Linux                                  | x                                |      |                    | x                  | x                  | x                   |
| libsvtjpegxs                                 | Encodes JPEG XS video                                   | Android, Linux, Windows, macOS         |                                  |      |                    | x                  | x                  | x                   |
| libopencolorio<sup>[15](#arch-info)</sup>   | Color space conversion                                  |                                        |                                  |      |                    | [15](#arch-info)   | [15](#arch-info)   | [15](#arch-info)    |
| libmpeghdec                                  | Decodes MPEG-H 3D Audio                                 |                                        |                                  |      | [9](#nonfree-info) | [9](#nonfree-info) | [9](#nonfree-info) | [9](#nonfree-info)  |

<sup>1</sup> The detailed table is subject to the platform matrix above. A blank Platform cell adds no restriction; listed platforms limit availability. Platform-specific defaults are enabled in all bundles on their target platform.<a id="platform-info"></a></br>
<sup>2</sup> Extra libraries are enabled on non-small bundles.<a id="extra-info"></a></br>
<sup>3</sup> RTMP(T)E support requires either gcrypt or gmp if the requires SSL library is not selected in the bundle.<a id="rtmpte-info"></a></br>
<sup>4</sup> HTTPS support requires a selected TLS backend. Platform defaults and available alternatives are listed in the platform matrix above; a custom build can select another supported backend.<a id="https-info"></a></br>
<sup>5</sup> MQ libraries are not enabled by default in any bundle. A custom build must be deployed to enable them using `--enable-mq` OR `--enable-librabbitmq` and `--enable-libzmq`.<a id="mq-info"></a></br>
<sup>6</sup> SAMBA (SMB protocol) library is not enabled by default in any bundle (except on Windows, which supports SMB by default). A custom build must be deployed to enable them using `--enable-smb` OR `--enable-libsmbclient`.<a id="smb-info"></a></br>
<sup>7</sup> SSH library is not enabled by default in any bundle. A custom build must be deployed to enable them using `--enable-ssh` OR `--enable-libssh`.<a id="ssh-info"></a></br>
<sup>8</sup> These libraries cannot be built statically. If you deploy a static build with these libraries they will not be bundled with FFmpegKit wrapper bundle. The target system will need these libraries installed or running the wrapper may crash immediately. <a id="install-info"></a></br>
<sup>9</sup> These libraries have restrictive licenses that may make the binaries non-redistributable, are not compatible with GPL and only included with `--enable-nonfree`.<a id="nonfree-info"></a></br>
<sup>10</sup> These libraries are GPL and only included with `--enable-gpl`.<a id="gpl-info"></a></br>
<sup>11</sup> These libraries can either be selected with GPU support or CPU only. Note that some of them do not support AMD ROCm framework. The platform matrix above specifies availability for each AI library; mobile exclusions apply to libopenvino, libtensorflow, libtorch, and libonnxruntime.<a id="compute-info"></a></br>
<sup>12</sup> while these libraries are not compatible with GPL and have a more restrictive license, they are redistributable and will be bundled with non-gpl ffmpeg-kit bundle.<a id="redist-info"></a></br>
<sup>13</sup> These libraries have been deprecated and will be auto-disabled and repalced by modern library if available.<a id="deprecated-info"></a></br>
<sup>14</sup> These libraries conflict with other libraries with overlapping functionality. If both conflicting libraries are enabled, the preferred library, indicated by an * will be enabled and the other library will be disabled:<a id="conflict-info"></a>

>   - libmfx -> libvpl*</br>
>   - libglslang -> libshaderc*</br>

<sup>15</sup> These libraries are only supported on specific CPU architectures.<a id="arch-info"></a></br>

>   - libsvtjpegxs -> x86_64 only</br>

## License

This project is licensed under the LGPL v3.0 by default. However, depending on the underlying FFmpeg build configuration and external libraries used, the effective license may be GPL v3.0. Please review the licenses of the included libraries.

Understand the difference between LGPL and GPL licenses before using this plugin in your project.

Using GPL licensed components in your application may require your application to also be licensed under GPL.
