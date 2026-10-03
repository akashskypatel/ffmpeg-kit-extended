# Review 50 — Luna Flutter + React Native Wrapper Closure Plan

Date: 2026-10-02  
Audience: Luna implementation/review model  
Repository: `akashskypatel/ffmpeg-kit-extended`  
Branch: `dev-wasm`  
Starting wrapper authority: `a26128cfc89b04e814102b3311d077313677822f`

## Mission

Close the three remaining React Native wrapper defects identified by Review 50 without reopening accepted Flutter, platform-native, shared-C++, or native-ABI behavior.

The implementation must establish:

1. one cancellation authority per native session ID even when multiple JavaScript wrappers exist;
2. cleanup/release ownership that remains retryable until a semantically required retained-handle release commits;
3. true runtime/type privacy for the queue-only local cancellation marker;
4. deterministic regression evidence and semantic documentation;
5. one exact-SHA wrapper-only source snapshot only after a final zero-finding audit.

If all goals below are completed and the final bounded audit has zero substantive findings, the next review should be a closeout verification rather than another remediation cycle.

## Hard boundaries

- Keep native ABI/runtime `0.11.2` frozen.
- Keep `libs/libffmpegkit` exactly at `b74da2c5d1e294b87d15d73a6687393729e932b3` on `dev`, matching `origin/dev`.
- Do not edit or rebuild the ManyLinux builders checkout.
- Do not download a remote old/staged native ABI bundle.
- Do not publish a native ABI artifact.
- Do not add or change exported native symbols.
- Do not modify React Native shared C++, Windows C++, Android Java/Kotlin/C++, or Apple Objective-C++ unless new direct source evidence proves a wrapper-only solution impossible. Review 50 identifies no such need.
- Do not modify Flutter production code unless new direct evidence proves a Flutter defect. Review 50 found none.
- Do not run hosted Flutter/React Native build or test workflows.
- The only permitted hosted workflow after a clean final source freeze is the wrapper-only repository source-snapshot workflow.
- Do not launch interactive apps, simulators, devices, or Web UI for automated acceptance.
- Interactive Flutter/React Native validation remains user-owned after remediation.
- Use only locally configured native ABI `0.11.2` artifacts for local validation.
- Do not fetch a remotely built stale/old native bundle for local tests.
- Production/test/comment names must be semantic. Do not place `Review 50`, `R50`, goal IDs, or finding IDs in implementation symbols, tests, comments, or user-facing docs.
- Record test failures, environment failures, retries, skipped tests, and mistakes truthfully. Do not fabricate or weaken tests to obtain green output.
- Exclude style, formatting, procedural, speculative, and pedantic observations from the final substantive audit.

## Starting evidence

Review 50 independently verified the frozen Review 49 artifact:

- wrapper SHA: `a26128cfc89b04e814102b3311d077313677822f`
- workflow: `37092403431`
- artifact ID: `11262925973`
- artifact name: `review49-final-source-snapshot-37092403431`
- artifact digest: `sha256:44ab21a115ce2e3b683d024216dc87de9a8c1c3230e1453138af0bc6b4e48bb1`
- embedded source archive SHA-256: `c7f3f85cd8b1be986d055f402dd50ac5b89d9dd61e2634affc5d74ad411d56fa`
- `SHA256SUMS`: `1080/1080` verified
- symlinks: `0`
- `runtimeExecution=false`
- frozen recursive submodule: `b74da2c5d1e294b87d15d73a6687393729e932b3`

Review 50's no-drift comparison found no production changes in Flutter, React Native shared C++, or any platform-native directory relative to the preceding verified authority.

## Goal tracker

| Goal | Objective | Expected production scope | Status |
| --- | --- | --- | --- |
| G1 | Route cancellation from any wrapper through the canonical queued/active owner for that native session ID | `react-native/src/session.ts`, `react-native/src/session-queue-manager.ts`; tests/docs | Pending |
| G2 | Keep pre-execution and retained-handle cleanup retry authority alive until release commits, including start/state/terminal failure paths | `session.ts`, `session-lifetime.ts`; possibly a narrow observer/lifetime hook; tests/docs | Pending |
| G3 | Make the queue-only local cancellation marker truly private at both TypeScript and JavaScript runtime boundaries | `session.ts` plus packed type/API tests | Pending |
| G4 | Preserve prior lifecycle behavior, run affected local validation, perform zero-finding audit, freeze exact SHA, verify wrapper-only snapshot | tests/docs/tracker only unless evidence requires otherwise | Pending |

