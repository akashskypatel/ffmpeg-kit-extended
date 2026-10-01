# Review 40 — G5 Platform-Native Bridge Closure Plan for Luna

**Project:** FFmpegKitExtended  
**Purpose:** Close all substantive platform-native bridge code gaps discovered or exposed by the Review 40 G5 audit.  
**Audience:** Luna implementation/review agent.  
**Planning basis:** `review40-g5-platform-native-bridge-audit.md`  
**Plan date:** 2026-10-01  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch:** `dev-wasm`  
**Audited product-code authority:** `7ad146981461fa5509bf781b49b51db01fc15f04`  
**Observed tracker-only head after that code authority:** `a6260077e6c238b77d150450c9ebca46835b05de`  
**Frozen native submodule:** `b74da2c5d1e294b87d15d73a6687393729e932b3`  
**Frozen native ABI/runtime:** `0.11.2`  
**Native ABI status:** frozen, read-only, already accepted; do not download, rebuild, review, publish, or modify it.

---

# 1. Goal tracker

| Goal | Objective | Primary surfaces | Required evidence | Status |
| --- | --- | --- | --- | --- |
| **G5.1** | Replace unsafe retained raw-handle publication with an explicit borrow/release lifetime authority | `react-native/cpp/FFmpegKitDynamicApi.cpp/.h` | Deterministic release-vs-borrow native concurrency tests; existing G2 retryability preserved | ☐ Not started |
| **G5.2** | Make `clearSessions()` participate in the same retained-handle lifetime transaction | `react-native/cpp/FFmpegKitDynamicApi.cpp` | Deterministic clear-vs-borrow and clear-vs-release tests; no double release, no stale borrow | ☐ Not started |
| **G5.3** | Audit every shared bridge acquisition path against the new authority and close any equivalent lifetime escape | Shared C++ session/history/FFplay/debug/media-information paths | Source review matrix proving each acquisition path is protected; focused regression tests where behavior differs | ☐ Not started |
| **G5.4** | Preserve G1 error-boundary semantics while integrating the lifetime fix | RN Windows bridge, shared Cxx TurboModule, TS native backend | Promise errors remain invocation-bound; sync diagnostic remains same-call only; no hidden fail-fast path | ☐ Not started |
| **G5.5** | Add truthful, deterministic native lifetime tests and update weak source-contract tests | `react-native/tests/*`, native bridge test harness | Real concurrency oracle with barriers/latches; negative and retry cases; no timing sleeps as primary proof | ☐ Not started |
| **G5.6** | Update technical comments/docs to describe the real ownership state machine and caller-visible semantics | C++ ownership comments, TS backend/session docs, tracker/review notes | Comments match implemented behavior and do not claim stronger guarantees than code provides | ☐ Not started |
| **G5.7** | Perform a final bounded platform-native bridge code review and close only substantive defects | RN shared C++, Windows/Android/Apple bridge, Flutter native bridge surfaces | No High/Medium correctness/lifetime/error-boundary defect remains; pedantic/procedural items excluded | ☐ Not started |
| **G5.8** | Run only the affected local noninteractive validation and produce the final exact-SHA wrapper snapshot | RN shared/native local gates, final snapshot workflow | Local gates pass against frozen local ABI 0.11.2; final snapshot records exact wrapper SHA | ☐ Not started |

---

# 2. Mission and closure target

The Review 40 G5 audit found one confirmed High-severity defect:

> A retained React Native native handle remains published as a borrowable raw pointer while `releaseRetainedSession()` is asynchronously retiring it. Synchronous getters/history/FFplay paths can borrow that pointer during the release window. `clearSessions()` is also outside the same lifetime barrier.

The work is not complete merely when that one code location is patched.

The closure target is stronger:

```text
For every platform-native bridge path that touches a native session handle:

1. a handle is never used outside a lifetime authority that guarantees validity;
2. release cannot retire a handle while a protected borrower still uses it;
3. once release begins, no new unsafe borrow of that retained instance can begin;
4. destructive global clear cannot invalidate retained handles behind active borrowers;
5. exactly-once release semantics are preserved;
6. failure remains retryable where the wrapper still owns the handle;
7. action failures remain observable at the originating API invocation;
8. cleanup/destructor paths remain non-throwing where required;
9. no frozen native ABI change is introduced;
10. no unrelated/pedantic cleanup is mixed into the remediation.
```

Review 40 closes only when the final bounded platform-native bridge audit finds no remaining substantive correctness gap.

---

# 3. Non-negotiable constraints

## 3.1 Frozen native ABI

The native ABI/runtime is frozen at:

```text
version: 0.11.2
submodule: b74da2c5d1e294b87d15d73a6687393729e932b3
```

Luna must **not**:

```text
download the native ABI again
re-review native ABI source
modify libs/libffmpegkit
modify the native submodule pointer
change native exported symbols
publish a native ABI bundle
run a remote native ABI build
fetch an older remote native bundle for local tests
replace the already-local frozen artifact with a remote artifact
```

Treat the frozen ABI behavior already established by Review 40 as the contract.

If Luna believes the fix requires a new native ABI symbol or native ABI behavior, stop and report that as a blocker rather than silently changing the ABI.

## 3.2 Source scope

Primary implementation scope:

```text
react-native/cpp/FFmpegKitDynamicApi.cpp
react-native/cpp/FFmpegKitDynamicApi.h
```

Secondary scope only if required by the actual lifetime design:

