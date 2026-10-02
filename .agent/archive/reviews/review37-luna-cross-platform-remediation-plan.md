# Review 37 — Luna Cross-Platform Flutter + React Native Remediation Plan

**Audience:** Luna model  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch:** `dev-wasm`  
**Starting wrapper authority:** `421946a3279e055a27a3dbd9141234e305f70e5d`  
**Review basis:** `review37-cross-platform-code-review.md`  
**Native ABI/runtime:** `0.11.2`, frozen/read-only  
**Native submodule:** `b74da2c5d1e294b87d15d73a6687393729e932b3`

## Goal tracker

| Goal | Objective | Status |
| --- | --- | --- |
| **R37-G1** | Give restored Running Flutter sessions a real terminal-completion owner independent of queue settlement | **Pending** |
| **R37-G2** | Make Flutter queue settlement failure-atomic when deferred disposal/release fails | **Pending** |
| **R37-G3** | Make Flutter/RN native/RN Web abandonment tombstones clearable and lifecycle-bounded without reopening Created-session resurrection | **Pending** |
| **R37-G4** | Run focused and affected local cross-platform wrapper regression using only existing frozen local artifacts | **Pending** |
| **R37-G5** | Reconcile evidence, freeze exact wrapper SHA, and create one wrapper-only source snapshot | **Pending** |

---

# Mandatory operating constraints

1. Work only in the Flutter and React Native wrapper repository.
2. `libs/libffmpegkit`, FFmpegKit native source, and
   `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders` remain read-only.
3. Do **not** download or re-review a native/builders source snapshot.
4. Do **not** rebuild, modify, or publish the native ABI.
5. Do **not** fetch a remote/published old ABI bundle for tests.
6. Keep native runtime pinned to **0.11.2** for local artifact authority.
7. Use only the established local Windows/Linux/Wasm/Android artifacts and the
   MacBook Air universal Apple XCFramework archives already recorded in the
   tracker.
8. Do not use hosted Flutter/React Native acceptance CI as evidence.
9. Do not launch or operate interactive Flutter/React Native applications.
10. Production identifiers must be semantic. `R37`, finding IDs, goal IDs,
    review names, and plan names are tracker metadata only.
11. Tests must be real executable oracles. Never fabricate results, weaken a
    scenario to pass, or claim execution that did not occur.
12. Record mistakes, failed commands, retries, environment corrections, and
    unexpected mutations truthfully.
13. Preserve primary execution/cancellation errors over cleanup errors.
14. Do not hide cleanup errors when execution otherwise succeeded.
15. Run Flutter/Dart with analytics disabled.
16. Tag and observe all task-owned Flutter/Dart/Node/PowerShell/WSL/compiler/SSH
    processes and clean task-owned output.
17. Commit and push meaningful completed goals separately where practical.
18. Final closeout creates **one wrapper source snapshot only**.
19. Do not reopen accepted Review 23–36 native or wrapper dispositions unless
    changed wrapper source provides direct contradictory evidence.

---

# Source preparation

Before editing:

1. Verify repository `akashskypatel/ffmpeg-kit-extended`, branch `dev-wasm`.
2. Record starting HEAD/tree.
3. Verify the checkout contains or descends from
   `421946a3279e055a27a3dbd9141234e305f70e5d`.
4. Verify the frozen `libs/libffmpegkit` gitlink remains
   `b74da2c5d1e294b87d15d73a6687393729e932b3` without inspecting native source.
5. Verify Flutter/RN example resolver configuration still points to established
   local artifacts.
6. Read:
   - `review37-cross-platform-code-review.md`;
   - this plan;
   - `.agent/TRACKER.md`.
7. If live `dev-wasm` contains later work, reconcile it explicitly before
   editing and do not overwrite it silently.

---

# R37-G1 — Restored-session terminal completion ownership

## Objective

A restored Running Flutter session that observes native completion must settle
its completion-observer lifecycle even though it was not submitted through the
local `SessionQueueManager`.

The fix must apply to:

- FFmpegSession;
- FFprobeSession;
- MediaInformationSession;
- FFplaySession.

## Required semantic distinction

Do not use one `_executionSettled` bit to mean both:

```text
local queue execution settled
and
terminal native completion was observed
```

Those are distinct lifecycle events.

