# Review 43 — Luna Platform-Native Bridge Closure Plan

**Project:** FFmpegKitExtended  
**Audience:** Luna implementation/review model  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Branch:** `dev-wasm`  
**Starting source authority:** `e798d1b07f55e07a042cb33faf4fc55867d70493`  
**Review basis:** `review-43-platform-native-bridge-code-review.md`  
**Native ABI/runtime:** frozen `0.11.2`  
**Frozen native submodule:** `b74da2c5d1e294b87d15d73a6687393729e932b3`

---

# 1. Goal tracker

| Goal | Objective | Production implementation | Required tests | Documentation/comments | Status |
| --- | --- | --- | --- | --- | --- |
| **R43-G1** | Make Flutter iOS FFplay texture registration failure-atomic in both Apple packaging source copies | Add the `tid == 0` guard immediately after `registerTexture:` and before any callback/owner/public state publication | Focused source-contract regression for both iOS copies; optional native fake-registry behavior test if existing Apple harness supports it | One semantic comment at most; no public API change | ☐ |
| **R43-G2** | Prove CocoaPods/SwiftPM iOS parity for this failure path without brittle byte-for-byte assertions | Keep both copies semantically equivalent while preserving include-path/formatting differences | Verify guard ordering and identical error contract in both sources | Test comments describe the Flutter failure sentinel, not review IDs | ☐ |
| **R43-G3** | Preserve every already-closed platform-native ownership/concurrency/error invariant | No unrelated production edits | Existing affected Flutter tests plus targeted regression; no weakened tests | No broad docs cleanup | ☐ |
| **R43-G4** | Run affected local noninteractive validation against frozen local ABI `0.11.2` | Wrapper repository only | Focused Flutter test(s), analysis if applicable, iOS build(s); no interactive app launch | Record exact commands/results truthfully | ☐ |
| **R43-G5** | Perform final substantive bridge audit and freeze one exact wrapper-only source snapshot if clean | No source change during audit unless a concrete defect is found | No hosted acceptance CI; source snapshot only after exact SHA freeze | Tracker/final closure provenance | ☐ |

---

# 2. Mission

Review 42 closed the shared React Native history/clear composability defect and froze the wrapper at:

```text
e798d1b07f55e07a042cb33faf4fc55867d70493
```

Review 43 found one remaining wrapper-level platform-native defect:

> Flutter iOS ignores the documented `0` failure sentinel from
> `FlutterTextureRegistry.registerTexture:` and continues publishing the failed
> texture as the process-global FFplay output owner.

The target is intentionally narrow.

Do **not** redesign FFplay ownership, native callbacks, Dart surfaces, or the native ABI.

The target is:

> Make iOS texture creation fail before any owner/lifetime state is published,
> keep CocoaPods and SwiftPM behavior equivalent, prove the failure-path ordering,
> then perform a final bounded platform-native audit.

---

# 3. Non-negotiable constraints

Luna must treat all of these as mandatory.

1. Work in `akashskypatel/ffmpeg-kit-extended`, branch `dev-wasm`.
2. Start from/reconcile against exact wrapper source:
   `e798d1b07f55e07a042cb33faf4fc55867d70493`.
3. Keep native ABI/runtime pinned to **0.11.2**.
4. Keep `libs/libffmpegkit` frozen at:
   `b74da2c5d1e294b87d15d73a6687393729e932b3`.
5. Do **not** download or re-review the native ABI.
6. Do **not** edit the native submodule.
7. Do **not** edit/rebuild the ManyLinux builder checkout.
8. Do **not** add/change native exported symbols.
9. Do **not** publish native ABI artifacts.
10. Do **not** fetch a remotely built old native bundle for local tests.
11. Use the existing locally configured/package native ABI artifacts only.
12. Do **not** run hosted Flutter/React Native build/test workflows as acceptance evidence.
13. The only hosted workflow allowed at final closure is the exact wrapper source-snapshot workflow.
14. Do **not** run interactive Flutter/React Native UI/runtime validation automatically.
15. Final interactive validation remains user-owned.
16. This remediation is wrapper-only and should normally change only the two iOS FFplay source copies plus focused tests/tracker/docs evidence.
17. Production/test identifiers must be semantic; do not use `R43`, `G1`, `F1`, or review names in implementation symbols.
18. Never fabricate tests or test results.
19. Do not weaken existing tests.
20. Record failed commands, environment corrections, retries, and skipped gates truthfully.
21. Exclude pedantic/style/procedural findings from the final audit.
22. A new finding needs a reachable path and concrete product consequence.
23. Do not reopen Review 42 shared-C++ behavior without concrete contradictory source evidence.
24. Do not broaden the change into Apple plugin cleanup, formatting normalization, or duplicate-source consolidation.

