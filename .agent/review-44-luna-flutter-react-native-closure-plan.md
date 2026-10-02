# Review 44 — Luna Flutter + React Native Closure Plan

**Project:** FFmpegKitExtended  
**Audience:** Luna implementation/review model  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch:** `dev-wasm`  
**Starting source authority:** `d8320a5fd3cd4031d9c9b9a0edf71539231c5380`  
**Review basis:** `review-44-flutter-react-native-code-review.md`  
**Native ABI/runtime:** frozen `0.11.2`  
**Frozen native submodule:** `b74da2c5d1e294b87d15d73a6687393729e932b3`

---

# 1. Goal tracker

| Goal | Objective | Primary implementation | Required tests | Documentation | Status |
| --- | --- | --- | --- | --- | --- |
| **R44-G1** | Make public React Native ID cancellation queue-aware and durable | Route `FFmpegKitExtended.cancelSession(id)` through session/queue authority; define ID `0` as cancel-all consistently | queued-by-ID, active-by-ID, ID 0, unknown ID | TSDoc + README cancellation semantics | ☐ |
| **R44-G2** | Preserve submitted-Created startup sessions during cancellation | Abandon Created only when truly pre-submission; keep intent during native handoff | pre-submit, queued, submitted-Created→Running, terminal-before-Running, native/Web history | lifecycle comment + tests | ☐ |
| **R44-G3** | Give restored Running history ownership one terminal releaser per native session ID | Add deduplicated observer/lifetime authority shared by reconstructed wrappers and execution release | restore/release, duplicate wrappers, original monitor coexistence, clear | lifecycle ownership comments | ☐ |
| **R44-G4** | Make restored Running callbacks real observer callbacks | Attach callback demand to restored Running observer without execution ownership | completion/log/statistics, sink removal, rollback, at-most-once | README restored-session callback contract | ☐ |
| **R44-G5** | Make Web history pointer lookup failure-atomic | Release newly obtained temporary pointer on pre-transfer state-probe error | throwing state probe, exactly-once release, primary error preservation | internal ownership-transfer comment | ☐ |
| **R44-G6** | Re-audit Flutter/RN wrapper closure, run affected local gates, freeze exact source snapshot if clean | No unrelated refactor; wrapper-only closure | focused + affected local tests/builds; no hosted acceptance CI | tracker/provenance | ☐ |

---

# 2. Mission

Review 44 has two distinct conclusions that Luna must preserve:

```text
platform-native bridge: closed
Flutter wrapper in reviewed lifecycle surfaces: clean
React Native wrapper: five substantive gaps remain
```

The implementation task is therefore **React Native wrapper remediation**, not another native ABI or broad platform-native rewrite.

The goals are:

```text
1. Make every public cancellation entrypoint use one durable queue-aware transaction.
2. Stop confusing a submitted startup session with a never-submitted Created identity.
3. Give Running history reconstruction a lifecycle owner that can retire promoted native/Web handles.
4. Make callbacks attached to restored Running wrappers actually observe the live execution.
5. Close one Web/Wasm exceptional handle leak.
6. Re-audit and freeze only after deterministic tests prove the corrected boundaries.
```

---

# 3. Non-negotiable constraints

Luna must treat all of these as mandatory:

1. Work in `akashskypatel/ffmpeg-kit-extended`, branch `dev-wasm`.
2. Reconcile against exact starting wrapper source `d8320a5fd3cd4031d9c9b9a0edf71539231c5380`.
3. Keep native ABI/runtime pinned to **0.11.2**.
4. Keep `libs/libffmpegkit` frozen at `b74da2c5d1e294b87d15d73a6687393729e932b3`.
5. Do not download or re-review native ABI source/artifacts.
6. Do not edit/rebuild `libs/libffmpegkit`.
7. Do not edit/rebuild the ManyLinux builders checkout.
8. Do not add or change native ABI exported symbols.
9. Do not publish native ABI artifacts.
10. Do not fetch a remotely built old native bundle for local tests.
11. Use only the existing locally configured/package native ABI `0.11.2` artifacts.
12. Do not run hosted Flutter/React Native test/build workflows as acceptance evidence.
13. The only hosted workflow allowed at final closeout is the exact wrapper source-snapshot workflow.
14. Do not automatically launch interactive Flutter/RN apps, simulators, or devices.
15. Interactive validation remains user-owned at the end of remediation.
16. Do not change Flutter production code unless a new concrete Flutter defect is proven while implementing these fixes.
17. Do not reopen platform-native bridge code merely for symmetry/cleanup.
18. Production/test identifiers must be semantic; never use `R44`, `G1`, `F1`, review names, or tracker language in implementation symbols.
19. Never fabricate tests or test results.
20. Do not weaken existing tests.
21. Record failed commands, retries, skipped gates, and environment corrections truthfully.
22. Exclude pedantic/style/procedural findings from the final audit.
23. New findings require a reachable path and concrete product consequence.
24. Make surgical changes only; no unrelated TypeScript architecture cleanup.

---

# 4. Frozen source provenance to preserve

Review 44 authority comes from Review 43 closeout:

```text
wrapper SHA:
  d8320a5fd3cd4031d9c9b9a0edf71539231c5380

workflow run:
  36961755649

artifact:
  review43-source-snapshot-36961755649

artifact ID:
  11207808848

artifact SHA-256:
  87de8776fe42c1740f390dda65f1cfcb43d1c1a2d167906b2ac98b4029beaae5

source.tar.gz SHA-256:
  69dab1a34958bd8948b2d5a6b472069b971989ae66c9fca29756a35992dd010b

SHA256SUMS:
  1093/1093 verified

SYMLINKS.tsv:
  0 entries

runtimeExecution:
  false

submodule:
  b74da2c5d1e294b87d15d73a6687393729e932b3 libs/libffmpegkit
```

Do not substitute a later tracker-only metadata commit for this source authority unless the tracker explicitly records a new implementation SHA.

---

# 5. Starting behavior that must be preserved

## 5.1 Platform-native bridge

Do not regress or redesign these accepted invariants:

```text
Flutter iOS/macOS:
  registerTexture failure sentinel 0 rejected before owner publication

Flutter Windows:
  asynchronous external-texture retirement owns callback-captured state
  latest-owner FFplay semantics
  packed-frame normalization

Flutter Linux:
  FlPixelBufferTexture engine lifecycle
  queued idle GObject references
  frame coalescing and pixel-buffer lifetime

Flutter Android:
  Surface/SurfaceTexture/ANativeWindow exact ownership
  stale owner cannot clear newer target

React Native shared C++:
  one composable top-level operation token
  clear blocks new admission and waits existing operations
  retained handle lease/release barriers
  non-throwing cleanup authority

React Native Windows/Android/Apple:
  invocation-bound action failures
  synchronous diagnostic boundary
  process-global FFplay latest owner
  callback unregister/drain and weak UI/view ownership
```

## 5.2 Flutter wrapper

Preserve the Flutter lifecycle semantics that already avoid R44-F1/R44-F2/R44-F4:

```text
cancelSession(0) -> cancelAllSessions
cancelSession(nonzero) -> resolve Session -> Session.cancel
submitted Created startup != pre-submission abandonment
cancellation intent survives startup state transition
restored observer routing verifies Running state
restored terminal observation is separate from execution queue ownership
```

No Flutter production change is expected.

---

# 6. R44-G1 — queue-aware public ID cancellation

## 6.1 Problem to fix

Current code in `react-native/src/ffmpeg-kit-extended.ts`:

```ts
static async cancelSession(sessionId: number): Promise<void> {
  this.requireInitialized();
  await NativeFFmpegKitExtended.cancelSession(sessionId);
}
```

This bypasses:

```text
Session.cancelled
recordCancellationIntent
SessionQueueManager.cancelQueued
queued execution promise rejection
pre-execution discard cleanup
active Session cancellation de-duplication
```

## 6.2 Recommended implementation shape

Do **not** put queue internals directly into `FFmpegKitExtended`.

Add a semantic lookup/cancel seam to `SessionQueueManager`, for example:

```ts
findManagedSessionById(sessionId: number): CancellableSession | undefined
cancelBySessionId(sessionId: number): MaybePromise<boolean>
```

The exact name can differ, but behavior must be:

```text
search queued + active managed sessions by getSessionId()
if found, call the actual Session.cancel()
return whether a managed target was found
```

Important: do not implement ID cancellation by merely removing the queue item yourself. Calling `Session.cancel()` is what records durable intent and preserves one cancellation transaction for queued/active/startup states.

Then implement `FFmpegKitExtended.cancelSession(sessionId)` as:

```text
require initialized

if sessionId == 0:
  await SessionQueueManager.shared.cancelAll()
  return

if manager has a managed session with this ID:
  await session.cancel()
  return

const restored = FFmpegKitExtended.getSession(sessionId)
if restored exists:
  await restored.cancel()
  return

otherwise:
  follow the chosen documented unknown-ID behavior
```

### Avoid recursion

If `FFmpegKitExtended.getSession()` is used inside `cancelSession`, ensure it does not itself route back into cancellation. There is no current recursion, but keep the boundary obvious.

### Unknown ID

Prefer compatibility with current backend cancellation semantics: unknown IDs should normally be a no-op unless the existing API contract explicitly documents an error. Test the chosen behavior.

## 6.3 ID 0 contract

Review 44 recommends aligning the high-level RN API with Flutter and the native cancel-all convention:

```text
cancelSession(0) == cancelAllSessions()
```

This is useful because it includes queued JS work. A raw backend `cancelSession(0)` cannot clear JavaScript queue entries.

## 6.4 Tests

Add a focused source/behavior regression in the existing React Native test architecture. Prefer behavior tests over string-only checks.

### Queued target

Setup:

```text
maxConcurrentSessions = 1
hold one blocker active
create FFmpeg session A
submit A so it is queued
call FFmpegKitExtended.cancelSession(A.id)
```

Assert:

```text
A execution promise rejects SessionCancelledException
A native executor start count == 0
A removed from queue
session-ID reservation released
native cancel was not needed for queued A
```

### Active target

Assert:

```text
managed active Session object is found
Session.cancel() records intent
native cancellation dispatch occurs once when Running
repeated static cancel does not duplicate a successful native dispatch
```

