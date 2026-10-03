# React Native Apple desktop and tvOS interactive tests

Appium is an external development-time agent for the React Native macOS and
tvOS examples. It is not a published `ffmpeg-kit-extended` dependency and it
must run against a local Appium server only. Maestro remains the mobile
Android/iOS authority.

## Prerequisites

Run these steps on the MacBook that owns the Xcode installation. Do not use a
remote Appium endpoint or commit a simulator UDID.

```sh
xcode-select --install
appium driver install mac2
appium driver doctor mac2
appium driver install xcuitest
xcrun simctl list devices available
```

The Mac2 driver needs Xcode Helper Accessibility permission in System
Settings. Run one Mac2 UI test at a time. A tvOS flow needs an installed tvOS
Simulator; real Apple TV pairing is outside this test surface.

The Appium MCP package must be invoked at the exact version tested on the
MacBook, never as `@latest`:

```sh
npx -y appium-mcp@<tested-version>
```

The current Windows host cannot verify the Appium/Mac2/XCUITest versions. The
version and driver output must be recorded here after the first real MacBook
run; the absence of that evidence is a blocker, not a passing test result.
MobileBuildMCP may be used as an optional local build, simulator, log, or
debugging companion. It is not the tvOS UI authority.

## Local runtime input

Before either launch, verify the local-only runtime override without fetching,
copying, extracting, or mutating a cache:

```sh
cd react-native
node scripts/verify-local-interactive-runtime.js --platform macos --app-root example
node scripts/verify-local-interactive-runtime.js --platform appletvos --app-root example
```

The runtime must resolve to the locally configured FFmpegKit ABI **0.11.2**.
Do not replace it with a hosted or historical native ABI.

## Build

```sh
cd react-native
./build.sh macos
./build.sh appletvos
```

The current expected application outputs are:

```text
example/macos/build/DerivedData/Build/Products/Debug/FFmpegKitExtendedExample.app
example/appletvos/build/DerivedData/Build/Products/Debug-appletvsimulator/FFmpegKitExtendedExample.app
```

Validate the built bundle IDs before starting Appium. They are
`org.reactjs.native.FFmpegKitExtendedExample` for macOS and
`org.reactjs.native.example.FFmpegKitExtendedExample` for tvOS.

## Launch

Use the existing isolated-runtime launchers; they own Metro startup and must
not be replaced by a second React Native build pipeline:

```sh
cd react-native
./launch.sh macos
./launch.sh appletvos
```

Start Appium on loopback and pass the corresponding capability example to the
MCP client:

```sh
appium --address 127.0.0.1
npx -y appium-mcp@<tested-version>
```

## Connect agent tool

Use Appium MCP in general/remote mode against the loopback Appium server.
Inspect page source first. For macOS, prove that `tab.ffmpeg` or
`ffmpeg.version.async` is exposed through the native accessibility hierarchy
before running the rest of the suite. If the ID is absent, correct the
React Native accessibility/testID mapping; do not fall back to coordinates.

## Run smoke scenarios

For macOS, run startup/navigation, async and awaited FFmpeg version, generated
video plus FFprobe, the FFplay control cycle, and generated-media transcode.
Use the semantic IDs in `capabilities.macos.example.json` and the example UI.

For tvOS, run startup/navigation, page-source inspection, FFmpeg async
version, FFprobe async version, and return to the FFmpeg/home state. Run
generated-media probing only when the wrapper supports the filesystem/media
operation. Run the FFplay cycle only when the surface is operational, using
focus or `mobile: pressButton` actions (`up`, `down`, `left`, `right`,
`select`, `menu`, `playpause`) rather than touch gestures.

## Expected evidence

Record the Appium MCP, Appium server, Mac2, and XCUITest versions; target
simulator name/version; validated bundle ID; page-source accessibility ID;
scenario outputs; and the exact local runtime path. A successful Xcode build
alone is not interactive evidence.

## Cleanup

Stop the Appium server, Metro process, simulator session, and every
task-owned MCP session. Verify no project-owned process remains and remove
temporary runtime staging before leaving the host.

## Troubleshooting

- **Appium server unavailable:** confirm the loopback server is running and
  the MCP client uses the same local URL.
- **Mac2 cannot interact:** grant Accessibility permission to Xcode Helper
  and rerun serially.
- **Wrong bundle ID:** inspect the built app with `plutil` and update the
  capability only after verifying the project setting.
- **tvOS simulator missing:** inspect `xcrun simctl list devices available`;
  do not substitute a real-device pairing.
- **XCUITest/WebDriverAgent startup failure:** verify Xcode, the installed
  XCUITest driver, simulator availability, and signing/runtime diagnostics.
- **Focus-driven tvOS behavior:** inspect page source and use remote button
  actions; do not introduce coordinate gestures.
- **Orphaned sessions:** stop only the task-tagged Appium/Metro/MCP tree and
  verify the loopback port is released.
