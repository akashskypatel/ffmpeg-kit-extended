# Review 51 — Flutter + React Native Cross-Platform Code Review

Date: 2026-10-02  
Repository: `akashskypatel/ffmpeg-kit-extended`  
Branch represented by reviewed snapshot: `dev-wasm`  
Review type: frozen-source, code-review-only, substantive findings only

## 1. Authority and provenance

Review 51 uses the wrapper-only source snapshot recorded by the Review 50 tracker as its source authority.

Tracker-recorded authorities:

- Review 50 implementation source SHA: `2b9e0fe954cabca3142ff6111f98758166163aa3`
- snapshot repository SHA: `e58dd81043bcc6feeaebca9e77efe7793ebcba87`
- source snapshot workflow: `37099036076`
- artifact: `repo-source-snapshot-37099036076`
- artifact ID: `11264529533`
- GitHub artifact SHA-256: `45389467138396af97f46af006b2e66c7065b82aa0562c1113d74632f6c82190`
- embedded `source.tar.gz` SHA-256: `5ac368d272616439bd2a248efb03fb555860631370c889a53c5c47a70350fa82`
- manifest entries: `1080/1080` verified
- symlinks: `0`
- `runtimeExecution=false`
- recursive native submodule: `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`
- native ABI/runtime: `0.11.2`, frozen and not re-reviewed

The snapshot artifact was downloaded through the GitHub connector. Review 51 independently verified:

1. the outer artifact SHA-256 against GitHub artifact metadata;
2. `source.tar.gz.sha256` against the actual embedded archive;
3. all 1,080 `SHA256SUMS` entries after extraction;
4. `SUBMODULES.txt`;
5. `SYMLINKS.tsv`;
6. `snapshot-metadata.json.snapshot_sha`;
7. `runtimeExecution=false`.

The snapshot records repository SHA `e58dd810...`, while the tracker identifies `2b9e0fe...` as the Review 50 implementation freeze and the later repository state as tracker/closeout metadata. Review 51 reviews the production source actually present in the verified snapshot; it does not substitute current branch HEAD or infer source from the post-snapshot tracker state.

No tests, builds, application launches, simulators, devices, Web UI, native ABI downloads, native rebuilds, hosted acceptance workflows, or repository mutations were performed as Review 51 evidence.

## 2. Scope and finding threshold

The requested order was applied:

1. verify the frozen source artifact and provenance;
2. recheck Flutter and React Native platform-native bridge drift;
3. if platform-native remains closed, recheck Flutter wrapper drift and lifecycle boundaries;
4. if Flutter remains closed, inspect the Review 50 React Native remediation and adjacent queue, cancellation, lifetime, restored-observer, clear, and Web/native ownership authorities;
5. report only reachable product, lifetime, ownership, cancellation-authority, error-authority, or public-contract defects;
6. exclude style, formatting, procedural, speculative, and pedantic observations.

Native ABI/runtime `0.11.2`, `libs/libffmpegkit`, native builders, and native exported-symbol design remain frozen and out of scope.

## 3. Snapshot no-drift result

The verified Review 50 snapshot was compared with the preceding verified Review 49 snapshot.

No production drift was found in:

- `flutter/lib`
- `flutter/native`
- `flutter/android`
- `flutter/ios`
- `flutter/macos`
- `flutter/linux`
- `flutter/windows`
- `react-native/cpp`
- `react-native/android`
- `react-native/ios`
- `react-native/macos`
- `react-native/appletvos`
- `react-native/windows`

The Review 50 production delta is confined to:

- `react-native/src/session.ts`
- `react-native/src/session-lifetime.ts`
- `react-native/README.md`

with associated React Native regression tests and tracker/review documents.

Therefore the accepted platform-native bridge and Flutter implementation remain closed unless contradicted by the fresh semantic audit. No contradiction was found.

## 4. Review 50 remediation verification

Review 50's three intended corrections are materially present.

### 4.1 Canonical managed-ID cancellation is present

`Session.cancel()` now resolves `SessionQueueManager.shared.findManagedSessionById(sessionId)` before object-local state classification.

When a different wrapper owns the queued/active execution, cancellation delegates to that owner instead of allowing the secondary wrapper to perform Created abandonment independently.

The queue continues to reserve native IDs and `findManagedSessionById()` prefers the active owner, then the queued owner.

This closes the Review 50 active-startup and queued-owner cancellation defect.

### 4.2 Retained-release retry authority is present

