# Review 38 — Flutter + React Native Cross-Platform Code Review

**Project:** FFmpegKitExtended  
**Review type:** frozen-source code review; pedantic and procedural findings excluded  
**Date:** 2026-09-29  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Frozen wrapper source:** `aa3010bf335f36daeb64231ba154f9b662d496a6`  
**Snapshot workflow:** `36637678845`  
**Snapshot artifact:** `review37-repo-source-snapshot-36637678845`  
**Artifact ID:** `11064483674`  
**Artifact digest:** `sha256:f1966c0e8cb1832be952c764135755917e06c96522c51831011e7b22476a1852`  
**Embedded `source.tar.gz` SHA-256:** `d73de836c2c5bb340ddb03771aad2ffe0b00007a858d5e0963b8457445990e52`  
**Manifest:** **1,067/1,067 files verified**  
**Symlinks:** `0`  
**Submodule:** `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`  
**Native ABI/runtime:** `0.11.2`, frozen/read-only; not downloaded or re-reviewed independently

---

# 1. Review boundary

Review 38 uses only the final Review 37 wrapper source snapshot recorded in
`.agent/TRACKER.md`.

The source artifact was downloaded through the repository source-snapshot
workflow path and verified before review.

This was **code review only**:

- no Flutter/Dart tests were run;
- no Node tests were run;
- no C/C++ syntax/build commands were run;
- no platform builds were run;
- no browser/runtime smoke was run;
- no simulator/device execution was run;
- no interactive Flutter or React Native application was launched;
- no hosted CI acceptance workflow was run;
- no repository source was mutated.

The native ABI is frozen. Review 38 did not perform a new native source review.
The recursively materialized `libs/libffmpegkit` tree was treated only as
snapshot provenance and was not used as a new review surface.

Excluded from Review 38 findings:

- naming/style/formatting;
- documentation-only differences;
- process/tracker/procedural issues;
- missing-test-only observations;
- speculative hardening without a reachable product effect;
- low-impact pedantry.

The fresh review first checked Review 37's changes around restored completion,
queue settlement, and abandonment reconciliation. It then reviewed the adjacent
Flutter and React Native ownership, cancellation, history, callback-demand,
FFplay, and artifact-staging surfaces for substantive regressions.

---

# 2. Snapshot verification

The frozen artifact matched the Review 37 tracker authority.

```text
Outer artifact ZIP SHA-256:
f1966c0e8cb1832be952c764135755917e06c96522c51831011e7b22476a1852

Embedded source.tar.gz SHA-256:
d73de836c2c5bb340ddb03771aad2ffe0b00007a858d5e0963b8457445990e52

snapshot_sha:
aa3010bf335f36daeb64231ba154f9b662d496a6

runtimeExecution:
false

recursive submodule:
b74da2c5d1e294b87d15d73a6687393729e932b3 libs/libffmpegkit

manifest:
1067/1067 verified

symlinks:
0
```

The production delta from the prior Review 36 wrapper snapshot is concentrated
in:

```text
flutter/lib/src/callback_manager.dart
flutter/lib/src/ffmpeg_kit_extended.dart
flutter/lib/src/ffmpeg_session.dart
flutter/lib/src/ffplay_session.dart
flutter/lib/src/ffprobe_session.dart
flutter/lib/src/media_information_session.dart
flutter/lib/src/session.dart
flutter/lib/src/session_history_index.dart
flutter/lib/src/session_queue_manager.dart

react-native/src/platform/backend.native.ts
react-native/src/platform/backend.web.ts
react-native/src/platform/web/session-history-registry.ts
```

The accompanying changed tests were inspected as supporting context only; they
were not executed and they are not the basis of a finding by themselves.

---

# 3. Executive disposition

The frozen Review 37 wrapper is **not code-review clean**.

Review 38 found three substantive wrapper defects.