### ID 0

Have one active + one queued target and assert:

```text
queued target discarded
active target receives cancellation
all attempts are made even if one active target fails
first error remains authoritative after all attempts
```

### Unknown ID

Assert the documented no-op/error behavior explicitly.

## 6.5 Documentation

Update TSDoc for `FFmpegKitExtended.cancelSession` and the RN README session-management section.

Recommended semantic wording:

```text
Cancellation by ID participates in the same process-wide SessionQueueManager
transaction as object cancellation. ID 0 cancels all queued and active managed
sessions. A queued target is removed before native execution begins.
```

Do not mention Review 44.

---

# 7. R44-G2 — distinguish pre-submission Created from submitted-Created startup

## 7.1 Problem to fix

Current `Session.cancel()` abandons whenever state is `Created`:

```ts
const state = this.getState();
if (state === SessionState.Created) {
  await this.abandonCreatedSession();
  return;
}
```

But `submitted` is already available and `submitOnce()` sets it before enqueue/handoff.

## 7.2 Minimal implementation

Change the abandonment predicate to require true pre-submission state:

```ts
if (state === SessionState.Created && !this.submitted) {
  await this.abandonCreatedSession();
  return;
}
```

Then explicitly handle submitted-Created:

```text
cancelled/intention already latched
session is not queued anymore
state is still Created during native startup
DO NOT abandon history
DO NOT invoke cancelSession yet unless the backend contract supports Created cancellation
return and let monitor dispatch when Running is observed
```

The existing `monitor()` already checks durable cancellation intent while polling state. Preserve that mechanism.

## 7.3 Do not break queued cancellation

Order remains:

```text
1. record intent
2. cancelQueued(this)
3. only then inspect native state
```

A queued object must still use `discardBeforeExecution()` and reject its execution promise.

## 7.4 Terminal-before-Running race

Existing source has a case where terminal completion wins before Running is observed. Required behavior:

```text
no native cancellation dispatch
do not abandon history
terminal monitor path clears durable cancellation intent
release retained handle normally
terminal history remains visible
execution promise follows terminal result
```

## 7.5 Native and Web history assertions

Tests must prove more than `registry.has(pointer)`.

For submitted-Created cancellation, assert after terminal:

```text
backend.isSessionAbandoned(id) == false
getSessionJson(id) remains visible if history capacity permits
getSessionsJson(kind) includes the terminal identity
Web SessionHistoryRegistry still owns the record and marks it terminal
```

For true pre-submission cancellation, retain existing fail-closed abandonment behavior.

## 7.6 Existing tests to strengthen

Extend the current cases whose comments already describe the handoff window:

```text
"deferred native cancellation..."
"completion before Running observation wins without late cancellation"
```

Add assertions that `abandonCreatedSession` was not called and history/tombstone state remains correct.

## 7.7 Documentation/comments

Add one semantic comment around the submitted-Created branch, equivalent in meaning to Flutter's existing comment:

```text
A submitted session can remain Created while native execution is handing off.
Keep cancellation intent durable and wait for Running instead of treating the
identity as an abandoned never-executed session.
```

No public API documentation change is required beyond cancellation semantics unless current README text claims every Created cancellation is abandonment.

---

# 8. R44-G3 — restored Running lifetime authority

## 8.1 Root ownership problem

Native and Web history reads intentionally promote Running handles into retained storage. This avoids releasing/cancelling a Running native identity during observation.

The missing piece is a guaranteed terminal releaser when a Running session is reconstructed without its original JS execution monitor.

Do **not** remove Running promotion. That would reintroduce the earlier history-ownership defect.

## 8.2 Recommended architecture

Introduce a semantic per-session coordinator in React Native TypeScript, conceptually:

```text
RestoredRunningSessionObserver
or
SessionObservationCoordinator
```

Do not name it after Review 44.

It should have one process-wide entry per native session ID:

```ts
type ObservationEntry = {
  sessionId: number;
  // one state-poll lifecycle per ID
  terminalPromise: Promise<void>;
  // wrapper observers/sinks can join this lifecycle
};
```

The exact structure may be simpler, but the properties must hold:

```text
one terminal poll lifecycle per ID
one in-flight retained-handle release per ID
multiple reconstructed wrappers can join
no executeSessionAsync call
no queue reservation
no cancellation unless caller explicitly requests it
```

## 8.3 Canonical history reconstruction

`sessionFromSnapshot(snapshot)` must become the single semantic restoration path.

After constructing the typed wrapper, preserve/observe the snapshot state. If snapshot state is Running, register that wrapper/ID with the restored-running coordinator.

The narrower helpers currently bypass this path:

```text
FFmpegKit.getLastFFmpegSession/getFFmpegSessions
FFprobeKit.getLastFFprobeSession/getFFprobeSessions
FFplayKit.getFFplaySessions
```

Refactor them surgically to delegate to `FFmpegKitExtended` typed history methods or another canonical parser. Do not maintain a second `{sessionId, command}` reconstruction path that discards lifecycle state.

## 8.4 Terminal observer behavior

For a restored Running ID:

```text
poll getSessionState(id) using existing interval policy
if Running:
  continue
if Completed/Failed:
  run terminal observer settlement
  retire callback demand (R44-G4)
  clear cancellation intent
  release retained handle through a shared release authority
  stop observer
if successful clear invalidates history:
  stop observer without trying to resurrect/re-read cleared session
```

### Created state

A wrapper reconstructed as Created is not a restored-running observer. It can retain the existing single-use execution rules.

### State-read failure

Do **not** release/cancel a possibly Running session merely because one observer state read failed.

Recommended behavior:

```text
preserve native ownership
surface/log observer failure through the available promise boundary
allow a later observer/retry to re-establish monitoring
```

If implementing retries, use the existing polling cadence or a small bounded backoff. Do not create an aggressive busy loop.

## 8.5 Shared terminal-release authority

Current `Session.handleReleased` is instance-local. Two wrappers for one native ID can therefore call `releaseSessionHandle(id)` concurrently.

Add an ID-level in-flight release authority, for example:

```ts
const sessionReleaseInFlight = new Map<number, Promise<void>>();
```

Required semantics:

```text
first caller creates release promise
concurrent callers await the same promise
on successful completion, later release calls may use existing backend idempotence
on failure, remove in-flight entry so a retry is possible
never permanently cache a failed release
```

Normal execution monitors and restored observers must both use this shared release seam.

Do not change the frozen native ABI.

## 8.6 Clear integration

After `FFmpegKitExtended.clearSessions()` successfully commits backend clear, notify/invalidate restored-running observer entries so they stop polling identities that global clear removed.

Do not invalidate observers before backend clear succeeds; that would make clear failure lose lifecycle authority.

## 8.7 Tests

Add deterministic tests with fake backend scalar states.

### Restored Running without original executor

```text
history snapshot state = Running
construct wrapper through public history API
assert executeSessionAsync was never called
advance scalar state to Completed
assert releaseSessionHandle(id) called exactly once
assert observer stops
```

### Duplicate restored wrappers

```text
create two history wrappers for same Running ID
assert one per-ID terminal poll authority or equivalent deduped behavior
terminal -> one retained release transaction
```

### Original monitor + restored wrapper

Start a normal execution monitor, also reconstruct same Running ID from history, then settle:

```text
both observers can see terminal
backend release transaction occurs once/in-flight-deduped
no "release already in progress" user-visible error
```

### Clear

```text
start restored-running observer
successful clear -> observer stops, no stale polling/release
failed clear -> observer remains authoritative/retryable
```

## 8.8 Documentation

README should state:

```text
A Running session returned from history is a control/observation wrapper around
an existing execution. It is not re-executed. The wrapper observes terminal
state so retained native ownership can be retired when execution finishes.
```

---

# 9. R44-G4 — restored Running callbacks

## 9.1 Root problem

`refreshCallbackDemand()` currently does nothing unless `runWithCallbackDemand()` has activated execution-owned providers.

A restored Running wrapper never entered that execution scope.

## 9.2 Do not fake this by setting callbackDemandActive=true globally

That would mix execution ownership and observer ownership and risks keeping process-global callback bridges installed after no observer needs them.

Instead, extend the callback-demand design with an explicit restored-observer scope.

## 9.3 Required callback behavior

### Completion

When a completion callback is attached to a restored Running session:

```text
join/start the per-ID terminal observer from G3
completion callback remains attached until terminal or explicit removal
invoke it at most once after terminal state/final reconciliation
```

### Log

When a log callback is attached:

```text
verify the session is currently Running
acquire the global log bridge lease
subscribe to direct log events using existing sequence ordering
use indexed history only for bounded gap/terminal reconciliation
release log lease when the sink is removed or observer terminates
```

### Statistics

For FFmpeg statistics callbacks:

```text
verify Running
acquire statistics demand if required by backend design
re-use existing indexed/statistics polling logic
release demand on sink removal/terminal
```

## 9.4 Setter failure atomicity

For restored wrappers, setter order must be transactional:

```text
remember previous callback
install/verify observer routing
if state read or bridge install fails:
  restore previous callback
  release any newly acquired lease
  rethrow
only then report success
```

A setter must not leave a callback stored after proving it cannot establish live routing.

## 9.5 Remove operations

Removing an optional callback must update observer demand immediately:

```text
last log sink removed -> log lease released
last statistics sink removed -> statistics lease released
completion removal -> no completion callback, but G3 lifetime observer may still need to run solely to retire the retained handle
```

Do not stop the G3 lifetime observer merely because there are no user callbacks.

## 9.6 Session types

Apply the semantics only where public callbacks exist:

```text
FFmpeg: completion + log + statistics
FFprobe: completion + log
FFplay: completion + log/statistics according to current public surface
MediaInformation: current public completion/log callback surface only
```

Inspect the actual class APIs; do not invent new callback types.

## 9.7 Tests

Use the existing callback-demand fake hooks rather than adding a platform app fixture.

Required cases:

```text
Running restored FFmpeg completion callback fires once
Running restored FFmpeg log callback receives direct event sequence
Running restored FFmpeg statistics callback receives expected updates
restored FFprobe/FFplay/media callback surface behaves consistently
state-read failure rejects setter and rolls callback back
bridge-install failure rejects setter and releases partial demand
two restored wrappers share global callback lease refcounts correctly
removing final sink releases optional bridge demand
terminal settlement releases all observer demand
no executeSessionAsync occurs
no queue reservation occurs
```