```text
react-native/cpp/FFmpegKitExtendedImpl.cpp
react-native/cpp/FFmpegKitExtendedImpl.h

react-native/windows/FFmpegKitExtended/FFmpegKitExtended.cpp
react-native/windows/FFmpegKitExtended/FFmpegKitExtended.h
react-native/windows/FFmpegKitExtended/recoverable_native_dispatch.h
react-native/windows/FFmpegKitExtended/operational_error_transport.h

react-native/src/NativeFFmpegKitExtended.ts
react-native/src/platform/backend-registry.ts
react-native/src/platform/backend.native.ts
react-native/src/session.ts
react-native/src/session-queue-manager.ts
react-native/src/callback-demand.ts

react-native/tests/*
```

Flutter production code passed the G5 audit and must not be changed unless the final audit finds a concrete substantive cross-wrapper defect.

## 3.3 No remote CI as acceptance evidence

Do not use hosted CI to prove this remediation.

Acceptance is local and noninteractive.

Do not publish any native ABI remotely.

Do not fetch a remotely built old native bundle for local testing.

Use the already-local packaged ABI `0.11.2`.

## 3.4 Interactive runtime validation remains deferred

Do not run Flutter or React Native interactive UI/runtime tests as part of this remediation.

The user performs final interactive platform validation after the remediation/code-review freeze.

Local noninteractive tests and platform builds are allowed when the implementation phase reaches validation.

## 3.5 This planning/review turn is code-review only

The current task is a planning artifact based on the completed G5 audit.

Do not claim that implementation or tests were executed while writing this plan.

When Luna later executes the plan, Luna must truthfully distinguish:

```text
implemented
compiled
test executed
test passed
test not run
platform not available
```

Never infer a pass from source inspection.

## 3.6 Findings threshold

Exclude:

```text
formatting
naming preference
style-only observations
comment wording with no correctness implication
test organization preference
procedural bookkeeping
speculative race with no reachable interleaving
cross-platform differences that are required by framework APIs
```

Include only defects with a concrete product consequence such as:

```text
use-after-release
double release
lost error
wrong ownership transition
stranded handle
deadlock
invalid reentrancy
stale native pointer
callback lifetime violation
incorrect cross-platform API semantics
incorrect pixel/surface ownership
destructive global operation escaping lifetime authority
```

## 3.7 Semantic implementation names

Do not name production symbols after this plan, review number, or goal number.

Forbidden examples:

```text
G5Fix
Review40BorrowGuard
R40HandleState
Goal5Lease
```

Use semantic names such as:

```text
RetainedSessionEntry
SessionHandleLease
beginSessionBorrow
releaseSessionBorrow
beginRetainedSessionRelease
SessionRegistryBarrier
```

Names are examples, not mandated API.

---

# 4. Protected Review 40 behavior that must not regress

The G5 audit already found these areas clean.

Do not reopen or redesign them without concrete contradictory evidence.

## 4.1 G1 error boundary

Preserve:

```text
Windows failure-bearing actions:
  REACT_METHOD
  ReactPromise<void>
  invocation-local Resolve/Reject

Windows synchronous getters:
  REACT_SYNC_METHOD
  same-call synchronous diagnostic only

shared Cxx actions:
  AsyncPromise<> / generated asynchronous result

TypeScript native backend:
  asynchronous native action list
  synchronous scalar getter path
```

Do not reintroduce a cross-call `lastOperationalError` mechanism.

Do not convert operational failures into:

```text
RaiseFailFastException
std::terminate
abort
silent default success
global mutable last-error shared by unrelated calls
```

## 4.2 G2 lifetime-symbol cache

Preserve:

```text
ffmpeg_kit_handle_release resolved/cached before handle ownership
ffmpeg_kit_free resolved/cached before owned allocations require cleanup
HandleGuard destructor performs no dynamic symbol lookup
HandleGuard move cleanup remains non-throwing
```

The new fix must build on this, not revert it.

## 4.3 G3 pixel normalization

Preserve the accepted canonical frame contract:

```text
accepted:
  rgba
  rgb0
  bgra
  bgr0
  argb
  abgr

published:
  tightly packed RGBA8888
  width * height * 4 bytes

rgb0/bgr0 alpha:
  0xFF

padded decoder rows:
  repacked to tight rows

invalid/unknown frame:
  rejected before mutating renderer-visible state
```

No further G3 work is required unless the final audit finds an actual correctness regression.

## 4.4 Callback and texture ownership

Preserve accepted behavior:

```text
single process-global callback owner
conditional uninstall
retired callback state lifetime
owned callback payload release
no callback exception crossing ABI boundary

Flutter Windows async texture retirement
Flutter Linux FlPixelBufferTexture ownership
existing Android/Apple texture/surface ownership
```

---

# 5. Goal G5.1 — implement a real retained-handle borrow/release authority

## 5.1 Problem to solve

Current retained state is effectively:

```cpp
std::unordered_map<std::int64_t, Handle> retainedSessionHandles;
std::unordered_set<std::int64_t> retainedSessionReleasesInProgress;
```

This prevents two release attempts from overlapping but does not protect a raw
pointer borrowed by another call.

The unsafe state is:

```text
retained pointer visible
release marked in progress
mutex unlocked
native release starts

another reader:
  sees retained pointer
  borrows pointer without ownership
  uses pointer after native release
```

## 5.2 Required production invariant

