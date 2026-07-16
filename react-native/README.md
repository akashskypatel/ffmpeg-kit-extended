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
} from 'ffmpeg-kit-extended';

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
import {FFprobeKit} from 'ffmpeg-kit-extended';

const session = await FFprobeKit.getMediaInformation('/path/to/video.mp4');
const media = session.getMediaInformation();

console.log(media?.format);
console.log(media?.streams);
```

FFplay session controls are also exposed:

```ts
import {FFplayKit} from 'ffmpeg-kit-extended';

const session = FFplayKit.createSession('-i /path/to/video.mp4');
void session.executeAsync();

session.pause();
session.seek(10);
session.resume();
```

## Native runtime packaging

The TurboModule does **not** compile or statically link FFmpegKit itself. The application must package the same `libffmpegkit` runtime produced by this repository.

### Android

Package `libffmpegkit.so` and its native dependencies for each target ABI so Android can load them at runtime. A conventional layout is:

```text
android/app/src/main/jniLibs/
  arm64-v8a/libffmpegkit.so
  armeabi-v7a/libffmpegkit.so
  x86_64/libffmpegkit.so
```

A consuming AAR may provide the same libraries instead. The bridge loads `libffmpegkit.so` with `dlopen`.

### iOS

Embed the matching FFmpegKit Extended framework/dynamic library in the application. The bridge resolves symbols from `RTLD_DEFAULT`, with framework/dylib fallbacks, so no direct link against `ffmpegkit_wrapper.h` is required by this pod.

After installing the package, run CocoaPods normally:

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

## Intentionally deferred

The Flutter package has rendering-specific abstractions that need React Native UI components rather than plain TurboModule methods:

- Flutter `FFplayAndroidSurface` / `FFplayView` equivalent for Android `ANativeWindow` binding.
- Desktop frame callback/texture rendering.
- Any future iOS FFplay rendering surface integration.

Those should be implemented as a Fabric Native Component that owns the platform view/surface and attaches it to an `FFplaySession`. The command/session bindings in this package can remain unchanged.

Global native callback registration is also not exposed because per-session callbacks are dispatched by the TypeScript polling layer. This avoids duplicate callback paths and cross-thread JavaScript invocation.

## Validation

The binding source has been checked for:

- C++20 syntax with `-Wall -Wextra -Werror` for `FFmpegKitDynamicApi.cpp`.
- Every dynamically resolved symbol referenced by the adapter exists in the provided `ffmpegkit_wrapper.h` snapshot.
- TypeScript strict-mode type checking using temporary React Native type shims for the TurboModule imports.
- One-to-one method-name coverage between `NativeFFmpegKitExtended.ts` and `FFmpegKitExtendedImpl.h`.

A full Android/iOS application link test still requires the actual platform `libffmpegkit` binaries, which are not included in this source snapshot.

## Example application

A React Native 0.86 example application is included under `example/` with native Android and iOS host projects. It ports the workflows from `flutter/example/lib/main.dart`: FFmpeg generation/custom commands, remote recording and cancellation, FFprobe media information, FFplay controls, transcoding statistics, log-level controls, build introspection, file picking, and an on-screen log console.

```sh
cd example
npm install
npm run android
# or, after CocoaPods setup:
npm run ios
```

The FFplay tab currently uses a video placeholder because the TurboModule binding does not yet include the deferred Fabric `FFplayView` surface component. Playback/session controls are still exercised by the example.
