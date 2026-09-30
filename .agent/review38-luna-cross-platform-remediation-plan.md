# Review 38 — Luna Cross-Platform Flutter + React Native Remediation Plan

**Audience:** Luna implementation model  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch:** `dev-wasm`  
**Starting wrapper authority:** `aa3010bf335f36daeb64231ba154f9b662d496a6`  
**Review basis:** `review38-cross-platform-code-review.md`  
**Native ABI/runtime:** `0.11.2`, frozen/read-only  
**Frozen native submodule:** `b74da2c5d1e294b87d15d73a6687393729e932b3`

---

# 1. Goal tracker

| Goal | Objective | Status |
| --- | --- | --- |
| **R38-G1** | Give restored Running Flutter observers explicit bridge-demand ownership for completion/log/statistics delivery | **Pending** |
| **R38-G2** | Make explicit cancellation durable by session ID before fallible state classification on Flutter restored sessions and React Native native/Web | **Pending** |
| **R38-G3** | Remove quadratic all-tombstone maintenance while preserving exact fail-closed Created-session anti-resurrection semantics | **Pending** |
| **R38-G4** | Run focused and affected local cross-platform wrapper regression using existing frozen local artifacts only | **Pending** |
| **R38-G5** | Reconcile evidence, freeze exact wrapper SHA, and create one wrapper-only source snapshot | **Pending** |

---

# 2. Mandatory operating constraints

Luna must treat every item in this section as a hard constraint.

1. Work only in `akashskypatel/ffmpeg-kit-extended`.
2. Work from `dev-wasm`.
3. The Review 38 implementation authority starts from:
   `aa3010bf335f36daeb64231ba154f9b662d496a6`.
4. `libs/libffmpegkit` is frozen/read-only at:
   `b74da2c5d1e294b87d15d73a6687393729e932b3`.
5. Do **not** edit FFmpegKit native ABI source.
6. Do **not** edit the ManyLinux builder checkout.
7. Do **not** download or re-review another native/builders source snapshot.
8. Do **not** rebuild, publish, or remotely stage a replacement native ABI.
9. Do **not** fetch a published/remote old native bundle for validation.
10. Keep the runtime artifact authority pinned to the existing local
    `0.11.2` artifacts already configured in the repository/tracker.
11. Use hosted GitHub workflows only for the final **source snapshot**. Do not
    use hosted Flutter/React Native test/build workflows as acceptance evidence.
12. Do not launch or operate interactive Flutter/React Native applications.
13. Final interactive runtime validation remains user-owned.
14. Production identifiers must be semantic. Do not put `R38`, finding IDs,
    goal IDs, "review38", "plan", or similar planning names into implementation
    variables, methods, classes, or production filenames.
15. Tests must be truthful executable oracles. Never fabricate test output,
    silently skip a failing production scenario, or weaken an assertion merely
    to make a gate pass.
16. If Luna makes an implementation mistake, uses a wrong command, mutates an
    unintended file, or initially reaches a false diagnosis, record it plainly
    in the tracker/evidence instead of hiding or rewording it.
17. Preserve primary execution/cancellation errors over later cleanup errors.
18. When execution otherwise succeeds, do not silently discard a meaningful
    cleanup/settlement failure.
19. Run Flutter/Dart with analytics disabled.
20. Tag/observe task-owned Flutter, Dart, Node, PowerShell, WSL, compiler,
    browser-smoke, and SSH processes.
21. Terminate only confirmed task-owned hangs/orphans.
22. Clean task-owned generated/staging output before final freeze.
23. Commit and push meaningful implementation goals separately where practical.
24. Final closeout creates **one wrapper-only source snapshot**.
25. Do not reopen accepted Review 23–37 dispositions unless the changed wrapper
    source directly contradicts one.

---

# 3. Preparation and source authority

Before editing code:

1. Verify repository and branch.
2. Record:
   - `git rev-parse HEAD`;
   - `git rev-parse origin/dev-wasm`;
   - `git status --short`;
   - the `libs/libffmpegkit` gitlink.
3. Confirm the working source contains or descends from:
   `aa3010bf335f36daeb64231ba154f9b662d496a6`.
4. Confirm the native gitlink remains:
   `b74da2c5d1e294b87d15d73a6687393729e932b3`.
