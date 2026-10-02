# Review 45 — Flutter + React Native Cross-Platform Code Review

**Project:** FFmpegKitExtended  
**Review type:** frozen-source code review; substantive findings only  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch represented by snapshot:** `dev-wasm`  
**Frozen wrapper source:** `2b4b902b0aa918d871659380475ebf6ec3bb06d3`  
**Snapshot workflow:** `37043971931`  
**Snapshot artifact:** `review44-source-snapshot-37043971931`  
**Artifact ID:** `11243086786`  
**Outer artifact SHA-256:** `00477bb4613ea604f0bce107420ed1335f513dba354b2c2543e07d4d0603282c`  
**Embedded `source.tar.gz` SHA-256:** `e426ff603eebe8a3a02797007fee5d64819a3ad62446d12590ece70dc58fcdd8`  
**Manifest:** **1,098/1,098 verified**  
**Symlinks:** `0`  
**Snapshot metadata:** `runtimeExecution=false`  
**Recursive submodule:** `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`  
**Native ABI/runtime:** frozen `0.11.2`; not downloaded, rebuilt, or re-reviewed  

---

## 1. Review authority and provenance

Review 45 uses the exact wrapper-only source snapshot frozen at Review 44 closeout.

The repository's same-repository source-snapshot mailbox path was not present on `dev-wasm`, so Review 45 used the tracker-recorded Review 44 workflow run and artifact as the documented fallback discovery path. The artifact was downloaded through the GitHub connector and independently verified before source inspection.

Verified provenance:

```text
GitHub artifact SHA-256:
  00477bb4613ea604f0bce107420ed1335f513dba354b2c2543e07d4d0603282c

snapshot-metadata.snapshot_sha:
  2b4b902b0aa918d871659380475ebf6ec3bb06d3

snapshot-metadata.runtimeExecution:
  false

source.tar.gz SHA-256:
  e426ff603eebe8a3a02797007fee5d64819a3ad62446d12590ece70dc58fcdd8

SHA256SUMS:
  1098/1098 verified

SYMLINKS.tsv:
  0 entries

SUBMODULES.txt:
  b74da2c5d1e294b87d15d73a6687393729e932b3 libs/libffmpegkit (b74da2c)
```

The workflow event head SHA is not used as source authority; `snapshot-metadata.snapshot_sha` is the exact reviewed source.

No native/builders artifact was downloaded. Native ABI `0.11.2`, the native submodule, and builders remain outside Review 45 source scope.

---

## 2. Review boundary

This was **code review only**.

Review 45 performed no:

```text
Flutter tests
React Native tests
compilation
platform builds
simulator/device launches
browser execution
native execution
hosted acceptance CI
repository mutation
```

The review order was:

```text
1. verify Review 44 frozen source provenance
2. re-audit platform-native bridge closure
3. re-audit Flutter wrapper closure
4. review the React Native wrapper changes introduced by Review 44
5. expand through adjacent queue/history/cancellation/callback ownership paths
6. report only reachable substantive defects with concrete product/lifecycle effect
```

Excluded from findings:

```text
formatting/style
naming preferences
tracker/procedural observations
documentation-only drift without product consequence
speculative hardening
refactoring opportunities without a correctness consequence
native ABI internals already frozen outside wrapper scope
```

---

## 3. Platform-native bridge disposition

### CLOSED

The Review 45 frozen source has no platform-native production drift from the already-closed Review 43 source in these directories:

```text
flutter/native
flutter/windows
flutter/linux
flutter/android
flutter/ios
flutter/macos

react-native/cpp
react-native/windows
react-native/android
react-native/ios
react-native/appletvos
react-native/macos
```

A recursive source comparison found those directories unchanged.

Therefore the accepted platform-native invariants remain the exact same implementation:

```text
Flutter iOS/macOS:
  Darwin external-texture registration failure is rejected before publication.

Flutter Windows:
  asynchronous texture retirement owns callback-captured state
  latest FFplay owner semantics
  packed-frame normalization

Flutter Linux:
  FlPixelBufferTexture engine lifecycle
  queued idle GObject references
  frame coalescing and stable pixel-buffer lifetime

Flutter Android:
  Surface / SurfaceTexture / ANativeWindow ownership
  stale owner cannot clear a newer target

React Native shared C++:
  composable top-level operation admission
  registry-wide clear barrier
  retained-handle borrow/release barrier
  non-throwing cleanup authority

React Native Windows/Android/Apple:
  invocation-bound action failures
  same-call synchronous diagnostic boundary
  callback lifetime/drain
  process-global FFplay latest-owner behavior
```

No contradictory source evidence was found. Review 45 opens **zero platform-native bridge findings**.

---

## 4. Flutter wrapper disposition

### CLOSED in the reviewed wrapper/lifecycle surfaces

`flutter/lib` and the Flutter regression source are unchanged from the Review 43 authority that Review 44 re-audited as clean.

Review 45 found no new concrete Flutter wrapper defect.

Relevant accepted Flutter semantics remain:

```text
ID cancellation routes through Session/queue authority
ID 0 uses cancel-all semantics
submitted-Created startup is not pre-submission abandonment
durable cancellation survives startup state transitions
restored Running observer demand is distinct from execution ownership
restored terminal observation owns its own lifecycle
queue identity reservations remain one-per-native-session-ID
```

No Flutter production change is required by Review 45 findings.

---

## 5. Executive React Native disposition

React Native is **not yet wrapper-clean**.

Review 44 correctly closed its five previously identified gaps, but the newly added restored-session ownership layer creates or exposes five additional substantive lifecycle defects.

| ID | Severity | Surface | Finding |
| --- | --- | --- | --- |
| **R45-F1** | **High** | React Native queue admission / restored-session execution | A restored Running or terminal wrapper can still enter `executeAsync()`. Handoff validation rejects the non-Created state, but `SessionQueueManager` then invokes the same destructive `onDiscard` callback used for an intentional queued cancellation. That tombstones the real session and releases retained ownership even though the session was not an abandoned queued Created identity. |
| **R45-F2** | **High** | React Native restored-session ID cancellation | `FFmpegKitExtended.cancelSession(id)` catches every error from history lookup and `Session.cancel()`, not only a missing-ID case. A real state-read or native cancellation failure can therefore be reported as success. Durable intent remains, but the restored-session observer never retries cancellation when it later observes Running, so cancellation can be silently lost. |
| **R45-F3** | **Medium-High** | React Native restored terminal observation vs original execution monitor | The restored observer releases the retained session immediately after its own terminal settlement. The original execution monitor may still be draining final logs/statistics/completion callbacks. Per-ID release serialization prevents two simultaneous release calls but does not prevent the restored observer from being the first owner to retire the handle too early. |
| **R45-F4** | **Medium** | React Native restored history observation | Every Running history lookup creates a new wrapper and stores it strongly in a per-ID `targets` set until terminal state. Repeated history polling of one long-running session therefore grows live wrapper roots and terminal fan-out linearly with the number of reads, even when those wrappers have no callbacks. |
| **R45-F5** | **Medium-High** | React Native restored callback setup | Restored log/statistics setters can await asynchronous bridge installation while terminal settlement concurrently releases callback demand and marks the wrapper settled. The setter can then resume and commit a newly acquired lease/subscription after terminal cleanup, leaking callback demand and returning success for an observer that is already dead. |

No finding requires a native ABI change.

---

# 6. R45-F1 — preparation failure uses destructive Created-session discard

**Severity:** High  
**Primary surfaces:** `react-native/src/session.ts`, `react-native/src/session-queue-manager.ts`  
**Native ABI change:** none

## 6.1 Source evidence

All session `executeAsync()` implementations route through:

```text
Session.submitOnce()
  -> SessionQueueManager.executeSession(...)
     onDiscard = Session.discardBeforeExecution()
```

For example, `react-native/src/session.ts:1185-1211`:

```ts
return this.submitOnce(() =>
  SessionQueueManager.shared.executeSession(
    this,
    () => /* execute/monitor */,
    () => this.discardBeforeExecution()
  )
);
```

`submitOnce()` (`session.ts:1071-1088`) currently validates only wrapper-local submission/cancellation state:

```ts
if (this.submitted) { ... }
if (this.cancelled) { ... }
this.submitted = true;
return submit();
```

It does **not** reject a restored wrapper whose authoritative native state is already Running, Completed, or Failed.

The queue revalidates immediately before native handoff (`session-queue-manager.ts:262-270`):

```ts
try {
  item.session.prepareForExecution?.();
} catch (error) {
  void this.discardAfterPreparationFailure(item, error);
  continue;
}
```

`prepareForExecution()` correctly rejects a state other than `Created` (`session.ts:367-390`).

The defect is the cleanup chosen for that validation failure.

`discardAfterPreparationFailure()` (`session-queue-manager.ts:293-309`) calls `item.onDiscard`:

```ts
const cleanup = item.onDiscard?.();
```

and `onDiscard` is `discardBeforeExecution()`.

`discardBeforeExecution()` (`session.ts:1054-1067`) does two ownership-changing operations:

```text
abandonCreatedSession()
releaseOwnedHandle()
```

That behavior is appropriate for an **intentional discard of known queued Created work**. It is not appropriate for an arbitrary handoff validation failure.

## 6.2 Reachable restored-session sequence

The Review 44 implementation intentionally supports Running history wrappers:

```text
history -> sessionFromSnapshot(snapshot)
snapshot.state == Running -> observeRestoredRunning()
```

The README also states that Running/terminal history wrappers are inspection/control wrappers and are never re-executed.

However there is no execution API guard enforcing that statement before queue admission.

Reachable sequence:

```text
1. A native session is Running.
2. Application obtains it through getSession()/getSessions()/typed history API.
3. History projection retained/promoted the Running native identity.
4. Application mistakenly calls executeAsync() on the returned wrapper.
5. submitOnce() marks that wrapper submitted and enqueues it.
6. Queue prepareForExecution() observes Running and rejects.
7. discardAfterPreparationFailure() invokes discardBeforeExecution().
8. abandonCreatedSession() tombstones the ID even though it is actually Running.
9. releaseOwnedHandle() can retire retained ownership for that Running ID.
10. The public execution call rejects, but the rejection caused destructive mutation to an unrelated live execution/history identity.
```

The same path can tombstone valid terminal history when a Completed/Failed history wrapper is submitted.

## 6.3 Product consequence

For Running sessions this can:

```text
hide a real live execution from direct/history lookup
publish an abandonment tombstone for an identity that was never abandoned
release retained ownership for a session still executing
break restored observation/control semantics
```

For terminal sessions it can destroy valid history visibility merely because the caller made an invalid execution request.

An invalid operation must fail closed without mutating the native/history ownership of the existing execution.

## 6.4 Required correction

Two boundaries should be corrected.

First, `submitOnce()` needs a non-destructive authoritative submission preflight before it marks the object submitted or enters the queue:

```text
wrapper already submitted -> reject
wrapper cancelled -> reject
authoritative state != Created -> reject without discard
abandoned/cancellation intent -> reject without queue admission
otherwise mark submitted and enqueue
```

Second, a queue **handoff validation failure** must not automatically reuse the explicit queued-cancellation discard callback.

`onDiscard` should remain reserved for:

```text
cancelQueued()
clearQueue()
cancelAll() queue removal
```

where the queue knows it is intentionally abandoning work before execution.

A race-time `prepareForExecution()` rejection should:

```text
release only the JavaScript queue reservation
reject the execution promise with the validation error
not call abandonCreatedSession()
not release the native retained handle
```

The second rule is required even with an early preflight because the native state can change between preflight and actual handoff.

---

# 7. R45-F2 — restored ID cancellation can report success while cancellation is lost

**Severity:** High  
**Primary surfaces:** `react-native/src/ffmpeg-kit-extended.ts`, `react-native/src/session.ts`, `react-native/src/session-observation.ts`  
**Affected backends:** native and Web  
**Native ABI change:** none

## 7.1 Broad error swallowing

Review 44 correctly changed static ID cancellation to route managed sessions through queue/session authority.

The fallback for a restored/history session is now `ffmpeg-kit-extended.ts:135-142`:

```ts
try {
  const restored = this.getSession(sessionId);
  if (restored) {
    await restored.cancel();
  }
} catch {
  // Unknown IDs retain the historical no-op behavior of the public API.
}
```

The catch does not distinguish:

```text
unknown session ID
history lookup transport failure
snapshot/state failure
native cancellation failure
Web/Wasm failure
observer-related wrapper failure
```

All are converted into successful completion.

This is broader than the comment's stated "unknown ID" compatibility behavior.

## 7.2 Durable intent exists, but restored observation does not deliver it

`Session.cancel()` (`session.ts:247-277`) explicitly documents:

```text
A state-read or native-dispatch failure does not erase the recorded request,
so an executing session can still deliver it when Running is observed again.
```

The implementation records cancellation intent before state classification:

```ts
this.cancelled = true;
NativeFFmpegKitExtended.recordCancellationIntent?.(this.sessionId);
```

The ordinary execution monitor honors that promise. At `session.ts:924-934`, when it later sees Running it retries native cancellation when:

```text
cancelled == true
nativeCancellationDispatched == false
```

The restored-session coordinator does not.

`session-observation.ts:65-119` only:

```text
reads state
polls callbacks while Running
settles callbacks at terminal
releases retained ownership
```

It never checks the backend's durable cancellation-intent authority and never retries native cancellation.

## 7.3 Reachable failure sequence

```text
1. Application reconstructs a Running session from history.
2. Application calls FFmpegKitExtended.cancelSession(id).
3. Static API builds the restored wrapper and calls Session.cancel().
4. recordCancellationIntent(id) succeeds.
5. getState() or native cancelSession(id) fails transiently.
6. Session.cancel() throws.
7. Static cancelSession(id) swallows the error and resolves successfully.
8. The restored observer continues polling.
9. The observer later sees Running again but never retries cancellation.
10. Native execution can continue to completion despite a public cancellation call that reported success.
```

This violates both the method's failure signaling and the durable-intent promise.

## 7.4 Web compatibility does not justify the blanket catch

The Web backend currently throws `Session <id> no longer exists` from `pointerFor()` when an unknown ID cannot be resolved. If unknown-ID cancellation must remain a no-op, normalize **that specific missing-ID lookup** rather than swallowing every exception from lookup and cancellation.

Native already represents missing history as an empty JSON result.

## 7.5 Required correction

The high-level static method should not catch arbitrary restored-session failures.

Preferred semantics:

```text
managed target found:
  call Session.cancel()
  propagate real failure

no managed target:
  attempt history lookup
  proven missing/unknown ID:
    return no-op if compatibility requires it
  restored wrapper:
    call Session.cancel()
    propagate state/native failure
```

The restored observer must also participate in durable cancellation delivery.

Use one per-ID cancellation-dispatch authority shared by:

```text
normal Session.cancel()
ordinary execution monitor
restored Running observer
```

Required properties:

```text
record intent before fallible classification
dedupe concurrent native cancel dispatches by ID
successful dispatch marks that ID dispatched
failed dispatch remains retryable
Running restored observation retries a recorded undelivered intent
terminal state clears intent + dispatch bookkeeping
global successful clear clears bookkeeping
```

Do not add or change a native ABI symbol.

---

# 8. R45-F3 — restored observer can retire the handle before original finalization drains

**Severity:** Medium-High  
**Primary surfaces:** `react-native/src/session-observation.ts`, `react-native/src/session.ts`, `react-native/src/session-lifetime.ts`  
**Native bridge contract involved:** existing retained-handle lifetime only; no native change required

## 8.1 The native contract is explicit

The retained-handle release path in `react-native/cpp/FFmpegKitDynamicApi.cpp` states:

```cpp
// Called by the JS monitor only after a terminal session state has been
// observed and final logs/statistics have been drained.
release(entry->handle);
```

The ordinary execution monitor follows that ordering.

At `session.ts:936-1025`:

```text
observe terminal
refresh/drain final log callback data
drain final statistics
invoke completion
clear cancellation intent
remove log subscription
releaseOwnedHandle()
return
```

## 8.2 Restored observer has a second release path

At `session-observation.ts:85-105`:

```text
observe terminal
settle each restored target
releaseSessionHandleSerialized(id)
delete observer entry
```

Review 44 added `releaseSessionHandleSerialized()` to prevent duplicate overlapping release calls.

That helper (`session-lifetime.ts:16-33`) serializes/deduplicates release calls by ID, but it does not model multiple active lifecycle owners.

Whichever caller reaches it first becomes the releaser.

## 8.3 Reachable coexistence case

A restored observer can coexist with the original execution monitor simply because application code reads history while the original session is running:

```text
original Session.executeAsync() is active
  +
getSession()/getSessions() reconstructs same Running ID
  -> restored observer starts
```

At terminal:

```text
restored observer:
  state terminal
  restored callbacks may finish quickly
  calls releaseSessionHandleSerialized()

original execution monitor:
  state terminal
  may still be draining final logs/statistics/completion
  has not reached releaseOwnedHandle() yet
```

If the restored observer wins the release race, the retained native handle is retired before the execution owner's final callback drain has completed.

The later execution-monitor release is suppressed by the serialized/completed map, so duplicate release is avoided, but the lifetime ordering is still wrong.

## 8.4 Product consequence

This can make finalization depend on a handle that another observer has already retired.

Depending on backend path, later final reads may:

```text
reacquire a temporary history handle unexpectedly
fail because the identity is no longer retained/visible
lose final buffered log/statistics delivery
surface a monitor/finalization error
```

The contract requires the active execution owner to remain authoritative until its executor/monitor has fully settled.

## 8.5 Required correction

Do not replace this with a broad new ownership subsystem unless necessary.

A minimal semantic rule is sufficient:

```text
if SessionQueueManager still has an ACTIVE managed session with this ID:
  restored observer may settle restored callbacks
  restored observer must NOT release retained ownership
  original execution monitor owns final release

if no active managed execution owner exists:
  restored observer is the terminal owner
  it releases the promoted retained handle after its own terminal settlement
```

Add an active-only lookup/query seam to `SessionQueueManager`. Do not use the existing queued-or-active lookup because a queued item does not represent an execution monitor that can own terminal release.

Keep per-ID release serialization as duplicate-call protection; do not treat it as the lifetime-owner decision.

---

# 9. R45-F4 — history polling accumulates strong restored-wrapper roots

**Severity:** Medium  
**Primary surfaces:** `react-native/src/session.ts`, `react-native/src/session-observation.ts`  
**Native ABI change:** none

## 9.1 Source evidence

Every Running snapshot creates a new wrapper and immediately registers that wrapper with the observer:

`session.ts:1573-1593`:

```ts
session = new <typed session>(snapshot.sessionId, snapshot.command);
if (snapshot.state === SessionState.Running) session.observeRestoredRunning();
```

`observeRestoredRunning()` calls:

```ts
restoredSessionObserver.observe(this);
```

The coordinator stores targets in a strong set:

`session-observation.ts:14-20`:

```ts
type ObservationEntry = {
  readonly sessionId: number;
  readonly targets: Set<RestoredSessionObservationTarget>;
  ...
};
```

and `observe()` does:

```ts
entry.targets.add(target);
```

A target is removed only when the whole entry terminates or is invalidated. There is no per-wrapper detach path when a caller simply drops a history wrapper.

## 9.2 Reachable product pattern

History APIs commonly feed polling UIs:

```text
every N milliseconds:
  FFmpegKitExtended.getSessions()
  render/update UI
  discard old JavaScript wrapper array
```

For one long-running native session:

```text
poll #1 -> wrapper A -> target set
poll #2 -> wrapper B -> target set
poll #3 -> wrapper C -> target set
...
```

The application no longer owns A/B/C, but the coordinator does.

The session ID has only one observer entry, yet the entry accumulates one wrapper object for every read until native terminal state.

At terminal, the coordinator also loops across every accumulated target.

## 9.3 Product consequence

Long-running operations combined with frequent history polling can cause:

```text
linear JavaScript heap growth during the execution
retention of per-wrapper callback/demand/log bookkeeping
linear terminal-settlement fan-out unrelated to actual callback consumers
```