A retained handle must have an explicit state machine.

Minimum logical states:

```text
Retained
Releasing
Released / absent
```

The implementation must also account for active borrowers.

Conceptually:

```text
RetainedSessionEntry:
  native handle
  release state
  number/lifetime of active borrowers
```

The exact internal representation is Luna's design choice.

## 5.3 Preferred design direction

Prefer an explicit RAII borrow lease.

Conceptual shape:

```cpp
class SessionHandleLease {
 public:
   Handle get() const noexcept;
   ~SessionHandleLease() noexcept;
};

struct RetainedSessionEntry {
  Handle handle;
  bool releasing;
  size_t borrowers;
  ...
};
```

The lease must guarantee:

```text
if lease.get() returns H
H remains valid until that lease is destroyed
```

Release must guarantee:

```text
mark entry as releasing
prevent new unsafe lease acquisition
wait for or otherwise exclude existing leases
call cached native release exactly once
commit wrapper removal
```

A reference-counted entry, condition variable, reader/writer lock, or equivalent
can satisfy this.

Do not mechanically implement the example if another design is safer and
simpler.

## 5.4 Design requirement: no unprotected raw pointer escape

Search every helper that can expose a retained pointer.

The final design must make it difficult to accidentally do:

```cpp
Handle handle = entry.handle;
// release mutex
// use handle later with no lease
```

Prefer APIs that return a lifetime-bearing object rather than `Handle`.

If some path legitimately obtains a separate owning handle directly from the
native registry, represent that ownership explicitly.

## 5.5 Behavior when release already started

Choose one safe semantic and use it consistently.

Acceptable choices:

### Choice A — wait

```text
borrow request observes Releasing
wait until release completes
perform a fresh native lookup
return a new separately-owned observation if the native registry still has it
```

### Choice B — fail deterministically

```text
borrow request observes Releasing
throw a normal wrapper error:
  "Session handle release is in progress"
```

### Choice C — separate native observation

Only if the frozen ABI contract already proves `ffmpeg_kit_get_session(id)`
returns an independent owning handle valid regardless of retained-handle
release.

Do not assume this without existing accepted native-contract evidence.

Do not return the retiring pointer.

## 5.6 Avoid deadlock/reentrancy

Do not solve the race by simply holding `sessionHandlesMutex` across arbitrary
native calls unless reentrancy has been proven safe.

Particularly inspect:

```text
ffmpeg_kit_handle_release
ffmpeg_kit_config_clear_sessions
session state getters
history getters
FFplay state/actions
callback teardown paths
```

If native release/clear can synchronously invoke callbacks or otherwise
re-enter wrapper code, a broad mutex held across native work can deadlock.

Prefer:

```text
state transition under mutex
explicit lease/barrier
native operation outside broad container mutex
commit under mutex
```

while still ensuring the native handle remains valid.

## 5.7 Failure semantics

If pre-release reconciliation fails before native release commits:

```text
wrapper must continue to own the retained handle
entry must return to retryable Retained state
new valid borrowers must not be permanently blocked
no stale "releasing" marker may remain
```

If native release itself cannot report failure because cached release is
`noexcept`/void, commit according to the established native contract.

Do not invent a fake retry after an irreversible release.

## 5.8 G5.1 implementation review checklist

Before moving on, Luna must answer in code comments/review notes:

```text
What object guarantees handle validity during a borrow?
When exactly does release block new borrows?
How are existing borrows drained or excluded?
What happens if state lookup fails before release?
What happens if a second release arrives?
Can a getter receive a handle in Releasing state?
Can an acquired raw pointer outlive its lease?
Can the release path deadlock on reentrant wrapper work?
```

Every answer must point to actual production code.

---

# 6. Goal G5.2 — integrate global clear with the same lifetime authority

## 6.1 Problem to solve

The current `clearSessions()` path performs a destructive native registry clear
and then clears wrapper ownership containers.

That is unsafe if another thread still has a borrowed retained pointer.

The global operation must participate in the same ownership state machine as:

```text
borrow
release
history projection
session getter
FFplay getter/action
debug-log getter/action
media-information access
```

## 6.2 Required invariant

Before destructive native clear can invalidate session handles:

```text
no unprotected active retained borrower may exist
no new retained borrower may begin
per-session release transactions must have a defined ordering with clear
```

After clear commits:

```text
retained ownership state is empty/coherent
history state is empty/coherent
release state is empty/coherent
no borrower believes an invalidated pointer remains valid
```

## 6.3 Define clear-vs-release ordering explicitly

Choose one semantic.

Examples:

### Serialize global clear after active per-session releases

```text
global clear enters exclusive registry barrier
wait for per-session release transaction(s)
block new borrows
perform native clear
clear wrapper state
leave barrier
```

### Global clear becomes the dominant destructive transaction

Only if safely implementable:

```text
global clear blocks all acquisitions
absorbs/removes pending release ownership
performs exactly one native destruction path
commits all wrapper state
```

Do not allow both paths to release the same owning token.

## 6.4 Define clear-vs-new-acquisition behavior

During clear, paths such as:

```text
getSessionJson
getSessionState
getSessionsJson
getLastSessionJson
getLogsJson
getStatisticsJson
getMediaInformationJson
FFplay getters/actions
debug-log access
```

must not receive a pointer that the clear can invalidate concurrently.

Safe options:

```text
wait for clear
fail with deterministic wrapper error
perform only after clear and fresh lookup
```