| ID | Severity | Surface | Finding |
| --- | --- | --- | --- |
| **R38-F1** | **High** | Flutter native + Web | Restored Running sessions can be inserted into `CallbackManager`, but their local completion/log/statistics sinks do not acquire the process-global callback bridge leases required to receive events. Delivery therefore depends on unrelated bridge demand. |
| **R38-F2** | **Medium-High** | Flutter + React Native native + React Native Web | Cancellation is not durably recorded by session ID when state classification fails. A transient state-read error can leave only an object-local cancellation bit; later wrapper reconstruction can revive a Created session as executable. |
| **R38-F3** | **Medium-High** | Flutter + React Native native + React Native Web | Review 37's periodic tombstone reconciliation is not actually bounded under the observed frozen-ABI behavior. Persistent Created tombstones are rescanned in full every 32 abandonments, producing unbounded metadata plus approximately quadratic cumulative synchronous backend work. |

No Review 38 finding requires changing the frozen native ABI source.

---

# 4. R38-F1 — Restored Flutter sinks do not own callback bridge demand

**Severity:** High  
**Surface:** Flutter native and Web  
**Affected session families:** FFmpeg, FFprobe, MediaInformation, FFplay

## 4.1 Review 37 fixed settlement after a callback arrives

Review 37 added a terminal-observation owner for restored Running sessions.

`flutter/lib/src/callback_manager.dart` now performs:

```text
claimCompletionDispatch()
-> observeTerminalCompletion()
-> beginCompletionDispatch()
-> local callback
-> global callback
-> endCompletionDispatch()
-> settleRestoredCompletionObservation()
```

`Session.settleRestoredCompletionObservation()` then lets a restored wrapper
unregister its completion-only routing and commit a callback-requested deferred
dispose without waiting for `SessionQueueManager`.

That solves the **post-delivery settlement** gap from Review 37.

The remaining problem is one step earlier:

> A restored observer does not reliably activate the platform callback bridge
> that would deliver the event in the first place.

## 4.2 Restored callback registration only inserts a Dart map entry

The generic restored-sink boundary is:

```text
flutter/lib/src/session.dart:369-386
```

Conceptually:

```dart
void ensureRoutingForSinkDemand(void Function() register) {
  if (isDisposed) return;
  if (hasPendingExecutionRouting) {
    register();
    return;
  }
  if (!isRestoredSession) return;
  if (executionStateForSubmission() == SessionState.running) {
    register();
  }
}
```

For a restored Running wrapper, this calls only `register()`.

Concrete completion setters follow that path.

For FFmpeg:

```text
flutter/lib/src/ffmpeg_session.dart:294-306
```

`setCompleteCallback()` invokes `_ensureRegisteredForSinkDemand()`.

That eventually reaches:

```text
flutter/lib/src/ffmpeg_session.dart:781-784
```

which calls the generic restored routing seam.

Equivalent registration exists for FFprobe, MediaInformation, and FFplay.

The resulting `CallbackManager` registration functions are only map insertion:

```text
flutter/lib/src/callback_manager.dart:503-518
```

```dart
ffmpegSessions[session.sessionId] = session;
ffprobeSessions[session.sessionId] = session;
ffplaySessions[session.sessionId] = session;
mediaInformationSessions[session.sessionId] = session;
```

They do not install any process-global native/Web callback bridge.

## 4.3 Bridge installation is lease-driven elsewhere

`CallbackManager` explicitly describes callback bridges as demand-driven.

The bridge is installed only when the first lease is acquired:

```text
flutter/lib/src/callback_manager.dart:104-120
```

Normal locally submitted FFmpeg execution acquires the completion lease through:

```text
flutter/lib/src/ffmpeg_session.dart:716-723
```

```dart
acquireBridgeLease(
  CallbackBridgeKind.ffmpegCompletion,
  install: ffmpegKitBackend.configureFFmpegSessionCompleteCallback,
  uninstall: ffmpegKitBackend.disableFFmpegSessionCompleteCallback,
);
```

The FFprobe/MediaInformation and FFplay paths have equivalent execution-owned
completion leases.

Those execution lease methods are reached from the local async execution paths.
A restored observer is intentionally **not** a local queue execution, so it
never takes that path.

## 4.4 Restored log and statistics demand is also inert

The gap is broader than the completion callback.

FFmpeg log bridge synchronization uses:

```text
flutter/lib/src/ffmpeg_session.dart:725-731
```

