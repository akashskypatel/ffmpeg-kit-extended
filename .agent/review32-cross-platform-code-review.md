# Review 32 — Flutter + React Native Cross-Platform Code Review

Repository: `akashskypatel/ffmpeg-kit-extended`  
Review date: 2026-09-24  
Review type: source-only code review  
Frozen wrapper source: `a3017c2f2415a5ad5052f54f4382a2c2ff910dd9`  
Snapshot workflow: `36082816715`  
Snapshot artifact: `review31-final-wrapper-source-36082816715`  
Artifact ID: `10842616283`  
Artifact digest: `sha256:858e7eecbc4bff2933d3442e9dd9ecdbc37fb237805cb2b01776b661539fcdab`  
Embedded `source.tar.gz` SHA-256: `dd8553b84c92ed49f0e4b7c5f9e3470b9906fe5b15554088d6f8a2a012de2863`  
Manifest: **1,055/1,055 files verified**

## Review boundary

This review used only the final Review 31 wrapper snapshot. The native/builder snapshot was intentionally not downloaded or re-audited because the native ABI is frozen and read-only. No tests, builds, hosted CI, simulators/devices, interactive runtime execution, or repository mutation were performed. Style, naming, formatting, documentation-only drift, missing-test-only observations, and speculative hardening were excluded. Review 31 remediation was treated as baseline.

## Executive disposition

The frozen wrapper is not code-review clean. Three substantive wrapper defects were found:

| ID | Severity | Surface | Finding |
| --- | --- | --- | --- |
| R32-F1 | Medium-High | Flutter + React Native | Execution admission is wrapper-object scoped instead of native-session-ID scoped, allowing multiple wrappers for one Created native session to reach duplicate execution handoff. |
| R32-F2 | Medium-High | React Native | `SessionQueueManager` does not enforce unique active/queued identity and does not unwind active accounting when an executor throws synchronously. |
| R32-F3 | Medium | React Native native bridge | Review 31’s bounded history mirror can evict valid Created sessions and alter native history visibility/order. |

No finding requires a native ABI change. Promotion is not recommended before all three findings are remediated.

## R32-F1 — Native-session execution ownership is not unique

### Flutter path

Flutter protects one Dart object with `_submitted` and a native-state check in `flutter/lib/src/session.dart:603-620`. History lookup in `flutter/lib/src/ffmpeg_kit_extended.dart:734-780` can nevertheless create multiple `fromHandle` objects for one native session ID when an inert object is not rooted in `CallbackManager`. The queue rejects duplicate object identity only (`flutter/lib/src/session_queue_manager.dart:79-117`). Two distinct wrappers can therefore both observe `Created`, set their own `_submitted`, enter the queue, and reach native handoff.

### React Native path

React Native reconstructs history wrappers as new objects (`react-native/src/session.ts:1032-1054`), and `submitOnce()` protects only that JavaScript object (`react-native/src/session.ts:644-659`). The native bridge obtains/retains the session and calls the async execution entrypoint without a wrapper-side state or execution-ID guard (`react-native/cpp/FFmpegKitDynamicApi.cpp:514-531`). React Native Web already enforces the missing invariant in `react-native/src/platform/backend.web.ts:201-238`: `retainForExecution()` rejects an executing session ID and requires `Created` state.

### Consequence

One native session ID can have multiple execution claimants. A second handoff may issue a duplicate async execution request, fail after queue/callback ownership is established, diverge between RN native and Web, or complicate cancellation, callback demand, completion ownership, and handle retention. This is distinct from calling the same wrapper object twice.

### Required remediation

Introduce one bounded execution-admission authority keyed by native session ID. Revalidate state at handoff, reject Running/terminal wrappers before native execution, prevent two wrappers for one Created session from reaching startup, release safe queue reservations on discard/cancel, and align RN native/Web behavior. No native ABI change is required.

## R32-F2 — React Native queue accounting is not failure-atomic

