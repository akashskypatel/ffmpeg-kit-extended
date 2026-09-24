# Review 27 — Luna Windows Platform Production-Readiness Plan

**Project:** FFmpegKitExtended  
**Date:** 2026-09-23  
**Audience:** Luna  
**Primary wrapper repository:** `akashskypatel/ffmpeg-kit-extended`, branch `dev-wasm`  
**Native/builder repository:** `akashskypatel/ffmpeg-kit-builders`, branch `dev`  
**Platform scope:** Windows only, covering both Flutter and React Native  
**Source authority:** exact Review 26 wrapper source snapshot at `ebb2b055aa9e1841c73dd82a89c1c8aab5fbc045` and unchanged frozen native source `625c3452ee3c93fb5d701bb6546726940b88d014`  
**Native ABI/runtime version:** `0.11.2`  
**Validation policy:** local Windows validation against locally packaged native ABI bundles only; do not use hosted CI or remotely built native ABI bundles as acceptance evidence  
**User-directed Apple validation amendment:** Windows remains the implementation scope, but noninteractive Apple build/test gates must use the synced `my MacBook Air` checkout at `/Users/akash/Projects/ffmpeg_kit_extended` over SSH (`akash@192.168.1.189`) instead of being deferred. Interactive iOS/tvOS simulator tests may remain deferred when the GUI simulator cannot be driven from this session.  
**Finding policy:** only real functional code defects discovered in the exact Review 26 source are remediation goals. Do not create goals for bookkeeping, intentional release/checksum policy, accepted sanitizer findings, or cosmetic inconsistencies.

---

## Review 26 prerequisite gate

**Result: PASS. Review 27 Windows platform review is authorized to proceed.**

The attached Review 26 closure claimed that:

- one shared semantic `LogBridgeRegistrationCoordinator` is used by React Native shared C++ and Windows;
- ownership is committed only after successful native callback installation;
- ownership is cleared only after successful current-owner disable;
- stale module teardown cannot clear a newer module's process-global structured-log registration;
- executable ownership/failure/concurrency coverage passed;
- React Native package/Web and Windows Release build gates passed;
- the frozen native ABI source remained unchanged.

The exact Review 26 snapshot was independently audited before this Windows review.

Independent focused reruns against the exact snapshot passed:

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

The implementation matches the Review 26 ownership invariant:

```text
latest successful install owns process-global registration
stale/non-owner uninstall does not invoke native disable
current-owner uninstall invokes native disable
owner changes only after native setter succeeds
owner clears only after native disable succeeds
```

No Review 26 closure-breaking defect was found.

**If this prerequisite had failed, this plan would stop here and contain no Windows platform goals. It passed, so the Windows review below is valid.**

---

# Tracker

| Goal | Severity | Wrapper(s) | Objective | Functional finding | Luna mode | Exit gate |
|---|---|---|---|---|---|---|
| **R27-W1** | **High** | Flutter + React Native | Make Windows architecture selection truthful and fail-closed | Both wrapper artifact resolvers accept Windows `arm64`, while the frozen native builder and React Native Windows projects support only `x86_64`; a custom x64 override can even be accepted for an `arm64` request | **Think** | Windows accepts only x64/x86_64 before any artifact/override resolution; Linux/Apple/Android behavior remains unchanged |
| **R27-W2** | **High** | React Native | Make Windows runtime preparation content-fresh and staging-coherent | Local ZIP extraction is keyed only by path, so replacing a ZIP in place can keep stale extracted bytes; destination staging is never cleared; malformed DLL sets can pass build staging without exactly one `libffmpegkit.dll` | **Think** | Same-path changed ZIP refreshes; staging exactly matches selected runtime; stale DLLs disappear; duplicate basenames and missing/multiple main DLLs fail before MSBuild deployment |
| **R27-W3** | **Critical** | Flutter | Make Windows FFplay frame-callback registration process-global-owner safe | FFplay's native frame callback is process-global, but each Flutter plugin instance unconditionally unregisters it on release/destruction; an old engine/plugin can disable a newer engine's active texture callback | **Think** | Latest successful texture registration owns the global callback; stale release/destructor cannot unregister a newer owner; current owner release drains and unregisters safely |
| **R27-W4** | **High** | Flutter | Make Windows FFplay symbol resolution retryable, atomic, and fail-closed | `std::call_once` permanently caches an early "DLL not loaded" lookup; `createTexture` can then return a valid-looking texture with no frame callback, and later initialization cannot recover | **Think** | Failed pre-init lookup does not poison the process; resolver commits only a complete register/unregister pair; texture creation fails without registering a dead texture and succeeds after later initialization |
| **R27-W5** | **High validation gate** | Flutter + React Native | Run a real local Windows production matrix against the locally packaged x64 runtime | Prior evidence proves builds but is not sufficient for all Windows-only lifecycle/runtime paths found here | **Think** for failures; **Instant** for established commands | Both wrappers pass local Windows build/runtime/package gates, FFmpeg/FFprobe/media-info/log/FFplay paths, and all W1–W4 regressions with no remote native artifact use |
| **R27-W6** | **Closeout** | Flutter + React Native | Reconcile Windows docs/tests/tracker and freeze one exact source | Final supported architecture, staging freshness, FFplay ownership, and runtime-init behavior must match implemented code | **Instant** after W1–W5 pass | Maintained docs/tests are accurate; tracker records exact commands/results; final source is clean and frozen |

---

# 1. Exact source authority

Use the exact Review 26 source snapshot as the immutable review baseline.

## Wrapper source

```text
repository:  akashskypatel/ffmpeg-kit-extended
branch:      dev-wasm
source SHA:  ebb2b055aa9e1841c73dd82a89c1c8aab5fbc045
tree SHA:    0b2313880b271086ec2b4c6276ac99521148fcda
workflow:    35943439201
artifact:    review26-wrapper-source-35943439201
artifact ID: 10786006110
```

Snapshot metadata:

```text
repository:           akashskypatel/ffmpeg-kit-extended
event:                workflow_dispatch
event_sha:            ebb2b055aa9e1841c73dd82a89c1c8aab5fbc045
snapshot_sha:         ebb2b055aa9e1841c73dd82a89c1c8aab5fbc045
archive_sha256:       9fe7de5c18269de2a97707c7a8e86b066dfd420a39d9d10cb61a7259e9ca55b5
file_count:           1044
symlink_count:        0
byte_count:           27057739
include_submodules:   true
include_lfs:          false
runtimeExecution:     false
```

## Frozen native product source

```text
625c3452ee3c93fb5d701bb6546726940b88d014
```

The native source remains frozen for this Windows wrapper review.

Do not modify or republish the native ABI under Review 27 unless a goal proves a wrapper-only correction is impossible and the user separately authorizes a native-first follow-up.

## Native Windows architecture authority

The recursively materialized frozen builder source explicitly says:

```bash
VALID_WINDOWS_ARCHS=("x86_64")
```

and the native build documentation/platform matrix names:

```text
windows-x86_64
```

There is no frozen `windows-arm64` native build authority.

## React Native Windows project authority

The package project and example are x64-only:

```xml
<ProjectConfiguration Include="Debug|x64">...</ProjectConfiguration>
<ProjectConfiguration Include="Release|x64">...</ProjectConfiguration>
```

No ARM64 project configuration exists.

---

# 2. Explicit exclusions

Do not create Review 27 goals for the following.

## Previously accepted policy

Do not reopen:

- `ffigen_js: ^0.0.16-pre`;
- native ABI/runtime version `0.11.2`;
- local-only manifest/hash/source-SHA depth;
- intentional checksum fail-open behavior when GitHub release metadata omits a digest;
- historical remote `0.11.2` resolver policy;
- remote native publication policy;
- developer-specific WSL paths used for local validation;
- workflow artifact-ID bookkeeping.

## Accepted native/sanitizer dispositions

Do not reopen:

- FFmpeg MPEG-4 `padding_bug_score` TSan race;
- accepted TLS cancellation diagnostic;
- GCC 14 matched-UBSAN-runtime disposition.

## Other platforms

Do not broaden Windows fixes into:

- Linux architecture policy;
- Android ABI work;
- Apple slice implementation work. Apple noninteractive build/test validation is required on `my MacBook Air` under the amendment above;
- Web/Wasm architecture;
- native builder ARM64 Windows enablement.

If Windows ARM64 support is desired later, it is a separate native-builder/platform project requiring actual Windows ARM64 native artifacts plus wrapper/project/runtime validation. Review 27 must not fake it by changing labels.

## Investigated but not promoted to findings

Do not create goals merely for:

- React Native Windows `RaiseFailFastException` policy without a proven supported high-level path that triggers it under a valid runtime;
- Flutter pixel channel ordering without an observed color/rendering failure;
- stale or unwired test-file hygiene;
- documentation-only Windows version-minimum discrepancies;
- React Native FFplay process-global view ownership: the exact source already guards `g_activeView` with a process-global registration mutex and conditionally unregisters only the active view.

---

# 3. R27-W1 — Make Windows architecture authority x64-only and fail-closed

## Severity

**High**

## Affected wrappers

- Flutter
- React Native

## Functional finding

The frozen native Windows platform supports only:

```text
x86_64
```

Yet Flutter's architecture helper uses the same desktop mapping for Linux and Windows:

```dart
String desktopArtifactArchitecture(
  Architecture architecture, {
  required String platform,
}) {
  switch (architecture) {
    case Architecture.arm64:
      return 'arm64';
    case Architecture.x64:
      return 'x86_64';
    ...
  }
}
```

and:

```dart
case OS.linux:
case OS.windows:
  desktopArtifactArchitecture(...)
```

The Flutter tests and maintained docs therefore explicitly treat Windows ARM64 as supported.

React Native has the same resolver-level problem:

```js
if (architecture === "x64" || architecture === "x86_64") return "x86_64";
if (architecture === "arm64" || architecture === "aarch64") return "arm64";
```

and later constructs:

```text
bundle-<type>-windows-arm64-shared-<license>.zip
```

if Windows ARM64 is requested.

The local override path is worse: because architecture validation is generic rather than platform-specific, an x86_64 local Windows archive can be accepted while the resolved request metadata says:

```text
platform: windows
architecture: arm64
```

The exact Review 26 source reproduces that resolver behavior.

At the same time, React Native's actual Windows `.vcxproj`, solution, example project and packaging project are x64-only.

This is a real unsupported-target selection defect.

A request must not be accepted when no native/project implementation exists for that target.

---

## Required invariant

For Review 27:

```text
Windows supported architecture = x64 / x86_64 only
```

Every Windows entry point must reject ARM64 **before**:

- custom override acceptance;
- official artifact URL construction;
- download;
- extraction;
- staging;
- MSBuild invocation.

Do not silently map ARM64 to x64.

Do not relabel an x64 custom bundle as ARM64.

---

## Flutter implementation

### Do not break Linux architecture handling

Do not change the generic Linux behavior as a side effect.

Preferred structure:

```dart
String linuxArtifactArchitecture(Architecture architecture) {
  ...
}

String windowsArtifactArchitecture(Architecture architecture) {
  switch (architecture) {
    case Architecture.x64:
      return 'x86_64';
    default:
      throw StateError(
        'Unsupported Windows target architecture "..."; '
        'supported architecture: x64.',
      );
  }
}
```

Then make:

```dart
validateTargetArchitecture(OS.windows, ...)
```

use the Windows-specific authority.

Likewise, official Windows artifact naming must use the same Windows-specific helper.

Do not validate with one function and name artifacts with another function that can disagree.

### Validation ordering

The existing build hook already validates before configuration/artifact resolution.

Preserve this:

```text
target detected
-> validate Windows architecture
-> load config
-> resolve custom/default artifact
-> download/extract
-> emit CodeAssets
```

A custom `windows:` override must not bypass the architecture check.

### Flutter tests

Change the existing architecture test that currently accepts Windows ARM64.

Required cases:

```text
Windows x64 -> x86_64
Windows arm64 -> throws
Windows arm -> throws
Windows ia32 -> throws
```

Also preserve:

```text
Linux current behavior unchanged
Android mappings unchanged
Apple mappings unchanged
```

Add a hook-level test proving unsupported Windows architecture fails before the artifact resolver/downloader seam is invoked.

The test must not merely check a string helper if the build hook can bypass it.

---

## React Native implementation

Keep generic normalization if useful, but add platform-specific validation immediately after platform + architecture normalization.

Conceptually:

```js
function validatePlatformArchitecture(platform, architecture) {
  if (platform === "windows") {
    const effective = architecture || "x86_64";
    if (effective !== "x86_64") {
      fail(
        `Unsupported Windows architecture: ${architecture}. ` +
        `Supported architecture: x64/x86_64.`
      );
    }
  }
}
```

Exact API shape is Luna's choice.

Important:

```text
normalize -> platform-specific validate -> config/override resolution
```

not:

```text
normalize -> accept local override -> validate later
```

### PowerShell staging entry point

`prepare-windows-runtime.ps1` currently accepts:

```powershell
[ValidateSet('x64', 'arm64')]
```

Remove ARM64 from the supported production contract.

Preferred:

```powershell
[ValidateSet('x64')]
```

or an explicit validation block with a clearer package-specific message.

Do not add an ARM64 MSBuild configuration.

### React Native tests

Add:

```text
resolve Windows x64 -> succeeds / normalized x86_64
resolve Windows arm64 -> fails
resolve Windows aarch64 -> fails
Windows arm64 + explicit local x64 ZIP -> fails before override selection
Windows arm64 + remote override -> fails before remote selection
Linux arm64 behavior -> unchanged
```

Add a source/project consistency test proving Windows production configurations are x64-only if such a test remains useful after the behavior test.

---

## Documentation

Update maintained Windows architecture claims.

At minimum audit:

```text
flutter/README.md
flutter/doc/installation.md
flutter/doc/quick-start.md
react-native/README.md
react-native/TEST.md
```

React Native's primary platform table already says Windows x86_64; preserve that.

Remove Flutter claims that published Windows ARM64 artifacts exist.

Do not claim Windows ARM64 is "planned" unless there is an actual plan in project authority.

---

## Exit gate

R27-W1 closes only when:

```text
Flutter Windows x64 accepted
Flutter Windows arm64 rejected before config/artifact resolution
RN Windows x64 accepted
RN Windows arm64 rejected before override/artifact resolution
RN PowerShell staging cannot be invoked as supported arm64 path
native builder remains unchanged
Linux/Android/Apple architecture tests remain green
```

---

# 4. R27-W2 — Make React Native Windows runtime staging fresh and coherent

## Severity

**High**

## Affected wrapper

React Native only.

## Affected code

Primary:

```text
react-native/scripts/prepare-windows-runtime.ps1
```

Related:

```text
react-native/scripts/resolve-ffmpeg-kit-config.js
react-native/windows/FFmpegKitExtended/FFmpegKitExtended.vcxproj
react-native/tests/windows-runtime-packaging.test.js
```

---

## Functional finding A — same-path local ZIP changes are ignored

The current extraction marker is based on source identity:

```powershell
$sourceKey = if ($resolution.override) {
  "$($resolution.override.kind):$($resolution.override.value)"
} else {
  "official:$($resolution.url)"
}
```

Extraction runs only when that text changes.

For a local ZIP override:

```text
C:\project\native\ffmpegkit.zip
```

this sequence is broken:

```text
build with ZIP bytes A
replace C:\project\native\ffmpegkit.zip with ZIP bytes B
build again using the same path
```

The marker still matches:

```text
local:C:\project\native\ffmpegkit.zip
```

so the old extraction remains authoritative.

The new local artifact bytes are never copied/extracted.

That is a real stale-runtime bug for the supported local override workflow.

---

## Functional finding B — destination staging retains stale DLLs

The current destination logic is:

```powershell
New-Item -ItemType Directory -Force -Path $Destination
foreach ($dll in $dlls) {
  Copy-Item -Force $dll.FullName (Join-Path $Destination $dll.Name)
}
```

It never removes DLLs that existed in a previous selected runtime but are absent from the current runtime.

Therefore:

```text
bundle A = libffmpegkit.dll + codecA.dll + codecB.dll
bundle B = libffmpegkit.dll + codecA.dll
```

can leave:

```text
codecB.dll
```

inside the dedicated staging directory after switching to B.

MSBuild then collects:

```xml
$(FFmpegKitExtendedRuntimeStagingDir)\*.dll
```

and can deploy the stale DLL.

A build can therefore contain a mixture of two runtime selections.

---

## Functional finding C — malformed DLL sets are accepted too late

The staging script currently requires only:

```text
at least one *.dll
```

It does not require the actual runtime authority:

```text
exactly one libffmpegkit.dll
```

A custom archive containing only:

```text
foo.dll
```

can pass staging and reach MSBuild deployment.

The dynamic API later tries to load:

```text
libffmpegkit.dll
ffmpegkit.dll
```

and fails at runtime.

The build should fail during artifact preparation instead.

---

## Functional finding D — recursive flattening can silently overwrite duplicate basenames

The script recursively discovers DLLs then copies each to one flat destination.

If an archive contains:

```text
dirA\codec.dll
dirB\codec.dll
```

both target:

```text
<staging>\codec.dll
```

Current behavior is last-copy-wins.

That is not a coherent runtime selection.

It should fail clearly rather than choose one based on enumeration order.

---

## Required invariant

The staging directory must be a pure projection of one selected runtime.

For every successful run:

```text
staging DLL set == selected source runtime DLL set
```

subject only to intentional flattening after duplicate-basename validation.

And:

```text
exactly one libffmpegkit.dll
```

must be present.

---

## Local archive cache design

Do not change the accepted GitHub release checksum policy.

This goal is about **local override byte freshness**.

For local archive overrides:

1. resolve the local source path;
2. verify it exists;
3. calculate SHA-256 of the current source file bytes;
4. derive local extraction identity from at least:

   ```text
   canonical local path + content SHA-256
   ```

5. compare that identity with the extraction marker;
6. if bytes changed:
   - copy the current local source to cache if a cached archive is still desired;
   - remove/recreate extraction root;
   - extract current bytes;
   - write the new marker only after successful extraction.

PowerShell has a direct primitive:

```powershell
Get-FileHash -Algorithm SHA256
```

Use exact production code; do not shell out to a fragile parser unnecessarily.

### Content-addressed extraction is also acceptable

A content-keyed extraction root is cleaner:

```text
vendor/windows/x64/<artifact-identity>/<sha256>/
```

provided old cache cleanup remains bounded and the current build selects only the matching root.

Do not let cache cleanup become a prerequisite for correctness.

---

## Local directory overrides

A local directory does not need archive extraction caching.

Every invocation should re-enumerate its DLL set.

But it still must pass the same coherence validation:

```text
exactly one libffmpegkit.dll
no duplicate flattened DLL basenames
```

and final destination must exactly match the current directory runtime selection.

---

## Runtime DLL selection helper

Before staging, derive a deterministic runtime manifest.

Preferred rules:

```text
find all *.dll recursively
case-insensitive Windows basename comparison
reject zero DLLs
require exactly one basename == libffmpegkit.dll
reject duplicate basenames after case folding
sort deterministic by target basename
```

Do not accept `ffmpegkit.dll` as the primary bundle authority unless project release layout explicitly supports it. The wrapper loader may keep its compatibility fallback, but the package's own configured bundle contract is `libffmpegkit.dll`.

If both:

```text
libffmpegkit.dll
ffmpegkit.dll
```

exist, do not silently select an ambiguous main runtime.

---

## Exact staging replacement

The destination is a dedicated intermediate directory:

```text
$(IntDir)\ffmpeg-kit-runtime
```

so production staging may safely ensure exact contents.

Preferred approach:

1. prepare a temporary sibling directory;
2. copy the complete validated DLL manifest into it;
3. verify copied target names;
4. replace the previous dedicated staging directory;
5. only expose the completed directory to MSBuild.

If atomic directory replacement is awkward on Windows, it is acceptable to:

```text
remove the dedicated staging directory
recreate it
copy complete validated set
```

because this target runs before deployment and the directory is build-owned.

Do not selectively overwrite into an uncleared destination.

---

## First-error behavior

If:

- hashing fails;
- archive extraction fails;
- main DLL is missing;
- duplicate basenames exist;
- staging copy fails;

the script must exit nonzero before MSBuild treats runtime preparation as successful.

Do not leave a newly written success marker before all extraction validation passes.

---

## Required real Windows regression harness

Do not rely only on regex/source tests.

Add a deterministic Windows-only fixture, for example:

```text
react-native/tests/windows-runtime-staging.ps1
```

or an equivalent semantically named test harness.

It may create temporary ZIPs with `Compress-Archive` and call the real production staging script.

### Test 1 — same path, changed bytes

Create:

```text
runtime.zip version A:
  libffmpegkit.dll -> bytes "A-main"
  extra-a.dll      -> bytes "A-extra"
```

Run staging.

Overwrite the exact same:

```text
runtime.zip
```

with:

```text
version B:
  libffmpegkit.dll -> bytes "B-main"
  extra-b.dll      -> bytes "B-extra"
```

Run staging again.

Assert:

```text
staged libffmpegkit.dll == B-main
extra-b.dll exists
extra-a.dll does not exist
```

This must fail against the Review 26 script.

### Test 2 — smaller bundle removes stale dependency

```text
A: libffmpegkit.dll + old.dll
B: libffmpegkit.dll
```

After B:

```text
old.dll absent
```

### Test 3 — missing main runtime

Archive:

```text
foo.dll
```

Expected:

```text
staging command fails
no successful runtime deployment state
```

### Test 4 — duplicate flattened basename

Archive:

```text
a\codec.dll
b\codec.dll
libffmpegkit.dll
```

Expected:

```text
fail with duplicate target basename diagnostic
```

### Test 5 — duplicate main DLL

Archive:

```text
a\libffmpegkit.dll
b\libffmpegkit.dll
```

Expected:

```text
fail
```

### Test 6 — local directory freshness

Modify the contents of the configured local directory without changing its path.

Next staging run must exactly reflect the new current set.

---

## MSBuild validation

After script-level tests:

```text
build React Native Windows Release x64
```

using the actual local `0.11.2` Windows bundle.

Inspect:

```text
react-native/example/windows/x64/Release/
```

and package/deployment outputs.

Assert:

```text
exactly intended runtime DLLs
exactly one libffmpegkit.dll
no stale fixture DLLs
FFmpegKitExtended.dll produced
example executable produced
```

Do not use "build succeeded" as the only staging oracle.

---

## Exit gate

R27-W2 closes only when:

```text
same-path local ZIP mutation refreshes
destination cannot retain removed DLLs
missing libffmpegkit.dll fails
multiple libffmpegkit.dll fails
duplicate flattened basenames fail
local directory mutations refresh
real Windows Release build deploys exact selected DLL set
```

---

# 5. R27-W3 — Make Flutter Windows FFplay frame callback ownership-safe

## Severity

**Critical**

## Affected wrapper

Flutter Windows only.

## Affected code

```text
flutter/windows/ffmpeg_kit_extended_flutter_plugin.cpp
```

Potential helper:

```text
flutter/windows/include/.../<semantic frame registration coordinator>.h
```

Tests should be placed in a test-only location with semantic naming.

---

## Native contract

The frozen native FFplay implementation has one process-global pair:

```c
static FFplayFrameCallback g_frame_callback = NULL;
static void *g_frame_callback_userdata = NULL;
```

The setter is process-global:

```c
ffplay_set_frame_callback(callback, userdata)
```

and registration/unregistration ultimately replace that same pair.

The native setter uses the FFplay API mutex.

When callback is set to null, it waits for the in-flight callback block that holds the same mutex to finish before returning.

This is useful lifetime authority, but it does **not** provide per-Flutter-engine ownership.

---

## Flutter Windows defect

Each `FfmpegKitExtendedFlutterPlugin` owns a local:

```text
texture_state_
```

but `ReleaseTextureState()` unconditionally calls:

```cpp
ffplay_kit_unregister_frame_callback();
```

The plugin destructor always calls:

```cpp
ReleaseTextureState();
```

There is no process-global current-owner guard.

Therefore:

```text
Flutter engine/plugin A creates texture
native global FFplay frame callback = A

Flutter engine/plugin B creates texture
native global FFplay frame callback = B

old engine/plugin A is disposed
A.ReleaseTextureState()
A unconditionally unregisters native global callback

result:
B remains alive with a registered Flutter texture
but B no longer receives FFplay frames
```

The failure can be silent: playback may continue while video freezes/stays empty.

This is the same general ownership class fixed for React Native structured logs in Review 26, but it is a separate native FFplay frame callback and a separate Flutter Windows implementation.

React Native Windows already guards its FFplay view with a process-global active-view owner. Do not change that implementation without new evidence.

---

## Required ownership contract

Use:

> **Latest successful Flutter Windows FFplay texture registration owns the process-global FFplay frame callback. Only that exact texture state may unregister it.**

A stale plugin/texture may destroy its local Flutter texture.

It may not unregister the current process-global native callback owned by another state.

Do not restore an older texture automatically.

---

## Preferred implementation

Create a small semantic Windows-local coordinator.

Example semantic concept:

```text
FrameCallbackRegistrationCoordinator
```

Do not use `Review27`, `W3`, or planning terminology in production names.

The coordinator should serialize:

```text
install owner
conditional uninstall owner
```

with owner identity equal to the actual `TextureState*` registered as native user-data.

Conceptually:

```cpp
class FrameCallbackRegistrationCoordinator {
 public:
  template <typename InstallFn>
  void install(void* owner, InstallFn&& install);

  template <typename UninstallFn>
  bool uninstallIfOwned(void* owner, UninstallFn&& uninstall);
};
```

Owner commit rules must match Review 26's proven semantics:

```text
native register succeeds
-> current owner = new TextureState*

native current-owner unregister succeeds
-> current owner = null

stale owner teardown
-> no native unregister call
```

---

## Create path

After W4 runtime-symbol resolution succeeds:

1. release this plugin instance's previous texture if needed;
2. allocate new `TextureState`;
3. build/register Flutter texture;
4. use the process-global coordinator to install:

   ```text
   OnFrameCallback + state_ptr
   ```

5. commit `texture_state_` only when local/native registration state is coherent.

If Flutter texture registration itself fails according to Flutter's documented API failure contract, do not install the native callback.

Do not return a success payload for a state that cannot receive frames.

---

## Release/destructor path

Conceptually:

```text
move local texture state out of plugin
conditional process-global unregister if this state is current owner
drain current-owner native callback through native unregister
mark local state destroyed
clear buffers
unregister local Flutter texture
destroy state
```

For a non-owner stale state:

```text
skip native unregister
mark local state destroyed
unregister local Flutter texture
destroy state
```

### Why stale non-owner state can be destroyed

When a newer owner successfully registers, the native `ffplay_set_frame_callback` call acquires the native FFplay API mutex.

That registration cannot complete until any old callback holding the same mutex completes.

Therefore, after successful replacement registration returns, the older owner no longer needs indefinite retirement solely for native FFplay frame callback safety.

Still preserve the local `TextureState::mutex` protocol around buffer destruction.

---

## Concurrent engine operations

The process-global registration coordinator must serialize at least:

```text
A release vs B create/register
A destructor vs B create/register
A create/register vs B create/register
```

Valid interleavings:

```text
A unregister completes first -> B registers -> final owner B
```

or:

```text
B registers first -> owner B -> stale A skips unregister -> final owner B
```

Invalid:

```text
B registers successfully -> stale A unregisters afterward -> callback null
```

---

## Behavioral tests

Do not rely only on source pattern matching.

Factor the owner state machine into a pure C++ helper that can be compiled without Flutter headers.

Required cases:

```text
install A -> A
install B -> B
stale uninstall A -> B
current uninstall B -> null

A install
A uninstall
B install
stale A destructor-equivalent uninstall
-> B

A install
B install
stale A destructor-equivalent uninstall
-> B
```

Add a deterministic concurrent barrier/latch test:

```text
A teardown racing B install
```

Final successful B registration must never end with no callback.

Stress repeated handoffs, e.g.:

```text
10,000 A/B transitions
```

and assert bounded coordinator state/no deadlock.

---

## Flutter plugin integration test

Add source/integration coverage proving:

```text
HandleCreateTexture -> owner-aware registration
ReleaseTextureState -> conditional owner-aware unregister
destructor -> same ReleaseTextureState path
```

A source-contract test may supplement but not replace the executable coordinator test.

---

## Exit gate

R27-W3 closes only when:

```text
stale Flutter engine/plugin release cannot disable newer frame callback
current owner release unregisters
native callback drain remains before owner-state destruction
local Flutter textures still release
multiple create/release cycles remain bounded
RN Windows FFplay owner behavior remains untouched
```

---

# 6. R27-W4 — Make Flutter Windows FFplay symbol resolution retryable and fail-closed

## Severity

**High**

## Affected wrapper

Flutter Windows only.

## Functional finding

The current Windows plugin uses:

```cpp
static RegisterFn g_register_fn = nullptr;
static UnregisterFn g_unregister_fn = nullptr;
static std::once_flag g_resolve_once;
```

and:

```cpp
std::call_once(g_resolve_once, [] {
  HMODULE h = GetModuleHandleA(...);
  ...
});
```

The plugin comment assumes:

```text
libffmpegkit.dll is already loaded by the time any MethodChannel call arrives
```

but that is not guaranteed by the plugin registration lifecycle.

The Flutter plugin's method channel exists independently of:

```dart
FFmpegKitExtended.initialize()
```

which is what opens `libffmpegkit.dll` on Windows.

Therefore a supported but misordered call can do this:

```text
FFplayDesktopTexture.create()
before FFmpegKitExtended.initialize()

ResolveFFplayProcs:
  GetModuleHandle("libffmpegkit.dll") -> null
  call_once completes permanently
  register/unregister pointers remain null

HandleCreateTexture:
  Flutter texture is registered
  register wrapper silently does nothing
  method returns a valid-looking textureId

later:
FFmpegKitExtended.initialize() loads DLL

later:
FFplayDesktopTexture.create()
ResolveFFplayProcs does not retry because once_flag is already consumed
frame callback remains unavailable for process lifetime
```

This is both:

- an early-call fail-open defect; and
- a permanent recovery defect.

---

## Secondary atomicity defect

The resolver assigns the two pointers independently:

```text
g_register_fn
g_unregister_fn
```

If an incompatible runtime exposes only one symbol, the resolver can leave a partial pair.

Then:

```text
register wrapper checks only register pointer
unregister wrapper checks only unregister pointer
```

A callback must never be installed unless its corresponding unregister function is also available.

Use one complete API pair as the commit unit.

---

## Required resolver contract

Resolver states should effectively be:

```text
unresolved
resolved-complete
```

A failed lookup is **not** a permanent resolved state.

Do not permanently cache:

```text
DLL absent
partial symbols
```

A later call may retry after the runtime DLL has been initialized/loaded.

---

## Preferred implementation

Replace `std::once_flag` with a mutex-protected complete pair.

Conceptually:

```cpp
struct FFplayFrameApi {
  RegisterFn registerCallback = nullptr;
  UnregisterFn unregisterCallback = nullptr;

  bool complete() const {
    return registerCallback != nullptr &&
           unregisterCallback != nullptr;
  }
};

std::mutex g_ffplay_frame_api_mutex;
FFplayFrameApi g_ffplay_frame_api;
```

Resolver:

```text
lock resolver mutex
if cached complete pair:
    return pair

for candidate DLL names:
    GetModuleHandle
    if absent:
        continue

    resolve register into local temporary
    resolve unregister into local temporary

    if both exist:
        commit both together
        return complete

leave global pair empty
return unavailable
```

### Do not use partial global assignments while probing

Use local temporaries first.

Only publish:

```text
register + unregister
```

as one complete pair.

---

## Do not auto-load FFmpegKit from the FFplay texture plugin

Prefer `GetModuleHandle`, not an independent `LoadLibrary`, for this path.

Why:

`FFmpegKitExtended.initialize()` owns native library initialization and calls:

```text
ffmpeg_kit_initialize()
```

The texture plugin should not silently bypass the package's initialization authority merely to make symbol lookup pass.

If the runtime is not loaded yet:

```text
return unavailable
```

and allow a later retry after correct initialization.

---

## Make `createTexture` fail closed

Before registering a Flutter texture or returning success:

```text
resolve complete FFplay frame API pair
```

If unavailable:

```cpp
result->Error(
  "FFMPEGKIT_RUNTIME_UNAVAILABLE",
  "Initialize FFmpegKit before creating an FFplay desktop texture."
);
return;
```

Exact code/message may differ.

Do not:

- register a dead Flutter texture;
- return a valid-looking texture ID;
- consume a one-shot resolver state.

---

## Dart API behavior

Preserve the existing public nullable behavior unless a broader API contract change is justified.

`FFplayDesktopTexture.create()` currently catches `PlatformException` and returns `null`.

It is acceptable for:

```text
pre-initialization native create -> PlatformException -> Dart null
```

provided:

- no dead native texture is left behind;
- no global callback is installed;
- later initialization followed by create succeeds.

Do not introduce a breaking throw-only public API merely to close this Windows defect unless existing package policy already requires it.

Update docs to make initialization ordering explicit.

---

## Required direct Windows regression

This must run in a fresh process/engine where FFmpegKit has not been initialized yet.

Sequence:

```text
1. call FFplayDesktopTexture.create() before initialize
2. expect null/error; no valid texture returned
3. call FFmpegKitExtended.initialize()
4. call FFplayDesktopTexture.create() again
5. expect valid texture
6. release texture
```

The second create proves the first failed lookup did **not** poison the process.

Do not run this test after a global `setUpAll` that already initialized FFmpegKit.

Use a dedicated Windows integration test entrypoint if necessary.

---

## Complete-pair test

Exercise a resolver helper with a fake lookup source:

```text
register missing, unregister present -> unavailable
register present, unregister missing -> unavailable
both present -> complete
retry after initial missing -> succeeds
```

This test can be pure C++ and does not need a real malformed DLL if the resolver's commit logic is factored cleanly.

