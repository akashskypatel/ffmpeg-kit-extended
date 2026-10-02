# Review 46 — Luna Flutter + React Native Final Closure Plan

**Project:** FFmpegKitExtended  
**Audience:** Luna implementation/review model  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch:** `dev-wasm`  
**Starting source authority:** `d150cebfc406c2cd61ce66f5e779debc9bed0c75`  
**Review basis:** `review-46-flutter-react-native-code-review.md`  
**Native ABI/runtime:** frozen `0.11.2`  
**Frozen native submodule:** `b74da2c5d1e294b87d15d73a6687393729e932b3`

---

# 1. Goal tracker

| Goal | Objective | Primary implementation | Required tests | Documentation | Status |
| --- | --- | --- | --- | --- | --- |
| **R46-G1** | Make every submission-preflight failure non-destructive | Remove pre-admission retained-handle release on state/backend probe failure; preserve actual start-failure cleanup | restored Running probe failure, terminal/history probe failure, retry after transient failure, existing non-Created and handoff cases | execution/history contract | ☐ |
| **R46-G2** | Keep terminal release retry authority alive through active-owner settlement and make retries iterative | Preserve terminal observer entry while active executor owns finalization; after active owner leaves, use one iterative release-retry phase | active owner release failure, history-only repeated failures, clear during retry, callbacks once | lifetime comments | ☐ |
| **R46-G3** | Bound per-ID lifecycle bookkeeping | Remove or bound completed-release and invalidated-ID tombstones; keep correctness in live/in-flight state | many unique releases, many clear-invalidated IDs, duplicate/stale release safety | ownership comments | ☐ |
| **R46-G4** | Preserve terminal restored-observer errors | Report settlement errors directly even if target detached during settlement | throwing completion, cleanup failure if seam exists, release still proceeds | restored callback error contract | ☐ |
| **R46-G5** | Perform final focused validation, substantive audit, exact-SHA freeze and source snapshot if clean | No unrelated refactor; wrapper-only closeout | focused + full affected local gates; no hosted acceptance CI | tracker/provenance + closeout summary | ☐ |

---

# 2. Mission

Review 46 preserves these conclusions:

```text
platform-native bridge: closed
Flutter wrapper audited lifecycle/session surfaces: closed
React Native wrapper: four remaining failure-path findings
```

The task is therefore **React Native wrapper lifetime closure**, not another native ABI, C++, Flutter, or platform-native rewrite.

Required outcomes:

```text
1. A submission that fails before queue admission never owns destructive native cleanup.
2. Restored terminal release authority survives until the active execution owner has actually settled.
3. Retained-release retries are iterative and bounded in memory.
4. Per-ID wrapper bookkeeping scales with live/in-flight work, not total historical sessions.
5. Restored terminal callback/cleanup errors remain observable through the established reporter.
6. Final audit closes only if no substantive Flutter/RN/platform-native finding remains.
```

---

# 3. Non-negotiable constraints

Luna must treat all of these as mandatory:

1. Work in `akashskypatel/ffmpeg-kit-extended`, branch `dev-wasm`.
2. Reconcile against exact starting wrapper source `d150cebfc406c2cd61ce66f5e779debc9bed0c75`.
3. Keep native ABI/runtime pinned to **0.11.2**.
4. Keep `libs/libffmpegkit` frozen at `b74da2c5d1e294b87d15d73a6687393729e932b3`.
5. Do not download or re-review native ABI source/artifacts.
6. Do not edit or rebuild `libs/libffmpegkit`.
7. Do not edit/rebuild the ManyLinux builders checkout.
8. Do not add or change native ABI exported symbols.
9. Do not publish native ABI artifacts.
10. Do not fetch a remotely built old native bundle for local validation.
11. Use only existing locally configured/package ABI `0.11.2` artifacts.
12. Do not run hosted Flutter/React Native test/build workflows as acceptance evidence.
13. The only hosted workflow allowed at final closure is the exact wrapper source-snapshot workflow.
14. Do not automatically launch interactive Flutter/RN apps, simulators, devices, or Web UI.
15. Interactive validation remains user-owned.
16. Do not change Flutter production code unless a new reachable Flutter defect is proven.
17. Do not reopen platform-native bridge code merely for symmetry or cleanup.
18. Do not change shared C++ production code for any Review 46 finding; the existing absent-entry release contract is sufficient.
19. Production/test identifiers must be semantic; never use `R46`, `G1`, `F1`, review names, or tracker wording in implementation symbols.
20. Never fabricate tests or test results.
21. Do not weaken existing tests.
22. Record failed commands, retries, skipped gates, environment corrections, and partial validation truthfully.
23. Exclude pedantic/style/procedural findings from the final audit.
24. A new finding requires a reachable path plus a concrete API/lifetime/resource consequence.
25. Make surgical changes only; no general Session/queue/callback framework rewrite.
26. Preserve all Review 45 corrected behavior unless a Review 46 fix directly changes the relevant failure path.

---

# 4. Frozen source provenance to preserve

Review 46 authority is the verified Review 45 source snapshot:

```text
wrapper SHA:
  d150cebfc406c2cd61ce66f5e779debc9bed0c75

workflow run:
  37056546191

artifact:
  review45-source-snapshot-37056546191

artifact ID:
  11248243890

artifact SHA-256:
  a79191d57ba62cf3525c9704502f6b29e39f66289fc07922b3c21ce773528e70

source.tar.gz SHA-256:
  df306046866e649dc070fecc4931f2a832f8e410ad420f06b4907dc35efc37a1

SHA256SUMS:
  1101/1101 verified

SYMLINKS.tsv:
  0 entries

runtimeExecution:
  false

submodule:
  b74da2c5d1e294b87d15d73a6687393729e932b3 libs/libffmpegkit
```

The same-repository source-snapshot mailbox path was absent at Review 46 discovery time. If it remains absent at final closeout, use tracker-recorded exact run/artifact provenance as the documented fallback and verify the artifact directly.

---

# 5. Source boundary to preserve

Review 45 changed only React Native TypeScript/Web lifecycle code plus tests/docs.

The following are unchanged and should remain unchanged through Review 46 unless a new concrete defect is proven:

```text
flutter/lib/**
flutter/native/**
flutter/windows/**
flutter/linux/**
flutter/android/**
flutter/ios/**
flutter/macos/**

react-native/cpp/**
react-native/windows/**
react-native/android/**
react-native/ios/**
react-native/appletvos/**
react-native/macos/**

libs/libffmpegkit/**
```

Likely Review 46 production scope is limited to:

```text
react-native/src/session.ts
react-native/src/session-observation.ts
react-native/src/session-lifetime.ts
react-native/README.md
```

Tests should remain within existing RN test infrastructure.

Do not touch `session-cancellation.ts`, `backend.web.ts`, or `session-queue-manager.ts` unless a specific implementation need appears while preserving their Review 45 semantics.

---

# 6. Architectural model Luna must preserve

Keep these authorities distinct:

```text
submission preflight
  observes whether admission may begin; it does not own cleanup

queue reservation
  JS concurrency/admission identity

explicit queue discard
  intentional destruction of never-started queued Created work

native execution start
  first point where a failed start may legitimately own execution-handle cleanup

active execution monitor
  final log/statistics/completion owner for a submitted execution

restored terminal observer
  fallback owner for a Running history identity when no active execution owner remains

release transaction
  backend retained-handle retirement; retryable on failure

release serialization
  prevents overlapping release transactions; should be bounded to in-flight work

callback target
  wrapper with live restored callback sinks

observer diagnostic reporter
  asynchronous failure surface for restored observation, which has no execution Promise
```

Core rules:

```text
preflight failure != start failure
active owner exists != active owner release succeeded
retry authority != recursive call chain
process-unique ID != reason to keep a permanent JS tombstone
self-detach != permission to drop the operation's own error
```

---

# 7. R46-G1 — make submission preflight completely non-destructive

## 7.1 Root defect

`Session.submitOnce()` correctly special-cases `SessionNotCreatedError` and `SessionCancelledException`, but for any other `validateInitialSubmission()` failure it calls `releaseOwnedHandle()`.

A state/backend read can throw before queue admission.

For a history/restored Running identity this destroys retained ownership even though the submission never started.

## 7.2 Required file

Primary:

```text
react-native/src/session.ts
```

Tests likely in:

```text
react-native/tests/restored-session-observer.test.js
react-native/tests/wasm-session-ownership.test.js
react-native/tests/session-queue-manager.test.js
```

## 7.3 Preferred implementation

Treat `validateInitialSubmission()` as a pure admission observation.

Change `submitOnce()` from the current generic cleanup branch to:

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
    // Admission never started. A failed observation does not own native cleanup.
    return Promise.reject(error);
  }

  this.submitted = true;
  return submit();
}
```

The exact code can differ, but **no preflight exception may call**:

```text
abandonCreatedSession
releaseOwnedHandle
releaseSessionHandleSerialized
```

## 7.4 Why this does not remove needed cleanup

Keep cleanup in `startNativeExecution()` for actual native-start failure.

Distinguish:

```text
validateInitialSubmission/getState fails
  -> no queue/native start committed
  -> preserve identity

executeSessionAsync fails after handoff begins
  -> executor owns failed-start cleanup
```

Do not move start cleanup earlier to compensate.

## 7.5 Existing test that must be reconsidered

The existing Wasm ownership test named approximately:

```text
state retrieval failure releases the owning handle and rejects
```

encodes the destructive preflight behavior.

Do not blindly preserve a test whose expected result conflicts with the corrected ownership contract.

Replace/strengthen it to prove:

```text
state retrieval failure before admission rejects
native executor does not start
handle is not released by preflight
wrapper/session remains retryable after state probe recovers
```

If there is a separate scenario where state retrieval fails **inside an already-started monitor**, keep that scenario's execution-owner cleanup semantics distinct.

## 7.6 Restored Running regression

Setup:

```text
ID 2001 snapshot = Running
getSession(2001) creates restored wrapper + observer
backend retained handle exists
state reads can be fault-injected
```

Inject:

```text
getSessionState(2001) -> throw sentinelStateError
```

Call:

```text
restored.executeAsync()
```

Assert:

```text
promise rejects sentinelStateError
executionStarts == 0
abandonCalls == 0
releaseCalls == 0
history still contains 2001
observer entry still exists
callback target count unchanged
```

Recover the state reader:

```text
state -> Running
```

Then later:

```text
state -> Completed
```

Assert the same restored observer completes its normal terminal release once.

## 7.7 Terminal history regression

Use a terminal snapshot wrapper and a faulted state reader.

Assert failed `executeAsync()` does not invoke retained release/abandonment or remove terminal history.

## 7.8 Retry regression

For a fresh Created wrapper:

```text
first state preflight -> throws transient error
second state preflight -> Created
second executeAsync -> starts exactly once
```

This proves preflight error recovery instead of destructive cleanup.

## 7.9 Documentation

Update execution/history documentation semantically:

```text
Submission validation is non-destructive. If the wrapper cannot read authoritative
state before queue admission, execution fails without abandoning or releasing the
session identity; the caller may retry after the state/runtime problem is resolved.
```

Do not promise retry if another independent terminal/cancellation transition made the session no longer executable.

---

# 8. R46-G2 — keep one bounded terminal release fallback until retirement commits

## 8.1 Root defect

Current terminal coordinator behavior:

```text
terminal callbacks settle
if active execution owner exists:
  delete restored observer entry
  return
