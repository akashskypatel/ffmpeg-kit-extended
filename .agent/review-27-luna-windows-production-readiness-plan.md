# Review 27 — Luna Cross-Platform Production-Readiness Plan

**Project:** FFmpegKitExtended  
**Date:** 2026-09-23  
**Audience:** Luna  
**Primary wrapper repository:** `akashskypatel/ffmpeg-kit-extended`, branch `dev-wasm`  
**Native/builder repository:** `akashskypatel/ffmpeg-kit-builders`, branch `dev`  
**Review baseline:** exact Review 26 wrapper source snapshot at `ebb2b055aa9e1841c73dd82a89c1c8aab5fbc045` and frozen native source `625c3452ee3c93fb5d701bb6546726940b88d014`  
**Native ABI/runtime version:** `0.11.2`  
**Implementation scope:** fix the Review 27 defect classes across every affected Flutter/React Native source path in one pass  
**Executable validation scope for the current agent:** Windows, Linux/WSL, Android  
**Explicitly deferred validation scope:** all Apple builds/tests/runtime validation: iOS, iOS Simulator, macOS, Apple tvOS, Apple tvOS Simulator, CocoaPods/Xcode integration  
**Validation policy:** use locally packaged current native ABI bundles; do not use hosted CI or remotely built old native ABI bundles as acceptance evidence  
**Finding policy:** only functional code defects are remediation goals. Do not reopen intentional release/checksum policy, accepted sanitizer findings, provenance bookkeeping, or unrelated historical issues.

**Apple local-binary handoff:** when the deferred Apple implementation/validation begins on the MacBook Air, update the Flutter example `hooks.user_defines.ffmpeg_kit_extended_flutter` Apple overrides and the React Native example `ffmpeg-kit-extended.config.json` Apple overrides to the locally built archives under `/Users/akash/Projects/ffmpeg-kit-builders/prebuilt`. Use only archive files confirmed present after the builder completes (including their exact SHA-256 values in the tracker); do not fall back to hosted releases, remotely staged old binaries, or a Windows/WSL path for Apple validation. The current Review 27 pass must leave Apple validation deferred until that handoff is available.

---

## Review 26 prerequisite

**PASS. Review 27 may proceed.**

Review 26 fixed the process-global React Native structured-log registration ownership bug and froze the wrapper at:

```text
wrapper SHA:
ebb2b055aa9e1841c73dd82a89c1c8aab5fbc045

wrapper tree:
0b2313880b271086ec2b4c6276ac99521148fcda

frozen native source:
625c3452ee3c93fb5d701bb6546726940b88d014
```

Independent exact-snapshot verification before this Review 27 audit passed:

```text
node --test react-native/tests/native-bridge-lifetime.test.js
  3/3 passed

g++ -std=c++20 -pthread -Wall -Wextra -Werror \
  -I react-native/cpp \
  react-native/tests/native/log_bridge_registration_coordinator_test.cpp \
  -o <temp>/coordinator_test

<temp>/coordinator_test
  exit 0
```

Do not regress Review 26's latest-successful-owner structured-log registration semantics.

---

# Tracker

| Goal | Severity | Platforms / wrappers | Objective | Functional finding | Luna mode | Exit gate |
|---|---|---|---|---|---|---|
| **R27-P1** | **High** | Flutter Android/Linux/Windows/iOS; RN Windows + resolver metadata | Replace broad architecture aliases with the actual frozen native platform matrix | Flutter accepts Android x86, Linux arm64, Windows arm64 and iOS x64 even though the frozen builder does not produce those targets; RN constructs nonexistent Windows/Linux arm64 bundle names | **Think** | Unsupported architecture requests fail before override/download/staging; supported platform mappings match the frozen builder; Apple source is corrected but Apple build/runtime validation is deferred |
| **R27-P2** | **High** | React Native Windows | Make local Windows runtime staging content-fresh and exact | Same-path changed local ZIPs can reuse old extraction; staging can retain removed DLLs; malformed/duplicate DLL layouts are flattened or accepted | **Think** | Current selected runtime bytes fully determine the staged DLL set; exactly one `libffmpegkit.dll`; same-path updates refresh; stale DLLs disappear |
| **R27-P3** | **Critical** | Flutter Windows/Linux/Android/iOS/macOS | Give every process-global FFplay video target a process-global wrapper owner | Flutter desktop/Apple frame callback and Android ANativeWindow are process-global, but ownership is local to a plugin instance or Dart isolate; stale engine teardown can clear a newer engine's target | **Think** | Latest successful high-level Flutter video target owns the native process-global output; stale engine/plugin/surface teardown cannot clear a newer owner; current owner still releases safely |
| **R27-P4** | **High** | Flutter Windows/Linux/iOS/macOS; RN Windows + Apple source | Make FFplay frame-API discovery retryable, complete and fail-closed | Flutter Windows/Linux permanently cache failed discovery; Flutter Apple resolves once and can return a live-looking texture without callback; RN Windows independently caches function pointers; RN Apple activation does not require the complete register/unregister pair | **Think** | A failed early lookup does not poison future initialization; no callback is installed without the complete required API; no dead texture/view is reported as usable |
| **R27-P5** | **High validation gate** | Windows + Linux/WSL + Android | Run the current agent's complete executable platform matrix | P1–P4 touch platform-specific artifact, FFplay ownership and loading behavior and require real current-source runtime evidence | **Think** for failures; **Instant** for established commands | Flutter/RN Windows, Flutter Linux, and Flutter/RN Android build/runtime gates pass against local `0.11.2` bundles; all new regressions pass |
| **R27-P6** | **Deferred validation gate** | iOS/iOS Simulator/macOS/tvOS/tvOS Simulator | Record Apple source remediation now and defer all Apple build/runtime validation | The same Flutter owner/resolution classes reach Apple source; RN Apple needs complete-pair activation hardening, but the current Windows agent cannot validate Apple toolchains/runtime | **Think for source review only** | Apple source changes are isolated and documented; **no Apple platform is declared validated or production-ready** until the later Apple validation review |
| **R27-P7** | **Closeout** | All reviewed wrappers | Reconcile docs/tests/tracker and freeze one exact source | Final supported architecture, FFplay ownership, resolver recovery and staging behavior must match the implementation | **Instant** after P1–P6 source work | Windows/Linux/Android production gates are green; Apple is explicitly source-remediated/validation-deferred; final source/tree are clean and frozen |