A real local runtime integration remains the final Windows oracle.

---

## Integration with R27-W3

W3 and W4 touch the same plugin.

The final create order should be coherent:

```text
resolve complete frame API
-> release this instance's prior texture
-> create/register Flutter texture
-> process-global owner-aware native frame callback install
-> publish local texture state
-> return textureId
```

The final release order:

```text
move local state
-> conditional owner-aware native unregister
-> drain callback
-> destroy local frame buffers
-> unregister Flutter texture
```

Do not create two unrelated global mutexes with an inverted lock order.

Prefer a clearly documented order between:

```text
symbol resolver mutex
frame registration coordinator mutex
TextureState mutex
native FFplay API mutex
```

The callback itself should not need the resolver/coordinator mutex.

---

## Exit gate

R27-W4 closes only when:

```text
pre-init texture creation fails without a live texture
failed lookup remains retryable
post-init texture creation succeeds
register/unregister symbols are committed atomically as a pair
partial ABI cannot install callback
W3 ownership behavior remains green
```

---

# 7. R27-W5 — Local Windows production validation for Flutter and React Native

## Severity

**High validation gate**

This goal does not create new findings.

It proves W1–W4 and validates the Windows platform surface comprehensively enough for production readiness.

---

## Hard validation rules

- Use the local Windows x86_64 native ABI bundle.
- Do not fetch or substitute a remotely built old bundle.
- Do not publish the native ABI remotely.
- Do not use hosted CI as acceptance evidence.
- Do not silently fall back to a default remote artifact.
- Do not call a build pass a runtime pass.
- Do not weaken a test because Windows behavior is inconvenient.

Set the existing local-only guard where appropriate:

```text
FFMPEG_KIT_EXTENDED_LOCAL_ONLY=true
```

and keep explicit local Windows configuration.

---

## A. Source/build architecture gates

### Flutter

Run the focused architecture tests including W1.

Require:

```text
Windows x64 success
Windows arm64 fail before resolution
```

Run the build-hook Windows extraction/layout tests.

### React Native

Run:

```text
node --test tests/resolve-ffmpeg-kit-config.test.js
```

plus the new Windows architecture cases.

Run the real PowerShell W2 fixture.

---

## B. Flutter package gate

With analytics disabled:

```text
dart --disable-analytics analyze
flutter analyze
flutter test --no-pub --exclude-tags native
```

Also run focused Windows tests explicitly so a future tag/filter change cannot hide them.

Suggested focused list:

```text
test/architecture_mapping_test.dart
test/native_artifact_layout_test.dart
test/windows_extraction_test.dart
```

plus all new W3/W4 tests.

---

## C. Flutter Windows native API gate

Use the local x64 bundle.

Run the native-tagged Windows API tests if supported by the package harness.

At minimum validate in-process:

```text
FFmpegKitExtended.initialize()
getVersion() == expected ABI family
getFFmpegVersion() nonempty
getFFmpegArchitecture() reports x86_64-compatible target
FFmpeg -version
FFprobe -version
media information on generated local file
session history
structured log callback
redirection disable/enable behavior
FFplay session controls
```

Use generated local media so this does not depend on network availability.

---

## D. Flutter Windows FFplay surface gate

This is mandatory because W3/W4 are Windows texture lifecycle findings.

### Pre-init recovery test

Fresh process:

```text
create surface before initialization -> no valid surface
initialize
create surface -> valid textureId
release -> succeeds
```

### Normal playback

Generate a short local video.

Then:

```text
create surface
start FFplay
wait for running
video width > 0
video height > 0
position advances
pause
position/control state behaves
resume
stop
release surface
```

Where feasible, verify an actual frame became available.

Preferred non-invasive evidence:

- integration/UI screenshot or rendered-surface observation; or
- test-only native fixture around frame callback ownership/arrival that does not ship as a public runtime API.

Do not add a permanent public debugging method solely for this test.

### Repeated lifecycle

Run:

```text
100+ create/play/release cycles
```

or another justified bounded stress count.

Assert:

- no crash;
- no dead texture;
- no callback into destroyed state;
- no unbounded texture/state growth.

### Multi-engine/owner oracle

The pure C++ W3 owner test must cover old/new plugin identity even if spinning up two Flutter engines in the automated suite is impractical.

If the local test harness can instantiate two Flutter engines/plugins, also perform the real A/B sequence.

Do not claim a two-engine runtime pass if only the helper test ran.

---

## E. Flutter Windows Release build and deployed DLL audit

Run:

```text
flutter build windows --release
```

against the explicit local x64 bundle.

Inspect the output.

Require:

```text
app executable present
plugin DLL present
libffmpegkit.dll present
selected runtime companion DLLs present
no stale DLLs from previous configured bundle
```

Use file-name set comparison against the selected artifact, not only spot checks.

If CodeAssets intentionally transforms paths/names, document the deterministic expected mapping and compare against that.

---

## F. React Native package gate

Run locally:

```text
npm run check
npm run prepare
npm run test:pack-types
npm run test:pack-web
npm pack --dry-run
```

Keep the Review 26 coordinator tests:

```text
node --test tests/native-bridge-lifetime.test.js
native/log_bridge_registration_coordinator_test.cpp
```

Keep existing Web callback lifetime stress tests.

W27 is Windows-only, but these bounded package tests guard against Windows source/package changes breaking package construction.

---

## G. React Native Windows staging gate

Run the W2 real PowerShell fixture.

Then stage the real local x64 bundle.

Record the exact staged DLL list and SHA-256 for:

```text
libffmpegkit.dll
```

and optionally all companions for reproducibility.

This is local evidence only, not a new mandatory artifact-provenance product feature.

---

## H. React Native Windows Release build

Run the established local Windows build.

Require production outputs:

```text
FFmpegKitExtended.dll
FFmpegKitExtendedExample.exe
```

and, where packaging is part of the normal build, verify package payload root placement of runtime DLLs.

Assert final runtime DLL set equals W2's validated selected manifest.

---

## I. React Native Windows runtime smoke

A build alone is not a complete platform runtime review.

Launch the locally built example/test host with the local x64 runtime.

Exercise:

```text
initialize
FFmpeg async + awaited execution
FFprobe
media information
structured direct log events
session history
redirection authority
FFplay video/audio
pause
resume
seek if supported by fixture
stop
```

For the FFplay Windows view:

```text
view mounted before playback
video dimensions become nonzero
position advances
surface remains valid through pause/resume
unmount current view -> callback unregisters
remount new view -> callback registers and receives playback frames
```

The existing RN Windows `g_activeView` owner guard should remain unchanged unless this runtime test finds an actual defect.

---

## J. Error/failure gates

Use controlled local failures.

### Wrong architecture

```text
Windows arm64
```

must fail before artifact use in both wrappers.

### Missing main runtime

RN staging fixture without `libffmpegkit.dll` must fail.

For Flutter custom Windows artifact, retain existing `selectExactMainLibrary` negative coverage.

### Changed local artifact

