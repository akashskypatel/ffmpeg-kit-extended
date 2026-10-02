# Review 44 — Flutter + React Native Cross-Platform Code Review

**Project:** FFmpegKitExtended  
**Review type:** frozen-source code review; substantive findings only  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch represented by snapshot:** `dev-wasm`  
**Frozen wrapper source:** `d8320a5fd3cd4031d9c9b9a0edf71539231c5380`  
**Snapshot workflow:** `36961755649`  
**Snapshot artifact:** `review43-source-snapshot-36961755649`  
**Artifact ID:** `11207808848`  
**Outer artifact SHA-256:** `87de8776fe42c1740f390dda65f1cfcb43d1c1a2d167906b2ac98b4029beaae5`  
**Embedded `source.tar.gz` SHA-256:** `69dab1a34958bd8948b2d5a6b472069b971989ae66c9fca29756a35992dd010b`  
**Manifest:** **1,093/1,093 verified**  
**Symlinks:** `0`  
**Snapshot metadata:** `runtimeExecution=false`  
**Recursive submodule:** `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`  
**Native ABI/runtime:** frozen `0.11.2`; not downloaded, rebuilt, or re-reviewed

---

## 1. Review authority and provenance

Review 44 uses the exact wrapper-only snapshot frozen at Review 43 closeout. Repository source was not reconstructed by piecemeal GitHub file reads.

The downloaded artifact was validated before source inspection:

```text
GitHub artifact SHA-256:
  87de8776fe42c1740f390dda65f1cfcb43d1c1a2d167906b2ac98b4029beaae5

snapshot-metadata.snapshot_sha:
  d8320a5fd3cd4031d9c9b9a0edf71539231c5380

snapshot-metadata.runtimeExecution:
  false

source.tar.gz SHA-256:
  69dab1a34958bd8948b2d5a6b472069b971989ae66c9fca29756a35992dd010b

SHA256SUMS:
  1093/1093 verified

SYMLINKS.tsv:
  0 entries

SUBMODULES.txt:
  b74da2c5d1e294b87d15d73a6687393729e932b3 libs/libffmpegkit (b74da2c)
```

No native/builders artifact was downloaded. Review 44 treats native ABI `0.11.2` and `libs/libffmpegkit` as frozen evidence, not review scope.

---

## 2. Review boundary

This was **code review only**.

No Flutter or React Native test suite, compiler, platform build, simulator/device application, browser runtime, native execution, hosted acceptance CI, or repository mutation was performed as Review 44 evidence.

The review first re-audited the platform-native bridge surfaces closed in Review 43. After finding no substantive open platform-native bridge defect in the frozen snapshot, the review expanded into Flutter and React Native wrapper/session/lifecycle code, as requested.

Reviewed areas included:

```text
Flutter
  flutter/lib/src/session.dart
  flutter/lib/src/session_queue_manager.dart
  flutter/lib/src/session_history_index.dart
  flutter/lib/src/ffmpeg_kit_extended.dart
  flutter/lib/src/ffmpeg_session.dart
  flutter/lib/src/ffprobe_session.dart
  flutter/lib/src/ffplay_session.dart
  flutter/lib/src/media_information_session.dart
  platform-native bridge sources rechecked for Review 43 closure

React Native
  react-native/src/ffmpeg-kit-extended.ts
  react-native/src/session.ts
  react-native/src/session-queue-manager.ts
  react-native/src/ffmpeg-kit.ts
  react-native/src/ffprobe-kit.ts
  react-native/src/ffplay-kit.ts
  react-native/src/platform/backend.native.ts
  react-native/src/platform/backend.web.ts
  react-native/src/platform/backend-registry.ts
  react-native/src/platform/web/session-history-registry.ts
  react-native/src/platform/web/session-registry.ts
  react-native/src/platform/native-session-reconciliation.ts
  react-native/cpp/FFmpegKitDynamicApi.cpp
  relevant regression tests and README contract text
```

Excluded from findings:

```text
formatting/style
naming preferences
tracker/procedural observations
documentation-only drift without product consequence
speculative hardening
unsupported hypothetical misuse
native ABI internals frozen outside wrapper scope
issues already closed unless contradictory frozen-source evidence exists
```

A Review 44 finding requires a reachable wrapper path, a concrete contract/lifetime/cancellation defect, and a product consequence supported by the frozen source.

---

## 3. Executive disposition

### Platform-native bridge

**CLOSED on the Review 44 frozen source.**

Review 43's iOS texture-registration failure fix is present in both CocoaPods and SwiftPM source copies, macOS retains the equivalent guard, and the accepted Windows/Linux/Android/Apple ownership and React Native native-bridge lifetime/error invariants remain intact. Review 44 found no contradictory source evidence requiring another platform-native bridge finding.

### Flutter wrapper

**No new substantive Flutter wrapper defect was established in this pass.**

The Flutter wrapper already contains the stronger cancellation and restored-observer boundaries relevant to the React Native findings below, including:

```text
ID-based cancel routes through wrapper/queue authority
submitted-Created cancellation does not become Created abandonment
restored wrappers gate callback routing on authoritative Running state
restored terminal observation is a separate lifecycle owner
```

### React Native wrapper

**NOT YET CLOSED. Five substantive wrapper findings remain.**

| ID | Severity | Surface | Finding |
| --- | --- | --- | --- |
| **R44-F1** | **High** | React Native public ID-based cancellation | `FFmpegKitExtended.cancelSession(id)` bypasses the JS queue/session cancellation authority and calls the backend directly. A queued Created session can therefore remain queued and execute after the public cancellation call returns. ID `0` also does not inherit the high-level cancel-all semantics used by Flutter. |
| **R44-F2** | **Medium-High** | React Native startup cancellation/history | `Session.cancel()` treats any observed `Created` state as pre-execution abandonment, even after this wrapper has been submitted and dequeued. During the real native handoff window this can tombstone/remove a session that actually proceeds to execution, causing terminal history to disappear behind an abandonment authority. |
| **R44-F3** | **Medium-High** | React Native native + Web restored Running history lifetime | History projection promotes an unowned Running handle into retained ownership to avoid cancelling it, but a reconstructed history wrapper starts no terminal monitor. If the original JS execution owner no longer exists, the promoted handle has no guaranteed terminal releaser and can remain retained indefinitely. |
| **R44-F4** | **Medium** | React Native restored Running callbacks | Callback setters on a reconstructed Running session silently store callbacks but cannot acquire completion/log/statistics demand because callback demand is activated only by `executeAsync()`. A Running history wrapper cannot re-execute, so the setters can appear successful while no events are delivered. |
| **R44-F5** | **Medium** | React Native Web history lookup | `historyPointer()` obtains a temporary owning Wasm handle and then probes state before it has established cleanup ownership. If the state probe throws, the pointer escapes without `ffmpeg_kit_handle_release`, leaking one native handle per failed lookup. |

No finding requires a native ABI change.

---

# 4. R44-F1 — public ID-based cancellation bypasses the JavaScript queue

**Severity:** High  
**Primary surface:** React Native `FFmpegKitExtended.cancelSession(sessionId)`  
**Affected backends:** native and Web through the shared high-level API  
**Native ABI change:** none

## 4.1 Source evidence

`react-native/src/ffmpeg-kit-extended.ts:114-118`:

```ts
/** Requests cancellation by native session ID. */
static async cancelSession(sessionId: number): Promise<void> {
  this.requireInitialized();
  await NativeFFmpegKitExtended.cancelSession(sessionId);
}
```

The method jumps directly to the selected backend.

By contrast, `Session.cancel()` owns the wrapper cancellation transaction:

```text
record durable cancellation intent
remove queued work when present
abandon only a true pre-execution Created identity
otherwise dispatch native cancellation when Running
preserve cancellation intent across startup state transitions
```

`SessionQueueManager` exposes object-based `cancelQueued(session)` and all-target `cancelAll()`, but the static ID method does not consult either authority.