## 9.8 Documentation

Update the README callback section to distinguish:

```text
execution callbacks: owned by the wrapper that submits work
restored observer callbacks: attached to an already-Running history session
```

Both may use the same process-global native callback bridge, but lifecycle ownership differs.

---

# 10. R44-G5 — Web history pointer failure atomicity

## 10.1 Target file

```text
react-native/src/platform/backend.web.ts
```

## 10.2 Current unsafe sequence

```text
pointer = ffmpeg_kit_get_session(id)
state = ffmpeg_kit_session_get_state(pointer)   <-- may throw
if Running -> retain pointer
else -> return temporary pointer descriptor
```

A throw before descriptor return bypasses the caller's temporary-handle `finally`.

## 10.3 Surgical implementation

Use a local transfer flag:

```ts
const pointer = ...;
if (!pointer) return undefined;

let transferred = false;
try {
  const state = ...;
  if (state === SessionState.Running) {
    this.sessions.retain(pointer, record.sessionId);
    transferred = true;
    return {pointer, temporary: false};
  }
  transferred = true; // ownership is now represented by returned temporary descriptor
  return {pointer, temporary: true};
} catch (error) {
  if (!transferred) {
    try {
      this.call('ffmpeg_kit_handle_release')(pointer);
    } catch {
      // Preserve the state-probe/transfer failure as primary.
    }
  }
  throw error;
}
```

The exact code can be smaller, but preserve this ownership transaction.

Important distinction:

```text
"transferred" means cleanup authority has moved either to WasmSessionRegistry
or to the caller's temporary descriptor/finally.
```

## 10.4 Tests

Mock:

```text
get_session -> pointer 0x1234
get_state -> throw sentinelStateError
handle_release -> increment release count
```

Assert:

```text
history API throws sentinelStateError
release count == 1
released pointer == 0x1234
WasmSessionRegistry does not contain the pointer
history record is not silently deleted merely because state probing failed
```

Add a second test where cleanup release itself throws; the original state error must remain authoritative.

Preserve existing normal paths:

```text
Running -> retained, not temporary-released
Created/terminal -> returned temporary and caller releases once
missing pointer -> history identity reconciles as absent according to existing behavior
```

## 10.5 Documentation

No public docs are required. Add one local comment only if necessary:

```text
Own the lookup handle locally until cleanup authority transfers to the retained
registry or the caller's temporary-handle finally block.
```

---

# 11. Canonical history reconstruction cleanup required by G3/G4

Do not leave two behaviorally different ways to reconstruct sessions from the same backend JSON.

Current narrower helpers manually parse minimal fields:

```text
FFmpegKit.getLastFFmpegSession/getFFmpegSessions
FFprobeKit.getLastFFprobeSession/getFFprobeSessions
FFplayKit.getFFplaySessions
```

They discard snapshot state and bypass any restored-session lifecycle hook added to `sessionFromSnapshot()`.

Refactor only these duplicated history wrappers so they call the canonical `FFmpegKitExtended` typed history API or the canonical parser.

This is not general deduplication; it is required to make the G3/G4 lifecycle fix apply to every public history entrypoint.

Test both API families return wrappers with equivalent restored Running behavior.

---

# 12. Shared release authority implementation detail

Because G3 adds another legitimate terminal observer, instance-local `handleReleased` is no longer enough to prevent two wrappers from issuing overlapping `releaseSessionHandle(id)` calls.

A minimal shared helper can live in `session.ts` or a small semantic module:

```ts
const releasesInFlight = new Map<number, Promise<void>>();

async function releaseSessionHandleSerialized(sessionId: number): Promise<void> {
  const existing = releasesInFlight.get(sessionId);
  if (existing) return existing;

  const release = Promise.resolve(
    NativeFFmpegKitExtended.releaseSessionHandle(sessionId),
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

Adjust for `ActionCompletion` sync/async types as necessary.

All Session instances should continue to keep their local `handleReleased` fast path, but actual backend release should pass through the per-ID in-flight serialization seam.

Required properties:

```text
concurrent release joins one call
successful completed call can be followed by backend-idempotent no-op from a much later stale wrapper
failed release is retryable
no permanent memory growth from completed release promises
```

If the existing backend guarantees make a different minimal design cleaner, use that design and prove the same properties with tests.

---

# 13. Cancellation monitor interaction

After G2/G3, there are three conceptually different authorities. Keep them separate:

```text
queue ownership
  whether JS work has been admitted to native execution

cancellation intent
  durable request keyed by native session ID

restored observer lifetime
  non-executing state observer used to retire promoted history ownership and callbacks