---

# 1. Exact review authority

Use the Review 26 source snapshot, not a later inferred branch state, as the audit baseline.

## Wrapper

```text
repository:  akashskypatel/ffmpeg-kit-extended
branch:      dev-wasm
source SHA:  ebb2b055aa9e1841c73dd82a89c1c8aab5fbc045
tree SHA:    0b2313880b271086ec2b4c6276ac99521148fcda
workflow:    35943439201
artifact:    review26-wrapper-source-35943439201
artifact ID: 10786006110
```

Downloaded snapshot metadata:

```text
snapshot_sha:       ebb2b055aa9e1841c73dd82a89c1c8aab5fbc045
archive_sha256:     9fe7de5c18269de2a97707c7a8e86b066dfd420a39d9d10cb61a7259e9ca55b5
file_count:         1044
byte_count:         27057739
include_submodules: true
runtimeExecution:   false
```

## Native/builder

Frozen native product source:

```text
625c3452ee3c93fb5d701bb6546726940b88d014
```

The frozen builder's actual architecture matrix is:

```text
Linux:                x86_64
Windows:              x86_64
Android:              aarch64, armv7a, x86_64
iOS:                  aarch64
iOS Simulator:        aarch64
Apple tvOS:           aarch64
Apple tvOS Simulator: aarch64
macOS:                aarch64, x86_64
Wasm:                 wasm32
```

The wrapper must not advertise/select native targets outside that matrix.

---

# 2. Cross-platform audit of the four original Windows issue classes

## Audit result matrix

| Issue class | Flutter Windows | Flutter Linux | Flutter Android | Flutter iOS/macOS | RN Windows | RN Android | RN iOS/macOS/tvOS | RN Web |
|---|---|---|---|---|---|---|---|---|
| **Architecture selection exceeds native builder support** | **YES** — arm64 accepted | **YES** — arm64 accepted | **YES** — ia32/x86 accepted | **YES for iOS** — x64 accepted although frozen iOS + simulator artifacts are arm64-only; macOS arm64/x64 is valid | **YES** — arm64 accepted | Normal AAR path is architecture-universal; no equivalent runtime selection bug in actual Gradle path | Podspec selects per-platform universal XCFramework rather than per-arch asset; no equivalent current artifact filename bug | N/A |
| **Same-path local archive cache / mixed staged binaries** | Flutter generic hook already hashes local file changes and invalidates extraction | Same generic Flutter behavior | Android AAR handled by generic Flutter local-file sync / direct ABI extraction | Same generic Flutter behavior | **YES** | Local AAR is consumed directly; no wrapper extraction/staging cache of this form | Local override is intentionally non-cacheable and destination is rebuilt | Local ZIP extracts into a fresh temporary root and target is replaced |
| **Process-global FFplay target cleared by stale wrapper instance** | **YES** | **YES** | **YES in multi-engine/isolate overlap** — native ANativeWindow is process-global but Dart `_currentNativeWindowPtr` is isolate-local | **YES** — frame callback is process-global and plugin instance release is unconditional | Existing process-global active-view guard: **NO** | Existing static process-global `activeOwner`: **NO** | Existing coordinator/view identity guard: **NO** | Different Wasm callback model; Review 25 behavior remains authoritative |
| **Frame API resolution permanently fails / installs partial API / reports dead target** | **YES** — `std::call_once` | **YES** — `g_symbols_resolved=true` after first miss | N/A — JNI/FFI direct API | **YES source path** — dlsym is captured at plugin registration and texture creation still succeeds when unavailable | **YES** — static function-local result caches first lookup | N/A | Resolver retries, but activation currently needs only register; require complete pair before activation | N/A |

---

# 3. Findings not expanded beyond their actual scope

## React Native Windows staging remains Windows-specific

Do not create copies of P2 for platforms whose current code already avoids the defect.

### Flutter local archive path

The generic hook already:

1. hashes the current local source file;
2. hashes the cached copy;
3. copies when content changes;
4. invalidates the extraction root when the cached bytes change;
5. extracts through a temporary root.

Do not replace that working behavior while fixing RN Windows.

### React Native Web

For a local ZIP:

```text
current local ZIP
-> fresh temporary extraction directory
-> exact runtime pair discovery
-> target directory removed/recreated
-> current files copied
```

Do not create a new cache layer merely for consistency.

### React Native Android

The local Android override is used directly as an AAR dependency.

Do not copy it into the Windows runtime staging design.

### React Native Apple

Local overrides are non-cacheable in the current podspec prepare contract and the destination is rebuilt.

Do not change that behavior under P2.

---

# 4. R27-P1 — Replace architecture aliases with the frozen native platform matrix

## Severity

**High**

## Objective

Architecture acceptance must be based on:

```text
platform + architecture
```

not a generic mobile/desktop alias.

Reject unsupported native targets before:

- user override acceptance;
- official artifact URL construction;
- local artifact copying;
- download;
- extraction;
- CodeAssets emission;
- PowerShell staging;
- MSBuild/CMake/Gradle/native link work.

---

## 4.1 Flutter — current defects

Current helper behavior includes:

```text
Android ia32 -> x86
Linux arm64 -> arm64
Windows arm64 -> arm64
iOS x64 -> x86_64
```

All four contradict the frozen builder matrix.

The current test suite even asserts several of these unsupported mappings as valid.

---

## 4.2 Flutter — required platform-specific mapping

Replace generic broad helpers with explicit semantic helpers.

Recommended contract:

```dart
String androidAbiForArchitecture(Architecture architecture) {
  arm    -> armeabi-v7a
  arm64  -> arm64-v8a
  x64    -> x86_64

  ia32 and every other architecture -> throw
}

String iosArtifactArchitecture(Architecture architecture) {
  arm64 -> arm64
  everything else -> throw
}

String macosArtifactArchitecture(Architecture architecture) {
  arm64 -> arm64
  x64   -> x86_64
  everything else -> throw
}

String linuxArtifactArchitecture(Architecture architecture) {
  x64 -> x86_64
  everything else -> throw
}

String windowsArtifactArchitecture(Architecture architecture) {
  x64 -> x86_64
  everything else -> throw
}
```

Exact function names may differ, but names must describe the platform semantics.

Do not keep one:

```text
desktopArtifactArchitecture
```

if its accepted set differs between Linux and Windows in the future.

Do not keep one:

```text
appleArtifactArchitecture
```

if iOS and macOS have different accepted sets.

---

## 4.3 Flutter — validation routing

Required:

```text
OS.android -> android helper
OS.iOS     -> iOS helper
OS.macOS   -> macOS helper
OS.linux   -> Linux helper
OS.windows -> Windows helper
```

This validation must happen before config/override resolution.

A local override must not bypass unsupported-target rejection.

---

## 4.4 Flutter — artifact naming

Use the same platform-specific helper for artifact naming that validation uses.

Avoid:

```text
validate with helper A
name bundle with helper B
```

that can drift.

For Android, the official AAR filename remains architecture-universal. The target architecture still must be validated before AAR extraction because the hook later selects one `jni/<abi>` directory.

---

## 4.5 Flutter tests executable now

Run on the current Windows agent.

### Android

Accepted:

```text
arm
arm64
x64
```

Rejected:

```text
ia32
```

and every non-supported architecture.

Explicitly prove:

```text
Architecture.ia32
does not reach AAR/artifact resolution
```

### Linux

Accepted:

```text
x64 -> x86_64
```

Rejected:

```text
arm64
```

before local override or default artifact construction.

### Windows

Accepted:

```text
x64 -> x86_64
```

Rejected:

```text
arm64
```

before override/artifact construction.

### macOS/iOS source contract

Implement:

```text
iOS: arm64 only
macOS: arm64 + x64
```

Do not execute Apple platform tests in Review 27.

A host-neutral Dart unit test of the pure architecture helper is acceptable because it does not invoke an Apple build/toolchain. However, per user direction, do not present such a helper test as Apple platform validation.

---

# 5. React Native architecture correction

## 5.1 Windows

Current resolver accepts:

```text
windows + arm64
```

and constructs:

```text
bundle-<type>-windows-arm64-shared-<license>.zip
```

even though the Windows projects and frozen builder are x64-only.

Fix exactly as the prior Windows Review 27 plan required.

`prepare-windows-runtime.ps1` must stop advertising `arm64` as a supported configuration.

---

## 5.2 Linux resolver metadata

The resolver currently produces, for example:

```text
platform=linux
architecture=arm64

-> bundle-video_hw-linux-arm64-shared-small-lgpl.zip
```

The frozen builder supports only:

```text
linux-x86_64
```

If Linux remains a recognized resolver platform, constrain its architecture metadata to x86_64.

Important:

There is **no native React Native Linux implementation in this repository**.

Do not create a React Native Linux build target or declare React Native Linux support.

This is resolver correctness only.

---

## 5.3 Android resolver metadata

The normal React Native Gradle AAR path does not pass a target architecture to the resolver and consumes one multi-ABI AAR.

Do not redesign Gradle artifact selection under P1.

If the resolver accepts an explicitly supplied Android architecture, align aliases with the AAR's actual frozen native ABI set:

```text
arm64 / aarch64        -> arm64
armv7a / armeabi-v7a   -> armv7a
x64 / x86_64           -> x86_64
```

Do not add x86/ia32 because the frozen builder does not produce it.

Leaving `architecture=null` for the normal universal-AAR call is valid.

---

## 5.4 Apple resolver metadata

The CocoaPods path selects one per-platform XCFramework artifact, not a per-architecture filename.

Do not change the Apple artifact filename scheme.

If callers explicitly provide architecture metadata, validate it against the frozen source:

```text
ios        -> arm64
appletvos  -> arm64
macos      -> arm64 or x86_64
```

This source correction is included now.

Apple Pod/Xcode validation is deferred.

---

## 5.5 React Native host-neutral tests

Run now:

```text
Windows x64 -> success
Windows arm64/aarch64 -> fail before override selection

Linux x64 -> success
Linux arm64/aarch64 -> fail before artifact construction

Android explicit arm64 -> valid metadata
Android explicit armv7a -> valid metadata
Android explicit x86_64 -> valid metadata
Android explicit x86/ia32 -> fail

iOS explicit arm64 -> valid metadata
iOS explicit x64 -> fail

tvOS explicit arm64 -> valid metadata
tvOS explicit x64 -> fail

macOS arm64/x64 -> valid metadata
```

These are Node resolver tests only.

They do not count as Apple platform build/runtime evidence.

---

# 6. R27-P2 — React Native Windows staging freshness and coherence

**This goal remains Windows-specific.**

Preserve the implementation guidance from the original Review 27 plan, with the following required properties.

## 6.1 Same-path local ZIP freshness

For local archive overrides, extraction identity must include current bytes.

Use at least:

```text
canonical path + SHA-256(current file bytes)
```

A path-only marker is insufficient.

Test:

```text
same runtime.zip path
A bytes -> stage
overwrite runtime.zip with B bytes
-> stage again
-> B must be active
```

---

## 6.2 Exact staging projection

The dedicated MSBuild staging directory must be rebuilt from the selected runtime manifest.

Do not selectively overwrite old contents.

Invariant:

```text
staged DLL basename set
==
validated DLL basename set from current selected runtime
```

---

## 6.3 Runtime manifest rules

Before staging:

```text
find *.dll recursively
compare target basenames case-insensitively
reject duplicate flattened basenames
require exactly one libffmpegkit.dll
sort deterministic
```

Reject:

```text
zero libffmpegkit.dll
multiple libffmpegkit.dll
a/foo.dll + b/foo.dll
```

---

## 6.4 Real PowerShell regression

Mandatory on Windows:

```text
same-path changed ZIP
removed dependency disappears
missing main DLL fails
duplicate main DLL fails
duplicate flattened basename fails
local directory mutation refreshes
```

Then run the actual x64 React Native Windows Release build and compare the deployed/staged DLL set with the validated runtime manifest.

---

# 7. R27-P3 — One process-global Flutter FFplay owner across every native video path

## Severity

**Critical**

## Common semantic rule

Use the same invariant everywhere:

> **The most recent successful high-level Flutter video-target binding owns the process-global FFplay output. Only that exact owner may clear or unregister it.**

A stale engine, plugin, texture or surface may release its local resources.

It may not clear a newer process-global FFplay target.

Do not create a restoration stack.

If B replaces A:

```text
A -> B
```

then B owns.

When B leaves:

```text
native target -> none
```

Do not restore A automatically.

---

# 8. Flutter Windows and Linux frame-callback ownership

Both platforms register the same process-global native frame callback.

Current release/destruction is local-instance based and unconditional.

Use an owner coordinator keyed by the native callback userdata identity.

Recommended owner tokens:

```text
Windows: TextureState*
Linux:   FfkitGlTexture* or TextureState*
```

Prefer a small platform-neutral header-only C++ coordinator if it can be included safely from both plugin builds without introducing cross-platform build-system coupling.

Example semantic responsibility:

```cpp
install(owner, nativeInstall)
uninstallIfOwned(owner, nativeUninstall)
isOwner(owner)
```

Required behavior:

```text
A install -> owner A
B install -> owner B
A stale release -> native unregister call count 0
B release -> unregister once, owner null
```

The native unregister operation drains any in-flight frame callback through the native FFplay mutex.

Only destroy the current owner's callback userdata after that unregister/drain completes.

A stale non-owner state can skip global unregister and release local texture state normally after B's successful replacement guarantees native no longer points at A.

---

# 9. Flutter Android process-global surface ownership

## Functional defect

The native FFplay ANativeWindow is process-global:

```text
g_android_native_window
g_owned_window
```

The high-level Flutter Dart guard is:

```dart
static int _currentNativeWindowPtr
```

but Dart statics are isolate-local.

Two Flutter engines normally have different Dart isolates.

Therefore this can occur:

```text
Engine A isolate:
  A.bindToFFplay()
  isolate A thinks current pointer = A

Engine B isolate:
  B.bindToFFplay()
  native process-global target = B
  isolate B thinks current pointer = B

Engine A:
  A.release()
  isolate A still sees A as its "current" pointer
  clearAndroidSurfaceIfMatches(A) calls global clear

Result:
  B loses FFplay video output
```

The high-level surface API therefore has the same ownership defect as Windows/Linux, even though it appears guarded in a single isolate.

---

## 9.1 Move high-level ownership into the Android process

The process-global ownership authority should live in Android plugin/JVM state shared by all Flutter engines.

Do not use Dart-isolate static state as the final owner authority.

Recommended structure in the Android Flutter plugin:

```text
SurfaceState
  texture entry
  android Surface
  nativeWindowPtr
  textureId

process-global static/companion coordinator
  lock
  active SurfaceState identity
```

Use object identity, not texture ID alone, because different Flutter engines can produce colliding texture IDs.

---

## 9.2 Add owner-aware high-level bind

Add a platform-channel method such as:

```text
bindSurface(textureId)
```

The Android plugin:

1. finds this engine's `SurfaceState`;
2. locks the process-global coordinator;
3. calls `FFplayKitAndroid.setAndroidSurface(surface)`;
4. commits that exact `SurfaceState` as process-global owner only after native set succeeds;
5. returns success.

The current `FFplayKitAndroid.setAndroidSurface(Surface)` JNI path already shares the correct single retained native ANativeWindow authority.

Use it.

Do not add a new native ABI function for ownership.

---

## 9.3 Owner-aware release

When a high-level Flutter surface releases:

```text
if process-global owner === this SurfaceState:
    FFplayKitAndroid.setAndroidSurface(null)
    owner = null

release this state's nativeWindowPtr ref
release Surface
release Flutter texture entry
```

For a stale non-owner:

```text
do not clear native process-global surface
release only local resources
```

The same logic must run during engine detach.

---

## 9.4 Dart API

`FFplayAndroidSurface.bindToFFplay()` currently performs a synchronous Dart FFI process-global set.

The safe high-level implementation should route binding through the process-global Android plugin owner.

Because a MethodChannel call is asynchronous, update the high-level method to:

```dart
Future<void> bindToFFplay()
```

and update examples/docs to:

```dart
await surface.bindToFFplay();
```

Calling a Future-returning method as a statement remains syntactically possible, but maintained examples must await it so playback does not race the bind.

`release()` is already asynchronous and should let the Android plugin own conditional global clear.

Do not retain the old high-level Dart `clearAndroidSurfaceIfMatches()` as the ownership authority.

The low-level public `FFplayKitAndroid` FFI API may remain available for advanced/manual use, but document that direct low-level calls manipulate one process-global native target and the caller owns coordination.

---

## 9.5 Android unit oracle

Extract the owner state machine into a testable Kotlin/Java helper that does not require a real `Surface`.

Use owner tokens + fake setter.

Mandatory:

```text
A bind
B bind
A stale release
-> native target B

A bind
A release
B bind
A stale engine detach
-> B

B current release
-> native clear

10,000 owner replacements/releases
-> bounded state, no stale clear
```

Run on the Windows Android/Gradle environment.

---

## 9.6 Android runtime gate

On emulator/device:

```text
create Flutter surface
await bind
start FFplay
video visible / dimensions advance
release
```

Then test two distinct high-level surface states:

```text
A bind
B bind
A release
B continues receiving video
B release
native target cleared
```

If practical, create two Flutter engines for a direct cross-isolate oracle.

If a two-engine harness is not practical in this review:

- the process-global owner helper test is mandatory;
- a single-engine two-surface runtime test is mandatory;
- record the multi-engine runtime case as not directly executed.

Do not claim a two-engine runtime pass without one.

---