---

# 4. Frozen source provenance to preserve

Review 43 source authority was verified from Review 42 snapshot workflow:

```text
workflow run:
  36955190477

artifact:
  review42-source-snapshot-36955190477

artifact ID:
  11206105842

artifact SHA-256:
  a86289b1e4a03926d8ba8b61ae041a8be879fa8f4396ebfc5d54c5803ea77672

source.tar.gz SHA-256:
  f06ac5ee92b63d755eb64a737bafaf277fd3487d8fcf22801938c9c3b4e1616e

SHA256SUMS:
  1090/1090 verified

SYMLINKS.tsv:
  0 entries

runtimeExecution:
  false

submodule:
  b74da2c5d1e294b87d15d73a6687393729e932b3 libs/libffmpegkit
```

Do not substitute a later tracker-only commit for this starting source authority unless the tracker explicitly records a new implementation SHA.

---

# 5. Starting behavior that must be preserved

## 5.1 Flutter Windows FFplay

Preserve:

```text
complete callback symbol-pair resolution
registration failure is rejected
latest-owner semantics
old state cannot unregister a newer owner
asynchronous Flutter texture retirement owns callback-captured TextureState
packed-frame normalization for rgba/rgb0/bgra/bgr0/argb/abgr
opaque alpha repair for rgb0/bgr0
```

No Windows production change is required for Review 43.

## 5.2 Flutter Linux FFplay

Preserve:

```text
FlPixelBufferTexture engine-side texture lifetime
queued idle callback GObject references
frame notification coalescing
PixelBufferFrameStore CPU-byte lifetime
latest-owner semantics
registration failure rejection
packed-frame normalization
```

No Linux production change is required.

## 5.3 Flutter Android FFplay

Preserve:

```text
SurfaceTextureEntry ownership
Java Surface ownership
native ANativeWindow reference release
process-global SurfaceOwnerCoordinator
stale surface/plugin cannot clear a newer native target
```

No Android production change is required.

## 5.4 Flutter macOS FFplay

Preserve the existing correct registration-failure branch:

```objc
int64_t tid = [_textureRegistry registerTexture:tex];

if (tid == 0) {
  result([FlutterError errorWithCode:@"TEXTURE_REGISTRATION_FAILED"
                             message:@"Flutter could not register the FFplay texture"
                              details:nil]);
  return;
}
```

Do not change macOS merely to make formatting match iOS.

## 5.5 React Native shared registry lifetime

Preserve the Review 42 operation model:

```text
one top-level operation admission token
nested history/session helpers reuse the token
no post-admission clear wait
clear blocks only new admission
clear waits admitted tokens to drain
owned native handle / retained borrow retires before operation token
```

Do not touch this code absent a new concrete defect.

## 5.6 React Native platform surfaces

Preserve:

```text
Windows invocation-bound Promise errors and same-call sync diagnostics
Windows FFplay callback owner and weak dispatch
Android Surface latest-owner semantics
Apple callback unregister/drain and weak coordinator ownership
log callback copied payload and retired userdata lifetime
```

No React Native production change is required by R43-F1.

---

# 6. Root cause Luna must understand before editing

Flutter's Darwin `FlutterTextureRegistry` uses this contract:

```text
registerTexture(texture)
  success -> nonzero texture identifier
  failure -> 0
```

Flutter iOS currently does:

```text
register texture
ignore whether returned id is 0
publish callback closure
publish wrapper texture state
bridge-retain texture
install process-global FFplay frame owner
return texture ID to Dart
```

This converts a Flutter registration failure into apparent success.

