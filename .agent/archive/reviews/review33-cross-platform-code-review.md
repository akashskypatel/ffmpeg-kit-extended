# Review 33 — Flutter + React Native Cross-Platform Code Review

**Project:** FFmpegKitExtended  
**Review type:** source-only code review  
**Date:** 2026-09-25  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Frozen wrapper source:** `bbdc02c942754cd3e3dbce1ded0ef59674fd5dd6`  
**Snapshot workflow:** `36095917288`  
**Snapshot artifact:** `review32-final-wrapper-source-36095917288`  
**Artifact ID:** `10847428217`  
**Artifact digest:** `sha256:79478c8d9a6ed785808b33d4acb2ff29d8544508a003ebbe0e6749cee6c7e688`  
**Embedded `source.tar.gz` SHA-256:** `2a25832597b6015e62e6dc5e3ce36e5773c6e100f97602022b8ba7a666fae7b9`  
**Manifest:** **1,057/1,057 files verified**  
**Native ABI:** frozen/read-only; not downloaded or re-reviewed

## Review boundary

Review 33 used only the final Review 32 wrapper snapshot recorded in `.agent/TRACKER.md`.

This was **code review only**:

- no Flutter/Dart tests;
- no Node tests;
- no builds;
- no hosted CI;
- no simulator/device execution;
- no interactive runtime execution;
- no repository mutation.

The review excludes style, naming, formatting, documentation-only drift, missing-test-only observations, speculative hardening, and low-impact pedantry.

Review 32's completed execution-ownership, queue-transaction, and native-history remediation is treated as the baseline.

---

# Executive disposition

The frozen Review 32 wrapper is **not code-review clean**.

Review 33 found **three substantive defects**:

| ID | Severity | Surface | Finding |
| --- | --- | --- | --- |
| **R33-F1** | **High** | Flutter native + Web | Read-only session-history lookup can release a duplicate handle for an actively Running session, and the wrapper's own handle contract says that release cancels the session |
| **R33-F2** | **High** | React Native native + Web | `getSessions*()` / `getLastSession*()` obtain owning history handles and release them after snapshotting, which can cancel active sessions being inspected |
| **R33-F3** | **Medium-High** | React Native native | The normal 50 ms state monitor obtains state by serializing complete session JSON, including complete output and log strings, creating repeated whole-history copies during long executions |

No Review 33 finding requires changing the frozen FFmpegKit native ABI.

---

# R33-F1 — Flutter history reads can cancel active sessions

**Severity: High**

## Wrapper-owned handle contract

`flutter/lib/src/session.dart:213-225` documents the ownership rule used by the wrapper:

> Dispose a running session only when cancellation/release semantics are acceptable. The native wrapper cancels a running session before releasing it.

That makes a Running session handle materially different from a terminal/Created inspection token: releasing it is not read-only.

## Unsafe history path

Flutter's native and Web backends return owning handles from the frozen session-history exports:

- `flutter/lib/src/platform/native/backend_native.dart:771-812`
- `flutter/lib/src/platform/web/backend_web.dart:753-796`

The public history and lookup APIs route those handles through:

- `FFmpegKitExtended.getSessions()`
- typed `getFFmpegSessions()`, `getFFprobeSessions()`, `getFFplaySessions()`, `getMediaInformationSessions()`
- `getSession(id)`
- `getLastSession()` and typed last-session variants

in `flutter/lib/src/ffmpeg_kit_extended.dart:336-440`.

`_wrapSession()` then checks `CallbackManager` for an existing live Dart object. When it finds one, it does this:

```dart
if (existing != null) {
  duplicateReleaseAttempted = true;
  ffmpegKitBackend.releaseSession(handle);
  return existing;
}
```

at `flutter/lib/src/ffmpeg_kit_extended.dart:742-753`.

For an actively executing session, that is exactly the state where the existing live object is most likely to be present. Therefore a nominally read-only history query obtains a second owning handle and immediately releases it while the underlying session is Running.

The same risk exists on both Flutter native and Flutter Web because both backends use the same history-handle wrapping path and `releaseSession()` ultimately calls `ffmpeg_kit_handle_release`.

## Consequence

Application code can stop or cancel live work merely by inspecting session history.

Examples include:

```text
FFmpegKitExtended.getSessions()
FFmpegKit.getFFmpegSessions()
FFprobeKit.getFFprobeSessions()
FFplayKit.getFFplaySessions()
FFmpegKitExtended.getSession(activeId)
FFmpegKitExtended.getLastSession()
```

