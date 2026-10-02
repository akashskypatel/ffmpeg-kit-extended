# Review 46 — Flutter + React Native Cross-Platform Code Review

**Project:** FFmpegKitExtended  
**Review type:** frozen-source code review; substantive findings only  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch represented by snapshot:** `dev-wasm`  
**Frozen wrapper source:** `d150cebfc406c2cd61ce66f5e779debc9bed0c75`  
**Snapshot workflow:** `37056546191`  
**Snapshot artifact:** `review45-source-snapshot-37056546191`  
**Artifact ID:** `11248243890`  
**Outer artifact SHA-256:** `a79191d57ba62cf3525c9704502f6b29e39f66289fc07922b3c21ce773528e70`  
**Embedded `source.tar.gz` SHA-256:** `df306046866e649dc070fecc4931f2a832f8e410ad420f06b4907dc35efc37a1`  
**Manifest:** **1,101/1,101 verified**  
**Symlinks:** `0`  
**Snapshot metadata:** `runtimeExecution=false`  
**Recursive submodule:** `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`  
**Native ABI/runtime:** frozen `0.11.2`; not downloaded, rebuilt, or re-reviewed

---

## 1. Review authority and provenance

Review 46 uses the exact wrapper-only source snapshot frozen at Review 45 closeout.

The repository source-snapshot mailbox path was checked first and was not present on `dev-wasm`. Review 46 therefore used the tracker-recorded Review 45 workflow run and artifact as the documented fallback discovery authority.

The downloaded artifact was independently verified before source inspection:

```text
GitHub artifact SHA-256:
  a79191d57ba62cf3525c9704502f6b29e39f66289fc07922b3c21ce773528e70

snapshot-metadata.snapshot_sha:
  d150cebfc406c2cd61ce66f5e779debc9bed0c75

snapshot-metadata.runtimeExecution:
  false

source.tar.gz SHA-256:
  df306046866e649dc070fecc4931f2a832f8e410ad420f06b4907dc35efc37a1

SHA256SUMS:
  1101/1101 verified

SYMLINKS.tsv:
  0 entries

SUBMODULES.txt:
  b74da2c5d1e294b87d15d73a6687393729e932b3 libs/libffmpegkit (b74da2c)
```

No native/builders artifact was downloaded. Native ABI `0.11.2`, `libs/libffmpegkit`, and the ManyLinux builders remain frozen evidence and outside Review 46 source scope.

---

## 2. Review boundary

This was **code review only**.

Review 46 performed no:

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

The review sequence was:

```text
1. verify Review 45 frozen snapshot provenance
2. compare the Review 45 final snapshot with the Review 44 source authority
3. re-audit platform-native closure for source drift
4. re-audit Flutter wrapper closure for source drift
5. review every React Native production change introduced by Review 45
6. expand through adjacent queue/history/cancellation/callback/lifetime paths
7. report only reachable correctness/lifetime defects with concrete product effect
```

Excluded from findings:

```text
formatting/style
naming preferences
tracker/procedural observations
documentation-only drift without product consequence
speculative hardening
general refactoring opportunities
native ABI internals frozen outside wrapper scope
```

---

## 3. Source-diff boundary

Relative to the Review 45 starting authority (`2b4b902b0aa918d871659380475ebf6ec3bb06d3`), the final Review 45 snapshot changes only these production paths:

```text
react-native/README.md
react-native/src/ffmpeg-kit-extended.ts
react-native/src/platform/backend.web.ts
react-native/src/session-cancellation.ts        (new)
react-native/src/session-observation.ts
react-native/src/session-queue-manager.ts
react-native/src/session.ts
```

and focused React Native tests.

The following production directories are unchanged byte-for-byte between the Review 44 and Review 45 wrapper snapshots:

```text
flutter/lib
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

This is important to the disposition below: Review 46 found no source change capable of reopening the already-closed Flutter or platform-native implementations.

---

## 4. Platform-native bridge disposition

### CLOSED

Review 46 opens **zero platform-native bridge findings**.

All platform-native production directories are unchanged from the previously accepted closure authority. The accepted invariants therefore remain the same implementation:

```text
Flutter iOS/macOS
  texture registration failure rejected before publication

Flutter Windows
  asynchronous registered-texture retirement
  callback-captured state lifetime
  latest-owner FFplay semantics
  packed-frame normalization

