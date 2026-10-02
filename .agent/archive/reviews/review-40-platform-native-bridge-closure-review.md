# Review 40 — Flutter + React Native Platform-Native Bridge Closure Review

**Project:** FFmpegKitExtended  
**Review type:** frozen-source platform-native bridge code review; pedantic and procedural findings excluded  
**Date:** 2026-09-30 / 2026-10-01 snapshot UTC  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Frozen wrapper source:** `8725426e55baac78ad8ba8f45dfd6a0bfc0cc2b8`  
**Snapshot workflow:** `36806954755`  
**Snapshot artifact:** `repo-source-snapshot-36806954755`  
**Artifact ID:** `11138276225`  
**Artifact digest:** `sha256:fc5eabd237eb4ce2c36310969475fc82435430003501ec28b9a92774d2d98b3f`  
**Embedded `source.tar.gz` SHA-256:** `8c58a0dc33fab05f6f58b1b20f65e66b0eb85fe59d89d8a669fb558c24604844`  
**Manifest:** **1,079/1,079 files verified**  
**Symlinks:** `0`  
**Snapshot bytes:** `27,574,328`  
**Submodule:** `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`  
**Native ABI/runtime:** `0.11.2`, frozen/read-only; not separately downloaded or re-reviewed

---

## 1. Review objective

Review 40 is intended as a **platform-native bridge closure pass**.

The goal is not to reopen the Dart/TypeScript application-layer reviews or the
frozen FFmpegKit ABI. The goal is to identify any remaining substantive gaps at
the platform/native boundary after Review 39's fixes.

The review therefore focused on:

```text
Flutter native bridge surfaces
  Windows C++ external-texture bridge
  Linux C++/GObject pixel-buffer bridge
  Android Kotlin/Java surface bridge
  iOS Objective-C texture/callback bridge
  macOS Objective-C texture/callback bridge
  shared native helper classes used by those platforms

React Native native bridge surfaces
  shared dynamic C++ ABI adapter
  shared Cxx TurboModule implementation
  Windows C++/WinRT TurboModule implementation
  Windows Fabric FFplay view
  Android Java FFplay surface bridge
  iOS Objective-C++ FFplay view/TurboModule registration
  tvOS Objective-C++ FFplay view/TurboModule registration
  macOS Objective-C++ FFplay view/TurboModule registration
```

Dart and TypeScript were read only where necessary to establish the native
bridge contract or downstream error/lifecycle consequence.

---

## 2. Review boundary

This was **code review only**.

No acceptance execution was performed:

- no Flutter/Dart tests;
- no Node tests;
- no native C/C++/Objective-C/Java/Kotlin test execution;
- no Windows, Android, Linux, iOS, tvOS, or macOS build;
- no simulator/device execution;
- no browser/runtime smoke;
- no interactive application;
- no hosted CI validation;
- no repository mutation.

The frozen native ABI/runtime was **not** redownloaded or re-reviewed.

`libs/libffmpegkit` was present only because the authoritative source snapshot
recursively materializes the frozen submodule. It was treated as provenance,
not as Review 40 source authority.

Excluded from findings:

- style and naming;
- formatting;
- tracker/process/procedural observations;
- documentation-only differences;
- missing-test-only observations;
- speculative future hardening without a reachable product effect;
- low-impact pedantry.

---

## 3. Snapshot verification

The repository snapshot was retrieved through the existing source-snapshot
workflow rather than through piecemeal repository reads.

Verification result:

```text
GitHub artifact digest:
fc5eabd237eb4ce2c36310969475fc82435430003501ec28b9a92774d2d98b3f

Locally computed outer ZIP SHA-256:
fc5eabd237eb4ce2c36310969475fc82435430003501ec28b9a92774d2d98b3f

snapshot_sha:
8725426e55baac78ad8ba8f45dfd6a0bfc0cc2b8

source.tar.gz SHA-256:
8c58a0dc33fab05f6f58b1b20f65e66b0eb85fe59d89d8a669fb558c24604844

SHA256SUMS:
1079/1079 verified

symlinks:
0

recursive submodule:
b74da2c5d1e294b87d15d73a6687393729e932b3 libs/libffmpegkit

runtimeExecution:
false
```