Flutter's equivalent high-level ID API already uses the stronger contract:

```dart
if (sessionId == 0) {
  cancelAllSessions();
  return;
}
getSession(sessionId)?.cancel();
```

This comparison is evidence of an existing wrapper-level semantic boundary, not a request for cosmetic API parity.

## 4.2 Reachable failure sequence

```text
1. maxConcurrentSessions prevents a newly submitted session from starting.
2. Session A is queued and owns its native session ID reservation.
3. Application calls FFmpegKitExtended.cancelSession(A.id).
4. Static cancelSession calls only NativeFFmpegKitExtended.cancelSession(A.id).
5. SessionQueueManager still contains A.
6. A.cancelled remains false and durable JS cancellation intent was not recorded.
7. A's queue slot later opens.
8. processQueue() prepares A and invokes its executor.
9. A starts even though the public ID-based cancellation call completed.
```

For an FFmpeg command that writes files or otherwise has side effects, execution after a successful cancellation request is a real product consequence.

## 4.3 Required semantics

The public ID method must use the same cancellation authority as object cancellation:

```text
sessionId == 0
  -> cancel all queued + active managed sessions

managed queued/active session ID
  -> cancel the matching Session object
  -> queue cancellation must prevent native execution

history/restored session ID
  -> reconstruct/resolve wrapper and invoke Session.cancel()

unknown ID
  -> preserve documented no-op/error semantics consistently
```

Do not add a second cancellation state machine inside `FFmpegKitExtended`.

---

# 5. R44-F2 — submitted-Created cancellation is misclassified as abandonment

**Severity:** Medium-High  
**Primary surface:** React Native `Session.cancel()`  
**Affected backends:** native and Web  
**Native ABI change:** none

## 5.1 Source evidence

`react-native/src/session.ts:164-183` currently does:

```ts
this.cancelled = true;
NativeFFmpegKitExtended.recordCancellationIntent?.(this.sessionId);

if (await SessionQueueManager.shared.cancelQueued(this)) {
  return;
}
const state = this.getState();
if (state === SessionState.Created) {
  await this.abandonCreatedSession();
  return;
}
```

But `submitOnce()` sets `submitted = true` before enqueue/handoff:

```ts
this.submitted = true;
return submit();
```

The repository's existing tests explicitly acknowledge the native startup interval in which the executor has started while state is still `Created`:

```text
"Keep the handoff boundary in Created until the monitor observes Running."
"completion before Running observation wins without late cancellation"
```

So `Created` does not mean "never submitted".

Flutter already guards this distinction:

```dart
if (currentState == SessionState.created && !_submitted) {
  abandonCreatedSession(...);
  ...
  return;
}

// A submitted session can remain Created while the native worker is
// handing off to its worker thread. Keep the intent and wait for Running.
```

## 5.2 Why abandonment is destructive here

React Native native abandonment:

```text
adds the session ID to abandonedSessionIds
invokes native abandonCreatedSession
filters abandoned IDs out of getSession/getSessions/getLastSession results
removes the tombstone only after an independent native-absence proof
```

React Native Web abandonment:

```text
SessionHistoryRegistry.abandonCreated(id)
  -> adds abandonedCreatedIds tombstone
  -> removes the non-terminal history record
  -> reconciliation preserves the tombstone while native identity still exists
```

If the session was already submitted and later reaches Running/terminal, this abandonment authority can outlive the real execution. On Web, later `markTerminal(id)` cannot mark a history record that abandonment already removed.

## 5.3 Product consequence

A user can cancel during startup, the native execution can still proceed/settle, but the session becomes hidden from history and direct lookup because it was classified as a never-executed Created discard.

That breaks lifecycle/history observability and can leave a durable tombstone for an identity that actually executed.

## 5.4 Required semantics

After queued cancellation has failed to find the session:

```text
state == Created AND submitted == false
  -> true pre-execution abandonment

state == Created AND submitted == true
  -> retain cancellation intent
  -> do not abandon history
  -> allow monitor to deliver cancellation when Running appears
  -> if terminal wins before Running, clear intent and preserve terminal history
```

