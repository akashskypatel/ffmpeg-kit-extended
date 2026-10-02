# Review 37 — Flutter + React Native Cross-Platform Code Review

**Project:** FFmpegKitExtended  
**Review type:** frozen-source code review; pedantic findings excluded  
**Date:** 2026-09-29  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Frozen wrapper source:** `421946a3279e055a27a3dbd9141234e305f70e5d`  
**Snapshot workflow:** `36596072158`  
**Snapshot artifact:** `repo-source-snapshot-36596072158`  
**Artifact ID:** `11046296370`  
**Artifact digest:** `sha256:098a410ad4fbce40283400d8fe3b9fd37b9dab44e5fe71e933e736460e6cc387`  
**Embedded `source.tar.gz` SHA-256:** `30078df4081dbbcbd79fd3974a23a2b75474cfdada028c0c304f99416a4f0cdd`  
**Manifest:** **1,066/1,066 files verified**  
**Submodule:** `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`  
**Native ABI/runtime:** `0.11.2`, frozen/read-only; not downloaded or re-reviewed

## Review boundary

Review 37 uses only the final Review 36 wrapper snapshot recorded in
`.agent/TRACKER.md`.

This was **code review only**:

- no Flutter/Dart test execution;
- no Node test execution;
- no compilation or builds;
- no hosted CI;
- no browser/runtime smoke;
- no simulator/device execution;
- no repository mutation.

Excluded from findings:

- style, formatting, and naming;
- documentation-only drift;
- missing-test-only observations;
- speculative hardening;
- low-impact pedantry.

The Review 36 completion-lifetime and Created-abandonment implementation was
reviewed first. A fresh risk pass then covered session ownership, history,
cancellation, queue transactions, restored-session callbacks, FFplay lifecycle,
and artifact staging/resolution. The frozen native ABI was not downloaded or
re-reviewed.

---

# Snapshot verification

The downloaded workflow artifact matched the tracker authority exactly.

```text
Outer ZIP SHA-256:
098a410ad4fbce40283400d8fe3b9fd37b9dab44e5fe71e933e736460e6cc387

Embedded source.tar.gz SHA-256:
30078df4081dbbcbd79fd3974a23a2b75474cfdada028c0c304f99416a4f0cdd

snapshot_sha:
421946a3279e055a27a3dbd9141234e305f70e5d

runtimeExecution:
false

submodule:
b74da2c5d1e294b87d15d73a6687393729e932b3 libs/libffmpegkit

manifest:
1066/1066 verified
```

---

# Executive disposition

The frozen Review 36 wrapper is **not code-review clean**.

Review 37 found **three substantive wrapper lifecycle defects**:

| ID | Severity | Surface | Finding |
| --- | --- | --- | --- |
| **R37-F1** | **High** | Flutter | The completion lifetime barrier is queue-dependent. Restored Running sessions can register completion callbacks but have no queue settlement, so callback disposal can remain deferred forever and restored completion has no owner that terminalizes/unregisters the observer lifecycle |
| **R37-F2** | **High** | Flutter | A deferred disposal release failure can escape `markExecutionSettled()` before queue active/reservation cleanup, stranding the queue and potentially losing the release error after the user execution Future has already completed |
| **R37-F3** | **Medium-High** | Flutter + React Native native + React Native Web | Created-session abandonment tombstones are not lifecycle-bounded as designed; Flutter production `clearSessions()` does not clear them at all, while RN native/Web retain them until a full clear and do not reconcile tombstones when the underlying native ID disappears |

No finding requires a frozen-native ABI source change.

---

# R37-F1 — Restored Flutter completion has no settlement owner

**Severity: High**

**Surface:** Flutter native and Web wrappers

Review 36 added a completion lifetime scope around local and global completion
fan-out:

```text
CallbackManager.dispatch*Complete()
-> session.beginCompletionDispatch()
-> local completion callback
-> global completion callback
-> session.endCompletionDispatch()
```

`Session.dispose()` now defers physical release while that scope is active:

```text
flutter/lib/src/session.dart:228-238
```

```dart
if (_completionDispatchDepth > 0) {
  _disposeRequested = true;
  return;
}
```

The deferred release is allowed to commit only when:

```text
_completionDispatchDepth == 0
AND _executionSettled == true
```

at:

```text
flutter/lib/src/session.dart:519-528
```

That is correct for sessions owned by `SessionQueueManager`, because queue
settlement eventually calls `markExecutionSettled()`.

It is not correct for restored Running sessions.

## Restored Running sessions are explicitly callback-capable