The Dart layer then receives a non-null map and constructs:

```text
FFplayDesktopTexture(textureId: 0)
FFplaySurface(textureId: 0)
Texture(textureId: 0)
```

The correct transaction boundary is:

```text
register texture
IF registration failed:
  return FlutterError
  publish nothing
ELSE:
  publish callback + owner/lifetime state
  return valid texture ID
```

---

# 7. R43-G1 — exact production implementation

Change exactly these two implementation files:

```text
flutter/ios/Classes/FfplayKitPlugin.m
flutter/ios/ffmpeg_kit_extended_flutter/Classes/ffmpeg_kit_native/FfplayKitPlugin.m
```

## 7.1 CocoaPods source

Find this exact semantic sequence:

```objc
FfkitPixelTexture *tex = [[FfkitPixelTexture alloc] init];
int64_t tid = [_textureRegistry registerTexture:tex];

__weak NSObject<FlutterTextureRegistry> *weakReg = _textureRegistry;
```

Insert the failure branch between registration and callback publication:

```objc
FfkitPixelTexture *tex = [[FfkitPixelTexture alloc] init];
int64_t tid = [_textureRegistry registerTexture:tex];

if (tid == 0) {
  result([FlutterError errorWithCode:@"TEXTURE_REGISTRATION_FAILED"
                             message:@"Flutter could not register the FFplay texture"
                              details:nil]);
  return;
}

__weak NSObject<FlutterTextureRegistry> *weakReg = _textureRegistry;
```

## 7.2 SwiftPM source

Apply the same semantic branch to:

```text
flutter/ios/ffmpeg_kit_extended_flutter/Classes/ffmpeg_kit_native/FfplayKitPlugin.m
```

Keep its existing include path:

```objc
#import "include/FfplayKitPlugin.h"
```

Do not replace the whole file from the CocoaPods copy, because the packaging copies intentionally differ in include paths and some formatting.

## 7.3 Error contract

Use the already-established macOS error:

```text
code:
  TEXTURE_REGISTRATION_FAILED

message:
  Flutter could not register the FFplay texture

details:
  nil
```

Do not invent a second iOS-specific error code.

---

# 8. R43-G1 — required failure-atomic state

When `tid == 0`, all of these must remain false/unpublished:

```text
tex.onFrameAvailable is not installed
_texture is not assigned
_textureId is not changed from the clean sentinel
_retainedTexPtr is not created
sFfplayOwner is not changed
_ffplay_kit_register_frame_callback_fn is not called
success result is not returned
```

The local ARC-owned `tex` should simply fall out of scope.

Do **not** call:

```objc
[_textureRegistry unregisterTexture:0];
```

Registration failed, so there is no registered Flutter texture to unregister.

---

# 9. R43-G1 — do not alter replacement semantics

Current create behavior intentionally releases any existing texture before attempting to create a new one:

```objc
[self releaseTextureState];
```

Review 43 does not require changing that behavior.

Do not introduce rollback/restoration of the previous texture. That would be a larger ownership redesign and is not necessary to fix the false-success defect.

After a failed new registration, the plugin may have no active texture; that is acceptable so long as the call reports failure and does not publish an invalid owner.

---

# 10. R43-G1 — do not refactor owner coordination

Do not rewrite:

```text
FfplayOwnerLock
sFfplayOwner
FfplayInstallOwner
FfplayUninstallIfOwned
ffplay_frame_cb
FfkitPixelTexture lifetime
```

The finding is earlier than these mechanisms.

The fix is to prevent a failed texture from ever reaching them.

---

# 11. R43-G2 — focused source-contract test

Add a focused test such as:

```text
flutter/test/apple_ffplay_texture_registration_test.dart
```

Use semantic anchors rather than exact full-file matching.

## 11.1 Source matrix

Test both iOS files:

```text
CocoaPods:
  ios/Classes/FfplayKitPlugin.m

SwiftPM:
  ios/ffmpeg_kit_extended_flutter/Classes/ffmpeg_kit_native/FfplayKitPlugin.m
```

Paths should be resolved relative to the Flutter package root using the same conventions as existing source/layout tests.

