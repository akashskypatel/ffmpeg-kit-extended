# Flutter Marionette interactive testing

This document is the local execution specification for the Flutter example.
Marionette is the primary Flutter UI driver on Windows, Linux, macOS, Android,
and iOS. It is an agent-side tool; it is not a published package dependency.

## Prerequisites

- Flutter and Dart are installed on the target host.
- The example resolves the already configured local FFmpegKit ABI/runtime
  input for the target platform. The frozen runtime expectation is **0.11.2**.
- The configured override is an existing local archive or directory on that
  same host. Check the path with the host's read-only file-existence command
  before launch. Do not download, extract, copy, cache, or replace it with a
  release URL.
- The Flutter example retains `marionette_flutter: ^0.6.0` and calls
  `MarionetteBinding.ensureInitialized()` in debug mode.
- Install the agent host tool at the tested version:

  ```bash
  dart pub global activate marionette_mcp 0.6.0
  marionette_mcp
  ```

  If the installed Dart SDK requires a supported equivalent activation command,
  record the actual installed version in the tracker. Do not commit a
  user-specific MCP client path.

## Start and connect

Run these checks on the target host, using a caller-supplied device ID:

```bash
flutter config --no-analytics
dart --disable-analytics
flutter doctor -v
flutter devices
```

For Android, also run `adb devices` and use an emulator or device visible to
both tools. For iOS on macOS, run `xcodebuild -version`,
`xcrun simctl list devices available`, and `flutter devices`.

Launch the example without changing its build system:

```bash
cd flutter/example
flutter run -d <device-id> --debug
```

Use the VM Service WebSocket URI printed by `flutter run` (the
`vmServiceUri`/`ws://.../ws` value in machine output) with Marionette's
`connect`. Do not guess a port. After connecting, call
`get_interactive_elements` and use the semantic keys below for all app
controls.

## Required semantic smoke cases

Use bounded waits based on visible state or log changes; do not use long fixed
sleeps.

1. Startup/navigation: inspect the tree, select `tab.ffmpeg`, `tab.stream`,
   `tab.ffprobe`, `tab.ffplay`, and `tab.transcode`, then return to
   `tab.ffmpeg`. Capture one screenshot and inspect Marionette logs for
   unhandled exceptions.
2. FFmpeg version: tap `toolbar.clear-logs`, `ffmpeg.version.async`, then
   `ffmpeg.version.awaited`. Confirm FFmpeg-family version text and success
   return-code output in `logs.output`.
3. Generated media/probe: tap `ffmpeg.generate-video`, wait for the generated
   success message, select `tab.ffprobe`, and tap `ffprobe.media-info`.
   Confirm format, duration, and at least one stream, and confirm the local
   generated file was used rather than the network fallback.
4. FFplay control cycle (only where the surface is supported): select
   `tab.ffplay`, use `ffplay.generate-video` if needed, tap
   `ffplay.play-video`, and observe `ffplay.position`. Exercise
   `ffplay.pause`, `ffplay.resume`, `ffplay.seek-forward`,
   `ffplay.seek-back`, and `ffplay.stop`; confirm the app remains responsive
   and position never becomes negative.
5. Generated transcode: select `tab.transcode`, leave the optional picker
   unused, tap `transcode.run`, and verify `transcode.progress`,
   `transcode.status`, and the generated AVI output in `logs.output`.

The remote HLS flow, native file picker, Android settings/media permission
screen, and network-dependent cases are boundary cases, not part of the
mandatory offline smoke suite.

## Android system-dialog boundary

The example may request media permissions during startup. If no system dialog
appears, stay entirely in Marionette. If Android system UI takes focus, grant
or dismiss only that OS prompt with device/system automation, return to the
Flutter app, and continue the app scenario in Marionette. This setup step does
not turn a Marionette app test into a coordinate-driven app test.

## Cleanup and evidence

- Save the target device name, Flutter version, Marionette version, exact
  commands, pass/fail result, and screenshot/log path in the local tracker.
- Call Marionette `disconnect`, stop `flutter run`, and terminate any confirmed
  stale task-owned process before starting another target.
- If a simulator, emulator, VM Service, or local ABI path is unavailable,
  record the exact blocker as **not run**. Build-only output is not an
  interactive pass.
