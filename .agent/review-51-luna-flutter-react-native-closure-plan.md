# Review 51 — Luna Flutter + React Native Final Cancellation-Lifecycle Closure Plan

Date: 2026-10-02  
Audience: Luna implementation/review model  
Repository: `akashskypatel/ffmpeg-kit-extended`  
Branch: `dev-wasm`  
Reviewed snapshot repository SHA: `e58dd81043bcc6feeaebca9e77efe7793ebcba87`  
Review 50 implementation source recorded by tracker: `2b9e0fe954cabca3142ff6111f98758166163aa3`

## Mission

Close the single remaining React Native wrapper lifecycle defect found by Review 51 without reopening accepted Flutter, platform-native, shared-C++, native-ABI, retained-release, observer, or queue behavior.

The defect is narrow:

> A secondary `Session` wrapper currently records durable native-session-ID cancellation intent before delegating to the canonical queued/active owner. If the canonical owner is already in terminal finalization and has cleared that intent, the secondary write can re-latch it while the canonical owner returns idempotently because native cancellation was already dispatched.

The implementation must restore one durable cancellation authority per managed native session ID.

If this goal is implemented, deterministic regressions pass, all prior lifecycle gates remain green, the final bounded source audit finds zero substantive findings, and frozen boundaries remain unchanged, the next review should be a cross-platform closeout verification.

## Hard boundaries

- Keep native ABI/runtime `0.11.2` frozen.
- Keep `libs/libffmpegkit` exactly at `b74da2c5d1e294b87d15d73a6687393729e932b3` on `dev`, matching its accepted authority.
- Do not edit or rebuild the ManyLinux builders checkout.
- The tracker records unrelated user-owned dirt in the ManyLinux checkout; preserve it. Do not clean, stage, alter, or attribute it to this task.
- Do not download a remote old/staged native ABI bundle.
- Do not publish a native ABI artifact.
- Do not add or change exported native symbols.
- Do not change React Native shared C++, Windows C++, Android Java/Kotlin/C++, or Apple Objective-C++.
- Do not modify Flutter production code or configuration. Review 51 found no Flutter defect.
- Do not modify `react-native/src/session-lifetime.ts` unless a deterministic regression directly disproves the existing release-retry invariant. Review 51 found that implementation sound.
- Do not modify `react-native/src/session-queue-manager.ts` unless needed only for a test seam; the managed-owner lookup semantics are already correct.
- Do not run hosted Flutter/React Native build or test workflows.
- The only permitted hosted workflow after a clean final source freeze is the wrapper-only repository source-snapshot workflow.
- Do not launch interactive applications, simulators, devices, or Web UI for automated acceptance.
- Interactive Flutter/React Native validation remains user-owned after remediation.
- Use only locally configured native ABI `0.11.2` artifacts for local builds/tests.
- Do not fetch a remotely built stale/old native bundle for local tests.
- Production/test/comment identifiers must be semantic. Do not place `Review 51`, `R51`, finding IDs, or goal IDs in implementation symbols, test names, comments, or user-facing documentation.
- Record every failure, environmental blocker, retry, skip, and mistake truthfully. Do not fabricate or weaken tests to obtain green output.
- Exclude style, formatting, procedural, speculative, and pedantic observations from the final audit.

## Starting evidence

Review 51 independently verified the Review 50 tracker-recorded source snapshot:

- snapshot workflow: `37099036076`
- artifact ID: `11264529533`
- artifact name: `repo-source-snapshot-37099036076`
- GitHub artifact digest: `sha256:45389467138396af97f46af006b2e66c7065b82aa0562c1113d74632f6c82190`
- snapshot repository SHA: `e58dd81043bcc6feeaebca9e77efe7793ebcba87`
- embedded source archive SHA-256: `5ac368d272616439bd2a248efb03fb555860631370c889a53c5c47a70350fa82`
- `SHA256SUMS`: `1080/1080` verified
- symlinks: `0`
- `runtimeExecution=false`
- frozen recursive submodule: `b74da2c5d1e294b87d15d73a6687393729e932b3`

