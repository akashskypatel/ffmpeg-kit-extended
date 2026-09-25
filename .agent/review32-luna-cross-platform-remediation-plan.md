# Review 32 — Luna Cross-Platform Flutter + React Native Remediation Plan

Audience: Luna implementation agent  
Repository: `akashskypatel/ffmpeg-kit-extended`  
Branch: `dev-wasm`  
Starting wrapper authority: `a3017c2f2415a5ad5052f54f4382a2c2ff910dd9`  
Review basis: `review32-cross-platform-code-review.md`

## Scope and authority

Review 32 is wrapper-only. The native ABI and `libs/libffmpegkit` are frozen and read-only at the already-established Review 31 authority. Do not download, re-review, modify, rebuild, or publish native ABI/builder artifacts for this review.

The implementation must use the existing local artifact authority:

- Windows: `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders\prebuilt\windows-x86_64\releases\bundle-base-windows-x86_64-shared-lgpl.zip`
- Linux: `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders\prebuilt\linux-x86_64\releases\bundle-base-linux-x86_64-shared-lgpl.zip`
- Wasm/Web: `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders\prebuilt\wasm-wasm32\releases\bundle-base-wasm-wasm32-static-lgpl.zip`
- Android: `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders\tools\android\build\outputs\aar\bundle-base-shared-small-lgpl-release.aar`
- Apple: the recorded universal XCFramework archives under `/Users/akash/Projects/ffmpeg-kit-builders/prebuilt/apple/xcframeworks/`

No hosted Flutter/React Native acceptance workflow, remotely staged old binary, native ABI publication, or interactive Flutter/React Native runtime execution is allowed. Linux noninteractive work runs in WSL with `/mnt/d/Projects/ffmpeg_kit_extended` as the working directory. Flutter/Dart commands use analytics-disabled mode and elevated shells when local locking or hangs require it.

Implementation identifiers must describe behavior. `R32-*`, finding numbers, plan names, and milestone identifiers are metadata only and must not become class, variable, file, test, or public API names.

## Findings and goal tracker

| Metadata | Finding / objective | Status |
| --- | --- | --- |
| R32-F1 / R32-G1 | One execution claimant per native session ID across Flutter and React Native | Complete — native-ID reservations, Created handoff checks, and focused Flutter/RN regressions pass |
| R32-F2 / R32-G2 | Transactional React Native queue admission and cleanup | Complete — duplicate admission, sync/async failure cleanup, wait, and cancellation regressions pass |
| R32-F3 / R32-G3 | Native-authoritative React Native history enumeration without dropping Created sessions | Complete — history/last-session queries use frozen native exports directly |
| R32-G4 | Focused and ordered local wrapper regression | Complete — focused suites, package gates, and ordered local platform validation pass |
| R32-G5 | Documentation, exact wrapper freeze, and one wrapper-only source snapshot | Pending |

Close each goal only after its required evidence exists, the tracker is updated, and a meaningful commit is pushed. Keep failed commands and corrected assumptions explicit.

## Source preparation

Before code changes:

1. Verify the checkout is `akashskypatel/ffmpeg-kit-extended` on `dev-wasm` and record the exact starting SHA/tree.
2. Verify the live checkout contains or descends from `a3017c2f2415a5ad5052f54f4382a2c2ff910dd9`.
3. Verify `libs/libffmpegkit` is unchanged at the frozen authority and on its `dev` branch; do not re-review its source.
4. Verify Flutter and React Native example configuration still points to local files and has no remote fallback substituted for this work.
5. Read this plan, `review32-cross-platform-code-review.md`, and the current `.agent/TRACKER.md`.
6. Do not reopen accepted Review 23–31 dispositions unless a changed wrapper path directly contradicts one.

If the branch contains changes after the starting authority, reconcile them explicitly. Never silently overwrite newer work.

## R32-G1 — Native-session-ID execution ownership

### Objective

Prevent two wrapper objects from concurrently or incorrectly claiming execution of one native session ID. The invariant is native-session identity, not Dart or JavaScript object identity.

### Required behavior

- A short-lived execution-admission authority tracks queued/active ownership by native session ID.
- Queue admission rejects a conflicting queued or active claimant before callback registration or native execution routing is installed.
- State is revalidated at or immediately before native handoff; only `Created` sessions may start.
- Running, completed, or failed restored/history wrappers fail closed before native execution.
- Queue discard/cancel releases only the reservation that is safe to release; no reservation is stranded and no second claimant can enter.
- Existing per-object one-shot guards remain in place as defense in depth.
- Flutter native and Web, and React Native native and Web, expose equivalent rejection behavior.
- The authority remains bounded by queued/active ownership; it is not a permanent set of historical IDs.

### Flutter work

Add semantic session-ID admission around the existing queue and execution boundary. Cover distinct wrappers for one Created ID, active conflicts, restored terminal states, queue discard, cancellation, independent IDs, and existing same-object double-submit behavior. Rejected wrappers must not start native work or acquire callback ownership.

### React Native work

Bring native React Native execution admission to parity with the stricter Web backend. Preserve the existing `Session` one-shot behavior, but add session-ID ownership and a Created-state guard before the native async execution symbol. History reconstruction must not bypass the authority.

### Required tests

