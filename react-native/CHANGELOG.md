# FFmpegKit Extended React Native Changelog

## Version 1.0.0

### Added
- **React Native Web / WebAssembly support:** Added browser execution of FFmpeg, FFprobe, and FFplay commands using an Emscripten/Wasm backend with shared session, callback, and configuration APIs.
- **Web video playback:** Added canvas-based `FFplayView` rendering for browser playback, with decoded video frame delivery, playback lifecycle tracking, and resource cleanup.
- **Web media streaming:** Added asynchronous FFmpeg, FFprobe, and FFplay support for HTTP(S) and HLS inputs when using compatible streaming-enabled WebAssembly bundles.
- **Web filesystem API:** Added `FFmpegKitWebFiles` with `writeFile()`, `readFile()`, `deleteFile()`, and `exists()` for temporary files in the browser's Wasm filesystem, exported through `ffmpeg-kit-extended/web-files`.
- **Web runtime configuration:** Added WebAssembly asset loading, configurable `assetBaseUrl`, browser-specific package exports, and runtime asset preparation through the `prepare-web` command.
- **Platform-specific runtime packaging:** Expanded artifact selection and packaging support for WebAssembly and Windows, including configurable bundle overrides and local runtime preparation.

### Improved
- **Session lifecycle management:** Improved asynchronous execution, cancellation, completion observation, session restoration, and native handle ownership.
- **Session queue management:** Improved cancellation of created, queued, starting, and running sessions, with more reliable cleanup and propagation of native operation errors.
- **Callback reliability:** Improved session completion, log, and statistics callback registration, event delivery, ordering, and cleanup. Added structured native log event handling with retained-history reconciliation.
- **Session history:** Improved retained-session retrieval, restored-session observation, callback handling, and cleanup of abandoned or completed sessions.
- **FFprobe integration:** Improved media-information execution, session lifecycle handling, and retrieval of structured media information.
- **FFplay playback lifecycle:** Improved playback startup, cancellation, session tracking, and playback control ownership. Global playback control now tracks unsettled executions more reliably.
- **Cross-platform FFplay rendering:** Improved native video frame delivery, surface ownership, and texture lifecycle management across Android, iOS, macOS, Windows, and Apple TV platforms.
- **Windows integration:** Improved packaged native library loading, runtime discovery, native error propagation, and example application build support.
- **Native bridge reliability:** Improved error handling and lifecycle coordination across TurboModule, C++, Java/Kotlin, Objective-C++, Windows, and Web backends.
- **Documentation and examples:** Expanded generated TypeScript API references, installation and platform guidance, WebAssembly usage documentation, and FFmpeg/FFprobe/FFplay example scenarios.

### Breaking Changes
- **Asynchronous initialization:** `FFmpegKitExtended.initialize()` now returns `Promise<void>` and must be awaited before invoking package APIs. Initialization failures can be retried.
- **Asynchronous cancellation:** Session cancellation methods, including `session.cancel()`, `FFmpegKit.cancel()`, `FFprobeKit.cancel()`, `FFplayKit.cancel()`, `FFmpegKitExtended.cancelSession()`, and `cancelAllSessions()`, now return Promises that callers should await.
- **Asynchronous configuration operations:** Mutating APIs such as log configuration, environment settings, session history configuration, debug-log management, and `clearSessions()` now return Promises.
- **Web synchronous API limitations:** On Web, synchronous video-stream detection does not support network URLs. Use asynchronous FFprobe media-information APIs for remote media.
- **Web runtime requirements:** WebAssembly execution requires compatible runtime assets and browser cross-origin isolation with `SharedArrayBuffer` support.

## Version 0.6.2

- Preserve FFmpeg, FFprobe, and FFplay session arguments as argv all the way into their embedded CLI runtimes to fix argument parsing bug exposed by quotes in commands.
- Fix `debug` build for macOS, iOS, Windows and Linux.

## Version 0.6.1

- Update documentation

## Version 0.6.0

- Upgrade FFmpeg version to v9.0.1
- Fix media-information probing for paths containing whitespace or literal quote characters by passing the input path as a native argv entry.
- Preserve pre-tokenized FFmpeg and FFplay arguments across the TurboModule boundary instead of serializing them back into command strings.
- Align command-string parsing with native compatibility semantics, including empty arguments and Windows/UNC backslash preservation.

## Version 0.5.13

- Update documentation

## Version 0.5.12

- Update documentation

## Version 0.5.11

- Initial release