History/session restoration creates `Session.fromHandle(... restoredSession:
true)` wrappers.

For restored wrappers, `ensureRoutingForSinkDemand()` explicitly permits
callback registration when native state is Running:

```text
flutter/lib/src/session.dart:360-385
```

Concrete `setCompleteCallback()` methods route through that seam:

```text
FFmpegSession._ensureRegisteredForSinkDemand()
FFprobeSession.ensureRegisteredForSinkDemand()
FFplaySession._ensureRegisteredForSinkDemand()
MediaInformationSession equivalent registration path
```

So this is an intended public lifecycle:

```text
get/history restore Running session
-> set completion callback
-> CallbackManager roots the restored wrapper
-> native execution completes elsewhere
-> wrapper receives completion dispatch
```

The existing focused test suite itself establishes that restored Running
sessions may register into the callback maps.

## Restored observers never receive queue settlement

A restored history wrapper was not submitted through this Dart
`SessionQueueManager`.

Therefore:

```text
_submitted == false
_executionSettled == false
```

and no queue-owned `markExecutionSettled()` will ever run.

## Callback disposal now leaks instead of releasing

Reachable sequence:

```text
restore Running session
-> setCompleteCallback()
-> native completion callback arrives
-> CallbackManager.beginCompletionDispatch()
-> user completion callback calls session.dispose()
-> dispose records _disposeRequested and returns
-> global completion callback runs
-> CallbackManager.endCompletionDispatch()
-> _executionSettled is still false
-> deferred release does not commit
-> no queue settlement will ever occur
```

The session remains physically undisposed.

Because the callback manager also owns a strong map reference to registered
sessions, this is not merely a delayed GC finalizer case.

## Restored completion also lacks terminal-history and registration settlement

Normal queue-owned synchronous/async execution commits terminal history before
dispatch and later settles/unregisters through its concrete execution wrapper.

A restored Running observer does not execute those wrappers.

`CallbackManager.dispatch*Complete()` itself currently does **not**:

- commit terminal history;
- declare observer-only completion settled;
- unregister the restored terminal session from the relevant callback map.

Therefore even when the user does not call `dispose()`:

- the wrapper history entry can remain nonterminal;
- terminal-capacity pruning can miss it;
- callback-map ownership can remain after terminal completion unless application
  code manually clears all callbacks;
- the restored owned handle can remain rooted longer than the observed native
  execution.

This is a genuine production lifecycle gap caused by making deferred disposal
depend solely on queue settlement.

## Required remediation

Completion lifetime must distinguish:

```text
queue-owned execution
observer-only restored Running session
```

Both need terminal completion ownership.

A semantic design should provide one terminal-completion boundary that:

1. commits terminal history idempotently;
2. performs local/global completion fan-out while the handle is valid;
3. marks completion observation settled;
4. unregisters terminal callback routing;
5. allows deferred disposal to physically release after fan-out;
6. leaves queue-owned execution reservation/queue cleanup to
   `SessionQueueManager` when a queue actually owns the session.

Do **not** fake queue ownership for restored observers.

Do **not** call `markExecutionSettled()` blindly from `CallbackManager` if doing
so conflates queue reservation state with observer completion.

The lifetime barrier needs an independent concept such as:

```text
completion fan-out active
terminal completion observed
queue settlement required / not required
```

## Required regression coverage

For each concrete session family:

- restore a Running session;
- set a completion callback;
- dispatch terminal completion without submitting through the queue;
- local callback calls `dispose()`;
- global callback still sees a valid terminal session;
- physical release occurs exactly once after fan-out;
- no queue settlement is required;
- callback map no longer roots the terminal restored session;
- terminal history is committed/pruned correctly.

Also prove restored completion without explicit disposal releases callback-map
ownership while preserving the wrapper's explicit handle ownership until the
caller later disposes it, if that remains the selected public contract.

---

# R37-F2 — Deferred release failure can strand Flutter queue ownership

**Severity: High**

**Surface:** Flutter queue-owned execution

Review 36 made callback disposal deferred until queue settlement.

At settlement:

```text
Session.markExecutionSettled()
-> commitTerminalHistory()
-> complete settlement signal
-> _releaseDeferredDisposeIfReady()
-> _disposeNow()
-> releaseHandle()
```

A backend release failure from `_disposeNow()` is intentionally allowed to
throw because failed deterministic disposal remains retryable.

That is reasonable at the session layer.

The queue layer is not failure-atomic around it.

## Queue cleanup happens after `markExecutionSettled()`

`flutter/lib/src/session_queue_manager.dart:185-202`:

```dart
try {
  await queued.executor();
  if (!queued.completer.isCompleted) {
    queued.completer.complete();
  }
} catch (...) {
  ...
} finally {
  queued.session.markExecutionSettled();
  _activeSessions.remove(queued.session);
  _reservedSessionIds.remove(queued.session.sessionId);
  _processQueue();
}
```

If a completion callback called `dispose()`, `markExecutionSettled()` can now
perform the deferred physical release.

If that release throws:

```text
markExecutionSettled() throws
-> _activeSessions.remove is skipped
-> _reservedSessionIds.remove is skipped
-> _processQueue is skipped
```

The queue can remain permanently occupied by an execution that already ended.

## The user's Future may already have been completed

The execution completer is completed **before** the `finally` block.

On successful execution:

```text
queued.completer.complete()
-> markExecutionSettled()
-> deferred release throws
```

So the caller can observe successful execution while:

- physical disposal failed;
- the active session remains stranded;
- its native session ID remains reserved;
- queued work may stop advancing;
- the release failure escapes only through the unobserved
  `_executeQueuedSession()` Future.

This loses error authority and corrupts queue bookkeeping simultaneously.

## Failure after executor rejection has a similar cleanup problem

If the executor already failed, that failure correctly completes the public
completer.

A later deferred-release failure must not replace the primary execution error,
but it also must not prevent active/reservation cleanup.

The current `finally` has no nested cleanup structure to enforce that.

## Required remediation

Make queue settlement a transaction.

Required ordering:

```text
capture executor success/error
-> attempt markExecutionSettled / deferred release
-> ALWAYS remove active session
-> ALWAYS release native-session-ID reservation
-> ALWAYS process later queue items
-> then complete/reject public Future with deterministic error authority
```

Prefer delaying the public completer until settlement cleanup is finished.

Error ordering:

1. executor/execution error remains primary;
2. settlement/deferred-dispose error is secondary if execution already failed;
3. settlement/deferred-dispose error becomes observable if execution succeeded;
4. queue bookkeeping cleanup must run regardless of either error.

Do not swallow a release failure merely to keep the queue moving.

## Required regression coverage

- successful execution + completion callback requests dispose + release succeeds;
- successful execution + deferred release throws;
- execution error + deferred release also throws;
- active set is empty in every terminal case;
- session-ID reservation is released in every terminal case;
- later queued item starts in every terminal case;
- `waitForAll()` terminates;
- successful execution does not complete publicly before a later settlement
  failure that the wrapper intends to surface;
- primary execution error is preserved over release cleanup error.

---

# R37-F3 — Abandonment tombstones are not lifecycle-bounded

**Severity: Medium-High**

**Surface:** Flutter + React Native native + React Native Web

Review 36 introduced ID-only tombstones so an explicitly abandoned Created
session cannot be reconstructed and executed again.

That fail-closed behavior is correct.

The lifetime of the new tombstones is not.

## Flutter

`SessionHistoryIndex` now owns:

```dart
final Set<int> _abandonedSessionIds = <int>{};
```

`abandon()` removes the visible identity and inserts the ID.

`record()` permanently rejects that ID while the tombstone exists.

`SessionHistoryIndex.clear()` would clear both entries and tombstones.

However production `FFmpegKitExtended.clearSessions()` does not call
`_sessionHistoryIndex.clear()` and has no tombstone-specific clear.

It performs:

```text
native clear
-> synchronize live sessions
-> remove/hide entries
```

but abandoned IDs are not entries.

Therefore a Flutter tombstone survives `FFmpegKitConfig.clearSessions()`.

This directly violates the Review 36 acceptance requirement that clearing the
history authority clears abandoned tombstones.

It also means repeated:

```text
create
-> cancel before submission
```

adds one ID forever for the process lifetime even after native history has been
cleared.

## React Native native

`backend.native.ts` owns:

```ts
const abandonedSessionIds = new Set<number>();
```

IDs are added on `abandonCreatedSession()` and removed only by:

```text
clearSessions()
```

There is no reconciliation when the C++ semantic history removes an ID, when
the native registry no longer returns the session, or when native history
capacity evicts it.

The C++ bridge record is removed at abandonment, so the JavaScript tombstone is
a second lifetime authority with no normal pruning event.

### Native clear is also not failure-atomic for tombstone authority

The native proxy currently performs:

```text
abandonedSessionIds.clear()
-> NativeFFmpegKitExtended.clearSessions()
```

If the native clear throws, the wrapper has already forgotten the tombstones
while the native sessions/history may still exist.

