# Review 50 — Flutter + React Native Cross-Platform Code Review

Date: 2026-10-02  
Repository: `akashskypatel/ffmpeg-kit-extended`  
Branch represented by reviewed snapshot: `dev-wasm`  
Review type: frozen-source, code-review-only, substantive findings only

## 1. Authority and provenance

Review 50 uses the exact final Review 49 wrapper freeze as its only source authority:

`a26128cfc89b04e814102b3311d077313677822f`

The tracker records:

- source snapshot workflow: `37092403431`
- artifact: `review49-final-source-snapshot-37092403431`
- artifact ID: `11262925973`
- GitHub artifact SHA-256: `44ab21a115ce2e3b683d024216dc87de9a8c1c3230e1453138af0bc6b4e48bb1`
- embedded `source.tar.gz` SHA-256: `c7f3f85cd8b1be986d055f402dd50ac5b89d9dd61e2634affc5d74ad411d56fa`
- manifest entries: `1080/1080` verified
- symlinks: `0`
- `runtimeExecution=false`
- recursive native submodule: `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`
- native ABI/runtime: `0.11.2`, frozen and not re-reviewed

Review 50 independently downloaded the artifact through the GitHub connector and verified the outer artifact digest, embedded archive digest, every `SHA256SUMS` entry, `SUBMODULES.txt`, `SYMLINKS.tsv`, and `snapshot-metadata.json` before extracting source.

No tests, builds, application launches, simulators, devices, Web UI, hosted acceptance workflows, repository mutations, native ABI downloads, or native ABI rebuilds were performed as Review 50 evidence.

## 2. Review scope and finding threshold

The requested order was applied:

1. verify the frozen source snapshot;
2. recheck Flutter and React Native platform-native bridge boundaries;
3. if platform-native remains closed, recheck Flutter wrapper drift and lifecycle boundaries;
4. if Flutter remains closed, inspect Review 49 React Native remediation and its adjacent queue, history, cancellation, observation, release, and public API authorities;
5. report only reachable product, lifetime, ownership, cancellation-authority, or public-contract defects;
6. exclude style, formatting, procedural, speculative, and pedantic observations.

The native ABI and builders remain frozen and out of scope.

## 3. Snapshot no-drift result

The exact Review 49 snapshot was compared against the preceding verified Review 48 snapshot. The only production changes between those authorities are:

- `react-native/src/session.ts`
- `react-native/src/session-queue-manager.ts`
- `react-native/README.md`

with associated React Native tests and `.agent` review/tracker material.

The following production trees are byte-for-byte unchanged:

- `flutter/lib`
- `flutter/native`
- `flutter/android`
- `flutter/ios`
- `flutter/macos`
- `flutter/linux`
- `flutter/windows`
- `react-native/cpp`
- `react-native/android`
- `react-native/ios`
- `react-native/macos`
- `react-native/appletvos`
- `react-native/windows`

The accepted platform-native bridge and Flutter implementation therefore remain closed unless contradicted by the fresh semantic audit. No contradiction was found.

## 4. Review 49 remediation verification

Review 49's three stated corrections are materially present:

1. the original wrapper now distinguishes one-shot submission consumption from a local native-start boundary through `nativeStartAttempted`;
2. `cancelCurrent()` and `cancelAll()` now store cancellation errors in deterministic indexed/branch slots instead of selecting the first asynchronously settled rejection;
3. ordinary TypeScript code can no longer directly call `markCancelledBeforeExecution()` because the method is now declared `protected`, and queue discard invokes it through an internal callback argument.

Those changes close the exact same-object and settlement-order cases identified by Review 49. Review 50's findings are deeper authority and failure-path gaps that remain around those fixes.

## 5. Disposition

| Area | Review 50 disposition |
| --- | --- |
| Native ABI/runtime `0.11.2` | Frozen; not reviewed |
| Flutter platform-native bridge | Closed |
| React Native platform-native bridge/shared C++ | Closed |
| Flutter wrapper | Closed in audited lifecycle/session surfaces |
| React Native wrapper | **Not closed — 3 substantive findings** |

