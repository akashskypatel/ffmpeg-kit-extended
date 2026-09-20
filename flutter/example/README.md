# FFmpegKit Extended Flutter Example

This example application demonstrates the core features of the `ffmpeg_kit_extended_flutter` plugin, providing a practical implementation of media processing and playback on desktop and Web Wasm platforms.

## Getting Started

### Prerequisites

- **Flutter SDK**
- **C++ Compiler** (GCC/Clang) for native library linking
- **Platform**: Android, iOS, macOS, Windows or Linux

The package requires Flutter **3.47.0** or newer and Dart **3.12.0** or newer.

### 1. Install Dependencies

From the example directory, fetch the Flutter packages:

```bash
flutter pub get
```

The example keeps its FFmpegKit selection in the official Hooks configuration
under `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    ffmpeg_kit_extended_flutter:
      type: base
      gpl: false
      small: true
```

For a Pub Workspace, place this map in the workspace-root `pubspec.yaml`.
Legacy `ffmpeg_kit_extended_config` remains a bounded migration fallback, but
explicit `hooks.user_defines` values take precedence. Platform overrides accept
local paths or HTTP(S) URLs only; remote URLs are refreshed using full-URL cache
identity. Prefer versioned or content-addressed URLs.

### 2. Run the App

```bash
flutter run
```

For Web Wasm development, enable cross-origin isolation on Flutter's local
server:

```bash
flutter run -d web-server --cross-origin-isolation
```

### Web Wasm deployment

Build the example for WebAssembly with:

```bash
flutter clean
flutter build web --wasm
```

Note that the WebAssembly bundle has pthread support by default. For a `non-pthread` build, a custom build of the WebAssembly dependencies and bundle is required using <https://github.com/akashskypatel/ffmpeg-kit-builders>.

Custom Web/Wasm ZIPs or directories must contain exactly one runtime directory
with both `ffmpegkit.mjs` and `ffmpegkit.wasm`; split or ambiguous pairs are
rejected by the build hook.

When using a pthread-enabled Wasm bundle, the deployment server must return:

```http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Verify `window.crossOriginIsolated === true` in the browser.

## Features Demonstrated

- **FFmpeg Execution**: Asynchronous video conversion with real-time statistics and log tracking.
- **FFprobe Integration**: Extracting detailed metadata, stream information, and chapters from media files.
- **FFplay Playback**: A functional media player implementation showing playback control (seek, pause, resume) and duration tracking.
- **Session Management**: Monitoring active tasks and handling session lifecycles.

## Implementation Details

- Look at `lib/main.dart` for the UI implementation and callback handling.
- Review how `FFmpegKit.executeAsync` is used to prevent UI blocking during heavy transcodes.
- See the `MediaInformation` parsing logic to understand how to handle FFprobe results.