```

This proves only that the active monitor **will attempt** final release, not that release **will succeed**.

If that release fails and the queue then removes the active session, retry authority has already been discarded.

The history-only branch has the opposite problem: it keeps retrying, but does so recursively.

## 8.2 Required files

Primary:

```text
react-native/src/session-observation.ts
```

Potential supporting source:

```text
react-native/src/session-queue-manager.ts
react-native/src/session-lifetime.ts
```

No shared C++ production edit is expected.

## 8.3 Required state model

One terminal observer entry should have conceptual phases:

```text
RunningObservation
TerminalCallbacksSettled
WaitingForExecutionOwner
ReleasePending
Released
InvalidatedByClear
```

Do not necessarily create an enum; the behavior matters.

Important invariant:

```text
entry deletion happens only after:
  successful retained release/no-op confirmation
or
  successful global clear invalidates the entry
```

The presence of an active owner alone is not a deletion condition.

## 8.4 Preferred iterative structure

Reshape terminal handling so callback settlement is one-shot and release ownership is a loop.

Conceptually:

```ts
private async settleTerminalEntry(entry: ObservationEntry): Promise<void> {
  if (!entry.terminalSettled) {
    entry.terminalSettled = true;
    await this.settleTargetsOnce(entry);
    this.clearTerminalCancellationState(entry.sessionId);
  }

  while (
    !entry.invalidated &&
    this.entries.get(entry.sessionId) === entry
  ) {
    if (SessionQueueManager.shared.isSessionActiveById(entry.sessionId)) {
      await sleep(POLL_INTERVAL_MS);
      continue;
    }

    try {
      await releaseSessionHandleSerialized(entry.sessionId);
      if (this.entries.get(entry.sessionId) === entry) {
        this.entries.delete(entry.sessionId);
      }
      return;
    } catch (error) {
      this.reportTerminalReleaseError(entry, error);
      await sleep(POLL_INTERVAL_MS);
    }
  }
}
```

Exact factorization may differ.

## 8.5 Why active owner must be waited out

`SessionQueueManager.active` remains populated until the execution Promise has completed/rejected.

The ordinary monitor attempts retained release before that Promise resolves/rejects.

Therefore:

```text
active == true
  -> final drain/release attempt is not fully settled yet

active transitions false
  -> original monitor has finished its finalization path
```

Only after active becomes false can the restored observer safely determine whether a fallback release call is needed.

## 8.6 Why fallback release after active false is safe

The wrapper/native backends already treat release of an absent retained entry as harmless/no-op.

So after active owner completion:

```text
original release succeeded
  -> fallback release sees absent/completed ownership and is harmless

original release failed
  -> retained ownership remains and fallback release retries it
```

R46-G3 may simplify wrapper completed-release bookkeeping; do not rely on an unbounded completed-ID Set for correctness.

## 8.7 Remove recursive retry

Do not retain:

```ts
await this.settleTerminalEntry(entry);
```

from the release-failure branch.

Use an iterative loop or return to the outer observer loop.

Required properties:

```text
terminal callbacks settle once
release may retry many times
memory used by one entry remains O(1)
no growing Promise recursion chain
clear can interrupt the retry phase
```

## 8.8 Active-owner failure test

Use deterministic gates.

Arrange:

```text
ID 2002 normal execution is active
same ID has restored observer
terminal state visible
restored observer reaches terminal while active == true
original final-drain release attempt fails once
execution promise rejects
active set becomes empty
second release attempt succeeds
```

Assert:

```text
restored entry is NOT deleted merely because active == true
release attempt count == 2 wrapper attempts
native retained release commit == 1
terminal callbacks == 1
observer entry removed only after successful fallback
```

If the fake backend counts method invocations rather than native commit, distinguish those counters.

## 8.9 History-only repeated failure test

Arrange:

```text
ID 2003 Running history-only observer
state -> Completed
release fails first 5 attempts
release succeeds on sixth
```

Assert:

```text
completion callback count == 1
log/stat terminal drain count == 1
release attempts == 6
entry count remains 1 during retry
entry count == 0 after success
```

Also include a source-level assertion or direct code review gate that terminal release retry no longer recursively calls `settleTerminalEntry`.

## 8.10 Clear during release retry

Arrange a persistent release failure, wait until retry phase, then commit a successful global clear.

Assert:

```text
observer invalidates/stops
no further release retry occurs after clear invalidation
callback targets are not re-fired
```

## 8.11 Documentation/comments

Internal comment:

```text
// An active execution owner gets the first final-release attempt, but restored
// terminal observation remains the fallback authority until that owner settles.
// After active ownership ends, an idempotent serialized release confirms or
// retries retained retirement before the observer entry is removed.
```

No public native-ownership implementation detail is necessary in the README.

---

# 9. R46-G3 — bound process-wide per-ID lifecycle bookkeeping

## 9.1 Root defect A: completed release tombstones

Current `session-lifetime.ts`:

```ts
const releasesInFlight = new Map<number, Promise<void>>();
const releasesCompleted = new Set<number>();
```

Every successful release adds a process-unique ID.

For normal sessions that are not reconstructed again, the ID is never removed.

## 9.2 Root defect B: clear invalidation tombstones

Current `session-observation.ts`:

```ts
private readonly invalidatedSessionIds = new Set<number>();
```

Every successfully clear-invalidated restored observer ID is added and never removed.

## 9.3 Preferred release implementation

Use the backend's existing idempotent absent-entry behavior for stale sequential release calls.

Keep only **in-flight** serialization:

```ts
const releasesInFlight = new Map<number, Promise<void>>();