### Findings summary

| Finding | Severity | Summary |
| --- | --- | --- |
| R50-F1 | High | Cancellation from a second wrapper for a queued/active native ID does not delegate to the managed canonical owner; a Created startup wrapper can abandon history and report success while the real execution continues |
| R50-F2 | Medium-High | Retained-handle cleanup is retryable in the backend but the high-level execution lifecycle can drop the retry owner after start/state/terminal release failures; the Review 49 native-start flag also remains latched after rejected start |
| R50-F3 | Medium | `protected markCancelledBeforeExecution()` is still consumer-reachable through subclassing and remains an ordinary callable method in emitted JavaScript, so the queue-only local cancellation mutation is not actually private |

---

# 6. R50-F1 — cancellation is still object-local when the native ID already has a managed owner

Severity: **High**

Affected production source:

- `react-native/src/session.ts`
- `react-native/src/session-queue-manager.ts`
- `react-native/src/ffmpeg-kit-extended.ts`

## 6.1 Existing authorities

The queue already maintains one native-session-ID authority:

- `SessionQueueManager.findManagedSessionById(sessionId)` returns the active or queued owner for an ID;
- `SessionQueueManager.cancelBySessionId(sessionId)` cancels that managed object;
- `FFmpegKitExtended.cancelSession(id)` correctly uses that managed-ID route before falling back to a reconstructed history wrapper.

Relevant source:

- `session-queue-manager.ts:249-274`
- `ffmpeg-kit-extended.ts:115-140`

Direct `Session.cancel()`, however, does not use the same authority.

It performs object-identity queue cancellation only:

- `session.ts:325-358`
- `SessionQueueManager.cancelQueued(this)` searches `item.session === session` at `session-queue-manager.ts:238-246`

If the caller holds a different wrapper for the same native ID, the queue lookup returns false and cancellation falls back to the requesting wrapper's local fields.

## 6.2 History reconstruction creates distinct wrapper objects

`FFmpegKitExtended.getSession`, list APIs, and last-session APIs parse native JSON into new typed wrappers.

`sessionFromSnapshot()` constructs a new `FFmpegSession`, `FFprobeSession`, `FFplaySession`, or `MediaInformationSession` for each snapshot. Only snapshots already reporting `Running` call `observeRestoredRunning()`.

Relevant source:

- `ffmpeg-kit-extended.ts:152-236`
- `session.ts:1707-1739`

A snapshot that reports `Created` therefore receives a fresh wrapper with:

- `nativeStartAttempted === false`;
- `submitted === false`;
- no restored Running observer;
- no relationship to the queued/active JavaScript owner beyond the shared native ID.

## 6.3 Reachable active-startup failure sequence

Review 44 and Review 49 intentionally preserve the fact that native startup may have been attempted while the authoritative native state still reports `Created`.

A reachable sequence is:

1. original wrapper `A` is submitted and becomes the queue's active owner;
2. `A.startNativeExecution()` crosses final preflight and sets `A.nativeStartAttempted = true` immediately before the native async start invocation;
3. the native state is still `Created` during startup handoff;
4. application code calls `FFmpegKitExtended.getSession(id)` or another history API and receives distinct wrapper `B` for the same native ID;
5. `B.nativeStartAttempted` is false because that field is object-local;
6. application code calls `await B.cancel()`;
7. `cancelQueued(B)` returns false because the queue contains `A`, not `B`;
8. `B.getState()` returns `Created`;
9. `B.cancel()` calls `abandonCreatedSession(id)` and resolves without native cancellation dispatch;
10. the native/history identity is tombstoned/hidden as a pre-execution abandonment even though `A` already owns startup;
11. `A.cancelled` is still false;
12. when the native state transitions to `Running`, `A.monitor()` checks only `A.cancelled` before dispatching native cancellation, so it does not deliver `B`'s request;
13. the real execution can continue even though `B.cancel()` reported success.