`session-lifetime.ts` now contains:

- one in-flight release transaction per native session ID;
- one retained-release retry coordinator per ID;
- iterative retries rather than recursive Promise chaining;
- reuse of `releaseSessionHandleSerialized()`;
- retry bookkeeping that retains only the session ID, not a `Session` wrapper.

`Session.releaseOwnedHandle()` registers the fallback after a release failure while preserving the original error for the current caller.

The native-start failure path also clears the local startup-in-flight authority after an authoritative invocation rejection.

The Review 50 pre-execution transaction now requires both Created abandonment and retained release to commit before the object considers that cleanup complete.

### 4.3 Queue-only cancellation mutation is runtime-private

The queue-only marker is now an ECMAScript private method:

```ts
#markCancelledBeforeExecution(): void
```

The four concrete Session types enqueue through the base-class helper, which supplies the private closure internally.

No ordinary `markCancelledBeforeExecution` method remains on the public TypeScript/session runtime surface.

This closes the Review 50 direct-call, subclass-call, and ordinary emitted-JavaScript reachability defect.

## 5. Disposition

| Area | Review 51 disposition |
| --- | --- |
| Native ABI/runtime `0.11.2` | Frozen; not reviewed |
| Flutter platform-native bridge | Closed |
| React Native platform-native bridge/shared C++ | Closed |
| Flutter wrapper | Closed in audited lifecycle/session surfaces |
| React Native wrapper | **Not closed — 1 substantive finding** |

### Finding summary

| Finding | Severity | Summary |
| --- | --- | --- |
| R51-F1 | Medium | A secondary wrapper records durable cancellation intent before delegating to a canonical managed owner. During terminal finalization this can re-latch intent after the canonical monitor has already cleared it, leaving terminal cancellation bookkeeping live after ownership settlement. |

## 6. R51-F1 — secondary-wrapper delegation can re-latch terminal cancellation intent

Severity: **Medium**

Affected production source:

- `react-native/src/session.ts`
- adjacent managed-owner authority in `react-native/src/session-queue-manager.ts`

No native, platform-specific, Flutter, shared-C++, or Web-backend implementation change is required.

### 6.1 Current secondary-wrapper delegation

The new Review 50 branch at `session.ts` lines approximately 326–336 performs:

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

The correct part is the delegation itself.

The remaining problem is that the secondary wrapper independently records durable per-ID cancellation intent *before* the canonical managed owner owns the cancellation transaction.

The canonical owner already records durable intent when it actually needs to initiate or retry cancellation. The secondary write is therefore a second authority over the same lifecycle bit.

### 6.2 Terminal monitor deliberately clears durable intent before retained release

When the canonical execution monitor observes `Completed` or `Failed`, it intentionally clears cancellation state before final retained-handle release:

```text
terminal callbacks/log/statistics drain
-> clearCancellationIntent(sessionId)
-> clearCancellationDispatch(sessionId)
-> remove log subscription
-> await releaseOwnedHandle()
-> monitor returns/rejects
-> SessionQueueManager removes active owner
```

This ordering is explicit in `session.ts` around lines 1128–1157.

The code comment states the intended invariant:

> Terminal state is authoritative ... do not leave cancellation intent live after the native identity has settled.

`releaseOwnedHandle()` is asynchronous because it uses the serialized Promise-based lifetime authority. Therefore the canonical Session remains in `SessionQueueManager.active` for a real asynchronous window after durable intent has been cleared.

### 6.3 Reachable re-latch sequence

A deterministic sequence exists when the canonical owner has already dispatched a cancellation request earlier in the run.

1. Original wrapper `A` is active and Running.
2. `A.cancel()` records durable intent and dispatches native cancellation successfully.
3. `A.cancelled === true`.
4. `A.nativeCancellationDispatched === true`.
5. Native state becomes terminal.
6. `A.monitor()` performs terminal callback/log/statistics settlement.
7. `A.monitor()` clears durable cancellation intent and the serialized dispatch record.
8. `A.monitor()` enters `await A.releaseOwnedHandle()`.
9. `A` is still present in `SessionQueueManager.active` until the monitor Promise settles.
10. During that release/finalization window, application code holds or reconstructs another wrapper `B` for the same native session ID and calls `B.cancel()`.
11. `B.cancel()` finds canonical managed owner `A`.
12. `B.cancel()` sets `B.cancelled = true` and independently calls `recordCancellationIntent(id)`.
13. `B.cancel()` delegates to `A.cancel()`.
14. `A.cancel()` immediately returns from its idempotence branch because `A.cancelled && A.nativeCancellationDispatched` is already true.
15. `A.cancel()` therefore does not reach terminal state classification and does not clear the newly re-recorded durable intent.
16. `B.cancel()` resolves successfully.
17. The retained release finishes and `A` leaves the active set.
18. No later authority clears the re-latched cancellation intent for that terminal ID.