Do not mark any goal complete from source inspection alone. A goal closes only after the required deterministic regression evidence passes locally.

---

# Goal 1 — canonical cancellation by native session ID

## Problem to solve

A native session ID can be represented by more than one JavaScript `Session` wrapper:

- the original object can be queued or active in `SessionQueueManager`;
- `FFmpegKitExtended.getSession(id)`, list APIs, or last-session APIs can construct another wrapper for the same ID;
- consumers can also construct another exported concrete Session wrapper with an existing ID.

`FFmpegKitExtended.cancelSession(id)` already prefers the managed queue owner by ID.

Direct `Session.cancel()` does not. It calls `cancelQueued(this)`, which matches object identity, then classifies native state using the requesting wrapper's private fields.

A second wrapper can therefore see `Created`, conclude native start never happened because its own `nativeStartAttempted` is false, and abandon the identity even while another wrapper already owns queue/native startup.

This must be fixed before any object-local Created abandonment occurs.

## Required semantic rule

For a given native `sessionId`:

> If `SessionQueueManager` already has a queued or active owner for that ID and the caller is a different wrapper object, cancellation must be delegated to that managed owner. The secondary wrapper must not independently abandon the ID or dispatch a second native cancellation transaction.

Object identity is not the cancellation authority. Native session ID + managed queue ownership is.

## Recommended implementation shape

Use the existing manager inventory rather than creating another registry.

Current useful methods already exist:

- `findManagedSessionById(sessionId)`
- `cancelBySessionId(sessionId)`
- `isSessionActiveById(sessionId)`

The cleanest surgical change is either:

### Option A — add an exclusion-aware manager helper

For example:

```ts
cancelManagedSessionById(
  sessionId: number,
  requester?: CancellableSession
): MaybePromise<boolean> {
  const session = this.findManagedSessionById(sessionId);
  if (!session || session === requester) return false;
  const cancellation = session.cancel();
  if (cancellation instanceof Promise) {
    return cancellation.then(() => true);
  }
  return true;
}
```

Then `Session.cancel()` asks this helper before object-local classification.

### Option B — resolve the managed owner in `Session.cancel()`

For example:

```ts
const managed = SessionQueueManager.shared.findManagedSessionById(
  this.sessionId
);
if (managed && managed !== this) {
  this.cancelled = true;
  NativeFFmpegKitExtended.recordCancellationIntent?.(this.sessionId);
  const delegated = managed.cancel();
  if (delegated instanceof Promise) await delegated;
  return;
}
```

Use the existing `CancellableSession` abstraction; do not create a second owner map.

## Exact ordering requirements

The ordering in `Session.cancel()` must be:

```text
resolve different managed owner by native ID
-> if found: record requesting wrapper cancellation / durable intent as appropriate
-> delegate to managed owner's cancel transaction
-> propagate exact delegated failure
-> return
-> otherwise continue with this wrapper's normal idempotence/queue/state path
```

The different-owner check must happen **before** a local early return based on `createdSessionAbandoned` or `nativeCancellationDispatched`.

Reason: a secondary wrapper may have stale local flags from an earlier attempt while a current canonical owner for the ID still exists.

## Preserve current managed-owner semantics

When the canonical owner is queued:

- its own `cancel()` must remove the exact queue item immediately;
- queue-local mark-before-cleanup still applies;
- execution promise rejects with `SessionCancelledException`;
- executor start count remains zero;
- reservation is released after cleanup.

When the canonical owner is active but has not reached native start:

- its own local cancellation should prevent start and run safe pre-execution cleanup.

When native start has been attempted but state still reads `Created`:

- the canonical owner's native-start authority must protect against destructive abandonment;
- durable intent survives;
- cancellation dispatch occurs when `Running` becomes authoritative.

When state is `Running`:

- one per-ID serialized native cancellation dispatch remains authoritative.

When no managed owner exists:

- standalone Created cancellation and restored Running cancellation continue using the existing object/state path.

## Do not solve this by global wrapper canonicalization

Do **not** replace every history wrapper with the active object.

History wrappers can own separate completion/log/statistics callback targets and restored-observer state. Global object canonicalization would reopen Review 44–47 callback/lifetime design.

Only cancellation authority needs to delegate to the managed execution owner.

## Goal 1 deterministic regression tests

Prefer existing files:

- `react-native/tests/wasm-session-ownership.test.js`
- `react-native/tests/session-queue-manager.test.js`
- `react-native/tests/restored-session-observer.test.js` only if needed for restored behavior preservation

### Test A — second wrapper cannot abandon an active startup

