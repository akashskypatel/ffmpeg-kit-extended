# Review 42 — Flutter + React Native Platform-Native Bridge Code Review

**Project:** FFmpegKitExtended  
**Review type:** frozen-source platform-native code review; substantive findings only  
**Date:** 2026-10-01  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch represented by snapshot:** `dev-wasm`  
**Frozen wrapper source:** `510fabb3e58730d211dddc78d343a7ed377eba2c`  
**Snapshot workflow:** `36933905787`  
**Snapshot artifact:** `review41-source-snapshot-36933905787`  
**Artifact ID:** `11197296864`  
**Outer artifact SHA-256:** `4d8d4d3dc3f993c3869388f7ab5556762e61825ef498d3a2dcfeda66d40fda96`  
**Embedded `source.tar.gz` SHA-256:** `b96fd69e804964312f020372b242bffa352fa5bf9bc8745a1a0a9d48610cca0f`  
**Manifest:** **1,087/1,087 verified**  
**Symlinks:** `0`  
**Snapshot bytes:** `27,776,092`  
**Recursive submodule:** `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`  
**Native ABI/runtime:** `0.11.2`, frozen/read-only and not independently downloaded or reviewed

---

# 1. Review authority

The Review 41 tracker freezes the completed wrapper implementation at:

```text
510fabb3e58730d211dddc78d343a7ed377eba2c
```

with wrapper-only source snapshot workflow:

```text
36933905787
```

and artifact:

```text
review41-source-snapshot-36933905787
artifact ID: 11197296864
```

The source artifact was retrieved through the repository's source-snapshot
workflow artifact surface and verified before review.

Verification:

```text
outer artifact SHA-256:
4d8d4d3dc3f993c3869388f7ab5556762e61825ef498d3a2dcfeda66d40fda96

embedded source.tar.gz SHA-256:
b96fd69e804964312f020372b242bffa352fa5bf9bc8745a1a0a9d48610cca0f

snapshot-metadata.snapshot_sha:
510fabb3e58730d211dddc78d343a7ed377eba2c

snapshot-metadata.runtimeExecution:
false

SHA256SUMS:
1087/1087 verified

SYMLINKS.tsv:
0 entries

SUBMODULES.txt:
b74da2c5d1e294b87d15d73a6687393729e932b3 libs/libffmpegkit (b74da2c)
```

No native/builders snapshot was downloaded or reviewed.

The frozen native ABI/runtime remains:

```text
version: 0.11.2
submodule: b74da2c5d1e294b87d15d73a6687393729e932b3
```

---

# 2. Review boundary

This was **code review only**.

No tests, builds, simulator/device launches, interactive applications, browser
smokes, remote CI, source mutation, or runtime execution were performed.

Reviewed platform-native surfaces:

```text
Flutter
  flutter/native/
  flutter/windows/
  flutter/linux/
  flutter/android/
  flutter/ios/
  flutter/macos/

React Native
  react-native/cpp/
  react-native/windows/
  react-native/android/
  react-native/ios/
  react-native/appletvos/
  react-native/macos/

Native-facing TypeScript
  react-native/src/NativeFFmpegKitExtended.ts
  react-native/src/platform/backend.native.ts
  react-native/src/platform/native-session-reconciliation.ts
  related session/history/cancellation wrappers where required
```

Excluded:

```text
formatting
style
naming preferences
procedural/tracker-only issues
documentation-only differences
test-file organization preferences
speculative hardening
framework-required platform differences
```

A finding must have:

```text
a reachable call/interleaving
a concrete violated ownership/concurrency/error invariant
a product consequence
source evidence
```

---

# 3. Change-set orientation from Review 41

The exact Review 42 source was compared with the exact Review 41 starting
snapshot (`7ba4a60621c77ac9add7328e8c27b7394f2cdb11`).

Product-code changes are limited to the intended Review 41 remediation:

```text
react-native/cpp/FFmpegKitDynamicApi.cpp
react-native/src/platform/backend.native.ts
react-native/src/platform/native-session-reconciliation.ts
```

