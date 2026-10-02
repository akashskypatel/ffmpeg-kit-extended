# Review 45 — Luna Flutter + React Native Final Wrapper Closure Plan

**Project:** FFmpegKitExtended  
**Audience:** Luna implementation/review model  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch:** `dev-wasm`  
**Starting source authority:** `2b4b902b0aa918d871659380475ebf6ec3bb06d3`  
**Review basis:** `review-45-flutter-react-native-code-review.md`  
**Native ABI/runtime:** frozen `0.11.2`  
**Frozen native submodule:** `b74da2c5d1e294b87d15d73a6687393729e932b3`

---

# 1. Goal tracker

| Goal | Objective | Primary implementation | Required tests | Documentation | Status |
| --- | --- | --- | --- | --- | --- |
| **R45-G1** | Make invalid/non-Created submission and queue handoff rejection non-destructive | Add authoritative submission preflight and separate validation rejection from explicit queued discard | Running/terminal restored submission; Created→non-Created handoff race; explicit queue cancel preservation | History/execution contract | ☐ |
| **R45-G2** | Preserve restored cancellation failures and deliver durable cancellation after transient failure | Remove blanket restored-cancel catch; add one per-ID retryable cancellation-dispatch authority used by normal and restored observers | unknown ID; state failure; cancel failure; later Running retry; dedupe; terminal clear | Cancellation API/TSDoc | ☐ |
| **R45-G3** | Preserve active execution ownership through final callback drain | Add active-only execution-owner query; restored observer releases only when no active execution monitor owns finalization | active monitor + restored observer race; history-only release; release failure/retry | Lifetime comments | ☐ |
| **R45-G4** | Bound restored observation memory independently of history-read frequency | Separate one per-ID lifetime observer from callback-bearing wrapper targets; attach/detach targets only for live sinks | 1000 history reconstructions; bounded targets; sink attach/remove; terminal/clear cleanup | Restored-history ownership comments | ☐ |
| **R45-G5** | Make restored callback setup atomic with terminal/clear cleanup | Serialize optional callback-demand mutations with restored terminal settlement/invalidation; revalidate after async bridge install | deferred log/stat bridge install vs terminal; rollback; no post-terminal subscription; demand baseline | Callback setter contract | ☐ |
| **R45-G6** | Perform focused regression, final substantive audit, exact-SHA freeze and source snapshot if clean | No unrelated refactor; wrapper-only closeout | focused + full affected local gates; no hosted acceptance CI | Tracker/provenance + closeout summary | ☐ |

---

# 2. Mission

Review 45 preserves three source-level conclusions:

```text
platform-native bridge: closed
Flutter wrapper reviewed lifecycle surfaces: closed
React Native wrapper: five substantive lifecycle defects remain
```

The task is therefore a **React Native wrapper lifecycle closure**, not another platform-native/native-ABI rewrite.

The implementation must:

```text
1. Reject invalid history-wrapper execution without changing native/history ownership.
2. Make restored cancellation truthful and retryable.
3. Keep the real execution owner authoritative through final callback drain.
4. Prevent history polling from rooting one wrapper per read.
5. Prevent async restored callback setup from committing after terminal cleanup.
6. Re-audit all three layers and freeze only if no substantive finding remains.
```

The target is the smallest coherent change that restores these invariants.

---

# 3. Non-negotiable constraints

Luna must treat every item below as mandatory.

1. Work in `akashskypatel/ffmpeg-kit-extended`, branch `dev-wasm`.
2. Reconcile against exact wrapper source:
   `2b4b902b0aa918d871659380475ebf6ec3bb06d3`.
3. Keep native ABI/runtime pinned to **0.11.2**.
4. Keep `libs/libffmpegkit` frozen at:
   `b74da2c5d1e294b87d15d73a6687393729e932b3`.
5. Do **not** download or re-review native ABI source/artifacts.
6. Do **not** edit or rebuild `libs/libffmpegkit`.
7. Do **not** edit/rebuild the ManyLinux builders checkout.
8. Do **not** add or change native ABI exported symbols.
9. Do **not** publish native ABI artifacts.
10. Do **not** fetch a remotely built old native bundle for local validation.
11. Use only the existing locally configured/package native ABI `0.11.2` artifacts.
12. Do **not** run hosted Flutter/React Native test/build workflows as acceptance evidence.
13. The only hosted workflow allowed at final closure is the exact wrapper source-snapshot workflow.
14. Do **not** automatically launch interactive Flutter/RN apps, simulators, devices, or Web UI.
15. Interactive validation remains user-owned.
16. Do **not** change Flutter production code unless a new concrete Flutter defect is proven.
17. Do **not** reopen platform-native bridge code merely for symmetry or cleanup.
18. Production/test identifiers must be semantic; never use `R45`, `G1`, `F1`, review names, or tracker wording as implementation names.
19. Never fabricate tests or results.
20. Do not weaken existing tests.
21. Record failed commands, retries, skipped gates, environment corrections, and partial validation truthfully.
22. Exclude pedantic/style/procedural findings from the final review.
23. A new finding needs a reachable path plus a concrete product/lifecycle consequence.
24. Make surgical changes. Do not broaden into general Session/queue architecture cleanup.
25. Preserve Review 44 behavior unless a Review 45 fix specifically requires changing it.

---

# 4. Frozen source provenance to preserve

Review 45 authority is the verified Review 44 source snapshot:

```text
wrapper SHA:
  2b4b902b0aa918d871659380475ebf6ec3bb06d3

workflow run:
  37043971931

artifact:
  review44-source-snapshot-37043971931

artifact ID:
  11243086786

artifact SHA-256:
  00477bb4613ea604f0bce107420ed1335f513dba354b2c2543e07d4d0603282c

source.tar.gz SHA-256:
  e426ff603eebe8a3a02797007fee5d64819a3ad62446d12590ece70dc58fcdd8

SHA256SUMS:
  1098/1098 verified

SYMLINKS.tsv:
  0 entries

runtimeExecution:
  false

submodule:
  b74da2c5d1e294b87d15d73a6687393729e932b3 libs/libffmpegkit
```

The workflow event branch head is discovery metadata. The exact source authority is the snapshot's `snapshot_sha`.

Do not substitute a later tracker/mailbox commit unless the tracker explicitly records a new implementation SHA.

---

# 5. Starting behavior that must be preserved

## 5.1 Platform-native bridge

Do not alter these already-closed invariants:

```text
Flutter iOS/macOS
  registerTexture failure ID 0 rejected before owner/lifetime publication

Flutter Windows
  asynchronous registered-texture retirement
  latest-owner FFplay callback semantics
  packed-frame normalization

Flutter Linux
  FlPixelBufferTexture engine lifecycle
  queued-idle references
  frame coalescing
  stable render-buffer lifetime

Flutter Android
  SurfaceTextureEntry / Surface / ANativeWindow exact ownership
  stale owner cannot clear newer surface

React Native shared C++
  composable operation token
  clear admission/drain barrier
  retained-handle lease/release state machine
  non-throwing cleanup

React Native platform bridges
  invocation-bound async errors
  same-call synchronous diagnostics
  callback copied-payload lifetime
  FFplay latest-owner / drain semantics
```

