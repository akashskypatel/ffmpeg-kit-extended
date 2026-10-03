# Review 49 — Luna Flutter + React Native Wrapper Closure Plan

Date: 2026-10-02  
Audience: Luna implementation/review model  
Repository: `akashskypatel/ffmpeg-kit-extended`  
Branch: `dev-wasm`  
Starting wrapper authority: `8c89594380b9db5313bd4a7c4173e341b5943f31`

## Mission

Close the three remaining React Native wrapper defects found by Review 49 without reopening accepted Flutter, platform-native, shared-C++, or native-ABI behavior.

The final implementation must preserve all previously accepted lifecycle invariants while establishing:

1. a correct distinction between public one-shot submission and actual native-start authority;
2. deterministic cancellation error authority independent of Promise settlement timing;
3. an internal-only pre-execution cancellation marker that cannot be misused through the public Session API;
4. deterministic regression evidence and semantic documentation;
5. one exact-SHA wrapper-only source snapshot only after a final zero-finding audit.

## Hard boundaries

- Keep native ABI/runtime `0.11.2` frozen.
- Keep `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3` on `dev`, matching `origin/dev`.
- Do not edit or rebuild the ManyLinux builders checkout.
- Do not download a remote old ABI bundle.
- Do not publish a native ABI artifact.
- Do not add or change exported native symbols.
- Do not edit React Native shared C++, Windows C++, Android Java/Kotlin/C++, or Apple Objective-C++ unless new direct evidence proves one of the TypeScript fixes cannot be implemented correctly without it. Review 49 identifies no such need.
- Do not edit Flutter production code unless new direct source evidence proves a Flutter defect. Review 49 found none.
- Do not run hosted Flutter/React Native build or test workflows.
- The only permitted hosted workflow after a clean final source freeze is the wrapper-only source snapshot workflow.
- Do not launch interactive apps, simulators, devices, or Web UI for automated acceptance.
- Interactive Flutter/React Native validation remains user-owned at the end of remediation.
- Use only locally configured native ABI `0.11.2` artifacts for local builds/tests.
- Do not fetch a remotely built stale/old native bundle for local tests.
- Production/test/comment identifiers must be semantic. Do not place Review 49, R49, goal IDs, or finding IDs in production symbols or test names.
- Record test failures, environmental blockers, retries, skipped tests, and mistakes truthfully. Do not fabricate green evidence.
- Exclude pedantic/style/procedural findings from the final audit.

## Starting evidence

Review 49 independently verified the Review 48 frozen artifact:

- wrapper SHA: `8c89594380b9db5313bd4a7c4173e341b5943f31`
- workflow: `37088245634`
- artifact ID: `11261735639`
- artifact name: `review48-final-source-snapshot-37088245634`
- artifact digest: `sha256:2bd60d4a76a31e9d94b055d54d8f7cd019f4e00ec1fffdde47174826e1ad681c`
- embedded archive: `f295a62cd61fa81382429d931f769ba42175dd2f8a4eafdb7bfaae8ab26d000a`
- `SHA256SUMS`: `1080/1080` verified
- symlinks: `0`
- `runtimeExecution=false`
- frozen recursive submodule: `b74da2c5d1e294b87d15d73a6687393729e932b3`

No Flutter or platform-native production path changed from the preceding verified Review 47 snapshot.

## Goal tracker

| Goal | Objective | Required production scope | Status |
| --- | --- | --- | --- |
| G1 | Separate one-shot submission from native-start authority and restore complete retryable pre-start cancellation | `react-native/src/session.ts`; related tests/docs only | Pending |
| G2 | Make multi-session cancellation error selection deterministic by stable target/branch order | `react-native/src/session-queue-manager.ts`; queue tests/docs only | Pending |
| G3 | Remove the queue-only marker from the exported Session API while preserving queue cancellation ordering | `session.ts`, `session-queue-manager.ts`, four Session execute call sites, type/API tests | Pending |
| G4 | Preserve prior lifecycle regressions, update semantic documentation, run affected local validation, perform final audit, freeze exact SHA, verify wrapper-only snapshot | tests/docs/tracker; no unrelated production changes | Pending |