Byte-level comparison against the preceding verified Review 49 source found no production drift in Flutter, React Native shared C++, or any platform-native directory.

Review 50's production changes are limited to React Native TypeScript lifecycle code and documentation. Its canonical-ID cancellation, retained-release fallback, and true runtime-private queue marker are present and should be preserved.

## Goal tracker

| Goal | Objective | Required production scope | Status |
| --- | --- | --- | --- |
| G1 | Make secondary-wrapper cancellation a pure delegation for durable per-ID cancellation authority | `react-native/src/session.ts` | Pending |
| G2 | Add deterministic terminal-finalization regression and semantic documentation | RN ownership test; README/TSDoc only if needed | Pending |
| G3 | Preserve all prior lifecycle behavior, run affected local validation, perform zero-finding audit, freeze exact SHA, and verify one wrapper-only snapshot | tests/docs/tracker; no unrelated production changes | Pending |

Do not mark a goal complete from code inspection alone. Complete it only after the deterministic regression evidence required below passes locally.

---

# Goal 1 — make secondary-wrapper cancellation a pure delegation

## Problem to solve

`Session.cancel()` currently begins with managed-owner delegation:

```ts
const managed = SessionQueueManager.shared.findManagedSessionById(
  this.sessionId
);
if (managed && managed !== this) {
  this.cancelled = true;
  NativeFFmpegKitExtended.recordCancellationIntent?.(this.sessionId);
  const delegated = managed.cancel();
  if (delegated instanceof Promise) await delegated;
  return;
}
```

The lookup/delegation is correct.

The independent `recordCancellationIntent()` call is not.

The canonical managed owner's `cancel()` transaction is already the authority that decides whether durable intent must be created, retained, retried, dispatched, or cleared.

The secondary wrapper should not mutate the same per-ID durable control state before delegation.

## Why the current code is wrong

A canonical session can remain in `SessionQueueManager.active` after native state becomes terminal because terminal finalization awaits asynchronous retained-handle release.

The terminal monitor intentionally executes:

```text
terminal callback/log/statistics settlement
-> clearCancellationIntent(id)
-> clearCancellationDispatch(id)
-> await releaseOwnedHandle()
-> return/reject execution
-> queue removes active owner
```

If the canonical owner had already successfully dispatched cancellation earlier, its local fields can be:

```text
cancelled = true
nativeCancellationDispatched = true
```

During the asynchronous release window a secondary wrapper can call `cancel()`.

Current sequence:

```text
secondary B finds active canonical A
-> B.cancelled = true
-> B records durable intent again
-> B delegates to A.cancel()
-> A sees cancelled && nativeCancellationDispatched
-> A returns immediately
-> no state classification occurs
-> newly re-latched durable intent survives terminal finalization
```

That violates the terminal invariant that durable cancellation control state is retired once the native identity has settled.

## Required semantic rule

For a native session ID that already has a different queued/active managed owner:

> The managed owner's `cancel()` transaction is the sole durable native-ID cancellation authority. The requesting secondary wrapper may record only its own local JavaScript cancellation-request state and must not independently mutate durable per-ID intent.

## Exact implementation

Modify only the different-managed-owner branch in `Session.cancel()`.

Required code shape:

```ts
const managed = SessionQueueManager.shared.findManagedSessionById(
  this.sessionId
);
if (managed && managed !== this) {
  // This wrapper records only that its caller requested cancellation.
  // The managed owner owns durable per-ID intent and native delivery.
  this.cancelled = true;
  const delegated = managed.cancel();
  if (delegated instanceof Promise) await delegated;
  return;
}
```

Remove this line from the secondary branch only:

```ts
NativeFFmpegKitExtended.recordCancellationIntent?.(this.sessionId);
```

Keep the existing durable-intent call in the canonical/local path below the managed-owner branch:

```ts
this.cancelled = true;
NativeFFmpegKitExtended.recordCancellationIntent?.(this.sessionId);
```

