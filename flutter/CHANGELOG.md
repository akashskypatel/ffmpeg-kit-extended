
# FFmpegKit Extended Flutter Plugin CHANGELOG

## Version 0.3.0

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

## Version 0.2.0

- Feature: Added Android support.
- Fix: Fixed lgpl package resolution.

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
