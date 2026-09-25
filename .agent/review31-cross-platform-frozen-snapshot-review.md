## Review 31 — Flutter + React Native cross-platform code review

Review 31 is complete against the **frozen Review 30 snapshots**, not the live repository:

- Wrapper: `e218d305dfd33cd06321f09e7bee706b1e2cd9a3`, workflow `36068910964`, artifact `10837312749`, `source.tar.gz` SHA-256 `22fac37f955738f14da360b430c7bda929565fdd4565206268b3a922d46cd8fe`.
- Builders/native contract authority: `b74da2c5d1e294b87d15d73a6687393729e932b3`, workflow `36069043862`, artifact `10836459435`, `source.tar.gz` SHA-256 `1df84a2c4a710a611e5597b137be33cc342ed357742bdd47a1c3901a3b9df224`. These are the tracker-recorded Review 30 freezes. :chatgpt-content-reference{index="0"}

I independently verified **1,054/1,054 wrapper files** and **425/425 builders files** against their snapshot manifests. This was strictly a **code review**: no Flutter/RN builds, tests, CI, simulators, applications, or runtime validation were executed. Review 30's completed remediations were treated as baseline and not reopened unless a distinct remaining code path demonstrated a defect. :chatgpt-content-reference{index="1"}

I excluded style, naming, documentation-only inconsistencies, missing-test-only observations, and speculative edge cases. Six findings met the substantive threshold:

| ID | Severity | Surface | Finding |
|---|---|---|---|
| **R31-F1** | **High** | React Native native | `clearSessions()` drops owning session handles without actually clearing the native handle registry |
| **R31-F2** | **Medium-High** | React Native lifecycle | Cancellation failure handling can leave other or deferred sessions running |
| **R31-F3** | **Medium** | Flutter lifecycle | Restored/history session wrappers cannot reliably dispatch native cancellation |
| **R31-F4** | **Medium** | React Native native | `knownSessionIds` grows forever despite bounded native history, producing increasing memory and lookup cost |
| **R31-F5** | **Medium** | Flutter build hook | Local artifact cache identity is basename-only, allowing distinct local artifacts to overwrite one another |
| **R31-F6** | **Medium** | React Native build/staging | Shared deterministic `.downloading` / `.extracting` paths remain cross-process race-prone |

### R31-F1 — React Native `clearSessions()` loses native handle ownership

This is the strongest Review 31 finding.

In `react-native/cpp/FFmpegKitDynamicApi.cpp:731-740`, native React Native does:

```cpp
resolve<Fn>("ffmpeg_kit_clear_sessions")();

std::lock_guard<std::mutex> lock(sessionHandlesMutex);
retainedSessionHandles.clear();
knownSessionIds.clear();
```

The comment says the core operation removes wrapper handles and cancels/drains sessions. The frozen native source shows that assumption is incorrect.

`FFmpegKit/src/ffmpegkit_wrapper.cpp:3189-3196` defines `ffmpeg_kit_clear_sessions()` as only:

```cpp
FFmpegKitConfig::clearSessions();
```

and `FFmpegKitConfig.cpp:2744-2752` merely clears the native **history list/map**.

The function that really clears the native C handle registry and cancels/drains retained sessions is the separate `ffmpeg_kit_config_clear_sessions()` at `ffmpegkit_wrapper.cpp:419-455`.

That distinction matters because `retainedSessionHandles` contains **owning C API handles**. React Native simply forgets those pointer values without invoking `ffmpeg_kit_handle_release()` and without invoking the native registry-clearing API. The corresponding `HandleRecord` remains in the native registry but React Native no longer has a pointer through which to release it.

There is a particularly realistic terminal-session path: `Session.monitor()` invokes the user's completion callback at `session.ts:600-603`, but does not release the owning handle until `:621-629`. If that completion callback calls `clearSessions()`, React Native drops the current handle from `retainedSessionHandles`; the subsequent `releaseOwnedHandle()` cannot find it. The native registry entry is then stranded.

For running sessions the consequences are worse: history disappears, React Native forgets the retained handle, but the native handle registry can keep the execution alive. This can produce an orphaned execution rather than the documented cancellation/invalidation behavior.

React Native Web does not make this mistake: `backend.web.ts:706-713` explicitly releases each Web session handle before clearing history.