Do not mark a goal complete from code inspection alone. Complete a goal only after the required deterministic regression evidence passes locally.

---

# Goal 1 — separate submission consumption from native-start authority

## Problem to solve

`Session.submitted` currently means both:

- the public single-use execute API has been consumed; and
- native startup may have begun.

`Session.cancel()` uses `!submitted` to decide whether a Created identity can be safely abandoned. Review 49 proves that public submission can be consumed without queue/native handoff, and that queued discard cleanup can fail while `submitted` remains true.

This can suppress an otherwise safe abandonment transaction and can prevent a later retry of failed queued abandonment.

## Required semantic state

Implement two separate concepts.

### A. Submission consumption

Keep an internal flag for the public single-use object contract.

You may keep the existing name `submitted` if changing it would create needless churn, but its meaning must be documented internally as:

> the wrapper has consumed its one public execution submission opportunity.

This flag alone must no longer decide whether Created abandonment is destructive.

### B. Native-start authority

Add a private semantic flag, for example:

```ts
private nativeStartAttempted = false;
```

or another equally descriptive name.

This flag means:

> the wrapper has crossed the final preflight and attempted the native async start call, so a subsequent Created observation may represent startup handoff rather than a never-started session.

Do not name it after Review 49 or a plan phase.

## Exact implementation ordering

In `Session.startNativeExecution(timeoutMs)` preserve the existing final `prepareForExecution()` check.

Required ordering:

```text
prepareForExecution()
-> mark native-start attempt
-> call NativeFFmpegKitExtended.executeSessionAsync(...)
```

Set the native-start flag immediately before the native call, after the final validation succeeds.

Do not set it:

- when a Session object is merely created;
- during initial submission validation;
- when it only enters the JavaScript queue;
- when it is cancelled while queued;
- when `submitOnce()` rejects because the wrapper was already cancelled;
- when queue preparation rejects before executor start.

This exact boundary protects the previously accepted “submitted startup may still read Created” case while allowing safe cleanup of work that never reached native startup.

## Cancel path correction

In `Session.cancel()` do not use `!submitted` as the Created-abandon authority.

The Created branch must use the real native-start boundary:

```ts
if (state === SessionState.Created && !this.nativeStartAttempted) {
  await this.abandonCreatedSession();
  return;
}
```

Preserve the existing behavior once native start has been attempted:

- do not destructively abandon a submitted-startup Created session;
- keep durable cancellation intent;
- let Running observation dispatch the native cancellation;
- terminal observation clears intent/dispatch bookkeeping.

## Avoid the unnecessary cancellation yield

Current code performs:

```ts
if (await SessionQueueManager.shared.cancelQueued(this)) {
  return;
}
```

`cancelQueued()` is a `MaybePromise<boolean>`. Awaiting synchronous `false` creates an unnecessary microtask boundary.

Use explicit normalization:

```ts
const queuedCancellation = SessionQueueManager.shared.cancelQueued(this);
if (queuedCancellation instanceof Promise) {
  if (await queuedCancellation) return;
} else if (queuedCancellation) {
  return;
}
```

This is not the sole fix; it removes one avoidable race window while the new native-start authority fixes the underlying state-model issue.

Do not replace every MaybePromise check in the repository. Keep this surgical.

## Preserve retryable pre-execution cleanup

A queued session may have consumed the public submission but never attempted native start.

After queue removal, a later `cancel()` must still be able to retry Created abandonment when the first discard cleanup did not commit.

The simplest valid implementation is for the Created branch to use `nativeStartAttempted`, not `submitted`. Existing `abandonCreatedSession()` already keeps `createdSessionAbandoned` false on Promise rejection and becomes idempotent only after commit.

If release cleanup also needs retry in the exact queued-discard path, preserve the existing `discardBeforeExecution()` semantics rather than inventing a second release authority. Do not duplicate backend release logic in `cancel()`.

