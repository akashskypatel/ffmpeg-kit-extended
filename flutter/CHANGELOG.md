# FFmpegKit Extended Flutter Plugin CHANGELOG

## Version 0.5.7

- **iOS**: Fix iOS-Simulator vs device build hook slice selection.

## Version 0.5.6

- **Android**: Fix Android app-bundle build from scratch. FFplayKitAndroid is integrated into native code and no longer needs to be added as a separate dependency via classes.jar staging.

## Version 0.5.5

- Cleanup unnecessary imports

## Version 0.5.4

- Export chapter and stream information
- Add build hook guard when not building code assets
- Update binary version to 0.10.3 to fix statistics callback issues

## Version 0.5.3

- Updates minimum supported SDK version to Flutter 3.44/Dart 3.12.
- Migrates Android Gradle configuration for built-in Kotlin (AGP 9+) with an AGP 8 fallback.
- Removes Java 17 toolchain requirement that blocked builds with only Java 21 installed.

## Version 0.5.2

- Fix Apple Swift Package Manager configuration

## Version 0.5.1

- Update `hooks` package to latest version: 2.0.0

## Version 0.5.0

- **Breaking changes:**
  - FFmpeg, FFprobe, and FFplay log delivery now drains through a Dart-managed session buffer instead of the previous per-line callback dispatch path. Code that implicitly relied on one callback invocation per native log notification should migrate to `logBatchStream` / `logStream` or tolerate batched delivery timing.
  - `FFprobeKit.executeAsync`, `FFprobeKit.createSession`, `FFplayKit.executeAsync`, and `FFplayKit.createSession` now accept `onLog`, and those callbacks follow the same buffered drain semantics as direct session listeners. Existing consumers may observe different callback grouping and timing under heavy log output.
  - Added `timeElapsed`, `dupFrames`, `dropFrames`, and `transcodingProgress` fields to `Statistics` class for enhanced statistics information

- Updated statistics callback signatures to include elapsed time parameter
- Added `ffmpeg_kit_statistics_get_time_elapsed` native binding
- Enhanced test callbacks to support new timeElapsed parameter
- Refactored FFmpeg log delivery to a Dart-managed stream over the existing native session log buffer instead of relying on per-line callback dispatch.
- Added `logBatchStream` and `logStream` to `FFmpegSession`, `FFprobeSession`, and `FFplaySession` for buffered and per-line log consumption.
- Extended `FFprobeSession` and `FFplaySession` with session-level log callbacks and wired `FFprobeKit` / `FFplayKit` convenience APIs to accept `onLog`.
- Unified log draining across FFmpeg, FFprobe, FFplay, and MediaInformation sessions through the shared Dart callback manager while preserving the existing native buffering model.
- Reduced example-app UI stalls during remote recording scenarios by batching log rendering and file writes, throttling stats-driven repainting, and avoiding high-volume debug log mirroring into the visible console.
- Fix Windows and Android stability issues.

## Version 0.4.6

- Fix binary version

## Version 0.4.5

- Fix build hook to correctly download remote files from URL.

## Version 0.4.4

- Fix build hook to skip SHA verification when override path is provided.

## Version 0.4.3

- Added release file SHA verification for added security
- Updated installation instructions to clarify bundle config changes and re-build requirements

## Version 0.4.2

- Change default package to base-lgpl-small if no configuration is provided

## Version 0.4.1

- Added Swift Package Manager support for iOS and macOS

## Version 0.4.0

- Added iOS and macOS support
- Updated FFplay playback to use OpenGL for Linux, and direct frame rendering instead of SDL passthrough.

## Version 0.3.4

- Updated README with demo link

## Version 0.3.0

- **Feature**: Complete video playback support with unified cross-platform surface API
  - New `FFplaySurface` class providing platform-agnostic video output
  - Android support via `FFplayAndroidSurface` with native Surface binding
  - Desktop support via `FFplayDesktopTexture` for Linux/Windows frame delivery
  - Real-time video dimension tracking via `videoSizeStream`
  - Enhanced position tracking with `positionStream` for playback progress
- **Feature**: Native C++ plugins for desktop video rendering
  - Linux plugin with pixel buffer texture support and frame callback handling
  - Windows plugin with double-buffered texture delivery and runtime symbol resolution
  - Thread-safe frame delivery from FFplay decoder to Flutter render thread
- **Feature**: FFmpegKit packages introspection API
  - Runtime detection of available FFmpeg packages and capabilities
  - Bundle type, version, and build configuration access
  - License detection (GPL, non-free enabled status)
  - Complete component registration queries:
    - Registered codecs, encoders, and decoders
    - Registered muxers, demuxers, and protocols
    - Registered filters and bitstream filters