This is a false-success cancellation path, not merely a history presentation issue.

## 6.4 The same authority gap exists while the canonical wrapper is queued

If `A` is still queued rather than active and `B.cancel()` is called:

- `cancelQueued(B)` again misses by object identity;
- `B` may abandon/tombstone the native ID;
- `A` remains physically queued until it reaches handoff or another queue operation removes it;
- later handoff fails closed because the backend sees the abandonment/cancellation intent, but the cancellation call did not cancel the actual queue item immediately.

The package already has a managed-ID cancellation route that would remove `A` immediately. `Session.cancel()` simply does not reuse it.

## 6.5 Why durable cancellation intent does not close the active-startup case

`B.cancel()` records per-ID cancellation intent before reading state. That protects future execution admission, but it does not by itself deliver cancellation to the already-active original monitor.

`Session.monitor()` dispatches cancellation when:

```text
state === Running
&& this.cancelled
&& !this.nativeCancellationDispatched
```

The local `this.cancelled` belongs to `A` and remains false when only `B.cancel()` was called.

The restored ID observer can deliver durable intent while Running, but a `Created` reconstructed wrapper does not install that observer. No other observer is guaranteed to exist.

Therefore durable intent is not sufficient for this sequence.

## 6.6 Required correction

Make managed native-session-ID ownership authoritative for object cancellation as well as static ID cancellation.

Before an independent wrapper performs object-local Created/Running classification, it must detect whether a different queue-managed owner exists for the same ID.

A surgical design is:

1. add or reuse a queue-manager helper that returns/cancels the managed owner for `sessionId`, with an optional requesting object to prevent self-recursion;
2. in `Session.cancel()`, check for a different managed owner before the local idempotent/Created-abandonment branch;
3. mark the requesting wrapper cancelled and preserve durable ID intent;
4. delegate to the canonical managed object's `cancel()` transaction;
5. propagate its exact failure;
6. return without locally abandoning or independently dispatching cancellation.

Pseudo-shape:

```ts
const managed = SessionQueueManager.shared.findManagedSessionById(this.sessionId);
if (managed && managed !== this) {
  this.cancelled = true;
  NativeFFmpegKitExtended.recordCancellationIntent?.(this.sessionId);
  const delegated = managed.cancel();
  if (delegated instanceof Promise) await delegated;
  return;
}
```

A queue-manager helper that encapsulates the self-exclusion is preferable if it avoids exporting more implementation detail.

Do not canonicalize by replacing history wrappers globally; callback-bearing restored Running wrappers still need their own callback target identity. This finding is specifically about cancellation authority.

## 6.7 Required regression coverage

Add deterministic cases to the existing queue/ownership suites.

### A. Secondary Created wrapper cancels active startup through the canonical owner

- create original wrapper `A`;
- start execution and hold the native state at `Created` after the native-start invocation has occurred;
- assert `SessionQueueManager.isSessionActiveById(id) === true`;
- construct/reconstruct wrapper `B` with the same ID;
- call `B.cancel()`;
- assert zero Created abandonment;
- assert durable intent is present;
- transition native state to `Running`;
- assert exactly one native cancellation dispatch;
- assert the original execution settles normally through its existing monitor path.

### B. Secondary wrapper cancels queued canonical work immediately

- hold one blocker active;
- queue original wrapper `A`;
- create wrapper `B` for the same ID;
- call `B.cancel()`;
- assert `A` is removed from the queue immediately;
- assert `A`'s execution promise rejects with `SessionCancelledException`;
- assert native executor start count remains zero;
- assert pre-execution cleanup commits once.

### C. Delegated cancellation failure remains truthful

- make canonical managed cancellation fail on state/native dispatch;
- call cancellation through `B`;
- assert the exact canonical error reaches the caller;
- assert durable intent remains available for retry;
- assert no local abandonment by `B` occurs.

### D. No-managed-owner restored cancellation remains unchanged