export async function releaseSessionHandleSerialized(
  sessionId: number
): Promise<void> {
  const existing = releasesInFlight.get(sessionId);
  if (existing) return existing;

  const release = Promise.resolve().then(() =>
    getBackend().releaseSessionHandle(sessionId)
  );
  releasesInFlight.set(sessionId, release);

  try {
    await release;
  } finally {
    if (releasesInFlight.get(sessionId) === release) {
      releasesInFlight.delete(sessionId);
    }
  }
}
```

Then remove:

```text
releasesCompleted
registerSessionWrapper
constructor-time completed tombstone reset
```

Why safe:

```text
concurrent callers -> share one in-flight Promise
later stale caller after success -> backend sees no retained entry/pointer and no-ops
failure -> in-flight entry removed, later caller can retry
memory -> returns to zero after transaction settles
```

This keeps correctness bounded by live work.

## 9.4 Confirm backend idempotence; do not change it

The current source already has:

```text
native shared C++ releaseRetainedSession:
  retainedSessionHandles.find(id) == end -> return

Web releaseSessionHandle:
  sessions.get(id) missing -> return
```

Use that existing behavior. No C++ or native ABI edit is needed.

## 9.5 Remove constructor ownership-epoch reset

`registerSessionWrapper(sessionId)` is not a real native ownership epoch: history reconstruction creates a JavaScript object, not a new retained native session.

Removing the completed Set should also remove this constructor hook.

Do not replace it with another process-lifetime history-ID Set.

## 9.6 Preferred restored-clear implementation

Avoid permanent `invalidatedSessionIds`.

Current Review 45 correctness barriers already include:

```text
entry.invalidated
entries map identity check
restored callback transition serialization
post-install authoritative Running/liveness recheck
restoredTerminalSettled on attached target invalidation
```

For the clear/setup race, the post-install state recheck is the key guarantee because backend clear already committed.

Preferred minimal change:

```text
remove invalidatedSessionIds
entries.clear() + entry.invalidated remains the coordinator lifecycle boundary
```

Then verify the existing clear-vs-deferred-install regression still passes.

If an additional race guard is actually required, use a bounded coordinator generation:

```ts
private clearGeneration = 0;
```

Capture generation when an entry/transition begins and reject stale commit after generation changes. A scalar generation is bounded; a process-history Set is not.

Do not add another ID tombstone collection.

## 9.7 Internal test seams

It is acceptable for tests to import module-internal helpers or expose non-public test-only counts such as:

```text
inFlightReleaseCount
observerEntryCount
callbackTargetCount
```

Do not add a public package API merely to inspect memory bookkeeping.

## 9.8 Many-release boundedness test

Use a fake backend whose release is idempotent by retained registry state.

For IDs 1..10000:

```text
register fake retained ownership
call releaseSessionHandleSerialized(id)
await completion
```

Assert:

```text
in-flight release bookkeeping == 0 after each/at end
no completed-ID Set exists/grows
native release commit count == 10000
```

Then call stale sequential releases for selected IDs and assert:

```text
wrapper method may reach backend
backend native release commit remains unchanged because ownership is absent
no error
```

## 9.9 Many-clear boundedness test

For many batches of unique restored IDs:

```text
ensure observer
successful clear/invalidate
```

Assert after each batch:

```text
observer entries == 0
callback targets == 0
no permanent invalidated-ID count grows
```

Keep the existing deferred bridge-install vs clear test to prove race safety without the tombstone Set.

## 9.10 Documentation/comments

Internal release comment:

```text
// Only overlapping release calls require wrapper-side serialization. Backends
// treat release of an already-absent retained ID as an idempotent no-op, so
// completed process-unique IDs are not retained in JavaScript bookkeeping.
```

Internal clear comment:

```text
// Clear invalidates live entries/transactions; it does not retain historical
// session IDs after those transitions have settled.
```

No public documentation change is required for bookkeeping implementation.

---

# 10. R46-G4 — report terminal restored errors even after target detachment

## 10.1 Root defect

Terminal target settlement intentionally may throw a completion callback or cleanup error.

The target marks itself terminal and detaches before throwing.

The coordinator currently catches the error but calls a helper that reports only when the target is still in `callbackTargets`.

That condition is false by construction after terminal settlement.

## 10.2 Required file

Primary:

```text
react-native/src/session-observation.ts
```

Potential tests:

```text
react-native/tests/restored-session-observer.test.js
```

## 10.3 Surgical implementation

For terminal settlement only, report directly:

```ts
for (const target of [...entry.callbackTargets]) {
  try {
    await target.settleRestoredObservation();
  } catch (error) {
    target.reportRestoredObserverError(error);
  } finally {
    entry.callbackTargets.delete(target);
  }
}
```

Do not gate this catch on current membership.

The target is the exact owner whose terminal operation threw. Its intentional self-detach does not invalidate the error result.

## 10.4 Preserve steady-state attachment guard

Do not automatically change the Running polling catch:

```text
pollRestoredCallbacks error
```

A wrapper can intentionally remove its last sink during asynchronous work. The existing attached-target check can remain there if it is needed to avoid reporting after deliberate detach.

The issue is specifically the terminal operation's own thrown result.

## 10.5 Throwing completion regression

Setup:

```text
Running restored FFmpeg session
completion callback throws sentinelCompletionError
```

Capture the observer diagnostic surface used by tests (`console.warn` or injected reporter seam).

Make state terminal.

Assert:

```text
completion callback count == 1
sentinelCompletionError reported exactly once
callback target detached
observer terminal release still proceeds/retries according to G2
no unhandled rejection
```

## 10.6 Cleanup-error regression

If existing callback-demand fakes allow an uninstall failure without adding infrastructure:

```text
install restored log callback
make terminal
uninstall bridge throws sentinelCleanupError
```

Assert:

```text
sentinelCleanupError reported
terminal callback target detached
release lifecycle continues
```

Do not weaken primary-error precedence inside `settleRestoredObservation()`.

## 10.7 Documentation

If public callback documentation discusses restored observers, add one sentence equivalent to:

```text
Exceptions raised by restored observer callbacks cannot reject an execution
Promise because no new execution is being owned; they are reported through the
observer diagnostic path while terminal lifetime cleanup continues.
```

If the project intentionally keeps this as internal behavior, an internal comment and deterministic test are sufficient.

---

# 11. Review 45 behavior that must not regress

Keep every item below intact:

```text
static cancelSession(0) -> queue-aware cancel all
managed ID cancellation -> Session.cancel
unknown ID -> narrow compatibility no-op
real lookup/state/native cancellation failure -> propagated
shared per-ID cancellation dispatch dedupe
failed cancellation dispatch -> retryable
restored Running observer retries durable cancellation
terminal/clear clears cancellation dispatch bookkeeping