One diagnostic checksum attempt was made before `source.tar.gz` had been
expanded into its intended `source/` root. `SHA256SUMS` correctly addresses that
expanded tree, so the attempt produced path-not-found diagnostics only. After
extracting the archive into the expected root, **1,079/1,079** entries verified.
This was a verification-order correction, not an artifact defect.

---

## 4. External bridge contracts checked

External framework source/documentation was used only where a platform contract
was necessary to judge the wrapper.

### React Native Windows

The repository's example resolves React Native Windows `0.81.32`.

React Native Windows documents:

```text
REACT_METHOD      -> asynchronous native method
REACT_SYNC_METHOD -> synchronous native method
```

The 0.81 `IReactModuleBuilder` API likewise states:

```text
AddMethod     -> adds an asynchronous native method
AddSyncMethod -> adds a synchronous native method
```

RNW also documents Promise/callback parameters as the completion/error channel
for JavaScript async methods.

Relevant framework references:

- React Native Windows 0.81 `IReactModuleBuilder`
- React Native Windows Native Modules documentation
- React Native Windows asynchronous native-module documentation

### Flutter Windows

Flutter's `PixelBufferTexture` path passes the returned CPU buffer to
`glTexImage2D` as `GL_RGBA`.

### Flutter Linux

`FlPixelBufferTexture::copy_pixels` explicitly requires the plugin to prepare
the pixel buffer in **RGBA format**. Flutter uploads the buffer with
`glTexImage2D(... GL_RGBA ...)`.

These external contracts are important to R40-F1 and R40-F3 below.

---

# 5. Executive disposition

The frozen Review 39 wrapper is **not yet platform-native bridge clean**.

Review 40 found three remaining substantive bridge defects:

| ID | Severity | Surface | Finding |
| --- | --- | --- | --- |
| **R40-F1** | **High** | React Native Windows | Review 39's thread-local `consumeLastError()` transport is paired with `REACT_METHOD` asynchronous methods. JavaScript consumes the error immediately after scheduling the asynchronous method, before the native call is guaranteed to run, and the error may be recorded on a different thread. Operational failures can therefore be silently lost. |
| **R40-F2** | **High** | React Native shared C++ → Windows/Android/Apple | `HandleGuard` calls a symbol-resolving, throwing `release()` from an implicitly `noexcept` destructor and an explicitly `noexcept` move assignment. Missing/failed cleanup-symbol resolution can therefore call `std::terminate()` across every native Cxx consumer. The explicit retained-handle release path also drops bridge ownership before native release commits. |
| **R40-F3** | **Medium-High** | Flutter Windows + Linux | Desktop FFplay frame callbacks receive a `pixel_format` parameter but Windows/Linux publish the bytes as RGBA without normalizing supported layouts. Only `rgb0` alpha is patched. BGRA/BGR0/ARGB/ABGR frames can render with swapped channels or transparent alpha, and padded row strides are not normalized for Flutter's tightly packed RGBA pixel-buffer consumers. |

No finding requires changing the frozen native ABI.

---

# 6. R40-F1 — React Native Windows asynchronous methods cannot use the thread-local post-call error channel

**Severity:** High  
**Platform:** React Native Windows  
**Primary files:**

```text
react-native/windows/FFmpegKitExtended/FFmpegKitExtended.h
react-native/windows/FFmpegKitExtended/FFmpegKitExtended.cpp
react-native/windows/FFmpegKitExtended/operational_error_transport.h
react-native/windows/FFmpegKitExtended/recoverable_native_dispatch.h
react-native/src/NativeFFmpegKitExtended.ts
react-native/src/platform/backend.native.ts
```

## 6.1 Review 39's intended design

Review 39 removed blanket process termination for operational adapter errors.

The new Windows seam catches C++ exceptions and records a diagnostic in:

```cpp
inline thread_local std::string lastOperationalError;
```

The TypeScript native backend then calls the method and immediately executes:

```ts
const result = Reflect.apply(candidate, NativeFFmpegKitExtended, args);
const message = NativeFFmpegKitExtended.consumeLastError();
if (message) throw new Error(message);
return result;
```

This works only if the native operation and `consumeLastError()` have one
synchronous completion boundary on the same thread.

## 6.2 The Windows surface contains many asynchronous `REACT_METHOD`s