Review 45 found these directories byte-for-byte unchanged from the prior closed source authority.

## 5.2 Flutter wrapper

Do not edit Flutter merely for parity.

Preserve:

```text
ID 0 -> cancel all
nonzero ID -> Session.cancel authority
submitted Created startup != abandoned Created identity
durable cancellation survives startup
restored callbacks use observer ownership, not execution ownership
restored terminal lifecycle does not re-execute
one native-ID queue reservation per active/queued execution
```

## 5.3 Review 44 React Native fixes

Preserve these corrected behaviors:

```text
public ID cancellation first searches managed queue/active work
submitted-Created cancellation is not abandoned
canonical typed history reconstruction
one restored observer entry per Running session ID
restored callback demand is distinct from execution callback demand
Web history temporary-pointer state probing is failure-atomic
successful global clear invalidates restored observer state only after backend commit
```

Review 45 does **not** require undoing those fixes.

---

# 6. Architectural model Luna must keep straight

There are distinct authorities. Do not collapse them.

```text
native identity
  session ID and frozen ABI handle ownership

queue admission
  whether this JS wrapper is allowed to start native work

explicit queued discard
  intentional removal of never-started JS work

authoritative native state
  Created / Running / Completed / Failed

cancellation intent
  durable request keyed by native session ID

execution monitor
  owner of one submitted execution's final logs/statistics/completion + release

restored lifetime observer
  non-executing watcher for a Running history identity

restored callback sink
  one wrapper that actually requested completion/log/statistics observation

retained-handle release transaction
  backend destruction/retirement after the true final owner is done
```

Core rules:

```text
invalid execution request != queued discard
history observation != execution ownership
release serialization != lifetime-owner selection
cancellation intent != successful cancellation dispatch
per-ID observation != per-wrapper strong ownership
callback bridge install != callback setup committed
```

Every Review 45 fix follows from these separations.

---

# 7. R45-G1 — non-destructive submission and handoff rejection

## 7.1 Root defect

Current execution flow has two validation times:

```text
submitOnce()
queue handoff -> prepareForExecution()
```

Only the second one reads authoritative native state.

If it fails, `SessionQueueManager.discardAfterPreparationFailure()` calls the same `onDiscard` callback used by explicit queue cancellation.

For Session objects, that callback:

```text
abandonCreatedSession()
releaseOwnedHandle()
```

This is destructive when the reason for rejection is "this identity is already Running/terminal."

## 7.2 Required source files

Primary:

```text
react-native/src/session.ts
react-native/src/session-queue-manager.ts
```

Likely tests:

```text
react-native/tests/session-queue-manager.test.js
react-native/tests/wasm-session-ownership.test.js
react-native/tests/restored-session-observer.test.js
react-native/tests/session-history-registry.test.js
```

Use existing test infrastructure; add a new file only if existing suites become incoherent.

## 7.3 First correction — authoritative preflight before queue insertion

Add a semantic non-mutating submission preflight.

Simplest acceptable shape:

```ts
protected validateInitialSubmission(): void {
  if (NativeFFmpegKitExtended.isSessionAbandoned?.(this.sessionId)) {
    throw new SessionCancelledException(...);
  }
  if (NativeFFmpegKitExtended.isCancellationRequested?.(this.sessionId)) {
    throw new SessionCancelledException(...);
  }
  const state = this.getState();
  if (state !== SessionState.Created) {
    throw new Error(
      `Session ${this.sessionId} cannot start from state ${state}`
    );
  }
}
```

Then `submitOnce()` should conceptually become:

```ts
protected submitOnce<T>(submit: () => Promise<T>): Promise<T> {
  if (this.submitted) {
    return Promise.reject(
      new Error(`Session ${this.sessionId} was already submitted for execution`)
    );
  }

  if (this.cancelled) {
    this.submitted = true;
    return Promise.reject(
      new SessionCancelledException(
        `Session ${this.sessionId} was cancelled before execution`
      )
    );
  }

  try {
    this.validateInitialSubmission();
  } catch (error) {
    return Promise.reject(error);
  }

  this.submitted = true;
  return submit();
}
```

Do not call abandonment/release when this initial validation rejects.

### Why keep `prepareForExecution()` too

Do **not** remove the queue-time revalidation.

The native state can change while waiting for a concurrency slot:

```text
initial preflight Created
queue delay
another authority changes same native identity
handoff sees Running/terminal/cancellation
```

The queue-time check is still required.

## 7.4 Second correction — handoff validation failure is not `onDiscard`

Change the queue behavior so `discardAfterPreparationFailure()` does **not** call `item.onDiscard`.

Semantically:

```ts
private rejectPreparationFailure(
  item: QueueItem<unknown>,
  primaryError: unknown
): void {
  this.releaseSessionReservation(this.executionSessionId(item.session));
  item.reject(primaryError);
}
```

Then:

```ts
try {
  item.session.prepareForExecution?.();
} catch (error) {
  this.rejectPreparationFailure(item, error);
  continue;
}
```

If retaining the old method name, its behavior must still be non-destructive.

### Keep `onDiscard` for explicit discard only

These remain legitimate users of `onDiscard`:

```text
cancelQueued()
clearQueue()
cancelAll() -> clearQueue()
```

Those operations intentionally discard known queued work before executor start.

## 7.5 Do not "fix" by weakening prepareForExecution

Do not permit Running/terminal sessions to execute.

The correct result is:

```text
reject invalid re-submission
preserve existing native identity
preserve history
preserve restored observer
```

not:

```text
allow execution again
```

## 7.6 Running restored-wrapper regression

Setup:

```text
fake/history backend contains ID 101 in Running
history getter returns a restored FFmpegSession
release count = 0
abandon count = 0
executor start count = 0
```

Call:

```text
restored.executeAsync()
```

Assert:

```text
promise rejects with cannot-start-from-Running error
executor start count == 0
abandon count == 0
release count == 0 at rejection
isSessionAbandoned(101) == false
history still contains ID 101
restored observer still owns the Running observation
```

## 7.7 Terminal restored-wrapper regressions

For Completed and Failed:

```text
get history wrapper
call executeAsync()
```

Assert:

```text
reject
no abandon
no handle release caused by invalid submission
history remains visible
no queue reservation remains
```

## 7.8 Created-to-Running handoff race regression

Use deterministic state control.

```text
initial state = Created
submit -> initial preflight passes
hold queue behind blocker
before slot opens set state = Running
release blocker
queue prepareForExecution observes Running
```

Assert:

```text
execution promise rejects
executor start count == 0
queue reservation released
onDiscard/abandon count == 0
releaseOwnedHandle count == 0
Running history identity remains visible
```

