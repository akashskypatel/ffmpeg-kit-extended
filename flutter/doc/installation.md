# Installation Guide

This guide describes how to install and configure FFmpeg Kit Extended Flutter in your project.

The current minimums are Flutter **3.47.0** and Dart **3.12.0**.

## 1. Add Dependency

1. Install the package:

    ```bash
    flutter pub add ffmpeg_kit_extended_flutter
    ```

2. Add the official Hooks `user_defines` section to the workspace-root (or
   standalone app-root) `pubspec.yaml`:

    ```yaml
    hooks:
      user_defines:
        ffmpeg_kit_extended_flutter:
          type: "base" # native pre-bundled builds: debug, base, full, audio, video, video_hw
          gpl: true # enable to include GPL libraries
          small: true # enable to use smaller builds
          # Preserve platform override keys under this same map.
          # windows: "path/to/ffmpeg-kit/libraries"
          # ios: "https://path/to/bundle.xcframework.zip"
    ```

    **Note**: Native libraries are now automatically downloaded and bundled during the build process using [Dart Hooks](https://dart.dev/tools/hooks). No manual configuration script is required.

    `hooks.user_defines` is the primary configuration path for native and Web
    builds. The legacy `ffmpeg_kit_extended_config` section remains a bounded
    migration fallback on every supported platform. If both sources are
    present, `hooks.user_defines` wins; this precedence is unchanged for
    platform override keys.
    Platform overrides may be local paths or HTTP(S) URLs. Only `http://` and
    `https://` are accepted for remote overrides; URL-like schemes such as
    `ftp://` fail explicitly. When the hook executes, remote overrides are
    refreshed and use the full URL as their cache identity. Remote URLs are not
    filesystem dependencies: URL changes invalidate through Hooks inputs, while
    a server-side change at an unchanged URL is not observed while Hooks skips
    the cached hook invocation. If the hook runs and bytes change, the matching
    extraction is invalidated; identical bytes may reuse it. Prefer versioned or
    content-addressed URLs for reproducible builds. Local override files remain
    filesystem dependencies.

    Native override archives must preserve the platform layout: Android
    requires `jni/<abi>/libffmpegkit.so`, Linux requires one runtime directory
    containing `libffmpegkit.so`, Windows requires one containing
    `libffmpegkit.dll`, and Apple archives must contain exactly one FFmpegKit
    `.xcframework`.

    The build hook validates architecture before downloading or extracting an
    artifact. Android supports `arm`, `arm64`, `ia32` (`x86`), and `x64`
    (`x86_64`); Apple supports `arm64` and `x64`; Linux and Windows support
    `arm64` and `x64`. Unsupported architectures fail with a diagnostic that
    names the requested architecture and supported set. The hook never maps an
    unsupported request to a different architecture.

    **Dart Pub Workspaces**: The package-config root `pubspec.yaml` takes priority. Otherwise, the build hook considers in-root package entries and accepts configuration only from package-graph roots with a normal dependency path to `ffmpeg_kit_extended_flutter`; arbitrary nested local/path packages and dev-only dependency paths are ignored. If a configured package candidate exists but `.dart_tool/package_graph.json` is unavailable, rerun `flutter pub get` or define the configuration in the root `pubspec.yaml`. If multiple dependent workspace roots could supply package-specific configuration, the build fails rather than guessing. If no applicable configuration remains, the default base LGPL small bundle is used. Dev-only dependencies are not used to choose an app configuration because Dart Hooks do not expose the active workspace package/build dependency mode to dependency hooks. Relative local override paths resolve from the pubspec that defines them, and referenced files are tracked by the Dart build hook so same-path content changes are picked up without `flutter clean`. Flutter Web keeps the same configuration precedence. App-scoped `hooks.user_defines` stage only into that app; shared workspace-root configuration resolves dependent Web app roots from the package graph before staging the selected runtime.

    For example, in the workspace root:

    ```yaml
    hooks:
      user_defines:
        ffmpeg_kit_extended_flutter:
          type: "video"
          gpl: true
    ```

3. Import the package in your Dart code:

    ```dart
    import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
    ```

**Important**: If you change the selected bundle configuration, rerun the build. Local override files are dependency-tracked, so replacing a local bundle is picked up without `flutter clean`.

## 2. Initialize the Plugin

Before using any API, call `FFmpegKitExtended.initialize()` once at application startup. This loads the native library and initializes required symbols.

```dart
import 'package:flutter/widgets.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();
  runApp(MyApp());
}
```

> **Important**: Any call to `FFmpegKit`, `FFprobeKit`, `FFplayKit`, or `FFmpegKitConfig` before `initialize()` completes will throw a `StateError`.

## 3. Platform Specific Configuration

### Android

1. Ensure your `minSdkVersion` is at least **21** in `android/app/build.gradle`.

2. Add necessary permissions to `android/app/src/main/AndroidManifest.xml` if you plan to read/write external storage:

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />
```

The published Android artifact contains `armeabi-v7a`, `arm64-v8a`, `x86`, and
`x86_64` layouts. Custom AAR overrides must provide the ABI requested by the
build; an unsupported architecture is rejected before extraction.

### iOS / macOS

1. Ensure your deployment target is at least **iOS 13.0** or **macOS 10.15**.

2. For iOS, you might need to add keys to `Info.plist` for file access:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app requires access to the photo library to process videos.</string>
<key>NSFileProviderUsageDescription</key>
<string>This app requires access to files to process videos.</string>
```

Apple builds request `arm64` or `x86_64` slices from the XCFramework. A
simulator `x86_64` build is valid only when that slice is present; the hook does
not relabel an `arm64` slice as `x86_64`.

### Windows

The Windows implementation uses `libffmpegkit.dll`. The published native
artifacts support `arm64` and `x86_64`; unsupported target architectures fail
before artifact download.

### Linux

Ensure you have basic `ffmpeg` runtime dependencies installed on your system if you are building from source. The published native artifacts support `arm64` and `x86_64`; unsupported target architectures fail before artifact download.

### WebAssembly Web

Build the Web target with Flutter Wasm:

```bash
flutter clean
flutter build web --wasm
```

Note that the WebAssembly bundle has pthread support by default. For a `non-pthread` build, a custom build of the WebAssembly dependencies and bundle is required using <https://github.com/akashskypatel/ffmpeg-kit-builders>.

If the selected Wasm bundle uses pthreads, the deployed site must return:

```http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Check `window.crossOriginIsolated` in the browser; it must be `true` for threaded Wasm execution.

The build hook resolves the selected Web runtime for every configuration and
stages `ffmpegkit.mjs`, `ffmpegkit.wasm`, the loader, callback bridge, and
callback runtime under `assets/packages/ffmpeg_kit_extended_flutter/wasm/`.
The same stable Flutter 3.47 path handles the default bundle, non-default bundle
selections, local archive/directory overrides, and HTTP(S) overrides; Dart
DataAssets are not required. Runtime files are staged into the consuming app's
source `web/` tree for development and `build/web/` for built output.

Custom Web/Wasm ZIPs or directories must contain exactly one coherent runtime
directory containing both `ffmpegkit.mjs` and `ffmpegkit.wasm`. The hook rejects
split files from different directories and ambiguous layouts with multiple
complete pairs.
Local Web overrides may be an archive or a directory; remote Web overrides
are HTTP(S) archive URLs. Native overrides keep their documented
platform-specific archive formats.

`debug` is supported for native prebuilt targets where available. The
automatic prebuilt Flutter Web debug artifact is not supported because the
published artifact is browser-incompatible. For Web debug/custom development,
provide an explicit `web`/`wasm` override containing one coherent
`ffmpegkit.mjs` + `ffmpegkit.wasm` pair.

## 4. Troubleshooting Installation

### Missing Binaries

If you encounter errors related to "Library not found", verify the
`hooks.user_defines.ffmpeg_kit_extended_flutter` configuration and ensure you
have an active internet connection during the first build so the hook can
download the artifacts. The legacy `ffmpeg_kit_extended_config` key is only a
compatibility fallback.

### FFIGEN Issues

The plugin uses `@Native` bindings generated by `ffigen`. If you see errors related to missing symbols, ensure you are using a recent version of the Flutter SDK that supports native assets.

### Permissions

If FFmpeg fails with "Permission denied", double-check that your app has the necessary storage permissions and that you are using absolute paths for files.