```

Do not use abandonment as a synonym for cancellation.

Do not let a restored observer call `executeSessionAsync`.

Do not let callback registration itself set cancellation intent.

Do not let successful cancellation dispatch erase intent until terminal state remains authoritative under the existing design.

---

# 14. React Native native/Web parity requirements

The remediation must maintain equivalent public behavior on native and Web even when internal handle mechanics differ.

| Behavior | Native backend | Web backend |
| --- | --- | --- |
| queued ID cancellation | JS queue prevents execution | JS queue prevents execution |
| submitted-Created cancellation | durable intent; no abandonment | durable intent; no abandonment |
| Running history ownership | retained C++ entry | retained WasmSessionRegistry pointer |
| restored terminal retirement | `releaseSessionHandle` after terminal | `releaseSessionHandle` after terminal |
| history visibility | no abandonment tombstone | no abandonment tombstone |
| restored callbacks | shared TS observer demand | shared TS observer demand |
| exceptional temporary cleanup | RAII/shared C++ guards | explicit failure-atomic release |

Do not force the Web backend to mimic C++ data structures; match semantics.

---

# 15. Flutter no-regression matrix

No Flutter production change is expected. The final source audit should confirm these remain unchanged:

| Surface | Invariant |
| --- | --- |
| ID cancellation | ID 0 -> cancel-all; nonzero -> Session.cancel |
| startup cancellation | submitted Created keeps intent; not abandoned |
| restored callback routing | verifies Running before routing |
| terminal restoration | completion observation commits terminal history and clears intent |
| queue | one native-ID reservation per queued/active execution |
| platform bridges | Review 43 native closure remains intact |

If implementation touches shared cross-package scripts/configuration, expand validation accordingly. Otherwise do not edit Flutter for symmetry.

---

# 16. Focused test implementation guidance

Prefer extending existing tests over introducing a new test framework.

Likely targets:

```text
react-native/tests/wasm-session-ownership.test.js
react-native/tests/session-queue-manager.test.js
react-native/tests/session-history-registry.test.js
react-native/tests/wasm-backend-memory.test.js
existing callback-demand/log-event tests
existing native-bridge lifetime/source tests when needed
```

Only add a new file if existing suites would become incoherent.

## 16.1 Queue cancellation oracle

Use explicit counters:

```text
executionStarts
cancelCalls
releaseCalls
abandonCalls
```

Never infer "did not execute" merely from a rejected promise; assert executor start count is zero.

## 16.2 Handoff cancellation oracle

Drive state deterministically:

```text
Created -> submit/dequeue -> still Created -> cancel -> Running -> terminal
```

No timing-only assertion should be the proof. Existing tests use small polling delays, but state/counter assertions must establish the result.

## 16.3 Restored ownership oracle

Use a fake backend with explicit scalar state sequence and release latch.

Do not depend on GC/finalizers.

## 16.4 Callback oracle

Use fake bridge lease install/uninstall counts and explicit log/statistics events. Prove demand counts return to baseline.

## 16.5 Web pointer oracle

Inject exact pointer values and throwing functions. Assert exact release identity/count.

---

# 17. TypeScript/API documentation guidance

Update comments/docstrings that currently under-specify behavior:

## `FFmpegKitExtended.cancelSession`

State queue-aware semantics and ID 0 behavior.

## `Session.cancel`

Document:

```text
true pre-execution Created cancellation may abandon
submitted-Created startup preserves intent and waits for Running/terminal
```

## History getters

Document Running wrappers as observation/control wrappers around an existing execution, not fresh execution objects.

## Callback setters

Document that a callback attached to a Running restored wrapper observes that existing execution and may fail if live observer routing cannot be established.

Do not promise callbacks for already-terminal sessions unless implementation explicitly supports retroactive completion delivery.

---

# 18. Production comment guidance

Comments should explain ownership boundaries, not restate code.

Useful comments:

```text
// A submitted session can remain Created while the native worker is starting;
// only a never-submitted Created identity is safe to abandon.
```

```text
// History promotion owns a Running handle. A restored observer retires that
// ownership only after terminal state is observed.
```

```text
// Own the lookup pointer locally until cleanup authority transfers to either
// the retained registry or the caller's temporary-handle scope.
```

Avoid review IDs and historical narrative in production code.

---

# 19. Validation sequence after implementation

Review 44 itself is code-review-only. Luna implementation must run affected validation locally with existing ABI `0.11.2` artifacts.

## 19.1 Focused React Native gates first

Run:

```text
npm run typecheck
npm run test:compile
focused queue/cancellation/history/ownership/callback/Web memory tests
```

Record exact test counts.

## 19.2 Full React Native JS test suite

Run the existing full local Node suite after focused tests are green.

Do not hide platform skips; report passed/skipped totals truthfully.

## 19.3 Native shared-C++ source regression

G3 should not normally require changing `FFmpegKitDynamicApi.cpp`; if it remains unchanged, re-run only the smallest accepted source/lifetime oracle necessary to prove no wrapper change invalidated its contract.

If shared C++ is edited, expand C++ validation accordingly and explain why the platform-native bridge was reopened.

## 19.4 Local platform builds

Because production changes are TypeScript/Web lifecycle code, use the repository's established local affected matrix without remote native retrieval:

```text
Windows React Native build
Android React Native build on local Windows
Web/Wasm tests/build/smoke if backend.web.ts changed
Apple iOS/tvOS/macOS React Native builds last
```

No interactive app launch.

Flutter builds need not be repeated merely for ceremony if no Flutter/shared build infrastructure changed; preserve tracker evidence and run only a bounded source/no-regression check. If shared package/config files change, expand Flutter validation.

## 19.5 No hosted acceptance CI

Do not run hosted Flutter/RN test/build workflows. Final wrapper source snapshot is the only permitted hosted workflow.

---

# 20. Test/result truthfulness

For every command actually executed, record:

```text
platform
working directory
exact command
exit status
test pass/fail/skip counts where available
whether acceptance evidence or diagnostic only
```

Never report as passing:

```text
source inspection
skipped command
timeout/killed process
compile that never started
older review evidence as if newly executed
platform unavailable locally
```

If an environment problem is repaired, record failed attempt and successful retry separately.

---

# 21. Final bounded code review after remediation

After tests/builds are stable, re-read final source.

## 21.1 Cancellation

Confirm:

```text
static ID cancel never bypasses a queued matching Session
ID 0 enters cancel-all authority
queued cancellation never starts executor
submitted Created is not abandoned
pre-submit Created still abandons
terminal clears durable cancellation intent
```

## 21.2 Restored Running lifetime

Confirm:

```text
canonical history parser sees Running state
one per-ID observer lifecycle exists
no re-execution occurs
terminal releases retained handle
clear invalidates observers only after successful backend clear
execution monitor + observer release cannot race visibly
```

## 21.3 Restored callbacks

Confirm:

```text
setter establishes routing before success
failure rolls back sink/demand
optional sink removal releases demand
completion one-shot guard exists
terminal releases callback demand
```

## 21.4 Web temporary ownership

Confirm every nonzero `ffmpeg_kit_get_session` temporary pointer has an exactly-one cleanup/transfer path when state probing throws.

## 21.5 Flutter/platform-native

Confirm no accidental Flutter production or native-bridge drift.

## 21.6 Finding threshold

Open another finding only if it has:

```text
reachable source path
real API/lifecycle/ownership/concurrency violation
concrete product consequence
```

Do not turn formatting, naming, test organization, or refactoring opportunities into findings.

---

# 22. Exact wrapper freeze

Only after all applicable remediation/test/audit gates are complete:

1. Verify `libs/libffmpegkit` remains the frozen SHA.
2. Verify no builders checkout changes.
3. Remove task-owned staging/cache/log output that must not be committed.
4. Commit/push wrapper remediation with semantic commit messages.
5. Record exact 40-character final wrapper SHA.
6. Dispatch **one** wrapper-only source snapshot using that exact SHA.
7. Do not dispatch hosted Flutter/RN acceptance workflows.
8. Do not create a native/builders snapshot.
9. Download the source snapshot artifact through the established workflow path.
10. Verify outer digest, `source.tar.gz.sha256`, every `SHA256SUMS` entry, `SUBMODULES.txt`, `SYMLINKS.tsv`, `snapshot-metadata.json`, exact `snapshot_sha`, and `runtimeExecution=false`.
11. Treat later tracker/mailbox commits as metadata only.

---

# 23. Tracker/final report requirements

Record:

```text
Review 44 starting wrapper SHA
  d8320a5fd3cd4031d9c9b9a0edf71539231c5380