Examples from the frozen header include:

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

These are declared with `REACT_METHOD`, not `REACT_SYNC_METHOD`.

React Native Windows' native-module contract classifies `REACT_METHOD` /
`AddMethod` as asynchronous.

## 6.3 `consumeLastError()` is synchronous and immediate

The backend does:

```text
schedule/invoke REACT_METHOD
-> immediately call synchronous consumeLastError()
```

There is no method-specific completion token, callback, Promise, or future
linking the two calls.

Therefore all of these are possible:

### Case A — consume runs before native method body

```text
JS calls cancelSession()
-> RNW enqueues/schedules native cancelSession
-> JS immediately calls consumeLastError()
-> thread-local error is currently empty
-> JS treats cancel as successful
-> native cancelSession later throws and records error
```

The intended caller never receives the failure.

### Case B — native method and consume use different threads

The error storage is explicitly:

```cpp
thread_local
```

If the asynchronous native method records the diagnostic on a native dispatcher
thread and `consumeLastError()` runs synchronously on the JS/native sync-call
thread, the consumer reads a different thread-local instance.

Again the caller sees no error.

### Case C — a later call erases the stale error

Every `invokeRecoverably()` starts with:

```cpp
clearOperationalError();
```

A failed asynchronous operation can leave an unread diagnostic on its native
thread. A later operation on that thread clears it before the JavaScript side
ever sees it.

## 6.4 Consequences are not limited to diagnostics

This changes correctness of lifecycle APIs.

### Initialization

`FFmpegKitExtended.initialize()` is exposed as a Promise by the platform-neutral
backend, but the Windows backend wraps a `void` native call.

A runtime initialization failure can therefore be lost while the wrapper-level
initialization Promise resolves.

### Cancellation

Review 38 deliberately made cancellation intent durable when state/native
cancellation fails.

If `cancelSession` fails in the asynchronous Windows method and the diagnostic
is lost, the caller can incorrectly observe cancellation dispatch as successful.

### Handle release / history cleanup

`releaseSessionHandle`, `abandonCreatedSession`, and `clearSessions` can fail
silently, leaving native ownership/history state different from wrapper state.

### FFplay controls/configuration

Pause, resume, seek, volume changes, logging/configuration writes, pipe closing,
and debug-log mutations can silently fail.

## 6.5 Why a global/process-shared string alone is not enough

Replacing `thread_local` with one global string would remove the cross-thread
visibility problem but would not establish which asynchronous call produced the
error.

Concurrent native operations could overwrite each other, and JavaScript would
still consume before completion.

The missing primitive is **completion-bound error transport**.

## 6.6 Required remediation principle

Every failure-bearing asynchronous Windows native method must report success or
failure through the same completion object that represents that invocation.

Valid implementation shapes include:

```text
Promise resolution/rejection
callback completion carrying status/error
explicit per-call token + completion event
```

The preferred RNW shape is Promise/callback completion where supported by the
exact generated spec.

Do not:

```text
keep a cross-call thread-local/global "last error"
convert methods to sync merely to preserve the workaround
sleep/poll consumeLastError after invocation
silently ignore errors on void methods
```

## 6.7 Shared-codegen decision

The TypeScript TurboModule spec is shared by Windows/Android/Apple.

Luna must first classify each native method by public semantic need.

For methods that need caller-visible failure and are naturally actions:

```text
prefer Promise<void> / completion-bearing contract
```

Then update all generated/platform implementations consistently.

For truly fire-and-forget methods where failure is intentionally not public,
remove false synchronous error expectations rather than maintaining an invalid
diagnostic channel.

The current wrapper semantics indicate that initialization, cancellation,
execution handoff, session-handle release, log-bridge mutation, clear/history
mutation, and FFplay control failures are meaningful and should not silently
disappear.

## 6.8 Required regression

A useful Windows behavior test must prove **actual asynchronous ordering**.

It is not sufficient to call `invokeRecoverably()` directly in one thread.

Required oracle:

```text
JS/native test schedules an async REACT_METHOD
native implementation records injected failure only inside async invocation
caller receives rejection/error for that exact invocation
next concurrent invocation receives its own result
no consumeLastError race or thread-local dependency
process remains alive
```