If a deterministic regression proves that a queued discard release failure can remain stranded after a later cancel, add one private pre-execution-discard cleanup method/state in `Session` and reuse it from both queue discard and cancellation retry. Do not change shared C++ for this.

## `submitOnce()` rules

Preserve the single-use public contract.

Required behaviors:

- second real submission attempt remains rejected;
- cancelled objects remain unexecutable;
- restored Running/terminal wrappers remain non-destructively rejected;
- a state-probe failure before admission remains non-destructive and retryable according to the accepted Review 46 behavior;
- consuming the public API because the object is already cancelled must not falsely imply native startup occurred.

Do not weaken the object-level one-shot invariant to solve cancellation cleanup.

## Goal 1 deterministic tests

Prefer `react-native/tests/wasm-session-ownership.test.js` because it already owns the cancellation, state, abandonment, execution-start, release, and durable-intent fakes.

### Test A — cancellation commits abandonment when execute is attempted before cancel resolves

Use a fresh Created session.

Sequence:

```text
const cancellation = session.cancel();
const execution = session.executeAsync();
await execution rejection;
await cancellation;
```

Do not insert arbitrary sleep to prove ordering.

Assertions:

- execution rejects with `SessionCancelledException`;
- executor/native-start count is `0`;
- abandonment attempts exactly `1`;
- abandonment commits exactly `1`;
- Running cancellation calls `0`;
- cancellation intent remains fail-closed as expected for the abandoned identity;
- repeated `cancel()` after commit causes no additional state read/abandonment.

This case must fail against the Review 48 snapshot before the fix if the existing scheduler/test seam reproduces the unconditional-await interleaving. If Node microtask scheduling makes the exact public interleaving difficult to freeze, expose an internal test latch around the queue false-return boundary rather than replacing it with timing sleeps.

### Test B — queued failed abandonment can be retried

- set queue concurrency to one;
- hold another session active;
- enqueue target Created session;
- inject a first abandonment failure;
- remove/cancel the queued target;
- prove executor/native start remains zero;
- clear the injected failure;
- call `target.cancel()` again;
- prove another abandonment attempt occurs and commits;
- prove no Running native cancellation occurs;
- prove reservation/queue state is clean.

Preserve the queue's accepted execution-promise outcome and cleanup logging policy unless a direct product invariant requires otherwise.

### Test C — consumed public submission is not native-start authority

Construct a case where the execution API has been consumed but the native executor never starts. Assert a later Created cancellation can still perform abandonment.

Use state/counter assertions, not source-text equality.

### Test D — startup Created remains protected

Retain and strengthen the existing startup cancellation case:

- native start attempt occurs;
- state remains `Created` temporarily;
- cancellation during this interval performs zero Created abandonment;
- durable cancellation intent survives;
- once Running is observed, native cancellation dispatch occurs exactly once.

### Test E — prior cancellation regressions remain green

Retain:

- direct Created cancellation;
- failed direct abandonment retry;
- state-read failure latching;
- reconstructed Created durable intent;
- queued cancellation no native dispatch;
- Running restored cancellation;
- immediate/deferred native cancellation failure retries;
- completion-wins race;
- terminal handle release.

## Goal 1 documentation

Update React Native README/TSDoc only as needed.

Public wording should say:

- cancellation before native start remains a pre-execution cancellation even if an execute call has already been consumed;
- once native start is attempted, a temporary Created state is treated as startup-in-flight and is not abandoned;
- failed pre-execution cleanup remains retryable without permitting later execution.

Do not expose internal flag names in public docs unless necessary.

---

# Goal 2 — deterministic first-error authority for multi-session cancellation

## Problem to solve

`SessionQueueManager.cancelCurrent()` invokes every active target, but Promise rejection handlers race to assign one shared `firstError`.

The selected error can therefore depend on Promise settlement timing instead of active-session order.

`cancelAll()` uses the same shared timing pattern across its top-level branches.

This violates the existing deterministic first-error contract even though cancellation delivery itself is complete.

## Required deterministic ordering