That local path remains authoritative when:

- this object is the canonical queued owner;
- this object is the canonical active owner;
- no managed owner exists and the wrapper is a standalone Created/history object;
- a restored Running wrapper has no managed execution owner.

## Ordering requirements

The final order must remain:

```text
find different managed owner by ID
-> if found: mark only requesting wrapper's local cancelled state
-> delegate to canonical managed owner
-> propagate exact delegated success/failure
-> return
-> otherwise execute this wrapper's normal durable-intent/state/cancellation transaction
```

Do not move the canonical durable-intent write above the managed-owner branch.

Do not state-probe the secondary wrapper before delegation.

Do not duplicate cancellation delivery.

Do not call `dispatchCancellationSerialized()` from the secondary branch.

Do not introduce another ID registry.

## Why canonical cancellation still remains durable after this change

Audit and preserve the following canonical behavior.

### Canonical queued owner

`managed.cancel()` executes the canonical object's normal path:

```text
set canonical cancelled
-> record durable intent
-> cancelQueued(canonical object)
-> queue-local private mark
-> pre-execution discard transaction
-> queue reservation release
```

### Canonical active owner before native start

The canonical owner records durable intent and safely performs pre-execution cleanup when startup has not crossed the native-start boundary.

### Canonical startup-in-flight Created owner

The canonical owner records intent but does not abandon the Created identity after native startup has been attempted. Its monitor later dispatches native cancellation when Running becomes authoritative.

### Canonical Running owner

The canonical owner records durable intent and dispatches through the serialized per-ID native cancellation authority.

### Canonical terminal owner

The canonical owner classifies terminal state and clears durable intent/dispatch bookkeeping.

### Canonical idempotent already-dispatched owner

No new durable intent is required for a late duplicate request. The original request was already delivered, and terminal cleanup is allowed to retire its control bookkeeping.

## Preserve secondary local semantics

Keep:

```ts
this.cancelled = true;
```

before delegation.

Reason:

- the caller did request cancellation through this secondary wrapper;
- `isCancelled` on that JavaScript object may therefore continue to reflect the local request;
- delegated failure should not erase the fact that cancellation was requested through the object.

The fix is specifically about *durable per-ID control state*, not the wrapper-local request flag.

## Goal 1 code-review checks

After implementation, inspect source and verify:

1. the secondary branch has no `recordCancellationIntent` call;
2. the canonical/local branch still records durable intent before fallible queue/state/native cancellation work;
3. delegated errors are still propagated exactly;
4. no secondary state read or Created abandonment was added;
5. no new cancellation owner map exists;
6. `SessionQueueManager.findManagedSessionById()` behavior is unchanged;
7. `session-lifetime.ts` is unchanged;
8. ECMAScript-private queue cancellation remains unchanged.

---

# Goal 2 — deterministic terminal-finalization regression and documentation

## Mandatory regression location

Prefer:

- `react-native/tests/wasm-session-ownership.test.js`

This suite already owns:

- retained handle fixtures;
- cancellation-intent fixtures;
- active/queue manager access;
- native state control;
- native cancellation counters;
- retained release counters;
- deterministic release failure/retry seams.

Do not create a broad new harness unless the existing fixture cannot express a deferred retained release cleanly.

## Add a deterministic retained-release gate

The test must be able to hold terminal finalization after cancellation intent has been cleared but before the canonical Session leaves the active set.

One acceptable fixture extension is a conditional deferred release gate.

Pseudo-shape:

```js
let releaseGate;

releaseSessionHandle: (sessionId) => {
  releases.push(sessionId);
  if (releaseGate) {
    return releaseGate.promise.then(() => commitRelease(sessionId));
  }
  return commitRelease(sessionId);
}
```

Use the suite's existing deferred/gate conventions if available.

Do not make every release permanently asynchronous if that would unnecessarily perturb unrelated tests. Gate only the target case or provide a fixture flag.

Reset the gate in `beforeEach`/`afterEach` and prove no gate remains unresolved after the test.

