# Review 39 — Flutter + React Native Platform-Native Code Review

**Project:** FFmpegKitExtended  
**Review type:** frozen-source platform-native code review; pedantic and procedural findings excluded  
**Date:** 2026-09-30  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Frozen wrapper source:** `0cc61d41906611f9118d8eb84a95647a7925b99d`  
**Snapshot workflow:** `36663896671`  
**Snapshot artifact:** `repo-source-snapshot-36663896671`  
**Artifact ID:** `11075422175`  
**Artifact digest:** `sha256:1e6ffe823ee20594f0b2ed3cf476956b3e494e313fc0f689abd78e235a4a5b5f`  
**Embedded `source.tar.gz` SHA-256:** `89776998f938540c87d33fc55d5cd9dc6d82f65350f2b21a93643cf86ece29d2`  
**Manifest:** **1,069/1,069 files verified**  
**Symlinks:** `0`  
**Submodule:** `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`  
**Native ABI/runtime:** `0.11.2`, frozen/read-only; not separately downloaded or re-reviewed

---

## 1. Review boundary

Review 39 uses only the exact final Review 38 wrapper source snapshot recorded in `.agent/TRACKER.md`.

The snapshot was obtained through the repository source-snapshot workflow, downloaded through the GitHub connector, and verified before review.

This pass intentionally narrows the review from the prior cross-platform wrapper reviews to **platform-native integration code**.

Reviewed production surfaces:

```text
Flutter
  flutter/windows/
  flutter/linux/
  flutter/android/
  flutter/ios/
  flutter/macos/
  flutter/native/

React Native
  react-native/cpp/
  react-native/windows/
  react-native/android/
  react-native/ios/
  react-native/appletvos/
  react-native/macos/
```

The Dart/TypeScript application/session layers were inspected only when required to understand a native boundary or user-visible consequence.

The frozen native ABI is not a Review 39 review surface. `libs/libffmpegkit`, FFmpeg, and the builders were not independently reviewed.

This was **code review only**:

- no Flutter/Dart tests;
- no Node tests;
- no C/C++/Objective-C/Java/Kotlin compilation;
- no platform builds;
- no browser/runtime smoke;
- no simulator/device execution;
- no interactive application execution;
- no hosted acceptance CI;
- no repository mutation.

Excluded from findings:

- style/naming/formatting;
- tracker/process/procedural issues;
- documentation-only drift;
- missing-test-only observations;
- speculative hardening without a reachable product effect;
- low-impact pedantry.

Framework source/documentation was consulted only to verify external embedder contracts necessary to judge the wrapper code.

---

## 2. Snapshot verification

The downloaded artifact exactly matched the tracker authority.

```text
Outer ZIP SHA-256:
1e6ffe823ee20594f0b2ed3cf476956b3e494e313fc0f689abd78e235a4a5b5f

Embedded source.tar.gz SHA-256:
89776998f938540c87d33fc55d5cd9dc6d82f65350f2b21a93643cf86ece29d2

snapshot_sha:
0cc61d41906611f9118d8eb84a95647a7925b99d

runtimeExecution:
false

recursive submodule:
b74da2c5d1e294b87d15d73a6687393729e932b3 libs/libffmpegkit

manifest:
1069/1069 verified

symlinks:
0
```

No native/builders snapshot was downloaded for Review 39.

---

## 3. Platform-native coverage

### Flutter Windows

Reviewed:

```text
flutter/windows/ffmpeg_kit_extended_flutter_plugin.cpp
flutter/windows/ffmpeg_kit_extended_flutter_plugin.h
flutter/windows/ffmpeg_kit_extended_flutter_plugin_c_api.cpp
flutter/native/ffplay_owner_coordinator.h
flutter/native/texture_registration_transaction.h
```

Primary concerns:

- external texture registration/unregistration;
- `TextureVariant` callback userdata lifetime;
- FFplay process-global owner replacement;
- producer callback drain;
- plugin destruction;
- registration rollback.

### Flutter Linux

Reviewed:

```text
flutter/linux/ffmpeg_kit_extended_flutter_plugin.cc
flutter/native/frame_notification_coalescer.h
flutter/native/ffplay_owner_coordinator.h
flutter/native/texture_registration_transaction.h
```