Add a fixture control so `executeSessionAsync` can be invoked while native state remains `Created` until the test advances it.

Sequence:

```text
create original A with ID
execute A
wait until native start call count == 1 while state remains Created
assert manager reports ID active
create/reconstruct wrapper B for same ID
call B.cancel()
```

Assertions before Running transition:

- `B.cancel()` does not call `abandonCreatedSession`;
- no duplicate executor start;
- canonical original is marked cancelled / durable intent exists;
- no native cancellation is dispatched while authoritative state is still Created startup.

Then:

```text
set state Running
allow monitor iteration
```

Assertions:

- exactly one native cancellation dispatch for ID;
- no Created abandonment;
- execution eventually reaches terminal path and releases ownership normally.

Use deterministic counters/gates; do not prove ordering with arbitrary sleeps alone. Existing monitor polling can be paired with a deferred state gate or explicit bounded helper.

### Test B — second wrapper removes queued canonical owner immediately

- set concurrency to one;
- keep blocker active;
- create and queue original `A`;
- create secondary wrapper `B` for same ID;
- call `B.cancel()`;
- assert manager queue length drops immediately;
- assert `A`'s execution promise rejects with `SessionCancelledException`;
- assert native executor starts zero times;
- assert queue cleanup/abandonment occurs once;
- assert reservation is released.

This must fail against the Review 49 snapshot, where `cancelQueued(B)` misses the queued `A` object.

### Test C — delegated error identity is preserved

Create active original `A`, secondary `B`, and inject a cancellation failure in `A`.

Assert:

- `B.cancel()` rejects with the exact error object emitted by canonical `A.cancel()`;
- durable cancellation intent remains;
- `B` does not call Created abandonment;
- retry through either canonical or secondary wrapper reaches the same per-ID cancellation authority.

### Test D — no managed owner preserves restored Running behavior

Retain an existing restored Running wrapper with no queue owner and prove:

- state Running;
- cancellation dispatch occurs once;
- restored observer retry behavior remains intact after transient failure.

### Test E — duplicate ID admission remains unchanged

Retain the existing duplicate-native-ID queue tests. Delegated cancellation must not weaken reservation enforcement.

## Goal 1 documentation

Update React Native README/TSDoc semantically:

- any wrapper cancellation for an ID with queued/active managed work is routed through that managed execution owner;
- a history/control wrapper cannot independently abandon a live startup owned by another wrapper;
- pre-start cancellation and startup-in-flight Created state remain distinct.

Do not expose manager implementation names unless they are already public API concepts.

---

# Goal 2 — preserve cleanup/release ownership until retained release commits

## Problem to solve

The backend/session-lifetime layer deliberately makes retained release retryable:

- one in-flight release per ID;
- failed release leaves ownership available for another attempt;
- restored terminal observers retry release iteratively when they exist.

The ordinary executing `Session` does not always preserve a retry owner after its release attempt fails.

The affected branches are:

1. native-start invocation failure;
2. execution-monitor state-read failure;
3. terminal finalization release failure;
4. partial pre-execution cleanup where abandonment and retained release do not both commit.

The high-level Session can leave the queue/active set after these branches. A restored observer is not guaranteed to exist, so backend retryability alone is insufficient.

## Required lifecycle invariant

> Once a high-level path decides that retained handle release is semantically safe and attempts it, a failure must leave exactly one retry authority alive until release succeeds or a successful global clear makes release unnecessary.

Primary user-visible error ordering must remain unchanged.

## Part A — make pre-execution cleanup a two-part commit

Current state has independent flags:

- `createdSessionAbandoned`
- `handleReleased`

Use them as independent commit state instead of treating abandonment alone as completion.

Recommended helper semantics:

```ts
private get preExecutionCleanupCommitted(): boolean {
  return this.createdSessionAbandoned && this.handleReleased;
}
```

or an equivalent named method.

### Change the early idempotence condition

Current concept:

```text
cancelled && (nativeCancellationDispatched || createdSessionAbandoned)
```

Required concept:

```text
cancelled && (
  nativeCancellationDispatched
  OR complete pre-execution cleanup committed
)
```

Do not return merely because abandonment committed if retained release is still pending.

### Retry already-abandoned retained cleanup before state reads

If:

```text
createdSessionAbandoned == true
handleReleased == false
```

then a later `cancel()` must retry `releaseOwnedHandle()` before calling `getState()`.

Reason: native/Web abandonment tombstones can make normal state lookup unavailable even though the retained-handle release still needs to commit.

### Use one cleanup transaction for safely never-started Created sessions