Flutter Linux
  FlPixelBufferTexture lifecycle
  queued idle references
  frame coalescing
  stable render buffer lifetime

Flutter Android
  Surface / SurfaceTexture / ANativeWindow exact ownership
  stale owner cannot clear a newer target

React Native shared C++
  composable operation admission
  clear barrier and drain
  retained-handle borrow/release barrier
  non-throwing native cleanup

React Native Windows/Android/Apple
  invocation-bound action failure transport
  synchronous diagnostic boundary
  callback copied-payload lifetime
  FFplay latest-owner / drain semantics
```

The Review 46 findings are wrapper-level TypeScript lifecycle defects and require no native ABI or platform-native source change.

---

## 5. Flutter wrapper disposition

### CLOSED in the audited wrapper/lifecycle surfaces

`flutter/lib` is unchanged from the prior clean authority.

Review 46 found no new concrete Flutter wrapper defect and no Review 45 source drift to investigate there.

Accepted Flutter semantics remain:

```text
ID cancellation routes through Session/queue authority
ID 0 uses cancel-all semantics
submitted-Created startup is not pre-submission abandonment
durable cancellation survives startup state transitions
restored Running observer ownership is distinct from execution ownership
restored terminal observation has independent lifecycle authority
queue identity reservations remain one-per-native-session-ID
```

No Flutter production change is required by Review 46.

---

## 6. Executive React Native disposition

React Native is **not yet wrapper-clean**.

Review 45 correctly implemented its five reported goals, including non-destructive non-Created state rejection, durable restored cancellation delivery, active-owner release ordering, bounded callback targets, and callback-setup serialization. Review 46 finds four remaining failure-path defects adjacent to those new authorities.

| ID | Severity | Surface | Finding |
| --- | --- | --- | --- |
| **R46-F1** | **High** | Session submission preflight / restored history identity | `submitOnce()` still calls `releaseOwnedHandle()` when the authoritative preflight fails with a generic state/backend error. A restored Running wrapper whose state probe throws can therefore retire the existing native identity even though queue admission never succeeded. |
| **R46-F2** | **Medium-High** | Restored terminal release authority | When terminal observation sees an active execution owner, it deletes the observer entry immediately. If the original execution owner's later retained-handle release fails, no observer remains to retry. The history-only failure path retries by recursive `settleTerminalEntry()` calls every 50 ms, building an unbounded promise chain under persistent failure. |
| **R46-F3** | **Medium** | Process-wide lifecycle bookkeeping | `releasesCompleted` and `invalidatedSessionIds` retain process-unique session IDs without a lifecycle bound. Normal completed sessions and clear-invalidated restored sessions can therefore grow permanent JavaScript sets over process lifetime. |
| **R46-F4** | **Medium** | Restored terminal callback/error reporting | `settleRestoredObservation()` detaches its callback target before throwing a completion/cleanup error; the coordinator then reports only if the target is still attached. The error is silently discarded even though restored observation has no public execution promise through which to surface it. |

No finding requires a native ABI change.

---

# 7. R46-F1 — submission preflight failure can still retire restored ownership

**Severity:** High  
**Primary surface:** `react-native/src/session.ts`  
**Affected backends:** native and Web  
**Native ABI change:** none

## 7.1 Review 45 correction that is sound

Review 45 added an authoritative non-mutating state check before queue admission:

```ts
protected validateInitialSubmission(): void {
  ...
  const state = this.getState();
  if (state !== SessionState.Created) {
    throw new SessionNotCreatedError(this.sessionId, state);
  }
}
```

It also correctly makes `SessionNotCreatedError` and `SessionCancelledException` non-destructive in `submitOnce()`.

That closes the ordinary restored-Running/terminal case where the state read succeeds.

## 7.2 Remaining destructive branch

`react-native/src/session.ts:1163-1204` still contains a second branch for any other preflight error:

```ts
try {
  this.validateInitialSubmission();
} catch (error) {
  if (
    error instanceof SessionNotCreatedError ||
    error instanceof SessionCancelledException
  ) {
    return Promise.reject(error);
  }

  let release: void | Promise<void>;
  try {
    release = this.releaseOwnedHandle();
  } catch {
    return Promise.reject(error);
  }
  ...
  return Promise.reject(error);
}
```

`validateInitialSubmission()` can throw a generic backend error through `getState()`.

For a reconstructed Running history wrapper, that wrapper is intentionally associated with promoted retained ownership and a restored observer.

So the reachable sequence is:

```text
1. Running native session is reconstructed from history.
2. sessionFromSnapshot() starts restored Running observation.
3. Application accidentally calls executeAsync() on that history wrapper.
4. submitOnce() calls validateInitialSubmission().
5. getSessionState(id) throws a transient state/backend error.
6. Error is not SessionNotCreatedError or SessionCancelledException.
7. submitOnce() calls releaseOwnedHandle().
8. releaseSessionHandleSerialized(id) retires the retained Running identity.
9. executeAsync() rejects with the state-read error.
10. The failed admission has nevertheless mutated the live execution/history lifetime.
```

This is the same ownership class that Review 45 intended to make non-destructive; the missing combination is **preflight observation failure**, not successful observation of a non-Created state.

## 7.3 Product consequence

A transient state-read/runtime failure during an invalid re-submission can:

```text
retire a Running retained handle
remove the wrapper's retained execution authority
cause the restored observer to lose its underlying native identity
turn an admission error into destructive lifecycle mutation
make a transient state error non-retryable
```

The public operation did not start native work and therefore should not own destructive cleanup of an already-existing history identity.

## 7.4 Why existing tests do not prove this boundary

The Review 45 regression covers:

```text
getState() succeeds
state == Running
executeAsync() rejects
release count == 0
```

The older ownership regression separately covers:

```text
fresh/new wrapper
authoritative state read throws
release is attempted
```

There is no regression combining:

```text
restored/history wrapper
+
state read itself throws during submission preflight
```

That is exactly the uncovered destructive branch.

## 7.5 Required correction

The submission preflight must have **no native-ownership side effect** when it cannot prove admission is valid.

Preferred invariant:

```text
validateInitialSubmission success
  -> queue admission may proceed

