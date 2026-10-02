# Review 43 — Flutter + React Native Platform-Native Bridge Code Review

**Project:** FFmpegKitExtended  
**Review type:** frozen-source platform-native code review; substantive findings only  
**Date:** 2026-10-01  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch represented by snapshot:** `dev-wasm`  
**Frozen wrapper source:** `e798d1b07f55e07a042cb33faf4fc55867d70493`  
**Snapshot workflow:** `36955190477`  
**Snapshot artifact:** `review42-source-snapshot-36955190477`  
**Artifact ID:** `11206105842`  
**Outer artifact SHA-256:** `a86289b1e4a03926d8ba8b61ae041a8be879fa8f4396ebfc5d54c5803ea77672`  
**Embedded `source.tar.gz` SHA-256:** `f06ac5ee92b63d755eb64a737bafaf277fd3487d8fcf22801938c9c3b4e1616e`  
**Manifest:** **1,090/1,090 verified**  
**Symlinks:** `0`  
**Snapshot bytes:** `27,862,197`  
**Recursive submodule:** `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`  
**Native ABI/runtime:** `0.11.2`, frozen/read-only; not independently downloaded or reviewed

---

## 1. Review authority and provenance

Review 43 uses the exact wrapper-only source snapshot frozen at the end of Review 42. The review did **not** read repository source piecemeal from the GitHub connector.

The source artifact was downloaded from Review 42 workflow run `36955190477` and verified before code inspection:

```text
GitHub artifact digest:
  a86289b1e4a03926d8ba8b61ae041a8be879fa8f4396ebfc5d54c5803ea77672

Downloaded outer ZIP SHA-256:
  a86289b1e4a03926d8ba8b61ae041a8be879fa8f4396ebfc5d54c5803ea77672

snapshot-metadata.snapshot_sha:
  e798d1b07f55e07a042cb33faf4fc55867d70493

snapshot-metadata.runtimeExecution:
  false

source.tar.gz SHA-256:
  f06ac5ee92b63d755eb64a737bafaf277fd3487d8fcf22801938c9c3b4e1616e

SHA256SUMS:
  1090/1090 verified

SYMLINKS.tsv:
  0 entries

SUBMODULES.txt:
  b74da2c5d1e294b87d15d73a6687393729e932b3 libs/libffmpegkit (b74da2c)
```

No native/builders artifact was downloaded. The native ABI remains frozen at `0.11.2` and is outside Review 43 source scope.

---

## 2. Review boundary

This was **code review only**.

No tests, builds, compilers, simulator/device launches, interactive applications, hosted CI, repository mutation, or native-runtime execution were performed as Review 43 evidence.

Reviewed platform-native surfaces:

```text
Flutter
  flutter/native/
  flutter/windows/
  flutter/linux/
  flutter/android/
  flutter/ios/
  flutter/macos/

React Native
  react-native/cpp/
  react-native/windows/
  react-native/android/
  react-native/ios/
  react-native/appletvos/
  react-native/macos/

Native-facing React Native TypeScript
  react-native/src/NativeFFmpegKitExtended.ts
  react-native/src/platform/backend.native.ts
  react-native/src/platform/native-session-reconciliation.ts
  related session/history/cancellation ownership paths where needed
```

The following were intentionally excluded from findings:

```text
formatting/style
naming preferences
procedural/tracker-only observations
documentation-only drift without product effect
speculative hardening
framework-required platform differences
resource-exhaustion-only hypotheticals without a practical bridge consequence
native ABI internals already frozen outside the wrapper snapshot
```

A Review 43 finding requires all of:

```text
a reachable wrapper path
an actual platform/framework contract violation or ownership/concurrency defect
a concrete user-visible or lifecycle consequence
source evidence from the frozen wrapper snapshot
```

---

## 3. Executive disposition

Review 43 found **one substantive platform-native bridge defect**.

