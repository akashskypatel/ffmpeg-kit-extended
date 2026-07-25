# FFmpegKit Extended React Native Example

This is the runnable Android/iOS/Apple tvOS/macOS/Windows example application for `ffmpeg-kit-extended`.
Its UI and scenarios are based on `flutter/example/lib/main.dart`.

## Covered scenarios

- FFmpeg test video/audio generation.
- FFmpeg version/help/custom commands.
- FFmpegKit build, bundle, license, component, and log-level introspection.
- Remote HLS/network stream recording with concurrent session tracking and cancellation.
- FFprobe version/custom commands and media-information inspection.
- Native document picking with a durable app-local copy before handing the path to FFmpeg/FFprobe.
- FFplay execution, pause/resume/stop/seek/position/duration/volume controls.
- MP4-to-AVI transcoding with progress derived from FFmpeg statistics and FFprobe duration.
- A persistent on-screen log pane similar to the Flutter example.

## Platform entry points

- `App.tsx` hosts the shared example UI, with `App.tv.tsx` providing the Apple tvOS entry point.
- `src/ExamplePlatform.<platform>.ts` provides platform-specific file and runtime services.
- Native projects live under `android/`, `ios/`, `appletvos/`, `macos/`, and `windows/`.
- `src/ExampleApp.tsx` contains the shared behavior.

The binding package has native integration for Android, iOS, Apple tvOS, macOS, and Windows.

## FFplay rendering

`FFplayView` provides the native playback surface. Android uses a native `TextureView`; iOS, Apple tvOS, and macOS present decoded frames through `AVSampleBufferDisplayLayer`; Windows presents desktop frame callbacks through a WinUI 3 Composition drawing surface. Audio playback continues through FFplay's native audio backend.

## File handling

The example uses:

- `react-native-file-access` for the application cache directory and filesystem operations.
- `@react-native-documents/picker` for importing user-selected media and copying it into app-local storage.

Generated and recorded files are stored below the platform cache directory in:

```text
ffmpeg_kit_extended_react_native_example/
```

This avoids broad storage permissions for the example's own generated files.

## Run Android

From this directory:

```sh
npm install
npm run android
```

The application must still receive the matching FFmpegKit Extended Android runtime (`libffmpegkit.so` and its dependencies), either from the package's future Gradle/Maven binary-resolution layer or from an AAR/native libraries supplied by the consuming app.

## Run iOS

```sh
npm install
cd ios
bundle install
bundle exec pod install
cd ..
npm run ios
```

The application must still embed the matching FFmpegKit Extended Apple runtime/XCFramework until the package's SPM binary-resolution layer is wired in.

## Run Apple tvOS

From the repository root on macOS:

```sh
./build.sh appletvos
./launch.sh appletvos
```

The tvOS host uses an isolated `react-native-tvos` runtime and resolves the FFmpegKit Extended release artifact using the `appletvos` platform name.

## Run Windows

From the repository root on Windows:

```sh
./build.sh windows
./launch.sh windows
```

The Windows host uses an isolated React Native for Windows runtime while loading the same `App.tsx` and `src/ExampleApp.tsx` used by the other platforms. `src/ExamplePlatform.windows.ts` delegates temporary-directory filesystem operations and native file picking to the example host. The build stages the default FFmpegKit Extended Windows runtime DLLs beside the executable.

## Difference from the Flutter example

Flutter exposes truly synchronous convenience methods in its example. The React Native binding intentionally keeps FFmpeg/FFprobe execution Promise-based so native work does not block the JavaScript runtime. The "Awaited Version" buttons demonstrate the `execute()` alias and await its completion rather than performing a blocking native call.