non-Created successful state observation -> non-destructive execution rejection
queue handoff validation failure -> reservation-only rejection
explicit queued cancellation -> Created abandonment/discard cleanup

one ID-level restored observer per Running ID
no-callback history reads -> no strong wrapper target
callback-bearing wrappers attach/detach targets
restored callback setup serialized with terminal/clear cleanup
post-install Running/liveness recheck
no post-terminal direct-log subscription
Web missing pointer normalized narrowly
Web state-probe ownership remains failure-atomic
```

---

# 12. Expected production diff

A minimal correct Review 46 implementation should normally touch only:

```text
react-native/src/session.ts
react-native/src/session-observation.ts
react-native/src/session-lifetime.ts
react-native/README.md                 (only semantic behavior updates)
```

Expected test updates:

```text
react-native/tests/restored-session-observer.test.js
react-native/tests/wasm-session-ownership.test.js
possibly react-native/tests/session-queue-manager.test.js
possibly react-native/tests/callback-demand.test.js only if cleanup reporting seam requires it
```

No production change is expected in:

```text
react-native/src/session-cancellation.ts
react-native/src/platform/backend.web.ts
react-native/src/session-queue-manager.ts
react-native/cpp/**
platform-specific RN native sources
flutter/**
libs/libffmpegkit/**
```

If implementation requires a production change outside the expected TypeScript wrapper area, Luna must first document the concrete source-level defect requiring it and expand validation accordingly.

---

# 13. Detailed deterministic test matrix

| Area | Case | Required oracle |
| --- | --- | --- |
| preflight | restored Running state probe throws | reject primary error; 0 executor starts; 0 abandon; 0 release; history/observer intact |
| preflight | terminal history state probe throws | reject; history intact; no retained cleanup from admission failure |
| preflight | transient probe failure then retry | first fails non-destructively; second Created admission can execute once |
| queue | successful non-Created state read | existing Review 45 non-destructive rejection remains green |
| queue | Created→Running handoff race | reservation released; no discard/abandon/release |
| queue | explicit queued cancel | discard/abandon still occurs exactly once |
| release | active owner succeeds | restored fallback waits; final native release commit once |
| release | active owner release fails once | observer survives active phase; fallback retry succeeds |
| release | history-only release fails repeatedly | callbacks once; iterative retry; entry O(1); success removes entry |
| release | clear during retry | retry stops after successful clear invalidation |
| bookkeeping | 10k unique successful releases | wrapper lifecycle bookkeeping returns to zero/bounded state |
| bookkeeping | stale sequential duplicate release | backend no-op; no second native release commit |
| bookkeeping | many observer clear cycles | no historical invalidated-ID growth |
| callbacks | terminal completion throws | error reporter sees exact error once; target detaches; release continues |
| callbacks | terminal cleanup throws | diagnostic preserved; lifetime release continues |
| regression | restored cancellation transient failure | Review 45 retry/dedupe remains correct |
| regression | deferred log install vs terminal | Review 45 rollback remains correct |
| regression | deferred statistics install vs terminal | Review 45 rollback remains correct |
| regression | 1000 no-callback history reads | one ID observer; zero/bounded callback targets |

Use counters/latches/fake backend state. Do not rely on sleeps alone as proof.

---

# 14. Test implementation guidance

## 14.1 Assert side effects, not only rejection

Bad:

```text
await assert.rejects(session.executeAsync())
```

Good:

```text
assert rejection identity
assert executorStarts == 0
assert abandonCalls == 0
assert releaseCalls == 0
assert queue reservation is gone
assert history identity still exists
```

## 14.2 Release retry oracle

Track separately:

```text
wrapper release method attempts
backend retained-entry presence
actual native handle-release commits
observer entry count
terminal callback count
active queue-owner count
```

Do not equate a wrapper no-op release call with a second native handle release.

## 14.3 Memory/bookkeeping oracle

Do not use RSS or GC timing.

Use direct module-internal state/counts so the test proves:

```text
bookkeeping cardinality after settled work == bounded expectation
```

## 14.4 Error reporting oracle

Capture the exact diagnostic hook already used by the Session observer.

Assert the specific sentinel object/message, not merely “some warning happened.”

## 14.5 No new framework

Extend existing Node tests. Do not add a new runner, simulator fixture, or app-hosted test solely for these TypeScript lifecycle fixes.

---

# 15. Documentation implementation guidance

## 15.1 Session submission

Document:

```text
pre-admission state/runtime probe errors are non-destructive
failed preflight does not abandon or release the session
actual native start failures retain their existing cleanup semantics
```

## 15.2 Running/terminal history wrappers

Preserve:

```text
Running/terminal history identities are observation/control objects
invalid re-execution never mutates their existing native/history lifetime
```

## 15.3 Terminal release ownership

Public docs need not expose maps/entries.

Internal technical comments should state:

```text
active execution gets first release attempt
restored observer remains fallback until active owner settles
fallback confirms/retries release after active owner exits
callback settlement is one-shot; release may retry
```

## 15.4 Bookkeeping

Internal comments should make clear that:

```text
wrapper-side release state tracks in-flight operations, not process history
clear invalidation tracks live transitions, not all IDs ever cleared
```

## 15.5 Restored observer callback errors

If documented publicly:

```text
restored callback exceptions are reported asynchronously because no new execution
Promise owns that observer; terminal resource cleanup still proceeds
```

Do not promise retroactive callbacks for already-terminal sessions.

---

# 16. Implementation order for Luna

Follow this order unless a real source conflict requires adjustment:

```text
1. Read Review 46 code review completely.

2. Verify starting wrapper SHA:
     d150cebfc406c2cd61ce66f5e779debc9bed0c75

3. Verify frozen submodule:
     b74da2c5d1e294b87d15d73a6687393729e932b3

4. Read current tests around:
     submission state-read failure
     restored execution preflight
     active-owner terminal release
     history-only release retry
     callback target boundedness
     clear vs deferred callback install

5. Implement G1 only:
     remove destructive preflight cleanup
     preserve actual native-start cleanup

6. Add G1 restored state-probe failure + retry regressions.

7. Run focused G1 tests.

8. Implement G2:
     keep terminal observer entry while active owner exists
     wait for active owner to settle
     retry serialized release afterward
     replace recursive release retry with iterative control

9. Add active-owner release-failure and repeated history-only failure tests.

10. Run focused G2 tests.

11. Implement G3:
      remove/bound releasesCompleted
      remove registerSessionWrapper ownership reset if completed Set is removed
      remove/bound invalidatedSessionIds
      retain only live/in-flight correctness state

12. Add high-cardinality bookkeeping tests.

13. Re-run Review 45 deferred-clear callback setup regression.

14. Implement G4:
      terminal settlement catch reports directly to target
      keep steady-state attachment guard if still appropriate

15. Add throwing completion/cleanup diagnostic tests.

16. Run all focused restored observer + ownership + queue tests.

17. Run npm typecheck.

18. Run npm test compilation.

19. Run lint.

20. Run complete local RN Node test suite.

21. If no Web production source changed, run only the smallest accepted Web/Wasm regression needed by changed shared TS behavior.

22. Run established local RN platform builds only as required by repository acceptance policy:
      Windows
      Android on Windows
      Apple iOS/tvOS/macOS last

23. Do not launch interactive apps/simulators/devices/Web UI.

24. Inspect git diff and revert unrelated refactors.

25. Re-audit platform-native directories for no drift.

26. Re-audit Flutter wrapper for no drift.

27. Perform final substantive RN lifecycle audit.

28. If any new substantive finding exists:
      record it
      do not claim closure
      do not hide it

29. If zero findings remain:
      freeze exact wrapper SHA
      push it
      dispatch one wrapper-only source snapshot
      download and verify it
      record provenance
```

---

# 17. Focused local validation after implementation

Review 46 itself is code review only and claims no executed validation.

After implementation, use local gates only.

## 17.1 React Native static/focused gates

From `react-native/`:

```text
npm run typecheck
npm run test:compile
npm run lint
```

Then run explicit focused Node test files containing the new regression cases.

Record exact pass/fail/skip totals.

## 17.2 Full RN suite

Run the repository's normal local full Node suite after focused cases pass.

Do not hide platform-specific skips.

## 17.3 Web/Wasm

If no `backend.web.ts` production change is needed:

```text
run only the existing affected ownership/Web regression required to prove shared TS behavior still works
```

If Web source changes unexpectedly, expand to the established local Web/Wasm package/runtime gate.

No browser UI interaction.

## 17.4 Native shared C++

No C++ production change is expected.

A bounded existing lifetime/source oracle may be rerun only as a no-regression check if repository acceptance requires it.

If C++ production source changes, stop and explain why Review 46 unexpectedly reopened the platform-native bridge.

## 17.5 Local native platform builds

Because shared React Native TypeScript ships to all native platforms, use the repository's established local matrix where required:

```text
Windows RN
Android RN on local Windows
Apple RN iOS/tvOS/macOS last
```

Use only configured local ABI `0.11.2` artifacts.

## 17.6 Flutter

If Flutter and shared packaging source remain unchanged:

```text
do not rerun the full Flutter platform matrix merely for ceremony
```

Perform a bounded source no-drift check and preserve accepted prior evidence.

If shared build/package configuration changes, expand Flutter validation accordingly.

## 17.7 Hosted workflow prohibition

Do not run hosted Flutter/RN build/test workflows.

The final exact-SHA wrapper source snapshot is the only allowed hosted workflow.

---

# 18. Result truthfulness requirements

For every command actually executed, record:

```text
platform
working directory
exact command
exit status
pass/fail/skip counts where available
acceptance evidence vs diagnostic only
```

Never call these a pass:

```text
source inspection
skipped command
timeout
killed process
compile that never started
prior-review evidence represented as a new run
platform unavailable locally
```

Record failed environment attempts and successful corrected retries separately.

---

# 19. Final substantive audit matrix

After implementation and local validation, re-read final source.

## 19.1 Preflight ownership

Confirm:

```text
validateInitialSubmission has no cleanup side effect
submitOnce never releases because a preflight observation threw
non-Created state rejection remains non-destructive
queue handoff validation remains non-destructive
actual executeSessionAsync failure still owns start cleanup
```

## 19.2 Terminal release authority

Confirm:

```text
terminal callbacks settle once
active owner causes waiting, not observer deletion
observer remains until active owner settles
failed active-owner release receives restored fallback retry
history-only failure retry is iterative
clear invalidation can terminate pending retry
entry deletes only after release success/no-op or clear invalidation
```

## 19.3 Bookkeeping boundedness

Confirm:

```text
no process-lifetime Set of every completed release ID
no process-lifetime Set of every clear-invalidated observer ID
release in-flight map is removed after success/failure
history wrapper construction does not redefine native ownership epoch
```

## 19.4 Error reporting

Confirm:

```text
terminal target that throws reports its own error even if it self-detaches
terminal callback error does not repeat callback settlement
reporting failure does not prevent handle release/retry
```

## 19.5 Review 45 regression matrix

Confirm:

```text
cancellation retry/dedupe intact
active-by-ID detection intact
bounded callback targets intact
callback setup terminal/clear serialization intact
Web missing-ID normalization intact
Web pointer failure atomicity intact
```

## 19.6 Flutter/platform-native

Confirm no accidental production drift.

## 19.7 Finding threshold

Open another finding only when all are present:

```text
reachable source path
actual API/lifetime/resource/concurrency violation
concrete product consequence
```

Do not report style, naming, test layout, or generic refactor preferences.

---

# 20. Exact wrapper freeze and source snapshot

Only after all applicable remediation/test/audit gates are complete:

1. Verify `libs/libffmpegkit` remains at the frozen SHA.
2. Verify no ManyLinux builder checkout change.
3. Verify no native ABI/config/publication change.
4. Remove task-owned staging/cache/log output that must not be committed.
5. Commit/push wrapper remediation with semantic commit messages.
6. Record exact 40-character final wrapper SHA.
7. Dispatch **one** wrapper-only source snapshot at that exact SHA.
8. Do not dispatch hosted Flutter/RN acceptance workflows.
9. Do not create a native/builders snapshot.
10. Retrieve the source artifact through the established connector workflow path.
11. Verify:
    - outer artifact digest;
    - `source.tar.gz.sha256`;
    - every `SHA256SUMS` entry;
    - `SUBMODULES.txt`;
    - `SYMLINKS.tsv`;
    - `snapshot-metadata.json`;
    - exact `snapshot_sha`;
    - `runtimeExecution=false`.
12. Treat later tracker/mailbox commits as discovery metadata, not source authority.

If the source-snapshot mailbox is absent, use the tracker-recorded exact run/artifact as the documented fallback and verify the artifact directly.

---

# 21. Tracker/final report requirements

Record:

```text
Review 46 starting wrapper SHA
  d150cebfc406c2cd61ce66f5e779debc9bed0c75

R46-F1 through R46-F4 disposition

exact production files changed
exact tests added/updated

G1 evidence:
  restored state-probe failure rejection
  executor/abandon/release counts
  retry after state recovery

G2 evidence:
  active owner first-release attempt
  release failure
  active owner removal
  restored fallback retry
  history-only repeated retry
  callback-at-most-once count
  clear-during-retry behavior

G3 evidence:
  high-cardinality release bookkeeping count
  high-cardinality clear bookkeeping count
  stale duplicate backend no-op behavior

G4 evidence:
  exact terminal callback/cleanup error reported
  target detach count
  release lifecycle remains intact

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

Do not write “all platforms pass” unless every named platform was actually executed in the remediation.

---

# 22. Anti-patterns Luna must reject

## 22.1 Releasing ownership because a preflight observation failed

Do not preserve:

```text
validateInitialSubmission throws generic state/backend error
-> releaseOwnedHandle
```

Admission never committed.

## 22.2 Deleting restored observer merely because active owner exists

Active means the owner has not finished. Keep fallback authority until it settles.

## 22.3 Recursive terminal release retry

Do not call `settleTerminalEntry()` recursively from its own release-failure branch.

## 22.4 Re-firing callbacks on release retry

Terminal callback settlement is one-shot. Release is a separate retryable phase.

## 22.5 Permanent completed-ID Set

Do not retain every process-unique released session ID to make an idempotent backend call look exactly-once at the wrapper layer.

## 22.6 Permanent invalidated-ID Set

Do not store all historically cleared restored IDs forever. Use live entries or a bounded generation.

## 22.7 Treating wrapper reconstruction as a native ownership epoch

Creating a new JavaScript history wrapper does not create a new retained native handle.

## 22.8 Suppressing terminal error after self-detach

The target that performed the terminal operation still owns its thrown result even if it detached during cleanup.

## 22.9 Reopening C++/native ABI

Not required by Review 46 findings.

## 22.10 Broad Flutter/native cleanup

Not authorized absent a new concrete defect.

## 22.11 Hosted acceptance CI

Not permitted. Local gates plus final source snapshot only.

---

# 23. Definition of done

Review 46 closure is complete only when every applicable item is true:

```text
[ ] Submission preflight performs no native/history cleanup on any observation failure.
[ ] Restored Running state-probe failure rejects without release.
[ ] Terminal/history preflight failure rejects without release.
[ ] Failed preflight leaves executor start count zero.
[ ] Transient preflight failure can follow documented retry semantics.
[ ] Existing successful non-Created rejection remains non-destructive.
[ ] Queue handoff rejection remains reservation-only.
[ ] Explicit queued Created cancellation still discards correctly.

[ ] Terminal restored observer remains alive while active execution owner exists.
[ ] Active owner gets first final-release attempt.
[ ] Failed active-owner release is retried after active ownership ends.
[ ] Successful active-owner release makes fallback harmless/no-op.
[ ] History-only terminal release retries without recursive promise growth.
[ ] Terminal callbacks/log/stat settlement does not repeat during release retries.
[ ] Successful clear stops pending release retry cleanly.

[ ] Wrapper release bookkeeping is bounded by in-flight/live lifecycle work.
[ ] No unbounded completed process-unique ID Set remains.
[ ] Observer invalidation bookkeeping is bounded by live transitions.
[ ] No unbounded historical invalidated-ID Set remains.
[ ] Wrapper reconstruction no longer resets a fake native ownership epoch.
[ ] Backend absent-entry release remains idempotent and unchanged.

[ ] Throwing restored completion callback is reported once.
[ ] Terminal cleanup error is reported where testable.
[ ] Target detachment does not suppress the operation's own error.
[ ] Error reporting does not block final release/retry.

[ ] Review 45 cancellation retry/dedupe tests remain green.
[ ] Review 45 bounded history-observer tests remain green.
[ ] Review 45 callback setup terminal/clear race tests remain green.
[ ] Review 45 Web ownership tests remain green.

[ ] Focused RN regressions pass.
[ ] Typecheck/test compilation/lint results are recorded.
[ ] Full local RN suite result is recorded truthfully.
[ ] Affected Web/Wasm gates are recorded.
[ ] Required local RN platform builds actually executed are recorded.
[ ] No interactive runtime validation is claimed by the agent.

[ ] Flutter reviewed lifecycle source remains clean/unchanged.
[ ] Platform-native bridge remains closed/unchanged.
[ ] Native ABI remains frozen at 0.11.2.
[ ] libs/libffmpegkit remains at the frozen SHA.
[ ] ManyLinux builder checkout remains unchanged.
[ ] No remote old native artifact is fetched.
[ ] No hosted Flutter/RN acceptance workflow is used.

[ ] Final bounded code review finds zero substantive open Flutter/RN/platform-native defect.
[ ] Exact final wrapper SHA is pushed/frozen.
[ ] One wrapper-only source snapshot at that exact SHA is downloaded and verified.
[ ] Snapshot metadata records runtimeExecution=false.
```

If any applicable item is false, do not declare full Flutter/React Native closure.

---

# 24. Expected final closeout if remediation is clean

Use a factual closeout:

```text
Platform-native bridge:
  closed; unchanged from prior frozen authority.

Flutter wrapper:
  closed in audited lifecycle/session surfaces; no Review 46 production change.

React Native wrapper:
  pre-admission failures are non-destructive;
  active execution release has a bounded restored fallback;
  terminal release retries are iterative;
  lifecycle bookkeeping is bounded to live/in-flight state;
  terminal restored callback/cleanup errors remain observable.

Native ABI:
  frozen at 0.11.2;
  no native/submodule/builders change.

Validation:
  list only commands/platforms actually executed.

Source authority:
  exact final wrapper SHA + one verified wrapper-only snapshot.
```

Only use this closeout after the final bounded source audit finds **zero** remaining substantive findings.