validateInitialSubmission failure of any kind
  -> reject submission
  -> do not abandon
  -> do not release retained ownership
  -> do not mark submitted
```

The simplest safe implementation is to remove the `releaseOwnedHandle()` fallback from `submitOnce()` preflight failure entirely.

Actual native start failure remains covered by `startNativeExecution()`, where an execution handoff was truly attempted and owner cleanup is appropriate.

If the project intentionally wants a distinction between a fresh creator-owned wrapper and a history-restored wrapper, model that provenance explicitly; do not infer it from whether a state read happened to throw.

---

# 8. R46-F2 — terminal release retry authority is dropped or recursively unbounded

**Severity:** Medium-High  
**Primary surfaces:** `react-native/src/session-observation.ts`, `react-native/src/session.ts`, `react-native/src/session-lifetime.ts`, `react-native/src/session-queue-manager.ts`  
**Native ABI change:** none

## 8.1 Review 45 owner ordering is directionally correct

The new restored terminal path correctly checks whether an ordinary execution monitor is still active:

```ts
if (SessionQueueManager.shared.isSessionActiveById(entry.sessionId)) {
  this.entries.delete(entry.sessionId);
  return;
}
```

The intent is correct: the active executor owns final log/statistics/completion drain and must be allowed to attempt retained-handle retirement first.

## 8.2 The observer gives up retry authority too early

The problem is `this.entries.delete(...)` plus immediate return.

The ordinary monitor later performs:

```ts
try {
  await this.releaseOwnedHandle();
} catch (error) {
  releaseErrorSet = true;
  releaseError = error;
}
```

and then rejects the execution if the release failed.

After the execution promise settles, `SessionQueueManager.completeActiveItem()` removes that session from the active set.

If the restored observer already deleted its entry while the executor was active, the final state is:

```text
native session terminal
active executor removed
retained release failed and remains retryable
restored observer entry gone
no terminal history wrapper starts observation because state is terminal
no automatic owner remains to retry release
```

The backend retained-release transaction was explicitly designed to remain retryable after failure. The wrapper drops the owner that could perform that retry.

## 8.3 Reachable race

```text
1. Session A is executing through the normal JS queue/monitor.
2. History lookup reconstructs the same Running ID and starts restored observation.
3. Native state becomes terminal.
4. Restored observer settles its callback targets first.
5. isSessionActiveById(id) == true.
6. Restored observer deletes its entry and returns.
7. Original monitor finishes final callback drain.
8. releaseSessionHandle(id) fails transiently.
9. Execution promise rejects; queue removes A from active set.
10. No restored entry remains to observe that active ownership ended.
11. Retained handle remains until some unrelated global cleanup occurs.
```

This is a concrete lifetime leak after a transient release failure.

## 8.4 History-only retry uses recursive promises

When no active executor exists, a release failure takes another path:

```ts
try {
  await releaseSessionHandleSerialized(entry.sessionId);
  this.entries.delete(entry.sessionId);
} catch (error) {
  this.reportTargets(entry, error);
  await sleep(POLL_INTERVAL_MS);
  if (this.entries.get(entry.sessionId) === entry && !entry.invalidated) {
    await this.settleTerminalEntry(entry);
  }
}
```

This recursively awaits another `settleTerminalEntry()` for each failure.

If release fails persistently, every 50 ms another promise/frame is retained behind the next recursive call. Terminal callbacks do not repeat because `terminalSettled` is set, but the retry control structure itself grows without bound.

The prior implementation used the outer polling loop and did not need recursive retry nesting.

## 8.5 Required correction

Terminal observation needs one **bounded iterative release phase** that remains authoritative until one of these events occurs:

```text
release succeeds
successful global clear invalidates the entry
the process/session lifecycle is otherwise explicitly abandoned
```

Required ordering:

```text
1. observe terminal
2. settle restored callback targets exactly once
3. clear terminal cancellation bookkeeping idempotently
4. while entry remains valid:
     if an active execution owner still exists:
       wait/poll; do not delete entry
       continue
     attempt releaseSessionHandleSerialized(id)
     if success:
       remove entry and return
     if failure:
       report once/as designed
       wait with existing cadence/backoff
       retry iteratively