5. Do not inspect native source as part of implementation diagnosis unless an
   already-approved wrapper integration contract explicitly requires a symbol
   name. Prefer the wrapper-generated bindings/contracts and the recorded
   Review 37 local oracle.
6. Read:
   - `review38-cross-platform-code-review.md`;
   - this plan;
   - `.agent/TRACKER.md`;
   - the current Review 37 implementation source in the files listed below.
7. If live `dev-wasm` contains later changes than the frozen source authority,
   reconcile them explicitly. Never overwrite newer work silently.

Primary files for Review 38:

```text
flutter/lib/src/session.dart
flutter/lib/src/callback_manager.dart
flutter/lib/src/ffmpeg_session.dart
flutter/lib/src/ffprobe_session.dart
flutter/lib/src/media_information_session.dart
flutter/lib/src/ffplay_session.dart
flutter/lib/src/ffmpeg_kit_extended.dart
flutter/lib/src/session_history_index.dart
flutter/lib/src/session_queue_manager.dart

react-native/src/session.ts
react-native/src/ffmpeg-kit-extended.ts
react-native/src/platform/backend.native.ts
react-native/src/platform/backend.web.ts
react-native/src/platform/web/session-history-registry.ts
```

Use adjacent backend/bridge files only as needed to preserve existing semantic
contracts.

---

# 4. R38-G1 — Restored Flutter observer bridge ownership

## 4.1 Objective

A restored Running Flutter session with a local observer must create its own
process-global callback demand.

The observer must receive events even when:

- there is no locally submitted execution of the same type;
- there is no global callback;
- no unrelated session currently owns the callback bridge.

Apply to:

- FFmpeg completion;
- FFmpeg logs;
- FFmpeg statistics;
- FFprobe completion;
- FFprobe logs;
- MediaInformation completion;
- MediaInformation logs;
- FFplay completion;
- FFplay logs.

Do not fake local execution state to achieve this.

## 4.2 Existing defect to remove

Current restored registration does:

```text
restored Running
-> CallbackManager map insertion
```

but does not necessarily do:

```text
-> CallbackManager.acquireBridge(...)
```

Completion bridge installation currently belongs to
`acquireExecutionBridgeLeases()`, which is a local execution path.

Log/statistics lease synchronization also requires `hasExecutionStarted`, which
is false for restored observer-only wrappers.

This creates "works only when another bridge owner happens to exist" behavior.

## 4.3 Required design separation

Model at least these two semantic owners:

```text
execution bridge demand
observer bridge demand
```

They can share the existing `Session._bridgeLeases` storage and the same
process-global `CallbackManager.acquireBridge()` refcount authority.

Do not create a second process-global callback registry.

A restored observer lease is not a queue reservation and must not set:

```text
_submitted
_executionStarted
_executionSettled
```

merely to satisfy existing conditions.

## 4.4 Completion observer lifecycle

For each concrete session type, the lifecycle must be:

```text
set completion callback on restored Running wrapper
-> validate Running state
-> register session in CallbackManager map
-> acquire matching completion bridge lease
-> native/Web terminal event arrives
-> observe terminal history
-> local completion callback
-> global completion callback
-> restored completion settlement
-> remove completion callback/routing as currently intended
-> release restored completion bridge lease
-> if callback requested dispose:
     physical release after fan-out/observer settlement
```

### Required completion bridge kinds

Use the existing kinds:

```text
CallbackBridgeKind.ffmpegCompletion
CallbackBridgeKind.ffprobeCompletion
CallbackBridgeKind.mediaInformationCompletion
CallbackBridgeKind.ffplayCompletion
```

Use the existing backend install/uninstall methods.

Do not add platform-specific bridge APIs.

## 4.5 Completion setter rollback requirements

A setter mutation must be failure-atomic.

For a restored Running session:

```text
old callback
-> install new callback reference
-> validate state/register/acquire observer bridge
```

If validation, map registration, or bridge installation throws:

- restore the previous callback value;
- remove any registration introduced solely by the failed mutation;
- release any bridge lease acquired during that failed attempt;
- preserve the original failure;
- do not leave an inflated bridge refcount.

The current completion setters already restore the callback value after routing
failure. Extend that transaction to observer bridge ownership.

## 4.6 Completion removal requirements

When a restored observer removes its completion callback before terminal state:

- release its restored completion bridge lease;
- unregister from `CallbackManager` only if no other local sinks require routing;
- do not disturb another session/global owner's process-global bridge lease.

