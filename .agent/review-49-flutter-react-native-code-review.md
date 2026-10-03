# Review 49 — Flutter + React Native Cross-Platform Code Review

Date: 2026-10-02  
Repository: `akashskypatel/ffmpeg-kit-extended`  
Branch represented by reviewed snapshot: `dev-wasm`  
Review type: frozen-source, code-review-only, substantive findings only

## 1. Authority and provenance

Review 49 uses the exact final Review 48 wrapper freeze as its only source authority:

`8c89594380b9db5313bd4a7c4173e341b5943f31`

The tracker records:

- source snapshot workflow: `37088245634`
- artifact: `review48-final-source-snapshot-37088245634`
- artifact ID: `11261735639`
- GitHub artifact SHA-256: `2bd60d4a76a31e9d94b055d54d8f7cd019f4e00ec1fffdde47174826e1ad681c`
- embedded `source.tar.gz` SHA-256: `f295a62cd61fa81382429d931f769ba42175dd2f8a4eafdb7bfaae8ab26d000a`
- manifest entries: `1080/1080` verified
- symlinks: `0`
- `runtimeExecution=false`
- recursive native submodule: `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`

The downloaded artifact was independently checked against those values before extraction. Review 49 did not download, rebuild, execute, or re-review native ABI/runtime `0.11.2`.

No tests, builds, application launches, simulators, devices, Web UI, hosted acceptance workflows, or repository mutations were performed as Review 49 evidence.

## 2. Scope and threshold

The requested order was applied:

1. recheck Flutter and React Native platform-native bridge boundaries;
2. if platform-native remains closed, recheck Flutter wrapper boundaries;
3. if Flutter remains closed, audit React Native wrapper changes from Review 48 and the adjacent cancellation/queue/lifecycle authorities;
4. report only reachable product/lifetime/error-authority defects;
5. exclude style, formatting, procedural, speculative, and pedantic observations.

The native ABI and builders remain out of scope and frozen.

## 3. Snapshot no-drift result

The exact Review 48 snapshot was compared against the preceding verified Review 47 snapshot. The following production trees are byte-for-byte unchanged:

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

The Review 48 production delta is limited to:

- `react-native/src/session.ts`
- `react-native/src/session-queue-manager.ts`
- `react-native/src/ffmpeg-kit-extended.ts`

with associated React Native README/tests.

Therefore the accepted platform-native bridge and Flutter implementation remain closed unless contradicted by the fresh semantic audit. No contradiction was found.

## 4. Disposition

| Area | Review 49 disposition |
| --- | --- |
| Native ABI/runtime `0.11.2` | Frozen; not reviewed |
| Flutter platform-native bridge | Closed |
| React Native platform-native bridge/shared C++ | Closed |
| Flutter wrapper | Closed in audited lifecycle/session surfaces |
| React Native wrapper | **Not closed — 3 substantive findings** |

### Findings summary

| Finding | Severity | Summary |
| --- | --- | --- |
| R49-F1 | Medium-High | Pre-start cancellation uses `submitted` as a proxy for native-start authority, so a consumed-but-never-started submission can suppress safe Created abandonment and retry |
| R49-F2 | Medium | `cancelCurrent()`/`cancelAll()` choose async failure authority by promise settlement timing instead of stable target/branch order |
| R49-F3 | Medium | The queue-only pre-execution cancellation marker became a public `Session` API and can create local-only cancellation without ID-level cancellation/abandonment authority |

## 5. R49-F1 — pre-start cancellation commit state is conflated with public submission consumption

Severity: **Medium-High**

Affected production source:

- `react-native/src/session.ts`
- adjacent queue interaction in `react-native/src/session-queue-manager.ts`

### 5.1 Current state model

`Session` currently has these relevant fields:

- `cancelled`
- `nativeCancellationDispatched`
- `submitted`
- `createdSessionAbandoned`

`Session.cancel()` performs:

1. set `cancelled = true`;
2. record ID-level cancellation intent;
3. `await SessionQueueManager.shared.cancelQueued(this)`;
4. read current state;
5. abandon only when state is `Created` **and `!submitted`**.

`submitOnce()` uses `submitted` for one-shot API behavior. It also sets `submitted = true` when it observes that the object was already locally cancelled, even though no queue admission or native start occurs.

That means `submitted` currently expresses two different concepts:

- “the public execution API has been consumed”; and
- “native startup may have begun, so a Created session must not be abandoned.”

Those concepts are not equivalent.

### 5.2 Reachable race without any backend failure

A fresh Created session can take this sequence:

1. caller invokes `const cancellation = session.cancel()` without awaiting it;
2. `cancel()` records local + ID-level cancellation;
3. `cancel()` reaches `await cancelQueued(this)`;
4. the queue returns synchronous `false`, but the unconditional `await` still yields to a microtask;
5. caller invokes `session.executeAsync()` before cancellation resumes;
6. `submitOnce()` sees `cancelled === true`, sets `submitted = true`, and rejects with `SessionCancelledException` without queue/native handoff;
7. `cancel()` resumes, sees native state `Created` but `submitted === true`, skips `abandonCreatedSession()`, and resolves.

Result:

- execution correctly does not start;
- durable cancellation intent remains, so wrapper execution remains fail-closed;
- however the never-started Created identity never reaches the intended explicit abandonment transaction;
- native/history cleanup is left incomplete until another lifecycle event such as global clear.

This is not a theoretical thread race. It is ordinary JavaScript interleaving created by `await` on a synchronous `false` result.

### 5.3 Failed queued abandonment also loses its normal retry branch

A queued session has already set `submitted = true` before it enters the queue.

If queue discard calls `discardBeforeExecution()` and `abandonCreatedSession()` fails:

- queue policy logs the discard cleanup failure and still rejects the queued execution with `SessionCancelledException`;
- `createdSessionAbandoned` remains false;
- a later `Session.cancel()` sees `submitted === true`;
- if native state is still `Created`, the `state === Created && !submitted` retry branch is skipped.

The Review 48 requirement that failed Created abandonment remain retryable is therefore true for the direct never-submitted test case, but not for the queued/discarded case.

On the native backend the ID tombstone is installed before the asynchronous native abandonment action, so reconstruction stays fail-closed. That prevents re-execution, but it does not make the failed native/history cleanup transaction complete. The wrapper loses the semantic retry route that Review 48 intended to preserve.

### 5.4 Root cause

`submitted` is too coarse to be the safety authority for Created abandonment.

The safety question is not “was `executeAsync()` ever called?” It is:

> Has native start actually been attempted, such that a `Created` observation may represent an in-flight startup handoff rather than a never-started identity?

Review 44 correctly protected submitted-startup Created sessions. Review 48 correctly added local queued cancellation state. The missing step is a distinct native-start/handoff state.

### 5.5 Required correction

Introduce semantic state that separates:

- one-shot public submission consumption; from
- actual native-start attempt / startup handoff authority.

A suitable design is:

- retain `submitted` (or rename internally to `submissionConsumed`) solely for one-shot execution API behavior;
- add a private `nativeStartAttempted`/`executionHandoffStarted` boolean;
- set it immediately after the final `prepareForExecution()` succeeds and immediately before calling `executeSessionAsync`;
- in `cancel()`, a `Created` identity is safe to abandon when native start has **not** been attempted, even if the public submission was consumed or the wrapper previously sat in the JS queue;
- once native start has been attempted, preserve the existing submitted-startup behavior: retain durable intent and wait for Running/terminal observation instead of abandoning the Created identity.

Also avoid yielding on the common synchronous `cancelQueued(...) === false` path. Resolve the `MaybePromise<boolean>` explicitly:

```ts
const queuedCancellation = SessionQueueManager.shared.cancelQueued(this);
if (queuedCancellation instanceof Promise) {
  if (await queuedCancellation) return;
} else if (queuedCancellation) {
  return;
}
```

The no-yield change removes the avoidable pre-submission microtask window; the distinct native-start authority fixes the deeper retry problem even when asynchronous cleanup/interleavings occur.

Do not solve this by abandoning every submitted Created session. That would reopen the accepted startup-handoff race.

### 5.6 Required tests

Add deterministic cases to the existing ownership/cancellation suite:

1. **cancellation wins before a concurrent submission attempt**
   - create a fresh Created session;
   - start `session.cancel()` without awaiting it;
   - immediately call `session.executeAsync()`;
   - execution rejects as cancelled;
   - native executor start count stays zero;
   - Created abandonment commits exactly once;
   - repeated cancellation is a no-op after commit.

