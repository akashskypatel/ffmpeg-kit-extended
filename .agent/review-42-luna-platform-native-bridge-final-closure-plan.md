# Review 42 — Luna Platform-Native Bridge Final Closure Plan

**Project:** FFmpegKitExtended  
**Audience:** Luna implementation/review model  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch:** `dev-wasm`  
**Starting source authority:** `510fabb3e58730d211dddc78d343a7ed377eba2c`  
**Review basis:** `review42-platform-native-bridge-code-review.md`  
**Native ABI/runtime:** frozen `0.11.2`  
**Frozen native submodule:** `b74da2c5d1e294b87d15d73a6687393729e932b3`

---

# 1. Goal tracker

| Goal | Objective | Production implementation | Required tests | Documentation/comments | Status |
| --- | --- | --- | --- | --- | --- |
| **R42-G1** | Make the session-registry operation authority composable so nested history/session helpers reuse one admitted operation instead of reacquiring the clear gate | `react-native/cpp/FFmpegKitDynamicApi.cpp` and only its header if a test/internal declaration is required | Deterministic `getSessionsJson`/`getLastSessionJson` history-vs-clear tests | Document one top-level admission token and nested reuse | ☐ |
| **R42-G2** | Remove every post-admission wait on `clearSessionsInProgress` and preserve correct Running-history promotion while clear drains existing work | `acquireHistorySession` and any factored under-operation helpers | Running-history-promotion-vs-clear regression; mixed retained/temporary history regression | Explain that admitted work continues while clear waits | ☐ |
| **R42-G3** | Preserve all Review 41 lifetime/error invariants and strengthen the C++ concurrency oracle around composability | `retained_handle_lifetime_test.cpp`, source-contract tests | Existing Review 41 matrix + new history tests | Test comments describe synchronization invariant rather than review IDs | ☐ |
| **R42-G4** | Perform a final substantive platform-native bridge audit across shared C++, Windows/Android/Apple RN, and unchanged Flutter bridge surfaces | code review only after implementation | No tests required specifically for unchanged code beyond affected local gates | No broad documentation cleanup | ☐ |
| **R42-G5** | Run affected local noninteractive validation, freeze exact wrapper SHA, and create one verified wrapper-only source snapshot only after the audit is clean | wrapper repository only | Windows → Android on Windows → WSL shared C++ → Apple last; local ABI only | Tracker/final closure evidence | ☐ |

---

# 2. Mission

Review 41 successfully expanded global clear protection to:

```text
temporary session observations
retained borrows/releases
session creation
history commit
native-backend fail-closed reconciliation
```

Review 42 found the final concurrency composition gap:

```text
the global operation authority is non-reentrant,
but history projection tries to acquire it recursively
and also re-waits the clear gate after already being admitted
```

This can permanently deadlock:

```text
history getter
vs
clearSessions()
```

The target is not another broad redesign.

The target is:

> Preserve the Review 41 registry-clear lifetime model while making a single
> admitted operation safely reusable throughout a complete history projection.

---

# 3. Non-negotiable constraints

Luna must treat all of these as mandatory.

1. Work in `akashskypatel/ffmpeg-kit-extended`, branch `dev-wasm`.
2. Start from/reconcile against exact source:
   `510fabb3e58730d211dddc78d343a7ed377eba2c`.
3. Keep native ABI/runtime pinned to **0.11.2**.
4. Keep `libs/libffmpegkit` frozen at:
   `b74da2c5d1e294b87d15d73a6687393729e932b3`.