and only acquires optional bridge demand if:

```text
hasExecutionStarted && !hasExecutionSettled
```

Statistics uses the same `hasExecutionStarted` requirement.

A restored Running wrapper has not been submitted by the local queue and never
called `markExecutionStarted()`.

Therefore this sequence:

```text
get/history restores Running FFmpeg session
-> setLogCallback(...)
-> ensureRoutingForSinkDemand() registers the wrapper
-> _syncLogBridgeLease()
-> hasExecutionStarted == false
-> no log bridge lease
```

leaves the local sink mapped but unable to create transport demand.

FFplay and FFprobe/MediaInformation use the same execution-start gating for
their local log bridge lease.

## 4.5 Observable behavior depends on unrelated sessions

If no other owner exists for the corresponding process-global bridge:

```text
restored Running wrapper
-> local completion/log/stat sink attached
-> CallbackManager map contains the session
-> platform bridge is not installed
-> native/Web event never enters CallbackManager
```

The callback silently does not run.

Review 37's new restored-completion settlement code is therefore unreachable in
the exact case it was intended to support.

If an unrelated locally submitted session or global callback happens to hold
the same bridge lease, the process-global bridge is already installed and the
restored callback can start working.

That makes restored callback behavior depend on unrelated application activity.

Example:

```text
A = restored Running FFmpeg session with complete callback
B = unrelated locally submitted FFmpeg session

B active:
  ffmpegCompletion bridge installed
  A completion may be routed

B settles first:
  last completion lease can be released
  A is still Running
  A completion may now be lost
```

The same coupling applies to log/statistics bridge demand.

## 4.6 Consequences

Production effects include:

- restored completion callbacks that never fire;
- restored log callbacks that never receive live events;
- restored FFmpeg statistics callbacks that never receive live events;
- terminal-history observation from Review 37 never running when the completion
  event is not transported;
- callback-map strong ownership potentially remaining until explicit manual
  cleanup;
- native/Web behavioral differences depending on unrelated bridge leases;
- non-deterministic behavior when another session starts or settles.

This is not a test-only issue. It follows directly from the source ownership
model:

```text
map registration != bridge lease acquisition
```

## 4.7 Required remediation direction

Restored observation needs its own callback-demand ownership, independent from
queue execution ownership.

Do not set `markExecutionStarted()` merely to make existing lease code run.
That would falsely represent observer-only sessions as locally submitted
executions.

Introduce explicit restored-observer bridge demand.

For completion:

```text
restored Running + local completion sink
-> register session routing
-> acquire session-owned completion bridge lease
-> receive terminal completion
-> local/global fan-out
-> restored completion settlement
-> release restored completion lease
-> unregister completion routing when otherwise idle
```

For log/statistics:

```text
restored Running + local sink
-> register session routing
-> acquire matching optional bridge lease
-> keep lease while sink remains and native state is observable as Running
-> release on sink removal, terminal observation, dispose, or routing teardown
```

Use the same process-global `CallbackManager.acquireBridge()` refcount authority
already used by queue-owned execution. Do not create a second platform bridge
registry.

---

# 5. R38-F2 — State-read failure can still erase cancellation durability

**Severity:** Medium-High  
**Surface:** React Native native/Web; Flutter restored Created wrappers

Review 36 introduced ID-scoped abandonment specifically to prevent a cancelled
Created session from being reconstructed into a fresh executable wrapper.

That protection still depends on successful state classification in important
paths.

## 5.1 React Native records only object-local cancellation before state lookup

`react-native/src/session.ts:161-177` performs:

```ts
this.cancelled = true;

if (SessionQueueManager.shared.cancelQueued(this)) {
  return;
}

const state = this.getState();

if (state === SessionState.Created) {
  this.abandonCreatedSession();
  return;
}

if (state === SessionState.Running) {
  this.dispatchNativeCancellation();
}
```

There is no ID-scoped cancellation/abandonment authority committed before
`getState()`.

If `getState()` throws:

```text
cancelled == true on this JavaScript object
backend tombstone == absent
native session may still be Created
```

The cancellation call throws, but the wrapper-level anti-resurrection authority
was never established.

