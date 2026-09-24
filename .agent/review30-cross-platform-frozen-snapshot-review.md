# Review 30 — Cross-Platform Frozen-Snapshot Source Review

**Project:** FFmpegKitExtended  
**Date:** 2026-09-24  
**Review type:** independent cross-platform frozen-source review  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Frozen Review 29 wrapper SHA:** `237fb5044243240b6199b3a46f0c7cc73ae3586a`  
**Snapshot workflow run:** `36060335093`  
**Snapshot artifact:** `review29-wrapper-source-36060335093`  
**Artifact ID:** `10833983040`  
**Downloaded artifact ZIP SHA-256:** `3fbe20bc33df827b505a0cb836d8c4f5412a155b7d5da35ed65a8e799d325224`  
**Embedded `source.tar.gz` SHA-256:** `576f3e1c5c74338a94daef6b80455749d77d211bc612c0e0bf1a46b6353ee75e`  
**Snapshot manifest:** `1058` files / `27222488` bytes  
**Recursive submodules:** `true`  
**Snapshot runtime execution:** `false`  
**Embedded `libs/libffmpegkit`:** `b74da2c5d1e294b87d15d73a6687393729e932b3`

## Authority and review boundary

Review 30 uses only the exact Review 29 source-snapshot artifact recorded in the tracker as wrapper source authority. Repository source was not reconstructed through piecemeal live GitHub reads.

Snapshot verification completed before source review:

- the downloaded ZIP SHA-256 matches the GitHub Actions artifact digest;
- `source.tar.gz` matches the snapshot-declared SHA-256;
- all **1058** `SHA256SUMS` entries verify after extraction;
- `snapshot-metadata.json.snapshot_sha` is exactly `237fb5044243240b6199b3a46f0c7cc73ae3586a`;
- the embedded native submodule is exactly `b74da2c5d1e294b87d15d73a6687393729e932b3`;
- the snapshot reports `runtimeExecution=false`.

This is a source/noninteractive review. No Flutter or React Native interactive application was launched. No hosted CI run, remotely published native ABI, or replacement native artifact was used as Review 30 evidence.

Previously accepted native/third-party dispositions remain closed unless directly contradicted by this frozen tree. Review 30 does **not** reopen the accepted FFmpeg TSan race, TLS cancellation diagnostic, matched-runtime UBSAN disposition, or `ffigen_js` prerelease exception.

---

# Executive disposition

**Do not promote the frozen Review 29 wrapper snapshot unchanged to final manual runtime validation.**

Review 30 found **four wrapper/product issues, one validation-classification error, and one source-authority/documentation defect**:

| ID | Severity | Surface | Finding | Main consequence |
|---|---|---|---|---|
| **R30-F1** | **Medium** | Flutter Web / public FFplay session API | Review 29 playback epochs are committed only by `FFplayKit` tracked startup; direct public `FFplaySession.execute()` / `executeAsync()` bypass the epoch | Reused Web surfaces can still suppress the first frame of a new playback and retain stale presentation |
| **R30-F2** | **Medium** | Flutter FFplay global ownership | Successful cancel/close of an untracked current session clears `currentSession` instead of falling back to an older unsettled tracked execution | Global playback controls can lose the still-running/tracked owner |
| **R30-F3** | **High validation blocker; not native product defect** | Flutter native API test | R29-B1 is misclassified: native fake numeric handles are intentionally required to fail closed; Flutter's integration test still expects obsolete fake-handle lookup | One full Flutter test remains red for the wrong expected contract and falsely blocks native parity |
| **R30-F4** | **Medium** | Flutter build hook shared artifact cache | shared cache download/extraction/update paths use deterministic temporary names with destructive cleanup and no inter-process ownership | Concurrent hook invocations can delete or replace each other's partial cache/extraction state |
| **R30-F5** | **Medium-Low** | React Native iOS/tvOS/macOS FFplay views | Apple owner replacement unregisters the old callback but does not deactivate the previous view's local `_acceptFrames` state | A replaced Apple view can still display already-queued stale frame data after ownership moves |

