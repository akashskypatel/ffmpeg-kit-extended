# Review 40 — Luna Platform-Native Bridge Closure Remediation Plan

**Audience:** Luna implementation model  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch:** `dev-wasm`  
**Starting wrapper authority:** `8725426e55baac78ad8ba8f45dfd6a0bfc0cc2b8`  
**Review basis:** `review40-platform-native-bridge-closure-review.md`  
**Native ABI/runtime:** `0.11.2`, frozen/read-only  
**Frozen native submodule:** `b74da2c5d1e294b87d15d73a6687393729e932b3`

---

## 1. Goal tracker

| Goal | Objective | Status |
| --- | --- | --- |
| **R40-G1** | Give every failure-bearing React Native Windows asynchronous native method invocation-bound error completion instead of the Review 39 thread-local post-call channel | **Pending** |
| **R40-G2** | Make shared React Native handle cleanup non-throwing by construction and retained-handle release failure-atomic across Windows/Android/Apple | **Pending** |
| **R40-G3** | Canonicalize Flutter Windows/Linux FFplay desktop frames to tightly packed RGBA8888 for all supported packed layouts | **Pending** |
| **R40-G4** | Run focused native bridge regressions and the affected local Windows → Android → Linux → Apple matrix using existing frozen artifacts only | **Pending** |
| **R40-G5** | Perform one final platform-native bridge audit, reconcile evidence, freeze exact wrapper SHA, and create one wrapper-only source snapshot | **Pending** |

---

# 2. Mission

Review 40 is intended to **close the platform-native bridge layer**.

Do not broaden the work into another application-layer redesign.

The implementation should finish three remaining contracts:

1. **Windows React Native errors belong to the invocation that produced them.**
2. **Shared C++ native-handle cleanup cannot throw from RAII/noexcept paths.**
3. **Flutter desktop pixel-buffer bridges hand Flutter canonical RGBA bytes.**

After implementing those contracts, Luna must run a final static/native bridge
audit across every platform-native source and close the review if no additional
substantive gap is found.

---

# 3. Hard operating constraints

Treat every item as mandatory.

1. Work only in `akashskypatel/ffmpeg-kit-extended`.
2. Work on `dev-wasm`.
3. Start from or explicitly reconcile against:
   `8725426e55baac78ad8ba8f45dfd6a0bfc0cc2b8`.
4. Keep `libs/libffmpegkit` frozen/read-only at:
   `b74da2c5d1e294b87d15d73a6687393729e932b3`.
5. Keep native runtime artifact authority pinned to existing local `0.11.2`
   artifacts.
6. Do **not** download or re-review a native/builders source snapshot.
7. Do **not** edit FFmpegKit native ABI source.
8. Do **not** edit the ManyLinux builder checkout.
9. Do **not** rebuild or publish a replacement native ABI.
10. Do **not** fetch a remote/published old native bundle.
11. Do **not** use hosted Flutter/React Native build/test workflows as
    acceptance evidence.
12. The only hosted workflow allowed at closeout is the repository source
    snapshot.
13. Do **not** launch or operate interactive Flutter/React Native applications.
14. Do **not** infer simulator/device runtime correctness from compilation.
15. Final interactive runtime validation remains user-owned.
16. Implementation identifiers must be semantic. Review/goal/finding names are
    tracker metadata only.
17. Tests must be genuine executable oracles where the failure is executable.
18. Source regex/source-contract checks may supplement but never replace a
    behavior test for G1/G2/G3.
19. Never fabricate a test, result, command, or platform outcome.
20. Never weaken a valid scenario merely to make a gate green.
21. Record mistakes, false starts, wrong commands, retries, environment fixes,
    and partial evidence explicitly.
22. Preserve the primary operation error over cleanup errors.
23. If the primary operation succeeded and a material cleanup step fails, do
    not falsely report clean success.
24. Run Flutter/Dart with analytics disabled.
25. Tag and observe task-owned Flutter/Dart/Node/PowerShell/WSL/compiler/
    Xcode/Gradle/SSH processes.
26. Terminate only confirmed task-owned hangs/orphans.
27. Clean task-owned generated/staging output before freeze.
28. Commit meaningful completed goals separately where practical.
29. Preserve Review 39's Flutter Windows async texture retirement.
30. Preserve Review 39's Flutter Linux `FlPixelBufferTexture` resource
    ownership.
31. Preserve accepted latest-successful FFplay owner semantics across all
    platforms.
32. Preserve the accepted log-bridge retirement design unless G1/G2 directly
    require only error/cleanup safety changes.
33. Do not reopen Review 23–39 dispositions without direct contradictory source
    or executable evidence.

---

# 4. Preparation

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
8725426e55baac78ad8ba8f45dfd6a0bfc0cc2b8