5. Do **not** download or re-review the native ABI.
6. Do **not** edit the native submodule.
7. Do **not** edit/rebuild the ManyLinux builder checkout.
8. Do **not** add/change native exported symbols.
9. Do **not** publish native ABI artifacts.
10. Do **not** fetch remote old native bundles for local validation.
11. Do **not** use hosted Flutter/React Native CI/build/test workflows as acceptance evidence.
12. The only hosted workflow allowed at final closure is the exact wrapper source-snapshot workflow.
13. Do **not** run interactive Flutter or React Native UI/runtime validation.
14. Final interactive validation remains user-owned.
15. Production/test identifiers must be semantic; do not use `R42`, `G1`, `F1`, or review names in implementation symbols.
16. Never fabricate tests or test results.
17. Do not weaken existing tests.
18. Record mistakes, failed commands, environment corrections, and retries.
19. Exclude pedantic/style/procedural findings from the final code review.
20. A final finding needs a reachable path and concrete product consequence.
21. Preserve primary errors over later cleanup errors.
22. Do not reopen accepted Flutter/platform-native behavior without concrete contradictory evidence.

---

# 4. Starting implementation state that must be preserved

## 4.1 Registry-level clear protection

Current Review 41 code correctly adds:

```text
activeSessionOperations
SessionOperationLease
clearSessionsInProgress admission gate
```

and protects:

```text
temporary acquireSession lookups
session creation
retained acquire/release
cancel
history size operations
messages-in-transmit
clear commit through history reset
```

Do not remove that protection.

## 4.2 Per-session retained lifetime

Preserve:

```text
Retained -> Releasing -> removed

new retained borrow rejected after release begins

existing retained borrows drain before native release

pre-release state-read failure restores retryability

duplicate release is rejected

native handle release happens exactly once
```

## 4.3 Handle cleanup ordering

Preserve:

```text
owned native handle release
before
registry-operation authority release
```

For retained handles preserve:

```text
retained borrow release
before
registry-operation authority release
```

## 4.4 Global clear commit

Preserve:

```text
publish Clearing
block new top-level operations
wait admitted operations
native config clear
clear retained wrapper state
clear local history state
only then reopen admission
```

Do not revert to reopening before `historyRecords.clear()`.

## 4.5 Native backend diagnostic handling

Preserve:

```text
reconcileAbandonedSession
-> invokeSynchronousNative('getSessionJson')
-> diagnostic-free empty result is the only absence proof
-> thrown/diagnostic probe keeps tombstone
```

No Review 42 change is required in this TypeScript area unless final audit
finds a concrete regression.

---

# 5. Root cause Luna must understand before editing

The current global clear design behaves like a reader/writer barrier.

Conceptually:

```text
reader / ordinary operation:
  wait until no clear
  activeSessionOperations++

writer / clear:
  set clearSessionsInProgress = true
  wait activeSessionOperations == 0
```

That is valid only when a reader that has already incremented
`activeSessionOperations` does not try to enter the reader gate again.

Current history code violates this twice.

---

# 6. Deadlock path A — nested operation acquisition

Current top-level history function:

```cpp
std::string getSessionsJson(...) {
  auto operation = acquireSessionOperation();
  ...
  HandleGuard guard = acquireHistorySession(record.sessionId);
}
```

Nested helper:

```cpp
HandleGuard acquireHistorySession(...) {
  HandleGuard guard = acquireSession(id);
  ...
}
```

and:

```cpp
HandleGuard acquireSession(...) {
  auto operation = acquireSessionOperation();
  ...
}
```

Interleaving:

```text
H: outer acquire -> active operations = 1

C: clear publishes Clearing
C: waits active operations == 0

H: nested acquire
H: waits Clearing == false

C waits H
H waits C
```

This must be structurally impossible after the fix.

---

# 7. Deadlock path B — post-admission clear wait

`acquireHistorySession()` also currently does:

```cpp
std::unique_lock<std::mutex> lock(sessionHandlesMutex);
sessionHandlesCondition.wait(
    lock, [] { return !clearSessionsInProgress; });
```

after `acquireSession()` already returned a guard containing an active operation
lease.

This is invalid.

An admitted operation must continue while clear waits for it.

Do not preserve this wait.

---

# 8. Required semantic rule

Implement and document:

```text
clearSessionsInProgress controls NEW ADMISSION only.

Once a logical top-level operation has been admitted, it may continue all of
its nested work until the operation token is released.

Nested helpers reuse that token.

They do not:
  reacquire the clear gate
  wait for clear to become false
  throw merely because clear became pending after admission
```