## Mandatory regression — late secondary cancellation cannot re-latch terminal intent

Use a semantic test name such as:

```text
secondary cancellation cannot restore durable intent after managed terminal cleanup
```

Do not include review/finding IDs.

### Setup

1. Create canonical original session `A` with a retained execution handle.
2. Start `A.executeAsync()`.
3. Wait deterministically until native execution starts and state is Running.
4. Call `A.cancel()` while Running.
5. Assert exactly one native cancellation dispatch.
6. Assert durable cancellation intent is currently present.
7. Install a deferred retained-release gate for this ID.
8. Transition native state to `Completed` (or `Failed`).

### Reach the exact race window

Wait until all of these are true:

- canonical `A` is still active in `SessionQueueManager`;
- terminal monitor has reached retained release (release attempt/gate observed);
- durable cancellation intent has been cleared by terminal settlement;
- the release gate is still closed.

Do not use an arbitrary sleep as the proof of this phase.

Use counters/flags and the existing bounded `waitFor` helper.

### Secondary request

Construct another wrapper `B` with the same native session ID.

Call:

```js
await B.cancel();
```

### Assertions while canonical release is still gated

Require:

- `B.isCancelled` reflects the local request;
- durable cancellation intent remains **absent**;
- native cancellation dispatch count remains exactly one;
- no Created abandonment occurs;
- canonical `A` remains the managed active owner only because final release is still blocked;
- no second retained release transaction starts outside the existing serialized authority.

### Complete finalization

Release the retained-handle gate.

Await the original execution Promise.

Final assertions:

- durable cancellation intent is still absent;
- canonical owner leaves the active set;
- no extra native cancellation dispatch occurred;
- no Created abandonment occurred;
- retained release commits according to existing exactly-once/serialized semantics;
- retained-release retry bookkeeping returns to zero when applicable;
- no restored history wrapper/observer is required to repair the durable intent state.

### Required red/green property

The new regression must fail against the Review 50 frozen implementation because the secondary wrapper currently executes:

```ts
recordCancellationIntent(sessionId)
```

before delegating to an idempotently already-dispatched canonical owner.

After Goal 1, the regression must pass.

If the regression unexpectedly passes before the implementation change, diagnose the fixture. Do not weaken assertions until direct source/runtime reasoning explains why the reproduced sequence is not reachable.

## Preserve Review 50 secondary-wrapper tests

Retain and rerun the existing cases proving:

- a secondary wrapper delegates active-startup cancellation to the managed owner;
- a secondary wrapper removes the managed queued owner immediately;
- a delegated cancellation failure reaches the secondary caller as the exact canonical error;
- no-managed-owner restored cancellation continues using the standalone state path.

These must remain green after removing the duplicate durable-intent write.

## Preserve retained-release tests

Rerun all Review 50 retained-release cases, especially:

- rejected native startup reopens safe Created cleanup;
- startup error remains primary while release retries automatically;
- state-read error remains primary while release retries automatically;
- partial pre-execution cleanup retries only the missing transaction half;
- release fallback is one per native session ID;
- terminal release failure retries without history reconstruction;
- callback/terminal primary errors remain authoritative while release retires.

Do not change `session-lifetime.ts` merely to make the new cancellation test pass.

## Preserve queue-marker privacy tests

After `npm run prepare`, retain:

- direct packed TypeScript access rejection;
- consumer subclass access rejection;
- emitted runtime surface absence of ordinary `markCancelledBeforeExecution` property;
- four concrete Session queued-cancellation behavior.

## Documentation guidance

The current README already says that cancellation from a secondary history/control wrapper is delegated to the managed execution owner.

That wording is directionally correct after Goal 1.

### Minimum required documentation action

Review the cancellation section and ensure it does not imply that both wrappers independently own durable per-ID cancellation state.

No public API addition is needed.

### Optional semantic clarification

If editing the README, add one concise statement such as:

> When a queued or active managed owner exists for a session ID, secondary wrappers mirror the local cancellation request but the managed owner's cancellation transaction remains the sole authority for durable native-ID intent and delivery.

Also state or preserve:

- terminal observation retires durable cancellation control state;
- a late duplicate cancellation cannot re-create terminal control intent after final state wins;
- `isCancelled` on a particular wrapper can still reflect that cancellation was requested through that JavaScript object.

Do not expose internal map/set names.

Do not mention Review 51 or historical finding IDs in public docs.

### Internal TSDoc/comment guidance

A small semantic comment in the managed-owner branch is useful:

```ts
// A different managed owner owns durable per-ID cancellation state.
// This wrapper records only its local request before delegating.
```

Do not add a large historical comment.

---

# Goal 3 — regression preservation, local validation, final zero-finding audit, exact freeze

## Expected implementation diff

Production changes should normally be limited to:

- `react-native/src/session.ts`

Optional documentation:

- `react-native/README.md`

Required regression:

- `react-native/tests/wasm-session-ownership.test.js`

Possibly fixture-only changes in the same test file to add the deferred release gate.

No other production change is expected.

## Stop-and-investigate paths

Any change in these paths requires direct new evidence before proceeding:

- `flutter/**`
- `react-native/src/session-lifetime.ts`
- `react-native/src/session-observation.ts`
- `react-native/src/session-cancellation.ts`
- `react-native/src/platform/**`
- `react-native/cpp/**`
- `react-native/windows/**`
- `react-native/android/**`
- `react-native/ios/**`
- `react-native/macos/**`
- `react-native/appletvos/**`
- `libs/libffmpegkit/**`
- native ABI/configuration
- ManyLinux builders checkout

The current finding does not require changes in those surfaces.

## Focused local gates

From `react-native/`, use only commands actually supported by the repository and record exact results truthfully.

Start with:

```text
npm run typecheck
npm run test:compile
node --test tests/wasm-session-ownership.test.js
node --test tests/session-queue-manager.test.js
node --test tests/restored-session-observer.test.js
npm run lint
```

After `npm run prepare`, run:

```text
npm run test:pack-types
```

Then run the complete local Node suite.

Record exact pass/fail/skip counts.

Run the established headless Web/Wasm smoke and packed Web consumer if required by the current local acceptance practice for shared TypeScript lifecycle changes.

Do not launch an interactive browser UI.

## Mandatory regression preservation matrix

### Canonical and secondary cancellation

Verify:

- direct never-started Created cancellation;
- consumed-but-never-started same-object cancellation;
- secondary-wrapper queued cancellation removes the actual managed item;
- secondary-wrapper active-startup cancellation delegates to the managed owner;
- delegated failure identity is exact;
- no-managed-owner restored Running cancellation still dispatches normally;
- durable intent survives real state/native cancellation failure;
- submitted/startup Created protection remains intact;
- late secondary cancellation during terminal finalization does not re-latch durable intent;
- completion-wins behavior remains correct.

### Queue behavior

Verify:

- duplicate object admission rejection;
- duplicate native-ID admission rejection;
- queue reservation release on all exits;
- queued cancellation starts no executor;
- mark-before-cleanup behavior remains private/internal;
- all active targets are attempted by aggregate cancellation;
- deterministic active-target error ordering remains independent of Promise settlement order;
- `cancelAll()` queue-before-active branch error priority remains deterministic;
- asynchronous queued cleanup does not delay initiation of active cancellation.

### Cleanup and retained release

Verify:

- pre-execution cleanup requires both abandonment and release commit;
- failed abandonment retries;
- failed retained release retries;
- rejected-start release fallback remains automatic;
- state-read release fallback remains automatic;
- terminal release fallback remains automatic without a restored observer;
- release retry authority is one per ID;
- successful/no-op release removes retry bookkeeping;
- restored observer and execution-owner fallback serialize through the same release authority;
- primary start/state/callback errors remain primary.

### Restored/history lifecycle

Verify:

- one ID-level restored observer per Running ID;
- callback targets remain bounded;
- callback setup remains serialized against terminal/clear cleanup;
- active execution owner retains final callback-drain priority;
- clear invalidates observation only after backend clear success;
- callback rollback cannot recreate an observer after clear;
- configuration clear and lifecycle clear remain equivalent;
- terminal observer release does not reintroduce durable cancellation intent.

### Web ownership

Verify:

- history state-probe failure releases a temporary pointer exactly once;
- retained/temporary ownership remains failure-atomic;
- abandoned Created identities remain fail-closed;
- cancellation intent blocks reconstructed Created execution while cancellation is pending;
- terminal durable intent retires and stays retired after the new late-secondary regression;
- retained release uses the shared serialized/retry authority.

### Public API privacy

Verify:

- direct queue-marker call is absent from packed types;
- subclass queue-marker call is absent from packed types;
- emitted JS exposes no ordinary queue-marker method;
- public Session constructors and supported methods otherwise remain unchanged.

## Ordered local platform validation

Expected production change is React Native TypeScript-only.

Use the established order and local artifacts only.

### 1. Windows first

Run:

- typecheck;
- test compile;
- focused ownership/queue/restored suites;
- lint;
- packed type consumer;
- full local Node suite;
- headless Web/Wasm/packed consumer gates as applicable;
- established local React Native Windows example build using the configured local Windows ABI ZIP.

Do not fetch any remote native artifact.

### 2. Android on local Windows

Run the existing local Android build using the already configured local AAR.

Do not repeat Android under WSL merely for duplication.

### 3. Linux/WSL where affected

Run the shared TypeScript/Node/Web/package gates required by the wrapper change.

Use only the existing local environment/artifacts.

Do not modify the ManyLinux builders checkout.

The tracker records unrelated dirty files in that checkout. Preserve them exactly and do not claim a clean builder working tree unless the user independently resolves them.

### 4. Apple last

Use the authorized MacBook Air SSH host and the existing local universal XCFramework archives.

Run the established noninteractive React Native:

- typecheck/lint/test gates required by current tracker practice;
- iOS build;
- tvOS simulator build;
- macOS build.

Use the already-established UTF-8 locale/PATH correction if needed.

Record an environment-first failure truthfully before retrying.

Do not launch an app or simulator interactively.

## Flutter validation policy

Review 51 independently verified no production drift in Flutter or any platform-native directory.

If implementation remains React Native-only:

- perform a bounded source no-drift comparison for Flutter/platform-native paths;
- preserve the accepted prior Flutter platform evidence;
- do not rerun the complete Flutter matrix merely for ceremony.

If any Flutter production change appears, stop and identify the concrete new Flutter defect before proceeding.

## Semantic identifier audit

Search changed production/tests for:

- `Review51`
- `Review 51`
- `R51`
- finding IDs
- goal IDs

No such identifiers belong in production symbols, tests, comments, or user-facing docs.

Tracker metadata may use them.

## Final substantive audit checklist

Before claiming closure, answer every question from final source/evidence rather than implementation intent.

1. Does a secondary wrapper delegate to a different managed owner before object-local state classification?
2. Does the secondary wrapper avoid independent durable per-ID intent mutation?
3. Does the canonical managed owner still record durable intent before fallible cancellation work?
4. Can a secondary wrapper still cancel queued canonical work immediately?
5. Can a secondary wrapper still cancel active startup without Created abandonment?
6. Does delegated failure identity remain exact?
7. Can a late secondary cancellation during terminal retained-release finalization re-latch durable intent?
8. Is durable cancellation intent absent after terminal finalization completes?
9. Is native cancellation dispatch still exactly once for the already-dispatched terminal-race case?
10. Are pre-execution abandonment/release transactions unchanged?
11. Are retained-release background retries unchanged and bounded by live failed ownership?
12. Is the ECMAScript-private queue marker unchanged?
13. Are deterministic aggregate cancellation error-order rules unchanged?
14. Are restored observer, callback, clear, and Web ownership authorities unchanged?
15. Are Flutter and all platform-native production directories unchanged?
16. Is `libs/libffmpegkit` still exactly `b74da2c5d1e294b87d15d73a6687393729e932b3`?
17. Was the ManyLinux checkout left untouched, including pre-existing user-owned dirt?
18. Was no native ABI downloaded, rebuilt, or published?
19. Were no hosted Flutter/RN acceptance workflows run?