# 10. Flutter Apple frame ownership — implement now, build/test later

The iOS and macOS `FfplayKitPlugin` implementations also use one native process-global frame callback.

Each plugin instance currently clears that global callback during local texture release/dealloc.

Apply the same latest-successful-owner rule now.

Use a process-global Objective-C synchronization authority.

Suitable owner identity:

```text
the exact retained texture userdata pointer
```

or another unique per-texture token.

Required:

```text
install A -> owner A
install B -> owner B
A stale release/dealloc -> no global unregister
B release -> unregister + owner null
```

Preserve:

- strong userdata retention through callback lifetime;
- texture invalidation/drain;
- Flutter texture unregister;
- ARC balance.

Do not attempt an Apple build, `pod install`, Xcode compile, simulator run or macOS runtime gate in Review 27.

Record Apple validation as deferred under P6.

---

# 11. React Native FFplay ownership audit result

Do **not** add a new React Native owner-remediation goal.

The exact Review 26 source already uses process-global owner authorities.

## Android

`FFplayTextureView` has:

```text
static SURFACE_LOCK
static activeOwner
```

Release clears the native surface only when:

```text
activeOwner == this
```

Preserve it.

## iOS/macOS/tvOS

The view uses a shared `FFplayFrameCoordinator`.

Deactivate returns without native unregister when:

```text
coordinator.view != self
```

Preserve it.

## Windows

The view uses:

```text
g_registrationMutex
g_activeView
```

Destructor unregisters only when:

```text
g_activeView == this
```

Preserve it.

Review 27 tests should guard these existing semantics while changing frame API resolution.

---

# 12. R27-P4 — Retryable, complete, fail-closed FFplay frame API resolution

## Common rule

A frame output target is usable only when its required native frame API is available.

Do not permanently cache an unsuccessful lookup.

Do not publish a partial API.

Do not create/return a live-looking Flutter texture or activate an RN view when required native frame delivery cannot be registered safely.

---

# 13. Flutter Windows resolver

Replace:

```text
std::once_flag
```

with a mutex-protected complete pair:

```text
RegisterFn
UnregisterFn
```

A lookup failure leaves the resolver retryable.

Commit globals only when both symbols exist.

Do not call an independent `LoadLibrary` here if `FFmpegKitExtended.initialize()` owns library initialization.

`GetModuleHandle` is appropriate for the Flutter plugin path.

Before Flutter texture creation:

```text
resolve complete pair
if unavailable:
    return Platform error
    create/register no Flutter texture
```

After later `FFmpegKitExtended.initialize()`:

```text
create again
-> resolver retries
-> success
```

---

# 14. Flutter Linux resolver

Current Linux code has the same permanent-failure bug:

```text
g_symbols_resolved = true
```

is set even when both lookups failed.

It also writes register/unregister globals independently.

Replace with the same logical state as Windows:

```text
mutex
complete pair or unresolved
retry while incomplete
```

Probe:

```text
RTLD_DEFAULT
then already-loaded libffmpegkit handles
```

Do not permanently cache failure.

Do not auto-load a second independent FFmpegKit runtime behind the Dart initialization layer.

Before first/reused texture is returned:

```text
complete frame API required
```

If unavailable:

```text
respond with Flutter method error
do not mark texture usable
```

A later call after FFmpegKit initialization must retry and succeed.

---

# 15. Flutter Apple resolver

The primary plugin attempts to preload FFmpegKit before registering `FfplayKitPlugin`, so normal Apple startup is less exposed than Windows/Linux.

However, the frame plugin currently stores the result of:

```text
dlsym(RTLD_DEFAULT, "ffplay_kit_register_frame_callback")
```

at registration time and does not retry in `createTexture`.

If preload did not expose the symbol, texture creation still returns a texture ID without frame delivery.

Correct the source now.

Preferred Apple frame API:

```text
register callback function
unregister callback function
```

Resolve both through `RTLD_DEFAULT` when `createTexture` needs them.

If the pair is incomplete:

```text
return FlutterError
create no usable texture
```

Do not permanently cache the miss.

If a later runtime load makes them available, retry.

Use the separate native unregister export rather than assuming a partial register-only API is sufficient.

No Apple build/runtime validation in this review.

---

# 16. React Native Windows frame API resolver

Current RN Windows FFplay uses function-local static initialization:

```cpp
static RegisterFrameCallback callback = [] { ... }();
static UnregisterFrameCallback callback = [] { ... }();
```

A failed first lookup is permanently cached.

The two symbols are also resolved independently.

Replace with one retryable complete frame API pair.

It may continue to use the RN Windows runtime loading authority:

```text
GetModuleHandle
then LoadLibrary fallback
```

because this existing RN view path already owns that behavior.

But:

```text
complete register + unregister pair
```

must be the activation prerequisite.

`Initialize()` should not register a frame callback if unregister is unavailable.

A later view initialization must retry if the earlier lookup failed.

Do not disturb:

```text
g_registrationMutex
g_activeView
```

ownership.

---

# 17. React Native Apple frame API hardening

The Apple resolver already retries while the pair is incomplete.

That is good.

Do not rewrite it into a once-only cache.

But activation currently checks only:

```text
gRegisterFrameCallback
```

Require:

```text
gRegisterFrameCallback && gUnregisterFrameCallback
```

before the view becomes active.

Reason:

A callback must not be installed when lifecycle teardown cannot unregister it.

Keep the existing process-global view coordinator unchanged.

No Apple build/runtime validation in Review 27.

---

# 18. Android frame API resolution

No P4 change is needed for the Android FFplay video path.

Android video uses:

```text
ANativeWindow
```

rather than desktop frame callback dlsym/GetProcAddress.

P3 owns the Android process-global target fix.

---

# 19. R27-P5 — Current-agent executable platform matrix

## Mandatory now

```text
Windows
Linux/WSL
Android
```

## Explicitly not run now

```text
iOS
iOS Simulator
macOS
Apple tvOS
Apple tvOS Simulator
CocoaPods integration
Xcode builds
Apple runtime tests
```

Do not substitute remote CI for deferred Apple validation.