The per-ID observer should not require one strong lifetime root per observational history read.

## 9.4 Required correction

Separate:

```text
per-ID lifetime observation
from
per-wrapper callback sinks
```

Preferred model:

```text
ensureObserved(sessionId)
  -> guarantees one lightweight state/lifetime observer per native ID
  -> does not retain every reconstructed wrapper

attachCallbackTarget(wrapper)
  -> only when that wrapper actually owns restored completion/log/statistics sinks

detachCallbackTarget(wrapper)
  -> when its final restored sink is removed
```

The coordinator should read state by ID/backend (or one bounded representative state reader), not by retaining every wrapper solely to call `getState()`.

No-callback history reads must keep target cardinality bounded regardless of how many wrappers are reconstructed.

---

# 10. R45-F5 — asynchronous restored callback setup can commit after terminal cleanup

**Severity:** Medium-High  
**Primary surface:** React Native restored log/statistics callback setters  
**Native ABI change:** none

## 10.1 Async setup path

`session.ts:173-195` implements restored callback mutation as:

```text
verify Running
mutate callback field
refreshCallbackDemand()
  possibly await asynchronous bridge installation
sync log-event subscription
return success
```

The native backend treats callback bridge installation as an asynchronous action, so `refreshCallbackDemand()` can yield.

## 10.2 Terminal cleanup is unsynchronized with the setter

`settleRestoredObservation()` (`session.ts:574-603`) independently:

```text
drains callbacks
fires completion
clears cancellation intent
releaseAllCallbackDemand()
removes log subscription
disables callback demand
marks restoredTerminalSettled = true
```

No transition lock/generation guards that cleanup against an in-flight async setter.

`syncRestoredLogEventSubscription()` (`session.ts:631-646`) checks:

```text
restoredRunning
log callback exists
direct log bridge active
```

but does not reject `restoredTerminalSettled`.

## 10.3 Reachable race

```text
1. Restored Running wrapper calls setLogCallback(cb).
2. Initial assertRestoredCallbackState() observes Running.
3. callback field is updated.
4. refreshCallbackDemand() begins async installLogBridge and awaits.
5. Session becomes terminal.
6. Restored observer calls settleRestoredObservation().
7. Cleanup sees no newly installed lease yet, releases existing demand, marks settled.
8. installLogBridge resolves.
9. Setter resumes and records/acquires the lease after terminal cleanup.
10. Setter can install a direct-log subscription and return success.
11. No restored observer remains to retire that newly committed demand.
```

The statistics path has the same class of race.

## 10.4 Product consequence

This can leave:

```text
process-global callback bridge demand retained after the session is terminal
a per-session event subscription retained after observer shutdown
a callback setter that resolves successfully although no future delivery is possible
```

This is a lifetime/resource bug, not a formatting or theoretical hardening concern.

## 10.5 Required correction

Make restored callback mutation and restored terminal/invalidation cleanup part of one serialized transition boundary.

A simple per-session async transition chain is sufficient:

```text
update restored optional callback
terminal settle
successful-clear invalidation
```

must not interleave their ownership commits.

Additionally:

```text
after asynchronous bridge acquisition and before commit/success:
  revalidate that restored observation is still live/Running
if terminal won:
  release newly acquired demand
  rollback callback field
  do not subscribe
  reject setter
```

`syncRestoredLogEventSubscription()` must never subscribe a terminal-settled wrapper.

---

## 11. Review 44 fixes that remain correct

The Review 45 findings do not invalidate the core Review 44 corrections.

The following source behavior is sound and should be preserved:

```text
static ID cancellation first searches managed queued/active sessions
ID 0 delegates to queue-aware cancel-all
Session.cancel distinguishes unsubmitted Created from submitted-Created
Web history state-probe ownership is failure-atomic
typed history reconstruction flows through the canonical snapshot parser
Running history creates a non-executing observer
restored callback demand is conceptually separate from execution demand
successful clear invalidates restored observation only after backend clear
```

The Review 45 remediation should be surgical around the new lifecycle edges.

---

## 12. Why Review 44 tests could remain green