Clear obtains exclusivity by:

```text
preventing new admission
+
waiting existing top-level operation tokens to drain
```

not by suspending admitted operations.

---

# 9. R42-G1 — choose a composable operation-token representation

## 9.1 Preferred implementation

Use one shared token per logical top-level registry operation.

Conceptual structure:

```cpp
class SessionOperationToken {
 public:
  ~SessionOperationToken() noexcept {
    releaseSessionOperation();
  }
};

class SessionOperationLease {
 public:
  SessionOperationLease() = default;

  // Copies share the SAME admission token.
  SessionOperationLease(const SessionOperationLease &) = default;
  SessionOperationLease &operator=(const SessionOperationLease &) = default;

  explicit operator bool() const noexcept;

 private:
  std::shared_ptr<SessionOperationToken> token_;
};
```

`acquireSessionOperation()`:

```text
lock
wait !clearSessionsInProgress
activeSessionOperations++
create one SessionOperationToken
unlock
return lease sharing token
```

Only destruction of the final shared token performs:

```text
activeSessionOperations--
notify_all
```

This gives:

```text
one logical operation
one activeSessionOperations count
many nested lifetime holders
```

## 9.2 Equivalent designs

An explicit borrowed operation scope is acceptable if:

```text
nested helper requires a valid existing operation parameter

nested helper cannot accidentally outlive the parent operation

nested helper never calls acquireSessionOperation

misuse is difficult and obvious
```

Prefer the shared-token design if Luna cannot prove borrowed-scope lifetime
statically from local structure.

## 9.3 Do not implement thread-local recursion depth

Avoid a hidden:

```text
thread_local operationDepth
```

unless absolutely necessary.

The bridge may move work across framework/native call boundaries, and hidden
thread-local recursion makes ownership harder to review.

Prefer explicit operation authority in function parameters/guards.

---

# 10. R42-G1 — factor top-level and under-operation session acquisition

Create semantic helpers.

Example:

```cpp
HandleGuard acquireSession(std::int64_t id) {
  auto operation = acquireSessionOperation();
  return acquireSessionWithinOperation(id, operation);
}
```

Internal helper:

```cpp
HandleGuard acquireSessionWithinOperation(
    std::int64_t id,
    const SessionOperationLease &operation);
```

The under-operation helper:

```text
does not call acquireSessionOperation

does not wait !clearSessionsInProgress

may lock sessionHandlesMutex briefly

may acquire retained borrow

may perform native getSession lookup

returns a guard carrying/sharing the SAME operation token
```

If the returned guard stores a copy of the shared token, that token must not
increment the global active-operation count.

---

# 11. R42-G1 — factor history acquisition

Replace the current nested entry with a helper such as:

```cpp
HandleGuard acquireHistorySessionWithinOperation(
    std::int64_t id,
    const SessionOperationLease &operation);
```

Its first step should be:

```text
acquireSessionWithinOperation(id, operation)
```

not:

```text
acquireSession(id)
```

and not:

```text
acquireSessionOperation()
```

---

# 12. R42-G1 — preserve one operation across full history projection

`getSessionsJson`:

```cpp
auto operation = acquireSessionOperation();

const auto records = visibleHistoryRecords(kind);

for (...) {
  auto guard =
      acquireHistorySessionWithinOperation(record.sessionId, operation);
  ...
}
```

`getLastSessionJson`:

```cpp
auto operation = acquireSessionOperation();

const auto records = visibleHistoryRecords(kind);

for (...) {
  auto guard =
      acquireHistorySessionWithinOperation(record.sessionId, operation);
  ...
}
```

The single token must span:

```text
history metadata snapshot
every native session lookup
Running-session promotion
session JSON serialization
temporary native-handle release
missing-record reconciliation
final return
```

This preserves clear atomicity.

---

# 13. R42-G2 — remove post-admission waiting

Inside history promotion, delete the semantic equivalent of:

```cpp
sessionHandlesCondition.wait(
    lock,
    [] { return !clearSessionsInProgress; });
```

when an existing operation lease is already held.

Reason:

```text
clear may legitimately be pending
clear is waiting for this admitted operation
this admitted operation must finish
```

Still lock `sessionHandlesMutex` briefly to inspect/update retained state.

Do not wait on the global admission condition.

---

# 14. R42-G2 — retained promotion semantics while clear is pending

Consider:

```text
history operation admitted
temporary native session discovered Running
clear publishes Clearing and starts waiting
history operation promotes temporary handle to retained entry
history serializes it
history operation releases retained borrow/token
clear sees active operations == 0
clear runs native destructive clear
clear clears retained map/history
```

This is safe.

The newly promoted retained entry does not escape clear because:

```text
clear cannot enter native clear until the entire admitted history operation
finishes
```

and then clear destroys the registry and wrapper retained map.

Do not reject the promotion solely because clear became pending after admission.

---

# 15. R42-G2 — existing retained entry discovered during promotion

If the temporary Running lookup races another admitted operation that already
created the retained entry:

```text
reuse current retained entry
increment its per-session borrow
release temporary owning handle exactly once
keep shared registry operation token alive
```

If the retained entry is already `releasing`:

```text
preserve the existing deterministic release-in-progress error
release temporary owning handle exactly once
release operation token on unwind
```

Do not block waiting for release or clear.

---

# 16. R42-G2 — operation token and HandleGuard destruction

If `HandleGuard` stores the shared operation token, preserve reset order:

```cpp
if (owned) {
  release(handle);
}

retainedLease.reset();

operationLease.reset();
```

The native owned handle and retained borrow must be retired before the final
registry operation token can disappear.

Do not rely solely on C++ member destruction order if an explicit `reset()`
already defines the intended invariant.

---

# 17. R42-G3 — deterministic concurrency test implementation

Extend:

```text
react-native/cpp/retained_handle_lifetime_test.cpp
```

or split a clearly named:

```text
session_registry_lifetime_test.cpp
```

only if that improves semantic clarity.

Primary evidence must execute the real shared C++ implementation through the
existing fake resolver seam.

---

# 18. Test A — `getSessionsJson` projection versus clear

## Setup

Create two history-visible sessions.

At least one should require a temporary native lookup.

Arrange deterministic synchronization so:

```text
history getter has acquired the top-level operation token

history getter has completed one record or reached a known point before the next
nested acquisition

clear has published Clearing
```

## Assertion while clear is pending

The history thread must still be able to continue.

Do not prove this with "nothing happened for 100ms".

Use explicit test-state notifications.

Example:

```text
historyReachedSecondRecord = true
```

must become observable while:

```text
testing::isSessionClearInProgress() == true
```

Then let history finish.

## Final assertions

```text
history call returns
clear proceeds afterward
native clear called exactly once
no deadlock
no leaked operation token
```

---

# 19. Test B — `getLastSessionJson` versus clear

Cover separately.

The code path is similar but not identical.

Required:

```text
last-session projection admitted
clear becomes pending
projection completes without reacquiring admission
clear then commits
```

---

# 20. Test C — Running-history promotion while clear waits

## Setup

Create a native-visible session with state `Running`.

Ensure it is not already in `retainedSessionHandles`.

History thread:

```text
starts history projection
obtains temporary native handle
enters fake state getter
blocks
```

Clear thread:

```text
starts
publishes Clearing
waits active operation
```

Release state getter.

## Required behavior

History thread must:

```text
lock retained map
promote/reuse Running handle
serialize/finish
release temporary/borrow correctly
release operation token
```

without waiting for:

```text
clearSessionsInProgress == false
```

Then clear may continue.

---

# 21. Test D — mixed retained and temporary history

History contains:

```text
one retained Running identity
one terminal/Created temporary identity
```

Start clear during projection.

Assert:

```text
one shared top-level operation authority
retained borrow is valid
temporary handle is valid
temporary release happens under operation authority
clear starts native destruction only after both records are complete
```