At terminal restored settlement:

- release completion-only observer demand exactly once;
- preserve independent log/statistics observer demand if still attached;
- remove the callback map root only when no remaining sink requires it.

## 4.7 Restored log observer lifecycle

For FFmpeg/FFprobe/MediaInformation/FFplay:

```text
set log callback or add log stream listener
-> restored state is Running
-> register session
-> acquire CallbackBridgeKind.log
-> receive live structured/buffered log events
```

Do not require `hasExecutionStarted` for restored observer demand.

Execution-owned log demand may keep the current condition:

```text
hasExecutionStarted && !hasExecutionSettled
```

Restored observer demand needs a separate condition.

When the last restored log sink is removed:

- release the session's log bridge lease;
- unregister if no completion/statistics/log sink remains.

When restored terminal completion is observed:

- decide explicitly whether a still-attached local log sink remains useful after
  final reconciliation.
- If terminal live log transport has ended, release the log bridge demand after
  final pending-log reconciliation.
- Do not close a user-created stream/controller merely to release native bridge
  demand unless that is already the documented session contract.

## 4.8 Restored statistics lifecycle

Only FFmpeg has statistics demand.

For a restored Running FFmpeg session:

```text
setStatisticsCallback(...)
-> register
-> acquire CallbackBridgeKind.statistics
```

Do not gate restored statistics lease acquisition on `hasExecutionStarted`.

Release it on:

- statistics callback removal;
- restored terminal observation after final statistics reconciliation;
- dispose.

## 4.9 Global callbacks

Do not make restored local observer behavior depend on global callbacks.

However, preserve shared process-global refcount semantics:

```text
global callback lease + restored local observer lease
```

must install the backend bridge once and uninstall only after both are gone.

Test this explicitly.

## 4.10 Required focused Flutter tests

Add tests that inspect **bridge lease/install behavior**, not only map
registration and direct manual `dispatch*Complete()` calls.

A manual call to `CallbackManager.dispatch*Complete()` is insufficient proof
that the platform bridge would have delivered the event.

### Completion cases

For every session family:

1. Create a restored Running wrapper using the existing no-native test seam.
2. Ensure no global completion callback and no other execution bridge owner.
3. Set a local completion callback.
4. Assert:
   - session is registered;
   - the matching completion bridge lease count becomes 1;
   - install function is called exactly once.
5. Simulate terminal completion.
6. Assert:
   - local callback runs exactly once;
   - global callback behavior remains correct if later added;
   - restored settlement runs;
   - completion lease returns to 0 if no other owner;
   - uninstall occurs exactly once;
   - callback map no longer retains the session when otherwise idle.
7. Repeat with callback-requested `dispose()`.
8. Assert physical release occurs after fan-out and exactly once.

### Refcount cases

For two restored FFmpeg sessions:

```text
A setCompleteCallback -> install once / leases 1
B setCompleteCallback -> install count still once / leases 2
A removes/settles      -> bridge remains / leases 1
B removes/settles      -> uninstall once / leases 0
```

Repeat at least one case with a global completion lease coexisting.

### Log cases

For restored Running FFmpeg, FFprobe, MediaInformation, FFplay:

- local log callback alone activates `CallbackBridgeKind.log`;
- removing it releases demand;
- no unrelated execution is required.

### Statistics cases

For restored Running FFmpeg:

- statistics callback alone activates statistics bridge demand;
- removing it releases demand.

### Failure-atomic cases

- restored state read throws;
- completion bridge install throws;
- log bridge install throws;
- statistics bridge install throws.

After each failure:

- no stale CallbackManager root;
- no leaked bridge lease;
- original callback value restored;
- later retry can succeed.

## 4.11 Exit criterion

The following statement must be true:

> A restored Running Flutter session's callback delivery is determined solely by
> its own observer demand plus shared refcount semantics, never by whether an
> unrelated session happens to keep the same process-global bridge installed.

---

# 5. R38-G2 — Durable ID-scoped cancellation intent before state classification

## 5.1 Objective

Once the user explicitly requests cancellation for a session ID, a later
wrapper must not be able to execute that same Created native ID merely because a
state read failed during the cancellation attempt.

Apply to:

- React Native native;
- React Native Web;
- Flutter restored session wrappers.

Preserve the existing fast durable path for ordinary newly-created Flutter
sessions.

## 5.2 Do not overload Created abandonment

