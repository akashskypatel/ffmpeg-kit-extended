# FFmpegKit Extended React Native Changelog

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