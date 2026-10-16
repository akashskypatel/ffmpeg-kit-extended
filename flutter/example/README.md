# FFmpegKit Extended Flutter Example

This example application demonstrates the core features of the `ffmpeg_kit_extended_flutter` plugin, providing a practical implementation of media processing and playback on desktop and Web Wasm platforms.

## Getting Started

On Web, open the **Stream** tab for direct HTTP(S) and HLS input. **Probe** reads
metadata; **Play** uses the FFplay tab's video surface and SDL audio; **Record
15 s** writes a bounded Matroska file in browser memory. After completion use
**Probe Recording** and **Download Recording**. **Stop** requests cancellation;
wait for the operation to settle before starting another. Download or delete
recordings before closing the page. See the [copyable commands and Web limits](../doc/guides/advanced.md#web-remote-urls-direct-http-and-hls).

Use the exact local runtime hashes and cross-origin isolation headers in the
[Web bridge guide](../doc/web-native-bridge.md). ABI `0.11.2` is required but does
not distinguish older builds with the same ABI; verified asset hashes are also
required. HTTPS pages require HTTPS media and the media server's CORS grant.
RTMP, RTSP, raw sockets and DRM are unsupported. Codec support follows the
selected bundle; do not assume all HLS codecs or encryption modes work.

For the complete local interactive test sequence, see
[`flutter/TEST.md`](../TEST.md) and
[`interactive-tests/marionette.md`](interactive-tests/marionette.md). Those
guides use the configured local ABI/runtime and do not substitute hosted or
historical artifacts.

### Prerequisites

- **Flutter SDK**
- **C++ Compiler** (GCC/Clang) for native library linking
- **Platform**: Android, iOS, macOS, Windows, Linux, or Flutter Web/Wasm

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

The repository's executable local Wasm smoke target uses the current local
builder archive when the ABI is unpublished. Run it from this directory after
setting the `web`/`wasm` override to the local artifact path in `pubspec.yaml`.
That override takes precedence over `type`, `gpl`, and `small` and fails if the
artifact cannot be resolved, without falling back to a published bundle. A
direct HTTP(S) artifact URL is also supported when a hosted override is wanted:

```bash
flutter build web --wasm --release --target lib/web_runtime_smoke.dart
node web_static_server.mjs build/web 8080
node web_runtime_smoke.mjs http://127.0.0.1:8080 wasm
```

The fixture staging tests in the package are synthetic archive-selection tests;
the served smoke target is the runtime check for the actual Wasm module,
FFmpeg, FFprobe, and callback path.

## Features Demonstrated

- **FFmpeg Execution**: Asynchronous video conversion with real-time statistics and log tracking.
- **FFprobe Integration**: Extracting detailed metadata, stream information, and chapters from media files.
- **FFplay Playback**: A functional media player implementation showing playback control (seek, pause, resume) and duration tracking.
- **Web/Wasm file transfer**: Pick a browser media file into temporary `/tmp/` Wasm storage, probe/transcode/play the selected file, and download generated MP4/WAV/AVI output.
- **Streaming support**: Remote HLS/network stream recording is available on supported native targets. Web/Wasm does not support network stream input or recording, including RTMP/RTMPE; its Stream tab explains the limitation and exposes no stream controls.
- **Session Management**: Monitoring active tasks and handling session lifecycles.

Imported files and generated media remain in browser memory until removed or
the Web app is reloaded. Large files can exhaust browser memory. The
`FFmpegKitWebFiles` API is Web/Wasm-only and requires
`FFmpegKitExtended.initialize()`. The selected Wasm runtime must export `FS`
with `writeFile`, `readFile`, `unlink`, and `stat` in
`EXPORTED_RUNTIME_METHODS` for file transfer to work.

The Web bridge refreshes `HEAPU8`, `HEAPU32`, and `HEAPF32` after shared Wasm
memory growth. Compatible writable Emscripten-owned heap properties remain
owned by the runtime; fallback accessors accept refreshed views and reject
incompatible non-configurable properties. The build hook stages
`ffmpegkit_heap_runtime.mjs` alongside the bridge and its callback/loader
modules.

When an imported file is replaced, built-in jobs keep the retired path while
their session still uses it. Custom FFprobe and FFplay hold a conservative Web
media-operation lease from before asynchronous startup through terminal
completion, so retired imports remain available even when the command's input
path cannot be safely inferred. FFplay position-stream completion also runs a
cleanup pass. The lease count decreases only once, while each terminal signal
retries cleanup in case an earlier callback arrived before the session state
became terminal. Overlapping custom sessions hold the retired files until the
last lease ends; failed startup releases its lease, while a running job is
released by its terminal callback. Large inputs may therefore remain in
memory longer than a single session; reloading the Web app clears the Wasm
filesystem.

## Implementation Details

- Look at `lib/main.dart` for the UI implementation and callback handling.
- Review how `FFmpegKit.executeAsync` is used to prevent UI blocking during heavy transcodes.
- See the `MediaInformation` parsing logic to understand how to handle FFprobe results.
