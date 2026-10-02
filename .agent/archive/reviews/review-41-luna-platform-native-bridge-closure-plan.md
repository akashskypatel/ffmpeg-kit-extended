# Review 41 — Luna Platform-Native Bridge Final Closure Plan

**Project:** FFmpegKitExtended  
**Audience:** Luna implementation/review model  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch:** `dev-wasm`  
**Starting source authority:** `7ba4a60621c77ac9add7328e8c27b7394f2cdb11`  
**Review basis:** `review41-platform-native-bridge-code-review.md`  
**Native ABI/runtime:** frozen `0.11.2`  
**Frozen native submodule:** `b74da2c5d1e294b87d15d73a6687393729e932b3`

---

# 1. Goal tracker

| Goal | Objective | Primary implementation | Tests required | Documentation/comments | Status |
| --- | --- | --- | --- | --- | --- |
| **R41-G1** | Make global session clear a true registry-wide lifetime transaction covering retained and temporary handles plus session creation | `react-native/cpp/FFmpegKitDynamicApi.cpp/.h` | Deterministic temporary-handle/creation/history-vs-clear C++ concurrency tests; retain Review 40 retained tests | Update registry-lifetime state-machine comments and clear commit-point comments | ☐ |
| **R41-G2** | Make native abandonment reconciliation diagnostic-aware and fail-closed on Windows synchronous errors | `react-native/src/platform/backend.native.ts` | Behavioral native-backend probe tests for non-empty, confirmed empty, diagnostic/error, clear success/failure | Clarify that only diagnostic-free empty snapshot proves absence | ☐ |
| **R41-G3** | Re-audit every native session-handle acquisition and every Windows synchronous native read against G1/G2 | shared RN C++, Windows RN module, native backend | Source matrix plus focused executable tests where a path has distinct behavior | Add only semantic maintenance comments | ☐ |
| **R41-G4** | Preserve all previously clean platform-native bridge invariants | Flutter native surfaces and RN Windows/Android/Apple callbacks/surfaces | Existing focused regressions remain applicable; run only affected local gates | Do not rewrite unrelated docs | ☐ |
| **R41-G5** | Perform the final bounded bridge code review, affected local validation, exact-SHA freeze, and one wrapper-only snapshot | whole affected wrapper surface | Local only; no hosted acceptance CI; no interactive UI | Tracker/final closure report with exact evidence | ☐ |

---

# 2. Hard constraints

Luna must treat these as mandatory.

1. Work only in `akashskypatel/ffmpeg-kit-extended` on `dev-wasm`.
2. Reconcile the live branch against exact Review 41 source authority:
   `7ba4a60621c77ac9add7328e8c27b7394f2cdb11`.
3. Keep native ABI/runtime pinned to **0.11.2**.
4. Keep `libs/libffmpegkit` frozen/read-only at:
   `b74da2c5d1e294b87d15d73a6687393729e932b3`.
5. Do **not** download or re-review the native ABI.
6. Do **not** edit the native submodule.
7. Do **not** edit or rebuild the ManyLinux builder checkout.
8. Do **not** add or require a new native exported symbol.
9. Do **not** publish a native ABI.
10. Do **not** fetch a remote old native bundle for local validation.
11. Do **not** use hosted Flutter/React Native test/build workflows as acceptance evidence.
12. The only hosted workflow allowed at final closeout is the exact wrapper source-snapshot workflow.
13. Do **not** launch interactive Flutter or React Native applications.
14. Final interactive runtime validation remains user-owned.
15. This plan is based on code review only; do not claim Review 41 tests already ran.
16. Production identifiers must be semantic and must not contain `R41`, `G1`, `F1`, `review41`, or planning terminology.
17. Tests must be truthful. Never fabricate execution, expected output, or platform results.
18. Never weaken an existing test merely to make a gate green.
19. Record implementation mistakes, failed commands, environment corrections, and retries.
20. Exclude style/pedantic/procedural findings from the final closure audit.
21. A new finding must have a reachable path and product consequence.
22. Preserve the primary error over cleanup errors.
23. Do not reopen accepted Review 39/40 behavior without direct contradictory source or test evidence.

---

# 3. Protected invariants from Reviews 39–40

Do not redesign these areas unless R41-G1/G2 directly require a change.

## 3.1 Windows React Native action errors

Preserve:

```text
failure-bearing action
-> invocation-owned Promise
-> Resolve once OR Reject once
```

