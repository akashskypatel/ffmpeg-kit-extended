# Local interactive testing

This is the entry point for Flutter and React Native interactive wrapper
validation. It uses the frozen native ABI/runtime **0.11.2** already configured
in each example. Interactive testing is local-only: do not fetch a remote or
historical ABI, publish native binaries, or use a hosted workflow as a
substitute for a local device, simulator, desktop app, or agent-tool run.

The shared scenario and evidence contract is in
[`interactive-testing-scenarios.md`](interactive-testing-scenarios.md). It
defines the core media matrix, bounded assertions, failure categories, rerun
policy, and process cleanup requirements.

## Support matrix and tool ownership

| Target | UI authority | Build/runtime notes |
| --- | --- | --- |
| Flutter Windows | Marionette MCP | Local Windows runtime; `flutter run -d windows` |
| Flutter Linux | Marionette MCP | Local Linux/WSL runtime; use the target host's path |
| Flutter Android | Marionette MCP; OS dialog only via system automation | Android emulator/device visible to `flutter devices` and `adb devices` |
| Flutter macOS | Marionette MCP | MacBook Air, local Apple runtime |
| Flutter iOS | Marionette MCP | MacBook Air, iOS Simulator |
| RN Web | Existing Playwright smoke | Browser/Wasm staging is local; not a mobile MCP target |
| RN Android | Maestro MCP and committed flows | Local Android emulator/device |
| RN iOS | Maestro MCP and committed flows | Local iOS Simulator |
| RN macOS | Appium MCP with Mac2 | Local loopback Appium server; serial UI tests |
| RN tvOS | Appium MCP with XCUITest | Local tvOS Simulator; focus/remote actions |
| RN Windows | AutoGenesis pywinauto MCP | Local Windows desktop; semantic AutomationId first |

MobileBuildMCP is an optional Apple build/simulator/log/debug companion. It is
not the tvOS UI authority. Maestro, Appium, AutoGenesis, and MobileBuildMCP
are external development tools and are not published runtime dependencies.

## Common prerequisites

1. Confirm the example's local runtime override exists on the host that will
   execute the test. Use the React Native verifier or a read-only Flutter path
   check; never repair it by downloading another artifact.
2. Disable analytics before Flutter/Dart commands when local locking or hangs
   are observed. Use an elevated shell for recovery:

   ```bash
   flutter config --no-analytics
   dart --disable-analytics
   ```

3. Tag every spawned process with `FFMPEG_KIT_TASK_TAG`, observe bounded
   commands, and terminate only confirmed stale/hung task-owned processes
   before retrying. Keep a record of process cleanup.
4. Run one interactive target at a time when it shares Metro, Appium,
   simulator state, accessibility input, or runtime staging.

## Flutter

See [`flutter/TEST.md`](../flutter/TEST.md) and the
[Marionette execution guide](../flutter/example/interactive-tests/marionette.md).

### Prerequisites

Flutter/Dart and the target platform toolchain must be installed. Android also
needs an emulator/device; Apple targets require the MacBook Air with Xcode and
simulators.

### Local runtime input

Use the existing `ffmpeg_kit_extended_config`/Hooks override for the selected
target and confirm the local path without copying, extracting, caching, or
network access.

### Build

```bash
cd flutter/example
flutter pub get
flutter build <target>
```

### Launch

```bash
flutter run -d <device-id> --debug
```

### Connect agent tool

Connect Marionette to the VM Service URI printed by `flutter run`, then inspect
interactive elements before acting.

### Run smoke scenarios

Use the semantic `ValueKey<String>` selectors and the shared core-media
scenarios. Handle Android system-permission UI only at the OS boundary, then
return to Marionette for app assertions.

### Expected evidence

Record host/device, Flutter/Dart/Marionette versions, local runtime path and
ABI, VM Service URI source (not a guessed port), selectors, output assertions,
screenshots/logs, and cleanup.

### Cleanup

Disconnect Marionette, stop `flutter run`, stop test-owned sessions, remove
temporary runtime staging, and verify no tagged process remains.

### Troubleshooting

For a missing VM Service URI, wrong Flutter process, Android dialog focus,
unselected tab, or missing key, follow the exact cases in the Marionette guide
and record the primary failure category before retrying once.

## React Native

See [`react-native/TEST.md`](../react-native/TEST.md), the
[example guide](../react-native/example/README.md), and the committed
[Maestro flows](../react-native/example/.maestro/).

### Prerequisites

Use Node/npm plus the platform SDK. Maestro is required for RN Android/iOS,
Appium with Mac2/XCUITest for RN Apple desktop/tvOS, and AutoGenesis pywinauto
for RN Windows. Install these tools outside the published package and record
the exact tested version or commit.

### Local runtime input

From `react-native/`, run:

```bash
node scripts/verify-local-interactive-runtime.js --platform <android|ios|appletvos|macos|windows> --app-root example
```

The verifier accepts only an existing local file/directory and the frozen
version; it performs no download, extraction, cache, or configuration mutation.

### Build

Reuse `react-native/build.sh <platform>`. Do not create a second build path.

### Launch

Reuse `react-native/launch.sh <platform>` for native example targets. Web uses
the existing local Playwright/Vite smoke path.

### Connect agent tool

Inspect the UI tree first. Maestro uses committed semantic flows, Appium uses
page-source accessibility IDs, and AutoGenesis uses AutomationId/accessibility
properties. Do not replace a missing semantic selector with coordinates.

### Run smoke scenarios

Run the shared startup/navigation, FFmpeg version, generated-media/FFprobe,
FFplay where operational, and transcode scenarios assigned to the target.
Use focus/remote actions on tvOS rather than touch gestures.

### Expected evidence

Record tool version/commit, app ID and build output, local runtime path and
ABI, semantic selectors/properties, output assertions, target identity, and
cleanup status. Build success without UI execution is not an interactive pass.

### Cleanup

Stop Metro, Appium/MCP/AutoGenesis, simulators/emulators, the example app,
FFplay work, and temporary staging. Verify the task-tagged process tree and
listening ports are gone.

### Troubleshooting

For Java/device/Metro/selector/Appium/Mac2/bundle-ID/tvOS/XCUITest/AutoGenesis
issues, use the platform-specific guides linked above and preserve the exact
command and primary failure category.

## Evidence and reporting

For every target report `passed`, `failed`, `not run`, or `flaky`. A not-run
target must include its exact blocker (for example, no emulator, absent Apple
host, missing external agent, or local runtime path inaccessible). Do not
claim a result from a different host or from a hosted workflow.

The final source snapshot is a separate repository-publication step after
local acceptance and source freeze. It must record the requested source SHA,
workflow run, artifact ID/link, checksums, and mailbox metadata; it does not
replace interactive evidence.

## Source snapshot mailbox

The reusable snapshot workflow publishes the source archive and then calls the
race-safe mailbox publisher. The latest discovery pointer is
`.workflow-mailbox/repo-source-snapshot/latest.json`; immutable per-run records
are under `.workflow-mailbox/repo-source-snapshot/runs/`.

Consumers must use the mailbox `source_sha`, not the branch head after the
mailbox metadata commit. Verify the recorded workflow/run URL, artifact ID and
authenticated artifact URL, artifact digest, embedded `snapshot-metadata.json`,
`source.tar.gz.sha256`, every `SHA256SUMS` entry, symlink manifest, and
submodule state. The mailbox commit is discovery metadata and is intentionally
not part of the source archive it reports.