| ID | Severity | Surface | Finding |
| --- | --- | --- | --- |
| **R43-F1** | **Medium** | Flutter iOS FFplay texture creation, CocoaPods + SwiftPM source copies | `registerTexture:` failure is not checked. Flutter defines texture ID `0` as registration failure, but both iOS implementations continue by publishing frame notification state, retaining the texture, installing it as the process-global FFplay frame owner, and returning `{textureId: 0}` as success. The Dart layer consequently creates a non-null `FFplaySurface` for an unregistered texture. |

No native ABI change is required.

No substantive React Native defect was established in this pass. Review 42's session-operation composability fix is present and coherent.

---

# 4. R43-F1 — Flutter iOS treats failed external-texture registration as success

**Severity:** Medium  
**Primary surface:** Flutter iOS FFplay rendering  
**Affected packaging paths:** CocoaPods and Swift Package Manager  
**Native ABI change:** none

## 4.1 Affected files

Both iOS source copies contain the same semantic defect:

```text
flutter/ios/Classes/FfplayKitPlugin.m
flutter/ios/ffmpeg_kit_extended_flutter/Classes/ffmpeg_kit_native/FfplayKitPlugin.m
```

The duplicated source is intentional because the first path is consumed by CocoaPods and the second by the package's SwiftPM target. Both must be updated together.

## 4.2 Current CocoaPods path

Frozen source around `flutter/ios/Classes/FfplayKitPlugin.m:444-475`:

```objc
- (void)handleCreateTexture:(FlutterResult)result {
  if (!ResolveFFplayFrameAPI()) {
    ...
    return;
  }

  [self releaseTextureState];
  FfkitPixelTexture *tex = [[FfkitPixelTexture alloc] init];
  int64_t tid = [_textureRegistry registerTexture:tex];

  __weak NSObject<FlutterTextureRegistry> *weakReg = _textureRegistry;
  tex.onFrameAvailable = ^{
    [weakReg textureFrameAvailable:tid];
  };

  _texture = tex;
  _textureId = tid;
  _retainedTexPtr = (__bridge_retained void *)tex;
  ...
  FfplayInstallOwner(_retainedTexPtr, ^{
    _ffplay_kit_register_frame_callback_fn(ffplay_frame_cb, _retainedTexPtr);
  });
  ...
  result(@{@"textureId" : @(tid)});
}
```

There is no `tid == 0` failure branch.

## 4.3 Current SwiftPM path

Frozen source around:

```text
flutter/ios/ffmpeg_kit_extended_flutter/Classes/ffmpeg_kit_native/FfplayKitPlugin.m:443-474
```

has the same sequence and the same missing check.

## 4.4 Flutter's iOS contract

Flutter's iOS embedder documents `FlutterTextureRegistry.registerTexture:` as returning a texture ID on success and **`0` on failure**.

Authoritative API reference:

```text
https://api.flutter.dev/ios-embedder/protocol_flutter_texture_registry-p.html
```

The current macOS implementation already honors the equivalent Darwin contract:

```objc
int64_t tid = [_textureRegistry registerTexture:tex];

if (tid == 0) {
  result([FlutterError errorWithCode:@"TEXTURE_REGISTRATION_FAILED"
                             message:@"Flutter could not register the FFplay texture"
                              details:nil]);
  return;
}
```

This makes the iOS omission a concrete platform parity defect rather than a proposed hardening change.

---

## 5. Reachable failure sequence

A registration failure can occur when Flutter's texture registry cannot register the external texture, including when the registry/engine is no longer in a usable registration state. Flutter reports that condition as ID `0`.

Current iOS sequence:

```text
Dart:
  FFplaySurface.create()
    -> FFplayDesktopTexture.create()
    -> MethodChannel createTexture

Objective-C:
  release previous texture
  allocate FfkitPixelTexture
  tid = registerTexture(tex)
  tid == 0                 <-- Flutter says registration failed

CURRENT behavior continues:
  install onFrameAvailable closure using texture ID 0
  publish _texture = tex
  publish _textureId = 0
  __bridge_retained tex
  install process-global FFplay frame callback owner
  return { textureId: 0 }

Dart:
  receives a non-null map
  creates FFplayDesktopTexture(textureId: 0)
  creates non-null FFplaySurface
  Texture(textureId: 0) is rendered as though registration succeeded
```

This violates the public Dart contract in `FFplayDesktopTexture.create()`, whose documentation states that creation returns `null` when texture creation fails.

---

## 6. Product consequence

The failure is not limited to an inaccurate error message.

When `registerTexture:` returns `0`, the current iOS wrapper can:

```text
report FFplay surface creation as successful
return a Texture widget referencing an unregistered texture ID
install frame delivery for a texture Flutter never registered
retain that native texture until explicit release
make the failed texture the process-global FFplay output owner
replace a previously valid FFplay surface before the failed registration attempt
```

The visible result can be a non-null playback surface that never renders video while FFplay frames are still routed to that failed surface state.

The correct behavior is to stop immediately after the failed Flutter registration and return `TEXTURE_REGISTRATION_FAILED`, allowing the Dart layer to return `null`.

---

## 7. Required implementation semantics

Immediately after `registerTexture:` on iOS:

```objc
int64_t tid = [_textureRegistry registerTexture:tex];
if (tid == 0) {
  result([FlutterError errorWithCode:@"TEXTURE_REGISTRATION_FAILED"
                             message:@"Flutter could not register the FFplay texture"
                              details:nil]);
  return;
}
```

The guard must occur **before** all of the following:

```text
onFrameAvailable callback installation
_texture publication
_textureId publication
__bridge_retained ownership
FfplayInstallOwner / native frame callback registration
success result containing textureId
```

On this branch:

```text
tex remains a local ARC object and is released naturally
_texture remains nil
_textureId remains -1
_retainedTexPtr remains nil
no FFplay owner is installed
no native frame callback is installed
no unregisterTexture call is needed because Flutter registration failed
Dart receives PlatformException and FFplayDesktopTexture.create() returns null
```

Apply the same semantic fix to both iOS source copies.

Do **not** refactor unrelated Apple FFplay ownership code to implement this one check.

---

## 8. Required regression coverage

Review 43 did not execute tests. The remediation must add evidence for the failure branch.

### 8.1 Deterministic source-contract regression

Add a focused Dart source-contract test, suggested name:

```text
flutter/test/apple_ffplay_texture_registration_test.dart
```

The test should inspect both:

```text
flutter/ios/Classes/FfplayKitPlugin.m
flutter/ios/ffmpeg_kit_extended_flutter/Classes/ffmpeg_kit_native/FfplayKitPlugin.m
```

For each source, prove semantically that:

```text
registerTexture result is assigned to tid
failure is identified as tid == 0
failure reports TEXTURE_REGISTRATION_FAILED
failure returns before onFrameAvailable setup
failure returns before _texture/_textureId publication
failure returns before __bridge_retained
failure returns before FfplayInstallOwner
failure returns before successful textureId result
```

Do not assert exact whitespace or full-file byte equality because the SwiftPM copy intentionally differs in include paths/formatting.

### 8.2 Apple native behavior test if the existing local harness can support it without new infrastructure

If the current Apple test setup can inject a `FlutterTextureRegistry`, use a fake registry whose `registerTexture:` returns `0` and invoke the real plugin create path.

Assert:

```text
result is FlutterError
error.code == TEXTURE_REGISTRATION_FAILED
no success map is returned
fake registry receives exactly one registration attempt
no textureFrameAvailable call occurs
plugin does not expose a live texture ID
```

Do not create a large new XCTest project solely to force this one branch if the repository has no reusable native Apple test target. The source-contract regression plus the affected local iOS build is an acceptable minimum for this narrow wrapper guard.