## 11.2 Required assertions per file

Locate the `handleCreateTexture` method and establish this ordering:

```text
A. registerTexture:tex
B. if (tid == 0)
C. TEXTURE_REGISTRATION_FAILED
D. return from failure branch
E. onFrameAvailable assignment
F. _texture = tex
G. _retainedTexPtr / __bridge_retained
H. FfplayInstallOwner
I. success result containing textureId
```

Required relation:

```text
A < B < E
A < B < F
A < B < G
A < B < H
A < B < I
```

and the failure branch must contain C plus an immediate return.

Do not assert whitespace, indentation, or the full method string.

## 11.3 Semantic parity assertion

For both iOS packaging files require the same:

```text
failure sentinel: tid == 0
error code: TEXTURE_REGISTRATION_FAILED
error message: Flutter could not register the FFplay texture
```

Do not require byte-identical files.

---

# 12. R43-G2 — optional native failure-path test

Use this only if the existing Apple test/build setup permits it without creating a new large testing subsystem.

A deterministic fake registry should implement:

```objc
@protocol FlutterTextureRegistry
```

with:

```text
registerTexture -> return 0
textureFrameAvailable -> count calls
unregisterTexture -> count calls
```

Invoke the real iOS create path with the fake registry.

Required assertions:

```text
registration called exactly once
FlutterResult receives FlutterError
error.code == TEXTURE_REGISTRATION_FAILED
no success map returned
textureFrameAvailable call count == 0
unregisterTexture call count == 0
plugin has no published active texture ID
```

If accessing the private create method requires a test-only Objective-C category declaration, keep it in the test target only.

Do not add a public production testing API.

Do not claim this native test ran unless the test target actually compiles and executes.

---

# 13. R43-G2 — preserve success-path behavior

The normal nonzero registration path must remain unchanged:

```text
register valid Flutter texture
set onFrameAvailable
publish _texture and _textureId
bridge-retain the callback userdata texture
claim latest process-global FFplay owner
register native frame callback
return {textureId: tid}
```

Existing frame conversion, pixel-buffer pool, callback drain, and texture release behavior must not change.

---

# 14. R43-G3 — Apple duplicate-source audit

After editing, compare the CocoaPods and SwiftPM iOS FFplay implementations semantically.

Expected allowed differences:

```text
header include path
formatting
package-directory layout
```

Required equivalent behavior:

```text
symbol resolution
log stream behavior
pixel conversion
alpha repair
texture registration failure branch
callback ownership
release ordering
success result
```

Also confirm the macOS copies still contain their existing `tid == 0` guard.

Do not normalize unrelated formatting merely to reduce the diff.

---

# 15. R43-G3 — React Native Review 42 regression audit

No production changes are expected, but the final bounded review must confirm the frozen behavior remains present.

Search/inspect:

```text
react-native/cpp/FFmpegKitDynamicApi.cpp
```

Verify:

```text
SessionOperationLease shares one token
acquireSessionWithinOperation does not reacquire admission
acquireHistorySessionWithinOperation does not reacquire admission
no post-admission wait on clearSessionsInProgress
getSessionsJson admits once
getLastSessionJson admits once
HandleGuard releases owned/retained handle authority before operation token
clearSessions waits active top-level operations and reopens only after history clear
```

If these unchanged files differ from starting authority unexpectedly, stop and reconcile the source diff before claiming closure.

---

# 16. R43-G3 — platform-native no-regression matrix

Use this as the final review checklist, not as an instruction to edit everything.

| Surface | Invariant to preserve | Review 43 expected source change |
| --- | --- | --- |
| Flutter Windows | async registered-texture retirement; latest owner; packed RGBA normalization | none |
| Flutter Linux | FlPixelBufferTexture lifetime; queued idle refs; coalescing; latest owner | none |
| Flutter Android | Surface/ANativeWindow exact release; latest process owner | none |
| Flutter iOS CocoaPods | Darwin registration failure is rejected before owner publication | **yes** |
| Flutter iOS SwiftPM | same as CocoaPods | **yes** |
| Flutter macOS CocoaPods/SwiftPM | existing `tid == 0` failure branch stays intact | none |
| RN shared C++ | composable operation token and clear barrier | none |
| RN Windows | invocation-bound action failures; sync diagnostic isolation; FFplay owner | none |
| RN Android | stale surface cannot clear newer owner | none |
| RN iOS/tvOS/macOS | unregister/drain; weak owner; locked latest-frame state | none |

