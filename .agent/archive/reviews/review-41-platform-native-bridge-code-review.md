# Review 41 — Flutter + React Native Platform-Native Bridge Code Review

**Project:** FFmpegKitExtended  
**Review type:** frozen-source platform-native code review; substantive findings only  
**Date:** 2026-10-01  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch represented by snapshot:** `dev-wasm`  
**Frozen wrapper source:** `7ba4a60621c77ac9add7328e8c27b7394f2cdb11`  
**Snapshot workflow:** `36923122934`  
**Snapshot artifact:** `runtime-lock-race-source-snapshot-36923122934`  
**Artifact ID:** `11192891900`  
**Outer artifact SHA-256:** `11d36d8cf5b99514fec03a060a8c9017ec33ec484ddc4bd9f0920bcfa0e56f07`  
**Embedded `source.tar.gz` SHA-256:** `c931871b883012e50c99c01dcbf17cdc22f4167daf11b00ff0561f79466cd6cb`  
**Manifest:** **1,083/1,083 verified**  
**Symlinks:** `0`  
**Snapshot bytes:** `27,695,855`  
**Recursive submodule:** `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`  
**Native ABI/runtime:** `0.11.2`, frozen/read-only and not independently downloaded/re-reviewed

---

# 1. Review authority

The tracker records Review 40 G5 closed at wrapper SHA
`ceb290999a637ed670ab84687865834c6c7a2813` with a verified wrapper-only source
snapshot.

A later wrapper-only source snapshot was created after the Windows runtime
packaging cleanup at:

```text
7ba4a60621c77ac9add7328e8c27b7394f2cdb11
```

That follow-up explicitly did not change the frozen native ABI or React Native
native bridge. Review 41 nevertheless uses the **latest tracker-frozen wrapper
snapshot**, `7ba4a606...`, so this review covers the exact newest frozen wrapper
tree rather than assuming the earlier Review 40 tree remains current.

The source artifact was retrieved through the GitHub Actions artifact surface
described by the repository snapshot workflow.

Verification:

```text
artifact digest:
11d36d8cf5b99514fec03a060a8c9017ec33ec484ddc4bd9f0920bcfa0e56f07

embedded source.tar.gz:
c931871b883012e50c99c01dcbf17cdc22f4167daf11b00ff0561f79466cd6cb

snapshot-metadata.snapshot_sha:
7ba4a60621c77ac9add7328e8c27b7394f2cdb11

snapshot-metadata.runtimeExecution:
false

SHA256SUMS:
1083/1083 verified

SYMLINKS.tsv:
0 entries

SUBMODULES.txt:
b74da2c5d1e294b87d15d73a6687393729e932b3 libs/libffmpegkit (b74da2c)
```

No native/builders snapshot was downloaded or reviewed.

---

# 2. Review boundary

This was **code review only**.

No tests, builds, runtime execution, simulator/device launch, browser smoke,
remote CI, or repository mutation were performed.

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
  react-native/src/platform/backend.native.ts
  react-native/src/platform/backend-registry.ts
  native-facing session/config wrappers where required to establish semantics
```

The frozen `libs/libffmpegkit` source was treated only as recorded provenance,
not as a Review 41 review target.

Excluded:

```text
formatting
style
naming preferences
procedural/tracker-only observations
documentation-only differences
test-file organization preferences
speculative future hardening
platform-required implementation differences with no product consequence
```

A finding must have a concrete execution path and a correctness, ownership,
lifetime, or error-boundary consequence.

---

# 3. Executive disposition

The latest frozen wrapper is **not yet platform-native bridge clean**.

Review 41 found two substantive defects:

| ID | Severity | Surface | Finding |
| --- | --- | --- | --- |
| **R41-F1** | **High** | React Native shared C++ bridge; directly reachable on Windows | The Review 40 global `clearSessions()` barrier protects retained leases/releases only. Temporary owning session handles and session-creation transactions are outside the barrier, so native registry clear can invalidate a handle while a getter/history/create path still uses it. The barrier also reopens before local history is cleared, allowing post-clear work to race with the wrapper history reset. |
| **R41-F2** | **Medium-High** | React Native Windows native backend | Abandonment reconciliation directly calls raw `NativeFFmpegKitExtended.getSessionJson()` instead of the diagnostic-aware synchronous bridge helper. A Windows native probe error is converted to the default empty string, which reconciliation interprets as confirmed absence and uses to delete the anti-resurrection tombstone. The native diagnostic is lost instead of preserving fail-closed state. |

No native ABI change is required.

---

# 4. R41-F1 — the global clear barrier does not protect temporary owning session handles or creation transactions

**Severity:** High  
**Primary file:** `react-native/cpp/FFmpegKitDynamicApi.cpp`

## 4.1 Intended Review 40 invariant

The current source comment says the registry clear is a process-wide lifetime
barrier:

```text
Clear is a registry-wide barrier:
  stops new acquisition/release transactions
  waits for all leases and release transactions
  calls the native clear entrypoint
  discards retained map/history afterward