Introduce semantic state such as:

```text
terminal completion observed
completion fan-out active
queue settlement required
queue settlement complete
deferred disposal requested
```

Names may differ; they must describe behavior.

## Required restored completion lifecycle

For a restored Running session:

```text
native terminal callback arrives
-> terminal history commit
-> enter completion lifetime barrier
-> local completion callback
-> global completion callback
-> exit completion lifetime barrier
-> mark observer-only completion settled
-> unregister terminal callback routing
-> commit deferred physical disposal if requested
```

No queue reservation or queue-active state should be invented.

## Queue-owned sessions

For locally submitted sessions:

```text
authoritative terminal observation
-> terminal history commit
-> completion fan-out
-> queue settlement
-> deferred physical disposal
```

Keep queue reservation cleanup owned by `SessionQueueManager`.

The restored-session fix must not prematurely release queue reservations for
normal submitted execution.

## Callback registration cleanup

A terminal restored observer must not remain permanently rooted in:

```text
CallbackManager.ffmpegSessions
CallbackManager.ffprobeSessions
CallbackManager.ffplaySessions
CallbackManager.mediaInformationSessions
```

after completion merely because application code did not manually remove the
callback.

Prefer idempotent terminal unregistration at the completion boundary.

## History

Restored Running sessions that reach terminal completion must:

- become terminal in wrapper history;
- participate in normal terminal-capacity pruning;
- not remain forever classified nonterminal.

If the history entry was previously hidden by `clearSessions()`, preserve the
existing hidden-entry removal semantics.

## Deferred disposal

If a restored completion callback calls `dispose()`:

- keep the handle valid through local/global fan-out;
- do not wait for queue settlement that will never occur;
- release exactly once after observer completion settlement;
- keep finalizer/error-handler/bridge cleanup ordering intact.

## Required focused tests

For each of FFmpeg, FFprobe, MediaInformation, FFplay:

1. create a restored Running test wrapper;
2. register completion routing;
3. dispatch terminal completion without queue submission;
4. local callback calls `dispose()`;
5. global callback observes a still-valid, not-yet-physically-disposed session;
6. callback map is unregistered after fan-out;
7. terminal history is reconciled;
8. physical release occurs exactly once;
9. no queue settlement call is needed.

Additional cases:

- no explicit disposal: callback map unregisters but the owned wrapper handle
  remains valid until ordinary caller disposal, if this remains the selected
  ownership contract;
- local callback throws;
- global callback throws;
- hidden history entry;
- duplicate native completion dispatch remains exactly once;
- restored terminal session cannot re-register as Running.

## Exit criterion

Restored completion is a first-class terminal lifecycle rather than a queue
lifecycle accidentally missing its final step.

---

# R37-G2 — Failure-atomic Flutter queue settlement

## Objective

No settlement/deferred-disposal failure may strand:

- `_activeSessions`;
- `_reservedSessionIds`;
- later queue processing;
- `waitForAll()`.

No settlement error may disappear after the public execution Future has already
reported success.

## Refactor `_executeQueuedSession` as a transaction

Do not complete the public `queued.completer` before queue settlement finishes.

Capture:

```text
execution result / execution error
settlement error
```

Then execute queue bookkeeping in unconditional cleanup.

Required conceptual sequence:

```text
run executor and capture result/error
-> attempt session.markExecutionSettled()
-> ALWAYS remove active session
-> ALWAYS release native session-ID reservation
-> ALWAYS trigger next queue processing
-> choose final public result/error
-> complete public completer exactly once
```

Use nested `try/finally` or equivalent.

## Error authority

Required ordering:

### Executor failed, settlement also failed

Public result:

```text
executor error is primary
```

Settlement/release error:

- log/store as secondary diagnostic according to existing project convention;
- must not strand queue state.

### Executor succeeded, settlement failed

Public result:

```text
settlement/release error
```

Do not report success first and lose the later release error.

### Both succeeded

Complete successfully only after queue ownership is fully cleaned.

## Deferred disposal retryability

If physical release fails:

- `Session.dispose()` semantics must remain retryable if that is the existing
  contract;
- queue ownership must nevertheless be released because native execution itself
  has ended;
- retrying explicit `dispose()` later must not reacquire queue reservation.

## Required focused tests

At minimum:

- successful execution + deferred dispose + release success;
- successful execution + deferred dispose + release failure;
- executor failure + deferred release failure;
- active set empty after every terminal path;
- reservation removed after every terminal path;
- next queued item begins after every terminal path;
- `waitForAll()` terminates;
- public Future is not completed before settlement error authority is known;
- repeated explicit dispose after failed release retries physical release but
  does not affect queue accounting.

Also rerun existing duplicate native-ID and queue-cancellation regressions.

## Exit criterion

Queue ownership cleanup is unconditional; result/error authority is deterministic.

---

# R37-G3 — Lifecycle-bounded abandonment authority

## Objective

Preserve Review 36 anti-resurrection semantics while preventing abandonment
tombstones from becoming permanent process-lifetime metadata.

Applies to:

- Flutter `SessionHistoryIndex`;
- React Native native backend tombstone authority;
- React Native Web `SessionHistoryRegistry`.

## Part A — Correct full-clear semantics

### Flutter

Current production `FFmpegKitExtended.clearSessions()` never clears
`_abandonedSessionIds`.

Add a semantic tombstone-clear operation that runs only after the native clear
successfully commits.

Do not blindly call `SessionHistoryIndex.clear()` if that would destroy live
identity bookkeeping needed for active-session ownership.

Prefer separate operations for:

```text
clear abandoned IDs
clear removable history identities
preserve/hide live execution identities
```

Required:

- successful `FFmpegKitConfig.clearSessions()` clears tombstones;
- failed backend clear leaves tombstones intact.

### React Native native

Current order is:

```text
abandonedSessionIds.clear()
-> native clear
```

Reverse the commit order:

```text
native clear succeeds
-> abandonedSessionIds.clear()
```

If native clear throws, abandoned IDs must remain fail-closed.

### React Native Web

Retain the safe order:

```text
underlying clear succeeds
-> history.clear()
```

and verify failure keeps tombstones.

## Part B — Normal tombstone reconciliation

Full clear alone is not sufficient.

Repeated Created-session abandonments in a long-lived application must not
create a second unbounded ID mirror after the underlying native IDs are gone.

### Frozen-ABI constraint

Do not add a native export.

Use only existing `0.11.2` operations.

Before choosing a reclamation strategy, run a focused local oracle against the
existing frozen artifact to determine what already-supported operations do to a
Created session:

- Created cancel;
- temporary handle release;
- history-capacity eviction where applicable;
- direct session lookup after each operation.

This oracle is validation of existing behavior, not native re-review.

### Acceptable wrapper strategies

One safe approach is a private **existence/reconciliation probe** that bypasses
the public tombstone gate:

```text
if underlying ID definitely no longer exists:
    remove tombstone
else:
    keep fail-closed tombstone
```

Another is to use an already-existing frozen ABI operation to reclaim the
Created session if the focused oracle proves that operation safe.

Do not delete tombstones solely because a wrapper capacity was exceeded while
the native ID still exists.

## Bounded maintenance triggers

Reconcile tombstones at bounded semantic events, such as:

- new abandonment after a threshold;
- history-size changes;
- explicit history maintenance;
- successful full clear;
- other existing low-frequency lifecycle boundaries.

Do not perform expensive full native scans in high-frequency state polling.

## Required tests

### Flutter

- abandon Created ID;
- successful production `FFmpegKitConfig.clearSessions()` clears tombstone;
- backend clear failure preserves tombstone;
- live execution ownership survives the established history-clear policy;
- repeated abandon/reconcile does not retain IDs whose native sessions are gone.

### RN native

- native clear success clears JS tombstones;
- native clear failure preserves them;
- direct lookup stays fail-closed while tombstone remains;
- dead native IDs are eventually reconciled out.

### RN Web

- clear failure preserves tombstone;
- clear success clears it;
- dead Wasm IDs can be reconciled without public reconstruction;
- ordinary Created/Running/terminal sessions retain current semantics.

### Cross-platform

- repeated abandonment does not grow metadata forever after native IDs are
  definitively gone;
- tombstone authority owns only IDs, never session objects or handles;
- no anti-resurrection regression.

## Residual frozen-ABI handling

If the frozen ABI cannot reclaim or safely prove disappearance of abandoned
Created sessions except through full clear:

- record that exact residual honestly;
- keep fail-closed tombstones;
- do not weaken anti-resurrection behavior;
- do not modify native source.

---

# R37-G4 — Focused and local cross-platform validation

Do not begin broad platform gates until G1–G3 focused regressions are green.

## Flutter focused gates

Run analytics-disabled:

- restored Running completion lifecycle tests for all four session families;
- completion local/global disposal tests;
- queue settlement/release failure tests;
- session history/tombstone clear tests;
- durable Created cancellation tests;
- `ownership_callback_regression_test.dart`;
- `session_history_index_test.dart`;
- `session_lifecycle_test.dart`;
- `session_queue_manager` regressions;
- `ffplay_execution_boundary_test.dart`;
- existing FFplay lifecycle suites;
- full non-native Flutter package suite;
- bounded analysis of changed files.

Use only the existing local Windows `0.11.2` artifact where genuine native
integration is needed.

## React Native focused gates

Run locally:

- `npm run typecheck`;
- `npm run test:compile`;
- `npm run lint`;
- `npm run test:unit`;
- queue-manager tests;
- native bridge lifetime/history tests;
- Web session-history registry tests;
- Wasm session ownership tests;
- scalar state monitor regression;
- MediaInformation Web classification regression;
- C++ dynamic bridge syntax check;
- package/consumer checks.

Do not weaken valid scenarios or hide a cleanup failure.

## Ordered local platform matrix

Use existing local artifacts only:

1. Windows
2. Android on Windows
3. Linux under WSL
4. Wasm/Web
5. Apple last on the MacBook Air

Run only builds/tests materially affected by the changed wrapper surfaces, while
retaining the established package gates.

No interactive application execution.

## Artifact policy

If a required local artifact is missing:

- mark only that gate blocked;
- continue unaffected local gates;
- do not substitute a remote/published old bundle.

No hosted acceptance workflow, no native publication, no builders/native
snapshot.

---

# R37-G5 — Evidence reconciliation and exact wrapper freeze

Update only tracker/review material affected by G1–G3 and actual validation.

Record:

- exact commands;
- actual pass/fail counts;
- failed/retried commands;
- environment corrections;
- any implementation mistakes;
- any residual frozen-ABI limitation.

After focused/local gates complete:

1. verify clean wrapper worktree;
2. record exact wrapper SHA/tree;
3. verify `libs/libffmpegkit` remains unchanged at
   `b74da2c5d1e294b87d15d73a6687393729e932b3`;
4. push final wrapper commits to `origin/dev-wasm`;
5. dispatch `.github/workflows/repo-source-snapshot.yml` once for the exact final
   wrapper SHA;
6. verify:
   - workflow head/source SHA;
   - outer artifact digest;
   - embedded `source.tar.gz` hash;
   - complete `SHA256SUMS`;
   - recursive submodule state;
   - `runtimeExecution=false`;
   - file/manifest count;
7. record exact snapshot provenance in `.agent/TRACKER.md`.

Do **not** create or download another builders/native snapshot for Review 37.

After the exact wrapper snapshot is verified, stop automated interactive work.
Final interactive Flutter/React Native runtime validation remains user-owned.

---

# Hard execution order

```text
R37-G1 restored Flutter completion ownership
-> R37-G2 failure-atomic Flutter queue settlement
-> R37-G3 bounded abandonment authority
-> focused regressions
-> R37-G4 Windows/Android/WSL/Wasm-Web/Apple local gates
-> R37-G5 tracker/evidence reconciliation
-> exact wrapper freeze
-> one wrapper-only source snapshot
-> STOP
-> user-owned final interactive runtime validation
```

## Final Luna handoff

Review 37 is entirely wrapper-owned. The native ABI is frozen and is not an
implementation work item.

The three required invariants are:

1. **A restored Running Flutter session that observes completion reaches a real
   terminal observer settlement even though no local queue owns it.**
2. **A deferred disposal/release failure can never strand Flutter queue active
   state, session-ID reservation, or later queued work.**
3. **Abandonment remains fail-closed but tombstone authority is cleared and
   reconciled safely instead of becoming append-only process-lifetime state.**

Implement those invariants with semantic names, prove them with genuine local
oracles, validate only against existing frozen local artifacts, then freeze and
snapshot only the wrapper source.