This is a surgical predicate/order fix, not a queue redesign.

---

# 6. R44-F3 — restored Running history ownership has no guaranteed terminal releaser

**Severity:** Medium-High  
**Primary surfaces:** React Native native shared C++ history projection and React Native Web history projection  
**Native ABI change:** none

## 6.1 Native history promotion

`react-native/cpp/FFmpegKitDynamicApi.cpp:554-591` intentionally promotes a Running temporary history handle into `retainedSessionHandles`:

```text
acquire temporary native handle
read state
if Running:
  create/find RetainedSessionEntry
  release temporary ownership
  return a retained borrow
```

This is necessary because releasing an owning Running-session handle is not a harmless observation.

The retained-handle release function documents its current owner:

```cpp
// Called by the JS monitor only after a terminal session state has been
// observed and final logs/statistics have been drained.
release(entry->handle);
```

## 6.2 Web history promotion

`react-native/src/platform/backend.web.ts:286-304` performs the equivalent promotion:

```ts
const retained = this.sessions.get(record.sessionId);
if (retained) return {pointer: retained, temporary: false};

const pointer = ffmpeg_kit_get_session(...);
...
const state = ffmpeg_kit_session_get_state(pointer);
if (state === SessionState.Running) {
  this.sessions.retain(pointer, record.sessionId);
  return {pointer, temporary: false};
}
```

## 6.3 Missing owner after reconstruction

`parseSessionJson()` / `sessionFromSnapshot()` constructs an ordinary `FFmpegSession`, `FFprobeSession`, `FFplaySession`, or `MediaInformationSession` from history data. Construction does not start the `monitor()` lifecycle.

`monitor()` is currently entered only by execution paths such as `executeAsync()`, and its terminal `finally` performs `releaseOwnedHandle()`.

A Running history wrapper is not allowed to re-submit as Created work, so there is no guaranteed later call into that execution monitor.

The narrower `FFmpegKit`, `FFprobeKit`, and `FFplayKit` typed history helpers are even less lifecycle-aware: they parse only `{sessionId, command}` and construct new wrapper objects directly.

## 6.4 Reachable consequence

The problematic case is a Running native session reconstructed without its original JavaScript execution monitor—for example a recovery/reload/history-adoption path:

```text
history read sees Running session
backend promotes owning handle to retained storage
JSON snapshot creates ordinary JS wrapper
no execution monitor belongs to that reconstructed wrapper
native session eventually reaches terminal state
no guaranteed owner calls releaseSessionHandle(id)
retained native/Wasm handle can remain alive for process lifetime
```

The design already treats Running history wrappers as supported control surfaces: an existing regression explicitly checks that "a running history wrapper forwards cancellation despite not being submitted." The missing terminal lifetime owner is therefore on a reachable intended wrapper path.

## 6.5 Required semantics

A reconstructed Running identity needs exactly one non-execution lifetime observer per session ID that:

```text
does not start/re-execute the session
does not claim queue ownership
observes scalar state until terminal
preserves cancellation intent semantics
releases the retained native handle exactly once after terminal observation
stops cleanly after successful global history clear
coexists safely with an original execution monitor if one still exists
```

Multiple wrappers for the same Running ID must share/dedupe terminal release authority rather than race two retained releases.

---

# 7. R44-F4 — callbacks attached to restored Running sessions are silently inert

**Severity:** Medium  
**Primary surface:** React Native `Session` callback demand/lifecycle  
**Affected session types:** FFmpeg, FFprobe, FFplay, MediaInformation as applicable  
**Native ABI change:** none

## 7.1 Source evidence

For FFmpeg, callback setters store the callback then call `refreshCallbackDemand()`:

```ts
async setLogCallback(callback) {
  this.logCallback = callback;
  await this.refreshCallbackDemand();
}
```

But `refreshCallbackDemand()` begins with:

```ts
if (!this.callbackDemandActive || !this.callbackDemandProviders) return;
```