- **Feature**: Enhanced audio control and test content generation
  - Volume control functionality for media playback
  - Improved test video generation with audio track support
- **Enhancement**: Extended FFmpeg bindings for video functionality
  - Video dimension accessors: `ffplay_kit_session_get_video_width/height`
  - Android surface binding: `ffplay_kit_set_android_surface_ptr`
  - Desktop frame callbacks: `ffplay_kit_register/unregister_frame_callback`
  - Build stamp verification: `ffmpeg_kit_get_build_stamp`
- **Enhancement**: Android platform integration
  - AAR extraction improvements with classes.jar handling for library modules
  - Native method channel for surface lifecycle management
  - ANativeWindow pointer management for SDL2 video output
- **Enhancement**: Example application with video playback UI
  - Real-time video display with proper aspect ratio handling
  - Playback controls with position slider and state indicators
  - Audio-only content handling with graceful UI fallback
- **Enhancement**: Adaptive position streaming and performance optimization
  - Hysteresis-based emit rate adjustment (60fps ceiling, 10fps floor)
  - Optimistic position updates on seek operations
  - Local stopwatch interpolation for smooth position tracking
  - Event loop performance improvements
- **Improvement**: Enhanced library loading with symbol verification
  - Runtime probing of critical FFmpeg symbols at initialization
  - Detailed logging for DLL/SO loading and symbol resolution
  - Graceful degradation for missing or outdated native libraries
- **Fix**: Critical thread safety and memory management improvements
  - Windows desktop texture double-buffering for stable pixel data delivery
  - Android native window pointer storage and proper cleanup on plugin detachment
  - Texture release validation to prevent invalid texture ID operations
  - Frame callback race condition prevention during texture cleanup
  - Stream controller lifecycle management to prevent closure conflicts
- **Fix**: Robust numerical handling for media playback
  - NaN and infinite value guards in FFplaySession seek operations
  - Position and duration validation to prevent mathematical errors
  - Statistics time conversion fixes (removed incorrect 1000x multiplication)
- **Fix**: Platform-specific build and runtime issues
  - Linux build API usage corrections
  - Windows runtime symbol resolution improvements
  - Frame callback guard fixes to prevent blocking initial video frames
- **Documentation**: Comprehensive video playback guides
  - Complete video playback documentation with platform-specific implementations
  - Detailed video surface API reference with usage examples
  - Enhanced quick-start guide with video player integration
  - Platform support matrix and real-time streaming examples

## Version 0.2.1

- Misc fixes to session handeling on error.

## Version 0.2.0

- Feature: Added Android support.
- Fix: Fixed lgpl package resolution.
- Feature: Automatic version detection from GitHub API for Flutter configure script with fallback to pubspec version
- Feature: New `ffmpeg_kit_initialize()` binding for proper library initialization
- Feature: Enhanced FFI bindings generation for improved native integration
- Feature: Comprehensive MediaInformationSession implementation
- Feature: Documentation comments to native callback typedefs
- Improvement: Refactor core session classes (FFmpegSession, FFplaySession, FFprobeSession, MediaInformationSession) for better async handling and state management
- Improvement: Simplify FFplayKit callback wrapper and session management
- Improvement: Improve callback management and error handling across all session types
- Improvement: Update build configuration with CMake external native build support for Android
- Improvement: Update example application with enhanced functionality
- Fix: Memory safety issues - fix unsafe handle releases in callbacks that could cause use-after-free bugs
- Fix: Replace manual handle release calls with NativeFinalizer-based cleanup
- Fix: Improve build configuration and library bundling across platforms (Android, Linux, Windows)
- Fix: Add WSL path handling in URI detection for cross-platform development
- Fix: Remove redundant await in executeAsync

## Version 0.1.2

- Feature: Add `flutter_lints` and improve static analysis configuration
- Feature: Add `logging` package for enhanced configuration script output
- Improvement: Refactor `configure.dart` to use `dart:developer.log` and `logging` package
- Improvement: Deprecate `streaming` bundle type in favor of `video` (streaming is now included in all bundles)
- Documentation: Update `installation.md` with modern installation steps and options
- Testing: Suppress verbose print statements in integration tests during non-debug modes
- Chore: Add LGPL license headers to configuration scripts

- Refactor: Improve configuration script logging syntax
- Fix: Disable unsupported mobile and macOS platforms in pubspec.yaml

## Version 0.1.0

- Feature release based on native FFmpeg v8.0 API
- Implemented windows support
- Updated linux support
- Complete refactoring of the codebase to ffi instead of native implementation

## Version 0.0.0

- Repository created