This proves the second queue boundary, not only the early preflight.

## 7.9 Preserve explicit queued cancellation

Keep/strengthen a case:

```text
state Created
session intentionally queued
Session.cancel() / cancelBySessionId / clearQueue removes it before handoff
```

Assert:

```text
execution promise rejects SessionCancelledException
executor start count == 0
abandonCreatedSession called exactly once
reservation released
durable cancellation behavior remains correct
```

The distinction must be visible in tests:

```text
explicit queue cancellation -> destructive Created discard
validation failure -> non-destructive rejection
```

## 7.10 Documentation

Update React Native history/execution documentation:

```text
A session reconstructed from history is executable only while the authoritative
native state is Created. Attempting to execute a Running or terminal history
wrapper fails without abandoning, cancelling, or releasing the existing native
session/history identity.
```

Add an internal queue comment:

```text
// A handoff validation failure is not an explicit queued discard. Reject the
// JS submission without tombstoning or releasing the existing native identity.
```

---

# 8. R45-G2 — truthful, retryable restored cancellation

## 8.1 Root defects

Two things must be fixed together:

```text
A. static ID cancellation swallows every restored-session failure
B. restored observation does not retry durable cancellation intent
```

Fixing only A makes failures visible but leaves durable intent inert.

Fixing only B still lets the public call falsely report success on the initial failure.

## 8.2 Required source files

Primary:

```text
react-native/src/ffmpeg-kit-extended.ts
react-native/src/session.ts
react-native/src/session-observation.ts
react-native/src/session-lifetime.ts
react-native/src/platform/backend.web.ts
```

A tiny semantic cancellation helper/module is acceptable if it reduces duplication, for example:

```text
react-native/src/session-cancellation.ts
```

Do not create a generic lifecycle framework.

## 8.3 Remove the blanket restored-cancel catch

Current logic:

```ts
try {
  const restored = this.getSession(sessionId);
  if (restored) await restored.cancel();
} catch {
  // unknown ID
}
```

must not remain.

Target behavior:

```ts
const restored = this.getSession(sessionId);
if (!restored) return;
await restored.cancel();
```

### Unknown ID compatibility

Native missing-ID history already returns empty JSON.

Web currently throws `Session <id> no longer exists` from `pointerFor()`.

Do **not** reintroduce a broad catch just for Web.

Choose one narrow normalization, preferably at the Web lookup boundary:

```text
getSessionJson(unknown ID) -> ''
```

while preserving throws from:

```text
get_session call failure
state/snapshot getter failure
handle-release failure
other Web runtime errors
```

A helper such as `tryGetSessionPointer` is acceptable if it is strictly about a proven `0` pointer result.

Unknown ID should remain the existing documented no-op.

## 8.4 Shared cancellation-dispatch authority

Review 45 needs cancellation delivery deduplicated by native session ID rather than by one wrapper instance.

Add a minimal helper, for example:

```ts
type CancellationDispatchState = {
  inFlight?: Promise<void>;
  dispatched: boolean;
};

const cancellationDispatches = new Map<number, CancellationDispatchState>();
```

Or use separate maps. Required semantics matter more than shape.

A conceptual implementation:

```ts
export async function dispatchCancellationSerialized(
  sessionId: number
): Promise<void> {
  const state = cancellationDispatches.get(sessionId) ?? {
    dispatched: false,
  };

  if (state.dispatched) return;
  if (state.inFlight) return state.inFlight;

  const operation = Promise.resolve().then(() =>
    getBackend().cancelSession(sessionId)
  );

  state.inFlight = operation;
  cancellationDispatches.set(sessionId, state);

  try {
    await operation;
    state.dispatched = true;
  } finally {
    if (state.inFlight === operation) state.inFlight = undefined;
  }
}
```

Failure must leave:

```text
dispatched == false
inFlight cleared
durable cancellation intent unchanged
```

so a later Running observation can retry.

Provide cleanup:

```ts
export function clearCancellationDispatch(sessionId: number): void
export function clearAllCancellationDispatches(): void
```

Call it only after terminal state or successful global clear.

Do not keep a process-lifetime permanent set of all IDs.

## 8.5 Route Session cancellation through the shared dispatch

`Session.dispatchNativeCancellation()` should use the shared per-ID helper.

The instance-local `nativeCancellationDispatched` flag may remain as a fast path, but it must not be the sole cross-wrapper authority.

Conceptually:

```ts
private async dispatchNativeCancellation(): Promise<void> {
  if (this.nativeCancellationDispatched) return;
  await dispatchCancellationSerialized(this.sessionId);
  this.nativeCancellationDispatched = true;
}
```

If another wrapper already delivered cancellation successfully, the shared helper no-ops and this wrapper can mark its local flag.

## 8.6 Restored observer retry

When a restored observer sees Running:

```text
if backend durable cancellation intent exists:
  invoke shared per-ID cancellation dispatch
```

Do this **before or alongside** callback polling; do not let user callback errors suppress cancellation delivery.

Conceptually inside the per-ID observer:

```ts
if (
  state === SessionState.Running &&
  getBackend().isCancellationRequested?.(entry.sessionId)
) {
  try {
    await dispatchCancellationSerialized(entry.sessionId);
  } catch (error) {
    report retryable observer error
    // Keep intent. Try again on a later Running observation.
  }
}
```

Do not mark terminal or abandon the session because dispatch failed.

## 8.7 Terminal cleanup

When terminal state is authoritative:

```text
clear durable cancellation intent
clear per-ID dispatch bookkeeping
```

Coordinate with Session's ordinary monitor so either terminal owner can perform idempotent cleanup.

On successful `clearSessions()`:

```text
clear all durable intent (existing behavior)
clear all cancellation-dispatch bookkeeping
```

Do not clear retry bookkeeping before backend clear succeeds.

## 8.8 Cancellation regressions

### Unknown ID

Assert:

```text
FFmpegKitExtended.cancelSession(unknown)
resolves according to compatibility contract
no backend cancellation dispatch
no blanket swallowing is required for real errors
```

For Web, prove `getSessionJson` returns absent/empty only for a proven missing pointer.

### Restored state read failure

Setup:

```text
history resolves restored Running wrapper
recordCancellationIntent succeeds
getState throws sentinelStateError on cancel()
```

Call static ID cancellation.

Assert:

```text
public call rejects sentinelStateError
durable intent remains true
```

Then:

```text
observer next state read -> Running
```

Assert:

```text
shared native cancellation dispatch count == 1
intent remains until terminal
```

### Native cancel failure

Setup:

```text
state Running
first backend cancel -> throw sentinelCancelError
second backend cancel -> success
```

Assert:

```text
static public call rejects sentinelCancelError
intent remains
observer retries later
second dispatch succeeds
no third dispatch while still Running
```

### Terminal after retry

Assert:

```text
terminal clears durable intent
terminal clears per-ID dispatch state
```