Primary concerns:

- `FlTextureGL` and OpenGL resource ownership;
- GL reset/reuse;
- GObject lifetime;
- idle callback temporary references;
- final plugin disposal;
- FFplay owner replacement.

### Flutter Android

Reviewed:

```text
flutter/android/src/main/kotlin/com/akashskypatel/ffmpeg_kit_extended_flutter/FfmpegKitExtendedFlutterPlugin.kt
flutter/android/src/main/kotlin/com/akashskypatel/ffmpeg_kit_extended_flutter/SurfaceOwnerCoordinator.kt
flutter/android/src/java/com/akashskypatel/ffmpegkit/FFplayKitAndroid.java
```

No new substantive finding met the Review 39 threshold.

### Flutter iOS/macOS

Reviewed the CocoaPods and SwiftPM native plugin implementations, especially FFplay callback ownership, texture registration, owner replacement, and callback drain.

No new substantive finding met the Review 39 threshold.

The prior exact-SDK distinction remains valid: macOS checks its documented registration-failure result; iOS does not incorrectly classify texture ID `0` as failure.

### React Native shared C++ bridge

Reviewed:

```text
react-native/cpp/FFmpegKitDynamicApi.cpp
react-native/cpp/FFmpegKitDynamicApi.h
react-native/cpp/FFmpegKitExtendedImpl.cpp
react-native/cpp/FFmpegKitExtendedImpl.h
react-native/cpp/LogBridgeRegistrationCoordinator.h
```

Primary concerns:

- dynamic symbol/runtime failures;
- exception transport;
- retained handle ownership;
- log bridge callback lifetime;
- history/session access;
- FFplay controls.

### React Native Windows

Reviewed:

```text
react-native/windows/FFmpegKitExtended/FFmpegKitExtended.cpp
react-native/windows/FFmpegKitExtended/FFmpegKitExtended.h
react-native/windows/FFmpegKitExtended/FFplayView.cpp
react-native/windows/FFmpegKitExtended/FFplayView.h
```

A high-severity error-boundary defect was established.

### React Native Android

Reviewed Java native integration and FFplay surface owner/teardown paths.

No new substantive finding met the threshold.

### React Native Apple

Reviewed iOS/tvOS/macOS FFplay view code and OnLoad native registration.

No new substantive finding met the threshold.

---

## 4. Executive disposition

The frozen Review 38 wrapper is **not platform-native code-review clean**.

| Finding | Severity | Platform | Summary |
| --- | --- | --- | --- |
| **R39-F1** | **High** | Flutter Windows | The plugin destroys its `TextureVariant` and callback-captured state immediately after calling the deprecated no-callback `TextureRegistrar::UnregisterTexture()` overload even though unregister is asynchronous. Flutter can retain callback `user_data` into freed memory during the unregister window. |
| **R39-F2** | **High** | React Native Windows | Every exception from the shared native adapter is converted to `RaiseFailFastException` / `std::terminate()`. Recoverable runtime, symbol, argument, session, and FFplay errors can therefore terminate the entire host process instead of becoming wrapper/JavaScript errors. |
| **R39-F3** | **Medium** | Flutter Linux | The custom `FlTextureGL` generates and owns an OpenGL texture name, but final GObject/plugin teardown deletes only the C++ state. The final `GLuint` is never retired when no later `populate` occurs. |

No finding requires a frozen native ABI source change.

---

# 5. R39-F1 — Flutter Windows frees external texture userdata before asynchronous unregister completion

**Severity: High**

### Frozen implementation

The plugin creates one `TextureState`. That object owns the `TextureVariant`.

The registered `PixelBufferTexture` callback captures a raw `TextureState*`:

```cpp
TextureState* state_ptr = state.get();

state->texture_variant = std::make_unique<flutter::TextureVariant>(
    flutter::PixelBufferTexture(
        [state_ptr](size_t w, size_t h)
            -> const FlutterDesktopPixelBuffer* {
          return CopyPixelBuffer(w, h, state_ptr);
        }));
```

Flutter receives `state->texture_variant.get()` in `RegisterTexture()`.

Therefore both of these must remain alive for as long as Flutter may invoke the external texture callback:

```text
TextureVariant / PixelBufferTexture
TextureState captured by PixelBufferTexture lambda
```