No Review 30 finding requires a native ABI change.

---

# R30-F1 — Flutter Web playback epoch does not cover direct `FFplaySession` execution

**Severity: Medium**

## Evidence

Review 29 added a Web rendering epoch. In the frozen source, the only production call to:

```text
FFplaySurface.beginPlayback()
```

is:

```text
flutter/lib/src/ffplay_kit.dart:183
```

inside `FFplayKit._startTrackedExecution()`.

The public session API still exposes direct execution:

```text
flutter/lib/src/ffplay_session.dart:513  FFplaySession execute()
flutter/lib/src/ffplay_session.dart      Future<FFplaySession> executeAsync(...)
```

Those paths call the backend directly and do not commit a Web playback epoch.

`FFplayKit.createSession()` also documents that the returned session can be executed through `execute` / `executeAsync`, so this is not an unreachable internal route.

The Web frame surface keys acceptance by:

```text
(playback epoch, native generation)
```

in:

```text
flutter/lib/src/web/ffplay_surface_web.dart
flutter/lib/src/web/ffplay_playback_epoch.dart
```

but direct session execution leaves the epoch unchanged.

## Consequence

The Review 29 defect remains reachable through a public API:

1. playback A renders generation `1`;
2. native teardown resets its frame generation;
3. the same Web surface is retained;
4. playback B starts through direct `FFplaySession.executeAsync()`;
5. the global Web epoch does not change;
6. playback B's first generation `1` can be treated as the already-seen `(same epoch, 1)` frame.

The old decoded image can therefore remain visible until a later generation is accepted.

## Cross-wrapper comparison

React Native Web commits the new playback identity at the backend FFplay execution boundary:

```text
react-native/src/platform/backend.web.ts:387-388
```

Immediately after `ffplay_kit_session_execute_async`, it calls `beginFFplayPlayback(sessionId)`. Direct and higher-level callers therefore converge on the same execution boundary.

## Test gap

`flutter/test/ffplay_web_playback_epoch_test.dart` verifies the epoch primitive and generation reuse, but it does not prove that **every public FFplay execution path** advances the epoch.

## Required remediation

Move Web playback-epoch ownership to one execution-start boundary shared by all public FFplay execution paths, rather than leaving it only in `FFplayKit._startTrackedExecution()`.

Required focused oracles:

- high-level `FFplayKit.executeAsync`;
- direct `FFplaySession.executeAsync`;
- direct synchronous path if Web continues to support it;
- failed startup does not commit a successful playback epoch;
- reused native generation is accepted after a new playback;
- stale displayed image is cleared at the new playback boundary;
- no double epoch increment for the high-level path.

---

# R30-F2 — Removing an untracked current FFplay session does not restore an older tracked owner

**Severity: Medium**

## Evidence

Flutter maintains:

```dart
FFplaySession? _activeFFplaySession;
final Set<FFplaySession> _trackedExecutions = <FFplaySession>{};
```

Review 29 correctly changed tracked settlement so that removing the current tracked session falls back to:

```dart
_trackedExecutions.last
```

when another tracked execution remains.

However, the separate untracked cleanup helper remains:

```dart
static void _clearCurrentIfUntracked(FFplaySession session) {
  if (identical(_activeFFplaySession, session) &&
      !_trackedExecutions.contains(session)) {
    _activeFFplaySession = null;
  }
}
```

`FFplayKit.cancel(session)` calls this helper after successful cancellation, and `FFplayKit.close()` applies the same untracked-current cleanup semantics.

`FFplayKit.createSession()` makes the new, not-yet-tracked session current immediately.

## Reachable sequence

```text
A = older tracked unsettled FFplay execution
B = FFplayKit.createSession(...) -> B becomes current but remains untracked
FFplayKit.cancel(B) or successful close of B
```

The helper sets `currentSession` to `null`, even though A is still present in `_trackedExecutions`.

Global pause/resume/seek/current-state access then loses A.