A later stale wrapper calling cancel on already terminal follows existing terminal behavior and does not resurrect dispatch bookkeeping.

## 8.9 Documentation

TSDoc for `FFmpegKitExtended.cancelSession` must distinguish:

```text
unknown ID no-op
from
real failure while resolving/cancelling an existing session
```

Suggested semantics:

```text
Cancellation by ID uses the queue/session authority. A missing ID is a no-op.
Errors while reading or cancelling an existing session are propagated. If a
Running restored session records cancellation but the native dispatch fails,
the durable request remains pending and restored observation retries delivery
while the session remains Running.
```

Do not mention Review 45.

---

# 9. R45-G3 — execution owner remains final release authority

## 9.1 Root defect

`releaseSessionHandleSerialized(id)` answers:

```text
"Are two release calls overlapping or already completed?"
```

It does not answer:

```text
"Which lifecycle owner is allowed to release now?"
```

Review 45 must add that owner selection without redesigning native handle storage.

## 9.2 Required source files

Primary:

```text
react-native/src/session-queue-manager.ts
react-native/src/session-observation.ts
react-native/src/session-lifetime.ts
react-native/src/session.ts
```

No shared C++ production edit is expected.

## 9.3 Add active-only execution-owner query

The queue manager already has:

```text
active Set
queued array
findManagedSessionById() -> queued OR active
```

Add a semantic active-only seam:

```ts
isSessionActiveById(sessionId: number): boolean
```

or:

```ts
findActiveSessionById(sessionId: number): CancellableSession | undefined
```

Example:

```ts
isSessionActiveById(sessionId: number): boolean {
  for (const session of this.active) {
    if (this.executionSessionId(session) === sessionId) return true;
  }
  return false;
}
```

Do not expose/mutate the Set itself.

Why active-only:

```text
queued session:
  has not started native execution
  cannot own terminal finalization

active session:
  executor promise has started
  remains in active set until monitor/finalization settles
  is the correct owner marker
```

## 9.4 Modify restored terminal release decision

After restored callback settlement at terminal:

```text
if active execution owner exists:
  do not call releaseSessionHandleSerialized
  remove/finish restored observer entry
  original execution monitor will perform final release
else:
  restored observer owns terminal release
  call releaseSessionHandleSerialized
```

Conceptually:

```ts
if (SessionQueueManager.shared.isSessionActiveById(entry.sessionId)) {
  this.entries.delete(entry.sessionId);
  return;
}

await releaseSessionHandleSerialized(entry.sessionId);
this.entries.delete(entry.sessionId);
return;
```

### Ordering

The restored observer may still perform its own callback sink settlement before yielding release authority.

Required order:

```text
terminal observed
settle restored sinks
check active execution owner
if active:
  no retained-handle release
else:
  release retained handle
```

Do not remove the observer before its restored callback sinks settle.

## 9.5 Ordinary execution monitor remains unchanged

Do not move the original monitor release earlier.

Keep:

```text
final log reconciliation
final statistics
completion
subscription cleanup
releaseOwnedHandle
```

This is already the desired contract.

## 9.6 `releaseSessionHandleSerialized` remains useful

Keep it as:

```text
in-flight release dedupe
completed-release dedupe
retry after failure
```

but update its comment so it does not falsely imply it selects the correct owner.

For example:

```text
// Serializes a release transaction after the caller has established that it
// owns final retirement for this session ID. It does not select lifecycle
// ownership between execution and restored observers.
```

## 9.7 Execution + restored observer race test

Use deterministic latches, not timing alone.

Setup:

```text
normal Session.executeAsync() becomes active
history getter reconstructs same Running ID
restored observer is running
state -> terminal
execution monitor reaches final log/statistics drain
block it before release
```

Allow restored observer to see terminal and finish its own sink settlement.

Assert while execution owner is still active:

```text
backend release count == 0
restored observer entry is finished/does not retry release
```

Release final-drain latch.

Assert:

```text
completion/final data drain completes
backend release count == 1
release occurs after drain
active set becomes empty afterward
```

## 9.8 History-only terminal owner test

No execution manager entry exists.

```text
history returns Running
restored observer starts
state -> Completed
```

Assert:

```text
restored callbacks settle
releaseSessionHandle called once
observer entry removed
```

## 9.9 Duplicate history wrappers

Even after G4 changes:

```text
multiple callback-bearing wrappers for one ID
no active execution owner
terminal
```

Assert one release transaction.

## 9.10 Release failure

For history-only owner:

```text
first release throws
entry remains retryable
second release succeeds
no callback completion repeats
```

Do not re-fire completion callbacks merely because handle retirement needs retry.

Track:

```text
terminal callbacks settled
release pending
```

as separate state if necessary.

## 9.11 Documentation/comments

Internal lifetime comment:

```text
// An active queue executor owns final retained-handle retirement through its
// final callback drain. Restored observation retires a promoted history handle
// only when no active execution owner exists for the same session ID.
```

README need not expose implementation details, but preserve:

```text
history observation does not steal execution ownership
```

---

# 10. R45-G4 — bound restored observation roots

## 10.1 Root defect

Current `RestoredSessionObservationCoordinator` stores every reconstructed Running wrapper in:

```ts
Set<RestoredSessionObservationTarget>
```

for the full execution lifetime.

History polling produces fresh wrapper objects, so memory use scales with history-read count instead of live callback consumers.

## 10.2 Required design

Separate two concepts.

### Per-ID lifetime entry

One entry per Running native session ID:

```ts
type ObservationEntry = {
  readonly sessionId: number;
  readonly callbackTargets: Set<RestoredSessionCallbackTarget>;
  invalidated: boolean;
  terminalSettled: boolean;
  releasePending: boolean;
  run?: Promise<void>;
};
```

The exact fields may vary.

The entry itself should be enough to:

```text
read scalar state by ID
retry durable cancellation by ID
decide terminal release ownership
exist without retaining a Session wrapper
```

### Per-wrapper callback target

Only wrappers that actually own restored callback sinks need strong retention.

The coordinator should not retain a wrapper merely because `sessionFromSnapshot()` returned it.

## 10.3 Coordinator API shape

Preferred semantic API:

```ts
ensureObserved(sessionId: number): void

attachCallbackTarget(
  sessionId: number,
  target: RestoredSessionCallbackTarget
): void

detachCallbackTarget(
  sessionId: number,
  target: RestoredSessionCallbackTarget
): void
```

Alternative names are fine.

Avoid a single `observe(target)` API that conflates per-ID lifetime with per-wrapper callback ownership.

## 10.4 State reads should not require a wrapper target

Use the backend scalar state authority:

```ts
getBackend().getSessionState(sessionId)
```

or the existing `NativeFFmpegKitExtended.getSessionState`.

Prefer the backend registry in `session-observation.ts` to avoid forcing a wrapper root solely for `target.getState()`.