RN same-path archive update must refresh.

Flutter existing local file/dependency behavior must remain green.

### FFplay pre-init

Flutter W4 pre-init call must recover after initialization.

---

## K. No stale process acceptance

When runtime tests finish:

- close example apps;
- stop Metro if started;
- remove test-only temporary runtime archives/directories;
- do not commit generated Windows build outputs;
- do not alter the frozen builder checkout.

---

## L. Apple noninteractive validation on `my MacBook Air`

Windows remains the implementation scope for W1–W4, but Apple validation is
part of the amended W5 evidence instead of an automatic deferral.

Use the already verified SSH connection:

```text
host: 192.168.1.189
user: akash
checkout: /Users/akash/Projects/ffmpeg_kit_extended
branch: dev-wasm
```

Before Apple commands:

1. verify the checkout is clean;
2. verify `dev-wasm` is synchronized with `origin/dev-wasm`;
3. use the checkout's local dependencies and the user-approved local ABI
   configuration only;
4. tag or record every long-running process and clean it up before returning.

Run the repository's available noninteractive Apple package/build/test gates,
including Flutter and React Native analysis/package checks and no-code-sign
Apple builds where the local toolchains support them. Do not use hosted Flutter
or React Native workflows, fetch remote native ABI bundles, or publish native
ABI binaries.

Interactive iOS and tvOS simulator tests may be recorded as **deferred** when
the simulator requires GUI interaction unavailable to this session. A deferred
interactive test must include the command attempted, the concrete environment
limitation, and the noninteractive evidence that was completed; it must not be
represented as a runtime pass.

---

## Exit gate

R27-W5 closes only when both wrappers have:

```text
analysis/tests green
Windows x64 Release build green
runtime initialized from local current ABI
FFmpeg green
FFprobe green
media information green
structured log path green
FFplay controls green
Windows-specific W1–W4 regressions green
Apple noninteractive package/build/test gates run on `my MacBook Air`; only GUI-dependent iOS/tvOS simulator tests may be explicitly deferred with evidence
no remote ABI artifact used
```

Record any unavailable runtime gate as **not executed**, not as inferred success.

---

# 8. R27-W6 — Documentation, tracker and exact-source closeout

## Objective

Reconcile only Windows behavior changed or proven by Review 27.

---

## Flutter documentation

Audit/update:

```text
flutter/README.md
flutter/doc/installation.md
flutter/doc/quick-start.md
flutter/doc/architecture.md
Flutter FFplay docs where desktop texture lifetime is described
flutter/CHANGELOG.md
```

Required final facts:

```text
Windows prebuilt/runtime target is x86_64 only
Windows arm64 requests fail closed
FFmpegKitExtended.initialize() precedes FFplay desktop texture creation
failed early FFplay texture resolution does not poison later initialization
only the currently owning Windows texture may unregister the process-global FFplay frame callback
```

Do not imply Linux architecture policy changed.

---

## React Native documentation

Audit/update:

```text
react-native/README.md
react-native/TEST.md
react-native/CHANGELOG.md
```

Required final facts:

```text
Windows target = x86_64
local Windows archives are content-refreshed when bytes change
runtime staging is an exact selected DLL set
libffmpegkit.dll is mandatory
duplicate flattened DLL names fail
local Windows validation uses the configured local ABI bundle
```

Do not document SHA enforcement as a product requirement for official GitHub releases.

---

## Tracker

Add a new Review 27 section above Review 26.

Record only:

```text
R27-W1 Windows x64 architecture authority
R27-W2 RN Windows runtime staging freshness/coherence
R27-W3 Flutter Windows FFplay global frame-owner safety
R27-W4 Flutter Windows FFplay retryable symbol resolution
R27-W5 local Windows production validation
R27-W6 closeout
```

Do not re-add excluded Review 24–26 findings.

---

## Review report

Create:

```text
.agent/review27-windows-production-readiness-report.md
```

Include:

```text
Review 26 prerequisite PASS evidence
starting wrapper SHA
frozen native SHA
each Windows finding and reproduction
implementation design
files changed
focused tests
PowerShell staging fixture results
Flutter Windows runtime results
RN Windows runtime results
Release build/package outputs
final wrapper SHA/tree SHA
residual Windows risk
```

---

## Source freeze

Before closeout:

```text
git status --short
git diff --check
git rev-parse HEAD
git rev-parse HEAD^{tree}
```

Product worktree must be clean.

No generated:

```text
build/
vendor runtime fixture output/
temporary ZIPs/
Windows package outputs/
Metro bundle scratch/
```

should be committed unless already intentional tracked source.

---

## Source-only snapshot

After the final product SHA is frozen, a source-only snapshot may be produced if the established local project process requires it.

It is provenance only.

Do not treat the snapshot workflow as Windows runtime validation.

Do not run hosted platform CI as a substitute for W5.

---

# 9. Hard implementation order

Use:

```text
Review 26 PASS
  -> R27-W1
  -> R27-W2
  -> R27-W3
  -> R27-W4
  -> R27-W5
  -> R27-W6
```

W3 and W4 touch the same Flutter Windows plugin and may be implemented in one carefully reviewed branch sequence, but preserve separate test oracles and tracker evidence.

Do not start final Windows runtime validation until W1–W4 are implemented.

---

# 10. Luna reasoning guidance by goal

## R27-W1 — Think

Questions Luna must answer before editing:

```text
What is the actual frozen native Windows architecture set?
Which wrapper APIs currently accept ARM64?
Can any custom override bypass platform-specific validation?
Which helper is shared with Linux and therefore must not be narrowed globally?
```

Do not solve by relabeling.

---

## R27-W2 — Think

Model the staging system as:

```text
source identity
source bytes
extraction identity
validated DLL manifest
dedicated staging directory
MSBuild deployment set
```

Correctness requires byte changes to flow through all five stages.

Do not reason only from filenames.

---

## R27-W3 — Think

Treat these as separate lifetimes:

```text
Flutter plugin instance
Flutter TextureState
process-global FFplay callback registration
native in-flight callback
Flutter texture registration
```

The defect exists because local object ownership was being used as if it implied process-global registration ownership.

---

## R27-W4 — Think

Treat symbol resolution as a retryable state machine.

Do not equate:

```text
"we tried once"
```

with:

```text
"runtime ABI is resolved"
```

Commit only a complete symbol pair.

---

## R27-W5 — Think for failures, Instant for commands

Once commands are established, execution can be mechanical.

Any Windows-only runtime failure requires source/dataflow analysis before changing product code.

Do not add sleep/retry workarounds without identifying the state transition they are synchronizing.

---

## R27-W6 — Instant after behavior is frozen

Documentation should describe proven behavior.

Do not use closeout as an opportunity for unrelated cleanup.

---

# 11. Test truthfulness rules

Luna must follow these rules for this review.

## Do not fabricate

Never state:

```text
passed
validated
green
production-ready
```

for a command that did not actually execute successfully.

## Do not substitute weak tests