**Fix:** make the native bridge's ownership semantics match its API contract. Using the already-existing `ffmpeg_kit_config_clear_sessions()` is the obvious candidate if React Native intends registry invalidation/cancel-and-drain semantics. Alternatively, explicitly release every retained handle before history clearing. It must not simply `clear()` an owning pointer map.

No native ABI change is required.

### R31-F2 — React Native cancellation can stop trying too early

There are two interacting defects.

First, `react-native/src/session-queue-manager.ts:104-107` implements:

```ts
for (const session of [...this.active]) session.cancel();
```

`Session.cancel()` can throw while reading native state or dispatching cancellation. The first exception therefore aborts `cancelCurrent()`, so later active sessions are never attempted. Public `cancelAll()` first clears queued work and then enters this fail-fast loop.

Flutter already has the correct model: its queue cancellation snapshots the active sessions, attempts every cancellation, records the first error/stack, and rethrows only after all sessions have been attempted.

Second, deferred React Native cancellation loses automatic retry authority. `session.ts:359` initializes:

```ts
let nativeCancellationFailed = false;
```

and the monitor only dispatches when `!nativeCancellationFailed`. If a queued/Created session is canceled and its first eventual Running-state native cancellation attempt throws, lines `548-551` permanently set that flag. Every later poll skips native cancellation even though the cancellation intent remains latched.

That conflicts with the method's own substantive contract at `session.ts:154-158`: dispatch failure should not erase the request so it can be delivered when Running is observed again.

The combined result is that a transient native cancellation failure can leave work running, and `cancelAllSessions()` can leave unrelated later sessions completely unattempted.

**Fix:** use all-attempts/first-error handling for queue-wide cancellation, and keep deferred cancellation retryable until native dispatch succeeds or the session reaches terminal state. Preserve the original error as the eventual error authority without using it to disable cancellation transport.

### R31-F3 — Flutter restored/history sessions take the “never submitted” cancellation path

`flutter/lib/src/session.dart:439-450` marks sessions reconstructed from native history with:

```dart
_restoredFromHandle = true;
```

but does not mark them `_submitted`.

`Session.cancel()` at `:986-1041` then performs:

```dart
if (!_submitted) {
  _cleanupCancelledBeforeStart();
  return;
}
```

before it ever examines native session state.

Consequently, a reconstructed **Running** session is treated like a newly-created Dart session that has never entered execution. Native cancellation is never dispatched.

This also affects the public ID-based route:

```dart
FFmpegKitExtended.cancelSession(id)
    -> getSession(id)?.cancel()
```

at `ffmpeg_kit_extended.dart:146-159`.

If the live Dart object remains in `CallbackManager`, lookup can reuse it and avoid the bug. But when lookup genuinely creates a `fromHandle` history/restored wrapper, a running native session does not receive cancellation.

**Fix:** restored wrappers need cancellation authority based on their native state. The pre-submission shortcut should apply only to genuinely new Dart-owned sessions, not `_restoredFromHandle` sessions. A restored Running session should dispatch native cancellation; a terminal restored session should simply return.

### R31-F4 — React Native's history mirror is unbounded while native history is bounded

`react-native/cpp/FFmpegKitDynamicApi.cpp` maintains:

```cpp
std::vector<std::int64_t> knownSessionIds;
```

Every created session executes a linear `std::find` before appending its ID. History APIs then copy and scan that entire vector, trying native lookup for each ID.

The frozen native implementation has a **default history capacity of 10** (`FFmpegKitConfig.cpp:1684`) and actively prunes terminal sessions in `deleteExpiredSessions()` at `:657-684`. Changing the history size also triggers pruning.

React Native never synchronizes `knownSessionIds` with those evictions. It is only emptied by explicit `clearSessions()`.

After `N` executions in a long-lived application:

- the native retained history can remain approximately bounded;
- `knownSessionIds` grows toward `N`;
- session creation performs an increasingly expensive linear duplicate search;
- `getSessionsJson()` and `getLastSessionJson()` repeatedly probe IDs that native history discarded long ago.

Creation therefore accumulates toward **O(N²)** work over process lifetime, with monotonically growing wrapper memory and O(N) history calls despite a bounded native history.

This is unnecessary because the frozen C API already exports native session-list/history functions such as `ffmpeg_kit_get_sessions()`.

**Fix:** consume native bounded history directly, or maintain an explicitly bounded/pruned wrapper index with constant-time membership. An indefinitely growing historical shadow should not be authoritative.

### R31-F5 — Flutter's local artifact cache still aliases different bundles with the same basename