```

Why this works:

```text
active executor release succeeds
  -> observer waits until active false
  -> serialized/backend idempotent release becomes a no-op
  -> observer can close safely

active executor release fails
  -> observer waits until active false
  -> observer retries the retained release
  -> transient failure is recoverable

history-only owner
  -> same iterative release phase owns retries
  -> no recursive promise chain
```

Do not re-fire completion callbacks during release retries.

---

# 9. R46-F3 — permanent per-ID bookkeeping grows with process lifetime

**Severity:** Medium  
**Primary surfaces:** `react-native/src/session-lifetime.ts`, `react-native/src/session-observation.ts`  
**Native ABI change:** none

## 9.1 `releasesCompleted` is process-unbounded

`react-native/src/session-lifetime.ts` contains:

```ts
const releasesInFlight = new Map<number, Promise<void>>();
const releasesCompleted = new Set<number>();
```

Every successful serialized release adds the session ID:

```ts
await release;
releasesCompleted.add(sessionId);
```

The only removal is:

```ts
export function registerSessionWrapper(sessionId: number): void {
  if (releasesCompleted.has(sessionId)) releasesCompleted.delete(sessionId);
}
```

But the public `Session` contract describes IDs as process-unique. For the normal case where a completed session is never reconstructed again after release, its ID remains in `releasesCompleted` for the rest of the process.

A long-running application executing many short jobs therefore grows the Set with total historical execution count rather than live ownership count.

## 9.2 `invalidatedSessionIds` is also process-unbounded

`react-native/src/session-observation.ts` contains:

```ts
private readonly invalidatedSessionIds = new Set<number>();
```

A successful clear adds each observed ID:

```ts
this.invalidatedSessionIds.add(entry.sessionId);
```

There is no removal path.

Again, process-unique IDs mean this is permanent historical bookkeeping rather than live lifecycle state.

## 9.3 Product consequence

For applications that perform many sessions or periodically clear history, JavaScript heap usage grows with **total past session IDs** even when:

```text
no session is active
no restored observer exists
no callback target exists
native retained handles were successfully released
history was cleared
```

This is the exact class of history-frequency/lifetime growth that Review 45 removed from callback target storage, but two ID tombstone structures remain.

## 9.4 `registerSessionWrapper` is not a sound ownership epoch

The completed-release Set also has a semantic weakness: constructing another history wrapper for the same terminal ID removes the completion marker even though wrapper reconstruction did not create a new native ownership epoch.

So the mechanism is simultaneously:

```text
unbounded for IDs never reconstructed again
and
reset by an event that does not actually recreate native ownership
```

## 9.5 Required correction

Prefer lifecycle state whose memory is bounded by live/in-flight work.

For release serialization, the cleanest design is:

```text
keep only releasesInFlight for concurrent transaction dedupe
remove releasesCompleted as correctness authority
rely on backend absent-entry release being idempotent
```

Both current wrapper backends already implement an absent retained entry/pointer as a no-op release:

```text
native shared C++: retained entry missing -> return
Web: retained pointer missing -> return
```

This permits a stale late release call to be harmless without retaining every completed process-unique ID forever.

If a completed-release cache is retained as an optimization, it must be explicitly bounded and must not be treated as ownership correctness.

For restored clear invalidation, avoid a permanent per-ID tombstone. Use one of:

```text
entry-local invalidation only
coordinator clear generation/epoch
bounded transition token
```

The Review 45 callback transaction already rechecks native Running/liveness after asynchronous installation, which is the real correctness barrier after clear.

---

# 10. R46-F4 — terminal restored-observer errors are silently discarded

**Severity:** Medium  
**Primary surfaces:** `react-native/src/session.ts`, `react-native/src/session-observation.ts`  
**Native ABI change:** none

## 10.1 Terminal settlement can throw by design

`settleRestoredObservation()` captures and then throws the first terminal callback/cleanup error after performing cleanup:

```text
poll final restored callbacks
invoke completion callback
clear cancellation intent
release callback demand
remove direct log subscription
mark restoredTerminalSettled = true
detach restored callback target
throw first callback/cleanup error if present
```

That is a reasonable boundary: restored observation has no execution promise, so the coordinator's reporting hook is the remaining asynchronous error surface.

## 10.2 The target detaches before the coordinator handles the throw

Near the end of `settleRestoredObservationWithinTransition()`:

```ts
this.restoredTerminalSettled = true;
this.syncRestoredCallbackTarget();
clearCancellationDispatch(this.sessionId);
if (firstError !== undefined) throw firstError;
if (cleanupError !== undefined) throw cleanupError;
```

`syncRestoredCallbackTarget()` detaches the wrapper because it is now terminal-settled.

The coordinator then catches the thrown error:

```ts
try {
  await target.settleRestoredObservation();
} catch (error) {
  this.reportTargetIfAttached(entry, target, error);
} finally {
  entry.callbackTargets.delete(target);
}
```

but `reportTargetIfAttached()` is:

```ts
if (entry.callbackTargets.has(target))
  target.reportRestoredObserverError(error);