Define ordering explicitly:

1. active session order is the order in the snapshot `const sessions = [...this.active]`;
2. the first failing active target in that snapshot is the cancellation error authority;
3. for `cancelAll()`, branch priority follows the declared transaction order:
   - queue-clear branch first;
   - active-cancellation branch second.

Do not use Promise completion timing as precedence.

## `cancelCurrent()` implementation shape

Keep all-target initiation behavior.

One acceptable implementation:

```ts
type ErrorSlot = { failed: false } | { failed: true; error: unknown };

const sessions = [...this.active];
const errors: ErrorSlot[] = sessions.map(() => ({ failed: false }));
const pending: Promise<void>[] = [];

sessions.forEach((session, index) => {
  try {
    const result = session.cancel();
    if (result instanceof Promise) {
      pending.push(
        result.catch((error) => {
          errors[index] = { failed: true, error };
        })
      );
    }
  } catch (error) {
    errors[index] = { failed: true, error };
  }
});
```

Then scan `errors` in index order after every async cancellation settles.

If there is no async work, scan and throw synchronously to preserve current `MaybePromise<void>` behavior.

Do not use `error !== undefined` as the presence sentinel. JavaScript can reject/throw `undefined`; use a tagged slot.

## `cancelAll()` implementation shape

Do not serialize the two branches.

Initiate in current order:

1. queue clear/removal;
2. active cancellation.

Capture each branch result/error in its own slot.

If either returns a Promise, wait for all initiated Promises. After settlement:

- throw queue-clear error when that branch failed;
- otherwise throw active-cancellation error when that branch failed;
- otherwise resolve.

Do not let the faster-rejecting branch become authority merely because it settled first.

If current `clearQueue()` policy intentionally logs secondary discard-cleanup errors rather than rejecting the aggregate, preserve that accepted policy in this goal. This goal is about deterministic ordering of errors the branches actually surface.

## Goal 2 tests

Use `react-native/tests/session-queue-manager.test.js`.

### Test A — earlier active target wins despite later settlement

- concurrency 2;
- start active A then B;
- A.cancel returns deferred Promise A;
- B.cancel returns deferred Promise B;
- call `cancelCurrent()`;
- assert both cancel methods invoked immediately;
- reject B first;
- reject A second;
- aggregate rejects with exact A error object.

### Test B — same authority under reverse settlement

- identical active ordering;
- reject A first then B;
- aggregate still rejects with A.

### Test C — second is authority only when first succeeds

- A resolves;
- B rejects;
- aggregate rejects with B.

### Test D — synchronous + asynchronous mix

- A returns a Promise that later rejects;
- B throws synchronously;
- both invoked;
- final error must still be A because A is earlier in target order.

Also test the inverse:

- A throws synchronously;
- B later rejects;
- A remains authority.

### Test E — cancel-all ordering remains parallel

Retain the Review 48 deferred queued-cleanup test:

- queue is emptied synchronously;
- active cancellation invoked before queued cleanup gate resolves;
- aggregate remains pending until all initiated branches settle.

If there is an existing safe seam to force top-level branch failures without rewriting queue internals, add one branch-order regression. Otherwise the target-order tests are mandatory and sufficient for the defect proven by Review 49.

## Goal 2 documentation

Update the queue manager TSDoc and README cancellation paragraph to say:

- every active target is attempted;
- async cancellation requests are initiated without serial waiting;
- after all attempts settle, the first failing target in stable active-session order is the reported error authority.

Do not say “first completed error.”

---

# Goal 3 — keep the pre-execution marker internal to queue handoff

## Problem to solve

Review 48 added `Session.markCancelledBeforeExecution()` as a public method because the queue directly invokes it through `CancellableSession`.

`Session` is exported by both native and Web package entry points, and generated TypeScript declarations are published. The marker therefore became consumer-visible even though it establishes only local wrapper state and does not perform the ID-level cancellation/abandonment transaction.

A consumer can call it and create a lifecycle state that supported cancellation APIs never produce.

## Required API boundary