```

That is the correct intended invariant.

The implementation currently enforces it only for **retained** handles.

## 4.2 Retained handles are correctly protected

A retained session acquisition:

```cpp
HandleGuard acquireSession(std::int64_t id) {
  std::unique_lock<std::mutex> lock(sessionHandlesMutex);
  sessionHandlesCondition.wait(lock, [] { return !clearSessionsInProgress; });

  const auto it = retainedSessionHandles.find(id);
  if (it != retainedSessionHandles.end()) {
    if (it->second->releasing) {
      throw std::runtime_error("Session handle release is already in progress");
    }
    ++it->second->activeBorrows;
    ++activeRetainedBorrows;
    return HandleGuard(RetainedHandleLease(it->second));
  }

  return HandleGuard(getSession(id), true);
}
```

For the retained branch, `activeRetainedBorrows` keeps global clear out until the
lease is destroyed.

That closes the Review 40 retained-pointer race.

## 4.3 The non-retained branch immediately leaves the clear authority

The final branch is:

```cpp
return HandleGuard(getSession(id), true);
```

The call happens while `sessionHandlesMutex` is still held, but once
`acquireSession()` returns:

```text
the mutex is unlocked
the temporary owning native HandleGuard remains alive
activeRetainedBorrows is still zero
```

The caller then uses that owning temporary outside any clear lifetime count.

This path is used for Created and terminal sessions that are not retained for a
running execution.

Examples include:

```text
getSessionJson
getSessionState
getLogsCount
getLogsJson
getStatisticsJson
getMediaInformationJson
debug-log getters/actions
FFplay validation/getters when the identity is not retained
history projection of non-running sessions
```

## 4.4 Concrete clear-vs-temporary-getter race

Thread A:

```text
getSessionState(id)
-> acquireSession(id)
-> no retained entry
-> ffmpeg_kit_get_session(id)
-> owns temporary handle H
-> sessionHandlesMutex released
-> native state read is about to use H
```

Thread B:

```text
clearSessions()
-> sessionHandlesMutex
-> clearSessionsInProgress = true
-> activeRetainedBorrows == 0
-> activeRetainedReleases == 0
-> immediately enters ffmpeg_kit_config_clear_sessions()
```

The frozen clear contract used by this bridge is destructive: it clears the
native handle registry while cancelling/draining sessions and clearing history.

Therefore the native registry can retire/invalidate the temporary handle while
Thread A is still invoking native methods through it.

Possible product effects include:

```text
invalid-handle access
use-after-release
native crash
session serialization/state call operating on retired handle memory
HandleGuard destructor subsequently releasing a token already cleared globally
```

The exact result depends on native timing, but the ownership invariant is
already violated before that detail matters.

## 4.5 The existing deterministic G5 test covers only the retained branch

The current native lifetime regression creates a retained session by calling
`executeSessionAsync()` and then tests:

```text
retained borrower vs release
retained borrower vs clear
duplicate retained release
pre-release retry
native clear failure retry
```

That correctly validates the G5 retained lease state machine.

It does not test:

```text
temporary Created/terminal handle vs clear
fresh ffmpeg_kit_get_session() temporary observation vs clear
session creation vs clear
```

So the passing retained-borrow clear test does not disprove R41-F1.

## 4.6 Session creation does not participate in the barrier at all

The creation helpers perform:

```cpp
HandleGuard guard(resolve<Fn>(symbol)(...));
const auto id = sessionIdOf(guard.handle);
rememberHistorySession(id, type);
return id;
```

They do not inspect:

```text
clearSessionsInProgress
activeRetainedBorrows
activeRetainedReleases
```

A native clear can therefore overlap a just-created owning handle before:

```text
sessionIdOf()
history registration
temporary handle release
```

complete.

This creates two correctness classes.

### Native lifetime

The destructive registry clear may invalidate the just-created handle while the
creation path still uses it.

### Wrapper-history transaction

Depending on scheduling:

```text
create native session
clear native registry
create records local history afterward
```

can leave local history metadata representing an identity the clear has already
removed.

The opposite ordering can erase a legitimate session created after the native
clear commit.

## 4.7 The clear barrier reopens before local history reset completes

Current clear ordering is:

```text
native config_clear_sessions succeeds