```

The target removed itself before throwing, so the membership test is false.

The error is dropped.

## 10.3 Reachable consequences

Examples include:

```text
restored completion callback throws
final restored log/statistics drain throws
callback bridge uninstall/cleanup reports an error
```

There is no public execution Promise for a restored history observer, so without `reportRestoredObserverError()` these failures disappear entirely.

This is not a style issue; the code contains an explicit reporting authority that is defeated by its own detach ordering.

## 10.4 Required correction

Terminal settlement owns the local `target` object even if that target detached during cleanup.

Report the thrown settlement error directly:

```ts
try {
  await target.settleRestoredObservation();
} catch (error) {
  target.reportRestoredObserverError(error);
} finally {
  entry.callbackTargets.delete(target);
}
```

The attachment guard remains useful for steady-state polling errors where a target may have intentionally removed its final sink while asynchronous work was underway. It should not suppress the terminal operation's own thrown result.

Do not make terminal callback errors abort handle retirement; report them and preserve the existing terminal lifetime ordering.

---

## 11. Review 45 fixes that remain correct

The Review 46 findings do **not** invalidate these Review 45 corrections:

```text
non-Created state rejection itself is non-destructive
queue handoff validation no longer reuses explicit discard cleanup
unknown-ID cancellation normalization is narrow
restored cancellation has shared per-ID delivery authority
Running observer retries durable cancellation intent
active execution ownership is detected by native session ID
per-ID observer lifetime is separated from callback-bearing wrapper targets
1000 history reads no longer imply 1000 strong callback targets
restored optional callback setup is serialized with terminal/clear cleanup
post-install Running/liveness recheck exists
Web missing-pointer normalization does not swallow arbitrary errors
```

Review 46 remediation should stay surgical around the failure paths above.

---

## 12. Why Review 45 tests could remain green

The tracker records strong Review 45 focused and full-suite validation. Those tests exercise the intended primary paths, but the four Review 46 defects require combinations not represented by the existing regressions:

```text
restored/history executeAsync + getSessionState throws during initial preflight

restored terminal observer sees active owner
+
that active owner's later release fails

history-only terminal release fails persistently for many retry cycles

many successful unique session releases with no later wrapper reconstruction