### 6.4 Result

The execution itself is already terminal, so this does not restart or continue native work.

The defect is lifecycle bookkeeping and terminal semantics:

- durable cancellation intent remains live after terminal cleanup deliberately cleared it;
- reconstructed terminal wrappers can observe stale `isCancellationRequested` / `isCancelled` authority from a control bit that should have retired;
- the native/Web per-ID cancellation-intent bookkeeping can retain terminal IDs until a later global clear;
- repeated late secondary cancellation across many sessions can grow terminal cancellation bookkeeping despite the accepted bounded-lifecycle design from earlier reviews.

This is substantive because the code explicitly treats terminal observation as the point where durable cancellation control state is retired.

### 6.5 Why the canonical owner does not need the secondary durable-intent write

The managed owner's `cancel()` transaction already handles all meaningful states.

If the managed owner is:

- **queued:** it records its own intent, removes the queue item, and performs pre-execution cleanup;
- **active before native start:** it records its own intent and prevents/cleans pre-execution work;
- **active startup while still Created:** it records its own intent and retains it until Running dispatch is safe;
- **Running:** it records intent and dispatches through the per-ID serialized cancellation authority;
- **terminal:** it classifies terminal state and clears intent/dispatch bookkeeping;
- **already idempotently cancelled/dispatched:** no new durable intent is required merely because a second wrapper repeats the request.

The secondary wrapper needs only to mirror that the caller requested cancellation on *that JavaScript object* (`this.cancelled = true`) and delegate to the canonical owner.

Durable native-ID intent must remain owned by the canonical cancellation transaction.

### 6.6 Required correction

Make the secondary-wrapper branch a pure delegation for per-ID lifecycle state.

Recommended surgical change:

```ts
const managed = SessionQueueManager.shared.findManagedSessionById(
  this.sessionId
);
if (managed && managed !== this) {
  this.cancelled = true;
  const delegated = managed.cancel();
  if (delegated instanceof Promise) await delegated;
  return;
}
```

Remove only this secondary-wrapper call:

```ts
NativeFFmpegKitExtended.recordCancellationIntent?.(this.sessionId);
```

Do **not** remove durable intent recording from the canonical/local cancellation path below the delegation branch.

Do **not** move state classification to the secondary wrapper.

Do **not** create a new per-ID owner map.

Do **not** modify `SessionQueueManager.findManagedSessionById()` semantics.

### 6.7 Required regression

Add one deterministic regression to `react-native/tests/wasm-session-ownership.test.js` using a deferred retained-release gate.

Required setup:

- original canonical session `A` starts normally;
- state reaches `Running`;
- call `A.cancel()` and prove exactly one native cancellation dispatch;
- configure terminal retained release to remain pending on a deterministic gate;
- set native state to `Completed` or `Failed`;
- wait until terminal monitor has cleared durable intent while `SessionQueueManager.isSessionActiveById(id)` remains true;
- create secondary wrapper `B` for the same ID;
- call `B.cancel()` while `A` is still active in terminal finalization.

Required assertions before releasing the gate:

- `B.isCancelled === true` or equivalent local-request state remains true;
- native cancellation dispatch count remains exactly one;
- no Created abandonment occurs;
- durable cancellation intent remains **false** after `B.cancel()`;
- the canonical owner remains active only because final retained release is gated.

Then release retained-handle cleanup and await the original execution.

Final assertions:

- durable cancellation intent is still false;
- the session leaves the active set;
- retained release commits exactly once according to the existing serialized/fallback semantics;
- no restored observer is required to repair the cancellation-intent state;
- no extra native cancellation dispatch occurred.

This test should fail on the Review 50 frozen snapshot because the secondary wrapper currently re-records intent before delegating to the idempotent canonical owner.

### 6.8 Preserve delegated failure semantics

Retain the existing Review 50 test that a secondary wrapper receives the exact canonical owner's cancellation error.

Removing the secondary `recordCancellationIntent` call does not weaken durable retry after a real failure because the canonical owner records intent before fallible state/native cancellation operations.