plus corresponding tests and tracker/review files.

All platform-specific native bridge directories are byte-identical to the
Review 41 source:

| Surface | Files checked | Changed |
| --- | ---: | ---: |
| `flutter/native` | 7 | 0 |
| `flutter/windows` | 8 | 0 |
| `flutter/linux` | 7 | 0 |
| `flutter/android` | 13 | 0 |
| `flutter/ios` | 18 | 0 |
| `flutter/macos` | 18 | 0 |
| `react-native/windows` | 20 | 0 |
| `react-native/android` | 7 | 0 |
| `react-native/ios` | 3 | 0 |
| `react-native/appletvos` | 3 | 0 |
| `react-native/macos` | 3 | 0 |

The highest-risk Review 42 surface is therefore the new shared React Native
registry-operation lifetime code.

---

# 4. Executive disposition

Review 42 found **one substantive platform-native bridge defect**.

| ID | Severity | Surface | Finding |
| --- | --- | --- | --- |
| **R42-F1** | **High** | React Native shared C++ session/history lifetime | The new global session-operation lease is not composition-safe. History APIs acquire one outer operation lease and then reacquire the same non-reentrant clear barrier in nested helpers. If `clearSessions()` becomes exclusive between those acquisitions, clear waits for the outer lease while the history path waits for clear to finish. `acquireHistorySession()` also retains an old `clearSessionsInProgress` wait after it already owns an admitted operation lease, creating a second permanent wait cycle during Running-session promotion. |

No native ABI change is required.

The Review 41 fixes for:

```text
temporary handle vs clear
session creation vs clear
diagnostic-aware abandonment reconciliation
clear commit through local history reset
```

are present and otherwise coherent.

---

# 5. R42-F1 — the registry operation lease deadlocks when history projection composes nested acquisitions

**Severity:** High  
**Primary file:** `react-native/cpp/FFmpegKitDynamicApi.cpp`

## 5.1 Correct design principle introduced by Review 41

The new registry authority correctly establishes this global model:

```text
Open:
  new session operations may be admitted

Clearing:
  new session operations are blocked
  clear waits activeSessionOperations == 0
```

`acquireSessionOperation()`:

```cpp
SessionOperationLease acquireSessionOperation() {
  std::unique_lock<std::mutex> lock(sessionHandlesMutex);
  sessionHandlesCondition.wait(lock, [] { return !clearSessionsInProgress; });
  ++activeSessionOperations;
  return SessionOperationLease(true);
}
```

`clearSessions()`:

```cpp
std::unique_lock<std::mutex> lock(sessionHandlesMutex);
sessionHandlesCondition.wait(lock, [] { return !clearSessionsInProgress; });
clearSessionsInProgress = true;
sessionHandlesCondition.wait(
    lock, [] { return activeSessionOperations == 0; });
```

That model is sound only if an already-admitted operation can finish without
trying to re-enter the admission gate.

History projection violates that requirement.

---

# 6. Deadlock A — outer history operation versus nested `acquireSessionOperation()`

`getSessionsJson()` begins with:

```cpp
auto operation = acquireSessionOperation();
const auto records = visibleHistoryRecords(kind);
...
HandleGuard guard = acquireHistorySession(record.sessionId);
```

`getLastSessionJson()` has the same shape.

`acquireHistorySession()` immediately calls:

```cpp
HandleGuard guard = acquireSession(id);
```

and `acquireSession()` immediately performs:

```cpp
auto operation = acquireSessionOperation();
```

Therefore one logical history transaction acquires the global operation
authority twice.

## 6.1 Concrete deadlock

Thread H — history getter:

```text
getSessionsJson()
-> acquireSessionOperation()
-> activeSessionOperations = 1
-> snapshot visible history
```

Thread C — clear:

```text
clearSessions()
-> obtains sessionHandlesMutex
-> clearSessionsInProgress = true
-> waits activeSessionOperations == 0
```

Thread H continues:

```text
-> acquireHistorySession(first/next record)
-> acquireSession()
-> acquireSessionOperation()
-> waits clearSessionsInProgress == false
```