Review 44 added strong deterministic tests for the originally reported gaps, but the Review 45 defects require different interleavings.

Missing combinations include:

```text
executeAsync() called on a reconstructed Running/terminal wrapper
handoff validation failure followed by destructive discard observation
restored ID cancellation with a transient getState/native-cancel failure
restored observer reaching terminal before original monitor finishes final drain
hundreds/thousands of no-callback Running history reconstructions
terminal settlement racing a deferred async log/statistics bridge installation
```

Build success and normal restored-session observation do not exercise these boundaries.

---

## 13. Review 45 remediation goals

| Goal | Required result |
| --- | --- |
| **R45-G1** | Make invalid/non-Created submission and handoff validation failure non-destructive. Explicit queued cancellation remains the only path that uses Created-session discard/tombstoning. |
| **R45-G2** | Preserve real cancellation errors and make durable restored-session cancellation retryable through one per-ID dispatch authority. |
| **R45-G3** | Keep the original active execution monitor authoritative for retained-handle release through its final callback drain; restored observation releases only when no active execution owner exists. |
| **R45-G4** | Separate per-ID restored lifetime observation from per-wrapper callback targets so history polling cannot accumulate unbounded strong wrapper roots. |
| **R45-G5** | Serialize restored callback setup with terminal/clear cleanup so asynchronous bridge installation cannot commit after observer death. |
| **R45-G6** | Add deterministic regressions and semantic documentation, re-audit platform-native/Flutter/RN closure, then freeze one exact wrapper snapshot if clean. |

---

## 14. Required regression coverage

Review 45 executed no tests. Remediation must add deterministic coverage.

### 14.1 Non-destructive invalid submission

Prove for a reconstructed Running session:

```text
executeAsync rejects
native executor start count == 0
abandonCreatedSession count == 0
releaseSessionHandle count == 0 at rejection
history identity remains visible
restored observer remains valid
```

Repeat for Completed/Failed history wrappers.

Also prove a queue handoff race:

```text
submission preflight sees Created
state changes before queue handoff
prepareForExecution rejects non-Created
queue reservation is released
onDiscard / abandon / release are NOT invoked
```

Explicit queued cancellation must still:

```text
remove queued item
reject with SessionCancelledException
abandon true queued Created identity
perform configured retained cleanup
```

### 14.2 Restored cancellation failure and retry

Cases:

```text
unknown ID remains documented no-op
history lookup transport/state failure is not swallowed
native cancellation failure is surfaced
durable cancellation intent remains after failure
later Running restored observation retries dispatch
retry is deduplicated by session ID
terminal clears intent and retry bookkeeping
```

### 14.3 Execution owner vs restored observer release

Use a deterministic latch around finalization:

```text
normal executeAsync monitor active
same Running ID reconstructed from history
native state becomes terminal
hold original monitor inside final log/statistics drain
allow restored observer to settle first
assert backend release count == 0 while active execution owner exists
release original drain latch
assert exactly one backend release after original finalization
```

Also prove a history-only restored Running session releases once at terminal.

### 14.4 Bounded restored targets

Create one Running snapshot and reconstruct it repeatedly without attaching callbacks:

```text
1000 history reconstructions
one per-ID observer entry
callback-target cardinality stays bounded (preferably zero)
no 1000-wrapper terminal fan-out
```

Then attach callbacks to two live wrappers and prove only those wrappers are retained as targets and are detached when their final sinks are removed.

### 14.5 Callback setup vs terminal race

Use a deferred fake bridge installation:

```text
start setLogCallback()
hold installLogBridge promise unresolved
make session terminal and begin terminal settlement
resolve bridge install
```

Required result:

```text
setter does not report a live observer after terminal
callback field rolls back or is terminal-inactive by contract
newly acquired lease is released
direct-log subscription is absent
callback demand returns to baseline
```

Repeat the ownership pattern for statistics demand.

---

## 15. Documentation guidance

Public React Native documentation should explicitly preserve these semantics:

```text
History Running/terminal wrappers are observation/control objects and cannot
be re-submitted for execution. A rejected re-submission does not abandon,
cancel, or release the existing native execution/history identity.

Cancellation by ID is queue-aware. Unknown IDs may remain compatibility no-ops,
but lookup/state/native-cancellation failures for an existing session are real
errors and are not reported as successful cancellation.

A durable cancellation request for a restored Running session remains pending
after a transient state/native dispatch failure and is retried while that
existing execution remains Running.

Reading a Running session from history does not create another execution owner.
When an original JavaScript execution owner still exists, it retains final
release authority through final callback drain.

Restored callback setters may fail if terminal state wins while observer routing
is being established; they never leave process-global callback demand installed
for a dead observer.
```

Internal comments should explain ownership boundaries, not Review 45 history.

Do not use `R45`, finding IDs, or goal IDs in production/test identifiers.

---

## 16. Closeout criteria

Review 45 is not wrapper-clean until every applicable item is true:

```text
[ ] Running history executeAsync rejection is non-destructive.
[ ] Terminal history executeAsync rejection is non-destructive.
[ ] Queue handoff validation failure never invokes explicit queued-discard cleanup.
[ ] Explicit queued Created cancellation still abandons correctly.
[ ] Queue reservation is released on every rejected handoff.

[ ] Static restored-session cancellation does not swallow real errors.
[ ] Unknown-ID no-op behavior is narrow and tested.
[ ] Durable restored cancellation retries after transient state/dispatch failure.
[ ] Per-ID cancellation dispatch cannot double-send after success.
[ ] Terminal/clear removes cancellation retry bookkeeping.

[ ] Active original execution owner prevents early restored-observer release.
[ ] Original monitor releases only after final log/statistics/completion drain.
[ ] History-only restored Running ownership releases once at terminal.
[ ] Per-ID release serialization remains retryable after failure.

[ ] No-callback history polling does not retain one wrapper per read.
[ ] Callback targets are attached only while they own live restored sinks.
[ ] Terminal/clear detaches callback targets and removes observer entry.

[ ] Async restored callback setup is serialized against terminal settlement.
[ ] Terminal-winning setup releases partial demand and cannot report false success.
[ ] Restored log subscription cannot be installed after terminal settlement.
[ ] Log/statistics bridge demand returns to baseline.

[ ] Focused RN regressions pass during remediation.
[ ] Typecheck/test compilation/full local suite results are recorded truthfully.
[ ] Affected Web/Wasm and local platform gates are run only as required.
[ ] No interactive app validation is claimed by the agent.
[ ] Flutter production source remains unchanged unless a new defect is proven.
[ ] Platform-native bridge source remains unchanged unless a new defect is proven.
[ ] Native ABI/submodule/builders remain frozen.
[ ] No remote old native bundle is fetched.
[ ] No hosted Flutter/RN acceptance workflow is used.
[ ] Final bounded source audit finds no substantive open Flutter/RN/platform-native finding.
[ ] Exact final wrapper SHA is frozen and represented by one verified wrapper-only source snapshot.
```

---

## 17. Review 45 closeout

```text
Frozen wrapper authority: VERIFIED
Outer artifact digest: VERIFIED
Embedded source archive: VERIFIED
Manifest: 1098/1098
Symlinks: 0
runtimeExecution: false
Frozen native submodule: VERIFIED

Native ABI separately downloaded: NO
Native ABI reviewed: NO
Native ABI source change required: NO

Code review only: YES
Tests/builds/runtime executed by Review 45: NO
Repository mutation by Review 45: NO

Platform-native bridge substantive findings: 0
Flutter wrapper substantive findings: 0
React Native wrapper substantive findings: 5

R45-F1 High        — handoff validation failure can destructively abandon/release an existing session
R45-F2 High        — restored ID cancellation swallows real errors and lacks durable retry
R45-F3 Medium-High — restored observer can release before original final callback drain
R45-F4 Medium      — Running history polling accumulates strong wrapper roots
R45-F5 Medium-High — async restored callback setup can commit after terminal cleanup

Pedantic/procedural findings reported: 0

Disposition:
PLATFORM-NATIVE BRIDGE CLOSED.
FLUTTER WRAPPER CLOSED IN REVIEWED SURFACES.
REACT NATIVE WRAPPER NOT YET CLOSED.
```