At minimum cover:

```text
initialize failure
cancelSession failure
releaseSessionHandle failure
clearSessions failure
FFplay invalid-target control
one successful async action
two overlapping async actions
```

## 6.9 Exit criterion

A React Native Windows asynchronous native operation must have exactly one
invocation-scoped success/failure completion, and no operational error may rely
on a separate thread-local "last error" read after scheduling the operation.

---

# 7. R40-F2 — Shared C++ handle RAII can terminate the process during ordinary cleanup failure

**Severity:** High  
**Platforms:** React Native Windows, Android, iOS, tvOS, macOS via shared C++ bridge  
**Primary file:**

```text
react-native/cpp/FFmpegKitDynamicApi.cpp
```

## 7.1 `release()` can throw

The shared helper is:

```cpp
void release(Handle handle) {
  if (handle == nullptr) return;
  using Fn = void (*)(Handle);
  resolve<Fn>("ffmpeg_kit_handle_release")(handle);
}
```

`resolve()` calls `resolveRaw()`.

`resolveRaw()` throws `std::runtime_error` when:

```text
runtime library cannot be loaded
requested ABI symbol is absent
```

Review 39 correctly classified these as operational/runtime conditions rather
than process-corruption conditions.

## 7.2 `HandleGuard` uses that throwing helper from `noexcept` cleanup

The frozen guard contains:

```cpp
HandleGuard &operator=(HandleGuard &&other) noexcept {
  if (this != &other) {
    if (owned) release(handle);
    ...
  }
  return *this;
}

~HandleGuard() {
  if (owned) release(handle);
}
```

The move assignment is explicitly `noexcept`.

The destructor is implicitly `noexcept(true)`.

If `release()` throws from either location:

```text
C++ runtime calls std::terminate()
```

The ordinary platform error boundary cannot catch that termination.

## 7.3 This affects all native React Native platforms

The guard is in the shared `FFmpegKitDynamicApi.cpp` used by:

```text
Windows native module
Android Cxx TurboModule
iOS Cxx TurboModule
tvOS Cxx TurboModule
macOS Cxx TurboModule
```

Review 39 removed Windows `RaiseFailFastException`, but a cleanup-symbol failure
can still terminate Windows through this lower shared layer.

Android/Apple also inherit the same destructor behavior.

## 7.4 Many normal APIs create owning guards

Owning temporary handles are used while:

```text
creating sessions
looking up Created/terminal sessions
serializing session snapshots
reading logs/statistics/media information
performing FFplay control resolution
projecting history
```

The destructor executes as normal scope cleanup.

A release-symbol failure can therefore terminate an otherwise recoverable call.

## 7.5 Throwing during stack unwinding is especially severe

Consider:

```text
main bridge operation throws runtime_error
-> stack begins unwinding
-> owning HandleGuard destructor runs
-> release() resolves missing cleanup symbol and throws
-> process terminates
```

The original operational error is lost entirely.

This violates the project's established primary-error-preservation rule.

## 7.6 Move assignment is also unsafe

`operator=(HandleGuard&&) noexcept` releases an existing owned handle before
adopting the new handle.

If release fails:

```text
noexcept move assignment
-> std::terminate
```

No JavaScript/native wrapper boundary can recover.

## 7.7 `releaseRetainedSession()` has a second transaction problem

The retained session path does:

```text
lock retained map
read handle/state
erase retainedSessionHandles[id]
unlock
release(handle)
mark/prune history
```

If `release(handle)` fails:

```text
bridge already forgot its retained owner
native release did not commit
history terminal reconciliation did not run
caller cannot retry the same retained ownership transaction reliably
```

Even after R40-F1 provides proper error delivery, this release order would leave
bridge state inconsistent.

## 7.8 Required remediation principle

Cleanup needed by RAII must be **non-throwing by construction**.

The bridge should resolve mandatory cleanup functions at initialization, before
any owning handles exist.

A robust initialization contract can resolve/cache:

```text
ffmpeg_kit_handle_release
ffmpeg_kit_free
other mandatory lifetime primitives
```

If a mandatory lifetime symbol is absent:

```text
initialize fails before handle ownership begins
```

After successful initialization, the RAII cleanup path uses the cached function
pointer and does not call the throwing general resolver.