Review 36's Created abandonment has two effects:

```text
hide/remove Created wrapper history identity
block future execution by ID
```

A cancellation request for a Running or unknown-state session should not
necessarily hide it from history.

Introduce or extend a semantic ID authority that can represent:

```text
cancellation requested
Created abandonment confirmed
```

These may be two flags/states in one record.

Do not use a strong wrapper reference as the authority.

## 5.3 React Native design

React Native currently reconstructs sessions freely from native snapshots.

Add backend/shared wrapper authority for "cancellation requested by ID".

Suggested semantic shape:

```text
sessionId -> cancellation intent state
```

Possible states:

```text
pending-classification
created-abandoned
running-cancel-requested
```

Do not use these exact planning names if a cleaner semantic model exists.

### Cancel ordering

Change the logical order from:

```text
object.cancelled = true
-> getState()
-> maybe abandonCreatedSession()
```

to:

```text
object.cancelled = true
-> record ID-scoped cancellation intent
-> getState()
-> refine cancellation authority
```

### If state is Created

- call existing Created-abandonment path;
- keep direct lookup/execution fail-closed;
- history hiding remains consistent with Review 36.

### If state is Running

- do not hide normal history;
- dispatch native cancellation;
- retain enough ID-scoped cancellation intent that a separately reconstructed
  wrapper cannot be submitted as new work;
- clear/reconcile intent when terminal state is authoritatively observed.

### If state is terminal

- cancellation has no execution effect;
- reconcile/remove pending cancellation intent as safe.

### If state read throws

- preserve ID-scoped cancellation intent;
- rethrow the original state-read failure;
- future direct lookup may remain inspectable if desired, but any execution
  handoff for that ID must fail closed until classification resolves.

## 5.4 React Native reconstruction

`sessionFromSnapshot()` currently creates a fresh wrapper with default lifecycle
flags.

Do not rely on constructor-local fields to carry cancellation across
reconstruction.

Possible safe approaches:

### Approach A — backend execution guard only

Allow inspection wrapper reconstruction, but:

```text
prepareForExecution()
-> check ID-scoped cancellation authority
-> reject
```

Also make `Session.isCancelled()` reflect ID-scoped intent where appropriate.

### Approach B — hydrate reconstructed wrapper

Have the reconstruction path read wrapper lifecycle metadata and initialize the
new wrapper as cancelled/abandoned.

If using this approach, keep the backend execution guard anyway. Object state
alone must not be the single authority.

Prefer A for minimal coupling unless API behavior requires `isCancelled()` to
reflect reconstructed cancellation.

## 5.5 Flutter design

Flutter already has a `SessionHistoryIndex` ID authority.

Extend it so restored cancellation can be recorded **before** the fallible state
read.

Do not tombstone a Running session as if it were abandoned Created work.

A possible record model:

```text
SessionHistoryEntry:
  cancellationRequestedById

or separate ID-only cancellation authority:
  Set<int> cancellationRequestedSessionIds
```

It must not retain wrappers or handles.

### New non-restored session

Keep the existing efficient path:

```text
!submitted && !restored
-> Created abandonment immediately
-> no state read required
```

### Restored wrapper

Use:

```text
record cancellation intent by ID
-> read state
```

Then refine:

```text
Created -> abandon Created identity
Running -> dispatch native cancellation
terminal -> reconcile cancellation intent
failure -> keep cancellation intent and rethrow
```

## 5.6 Execution handoff

Both wrappers must fail closed by ID.

Flutter `validateExecutionHandoff()` must check:

```text
Created abandonment
OR unresolved/cancel-requested ID authority
OR object-local cancellation
```

React Native `prepareForExecution()` must do the equivalent.

The ID check must occur before native execution handoff.

## 5.7 Clear/history lifecycle

On a successful full session clear:

- clear cancellation-intent metadata only after backend clear commits;
- preserve fail-closed metadata if backend clear throws.

When terminal completion is authoritatively observed:

- remove pending cancellation intent when it is no longer needed to prevent a
  Created resurrection;
- do not leave permanent cancellation metadata for terminal IDs.

## 5.8 Required tests — React Native

Run for native-proxy seam and Web backend.

### State-read failure resurrection oracle

1. Create/reconstruct a Created session.
2. Configure first state read to throw.
3. Call `cancel()`.
4. Assert:
   - cancel throws original state error;
   - ID cancellation intent is recorded.