native gitlink:
b74da2c5d1e294b87d15d73a6687393729e932b3
```

Read:

```text
review40-platform-native-bridge-closure-review.md
this plan
.agent/TRACKER.md
```

If live `dev-wasm` contains later commits:

```text
inspect
reconcile
preserve newer work
```

Do not overwrite it silently.

Primary implementation surfaces:

```text
R40-G1:
  react-native/src/NativeFFmpegKitExtended.ts
  react-native/src/platform/backend.native.ts
  react-native/windows/FFmpegKitExtended/FFmpegKitExtended.h
  react-native/windows/FFmpegKitExtended/FFmpegKitExtended.cpp
  react-native/windows/FFmpegKitExtended/operational_error_transport.h
  react-native/windows/FFmpegKitExtended/recoverable_native_dispatch.h
  react-native/cpp/FFmpegKitExtendedImpl.h/.cpp if shared codegen changes
  generated RNW/Cxx code only as produced by the repository's codegen flow

R40-G2:
  react-native/cpp/FFmpegKitDynamicApi.cpp
  react-native/cpp/FFmpegKitDynamicApi.h
  native test seams adjacent to shared bridge

R40-G3:
  flutter/windows/ffmpeg_kit_extended_flutter_plugin.cpp
  flutter/linux/ffmpeg_kit_extended_flutter_plugin.cc
  flutter/native/ new semantic packed-frame helper
  focused native tests
```

Do not assume every file listed must change.

---

# 5. R40-G1 — Invocation-bound React Native Windows error transport

## 5.1 Objective

For every Windows native operation whose failure matters to the wrapper:

```text
one JS/native invocation
-> one native completion
-> one success OR one error for that invocation
```

No operation may rely on a separate cross-call "last error" read.

## 5.2 Current invalid shape

Current native method:

```text
REACT_METHOD(cancelSession)
void cancelSession(...) noexcept
```

Current implementation:

```text
catch adapter exception
-> record thread_local lastOperationalError
-> native method returns
```

Current JS:

```text
Reflect.apply(cancelSession)
-> consumeLastError()
```

RNW classifies `REACT_METHOD` as asynchronous.

Therefore the JS read is not a valid completion boundary.

## 5.3 First implementation task: method contract inventory

Before modifying code, create a temporary engineering table covering every
native method.

Columns:

```text
native method name
TS return type
Windows macro: REACT_METHOD / REACT_SYNC_METHOD
high-level wrapper return type
can shared adapter throw?
does caller currently depend on a thrown error?
is operation logically action or getter?
selected new error/completion transport
does shared Cxx codegen change?
```

At minimum classify:

```text
initialize

executeSessionAsync
cancelSession
installLogBridge
uninstallLogBridge
releaseSessionHandle
abandonCreatedSession

ffplayStart
ffplayPause
ffplayResume
ffplayStop
ffplaySeek
ffplaySetPosition
ffplaySetVolume

enableRedirection
disableRedirection
setLogLevel
setFontDirectory
setEnvironmentVariable
ignoreSignal
setAudioOutputDevice

setSessionHistorySize
clearSessions
closeFFmpegPipe