If any answer is wrong or uncertain from source/evidence, do not claim closeout.

## Exact final source freeze and wrapper-only snapshot

Only after all focused/local validation passes and the final bounded audit has zero substantive findings:

1. commit and push the final wrapper change to `dev-wasm`;
2. record the exact full 40-character implementation SHA;
3. verify the tracked production diff is limited to the intended React Native wrapper/test/doc scope;
4. distinguish any later tracker-only provenance commit from the implementation source SHA;
5. dispatch only the repository source-snapshot workflow against the intended exact source authority;
6. download the wrapper-only artifact through the GitHub connector;
7. verify:
   - GitHub artifact digest;
   - `source.tar.gz.sha256`;
   - actual embedded archive SHA-256;
   - every `SHA256SUMS` entry;
   - `SUBMODULES.txt`;
   - `SYMLINKS.tsv`;
   - `snapshot-metadata.json.snapshot_sha`;
   - `runtimeExecution=false`;
   - frozen `libs/libffmpegkit` SHA;
8. record workflow run ID, artifact ID/name/link, outer digest, embedded archive digest, manifest count, symlink count, runtime flag, implementation source SHA, snapshot SHA, and submodule SHA in the tracker.

Do not create a native/builders snapshot.

If the snapshot includes a later tracker-only metadata commit rather than the exact implementation SHA, record that distinction explicitly and prove no production drift between the implementation freeze and snapshotted repository source before using it as closeout authority.

---

# Definition of done

Review 51 remediation is complete only when all of the following are true:

- [ ] a secondary wrapper delegates cancellation to a different managed queued/active owner by native ID;
- [ ] the secondary delegation branch does not independently call `recordCancellationIntent`;
- [ ] the canonical/local cancellation branch still owns durable intent;
- [ ] a late secondary cancellation during canonical terminal release cannot re-latch durable intent;
- [ ] terminal finalization leaves durable cancellation intent retired;
- [ ] local secondary `isCancelled` semantics remain intact;
- [ ] secondary queued-owner cancellation remains immediate;
- [ ] secondary active-startup cancellation remains non-destructive;
- [ ] exact delegated cancellation failures remain visible;
- [ ] no extra native cancellation dispatch is introduced;
- [ ] Review 50 pre-execution cleanup/release retry behavior remains unchanged;
- [ ] Review 50 runtime-private queue marker remains absent from public TypeScript/subclass/runtime surfaces;
- [ ] Review 49 deterministic cancellation error ordering remains green;
- [ ] Review 44–50 observer/clear/release/Web ownership regressions remain green;
- [ ] React Native typecheck/test compile/lint/focused/full local tests are recorded truthfully;
- [ ] required local Windows → Android-on-Windows → Linux/WSL → Apple validation is complete using local ABI `0.11.2` artifacts only;
- [ ] Flutter and platform-native no-drift checks remain clean;
- [ ] `libs/libffmpegkit` remains exactly `b74da2c5d1e294b87d15d73a6687393729e932b3`;
- [ ] pre-existing ManyLinux builder dirt is preserved and not attributed to this task;
- [ ] no hosted Flutter/RN acceptance workflow ran;
- [ ] no native ABI was downloaded, published, or rebuilt;
- [ ] final bounded audit has zero substantive findings;
- [ ] exact final wrapper implementation SHA is frozen and pushed;
- [ ] one wrapper-only source snapshot is downloaded and fully verified;
- [ ] tracker clearly distinguishes implementation source SHA from any later tracker-only snapshot/provenance commit.

If every item is satisfied, the next review should produce a cross-platform closeout summary rather than another remediation plan.