Any unexpected change outside the two iOS implementation files and focused tests must be justified by a newly proven defect, not cleanup preference.

---

# 17. R43-G3 — documentation/comment guidance

## 17.1 Production comment

A short comment is optional:

```objc
// FlutterTextureRegistry reports registration failure with texture ID 0.
```

Place it immediately above the guard if added.

Do not mention Review 43 in production code.

## 17.2 Public API documentation

No public documentation change is required because the current public contract is already correct:

```text
FFplayDesktopTexture.create() returns null if texture creation fails.
FFplaySurface.create() returns null if platform surface creation fails.
```

The code must be brought into agreement with that contract.

## 17.3 Test documentation

Test comments should explain:

```text
Darwin uses texture ID 0 as registration failure
failed registration must not publish FFplay callback ownership
both Apple packaging source copies must enforce the same transaction boundary
```

Do not use goal/finding/review IDs inside test names.

---

# 18. R43-G4 — focused local validation

Review 43 itself is code review only and claims no execution.

After implementation, run affected validation locally using only the configured local ABI `0.11.2`.

Do not fetch a remote native bundle.

## 18.1 Flutter source/test gates

From the Flutter package root, with analytics disabled, run the new focused regression first.

Conceptually:

```text
flutter test --no-pub test/apple_ffplay_texture_registration_test.dart
```

Then run the smallest existing Apple/source tests that cover the touched surface, for example the relevant architecture/hook/lifecycle tests already in the repository.

Do not substitute a source grep command for a passing Dart test if the test was added.

## 18.2 Static analysis

Run affected Flutter analysis if the local package graph is valid.

Record warnings separately from errors. Do not claim a warning-free result unless it is actually warning-free.

## 18.3 iOS build

Use the existing authorized Mac environment and locally configured iOS universal XCFramework/native artifact.

Run the repository's established noninteractive Flutter iOS build gate, for example:

```text
flutter build ios --debug --no-codesign --no-pub
```

or the exact established equivalent from the tracker/current build scripts.

No simulator/device launch.

## 18.4 SwiftPM source copy

If the repository already has a functioning SwiftPM consumer/build gate, run the smallest existing noninteractive gate that compiles the SwiftPM source copy.

If no such existing gate exists:

```text
do not invent a large new SwiftPM sample application merely for Review 43
```

Instead rely on:

```text
semantic source-contract test covering the SwiftPM copy
existing package/source layout validation
CocoaPods iOS build for the runtime path
final source audit
```

State this limitation explicitly.

---

# 19. Validation scope that should NOT expand

Because Review 43 production changes should be iOS-only:

```text
do not rerun React Native Windows/Android/Apple builds merely for ceremony
do not rerun Flutter Windows/Linux/Android builds unless an unexpected shared file changes
do not rerun Web/Wasm gates
do not rebuild the native ABI
do not run hosted CI acceptance workflows
```

If Luna changes any shared Flutter native helper, React Native file, hook, or platform config, this narrow validation scope is no longer valid. Either revert the unrelated change or explicitly expand validation for the affected surface.

---

# 20. Interactive validation remains user-owned

Do not automatically launch:

```text
iOS simulator app
device app
Flutter interactive FFplay playback
React Native interactive app
```

The user has reserved interactive Flutter/React Native validation for manual execution at the end of remediation.

The automated closure evidence is source/test/build only.

---

# 21. Test/result truthfulness

For every command Luna actually executes, record:

```text
platform
working directory
exact command
exit status
test count when available
whether the command is acceptance evidence or diagnostic only
```

Do not report any of these as a pass:

```text
source inspection only
a command that timed out
a killed process
a command skipped before compilation
a platform that was unavailable
an inferred result from an older review
```

If an environment problem is corrected, record both the failed attempt and the successful retry.

---

# 22. Final bounded code review after remediation

After tests/builds are stable, inspect the final source again.