This protects both acquisition modes.

---

# 22. Test E — clear already exclusive before history starts

This verifies the opposite ordering.

Clear:

```text
publish Clearing
pause in fake native clear
```

History thread starts.

Assert before releasing clear:

```text
no native history lookup
no history serialization
history caller remains blocked at TOP-LEVEL admission
```

Finish clear.

Assert:

```text
history caller resumes
observes post-clear history
```

This proves the fix did not weaken the admission gate.

---

# 23. Test F — clear failure with history waiter

Start clear and a history call waiting for admission.

Inject existing synthetic native clear failure.

Assert:

```text
clear reports failure
barrier reopens
waiting history call proceeds
existing wrapper/native history remains usable
active operation count does not leak
```

---

# 24. Test G — repeated/multiple nested history helpers

The operation-token design must remain correct if:

```text
getSessionsJson loops many records
```

Assert:

```text
activeSessionOperations represents one top-level history transaction
not one count per record
```

Use a test-only accessor only if needed.

Do not expose the counter through the public bridge API.

---

# 25. Test H — preserve existing Review 41 lifetime cases

All existing cases remain required:

```text
retained borrower vs release
new retained borrow after release begins
retained borrower vs clear
temporary getter vs clear
duplicate release
pre-release lookup failure retry
native clear failure retry
active session creation vs clear
new session creation waits while clear is exclusive
```

If any existing case fails after the composability change, do not weaken it.

---

# 26. Test synchronization rules

Prefer:

```text
condition_variable
barrier
latch
promise/future
explicit atomic phase flags
```

Avoid:

```text
sleep_for as the success oracle
fixed delay followed by "probably blocked"
```

A timeout is acceptable only as:

```text
deadlock/failure watchdog
```

not as the proof that ordering is correct.

The current harness uses bounded timing in a few negative checks.

Do not expand that pattern for the new deadlock proof when explicit phase
coordination can prove the interleaving.

---

# 27. Source-contract test updates

Update:

```text
react-native/tests/native-bridge-lifetime.test.js
```

Secondary assertions should require the new structure.

Good examples:

```text
getSessionsJson acquires one top-level operation authority

getLastSessionJson acquires one top-level operation authority

history acquisition receives/reuses an existing operation token

acquireHistorySession implementation does not contain a
wait(!clearSessionsInProgress) after admission

under-operation helper does not call acquireSessionOperation
```

Remove/replace any assertion that unintentionally encourages recursive
`acquireSessionOperation()`.

Do not encode exact whitespace or fragile line ordering.

---

# 28. R42-G3 — audit every operation-lease call site after refactor

Build a private review matrix.

Minimum:

| Path | Top-level operation acquisition | Nested acquisition allowed? | Required result |
| --- | --- | --- | --- |
| `createSessionWith` | yes | no | one token through native create/history commit/temp release |
| `createSessionWithArguments` | yes | no | same |
| MediaInfo path create | yes | no | same |
| `acquireSession` normal getter | yes | no | token stored in returned guard |
| `ensureRetainedSession` execution | yes | no | one token through retention/execution call |
| `releaseRetainedSession` | yes | no | clear blocked until release transaction ends |
| `cancelSession` | yes | no | clear cannot overlap native cancel transaction |
| `abandonCreatedSession` | yes | no | wrapper history mutation serialized with clear |
| `getSessionsJson` | yes | **nested helpers reuse same token** | one token for full projection |
| `getLastSessionJson` | yes | **nested helper reuses same token** | one token for full projection |
| `setSessionHistorySize` | yes | no | history mutation serialized |
| `getSessionHistorySize` | yes | no | clear ordering preserved |
| `messagesInTransmit` | yes | no | clear ordering preserved |
| session getters/log/stat/media | via `acquireSession` | no | guard owns token |
| FFplay getters/actions | via `acquireSession` | no | guard owns token |
| debug-log getters/actions | via `acquireSession` | no | guard owns token |
| `clearSessions` | exclusive writer | n/a | waits top-level tokens only |