Do not reintroduce:

```text
cross-call async last-error state
RaiseFailFastException
std::terminate for operational errors
silent action success after adapter failure
```

## 3.2 Windows synchronous result errors

Preserve:

```text
REACT_SYNC_METHOD
-> same-call native invocation
-> same-call synchronous diagnostic
-> invokeSynchronousNative consumes diagnostic
-> JS throws if diagnostic is non-empty
```

R41-G2 closes a bypass of this authority; do not replace the authority.

## 3.3 Shared retained-handle release

Preserve:

```text
Retained -> Releasing -> removed
new retained borrow rejected after Releasing
existing retained leases drain before release
pre-release state failure restores retryable retained state
duplicate release rejected
native release/free functions cached before ownership begins
HandleGuard/RetainedHandleLease cleanup is non-throwing
```

R41-G1 expands global clear authority beyond the retained-only subset.

## 3.4 Flutter texture/surface ownership

Preserve:

```text
Flutter Windows:
  async TextureVariant retirement through unregister completion

Flutter Linux:
  FlPixelBufferTexture engine-side GL ownership
  plugin CPU frame-store lifetime
  coalesced main-loop frame notification

Flutter Android:
  process-global Surface owner
  explicit ANativeWindow/Surface/TextureEntry cleanup

Flutter Apple:
  callback unregister/drain
  texture owner replacement
  CocoaPods/SwiftPM behavioral parity
```

## 3.5 Packed frame contract

Preserve:

```text
Flutter Windows/Linux canonical output:
  tightly packed RGBA8888

accepted source:
  rgba
  rgb0
  bgra
  bgr0
  argb
  abgr

rgb0/bgr0:
  alpha = 255

padded rows:
  repacked

unknown/invalid:
  dropped before renderer-visible mutation
```

---

# 4. R41-G1 — true session-registry lifetime authority

## 4.1 Objective

Global `clearSessions()` must not invalidate **any** native session handle while
the bridge is still using that handle.

The protection must cover:

```text
retained running-session borrows
temporary Created/terminal observations
history temporary observations
session creation temporary handles
media/statistics operations rooted in a temporary session
FFplay operations rooted in a temporary session
retained release transactions
```

The global clear operation must remain exclusive until:

```text
native registry clear committed
retained wrapper ownership cleared
wrapper history state cleared
```

Only then may new session-registry work begin.

---

# 5. G1 design requirement — separate per-session retention from registry-wide operation lifetime

The current retained lease solves a per-session ownership problem.

Do not overload it with unrelated meaning.

Introduce a semantic registry-level authority.

Recommended concepts:

```text
SessionRegistryOperationLease
SessionRegistryTransaction
SessionRegistryBarrier
```

Choose one design.

A useful mental model:

```text
global registry state:
  Open
  Clearing

active registry operations:
  count

retained release transactions:
  count or included in active operations
```

Any operation that can own/use a native session handle whose registry token can
be invalidated by global clear must hold a registry operation lease.

---

# 6. G1 implementation option A — explicit registry operation lease

This is the preferred direction.

Conceptually:

```cpp
class SessionRegistryOperationLease {
 public:
  SessionRegistryOperationLease() = default;
  SessionRegistryOperationLease(SessionRegistryOperationLease&&) noexcept;
  SessionRegistryOperationLease& operator=(SessionRegistryOperationLease&&) noexcept;
  ~SessionRegistryOperationLease() noexcept;

  explicit operator bool() const noexcept;
};
```

Acquisition:

```text
lock registry mutex
wait while clear is exclusive
increment active registry-operation count
unlock
```

Destruction:

```text
lock
decrement
notify clear waiter
unlock
```

Global clear:

```text
lock
wait no other clear
mark clear exclusive
wait active registry operations == 0
wait retained release transactions == 0 if not represented in operation count
unlock

native config_clear_sessions()

clear retained map while still exclusive
clear local history while still exclusive

lock
clear exclusive flag
notify all
unlock
```

The exact lock split may vary, but the lifetime invariant must remain true.

---

# 7. G1: protect temporary `getSession()` observations

Current unsafe branch:

```cpp
return HandleGuard(getSession(id), true);
```

Replace it with a transaction where the registry lease starts **before**
`ffmpeg_kit_get_session()` and remains alive until the temporary owning handle
has finished all native use and has been released.

Possible `HandleGuard` structure:

```text
HandleGuard
  Handle handle
  ownership mode
  optional retained-session lease
  optional registry-operation lease
```