## 22.1 iOS failure transaction

For both iOS source copies confirm:

```text
registerTexture -> tid
if tid == 0 -> FlutterError + return
no callback state before guard
no plugin state before guard
no bridge retain before guard
no owner install before guard
no success result before guard
```

## 22.2 iOS normal ownership

Confirm unchanged:

```text
successful registration installs frame callback
release unregisters only when still current owner
invalidate drains in-flight texture update
bridge-retained userdata is balanced exactly once
Flutter texture is unregistered after callback drain
```

## 22.3 macOS parity

Confirm macOS still has the correct failure branch in both packaging copies.

## 22.4 React Native shared C++

Confirm no accidental change to Review 42 operation-token behavior.

## 22.5 Finding threshold

Only open another finding when it has:

```text
reachable source path
concrete ownership/concurrency/framework-contract violation
product consequence
```

Do not turn formatting, dead code, naming, or test organization into Review 43 findings.

---

# 23. Final exact-SHA freeze

Only after all are true:

```text
R43-F1 fixed in both iOS packaging source copies
focused regression passes
normal affected iOS build passes
no native ABI/submodule change exists
final bounded platform-native review finds no substantive open defect
```

then:

1. Verify `libs/libffmpegkit` is unchanged at the frozen SHA.
2. Verify no builder checkout change.
3. Remove task-owned staging/output that should not be committed.
4. Commit/push the wrapper remediation.
5. Record the exact 40-character wrapper SHA.
6. Dispatch **one** wrapper-only source snapshot at that exact SHA.
7. Do not dispatch hosted Flutter/React Native test/build workflows.
8. Do not create a native/builders snapshot.
9. Download the source artifact through the established snapshot workflow path.
10. Verify:
    - outer artifact digest;
    - `source.tar.gz.sha256`;
    - every `SHA256SUMS` entry;
    - `SUBMODULES.txt`;
    - `SYMLINKS.tsv`;
    - `snapshot-metadata.json`;
    - `snapshot_sha` equals exact frozen wrapper SHA;
    - `runtimeExecution=false`.
11. Treat later tracker/mailbox commits as metadata, not source authority.

---

# 24. Tracker/final closure report requirements

Record:

```text
Review 43 starting source authority
  e798d1b07f55e07a042cb33faf4fc55867d70493

R43-F1 disposition

exact CocoaPods iOS source change
exact SwiftPM iOS source change

proof that tid == 0 returns before:
  onFrameAvailable
  _texture publication
  bridge retain
  FFplay owner install
  success result

focused regression command/result
Apple build command/result
SwiftPM compilation evidence if an existing gate is available

confirmation that RN shared C++ is unchanged
confirmation that native ABI/submodule is unchanged

exact final wrapper SHA
snapshot workflow run ID
snapshot artifact name/ID/link
digests
manifest count
symlink count
runtimeExecution=false
frozen native submodule SHA
```

Do not write "all platforms pass" unless each platform was actually run in this remediation.

For Review 43, a truthful closeout can instead say:

```text
affected iOS wrapper gates passed; unchanged platform-native surfaces were
re-audited in source and retain prior accepted validation evidence
```

when that is the evidence actually obtained.

---

# 25. Luna implementation sequence

Use this order exactly unless a concrete source conflict forces reconciliation.

```text
1. Read Review 43 code review completely.

2. Verify starting wrapper SHA / working-tree scope.

3. Verify native submodule remains frozen at:
   b74da2c5d1e294b87d15d73a6687393729e932b3

4. Open CocoaPods iOS FfplayKitPlugin.m.

5. Add tid == 0 failure guard immediately after registerTexture:.

6. Open SwiftPM iOS FfplayKitPlugin.m.

7. Apply the same semantic guard while preserving its include path/formatting.

8. Inspect git diff.
   Expected production diff: two iOS FFplay files only.

9. Add focused semantic source-contract regression for both copies.

10. Run the new focused test locally.

11. Run the smallest relevant existing Flutter Apple/source regression set.

12. Run affected Flutter analysis if applicable.

13. On the authorized Mac, run the established noninteractive Flutter iOS build
    using the existing local ABI 0.11.2 artifact.

14. If an existing SwiftPM compile gate exists, run it.
    Otherwise document that no new SPM fixture was invented and rely on the
    source-contract parity test for that duplicate source copy.

15. Re-inspect both iOS source copies for failure-before-publication ordering.

16. Recheck macOS copies retain their existing failure branch.

17. Re-audit Review 42 RN shared C++ operation-token invariants without editing.

18. Perform the final bounded platform-native review.

19. If another substantive defect is found, stop closure and record it with
    source/product evidence. Do not hide it.

20. If clean, freeze exact wrapper SHA.

21. Dispatch/download/verify one wrapper-only source snapshot.

22. Record provenance and stop automated work.
```