while the returned/selected native session is still Running.

This is especially dangerous for UI/status code that periodically reads history while transcoding or playback is active.

## Why Review 32 did not fix it

Review 32 correctly added queue/execution ownership by native session ID. That controls **execution admission**. It does not change ownership of extra handles returned by history lookup.

The execution reservation can therefore remain correct while the history reader independently cancels the admitted execution.

## Required remediation

History inspection must never release a Running session handle.

The wrapper needs a history identity/projection layer that can answer history queries without asking the frozen ABI for a fresh releasable handle for a known Running session.

A viable wrapper-only design should:

1. record session ID, type, and creation order when wrapper sessions are created;
2. identify queued/active Running sessions through existing wrapper ownership;
3. return/reuse the live Dart object for active history entries without obtaining a fresh native history handle;
4. obtain temporary native handles only for states where release is non-cancelling;
5. prune only entries the frozen native history semantics would evict;
6. reconcile `setSessionHistorySize()` and `clearSessions()`;
7. keep metadata bounded to live/Created sessions plus configured terminal history;
8. avoid retaining strong Dart session objects solely for history, preserving prior callback/lifetime work.

If Luna establishes that the frozen ABI makes a required history case impossible without either cancelling or leaking a Running handle, it must record the exact blocker rather than changing the native ABI.

---

# R33-F2 — React Native history snapshots can cancel active sessions

**Severity: High**

This is the React Native counterpart, but it is implemented independently and requires separate remediation.

## Native bridge contract already states the hazard

`react-native/cpp/FFmpegKitDynamicApi.cpp:33-35` states:

```cpp
// C API session handles are owning handles. Releasing a handle for a running
// session requests cancellation, so React Native must retain the handle created
// for each session until execution has actually completed.
```

`acquireSession()` reinforces the invariant at `:223-234`:

```cpp
if (it != retainedSessionHandles.end()) {
  // Borrow the retained handle. Releasing it while Running would cancel
  // the underlying native session.
  return HandleGuard(it->second, false);
}
```

Single-session operations such as logs/state therefore deliberately borrow the retained execution handle while a session is active.

## Native list/last-session path bypasses that protection

Review 32 changed history enumeration to the native list exports.

`collectNativeSessionHandles()` at `react-native/cpp/FFmpegKitDynamicApi.cpp:317-333` wraps every returned history pointer in an **owning** `HandleGuard`.

`getSessionsJson()` at `:559-573` serializes those guards and then lets their destructors release every handle.

`getLastSessionJson()` at `:575-580` similarly creates an owning guard for the returned history handle and releases it on return.

Neither path checks `retainedSessionHandles` before releasing a handle whose session ID is actively Running.

Thus the bridge contains both:

- a rule saying release of a Running handle requests cancellation; and
- read-only history code that performs exactly that release.

## React Native Web has the same behavior

`react-native/src/platform/backend.web.ts:268-328`:

1. calls the native/Wasm history-list export;
2. snapshots every returned pointer;
3. unconditionally calls `ffmpeg_kit_handle_release(pointer)` for every history pointer.

`getLastSessionJson()` at `:432-444` wraps the returned pointer in `withTemporaryHandle()`, which releases it at `:176-199`.

The Web backend already maintains `this.sessions` / `executingSessions` specifically to retain active execution handles, but the list/last-session path does not use that ownership knowledge.

By contrast, single-session `withSession()` at `:170-174` is safe: it borrows the retained active pointer when present.

## Consequence

These public APIs can cancel an active RN native or Web session:

```text
FFmpegKitExtended.getSessions()
getFFmpegSessions()
getFFprobeSessions()
getFFplaySessions()
getMediaInformationSessions()
getLastSession()
typed getLast*Session()
FFplayKit.getFFplaySessions()
```

The API appears observational but can mutate execution state.

## Required remediation

Do not restore the incorrect Review 31 mirror that pruned Created sessions. Instead implement a correct bounded history identity authority.

Preferred properties:

- known wrapper-created session IDs/types are recorded at creation;
- active IDs are resolved through borrowed retained execution handles;
- Created/terminal IDs may use temporary handles only where release is safe;
- terminal pruning follows frozen native history semantics;
- Created/Running sessions are not discarded merely because terminal history capacity is exceeded;
- creation/last ordering is preserved;
- `setSessionHistorySize()` and `clearSessions()` reconcile the identity index;
- native and Web backends expose the same results;
- no repeated history read accumulates unreleased Running handles;
- no lifetime-unbounded ID shadow returns.