For a temporary observation:

```text
registry lease = active
native handle = owning
retained lease = none
```

Destructor order should keep the registry lease alive until after native
`handle_release` has completed.

Safe order:

```text
release owned native handle
then release registry operation lease
```

Do not decrement the registry count first.

---

# 8. G1: retained borrows also belong to the registry authority

A retained handle borrow is already counted by:

```text
entry.activeBorrows
activeRetainedBorrows
```

Luna may:

### Option A

Keep the retained counts and make clear wait on:

```text
active temporary registry operations
active retained borrows
active retained releases
```

### Option B

Unify every live native session observation under one registry-operation count
while retaining per-entry borrow counts for release ordering.

Option B reduces global-clear concepts, but do not rewrite more code than
needed.

Whichever design is selected, document the two distinct invariants:

```text
per-entry lease:
  protects retained handle against per-session release

registry operation lease:
  protects any native session handle against global clear
```

---

# 9. G1: protect session creation

Before calling any native session-creation function, acquire the registry
operation authority.

Applies to:

```text
createFFmpegSession
createFFmpegSessionFromArguments
createFFprobeSession
createFFplaySession
createFFplaySessionFromArguments
createMediaInformationSession
createMediaInformationSessionFromPath
```

Required transaction:

```text
acquire registry operation lease
create native session handle
read session ID/type
record wrapper history
release temporary native handle
release registry lease
```

This gives deterministic clear ordering.

### Create already active when clear starts

Clear waits until creation transaction commits.

Then clear may remove that just-created session as part of its documented
destructive semantics.

### Clear already exclusive when create begins

Creation waits.

After clear commits and reopens the registry, creation proceeds and its new
history entry must survive.

---

# 10. G1: do not reopen clear before history commit

Current source reopens the registry before:

```cpp
historyRecords.clear();
nextHistoryOrder = 0;
```

Move the exclusive clear commit point.

Required order:

```text
mark global clear exclusive
drain protected operations
perform native clear

while still exclusive:
  clear retained wrapper ownership
  clear wrapper history / reset history order

only after both wrapper states commit:
  reopen registry
  notify waiting operations
```

Do not permit a new create/acquire transaction to start in the native-clear /
local-history-clear gap.

---

# 11. G1: history projection

`getSessionsJson()` and `getLastSessionJson()` use `acquireHistorySession()`.

Audit all branches.

Required:

```text
retained Running identity
  -> retained lease + global registry protection

temporary terminal/Created identity
  -> owning temporary handle + global registry operation lease

temporary Running handle promoted to retained entry
  -> no lifetime gap during promotion
  -> temporary ownership transferred exactly once
  -> resulting retained borrow remains protected
```

If the design transfers a registry lease into a retained lease/guard, make the
ownership transition explicit.

Do not create two independent leases that accidentally decrement the same
global count twice.

---

# 12. G1: media information/statistics nested handles

Examples:

```text
getStatisticsJson
getMediaInformationJson
stream/chapter iteration
```

The session parent guard must remain alive for the entire nested read.

If the parent is a temporary session observation:

```text
global registry operation lease must remain alive through all nested reads
```

Temporary child handles retain their existing owning cleanup.

Do not release the parent registry lease immediately after obtaining a child
unless the frozen ABI contract explicitly proves the child is fully independent.

No native ABI review is required; the simplest safe design is to keep the
parent guard alive for the function's existing lexical lifetime.

---

# 13. G1: FFplay and debug-log paths

Audit:

```text
getFFplaySession
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

enableDebugLog
disableDebugLog
isDebugLogEnabled
getDebugLog
clearDebugLog
```

They must inherit registry protection automatically from the common session
acquisition helper.

Do not add per-method ad-hoc clear checks.

---

# 14. G1: avoid broad mutex/native-call deadlocks

Do not fix R41-F1 by holding `sessionHandlesMutex` across every native operation.

That risks:

```text
native callback reentrancy deadlock
long cross-session serialization
clear/release wait cycles
blocking synchronous Windows getters behind unrelated native work
```

Prefer:

```text
short state transition under mutex
lifetime-bearing operation lease
native call outside container mutex
short commit under mutex
```

The lease, not the locked mutex, is the safety authority.

---

# 15. G1 deterministic test plan

Extend `react-native/cpp/retained_handle_lifetime_test.cpp` or split a semantic
registry-lifetime test if clearer.

