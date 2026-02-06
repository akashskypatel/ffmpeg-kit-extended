<center>

[![Stars](https://img.shields.io/github/stars/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/stargazers) [![Forks](https://img.shields.io/github/forks/akashskypatel/ffmpeg-kit-extended?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/fork) [![Downloads](https://img.shields.io/github/downloads/akashskypatel/ffmpeg-kit-extended/total?style=flat-square&color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/releases) [![GitHub release](https://img.shields.io/github/v/release/akashskypatel/ffmpeg-kit-extended?color=144DB3)](https://github.com/akashskypatel/ffmpeg-kit-extended/releases) [![License](https://img.shields.io/github/license/akashskypatel/ffmpeg-kit-extended?color=144DB3)](LICENSE)

</center>

# FFmpegKit for Flutter

### 1. Features

- Includes both `FFmpeg` and `FFprobe`
- Supports
    - FFmpeg `v8.0`
    - Platforms: `Windows`, `Linux`, `Android`, `iOS` and `macOS`
    - Architectures:
      - `Android`: `arm64-v8a`, `armeabi-v7a`, `x86_64`
      - `Linux`, `macOS`, and `iOS`: `x86_64`, `arm64`
      - `Windows`: `x86_64`
    - `Android API Level 24` or later
    - `armv7`, `armv7s`, `arm64`, `arm64-simulator`, `i386`, `x86_64`, `x86_64-mac-catalyst` and `arm64-mac-catalyst`
      architectures on iOS
    - `iOS SDK 12.1` or later
    - `arm64` and `x86_64` architectures on macOS
    - `macOS SDK 10.15` or later
    - Can process Storage Access Framework (SAF) Uris on Android
    - 155 external libraries including below. See [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) for a full list

      `dav1d`, `fontconfig`, `freetype`, `fribidi`, `gmp`, `gnutls`, `kvazaar`, `lame`, `libass`, `libiconv`, `libilbc`, `libtheora`, `libvorbis`, `libvpx`, `libwebp`, `libxml2`, `opencore-amr`, `opus`, `shine`, `snappy`, `soxr`, `speex`, `twolame`, `vo-amrwbenc`, `zimg`, `vid.stab`, `x264`, `x265`, `xvidcore` and many more.
    - Deploy your own custom ffmpeg-kit using [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders)
- Licensed under `LGPL 3.0` by default, some packages licensed by `GPL v3.0` effectively

### 2. Installation

Add `ffmpeg_kit_extended_flutter` as a dependency in your `pubspec.yaml file`.

```yaml
dependencies:
  ffmpeg_kit_extended_flutter: 1.0.0
```

#### 2.1 Packages

`FFmpeg` includes built-in encoders for some popular formats. However, there are certain external libraries that needs
to be enabled in order to encode specific formats/codecs. For example, to encode an `mp3` file you need `lame` or
`shine` library enabled. You have to install a `ffmpeg_kit_extended_flutter` package that has at least one of them inside. To
encode an `h264` video, you need to install a package with `x264` inside. To encode `vp8` or `vp9` videos, you need
a `ffmpeg_kit_extended_flutter` package with `libvpx` inside.

`ffmpeg-kit` provides eight packages that include different sets of external libraries. These packages are named
according to the external libraries included.
You can deploy your own version of `ffmpeg-kit` using [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) with your own set of external libraries.

##### Pre-built Bundles

See [ffmpeg-kit-builders](https://github.com/akashskypatel/ffmpeg-kit-builders) for a full list of libraries for each feature

|Feature  |Audio   |Video   |Streaming|Video+Hardware
|---------|--------|--------|-------- |--------
|Video    ||x|x|
|Audio    |x|x|x|
|Streaming|||x|
|Hardware ||||x|
|AI       |||||
|HTTPS    |x|x|x|x|x|x|

#### 2.2 Installing Packages

Installing `ffmpeg_kit_extended_flutter` enables the `https` package by default. You can install the other packages
using the following config in pubspec.yaml file.

```yaml
ffmpeg_kit_extended_config:
  version: "1.0.0"
  type: "full"         # full, audio, video, video_hw, or streaming
  gpl: false           # true/false
  small: false         # true/false
  # Optional: Custom paths or URLs for specific platforms
  # android: "https://example.com/custom_android_bundle.zip"
  # ios: "/path/to/local/ios_bundle.zip"
  # windows: "C:/path/to/windows_bundle.zip"
  # macos: "../macos_bundle.zip"
  # linux: "/tmp/linux_bundle.zip"
```

Note that hyphens in the package name must be replaced with underscores. Additionally, do not forget to use the package
name in the import statements if you install a package.

#### 2.5 Platform Support

The following table shows Android API level, iOS deployment target and macOS deployment target requirements in
`ffmpeg_kit_flutter` releases.

<table>
<thead>
<tr>
<th align="center">Android<br>API Level</th>
<th align="center">iOS Minimum<br>Deployment Target</th>
<th align="center">macOS Minimum<br>Deployment Target</th>
</tr>
</thead>
<tbody>
<tr>
<td align="center">24</td>
<td align="center">12.1</td>
<td align="center">10.15</td>
</tr>
</tbody>
</table>

### 3. Using

1. Execute FFmpeg commands.

    ```dart
    import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit.dart';

    FFmpegKit.execute('-i file1.mp4 -c:v mpeg4 file2.mp4').then((session) async {
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {

        // SUCCESS

      } else if (ReturnCode.isCancel(returnCode)) {

        // CANCEL

      } else {

        // ERROR

      }
    });
    ```

2. Each `execute` call creates a new session. Access every detail about your execution from the session created.

    ```dart
    FFmpegKit.execute('-i file1.mp4 -c:v mpeg4 file2.mp4').then((session) async {

      // Unique session id created for this execution
      final sessionId = session.getSessionId();

      // Command arguments as a single string
      final command = session.getCommand();

      // Command arguments
      final commandArguments = session.getArguments();

      // State of the execution. Shows whether it is still running or completed
      final state = await session.getState();

      // Return code for completed sessions. Will be undefined if session is still running or FFmpegKit fails to run it
      final returnCode = await session.getReturnCode();

      final startTime = session.getStartTime();
      final endTime = await session.getEndTime();
      final duration = await session.getDuration();

      // Console output generated for this execution
      final output = await session.getOutput();

      // The stack trace if FFmpegKit fails to run a command
      final failStackTrace = await session.getFailStackTrace();

      // The list of logs generated for this execution
      final logs = await session.getLogs();

      // The list of statistics generated for this execution (only available on FFmpegSession)
      final statistics = await (session as FFmpegSession).getStatistics();

    });
    ```

3. Execute `FFmpeg` commands by providing session specific `execute`/`log`/`session` callbacks.

    ```dart
    FFmpegKit.executeAsync('-i file1.mp4 -c:v mpeg4 file2.mp4', (Session session) async {

      // CALLED WHEN SESSION IS EXECUTED

    }, (Log log) {

      // CALLED WHEN SESSION PRINTS LOGS

    }, (Statistics statistics) {

      // CALLED WHEN SESSION GENERATES STATISTICS

    });
    ```

4. Execute `FFprobe` commands.

    ```dart
    FFprobeKit.execute(ffprobeCommand).then((session) async {

      // CALLED WHEN SESSION IS EXECUTED

    });
    ```

5. Get media information for a file/url.

    ```dart
    FFprobeKit.getMediaInformation('<file path or url>').then((session) async {
      final information = await session.getMediaInformation();

      if (information == null) {

        // CHECK THE FOLLOWING ATTRIBUTES ON ERROR
        final state = FFmpegKitConfig.sessionStateToString(await session.getState());
        final returnCode = await session.getReturnCode();
        final failStackTrace = await session.getFailStackTrace();
        final duration = await session.getDuration();
        final output = await session.getOutput();
      }
    });
    ```

6. Stop ongoing FFmpeg operations.

- Stop all sessions
  ```dart
  FFmpegKit.cancel();
  ```
- Stop a specific session
  ```dart
  FFmpegKit.cancel(sessionId);
  ```

7. (Android) Convert Storage Access Framework (SAF) Uris into paths that can be read or written by
   `FFmpegKit` and `FFprobeKit`.

- Reading a file:
  ```dart
  FFmpegKitConfig.selectDocumentForRead('*/*').then((uri) {
    FFmpegKitConfig.getSafParameterForRead(uri!).then((safUrl) {
      FFmpegKit.executeAsync("-i ${safUrl!} -c:v mpeg4 file2.mp4");
    });
  });
  ```

- Writing to a file:
  ```dart
  FFmpegKitConfig.selectDocumentForWrite('video.mp4', 'video/*').then((uri) {
    FFmpegKitConfig.getSafParameterForWrite(uri!).then((safUrl) {
      FFmpegKit.executeAsync("-i file1.mp4 -c:v mpeg4 ${safUrl}");
    });
  });
  ```

8. Get previous `FFmpeg`, `FFprobe` and `MediaInformation` sessions from the session history.

    ```dart
    FFmpegKit.listSessions().then((sessionList) {
      sessionList.forEach((session) {
        final sessionId = session.getSessionId();
      });
    });

    FFprobeKit.listFFprobeSessions().then((sessionList) {
      sessionList.forEach((session) {
        final sessionId = session.getSessionId();
      });
    });

    FFprobeKit.listMediaInformationSessions().then((sessionList) {
      sessionList.forEach((session) {
        final sessionId = session.getSessionId();
      });
    });
    ```

9. Enable global callbacks.

- Session type specific Complete Callbacks, called when an async session has been completed

  ```dart
  FFmpegKitConfig.enableFFmpegSessionCompleteCallback((session) {
    final sessionId = session.getSessionId();
  });

  FFmpegKitConfig.enableFFprobeSessionCompleteCallback((session) {
    final sessionId = session.getSessionId();
  });

  FFmpegKitConfig.enableMediaInformationSessionCompleteCallback((session) {
    final sessionId = session.getSessionId();
  });
  ```

- Log Callback, called when a session generates logs

  ```dart
  FFmpegKitConfig.enableLogCallback((log) {
    final message = log.getMessage();
  });
  ```

- Statistics Callback, called when a session generates statistics

  ```dart
  FFmpegKitConfig.enableStatisticsCallback((statistics) {
    final size = statistics.getSize();
  });
  ```

10. Register system fonts and custom font directories.

    ```dart
    FFmpegKitConfig.setFontDirectoryList(["/system/fonts", "/System/Library/Fonts", "<folder with fonts>"]);
    ```

### 4. Test Application

You can see how `FFmpegKit` is used inside an application by running `flutter` test applications developed under
the [FFmpegKit Test](https://github.com/akashskypatel/ffmpeg-kit-test) project.

### 5. Tips

See [Tips](https://github.com/akashskypatel/ffmpeg-kit/wiki/Tips) wiki page.

### 6. License

See [License](https://github.com/akashskypatel/ffmpeg-kit/wiki/License) wiki page.

### 7. Patents

See [Patents](https://github.com/akashskypatel/ffmpeg-kit/wiki/Patents) wiki page.
