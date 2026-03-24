
# FFmpegKit Extended Flutter Plugin CHANGELOG

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
- **Improvement**: Enhanced library loading with symbol verification
  - Runtime probing of critical FFmpeg symbols at initialization
  - Detailed logging for DLL/SO loading and symbol resolution
  - Graceful degradation for missing or outdated native libraries

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
