# React Native FFmpegKit Extended bindings

This package is the React Native binding layer for the repository's `libffmpegkit` C API (`ffmpegkit_wrapper.h`). It mirrors the public structure already used by the Flutter package under `flutter/lib`, while adapting execution and callbacks to React Native's JavaScript runtime.

## Architecture

The binding has three layers:

1. **TypeScript API** (`src/`)
   - `FFmpegKit`, `FFprobeKit`, and `FFplayKit`
   - `FFmpegKitExtended` and `FFmpegKitConfig`
   - `Session`, `FFmpegSession`, `FFprobeSession`, `FFplaySession`, and `MediaInformationSession`
   - `SessionQueueManager` with the same default maximum concurrency of 8 as the Flutter implementation
   - `Log`, `Statistics`, `MediaInformation`, `StreamInformation`, and `ChapterInformation`
2. **React Native TurboModule** (`src/NativeFFmpegKitExtended.ts`, `cpp/FFmpegKitExtendedImpl.*`)
   - A typed Codegen boundary.
   - Only scalar values and JSON strings cross the JavaScript/native boundary.
3. **libffmpegkit adapter** (`cpp/FFmpegKitDynamicApi.*`)
   - Resolves `ffmpegkit_wrapper.h` exports with `dlsym`.
   - Does not expose opaque native handles to JavaScript.
   - Temporary session/media/statistics handles are released with `ffmpeg_kit_handle_release`.
   - Native strings allocated by the wrapper are released with `ffmpeg_kit_free`.

The adapter deliberately does not include `ffmpegkit_wrapper.h`. The source snapshot does not contain `ffmpeg_tls.h`, which that header includes, and the React Native bridge only needs the stable exported C ABI. Resolving the exported symbols directly also matches the runtime-loading approach used by the Flutter Apple targets.

## Execution model

React Native command execution is asynchronous. `execute()` and `executeAsync()` both return a `Promise` that resolves when the session finishes.

The native session starts asynchronously, while the TypeScript `Session` polls buffered native logs, statistics, and state. This keeps C callbacks and JavaScript callback lifetime management out of the C ABI boundary while preserving per-session completion/log/statistics callbacks.

```ts
import {
  FFmpegKitExtended,
  FFmpegKit,
  ReturnCode,
} from 'react-native-ffmpeg-kit-extended';

FFmpegKitExtended.initialize();

const session = await FFmpegKit.executeAsync(
  '-i input.mp4 -c:v libx264 output.mp4',
  {
    logCallback: log => console.log(log.message),
    statisticsCallback: stats => console.log(stats.time, stats.speed),
  },
);

if (session.getReturnCode() === ReturnCode.Success) {
  console.log('Completed');
}
```

Media information follows the same abstraction as Flutter:

```ts
import {FFprobeKit} from 'react-native-ffmpeg-kit-extended';

const session = await FFprobeKit.getMediaInformation('/path/to/video.mp4');
const media = session.getMediaInformation();

console.log(media?.format);
console.log(media?.streams);
```

FFplay video and audio playback are supported on Android. Mount `FFplayView` before starting video playback so its native `TextureView` can bind an Android `Surface` to FFplay. Audio-only playback does not require a video surface.

```tsx
import {FFplayKit, FFplayView} from 'react-native-ffmpeg-kit-extended';

export function Player() {
  const play = async () => {
    const session = FFplayKit.createSession(
      '-hide_banner -autoexit -i "/path/to/video.mp4"',
    );
    await session.executeAsync();
  };

  return (
    <>
      <FFplayView style={{width: '100%', aspectRatio: 16 / 9}} />
      {/* Call play() after the view is mounted. */}
    </>
  );
}
```

Playback controls remain session based:

```ts
session.pause();
session.seek(10);
session.resume();
session.setVolume(0.5);
```

## Native runtime packaging

The TurboModule does **not** compile or statically link FFmpegKit itself. The application must package the same `libffmpegkit` runtime produced by this repository.

### Android

The Android library depends on the published FFmpegKit Extended AAR and defaults to:

```text
io.github.akashskypatel.ffmpegkit:bundle-base-shared-small-lgpl:0.10.5
```

The artifact and version can be overridden with Gradle properties:

```properties
ffmpegKitAndroidArtifact=bundle-video-shared-small-lgpl
ffmpegKitVersion=0.10.5
```

The C++ TurboModule loads `libffmpegkit.so` with `dlopen`. `FFplayView` uses a native Android `TextureView`, converts its `Surface` to FFplay's `ANativeWindow` through the FFmpegKit JNI bridge, and clears the surface when the React Native view is destroyed. Audio output is handled directly by FFplay/SDL and works for both video and audio-only sessions.

### iOS and Apple tvOS

