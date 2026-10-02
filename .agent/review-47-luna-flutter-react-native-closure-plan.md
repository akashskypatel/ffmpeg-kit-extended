# Review 47 — Luna Flutter + React Native Wrapper Closure Plan

Date: 2026-10-02  
Audience: Luna implementation/review model  
Repository: `akashskypatel/ffmpeg-kit-extended`  
Branch: `dev-wasm`  
Starting wrapper authority: `a0d38c9374091174cb560651e6a36d62378ada2b`

## Mission

Close the two remaining React Native wrapper lifecycle defects from the frozen
source review without reopening accepted native ABI, shared C++, platform-native,
or Flutter behavior. The platform-native bridge and audited Flutter wrapper are
already closed. The result must be a single lifecycle-aware clear transaction,
an observer creation authority that cannot be resurrected by callback rollback,
deterministic regression coverage, truthful local validation, and an exact-SHA
source snapshot only after the final substantive audit is clean.

## Non-negotiable boundaries

- Keep native ABI/runtime `0.11.2` frozen.
- Keep `libs/libffmpegkit` at
  `b74da2c5d1e294b87d15d73a6687393729e932b3`, on `dev`, synchronized with
  `origin/dev`; do not edit or rebuild it.
- Do not edit or rebuild `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders`.
- Do not download remote old ABI bundles, publish native ABI artifacts, or add
  exported native symbols.
- Do not run hosted Flutter/React Native build or test workflows. The only
  permitted hosted action is the final exact-SHA wrapper source snapshot.
- Do not launch interactive apps, simulators, devices, or Web UI as acceptance
  evidence.
- Do not change Flutter or platform-native production code without a new,
  reachable, concrete defect.
- Production and test identifiers must express semantic behavior. Never put
  review/goal/finding identifiers in implementation or test names.

## Goal 1 — one public clear lifecycle authority

### Implementation

In `react-native/src/ffmpeg-kit-config.ts`, import `FFmpegKitExtended` and make
`FFmpegKitConfig.clearSessions()` delegate to `FFmpegKitExtended.clearSessions()`.
The method may return the delegated promise directly or await it; the behavior
must remain one transaction. Remove the direct backend-only call as the complete
implementation. Do not copy backend clear, observer invalidation, or
cancellation-dispatch cleanup into the configuration facade.

The authoritative ordering remains:

1. attempt backend clear;
2. if it fails, propagate the primary error and do not claim wrapper invalidation;
3. after backend success, invalidate restored observers/callback demand;
4. clear cancellation-dispatch bookkeeping after the committed clear, preserving
   the existing error-handling semantics of the lifecycle-aware authority.

Update the configuration TSDoc and, if needed, the API-level README wording to
state that both public clear facades share this lifecycle transaction. Preserve
the existing warning about clearing while sessions are running. Do not mention
this review in public documentation.

### Goal 1 tests

Use the existing fake backend and restored-observer fixtures. A successful
configuration clear must prove backend clear count one, zero restored observer
entries, zero callback targets, and baseline callback demand/subscriptions. Run
the same fixture through `FFmpegKitExtended.clearSessions()` and compare behavior
semantically, not by source-text equality. Configure a sentinel backend clear
failure and assert the exact error is propagated and pre-clear observer state is
not falsely invalidated. If an internal cancellation counter already exists,
assert successful cleanup; do not add a public diagnostic API solely for this.

## Goal 2 — prevent observer resurrection after clear

### Implementation

In `react-native/src/session-observation.ts`, keep `ensureObserved(sessionId)` as
the only normal caller allowed to create an ID-level observer entry. Change
`attachCallbackTarget(sessionId, target)` so it reads the existing entry from the
coordinator map and returns without mutation when the entry is absent or already
invalidated. For a live entry, add the target and start/use its existing run as
before. Validate the target/session identity as the current code requires.

The intended semantic split is:

```ts
ensureObserved(id)              // may create the ID-level lifetime observer
attachCallbackTarget(id, sink)  // may attach only to a live existing entry
detachCallbackTarget(id, sink)  // removes a sink; never creates an entry
```

Add a concise internal comment near attachment explaining that ID-level
observation is created by `ensureObserved()` and callback attachment never
recreates an entry removed by terminal/clear lifecycle. Do not restore an
unbounded cleared-ID tombstone set. Do not add a coordinator generation unless
the deterministic regression demonstrates that the surgical authority split is
insufficient.