2. **queued abandonment failure remains retryable after queue removal**
   - hold another session active so target remains queued;
   - inject one abandonment failure for the queued target;
   - cancel/remove target from queue;
   - prove no executor start;
   - call `cancel()` again after clearing the injected error;
   - prove the abandonment action is attempted again and commits once;
   - prove no Running cancellation is dispatched.

3. **consumed submission does not imply native handoff**
   - use a pre-start cancellation/queue-discard case where public submission was consumed;
   - assert Created cleanup still occurs because native start was never attempted.

4. **submitted startup Created remains non-destructive**
   - retain the existing startup test;
   - native start is attempted while state still reads Created;
   - cancellation records durable intent but performs zero Created abandonment;
   - cancellation dispatch occurs once Running is observed.

5. Preserve all state-probe failure, Running retry, terminal race, queue discard, restored-session, and handle-release regressions.

## 6. R49-F2 — first cancellation error is selected by settlement timing

Severity: **Medium**

Affected source:

- `react-native/src/session-queue-manager.ts`

### 6.1 Current behavior

`cancelCurrent()` snapshots active sessions in stable Set iteration order and invokes every target. That part is correct.

For Promise-returning cancellations, however, every rejection handler mutates one shared `firstError` when its Promise settles:

```ts
cancellation.catch((error) => {
  if (firstError === undefined) firstError = error;
})
```

Therefore the reported error is the first Promise to reject in wall-clock/microtask settlement order, not the first failing target in the stable active-session snapshot.

A later target that rejects quickly can become error authority while an earlier target rejects more slowly. Native scheduling and bridge timing can change that winner between platforms or runs.

The same shared-settlement pattern is used by `cancelAll()` when combining queue-clear and active-cancellation branches.

### 6.2 Why this is substantive

The queue contract already promises deterministic first-error authority while still attempting every active target. Earlier closure work also treats “first error” as an ordering invariant rather than a race winner.

All cancellation requests are still delivered, so this is not a missed-cancellation defect. It is an error-authority defect: the caller can receive a different error for the same target ordering depending on asynchronous completion timing.

### 6.3 Required correction

Capture outcomes by deterministic position, not by completion time.

For `cancelCurrent()`:

1. take `const sessions = [...this.active]`;
2. create one indexed outcome slot per target;
3. invoke every cancellation immediately in snapshot order;
4. store synchronous errors in that target's slot;
5. for asynchronous results, settle that same target's slot when its Promise completes;
6. after every asynchronous attempt settles, scan the slots from index 0 upward and throw the first recorded error;
7. if no async work exists, perform the same ordered scan synchronously and preserve current `MaybePromise<void>` behavior.

Use an explicit tagged slot rather than `undefined` as the sentinel so even an unusual `throw undefined` cannot be mistaken for success.

For `cancelAll()`:

- preserve branch order explicitly rather than letting branch settlement race to assign one shared variable;
- queue-removal branch is initiated first, active-cancellation branch second;
- await every initiated branch;
- choose the first recorded branch failure according to that defined order.

Do not serialize active cancellation. Every target must still be invoked before awaiting aggregate completion.

### 6.4 Required tests

Add deterministic latch/deferred cases:

1. **active cancellation error authority ignores settlement order**
   - active A is first in queue order and returns a deferred Promise;
   - active B is second and returns another deferred Promise;
   - reject B first, then A;
   - aggregate must reject with A's exact error object.

2. Reverse the Promise settlement order and prove the same A error remains authority.

3. First target succeeds and second target fails; aggregate reports second.

4. First target throws synchronously while later targets reject asynchronously; all targets are attempted and first target remains authority.

5. Preserve existing all-success, all-target-attempt, deferred queued-cleanup ordering, and cancel-all completion-waits-for-both regressions.

## 7. R49-F3 — queue-only cancellation marker leaked into the public Session API

Severity: **Medium**

Affected source:

- `react-native/src/session.ts`
- `react-native/src/session-queue-manager.ts`
- `react-native/src/index.ts`
- `react-native/src/index.web.ts`

### 7.1 Current exposure

Review 48 added:

```ts
markCancelledBeforeExecution(): void {
  this.cancelled = true;
}
```

to the exported `Session` base class.

Both package entry points export everything from `./session`, and the package publishes generated TypeScript declarations from that source. There is no `stripInternal` boundary in the TypeScript build configuration.