Embed the matching FFmpegKit Extended framework/dynamic library in the application. The bridge resolves symbols from `RTLD_DEFAULT`, with framework/dylib fallbacks, so no direct link against `ffmpegkit_wrapper.h` is required by this pod.

After installing the package, run CocoaPods normally. Apple tvOS uses the `appletvos` platform artifact and the podspec automatically selects `vendor/appletvos/ffmpegkit.xcframework` for tvOS targets.

```sh
cd ios
pod install
```

## Flutter abstraction mapping

| Flutter | React Native |
| --- | --- |
| `FFmpegKit` | `FFmpegKit` |
| `FFprobeKit` | `FFprobeKit` |
| `FFplayKit` | `FFplayKit` |
| `FFmpegKitExtended` | `FFmpegKitExtended` |
| `FFmpegKitConfig` | `FFmpegKitConfig` |
| `Session` | `Session` |
| `FFmpegSession` | `FFmpegSession` |
| `FFprobeSession` | `FFprobeSession` |
| `FFplaySession` | `FFplaySession` |
| `MediaInformationSession` | `MediaInformationSession` |
| `SessionQueueManager` | `SessionQueueManager` |
| `Log` | `Log` |
| `Statistics` | `Statistics` |
| `MediaInformation` | `MediaInformation` |
| `StreamInformation` | `StreamInformation` |
| `ChapterInformation` | `ChapterInformation` |

## Current coverage

Implemented native coverage includes:

- FFmpeg, FFprobe, FFplay, and media-information session creation/execution/cancellation.
- Session state, return code, timing, command, output, logs, failure trace, and history.
- Incremental log and FFmpeg statistics retrieval.
- Media, stream, and chapter information.
- FFplay start/pause/resume/stop/seek/position/duration/video dimensions/play state/volume.
- Log level, redirection, fonts, environment variables, signal ignore, and audio output configuration.
- FFmpeg/package/build metadata and registered component lists.
- Session-history sizing/clearing, FFmpeg pipes, messages-in-transmit, and per-session debug logs.
- JavaScript argument parsing/stringification and queue concurrency controls.

## FFplay rendering

Android video rendering is implemented by `FFplayView` using a native `TextureView`. iOS, Apple tvOS, and macOS use the decoded-frame callback path and present frames with `AVSampleBufferDisplayLayer`. Audio playback uses FFplay's native audio backend and does not require a video surface.

Global native callback registration is also not exposed because per-session callbacks are dispatched by the TypeScript polling layer. This avoids duplicate callback paths and cross-thread JavaScript invocation.

## Validation

The binding source has been checked for:

- C++20 syntax with `-Wall -Wextra -Werror` for `FFmpegKitDynamicApi.cpp`.
- Every dynamically resolved symbol referenced by the adapter exists in the provided `ffmpegkit_wrapper.h` snapshot.
- TypeScript strict-mode type checking using temporary React Native type shims for the TurboModule imports.
- One-to-one method-name coverage between `NativeFFmpegKitExtended.ts` and `FFmpegKitExtendedImpl.h`.

Native example builds resolve the matching FFmpegKit Extended platform artifacts through the repository build scripts and CocoaPods integration.

## Example applications

The React Native example under `example/` contains Android, iOS, Apple tvOS, and macOS host projects. It ports the workflows from `flutter/example/lib/main.dart`: FFmpeg generation/custom commands, remote recording and cancellation, FFprobe media information, FFplay controls, transcoding statistics, log-level controls, build introspection, file picking, and an on-screen log console.

The unified React Native example contains Android, iOS, Apple tvOS, and macOS native hosts under `example/`. Apple tvOS uses an isolated `react-native-tvos` runtime, and macOS uses the React Native macOS toolchain to exercise the same C++ TurboModule and the native `FFplayView` implementation with FFmpeg/FFprobe execution, generated video/audio playback, pause/resume/stop/seek/volume controls, aspect-ratio-preserving video output, and a resizable log pane.

The repository scripts prepare the matching native binary, Codegen output, CocoaPods dependencies, and host application:

```sh
./build.sh android
./build.sh ios
./build.sh appletvos
./build.sh macos

./launch.sh android
./launch.sh ios
./launch.sh appletvos
./launch.sh macos
```

`./launch.sh appletvos` and `./launch.sh macos` open the matching platform-specific Metro server in a visible Terminal window. Because the Apple tvOS and macOS examples use different React Native runtimes, the launcher will stop a Metro process owned by another runtime in this repository before switching platforms. An unrelated process already using port 8081 is left untouched and reported as an error instead of serving an incompatible JavaScript bundle.

On Android, `FFplayView` supplies the native Android surface used by FFplay. On iOS, Apple tvOS, and macOS, `FFplayView` receives FFplay's decoded frame callback and presents frames through `AVSampleBufferDisplayLayer`. Audio playback continues through FFplay's native SDL audio backend.