`HandleGuard` should then have explicitly non-throwing cleanup semantics.

## 7.9 Do not hide failed ownership transitions

For explicit lifecycle operations, choose a transaction that keeps retryability.

For retained-session release:

```text
identify retained handle
perform required terminal state read while still owned
perform native release / guaranteed nonthrowing release primitive
only after release commit:
  erase retained bridge ownership
  mark/prune history
```

If a pre-release operation fails:

```text
keep retained map ownership
caller can retry
```

If release is guaranteed nonthrowing after initialization, document and test
that invariant.

## 7.10 Other cleanup helpers

Audit every RAII/destructor path that calls dynamic resolution.

The immediate blocker is `HandleGuard`, but Luna should also prove:

```text
no destructor
no noexcept move/copy operation
no finalizer-equivalent cleanup
```

can call `resolve()` or another throwing symbol-discovery path.

The existing `OwnedLogMessage` code already demonstrates the desired style: its
destructor is `noexcept` and contains its cleanup failure.

Do not reopen the accepted log-bridge lifetime design; use it as a cleanup
safety reference.

## 7.11 Required tests

Provide a resolver injection seam without altering the frozen ABI.

Required native tests:

### Destructor cleanup failure

```text
acquire fake owned handle
configure handle-release resolution failure
leave scope
process/test does not terminate
failure follows selected cleanup policy
```

### Primary error + cleanup failure

```text
operation throws primary error
guard cleanup also cannot resolve release
primary error remains observable
no std::terminate
```

### Move assignment

```text
target owns handle A
source owns handle B
cleanup failure injected for A
move-assignment path does not terminate
ownership outcome is deterministic
```

Prefer redesigning so cleanup cannot fail here rather than catching inside a
`noexcept` move assignment.

### Retained-session transaction

```text
release precondition/state failure
-> retained owner remains

successful release
-> owner erased exactly once
-> terminal/history reconciliation exactly once
```

### Nested temporary handles

Exercise representative:

```text
session
log/statistics
media information
history projection
FFplay lookup
```

to ensure all owning guards share the safe primitive.

## 7.12 Exit criterion

After successful bridge initialization, destruction or movement of an owning
native-handle guard must be incapable of throwing or terminating the process,
and explicit retained ownership must not be discarded before native release has
committed.

---

# 8. R40-F3 — Flutter Windows/Linux FFplay pixel buffers do not normalize the advertised source layout

**Severity:** Medium-High  
**Platforms:** Flutter Windows and Flutter Linux  
**Primary files:**

```text
flutter/windows/ffmpeg_kit_extended_flutter_plugin.cpp
flutter/linux/ffmpeg_kit_extended_flutter_plugin.cc
flutter/native/ (new shared conversion helper recommended)
```

## 8.1 The callback carries a pixel-format contract

The frozen generated Flutter binding documents the desktop frame callback as:

```text
pixels: RGBA8888 / four bytes per pixel
linesize: bytes per row
format: pixel format string, e.g. "rgba", "bgra", etc.
```

The format argument is real bridge data and is already consumed by other
platform implementations.

## 8.2 Apple and React Native Windows already normalize multiple layouts

The Flutter iOS/macOS bridges support:

```text
rgba
rgb0
bgra
bgr0
argb
abgr
```

and repair alpha for the `0` formats.

React Native Windows `ConvertToBGRA()` handles the same six layouts and honors
the source row stride.

That makes platform intent clear: the frame bridge must not assume every source
layout already matches the renderer's destination layout.

## 8.3 Flutter Windows copies source bytes without channel normalization

Frozen Windows callback:

```cpp
size_t row_bytes = static_cast<size_t>(linesize);
state->write_buf.resize(row_bytes * height);
memcpy(state->write_buf.data(), pixels, state->write_buf.size());

if (pixel_format && strcmp(pixel_format, "rgb0") == 0) {
  ... set byte 3 to 0xff ...
}
```

For all other layouts, the byte order is unchanged.

`CopyPixelBuffer()` gives those bytes to Flutter.

Flutter Windows' `ExternalTexturePixelBuffer` uploads
`FlutterDesktopPixelBuffer::buffer` with:

```text
GL_RGBA
```

Therefore the returned buffer must be RGBA byte order.