Remove the queue-only marker from the consumer-visible Session contract.

Preferred implementation:

### 1. Protect the Session method

Change the marker to `protected`, or replace it with a private method if convenient.

Example:

```ts
protected markCancelledBeforeExecution(): void {
  this.cancelled = true;
}
```

Do not make it a public documented API.

### 2. Move the queue call through an internal closure

Change the queue handoff so the queue item carries an internal callback, e.g.:

```ts
type QueueItem<T> = {
  session: CancellableSession;
  executor: () => Promise<T>;
  resolve: (value: T) => void;
  reject: (reason?: unknown) => void;
  onCancelBeforeExecution?: () => void;
  onDiscard?: () => void | Promise<void>;
};
```

Extend `executeSession(...)` with an internal callback parameter or an options object if that produces a cleaner signature.

For each concrete Session `executeAsync()` call, pass a closure from inside the subclass/base context:

```ts
() => this.markCancelledBeforeExecution()
```

Then `SessionQueueManager.discard()` performs:

```text
invoke queue-item pre-execution cancellation marker
-> invoke discard cleanup
-> release reservation
-> reject execution promise
```

The queue manager should no longer structurally require a public `markCancelledBeforeExecution` method on the session object.

### 3. Preserve zero native dispatch

Do not replace the marker callback with `session.cancel()`.

Queued discard must still avoid:

- native state reads;
- Running cancellation dispatch;
- cancellation recursion back into the queue.

The marker is local state only; ID-level abandonment remains in `discardBeforeExecution()`.

## Alternative implementation

An internal symbol or private queue-adapter object is acceptable if it:

- is not exported in generated declarations;
- cannot be called as a normal public Session method;
- preserves the same mark-before-cleanup order;
- does not add public diagnostics solely for tests.

Avoid a broad queue API redesign.

## Goal 3 tests

### Test A — public type surface does not expose the marker

Use the existing packed-type consumer or a small compile-time type fixture.

The public package type must not allow:

```ts
session.markCancelledBeforeExecution();
```

Do not rely only on grep of source. The test should exercise the generated/published TypeScript declaration surface when the existing package test infrastructure supports it.

If the packed type harness cannot express a negative compilation assertion cleanly, add a focused source/declaration contract test plus a positive package type consumer. Keep it semantic and small.

### Test B — queue still marks before cleanup

Use a retained fake/session with a marker callback and deferred discard cleanup.

Assert:

- local cancelled state is visible before cleanup resolves;
- queue item is removed;
- executor start is zero;
- full `cancel()` call count is zero.

### Test C — all four Session types pass the internal hook

Do not duplicate four large runtime tests if the common Session implementation and source contract can prove the same call pattern.

At minimum prove that FFmpeg, FFprobe, MediaInformation, and FFplay `executeAsync()` pass the queue cancellation hook alongside discard cleanup.

### Test D — Web/native public entry points remain consistent

Both `index.ts` and `index.web.ts` should expose the same supported Session API; the internal marker must not appear as a consumer API on either surface.

## Goal 3 documentation

Remove any generated/public-facing wording that makes the queue marker look callable by applications.

Keep public docs focused on:

- `Session.cancel()`;
- `FFmpegKitExtended.cancelSession(id)`;
- `FFmpegKitExtended.cancelAllSessions()`;
- `SessionQueueManager.clearQueue()/cancelAll()` only if those lower-level queue APIs are intentionally public.

No Flutter documentation change is required.

---

# Goal 4 — regression closure, local validation, final audit, and snapshot

## Focused static/test gates

From `react-native/`, run only commands actually available in the repository and record exact results.

Start with:

```text
npm run typecheck
npm run test:compile
npm run lint
node --test tests/session-queue-manager.test.js
node --test tests/wasm-session-ownership.test.js
```

Then run the focused restored-session/clear suites that protect Review 44–47 invariants, including at least:

```text
node --test tests/restored-session-observer.test.js
node --test tests/wasm-backend-memory.test.js
```