Review 30 correctly made cache publication transactional, but local override **identity** remains weaker than remote override identity.

Remote artifacts use a URI hash:

```dart
<uri-hash>-<basename>
```

at `flutter/hook/build.dart:1515-1525`.

Local overrides at `:1685-1705` instead map solely to:

```dart
File(p.join(cacheDir.path, p.basename(localFile.path)))
```

The cache directory is shared per target platform.

Therefore:

```text
/A/bundle-base-ios-....zip
/B/bundle-base-ios-....zip
```

map to the same shared cached file if their basenames match.

The Review 30 inter-process lock serializes writes, but it cannot solve this identity collision. One invocation can finish publishing A and release its cache lock; another can replace the same pathname with B before the first invocation hashes/extracts that pathname. The first build can then consume B despite being configured for A.

This is a correctness problem, not merely stale-cache tidiness.

**Fix:** give local overrides stable source/content identities just as remote overrides have URI identities—e.g. canonical source URI/path hash, ideally coupled to content hash—so two different local sources never share the same mutable cache filename.

### R31-F6 — React Native artifact staging still has deterministic cross-process temp paths

The common downloader uses:

```js
const tempTarget = `${target}.downloading`;
fs.rmSync(tempTarget, {force: true});
```

in `react-native/scripts/download-ffmpeg-kit-artifact.js:98-113`, and `ensureArtifact()` also deletes that same deterministic temp path before operating.

Two processes downloading the same target can therefore delete or rename each other's temporary file.

Windows extraction has the same pattern in `prepare-windows-runtime.ps1:138-170`:

```powershell
$temporaryRoot = "$ExtractRoot.extracting"
if (Test-Path $temporaryRoot) {
    Remove-Item $temporaryRoot -Recurse -Force
}
```

A second build can delete the first build's active extraction directory.

Unlike R31-F5, this generally produces nondeterministic build failures rather than selecting another configured artifact, but it affects shared package/build staging across React Native targets and is substantive for parallel builds.

**Fix:** use process-unique sibling temporary paths plus atomic publication and a per-artifact lock/recheck protocol. Do not identify another process's in-progress path as “stale” solely because it exists.

## Review 31 disposition

I did **not** find a Critical-level defect that met the code-review evidence threshold, but the frozen Review 30 wrapper is **not code-review clean**.

**R31-F1 should block promotion**: it violates native handle ownership and can strand both terminal handles and active executions. **R31-F2 and R31-F3 are cancellation correctness defects** and should also be resolved before final interactive validation. R31-F4 is a real long-running-process scalability defect, while R31-F5/F6 are build correctness/concurrency defects rather than cosmetic hardening.

None of these findings requires changing the frozen native ABI. R31-F1 specifically relies on an API already present in the frozen builders source.

## Implementation handoff

Review 31 is now prepared for live wrapper implementation against the current `dev-wasm` checkout. The finding identifiers above remain review metadata; implementation names must describe the ownership, cancellation, history, cache-identity, and transactional-staging semantics being repaired.

### Remediation goals

1. Preserve native session-handle ownership when the React Native bridge clears session history.
2. Attempt every React Native cancellation target and keep deferred cancellation retryable until successful dispatch or terminal state.
3. Let restored Flutter/history sessions cancel a live native session while retaining the pre-submission fast path for genuinely new Dart sessions.
4. Replace the unbounded React Native history shadow with bounded/native-aligned history ownership.
5. Give local Flutter artifact overrides collision-free shared-cache identities based on stable source identity and content validation.
6. Replace deterministic React Native download/extraction staging paths with process-unique transactional publication and per-artifact coordination.
7. Record focused and cross-platform local evidence, freeze the exact wrapper SHA, and source-snapshot the wrapper and builders repositories.

### Required implementation constraints

- No native ABI, `libs/libffmpegkit`, or ManyLinux builder checkout changes.
- Use only the supplied local WSL artifacts and the recorded MacBook Air universal XCFramework archives; do not retrieve remotely staged prebuilt binaries.
- Do not use hosted Flutter/React Native CI for acceptance of unpublished-ABI changes.
- Run Flutter/Dart commands with analytics disabled and use elevated shells if local locking or hangs recur. Tag every spawned process, terminate confirmed task-owned orphans, and remove temporary staging directories.
- Push a meaningful commit after each completed remediation goal, then freeze the final wrapper SHA before the requested source snapshots.
