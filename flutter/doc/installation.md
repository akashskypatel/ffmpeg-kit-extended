# Installation Guide

This guide describes how to install and configure FFmpeg Kit Extended Flutter in your project.

## 1. Add Dependency

1. Install the package:

    ```bash
    flutter pub add ffmpeg_kit_extended_flutter
    ```

2. Add the dependency to your `pubspec.yaml` then add `ffmpeg_kit_extended_config` section to your `pubspec.yaml`:

    ```yaml
    dependencies:
      ffmpeg_kit_extended_flutter: ^0.1.0

    ffmpeg_kit_extended_config:
      version: "0.8.2" # version of the pre-bundled libffmpegkit libraries released at https://github.com/akashskypatel/ffmpeg-kit-builders/releases
      type: "base" # pre-bundled builds: debug, base, full, audio, video, video_hw
      gpl: true # enable to include GPL libraries
      small: true # enable to use smaller builds
      # == OR ==
      # -------------------------------------------------------------
      # You can specify remote or local path to libffmpegkit libraries for each platform
      # This allows you to deploy custom builds of libffmpegkit.
      # See: https://github.com/akashskypatel/ffmpeg-kit-builders
      # Note: This will override all above options.
      # -------------------------------------------------------------
      # windows: "path/to/ffmpeg-kit/libraries"
      # linux: "https://path/to/ffmpeg-kit/libraries"
    ```

3. Run `dart run ffmpeg_kit_extended_flutter:configure` to generate the native libraries.

    ```bash
    dart run ffmpeg_kit_extended_flutter:configure
    ```

    **Configure Options**
    - `--help`: Show this help message.
    - `--platform=<platform1,platform2>`: Specify platforms to configure (e.g., `windows,linux`).
    - `--verbose`: Enable verbose output.
    - `--app-root=<path>`: Specify the path to the app root.

4. Import the package in your Dart code:

    ```dart
    import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
    ```

## 2. Platform Specific Configuration

### Android

1. Ensure your `minSdkVersion` is at least **21** in `android/app/build.gradle`.

2. Add necessary permissions to `android/app/src/main/AndroidManifest.xml` if you plan to read/write external storage:

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS / macOS

1. Ensure your deployment target is at least **iOS 12.1** or **macOS 10.13**.

2. For iOS, you might need to add keys to `Info.plist` for file access:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app requires access to the photo library to process videos.</string>
<key>NSFileProviderUsageDescription</key>
<string>This app requires access to files to process videos.</string>
```

### Windows

The Windows implementation uses `libffmpegkit` compiled with MinGW. Ensure your environment supports running compiled C binaries. No specific configuration is usually required as the binaries are bundled with the plugin.

### Linux

Ensure you have `ffmpeg` dependencies installed if you are building from source or using specific features that rely on system libraries (though the plugin aims to be self-contained).

## 3. Configuration Script

FFmpeg Kit Extended Flutter uses a `configure.dart` script to manage native binaries. In some environments, you may need to run this manually if the automatic download fails:

```bash
dart run ffmpeg_kit_extended_flutter:configure
```

This script handles:

- Downloading the correct native binaries for your platform.
- Generating Dart bindings using `ffigen`.
- Setting up the native build environment.

## 4. Troubleshooting Installation

### Missing Binaries

If you encounter errors related to "Library not found" or "Missing symbol", try running the configuration script manually:

```bash
flutter pub run ffmpeg_kit_extended_flutter:configure
```

### FFIGEN Issues

The plugin generates bindings at build time. If you see errors related to `Pointer<Void>` or missing FFI functions, ensure you have `llvm` installed on your system as it's required by `ffigen`.

### Permissions

If FFmpeg fails with "Permission denied", double-check that your app has the necessary storage permissions and that you are using absolute paths for files.
