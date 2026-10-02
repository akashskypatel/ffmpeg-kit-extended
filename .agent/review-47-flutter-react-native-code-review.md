# Review 47 — Flutter + React Native Cross-Platform Code Review

Date: 2026-10-02  
Repository: `akashskypatel/ffmpeg-kit-extended`  
Branch represented by the reviewed snapshot: `dev-wasm`  
Review type: frozen-source, substantive findings only

## Authority and disposition

The reviewed wrapper source is the exact Review 46 closeout SHA:

`a0d38c9374091174cb560651e6a36d62378ada2b`

The recorded wrapper-only source snapshot is workflow `37071751090`, artifact
`review46-final-source-snapshot-37071751090`, artifact ID `11253859692`.
Its independently recorded evidence is:

- outer artifact SHA-256: `ef6fe740716daa55279ca5152da53153d76d9d2758305d25d1fa957135053499`
- embedded `source.tar.gz` SHA-256: `428fcb53e9ab051f8d7070055c921f10e48da1b1abaf32184ddfff959379191e`
- manifest: `1111/1111` entries verified
- symlinks: `0`
- `runtimeExecution`: `false`
- recursive `libs/libffmpegkit`: `b74da2c5d1e294b87d15d73a6687393729e932b3`

Native ABI/runtime `0.11.2` was frozen and was not downloaded, rebuilt, or
re-reviewed. Review 47 itself performed no tests, builds, runtime execution,
interactive validation, hosted acceptance workflow, or repository mutation.

Disposition: the platform-native bridge remains closed and the audited Flutter
wrapper surfaces remain closed. React Native has two reachable wrapper-lifecycle
defects that require surgical TypeScript/test/documentation changes.

## Findings

### R47-F1 — configuration clear bypasses wrapper lifecycle cleanup

`react-native/src/ffmpeg-kit-config.ts` exposes a public
`FFmpegKitConfig.clearSessions()` that calls `NativeFFmpegKitExtended.clearSessions()`
directly. `FFmpegKitExtended.clearSessions()` is the lifecycle-aware authority:
it commits the backend clear first, invalidates restored-session observation and
callback demand, and clears cancellation-dispatch bookkeeping after a successful
backend transaction.

The public configuration alias therefore resolves after native history has been
cleared while JavaScript can still retain restored observer entries, callback
targets, direct-log subscriptions, callback demand, or per-ID cancellation
dispatch state. This is a concrete reachable resource/lifetime defect, not API
duplication: both public methods promise the same session-clear semantics.

Required correction: import `FFmpegKitExtended` and delegate the configuration
method to `FFmpegKitExtended.clearSessions()`. Do not duplicate cleanup logic in
the configuration facade. Backend failure must still reject before wrapper state
is invalidated.

### R47-F2 — callback rollback can resurrect a cleared observer

`react-native/src/session-observation.ts` currently allows both
`ensureObserved()` and `attachCallbackTarget()` to call the entry-creation path.
That makes a clear/setup interleaving reachable:

1. a Running restored wrapper has an ID-level observer and a pre-existing
   completion sink;
2. an optional log/statistics bridge install is held in flight;
3. a successful clear removes and invalidates the coordinator entry;
4. the bridge install resumes and post-install state validation fails;
5. callback rollback synchronizes the still-live completion sink;
6. `attachCallbackTarget()` creates a new entry for the already-cleared ID;
7. queued wrapper invalidation detaches its target, leaving a zero-target polling
   observer behind.

The corrected authority split is:

- `ensureObserved(sessionId)` may create the ID-level lifetime observer;
- `attachCallbackTarget(sessionId, target)` may attach only to an existing,
  non-invalidated entry and must not create one;
- detach never creates an entry and clear removal cannot be undone by rollback.

Do not restore a process-lifetime set of every cleared ID. Existing lifecycle
bookkeeping is intentionally bounded to live/in-flight state.

## Required regression coverage

Add deterministic tests with direct entry, target, demand, and subscription
oracles. Timing or process RSS is not proof of cleanup.

- configuration clear with a restored Running observer and completion sink leaves
  backend clear count one, observer count zero, target count zero, and callback
  demand/subscriptions at baseline;
- configuration and extended clear facades have identical success and backend
  failure semantics;
- backend clear failure propagates the sentinel error and does not falsely
  invalidate pre-clear observer/cancellation state;
- a pre-existing completion sink plus deferred log/statistics install plus clear
  rejects the setter after clear and leaves no recreated observer through either
  public facade;
- ordinary attachment to an existing Running observer still attaches and later
  detaches without removing the ID-level lifetime observer prematurely;
- clearing an ID-level observer with no callback targets removes the observer;
- existing cancellation, release, preflight, bounded-target, and terminal-error
  regressions from the preceding reviews remain green.

Use semantic test names such as:

- `configuration clear invalidates restored observer state`
- `configuration and lifecycle clear share cleanup semantics`
- `clear during callback rollback does not recreate observation`
- `callback target attachment requires a live ID observer`

Do not use review, goal, or finding identifiers in production/test names.

## Audited clean boundaries

No new defect was established in Flutter production code, Flutter platform-native
code, React Native shared C++, React Native platform-native directories, queue
admission, cancellation/retry, retained release, Web history pointer ownership,
or native ABI exports. Do not broaden the implementation into those areas unless
new evidence proves one of these two TypeScript boundary fixes insufficient.

The implementation must not edit `libs/libffmpegkit`, the ManyLinux builders
checkout, native ABI configuration/publication, or hosted Flutter/React Native
test workflows. Interactive apps, simulators, devices, and Web UI are outside
this review evidence.
