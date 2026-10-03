# Cross-platform interactive scenario contract

This document defines the shared acceptance language for the Flutter and
React Native examples. The examples use the frozen local FFmpegKit ABI/runtime
`0.11.2`; interactive acceptance is local-only and must never fetch a remote or
historical ABI. Hosted workflows are not an interactive-test authority.

## Core scenarios

Run each applicable scenario from a known starting tab and use semantic keys or
accessibility IDs. Every scenario has a bounded completion timeout, creates or
explicitly owns its media prerequisite, stops active FFplay work, cancels
test-owned background sessions, and leaves no agent-owned process/session.

| Scenario | Flutter | RN Android | RN iOS | RN macOS | RN Windows | RN tvOS |
| --- | --- | --- | --- | --- | --- | --- |
| Startup/navigation | Required | Required | Required | Required | Required | Required |
| FFmpeg async version | Required | Required | Required | Required | Required | Required |
| FFmpeg awaited/sync version | Required | Required | Required | Required | Required | Preferred when focus is stable |
| Generate local video | Required | Required | Required | Required | Required | Required if supported |
| FFprobe generated video | Required | Required | Required | Required | Required | Required if supported |
| FFplay play/pause/resume/seek/stop | Required where the surface exists | Required | Required | Required | Required | Required if stable |
| Transcode generated video | Required | Required | Required | Required | Required | Optional |
| Native file picker | Boundary-only | Boundary-only | Boundary-only | Boundary-only | Boundary-only | Not core |
| Remote stream recording | Non-core/network | Non-core/network | Non-core/network | Non-core/network | Non-core/network | Non-core/network |

Platform-specific tools own only the target assigned to them: Marionette for
Flutter, Maestro for RN Android/iOS, Appium with Mac2 for RN macOS, Appium with
XCUITest for RN tvOS, and AutoGenesis pywinauto for RN Windows. Build/simulator
companions do not replace the assigned UI authority.

## Assertions and evidence

Prefer semantic state/output assertions over screenshots:

- success return code and version output;
- generated-file completion text;
- FFprobe format, duration, and stream metadata;
- playback state and position;
- transcode completion and progress.

Screenshots are diagnostic evidence, not the primary correctness oracle. A
recorded scenario must include:

```text
target and host
tool and exact version/commit
application build and bundle/application ID
frozen implementation source SHA
local runtime path and ABI version
scenario name
start/end time and bounded timeout
semantic selectors/accessibility properties used
observed assertions and output excerpts
result: passed | failed | not run | flaky
primary failure category when not passed
cleanup result and remaining-process check
```

Never claim a scenario passed without execution on the stated target. For a
not-run target, preserve the exact blocker and classify it rather than
substituting hosted output or a different platform.

## Failure categories

Every failed or blocked case receives exactly one primary category:

```text
build
launch
agent-tool-connectivity
selector/accessibility
wrapper-api
native-runtime
platform-permission
simulator/emulator
test-assumption
external-network
```

The category describes the first established cause, not the most convenient
workaround. A missing simulator, unavailable external agent, or inaccessible
local runtime is recorded as the corresponding blocker with command/output
evidence.

## Rerun and cleanup policy

Rerun at most once after correcting a known environment problem. If a failure
looks flaky, preserve the first result, rerun without code changes, and mark it
flaky until ownership, waiting, or selector state is understood.

Before and after every interactive run, record task-owned process tags. Stop
Metro, Appium/MCP, emulator/simulator sessions, the example app, FFplay work,
and temporary local-runtime staging that the run created. Verify no tagged
process or listening port remains. Do not kill unrelated user processes.