---

# 20. Common package gates

## Flutter

Run:

```text
dart --disable-analytics analyze
flutter analyze
flutter test --no-pub --exclude-tags native
```

Run focused Review 27 tests separately so a future tag/filter change cannot hide them.

## React Native

Run:

```text
npm run check
npm run prepare
npm run test:pack-types
npm run test:pack-web
npm pack --dry-run
```

Retain Review 25/26 callback ownership tests.

---

# 21. Windows validation

Run the Windows matrix from the original Review 27 plan with P1–P4 additions.

## Flutter Windows

Mandatory:

```text
x64 architecture accepted
arm64 rejected before config/artifact resolution

pre-init FFplay texture create -> fail/no live texture
initialize
texture create -> success
FFplay playback/frame delivery
pause/resume/stop
release

owner A
owner B
stale A release
B still receives frames

flutter build windows --release
```

Use the local Windows x86_64 `0.11.2` bundle.

Inspect final deployed DLL set.

## React Native Windows

Mandatory:

```text
x64 accepted
arm64 rejected

P2 real PowerShell staging suite

retryable complete FFplay frame API fixture

Review 26 log registration ownership fixture

Release MSBuild

runtime:
  initialize
  FFmpeg
  FFprobe
  media info
  direct structured log
  session history
  FFplay video
  pause/resume/stop
```

Keep RN Windows FFplay `g_activeView` behavior unchanged.

---

# 22. Linux/WSL validation

React Native has no native Linux implementation in this repository.

Do not invent one.

Linux runtime validation is therefore Flutter-only.

## Flutter Linux architecture

Mandatory:

```text
x64 -> accepted
arm64 -> rejected before override/artifact resolution
```

## Flutter Linux C++ helper tests

Compile/run the shared or Linux-specific owner coordinator.

Compile/run the retryable frame API state-machine helper with a fake lookup.

Required resolver sequence:

```text
lookup unavailable
-> no committed API

lookup later returns both
-> complete pair committed
-> install succeeds
```

Required owner sequence:

```text
A install
B install
A stale release
-> B remains owner

B release
-> null
```

## Flutter Linux build

Using the local Linux x86_64 bundle:

```text
flutter build linux --release
```

Verify expected executable + native assets.

## Flutter Linux runtime

If WSLg/display support is available as expected from the current agent capability:

```text
initialize
FFmpeg
FFprobe
media info
structured log
create FFplay desktop texture
video frame arrives
pause
resume
stop
release
```

### Pre-init resolver recovery

Fresh process:

```text
create texture before initialize
-> no usable texture / expected platform error

initialize
create again
-> success
```

### Ownership runtime

Use at least two texture states:

```text
A create
B create
A stale release
B remains active
```

If spinning two Flutter engines is practical under WSL, add the direct multi-engine case.

Otherwise:

- executable process-global owner helper is mandatory;
- two-texture runtime case is mandatory;
- multi-engine runtime remains not directly executed.

Do not claim it passed if not run.

---

# 23. Android validation

Both wrappers are in scope.

## 23.1 Flutter Android architecture

Mandatory host-neutral tests:

```text
arm -> accepted
arm64 -> accepted
x64 -> accepted
ia32 -> rejected before artifact resolution
```

Build at least the locally configured target ABI set intended by the example.

Do not add unsupported x86.

---

## 23.2 Flutter Android owner helper

Run the pure JVM/Kotlin owner coordinator tests.

Mandatory:

```text
A bind
B bind
A stale release
-> B remains owner

current B release
-> native clear

stale engine detach
-> no clear of B

10,000 replacements
-> bounded
```

---

## 23.3 Flutter Android emulator/device runtime

Use local/current AAR/native bundle.

Run:

```text
initialize
FFmpeg
FFprobe
media information
structured logs
create FFplayAndroidSurface
await bindToFFplay()
start local video
verify video target active
pause/resume/stop
release
```

Then:

```text
A surface bind
B surface bind
A release
B playback remains visible/active
B release
```

If a two-Flutter-engine instrumentation fixture is feasible, run it.

If not, record:

```text
process-global helper: passed
single-engine two-surface runtime: passed
two-engine runtime: not executed
```

Do not collapse those into one claim.

---

## 23.4 React Native Android

No FFplay owner defect was found, but run regression to ensure P1/P4 source changes did not regress Android.

Mandatory:

```text
resolver/package tests
Android codegen
Android build
runtime example on emulator/device
```

Exercise:

```text
initialize
FFmpeg
FFprobe
media information
direct structured logs
FFplayView mounted
video output
pause/resume/stop
unmount active view -> clears
mount replacement view -> receives output
```

The existing static Java `activeOwner` contract must remain intact.

---

# 24. R27-P6 — Apple source remediation now, all Apple execution later

## This is an explicit deferred validation gate

Review 27 **does change Apple source** where P1/P3/P4 found the same defect class.

Review 27 **does not execute Apple platform validation**.

Do not run:

```text
pod install
pod lib lint
xcodebuild
Flutter iOS build
Flutter macOS build
RN iOS build
RN macOS build
RN tvOS build
iOS simulator
tvOS simulator
Apple device tests
macOS runtime
```

under this current Windows agent.

---

# 25. Apple source changes included now

## Flutter iOS

Implement:

```text
P1: arm64-only source architecture authority
P3: process-global latest-successful frame owner
P4: retryable, complete frame API resolution
P4: fail texture creation when API unavailable
```

## Flutter macOS

Implement:

```text
P1: arm64 + x64 architecture authority
P3: process-global latest-successful frame owner
P4: retryable, complete frame API resolution
P4: fail texture creation when API unavailable
```

## React Native iOS/macOS/tvOS

No owner redesign.

Implement only:

```text
P1 explicit resolver architecture metadata validation when architecture supplied
P4 require complete register/unregister pair before frame activation
```

Preserve the existing process-global view coordinator.

---

# 26. Apple source-review requirements before commit

Because Apple cannot compile on the current host, Luna Think must do a careful direct source audit.

For each edited Apple file verify:

```text
Objective-C syntax is locally consistent with surrounding file
headers/imports needed by synchronization changes are present
ARC ownership remains balanced
retained callback userdata is not released before current-owner unregister
stale non-owner release still invalidates/releases local texture
Flutter result callback returns exactly once
RN coordinator logic remains unchanged except complete-pair gate
no Apple bundle/podspec path changes are introduced unnecessarily
```

Use `git diff --check`.

Do not treat this as Apple platform testing.

---

# 27. Required later Apple validation review

Carry this exact deferred ledger forward.

## Flutter iOS

Later Apple host must run:

```text
arm64 device or supported arm64 target build
arm64 simulator build
analysis/tests
FFmpeg
FFprobe
media info
direct structured logs
FFplay texture create/frame/release
A/B owner replacement + stale A release
frame API unavailable/retry fixture if controllable
```

Explicitly confirm x64 iOS simulator is rejected/not advertised under the frozen native matrix.

## Flutter macOS

Run both native artifact slices as available:

```text
arm64
x86_64
```

Build/runtime:

```text
initialize
FFmpeg
FFprobe
media info
FFplay
A/B owner lifecycle
pre-init/unavailable frame API recovery
```

## React Native iOS

Run:

```text
Pod prepare/install
Codegen
device/simulator build as supported
runtime FFmpeg/FFprobe/media info/log/FFplay
view mount/replacement/unmount
complete-pair frame activation
```

## React Native tvOS

Run:

```text
Pod prepare/install
tvOS build
tvOS simulator build where frozen artifact supports it
FFplay view lifecycle
```

## React Native macOS

Run:

```text
Pod prepare/install
macOS build
runtime native API
FFplay view lifecycle
```

Do not close Apple production readiness until those later gates actually execute.

---

# 28. R27-P7 — Documentation and closeout

## Flutter docs

Reconcile:

```text
README
installation
quick-start
architecture
FFplay desktop/mobile surface guidance
CHANGELOG
```

Final architecture claims:

```text
Android:
  armv7a / arm64 / x86_64
  no x86/ia32

Linux:
  x86_64 only

Windows:
  x86_64 only

iOS + iOS Simulator:
  arm64 under the frozen native artifact set

macOS:
  arm64 + x86_64
```

Do not imply Apple runtime validation happened in Review 27.

---

## Flutter FFplay docs

Document high-level ownership:

```text
one process-global FFplay video output target per process
latest successful high-level Flutter target owns it
stale surface/texture teardown does not clear a newer target
```

Android examples must use:

```dart
await surface.bindToFFplay();
```

Document:

```text
FFmpegKitExtended.initialize()
before desktop/Apple FFplay texture creation
```

and that an early unavailable-runtime create fails without poisoning later retry.

---

## React Native docs

Document:

```text
Windows x86_64 only
RN Linux native implementation is not supplied by this package
Windows staging refreshes local archive bytes and deploys one exact DLL set
FFplay frame APIs must resolve as a complete register/unregister pair
```

Do not claim Apple build validation occurred.

---

# 29. Tracker closeout states

At the end of the current Windows-agent run, valid statuses are:

```text
R27-P1 Complete
  if source + host-neutral architecture tests pass

R27-P2 Complete
  if real Windows staging/runtime build tests pass

R27-P3:
  Windows/Linux/Android -> Complete only with required executable evidence
  Apple source -> Implemented / Validation Deferred

R27-P4:
  Windows/Linux/RN Windows -> Complete only with required executable evidence
  Apple source -> Implemented / Validation Deferred

R27-P5 Complete
  only if Windows/Linux/Android required gates pass

R27-P6 Deferred
  by explicit user direction

R27-P7 Complete
  only if tracker/docs distinguish validated non-Apple platforms from deferred Apple
```

Do not mark:

```text
Apple production ready
```

during Review 27.

---

# 30. Suggested tracker wording

Use a compact platform split such as:

```text
Review 27 source remediation:
  Windows: implemented + validated
  Linux: implemented + validated for Flutter
  Android: implemented + validated
  Apple: source remediation implemented; all builds/runtime tests deferred
```

If any Windows/Linux/Android runtime gate cannot execute, state:

```text
Not executed — <exact reason>
```

not:

```text
Passed by source inspection
```

---

# 31. Implementation order

Use:

```text
R27-P1 architecture matrix
  ->
R27-P2 RN Windows staging
  ->
R27-P3 Flutter process-global FFplay ownership
  ->
R27-P4 FFplay frame API resolution
  ->
R27-P5 Windows/Linux/Android executable validation
  ->
R27-P6 Apple deferred-source ledger
  ->
R27-P7 docs/tracker/source freeze
```

P3 and P4 touch the same Flutter desktop/Apple files.

Implement their platform-local changes together carefully, but preserve separate test oracles and tracker evidence.

---

# 32. Luna model guidance

## Think required

Use Luna Think for:

- platform architecture authority;
- Flutter Android cross-engine/process-global surface ownership;
- desktop/Apple callback lifetime;
- frame API retry/commit semantics;
- RN Windows staging identity and exact-set replacement;
- lock ordering;
- Android/desktop runtime failure diagnosis;
- Apple source edits that cannot compile on the current host.

Do not let Instant redesign those systems.

## Instant appropriate after design freezes

Use Luna Instant for:

- repetitive architecture test vectors;
- established build/test commands;
- deterministic source scans;
- README/CHANGELOG updates;
- tracker table updates;
- package file inspection.

On a new functional failure, return to Think.

---

# 33. Lock-order rules

Do not introduce accidental cross-platform deadlocks.

## Desktop Flutter

Keep these concepts separate:

```text
frame API resolver lock
process-global registration-owner lock
TextureState lock
native FFplay API mutex
```

Recommended:

```text
resolve API
(no owner/state locks held)

owner coordinator lock
-> invoke native install/uninstall
-> commit owner
unlock

local TextureState lock
-> mark/destroy buffers
unlock
```

The frame callback itself should not acquire resolver/owner locks.

## Android Flutter

Recommended:

```text
process-global SurfaceOwner lock
-> JNI set/clear target
-> commit owner
unlock

then release local Surface/nativeWindowPtr/texture resources
```

Do not call back into Dart while holding the Java owner lock.

## Apple Flutter

Use the same semantic ordering:

```text
resolve complete API
process-global owner synchronization
native unregister/install
local texture invalidate/release
```

Do not release retained callback userdata before current-owner native unregister returns.

---

# 34. Failure semantics

## Architecture

Unsupported target:

```text
fail before artifact selection
```

Do not substitute another architecture.

## RN Windows staging

Any of:

```text
hash/read failure
archive extraction failure
missing libffmpegkit.dll
multiple libffmpegkit.dll
duplicate target basename
staging copy failure
```

must fail the build preparation.

## Flutter frame API unavailable

Desktop/Apple texture create:

```text
no complete frame API
-> method error
-> no usable texture published
```

Later retry remains allowed.

## Owner teardown

Non-owner stale teardown is not an error.

It releases local resources and performs zero process-global clear/unregister operations.

---

# 35. Test truthfulness

Never substitute:

```text
source regex
```

for an executable test when Windows/Linux/Android can execute the behavior.

Source contract inspection is acceptable only for the explicitly deferred Apple platform paths.

Do not claim:

```text
Apple passed
```

from:

```text
Dart unit test
Node resolver test
C++ coordinator test
source inspection
```

Those can validate shared logic, not Apple integration.

---

# 36. Regression invariants inherited from Reviews 23–26

Preserve:

## Structured logs

```text
single structured callback ABI
session id exact
sequence exact
level exact
message exact
owned payload freed once
no steady-state whole-history polling
bounded terminal reconciliation
```

## Demand and redirection

```text
callback activation demand-driven
completion independent from optional log/stat sinks
disableRedirection remains authoritative
first error preserved
```

## Review 25

```text
RN Web callback slot is retained/non-recycled
native/Windows RN log bridge state remains bounded
stale Flutter packaged old-ABI Wasm runtime remains absent
```

## Review 26

```text
latest successful RN module owns process-global structured-log registration
stale RN teardown cannot clear newer registration
```

## Native/build

```text
native ABI version stays 0.11.2
no _v2 callback ABI
no DataAssets reintroduction
no remote native publication
```

---

# 37. Pre-fix evidence Luna should capture

Before edits, preserve minimal reproduction evidence.

## Architecture

Record current:

```text
Flutter:
  Android ia32 -> x86
  Linux arm64 -> arm64
  Windows arm64 -> arm64
  iOS x64 -> accepted

RN resolver:
  windows arm64 -> bundle-...-windows-arm64-...
  linux arm64   -> bundle-...-linux-arm64-...
```

against frozen builder:

```text
Android: armv7a, arm64, x86_64
Linux: x86_64
Windows: x86_64
iOS: arm64
```

## Flutter Linux ownership

Record current unconditional:

```text
ffplay_kit_unregister_frame_callback()
```

from release/dispose.

## Flutter Android ownership

Record that:

```text
Dart isolate static pointer guard
```

is separate from:

```text
native process-global g_android_native_window
```

## Flutter Apple ownership

Record unconditional global callback clear in local plugin release/dealloc.

## Resolvers

Record:

```text
Flutter Windows: once_flag
Flutter Linux: g_symbols_resolved=true
Flutter Apple: one-time registration dlsym
RN Windows: function-local static callback caches
```

and the behavior when first lookup is unavailable.

---

# 38. Final production-readiness definition for this Review 27 pass

The current Windows agent may close Review 27's **non-Apple** production gate only when:

1. Flutter Android rejects unsupported ia32/x86.
2. Flutter Linux rejects arm64.
3. Flutter Windows rejects arm64.
4. Flutter iOS/macOS source architecture matrix is corrected without claiming Apple validation.
5. RN Windows rejects arm64 before overrides/artifacts.
6. RN Linux resolver does not construct unsupported arm64 native bundles.
7. RN Windows same-path local archive updates refresh staged bytes.
8. RN Windows staging removes stale DLLs and requires exactly one `libffmpegkit.dll`.
9. Flutter Windows stale texture/plugin teardown cannot clear a newer FFplay frame owner.
10. Flutter Linux stale texture/plugin teardown cannot clear a newer FFplay frame owner.
11. Flutter Android stale surface/engine teardown cannot clear a newer process-global ANativeWindow owner through the high-level surface API.
12. Flutter Apple source implements the same owner rule, with validation explicitly deferred.
13. Flutter Windows failed early frame-API lookup remains retryable.
14. Flutter Linux failed early frame-API lookup remains retryable.
15. Flutter Apple source resolves frame API at use time and fails closed, with validation deferred.
16. RN Windows frame API lookup is retryable and complete-pair.
17. RN Apple source requires a complete frame API pair before activation, with validation deferred.
18. Flutter Windows current local x64 runtime passes build/native API/FFplay gates.
19. RN Windows current local x64 runtime passes build/native API/FFplay gates.
20. Flutter Linux current local x64 runtime passes build/native API/FFplay gates.
21. Flutter Android current local native bundle passes build/native API/FFplay surface gates.
22. RN Android current local native bundle passes build/native API/FFplayView gates.
23. Existing RN Android/Apple/Windows process-global view-owner semantics are preserved.
24. Review 25/26 callback ownership tests remain green.
25. No hosted CI or remotely built old native ABI bundle is used as acceptance evidence.
26. No Apple build/runtime result is fabricated or inferred.
27. Apple platform status remains **Validation Deferred**.
28. Documentation/tracker state exactly which platforms were executable and validated.
29. Product worktree is clean and one exact final SHA/tree is frozen.

At that point the justified status is:

```text
Windows: production-ready at the frozen Review 27 source
Linux: Flutter production-ready at the frozen Review 27 source
Android: Flutter + React Native production-ready at the frozen Review 27 source
Apple: source-remediated for the reviewed defect classes, platform validation deferred
Web/Wasm: unchanged from prior accepted Review 25/26 evidence
```

Apple production readiness must be decided only after the later Apple-specific build/runtime validation review.