Add any discovered path.

---

# 29. R42-G3 — mechanical nested-admission audit

After implementation, search every function that calls:

```text
acquireSessionOperation()
```

For each one, determine whether it can call another function that also acquires
a new operation.

There must be no hidden recursive admission on a path that can overlap clear.

Do not assume "same thread" makes reacquisition safe.

The barrier is deliberately non-reentrant unless the new shared-token design
makes nested use explicit.

---

# 30. R42-G4 — final platform-native code review

After code/tests are stable, perform a new code review.

Do not just verify R42-F1 disappeared.

## 30.1 Shared C++ lifetime

Review:

```text
SessionOperationLease/token
HandleGuard
RetainedHandleLease
acquireSession
under-operation acquisition
ensureRetainedSession
acquireHistorySession
releaseRetainedSession
history projection
create
cancel
clear
media/statistics
FFplay
debug-log
```

Look for:

```text
recursive clear-gate admission
post-admission clear wait
operation token count leak
double decrement
handle release after operation token is gone
retained borrow outliving operation authority
condition wait with impossible wakeup
lock-order inversion
raw handle escaping guard
```

## 30.2 Windows error transport

Preserve:

```text
ReactPromise invocation-bound action errors
same-call synchronous diagnostic
consumeSynchronousError not used as async cross-call state
no fail-fast/terminate
```

The Review 41 abandonment reconciliation helper must remain diagnostic-aware.

## 30.3 React Native callback ownership

Recheck unchanged:

```text
log bridge owner
retired callback state
Windows FFplay view
Android Surface owner
Apple FFplay coordinator
```

Only report concrete findings.

## 30.4 Flutter

Flutter platform-native files are unchanged by Review 41.

Recheck:

```text
Windows async texture retirement
Linux FlPixelBufferTexture lifetime
Android Surface/ANativeWindow ownership
Apple callback/texture lifetime
packed frame layout normalization
Apple duplicate-source parity
```

Do not invent Flutter remediation absent a real defect.

---

# 31. R42-G4 — documentation/comment updates

Do not perform broad prose cleanup.

## 31.1 Global registry comment

Update the central state-machine comment to state:

```text
clear blocks NEW operation admission

existing admitted operations drain naturally

nested helpers reuse the admitted token

clear waits for final token release
```

## 31.2 Operation token comment

If using a shared token:

```text
copies share one global active-operation slot

only destruction of the last token decrements activeSessionOperations
```

## 31.3 History comment

Near history projection:

```text
one operation token spans the entire projection so destructive clear cannot
split the result or invalidate a handle between records
```

## 31.4 Running promotion comment

State:

```text
promotion runs under a previously admitted operation and must not wait on the
clear admission gate
```

## 31.5 End-user docs

No end-user behavior should change.

No README/API update is required unless implementation deliberately changes
public clear/history behavior.

---

# 32. Local validation after code-review remediation

Review 42 itself is code review only and claims no test/build execution.

Luna implementation should validate locally only after focused tests pass.

Use only existing local ABI `0.11.2`.

No hosted acceptance workflow.

---

# 33. Validation order

Use:

```text
1. focused compiled C++ lifetime tests on Windows
2. focused React Native Node/source tests
3. TypeScript typecheck/test compile/lint as applicable
4. React Native Windows local build
5. React Native Android local build on Windows
6. shared C++ lifetime test under WSL
7. React Native Apple builds last:
   iOS
   tvOS
   macOS
8. final bounded code review
9. exact wrapper snapshot
```

No interactive application launch.

---

# 34. Windows gates

Run locally:

```text
compiled session-registry lifetime test
native bridge lifetime/source tests
Windows error transport tests
native-session reconciliation tests
npm run typecheck
npm run test:compile
React Native Windows example build
```

Use the existing local frozen runtime.

Do not fetch a remote binary.

---

# 35. Android gates

Because `FFmpegKitDynamicApi.cpp` is shared C++:

```text
React Native Android Gradle/CMake example build
```