---

# 26. Anti-patterns Luna must reject

## 26.1 Returning texture ID 0 as a recoverable texture

Do not do:

```text
registerTexture -> 0
continue
return textureId 0
```

Zero is the documented Darwin failure sentinel.

## 26.2 Installing FFplay owner before validating Flutter registration

Do not reorder toward:

```text
retain texture
install native callback owner
then inspect tid
```

The Flutter registration must succeed first.

## 26.3 Unregistering texture ID 0

Do not attempt cleanup with:

```objc
[_textureRegistry unregisterTexture:0];
```

The registration did not succeed.

## 26.4 Restoring the previously released texture

Do not turn this fix into a rollback transaction that resurrects the prior FFplay surface.

That is outside the finding and increases ownership complexity.

## 26.5 Consolidating CocoaPods and SwiftPM files

Do not restructure Apple packaging to remove duplicate sources in this remediation.

Patch both current authorities and test semantic parity.

## 26.6 Byte-for-byte duplicate assertion

Do not require both files to be identical. Their include paths are intentionally different.

Test behavior/ordering instead.

## 26.7 Broad Apple formatting cleanup

Do not reformat unrelated Objective-C just because both files are being touched.

## 26.8 React Native changes without evidence

Do not modify shared C++, Windows, Android, iOS/tvOS/macOS RN code merely to "finish" Review 43.

The audit did not establish another RN defect.

## 26.9 Native ABI change

Not permitted.

## 26.10 Remote CI as acceptance evidence

Not permitted. Use local affected gates. The only hosted workflow allowed at final closure is the wrapper source snapshot.

---

# 27. Definition of done

Review 43 closes only when every applicable item is true:

```text
[ ] CocoaPods iOS checks tid == 0 immediately after registerTexture:.
[ ] SwiftPM iOS checks tid == 0 immediately after registerTexture:.
[ ] Both return TEXTURE_REGISTRATION_FAILED on zero.
[ ] Neither publishes onFrameAvailable before the guard.
[ ] Neither publishes _texture/_textureId before the guard.
[ ] Neither creates __bridge_retained userdata before the guard.
[ ] Neither installs process-global FFplay ownership before the guard.
[ ] Neither returns successful textureId before the guard.
[ ] Failed local tex is ARC-released naturally without unregisterTexture:0.
[ ] Normal nonzero registration path remains unchanged.
[ ] CocoaPods/SwiftPM iOS semantic parity regression exists and passes.
[ ] Existing affected Flutter Apple/source regressions remain green.
[ ] Affected noninteractive local iOS build passes with local ABI 0.11.2.
[ ] No automated interactive simulator/device app launch is claimed.
[ ] macOS retains its already-correct registration failure behavior.
[ ] Flutter Windows/Linux/Android accepted ownership behavior is unchanged.
[ ] RN shared operation-token/clear behavior is unchanged.
[ ] RN Windows/Android/Apple ownership/error behavior is unchanged.
[ ] No native ABI/submodule/builder change occurred.
[ ] No remote native bundle was fetched for local validation.
[ ] No hosted Flutter/RN acceptance CI was used.
[ ] Final bounded code review finds no substantive open platform-native defect.
[ ] Exact final wrapper SHA is frozen and pushed.
[ ] One wrapper-only source snapshot at that exact SHA is downloaded and verified.
[ ] Snapshot metadata records runtimeExecution=false.
```

If any applicable item is false, do not declare final platform-native bridge closure.