Those fields are activated only by `runWithCallbackDemand()`, which wraps this wrapper object's `executeAsync()` path.

A reconstructed Running history wrapper did not execute through that object. Therefore:

```text
setLogCallback -> returns successfully, no bridge lease
setStatisticsCallback -> returns successfully, no bridge lease
setCompleteCallback -> stores callback, no terminal observer exists
```

Because a Running session cannot be re-executed as a Created session, there is no later path that automatically activates those callbacks.

## 7.2 Product consequence

An application can retrieve a Running session from history, attach callbacks through public methods, receive no error, and then receive no completion/log/statistics delivery.

This is especially important on the same recovery/restoration path in R44-F3: the wrapper is intended for inspection/control but lacks observer ownership.

## 7.3 Flutter comparison

Flutter already models this explicitly:

```text
restored wrapper flag
Running-state verification before observer routing
restored observer bridge demand separate from execution ownership
terminal completion observation separate from queue settlement
```

That is useful architectural evidence for the required lifecycle distinction; React Native does not need to copy Flutter implementation mechanically.

## 7.4 Required semantics

Restored Running callback attachment must become an observer operation:

```text
verify current state is Running before publishing routing
acquire only callback demand actually needed
share the per-ID restored lifetime observer from R44-F3
stream/reconcile logs/statistics using existing delivery machinery
invoke completion at most once
release observer callback demand at terminal or explicit sink removal
never execute the session
never turn callback observation into cancellation ownership
```

If the initial Running-state read or bridge install fails, the setter must roll back the sink mutation and surface the error rather than report a live callback that cannot receive events.

---

# 8. R44-F5 — Web history state-probe failure leaks a temporary owning handle

**Severity:** Medium  
**Primary surface:** React Native Web/Wasm history projection  
**Native ABI change:** none

## 8.1 Source evidence

`react-native/src/platform/backend.web.ts:286-304`:

```ts
const pointer = numberResult(
  this.call('ffmpeg_kit_get_session')(int64(record.sessionId)),
);
if (!pointer) return undefined;

const state = numberResult(this.call('ffmpeg_kit_session_get_state')(pointer));
if (state === SessionState.Running) {
  this.sessions.retain(pointer, record.sessionId);
  return {pointer, temporary: false};
}
return {pointer, temporary: true};
```

`historySnapshots()` releases temporary handles in its `finally`, but that cleanup starts only **after** `historyPointer()` successfully returns a handle descriptor.

If `ffmpeg_kit_session_get_state(pointer)` throws, `historyPointer()` throws before returning `{pointer, temporary: true}`. The caller catches the error but has no pointer value to release.

## 8.2 Product consequence

A failed history state probe can leak one owning Wasm handle. Repeated failed history calls can accumulate native references and keep session resources alive.

This is not theoretical cleanup preference: the same backend already uses failure-atomic cleanup when creation/ownership probes fail in other paths.

## 8.3 Required semantics

Once `ffmpeg_kit_get_session` returns a nonzero temporary pointer, one local cleanup authority must exist until ownership is either:

```text
transferred into WasmSessionRegistry for Running state
or
returned to historySnapshots as an explicitly temporary handle
```

Any exception before either transfer must release the pointer exactly once while preserving the original state-probe error as primary.

---

# 9. Platform-native bridge re-audit

Review 44 rechecked the Review 43 closure state before expanding wrapper scope.

## 9.1 Flutter iOS

Both CocoaPods and SwiftPM FFplay sources now reject `registerTexture:` returning `0` immediately with:

```text
TEXTURE_REGISTRATION_FAILED
Flutter could not register the FFplay texture
```

The guard is before callback, texture, bridge-retain, owner, native-frame-callback, and success-result publication.

## 9.2 Flutter macOS

Both macOS packaging copies retain the already-correct zero-registration guard.

## 9.3 Flutter Windows/Linux/Android

No contradictory source evidence was found against the accepted texture retirement, Linux pixel-buffer lifetime, Android Surface/ANativeWindow ownership, latest-owner, or packed-frame normalization invariants.