Permanent cycle:

```text
clear waits for H's outer operation lease to be destroyed

H cannot destroy the outer lease until getSessionsJson returns

H cannot return because its nested operation acquisition waits for clear

clear cannot finish because H still owns the outer lease
```

This is a real lock-order/lifetime cycle, not a speculative timing issue.

---

# 7. Deadlock B — Running-history promotion re-waits the clear gate after admission

There is a second independent wait point inside the same history helper.

`acquireHistorySession()` first calls `acquireSession(id)`.

That call already returns a `HandleGuard` carrying a live
`SessionOperationLease`.

For an owned temporary handle in Running state, the helper later does:

```cpp
std::unique_lock<std::mutex> lock(sessionHandlesMutex);
sessionHandlesCondition.wait(
    lock, [] { return !clearSessionsInProgress; });
```

This wait is invalid under the new model.

Once an operation has been admitted:

```text
clear is allowed to publish Clearing
clear must wait for the admitted operation to finish
the admitted operation must continue to completion
```

It must **not** wait for `clearSessionsInProgress` to become false again.

## 7.1 Concrete deadlock

Thread H:

```text
acquireHistorySession(id)
-> acquireSession(id)
-> operation lease admitted
-> activeSessionOperations = 1
-> obtain temporary native handle
-> native state read says Running
```

Thread C starts before H reaches the promotion mutex:

```text
clearSessions()
-> clearSessionsInProgress = true
-> waits activeSessionOperations == 0
```

Thread H then reaches the old wait:

```text
wait clearSessionsInProgress == false
```

Again:

```text
C waits H to release operation
H waits C to clear the barrier
```

Neither can progress.

This deadlock exists even if the top-level history getter did not hold an extra
outer lease.

---

# 8. Product consequence

The affected public native history surfaces are:

```text
getSessionsJson(kind)
getLastSessionJson(kind)
```

and every higher-level React Native history API that delegates to them.

On an affected interleaving, the native call does not merely return a transient
error.

It can block permanently until process teardown.

Potential user-visible consequences include:

```text
hung synchronous history call
blocked JavaScript/native bridge thread
clearSessions() Promise never settling
application UI/event-loop stall depending on platform scheduling
session-history cleanup never completing
subsequent queued work unable to progress
```

The same shared C++ implementation is used by:

```text
Windows
Android
iOS
tvOS
macOS
```

so the defect is cross-platform at the shared bridge layer.

---

# 9. Why the Review 41 validation did not disprove the defect

The Review 41 plan explicitly required a deterministic:

```text
terminal history projection vs clear
```

case.

The final executable lifetime harness covers:

```text
retained borrower vs release
retained borrower vs clear
duplicate release
pre-release state retry
clear failure retry
temporary getter vs clear
active session creation vs clear
creation after clear becomes exclusive
```

but it does not execute a history-projection/clear interleaving.

The source-contract test does assert that:

```text
getSessionsJson contains acquireSessionOperation
getLastSessionJson contains acquireSessionOperation
```

but that structural check verifies the presence of the exact outer lease that
participates in the deadlock; it does not prove composability.

No existing executable test exercises:

```text
outer history operation lease
+
nested acquireSessionOperation
+
concurrent clear
```

or:

```text
admitted Running-history acquisition
+
clear becomes exclusive
+
old inner clear wait
```

Therefore the green Review 41 focused results do not contradict R42-F1.

---

# 10. Required implementation semantics

The registry barrier needs one additional invariant:

> **Once a top-level bridge operation is admitted, every nested helper used by
> that transaction must reuse the same admission authority. It must never wait
> for the clear gate again.**

Equivalent formulation:

```text
clearSessionsInProgress is an admission gate.

It blocks operations that have not started.

It does not suspend operations that were already admitted before clear became
exclusive.

Clear waits for those admitted operations to finish.
```

This invariant must be explicit in code and comments.

---

# 11. Preferred remediation direction

Preserve one registry operation token per **logical top-level transaction**.