enableDebugLog
disableDebugLog
clearDebugLog
```

Also inventory all `REACT_SYNC_METHOD` getters/creators so G1 does not
accidentally destabilize their valid synchronous transport.

## 5.4 Decision gate: choose supported invocation-completion transport

Use the repository's exact RN 0.81.6 / RNW 0.81.32 codegen to confirm the
generated signatures.

Preferred rule:

### Failure-bearing action

Use a completion-bearing method:

```text
Promise<void>
or exact RNW supported callback/promise result
```

Windows implementation:

```text
REACT_METHOD
-> receives ReactPromise<void> / generated completion object
-> try native operation
-> Resolve on success
-> Reject with method-qualified message on failure
```

This is the preferred design for:

```text
initialize
cancelSession
releaseSessionHandle
clearSessions
FFplay controls
log bridge install/uninstall
other actions whose caller needs error authority
```

### Truly fire-and-forget action

If a method's public contract genuinely does not surface errors:

```text
document that semantic internally
remove the fake consumeLastError expectation
do not keep hidden stale errors
```

Be conservative: most lifecycle/configuration operations in this project have
historically preserved errors, so do not downgrade them without explicit
evidence.

## 5.5 Do not solve G1 by making everything synchronous

Do not convert `REACT_METHOD` to `REACT_SYNC_METHOD` solely to preserve
`consumeLastError`.

Reasons:

```text
changes RNW scheduling semantics
may block JS/native call path
can violate generated ModuleSpec
does not provide the intended async completion contract
```

If a particular method should truly be synchronous, make that a deliberate
cross-platform API decision supported by generated code and public semantics,
not a workaround.

## 5.6 Shared TypeScript/codegen migration

If the TS spec changes:

```text
initialize(): Promise<void>
cancelSession(...): Promise<void>
...
```

then update the platform-neutral backend and high-level wrappers deliberately.

Do not leave:

```text
Promise returned by native
but backend typed as void
```

or:

```text
caller forgets to await a lifecycle-critical operation
```

Map affected high-level semantics.

### Initialize

Already public async:

```text
FFmpegKitExtended.initialize(): Promise<void>
```

This is the easiest contract to make exact.

### Session execution handoff

`executeSessionAsync` starts native asynchronous execution but the bridge call
itself has a handoff success/failure boundary.

The completion Promise should represent:

```text
native handoff accepted
```

not the eventual FFmpeg/FFprobe/FFplay session completion.

Session completion remains owned by the existing monitor/callback lifecycle.

### Cancel

If native dispatch becomes Promise-bearing:

```text
Session.cancel()
```

must await or otherwise preserve that dispatch error exactly where Review 31/38
cancellation retry/error authority expects it.

Do not silently turn cancellation into an unobserved Promise.

### Handle release

If release becomes Promise-bearing, ensure terminal cleanup waits for the
release transaction before wrapper ownership is considered gone.

Coordinate with G2.

### FFplay/configuration actions

Propagate Promise semantics only as far as required to preserve truthful caller
error behavior.

If public FFplay methods are currently synchronous, decide explicitly whether
they should become Promise-returning or whether Windows should use a different
generated invocation-bound result compatible with the existing public API.

This is a design gate; document the chosen method family contract before coding.

## 5.7 Alternative supported transport

If exact RNW codegen makes Promise migration across the shared spec
disproportionately invasive, a per-invocation callback/token completion can be
used **only if** it is generated/supported and has these properties:

```text
unique invocation identity
completion cannot race a different call
success and error are mutually exclusive
concurrent calls cannot overwrite one another
no polling or "last error"
```

Do not implement a process-global or thread-local mailbox.

## 5.8 Remove obsolete last-error state

After every affected method has a valid completion-bound transport:

```text
remove or strictly narrow consumeLastError
remove thread_local operational error state from async paths
remove invokeNative pattern that assumes immediate post-call error visibility
```

If synchronous getters retain a structured/same-call error mechanism, give it a
name that describes synchronous result transport rather than "last error."

Prefer one consistent generated result contract if practical.

## 5.9 Windows behavior oracles

Behavioral tests must cross the real RNW method scheduling boundary.

### Async failure ordering

Inject error **inside** the native asynchronous method body.

Assert:

```text
JS schedules method
no early false success
completion rejects for exact invocation
process remains alive
```

### Success

```text
operation completes
completion resolves exactly once
```

### Concurrency

Schedule A and B before either completes:

```text
A fails with error A
B succeeds
```

Assert:

```text
A gets A
B succeeds
no cross-talk
```

Then:

```text
A fails A
B fails B
```

Each must receive its own error.

### Initialization

Runtime-unavailable injection:

```text
await FFmpegKitExtended.initialize()
-> rejects
-> package does not mark initialization successful
```

### Cancellation

```text
durable cancellation intent recorded
native cancel dispatch rejects
Session cancellation path receives the rejection
Review 38 retry/error authority remains intact
```

### Release / clear

```text
native cleanup action rejects
wrapper does not clear its own ownership metadata prematurely
```

Coordinate with G2.

### FFplay

Invalid session target:

```text
control invocation rejects
process remains alive
```

## 5.10 Synchronous getter regression

Keep a separate focused suite for:

```text
create session
get state
get scalar values
get JSON
version/build information
```

Prove valid:

```text
0
false
empty string
```

are not confused with errors.

## 5.11 G1 exit criteria

Before closing G1:

```text
[ ] no failure-bearing Windows REACT_METHOD uses post-call consumeLastError
[ ] every such method has invocation-bound success/error completion
[ ] concurrent calls cannot overwrite one another
[ ] initialize cannot falsely resolve after native failure
[ ] cancellation error authority remains exact
[ ] release/clear errors are not silently lost
[ ] process remains alive on ordinary native errors
[ ] shared generated platforms compile if the TS spec changed
```

---

# 6. R40-G2 — Non-throwing shared C++ handle cleanup and transactional retained release

## 6.1 Objective

After bridge initialization succeeds:

```text
destroying/moving an owned HandleGuard cannot throw
```

and:

```text
retained bridge ownership is not erased before native release commits
```

Apply to the shared bridge used by:

```text
Windows
Android
iOS
tvOS
macOS
```

## 6.2 Establish mandatory lifetime symbols during initialization

Current `ensureInitialized()` resolves only:

```text
ffmpeg_kit_initialize
```

Extend shared bridge initialization with an internal runtime-symbol contract.

At minimum pre-resolve/cache:

```text
ffmpeg_kit_handle_release
ffmpeg_kit_free
```

Also consider any cleanup primitive invoked from destructors/RAII.

Recommended semantic structure:

```cpp
struct RuntimeLifetimeApi {
  HandleReleaseFn release_handle;
  FreeFn free_memory;
};
```

Initialize it atomically with the bridge.

If a mandatory lifetime symbol is missing:

```text
initialize() fails
before any owning wrapper handle is created
```

Do not permit partial initialization with unsafe RAII.

## 6.3 Thread-safe initialization

The existing `std::call_once` retry behavior for a throwing initializer should
remain correct.

The complete initialization transaction should be:

```text
load library
resolve mandatory lifecycle symbols
call native initialize
publish cached lifecycle API
mark initialization complete
```

If any step throws:

```text
do not publish partial cached state
next initialize may retry according to call_once semantics
```

## 6.4 HandleGuard contract

Rewrite guard semantics so this is structurally true:

```cpp
~HandleGuard() noexcept;
HandleGuard& operator=(HandleGuard&&) noexcept;
```

without hidden throwing symbol lookup.

Preferred:

```text
guard stores only handle + ownership
cleanup calls cached nonthrowing release function
```

If cached release unexpectedly cannot exist:

```text
that should have prevented successful bridge initialization
```

Do not catch a dynamic resolver exception in the destructor as the primary
design if early symbol validation can eliminate the failure.

A no-throw defensive fallback can still protect against impossible corrupted
state, but it must not be the normal error path.

## 6.5 Move assignment

Avoid:

```text
noexcept move assignment
-> perform potentially fallible release
```

Possible safe forms:

### Swap-based move

```text
move constructor transfers ownership
assignment uses swap with temporary
temporary destructor uses guaranteed nonthrowing release
```

### Explicit reset

If reset is guaranteed nonthrowing after initialization:

```text
reset()
adopt source
```

Document invariant.

## 6.6 Freeing native strings

`takeString()` uses `ffmpeg_kit_free`.

Because this is a mandatory ownership primitive, use the same pre-resolved
lifetime API.

Benefits:

```text
no repeated dlsym/GetProcAddress
no late missing-free-symbol surprise
one initialization-time ABI contract
```

Do not modify the frozen ABI; only validate symbols already expected by the
wrapper.

## 6.7 `releaseRetainedSession()` transaction

Current order erases bridge ownership before release.

Change to a failure-atomic semantic order.

Suggested:

```text
lock
locate retained handle
read/capture handle
unlock if safe, but retain map entry as owner marker