Retain existing restored Running and standalone Created cancellation cases to prove that the fallback state-based path still works when no queue-managed owner exists.

---

# 7. R50-F2 — execution-owned handle release can lose its retry authority

Severity: **Medium-High**

Affected production source:

- `react-native/src/session.ts`
- `react-native/src/session-lifetime.ts`
- adjacent restored fallback in `react-native/src/session-observation.ts`

## 7.1 Backend release is explicitly retryable

`releaseSessionHandleSerialized(sessionId)` serializes one release attempt and removes only the in-flight entry in `finally`. A failed backend release does not mark the Session's `handleReleased` flag.

This is intentionally retryable state.

The restored-session observer also contains an iterative terminal release fallback when a restored ID observer exists.

That fallback is useful but not guaranteed to exist for an ordinary execution owner.

## 7.2 Native-start failure can lose cleanup authority

`Session.startNativeExecution()` sets `nativeStartAttempted = true` immediately before invoking `executeSessionAsync`.

If the invocation rejects or throws:

- the wrapper attempts `releaseOwnedHandle()`;
- a release failure is intentionally swallowed so the native-start error remains primary;
- `nativeStartAttempted` is never reset;
- no separate retry owner is registered.

Relevant source:

- `session.ts:412-458`

After the execution promise leaves the queue, a later `cancel()` can observe `Created` but refuses pre-execution abandonment because `nativeStartAttempted` is still true.

If the release also failed, the retained handle remains owned and no automatic high-level retry path was preserved.

The existing code already treats a rejected start invocation as safe for release. The start-boundary flag should therefore distinguish an accepted/in-flight start from an invocation that authoritatively rejected.

## 7.3 Monitor state-read failure has the same dropped-release pattern

If the execution monitor loses its state oracle, it intentionally attempts to release the owning handle because the run is no longer monitorable.

`session.ts:1019-1037` catches a release failure and preserves the state-read error as primary, then exits the execution monitor.

No release fallback is registered before the queue removes the execution owner.

The backend release remains retryable, but the high-level owner that knew release was required is gone.

## 7.4 Terminal release failure also lacks a guaranteed fallback

At terminal state the active monitor attempts `releaseOwnedHandle()` in finalization. If it fails, the execution promise rejects with the release error (or with an earlier primary callback/monitoring error), and the queue then removes the active owner.

A restored observer would retry the release if one already existed. But an ordinary execution does not automatically create a restored observer. If the application never reconstructed the session while it was Running, there is no guaranteed ID-level fallback owner.

The existing ownership regression demonstrates the gap indirectly:

- `wasm-session-ownership.test.js:1092-1110` causes terminal release to fail;
- the test then calls the internal backend's `releaseSessionHandle(24)` directly to prove the backend operation is retryable.

That is not a retry performed by the public `Session` lifecycle.

## 7.5 Queue cleanup idempotence is keyed to only part of the cleanup transaction

`Session.cancel()` currently returns early when:

```ts
this.cancelled && (this.nativeCancellationDispatched || this.createdSessionAbandoned)
```

`createdSessionAbandoned` does not prove retained-handle retirement committed.

`discardBeforeExecution()` deliberately treats abandonment and retained release as separate operations. If abandonment commits and release does not, the lifecycle needs to retain release retry authority rather than treating abandonment alone as the complete pre-execution cleanup commit.

Even where the ordinary queued-created path normally has no retained execution handle, this state machine is incomplete for the same failure-atomic ownership model used elsewhere.

## 7.6 Required correction

Establish one explicit cleanup/release authority that survives the execution object's exit whenever a release attempt has already been deemed semantically safe.

The implementation should have two parts.

### A. Represent pre-execution cleanup as a complete transaction

Use the existing independent flags or one semantic commit flag, but do not treat `createdSessionAbandoned` alone as full cleanup.

A valid invariant is:

```text
pre-execution cleanup committed
= Created abandonment committed
AND retained release committed/no-op committed
```