Do not solve the problem by removing clear protection from history.

History projection should remain atomic with respect to destructive clear.

Preferred architecture:

```text
SessionOperationLease
  owns one shared admission token

copies/children:
  share that same token
  do not increment activeSessionOperations again

last token release:
  decrements activeSessionOperations exactly once
```

A practical representation is a shared operation token:

```cpp
struct SessionOperationToken {
  ~SessionOperationToken() noexcept {
    releaseSessionOperation();
  }
};

class SessionOperationLease {
  std::shared_ptr<SessionOperationToken> token_;
};
```

`acquireSessionOperation()`:

```text
wait until Open
increment activeSessionOperations once
create one token
return lease(token)
```

Copies of the lease:

```text
share token
do not increment activeSessionOperations
```

Nested history helpers receive the existing lease instead of calling
`acquireSessionOperation()` again.

An equivalent explicit borrowed-scope design is acceptable if it makes misuse
difficult and proves the same lifetime invariant.

---

# 12. Required history helper shape

Refactor toward a distinction between:

```text
top-level acquisition
nested acquisition under an existing operation
```

Conceptually:

```cpp
HandleGuard acquireSession(std::int64_t id) {
  auto operation = acquireSessionOperation();
  return acquireSessionWithinOperation(id, operation);
}

HandleGuard acquireSessionWithinOperation(
    std::int64_t id,
    const SessionOperationLease &operation);
```

and:

```cpp
HandleGuard acquireHistorySessionWithinOperation(
    std::int64_t id,
    const SessionOperationLease &operation);
```

Then:

```cpp
std::string getSessionsJson(...) {
  auto operation = acquireSessionOperation();
  ...
  auto guard =
      acquireHistorySessionWithinOperation(record.sessionId, operation);
}
```

`getLastSessionJson()` should use the same pattern.

The nested helper must not reacquire the global admission barrier.

---

# 13. Remove the stale post-admission clear wait

Inside Running-history promotion, remove the semantic equivalent of:

```cpp
sessionHandlesCondition.wait(
    lock, [] { return !clearSessionsInProgress; });
```

when the current function already holds a valid operation lease.

A valid already-admitted operation is allowed to:

```text
lock sessionHandlesMutex
inspect/insert retained entry
release temporary handle
finish serialization
release its operation token
```

even while `clearSessionsInProgress == true`.

That is how clear drains existing work safely.

Do not replace the wait with:

```cpp
if (clearSessionsInProgress) throw ...
```

That would still break the contract of an admitted operation and can strand
partially completed history transactions.

---

# 14. Preserve the Review 41 lifetime fixes

Do not regress:

```text
temporary getSession handle vs clear
session creation vs clear
retained borrow vs clear
retained release vs clear
clear exclusivity through historyRecords.clear()
native clear failure reopening the barrier
diagnostic-aware abandonment reconciliation
```

Specifically preserve `HandleGuard` destruction ordering:

```text
release owned native handle
release retained lease
release registry operation token last
```

so native handle cleanup remains protected from global clear.

---

# 15. Deterministic regression tests required

The fix is not complete with source assertions alone.

Use the compiled fake-resolver C++ harness.

Use condition variables/barriers/latches as the success oracle.

A timeout may exist only as a failure watchdog.

Do not use arbitrary sleeps as the primary proof.

## 15.1 Test A — full history projection already admitted when clear starts

Prepare at least two visible history records.

History thread:

```text
getSessionsJson("all")
-> acquires outer operation token
-> serializes first record
-> pause before acquiring/serializing second record
```

Clear thread:

```text
clearSessions()
-> publishes Clearing
-> waits on the one admitted history operation
```

Release the history thread.

Required assertions:

```text
history call reaches second record without waiting for clear to reopen
history call completes
clear enters native clear only after the history transaction completes
no deadlock
active operation count returns to zero
```

This directly catches the outer-lease/nested-acquisition cycle.

## 15.2 Test B — last-session projection versus clear

Repeat with:

```text
getLastSessionJson(...)
```

because it has its own top-level implementation and must not regress separately.