read terminal/native state while ownership is still recorded

perform native release
  - should be nonthrowing after successful initialization

only after release commit:
  lock
  erase exact same retained handle/identity
  unlock

then:
  reconcile terminal or Created history
```

If any fallible pre-release operation fails:

```text
retainedSessionHandles remains unchanged
caller can retry
```

If concurrent release is possible, add a semantic state/claim so two callers
cannot release the same handle.

Do not solve this with "erase first to prevent duplicates" unless a rollback
record restores ownership on failure.

## 6.8 `acquireHistorySession()` handoff

Audit this path:

```text
temporary owning handle
existing retained handle discovered
release temporary
adopt existing borrowed handle
```

After G2, temporary release is nonthrowing.

Ensure:

```text
no double release
no release under map mutex if native callback could re-enter bridge
no ownership gap
```

Prefer to avoid calling native release while holding `sessionHandlesMutex` if
the native ABI could perform meaningful work. If moving it outside the lock,
preserve race correctness with a retained-owner claim.

Do not invent complexity unless needed; document selected lock/ownership rule.

## 6.9 Destructor audit

Search the entire shared/native RN bridge for:

```text
~Type()
noexcept methods
move assignment noexcept
scope guards
finalizers
callbacks destroying native-owned data
```

Prove none calls:

```text
resolve()
resolveRaw()
another throwing dynamic lookup
```

The existing `OwnedLogMessage::~OwnedLogMessage() noexcept` is acceptable
because it catches cleanup failure.

Keep accepted log-bridge retirement behavior.

## 6.10 Resolver injection seam

Build a wrapper-only test seam around symbol resolution.

Do not alter or corrupt the user's real `0.11.2` library.

Need deterministic controls:

```text
mandatory release symbol absent at initialize
mandatory free symbol absent at initialize
normal optional symbol absent during ordinary API call
```

## 6.11 Required tests

### Initialization contract

```text
release symbol missing
-> initialize fails normally
-> no HandleGuard created
-> process lives
```

```text
free symbol missing
-> initialize fails normally
-> process lives
```

### Guard destruction

After successful fake initialization:

```text
owned handle leaves scope
-> release exactly once
-> destructor cannot throw
```

### Move

```text
A owns handle 1
B owns handle 2
B = move(A)
-> old B handle released exactly once
-> B owns handle 1
-> A empty
-> no throw
```

### Primary error

```text
operation throws
-> guard destructor runs
-> original exception remains primary
-> no terminate
```

### Retained transaction

```text
state lookup fails before release
-> map still owns handle
```

```text
release succeeds
-> map erases exactly once
-> terminal history reconciles
```

### Representative APIs

Exercise at least one owned temporary from:

```text
session creation
session snapshot
statistics/log/history read
media information
FFplay lookup
```

## 6.12 Cross-platform compile requirement

Because this is shared C++:

```text
Windows C++ bridge compile
Android Cxx/Gradle build
iOS Cxx/codegen build
tvOS build
macOS Cxx/codegen build
```

must all be included in G4.

## 6.13 G2 exit criteria

```text
[ ] HandleGuard destructor explicitly/non-implicitly no-throw
[ ] noexcept move path cannot call throwing resolver
[ ] mandatory cleanup symbols validated before ownership begins
[ ] native free uses cached mandatory primitive
[ ] primary exceptions survive cleanup
[ ] retained map ownership erased only after release commit
[ ] no double release in history-retention handoff
[ ] Windows/Android/Apple shared builds compile
```

---

# 7. R40-G3 — Canonical packed RGBA FFplay frame bridge for Flutter Windows/Linux

## 7.1 Objective

The Flutter desktop bridge accepts supported packed FFplay formats and produces:

```text
RGBA8888
tightly packed
destination stride = width * 4
```

before any bytes enter renderer-facing buffers.

Supported source layouts:

```text
rgba
rgb0
bgra
bgr0
argb
abgr
```

## 7.2 Create one shared native helper

Add a semantic helper under:

```text
flutter/native/
```

Suggested name:

```text
packed_rgba_frame.h
pixel_format_converter.h
rgba_frame_normalizer.h
```

Do not use review/goal names.

API example:

```cpp
enum class PackedPixelFormat { ... };