## 8.4 Flutter Linux has the same assumption

Linux copies:

```cpp
std::vector<uint8_t> frame(pixels, pixels + linesize * height);
```

and only patches `rgb0` alpha.

The resulting bytes are published to `FlPixelBufferTexture`.

Flutter's Linux API explicitly says:

```text
You must prepare your pixel buffer in RGBA format.
```

and its implementation uploads the returned bytes using:

```text
GL_RGBA
```

## 8.5 Concrete corruption by layout

### `bgra`

Source:

```text
B G R A
```

Published as if:

```text
R G B A
```

Red and blue are swapped.

### `bgr0`

Source:

```text
B G R 0
```

Windows/Linux do not repair its alpha because they only special-case `rgb0`.

Result:

```text
red/blue swapped
alpha remains 0
```

The video can appear transparent in addition to being color-swapped.

### `argb`

Source:

```text
A R G B
```

Published directly as RGBA.

All channels are displaced.

### `abgr`

Source:

```text
A B G R
```

Again published directly as RGBA.

### `rgba`

Correct.

### `rgb0`

Channel order is correct and existing alpha repair makes it usable.

## 8.6 Row stride is not canonicalized

Both bridges allocate/copy:

```text
linesize * height
```

but their Flutter pixel-buffer consumers are given only:

```text
width
height
pointer
```

There is no stride field in `FlutterDesktopPixelBuffer`, and
`FlPixelBufferTexture` likewise asks only for RGBA pointer + width + height.

If a source row ever contains padding:

```text
linesize > width * 4
```

the destination must be repacked row-by-row into:

```text
width * 4
```

before it is exposed to Flutter.

The current code preserves padding bytes in the middle of the linear buffer.

The frozen binding commonly documents `linesize == width*4`, so padding may not
occur in the current runtime's ordinary path. Review 40 does not rely on padded
stride to establish the finding; the multi-layout format defect is sufficient.
However, normalization should close the stride gap at the same bridge boundary.

## 8.7 Required remediation principle

Create one shared Flutter-native packed-frame converter whose output contract is:

```text
RGBA8888
destination stride = width * 4
alpha = 255 for rgb0/bgr0
```

Supported source layouts:

```text
rgba -> R G B A
rgb0 -> R G B 255
bgra -> R G B A
bgr0 -> R G B 255
argb -> R G B A
abgr -> R G B A
```

Inputs must be validated:

```text
pixels != nullptr
width > 0
height > 0
linesize >= width * 4
known supported format
overflow-safe byte-count calculation
```

Unknown layouts should fail closed/drop the frame with bounded diagnostic
behavior rather than silently interpreting unknown bytes as RGBA.

## 8.8 Windows integration

`OnFrameCallback()` should normalize into a tightly packed RGBA write buffer.

Then:

```text
write_buf/read_buf/render_buf
```

all carry one canonical pixel contract.

`CopyPixelBuffer()` remains simple and renderer-specific code no longer needs
format knowledge.

Preserve:

```text
callback-state mutex
Review 39 async texture retirement
latest-frame buffer swap
MarkTextureFrameAvailable
```

## 8.9 Linux integration

Normalize into a temporary/canonical RGBA frame before publishing into
`PixelBufferFrameStore`.

`PixelBufferFrameStore` should receive:

```text
byte_count == width * height * 4
```

and remain renderer-format agnostic.

Preserve:

```text
FrameNotificationCoalescer
GObject temporary callback refs
FlPixelBufferTexture ownership
release/reuse semantics
```

## 8.10 Required executable regression

Create a native converter test with visibly distinct channel values.

Example pixel:

```text
R = 0x11
G = 0x22
B = 0x33
A = 0x44
```

For every supported source layout, assert destination:

```text
11 22 33 expected-alpha
```

Required cases:

```text
rgba
rgb0
bgra
bgr0
argb
abgr
```

Also test:

```text
two rows with padded source stride
unknown format rejected
linesize < width*4 rejected
negative/invalid dimensions rejected
overflow-safe dimensions rejected
```

Then add thin Windows/Linux callback integration oracles proving that the
platform callback publishes only canonical RGBA bytes.

## 8.11 Exit criterion