many clear-invalidated restored IDs over process lifetime

restored terminal completion/cleanup throws after the target self-detaches
```

Ordinary build/test success does not prove those failure-state ownership boundaries.

---

## 13. Review 46 remediation goals

| Goal | Required result |
| --- | --- |
| **R46-G1** | Make every submission-preflight failure non-destructive. State/backend observation failure before queue admission must reject without abandoning or releasing the native/history identity. |
| **R46-G2** | Keep one restored terminal release authority alive until active execution finalization has actually settled, then retry retained release iteratively if needed; remove recursive retry growth. |
| **R46-G3** | Bound release/invalidation bookkeeping by live/in-flight lifecycle state instead of retaining process-unique IDs forever. |
| **R46-G4** | Preserve asynchronous restored terminal errors through the coordinator's reporting surface even when the target detaches during settlement. |
| **R46-G5** | Add deterministic regressions/documentation, run only affected local validation during remediation, re-audit all layers, and create one exact-SHA wrapper snapshot only if zero substantive findings remain. |

---

## 14. Required regression coverage

Review 46 itself executed no tests. Remediation should add deterministic coverage before broad local validation.

### 14.1 Preflight state-read failure on restored history

Setup:

```text
Running history snapshot exists for ID A
history getter reconstructs wrapper A
restored observer exists
getSessionState(A) is changed to throw sentinelStateError
```

Call:

```text
A.executeAsync()
```

Assert:

```text
rejects with sentinelStateError
executor start count == 0
abandon count == 0
release count == 0
queue reservation count returns to baseline
history identity remains visible
restored observer entry remains valid
```

Then recover state reads, set state terminal, and prove the restored observer can still retire the real retained ownership normally.

### 14.2 Fresh Created preflight observation failure

Decide and document the intended contract explicitly.

Preferred:

```text
state probe failure before admission is non-destructive
wrapper remains retryable
second preflight after state recovery can execute
```

Do not retain the old test merely because it encodes the current destructive implementation.

### 14.3 Active owner release failure fallback

Use deterministic latches/counters:

```text
normal execution owner active for ID B
history reconstruction starts restored observer for B
state becomes terminal
restored observer settles while B is still active
original monitor reaches release
first release attempt throws sentinelReleaseError
queue removes active owner after execution rejects
```

Required result:

```text
restored entry still exists in terminal-release phase
observer notices active owner is gone
second retained release attempt occurs
second release succeeds
entry removed
completion callbacks not repeated
native release commit occurs exactly once
```

### 14.4 Persistent history-only release failures

Configure history-only restored ID C:

```text
terminal
release attempts 1..N throw
attempt N+1 succeeds
```

Assert:

```text
terminal callbacks settle once
observer entry remains one object
retry attempts are iterative
no recursive callback settlement
entry removed after success
```

A source assertion may additionally reject recursive self-calls from the release-failure branch.

### 14.5 Bounded completed-release bookkeeping

Use an internal test seam rather than process RSS.

Drive many unique session IDs through serialized successful release.

Assert:

```text
in-flight release map returns to zero
no permanent completed-ID structure grows with total session count
sequential stale release remains harmless through backend idempotence
```

### 14.6 Bounded clear invalidation bookkeeping

Create/clear many unique restored observer IDs.

Assert:

```text
observer entries return to zero after clear
callback targets return to zero
no permanent invalidated-ID structure grows with clear history
in-flight callback setup after clear still fails/rolls back correctly
```

### 14.7 Terminal error reporting after detach

Use a restored completion callback that throws `sentinelCompletionError`.

Make the session terminal.

Assert:

```text
completion callback invoked once
observer error reporter receives sentinelCompletionError once
callback target is detached
handle retirement still follows the normal owner/retry path
```

Add a cleanup-error variant if the existing callback-demand fake can inject uninstall failure without new infrastructure.

---

## 15. Documentation guidance

Public React Native documentation should change only where behavior is externally meaningful.

Document submission preflight as:

```text
History/session execution validation is non-destructive. If authoritative state
cannot be read before queue admission, the submission fails without abandoning
or releasing the existing session identity. The caller may retry after the
underlying read/runtime problem is resolved.
```

Preserve the existing Running/terminal history rule:

```text
A Running or terminal history wrapper is not re-executed and a rejected
re-submission does not mutate the existing native execution/history identity.
```

For restored observer errors, if the project's chosen public convention remains asynchronous warning/reporting rather than a returned Promise, state that callback failures are reported through the wrapper's observer diagnostic path and do not silently abort handle retirement.

Internal comments should explain:

```text
submission validation does not own cleanup before admission
active execution ownership must fully settle before restored release fallback
release retry control is iterative and terminal callbacks are one-shot
release dedupe state is bounded to live/in-flight work
clear invalidation does not retain historical process-unique IDs
terminal settlement reports its own error even after target detachment
```

Do not mention Review 46 IDs in production/test identifiers or comments.

---

## 16. Closeout criteria

Review 46 must not be declared fully wrapper-clean until every applicable item below is true:

```text
[ ] Restored Running preflight state-read failure rejects without release.
[ ] Restored terminal/history preflight failure rejects without release.
[ ] Preflight backend failure does not abandon history.
[ ] No native executor starts after failed admission.
[ ] Retry after transient preflight failure follows the documented contract.