must run on local Windows using the configured local artifact.

Do not substitute WSL Android.

---

# 36. WSL gate

Compile/run the shared deterministic C++ lifetime harness under WSL with strict
warnings.

React Native has no Linux app target in this repository.

Do not invent one.

Flutter Linux need not be rebuilt if no Flutter source/config file changes.

---

# 37. Apple-last gates

On the existing authorized Mac environment using local universal XCFrameworks:

```text
React Native iOS build
React Native tvOS build
React Native macOS build
```

No simulator/device launch.

No remote artifact retrieval.

If the shared C++ lifetime harness is portable in the existing local harness,
running it on Apple is useful secondary evidence but not required to replace the
Windows/WSL executable proof.

---

# 38. Flutter validation scope

Review 42 production remediation should remain React Native shared C++ only.

If Flutter source remains untouched:

```text
do not rerun broad Flutter platform builds/tests merely for ceremony
```

Preserve the already-established Review 41/40 Flutter evidence.

If final code review discovers and fixes a real Flutter bridge defect, then run
the affected local Flutter gates and document that scope change explicitly.

---

# 39. Test/result truthfulness

For every executed command record:

```text
platform
working directory
exact command
exit status
test count if available
whether acceptance or diagnostic
```

Do not report:

```text
source inspection
timeout
killed process
skipped compile
unavailable platform
```

as a passing test.

If a command initially fails due environment/path/toolchain setup and is
corrected, record both attempts.

---

# 40. Final exact-SHA freeze

Only after all are true:

```text
R42-F1 fixed
new deterministic history-vs-clear tests pass
existing Review 41 lifetime tests pass
affected local RN builds pass
final bounded code review finds no substantive bridge defect
```

then:

1. Verify no change to `libs/libffmpegkit`.
2. Verify no builder checkout change.
3. Clean task-owned staging/output.
4. Commit/push final wrapper code.
5. Record exact 40-character wrapper SHA.
6. Dispatch **one** wrapper-only source snapshot at that exact SHA.
7. Do not dispatch hosted test/build workflows.
8. Do not create a native/builders snapshot.
9. Download and verify:
   - artifact digest;
   - `source.tar.gz.sha256`;
   - every `SHA256SUMS` entry;
   - `SUBMODULES.txt`;
   - `SYMLINKS.tsv`;
   - `snapshot-metadata.json`;
   - `runtimeExecution=false`.
10. Treat later tracker/mailbox commits as metadata, not source authority.

---

# 41. Tracker/final closure report requirements

Record:

```text
Review 42 starting authority
510fabb3e58730d211dddc78d343a7ed377eba2c

R42-F1 disposition

chosen composable operation-token design

proof that nested history helpers do not re-enter clear admission

proof that admitted Running-history promotion does not wait for clear

deterministic test cases/results

existing Review 41 regression results

Windows/Android/WSL/Apple affected local build results

exact final wrapper SHA

source snapshot run/artifact IDs and digests

manifest count
symlink count
runtimeExecution=false
frozen native submodule SHA
```

Do not write "all platforms pass" unless each listed gate actually ran.

---

# 42. Luna implementation sequence

Use this order:

```text
1. Read Review 42 code review.

2. Inspect current:
   SessionOperationLease
   HandleGuard
   acquireSessionOperation
   acquireSession
   acquireHistorySession
   getSessionsJson
   getLastSessionJson
   clearSessions.

3. Write down the one-token-per-top-level-operation invariant.

4. Choose shared-token or equivalently safe explicit-scope design.

5. Refactor operation lease representation.

6. Add acquireSessionWithinOperation.

7. Refactor acquireSession to:
   acquire top-level token
   delegate to within-operation helper.

8. Add acquireHistorySessionWithinOperation.

9. Change getSessionsJson/getLastSessionJson to:
   acquire one token
   pass/reuse it for all records.

10. Remove the stale post-admission
    wait(!clearSessionsInProgress)
    from Running-history promotion.

11. Re-audit HandleGuard destruction ordering.

12. Implement deterministic history-vs-clear tests A-F.

13. Run focused C++ tests.

14. Update secondary source-contract tests.

15. Run focused Node/TypeScript tests.

16. Update semantic comments.

17. Perform full bounded platform-native code review.

18. Run affected local platform gates:
    Windows
    Android on Windows
    WSL shared C++
    Apple last.

19. Re-review final source.

20. Freeze exact wrapper SHA.

21. Dispatch/download/verify one wrapper-only source snapshot.

22. Stop automated work.
```