## 6.5 Preserve JavaScript state cleanup semantics

`react-native/src/platform/backend.native.ts` currently clears:

```text
abandonedSessionIds
cancellationIntentSessionIds
```

only after the native `clearSessions()` action resolves.

Preserve that ordering.

If native clear rejects:

```text
JS tombstone/cancellation state must not falsely report successful clear
```

Do not clear JS bookkeeping before native ownership authority commits.

## 6.6 G5.2 review checklist

Luna must explicitly prove:

```text
clear vs active borrower
clear vs new borrower
clear vs release
clear vs history projection
clear vs running-session monitor
clear failure vs JS bookkeeping
repeated clear
clear when registry already empty
```

---

# 7. Goal G5.3 — audit every acquisition path against the new authority

Do not fix only `getSessionState()` and declare success.

Review every path that currently reaches:

```text
acquireSession
acquireHistorySession
ensureRetainedSession
getFFplaySession
getSession
retainedSessionHandles
```

or can otherwise obtain a native session pointer.

## 7.1 Required path matrix

Build a review table in the remediation notes with at least:

| Path | Handle origin | Ownership before fix | Required ownership after fix | Can race release? | Can race clear? | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| `getSessionState` | retained or lookup | borrowed/temporary | protected lease or owned temporary | yes | yes | code/test |
| `getSessionJson` | retained or lookup | borrowed/temporary | protected lease or owned temporary | yes | yes | code/test |
| `getLogsCount` | retained or lookup | borrowed/temporary | protected lease or owned temporary | yes | yes | code/test |
| `getLogsJson` | retained or lookup | borrowed/temporary | protected lease or owned temporary | yes | yes | code/test |
| `getStatisticsJson` | retained or lookup | borrowed/temporary | protected lease or owned temporary | yes | yes | code/test |
| `getMediaInformationJson` | retained or lookup | borrowed/temporary | protected lease or owned temporary | yes | yes | code/test |
| FFplay controls | retained/history lookup | borrowed/temporary | protected lease or owned temporary | yes | yes | code/test |
| debug-log controls | retained or lookup | borrowed/temporary | protected lease or owned temporary | yes | yes | code/test |
| `getSessionsJson` | history projection | mixed | each entry protected for serialization | yes | yes | code/test |
| `getLastSessionJson` | history projection | mixed | protected selected entry | yes | yes | code/test |
| execution retention | lookup -> retained | owning | transactionally retained | yes | yes | code/test |
| release | retained | owning | exclusive release authority | n/a | yes | code/test |
| clear | global registry | destructive | exclusive registry authority | yes | n/a | code/test |

Add rows for any path discovered during implementation.

## 7.2 History projection must not smuggle an unsafe borrow

Pay special attention to:

```cpp
acquireHistorySession()
```

Current history code may:

```text
lookup a native handle
inspect Running state
insert it into retainedSessionHandles
return a non-owning raw pointer
```

The new design must make history retention and the returned borrow part of one
coherent transaction.

Do not:

```text
insert raw pointer
drop lock
return raw pointer without borrow protection
```

## 7.3 Execution retention must remain exactly once

`ensureRetainedSession()` must not create two owning retained tokens for the
same session when concurrent start/history/getter paths overlap.

Preserve:

```text
one retained execution ownership entry per session ID
```

If a temporary native lookup races with creation of the retained entry, the
losing temporary handle must be released safely and exactly once.

## 7.4 FFplay helper review

Locate the helper used by:

```text
ffplayStart
ffplayPause
ffplayResume
ffplayStop
ffplaySeek
ffplayGetPosition
ffplaySetPosition
ffplayGetDuration
ffplayGetVideoWidth
ffplayGetVideoHeight
ffplayIsPlaying
ffplayIsPaused
ffplaySetVolume
ffplayGetVolume
```

Ensure FFplay-specific type validation does not unwrap the protected lease and
then use the raw pointer after the lease is gone.

## 7.5 Media-information and statistics nested handles

The parent session handle must remain protected while obtaining nested native
handles.

Nested objects returned by the frozen ABI must retain their established
temporary owning semantics.

Do not accidentally couple nested-handle destruction to the retained parent
entry.

---

# 8. Goal G5.4 — preserve and re-audit G1 error semantics

The lifetime fix must not create a new error transport gap.

## 8.1 Windows actions

For actions such as:

```text
releaseSessionHandle
clearSessions
cancelSession
executeSessionAsync
FFplay actions
debug-log actions
configuration actions
```

preserve invocation-local Promise settlement.

A release/clear lifetime error must reject the exact action invocation that
encountered it.

Do not write such an error into the synchronous diagnostic slot.

## 8.2 Windows synchronous getters

If the chosen lifetime behavior rejects/fails a getter while release/clear is in
progress, it must become a same-call synchronous error consumed immediately by:

```ts
invokeSynchronousNative()
```

Do not:

```text
return a plausible default and suppress the error
leave the error for a later unrelated getter
reject an unrelated Promise
```

## 8.3 Shared Cxx Android/Apple bridge

If lifetime authority throws a normal C++ exception before the generated method
returns, confirm the existing Codegen/JSI boundary behavior remains correct.

For asynchronous actions:

```text
completeAction()
must reject its AsyncPromise
```

For synchronous getters:

```text
normal synchronous error propagation must remain framework-correct
```

Do not add Windows-specific error machinery to the shared Cxx path unless
required.