5. Allow state/snapshot lookup to recover.
6. Call public `getSession(id)`.
7. Attempt `executeAsync()`.
8. Assert execution fails before native start.
9. Assert native execute call count is zero.

### Running case

- record cancellation intent;
- state is Running;
- native cancellation dispatch occurs;
- history remains inspectable;
- fresh wrapper execution remains impossible;
- terminal observation reconciles intent.

### Terminal case

- cancel terminal session;
- no Created tombstone;
- no native execution/cancellation misuse;
- intent does not become permanent.

### Clear failure/success

- failed backend clear preserves cancellation authority;
- successful clear removes it.

## 5.9 Required tests — Flutter

### Restored Created state-read failure

1. Build restored Created wrapper.
2. Make the first state read throw.
3. Call `cancel()`.
4. Assert original error is rethrown.
5. Drop/clear the live wrapper reference through the history test seam.
6. Reconstruct same ID.
7. Assert execution handoff is rejected by ID authority.
8. Assert native execute path is not entered.

### Restored Running

- cancellation intent recorded before state read;
- Running state dispatches native cancellation;
- history remains inspectable;
- terminal observation clears no-longer-needed cancellation intent.

### Existing new-session path

Retain regression proving direct new Created cancellation still abandons without
requiring a state read.

## 5.10 Exit criterion

The following must hold:

> Once `cancel()` records user intent for a session ID, a later wrapper cannot
> execute that same Created ID unless the cancellation authority is explicitly
> and safely reconciled by terminal/full-clear lifecycle—not merely because one
> state read threw.

---

# 6. R38-G3 — Remove quadratic tombstone maintenance

## 6.1 Objective

Preserve exact Created-session anti-resurrection while removing repeated
full-set scans that cannot reclaim the normal frozen-runtime Created tombstones.

Do not promise full tombstone memory boundedness if the frozen ABI makes exact
per-ID forgetting unsafe.

The goal is:

```text
no O(N²) repeated maintenance
+
fail-closed exact resurrection prevention
+
honest residual classification
```

## 6.2 Treat Review 37 runtime evidence as authority

Do not redownload/re-review native source.

The tracker already records the required runtime discriminator:

```text
Created ID remains directly discoverable after abandonment and handle release
history capacity reduction does not evict the Created identity
full clear removes it
```

Use that evidence as the design constraint.

Luna may rerun a **wrapper-level local oracle** only if code changes require
confirming behavior against the existing local `0.11.2` artifact. This is not a
native-source review.

## 6.3 Remove "scan all tombstones every 32 abandonments"

The current threshold counter is not a true bound.

Remove or redesign:

```text
_abandonmentEventsSinceReconciliation
abandonmentEventsSinceReconciliation
reconcile all tombstones at threshold
```

Do not replace 32 with another arbitrary threshold. That changes constants, not
complexity.

## 6.4 Candidate-driven reconciliation

A tombstone should be probed only when there is a reason it may have
disappeared.

Separate tombstones into semantic categories such as:

```text
known-present Created tombstone
reconciliation candidate
```

A known-present tombstone should not be re-probed after every unrelated batch of
new abandonments.

Possible candidate triggers include:

- successful backend/full history clear;
- a direct internal lookup already returned absence;
- a native/Web operation specifically invalidated that ID;
- a lifecycle event known to remove the underlying session;
- explicit low-frequency maintenance where the ID has not already been proven
  persistently present under the current lifecycle generation.

Do not invent a native event that does not exist.

## 6.5 Per-generation strategy

A simple safe wrapper model is:

```text
history/registry generation increments on successful full clear

tombstone record:
  id
  lastExistenceProbeGeneration
  knownPresentInGeneration
```

If the ID was proven present in the current generation:

- do not probe it again merely because another session was abandoned.

After a successful full clear:

- all tombstones are cleared anyway.

This eliminates repeated scans for the exact frozen-runtime case.

If other wrapper operations can remove individual IDs, mark only those IDs as
candidates.

## 6.6 Maintenance budget

If a candidate queue is retained:

- probe a bounded number of **candidates**, not the entire tombstone set;
- never loop all known-present IDs from a latency-sensitive cancel/discard path;
- keep one operation's maintenance work O(1) or O(K) for a small fixed candidate
  budget.

Do not confuse a bounded per-event budget with arbitrary eviction. A still-live
ID remains tombstoned.