`SessionQueueManager` tracks active work in `Set<CancellableSession>` and starts items by adding the object, invoking `item.executor()`, then attaching `.then(...).finally(...)` (`react-native/src/session-queue-manager.ts:47-60,165-175`).

### Duplicate object admission

`executeSession()` does not reject the same object while queued or active. With `maxConcurrentSessions >= 2`, two executions can run while `Set.add()` still counts one active item. The first settlement can delete the sole set entry while the second is still running. This can bypass concurrency limits, corrupt `activeSessionCount`, misrepresent cancellation targets, allow `waitForAll()` to resolve early, and start queued work prematurely.

### Synchronous executor throw

The executor is invoked before a Promise chain is established. A function typed `Promise<T>` may throw before returning one. The item is already removed from the queue and added to `active`; the throw escapes `processQueue()`, so `.finally()` is never attached and the active slot remains permanently occupied. With concurrency one, later work can remain queued and `waitForAll()` can hang.

### Required remediation

Reject duplicate object admission, normalize synchronous throws through the same cleanup path as asynchronous rejection, preserve the original error/result, remove active membership exactly once, process the next item exactly once, and guarantee no capacity leak. Preserve Review 31 all-target/first-error cancellation behavior.

## R32-F3 — Bounded history mirror can evict Created sessions

Review 31 replaced the unbounded `knownSessionIds` vector with a bounded deque/set. The current pruning rule in `react-native/cpp/FFmpegKitDynamicApi.cpp:246-257` removes the first known ID that is not present in `retainedSessionHandles` until the mirror reaches native history capacity. New sessions are recorded immediately (`:447-457`), but their temporary creation handles are released while they remain `Created`, so they are unprotected by the retained-handle set.

With native capacity ten, creating eleven unstarted sessions can prune the oldest Created ID from the wrapper mirror even though native history still contains it. `getSessionsJson()` and `getLastSessionJson()` enumerate the mirror, so valid sessions can disappear and later reinsertion when execution begins can falsely alter last-session ordering.

### Required remediation

Prefer native history as the authority through existing frozen-ABI exports. If a mirror remains, prove that Created/Running entries are not evicted merely because an execution handle is not retained, terminal pruning follows native capacity semantics, native ordering is preserved, history-size changes and `clearSessions()` reconcile state, storage remains bounded, and no unbounded historical shadow returns. Do not add or modify a native export.

## Flutter-specific disposition

Beyond the cross-wrapper execution-ownership defect in R32-F1, the reviewed Flutter lifecycle, callback ownership, FFplay coordination, Web playback epoch, and Review 31 artifact-cache changes produced no additional finding meeting the non-pedantic threshold.

## Closeout status

```text
Wrapper snapshot authority: VERIFIED
Wrapper manifest: 1055/1055
Native ABI downloaded for Review 32: NO
Native ABI re-reviewed: NO
Code review only: YES
Tests/builds/runtime executed: NO
Substantive findings: 3
Pedantic/style/docs-only findings reported: 0
Native ABI change required: NO
Repository mutation during review: NO
Promotion: NOT RECOMMENDED before R32-F1..F3 remediation
```

## Remediation disposition

The pre-remediation review disposition above is retained as the review-time baseline. Review 32 subsequently resolved all three substantive findings in the wrapper: native-session-ID execution ownership, transactional React Native queue admission/cleanup, and native-authoritative history enumeration. Focused Flutter/React Native regressions, package gates, and ordered local Windows, Android, WSL Linux, Wasm/Web, and MacBook Air Apple validation passed against the existing local ABI artifacts. No native ABI change, `libs/libffmpegkit` change, ManyLinux builder change, remote binary retrieval, hosted acceptance workflow, or interactive runtime claim was introduced.

Promotion remains subject only to the exact wrapper SHA freeze and the single wrapper-only source snapshot required by the implementation plan.
