# Windows Android emulator interaction

This guide is the Windows Android alternative to the external Maestro CLI for
the React Native example. It uses the local `mcp-android-emulator` stdio
server, the semantic `testID` contract already exercised by the app, and the
configured local FFmpegKit runtime. It is development tooling only and is not
part of the published package.

## Prerequisites

- Node.js 18 or newer and the pinned `mcp-android-emulator.cmd` command.
- Android SDK platform tools with `adb` available on `PATH`.
- The Android emulator AVD `Medium_Phone_API_36.1`.
- The MCP server entry in the project-local `.codex/config.toml` configuration,
  using the example below.
- A trusted local runtime override validated from `react-native/`:

  ```bash
  node scripts/verify-local-interactive-runtime.js --platform android --app-root example
  ```

Install the pinned external tool once for the Windows user account:

```bash
npm install --global mcp-android-emulator@2.0.0
```

Add this server entry to `.codex/config.toml`:

```toml
[mcp_servers.android_emulator]
command = "mcp-android-emulator.cmd"
args = []
env = { ADB_PATH = "adb" }
```

The server package is pinned to the globally installed
`mcp-android-emulator@2.0.0`. Do not replace the local runtime with a remote or
historical ABI archive.

## Start the target

The repository's Windows launch command is defined in
`.vscode/launch.json` and starts:

```text
emulator -avd Medium_Phone_API_36.1 -gpu swiftshader_indirect
```

The target must be visible as `emulator-5554` with status `device` before the
MCP server or RN app is used:

```bash
adb start-server
adb devices -l
```

The Codex MCP server is started by the project configuration using the globally
installed pinned command. A Codex restart or MCP reload is required before a
newly added project server appears as a tool in the current Codex session.

## Build and launch the RN example

From `react-native/`, keep the existing local-only build path:

```bash
npm run example:android
```

The `.vscode` RN launch configuration uses `npm run android` from
`react-native/example`. It must use the same local runtime override and the
same emulator identity; do not create a second build or artifact path.

## Agent-driven scenario

Use the MCP server's semantic operations, inspecting the UI tree before each
action. Do not fall back to screen coordinates or a cloud service.

1. Run `adb devices -l` and require `emulator-5554` to be in `device` state;
   use the MCP `device_info` operation to confirm the same target.
2. `install_apk` with the locally built RN APK if it is not installed.
3. `launch_app` with
   `com.akashskypatel.ffmpegkitextendedexample`.
4. `get_ui_tree` and confirm `app.root`, the log output, and the semantic tab
   selectors are present.
5. Exercise the FFmpeg version controls, including async and awaited calls.
6. Run video/audio generation, then inspect the generated media with the
   `ffprobe.media-info` action.
7. Open FFplay through the semantic `tab.ffplay` control, use `get_ui_tree` to
   confirm the `ffplay.*` controls including `ffplay.play-video`, and use
   `tap_element` for play, pause,
   resume, and stop. Capture `screenshot` while playback is active and inspect
   the surface.
8. Require the app's frame-validity assertion and the expected non-black
   pixel/content status; a screenshot alone is visual evidence, not a pixel
   oracle.
9. Run the generated-media transcode and require the success result.
10. Use `get_logs` with the application package when diagnosing a failure.

The existing shared scenario contract remains the source of required cases:
startup/navigation, FFmpeg version, generated-media probing, FFplay lifecycle,
and generated-media transcode. This MCP server supplies interaction and
evidence capture; it does not execute the committed Maestro YAML files.

## Evidence and cleanup

Record the MCP package version, AVD/ADB serial, app build output, local runtime
path and ABI, semantic selectors, screenshots/logs, and each assertion result.
Tag every process with `FFMPEG_KIT_TASK_TAG`. After the run, stop Metro, the RN
app, the emulator, and the MCP-owned temporary work; remove temporary
screenshots and verify that no tagged process remains.