If a new deterministic regression disproves that statement for a specific canonical branch, fix that canonical branch rather than restoring a second durable-intent writer in the secondary wrapper.

## 7. Platform-native bridge audit

Review 51 found no new substantive platform-native bridge defect.

The verified snapshot preserves the already accepted boundaries:

- Flutter iOS CocoaPods and SwiftPM FFplay texture registration reject ID `0` before publishing texture/callback/owner state;
- Flutter macOS retains the same registration failure contract;
- Flutter Windows external-texture retirement remains completion-owned;
- Flutter Linux remains on the engine-supported pixel-buffer texture lifecycle;
- Flutter Windows/Linux packed-frame normalization remains present;
- React Native shared C++ retains composable operation-token admission across history projection and clear;
- retained-handle release remains failure-atomic in shared C++;
- Windows asynchronous action failures remain invocation-bound;
- React Native Android/Apple/Windows FFplay ownership surfaces are unchanged.

No implementation change is recommended in platform-native directories.

## 8. Flutter wrapper audit

No Flutter production source changed from the preceding verified authority.

Review 51 found no contradiction in the previously accepted Flutter:

- queue settlement;
- durable cancellation intent;
- restored Running observation;
- callback bridge demand;
- history/tombstone reconciliation;
- FFplay ownership/surface behavior;
- platform packaging behavior.

Disposition: **Flutter remains closed in the audited surfaces.**

No Flutter implementation or documentation change is required by Review 51.

## 9. Other React Native boundaries rechecked and retained

No new substantive defect was established in:

- Review 50 canonical managed-ID lookup itself;
- queued secondary-wrapper cancellation/removal;
- active-startup Created protection;
- same-object pre-start cancellation;
- deterministic multi-target cancellation error ordering;
- queue-before-active `cancelAll()` branch ordering;
- pre-execution abandonment + release two-part commit;
- rejected-start cleanup authority;
- retained-release background retry serialization;
- restored observer release fallback coexistence;
- runtime-private queue cancellation marker;
- callback setup terminal/clear serialization;
- clear-time observer non-resurrection;
- Web history-pointer failure atomicity;
- native/Web abandoned-ID fail-closed behavior;
- native ABI exports.

Do not broaden remediation into these surfaces without new direct evidence.

## 10. Documentation implications

Public React Native documentation should continue to describe cancellation by semantic authority rather than wrapper implementation details.

After remediation, the existing Review 50 README statement that a secondary wrapper delegates to the managed execution owner remains correct.

Recommended clarification, if documentation is touched:

- a secondary wrapper mirrors the local fact that cancellation was requested through that object;
- durable native-ID cancellation intent is owned by the canonical managed cancellation transaction;
- terminal observation retires durable cancellation control state and a late duplicate request cannot re-create it after terminal settlement has already won.

No Flutter documentation change is required.

## 11. Review 51 goals

1. **Single durable cancellation authority during delegation:** remove the secondary wrapper's independent per-ID intent mutation and let the canonical queued/active owner's `cancel()` transaction exclusively own durable intent.
2. **Terminal-finalization regression:** add a deterministic release-gated case proving a late secondary cancellation cannot re-latch intent after terminal cleanup while the canonical owner is still active.
3. **Preservation and closeout validation:** preserve all Review 44–50 cancellation, release, observer, clear, Web ownership, privacy, and deterministic-error regressions; run only affected local validation against frozen ABI `0.11.2`; perform one final bounded audit and exact-SHA wrapper snapshot only if zero substantive findings remain.

## 12. Closeout status

**Review 51 does not yet close the React Native wrapper.**

Platform-native bridge: **closed**.  
Flutter wrapper: **closed in the audited surfaces**.  
React Native wrapper: **1 substantive finding remains**.

The next review may claim cross-platform closeout only after:

- R51-F1 is implemented;
- the deterministic terminal-finalization regression passes;
- Review 44–50 lifecycle regressions remain green;
- affected local Windows → Android-on-Windows → Linux/WSL → Apple-last validation is recorded truthfully;
- Flutter and platform-native production remain unchanged;
- native ABI `0.11.2`, `libs/libffmpegkit`, and builders remain frozen;
- no hosted Flutter/RN acceptance workflow or remote old native bundle is used;
- final source audit finds zero substantive findings;
- one exact final wrapper SHA is pushed and fully verified through the wrapper-only source snapshot workflow.
