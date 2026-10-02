# Review 39 — Luna Platform-Native Flutter + React Native Remediation Plan

**Audience:** Luna implementation model  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch:** `dev-wasm`  
**Starting wrapper authority:** `0cc61d41906611f9118d8eb84a95647a7925b99d`  
**Review basis:** `review39-platform-native-code-review.md`  
**Native ABI/runtime:** `0.11.2`, frozen/read-only  
**Frozen native submodule:** `b74da2c5d1e294b87d15d73a6687393729e932b3`

---

## 1. Goal tracker

| Goal | Objective | Status |
| --- | --- | --- |
| **R39-G1** | Make Flutter Windows external-texture retirement asynchronous-lifetime-safe | **Pending** |
| **R39-G2** | Replace React Native Windows blanket fail-fast operational errors with normal caller-visible failures | **Pending** |
| **R39-G3** | Give Flutter Linux every generated GL texture a deterministic context-safe final deletion path | **Pending** |
| **R39-G4** | Run focused native regressions and affected local Windows → Android → Linux → Apple validation with existing frozen artifacts only | **Pending** |
| **R39-G5** | Reconcile evidence, freeze exact wrapper SHA, and create one wrapper-only source snapshot | **Pending** |

---

## 2. Hard constraints

Luna must treat every item below as mandatory.

1. Work only in `akashskypatel/ffmpeg-kit-extended`.
2. Work on `dev-wasm`.
3. Start from or explicitly reconcile against `0cc61d41906611f9118d8eb84a95647a7925b99d`.
4. Keep `libs/libffmpegkit` frozen/read-only at `b74da2c5d1e294b87d15d73a6687393729e932b3`.
5. Native runtime remains pinned to existing local `0.11.2` artifacts.
6. Do not download/re-review another native/builders source snapshot.
7. Do not modify FFmpegKit native ABI source.
8. Do not modify the ManyLinux builder checkout.
9. Do not rebuild or publish a replacement native ABI.
10. Do not fetch a remote/published old native bundle for validation.
11. Do not use hosted Flutter/React Native build/test workflows as acceptance evidence.
12. The only permitted hosted workflow at closeout is the wrapper source-snapshot workflow.
13. Do not launch or operate interactive Flutter/React Native applications.
14. Do not infer simulator/device runtime behavior from build success.
15. Final interactive runtime validation remains user-owned.
16. Production identifiers must be semantic; do not put review/goal identifiers into implementation names.
17. Tests must be real executable oracles when behavior is testable.
18. Do not replace behavioral coverage with source-text regex assertions.
19. Never fabricate test output or weaken a valid production scenario.
20. Record failed commands, retries, environment corrections, and implementation mistakes truthfully.
21. Preserve the primary operation error over later cleanup errors.
22. If the primary operation succeeded and cleanup fails materially, do not silently claim success.
23. Run Flutter/Dart with analytics disabled.
24. Observe and clean task-owned Flutter/Dart/Node/PowerShell/WSL/compiler/Xcode/Gradle/SSH processes.
25. Clean task-owned staging/output before final freeze.
26. Commit meaningful goals separately where practical.
27. Do not reopen accepted Review 23–38 dispositions without direct contradictory evidence.
28. Preserve latest-successful FFplay owner semantics from prior reviews.
29. Preserve accepted log-bridge retirement semantics unless G2 necessarily changes only its error transport.

---

## 3. Preparation

Before editing:

```text
git rev-parse HEAD
git rev-parse origin/dev-wasm
git status --short
git ls-tree HEAD libs/libffmpegkit
```

Confirm:

```text
wrapper contains/descends from:
0cc61d41906611f9118d8eb84a95647a7925b99d

native gitlink:
b74da2c5d1e294b87d15d73a6687393729e932b3
```

Read:

```text
review39-platform-native-code-review.md
this plan
.agent/TRACKER.md
```

If live `dev-wasm` contains later commits, reconcile rather than overwrite.

Primary files:

```text
G1:
  flutter/windows/ffmpeg_kit_extended_flutter_plugin.cpp
  flutter/windows/ffmpeg_kit_extended_flutter_plugin.h
  flutter/native/texture_registration_transaction.h
  flutter/native/ffplay_owner_coordinator.h

G2:
  react-native/windows/FFmpegKitExtended/FFmpegKitExtended.cpp
  react-native/windows/FFmpegKitExtended/FFmpegKitExtended.h
  react-native/src/NativeFFmpegKitExtended.ts
  react-native/src/platform/backend.native.ts
  react-native/src/session.ts
  react-native/cpp/FFmpegKitDynamicApi.cpp/.h
  react-native/cpp/FFmpegKitExtendedImpl.cpp/.h

G3:
  flutter/linux/ffmpeg_kit_extended_flutter_plugin.cc
  flutter/native/frame_notification_coalescer.h
  flutter/native/texture_registration_transaction.h
  flutter/native/ffplay_owner_coordinator.h
```

Do not assume every listed file must change.

---

# 4. R39-G1 — Flutter Windows asynchronous external-texture retirement

## Objective

A registered Windows external texture's `TextureVariant` and callback-captured state must remain physically alive until Flutter confirms unregister completion.

This must apply to:

```text
explicit release
replacement
FFplay owner-install rollback
plugin destruction
```

## Current topology

```text
Plugin
  -> unique_ptr<TextureState>
       -> unique_ptr<TextureVariant>
            -> PixelBufferTexture callback
                 -> raw TextureState*
```

Flutter receives a pointer inside the `TextureVariant` as external-texture callback `user_data`.

Current release uses the deprecated bool `UnregisterTexture(texture_id)` and immediately destroys the state.

That is invalid because Flutter's unregister contract is asynchronous.

## Required model

Separate:

```text
logical detach
physical retirement
```

### Logical detach

Immediately:

```text
remove current texture from plugin-visible ownership
stop FFplay producer if this exact state is current owner
drain producer callback mutex
mark TextureState non-producing/destroyed
clear mutable frame state as appropriate
```

### Physical retirement

Then:

```text
TextureRegistrar::UnregisterTexture(id, completion)
keep TextureVariant + TextureState alive
wait for completion
destroy retirement state exactly once
```

## Lifetime owner

Create a semantic helper such as:

```text
RegisteredTextureLifetime
ExternalTextureRegistration
RetiringExternalTexture
```

Do not use review IDs in names.

Possible ownership:

```cpp
struct RegisteredTextureLifetime {
  std::unique_ptr<TextureState> state;
  int64_t texture_id;
};
```

A `shared_ptr` can be used for completion ownership if state transitions remain explicit.

The invariant is more important than the exact type:

```text
physical lifetime >= unregister completion
```

## Do not capture plugin `this`

The unregister completion may occur after plugin destruction.

The completion-owned retirement state must not require the plugin object.

If the registrar lifetime itself has shutdown constraints, inspect Flutter's exact plugin registrar lifecycle and implement a shutdown-specific safe path. Do not guess.

## Pending unregister callback behavior

Flutter may still request the external texture while unregister is pending.

`CopyPixelBuffer()` must therefore see valid state.

If `destroyed == true`, define a safe callback result during retirement; do not access freed memory.

## Immediate completion

The registrar may invoke completion synchronously.

Design so this is safe:

```text
UnregisterTexture(...)
  -> callback fires before call returns
```

No double destruction and no use of the retired object after callback.

## Rollback

Replace the current rollback:

```cpp
texture_registrar_->UnregisterTexture(texture_id);
```

with the same lifetime-safe retirement path.

Sequence:

```text
Flutter texture registered
FFplay owner install fails
async unregister requested
state remains alive until completion
method reports FFPLAY_OWNER failure
```

## Replacement

If a new texture can be registered while an old retirement is pending, each retirement needs independent ownership.

Do not use one mutable retirement slot that can be overwritten.

Test both completion orders.

## Plugin destructor

Required behavior:

```text
plugin destructor starts
current texture logically detached
unregister requested
plugin object can be destroyed
retirement object survives independently
unregister completion destroys state
```

## Preserve producer lifetime barrier

Do not regress:

```text
g_ffplay_owner.uninstallIfOwned(...)
ffplay_kit_unregister_frame_callback()
mutex drain
```

The producer callback and Flutter raster callback are separate lifetime barriers.

Both must be closed.

## Behavioral test seam

Create a fake/controllable registrar.

It must be able to:

```text
register TextureVariant
record external texture object
accept UnregisterTexture(id, callback)
defer callback
invoke PixelBufferTexture copy callback while unregister pending
complete unregister later
```

Required cases:

### Explicit release

```text
register
release
unregister pending
state/variant alive
Flutter copy callback safe
complete
destroy exactly once
```

### Rollback

```text
registration succeeds
owner installation fails
unregister pending
state alive
complete
destroy once
```

### Plugin destruction

```text
register
destroy plugin
unregister pending
retirement state survives
complete
destroy
```

### Overlap

If supported:

```text
A release pending
register B
B release pending
complete B then A
repeat A then B
```

No cross-destruction.

## Focused G1 acceptance

Run locally:

```text
new Windows retirement behavior oracle
existing texture registration transaction oracle
existing FFplay owner coordinator oracle
Windows plugin native compile/syntax gate
Flutter Windows example build
```

Use the existing local Windows `0.11.2` artifact only.

No interactive execution.

## G1 exit

There must be no path that destroys an engine-registered `TextureVariant` or its callback state before unregister completion.

---

# 5. R39-G2 — React Native Windows recoverable error transport

## Objective

Recoverable exceptions from the shared adapter must become normal caller-visible errors on Windows, not `RaiseFailFastException`/`std::terminate()`.

The Windows native boundary must remain `noexcept`.

## First step: method inventory

Before coding, build a working table for every Windows native method:

```text
method
current REACT_METHOD / REACT_SYNC_METHOD shape
TypeScript type
can shared adapter throw?
can zero/false/empty be a valid result?
high-level wrapper sync or async?
selected error transport
```

At minimum include:

```text
initialize
createFFmpegSession
createFFmpegSessionFromArguments
createFFprobeSession
createFFplaySession
createFFplaySessionFromArguments
createMediaInformationSession
createMediaInformationSessionFromPath
executeSessionAsync
cancelSession
installLogBridge
uninstallLogBridge
getSessionJson
getSessionState
getLogsCount
releaseSessionHandle
abandonCreatedSession
getSessionsJson
getLastSessionJson
getLogsJson
getStatisticsJson
getMediaInformationJson
all FFplay controls/getters
setSessionHistorySize
clearSessions
debug-log methods
version/build/config getters
```

## Error taxonomy

### Recoverable operational errors

Examples:

```text
DLL not found
symbol not found
invalid argument list
native session create failure
session ID absent
wrong session kind for FFplay
runtime/session state lookup failure
```

These must not kill the host.

### True invariant corruption

Keep fail-fast only if continuation is genuinely unsafe due to internal corruption.

Do not classify runtime availability, user input, or missing sessions as corruption.

## Noexcept boundary rule

Do not remove `noexcept`.

Implement:

```text
catch adapter exception
translate to RNW supported error/result
return through native boundary
```

Never let C++ exceptions escape.

## Transport selection

Inspect the exact RNW/codegen version used by this repository before modifying the shared spec.

### Prefer Promise rejection

For operations already asynchronous at the wrapper level and where generated RNW contract supports it.

### Prefer explicit structured result

For synchronous operations where a value can be validly `0`, `false`, or `""`.

Example shape if supported:

```text
{ok: true, value: ...}
{ok: false, error: ...}
```

### Use sentinel only if existing contract is unambiguous

Do not invent generic zero/false/empty error sentinels.

## Public API stability

Do not silently change a public synchronous API to asynchronous unless necessary and accurately documented.

If internal Windows native transport becomes asynchronous, determine whether high-level semantics can honestly remain synchronous.

Correctness has priority over pretending async failure is sync.

## Review 38 cancellation compatibility

This exact sequence must work without process death:

```text
record ID-scoped cancellation intent
getSessionState fails
caller receives ordinary error
process survives
cancellation intent remains fail-closed
```

Add a focused regression.

## Log bridge

Preserve Review 25/26 lifetime behavior.

If installation fails because runtime/symbol is unavailable:

```text
ownership state rolls back
caller receives error
process survives
```

Destructor stays nonthrowing and may preserve callback state on uninstall failure as already accepted.

## Injectable adapter seam

Do not corrupt the real local DLL to test errors.

Inject deterministic adapter failures at the Windows native-module boundary.