## 8.4 Error precedence

Preserve existing first/primary error rules.

Examples:

```text
native start error beats release cleanup error
monitor state-read error beats cleanup error
callback execution error remains authoritative over later cleanup errors
queue cancellation tries all active sessions and reports first failure
```

Do not let the new lifetime layer overwrite a more relevant primary operation
error unless the lifetime failure itself is the operation being requested.

---

# 9. Goal G5.5 — deterministic test plan

The test suite must prove the lifetime invariant rather than inspect source
order.

Do not treat regex/source tests as primary evidence for concurrency correctness.

Source-contract tests may remain as secondary guards.

## 9.1 Test harness requirement

Provide a controllable fake native symbol implementation for at least:

```text
ffmpeg_kit_get_session
ffmpeg_kit_handle_release
ffmpeg_kit_session_get_session_id
ffmpeg_kit_session_get_state
ffmpeg_kit_config_clear_sessions
```

Add other symbols required by the chosen tested path.

Use:

```text
condition_variable
barrier
latch
promise/future
atomic state
```

or the test framework's deterministic equivalent.

Avoid proving races with arbitrary sleep durations.

## 9.2 Test A — active borrower blocks/isolates release

Setup:

```text
retained session H
getter thread acquires protected borrow
getter pauses after acquisition but before native state call completes
release thread requests release
```

Assertions:

```text
native release has not retired H while getter owns its lease
getter completes using valid H
release then commits
H is released exactly once
retained entry is absent afterward
no release marker remains
```

If the design instead copies an independent owning observation handle, adapt
the exact assertion while preserving pointer validity.

## 9.3 Test B — new borrow after release begins

Setup:

```text
retained H
release enters Releasing state
pause before native release commit
second thread calls getSessionState/getSessionJson
```

Assertions depend on chosen policy.

For fail policy:

```text
getter deterministically fails with release-in-progress error
getter never receives H
release commits once
```

For wait policy:

```text
getter blocks until release commits
getter then performs a fresh lookup
getter never uses retiring H
```

Do not accept nondeterministic success/failure.

## 9.4 Test C — simultaneous release requests

Setup:

```text
two releaseSessionHandle calls for same ID
```

Assert one documented outcome:

```text
one succeeds and second receives deterministic already-releasing result
```

or equivalent.

Required universal assertions:

```text
native release called exactly once
no deadlock
no stale releasing state
no second pointer retirement
```

## 9.5 Test D — pre-release state failure remains retryable

Inject failure into state read before native release.

Assert:

```text
release rejects/fails
native release not called
entry still owns H
releasing state rolled back
later getter can safely borrow H
second release attempt can succeed
```

This preserves G2's accepted retryability.

## 9.6 Test E — `clearSessions()` waits/excludes active borrower

Setup:

```text
borrow H
pause inside borrower
start clearSessions()
```

Assert:

```text
destructive native clear does not invalidate H while borrower is active
no new unsafe borrower begins during clear
borrow finishes safely
clear then commits
retained state empty
history state empty
```

If policy is deterministic failure rather than waiting, assert that explicitly.

## 9.7 Test F — clear versus per-session release

Setup:

```text
start per-session release
pause at a deterministic boundary
start clearSessions
```

Assert:

```text
defined serialization order
no double release
no stale retained entry
no stale releasing marker
no invalid pointer use
no deadlock
```

## 9.8 Test G — clear failure does not lie to JS layer

Where possible through backend seam:

```text
native clear rejects
```

Assert:

```text
backend.native.ts does not clear abandonedSessionIds early
backend.native.ts does not clear cancellationIntentSessionIds early
Promise rejects to caller
second attempt remains possible
```

## 9.9 Test H — history projection during release

Setup:

```text
retained H
release starts
call getSessionsJson/getLastSessionJson
```

Assert history projection follows the selected lifetime policy and never
serializes an invalid pointer.

## 9.10 Test I — FFplay getter/action during release

Pick at least:

```text
ffplayGetPosition
ffplayPause or ffplayStop
```

Start release in parallel.

Assert the FFplay path cannot borrow the retiring retained pointer.

## 9.11 Test J — debug/media getter during release

Cover at least one non-FFplay path that uses the common acquisition helper:

```text
getDebugLog
getMediaInformationJson
```

The purpose is to prove the common authority applies beyond state/history.

## 9.12 Test K — repeated clear and empty registry

Assert:

```text
clearSessions on empty registry is safe
clearSessions twice is safe
no false owned state remains
```

## 9.13 Test L — no destructor dynamic lookup regression

Keep or strengthen the existing G2 oracle proving:

```text
HandleGuard destructor has no resolve<>
move assignment cleanup has no resolve<>
lifetime symbols are published only after initialization transaction succeeds
```

This may remain a source-contract test because the property is structural.

## 9.14 Test M — Windows action error stays with originating Promise

Inject a release/clear failure at the adapter seam.

Assert:

```text
releaseSessionHandle invocation A rejects
unrelated invocation B is unaffected
synchronous getter C does not consume A's error
```

This protects G1 while exercising the new lifetime layer.

## 9.15 Test N — synchronous getter lifetime failure is same-call only

If getters can fail while releasing/clearing:

```text
getter A encounters release-in-progress
getter A throws
getter B later succeeds or receives its own error
no stale synchronous error survives from A
```

## 9.16 Test O — stress test as secondary evidence

After deterministic tests pass, optionally run a bounded concurrency stress
test:

```text
many repeated borrow/release/clear interleavings
```

This is secondary evidence only.

A stress test must not replace deterministic barrier-based tests.

---

# 10. Existing tests to update

## 10.1 `react-native/tests/native-bridge-lifetime.test.js`

Current source-contract logic that only proves:

```text
release(handle)
appears before
retainedSessionHandles.erase(it)
```

is insufficient.

Update it to check the new structural ownership primitives.

Examples:

```text
retained entry contains lifetime state
acquisition returns a lease/protected object
release marks entry before native release
raw retiring pointer is not returned through normal acquisition
global clear uses the same registry/lifetime authority
```

Do not overfit to exact line ordering if the new design is semantically safer.

## 10.2 Native concurrency test location

Prefer a compiled C++ test close to `FFmpegKitDynamicApi.cpp` or an existing
native bridge oracle capable of injecting symbol functions.

Do not fake concurrency by testing a JavaScript mock that never reaches the C++
ownership code.

The primary R40-G5-F1 proof must execute the C++ ownership implementation.

## 10.3 JavaScript/TypeScript tests

Use JS tests for:

```text
Promise propagation
JS bookkeeping after native clear success/failure
session wrapper error precedence
high-level await/propagation behavior
```

Do not use JS-only mocks as proof of native pointer lifetime.

---

# 11. Goal G5.6 — documentation and comment updates

Documentation updates are required only where they clarify actual product
semantics or prevent future ownership regressions.

Do not perform broad prose cleanup.

## 11.1 `FFmpegKitDynamicApi.cpp` ownership comments

Document:

```text
what a retained handle owns
what a borrow/lease guarantees
when release becomes exclusive
what "releasing" means
whether new borrowers wait or fail
when wrapper ownership ends
how global clear serializes with borrows/releases
```

Comments must describe the actual implemented state machine.

Avoid vague claims such as:

```text
"thread-safe"
"atomic"
"safe"
```

without stating the protected operation.

## 11.2 `FFmpegKitDynamicApi.h`

If a new internal/public-to-wrapper helper type or semantic contract is
declared, document only the externally relevant bridge behavior.

Do not expose plan terminology.

## 11.3 `backend-registry.ts`

If `ActionCompletion` semantics remain unchanged, no doc change is required.

If a getter can now deliberately throw "release in progress", update the nearest
backend/session documentation to explain that a synchronous inspection can fail
when the session is concurrently being destructively cleared/released.

Do not promise that every getter waits unless that is the implementation.

## 11.4 `session.ts`

Current docs already state that `clearSessions()` can invalidate handles.

Update only if the user-observable behavior changes.

Examples:

For wait policy:

```text
inspection during final native-handle retirement may wait for retirement and
then perform a fresh lookup
```

For fail policy:

```text
inspection during final native-handle retirement may throw because the session
is being released
```

Keep wording concise.

## 11.5 `FFmpegKitConfig.clearSessions()` and `FFmpegKitExtended.clearSessions()`

Ensure docs continue to state that clear is destructive and should not be used
as a benign history-only operation.

If the new global barrier makes the exact behavior stronger, document:

```text
clear waits for/protects active bridge observations before native invalidation
```

only if that is actually true.

## 11.6 Tests/comments about G2

Replace misleading comments that imply:

```text
"release-before-erase is atomic"
```

if the implementation now uses a real borrow/release transaction.

Explain the true commit point.

## 11.7 Tracker/review documentation

When remediation is complete, record:

```text
exact implementation SHA
R40-G5-F1 disposition
chosen borrow-during-release semantic
chosen clear-vs-release ordering
focused deterministic tests run
local platform gates run
any skipped platform with reason
final G5 re-audit disposition
```

Do not state "all platforms pass" unless each listed gate actually ran and
passed.

---

# 12. Goal G5.7 — final bounded platform-native bridge review

After implementation and focused tests, perform a fresh code-review pass.

This is not a broad project review.

## 12.1 Review class A — retained handle ownership

Re-read all code touching:

```text
retained session entries
temporary handles
borrow leases
release
clear
history retention
execution retention
nested media/statistics handles
```

Look specifically for:

```text
raw pointer escaping protected lifetime
borrow count leak
release state never cleared
release while borrower active
borrow after release commit
duplicate owning retained entries
temporary handle double-release
temporary handle leak
deadlock caused by lock ordering
condition wait that can never be signaled
```

## 12.2 Review class B — error boundary

Re-read:

```text
shared Cxx completeAction
Windows completeAction/invokeWithCompletion
Windows synchronous error transport
backend.native async/sync dispatch
Session release/clear awaiting
```

Look for:

```text
Promise dropped
Promise rejection not awaited
sync error stored globally for later call
exception crossing noexcept boundary
fail-fast/terminate
default result masking error
cleanup error replacing established primary error incorrectly
```

## 12.3 Review class C — callback lifetime

Do not rewrite accepted callback code.

Only identify a finding if the new lifetime implementation changes or invalidates
a callback-owner assumption.

Check:

```text
session release does not free callback user data still in use
clear does not destroy callback state through the wrong ownership path
log callback message still released once
```

## 12.4 Review class D — dynamic loading

Verify the remediation does not reintroduce symbol lookup inside:

```text
destructor
lease destructor
release cleanup
clear cleanup
```

No new dynamic resolver should be required for the fix.

## 12.5 Review class E — Windows concurrency

This is the most important platform-specific pass.

