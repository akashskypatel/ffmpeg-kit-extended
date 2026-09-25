# Review 33 — Luna Cross-Platform Flutter + React Native Remediation Plan

**Audience:** Luna model  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch:** `dev-wasm`  
**Starting wrapper authority:** `bbdc02c942754cd3e3dbce1ded0ef59674fd5dd6`  
**Review basis:** `review33-cross-platform-code-review.md`  
**Native ABI:** frozen/read-only; do not download, re-review, modify, rebuild, or republish it  
**Native runtime version:** `0.11.2`

## Goal tracker

| Goal | Objective | Status |
| --- | --- | --- |
| **R33-G1** | Make Flutter session-history inspection ownership-safe so read APIs cannot cancel Running sessions | **Pending** |
| **R33-G2** | Make React Native native/Web history inspection ownership-safe without reintroducing the Review 31/32 history-mirror defects | **Pending** |
| **R33-G3** | Give React Native native monitoring a scalar session-state path instead of full-session JSON polling | **Pending** |
| **R33-G4** | Run focused and affected cross-platform local wrapper regression against the existing frozen local ABI artifacts | **Pending** |
| **R33-G5** | Reconcile affected behavior/tracker, freeze the exact wrapper SHA, and create one wrapper-only source snapshot | **Pending** |

---

# Mandatory constraints

1. Do **not** modify `libs/libffmpegkit`, FFmpegKit native source, the ManyLinux builder checkout, or the frozen ABI.
2. Do **not** download or re-review a builders/native source snapshot.
3. Do **not** publish a native ABI/runtime bundle.
4. Do **not** fetch remotely built or published old ABI artifacts for validation.
5. Use only the already-established local Windows/Linux/Wasm/Android artifacts and MacBook Air universal Apple XCFramework archives.
6. Do not use hosted Flutter/React Native CI as acceptance evidence for this unpublished/frozen ABI integration.
7. Do not launch or operate interactive Flutter/React Native apps. Final interactive validation remains user-owned after the wrapper freeze.
8. Implementation identifiers must be semantic. Do not use `R33`, finding IDs, goal IDs, review names, or plan names in classes, variables, methods, files, or public API names.
9. Tests must be genuine. Do not fabricate tests/results, weaken scenarios, or claim commands ran when they did not.
10. Immediately disclose mistakes, wrong assumptions, failed commands, and unexpected mutations.
11. Preserve the primary error if cleanup also fails.
12. Tag and observe all task-owned Flutter/Dart/Node/PowerShell/WSL/compiler/browser-server processes to completion and clean leftovers.
13. Use analytics-disabled Flutter/Dart commands.
14. Commit and push meaningful completed remediation goals separately when practical.
15. Final closeout creates **one wrapper source snapshot only**. Do not create another builders/native snapshot.

---

# Source preparation

Before changing code:

1. Verify repo/branch and record the exact starting SHA/tree.
2. Verify the checkout contains or descends from `bbdc02c942754cd3e3dbce1ded0ef59674fd5dd6`.
3. Verify the `libs/libffmpegkit` gitlink is unchanged at the already-frozen authority without re-reviewing its source.
4. Verify example resolver/build-hook configuration still points to the established local artifacts.
5. Read this plan, `review33-cross-platform-code-review.md`, and `.agent/TRACKER.md`.
6. Do not reopen accepted Review 23–32 dispositions unless a changed wrapper path directly contradicts them.
7. If live `dev-wasm` has changes after the frozen snapshot, reconcile them explicitly; never overwrite newer work silently.

---

# R33-G1 — Flutter ownership-safe history inspection

## Objective

Make every Flutter history/lookup API observational for a Running session.

These APIs must not cancel, stop, dispose, or otherwise mutate an active execution merely because the caller reads history:

- `getSessions()`;
- typed session-history methods;
- `getSession(id)`;
- `getLastSession()` and typed last-session methods;
- the FFmpeg/FFprobe/FFplay convenience history methods.

## Invariant

Never call `releaseSession()` on a handle for a Running session as part of a read-only history operation.

Do not solve this by simply retaining every duplicate Running handle until terminal state: repeated history polling would turn the correctness bug into an unbounded handle leak.

## Preferred design

Introduce a lightweight wrapper-owned **history identity index**, separate from callback ownership.