## 5.2 React Native direct lookup immediately creates a fresh wrapper

Public lookup is:

```text
react-native/src/ffmpeg-kit-extended.ts:168-172
```

```ts
return parseSessionJson(
  NativeFFmpegKitExtended.getSessionJson(sessionId),
);
```

When no tombstone exists, a later successful state/snapshot lookup can return
the same Created native ID.

`sessionFromSnapshot()` then constructs a new concrete wrapper:

```text
react-native/src/session.ts:1076-1087
```

The new wrapper gets default object-local lifecycle state:

```text
cancelled = false
submitted = false
createdSessionAbandoned = false
```

Therefore this sequence is reachable:

```text
create or restore Created session A
-> A.cancel()
-> backend state read throws
-> A.cancelled is true, but ID has no tombstone
-> FFmpegKitExtended.getSession(A.id)
-> state read/snapshot now succeeds
-> fresh wrapper B has cancelled == false
-> B.executeAsync()
-> prepareForExecution sees no tombstone and Created state
-> native execution can start
```

A transient state transport error can therefore undo an explicit cancellation.

This applies to React Native native and Web because both share the Session
lifecycle and backend-level tombstone gate.

## 5.3 Flutter has the same gap for restored Created wrappers

Flutter protects a newly created, non-restored session before any state read:

```text
flutter/lib/src/session.dart:1099-1103
```

```dart
if (!_submitted && !_restoredFromHandle) {
  FFmpegKitExtended.abandonCreatedSession(sessionId);
  _cleanupCancelledBeforeStart();
  return;
}
```

That path is durable.

A restored wrapper intentionally skips it.

The restored path reads native state at:

```text
flutter/lib/src/session.dart:1105-1118
```

On state-read failure it:

- logs the error;
- starts a cancellation retry monitor only if `_executionStarted` is true;
- rethrows.

A restored history wrapper is not a local queue execution, so
`_executionStarted` is normally false.

No abandonment tombstone is installed.

If the restored wrapper represented a Created native session and the state read
failed transiently:

```text
_isCancelled == true only on that Dart object
SessionHistoryIndex tombstone == absent
```

The history index owns only a weak wrapper reference.

Once the cancelled wrapper is no longer strongly referenced, a later history
lookup can reconstruct the same Created native ID with a new wrapper whose
`_isCancelled` field is false.

`validateExecutionHandoff()` blocks only:

```text
ID tombstone
OR current wrapper _isCancelled
OR non-Created native state
```

so the reconstructed wrapper can execute if the state oracle has recovered.

## 5.4 Why simply tombstoning every cancel is not sufficient

Cancellation may target:

- Created work that must become non-executable;
- Running work that should dispatch native cancellation and remain inspectable;
- terminal work where cancellation has no execution effect;
- a restored wrapper whose state cannot currently be read.

A robust fix needs an ID-scoped **cancellation intent authority** distinct from
the narrower **Created abandonment/history hiding authority**.

Do not hide a Running session from history merely because the user asked it to
cancel.

The wrapper needs to remember:

```text
cancel was requested for this ID
```

before a fallible state read.

Then state classification can refine the authority:

```text
Created
-> promote to Created abandonment
-> hide/fail closed for reconstruction/execution

Running
-> keep cancellation intent
-> dispatch/retry native cancellation
-> history remains inspectable

Completed/Failed
-> execution already terminal
-> cancellation intent can be reconciled/cleared

state read failed
-> retain ID-scoped cancellation intent
-> fail closed for future execution/reconstruction until classification succeeds
```

## 5.5 Required remediation direction

Flutter and React Native should share the semantic rule:

> An explicit cancellation request cannot become executable again merely because
> the state oracle failed between recording intent and classifying the native
> session.

For React Native, add durable ID-scoped cancellation intent before `getState()`.

For Flutter, extend the existing history authority so restored sessions can
record cancellation intent before the restored-state read.

Avoid retaining wrapper objects or native handles solely for this purpose.

---

# 6. R38-F3 — Periodic tombstone reconciliation becomes quadratic without reclaiming normal abandoned Created IDs