### Normal release

`ReleaseTextureState()`:

```text
move plugin texture_state_ to local owner
-> stop FFplay producer if still current owner
-> drain producer mutex
-> mark TextureState destroyed and clear buffers
-> UnregisterTexture(texture_id) using deprecated bool overload
-> local owner goes out of scope
-> TextureVariant destroyed
-> TextureState destroyed
```

The final comment explicitly assumes immediate destruction is safe.

It is not.

### Verified Flutter contract

Flutter 3.47.5's `TextureRegistrar` API declares:

```cpp
void UnregisterTexture(
    int64_t texture_id,
    std::function<void()> callback);
```

as **asynchronous**, and marks the bool overload used by this plugin as deprecated.

Flutter's registrar implementation also stores the `PixelBufferTexture*` as the external texture's `user_data` and calls `CopyPixelBuffer()` through that pointer.

The old bool overload simply calls the async unregister path with no completion callback and returns `true`; it does not wait for retirement.

### Reachable failure

```text
platform thread:
  request unregister
  destroy TextureVariant
  destroy TextureState

raster thread / engine:
  external texture retirement still in progress
  callback/user_data may still reference PixelBufferTexture
  PixelBufferTexture closure refers to destroyed TextureState
```

Potential outcomes include UAF, race, crash, or access through a destroyed callback object.

Stopping FFplay's producer callback does not solve this. Flutter's raster/external-texture callback is a second independent callback path.

### Owner-install rollback has the same bug

`InstallOwnerAfterTextureRegistration()` currently receives:

```cpp
[this](int64_t texture_id) {
  texture_registrar_->UnregisterTexture(texture_id);
}
```

If Flutter registration succeeds but FFplay owner installation fails:

```text
texture is engine-visible
-> unregister is requested
-> HandleCreateTexture returns error
-> local TextureState is destroyed
-> async external texture retirement is still pending
```

### Plugin destruction

A correct fix must not rely on capturing plugin `this` in the unregister completion callback because the plugin itself may be destructing.

The retirement owner must be self-contained.

### Required fix shape

Introduce a semantic registered-texture lifetime owner.

The invariant is:

```text
registered TextureVariant + callback-captured TextureState
remain alive
until Flutter invokes unregister completion
```

Recommended release sequence:

```text
1. detach plugin-visible current texture
2. stop FFplay producer only if this state still owns it
3. drain producer callback
4. mark state non-producing/destroyed
5. call UnregisterTexture(texture_id, completion)
6. retain state/variant in completion-owned retirement state
7. destroy state/variant only from completion
```

The completion callback must not dereference plugin `this`.

The same retirement mechanism must be used for:

- explicit release;
- replacement;
- owner-install rollback;
- plugin destruction.

It must also tolerate immediate completion and multiple overlapping retirements if a new registration can occur while an old unregister is pending.

### Required executable regression

Use a controllable fake `TextureRegistrar` that deliberately defers unregister completion.

Required assertions:

```text
registered state is alive
release requested
plugin no longer exposes it as active
FFplay producer stopped
unregister completion deferred
PixelBufferTexture callback object is still valid
state is not destroyed
completion invoked
state/variant destroyed exactly once
```

Repeat for rollback and plugin destruction.

A source regex is not sufficient.

### Exit criterion

No path may destroy a registered Windows `TextureVariant` or its callback-captured `TextureState` before Flutter confirms external texture unregistration.

---

# 6. R39-F2 — React Native Windows converts ordinary errors into host-process termination

**Severity: High**

### Frozen Windows boundary

The Windows native module implements:

```cpp
[[noreturn]] void failFast(
    const char* method,
    const char* message) noexcept {
  ...
  RaiseFailFastException(nullptr, nullptr, 0);
  std::terminate();
}
```

`invokeVoid()` and `invoke()` wrap shared-adapter calls:

```cpp
try {
  ...
} catch (const std::exception& error) {
  failFast(method, error.what());
} catch (...) {
  failFast(method, "non-standard exception");
}
```

Nearly every native method routes through these wrappers.

### Shared adapter throws for normal operational conditions

`FFmpegKitDynamicApi.cpp` throws ordinary C++ exceptions for recoverable states, including:

```text
libffmpegkit.dll unavailable
required symbol unavailable
empty argument list
native session creation failure
session ID not found
FFplay target not found
session is not FFplay
```

These are application/runtime errors, not evidence that the host process is corrupted.

### Windows changes the semantic meaning

On Windows:

```text
shared adapter throws ordinary runtime/argument error
-> native module catches it
-> RaiseFailFastException
-> std::terminate
-> React Native host process dies
```

No wrapper or JavaScript code gets a chance to handle or report the failure.

### Review 38 interaction

Review 38 intentionally made cancellation state-read failure recoverable:

```text
record durable cancellation intent
-> state lookup may fail
-> caller observes failure
-> future execution remains fail-closed
```

That design cannot operate on Windows when `getSessionState()` failure terminates the process.

### Required direction

Keep the Windows C++ native boundary `noexcept`.

Do **not** let arbitrary C++ exceptions escape.

Instead:

```text
catch adapter exception
-> translate to RNW-supported JS-visible error/result transport
-> return normally across noexcept boundary
```

Inventory every Windows method and classify its proper error channel.

#### Async/native actions

Where the exact RNW generated contract and high-level API are already asynchronous, prefer a Promise rejection or equivalent supported RNW failure channel.

#### Sync getters

Do not replace an exception with ambiguous `0`, `false`, or `""` where those are valid results.

Use a structured error/result or a provably unambiguous existing sentinel that the high-level wrapper deterministically converts to an error.

#### True invariant corruption

A narrowly scoped fail-fast path can remain only for genuinely unrecoverable internal corruption, not ordinary runtime/configuration/user/session failures.

### Must preserve shared-spec compatibility

The TypeScript TurboModule spec is shared across platforms.

Before changing method signatures, inspect the exact generated RNW contract.

Do not blindly convert all sync methods to Promises.

Do not preserve a sync signature by inventing misleading defaults.

### Required behavioral tests

Inject deterministic shared-adapter failures without touching the frozen ABI.

At minimum:

```text
initialize/runtime unavailable
missing required symbol
invalid create arguments
session state missing
FFplay missing/wrong session
```

For each:

```text
native boundary remains noexcept
host process remains alive
caller receives meaningful error
```

Also verify happy-path return values are unchanged.

Add a supplemental source-contract test that rejects blanket `RaiseFailFastException` / `std::terminate()` use in normal operational dispatch.

### Exit criterion

An ordinary runtime/wrapper failure on React Native Windows must be caller-observable without terminating the application process.

---

# 7. R39-F3 — Flutter Linux does not retire the final custom GL texture

**Severity: Medium**

### Frozen custom texture state

`FfkitGlTexture` owns a `TextureState` containing:

```text
GLuint gl_texture_id
bool gl_initialized
bool needs_gl_reset
```

During `FlTextureGL::populate`:

```cpp
if (needs_reset || !state->gl_initialized) {
  if (state->gl_initialized && state->gl_texture_id) {
    glDeleteTextures(1, &state->gl_texture_id);
  }

  glGenTextures(1, &state->gl_texture_id);
  ...
  state->gl_initialized = true;
}
```

This handles reuse correctly: a later render can delete the previous GL texture and create a replacement.

### Final disposal is different

`release_texture()` intentionally keeps the Flutter texture registration for reuse and sets:

```text
destroyed = true
needs_gl_reset = true
```

On future `populate`, the old `GLuint` is deleted.

During final plugin disposal, however, the texture is unregistered and the `FfkitGlTexture` GObject is unref'd.

Its finalizer says:

```cpp
// GL cleanup is handled by populate or engine. Safe to delete state.
delete self->state;
```

No `glDeleteTextures()` occurs there.

When final teardown happens after at least one populated frame:

```text
gl_texture_id != 0
no future populate
state deleted
GLuint never explicitly deleted
```

### Why the engine is not the owner of this custom GL name

The wrapper itself calls `glGenTextures()` and returns the generated name in the external texture descriptor.

Flutter's standard Linux `FlPixelBufferTexture` implementation explicitly deletes its internally generated `GLuint` in its dispose handler.

That standard implementation is strong evidence for ownership: generated GL names need explicit retirement by the object that created them.

### Consequence

The final GL object can remain allocated until context/share-group destruction.