For a safely never-started Created session, cancellation should use the same `discardBeforeExecution()` transaction rather than only `abandonCreatedSession()`.

On a later cancellation:

- if abandonment committed but release did not, retry release before any state lookup that an abandonment tombstone may make unavailable;
- if release committed but abandonment did not, retry abandonment;
- return idempotently only after both parts have committed.

### B. Preserve a release retry owner after execution-monitor release failures

Add a small per-ID fallback in `session-lifetime.ts`, for example a semantic `ensureRetainedReleaseRetry(sessionId)` coordinator.

Required properties:

- one fallback loop per session ID;
- reuse `releaseSessionHandleSerialized()` for serialization;
- iterative retry, not recursive Promise chaining;
- retry only after a code path has already established that release is semantically correct;
- remove fallback bookkeeping immediately after a successful/no-op release;
- allow successful backend-wide clear to make the next release a no-op and end the retry;
- do not create a second native ownership implementation;
- do not modify shared C++ or the native ABI.

Activate the fallback after a release attempt fails in:

1. rejected native-start cleanup;
2. unmonitorable state-read cleanup;
3. terminal execution finalization;
4. pre-execution discard cleanup where a retained release actually fails.

The primary execution/callback/state error must remain the error reported by the current call. The fallback exists to preserve cleanup authority, not to replace primary error ordering.

### C. Correct the native-start boundary after rejected invocation

`nativeStartAttempted` should protect only a start that may actually be in flight/committed.

On the same authoritative start-rejection paths that already trigger release-on-start-failure, reset the start-in-flight authority before allowing later Created cleanup.

Do **not** reset it merely because state remains Created after a successful start invocation; that would reopen the accepted startup-handoff race.

A clearer enum/boolean name such as `nativeStartInFlightOrCommitted` is acceptable if it reduces ambiguity.

## 7.7 Required regression coverage

### A. Start rejection followed by cancellation can complete Created cleanup

- inject a native-start error before execution begins;
- keep state `Created`;
- assert execution rejects with the exact start error;
- call `session.cancel()` afterward;
- assert pre-execution abandonment can commit;
- assert no Running cancellation dispatch occurs.

### B. Start error remains primary while failed release gets an automatic retry owner

- inject start error plus first release failure;
- assert execution rejects with the exact start error;
- clear release failure;
- assert the fallback performs the second release attempt and commits ownership without requiring direct backend calls or a history read.

### C. Terminal release failure retries without a restored history wrapper

- execute one session to terminal state;
- fail the first retained release;
- do not call any history API and do not create a restored observer;
- assert the execution surfaces the expected release/primary error;
- clear the release failure;
- assert fallback release commits automatically;
- assert fallback bookkeeping returns to zero.

### D. State-read failure remains primary while release retries

- make state polling fail after native start;
- fail the first release;
- assert the state-read error remains the execution error;
- recover release;
- assert the fallback commits the retained release exactly once.

### E. Partial pre-execution cleanup remains retryable

- abandonment succeeds;
- retained release fails;
- assert later cleanup does not return merely because `createdSessionAbandoned` is true;
- recover release and assert it commits without duplicate abandonment.

### F. Fallback deduplication

- request release fallback more than once for one ID;
- assert at most one backend release transaction is active at a time;
- after success, assert no retry entry remains.

---

# 8. R50-F3 — `protected` does not make the queue-only cancellation marker truly internal

Severity: **Medium**

Affected source:

- `react-native/src/session.ts`
- React Native declaration/module packaging
- `react-native/tests/packed-types-consumer.js`

## 8.1 Current Review 49 correction

Review 49 changed:

```ts
markCancelledBeforeExecution(): void
```

to:

```ts
protected markCancelledBeforeExecution(): void
```

The direct packed TypeScript test now proves ordinary consumer code cannot write:

```ts
session.markCancelledBeforeExecution();
```

That is an improvement, but it does not establish a private lifecycle boundary.

## 8.2 Consumer subclasses can still invoke it