bool NormalizePackedFrameToRgba(
    const uint8_t* source,
    int width,
    int height,
    int source_stride,
    const char* source_format,
    std::vector<uint8_t>* destination);
```

Or separate parse + convert functions if cleaner.

## 7.3 Validation before allocation/copy

Reject:

```text
source == nullptr
destination == nullptr
width <= 0
height <= 0
source_stride < width * 4
unknown/empty format when no safe documented default exists
size_t multiplication overflow
destination byte-count overflow
```

Do not cast negative `linesize` to `size_t`.

If the frozen runtime guarantees positive stride, this remains cheap bridge
validation.

## 7.4 Exact byte mappings

For each source pixel, produce:

### rgba

```text
src: R G B A
dst: R G B A
```

### rgb0

```text
src: R G B X
dst: R G B FF
```

Do not preserve source alpha for `rgb0`.

### bgra

```text
src: B G R A
dst: R G B A
```

### bgr0

```text
src: B G R X
dst: R G B FF
```

### argb

```text
src: A R G B
dst: R G B A
```

### abgr

```text
src: A B G R
dst: R G B A
```

## 7.5 Row packing

Destination is always:

```text
width * height * 4
```

For each row:

```text
src_row = source + y * source_stride
dst_row = destination + y * width * 4
```

Ignore source padding after `width*4`.

Do not publish `linesize*height` directly to Flutter pixel-buffer consumers.

## 7.6 Fast path

For `rgba` with:

```text
source_stride == width*4
```

a bulk copy is allowed.

For `rgb0` with tight stride:

```text
bulk copy + alpha patch
```

is allowed.

Other layouts can use a simple per-pixel loop unless benchmark evidence
justifies SIMD.

Do not overengineer this remediation.

## 7.7 Windows integration

Replace current:

```text
resize(linesize * height)
memcpy
rgb0-only alpha patch
```

with:

```text
normalize source -> state->write_buf canonical RGBA
```

Then preserve:

```text
state mutex
write/read swap
Review 39 TextureVariant retirement
MarkTextureFrameAvailable
render buffer stable copy
```

Set:

```text
state width/height
```

only after successful normalization.

On unsupported/invalid frame:

```text
drop frame
do not mutate the last valid render buffer
do not mark a new frame available
```

Use bounded diagnostic logging only if an existing safe non-FFplay API path is
available. Remember the callback is invoked while the internal FFplay API mutex
is held; do not call FFplay APIs from it.

## 7.8 Linux integration

Replace:

```text
vector(source, source + linesize*height)
rgb0-only patch
frame_store.publish(raw)
```

with:

```text
normalize source -> local/canonical RGBA
frame_store.publish(rgba, width*height*4, width, height)
```

Preserve:

```text
TextureState lifetime
FrameNotificationCoalescer
g_object_ref idle callback barrier
FlPixelBufferTexture ownership
release/reuse behavior
```

`PixelBufferFrameStore` should not know the source format.

## 7.9 Apple/RN parity

Do not gratuitously rewrite working Apple or RN Windows converters.

Instead add a source/behavior parity oracle if useful:

```text
same synthetic source pixel
-> Flutter canonical RGBA
-> Apple destination represents same visual channels
-> RN Windows BGRA destination represents same visual channels
```

The purpose is to prevent future platform drift.

## 7.10 Converter tests

Create executable native tests.

Use distinct bytes:

```text
R 0x11
G 0x22
B 0x33
A 0x44
X 0x00
```

Expected canonical:

```text
rgba -> 11 22 33 44
rgb0 -> 11 22 33 FF
bgra -> 11 22 33 44
bgr0 -> 11 22 33 FF
argb -> 11 22 33 44
abgr -> 11 22 33 44
```

Construct the correct source order for each format.

## 7.11 Multi-row/stride test

Use:

```text
width = 2
height = 2
source_stride = width*4 + padding
```

Give each row distinct colors and padding sentinel bytes.

Assert:

```text
destination size == width*height*4
padding sentinel never appears in destination
row 2 starts at width*4
```

## 7.12 Invalid input tests

```text
null pixels
zero/negative width
zero/negative height
stride < width*4
unknown format
overflow dimensions
```

All fail without mutating destination into a partially valid frame.

## 7.13 Thin platform integration tests

Windows:

```text
invoke frame callback seam
inspect canonical write/read buffer
copy callback sees RGBA
```

Linux:

```text
invoke frame callback seam
PixelBufferFrameStore render bytes are canonical RGBA
```

Do not require the real native ABI for this focused conversion test.

## 7.14 G3 exit criteria

```text
[ ] one semantic Flutter native normalization authority
[ ] six supported packed layouts covered
[ ] rgb0 and bgr0 alpha forced to FF
[ ] padded rows repacked
[ ] invalid format/stride fails closed
[ ] Windows publishes only canonical RGBA
[ ] Linux publishes only canonical RGBA
[ ] Review 39 texture/resource ownership unchanged
[ ] native behavior tests pass
```

---

# 8. R40-G4 — Focused regression and affected local platform matrix

Do not begin broad local builds until G1–G3 focused tests are green.

No hosted acceptance workflow.

No remote native artifact.

No interactive app.

---

## 8.1 Flutter focused gate

Disable analytics first:

```text
flutter config --no-analytics
dart --disable-analytics
```

Run new native conversion tests plus retained native helpers:

```text
packed RGBA converter
Windows registered texture lifetime
Windows texture registration transaction
FFplay owner coordinator
Linux pixel buffer frame store
Linux FrameNotificationCoalescer
Linux texture registration transaction
Apple callback/source parity where maintained
Android surface owner coordinator
```

Run the relevant Flutter package tests that exercise native bridge configuration
without requiring interactive UI.

## 8.2 React Native focused gate

Run:

```text
npm run typecheck
npm run test:compile
npm run lint
```

Then focused native bridge tests:

```text
Windows invocation-bound error transport
Windows async concurrency/error isolation
Review 38 cancellation state-read/error authority
shared HandleGuard cleanup
mandatory lifetime symbol initialization
retained session release transaction
native log bridge lifetime
FFplay native lifecycle
session/history ownership
```

If TS native spec changes:

```text
regenerate codegen
run source/codegen contract tests
```

## 8.3 Windows first

Primary platform for G1 and half of G3.

Use existing local Windows `0.11.2` archive.

Flutter:

```text
native helper tests
Flutter Windows debug build
```

React Native:

```text
native error-completion tests
shared C++ cleanup tests
RN type/codegen gates
./build.sh windows
```

No interactive executable launch.

## 8.4 Android on local Windows

Required because G2 changes shared C++ and G1 may change shared TS/Cxx codegen.

Use installed Windows Android toolchain and the existing local AAR.

Required:

```text
React Native Android build
shared Cxx/codegen compile
```

Flutter Android is not directly changed by G3, but if shared Flutter native
helper/build configuration changed in a way that enters Android packaging, run
the existing Android package/build gate.

Do not substitute WSL Android.

## 8.5 Linux under WSL

Primary platform for G3.

Use existing local Linux archive.

Required:

```text
new RGBA conversion native test
PixelBufferFrameStore test
FrameNotificationCoalescer test
Flutter Linux build
```

No interactive app.

## 8.6 Apple last

G2 shared C++ and any G1 shared TurboModule spec change require Apple compile
validation.

Use existing local universal XCFramework archives.

React Native:

```text
iOS build
tvOS build
macOS build
```

If codegen changed:

```text
ensure regenerated consumer code matches exact shared spec
```

Flutter Apple does not directly consume the new Windows/Linux converter unless
the helper is made cross-platform. Run only necessary source/parity/build gates;
do not gratuitously alter the working Apple frame converter.

No interactive simulator/device operation.

## 8.7 Shared package/Web compatibility

If G1 changes `NativeFFmpegKitExtended.ts`:

run compile/package compatibility gates for the shared React Native package.

Web/Wasm runtime is not a Review 40 native acceptance target unless the shared
backend interface must change to Promise-returning methods.

If backend interface changes, update Web implementation to preserve the same
TypeScript contract, but do not turn Review 40 into another Web behavior review.

---

# 9. G4 error/evidence rules

For every test/build command:

```text
record exact command
record exact result
record actual pass count where available
record whether it is diagnostic or acceptance
```

A timeout or killed process is not a pass.

If an environment issue occurs:

```text
prove it
correct it
rerun exact intended gate
record both attempts
```

Do not reclassify a product failure as environment noise.

---

# 10. R40-G5 — Final platform-native bridge closure audit

After G1–G4 are complete, do **one final source audit** before freezing.

This is a bounded closure audit, not Review 41.

Search the final source for the bridge-gap classes addressed through Reviews
27–40.

## 10.1 Error-boundary audit

Search React Native native code for:

```text
RaiseFailFastException
std::terminate
throw from destructor
throw from noexcept
thread_local last error
cross-call error mailbox
unobserved Promise/action failure
```

Required result:

```text
no ordinary operational failure terminates the process
no async operation depends on cross-call "last error"
```

## 10.2 RAII/lifetime audit

Search for:

```text
~Type
noexcept move
dynamic resolve inside cleanup
release before ownership commit
free after ownership forgotten
```

Required result:

```text
destructors/finalizers cannot throw
native-handle ownership transitions are exactly once
```

## 10.3 Callback owner audit

Across Flutter/RN Windows/Linux/Android/Apple:

```text
register callback
unregister callback
userdata owner
drain/accept flag
stale owner conditional teardown
```

Required result:

```text
every callback has a lifetime owner
stale teardown cannot clear newer owner
callback-visible state outlives in-flight callback
```

Do not reopen accepted working implementations without contradictory evidence.

## 10.4 Texture/surface audit

Search:

```text
RegisterTexture
UnregisterTexture
register_texture
unregister_texture
Surface
SurfaceTextureEntry
ANativeWindow
CVPixelBuffer/IOSurface
frame callback
```

Required result:

```text
engine-visible state lives long enough
native surfaces have balanced ownership
desktop renderer receives canonical pixels
```

## 10.5 Dynamic symbol audit

Search:

```text
dlsym
GetProcAddress
LoadLibrary
dlopen
```

Required result:

```text
required callback pairs commit atomically
misses remain retryable where intended
mandatory lifetime symbols validated before RAII ownership
no one-half callback API publication
```

## 10.6 Duplicate Apple source parity

Diff:

```text
Flutter CocoaPods vs SwiftPM plugin native copies
RN iOS vs tvOS vs macOS shared FFplay logic where expected
```

Allow imports/platform-specific paths/platform labels.

Any behavioral difference must be deliberate and documented.

## 10.7 Pixel-layout audit

Search every FFplay frame callback for:

```text
pixel_format
linesize
rgba
bgra
rgb0
bgr0
argb
abgr
```

Required result:

```text
each renderer receives its documented destination format
stride handled deliberately
unused alpha handled deliberately
unknown format behavior explicit
```

## 10.8 Closure decision

If this final audit finds no new substantive issue:

```text
mark platform-native bridge review CLOSED
```

Do not invent a new finding merely to continue the review series.

If it finds a direct substantive defect introduced by G1–G3:

```text
fix it within Review 40
add focused evidence
rerun affected gates
repeat only the relevant bounded audit
```

If it finds an unrelated pre-existing substantive defect that truly meets the
threshold:

```text
record it honestly
remediate within Review 40 if it belongs to platform-native bridge closure
```

The requested goal is closure, not artificial iteration count.

---

# 11. Documentation/tracker reconciliation

Update `.agent/TRACKER.md` with:

```text
Review 40 source authority
three findings
goal status
focused behavior evidence
platform validation
closure audit result
any residual frozen-ABI limitation
```

If G1 changes public/internal async contracts, update relevant RN docs/API
comments accurately.

If G3 changes supported format handling, document the canonical bridge format
only where it materially helps maintainers.

Do not perform unrelated documentation cleanup.

---

# 12. Exact final source freeze

After all implementation, tests, builds, and closure audit:

1. Clean task-owned output.
2. Verify wrapper worktree.
3. Verify native gitlink unchanged.
4. Verify builder checkout untouched.
5. Record implementation commits.
6. Push final wrapper implementation to `origin/dev-wasm`.
7. Record exact final wrapper SHA/tree.
8. Dispatch **one** repository source-snapshot workflow for that exact SHA.
9. Do not dispatch hosted Flutter/RN validation workflows.
10. Do not create/download native/builders snapshot.

Verify final source artifact:

```text
workflow head SHA == frozen wrapper SHA
snapshot-metadata.snapshot_sha == frozen wrapper SHA
artifact digest matches connector
source.tar.gz hash matches sidecar/metadata
SHA256SUMS verifies every file
SUBMODULES.txt contains frozen native gitlink
SYMLINKS.tsv matches metadata
runtimeExecution == false
```

Record:

```text
workflow run ID
artifact name
artifact ID
artifact digest
source archive SHA-256
manifest count
symlink count
submodule SHA
runtimeExecution
```

Then stop automated work.

---

# 13. Hard execution order

```text
R40-G1
  inventory Windows async/sync method contracts
  choose invocation-bound RNW transport
  implement generated/shared changes
  prove async error isolation
  commit/push where practical