**Severity:** Medium-High  
**Surface:** Flutter + React Native native + React Native Web  
**Primary effect:** long-running cancellation/discard performance and metadata growth

Review 37 attempted to make abandonment tombstones lifecycle-bounded by probing
the underlying session every 32 abandonment events.

The code is fail-closed, but under the exact frozen runtime behavior recorded in
the Review 37 tracker, the periodic algorithm does not bound the dominant
tombstones.

It instead creates increasing synchronous maintenance cost.

## 6.1 Flutter scans the entire tombstone set every 32 events

`flutter/lib/src/ffmpeg_kit_extended.dart` adds:

```dart
static const _abandonmentReconciliationThreshold = 32;
static int _abandonmentEventsSinceReconciliation = 0;
```

Every abandonment increments the counter.

At the threshold, `_reconcileAbandonedCreatedSessions()` executes:

```text
for every abandoned session ID:
    getSessionById(id)
    if absent:
        remove tombstone
    else:
        release temporary observation
        keep tombstone
```

The scan is synchronous from `abandonCreatedSession()`.

## 6.2 React Native native does the same work on the JS/native boundary

`react-native/src/platform/backend.native.ts:4-20` stores all tombstones in a
module-level `Set<number>`.

Every 32 abandonments it iterates a copy of the complete set.

For each ID it calls:

```ts
NativeFFmpegKitExtended.getSessionJson(sessionId)
```

This is heavier than a scalar existence query: the bridge constructs the full
session JSON snapshot, including ordinary snapshot fields, simply to determine
whether the ID exists.

If it exists, the tombstone remains.

## 6.3 React Native Web also scans every tombstone

`react-native/src/platform/backend.web.ts` does the same threshold scan.

For every tombstone it:

```text
ffmpeg_kit_get_session(id)
-> if handle == 0 remove tombstone
-> otherwise ffmpeg_kit_handle_release(handle)
-> keep tombstone
```

Again this is synchronous Wasm work on the JavaScript execution path.

## 6.4 The Review 37 frozen-runtime oracle says normal Created tombstones persist

The Review 37 tracker records the local frozen-runtime result:

```text
a real Created Flutter session remained directly discoverable after explicit
abandonment plus temporary and owner-handle release

two Created identities also remained at history capacity 1

a successful full clear then removed the tombstone
```

That means the ordinary Created IDs produced by the cancellation/queue-discard
path are expected to return **present** during the periodic probe.

So the periodic scan normally does:

```text
probe tombstone 1 -> present -> keep
probe tombstone 2 -> present -> keep
...
probe tombstone N -> present -> keep
```

and then repeats the same work after another 32 abandonments.

## 6.5 Complexity

Let `N` be the number of abandoned Created sessions accumulated since the last
successful full clear.

The tombstone set itself remains O(N).

The periodic scan cost after every 32 events is approximately:

```text
32 + 64 + 96 + ... + N
```

which is approximately:

```text
O(N² / 32)
```

backend existence operations over the lifetime of the process.

For 32,000 abandoned sessions, the maintenance loop performs on the order of
16 million tombstone probes even though the recorded native behavior tells us
those Created identities are expected to survive.

The exact constant differs by wrapper:

- Flutter: backend handle lookup + temporary release;
- RN native: full JSON snapshot call per tombstone;
- RN Web: Wasm lookup + handle release.

## 6.6 User-visible consequences

In applications that frequently create and cancel queued work:

- cancellation/discard latency increases over process lifetime;
- every 32nd cancellation can synchronously scan thousands of IDs;
- RN native performs increasingly many full snapshot serializations;
- Web performs increasingly many Wasm boundary calls;
- Flutter performs increasingly many FFI handle lookups/releases;
- tombstone memory remains unbounded until full clear anyway.

The code therefore pays an increasing maintenance cost without solving the
dominant retention case.

## 6.7 What is and is not fixable with the frozen ABI

The exact anti-resurrection requirement is correct:

> Do not delete a tombstone while the underlying Created ID remains directly
> reconstructable.

If the frozen ABI keeps an abandoned Created session discoverable until full
clear, an exact wrapper anti-resurrection authority may need to remember that ID
until full clear.