The tests must execute the real shared C++ lifetime code through the existing
fake resolver seam.

Do not prove the race with source text.

## Test G1-A — temporary getter versus clear

Create a visible session that is **not** retained by execution.

Thread A:

```text
getSessionState(id)
-> temporary native handle acquired
-> fake state function blocks
```

Thread B:

```text
clearSessions()
```

Assert before releasing A:

```text
fake native clear has not been called
```

Release A.

Assert:

```text
getter finishes safely
temporary native handle released once
clear then reaches native clear
```

This is the direct regression for R41-F1.

## Test G1-B — terminal history projection versus clear

Create a non-retained terminal/history identity.

Pause:

```text
getSessionsJson / getLastSessionJson
```

while it holds the temporary observation.

Start clear.

Assert native clear waits until serialization/temporary handle release is
complete.

## Test G1-C — creation already in progress when clear starts

Fake native create returns a handle.

Pause the creation transaction during:

```text
sessionIdOf()
or immediately before rememberHistorySession()
```

Start clear.

Assert:

```text
native clear does not begin until creation transaction releases its temporary
handle and finishes its wrapper-history commit
```

Then clear commits.

Assert the just-created pre-clear session is absent afterward.

## Test G1-D — create begins after clear is exclusive

Start clear and pause inside fake native clear after the exclusive barrier is
visible.

Start create.

Assert:

```text
fake native create has not been called yet
```

Finish clear.

Assert:

```text
create then runs
new session remains visible
new history record remains visible
```

This also proves the clear barrier remains exclusive through wrapper-history
reset.

## Test G1-E — barrier remains closed through local history clear

Provide a test-only synchronization hook around the wrapper clear commit if
needed.

Pause after native clear has returned but before `historyRecords.clear()`.

Start:

```text
create session
or temporary getSession observation
```

Assert it remains blocked.

Finish local history reset and reopen.

Assert new operation runs afterward.

Do not ship a general production callback solely for the test; keep the seam in
the `testing` namespace or compile-time test support.

## Test G1-F — temporary media-information read versus clear

Use a temporary non-retained media-information session.

Pause a session-level/native child read.

Assert clear cannot invalidate the parent session handle before the complete
operation exits.

## Test G1-G — retained behavior remains unchanged

Keep Review 40 cases:

```text
active retained borrower vs release
new borrow after release starts
duplicate release
pre-release state failure retry
retained borrower vs clear
native clear failure retry
```

All must remain green.

## Test G1-H — no deadlock under mixed operations

Use deterministic latches to interleave:

```text
retained borrower
temporary borrower
release request
clear request
```

Choose one valid serial order and assert completion without deadlock.

This is secondary to the targeted tests but useful after the state machine is
stable.

---

# 16. R41-G2 — diagnostic-aware fail-closed abandonment reconciliation

## 16.1 Objective

An abandonment tombstone may be reclaimed only after a native probe has
**successfully and diagnostic-free** proven that the session identity is absent.

On Windows:

```text
default return value after a caught native error
must never be interpreted as absence
```

## 16.2 Minimal production correction

Current:

```ts
const json = NativeFFmpegKitExtended.getSessionJson(sessionId);
```

Required:

```ts
const json = invokeSynchronousNative<string>(
  'getSessionJson',
  [sessionId],
);
```

Keep the existing `try/catch`.

Then:

```text
non-empty -> still present -> retain tombstone
empty with no diagnostic -> confirmed absent -> remove tombstone
throw/diagnostic -> catch -> retain tombstone
```

## 16.3 Do not duplicate Windows handling

Do not write:

```ts
const json = NativeFFmpegKitExtended.getSessionJson(...);
const error = NativeFFmpegKitExtended.consumeSynchronousError();
...
```

inside reconciliation.

That duplicates the synchronous-call authority and makes future bypasses more
likely.

All synchronous native reads with semantically meaningful defaults should use
the common helper.

---

# 17. G2 implementation audit — raw native synchronous calls inside backend.native

After the fix, inspect `backend.native.ts` itself.

Allowed raw module usage includes:

```text
function-presence checks
EventEmitter property access
the internal implementation of invokeSynchronousNative
the internal implementation of invokeAsyncNative
```

A synchronous native method whose result influences state must not bypass
`invokeSynchronousNative`.

Specifically ensure:

```text
reconcileAbandonedSessionId
getMediaInformationData
getSessionState
getSessionJson
getSessionsJson
getLastSessionJson
generic proxy getter path
```