When state is `Created` and no native startup can be in flight, call the existing combined cleanup path rather than abandonment alone:

```ts
await this.discardBeforeExecution();
```

That helper already attempts abandonment and retained release independently and preserves the first failure.

Do not duplicate backend release logic in `cancel()`.

## Part B — distinguish successful/ongoing native start from rejected invocation

Review 49 added `nativeStartAttempted` to protect startup-in-flight Created state. Keep that protection, but do not leave it permanently latched after the start invocation authoritatively rejects.

The same failure branches already treat rejected start as safe for release. Align the state model with that existing contract.

A clearer state is acceptable, for example:

```ts
private nativeStartInFlightOrCommitted = false;
```

Required ordering:

```text
final prepareForExecution succeeds
-> set nativeStartInFlightOrCommitted = true
-> invoke executeSessionAsync
-> on successful invocation/Promise resolution: keep true
-> on authoritative invocation rejection/throw: set false before/while failure cleanup is registered
```

Do not set it false merely because a successfully invoked native worker still reports `Created`.

That would reopen the startup-handoff race.

## Part C — add one retained-release fallback authority

Implement in `react-native/src/session-lifetime.ts` or another narrowly scoped internal lifetime module.

Suggested semantic API:

```ts
export function ensureRetainedReleaseRetry(sessionId: number): void;
```

Optional internal test seam:

```ts
export function getRetainedReleaseRetryCount(): number;
```

### Required properties

- map/deduplicate by `sessionId`;
- one retry loop per ID;
- use `releaseSessionHandleSerialized(sessionId)` for every attempt;
- iterative loop, not recursive `.catch(() => retry())` chains;
- small fixed/bounded polling delay consistent with existing restored observer behavior;
- remove the retry entry immediately after successful/no-op release;
- if a successful global clear empties backend ownership, the next release is allowed to no-op successfully and stop the loop;
- do not retain Session wrapper objects in the retry map;
- do not add native symbols;
- do not perform state reads in the retry coordinator: only callers that already established release safety may register it.

### Where to register fallback

Register only after a normal release attempt has failed in a path that already decided release is correct:

#### 1. Start invocation failure

Current branch preserves native-start error over release error.

Required behavior:

```text
start invocation fails
-> clear startup-in-flight authority for this rejected invocation
-> attempt release once
-> if release fails, register release fallback
-> throw original start error
```

#### 2. State-read failure while monitoring

Current branch already decides release is the safe abandonment/cancellation action for an unmonitorable run.

Required behavior:

```text
state read fails
-> attempt release
-> if release fails, register release fallback
-> throw original state error
```

#### 3. Terminal finalization release failure

Required behavior:

```text
terminal state known
-> attempt release
-> if release fails, register release fallback
-> preserve existing terminal/primary error ordering
```

The fallback must survive after `SessionQueueManager.completeActiveItem()` removes the execution owner.

#### 4. Pre-execution discard release failure

If abandonment succeeds but retained release fails:

- preserve cleanup diagnostic behavior;
- ensure a retry owner exists;
- do not treat abandonment alone as full cleanup commit.

## Interaction with restored-session observer

Do not delete the restored observer release fallback.

Both authorities must use `releaseSessionHandleSerialized()` so they cannot double-release.

If both exist for one ID:

- one attempt wins serialization;
- the other sees the same in-flight Promise or a later no-op success;
- both retire their local bookkeeping after successful/no-op release.

Do not introduce a second raw backend-release call path.

## Primary error policy

Preserve all current primary error rules:

- native start error remains primary over release failure;
- state-read error remains primary over release failure;
- callback/monitor terminal error remains primary over later release failure;
- if execution otherwise succeeds and terminal release fails, the release error remains visible to that execution promise;
- background/fallback cleanup success does not retroactively change the already-settled public Promise.

The retry coordinator exists to finish ownership cleanup, not to rewrite past Promise results.

## Goal 2 deterministic tests

Primary file:

- `react-native/tests/wasm-session-ownership.test.js`

Secondary lifetime-specific coverage can be added if needed without creating a broad new harness.

### Test A — rejected start reopens Created cleanup authority

- state starts `Created`;
- inject exact `startError`;
- execute session and assert exact rejection;
- clear start error;
- call `session.cancel()`;
- assert Created abandonment occurs;
- assert no Running native cancellation occurs;
- assert repeated cancellation is idempotent only after full cleanup commit.

This proves rejected invocation is not permanently classified as startup-in-flight.

### Test B — start error remains primary while release retry commits automatically