If those test files depend on generated `.test-dist`, run `npm run test:compile` first as above.

After focused cases pass, run the full local Node suite and record pass/fail/skip counts truthfully.

Run the smallest established local Web/Wasm smoke needed for the changed shared TypeScript lifecycle/cancellation code. Do not launch an interactive browser UI.

## Required regression preservation matrix

Before declaring closure, verify that the following accepted behaviors remain green:

### Queue/execution

- duplicate object and duplicate session-ID admission rejection;
- queue reservation release on all exits;
- queue progression after sync/async executor failure;
- preparation/handoff rejection remains non-destructive;
- waiting/active accounting remains correct;
- queued cancellation never starts executor;
- later queued work continues after targeted cancellation/cleanup diagnostic.

### Cancellation

- durable ID cancellation intent;
- created direct cancellation;
- created abandonment retry;
- Running cancellation retry after native failure;
- submitted-startup Created protection;
- completion-wins race;
- all active targets attempted;
- deterministic first-error authority;
- ID `0` queue-aware cancel-all.

### Restored/history lifecycle

- restored Running observation is deduplicated by ID;
- callback targets remain bounded;
- terminal observer does not release before active execution owner settles;
- release retries remain iterative/bounded;
- clear removes observer/callback demand;
- callback rollback cannot recreate a cleared observer;
- configuration clear and lifecycle clear remain equivalent.

### Web ownership

- history state-probe failure releases temporary pointer exactly once;
- retained/temporary handle ownership remains failure-atomic;
- abandoned Created identities remain fail-closed;
- cancellation intent blocks reconstructed Created wrappers.

## Platform validation order

The implementation is React Native TypeScript-only unless Goal 3 changes declaration/package plumbing. Preserve the established order.

### 1. Windows first

Use the configured local Windows runtime artifact only.

Run the established React Native Windows package/build gate after type/tests pass.

Do not download a remote native bundle.

### 2. Android on local Windows

Run the existing local Android build using the already configured local AAR.

Do not run Android under WSL merely to duplicate the Windows-host gate.

### 3. Linux/WSL where affected

Run the existing TypeScript/Node/Web or package gates required by the repository for shared wrapper changes.

Do not modify the ManyLinux builders checkout.

### 4. Apple last

Use the authorized MacBook Air SSH host and existing local universal XCFramework artifacts.

Run the established React Native iOS, tvOS, and macOS noninteractive builds and the package tests required by the current repository gate.

Use UTF-8 locale/PATH corrections already established by the tracker if required. Record any first-attempt environment failure rather than hiding it.

Do not launch a simulator/application interactively.

## Flutter validation policy

Review 49 source comparison proves Flutter and shared packaging are unchanged from the prior verified authority.

If implementation remains React Native-only:

- perform a bounded no-drift source check for Flutter and platform-native directories;
- preserve the previously accepted Flutter platform evidence;
- do not rerun the full Flutter matrix merely for ceremony.

If implementation unexpectedly touches Flutter, stop and justify the concrete defect before proceeding.

## Source-diff audit before freeze

Inspect the complete implementation diff against starting SHA `8c89594380b9db5313bd4a7c4173e341b5943f31`.

Expected production changes should remain within:

- `react-native/src/session.ts`
- `react-native/src/session-queue-manager.ts`
- possibly the four Session execute call sites in `session.ts` if the internal hook is passed separately
- `react-native/src/ffmpeg-kit-extended.ts` only if documentation/TSDoc needs a semantic clarification; no logic change is expected there

Expected non-production changes:

- `react-native/tests/session-queue-manager.test.js`
- `react-native/tests/wasm-session-ownership.test.js`
- packed type/API test if needed
- `react-native/README.md`
- semantic internal comments/TSDoc
- tracker/review working documents

Any change in Flutter, shared C++, platform-native directories, `libs/libffmpegkit`, native configuration, or builders is a stop-and-investigate event.

## Semantic identifier audit

Search changed production/tests for:

- `Review49`
- `Review 49`
- `R49`
- finding IDs
- goal IDs