This matters for:

- repeated Flutter engine creation/destruction in one process;
- dynamic plugin/engine detach/reattach;
- long-running desktop embedding hosts.

### Context safety

Do not simply add `glDeleteTextures()` to an arbitrary GObject finalizer without proving a valid current GL context.

The existing code deliberately performs GL mutation in `populate`, a render-context callback.

A correct fix must close resource ownership and context correctness together.

### Preferred remediation options

#### Option A — migrate to `FlPixelBufferTexture`

The FFplay producer already writes CPU RGBA frame buffers.

If compatible with performance and format requirements, use Flutter's pixel-buffer texture abstraction and let Flutter's standard texture implementation own the GL upload/name lifecycle.

Preserve:

- latest-frame buffering;
- width/height correctness;
- RGBA format;
- synchronization;
- `FrameNotificationCoalescer`;
- frame-available signaling.

This is preferred if it satisfies the product's rendering/performance requirements.

#### Option B — keep `FlTextureGL` with explicit render-context retirement

If the custom GL texture is required, create a supported lifecycle that guarantees:

```text
last generated GLuint deleted exactly once
while a valid Flutter GL context is current
before TextureState destruction
```

Do not invent an unsupported engine callback.

### Required regression

Add a small GL operation seam or deterministic native helper.

Verify:

```text
initial populate:
  gen=1 delete=0

release + reuse:
  delete old once
  generate replacement once

final dispose:
  delete current texture once

release + reuse + final:
  total generated == total deleted

never populated:
  no delete of texture 0

queued idle callback:
  GObject temporary ref remains safe during teardown
```

The test must also document why the real production deletion boundary has a valid GL context.

### Exit criterion

Every GL texture generated by the Linux wrapper has an exactly-once context-safe deletion path, including final lifecycle where no later `populate` runs.

---

# 8. Retained non-findings

No additional substantive issue met the Review 39 threshold in the following reviewed areas:

- Flutter Android latest-successful FFplay surface owner and stale-plugin teardown;
- Flutter iOS/macOS FFplay callback/userdata drain and owner replacement;
- Flutter Linux `FrameNotificationCoalescer` and queued idle GObject reference safety;
- React Native Android process-global FFplay surface ownership;
- React Native iOS/tvOS/macOS complete callback-pair resolution and stale-view deactivation;
- React Native Windows FFplayView active-owner replacement and callback drain;
- accepted React Native log-bridge retirement behavior.

R39-F3 does not reopen Linux frame-coalescing correctness; it is specifically the final GL resource lifetime.

R39-F2 concerns the general Windows native-module exception boundary, not the FFplayView callback owner.

---

# 9. Review 39 remediation goals

| Goal | Required result |
| --- | --- |
| **R39-G1** | Make Flutter Windows external-texture retirement asynchronous-lifetime-safe for release, replacement, rollback, and plugin teardown |
| **R39-G2** | Replace React Native Windows blanket fail-fast operational error handling with a normal caller-visible error/result transport while keeping the native boundary `noexcept` |
| **R39-G3** | Give Flutter Linux every generated GL texture name an exactly-once context-safe final deletion path |
| **R39-G4** | Run focused native regressions and affected local Windows → Android → Linux → Apple validation using existing frozen `0.11.2` artifacts only |
| **R39-G5** | Reconcile evidence, freeze exact wrapper SHA, and create one wrapper-only source snapshot |

---

# 10. Closeout

```text
Wrapper snapshot authority: VERIFIED
Outer artifact digest: VERIFIED
Embedded source archive: VERIFIED
Wrapper manifest: 1069/1069
Symlink state: VERIFIED (0)
Frozen submodule provenance: VERIFIED

Native ABI separately downloaded for Review 39: NO
Native ABI re-reviewed: NO

Review scope: PLATFORM-NATIVE WRAPPER CODE
Code review only: YES
Tests/builds/runtime executed during review: NO
Repository mutation during review: NO

Substantive findings: 3
Pedantic findings reported: 0
Procedural findings reported: 0
Documentation-only findings reported: 0

Native ABI source change required: NO

Promotion unchanged:
NOT RECOMMENDED before R39-F1 and R39-F2 are corrected and R39-F3 has a deterministic final GL-resource retirement path.
```