## Documentation contradiction

The frozen README states that `FFplayKit.cancel()` and `FFplayKit.close()` clear the global current session only when no tracked execution is pending, and that tracked executions remain current until their execution Future settles.

The implementation violates that stated contract in the mixed tracked/untracked case.

## Test gap

The lifecycle suite covers:

- older tracked settles before newer;
- newer tracked settles before older;
- untracked cancel with no older tracked owner;
- tracked cancel;
- successful/failed close.

It does not cover an **older tracked execution plus a newer untracked current session**.

## Required remediation

Use one owner-removal helper for both tracked and untracked current-session removal:

```text
if removed session is current:
    current = newest remaining tracked execution, or null
```

Add separate regression cases for:

- canceling newer untracked B restores tracked A;
- closing newer untracked B restores tracked A;
- no remaining tracked execution still produces null;
- failed cancel/close preserves B as current.

---

# R30-F3 — R29-B1 is a stale Flutter test, not a native fake-handle defect

**Severity: High validation blocker; native product severity: none established**

## Tracker classification being corrected

Review 29 recorded one full Flutter test failure:

```text
expected session ID
actual -1
```

for:

```dart
Pointer<Void>.fromAddress(id)
```

and classified it as a native-only fake-handle lookup mismatch.

The frozen source disproves that classification.

## Native contract in the exact embedded submodule

`libs/libffmpegkit/FFmpegKit/tests/wrapper_test.cpp:3508-3513` explicitly states:

```text
Numeric session IDs are not opaque handles.
They must fail closed instead of being guessed from pointer values.
```

and expects:

```text
ffmpeg_kit_session_get_session_id(fake_handle) == -1
ffmpeg_kit_session_get_output(fake_handle) == nullptr
ffmpeg_kit_session_get_logs_count(fake_handle) == -1
```

This is also consistent with the earlier native change that removed the numeric fake-handle heuristic.

## Stale Flutter oracle

`flutter/test/api_test.dart:2760-2768` still says that the native layer should look up session history from the integer pointer and expects:

```dart
ffmpeg_kit_session_get_session_id(fakeHandle) == id
ffmpeg_kit_session_get_output(fakeHandle) != nullptr
```

That expectation is obsolete.

The supplied Windows artifact returning `-1` is therefore aligned with the frozen native source, not evidence of a native ABI regression.

## Required remediation

Change only the stale Flutter native integration oracle:

```text
numeric ID cast as pointer -> fail closed
session ID -> -1
pointer-returning getters -> null
count getters -> failure sentinel where applicable
no crash
```

Then rerun the complete Flutter native/API suite against the same local Windows artifact.

Do **not** add a wrapper compatibility fallback, reintroduce fake-pointer lookup, weaken the native test, or change the native ABI.

R29-B1 should be closed/reclassified after the corrected exact-source test passes.

---

# R30-F4 — Flutter shared artifact cache operations are not inter-process safe

**Severity: Medium**

## Evidence

The build hook deliberately places platform caches under the shared hook output directory:

```text
input.outputDirectoryShared/ffmpeg_kit_cache/<platform>/
```

but mutation uses deterministic temporary paths without an ownership/locking protocol.

Examples:

```text
<target>.downloading
<cacheFile>.refreshing
<extractRoot>.extracting
```

`prepareExtractedArtifact()`:

1. deletes an incomplete final extract;
2. deletes the fixed `.extracting` directory;
3. extracts into that fixed directory;
4. renames it to the final root.

`cleanupStaleDownload()` deletes the fixed `.downloading` path.

`syncRemoteOverrideToCache()` deletes the fixed `.refreshing` path before use and again during cleanup.

`syncLocalOverride()` writes directly to the final shared cache filename rather than publishing from a unique temporary file.

No file lock, lock-directory protocol, process identifier, unique temporary name, or winner/recheck publish step exists around these shared mutations.

## Consequence

If two hook processes operate on the same platform/artifact concurrently, either process can treat the other process's active temporary state as stale.