`FFmpegSession`, `FFprobeSession`, `MediaInformationSession`, and `FFplaySession` are exported classes with public constructors.

A TypeScript consumer can legally subclass one of them and invoke the protected marker:

```ts
class DerivedSession extends FFmpegSession {
  forceLocalCancellation(): void {
    this.markCancelledBeforeExecution();
  }
}
```

That operation still:

- sets only the wrapper-local `cancelled` flag;
- does not record durable ID cancellation intent;
- does not abandon the native Created identity;
- does not route through queue cancellation;
- does not dispatch native cancellation.

The subclass can therefore recreate the local/native cancellation inconsistency that Review 49 intended to remove from the consumer API.

## 8.3 `protected` has no JavaScript runtime privacy

TypeScript `protected` is a compile-time access modifier. The emitted JavaScript method is an ordinary property/method on the class instance/prototype.

The package publishes JavaScript modules as well as declarations. Plain JavaScript consumers, reflective code, or TypeScript consumers that cross the type boundary can still call the emitted method by name.

Therefore the current fix hides the marker only from a direct well-typed access expression; it does not make the queue-only mutation internal at runtime.

## 8.4 Current regression is too narrow

`tests/packed-types-consumer.js` writes one direct call and asserts that TypeScript reports a diagnostic mentioning `markCancelledBeforeExecution`.

It does not test:

- subclass access;
- declaration absence/true private representation;
- emitted JavaScript runtime reachability.

## 8.5 Required correction

Remove the queue-only state mutation as a normal named consumer-reachable method.

Preferred surgical design:

1. make the local mutation a true ECMAScript private method/field, e.g. `#markCancelledBeforeExecution()`;
2. move queue wiring into a base-class helper that is allowed to invoke that private member;
3. let the four concrete `executeAsync()` implementations call the base helper with their executor/discard closures;
4. the base helper supplies `() => this.#markCancelledBeforeExecution()` to `SessionQueueManager.executeSession()`;
5. no generated declaration or emitted JavaScript property named `markCancelledBeforeExecution` remains.

The helper may be protected if necessary, but it must not expose a callable that performs only the local cancellation mutation. Calling the helper should perform the normal queue transaction.

An equivalent module-private closure/symbol design is acceptable if it provides actual runtime privacy and keeps the marker out of consumer declarations.

Do not replace the marker with full `Session.cancel()` from queue discard; queued work must still avoid state reads, Running cancellation dispatch, and cancellation recursion.

## 8.6 Required regression coverage

### A. Direct packed-type call remains rejected

Keep the existing negative type case.

### B. Consumer subclass cannot invoke the marker

Add a packed declaration fixture containing a subclass that attempts to invoke `markCancelledBeforeExecution()`.

The fixture must fail because the member does not exist/is truly inaccessible, not merely because an unrelated type error occurred.

### C. Runtime package surface has no marker method

If the existing packed-package harness can safely load the emitted session module, instantiate a session and assert that the ordinary property name is absent/non-callable.

If direct module loading is not safe in the Node fixture because of React Native package initialization, use a focused emitted-module/source-contract assertion proving that the built class uses an ECMAScript private member and does not emit a normal `markCancelledBeforeExecution` method.

Do not use full-file byte equality.

### D. Queue cancellation semantics remain unchanged

Retain assertions that:

- queued cancellation marks the retained object cancelled before cleanup;
- executor start count is zero;
- no native state read is needed for queue discard;
- no Running native cancellation is dispatched;
- all four concrete Session types wire the queue hook.

---

# 9. Platform-native bridge audit

Review 50 found no new substantive platform-native bridge defect.

The following accepted boundaries remain present and unchanged:

- Flutter iOS CocoaPods and SwiftPM FFplay copies reject `registerTexture:` ID `0` with `TEXTURE_REGISTRATION_FAILED` before publishing texture/callback/owner state;
- Flutter macOS retains the same Darwin registration guard;
- Flutter Windows external-texture retirement remains completion-owned;
- Flutter Linux remains on `FlPixelBufferTexture` lifecycle ownership;
- Flutter Windows/Linux packed-frame normalization remains present;
- React Native shared C++ retains composable `SessionOperationToken` admission for history projection and clear;
- retained-handle release remains failure-atomic in shared C++;
- Windows async action error completion remains invocation-bound;
- React Native Android and Apple FFplay ownership/coordinator code is unchanged;
- React Native Windows FFplay view and log/error transport are unchanged.

No implementation change is recommended in any of those directories for Review 50.

# 10. Flutter wrapper audit

No Flutter production source changed between the Review 48 and Review 49 frozen authorities.

Review 50 did not establish a contradictory defect in the previously accepted Flutter session lifecycle, history, cancellation intent, observer demand, queue settlement, or FFplay wrapper surfaces.

Disposition: **Flutter remains closed in the audited surfaces.**

No Flutter implementation or documentation change is required by Review 50.

# 11. Other React Native lifecycle boundaries rechecked and retained

No new substantive defect was established in:

- Review 49 deterministic `cancelCurrent()` target-order error selection;
- Review 49 queue-before-active branch ordering in `cancelAll()`;
- same-object consumed-but-never-started cancellation;
- submitted-startup Created protection on the canonical executing wrapper;
- queue reservation cleanup and duplicate native-ID admission;
- Review 47 configuration/lifecycle clear parity;
- clear-time observer non-resurrection;
- restored Running callback demand and bounded callback targets;
- restored terminal release fallback when an observer entry actually exists;
- Web history-pointer failure atomicity;
- per-ID serialized cancellation dispatch;
- native/Web Created abandonment tombstones;
- native ABI exports.

Do not reopen those surfaces without new direct evidence.

# 12. Documentation implications

React Native documentation should remain semantic.

After remediation:

- state that cancellation of any wrapper for a native session ID routes through an existing queued/active owner when one exists;
- retain the distinction between pre-native-start cancellation and startup-in-flight Created state;
- state that retained handle retirement remains owned until cleanup commits, including after transient release failure;
- keep deterministic active-session cancellation error ordering language;
- do not document the queue-only local marker because it must be truly internal;
- do not mention review/finding identifiers in user-facing documentation.

No Flutter documentation change is required.

# 13. Review 50 goals

1. **Canonical managed-ID cancellation:** make `Session.cancel()` delegate to the actual queued/active owner for the same native ID before any secondary wrapper performs object-local Created abandonment or Running dispatch.
2. **Persistent release/cleanup authority:** preserve retry ownership after semantically safe release failures, make pre-execution cleanup commit only after abandonment plus retained release, and correct the native-start boundary after an authoritative start rejection.
3. **True queue-marker privacy:** remove the local queue cancellation mutation from subclass/runtime consumer reach while preserving mark-before-cleanup and zero native dispatch.
4. **Closure verification:** add deterministic regressions, update semantic RN docs, run affected local validation only with frozen ABI `0.11.2`, re-audit all frozen boundaries, and create one exact-SHA wrapper-only source snapshot only after a zero-finding final audit.

# 14. Closeout status

**Review 50 does not close the React Native wrapper.**

Platform-native bridge: **closed**.  
Flutter wrapper: **closed in the audited surfaces**.  
React Native wrapper: **3 substantive findings remain**.

A final cross-platform closeout may be claimed only after:

- the three findings above are implemented;
- deterministic regression evidence is green;
- affected local Windows → Android-on-Windows → Linux/WSL → Apple-last validation is recorded truthfully;
- Flutter/platform-native/source boundaries remain unchanged;
- native ABI `0.11.2`, `libs/libffmpegkit`, and builders remain frozen;
- no hosted Flutter/React Native acceptance workflow or remote old native bundle is used;
- the final bounded source audit finds zero substantive findings;
- one exact final wrapper SHA is pushed and verified through the wrapper-only source snapshot workflow.