Trace:

```text
async ReactPromise release/clear
sync REACT_SYNC_METHOD inspection
shared retained registry
JS monitor finalization
concurrent JS timer/UI inspection
```

Confirm no raw-pointer race remains.

## 12.6 Review class F — Android/Apple shared Cxx

Because `FFmpegKitDynamicApi.cpp` is shared, verify:

```text
new mutex/condition/lease code is valid on Android
new code is valid on iOS
new code is valid on tvOS
new code is valid on macOS
no Windows-only type leaked into shared implementation
```

No platform needs a special workaround unless the compiler/API requires it.

## 12.7 Review class G — Flutter/native bridge regression scan

Flutter G5 areas passed.

Only run a source regression scan for shared assumptions:

```text
no native ABI changed
no exported symbol changed
no frame callback contract changed
no pixel-format contract changed
```

Do not invent new Flutter work.

## 12.8 Review class H — Apple duplicate-source parity

Recheck only files affected by any remediation.

If no Apple duplicate file changed, preserve the previous PASS.

Do not report import-path or formatting differences.

## 12.9 Final finding threshold

A new finding must include:

```text
reachable execution path
specific ownership/error invariant violated
specific product consequence
source location(s)
why existing tests do not already disprove it
```

No "could perhaps" findings without a concrete interleaving.

---

# 13. Goal G5.8 — local validation and final freeze

This section is for the later remediation execution.

No validation is being claimed by this plan.

## 13.1 Validation order

Run after implementation review is locally clean:

```text
1. focused compiled C++ retained-handle concurrency tests
2. React Native native bridge lifetime/source-contract tests
3. React Native JS tests affected by Promise/clear semantics
4. TypeScript typecheck
5. React Native test compilation
6. local platform-native builds
7. final bounded G5 code review
8. exact final wrapper source snapshot
```

## 13.2 Windows local gates

Run locally with the already-local frozen ABI 0.11.2:

```text
RN native bridge test
RN Windows compile/build
focused Windows error transport tests
```

If the native concurrency oracle is platform-neutral C++, also run it on
Windows.

## 13.3 Android local gates

Run:

```text
shared Cxx/codegen compile
Android RN local build
focused shared native test if supported in current harness
```

No remote ABI fetch.

## 13.4 Apple local gates

Run last:

```text
RN iOS local build
RN tvOS local build
RN macOS local build
```

Use the existing local packaged ABI.

No native ABI publication.

No interactive app runtime test.

## 13.5 Flutter validation

Do not rerun broad Flutter builds unless the remediation changes a file used by
Flutter.

If only RN shared C++ changes, Flutter G3 remains accepted from the G5 audit.

## 13.6 Final snapshot

Only after:

```text
R40-G5-F1 fixed
focused tests pass
affected local builds pass
final G5 code review finds no substantive defect
```

create one exact-SHA wrapper source snapshot.

The final tracker must record:

```text
wrapper SHA
workflow run ID
artifact ID
artifact name
artifact digest
embedded source.tar.gz SHA
manifest/file count
recursive submodule state
runtimeExecution=false
frozen submodule SHA
```

Do not snapshot an intermediate remediation state as the Review 40 final
authority.

---

# 14. Detailed implementation sequence for Luna

Luna should follow this order to reduce accidental scope expansion.

## Step 1 — inspect only the affected ownership code

Read:

```text
react-native/cpp/FFmpegKitDynamicApi.cpp
react-native/cpp/FFmpegKitDynamicApi.h
react-native/tests/native-bridge-lifetime.test.js
```

Then identify every helper that returns or stores a session `Handle`.

Produce a small private working map:

```text
helper
source of handle
owns?
borrows?
release point
can overlap release?
can overlap clear?
```

Do not change code yet.

## Step 2 — choose one ownership model

Before editing, define:

```text
borrow representation
release state
global clear state
wait/fail policy
lock ordering
condition notification point
rollback behavior
```

Reject any design that still lets a raw retained pointer escape after dropping
all lifetime protection.

## Step 3 — implement the retained entry/lease primitive

Keep the implementation small and centralized.

Prefer one reusable authority rather than scattered checks such as:

```cpp
if (retainedSessionReleasesInProgress.contains(id)) ...
```

in every getter.

Scattered checks are race-prone because:

```text
check
unlock
release commits
use pointer
```

still races.

## Step 4 — migrate `acquireSession()`

Make this the canonical safe acquisition path.

Any retained-handle path must receive a lifetime-bearing result.

Temporary independently-owned native lookup remains allowed if it is clearly
owned and released.

## Step 5 — migrate `acquireHistorySession()`

Ensure running history retention and the returned observation are one
transaction.

Do not insert then return an unprotected pointer.

## Step 6 — migrate `ensureRetainedSession()`

Ensure execution start retains exactly one owning token.

Handle concurrent existing entry/releasing/global-clear state explicitly.

## Step 7 — migrate `releaseRetainedSession()`

Release must:

```text
gain exclusive release authority
block new unsafe borrows
drain/exclude existing borrowers
perform pre-release state reconciliation
rollback if pre-release reconciliation fails
release cached handle exactly once
commit removal
notify waiters
perform history terminal/prune update
```

Be explicit about which operations happen before/after the native release
commit.

## Step 8 — integrate `clearSessions()`

Put global clear through the same lifetime authority.

Do not independently clear ownership containers behind the authority's back.

## Step 9 — inspect all call sites