Possible races include:

- A is extracting; B deletes A's `.extracting` directory;
- A is downloading; B's stale cleanup deletes A's `.downloading` file;
- two remote refreshes replace/delete the same `.refreshing` file;
- one reader hashes or extracts a local cached file while another invocation copies new bytes directly over its final pathname.

The current hook-artifact-cache tests are sequential and contain no multi-process contention oracle.

This finding is about the cache transaction itself; Review 30 does not claim that the transient Review 29 build-retry diagnostic was caused by this race.

## Required remediation

Keep the shared cache, but make publication transactional.

A minimal design is:

- use a per-artifact inter-process lock **or** unique per-process temporary paths plus atomic publish/recheck;
- never delete another process's in-progress temporary path;
- publish local overrides through a complete temporary file and atomic rename/replace;
- after winning/losing publication, revalidate final hash/marker before use;
- make extraction marker identity correspond to the archive content identity, not merely basename/existence.

Add a true **multi-process** regression oracle. Concurrent Futures in one Dart isolate are insufficient for this failure mode.

---

# R30-F5 — React Native Apple owner replacement leaves the previous view locally frame-active

**Severity: Medium-Low**

## Evidence

The iOS, tvOS, and macOS implementations have the same ownership sequence.

When a new view activates:

```objc
if (coordinator.view == self && _acceptFrames) return;
gUnregisterFrameCallback();
coordinator.view = self;
_acceptFrames = YES;
gRegisterFrameCallback(...);
```

The previous `coordinator.view` is never told to set its own `_acceptFrames = NO`.

Later, if that previous view calls `deactivateFrameOutput`, it returns immediately when:

```objc
coordinator.view != self
```

and still does not clear its local acceptance flag.

`displayPendingFrame` checks `_acceptFrames` before enqueueing its already-queued sample buffer. Therefore a main-thread display callback that was queued before global ownership replacement can still display the stale sample after another view has become the process-global FFplay target.

## Cross-platform comparison

React Native Windows explicitly deactivates the old view before replacement:

```cpp
if (g_activeView) {
    g_activeView->m_acceptFrames.store(false, ...);
    s_unregisterFrameCallback();
}
```

Apple does not have the equivalent local-owner invalidation.

The Apple behavior is bounded by the globally drained callback/unregister path; this review does not identify an unbounded producer or UAF. The issue is stale visual ownership after replacement.

## Required remediation

When replacing an Apple owner:

1. capture the previous view;
2. clear its local frame-acceptance state under its frame lock;
3. unregister/drain the process-global native callback;
4. install the new owner and callback.

Also make stale-view deactivation always clear **local** acceptance/pending display state even when it is no longer allowed to unregister the global callback.

Add the same ownership oracle for iOS, tvOS, and macOS.

---

# Fresh Review 30 executable/static evidence

## Snapshot integrity

```text
GitHub artifact digest:
sha256:3fbe20bc33df827b505a0cb836d8c4f5412a155b7d5da35ed65a8e799d325224

Embedded source.tar.gz:
sha256:576f3e1c5c74338a94daef6b80455749d77d211bc612c0e0bf1a46b6353ee75e

SHA256SUMS:
1058/1058 entries verified
```

## React Native source/regression subset

Executed from the frozen `react-native/` directory:

```text
node --test   tests/ffplay-native-lifecycle.test.js   tests/resolve-ffmpeg-kit-config.test.js   tests/windows-runtime-packaging.test.js
```

Result:

```text
32 tests
29 passed
3 skipped (PowerShell-only tests on this audit host)
0 failed
```

This confirms, among other retained contracts, that Review 29's tvOS complete-pair symbol remediation is present in the frozen source.

## Audit-host limits

The Review 30 audit container has Node.js and a C++ compiler, but no Flutter/Dart executable. Review 30 therefore does **not** claim a fresh Flutter runtime/package test pass from this host.

The tracker-recorded Review 29 local Flutter/platform results remain historical evidence for that frozen source. Review 30's Flutter findings above are source/contract findings and must be converted into executable regression tests during remediation on the established local Flutter hosts.

