# Review 35 — Luna Cross-Platform Flutter + React Native Remediation Plan

**Audience:** Luna model  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch:** `dev-wasm`  
**Starting wrapper authority:** `c9682fb8a7f98141b1566374b0f7c827aedd7e1b`  
**Review basis:** `review35-cross-platform-code-review.md`  
**Native ABI:** frozen/read-only; do not download, re-review, modify, rebuild, or publish it  
**Native runtime:** `0.11.2`

## Goal tracker

| Metadata ID | Objective | Status |
| --- | --- | --- |
| R35-G1 | Commit Flutter terminal-history state before user completion callbacks can dispose a session | Pending |
| R35-G2 | Remove React Native Created identities on explicit pre-execution abandonment | Pending |
| R35-G3 | Remove Flutter identities hidden by `clearSessions()` when execution settles | Pending |
| R35-G4 | Run focused and affected local cross-platform wrapper regression using frozen local artifacts | Pending |
| R35-G5 | Reconcile evidence, freeze the exact wrapper SHA, and create one wrapper-only source snapshot | Pending |

## Operating constraints

- `libs/libffmpegkit`, FFmpegKit native source, and `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders` are read-only.
- Do not download or re-review another native/builders snapshot, rebuild or publish native ABI bundles, or fetch remote old ABI bundles.
- Use only the established local Windows/Linux/Wasm/Android artifacts and MacBook Air universal Apple XCFramework archives.
- Apple implementation uses the completed universal XCFramework archives on the MacBook Air, not individual dylibs:
  - `/Users/akash/Projects/ffmpeg-kit-builders/prebuilt/apple/xcframeworks/bundle-base-ios-universal-small-lgpl.xcframework.zip`
  - `/Users/akash/Projects/ffmpeg-kit-builders/prebuilt/apple/xcframeworks/bundle-base-macos-universal-small-lgpl.xcframework.zip`
  - `/Users/akash/Projects/ffmpeg-kit-builders/prebuilt/apple/xcframeworks/bundle-base-appletvos-universal-small-lgpl.xcframework.zip`
- Do not use hosted Flutter/React Native acceptance CI as evidence and do not launch interactive applications.
- Implementation names must describe behavior; R35, finding IDs, goal IDs, review names, and plan names are metadata only.
- Tests must be executable oracles. Record failed commands, retries, environment corrections, and mistakes truthfully.
- Preserve the primary execution/cancellation error when history cleanup also fails.
- Tag and observe task-owned Flutter/Dart/Node/PowerShell/WSL/compiler/SSH processes; terminate confirmed task-owned hangs immediately and clean task-owned outputs.
- Run Flutter/Dart with analytics disabled (`flutter config --no-analytics`, `dart --disable-analytics`).
- Commit and push completed goals separately where practical. Create one wrapper-only source snapshot at final closeout.

## Source preparation

Before editing, verify the repository, `dev-wasm` branch, exact starting tree, and
starting wrapper authority. Verify the frozen native submodule without editing it, and
verify Flutter/React Native example configuration still points to the established local
artifacts. Read this plan, the code review, and `.agent/TRACKER.md`.

## G1 — Terminal history before user completion

Create one semantic, idempotent terminal-history transition separate from queue
settlement. When authoritative native completion is known, it must:

1. mark a visible identity terminal;
2. apply configured terminal-history capacity;
3. remove an identity hidden by `clearSessions()`;
4. run before wrapper/global/user completion callbacks.

Queue settlement remains responsible for cancellation monitors, active/reserved queue
ownership, queue advancement, and execution-future settlement. It must not be the first
terminal-history authority.

Required ordering:

```text
synchronous native return
-> terminal-history commit/prune
-> completion callbacks
-> stream/bridge cleanup
-> queue settlement
```

```text
authoritative async completion
-> terminal-history commit/prune
-> final bounded log/stat reconciliation
-> callback cleanup
-> user completion callback
-> execution future completion
-> queue settlement
```

Do not terminalize a Created/Running session after a pre-start failure. Reconciliation
errors are secondary and must not replace a primary execution error or cause duplicate
native release.

## G2 — Explicit React Native Created-session abandonment

Add a behavior-oriented wrapper bridge operation for a session that the JavaScript layer
has definitively discarded before native execution. It updates native bridge history
metadata without requiring `retainedSessionHandles`; Web removes the identity from its
metadata registry without manipulating a Wasm pointer. The operation must be idempotent,
must not infer abandonability from a missing handle, and must not affect Running or
terminal work.

Use it from shared queue discard for FFmpeg, FFprobe, MediaInformation, and FFplay,
`clearQueue()`, `cancelQueued()`, and permanent pre-submission cancellation if that is
the current public contract. Keep the queue's cancellation exception primary; log any
metadata cleanup failure as secondary and always release queue reservations.

## G3 — Cleared Flutter lifecycle

Keep the existing ownership-safe `clearSessions()` behavior: remove entries without a
live wrapper and hide entries whose callback/execution owner must remain alive. At the
G1 terminal boundary, remove invisible entries instead of marking them terminal. Permit
disposal to remove invisible entries even if they are already terminal. Visible terminal
entries must remain available until capacity pruning; active sessions must not be
cancelled merely to simplify metadata.

## G4 — Local verification

Do not begin the broad matrix until G1–G3 focused regressions are green.

Flutter focused gates include terminal-before-callback and cleared-history regressions,
`session_history_index_test.dart`, lifecycle/ownership/callback suites, FFplay boundary
suites, the full non-native package suite, and bounded analysis of changed files.

React Native focused gates include TypeScript compile/typecheck, queue regressions,
native/Web abandonment behavior, bounded-history regressions, scalar-state monitoring,
MediaInformation Web classification, dynamic bridge syntax, and package checks. Update
obsolete tests to the current semantic contract instead of weakening valid scenarios.

Run affected local validation in this fixed order:

1. Windows;
2. Android on Windows;
3. Linux under WSL;
4. Wasm/Web;
5. Apple last on the MacBook Air over SSH.

If an established local artifact is missing, mark only that gate blocked and continue
unaffected gates; never substitute a published or remote old bundle.

## G5 — Evidence and exact wrapper closeout

Update only behavior changed by G1–G3 and record actual local evidence. Verify a clean
wrapper worktree and exact final SHA/tree, confirm the native submodule is unchanged,
push `origin/dev-wasm`, and dispatch `.github/workflows/repo-source-snapshot.yml` once
for the exact wrapper SHA. Verify and record the workflow/source SHA, artifact ID/name/
digest, embedded archive hash, full checksums, recursive submodule state,
`runtimeExecution=false`, and manifest count in `.agent/TRACKER.md`.

Do not create a builders/native snapshot for Review 35. After the exact wrapper snapshot
is verified, stop automated interactive work; final interactive runtime validation is
user-owned.

## Hard sequence

```text
terminal-history ordering
-> Created-session abandonment
-> cleared-history lifecycle cleanup
-> focused regressions
-> local Windows/Android/WSL/Wasm/Apple gates
-> tracker reconciliation
-> exact wrapper freeze
-> one wrapper-only source snapshot
-> stop
```