### 8.3 Existing success path

Preserve the existing normal iOS app-hosted FFplay surface behavior. Do not turn texture ID `0` into a valid success sentinel.

---

## 9. Documentation guidance

No public API documentation change is required.

Existing Dart/API documentation already states the desired behavior:

```text
FFplayDesktopTexture.create() returns null if texture creation fails.
FFplaySurface.create() returns a surface instance or null if creation fails.
```

The implementation should be corrected to match that contract.

Add at most one local maintenance comment near the new iOS guard if useful, for example:

```objc
// FlutterTextureRegistry uses 0 as the Darwin registration-failure sentinel.
```

Do not add Review 43 identifiers to production comments or symbols.

---

# 10. Verification of the Review 42 shared-C++ fix

Review 43 re-read the Review 42 shared React Native registry lifetime implementation.

The intended structure is present:

```text
SessionOperationToken
  last shared token releases one activeSessionOperations slot

SessionOperationLease
  copyable shared token authority

acquireSessionWithinOperation
  uses an existing admitted token

acquireHistorySessionWithinOperation
  reuses existing token
  does not reacquire the clear admission gate
  does not wait for clearSessionsInProgress after admission

getSessionsJson
getLastSessionJson
  each acquires one top-level operation token
  each reuses that token across the complete history projection

clearSessions
  publishes exclusivity
  waits activeSessionOperations == 0
  performs native clear
  clears retained wrapper state/history
  reopens admission only after the local commit
```

No recurrence of R42-F1 was found.

The new deterministic `history_clear_composability_test.cpp` covers the expected history/clear interleavings in source. Review 43 did not execute it.

---

# 11. React Native platform-native audit

## 11.1 Shared C++ ownership/concurrency

Reviewed:

```text
SessionOperationToken / SessionOperationLease
HandleGuard
RetainedHandleLease
acquireSession / acquireSessionWithinOperation
ensureRetainedSession
acquireHistorySessionWithinOperation
releaseRetainedSession
history projection
create/session execution/cancel
clearSessions
FFplay getters/actions
media/statistics/debug-log access
```

No additional substantive concurrency or raw-handle escape defect was established.

In particular:

```text
owned temporary handle release precedes operation-token release
retained borrow release precedes operation-token release
history nested acquisition reuses the outer token
clear does not hold sessionHandlesMutex during native clear
clear failure reopens admission
```

## 11.2 Windows error transport

Reviewed the Windows TurboModule contract and implementation.

Failure-bearing Promise methods use invocation-bound completion through `completeAction`/`invokeWithCompletion`. Synchronous methods retain the same-call `consumeSynchronousError` diagnostic path.

No reintroduction of:

```text
thread-local asynchronous action errors
cross-call Promise error state
blanket fail-fast/terminate behavior
```

was found.

## 11.3 React Native log callback ownership

Shared C++ and Windows keep callback user data alive after module retirement and serialize the process-global callback owner.

The callback copies native log payloads before asynchronous JS delivery and releases the native payload exactly once.

No new substantive callback lifetime defect was established.

## 11.4 React Native Windows FFplay view

Preserved:

```text
latest process-global owner
old owner stops accepting frames before replacement
callback unregister before active owner destruction
weak UI dispatch
latest-frame coalescing
packed RGBA/BGRA/ARGB/ABGR conversion
opaque alpha for rgb0/bgr0
```

No new finding.

## 11.5 React Native Android FFplay view

Preserved:

```text
one process-global Surface owner
stale view cannot clear a newer owner's target
Java Surface lifetime separated from owner identity
surface destruction detaches only when current owner
```

No new finding.

## 11.6 React Native Apple FFplay views

Reviewed iOS, tvOS, and macOS implementations.

Preserved:

```text
process-global coordinator
weak current-view reference
previous owner stops accepting frames before replacement
native unregister/drain before active owner detachment
locked pixel-buffer/sample-buffer state
latest-frame coalescing
main-thread display enqueue
packed format conversion and rgb0/bgr0 alpha repair
```