Examples of unacceptable substitutions:

```text
source regex instead of W2 real PowerShell same-path ZIP test
source regex instead of W3 executable owner state machine
successful compile instead of Windows runtime smoke
successful FFplay session without testing W4 pre-init recovery
```

## Do not weaken scenarios

Do not:

- remove ARM64 negative cases because they fail;
- delete stale-DLL assertions;
- skip duplicate-basename case;
- avoid stale plugin teardown case;
- initialize FFmpegKit before the W4 pre-init regression;
- filter callback lifetime tests.

## Report mistakes

If implementation initially:

- stages stale files;
- deadlocks;
- breaks x64;
- causes FFplay callback loss;
- poisons later initialization;

record the error directly and correct it.

Do not hide it by changing tracker language.

---

# 12. Semantic naming rule

Do not name production artifacts after planning/review identifiers.

Bad:

```text
Review27WindowsFix
W3Coordinator
R27RuntimeManifest
```

Good:

```text
windowsArtifactArchitecture
RuntimeDllManifest
FrameCallbackRegistrationCoordinator
FFplayFrameApi
resolveFFplayFrameApi
```

Tests may mention the regression behavior, not the planning goal number, in test names.

---

# 13. Files likely to change

This is guidance, not a requirement to edit every file.

## R27-W1

Likely:

```text
flutter/hook/native_artifact.dart
flutter/hook/build.dart
flutter/test/architecture_mapping_test.dart

react-native/scripts/resolve-ffmpeg-kit-config.js
react-native/scripts/prepare-windows-runtime.ps1
react-native/tests/resolve-ffmpeg-kit-config.test.js

Flutter/RN Windows docs
```

## R27-W2

Likely:

```text
react-native/scripts/prepare-windows-runtime.ps1
react-native/tests/windows-runtime-packaging.test.js
react-native/tests/<real Windows staging fixture>
react-native/TEST.md
```

Do not change `FFmpegKitDynamicApi` unless the staging/runtime test proves a separate loader defect after coherent staging is fixed.

## R27-W3/W4

Likely:

```text
flutter/windows/ffmpeg_kit_extended_flutter_plugin.cpp
flutter/windows/include/.../<semantic coordinator/helper>.h
flutter/test or windows test-only helper source
flutter/lib/src/platform/native/ffplay_desktop_texture.dart   # docs/error contract only if needed
Flutter FFplay docs
```

Do not modify React Native FFplay ownership merely to share implementation.

---

# 14. Regression invariants inherited from Reviews 23–26

Review 27 must preserve all of the following.

## Structured log transport

```text
one structured native callback ABI
session ID exact
sequence exact
level exact
message exact
owned message released once
no steady-state full-history polling
bounded terminal reconciliation
```

## Demand/lifecycle

```text
callback activation remains demand-driven
completion is independent of optional log/stat consumers
disableRedirection remains authoritative
first error remains authoritative
```

## Review 25

```text
RN Web callback pointer is not recycled while delayed native work may hold it
native/Windows structured-log bridge state remains bounded
stale Flutter packaged old-ABI Wasm runtime remains removed
```

## Review 26

```text
latest successful RN module owns process-global structured-log registration
stale RN module teardown cannot clear a newer owner's registration
```

## Build/runtime

```text
DataAssets are not reintroduced
native ABI remains 0.11.2
no _v2 callback is reintroduced
local ABI bundle remains test authority
```

---

# 15. Pre-fix evidence Luna should record

Before implementation, record concise reproductions.

## W1

React Native exact source currently permits a result equivalent to:

```json
{
  "platform": "windows",
  "architecture": "arm64",
  "override": {
    "kind": "local",
    "value": "...windows-x86_64...zip"
  }
}
```

while the Windows projects contain only x64 configurations.

Flutter's current architecture tests explicitly accept:

```text
desktopArtifactArchitecture(Architecture.arm64, platform: 'windows')
-> arm64
```

Record both.

---

## W2

On a Windows test shell:

```text
same local ZIP path
content A -> stage
replace with content B -> stage again
```

Record that Review 26 reuses old extraction/staging before the fix.

Also record stale destination behavior with a DLL removed between A and B.

---

## W3

Use the owner helper or minimal extraction of current behavior:

```text
A create
B create
A release/destructor
```

Record the unconditional unregister call from A's release path.

---

## W4

Fresh process:

```text
createTexture before FFmpegKit initialize
```

Record:

```text
GetModuleHandle misses runtime
once_flag consumed
texture create returns apparent success/current behavior
later initialization cannot make resolver retry
```

If direct app behavior differs due another startup side effect loading the DLL, preserve the source finding but document that the concrete host loaded the DLL earlier. Then create a deterministic resolver/helper regression that controls the lookup sequence.

Do not invent runtime evidence.

---

# 16. Final Windows production-readiness definition

Review 27 can be closed only when all of the following are true.

1. Review 26 remains passed and its ownership regression tests remain green.
2. Windows is advertised and accepted as x86_64 only across Flutter and React Native.
3. Windows ARM64 cannot reach custom override selection, remote artifact resolution, extraction or build staging.
4. React Native local Windows ZIP changes at the same path invalidate stale extraction by byte identity.
5. React Native staging contains exactly the DLL set from the current selected runtime.
6. React Native staging requires exactly one `libffmpegkit.dll`.
7. Recursive duplicate DLL basenames are rejected rather than flattened nondeterministically.
8. React Native Windows Release build consumes the current validated staging set.
9. Flutter Windows FFplay frame callback has process-global current-owner protection.
10. A stale Flutter plugin/engine cannot unregister a newer engine's FFplay frame callback.
11. Current Flutter frame owner unregister still drains in-flight callback before state destruction.
12. Flutter FFplay symbol lookup is retryable after an early unavailable-runtime lookup.
13. Flutter FFplay symbol pair is committed atomically only when both register and unregister exports exist.
14. Flutter texture creation does not report a live texture when the native frame API is unavailable.
15. A fresh-process pre-init Flutter FFplay surface failure can recover after `FFmpegKitExtended.initialize()`.
16. Flutter local Windows native APIs execute against the current local x64 ABI bundle.
17. React Native local Windows native APIs execute against the current local x64 ABI bundle.
18. FFmpeg, FFprobe and media-information runtime paths pass in both wrappers.
19. Structured direct-log behavior remains correct in both wrappers.
20. FFplay playback/control paths pass in both Windows hosts.
21. No remote native ABI artifact or hosted CI run is used as acceptance evidence.
22. No native ABI publication occurs.
23. DataAssets are not reintroduced.
24. The accepted TSan/TLS/UBSAN/`ffigen_js` dispositions are not reopened without new evidence.
25. Documentation and tracker accurately state the final Windows contract.
26. One clean exact wrapper source SHA/tree is frozen at closeout.

When all applicable local runtime gates actually pass, Windows can be considered production-ready for the reviewed Flutter and React Native surfaces at that exact wrapper source and the frozen local `0.11.2` native ABI.