## 6.7 React Native native optimization

Do not use full `getSessionJson()` serialization merely to answer "does this ID
exist?" if an existing wrapper/native module scalar/existence seam already
provides a cheaper safe result.

However:

- do not add a frozen native ABI export;
- do not edit `libs/libffmpegkit`;
- do not use a state call that throws on absence if that makes absence
  indistinguishable from transport failure.

If `getSessionJson()` remains the only trustworthy wrapper seam, restrict its
use to actual reconciliation candidates rather than scanning every tombstone.

## 6.8 React Native Web optimization

Avoid repeated:

```text
ffmpeg_kit_get_session
-> ffmpeg_kit_handle_release
```

for IDs already proven persistent in the current lifecycle generation.

Maintain fail-closed behavior when lookup/release fails.

## 6.9 Flutter optimization

Avoid repeated synchronous:

```text
getSessionById
-> releaseSession
```

for known-present abandoned Created IDs.

Keep successful full clear semantics introduced by Review 37:

```text
backend clear succeeds
-> clear abandonment authority
```

If backend clear fails, preserve tombstones.

## 6.10 Memory residual

Under the recorded frozen ABI, exact anti-resurrection may require:

```text
O(number of abandoned Created IDs since last successful full clear)
```

ID-only metadata.

Do not hide this.

Do not delete a live tombstone to satisfy a wrapper capacity.

Do not claim "bounded by session history capacity" when Created native IDs are
not actually evicted by that capacity.

The required improvement is to ensure CPU/backend-call maintenance does not also
grow quadratically.

## 6.11 Optional exact compression

Only consider an exact compact representation if the necessary session-ID
properties are already established by wrapper contract/evidence.

Examples might include exact interval/range compression if IDs are guaranteed
monotonic/non-reused.

Do **not** assume those properties from intuition.

Do not inspect or modify native source to justify an optional optimization.

If the guarantee is not already explicit, keep the exact Set/Map representation
and accept the memory residual.

## 6.12 Required performance/oracle tests

Add instrumentation-friendly unit tests that count existence probes.

### 10,000 abandonment regression

For each relevant backend authority:

```text
abandon 10,000 IDs that all remain present
```

Assert:

- all IDs remain fail-closed;
- probe count is O(N) or better, not O(N²);
- no individual known-present ID is repeatedly probed after every threshold;
- the 10,000th abandonment does not scan all previous live tombstones.

A practical test can assert a strict maximum probe count based on the chosen
algorithm.

### Dead candidate

- create tombstone;
- mark/provide underlying ID absent;
- run the specific candidate reconciliation event;
- tombstone is removed.

### Error

- existence probe throws;
- tombstone remains;
- no resurrection.

### Full clear

- backend clear succeeds;
- all tombstones/cancellation-intent metadata cleared according to contract.

### Failed clear

- metadata remains fail-closed.

## 6.13 Exit criterion

The following statement must be true:

> Abandonment maintenance never repeatedly scans every known-present Created
> tombstone in response to unrelated cancellations. Exact anti-resurrection is
> preserved, and any frozen-ABI memory residual is documented rather than hidden
> behind ineffective periodic scans.

---

# 7. R38-G4 — Focused regression and local platform matrix

Do not start the broad matrix until the focused G1–G3 oracles are green.

No hosted wrapper CI is acceptance evidence.

---

## 7.1 Flutter focused gate order

First disable analytics:

```text
flutter config --no-analytics
dart --disable-analytics
```

Then run the narrow suites covering the changed semantics.

At minimum include:

```text
test/ownership_callback_regression_test.dart
test/session_history_index_test.dart
test/session_lifecycle_test.dart
test/session_queue_manager_test.dart
test/ffplay_execution_boundary_test.dart
test/abandonment_reconciliation_oracle_test.dart
```

Add new focused files if they make the semantic boundary clearer, but do not
name them after Review 38 goals/findings.

Required coverage from G1:

- restored completion bridge demand;
- restored log bridge demand;
- restored statistics bridge demand;
- multiple restored-session bridge refcount;
- coexistence with global callback demand;
- install-failure rollback;
- terminal release/unregister.

Required coverage from G2:

- restored Created cancel + state-read failure;
- reconstruction cannot execute;
- Running cancellation;
- terminal cancellation;
- clear success/failure.

Required coverage from G3:

- 10,000-event probe-count bound;
- known-present tombstones are not repeatedly rescanned;
- absent candidate removal;
- fail-closed probe error.

Then run:

```text
flutter test --no-pub --exclude-tags native
```

or the current package-wide local non-native gate used by the project if its
contract has changed.

Run bounded analysis on changed Dart files.

Do not treat unrelated analyzer info/warnings as Review 38 defects unless the
changed code introduced them.

---

## 7.2 React Native focused gate order

Use the current local Node/npm toolchain and task-local npm cache if the default
cache is unwritable.

Run:

```text
npm run typecheck
npm run test:compile
npm run lint
npm run test:unit
```

Then focused Node suites covering:

```text
session queue
Wasm session ownership
native bridge lifetime/history
session-history registry
Wasm backend memory/ownership
scalar session state
MediaInformation classification
callback demand
```

Add explicit new tests for:

- cancel state-read failure + reconstructed execution rejection;
- ID cancellation authority;
- clear failure/success;
- tombstone probe complexity;
- candidate-only reconciliation.

Run the C++ dynamic bridge syntax check if any wrapper C++ source changes.
R38-G1/G2/G3 should not require a native ABI change.

Do not count stale tests that assert superseded pre-contract ownership models as
acceptance failures, but do not skip a test simply because it is inconvenient.
If a test is obsolete, update it to the current supported semantic contract and
state why.

---

# 8. Ordered local cross-platform validation

After focused suites are green, validate in the existing required order.

## 8.1 Windows first

Use the existing configured local Windows `0.11.2` archive.

Flutter:

- package tests requiring the local Windows runtime;
- affected Windows build.

React Native:

- package gates;
- Windows build through the established Git-for-Windows/MSBuild path.

Do not fetch an old remote artifact.

## 8.2 Android on local Windows

Use the existing WSL-local AAR configured by the project.

Flutter Android build.

React Native Android build using the installed Windows Android toolchain.

Do not substitute a WSL Android build if the established gate is Windows-hosted.

## 8.3 Linux under WSL

Use the existing local Linux archive.

Run analytics-disabled WSL Flutter commands.

Regenerate WSL package metadata only if required by shared Windows/WSL generated
paths, and record that as an environment repair rather than product evidence.

## 8.4 Wasm/Web

Use the existing local Wasm artifact.

Flutter:

- Wasm build;
- existing noninteractive COOP/COEP browser smoke if materially affected.

React Native:

- `prepare-web`;
- packed consumer/build gates;
- repository Web smoke.

G1 changes callback bridge ownership and therefore materially affect Web callback
transport; include a noninteractive runtime smoke that exercises callback/log
delivery if the repository already has an appropriate headless fixture.

Do not launch an interactive app.

## 8.5 Apple last

Use the existing universal XCFramework archives on the MacBook Air.

Run noninteractive Flutter macOS/iOS build gates and React Native iOS/tvOS/macOS
build gates that are materially affected by shared Dart/TS wrapper changes.

No interactive simulator/device operation.

If SSH PATH/locale needs correction, record the correction and rerun the exact
intended gate.

---

# 9. Validation truthfulness requirements

For every command recorded in the tracker:

- record the exact command;
- record the actual exit/result;
- record actual test counts when available;
- distinguish a diagnostic attempt from acceptance evidence;
- do not call a command "passed" if it timed out, was killed, or never reached
  the intended target;
- if a failure is environmental, prove the environment diagnosis before
  reclassifying it;
- if a failure reveals a product issue, do not relabel it as environment noise.

If a broad test file has known stale fixtures, isolate the actual current
production scenario with a truthful focused oracle and separately note the stale
fixture. Do not use fixture staleness to dismiss a real failure.

---

# 10. R38-G5 — Reconcile evidence and freeze exact wrapper source

After G1–G4 are complete:

1. Re-read all changed production files.
2. Confirm no planning identifiers leaked into semantic production names.
3. Confirm no native ABI/submodule/builder source changed.
4. Confirm local artifact configuration still points to the approved current
   local artifacts.
5. Clean generated task-owned staging/output as appropriate.
6. Verify clean wrapper worktree except intentional tracker/report updates.
7. Record:
   - final implementation commits;
   - exact final wrapper SHA;
   - exact tree;
   - native gitlink.