- Two distinct Flutter wrappers for one Created ID: first admitted, second rejected before executor/native start.
- First active and second conflicting wrapper rejected.
- Running/completed/failed restored wrappers rejected.
- Queue discard/cancel releases only the correct reservation.
- Distinct IDs remain independently admissible.
- Existing object-level one-shot tests remain green.
- React Native native and Web reject the same invalid states and permit distinct IDs concurrently.

## R32-G2 — React Native queue transaction integrity

### Objective

Make the public `SessionQueueManager` maintain exact active/concurrency accounting for every accepted item.

### Required behavior

- Reject an identical session object while queued or active; do not invoke `onDiscard` for an item never admitted.
- Keep distinct-object behavior valid unless the native-session-ID rule from G1 rejects it.
- Guard executor invocation so synchronous throws use the same settlement path as asynchronous rejection.
- Preserve the original executor result/error and its identity/stack where practical.
- Remove active membership exactly once, then process the next queued item exactly once.
- Never leak a concurrency slot; `waitForAll()` cannot resolve while an executor remains active.
- Preserve Review 31 all-target/first-error cancellation semantics.

### Required tests

Cover duplicate queued admission, duplicate active admission with `maxConcurrentSessions >= 2`, `waitForAll()` while a duplicate executor remains active, synchronous executor throw, exact returned error, active count returning to zero, next queued item starting, asynchronous rejection, and Review 31 cancellation behavior.

## R32-G3 — React Native native-history authority

### Objective

Remove the mismatch between the bounded React Native wrapper mirror and frozen native history. Prefer existing native history exports; do not add a native export.

### Preferred design

Enumerate native history directly for `getSessions*()` and `getLastSession*()`. Retain a separate bounded structure only for owning execution handles and other ownership state.

If a mirror remains, prove all of the following:

- Created and Running sessions visible in native history are not pruned merely because a temporary handle is not retained.
- Terminal eviction follows native capacity semantics.
- Native creation ordering and last-session ordering are preserved; reinserting an old ID cannot make it newest.
- History-size changes and `clearSessions()` reconcile all wrapper state.
- Storage remains bounded and no lifetime shadow of all historical IDs returns.

### Required tests

Using existing wrapper seams/mocks, cover capacity `N` with `N+1` unstarted Created sessions, ordering, terminal eviction, active retained handles, re-observed IDs, decreasing/increasing history size, `clearSessions()`, type-filtered history, and all `getLastSession` variants.

## R32-G4 — Local cross-platform wrapper regression

Do not start this goal until G1–G3 focused tests are green.

Run the affected Flutter and React Native package gates locally with analytics disabled. Serialize shared-fixture tests where required and do not reinterpret runner races as product passes. Use only the configured local artifacts.

Platform order:

1. Windows.
2. Android on the established Windows host.
3. Linux under WSL using `/mnt/d/Projects/ffmpeg_kit_extended`.
4. Wasm/Web local build and browser smoke.
5. Apple last on the MacBook Air using the recorded universal XCFramework archives.

Only materially affected platform builds are required, but both Flutter and React Native package-level gates must remain green. Do not launch interactive apps.

Exit evidence must show focused regressions, affected package gates, required local platform gates, no remote old ABI retrieval, no native publication, and no interactive runtime claim.

### Implementation validation recorded before exact closeout

The wrapper remediation and local regression sequence is complete through G4. Flutter and React Native focused regressions, the full non-native Flutter package suite (**200/200**), React Native package gates, Windows and Windows-hosted Android builds, WSL Linux, Wasm/Web build and browser smoke, and the ordered MacBook Air Apple builds all passed against the configured local artifacts. Failed or retried commands were environment corrections only: elevated shells, task-local npm cache/temp paths, Windows Edge for the missing WSL Playwright executable, UTF-8 SSH locale, and Windows JDK 17 for Android. No native ABI contradiction was found.

The G5 source candidate is the next pushed wrapper commit after this documentation reconciliation. It must be snapshotted once with recursive submodules, then its exact workflow/artifact evidence must be added to the tracker.

## R32-G5 — Exact wrapper closeout

Update only behaviorally affected documentation and tracker evidence. Record every failed or retried command accurately.

After all implementation/tests/docs are committed:

1. Verify a clean wrapper worktree and record the exact SHA/tree.
2. Verify `libs/libffmpegkit` is unchanged at the frozen authority.
3. Push the wrapper commit to `origin/dev-wasm`.
4. Run `.github/workflows/repo-source-snapshot.yml` once for the wrapper only at the exact final SHA.
5. Verify snapshot digest, embedded `source.tar.gz` hash, manifest count, recursive submodule state, and `runtimeExecution=false`.
6. Record the workflow run ID, artifact ID/name/digest/hash, and download link in `.agent/TRACKER.md`.

Do not create or download another builders/native snapshot for Review 32. After the wrapper snapshot is verified, stop automated interactive work; final Flutter/React Native runtime validation is user-owned.

## Operating checklist

- Tag every spawned Dart, Flutter, Node, PowerShell, WSL, compiler, and browser-server process.
- Observe each process to completion; terminate confirmed task-owned hangs/orphans immediately.
- Clean task-owned temporary files/directories before the next gate and at closeout.
- Push a meaningful commit after each completed goal when practical.
- If a genuine native-ABI contradiction appears, stop that goal and document exact evidence as a blocker; do not patch around it or alter the native ABI.

## Final handoff

Review 32 is entirely wrapper-owned: enforce execution ownership by native session identity, make the React Native public queue transactional, make React Native history reflect native history, validate locally against existing frozen artifacts, then freeze and snapshot only the final wrapper source.