---

# Reviewed non-findings retained

The following Review 29 fixes remain present and did not produce a new defect in the audited path:

- React Native tvOS now requires the complete FFplay register/unregister symbol pair.
- Flutter Linux uses `FrameNotificationCoalescer` so one pending main-loop notification/reference is retained per pending mark.
- Flutter tracked FFplay settlement falls back from a newer settled tracked execution to an older unsettled tracked execution.
- Flutter fullscreen cleanup retains the Review 29 failure-atomic structure.
- React Native Web uses playback identity at its backend execution boundary.
- React Native Windows explicitly deactivates the previous FFplay view before process-global owner replacement.
- The frozen native fake-handle contract itself is internally consistent: numeric IDs are not accepted as opaque handles.

---

# Recommended Review 30 remediation goals

| Goal | Objective | Required exit evidence |
|---|---|---|
| **R30-G1** | Move Flutter Web playback epoch ownership to a boundary covering every public FFplay execution route | high-level + direct-session epoch regressions; reused-generation/stale-image oracles; local Web build/browser playback-restart smoke |
| **R30-G2** | Restore the newest remaining tracked Flutter owner when an untracked current session is removed | cancel/close mixed tracked+untracked lifecycle tests pass |
| **R30-G3** | Correct the stale Flutter fake-handle integration oracle and close/reclassify R29-B1 | complete native Flutter API suite green against the unchanged local Windows artifact |
| **R30-G4** | Make Flutter hook shared artifact mutation safe across concurrent processes | true multi-process same-cache regression plus existing hook/path suites; local Windows/Linux and relevant Apple hook builds |
| **R30-G5** | Deactivate the previous React Native Apple view locally before callback-owner replacement | iOS/tvOS/macOS source/native ownership oracle; local noninteractive Apple builds |
| **R30-G6** | Reconcile Review 29/30 docs, tracker links, affected package gates, and freeze one new exact source | no missing active-review tracker links; affected local gates green; new exact SHA/tree and source snapshot recorded |

## Validation order

```text
R30-G1..G5 implementation
-> focused regression tests
-> complete Flutter native/API suite to clear the stale R29-B1 classification
-> Flutter non-native/package tests
-> Flutter Web local build + playback-restart browser oracle
-> hook multi-process/cache tests + affected local platform builds
-> React Native focused/full package gates + local Apple noninteractive builds
-> R30-G6 docs/tracker reconciliation
-> freeze one new exact wrapper SHA/tree
-> source-snapshot verification
-> STOP automated interactive execution
-> user performs final Flutter/RN interactive runtime matrices
```

No hosted CI should be substituted for the established local unpublished-ABI acceptance gates, and no remotely published native ABI is needed for these fixes.

---

# Review 30 implementation status after the local Flutter cache gate

```text
Frozen Review 29 snapshot provenance: VERIFIED
Manifest verification: 1058/1058
Cross-platform source review: COMPLETE
R30-G1: COMPLETE — direct and high-level Flutter Web execution boundaries converge.
R30-G2: COMPLETE — mixed tracked/untracked owner removal restores the newest tracked owner.
R30-G3: COMPLETE — the Flutter oracle now matches the native fail-closed numeric-handle contract.
R30-G4: COMPLETE — shared hook cache publication is inter-process safe; local Windows/Linux/Android/Apple gates pass.
R30-G5: IMPLEMENTED — React Native Apple ownership oracle and local Mac iOS/tvOS/macOS builds pass; tracker closeout follows the per-goal push boundary.
R30-G6: PENDING — reconcile final documentation, freeze the exact wrapper SHA, and run the requested source snapshots.
Native ABI change required: NO
Native/builder source modification performed: NO
Hosted CI used as Flutter/React Native acceptance evidence: NO
Interactive Flutter/RN runtime executed: NO
Promotion of frozen Review 29 wrapper unchanged: NOT RECOMMENDED
```