lock sessionHandlesMutex
  retainedSessionHandles.clear()
  clearSessionsInProgress = false
  notify_all()
unlock

lock historyMutex
  historyRecords.clear()
  nextHistoryOrder = 0
unlock
```

This means waiting acquisition/release work is allowed to resume before the
wrapper history transaction has committed.

A fresh operation can therefore begin after the native registry was cleared but
before old local history is cleared.

Most importantly, once creation is correctly added to the clear barrier, this
early reopen would still be wrong:

```text
clear native registry
barrier opens
new session creation starts and records history
old clear thread clears historyRecords
newly created session becomes invisible to wrapper history
```

The barrier must remain exclusive until **both** native registry clear and
wrapper ownership/history reset have committed.

## 4.8 Required remediation

Introduce a true **session-registry operation authority** that covers every
bridge operation holding a session-registry-backed native handle, not only
retained execution borrows.

The authority must cover at minimum:

```text
temporary ffmpeg_kit_get_session observations
session creation temporary handles
history temporary observations
retained execution borrows
retained release transactions
global clear
```

A semantic RAII operation lease is preferred.

Conceptually:

```text
SessionRegistryOperationLease
  admitted only while global clear is not exclusive
  increments active registry-operation count
  decrements on destruction

Global clear
  publishes exclusive/clearing state
  blocks new operation leases
  waits active registry operations == 0
  waits active retained releases == 0
  performs native config clear
  commits retained state clear
  commits history state clear
  only then reopens the registry
```

Do not simply add another `if (clearSessionsInProgress)` check before returning
a raw temporary handle; a check without a lifetime-bearing lease has the same
check/unlock/use race that Review 40 removed for retained handles.

## 4.9 Required tests

At minimum add deterministic C++ tests for:

```text
temporary getter borrow vs clear
history terminal observation vs clear
session creation already in progress vs clear
session creation starting after clear becomes exclusive
clear remains exclusive through local history commit
nested media/statistics access through a temporary parent session
existing retained-borrow vs clear regression remains green
clear failure returns registry authority to usable state
```

Use condition variables/barriers, not sleeps as the primary synchronization
oracle.

## 4.10 Exit criterion

No thread may invoke a native session-handle operation while global clear can
concurrently invalidate that handle, regardless of whether the handle is:

```text
retained
temporary
freshly created
history-derived
nested under a temporary session observation
```

The global clear barrier must not reopen until wrapper ownership and local
history state are fully committed.

---

# 5. R41-F2 — Windows abandonment reconciliation bypasses the synchronous diagnostic channel

**Severity:** Medium-High  
**Primary file:** `react-native/src/platform/backend.native.ts`

## 5.1 Intended fail-closed abandonment contract

The native backend keeps:

```ts
const abandonedSessionIds = new Set<number>();
```

When a Created identity is explicitly abandoned, the wrapper tombstones it
before calling the native abandonment action.

A direct native probe may later remove the tombstone only when native absence is
authoritatively established.

The comment states:

```text
non-empty snapshot -> ID still exists -> keep fail-closed
empty snapshot -> ID absent -> safe reclamation
probe error -> preserve tombstone
```

That contract is correct.

## 5.2 Normal Windows synchronous calls require `invokeSynchronousNative`

The backend has one helper for Windows synchronous calls:

```ts
function invokeSynchronousNative<TResult>(
  method: string,
  args: readonly unknown[],
): TResult {
  const result = Reflect.apply(...);
  const message = NativeFFmpegKitExtended.consumeSynchronousError();
  if (message) throw new Error(message);
  return result;
}
```

This is required because Windows `REACT_SYNC_METHOD` methods cannot reject a
Promise.

The Windows C++ wrapper catches ordinary native exceptions, records the
same-call diagnostic, and returns `Result{}`.

For a string method:

```text
native operation fails
-> Windows returns ""
-> synchronous diagnostic contains failure
-> invokeSynchronousNative consumes diagnostic and throws
```

## 5.3 Reconciliation bypasses that helper

Current reconciliation performs:

```ts
function reconcileAbandonedSessionId(sessionId: number): void {
  try {
    const json = NativeFFmpegKitExtended.getSessionJson(sessionId);
    if (!json) abandonedSessionIds.delete(sessionId);
  } catch {
    // Preserve tombstone when the reconciliation oracle is unavailable.
  }
}
```

The raw TurboModule call is the defect.

## 5.4 Windows failure becomes false absence

On Android/Apple shared Cxx, a synchronous bridge exception can propagate into
the `catch`, preserving the tombstone.

On Windows:

```text
raw getSessionJson
-> shared bridge operation throws
-> RNW invokeSynchronous catches
-> records synchronous diagnostic
-> returns default std::string{} == ""
```

The TypeScript code receives no JavaScript exception because it did not call
`consumeSynchronousError()`.

It then evaluates:

```ts
if (!json) abandonedSessionIds.delete(sessionId);
```

So an unavailable/failed oracle is misclassified as **proven native absence**.

That changes the anti-resurrection authority from fail-closed to fail-open on
Windows.

## 5.5 Product consequence

The abandoned ID is the wrapper's durable authority preventing reconstruction
of a Created session that the frozen native ABI may still expose by ID.

Deleting that tombstone after an error means a future:

```text
getSession(id)
history projection
execution validation
```

can once again reconstruct the residual Created identity.

This directly contradicts the established anti-resurrection behavior from the
earlier wrapper reviews.

R41-F1 also makes concurrent destructive-clear activity an additional reason
the direct native probe must never infer absence from an operational failure.

## 5.6 The native diagnostic is also discarded

Because reconciliation does not consume the same-call Windows diagnostic, the
probe failure is not surfaced or used for the fail-closed decision.

A later Windows synchronous method clears its diagnostic slot when it begins,
so this is not primarily a stale-error poisoning bug; it is a **lost error /
false absence** bug.

## 5.7 Required remediation

Use the same diagnostic-aware synchronous boundary as every other native
backend read.

Minimum correction:

```ts
const json = invokeSynchronousNative<string>('getSessionJson', [sessionId]);
```

Then the existing `try/catch` produces the intended behavior:

```text
confirmed non-empty -> tombstone remains
confirmed empty + no diagnostic -> tombstone removed
native diagnostic/throw -> catch -> tombstone remains
```

Do not duplicate Windows-specific diagnostic logic inside reconciliation.

## 5.8 Required tests

Add a behavioral native-backend test seam.

Required cases:

```text
1. getSessionJson returns non-empty JSON, no diagnostic
   -> tombstone remains