The Flutter Windows and Linux texture paths must expose exactly the same
canonical RGBA visual result for every supported FFplay packed pixel format and
must never depend on source-row padding being absent.

---

# 9. Platform-native surfaces reviewed without another substantive finding

The closure pass also rechecked the following.

## Flutter Windows

Review 39's asynchronous `TextureVariant` retirement is present.

The texture callback state survives Flutter unregister completion, including
rollback and plugin destruction.

No new lifetime defect met the threshold beyond R40-F3's pixel-layout issue.

## Flutter Linux

Review 39's `FlPixelBufferTexture` migration is present.

The plugin no longer owns raw GL names.

`FrameNotificationCoalescer` and callback-held GObject references remain intact.

No new ownership issue met the threshold beyond R40-F3.

## Flutter Android

`SurfaceTextureEntry`, Java `Surface`, the explicitly acquired native-window
pointer, and the process-global FFplay surface owner have corresponding teardown
paths.

A stale plugin surface cannot clear the newer process-global owner.

No new threshold finding.

## Flutter iOS/macOS

The callback pair is resolved as a complete pair.

Owner replacement/unregister/drain ordering remains intact.

The Apple frame paths already normalize the supported packed pixel layouts.

CocoaPods and SwiftPM FFplay source copies are behaviorally aligned; their
differences are imports/formatting only.

No new threshold finding.

## React Native Windows FFplay view

Latest-owner replacement, callback drain, weak view dispatch, and packed-frame
conversion remain present.

R40-F1 concerns the native module method/error boundary, not the Fabric view.

## React Native Android FFplay view

The process-global weak-owner surface coordination remains synchronized.

Stale views do not clear a newer owner.

No new threshold finding.

## React Native iOS/tvOS/macOS FFplay views

The complete frame callback pair, latest owner, frame acceptance flag, callback
drain, and main-thread presentation ownership remain present.

The three TurboModule `OnLoad.mm` files differ only by platform labeling.

No new threshold finding.

## React Native log bridge

The accepted reusable log-bridge state/lifetime design remains intact.

`OwnedLogMessage` already catches release failure inside a `noexcept`
destructor, which is consistent with the cleanup direction required by R40-F2.

No new threshold finding.

---

# 10. Review 40 bridge-closure goals

| Goal | Required result |
| --- | --- |
| **R40-G1** | Replace React Native Windows cross-call/thread-local error reporting for asynchronous `REACT_METHOD`s with invocation-completion-bound error transport |
| **R40-G2** | Make shared React Native native-handle cleanup non-throwing by construction and make retained-handle release transactional |
| **R40-G3** | Normalize Flutter Windows/Linux FFplay frames into one tightly packed RGBA8888 contract before handing bytes to Flutter |
| **R40-G4** | Run focused native bridge regressions and affected local Windows → Android → Linux → Apple validation using only frozen local `0.11.2` artifacts |
| **R40-G5** | Perform a final platform-native bridge audit, reconcile evidence, freeze the exact wrapper SHA, and create one wrapper-only source snapshot |

The accompanying Luna plan expands these goals into implementation decision
gates, per-file guidance, behavior oracles, error/lifetime invariants, and final
closure criteria.

---

# 11. Review 40 closeout

```text
Wrapper source authority: VERIFIED
Outer artifact digest: VERIFIED
Embedded source archive: VERIFIED
SHA256SUMS: 1079/1079
Symlink state: VERIFIED (0)
Frozen native submodule provenance: VERIFIED
runtimeExecution: false

Native ABI separately downloaded for Review 40: NO
Native ABI re-reviewed: NO

Review scope: PLATFORM-NATIVE BRIDGE CLOSURE
Code review only: YES
Tests/builds/runtime executed during review: NO
Repository mutation during review: NO

Substantive findings: 3
Pedantic findings reported: 0
Procedural findings reported: 0
Documentation-only findings reported: 0

Native ABI source change required: NO

Closure status:
PLATFORM-NATIVE BRIDGE PROMOTION SHOULD WAIT FOR R40-F1..F3 REMEDIATION.

If the R40 remediation satisfies the explicit exit criteria and the final
platform-native audit finds no contradictory source, Review 40 is designed to be
the platform-native bridge closure milestone rather than the start of another
unbounded review cycle.
```