No such identifier belongs in production/test names or public documentation.

Tracker metadata may use those identifiers.

## Final substantive audit checklist

Before claiming zero findings, inspect the final source for each question:

1. Can a never-started Created session still be abandoned even if its public execute method was consumed?
2. Can a native-started-but-still-Created session ever be destructively abandoned by cancellation?
3. Can a queued abandonment failure be retried by a later cancellation call?
4. Does cancellation avoid an unnecessary microtask yield when the target is not queued?
5. Does multi-session cancellation attempt every target immediately?
6. Is the reported cancellation error stable when Promise rejection order is reversed?
7. Can a consumer call the queue-only marker through the published Session type?
8. Does queue discard still mark local cancellation before cleanup without invoking full cancel/native state reads?
9. Are restored observer, clear, release, and Web ownership authorities unchanged?
10. Are Flutter/platform-native directories unchanged?
11. Is native ABI/submodule/builders state unchanged?

If any answer is wrong or uncertain from source, do not claim closeout.

## Exact source freeze and snapshot

Only after all focused/local validation passes and the final audit has zero substantive findings:

1. commit/push the final wrapper changes to `dev-wasm`;
2. record the exact full 40-character wrapper SHA;
3. verify the working tree and relevant remote ref represent that source authority;
4. run only the repository source-snapshot workflow at the exact SHA;
5. download the wrapper-only artifact through the GitHub connector;
6. verify:
   - GitHub artifact digest;
   - `source.tar.gz.sha256`;
   - actual archive SHA-256;
   - every `SHA256SUMS` entry;
   - `SUBMODULES.txt`;
   - `SYMLINKS.tsv`;
   - `snapshot-metadata.json.snapshot_sha`;
   - `runtimeExecution=false`;
   - frozen `libs/libffmpegkit` SHA;
7. record workflow run ID, artifact ID/name/link, outer digest, embedded archive digest, manifest count, symlink count, runtime flag, and submodule SHA in the tracker.

Do not create a native/builders snapshot.

Tracker-only provenance commits after the frozen wrapper snapshot must be clearly identified as metadata-only and must not be substituted for the frozen implementation SHA.

---

# Definition of done

Review 49 remediation is complete only when all of the following are true:

- [ ] public one-shot submission and native-start authority are separate concepts;
- [ ] never-started Created cancellation cannot be suppressed merely because an execute call was consumed;
- [ ] queued failed abandonment can be retried without native Running cancellation;
- [ ] submitted-startup Created sessions remain protected from destructive abandonment;
- [ ] nonqueued cancellation avoids the unnecessary synchronous-false await boundary;
- [ ] `cancelCurrent()` error authority is stable by active target order, not Promise settlement order;
- [ ] `cancelAll()` branch error authority is deterministic;
- [ ] all active targets are still attempted without serial waiting;
- [ ] queue cancellation marker is no longer a consumer-visible Session API;
- [ ] queued work is still marked cancelled before discard cleanup;
- [ ] queued discard still performs zero native state read/Running cancellation dispatch before execution;
- [ ] prior Review 44–48 cancellation/observer/clear/release/Web ownership regressions remain green;
- [ ] React Native typecheck/test compile/lint/focused/full local tests are recorded truthfully;
- [ ] required local Windows → Android → Linux/WSL → Apple validation is complete using local ABI `0.11.2` artifacts only;
- [ ] Flutter and platform-native source no-drift checks are clean;
- [ ] `libs/libffmpegkit` remains exactly `b74da2c5d1e294b87d15d73a6687393729e932b3`;
- [ ] ManyLinux builders remain unchanged;
- [ ] no hosted Flutter/RN acceptance workflow ran;
- [ ] no native ABI was downloaded/published/rebuilt;
- [ ] final bounded audit has zero substantive findings;
- [ ] exact final wrapper SHA is frozen and pushed;
- [ ] one wrapper-only source snapshot at that exact SHA is downloaded and fully verified.

If all items are satisfied, the next review should be a closeout verification rather than another implementation plan.