- state `Created`;
- inject `startError`;
- inject first release failure;
- execute and assert the exact start error is reported;
- assert retained registry entry remains after failed first release;
- clear release failure;
- wait on the retry coordinator's deterministic test seam / bounded completion;
- assert second release attempt commits;
- assert retry bookkeeping returns to zero;
- do not call `getBackend().releaseSessionHandle()` manually.

### Test C — terminal release failure gets fallback without history reconstruction

- execute session normally;
- transition to terminal;
- fail first retained release;
- assert execution reports release error according to existing policy;
- do **not** call `FFmpegKitExtended.getSession`, history list APIs, or `observeRestoredRunning`;
- clear release failure;
- assert fallback release commits;
- assert no retained entry/retry entry remains.

This specifically proves the ordinary execution path no longer depends on a pre-existing restored observer.

### Test D — state-read primary error survives release retry

- start execution;
- after native start, inject state read failure;
- fail first release;
- assert execution rejects with exact state-read error;
- recover release;
- assert fallback commits exactly one release;
- assert state error was not replaced.

### Test E — partial pre-execution cleanup retries only missing half

Case 1:

- abandonment succeeds;
- retained release fails;
- later cleanup retry must not repeat successful abandonment;
- release retries and commits.

Case 2:

- abandonment fails;
- retained release succeeds;
- later retry must not repeat release;
- abandonment retries and commits.

Assert final cleanup commit only after both parts are complete.

### Test F — release fallback deduplicates concurrent requests

- register fallback twice for same ID while release is failing/deferred;
- assert one in-flight backend release at a time;
- recover release;
- assert one final commit and zero retry entries.

### Test G — restored fallback coexistence remains safe

If feasible with current observer fixtures:

- have restored observer and execution-owner fallback both target same ID;
- prove serialized release produces one native commit;
- both authorities retire bookkeeping.

Do not add timing-only sleeps as the sole proof. Use existing deferred gates/counters or an internal wait seam.

## Goal 2 documentation

Update React Native lifecycle documentation to state:

- pre-execution cleanup is complete only after both abandonment and retained ownership retirement are committed;
- release failures remain retryable internally until ownership retires;
- a start invocation that rejects is not treated forever as an in-flight startup;
- startup-in-flight Created remains protected after a successfully accepted native start;
- primary execution/callback errors remain stable even when cleanup must continue afterward.

Avoid documenting internal retry-loop names.

---

# Goal 3 — make queue-only cancellation mutation truly private

## Problem to solve

Review 49 changed `markCancelledBeforeExecution()` from public to `protected` and added a packed TypeScript negative direct-call test.

That does not create a real private boundary:

- exported concrete Session classes can be subclassed by consumers;
- a subclass can call a protected member;
- TypeScript access modifiers are erased from emitted JavaScript;
- plain JavaScript can still call the normal method property by name.

The method performs only local mutation and intentionally does not establish durable ID cancellation/abandonment authority. It must not remain a callable runtime surface.

## Required API invariant

> No consumer-accessible property/method may perform only the queue-local pre-execution cancellation mutation.

The queue may still receive a closure that performs that mutation, but the mutation itself must be inaccessible outside the Session implementation.

## Preferred implementation

Use an ECMAScript private method in the base class:

```ts
#markCancelledBeforeExecution(): void {
  this.cancelled = true;
}
```

Because the four concrete subclasses currently wire `SessionQueueManager.executeSession()` themselves, add one base helper that supplies the private queue marker.

One acceptable shape:

```ts
protected enqueueSessionExecution<T>(
  executor: () => Promise<T>,
  onDiscard: () => void | Promise<void>
): Promise<T> {
  return SessionQueueManager.shared.executeSession(
    this,
    executor,
    onDiscard,
    () => this.#markCancelledBeforeExecution()
  );
}
```

The concrete session classes then call the base helper instead of passing the marker directly.

If useful, the helper may also own the common `submitOnce()` wrapping, but do not broaden this into a queue redesign merely for deduplication.

## Runtime requirements

After build:

- no ordinary instance/prototype property named `markCancelledBeforeExecution` exists;
- no generated `.d.ts` callable protected method with that name exists;
- subclass code cannot name/invoke it;
- queue cancellation still reaches it only through the closure produced inside the base Session lexical scope.

An equivalent truly private symbol/module closure is acceptable if it meets the same runtime and declaration requirements.

Do **not** use TypeScript `private markCancelledBeforeExecution()` if the emitted JavaScript still exposes an ordinary property by that exact name. Use actual ECMAScript privacy or a module-private design.

## Preserve queue behavior

Queue discard ordering remains:

```text
local queue-cancel mark
-> pre-execution discard cleanup
-> reservation release
-> reject queued execution promise
```

Do not call full `Session.cancel()` from queue discard.

Queued discard must still perform:

- zero native state reads before cleanup;
- zero Running cancellation dispatches;
- no recursion into `cancelQueued()`;
- no executor start.

## Goal 3 regression tests

Primary file:

- `react-native/tests/packed-types-consumer.js`

Preserve existing queue behavior tests in:

- `session-queue-manager.test.js`
- `wasm-session-ownership.test.js`

### Test A — direct packed TypeScript call remains invalid

Keep current direct-call negative fixture.

### Test B — subclass access is invalid

Add a second fixture:

```ts
import {FFmpegSession} from 'ffmpeg-kit-extended';

class ConsumerDerivedSession extends FFmpegSession {
  forceQueueOnlyCancel(): void {
    this.markCancelledBeforeExecution();
  }
}
```

The packed declaration compilation must report the marker as nonexistent/inaccessible for the subclass.

Verify the diagnostic belongs to that expression rather than accepting any unrelated compile error.

### Test C — ordinary runtime property is absent

Preferred when the packed module can be safely loaded in the existing Node consumer harness:

```text
create/import a session object from built package
assert typeof session.markCancelledBeforeExecution === 'undefined'
```

If loading the built runtime requires React Native host initialization that the fixture intentionally lacks, add a focused emitted-module contract check after `npm run prepare`:

- inspect only the emitted session module;
- assert no ordinary named method/property is emitted for the marker;
- accept ECMAScript private syntax/transformation generated by the configured build;
- do not use full-file snapshot equality.

### Test D — all concrete session types still use the internal hook

Retain the existing four-session queued cancellation case:

- FFmpeg;
- FFprobe;
- MediaInformation;
- FFplay.

For each:

- queue behind blocker;
- cancel/clear queued work;
- `isCancelled` is visible on the retained object;
- executor starts zero times;
- Running cancel dispatch zero;
- discard cleanup occurs.

## Goal 3 documentation

Do not mention the queue-only marker in public README/API docs.

Public cancellation surfaces remain:

- `Session.cancel()`;
- `FFmpegKitExtended.cancelSession(id)`;
- `FFmpegKitExtended.cancelAllSessions()`;
- documented queue manager APIs only where they are intentionally public.

Internal comments may state that the queue marker is lexically/private and does not establish durable cancellation authority.

---

# Goal 4 — regression closure, local validation, final audit, exact freeze

## Implementation scope audit before tests

Expected production changes should remain within:

- `react-native/src/session.ts`
- `react-native/src/session-queue-manager.ts`
- `react-native/src/session-lifetime.ts`
- possibly a narrow call in `session-observation.ts` only if needed to share release fallback semantics
- `react-native/README.md`

Expected test changes:

- `react-native/tests/wasm-session-ownership.test.js`
- `react-native/tests/session-queue-manager.test.js`
- `react-native/tests/packed-types-consumer.js`
- possibly restored observer tests for release-fallback coexistence

Any production change in these paths is a stop-and-investigate event unless directly justified by new source evidence:

- `flutter/**`
- `react-native/cpp/**`
- `react-native/windows/**`
- `react-native/android/**`
- `react-native/ios/**`
- `react-native/macos/**`
- `react-native/appletvos/**`
- `libs/libffmpegkit/**`
- native ABI/configuration
- builders checkout

## Focused static/test gates

From `react-native/`, use only repository-supported commands and record exact results.

Start with:

```text
npm run typecheck
npm run test:compile
npm run lint
node --test tests/session-queue-manager.test.js
node --test tests/wasm-session-ownership.test.js
node --test tests/restored-session-observer.test.js
node --test tests/wasm-backend-memory.test.js
```

After `npm run prepare`, run:

```text
npm run test:pack-types
```

Then run the complete local Node suite and record exact pass/fail/skip counts.

Run the smallest established local Web/Wasm smoke required for shared TypeScript lifecycle changes. Do not launch an interactive browser UI.

## Mandatory regression preservation matrix

### Queue / execution

Verify:

- duplicate object admission rejects;
- duplicate native-session-ID admission rejects;
- reservation release occurs on every exit;
- queue progression survives sync and async executor failure;
- initial and handoff state probe failures remain non-destructive;
- queued cancellation removes exact managed work;
- secondary-wrapper cancellation delegates to managed queued work;
- wait/active accounting remains correct;
- no queue cancellation starts native execution.

### Cancellation

Verify:

- direct never-started Created cancellation;
- consumed-but-never-started same-object cancellation;
- secondary-wrapper queued cancellation;
- secondary-wrapper active-startup cancellation;
- durable cancellation intent;
- failed state read keeps intent;
- Running native cancellation retry;
- submitted-startup Created protection;
- completion-wins race;
- all active targets attempted;
- deterministic target-order first error;
- deterministic cancel-all branch order;
- ID `0` queue-aware cancel-all.

### Cleanup / release

Verify:

- pre-execution abandonment and release commit independently;
- failed abandonment remains retryable;
- failed release remains retryable;
- start-error cleanup preserves start error and retries release;
- state-read cleanup preserves state error and retries release;
- terminal release failure retains automatic fallback;
- fallback bookkeeping is bounded and deduplicated;
- successful release removes fallback entry;
- restored observer fallback and execution-owner fallback serialize rather than double-release.

### Restored/history lifecycle

Verify:

- one ID-level observer per restored Running ID;
- callback targets remain bounded;
- callback setup remains serialized with terminal/clear;
- active execution owner retains final callback-drain priority;
- clear invalidates restored observation only after backend clear succeeds;
- callback rollback cannot recreate a cleared observer;
- configuration clear and lifecycle clear remain equivalent;
- secondary Created history wrapper cannot abandon a managed active startup.

### Web ownership

Verify:

- history state-probe failure releases temporary pointer exactly once;
- retained/temporary handle ownership remains failure-atomic;
- abandoned Created identity remains fail-closed;
- cancellation intent blocks reconstructed Created execution;
- failed retained release remains available to the shared retry coordinator.

### Public API

Verify:

- direct queue marker call is absent from packed types;
- subclass queue marker call is absent from packed types;
- ordinary emitted JS runtime surface has no callable marker property;
- supported Session constructors/methods remain unchanged unless intentionally documented.

## Platform validation order

The expected implementation remains React Native TypeScript-only.

Use the established ordered local matrix.

### 1. Windows first

- static/focused/full RN gates;
- packed type/Web consumer gates as applicable;
- established local RN Windows build using the configured local Windows ABI ZIP;
- do not retrieve any remote native artifact.

### 2. Android on local Windows

- run the existing local Android build using the configured local AAR;
- do not repeat Android under WSL merely for duplication.

### 3. Linux/WSL where affected

- run shared TypeScript/Node/Web/package gates required by this wrapper change;
- do not modify the ManyLinux builders checkout;
- do not fetch a Linux ABI remotely.

### 4. Apple last

Use the authorized MacBook Air SSH host and the existing local universal XCFramework archives.

Run:

- RN typecheck/lint/test gates required by current tracker practice;
- established noninteractive iOS build;
- established noninteractive tvOS simulator build;
- established noninteractive macOS build.

Apply the already-established UTF-8 locale/PATH corrections if the noninteractive SSH environment needs them. Record an environment-first failure truthfully before retrying.

Do not launch apps or simulators interactively.

## Flutter validation policy

Review 50 verified byte-for-byte no drift in Flutter production and platform-native paths.

If G1-G3 remain React Native-only:

- perform a bounded source no-drift check for Flutter and platform-native directories;
- preserve accepted prior Flutter validation evidence;
- do not rerun the complete Flutter platform matrix merely for ceremony.

If implementation unexpectedly needs Flutter production changes, stop and record the concrete new Flutter defect before proceeding.

## Semantic identifier audit

Search changed production/tests for:

- `Review50`
- `Review 50`
- `R50`
- finding IDs
- goal IDs

No such identifier belongs in production symbols, tests, comments, or public docs.

Tracker metadata may use review/goal identifiers.

## Final substantive audit checklist

Before declaring closure, answer every item from final frozen source, not from intent:

1. Can a secondary wrapper for a queued ID cancel the actual queued owner immediately?
2. Can a secondary wrapper for an active startup ever call Created abandonment?
3. Does secondary-wrapper cancellation propagate the canonical owner's exact failure?
4. Does a successfully invoked startup that still reports Created remain protected from abandonment?
5. Does a rejected start invocation stop being treated as permanently startup-in-flight?
6. Can start-failure release fail once and later retire automatically without direct backend calls?
7. Can state-read cleanup release fail once and later retire automatically while preserving the state error?
8. Can terminal release fail once and later retire automatically without any history read/restored observer?
9. Is pre-execution cleanup considered complete only after both abandonment and retained release commit?
10. Can an abandonment tombstone prevent a needed retained-release retry from being reached?
11. Is release fallback bounded to one task/ID and serialized through `releaseSessionHandleSerialized()`?
12. Can a TypeScript consumer directly call the queue-only marker?
13. Can a consumer subclass call the queue-only marker?
14. Can plain emitted JavaScript call a normal marker property?
15. Does queued discard still mark local cancellation before cleanup with zero native Running dispatch?
16. Are Review 44–49 clear, observation, callback, cancellation, and Web ownership regressions preserved?
17. Are Flutter and every platform-native production directory unchanged?
18. Is `libs/libffmpegkit` exactly the frozen SHA?
19. Is the ManyLinux builders checkout unchanged?
20. Was no native ABI downloaded, rebuilt, or published?
21. Were no hosted Flutter/RN acceptance workflows run?