Compile mentally/source-review all functions listed in G5.3.

Do not assume helper migration automatically covers a call site that stores
`Handle` beyond helper scope.

## Step 10 — update deterministic native tests

Implement Tests A-F first.

Do not continue to platform builds until those core ownership tests pass.

## Step 11 — update JS error/clear tests

Implement Tests G, M, N as applicable.

## Step 12 — update comments/docs

Only after semantics are stable.

Do not document a design that is still changing.

## Step 13 — local affected validation

Use only the local frozen ABI 0.11.2.

No hosted CI.

## Step 14 — final code review

Perform G5.7 from scratch against the post-fix source.

Do not simply verify that the original finding disappeared.

Look for defects introduced by the fix.

## Step 15 — final snapshot

Only after the review is clean.

---

# 15. Anti-patterns Luna must avoid

## 15.1 Checking `releasesInProgress` then returning the same raw pointer

Unsafe:

```cpp
lock
if (releasing) throw
auto handle = entry.handle
unlock
return handle
```

The release can begin immediately after unlock.

A lifetime-bearing borrow is required.

## 15.2 Holding one global mutex around all native calls

This may hide the race while introducing:

```text
deadlock
callback reentrancy deadlock
long synchronous JS stalls
cross-session serialization
```

Use only if reentrancy and performance consequences are proven acceptable.

## 15.3 Erasing map entry before native release without replacing ownership

Erasing first may prevent new borrows, but it can:

```text
lose retryable ownership
allow fresh lookup of the same underlying session while old release is pending
break G2 failure semantics
```

Do not use map erasure alone as the lifetime model.

## 15.4 Copying the raw handle into a `shared_ptr<void>`

A shared pointer to the pointer value does not make the native token valid.

The object controlling release must own the actual release transaction.

## 15.5 JavaScript-only lock

The defect exists below JS and can be exposed by platform scheduling.

A JS mutex is not sufficient evidence.

## 15.6 Source regex as concurrency proof

A test that checks:

```text
"releasing" appears before "release(handle)"
```

does not prove borrowers are protected.

Use real C++ interleaving tests.

## 15.7 Weakening synchronous getter semantics silently

Do not make getters return:

```text
0
false
""
[]
```

merely because release is in progress.

Either perform a valid observation or report the real error.

## 15.8 Changing the native ABI

Not allowed.

---

# 16. Expected final code-review report structure

After Luna finishes implementation and validation, produce a concise final
Review 40 G5 closure report with:

## Authority

```text
exact wrapper SHA
frozen ABI 0.11.2
frozen submodule SHA
no native ABI modification
```

## Original finding disposition

```text
R40-G5-F1:
  fixed / not fixed
  implementation summary
  exact files
  chosen borrow-during-release policy
  chosen clear ordering
```

## Test evidence

Table:

| Test | Platform/harness | Result | Notes |
| --- | --- | --- | --- |
| release vs existing borrower | C++ | PASS/FAIL | deterministic barrier |
| release vs new borrower | C++ | PASS/FAIL | wait/fail policy |
| duplicate release | C++ | PASS/FAIL | exactly once |
| pre-release failure retry | C++ | PASS/FAIL | ownership retained |
| clear vs borrower | C++ | PASS/FAIL | global barrier |
| clear vs release | C++ | PASS/FAIL | no double release |
| Windows action error isolation | RNW/native | PASS/FAIL | Promise-local |
| JS clear bookkeeping failure | JS/native seam | PASS/FAIL | no false clear |

## Local platform evidence

```text
Windows
Android
iOS
tvOS
macOS
```

Record only what actually ran.

## Final bounded audit

```text
retained lifetime: PASS/FAIL
error boundary: PASS/FAIL
callback owner: PASS/FAIL
texture/surface ownership: PASS/FAIL
dynamic symbols: PASS/FAIL
Apple parity: PASS/FAIL
pixel layout: PASS/FAIL
```

## Closure

Only write:

```text
Review 40 G5 CLOSED
```

if no substantive platform-native bridge defect remains.

Otherwise list the remaining defect and keep G5 open.

---

# 17. Definition of done

Review 40 G5 is complete only when all are true:

```text
[ ] R40-G5-F1 production race is removed by a real lifetime authority.
[ ] No retained raw pointer can outlive its protected borrow.
[ ] Release prevents new unsafe borrows and respects existing borrowers.
[ ] clearSessions participates in the same ownership transaction.
[ ] No double release is possible.
[ ] Pre-release failure preserves retryable ownership.
[ ] G1 Promise/synchronous error semantics remain intact.
[ ] Cached non-throwing cleanup from G2 remains intact.
[ ] G3 packed RGBA normalization remains unchanged/clean.
[ ] Callback ownership remains unchanged/clean.
[ ] Dynamic symbol cleanup remains unchanged/clean.
[ ] Deterministic native concurrency tests exist and pass.
[ ] JS/native Promise and clear-bookkeeping tests pass.
[ ] Affected local noninteractive platform builds pass using local ABI 0.11.2.
[ ] No hosted CI is used as acceptance evidence.
[ ] No native ABI is downloaded/re-reviewed/modified/published.
[ ] Final bounded code review finds no substantive platform-native bridge gap.
[ ] Final exact-SHA wrapper snapshot is created only after clean closure.
[ ] Tracker records truthful commands/results and exact source authority.
```

If any box remains false, do not declare Review 40 closed.