---

# 43. Anti-patterns Luna must reject

## 43.1 Remove the outer history operation and accept partial clear races

Do not simply delete:

```cpp
auto operation = acquireSessionOperation();
```

from `getSessionsJson`/`getLastSessionJson` and make every record independently
acquire the gate.

That can allow:

```text
record 1 serialized
clear commits
record 2 serialized from post-clear state
```

within one history result.

Preserve full-operation atomicity.

## 43.2 Keep recursive acquisition and make condition variable recursive

A condition variable is not a reentrant lock.

Do not hide nested operation acquisition with ad-hoc recursion flags.

Use explicit shared operation authority.

## 43.3 Wait for clear after admission

Do not:

```text
already admitted
clear pending
wait for clear to finish
```

Clear is waiting for the admitted operation.

That is the deadlock.

## 43.4 Throw on pending clear after admission

Do not replace the wait with:

```cpp
if (clearSessionsInProgress) throw ...
```

The operation was already admitted and owns valid lifetime authority.

It should finish.

## 43.5 Increment global operation count for every nested helper

One logical top-level operation should not produce a new global admission count
for each nested history record.

## 43.6 Release registry authority before temporary native handle

Do not let:

```text
activeSessionOperations reach zero
```

while an owned temporary handle is still being used/released.

## 43.7 JS mutex

The defect is in shared native C++.

A JavaScript lock cannot prove native lifetime correctness.

## 43.8 Timing-only test

Do not use:

```text
sleep 100ms
if nothing happened assume safe
```

as the main deadlock proof.

Use deterministic phase synchronization.

## 43.9 Native ABI change

Not permitted.

---

# 44. Definition of done

Review 42 closes only when every item is true:

```text
[ ] One top-level registry operation creates one clear-barrier admission token.
[ ] Nested history helpers reuse the existing token.
[ ] Nested history helpers do not call acquireSessionOperation again.
[ ] No admitted operation waits for clearSessionsInProgress to become false.
[ ] getSessionsJson cannot deadlock with clearSessions.
[ ] getLastSessionJson cannot deadlock with clearSessions.
[ ] Running-history promotion cannot deadlock with clearSessions.
[ ] Full history projection remains atomic against destructive clear.
[ ] New history calls still block when clear was already exclusive before admission.
[ ] Temporary native handles remain protected until release.
[ ] Session creation remains protected until history commit and temporary release.
[ ] Retained per-session release behavior remains correct.
[ ] Clear failure reopens admission without leaking operation state.
[ ] Diagnostic-aware abandonment reconciliation remains intact.
[ ] Windows action Promise errors remain invocation-bound.
[ ] Windows synchronous diagnostics remain same-call only.
[ ] RAII cleanup remains non-throwing/resolver-free.
[ ] RN Windows/Android/Apple callback/surface ownership remains clean.
[ ] Flutter Windows/Linux/Android/Apple platform-native ownership remains clean.
[ ] Packed frame normalization remains clean.
[ ] Deterministic history-vs-clear C++ regressions exist and pass.
[ ] Existing Review 41 deterministic lifetime regressions pass.
[ ] Affected local Windows/Android/WSL/Apple gates pass with local ABI 0.11.2.
[ ] No hosted acceptance CI is used.
[ ] No native ABI is downloaded/reviewed/changed/rebuilt/published.
[ ] Final bounded code review finds no substantive High/Medium bridge defect.
[ ] Exact final wrapper SHA is snapshotted once and verified.
```

If any item is false, do not declare platform-native bridge closure.