## 15.3 Test C — Running-history promotion after clear becomes exclusive

Create a visible Running session not yet represented by a retained execution
entry.

History thread:

```text
acquire history temporary handle
enter fake state read
pause
```

Clear thread:

```text
publish Clearing
wait active operations
```

Release fake state read.

Required:

```text
history thread promotes/reuses retained ownership without waiting for
clearSessionsInProgress == false
history transaction completes
clear then proceeds
no deadlock
temporary handle released/transferred exactly once
retained borrow count returns to expected value
```

This catches the stale inner clear wait.

## 15.4 Test D — mixed retained + temporary history records

History contains:

```text
one retained Running record
one temporary terminal/Created record
```

Start clear while the projection is in progress.

Assert:

```text
both records obey one top-level operation authority
no nested admission
no premature native clear
no double release
no deadlock
```

## 15.5 Test E — clear starts before history call

Start clear and pause inside the native clear function.

Then start:

```text
getSessionsJson
getLastSessionJson
```

Required:

```text
new history calls remain blocked at top-level admission
they do not enter history helper/native lookup
after clear fully commits, they resume against post-clear history
```

This preserves the intended admission behavior.

## 15.6 Test F — clear failure

With a history caller waiting behind clear:

```text
native clear throws/fails through existing resolver seam
```

Assert:

```text
clear barrier reopens
waiting history operation is admitted
existing retained/history state remains usable
no operation count leak
```

## 15.7 Test G — existing Review 41 regression matrix

Keep all existing deterministic cases green:

```text
active retained borrow vs release
new borrow after release starts
duplicate release
pre-release state failure retry
retained borrow vs clear
temporary getter vs clear
active creation vs clear
creation after clear becomes exclusive
native clear failure retry
```

---

# 16. Structural/source-contract test guidance

Source-contract tests are secondary.

Useful structural assertions after the executable regression exists:

```text
getSessionsJson acquires one top-level operation authority
getLastSessionJson acquires one top-level operation authority
history nested helper receives/reuses that authority
acquireHistorySession no longer waits for !clearSessionsInProgress after
admission
nested history helper does not call acquireSessionOperation
```

Do not assert brittle exact line ordering.

Do not make:

```text
"getSessionsJson contains acquireSessionOperation"
```

the primary concurrency proof.

---

# 17. Documentation/comment guidance

Update only comments that communicate ownership/concurrency semantics.

## 17.1 Registry authority comment

Clarify:

```text
clearSessionsInProgress is an admission gate.

Operations admitted before clear publishes exclusivity are allowed to finish.

Clear waits for their shared operation tokens to drain.

Nested helpers reuse the already-admitted token and never re-enter the gate.
```

## 17.2 `SessionOperationLease`

Document whether the implementation is:

```text
shared token
or
borrowed existing scope
```

and explicitly state:

```text
nested use does not create a second activeSessionOperations count
```

## 17.3 History projection

Near `getSessionsJson()` / `getLastSessionJson()`:

```text
one registry operation spans history snapshot selection and native
serialization so destructive clear cannot split the projection
```

## 17.4 Running-history promotion

Explain:

```text
promotion runs under an already-admitted registry operation and therefore must
not wait for global clear; clear is waiting for this transaction to finish
```

## 17.5 Public API docs

No public API behavior needs to change.

Do not add end-user documentation about internal lock/lease mechanics.

---

# 18. Review of the Review 41 diagnostic-aware reconciliation fix

The Review 41 abandonment correction is present:

```ts
candidate =>
  invokeSynchronousNative<string>(
    'getSessionJson',
    [candidate],
  )
```

The helper preserves the tombstone when the probe throws.

All raw synchronous native backend reads with semantic default values still
route through `invokeSynchronousNative()`.

No new substantive finding was established in this area.

---

# 19. Retained shared C++ areas with no additional finding

The following Review 41 behavior remains sound outside R42-F1:

```text
temporary owning handles carry registry protection
session creation carries registry protection
retained entry borrows carry per-session + registry lifetime
retained release is serialized and clear-protected
HandleGuard releases owned native handle before dropping registry authority
clear remains exclusive through retained-map and local-history reset
native clear failure reopens the barrier
mandatory release/free functions remain cached before ownership begins
RAII cleanup performs no throwing dynamic symbol lookup
```

The problem is composability of the operation authority inside history
projection, not loss of the Review 41 protection itself.

---

# 20. Platform-specific native surfaces with no new substantive finding

All files in these directories are byte-identical to Review 41:

```text
Flutter Windows/Linux/Android/iOS/macOS
React Native Windows/Android/iOS/tvOS/macOS
```

A fresh bounded source pass did not establish another threshold finding.

## 20.1 React Native Windows

Preserved:

```text
invocation-bound ReactPromise action failures
same-call synchronous diagnostic path
no fail-fast operational error path
log payload copy-before-release
retired callback state lifetime
FFplay latest-owner frame routing
```

R42-F1 is shared C++ below this module.

## 20.2 React Native Android

Preserved:

```text
single process-wide Surface owner
stale view cannot clear a newer owner's target
Java Surface cleanup
native target replacement
```

No new surface ownership defect established.

## 20.3 React Native Apple

iOS/tvOS/macOS preserve:

```text
complete callback API check
latest-owner semantics
previous owner stops accepting frames before replacement
unregister/drain before detachment
locked pending-frame lifetime
main-thread display dispatch
```

No substantive current-ABI parity defect established.

## 20.4 Flutter Windows

Preserved:

```text
asynchronous external texture retirement
callback-captured TextureState lifetime through unregister completion
canonical packed RGBA normalization
```

No new finding.

## 20.5 Flutter Linux

Preserved:

```text
FlPixelBufferTexture engine texture ownership
CPU frame-store lifetime
coalesced frame notifications
canonical packed RGBA normalization
```

No new finding.

## 20.6 Flutter Android

Preserved:

```text
SurfaceTextureEntry ownership
Java Surface ownership
ANativeWindow pointer ownership
process-global FFplay target coordination
```

No new finding.

## 20.7 Flutter Apple

Preserved:

```text
callback unregister/drain
retained texture userdata balance
CocoaPods/SwiftPM behavioral parity
BGRA conversion for accepted packed formats
opaque alpha repair for rgb0/bgr0
```

No new finding.

---

# 21. Review 42 remediation goals

| Goal | Required result |
| --- | --- |
| **R42-G1** | Make the registry operation authority composition-safe: one admitted top-level operation must be reusable by nested history/session helpers without re-entering the global clear gate |
| **R42-G2** | Remove every post-admission wait on `clearSessionsInProgress`; existing admitted operations must finish while clear waits for them |
| **R42-G3** | Add deterministic executable history-vs-clear regressions covering both nested-admission and Running-history-promotion deadlock windows |
| **R42-G4** | Update only semantic registry/history comments and preserve all Review 41 lifetime/error fixes plus unchanged Flutter/RN platform-native invariants |
| **R42-G5** | Perform the final bounded post-fix bridge audit; if clean, run only affected local noninteractive RN shared/platform gates and freeze one wrapper-only exact-SHA source snapshot |

---

# 22. Review 42 closeout

```text
Wrapper source authority: VERIFIED
Outer artifact digest: VERIFIED
Embedded source archive: VERIFIED
Manifest: 1087/1087
Symlinks: 0
runtimeExecution: false
Frozen submodule provenance: VERIFIED

Native ABI separately downloaded: NO
Native ABI reviewed: NO
Native ABI source change required: NO

Code review only: YES
Tests/builds/runtime executed by Review 42: NO
Repository mutation by Review 42: NO

Substantive findings: 1
  R42-F1 High

Pedantic findings reported: 0
Procedural findings reported: 0
Documentation-only findings reported: 0

Disposition:
NOT YET PLATFORM-NATIVE BRIDGE CLEAN.

The remaining defect is narrow but release-blocking: the new registry lifetime
authority must become composable for history projection without losing global
clear atomicity.
```