Required failures:

```text
initialize/runtime unavailable
required symbol unavailable
invalid create arguments
session creation failure
session not found
wrong FFplay target
```

For each:

```text
native method returns through noexcept boundary
host process remains alive
caller sees meaningful error
```

Verify normal successful values remain unchanged.

## Anti-fail-fast companion oracle

Add a focused source/native contract check rejecting blanket normal-operation dispatch through:

```text
RaiseFailFastException
std::terminate
```

This is supplemental only.

## If shared spec changes

Run:

```text
npm run typecheck
npm run test:compile
React Native codegen
shared C++ syntax/compile
Windows native build
Android native build
iOS build
tvOS build if shared generated interface is affected
macOS build
package type consumer
```

Use local artifacts only.

## G2 exit

No recoverable shared-adapter exception may terminate the React Native Windows application process.

---

# 6. R39-G3 — Flutter Linux final GL resource ownership

## Objective

Every GL texture name created by the Linux FFplay texture path must be deleted exactly once through a context-safe lifecycle.

This includes final plugin/engine teardown where no later `populate()` occurs.

## Existing resource topology

```text
FfkitGlTexture GObject
  -> TextureState*
       -> GLuint gl_texture_id
       -> gl_initialized
       -> needs_gl_reset
```

`populate()`:

```text
first use -> glGenTextures
reset/reuse -> glDeleteTextures(old), glGenTextures(new)
```

The release/reuse path can therefore retire old resources.

Final teardown cannot.

## Do not blindly delete in finalizer

The current GL work occurs inside Flutter's render-context callback.

Do not add `glDeleteTextures()` to arbitrary GObject finalization unless the exact current-context guarantee is proven.

## Option A — prefer `FlPixelBufferTexture` if compatible

Evaluate this first.

The producer already supplies CPU RGBA.

Flutter's standard `FlPixelBufferTexture` owns its GL name lifecycle and explicitly deletes its generated texture in dispose.

Check:

```text
pixel format/alpha
width/height
copy buffer lifetime
mutex/synchronization
frame-available integration
performance
Impeller/OpenGL compatibility for supported Linux target
```

If acceptable, migrate and remove custom raw GL ownership.

Preserve `FrameNotificationCoalescer`.

## Option B — custom `FlTextureGL` with context-safe retirement

If custom GL is required, implement an explicit retirement boundary with a valid current Flutter GL context.

Required invariant:

```text
last generated GLuint deleted exactly once
before TextureState physical destruction
```

Do not invent engine callbacks.

Use supported embedder APIs only.

## Keep public release/reuse semantics

Current release intentionally keeps Flutter registration for reuse:

```text
releaseTexture
-> stop producer
-> destroyed=true
-> needs_gl_reset=true
-> keep registration
```

On a later `populate`:

```text
delete old GL name
create new GL name
```

Preserve this if still beneficial.

Final plugin disposal is different:

```text
no future reuse
-> final GL retirement
-> unregister Flutter texture
-> GObject/state destruction after resource closed
```

## Idle callback safety

Preserve:

```text
g_object_ref(texture) for queued idle callback
idle callback checks destroyed
g_object_unref(texture)
```

Do not move/destroy `TextureState` before an outstanding callback-held GObject reference can safely run.

## GL operation seam

Add only a minimal test seam:

```text
generateTexture()
deleteTexture(id)
```

plus any operations needed to prove lifecycle.

Do not abstract the entire renderer.

## Required tests

### First populate

```text
gen=1
delete=0
```

### Release/reuse

```text
A generated
release marks reset
next populate deletes A once
generates B once
```

### Final disposal

```text
A generated
final plugin disposal
A deleted once
state destroyed
```

### Reuse then final

```text
A generated
reuse deletes A, creates B
final delete B
total generated == total deleted
```

### Never populated

```text
no glDeleteTextures(0)
```

### Queued idle callback

```text
temporary GObject ref survives plugin dispose transition
idle callback safely sees destroyed state
resource retirement remains once-only
```

## Context proof

Record why production deletion executes with a valid GL context.

If `FlPixelBufferTexture` is selected, document that the standard Flutter implementation owns its GL texture creation/deletion, so this plugin no longer owns the raw `GLuint`.