all use the diagnostic-aware helper.

Do not report raw calls in public wrapper files when the variable is actually
`getBackend()`; distinguish the backend proxy from the raw TurboModule import.

---

# 18. G2 behavioral test seam

A source regex is not sufficient because the bug is semantic:

```text
Windows returns a default value and stores a side-channel diagnostic
```

Prefer a small injectable backend factory.

One maintainable design:

```ts
export function createNativeBackend(
  nativeModule: NativeModuleLike,
): FFmpegKitBackend
```

Production:

```ts
export const nativeBackend =
  createNativeBackend(NativeFFmpegKitExtended);
```

Tests can supply a fake module.

Do this only if it remains a small semantic refactor.

An equivalent narrow test-only seam is acceptable.

Do not expose a public package API solely for testing.

---

# 19. G2 test cases

## Test G2-A — non-empty probe

Fake:

```text
getSessionJson -> valid session JSON
consumeSynchronousError -> ""
```

After abandonment reconciliation:

```text
isSessionAbandoned(id) == true
```

## Test G2-B — confirmed empty probe

Fake:

```text
getSessionJson -> ""
consumeSynchronousError -> ""
```

After reconciliation:

```text
isSessionAbandoned(id) == false
```

This is the only normal tombstone reclamation case.

## Test G2-C — Windows diagnostic with empty default

Fake Windows behavior:

```text
getSessionJson -> ""
consumeSynchronousError -> "synthetic getSessionJson failure"
```

Assert:

```text
reconcile catches diagnostic-derived Error
tombstone remains
```

This is the direct R41-F2 regression.

## Test G2-D — thrown synchronous probe

Fake:

```text
getSessionJson throws
```

Assert tombstone remains.

This covers Android/Apple-style synchronous exception behavior.

## Test G2-E — diagnostic consumed once

First probe:

```text
empty + diagnostic
```

Second independent successful synchronous call:

```text
no stale diagnostic from first probe
```

Use the fake module's `consumeSynchronousError` semantics to assert one
consumption.

## Test G2-F — abandon native action rejects

`abandonCreatedSession` adds the tombstone before the native action.

If the native action rejects:

```text
verify the existing intended fail-closed tombstone policy remains intact
```

Do not silently remove the tombstone merely because native cleanup failed.

## Test G2-G — clear success/failure

Success:

```text
native clear resolves
-> abandonment set clears
-> cancellation-intent set clears
```

Failure:

```text
native clear rejects
-> both sets remain
```

Retain existing tests if they already cover this behavior.

---

# 20. R41-G3 — complete session-handle acquisition audit

After G1/G2 implementation, build a code-review matrix.

Minimum rows:

| Operation | Handle source | Lifetime authority after fix | Clear-safe? | Release-safe? | Test |
| --- | --- | --- | --- | --- | --- |
| create FFmpeg | native create | registry operation lease + owned temp | yes | n/a | G1-C/D |
| create FFprobe | native create | registry operation lease + owned temp | yes | n/a | shared create helper |
| create FFplay | native create | registry operation lease + owned temp | yes | n/a | shared create helper |
| create MediaInfo | native create | registry operation lease + owned temp | yes | n/a | shared create helper |
| getSessionJson retained | retained map | retained lease + registry authority | yes | yes | retained suite |
| getSessionJson temporary | native lookup | registry lease + owned temp | yes | n/a | G1-A |
| getSessionState temporary | native lookup | registry lease + owned temp | yes | n/a | G1-A |
| history terminal | native lookup | registry lease + owned temp | yes | n/a | G1-B |
| history running | temporary -> retained | transfer transaction | yes | yes | focused history case |
| statistics | session guard + child guard | parent registry authority | yes | yes | nested test |
| media information | session guard + child handles | parent registry authority | yes | yes | G1-F |
| FFplay getters/actions | session guard | inherited common authority | yes | yes | focused FFplay |
| debug-log operations | session guard | inherited common authority | yes | yes | focused debug |
| release | retained entry | exclusive entry release + registry ordering | yes | n/a | retained suite |
| clear | global registry | exclusive barrier | n/a | serializes | G1-A..E |

Add any missing handle-bearing path found during review.

If a function stores a raw `Handle` outside the lexical lifetime of its guard or
lease, treat it as a blocker.

---

# 21. R41-G4 — documentation and comment guidance