R44-F1 through R44-F5 disposition

exact production files changed
exact tests added/updated

ID cancellation evidence:
  queued target never executes
  active target dispatches cancellation
  ID 0 all-target behavior

startup cancellation evidence:
  submitted Created not abandoned
  terminal-before-Running history preserved

restored lifetime evidence:
  per-ID observer
  exact terminal release count
  execution-monitor coexistence
  successful/failed clear behavior

restored callback evidence:
  completion/log/statistics as applicable
  bridge lease install/uninstall counts
  setter rollback on failure

Web pointer evidence:
  primary error preserved
  pointer released exactly once

React Native focused/full test results
local Web/platform build results actually executed

confirmation Flutter production source unchanged unless separately justified
confirmation platform-native bridge source unchanged unless separately justified
confirmation native ABI/submodule/builders unchanged

exact final wrapper SHA
snapshot workflow run ID
snapshot artifact ID/name/link
digests
manifest count
symlink count
runtimeExecution=false
frozen submodule SHA
```

Do not write "all platforms pass" unless each platform was actually executed in this remediation.

---

# 24. Luna implementation sequence

Follow this order unless a real source conflict requires reconciliation:

```text
1. Read Review 44 code review completely.

2. Verify starting source SHA and frozen submodule.

3. Read the existing SessionQueueManager cancellation/queue tests.

4. Implement G1: route static ID cancellation through one queue/session authority.

5. Add G1 queued/active/ID-0 tests and run them.

6. Implement G2: require !submitted for Created abandonment.

7. Strengthen existing startup cancellation tests with abandon/history assertions.

8. Run focused cancellation + queue + ownership tests.

9. Design G3 before coding G4:
   establish one semantic restored-running per-ID observer/lifetime authority.

10. Canonicalize typed history reconstruction so every public history entrypoint
    passes through the same restored-session lifecycle hook.

11. Route normal and restored terminal retained-handle release through a shared
    per-ID in-flight release authority.

12. Add restored-running terminal-release, duplicate-wrapper, execution-monitor
    coexistence, and clear tests.