## G3 focused acceptance

Run:

```text
GL lifecycle behavior oracle
FrameNotificationCoalescer regression
texture registration transaction regression
Linux plugin native compile
Flutter Linux local build
```

Use existing local Linux `0.11.2` artifact.

No interactive app.

## G3 exit

For retired Linux texture lifecycles:

```text
number of generated GL texture names == number deleted
```

with no double delete and no unsafe-context GL call.

---

# 7. R39-G4 — Focused regressions and local platform matrix

Do not start broad builds until G1–G3 focused tests pass.

This review is platform-native. Wasm/Web is not a primary acceptance target unless a shared RN TypeScript/native spec change requires package/type compatibility.

## Flutter focused

Disable analytics:

```text
flutter config --no-analytics
dart --disable-analytics
```

Run existing helpers plus new G1/G3 tests covering:

```text
FFplay owner coordinator
texture registration transaction
Windows external texture lifetime
Linux frame notification coalescing
Linux GL texture lifetime
Android surface owner coordinator
Apple callback/source parity where relevant
```

## React Native focused

Run:

```text
npm run typecheck
npm run test:compile
npm run lint
```

Then native tests for:

```text
Windows native error boundary
native bridge lifetime
FFplay native lifecycle
log registration coordinator
Review 38 session-state cancellation error path
```

If G2 changes codegen/shared native spec, run required generation and shared platform compile gates.

---

# 8. Ordered local build order

Use only existing local artifacts.

## Windows first

Primary platform for G1/G2.

Flutter:

```text
Windows native behavior tests
Flutter Windows example build
```

React Native:

```text
Windows native error tests
./build.sh windows
```

Verify expected executable/module output.

## Android on Windows

Required if G2 changes shared RN spec/Cxx/codegen.

Use installed Windows Android toolchain and established local AAR.

Do not substitute WSL Android.

If G2 remains Windows-only and shared interface is unchanged, a narrower Android shared native compile/package gate is acceptable.

## Linux under WSL

Primary platform for G3.

Use existing local Linux archive.

Run:

```text
new GL lifetime oracle
existing Linux native helper regressions
Flutter Linux build
```

No interactive app.

## Shared package compatibility

If `NativeFFmpegKitExtended.ts` changes:

```text
test:pack-types
type consumer
other compile-only package compatibility gates
```

This is not a Web runtime acceptance review.

## Apple last

Only after Windows/Android/Linux are green.

If G2 changes shared RN spec/codegen:

```text
React Native iOS build
React Native tvOS build
React Native macOS build
```

using existing local XCFramework archives.

If Flutter common native helpers change, run affected macOS/iOS builds.

No interactive simulator/device execution.

---

# 9. Error authority

For all goals:

```text
primary operation fails
cleanup also fails
-> preserve primary
-> record secondary

primary operation succeeds
material cleanup fails
-> surface cleanup failure where contract supports it
-> do not falsely report clean success
```

For G1 async unregister completion, determine what late diagnostics can truthfully be delivered after the Dart method has already returned.

Do not invent a late Dart exception if there is no valid delivery channel.

---

# 10. Validation truthfulness

For every command recorded:

- record exact command;
- record actual exit/result;
- record actual test counts;
- distinguish diagnostic attempts from acceptance evidence;
- do not call a timeout/killed command a pass;
- prove environment classifications;
- do not relabel product failures as environment issues;
- disclose wrong directory/toolchain invocations and correct them.

No fake tests.

No source-regex-only substitute for the main G1/G2/G3 behavioral oracles.

---

# 11. R39-G5 — Evidence reconciliation and exact source freeze

After implementation and local validation:

1. Re-read all changed production files.
2. Verify semantic implementation names.
3. Verify `libs/libffmpegkit` remains `b74da2c5d1e294b87d15d73a6687393729e932b3`.
4. Verify builder checkout untouched.
5. Verify local artifact overrides unchanged/current.
6. Clean task-owned generated/staging output.
7. Record implementation commits and evidence in `.agent/TRACKER.md`.
8. Verify clean worktree except intended tracker/review metadata.
9. Push final wrapper implementation to `origin/dev-wasm`.
10. Record exact final wrapper SHA/tree.
11. Dispatch exactly one wrapper source snapshot workflow.
12. Do not dispatch hosted wrapper test/build CI.
13. Do not create/download a builders/native snapshot.