If this creates a module cycle, move only the minimal ID-state helper to a small semantic module; do not retain all wrappers as the workaround.

## 10.5 Change Session restoration

`Session.observeRestoredRunning()` should:

```text
mark this wrapper restoredRunning
configure its callback-demand providers
ensure one per-ID observer exists
NOT attach this wrapper as a callback target unless it currently has a live callback sink
```

A history read with no callbacks should leave:

```text
observer entries for ID: 1
callback target count: 0
```

regardless of number of wrappers created.

## 10.6 Attach/detach target on callback demand

Add a helper in `Session`:

```ts
private hasRestoredObserverSinks(): boolean
```

It should reflect the actual public callback surfaces:

```text
complete callback
log callback
statistics callback where supported
```

After a setter/remover transaction commits:

```text
if restoredRunning && has sink:
  attach callback target
else:
  detach callback target
```

Completion setter is synchronous today. Keep public signature if possible.

Because synchronous complete setter does not acquire a bridge:

```text
verify Running
mutate callback
attach/detach target immediately
```

Optional log/stat setters use G5's serialized async transaction.

## 10.7 Terminal behavior

At terminal:

```text
snapshot callbackTargets
settle those targets
do not iterate wrappers that never requested callbacks
remove/detach targets
perform G3 release-owner decision
delete entry when lifetime work is complete
```

## 10.8 Successful global clear

`invalidateAll()` should:

```text
mark entries invalidated
settle/release callback demand for attached targets
drop target sets
drop entries
```

Do not keep abandoned target references after clear.

## 10.9 1000-read regression

Do not rely on GC.

Exercise the coordinator/public history path with deterministic instrumentation.

Example:

```text
backend one Running ID
perform 1000 parse/getSession/getSessions reconstructions
never install any callback
```

Assert through an internal test seam or coordinator instance:

```text
entry count == 1
callback target count == 0 (preferred)
or bounded to one representative if implementation absolutely requires it
```

Do **not** expose a public package API solely for testing. Module-internal class access from tests is acceptable.

Then make terminal and assert:

```text
one terminal lifecycle
one release decision
no 1000-target settlement loop
entry count == 0
```

## 10.10 Callback-bearing wrapper regression

Create two wrappers for one Running ID.

Attach:

```text
wrapper A completion callback
wrapper B log callback
```

Assert:

```text
target count == 2
```

Remove A completion and B log before terminal.

Assert:

```text
target count == 0
per-ID lifetime observer remains because handle still needs terminal retirement
```

Then terminal -> release once.

## 10.11 Documentation/comments

Internal comment:

```text
// History reads ensure one ID-level observer but do not root each reconstructed
// wrapper. A wrapper is retained only while it owns a restored callback sink.
```

No public API change is required beyond the existing history-observation description.

---

# 11. R45-G5 — serialize callback setup against observer death

## 11.1 Root defect

Restored log/statistics setter setup can be asynchronous.

Terminal settlement/invalidation can execute while the setter awaits bridge installation.

The code needs a per-wrapper ownership transition, not another global lock.

## 11.2 Required source file

Primary:

```text
react-native/src/session.ts
```

Coordinator interactions in:

```text
react-native/src/session-observation.ts
```

Tests should use existing callback-demand fake hooks.

## 11.3 Add a per-session restored transition queue

A small promise chain is sufficient.

Conceptual field:

```ts
private restoredTransition: Promise<void> = Promise.resolve();
```

Helper:

```ts
private runRestoredTransition<T>(operation: () => Promise<T>): Promise<T> {
  const next = this.restoredTransition.then(operation, operation);
  this.restoredTransition = next.then(
    () => undefined,
    () => undefined
  );
  return next;
}
```

Do not expose this publicly.

All ownership-changing async restored operations must use it:

```text
async optional callback setter/update
terminal settle
successful-clear invalidation
```

This ensures terminal cleanup cannot run through the middle of a bridge-install commit.

## 11.4 Revalidate after async acquisition

Even with serialization, the native state may become terminal during the awaited install.

Within the setter transaction:

```text
1. verify Running
2. remember previous callback
3. apply tentative callback
4. acquire/refresh demand
5. await any async bridge install
6. verify restored observer is still live and authoritative state is still Running
7. sync direct-log subscription
8. attach/detach callback target (G4)
9. commit success
```

If step 6 fails:

```text
restore previous callback
refresh/release the demand created by tentative callback
remove any tentative subscription
restore target attachment to previous state
throw the terminal/not-Running error
```

The bridge-install error remains primary if installation itself failed.

## 11.5 Terminal settlement uses same transition

Split current public/internal method if needed:

```ts
async settleRestoredObservation(): Promise<void> {
  return this.runRestoredTransition(() =>
    this.settleRestoredObservationWithinTransition()
  );
}
```

Same for:

```text
invalidateRestoredObservation()
```

Do not recursively call another method that reacquires the same transition.

## 11.6 Completion callback setter

Current completion setter is synchronous.

Do not make it async unless absolutely necessary because that is a public API change.

JavaScript synchronous mutation cannot interleave with another callback in the same turn.

Required behavior:

```text
assert restored Running
set callback
attach/detach G4 callback target
```

Terminal settlement running later will see the committed value.

If a log/stat async transition is in flight, terminal settlement is serialized behind it; completion mutation can be observed by the later terminal transaction.

If this creates an unprovable edge, a generation counter may be used, but do not convert public completion setter signatures casually.

## 11.7 Harden direct log subscription predicate

`syncRestoredLogEventSubscription()` should require:

```text
restoredRunning
!restoredTerminalSettled
log callback exists
direct log bridge active
```

If G4 introduces an explicit observation-live flag, use that semantic flag instead.

Never subscribe after terminal/clear settlement.

## 11.8 Deferred install vs terminal test

Fake bridge behavior:

```text
installLogBridge() -> deferred Promise
uninstallLogBridge() -> counter
session state initially Running
```

Start:

```text
const setter = restored.setLogCallback(cb)
```

Hold installation.

Then make terminal and schedule/trigger observer terminal settlement.

Resolve installation.

Required final result:

```text
terminal settlement and setter ordering is deterministic
setter must not report an active observer after terminal
no restored log subscription remains
global log-demand count returns to baseline
callback target is detached
observer target set contains no dead wrapper
```

Acceptable public behavior:

```text
setter rejects "no longer Running"
```

Preferred over silently succeeding after terminal.

## 11.9 Cleanup error precedence

If:

```text
bridge install succeeds
terminal recheck fails
rollback uninstall also fails
```

the terminal/not-Running or primary setup error should remain primary. Cleanup failure may be logged/attached according to existing project conventions.

Do not mask the reason the setter could not establish routing.

## 11.10 Statistics race

Repeat the same deferred ownership case for statistics demand when the backend/test seam supports asynchronous install.

If statistics demand shares the same global bridge implementation, one well-designed shared test plus a statistics-specific demand assertion may be enough; do not duplicate hundreds of lines.