No new finding.

---

# 12. Flutter platform-native audit

## 12.1 Windows

Preserved:

```text
complete register/unregister symbol pair resolution
registration failure handling
latest-owner callback coordination
callback-captured TextureState lifetime through asynchronous unregister
packed-frame normalization
render-buffer lifetime after CopyPixelBuffer returns
```

No new finding.

## 12.2 Linux

Preserved:

```text
complete callback symbol pair resolution
FlPixelBufferTexture ownership
registration failure handling
latest-owner callback coordination
queued-idle GObject reference lifetime
frame notification coalescing
PixelBufferFrameStore lifetime through unregister
packed-frame normalization
```

No new finding.

## 12.3 Android

Preserved:

```text
SurfaceTextureEntry ownership
Java Surface ownership
native ANativeWindow reference release
process-global surface coordinator
stale engine/surface cannot clear newer native target
```

No new finding.

## 12.4 macOS

macOS already handles `registerTexture:` returning `0` before callback ownership is published.

Its CocoaPods and SwiftPM FFplay implementations remain semantically aligned apart from expected include-path/formatting differences.

No new finding.

## 12.5 iOS

R43-F1 is the sole substantive finding from this surface.

Both CocoaPods and SwiftPM source copies omit the Darwin `tid == 0` failure branch.

---

# 13. Why prior green validation did not disprove R43-F1

Review 42's Apple builds and Flutter package/integration tests demonstrated successful texture/build paths with the configured local artifact. They did not force `FlutterTextureRegistry.registerTexture:` to fail.

The repository currently has no focused test that asserts the iOS `0` failure sentinel is handled before FFplay owner publication.

A successful build therefore does not exercise or disprove this failure-path defect.

---

# 14. Review 43 remediation goals

| Goal | Required result |
| --- | --- |
| **R43-G1** | Make Flutter iOS FFplay texture creation failure-atomic: treat `registerTexture:` returning `0` as `TEXTURE_REGISTRATION_FAILED` before any wrapper/native owner state is published, in both CocoaPods and SwiftPM source copies. |
| **R43-G2** | Add focused regression coverage that proves the iOS failure guard exists in both packaging paths and precedes callback/ownership/success publication. |
| **R43-G3** | Preserve all accepted FFplay owner, callback drain, texture lifetime, packed-frame, and React Native registry/clear invariants; make no unrelated platform-native refactor. |
| **R43-G4** | Run only affected local noninteractive validation after remediation, using the existing local frozen ABI `0.11.2`; no hosted acceptance workflow and no remote native artifact retrieval. |
| **R43-G5** | Perform one final bounded substantive bridge audit and, only if clean, freeze the exact wrapper SHA and create one verified wrapper-only source snapshot. |

---

# 15. Review 43 closeout

```text
Wrapper source authority: VERIFIED
Outer artifact digest: VERIFIED
Embedded source archive: VERIFIED
Manifest: 1090/1090
Symlinks: 0
runtimeExecution: false
Frozen submodule provenance: VERIFIED

Native ABI separately downloaded: NO
Native ABI reviewed: NO
Native ABI source change required: NO

Code review only: YES
Tests/builds/runtime executed by Review 43: NO
Repository mutation by Review 43: NO

Substantive findings: 1
  R43-F1 Medium — Flutter iOS external-texture registration failure is
                   published as a successful FFplay surface in both Apple
                   packaging source copies.

Pedantic findings reported: 0
Procedural findings reported: 0
Documentation-only findings reported: 0

Disposition:
NOT YET PLATFORM-NATIVE BRIDGE CLEAN.

The remaining code gap is narrow and wrapper-only. Correct both iOS source
copies, add focused failure-path coverage, run affected local validation, and
re-audit before declaring final platform-native bridge closure.
```
