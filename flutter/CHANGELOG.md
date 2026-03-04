
# FFmpegKit Extended Flutter Plugin CHANGELOG

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