## 11.11 Remove callback race

When the final optional callback sink is removed:

```text
serialized transition
release its optional bridge demand
detach G4 callback target if no other restored sink exists
do not stop the ID-level lifetime observer
```

The lifetime observer remains until terminal/clear because it may own retained handle retirement.

## 11.12 Documentation

Public callback documentation:

```text
Attaching a callback to a restored Running session establishes live observer
routing transactionally. If the session becomes terminal while routing is being
installed, setup fails and any partially acquired callback demand is released.
```

Do not promise retroactive callback delivery for already-terminal sessions unless the implementation deliberately supports it.

---

# 12. Shared source changes expected

A likely minimal production diff is limited to:

```text
react-native/src/ffmpeg-kit-extended.ts
react-native/src/session.ts
react-native/src/session-queue-manager.ts
react-native/src/session-observation.ts
react-native/src/session-lifetime.ts
react-native/src/platform/backend.web.ts
react-native/README.md
```

Optional small semantic helper:

```text
react-native/src/session-cancellation.ts
```

Expected tests are within existing RN suites.

No production change is expected in:

```text
flutter/**
react-native/cpp/**
react-native/windows/**
react-native/android/**
react-native/ios/**
react-native/appletvos/**
react-native/macos/**
libs/libffmpegkit/**
```

If a production change outside the expected RN TypeScript/Web area becomes necessary, Luna must explain the concrete defect requiring it and expand validation accordingly.

---

# 13. Detailed test matrix

Use deterministic state/counters/latches. Do not rely on sleeps as proof.

| Area | Case | Required assertion |
| --- | --- | --- |
| submission | restored Running execute | rejects; 0 executor starts; 0 abandon; 0 release at rejection |
| submission | restored Completed execute | rejects; history unchanged |
| submission | restored Failed execute | rejects; history unchanged |
| handoff | Created preflight → Running before slot | preparation rejects; reservation released; no discard callback |
| queue | explicit queued cancel | executor never starts; discard runs once; promise cancelled |
| cancellation | unknown ID | documented no-op |
| cancellation | restored state read throws | public call propagates error; durable intent remains |
| cancellation | first native cancel throws | public call propagates; observer later retries |
| cancellation | retry succeeds | exactly one successful dispatch authority; no repeated native sends |
| cancellation | terminal after retry | intent + dispatch state cleared |
| release | original execution + restored observer | restored observer does not release while active execution owner exists |
| release | history-only restored Running | restored observer releases once after terminal |
| release | retirement first fails | retry succeeds; callbacks do not duplicate |
| observation | 1000 no-callback history reads | one ID observer; bounded callback targets |
| observation | two callback wrappers | only callback wrappers retained |
| observation | remove final sinks | callback targets detach; ID observer remains |
| callbacks | deferred log bridge install vs terminal | no post-terminal lease/subscription; setup fails/rolls back |
| callbacks | deferred statistics setup vs terminal | same ownership invariant |
| callbacks | clear during setup | serialized cleanup; no leaked demand |
| clear | failed backend clear | observation/cancellation authorities remain |
| clear | successful backend clear | observers + cancellation bookkeeping invalidated after commit |

---

# 14. Regression suite placement guidance

Prefer extending these existing files:

```text
react-native/tests/session-queue-manager.test.js
react-native/tests/restored-session-observer.test.js
react-native/tests/wasm-session-ownership.test.js
react-native/tests/wasm-backend-memory.test.js
react-native/tests/session-history-registry.test.js
react-native/tests/native-bridge-lifetime.test.js
```

Potential grouping:

```text
session-queue-manager.test.js
  G1 validation-vs-discard cases

restored-session-observer.test.js
  G2 retry
  G3 release ownership
  G4 target boundedness
  G5 callback transition races

wasm-backend-memory.test.js
  Web missing-ID normalization if changed
  ensure previous failure-atomic pointer coverage remains green

wasm-session-ownership.test.js
  history visibility / retained ownership invariants
```

Do not create separate test files named after Review 45.

---

# 15. Test truthfulness requirements

For every test added:

```text
assert the actual side effect, not just a rejected promise
```

Examples:

Bad:

```text
await assert.rejects(restored.executeAsync())
```

Good:

```text
await assert.rejects(...)
assert.equal(executorStarts, 0)
assert.equal(abandonCalls, 0)
assert.equal(releaseCalls, 0)
assert.equal(historyStillContainsId, true)
```

Bad:

```text
await cancelSession(id)
```

Good:

```text
assert.equal(cancelDispatchAttempts, expected)
assert.equal(cancellationIntent, expected)
assert.equal(observerRetryCount, expected)
```

Bad:

```text
run 1000 history reads and inspect process RSS
```

Good:

```text
run 1000 history reads
assert observerEntryCount == 1
assert callbackTargetCount is bounded
```

Do not fabricate test outputs. A test that did not execute is not a pass.

---

# 16. Documentation implementation guidance

## 16.1 `FFmpegKitExtended.cancelSession`

Document:

```text
ID 0 -> queue-aware cancel all
known managed ID -> object Session.cancel
known restored ID -> object Session.cancel
missing ID -> no-op
real lookup/state/native cancellation error -> propagated
durable request may be retried while restored execution remains Running
```

## 16.2 Session execution

Document:

```text
Session objects are single-use.
History wrappers can execute only if authoritative state is Created.
Running/terminal history execution requests fail without mutating the existing
session's history, cancellation, retained handle, or observer ownership.
```

## 16.3 Running history observation

Document:

```text
One per-ID observer owns restored lifetime monitoring.
Repeated history reads do not create additional execution owners.
Only wrappers with live restored callback sinks need callback-target ownership.
```

## 16.4 Restored callbacks

Document:

```text
setup is transactional
terminal-winning setup fails and rolls back
callback routing never causes re-execution
callback sink removal does not remove the underlying lifetime observer
```

## 16.5 Internal comments

Useful comments:

```ts
// Handoff validation failure is not an explicit queued discard; reject the
// submission without abandoning or releasing the existing native identity.
```

```ts
// An active execution monitor owns final retained-handle retirement through
// final callback drain. Restored observation releases only without that owner.
```

```ts
// The ID-level observer outlives individual history wrappers. Strong wrapper
// targets exist only while they own restored callback sinks.
```

```ts
// Restored callback setup and terminal cleanup share one transition so an
// asynchronous bridge install cannot commit after observer termination.
```

Do not write historical review prose in production comments.

---

# 17. Focused implementation sequence

Follow this order to avoid fixing symptoms against an unstable lifetime model.