If any answer is wrong or uncertain from source/evidence, do not claim closeout.

## Exact source freeze and wrapper-only snapshot

Only after all focused/local validation passes and the final audit has zero substantive findings:

1. commit and push the final wrapper changes to `dev-wasm`;
2. record the exact full 40-character source SHA;
3. verify the working tree and intended remote ref represent that source authority;
4. dispatch only the repository source-snapshot workflow against that exact SHA;
5. download the wrapper-only artifact through the GitHub connector;
6. verify:
   - GitHub artifact digest;
   - `source.tar.gz.sha256`;
   - actual embedded archive SHA-256;
   - every `SHA256SUMS` entry;
   - `SUBMODULES.txt`;
   - `SYMLINKS.tsv`;
   - `snapshot-metadata.json.snapshot_sha`;
   - `runtimeExecution=false`;
   - frozen `libs/libffmpegkit` SHA;
7. record workflow run ID, artifact ID/name/link, outer digest, embedded archive digest, manifest count, symlink count, runtime flag, and submodule SHA in the tracker.

Do not create a native/builders snapshot.

Tracker-only provenance commits after the frozen wrapper snapshot must be identified as metadata-only and must not replace the frozen implementation SHA as source authority.

---

# Definition of done

Review 50 remediation is complete only when all of the following are true:

- [ ] cancellation from a secondary wrapper delegates to a different queued/active owner for the same native ID;
- [ ] secondary-wrapper cancellation cannot abandon an active startup that still reports Created;
- [ ] secondary-wrapper queued cancellation removes the real queue item immediately;
- [ ] canonical cancellation failures remain exact and retryable;
- [ ] same-object pre-start cancellation from Review 49 remains correct;
- [ ] successful native-start invocation protects startup-in-flight Created state;
- [ ] rejected native-start invocation no longer permanently blocks safe later Created cleanup;
- [ ] pre-execution cleanup commits only after abandonment and retained release have both committed/no-op committed;
- [ ] partial pre-execution cleanup retries only the missing part;
- [ ] start-error release failure receives an automatic retry owner;
- [ ] state-read release failure receives an automatic retry owner;
- [ ] terminal release failure receives an automatic retry owner even without a restored observer;
- [ ] release retry is one-per-ID, iterative, serialized, and bounded in bookkeeping;
- [ ] restored observer and execution-owner release fallback do not double-release;
- [ ] primary error ordering is unchanged;
- [ ] queue-only local cancellation marker is not directly consumer-callable in packed TypeScript;
- [ ] queue-only local cancellation marker is not subclass-callable in packed TypeScript;
- [ ] queue-only local cancellation marker is not an ordinary callable emitted-JavaScript property;
- [ ] queue discard still performs mark-before-cleanup with zero native Running cancellation;
- [ ] deterministic Review 49 multi-target error ordering remains green;
- [ ] prior Review 44–49 cancellation/observer/clear/release/Web ownership regressions remain green;
- [ ] React Native typecheck/test compile/lint/focused/full local tests are recorded truthfully;
- [ ] required local Windows → Android-on-Windows → Linux/WSL → Apple validation is complete using local ABI `0.11.2` artifacts only;
- [ ] Flutter and platform-native no-drift checks are clean;
- [ ] `libs/libffmpegkit` remains exactly `b74da2c5d1e294b87d15d73a6687393729e932b3`;
- [ ] ManyLinux builders remain unchanged;
- [ ] no hosted Flutter/RN acceptance workflow ran;
- [ ] no native ABI was downloaded, published, or rebuilt;
- [ ] final bounded audit has zero substantive findings;
- [ ] exact final wrapper SHA is frozen and pushed;
- [ ] one wrapper-only source snapshot at that exact SHA is downloaded and fully verified.

If every item is satisfied, the next review should produce a cross-platform closeout summary rather than another remediation plan.