### Goal 2 tests

Add the missing interleaving with direct latches/counters:

1. reconstruct a Running wrapper with an existing completion sink and live
   observer;
2. start a deferred log or statistics bridge install;
3. start a lifecycle-aware clear and wait until backend clear commits and the old
   coordinator entry has been invalidated/removed;
4. resolve the deferred bridge install;
5. await the setter rejection and clear completion;
6. assert observer entry count zero, target count zero, demand/subscription
   baseline, and no recreated polling for the cleared ID.

Run the race through both public clear facades, or parameterize one helper over
the two authorities. The pre-existing completion sink is mandatory: a no-sink
rollback can legitimately choose detach and does not exercise the creation bug.

Retain positive controls: callback attachment to a live observer still works;
removing the last callback sink detaches only the wrapper target while a Running
ID-level observer remains; terminal or successful clear eventually removes the
ID-level observer. Add a coordinator-level absent-entry attachment case only if
the current test seam supports it without a new public API.

## Goal 3 — deterministic regression and documentation closure

Extend the existing restored observer suite, preferably
`react-native/tests/restored-session-observer.test.js`, and an existing config
facade suite if that is the cleaner fixture location. Preserve all prior
cancellation, queue, retained-release, callback-transition, preflight, bounded
target, and terminal-diagnostic regressions. Use semantic names, for example:

- `configuration clear invalidates restored observer state`
- `configuration and lifecycle clear share cleanup semantics`
- `clear during callback rollback does not recreate observation`
- `callback target attachment requires a live ID observer`

Use side-effect assertions instead of sleep/RSS evidence: backend clear calls,
coordinator entry count, target count, callback demand, direct-log subscription,
and release/cancellation counters where existing seams expose them.

## Goal 4 — local validation and exact closeout

Run and record only commands actually executed. Tag every spawned process with a
task-specific `FFKIT_TASK=review47-*` marker, observe boundedly, and kill any
task-owned hang before retrying. Remove task-owned staging, logs, caches, and
temporary directories after each gate.

### Static and focused React Native gates

From `react-native/`, run:

```text
npm run typecheck
npm run test:compile
npm run lint
node --test tests/restored-session-observer.test.js
```

Run the full local Node suite after focused cases pass and record pass/fail/skip
counts truthfully. Run the smallest established local Web/Wasm ownership smoke
required by the changed shared TypeScript lifecycle behavior; do not launch an
interactive browser UI.

### Platform order

Use the existing locally configured ABI artifacts. Run Windows package/build
validation first, Android on local Windows second, Linux/WSL third where the
repository gate requires it, and Apple iOS/tvOS/macOS last through the
authorized MacBook Air SSH host. Do not claim a platform pass for a skipped,
timed-out, killed, or unavailable command. If Flutter/shared packaging remains
unchanged, perform a bounded source no-drift check and preserve prior accepted
Flutter evidence instead of rerunning the entire Flutter matrix only for
ceremony. No hosted Flutter/React Native acceptance workflow is allowed.

### Final audit and source snapshot

Before closeout, inspect the final diff and re-audit:

- both public clear aliases and backend-first commit ordering;
- observer creation/attachment/detachment authority and clear/setup ordering;
- prior cancellation, queue, retained-release, callback-transition, and
  diagnostic invariants;
- Flutter wrapper and all platform-native source boundaries for no drift;
- frozen submodule, native ABI, and builder checkout for no change;
- production/test identifiers for semantic naming only.

If any substantive finding remains, record it and do not claim closure. If zero
substantive findings remain, commit and push the exact wrapper source freeze,
record its full 40-character SHA, then run only
`.github/workflows/repo-source-snapshot.yml` at that exact SHA. Download and
verify the resulting wrapper-only artifact: outer digest, embedded source
archive digest, every `SHA256SUMS` entry, `SUBMODULES.txt`, `SYMLINKS.tsv`,
`snapshot-metadata.json`, exact `snapshot_sha`, and `runtimeExecution=false`.
Record workflow ID, artifact ID/name/link, digests, manifest count, symlink
count, and frozen submodule SHA in the tracker. Do not create a native/builder
snapshot.