Verify:

```text
workflow head SHA == final wrapper SHA
snapshot-metadata.snapshot_sha == final wrapper SHA
outer artifact digest matches connector
source.tar.gz hash matches recorded digest
all SHA256SUMS entries verify
SUBMODULES.txt contains exact frozen native gitlink
SYMLINKS.tsv matches metadata
runtimeExecution == false
```

Record:

```text
workflow run ID
artifact name
artifact ID
artifact digest
embedded source hash
manifest count
symlink count
submodule SHA
runtimeExecution
```

Then stop automated work.

---

# 12. Hard execution order

```text
R39-G1 Windows async texture retirement
-> deferred-unregister behavioral oracle
-> Flutter Windows build
-> commit/push

R39-G2 Windows recoverable error transport
-> exact RNW method/error-channel inventory
-> implementation
-> injected failure behavior oracles
-> shared type/codegen gates
-> RN Windows build
-> commit/push

R39-G3 Linux final GL retirement
-> choose FlPixelBufferTexture or proven context-safe custom retirement
-> GL lifecycle oracle
-> Flutter Linux build
-> commit/push

-> combined focused native regressions
-> R39-G4 Windows
-> Android if affected
-> Linux
-> shared package compile if needed
-> Apple last if affected

-> R39-G5 tracker/evidence
-> exact wrapper freeze
-> one wrapper source snapshot
-> verify
-> STOP
-> user-owned final interactive runtime validation
```

---

# 13. Luna closeout checklist

Before G1 complete:

```text
[ ] live paths use async unregister completion
[ ] TextureVariant survives until completion
[ ] TextureState survives until completion
[ ] completion does not depend on plugin `this`
[ ] explicit release covered
[ ] replacement covered
[ ] rollback covered
[ ] plugin destruction covered
[ ] immediate callback safe
[ ] deferred callback safe
[ ] overlapping retirement safe if supported
[ ] FFplay producer drain preserved
```

Before G2 complete:

```text
[ ] blanket operational RaiseFailFastException removed
[ ] blanket operational std::terminate removed
[ ] native boundary remains noexcept
[ ] runtime-missing error caller-visible
[ ] symbol-missing error caller-visible
[ ] invalid-argument error caller-visible
[ ] missing-session state error caller-visible
[ ] invalid FFplay target caller-visible
[ ] Review 38 cancellation error path survives on Windows
[ ] valid zero/false/empty results are not confused with failures
[ ] public sync/async contract is honest
[ ] shared generated platforms compile if spec changed
```

Before G3 complete:

```text
[ ] every generated GLuint has a deletion owner
[ ] final plugin disposal retires final GL resource
[ ] release/reuse still deletes old texture once
[ ] no delete of texture 0
[ ] no double delete
[ ] production GL context validity is proven
[ ] queued idle GObject refs remain safe
[ ] FrameNotificationCoalescer remains intact
```

Before final freeze:

```text
[ ] focused behavior tests pass
[ ] Windows local gates pass
[ ] Android shared-code gate passes if applicable
[ ] Linux local gates pass
[ ] Apple last gates pass if applicable
[ ] no remote old binary
[ ] no hosted acceptance CI
[ ] no native ABI publication
[ ] no native/builders mutation
[ ] native gitlink unchanged
[ ] task-owned processes/output cleaned
[ ] exact wrapper SHA pushed
[ ] one wrapper source snapshot verified
```

---

# 14. Final Luna handoff

Review 39 has three platform-native invariants.

**Flutter Windows:** engine-visible external-texture callback state must outlive asynchronous unregister completion.

**React Native Windows:** recoverable wrapper/runtime failures must remain caller-visible application errors; the native boundary stays `noexcept`, but ordinary adapter exceptions cannot terminate the host process.

**Flutter Linux:** every raw GL texture name created by the wrapper must have a deterministic exactly-once deletion path on a valid GL context, including the final lifecycle where no later `populate()` occurs.

Implement those invariants without touching the frozen native ABI, prove them with real native behavioral oracles, validate only against existing local `0.11.2` artifacts, and freeze/snapshot only the wrapper source.