## 9.4 React Native native bridge

No new platform-native defect was established in:

```text
shared C++ operation-token/clear composition
retained-handle lease/release authority
Windows invocation-bound Promise errors
same-call synchronous diagnostics
log callback copied-payload lifetime
Windows FFplay weak dispatch/latest owner
Android latest Surface owner
iOS/tvOS/macOS unregister/drain and weak owner coordination
```

R44-F3 does involve the shared C++ retained-history mechanism, but the defect is not the platform implementation of retention itself. The missing authority is the wrapper-level terminal owner after history reconstruction.

---

# 10. Flutter wrapper audit disposition

No substantive Flutter finding was established in the Review 44 expanded pass.

Relevant clean semantics include:

```text
FFmpegKitExtended.cancelSession(0) delegates to cancel-all
nonzero ID cancellation resolves a Session and calls Session.cancel()
Session.cancel() distinguishes unsubmitted Created from submitted Created startup
startup cancellation preserves intent until Running or terminal
restored-session callback routing verifies authoritative Running state
restored terminal completion has lifecycle ownership distinct from queue settlement
```

Review 44 does not recommend touching Flutter merely for parity with the React Native remediation.

---

# 11. Regression gaps explaining why prior validation could stay green

The Review 43 local matrix primarily proved platform-native bridge behavior and normal session execution. The five Review 44 findings require combinations not covered by those success-path gates:

```text
public static ID cancellation while a session is still queued
cancel during the submitted-but-native-Created handoff window plus history inspection
Running history reconstruction after original JS execution ownership is absent
callback setters on a reconstructed Running wrapper
Web history lookup where get_session succeeds but get_state throws
```

A successful build or ordinary execution test does not exercise these lifecycle boundaries.

---

# 12. Review 44 remediation goals

| Goal | Required result |
| --- | --- |
| **R44-G1** | Route public React Native ID-based cancellation through the same queue/session/durable-intent authority as object cancellation; preserve ID `0` cancel-all behavior. |
| **R44-G2** | Distinguish true pre-submission Created abandonment from the submitted-Created native handoff window so cancellation cannot tombstone a real execution. |
| **R44-G3** | Give reconstructed Running React Native sessions one deduplicated terminal lifetime observer that retires retained native/Web ownership exactly once without re-execution. |
| **R44-G4** | Make callbacks attached to restored Running sessions acquire/release observer demand and deliver completion/log/statistics consistently without claiming execution ownership. |
| **R44-G5** | Make React Native Web history-pointer acquisition failure-atomic so every temporary pointer is released exactly once on a state-probe error. |
| **R44-G6** | Add focused deterministic regressions, update semantic API/lifecycle documentation, run only affected local wrapper validation during remediation, then perform one final bounded audit and exact-SHA wrapper snapshot if clean. |

---

# 13. Required regression coverage

Review 44 itself executed no tests. Remediation should add focused tests before relying on broad package/platform validation.

## 13.1 ID cancellation

Prove:

```text
queued target by ID is removed and never starts
execution promise rejects with SessionCancelledException
queue reservation is released
active target by ID receives exactly one native cancellation request
ID 0 uses all-target queue + active cancellation semantics
unknown ID follows the documented no-op/error contract
```

## 13.2 Submitted-Created handoff

Prove:

```text
pre-submission Created cancel still abandons
queued cancel still discards
submitted/dequeued Created cancel does not call abandonCreatedSession
cancellation intent remains live until Running
Running dispatches cancellation exactly once
terminal-before-Running preserves terminal history and clears intent
native + Web history do not tombstone the submitted identity
```

## 13.3 Restored Running lifetime

Prove:

```text
history reconstruction of Running ID creates/joins one terminal observer
multiple reconstructed wrappers do not race duplicate retained release
terminal observation releases promoted native/Web ownership once
original execution monitor + restored observer coexist without double release
successful clear terminates/rests observer ownership cleanly
no executeSessionAsync call occurs from observer-only lifecycle
```