The method is therefore part of the consumer-visible typed API even though its semantics are explicitly queue-internal.

### 7.2 Reachable inconsistent identity

A consumer can call the exposed method directly on a fresh Created session:

1. `markCancelledBeforeExecution()` sets only the wrapper-local `cancelled` flag;
2. it does **not** record ID-level cancellation intent;
3. it does **not** abandon/tombstone the Created identity;
4. `executeAsync()` on that wrapper rejects as cancelled;
5. native history can still expose the same Created session ID;
6. a reconstructed wrapper has no local cancellation flag and no ID-level cancellation authority established by the marker.

The public object and the native session identity can therefore disagree about whether that identity has been cancelled.

This is not merely naming/style. The method can produce a lifecycle state that the supported cancellation APIs intentionally prevent.

### 7.3 Required correction

Remove the queue marker from the public `Session` contract.

Preferred surgical design:

- make the base marker `protected` or private;
- extend the internal `QueueItem`/`executeSession` handoff with an explicit pre-execution-cancel callback, for example `onCancelBeforeExecution?: () => void`;
- each concrete Session `executeAsync()` passes a closure from inside the class/subclass that invokes the protected marker;
- `SessionQueueManager.discard()` invokes the queue-item callback before discard cleanup;
- external consumers no longer see a typed method that can create local-only cancellation.

An alternative internal symbol/closure is acceptable if it keeps the marker out of generated public declarations and preserves the same ordering.

Do not replace this with full `Session.cancel()` from queue discard; that would reintroduce state reads/native Running cancellation on work that never started.

### 7.4 Required tests

1. Type/declaration contract: the packed public type surface must not expose `markCancelledBeforeExecution` as a callable `Session` API.
2. Queue cancellation still records the retained object's local cancelled state before discard cleanup.
3. Queue cancellation still performs zero state reads and zero native Running-cancel dispatches for never-started work.
4. Existing queue-discard and retained-object tests remain green.
5. Optional source-contract assertion may confirm the queue uses the internal callback/seam rather than a public Session method; do not use brittle full-file string equality.

## 8. Clean boundaries retained by Review 49

No new substantive defect was established in:

- Flutter wrapper session lifecycle/history/cancellation code;
- Flutter Windows/Linux/macOS/iOS/Android platform-native bridge;
- React Native shared C++ retained-handle/clear/history operation authority;
- React Native Windows error transport and FFplay surface;
- React Native Android FFplay surface owner;
- React Native iOS/tvOS/macOS FFplay views/coordinators;
- restored Running observer ownership and callback demand;
- successful clear invalidation;
- Web history-pointer failure atomicity;
- terminal release retry authority;
- callback setup terminal/clear serialization;
- native ABI exports.

Do not broaden implementation into these surfaces without new source evidence.

## 9. Documentation implications

Public React Native documentation should describe semantics, not implementation history.

After remediation:

- retain the statement that Created/queued cancellation prevents native start;
- clarify that one-shot submission consumption does not weaken pre-start cleanup;
- state that cancellation requests across active sessions are all attempted and aggregate errors are selected in stable target order;
- do not document the queue-only marker because it must no longer be public;
- preserve the existing statement that submitted startup can remain Created and is not destructively abandoned after native start has begun.

No Flutter documentation change is required by Review 49.

## 10. Review 49 goals

1. Separate public submission consumption from native-start authority and restore retryable pre-start abandonment for every never-started path.
2. Make multi-session cancellation error authority deterministic by target/branch order while retaining parallel delivery and all-target attempts.
3. Remove the queue-only cancellation marker from the exported Session API while preserving queue-local cancellation state and zero native dispatch for never-started work.
4. Add deterministic regression coverage and semantic documentation, run only affected local validation using frozen ABI `0.11.2`, then perform one final bounded audit and exact-SHA wrapper snapshot if zero substantive findings remain.

## 11. Closeout status

**Review 49 does not close the React Native wrapper.**

Platform-native bridge: **closed**.  
Flutter wrapper: **closed in the audited surfaces**.  
React Native wrapper: **3 substantive findings remain**.

A final closeout may be claimed only after the three findings above are implemented, deterministic regressions are green, affected local platform validation is recorded truthfully, no frozen boundary drifts, and a new exact wrapper SHA is snapshotted and verified.