R40-G2
  establish mandatory lifetime symbol initialization
  make HandleGuard cleanup structurally no-throw
  make retained release transactional
  prove primary-error preservation
  commit/push where practical

R40-G3
  add shared RGBA normalizer
  integrate Flutter Windows
  integrate Flutter Linux
  prove six pixel layouts + stride handling
  commit/push where practical

combined focused native bridge regression

R40-G4
  Windows
  Android on Windows if shared code/spec changed
  WSL Linux
  shared package compile compatibility as needed
  Apple last

R40-G5
  final bounded platform-native bridge audit
  fix any directly discovered closure regression inside Review 40
  reconcile tracker/docs
  freeze exact wrapper SHA
  one wrapper-only source snapshot
  verify artifact
  STOP

user-owned final interactive runtime validation
```

---

# 14. Luna closeout checklist

## G1

```text
[ ] every Windows failure-bearing REACT_METHOD has invocation-bound completion
[ ] no async operation uses consumeLastError after scheduling
[ ] no thread-local/global last-error race
[ ] initialize failure rejects accurately
[ ] cancellation failure reaches wrapper error authority
[ ] release/clear failure cannot silently succeed
[ ] concurrent async calls isolate errors
[ ] valid synchronous zero/false/empty values remain valid
[ ] shared codegen consumers compile if spec changed
```

## G2

```text
[ ] mandatory release/free symbols validated before handle ownership
[ ] HandleGuard destructor cannot throw
[ ] noexcept move assignment cannot throw
[ ] dynamic resolver not called from RAII cleanup
[ ] primary exception survives cleanup
[ ] retained owner not erased before release commit
[ ] exactly-once release maintained
[ ] Android/iOS/tvOS/macOS/Windows shared bridge compiles
```

## G3

```text
[ ] rgba normalized
[ ] rgb0 normalized + alpha FF
[ ] bgra normalized
[ ] bgr0 normalized + alpha FF
[ ] argb normalized
[ ] abgr normalized
[ ] padded source stride repacked
[ ] bad stride rejected
[ ] unknown format rejected/drop policy explicit
[ ] Windows renderer sees RGBA only
[ ] Linux FlPixelBufferTexture sees RGBA only
[ ] Review 39 texture/resource lifetime remains intact
```

## G4

```text
[ ] focused native tests green before platform builds
[ ] Windows local gates green
[ ] Android shared bridge gate green when applicable
[ ] Linux local gates green
[ ] Apple shared bridge builds green
[ ] no interactive app execution
[ ] no hosted acceptance CI
[ ] no remote old native binary
```

## G5

```text
[ ] no operational fail-fast remains
[ ] no throwable RAII cleanup remains
[ ] no callback userdata lifetime gap remains
[ ] no stale owner clears newer owner
[ ] no unresolved texture/surface ownership gap
[ ] no one-half symbol-pair publication
[ ] every desktop FFplay renderer gets explicit correct pixel format
[ ] duplicate Apple native sources behaviorally aligned
[ ] native gitlink unchanged
[ ] builder checkout unchanged
[ ] exact final wrapper SHA pushed
[ ] one wrapper source snapshot verified
[ ] tracker explicitly marks platform-native bridge closure result
```

---

# 15. Final Luna handoff

Review 40 should be treated as the **platform-native bridge closure milestone**.

The three core invariants are:

**Invocation ownership**

> A native method failure belongs to the invocation that caused it. Windows
> asynchronous native calls cannot communicate through a separate thread-local
> "last error" lookup.

**Native resource ownership**

> Once the shared bridge begins owning native handles, RAII cleanup is
> structurally non-throwing and bridge ownership is never discarded before the
> underlying release transaction commits.

**Pixel contract ownership**

> Flutter Windows and Linux receive one canonical tightly packed RGBA8888 frame
> contract regardless of the supported FFplay source layout.

Implement those invariants without touching the frozen ABI, prove them with
real native behavior oracles, execute only the affected local platform matrix,
then perform the bounded final platform-native audit. If that audit is clean,
freeze one exact wrapper snapshot and close the platform-native bridge review.