Review 38 does **not** recommend weakening that protection.

The avoidable defect is the repeated all-tombstone scan.

The wrapper can distinguish:

```text
known-live persistent tombstone
candidate that may have disappeared
```

and only probe candidates after a lifecycle event that can plausibly make them
absent.

At minimum, do not repeatedly probe the same known-present Created ID every 32
unrelated abandonment events.

If the frozen ABI provides no per-session reclamation event, explicitly accept
the residual O(N) ID-only memory until `clearSessions()` rather than adding
O(N²) maintenance work that cannot reclaim it.

---

# 7. Review 37 fixes that remain valid

The following Review 37 changes did not expose a new substantive defect in their
core intended behavior:

- restored completion dispatch now has an independent post-delivery settlement
  owner rather than waiting forever for local queue settlement;
- a callback-requested Flutter disposal can wait through local/global completion
  fan-out;
- queue-owned Flutter settlement captures executor and settlement failures before
  resolving the public queue Future;
- queue active-session and native-ID reservation cleanup happens even when
  settlement fails;
- RN native tombstones are now cleared only after the underlying clear succeeds;
- Flutter production clear now clears abandonment authority after backend clear
  success;
- React Native Web clear remains fail-closed when the underlying clear fails;
- direct abandoned-session lookup/execution remains fail-closed while a
  tombstone is present.

R38-F1 concerns **transport demand before restored completion arrives**, not the
new post-delivery settlement logic itself.

R38-F3 concerns the periodic maintenance algorithm, not the correctness of
keeping a still-live tombstone.

---

# 8. Fresh retained non-findings

The fresh cross-platform pass found no additional issue meeting the Review 38
non-pedantic/non-procedural threshold in:

- Flutter FFplay playback-epoch ownership;
- Flutter process-global FFplay owner replacement;
- Flutter fullscreen failure-atomic cleanup;
- Flutter desktop/Linux texture registration and frame-notification coalescing;
- React Native Apple/Windows FFplay frame-owner replacement;
- React Native scalar session-state monitoring;
- React Native Web MediaInformation-vs-FFprobe classification;
- native-session-ID duplicate queue reservation;
- Flutter hook local artifact cache transactionality;
- React Native artifact download staging;
- React Native Windows runtime extraction transactionality;
- local artifact resolver fail-closed behavior.

No native/builders issue was established because the frozen native ABI was not a
Review 38 source-review surface.

---

# 9. Review 38 remediation goals

| Goal | Required result |
| --- | --- |
| **R38-G1** | Give restored Running Flutter observers explicit completion/log/statistics bridge leases so delivery never depends on unrelated bridge owners |
| **R38-G2** | Make cancellation intent durable by native session ID before fallible state classification in Flutter restored sessions and React Native native/Web |
| **R38-G3** | Replace all-tombstone periodic scanning with event/candidate-driven reconciliation and explicitly preserve the irreducible frozen-ABI tombstone residual until clear |
| **R38-G4** | Run focused and affected local wrapper regression using only existing frozen `0.11.2` artifacts |
| **R38-G5** | Reconcile exact evidence, freeze the wrapper SHA, and create one wrapper-only source snapshot |

The accompanying Luna plan provides file-level implementation guidance,
invariants, test oracles, failure-order requirements, and the local-only
cross-platform validation order.

---

# 10. Review 38 closeout

```text
Wrapper snapshot authority: VERIFIED
Outer artifact digest: VERIFIED
Embedded source archive: VERIFIED
Wrapper manifest: 1067/1067
Symlink state: VERIFIED (0)
Frozen submodule provenance: VERIFIED

Native ABI separately downloaded for Review 38: NO
Native ABI re-reviewed: NO

Code review only: YES
Tests/builds/runtime executed during review: NO
Repository mutation during review: NO

Substantive findings: 3
Pedantic findings reported: 0
Procedural findings reported: 0
Documentation-only findings reported: 0

Native ABI source change required: NO

Promotion unchanged:
NOT RECOMMENDED before R38-F1 and R38-F2 are corrected and R38-F3's
quadratic maintenance behavior is removed or explicitly bounded without
weakening anti-resurrection semantics.
```
