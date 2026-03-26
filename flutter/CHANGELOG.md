# FFmpegKit Extended Flutter Plugin CHANGELOG

## Version 0.3.1

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