The existing frozen native exports are sufficient to remain ABI-compatible. If a contradiction appears, record it as a blocker rather than modifying the ABI.

---

# R33-F3 — React Native native state polling serializes complete logs/output every 50 ms

**Severity: Medium-High**

## Hot path

`Session.monitor()` polls native state every **50 ms** by default:

```text
react-native/src/session.ts:361-368
```

Each iteration calls:

```text
state = this.getState();
```

at `:533-551`.

`Session.getState()` prefers the backend's `getSessionState()` method.

## Web implementation is efficient

React Native Web implements the scalar operation directly:

```ts
getSessionState(sessionId) {
  return this.withSession(
    sessionId,
    pointer => numberResult(this.call('ffmpeg_kit_session_get_state')(pointer)),
  );
}
```

at `react-native/src/platform/backend.web.ts:405-410`.

## Native implementation serializes the entire session

The native proxy synthesizes `getSessionState()` as:

```ts
const json = NativeFFmpegKitExtended.getSessionJson(sessionId);
return JSON.parse(json).state;
```

at `react-native/src/platform/backend.native.ts:45-50`.

The C++ `sessionJson()` implementation does much more than read state. At `react-native/cpp/FFmpegKitDynamicApi.cpp:274-314` it fetches and serializes:

- session ID and state;
- return code and timestamps;
- command;
- **complete output**;
- **complete logs as one string**;
- fail stack;
- log/statistics counts;
- debug state;
- session type.

In particular:

```cpp
const auto output =
    takeString(resolve<GetString>("ffmpeg_kit_session_get_output")(handle));
const auto logs =
    takeString(resolve<GetString>("ffmpeg_kit_session_get_logs_as_string")(handle));
```

This happens on the normal state-monitor path roughly twenty times per second.

## Consequence

For a long-running FFmpeg process whose output/log history grows over time, the monitor repeatedly materializes, copies, escapes, serializes, crosses the native/JS boundary with, and parses the complete accumulated log/output payload merely to read one integer state.

If retained log size grows roughly with execution time, repeatedly copying the entire accumulated history creates cumulative work that can approach quadratic growth in output volume/time.

This also undermines the earlier direct-log design goal: steady-state delivery may avoid indexed history polling, while the state monitor still copies complete logs through `getSessionJson()`.

Potential effects include:

- unnecessary C++ allocation/copy cost;
- bridge traffic and JS JSON parsing;
- GC pressure;
- UI/runtime contention on verbose/long-running jobs;
- disproportionate performance degradation as logs grow.

## Required remediation

Add a **wrapper-module scalar state method**, not a native ABI change.

The frozen FFmpegKit ABI already exposes `ffmpeg_kit_session_get_state`; the C++ dynamic bridge already calls it inside `sessionJson()`.

Luna should expose a semantic `getSessionState(sessionId)` through the RN TurboModule/C++/Windows wrapper surface and implement it by:

1. acquiring/borrowing the session through existing ownership-safe `acquireSession`;
2. calling `ffmpeg_kit_session_get_state` directly;
3. returning only the integer state.

Then remove the native proxy's JSON fallback as the primary native implementation.

Keep a compatibility fallback only if required by a supported codegen/module configuration, and ensure the normal native monitor uses the scalar path.

No frozen FFmpegKit ABI change is needed.

---

# Reviewed non-findings retained

The Review 32 native-session-ID queue reservation is internally coherent in the audited single wrapper runtime: reservations are removed on discard and settlement, and the RN synchronous-executor failure path now converges on active cleanup.

The Review 31/32 transactional artifact-cache/download staging changes did not produce another correctness issue meeting the Review 33 threshold.

React Native Apple FFplay previous-owner invalidation and frame coalescing remain present.

Flutter FFplay owner fallback, Web playback epoch, Linux frame-notification coalescing, and fullscreen cleanup remain present.

No new native ABI or builder defect was established because Review 33 intentionally did not re-review native source.

---

# Review 33 closeout

```text
Wrapper snapshot authority: VERIFIED
Wrapper manifest: 1057/1057
Native ABI downloaded for Review 33: NO
Native ABI re-reviewed: NO
Code review only: YES
Tests/builds/runtime executed: NO
Substantive findings: 3
Pedantic/style/docs-only findings reported: 0
Native ABI change required: NO
Repository mutation during review: NO
Promotion unchanged: NOT RECOMMENDED before R33-F1..F3 remediation
```