Previously abandoned Created IDs can then become reconstructable again.

A fail-closed lifecycle authority should clear tombstones only after the
underlying clear commits.

## React Native Web

`SessionHistoryRegistry` likewise owns:

```ts
private readonly abandonedCreatedIds = new Set<number>();
```

`remove(sessionId)` can delete a tombstone, but normal abandoned IDs have no
remaining visible record to drive `historySnapshots()` reconciliation.

Public lookup fails closed before native lookup, so the Web wrapper never learns
that the underlying ID has disappeared.

Unless the application calls full `clearSessions()`, every abandoned ID remains
in the set.

## Consequence

The Review 36 anti-resurrection authority becomes a process-lifetime append-only
set under ordinary discard-heavy workloads.

Effects include:

- metadata growth proportional to lifetime abandoned sessions;
- divergence from the earlier "live identities + retained terminal capacity"
  bounded-history design;
- Flutter `clearSessions()` not actually clearing all wrapper history authority;
- RN native resurrection risk when a native clear fails after the JS tombstone
  set was already cleared.

This is not a native ABI defect; it is wrapper lifecycle ownership.

## Required remediation

Keep fail-closed abandonment, but add explicit tombstone reconciliation.

### Clear semantics

Flutter:

- after native clear successfully commits, clear abandoned tombstones;
- preserve any live execution identities required by the established
  `clearSessions()` ownership contract;
- do not clear active wrapper ownership merely to clear tombstones.

RN native:

- call native clear first;
- clear JavaScript tombstones only after native clear succeeds;
- preserve tombstones when native clear throws.

RN Web:

- preserve its current fail-closed order;
- ensure tombstones are cleared only after the underlying clear succeeds.

### Normal bounded reconciliation

Do not rely exclusively on full `clearSessions()`.

Use the existing frozen ABI to establish a safe wrapper-only pruning strategy.

Options may include:

- a private existence probe that bypasses the public tombstone gate and removes
  the tombstone only when the native ID is definitively gone;
- reclaiming a Created session through an already-existing frozen ABI operation,
  if a focused local `0.11.2` oracle proves that operation safe;
- reconciling tombstones during abandonment, history-size changes, or bounded
  maintenance without exposing the ID publicly.

Do **not** remove a tombstone merely to satisfy a memory bound while the native
Created session still exists, because that reintroduces Review 36 resurrection.

If the frozen ABI cannot safely reclaim/detect abandoned Created sessions
without a full clear, document that exact residual honestly. Do not modify the
native ABI.

## Required regression coverage

Across Flutter, RN native, and RN Web:

- repeated abandonment does not become unbounded when underlying IDs are gone;
- abandoned ID remains fail-closed while native ID still exists;
- successful `clearSessions()` clears tombstone authority;
- failed `clearSessions()` preserves tombstones;
- ordinary Created sessions remain reconstructable/executable;
- terminal/Running history semantics remain unchanged;
- no wrapper/session object or native handle is strongly retained solely by the
  tombstone authority.

For Flutter specifically, add a production-facade test proving
`FFmpegKitConfig.clearSessions()` clears abandonment authority, not merely a
unit test that calls `SessionHistoryIndex.clear()` directly.

---

# Retained non-findings

The Review 36 queue/native-session-ID anti-resurrection guards are present for
ordinary high-level React Native native/Web execution.

Flutter terminal reconciliation now checks an already-terminal marker before
performing another backend state read.

React Native Web MediaInformation classification remains correctly ordered
before FFprobe.

The scalar RN session-state monitor remains separate from full-session JSON.

The existing native-session-ID duplicate queue reservations remain present.

The previously-remediated FFplay texture/frame ownership, playback epoch,
owner-replacement, fullscreen cleanup, and build-artifact transactional staging
surfaces did not expose another issue meeting the Review 37 non-pedantic
threshold.

No native/builders finding was established because native source was
intentionally frozen and not re-reviewed.

---

# Review 37 closeout

```text
Wrapper snapshot authority: VERIFIED
Outer artifact digest: VERIFIED
Embedded source archive: VERIFIED
Wrapper manifest: 1066/1066
Frozen submodule provenance: VERIFIED
Native ABI downloaded for Review 37: NO
Native ABI re-reviewed: NO
Code review only: YES
Tests/builds/runtime executed: NO
Substantive findings: 3
Pedantic/style/docs-only findings reported: 0
Native ABI source change required: NO
Repository mutation during review: NO
Promotion unchanged: NOT RECOMMENDED before R37-F1..F3 remediation
```