Update comments only where they communicate the corrected ownership/error
contract.

Do not perform broad prose cleanup.

## 21.1 `FFmpegKitDynamicApi.cpp` registry-state comment

The top ownership comment must accurately state:

```text
retained entry lease:
  protects against per-session release

registry operation lease:
  protects all session-registry-backed handles against global clear

global clear:
  blocks new session-handle create/acquire operations
  waits all existing operations/releases
  clears native registry
  commits retained + history reset
  reopens only after full wrapper commit
```

Avoid generic phrases such as "thread-safe" without the actual protected
operation.

## 21.2 Temporary handle comments

Near the non-retained branch of `acquireSession()`, document:

```text
the temporary owning handle carries registry-clear protection for its entire
native-use lifetime
```

Near creation helpers, document:

```text
creation participates in the same registry barrier so native clear cannot retire
the handle before identity/history commit
```

## 21.3 `clearSessions()` commit comment

Explicitly mark the commit point.

Example semantics:

```text
The registry remains exclusive until native clear, retained ownership reset, and
local history reset are all complete.
```

## 21.4 `backend.native.ts` reconciliation comment

State:

```text
Only a diagnostic-free empty synchronous snapshot proves native absence.
Windows default return values after a caught native error are not evidence of
absence.
```

## 21.5 `NativeFFmpegKitExtended.ts` / backend helper

If useful, add one maintenance comment around `consumeSynchronousError()`:

```text
Windows synchronous native methods return default values on caught adapter
errors; native backend code must consume the same-call diagnostic before
interpreting those values.
```

Keep it internal/maintainer-focused.

## 21.6 Public docs

Do **not** update end-user API docs unless behavior changes.

If G1 chooses to make synchronous inspection explicitly fail during clear
instead of waiting, document that user-visible behavior in the relevant session
or `clearSessions()` JSDoc.

If G1 uses waiting/serialization and preserves current public semantics, no
public doc change is necessary.

---

# 22. R41-G5 — final bounded platform-native bridge review

After implementation and focused tests, perform a new code review against the
post-fix source.

Do not simply confirm the two original findings disappeared.

Review for defects introduced by the fix.

## 22.1 Shared RN registry lifetime

Search/read:

```text
HandleGuard
RetainedHandleLease
new SessionRegistry* authority
getSession
createSessionWith
createSessionWithArguments
createMediaInformationSessionFromPath
acquireSession
ensureRetainedSession
acquireHistorySession
releaseRetainedSession
getSessionsJson
getLastSessionJson
getStatisticsJson
getMediaInformationJson
getFFplaySession
clearSessions
```

Reject:

```text
unprotected raw session handle
registry lease released before native handle release
clear flag reopened before local state commit
double-counted lease
missing notify
condition-variable wait with impossible wakeup
lock-order cycle
native call under broad mutex without reentrancy proof
```

## 22.2 Native backend synchronous diagnostics

Read all of `backend.native.ts`.

Reject:

```text
raw synchronous TurboModule calls whose default value has semantic meaning
diagnostic not consumed
default ""/0/false interpreted as native state after an error
cross-call synchronous diagnostic assumptions
```

## 22.3 Error boundary

Preserve Review 40:

```text
Windows action Promise errors invocation-bound
Cxx AsyncPromise errors invocation-bound
synchronous Windows errors same-call only
no fail-fast/terminate
```

## 22.4 Callback lifetime

Recheck but do not rewrite:

```text
RN log bridge
RN FFplay Windows/Android/Apple
Flutter FFplay Windows/Linux/Android/Apple
```

Only report a finding if G1/G2 changed an assumption or an existing concrete
bug is established.

## 22.5 Dynamic loading

Verify:

```text
no dynamic symbol resolution reintroduced into noexcept destructor/cleanup
mandatory release/free cache unchanged
frame callback symbol pairs still commit atomically/fail closed
```

## 22.6 Texture/surface ownership

Verify no changes/regressions in:

```text
Flutter Windows async unregister retirement
Flutter Linux FlPixelBufferTexture
Flutter Android Surface/ANativeWindow
Flutter Apple texture callback lifecycle
RN Android Surface
RN Windows/Apple FFplay views
```

## 22.7 Pixel layout

Verify Review 40 packed-frame conversion remains unchanged.

No additional format work is required absent a concrete defect.

## 22.8 Apple duplicate sources

If G1/G2 does not change Apple-specific source files, preserve the current
parity result.