2. getSessionJson returns empty string, no diagnostic
   -> tombstone removed

3. Windows-style getSessionJson returns empty string AND consumeSynchronousError
   returns an error
   -> reconciliation catches
   -> tombstone remains

4. synchronous diagnostic is consumed exactly once
   -> later successful probe is not contaminated

5. abandon action itself rejects
   -> tombstone remains fail-closed unless existing contract explicitly says
      otherwise

6. successful clearSessions
   -> tombstones clear only after native clear resolves

7. failed clearSessions
   -> tombstones remain
```

A source regex that checks the helper name may supplement this test, but it must
not be the only evidence.

## 5.9 Documentation/comment update

Update the reconciliation comment to state explicitly:

```text
Only a successful diagnostic-free empty native snapshot proves absence.
Any synchronous native diagnostic or thrown probe error preserves the
abandonment tombstone.
```

Add a short maintenance comment near the Windows synchronous helper:

```text
Internal native backend code must use this helper for Windows synchronous calls
whose default return value has semantic meaning.
```

Do not add public API documentation unless the externally observable behavior
changes.

## 5.10 Exit criterion

No Windows synchronous probe may interpret a default value returned after a
native error as authoritative session state.

Abandonment reclamation must remain fail-closed on every native platform.

---

# 6. Retained platform-native areas with no new substantive finding

The following were re-reviewed at the Review 41 threshold.

## 6.1 Review 40 retained-handle per-session release — retained branch clean

The retained entry now provides:

```text
Retained -> Releasing -> removed
active borrow count
new-borrow rejection after Releasing
release waits existing retained borrows
pre-release state failure rolls back Releasing
duplicate release rejected
```

R41-F1 does not reopen that per-session retained lease result.

It concerns native handles that never enter that retained lease authority and
the incomplete global-clear transaction.

## 6.2 Non-throwing shared C++ cleanup — clean

Mandatory:

```text
ffmpeg_kit_handle_release
ffmpeg_kit_free
```

are resolved before the lifetime cache is published.

`HandleGuard` and `RetainedHandleLease` destructors do not perform dynamic
symbol lookup and are `noexcept`.

No new ordinary cleanup path to `std::terminate()` was found.

## 6.3 React Native Windows action completion — clean

Failure-bearing actions remain invocation-bound:

```text
REACT_METHOD
ReactPromise<void>
resolve/reject in the originating invocation
```

The old asynchronous thread-local last-error transport has not returned.

R41-F2 is specifically one raw synchronous probe bypassing the separate
synchronous diagnostic helper.

## 6.4 React Native callback/log ownership — clean

The process-global log callback owner still uses:

```text
conditional coordinator uninstall
managed callback state
native-owned message copy
exactly-once native payload release
retired state lifetime for teardown safety
```

No new substantive callback lifetime issue was established.

## 6.5 React Native Windows FFplay view — clean

The view retains:

```text
single active process-global owner
accept-frame shutdown before replacement
callback unregister on active-owner destruction
weak UI dispatch
bounded latest-frame queue
packed frame conversion
```

No new threshold finding.

## 6.6 React Native Android FFplay surface — clean

The Android view continues to:

```text
coordinate one process-global owner
clear native target only when stale view is still owner
release Java Surface objects
bind valid replacement surfaces
```

No new threshold finding.

## 6.7 React Native iOS/tvOS/macOS FFplay views — clean

The Apple views preserve:

```text
complete callback API requirement
latest-owner semantics
previous-owner frame rejection
unregister/drain before detach
locked pending-frame state
weak main-thread display dispatch
```

No product-significant duplicate-source divergence was found.

## 6.8 Flutter Windows external texture lifetime — clean

Review 39 asynchronous retirement remains present.

The registered `TextureVariant` and callback-captured state are retained until
Flutter unregister completion.

Owner-install rollback uses the same retirement path.

No regression found.

## 6.9 Flutter Linux pixel-buffer lifecycle — clean

The Linux plugin remains on `FlPixelBufferTexture`.

Plugin state owns CPU pixels while Flutter owns the engine-side GL texture
lifecycle.

The frame notification coalescer and GObject callback-held references remain in
place.

No new threshold finding.

## 6.10 Flutter Android surface ownership — clean

The plugin retains distinct ownership for:

```text
SurfaceTextureEntry
Java Surface
ANativeWindow pointer acquired for Dart
process-global FFplay Surface target
```

Cleanup remains conditional on process-owner identity.

No new threshold finding.

## 6.11 Flutter Apple frame bridge — clean

iOS/macOS CocoaPods and SwiftPM FFplay implementations remain behaviorally
aligned.

The supported packed layouts are converted to the Apple BGRA destination, with
opaque alpha repaired for `rgb0`/`bgr0`.

No new substantive parity or callback-lifetime defect was established.

## 6.12 Desktop packed-frame normalization — clean

Flutter Windows/Linux continue to use the shared packed-RGBA normalizer for:

```text
rgba
rgb0
bgra
bgr0
argb
abgr
```

including tight-row repacking and opaque alpha for zero-alpha layouts.

No regression found.

---

# 7. Review 41 remediation goals

| Goal | Required result |
| --- | --- |
| **R41-G1** | Replace the retained-only global-clear accounting with a true session-registry operation lifetime authority covering temporary observations, session creation, retained borrows, release, and clear; keep clear exclusive through local history commit |
| **R41-G2** | Route abandonment reconciliation through the Windows diagnostic-aware synchronous bridge and prove fail-closed tombstone behavior on diagnostic/error |
| **R41-G3** | Add deterministic native concurrency and native-backend behavioral tests that specifically cover the Review 41 gaps without weakening Review 40 evidence |
| **R41-G4** | Update ownership/error comments and only user-facing docs whose observable semantics actually change |
| **R41-G5** | Perform one final bounded platform-native bridge audit; if no substantive High/Medium bridge defect remains, run affected local noninteractive gates and freeze one exact wrapper source snapshot |

---

# 8. Review 41 closeout

```text
Wrapper source authority: VERIFIED
Outer artifact digest: VERIFIED
Embedded source archive: VERIFIED
Manifest: 1083/1083
Symlinks: 0
runtimeExecution: false
Frozen submodule provenance: VERIFIED

Native ABI separately downloaded: NO
Native ABI reviewed: NO
Native ABI source change required: NO

Code review only: YES
Tests/builds/runtime executed: NO
Repository mutation: NO

Substantive findings: 2
  R41-F1 High
  R41-F2 Medium-High

Pedantic findings reported: 0
Procedural findings reported: 0
Documentation-only findings reported: 0

Closure:
NOT YET PLATFORM-NATIVE BRIDGE CLEAN.

Review 41 should be the final bridge closure iteration if R41-F1/F2 are fixed,
their deterministic regressions are added, and the bounded post-fix audit finds
no additional substantive ownership/error-boundary defect.
```