The index should record enough immutable metadata to identify history entries safely:

- session ID;
- session type;
- creation order;
- whether the entry remains history-visible.

It must not strongly retain all Session objects.

Use existing live wrapper ownership for queued/Running sessions. For an active ID, return/reuse the already-owned live Dart session object without asking the frozen native history API for a new owning handle.

For Created/terminal history entries, use temporary native handles only when their release is known to be non-cancelling.

### Bounding semantics

The index must remain bounded by:

```text
currently Created/queued/Running entries
+ configured retained terminal history
```

Do not reintroduce an unbounded lifetime shadow.

When history capacity changes, prune only terminal entries according to the already-established frozen-native history policy. Created/Running sessions must not be dropped solely because terminal-history capacity is exceeded.

`clearSessions()` must reconcile history visibility without destroying unrelated Dart callback/execution ownership.

## Required regressions

Add genuine tests covering native and Web wrapper behavior through test seams:

- active FFmpeg session + `getSessions()` does not call release on the active history identity;
- active FFprobe, FFplay, and MediaInformation variants;
- `getSession(activeId)` is observational;
- `getLastSession()` and typed last-session calls are observational;
- repeated history reads while Running do not accumulate deferred handles;
- terminal history handles are still released exactly once;
- Created-session history remains visible according to capacity semantics;
- history ordering and typed filtering remain correct;
- capacity shrink/grow behavior;
- `clearSessions()` behavior;
- no strong-reference leak of terminal session objects.

If the frozen ABI makes one required case impossible without cancelling or leaking a Running handle, stop G1 and record exact evidence. Do not change the ABI.

---

# R33-G2 — React Native ownership-safe native/Web history

## Objective

Make React Native history snapshots read-only for active sessions on both native and Web.

## Native bridge

Replace the Review 32 direct-list-handle release pattern for active history.

Do not simply keep owning list handles alive.

A correct bounded identity authority may build on the earlier `knownSessionIds` concept, but it must fix both prior defects:

- Review 31: lifetime-unbounded/incorrectly-pruned mirror;
- Review 32: direct native list handles that are unsafe to release while Running.

Recommended authority:

- record ID/type/order when a wrapper creates a session;
- maintain active execution IDs through `retainedSessionHandles`;
- borrow retained handles for active serialization;
- for non-active entries, obtain temporary handles only where release is safe;
- prune oldest terminal entries according to native history capacity;
- allow Created/Running entries to temporarily exceed terminal history capacity as required by frozen semantics;
- remove IDs when native lookup proves they no longer exist;
- reconcile capacity changes and registry clear;
- preserve exact creation and `lastSession` ordering.

Do not call a native history-list export merely to obtain a fresh owning handle for an ID already known to be Running.

## Web backend

Apply the same semantic model to `backend.web.ts`.

The Web backend already has:

- `this.sessions` for retained execution handles;
- `executingSessions` for active execution IDs.

History projection must use those retained pointers for active entries and must not feed active history pointers into `withTemporaryHandle()` / unconditional `ffmpeg_kit_handle_release`.

Native and Web must return equivalent history ordering/filtering behavior.

## Required regressions

Cover both backend families:

- active session survives `getSessionsJson('all')`;
- active typed session survives typed list lookup;
- active session survives `getLastSessionJson`;
- repeated active history reads do not increase retained-handle count;
- terminal history handles release exactly once;
- `N+1` Created sessions with terminal capacity `N` retain the Created entries required by native semantics;
- terminal pruning;
- ordering and typed filtering;
- history size shrink/grow;
- `clearSessions()`;
- missing native entries reconcile without an unbounded stale mirror.

Include a source-level/native-bridge oracle only as supplemental evidence; behavioral ownership tests must be the primary gate.

---

# R33-G3 — React Native scalar native state transport

## Objective

Remove complete-session JSON serialization from the steady-state native monitor path.

## Required implementation

Expose `getSessionState(sessionId)` as a real wrapper-module method across the React Native native module surfaces:

- TypeScript TurboModule spec;
- generated/codegen-facing shape as required;
- shared C++ implementation;
- Windows implementation if it has a separate surface;
- Android/Apple Cxx module path.

Implementation must:

1. use existing ownership-safe session acquisition/borrowing;
2. call the already-exported frozen ABI symbol `ffmpeg_kit_session_get_state`;
3. return only the scalar lifecycle state;
4. never fetch output, complete logs, command, statistics, or fail stack;
5. preserve the same missing-session/error behavior expected by `Session.getState()`.

Update `backend.native.ts` so normal native execution uses the scalar method directly instead of:

```text
getSessionJson -> JSON.parse -> .state
```

React Native Web already has the desired scalar implementation; keep it behaviorally aligned.

Do not add any FFmpegKit ABI export.

## Required regressions/performance oracle

Prove that one native `getState()`:

- invokes scalar state lookup;
- does not call `getSessionJson`;
- does not call output/log-string getters;
- preserves missing-session errors;
- works for Created, Running, Completed, and Failed.

Add a bounded monitor-performance oracle using instrumentation/counters rather than wall-clock timing:

- run many monitor polls;
- assert state calls scale with poll count;
- assert complete-output/log snapshot calls remain zero in steady state;
- retain existing terminal reconciliation behavior.

This is an operation-count oracle, not a flaky timing benchmark.

---

# R33-G4 — Local affected regression

Do not start broad validation until G1–G3 focused regressions pass.

## Flutter

Run analytics-disabled:

- affected history/ownership tests;
- session queue/lifecycle suites;
- callback ownership regressions;
- full non-native Flutter package suite;
- bounded analysis of changed files.

Use the existing local native artifact only if an affected test genuinely requires it.

## React Native

Run locally:

- typecheck;
- test compilation;
- history ownership tests;
- session queue/lifecycle tests;
- scalar state bridge/codegen tests;
- native bridge syntax/compile oracle;
- Web ownership tests;
- package check.

Serialize shared-fixture tests when necessary rather than accepting worker interference.

## Platform order

Use existing local artifacts only:

1. Windows
2. Android on the established Windows host
3. Linux under WSL
4. Wasm/Web local build and browser smoke
5. Apple last on the MacBook Air using existing universal XCFramework archives

Only platform builds materially affected by changed native-wrapper/module surfaces are mandatory, but both wrapper package gates must be green.

Because G3 changes the RN native module/codegen surface, validate at least:

- React Native Android;
- React Native Windows;
- React Native iOS;
- React Native tvOS/macOS where the common Apple Cxx module surface is affected.

No interactive application execution.

## Artifact authority

Continue using the established local Review 24+ artifacts. If a required local file is absent, mark the gate blocked; do not substitute a remote artifact.

---

# R33-G5 — Exact wrapper closeout

Update documentation only where behavior materially changed:

- history reads are observational and do not cancel active sessions;
- RN native state polling uses a scalar bridge;
- tracker evidence.

Do not perform unrelated cleanup.

After all implementation/evidence is complete:

1. verify clean wrapper worktree;
2. record exact wrapper SHA/tree;
3. verify the frozen `libs/libffmpegkit` gitlink is unchanged;
4. push final wrapper source to `origin/dev-wasm`;
5. dispatch the repository source-snapshot workflow once for the wrapper exact SHA;
6. verify artifact digest, embedded `source.tar.gz`, manifest count, recursive submodule state, and `runtimeExecution=false`;
7. record the wrapper workflow run/artifact details in `.agent/TRACKER.md`.

Do **not** create or download another builders/native snapshot for Review 33.

After snapshot verification, stop automated interactive work. Final interactive Flutter/React Native validation is user-owned.

---

# Hard execution order

```text
R33-G1 Flutter history ownership
-> R33-G2 React Native native/Web history ownership
-> R33-G3 RN scalar native state transport
-> focused ownership/state regressions
-> R33-G4 affected local package/platform gates
-> R33-G5 tracker/docs reconciliation
-> exact wrapper commit
-> one wrapper-only source snapshot
-> STOP
-> user-owned final interactive runtime validation
```

## Final Luna handoff

Review 33 is wrapper-only. The native ABI is not a work item.

The key invariant is simple:

> Reading session history must never cancel the session being observed.

After that invariant is restored on Flutter and React Native, remove full-session JSON/log copying from the React Native native state-monitor hot path, validate only against the existing local frozen artifacts, then freeze and snapshot only the wrapper source.