## 13.4 Restored callbacks

For supported session types prove:

```text
Running restored wrapper can attach completion callback
FFmpeg restored wrapper can attach log/statistics callbacks
initial state/bridge failure rolls setter state back
removing final optional sink releases matching callback demand
terminal callbacks are delivered at most once
callbacks do not re-execute or cancel the session
callback demand returns to baseline after terminal
```

## 13.5 Web failure atomicity

Use a fake Wasm module where:

```text
ffmpeg_kit_get_session -> nonzero pointer
ffmpeg_kit_session_get_state -> throws sentinel error
ffmpeg_kit_handle_release -> records releases
```

Assert the sentinel error remains primary and the pointer is released exactly once.

---

# 14. Documentation guidance

Public documentation should be changed only where behavior is externally meaningful.

Update React Native API/README text to make these guarantees explicit:

```text
cancelSession(id) participates in the same queue-aware cancellation transaction as Session.cancel()
ID 0 cancels all managed queued/active sessions if that is the chosen compatibility contract
submitted Created sessions are startup work, not abandoned Created identities
Running sessions returned from history are observer/control wrappers, not re-executable sessions
callbacks attached to a restored Running wrapper observe the existing execution without claiming execution ownership
```

Use internal comments for the Web temporary-pointer transfer invariant and the per-ID restored terminal-release authority.

Do not mention Review 44, goal IDs, or finding IDs in production symbols/comments/tests.

---

# 15. Closeout criteria

Review 44 should not be declared wrapper-clean until all applicable items below are true:

```text
[ ] Public RN ID cancellation is queue-aware and durable.
[ ] RN ID 0 cancellation semantics are explicitly defined and tested.
[ ] Submitted-Created startup cancellation never abandons a real execution.
[ ] Pre-submission/queued Created discard behavior remains intact.
[ ] Native and Web history preserve submitted sessions through terminal state.
[ ] Running history promotion has one terminal release authority per session ID.
[ ] Restored Running wrappers do not re-execute native work.
[ ] Restored callbacks acquire observer demand and deliver/retire correctly.
[ ] Execution monitor and restored observer cannot double-release a retained handle.
[ ] Web state-probe failure releases its temporary pointer exactly once.
[ ] Existing React Native queue/history/cancellation/lifetime tests remain green.
[ ] No Flutter regression is introduced.
[ ] No native ABI/submodule/builder source changes occur.
[ ] No remote native bundle is fetched for local validation.
[ ] No hosted Flutter/RN acceptance CI is used.
[ ] Final bounded code review finds no substantive open Flutter/RN wrapper defect in the audited surfaces.
[ ] Exact wrapper SHA is frozen and represented by one verified wrapper-only source snapshot.
```

---

# 16. Review 44 closeout

```text
Frozen wrapper authority: VERIFIED
Outer artifact digest: VERIFIED
Embedded source archive: VERIFIED
Manifest: 1093/1093
Symlinks: 0
runtimeExecution: false
Frozen native submodule: VERIFIED

Native ABI separately downloaded: NO
Native ABI reviewed: NO
Native ABI source change required: NO

Code review only: YES
Tests/builds/runtime executed by Review 44: NO
Repository mutation by Review 44: NO

Platform-native bridge substantive findings: 0
Flutter wrapper substantive findings: 0
React Native wrapper substantive findings: 5

R44-F1 High        — public ID cancellation bypasses queue/session authority
R44-F2 Medium-High — submitted-Created startup cancellation is mis-abandoned
R44-F3 Medium-High — restored Running retained ownership lacks terminal releaser
R44-F4 Medium      — restored Running callback setters are silently inert
R44-F5 Medium      — Web history state-probe error leaks a temporary handle

Pedantic/procedural findings reported: 0

Disposition:
PLATFORM-NATIVE BRIDGE CLOSED.
FLUTTER WRAPPER CLEAN IN REVIEWED SURFACES.
REACT NATIVE WRAPPER NOT YET CLOSED.
```