Do not report formatting/import-only differences.

---

# 23. Finding threshold for final audit

A new Review 41 finding must document:

```text
specific source path/lines
reachable interleaving or call path
violated ownership/error contract
concrete product consequence
why current deterministic tests do not already disprove it
```

Do not report:

```text
style
naming
test organization
"might be nicer"
unsupported theoretical race
framework-required platform difference
```

The objective is actual bridge closure, not continued iteration.

---

# 24. Local validation after implementation

The current Review 41 task did not execute tests.

Luna implementation must run affected local noninteractive validation only
after focused tests are green.

No hosted acceptance CI.

Use only existing local frozen ABI `0.11.2`.

## 24.1 Focused shared C++ first

Compile/run the deterministic registry lifetime executable on:

```text
Windows
WSL Linux
```

Required cases include G1-A through G1-H as implemented.

Then run existing native bridge source/behavior suites.

## 24.2 React Native TypeScript/Node

Run:

```text
npm run typecheck
npm run test:compile
focused native-backend reconciliation tests
focused native-bridge lifetime tests
Windows error-transport tests
session/history ownership tests affected by G1/G2
```

Do not count source regex alone as the lifetime acceptance gate.

## 24.3 Windows

Primary platform because both findings have direct Windows consequences.

Run locally:

```text
shared C++ lifetime executable
native backend diagnostic tests
React Native Windows local build
```

No interactive app launch.

## 24.4 Android on Windows

Because G1 modifies shared C++:

```text
React Native Android local Gradle/CMake build
```

Use existing local AAR/native artifacts.

Do not use WSL Android as a substitute.

## 24.5 WSL Linux

Run the shared C++ lifetime executable under WSL.

React Native has no Linux app target in this repository, so do not invent one.

No Flutter Linux rebuild is required unless Flutter production code changes.

## 24.6 Apple last

Because G1 modifies shared C++ used by Apple Cxx TurboModule:

```text
React Native iOS local build
React Native tvOS local build
React Native macOS local build
```

Use existing local universal XCFrameworks.

No simulator/device interaction.

## 24.7 Flutter

R41 findings are React Native bridge defects.

If Luna does not modify Flutter production/build configuration:

```text
do not rerun the full Flutter platform matrix merely for ceremony
```

Preserve the verified Review 40 Flutter evidence.

If final code review finds and fixes a real Flutter defect, run only the
affected Flutter local gates and document why.

---

# 25. Required test-result truthfulness

For every command, record:

```text
exact command
platform/working directory
exit result
actual test count where available
whether it was acceptance or diagnostic
```

Do not call:

```text
timeout
killed process
compile skipped
platform unavailable
source inspection
```

a passing executable test.

If a command is corrected after an environment mistake, record both attempts.

---

# 26. Final source freeze

Only after:

```text
R41-F1 fixed
R41-F2 fixed
focused executable tests green
affected local builds green
final bounded code review clean
```

freeze the wrapper.

Procedure:

1. Verify `libs/libffmpegkit` gitlink is unchanged.
2. Verify no builder checkout change.
3. Clean task-owned generated output.
4. Commit/push final wrapper changes to `origin/dev-wasm`.
5. Record exact full 40-character wrapper SHA.
6. Dispatch exactly one wrapper source-snapshot workflow for that SHA.
7. Do not dispatch hosted test/build workflows.
8. Do not produce a builders/native snapshot.
9. Download and verify the wrapper snapshot:
   - artifact digest;
   - `source.tar.gz.sha256`;
   - all `SHA256SUMS`;
   - `SUBMODULES.txt`;
   - `SYMLINKS.tsv`;
   - `snapshot-metadata.json`;
   - `runtimeExecution=false`.
10. Treat any mailbox/tracker publication commit as metadata, not source authority.

---

# 27. Required tracker/final report updates

Record:

```text
Review 41 starting snapshot SHA/run/artifact
R41-F1 disposition
R41-F2 disposition
chosen registry-operation lifetime design
global clear commit point
temporary-handle clear policy
creation-vs-clear ordering
diagnostic-aware abandonment policy
focused test names/results
Windows/Android/WSL/Apple local build results
any diagnostic failures and reconciliation
exact final wrapper SHA
source snapshot workflow/artifact/digests
frozen submodule SHA
runtimeExecution=false
```

Do not state "all platforms pass" if a listed platform was not actually run.

---

# 28. Luna implementation order

Use this order.

