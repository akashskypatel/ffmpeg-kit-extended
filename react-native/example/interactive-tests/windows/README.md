# React Native Windows interactive tests

AutoGenesis's external Microsoft pywinauto MCP is the Windows desktop
interaction authority. It is development tooling only: do not vendor
AutoGenesis, add its Python packages to the React Native package, or introduce
WinAppDriver/Appium as the first-line Windows dependency.

## Prerequisites

On the Windows host install or expose Python 3.10+, `uv`, and the AutoGenesis
pywinauto MCP server from its upstream repository. Pin and record the exact
AutoGenesis commit used for a real test; this host has not yet run that
external server, so the commit remains an explicit acceptance blocker.

The application must be accessible to the desktop automation account. Do not
run the agent at a different privilege level from the application unless the
privilege boundary is the subject of the test.

## Local runtime input

The example must resolve its existing local FFmpegKit ABI **0.11.2** without a
remote download:

```powershell
Set-Location react-native
node scripts/verify-local-interactive-runtime.js --platform windows --app-root example
```

Use the configured local runtime input only. A hosted or historical ABI is not
a fallback for this test.

## Build

Reuse the existing React Native Windows pipeline:

```sh
cd react-native
./build.sh windows
```

Do not create a second build pipeline. If the agent must launch by executable
path, discover it with `scripts/find-windows-example.ps1`; the helper searches
only the project-owned `react-native/example/windows` build root and never
launches or modifies the application.

## Launch

```sh
cd react-native
./launch.sh windows
```

The launcher starts the required isolated Metro runtime. An already running
instance may be attached when the AutoGenesis client supports it.

## Connect agent tool

Start the external AutoGenesis pywinauto MCP server using its documented
Windows setup. Inspect the running window before interacting. First verify that
`tab.ffmpeg` or `ffmpeg.version.async` is exposed through AutomationId or the
corresponding accessibility property, and record which property was used.
If semantic mapping is absent, fix the React Native testID/accessibility
surface. Do not silently replace it with a coordinate click.

## Run smoke scenarios

Run startup/navigation, FFmpeg async and awaited version, generated video plus
FFprobe, the FFplay control cycle when the Windows surface is operational, and
generated-media transcode. Use the semantic selectors defined by the shared
example UI. AutoGenesis-generated BDD/code files are not committed unless they
are deterministic, readable, stable-selector tests that add coverage beyond
the simpler wrapper tests.

## Expected evidence

Record the AutoGenesis commit SHA, Python/uv versions, application executable
path discovered by the helper, window title, accessibility property and
semantic ID, local runtime path, and each scenario's output. A successful
MSBuild invocation without a real desktop interaction is not a pass.

## Cleanup

Stop the AutoGenesis MCP server, Metro, the Windows example, and all
task-owned child processes. Remove temporary runtime staging and verify that
no task-owned process or listening port remains.

## Troubleshooting

- **Python/uv setup:** verify the interpreter and `uv` are on PATH, then
  record the exact external-server error.
- **Executable not found:** rerun the helper after `build.sh windows` and
  inspect only the known example build root.
- **Title regex mismatch:** inspect the actual top-level window title and
  update the example configuration, not the app's production behavior.
- **Automation ID not exposed:** inspect the RN Windows accessibility tree and
  fix the semantic testID mapping before retrying.
- **Privilege mismatch:** launch the app and automation server at compatible
  privilege levels, or classify the boundary explicitly.