8. Push final wrapper implementation to `origin/dev-wasm`.
9. Only after the exact wrapper SHA is frozen, dispatch the reusable repository
   source snapshot workflow once.
10. Do not dispatch hosted Flutter/React Native acceptance workflows.

Verify the final source snapshot:

```text
workflow head SHA == frozen wrapper SHA
snapshot-metadata.snapshot_sha == frozen wrapper SHA
artifact digest matches connector metadata
source.tar.gz SHA-256 matches source.tar.gz.sha256
SHA256SUMS verifies every file
SUBMODULES.txt contains the frozen gitlink
SYMLINKS.tsv matches metadata
runtimeExecution == false
```

Record in `.agent/TRACKER.md`:

- workflow run ID;
- source artifact name;
- artifact ID;
- artifact digest;
- source archive SHA-256;
- manifest count;
- recursive submodule state;
- runtimeExecution state.

Do not create/download another native/builders snapshot.

After final wrapper snapshot verification, stop automated interactive work.

---

# 11. Hard implementation order

```text
R38-G1 restored Flutter bridge-demand ownership
-> focused Flutter bridge-demand tests
-> commit/push G1 where practical

R38-G2 durable ID-scoped cancellation intent
-> focused Flutter + RN cancellation reconstruction tests
-> commit/push G2 where practical

R38-G3 candidate-driven tombstone reconciliation
-> probe-count/performance oracles
-> clear/failure anti-resurrection regressions
-> commit/push G3 where practical

-> combined focused Flutter/RN regressions
-> R38-G4 Windows
-> Android on local Windows
-> WSL Linux
-> Wasm/Web
-> Apple last

-> R38-G5 tracker/evidence reconciliation
-> freeze exact wrapper SHA
-> one wrapper-only source snapshot
-> verify artifact/manifests
-> STOP
-> user-owned final interactive runtime validation
```

---

# 12. Luna implementation checklist

Before closing G1:

```text
[ ] restored completion sink activates its own bridge
[ ] restored log sink activates log bridge
[ ] restored FFmpeg statistics sink activates statistics bridge
[ ] no unrelated session/global callback required
[ ] multiple observer leases refcount correctly
[ ] failed install rolls back callback/map/lease state
[ ] terminal settlement releases completion observer demand
[ ] dispose remains exactly-once
```

Before closing G2:

```text
[ ] cancellation ID intent recorded before fallible state classification
[ ] React Native state-read failure cannot resurrect executable Created wrapper
[ ] Flutter restored Created state-read failure cannot resurrect executable wrapper
[ ] Running cancel remains inspectable and dispatches native cancellation
[ ] terminal cancel does not create permanent stale metadata
[ ] clear success/failure preserves fail-closed ordering
```

Before closing G3:

```text
[ ] no every-32 full tombstone scan
[ ] known-present tombstones are not repeatedly probed
[ ] candidate absence removes tombstone
[ ] probe error preserves tombstone
[ ] 10k abandonment probe count is bounded by algorithm, not quadratic
[ ] no still-live Created tombstone is evicted just to meet a memory cap
[ ] frozen-ABI O(N)-until-clear residual is recorded honestly if still applicable
```

Before final freeze:

```text
[ ] all focused tests green
[ ] ordered local matrix complete
[ ] no remote old binary used
[ ] no hosted wrapper acceptance CI used
[ ] no native publication
[ ] native gitlink unchanged
[ ] no builder checkout mutation
[ ] task-owned processes cleaned
[ ] exact wrapper SHA frozen and pushed
[ ] one wrapper source snapshot verified
```

---

# 13. Final Luna handoff

Review 38 is wrapper-owned. Do not treat the frozen native ABI as an
implementation task.

The three product invariants are:

1. **Restored Running Flutter observers own the bridge demand required to
   receive their own completion/log/statistics events. Their behavior cannot
   depend on an unrelated bridge owner.**

2. **An explicit cancellation request becomes durable by native session ID
   before a fallible state read. A transient state-oracle failure cannot make a
   later wrapper executable again.**

3. **Exact Created-session anti-resurrection remains fail-closed, but wrapper
   maintenance must not repeatedly rescan every persistent tombstone. If the
   frozen ABI forces ID-only retention until full clear, preserve that residual
   honestly while eliminating quadratic backend work.**

Implement those invariants with semantic names, prove them with genuine local
oracles, validate only against the existing frozen local artifacts, and then
freeze/snapshot only the wrapper source.