```text
1. Re-read Review 41 report and current FFmpegKitDynamicApi.cpp.

2. Design registry-operation lifetime authority:
   - admission
   - active operation count
   - retained lease interaction
   - release interaction
   - global clear exclusivity
   - commit point
   - lock order.

3. Implement registry operation lease.

4. Migrate temporary getSession acquisitions.

5. Migrate all session creation helpers.

6. Audit/promote acquireHistorySession transitions.

7. Keep parent registry authority alive through nested media/statistics work.

8. Change clearSessions so exclusive state remains set through:
   native clear
   retained ownership reset
   history reset.

9. Add G1 deterministic C++ tests.

10. Fix backend.native abandonment reconciliation to use the synchronous
    diagnostic helper.

11. Add G2 behavioral backend tests.

12. Run focused tests.

13. Update technical comments/docs after semantics stabilize.

14. Perform the full bounded Review 41 post-fix code review.

15. Run affected local platform validation:
    Windows -> Android on Windows -> WSL shared C++ -> Apple last.

16. Re-review final changed source.

17. Freeze exact wrapper SHA.

18. Dispatch/download/verify one wrapper-only source snapshot.

19. Stop automated work; interactive runtime validation remains user-owned.
```

---

# 29. Anti-patterns Luna must reject

## 29.1 Check-then-use without a lease

Unsafe:

```cpp
lock
if (!clearSessionsInProgress) handle = getSession(id)
unlock
use handle
```

Clear can start immediately after unlock.

## 29.2 Retained-only counting

Do not keep:

```text
global clear waits activeRetainedBorrows only
```

while temporary owning session handles remain outside the count.

## 29.3 Open barrier before local history commit

Do not:

```text
native clear
clear flag = false
notify
historyRecords.clear()
```

## 29.4 Hold one global mutex over all native work

Do not substitute broad locking for lifetime authority without reentrancy proof.

## 29.5 Erase metadata as synchronization

Removing a map/history entry does not make an already borrowed native pointer
safe.

## 29.6 Raw Windows synchronous probe

Do not directly call a Windows sync TurboModule method when:

```text
"" / 0 / false
```

has semantic meaning.

Use the common synchronous diagnostic helper.

## 29.7 JS-only concurrency fix

R41-F1 is in the shared C++ lifetime layer.

A JS mutex or Promise queue is not sufficient.

## 29.8 Source-only concurrency test

A source assertion such as:

```text
clear flag appears before getSession
```

does not prove handle validity.

Use deterministic C++ barriers.

## 29.9 Native ABI change

Not permitted.

---

# 30. Definition of done

Review 41 is closed only if every item is true:

```text
[ ] Temporary native session handles participate in the global clear lifetime authority.
[ ] Session creation participates in the same authority.
[ ] Retained per-session release behavior remains correct.
[ ] Global clear blocks new session-registry operations before destructive clear.
[ ] Global clear waits all existing protected session-handle operations.
[ ] Global clear remains exclusive through retained-map and local-history reset.
[ ] No native session handle can be invalidated while a bridge operation uses it.
[ ] History projection has no temporary-handle clear race.
[ ] Media/statistics/FFplay/debug paths inherit the common authority.
[ ] Abandonment reconciliation uses diagnostic-aware synchronous native reads.
[ ] Windows native probe errors preserve abandonment tombstones.
[ ] Confirmed diagnostic-free native absence still reclaims tombstones.
[ ] Windows Promise action error semantics remain invocation-bound.
[ ] Windows synchronous diagnostics remain same-call only.
[ ] RAII cleanup remains non-throwing and resolver-free.
[ ] Flutter Windows texture retirement remains clean.
[ ] Flutter Linux pixel-buffer ownership remains clean.
[ ] Flutter/RN Android surfaces remain clean.
[ ] Flutter/RN Apple callback ownership/parity remains clean.
[ ] Packed pixel normalization remains clean.
[ ] Deterministic C++ concurrency regressions pass.
[ ] Native-backend fail-closed behavioral regressions pass.
[ ] Affected local Windows/Android/WSL/Apple gates pass using local ABI 0.11.2.
[ ] No hosted acceptance CI is used.
[ ] No native ABI is downloaded, reviewed, changed, rebuilt, or published.
[ ] Final bounded code review finds no substantive High/Medium bridge defect.
[ ] Exact final wrapper SHA is snapshotted once and verified.
```

If any item remains false, do not declare platform-native bridge closure.