13. Implement G4 restored callback observer demand using the G3 lifecycle.

14. Add callback delivery/rollback/refcount tests for the actually supported
    session callback types.

15. Implement G5 Web historyPointer failure-atomic cleanup.

16. Add the throwing-state/exact-release Web regression.

17. Run typecheck + test compilation + focused suites.

18. Run the complete local RN JS suite.

19. Run affected Web/Wasm validation because backend.web.ts changed.

20. Run the established local RN platform build matrix in the repository's
    accepted order, using only configured local ABI 0.11.2 artifacts.

21. Do not run interactive applications.

22. Inspect git diff. Revert unrelated cleanup/refactors.

23. Perform final bounded Flutter/RN + platform-native source audit.

24. If another substantive defect is found, record it and stop closure.

25. If clean, freeze exact wrapper SHA.

26. Dispatch/download/verify one wrapper-only source snapshot.

27. Record tracker provenance and stop automated work.
```

---

# 25. Anti-patterns Luna must reject

## 25.1 Calling backend cancel directly for public ID cancellation

Do not preserve:

```ts
await NativeFFmpegKitExtended.cancelSession(sessionId);
```

as the complete high-level implementation. It cannot remove queued JS work.

## 25.2 Cancelling queue item without Session.cancel()

Do not invent a second ID-only queue discard that skips durable cancellation/lifecycle authority.

## 25.3 Treating all Created state as abandonment

Created is not proof of "never submitted." The handoff window is an existing tested behavior.

## 25.4 Removing Running-history promotion

Do not release a Running temporary handle just to avoid retained ownership. That risks cancelling the execution and reopens an earlier fixed ownership problem.

## 25.5 Starting execution from a restored observer

Never call `executeSessionAsync` from G3/G4.

## 25.6 Reusing execution monitor without separating ownership semantics

Current `monitor()` releases execution ownership and assumes an execution-owned lifecycle. Do not blindly call it from restored wrappers if that would create duplicate release/cancellation ownership.

## 25.7 Per-wrapper competing release calls

Do not rely only on instance-local `handleReleased` once multiple wrappers can observe one native ID.

## 25.8 Silent callback setter success

Do not store a restored callback and return success if Running-state verification or bridge installation failed.

## 25.9 Releasing Web pointer only in historySnapshots finally

That `finally` cannot see a pointer when `historyPointer()` throws before returning it.

## 25.10 Broad Flutter/native cleanup

No Flutter or platform-native production change is needed by the five Review 44 findings unless new contradictory evidence emerges.

## 25.11 Native ABI change

Not permitted.

## 25.12 Hosted CI acceptance

Not permitted. Use local affected gates. Final source snapshot only.

---

# 26. Definition of done

Review 44 wrapper closure is complete only when every applicable item is true:

```text
[ ] Static RN cancelSession(id) is queue-aware.
[ ] cancelSession(0) has explicit tested cancel-all semantics.
[ ] Queued ID cancellation prevents executor start.
[ ] Active ID cancellation uses Session.cancel durable intent.
[ ] Unknown ID behavior is documented/tested.

[ ] Only never-submitted Created sessions are abandoned.
[ ] Submitted-Created startup cancellation preserves intent.
[ ] Running transition dispatches cancellation once.
[ ] Terminal-before-Running does not tombstone history.
[ ] Native/Web submitted identities remain visible in history after terminal.

[ ] Running history reconstruction registers one per-ID terminal observer.
[ ] Restored observer never executes the session.
[ ] Terminal state retires promoted native/Web handle ownership.
[ ] Multiple wrappers cannot race duplicate retained release.
[ ] Original execution monitor and restored observer coexist safely.
[ ] Successful clear invalidates restored observers after backend commit.
[ ] Failed clear does not silently drop observer authority.

[ ] Restored Running completion callbacks are live.
[ ] Restored Running log callbacks are live where supported.
[ ] Restored Running statistics callbacks are live where supported.
[ ] Setter setup failure rolls back callback/demand state.
[ ] Optional bridge demand releases when final sink is removed.
[ ] Terminal observer releases callback demand at most once.

[ ] Web history state-probe failure releases temporary pointer exactly once.
[ ] Web cleanup failure never masks the original probe error.
[ ] Normal Running/temporary/missing history paths remain correct.

[ ] Focused RN regressions pass.
[ ] RN typecheck/test compilation pass.
[ ] Full local RN suite result is recorded truthfully.
[ ] Affected Web/Wasm gates pass.
[ ] Required local platform builds actually executed are recorded truthfully.
[ ] No interactive app launch is claimed.

[ ] Flutter reviewed lifecycle semantics remain unchanged/clean.
[ ] Platform-native bridge closure remains intact.
[ ] No native ABI/submodule/builder change occurred.
[ ] No remote old native bundle was fetched.
[ ] No hosted Flutter/RN acceptance workflow was used.
[ ] Final bounded code review finds no substantive open wrapper finding.
[ ] Exact final wrapper SHA is pushed/frozen.
[ ] One wrapper-only source snapshot at that SHA is downloaded and verified.
[ ] Snapshot metadata records runtimeExecution=false.
```

If any applicable item is false, do not declare full Flutter/React Native wrapper closure.