```text
1. Read Review 45 code review completely.

2. Verify source SHA and frozen submodule.

3. Read current queue/session tests around:
     executeSession
     prepareForExecution
     cancelQueued
     restored observer
     release serialization
     callback-demand fakes

4. Implement G1:
     add initial authoritative submission validation
     make handoff validation rejection non-destructive

5. Add G1 tests and run them.

6. Implement G2:
     narrow unknown-ID handling
     shared per-ID cancellation dispatch
     restored Running retry

7. Add G2 state-failure/native-cancel-failure retry tests.

8. Implement G3:
     add active-only queue-owner query
     prevent restored release while original execution owner is active

9. Add G3 latch-based final-drain ordering tests.

10. Implement G4:
      split ID-level observer from callback-target retention
      attach/detach only callback-bearing wrappers

11. Add G4 1000-history-read bounded-target regression.

12. Implement G5:
      serialize callback setup vs terminal/clear cleanup
      add post-install Running/liveness recheck
      harden direct-log subscription predicate

13. Add deferred bridge-install race tests.

14. Run all focused queue/cancellation/restored-observer/Web ownership tests.

15. Run npm typecheck/test compilation/lint.

16. Run complete local RN JS test suite.

17. Run affected Web/Wasm validation if backend.web.ts changed.

18. Run established local RN build matrix using existing local ABI artifacts:
      Windows
      Android on Windows
      Apple iOS/tvOS/macOS last
    Use WSL only for source/C++ checks that are actually affected/required.

19. Do not launch interactive applications.

20. Inspect git diff and revert unrelated refactors.

21. Re-audit Flutter + platform-native source for accidental drift.

22. Perform final substantive RN wrapper audit.

23. If another substantive defect is found:
      record it
      do not claim closure
      do not hide it

24. If clean:
      freeze exact wrapper SHA
      push it
      run one wrapper-only source snapshot
      download and verify the artifact
      record provenance
```

---

# 18. Focused local validation after implementation

Review 45 itself is code review only and claims no execution.

After implementation, use local gates only.

## 18.1 React Native focused gates

From the RN package:

```text
npm run typecheck
npm run test:compile
npm run lint
```

Then explicit focused tests covering the goals.

Record exact pass/fail/skip totals.

## 18.2 Full RN suite

Run the repository's normal complete local Node test suite.

Do not hide skipped Windows-only cases on Apple or platform-specific skips.

## 18.3 Web/Wasm

If `backend.web.ts` changes for narrow missing-ID normalization:

```text
run the focused Wasm memory/ownership suite
run the established Web/Wasm package/runtime gate used by prior reviews
```

Do not add browser UI interaction.

## 18.4 Native shared C++

No C++ production change is expected.

A bounded existing source/lifetime oracle may be rerun to confirm RN TypeScript changes did not alter the bridge contract.

If C++ production source changes unexpectedly, stop and explain why the platform-native bridge had to be reopened; expand validation accordingly.

## 18.5 Platform builds

Because RN TypeScript lifecycle behavior ships across native platforms, use the established local builds:

```text
Windows RN
Android RN on local Windows
Apple RN iOS/tvOS/macOS last
```

Use only configured local ABI `0.11.2` artifacts.

## 18.6 Flutter

If no Flutter/shared packaging source changes:

```text
do not rerun the full Flutter platform matrix merely for ceremony
```

Perform a bounded source no-drift check and preserve accepted prior validation.

If shared package/build infrastructure changes, expand Flutter validation accordingly.

## 18.7 Hosted workflow prohibition

Do not run hosted test/build acceptance workflows.

The final exact-SHA wrapper source snapshot is the only allowed hosted workflow.

---

# 19. Result recording

For every command actually executed, record:

```text
platform
working directory
exact command
exit status
pass/fail/skip counts where available
whether acceptance evidence or diagnostic only
```

Never call these a pass:

```text
source inspection
skipped command
timeout
killed process
compile that never started
an old review's result presented as a new run
a platform unavailable locally
```

If the first command fails because of environment configuration and a corrected retry passes, record both.

---

# 20. Final substantive audit matrix

After implementation/tests, re-read final source.

## 20.1 G1 submission/discard

Confirm:

```text
submitOnce rejects non-Created history before queue insertion
queue handoff still revalidates state
handoff validation failure does not invoke onDiscard
queue reservation always releases
explicit queued cancellation still invokes onDiscard
Running/terminal invalid execute does not abandon/release
```

## 20.2 G2 cancellation

Confirm:

```text
static ID cancel has no blanket catch
missing ID no-op is represented narrowly
real state/native error propagates
durable intent remains after failure
restored Running observer retries
successful dispatch dedupes by ID
terminal/clear cleans dispatch state
```

## 20.3 G3 release ownership

Confirm:

```text
active execution owner visible via active-only queue query
restored observer does not release while active owner exists
ordinary monitor still releases after final callback drain
history-only restored observer releases at terminal
release retry does not repeat completion callbacks
```

## 20.4 G4 bounded targets

Confirm:

```text
sessionFromSnapshot(Running) ensures ID observer
history read without callbacks does not root wrapper
callback setter attaches target
final callback removal detaches target
terminal/clear empties target set
one ID entry per session regardless of history-read count
```

## 20.5 G5 callback transaction

Confirm:

```text
optional callback update serialized with terminal/invalidate
state/liveness rechecked after async bridge acquisition
partial demand released on terminal-winning race
direct log subscription checks terminal status
setter never returns success with dead routing
```

## 20.6 Flutter/platform-native

Confirm no source drift unless separately justified.

## 20.7 Finding threshold

Open another finding only when all exist:

```text
reachable code path
actual lifecycle/API/ownership/concurrency violation
concrete product consequence
```

Do not report style, naming, test organization, or refactor preferences.

---

# 21. Exact wrapper freeze and source snapshot

Only after all applicable goals/tests/audit gates are complete:

1. Verify `libs/libffmpegkit` remains at the frozen SHA.
2. Verify no builders checkout change.
3. Remove task-owned staging/cache/log output that should not be committed.
4. Commit/push the wrapper remediation with semantic messages.
5. Record the exact 40-character final wrapper SHA.
6. Dispatch **one** wrapper-only source snapshot at that exact SHA.
7. Do not dispatch hosted Flutter/RN acceptance workflows.
8. Do not create a native/builders snapshot.
9. Retrieve the source artifact through the established connector workflow path.
10. Verify:
    - outer artifact digest;
    - `source.tar.gz.sha256`;
    - every `SHA256SUMS` entry;
    - `SUBMODULES.txt`;
    - `SYMLINKS.tsv`;
    - `snapshot-metadata.json`;
    - exact `snapshot_sha`;
    - `runtimeExecution=false`.
11. Treat later tracker/mailbox commits as discovery metadata, not source authority.

If the same-repository mailbox is still absent, use the run/artifact provenance recorded by the tracker as the documented fallback and verify the artifact directly.

---

# 22. Tracker/final closeout requirements

Record:

```text
Review 45 starting wrapper SHA
  2b4b902b0aa918d871659380475ebf6ec3bb06d3

R45-F1 through R45-F5 disposition

exact production files changed
exact tests added/updated

G1 evidence:
  Running/terminal invalid execute is non-destructive
  Created->Running queue race is non-destructive
  explicit queue cancellation still discards

G2 evidence:
  unknown ID behavior
  state-read failure propagation
  native-cancel failure propagation
  durable observer retry
  per-ID dedupe
  terminal/clear cleanup

G3 evidence:
  active execution owner blocks restored release
  final callback drain precedes release
  history-only release
  release failure retry

G4 evidence:
  repeated history reads target cardinality
  callback attach/detach counts
  terminal/clear cleanup

G5 evidence:
  deferred bridge install race
  setter result
  acquired/released lease counts
  direct subscription cleanup
  statistics parity

RN focused/full test results
Web/Wasm results actually run
native platform builds actually run

confirmation Flutter production source unchanged unless justified
confirmation platform-native source unchanged unless justified
confirmation native ABI/submodule/builders unchanged

exact final wrapper SHA
snapshot workflow run ID
snapshot artifact ID/name/link
outer digest
source.tar.gz digest
manifest count
symlink count
runtimeExecution=false
frozen submodule SHA
```

Do not write "all platforms pass" unless each named platform was actually executed in this remediation.

---

# 23. Anti-patterns Luna must reject

## 23.1 Calling `onDiscard` after any preparation error

Do not preserve:

```text
prepareForExecution throws
-> onDiscard
-> abandon/release
```

A validation error can mean the native identity is already Running/terminal.

## 23.2 Removing `prepareForExecution`

Do not rely only on initial preflight. Queue delay creates a real second handoff race.

## 23.3 Letting history wrappers execute again

The fix is not to accept Running/terminal execution.

## 23.4 Keeping the blanket `catch {}` in static cancellation

Unknown-ID compatibility does not justify hiding native/state/runtime failures.

## 23.5 Recording intent without delivery authority

Durable cancellation is incomplete if the only monitor capable of retrying is absent.

## 23.6 Treating release serialization as lifetime ownership

`releaseSessionHandleSerialized` prevents duplicate transactions; it does not prove the first caller is allowed to retire the handle.

## 23.7 Waiting for GC to solve restored target growth

The coordinator itself owns strong references. GC cannot collect those wrappers.

## 23.8 Using `WeakRef` as the only correctness mechanism

Weak references may reduce retention but do not define callback-sink ownership or deterministic terminal settlement. Prefer explicit attach/detach.

## 23.9 Turning every reconstructed wrapper into an observer target

Per-ID lifetime observation must not scale with history-read count.

## 23.10 Allowing terminal cleanup and async setter setup to interleave

A post-terminal callback bridge lease is a real resource leak.

## 23.11 Making completion callback setter async casually

Avoid public API churn. Solve async ownership where it actually exists.

## 23.12 Reopening native ABI or platform-native code

Not required by Review 45 findings.

## 23.13 Broad refactor

Do not redesign the entire Session class, queue, backend registry, or callback system.

## 23.14 Hosted CI acceptance

Not permitted. Local gates plus final source snapshot only.

---

# 24. Definition of done

Review 45 final wrapper closure is complete only when every applicable item is true:

```text
[ ] Restored Running executeAsync rejects before destructive queue discard.
[ ] Restored terminal executeAsync rejects before destructive queue discard.
[ ] Queue handoff validation failure releases reservation only.
[ ] Queue handoff validation failure does not call abandonCreatedSession.
[ ] Queue handoff validation failure does not release existing retained ownership.
[ ] Explicit queued Created cancellation still uses discard cleanup.
[ ] Created->non-Created handoff race is covered deterministically.

[ ] Static cancelSession(id) no longer swallows arbitrary restored errors.
[ ] Unknown ID remains a narrow tested no-op if compatibility requires it.
[ ] Restored state-read failure propagates.
[ ] Restored native cancel failure propagates.
[ ] Durable cancellation intent survives those failures.
[ ] Restored Running observation retries pending cancellation.
[ ] Native cancellation dispatch is deduplicated per session ID.
[ ] Failed dispatch is retryable.
[ ] Terminal/clear removes cancellation dispatch bookkeeping.

[ ] Active execution owner is detectable by native session ID.
[ ] Restored terminal observation never releases while that active owner exists.
[ ] Original execution monitor retains final callback-drain release authority.
[ ] History-only restored observer releases promoted ownership exactly once.
[ ] Release failure remains retryable.
[ ] Completion callbacks are not duplicated by release retry.

[ ] Per-ID observer state does not strongly retain every history wrapper.
[ ] 1000 no-callback history reads keep callback target count bounded.
[ ] Callback-bearing wrappers attach explicitly.
[ ] Removing final restored sink detaches wrapper target.
[ ] Lifetime observer remains even with zero callback sinks until terminal/clear.
[ ] Terminal/clear removes entry/targets.

[ ] Restored log/stat callback setup is serialized with terminal settlement.
[ ] Restored callback setup is serialized with successful-clear invalidation.
[ ] Async bridge install is followed by live/Running revalidation.
[ ] Terminal-winning setup releases partial demand.
[ ] Terminal-winning setup cannot install a direct-log subscription.
[ ] Terminal-winning setup does not report a live observer.
[ ] Callback bridge demand returns to baseline.

[ ] Focused RN regressions pass.
[ ] Typecheck/test compilation/lint results are recorded.
[ ] Full local RN suite result is recorded truthfully.
[ ] Affected Web/Wasm gates are recorded.
[ ] Required local RN platform builds actually executed are recorded.
[ ] No interactive runtime validation is claimed.

[ ] Flutter reviewed lifecycle source remains clean.
[ ] Platform-native bridge remains closed.
[ ] No native ABI/submodule/builder change occurred.
[ ] No remote old native artifact was fetched.
[ ] No hosted Flutter/RN acceptance workflow was used.
[ ] Final bounded code review finds no substantive open Flutter/RN/platform-native defect.
[ ] Exact final wrapper SHA is pushed/frozen.
[ ] One wrapper-only source snapshot at that exact SHA is downloaded and verified.
[ ] Snapshot metadata records runtimeExecution=false.
```

If any applicable item is false, do not declare full Flutter/React Native closure.

---

# 25. Expected final closeout if Review 45 remediation is clean

Use a factual summary, not a generic "all done":

```text
Platform-native bridge:
  closed; unchanged from prior frozen authority.

Flutter wrapper:
  closed in audited lifecycle/session surfaces; no Review 45 production change.

React Native wrapper:
  invalid history re-submission is non-destructive;
  durable restored cancellation is truthful/retryable;
  original execution monitor retains final-release authority;
  history polling has bounded observer targets;
  restored callback setup is terminal-race-safe.

Native ABI:
  remains frozen at 0.11.2;
  no native/submodule/builders change.

Validation:
  list only commands/platforms actually executed.

Source authority:
  exact final wrapper SHA + one verified wrapper-only snapshot.
```

Only use this closeout after the final bounded source audit finds **zero** remaining substantive findings.