[ ] Restored terminal observer does not disappear merely because an active owner exists.
[ ] Observer waits for active owner settlement before fallback release decision.
[ ] Failed original-owner release is automatically retryable by remaining terminal authority.
[ ] History-only release retry is iterative, not recursively nested.
[ ] Terminal callback settlement remains at-most-once across release retries.
[ ] Successful global clear can still invalidate a pending terminal release phase.

[ ] Release serialization retains no unbounded completed-session ID set.
[ ] Clear invalidation retains no unbounded historical session ID set.
[ ] Lifecycle bookkeeping size is bounded by live/in-flight work or an explicit bounded cache.
[ ] Backend idempotent absent-entry release remains preserved.

[ ] Restored completion/callback cleanup error is reported even after target detachment.
[ ] Error reporting does not repeat terminal callbacks.
[ ] Error reporting does not prevent retained-handle retirement/retry.

[ ] Existing Review 45 cancellation delivery remains correct.
[ ] Existing Review 45 callback setup vs terminal/clear serialization remains correct.
[ ] Existing Review 45 bounded callback-target semantics remain correct.
[ ] Existing Review 45 Web missing-ID/failure-atomic lookup remains correct.

[ ] Focused RN regressions pass during remediation.
[ ] Typecheck/test compilation/lint results are recorded truthfully.
[ ] Complete local RN test result is recorded truthfully.
[ ] Only affected Web/platform local gates are run as required.
[ ] No interactive app/simulator/device validation is claimed by the agent.

[ ] Flutter source remains unchanged unless a new concrete Flutter defect is proven.
[ ] Platform-native source remains unchanged unless a new concrete bridge defect is proven.
[ ] Native ABI remains 0.11.2.
[ ] libs/libffmpegkit remains at the frozen SHA.
[ ] No ManyLinux builder source is changed.
[ ] No remote old native artifact is fetched.
[ ] No hosted Flutter/RN acceptance workflow is run.

[ ] Final bounded code review finds zero substantive Flutter/RN/platform-native findings.
[ ] Exact final wrapper SHA is pushed/frozen.
[ ] One wrapper-only source snapshot at that exact SHA is downloaded and verified.
[ ] Snapshot metadata records runtimeExecution=false.
```

---

## 17. Review 46 closeout

```text
Frozen wrapper authority: VERIFIED
Outer artifact digest: VERIFIED
Embedded source archive: VERIFIED
Manifest: 1101/1101
Symlinks: 0
runtimeExecution: false
Frozen native submodule: VERIFIED

Native ABI separately downloaded: NO
Native ABI reviewed: NO
Native ABI source change required: NO

Code review only: YES
Tests/builds/runtime executed by Review 46: NO
Repository mutation by Review 46: NO

Platform-native bridge substantive findings: 0
Flutter wrapper substantive findings: 0
React Native wrapper substantive findings: 4

R46-F1 High        — generic submission-preflight failure can release restored ownership
R46-F2 Medium-High — terminal release fallback is dropped behind active owner; history-only retry recurses
R46-F3 Medium      — completed-release and clear-invalidated ID bookkeeping grows without lifecycle bound
R46-F4 Medium      — terminal restored-observer errors can be silently discarded after target detachment

Pedantic/procedural findings reported: 0

Disposition:
PLATFORM-NATIVE BRIDGE CLOSED.
FLUTTER WRAPPER CLOSED IN AUDITED SURFACES.
REACT NATIVE WRAPPER NOT YET CLOSED.
```
