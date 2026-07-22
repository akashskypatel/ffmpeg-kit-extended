# FFmpegKit Extended React Native Example

This is the runnable Android/iOS example application for `ffmpeg-kit-extended`.
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

- `App.tsx` hosts the shared example UI on Android, iOS, and macOS.
- `src/ExamplePlatform.<platform>.ts` provides platform-specific file and runtime services.
- Native projects live under `android/`, `ios/`, and `macos/`.
- `src/ExampleApp.tsx` contains the shared behavior.

The current React Native binding package has native integration for Android and iOS, so those are the example host projects included here.

## FFplay rendering

The current TurboModule exposes FFplay execution and playback controls, but the React Native Fabric video surface is still deferred. The FFplay tab therefore shows decoded dimensions and playback controls while displaying a placeholder where the future `FFplayView` Fabric component will render video.

Audio playback does not require that video surface.

## File handling

The example uses:

- `react-native-file-access` for the application cache directory and filesystem operations.
- `@react-native-documents/picker` for importing user-selected media and copying it into app-local storage.
- `@react-native-community/slider` for FFplay seek and volume controls.

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

## Difference from the Flutter example

Flutter exposes truly synchronous convenience methods in its example. The React Native binding intentionally keeps FFmpeg/FFprobe execution Promise-based so native work does not block the JavaScript runtime. The "Awaited Version" buttons demonstrate the `execute()` alias and await its completion rather than performing a blocking native call.
