# Review 25 Remediation Audit — Luna Functional Production-Readiness Plan

**Project:** FFmpegKitExtended  
**Date:** 2026-09-23  
**Audience:** Luna  
**Primary wrapper repository:** `akashskypatel/ffmpeg-kit-extended`, branch `dev-wasm`  
**Native/builder repository:** `akashskypatel/ffmpeg-kit-builders`, branch `dev`  
**Review authority:** exact Review 25 source snapshots downloaded from the tracker-linked source-snapshot workflow runs  
**Scope:** only real functional code defects found in the Review 25 remediation source. Do not create remediation goals for provenance bookkeeping, intentional local-validation policy, intentionally permissive checksum behavior, accepted sanitizer/toolchain dispositions, or release-process details.

## Tracker

| Goal | Severity | Objective | Functional finding | Luna mode | Exit gate |
|---|---|---|---|---|---|
| **R25-R1** | **Critical** | Make React Native Web callback registration lifetime-safe | A recycled Wasm callback-table slot can be reused while native queued work still holds the old numeric pointer, allowing delayed work to invoke a different/new callback | **Think** | Delayed accepted callbacks cannot target a recycled/new callback; callback table use remains bounded and stable |
| **R25-R2** | **High** | Bound React Native native/Windows callback bridge state lifetime | C++/Windows bridge state is retained indefinitely across repeated install/uninstall cycles, causing unbounded growth in long-lived processes | **Think** | Bridge-state ownership is O(1) per live module/bridge instance; no UAF, misdelivery, or unbounded retention under stress |
| **R25-R3** | **High** | Remove stale old-ABI Flutter Web runtime from positive/runtime authority | `flutter/assets/wasm` remains the old callback ABI and is still referenced by a positive custom-Web fixture/package-visible source | **Think** | No positive test or package-visible runtime can accidentally use the historical callback ABI; current runtime tests use the intended current ABI |
| **R25-R4** | **High validation gate** | Re-run the affected local platform/runtime matrix after R1–R3 | Callback lifetime and stale-runtime fixes touch shared Web/native bridge/runtime paths and must be revalidated on the locally supported target surfaces | **Think** for failures; **Instant** for established commands | All locally supported affected targets pass with no callback regression, stale-runtime use, or packaging regression |
| **R25-R5** | **Closeout** | Reconcile tests/docs only for behavior changed by R1–R3 | Documentation and regression tests must describe the actual final callback lifetime/runtime authority | **Instant** after implementation is proven | No stale documentation or positive fixture contradicts the implemented callback/runtime behavior |

---

# 1. Review authority

Use these exact snapshots as the source reviewed by this plan.

## Wrapper snapshot

```text
repository: akashskypatel/ffmpeg-kit-extended
workflow run: 35931116466
head SHA: f46d64f782b0a3b6663ac9512c5b90426ab34863
source artifact: review24-wrapper-source-35931116466
artifact ID: 10781008469
```

## Native/builder snapshot

```text
repository: akashskypatel/ffmpeg-kit-builders
workflow run: 35932349418
snapshot/native product source:
625c3452ee3c93fb5d701bb6546726940b88d014
```

The review compared the final snapshots against their Review 25 baselines and concentrated on the remediation-owned code paths.

---

# 2. Explicitly excluded from this remediation plan

Do **not** create findings/goals for the following. They are intentionally excluded by user direction.

## Local-only provenance depth

Do not treat the absence of manifest/hash/builder-SHA verification in local-only mode as a production defect for this review.

The current local-only behavior is accepted for this scope.

## Historical remote `0.11.2` default resolver path

Do not treat the continued use of the existing remote `0.11.2` release URLs as a Review 25 remediation finding/goal.

Native ABI/runtime version remains pinned to:

```text
0.11.2
```

Do not create a version-bump or resolver-authority goal.

## Developer-specific local paths used for Review 25 validation

Do not treat the committed `\\wsl.localhost\ManyLinux\...` paths as a production-readiness finding in this plan.

They are outside this functional-code remediation scope.

## Workflow artifact-ID bookkeeping

Do not create a goal for source/log artifact ID ordering or tracker provenance bookkeeping.

## Official checksum fail-open behavior

This is intentional.

GitHub's public release API does not consistently provide SHA hashes for valid releases, and making missing SHA metadata fatal can reject legitimate builds.

Therefore:

- do not create a checksum-hardening goal;
- do not make missing GitHub release SHA metadata a build failure;
- preserve the current compatibility behavior unless separately directed.

## UBSAN matched-runtime setup

FFK25-N11 is closed and user-accepted.

Do not create a goal to automate/rework the temporary matched GCC UBSAN runtime setup as part of this review.

## Accepted FFmpeg findings

Do not reopen:

- the accepted FFmpeg MPEG-4 `padding_bug_score` TSan race;
- the accepted TLS cancellation-only diagnostic;
- the `ffigen_js: ^0.0.16-pre` prerelease dependency warning.

---

# 3. Functional finding R1 — React Native Web callback-table slot reuse

## Severity

**Critical**

## Finding

The final React Native Web implementation allocates a callback table entry for the structured native log callback.

The effective lifecycle is:

```text
install:
  pointer = addFunction(callback)
  native enableLogCallback(pointer, ...)

uninstall:
  native enableLogCallback(0, 0)
  removeFunction(pointer)
```

The callback runtime's `removeFunction(pointer)` clears the table entry and returns the numeric slot to a free list.

However, native callback unregistration only prevents **future native snapshots** of the callback pointer. It does not revoke work that was already accepted and queued before unregistration.

The native callback dispatch path snapshots the callback pointer/user-data and submits queued work that can invoke that pointer later.

Therefore this sequence is possible:

```text
register callback A at table slot P
native accepts work carrying P
unregister callback
removeFunction(P)
table slot P enters free list
register callback B
allocator reuses P
delayed old native work invokes P
callback B runs
```

The exact Review 25 callback registry reproduces this slot-reuse behavior.

This is a real callback misdelivery/lifetime defect.

Flutter Web already uses the safer model: retain callback slots for the lifetime of the loaded Wasm module rather than immediately recycling them on callback-demand teardown.

---

# 4. R25-R1 — Make React Native Web callback lifetime-safe

## Objective

Make React Native Web callback function-pointer lifetime at least as long as any native work that may already have captured the pointer.

Do not change the native ABI unless wrapper-level retention proves insufficient.

## Preferred implementation

Mirror the Flutter Web lifetime strategy.

### Allocate once

On first successful structured log bridge installation:

```text
if callback pointer not allocated:
    pointer = addFunction(stableBridgeCallback, structured signature)

native enableLogCallback(pointer, 0)
installed = true
```

### Uninstall without recycling

On bridge uninstall:

```text
native enableLogCallback(0, 0)
installed = false
DO NOT removeFunction(pointer)
DO NOT return the slot to the free list
```

### Reinstall

Reuse the same stable callback pointer:

```text
native enableLogCallback(pointer, 0)
installed = true
```

The retained callback wrapper should route through current bridge state rather than relying on table-slot identity to encode callback ownership.

## Why this is safe

The callback slot becomes a module-lifetime resource rather than a demand-lifetime resource.

That makes the number of retained slots bounded:

```text
O(number of bridge callback types)
```

not:

```text
O(number of install/uninstall cycles)
```

It also prevents an old accepted native task from being redirected into a different callback because the numeric slot was recycled.

## Registration failure

If first registration fails, do not immediately assume the slot is safe to recycle.

Only recycle if Luna can prove native never accepted/snapshotted the pointer.

Otherwise retain it.

Preserve the primary native-registration error if cleanup also fails.

## Required tests

### Exact delayed-pointer regression

Add a focused test:

1. allocate/install callback A;
2. capture its numeric Wasm table pointer;
3. simulate native acceptance of a delayed invocation;
4. uninstall;
5. reinstall using current bridge state;
6. trigger the delayed invocation using the old pointer;
7. assert it cannot dispatch into an unrelated newly allocated callback.

The test should fail against the current slot-recycling implementation.

### Slot stability stress

Run at least:

```text
10,000 install/uninstall cycles
```

Assert:

- pointer allocated at most once for the structured log bridge;
- table size does not grow per cycle;
- pointer is not recycled to unrelated callbacks;
- no trap;
- no duplicate log delivery;
- no missing log delivery.

### Lifecycle/error cases

Cover:

- callback accepted immediately before uninstall;
- callback accepted immediately before re-install;
- handler throws;
- native registration fails;
- repeated initialize/dispose;
- two active sessions interleaving log sequences.

## Native ABI decision

Do not change native source for R1 unless Luna Think demonstrates wrapper retention cannot make this safe.

If native callback quiescence is truly required, stop and create a separate native-first goal before touching wrapper bindings.

## Documentation

Add one architecture statement:

> Native callback unregistration prevents future callback snapshots but does not revoke already accepted callback work. Wasm callback function-pointer storage therefore outlives demand-driven bridge registration.

## Exit gate

R1 closes only when the old numeric callback pointer can never become an alias for a different/new callback while delayed native work may still invoke it.

---

# 5. Functional finding R2 — unbounded React Native native/Windows bridge-state retention

## Severity

**High**

## Finding

The native React Native bridge currently preserves callback user-data lifetime by retaining old bridge-state objects indefinitely.

The reviewed C++ implementation effectively accumulates:

```text
vector<shared_ptr<LogBridgeState>> logBridgeStates
```

where each install creates another state and unregistration only clears its owner.

The Windows implementation follows the same strategy using retained/retired bridge state.

This avoids use-after-free, but repeated demand-driven install/uninstall cycles are normal behavior.

A long-lived app can therefore retain one historical state per cycle, including references owned by that state such as invocation infrastructure.

This is a real unbounded lifetime/resource defect.

---

# 6. R25-R2 — Bound native/Windows callback bridge state

## Objective

Preserve callback user-data lifetime safety without retaining one new state forever for every bridge installation.

## Preferred native C++ design

Use one stable state per module instance.

Conceptually:

```cpp
class FFmpegKitExtendedImpl {
    std::shared_ptr<LogBridgeState> logBridgeState_;
};
```

The state storage itself lives for the module lifetime.

### Install

```text
lock state
update current owner/sink/invoker
native enable callback(state.get())
mark active
```

### Uninstall

```text
native disable callback
lock state
clear active owner/sink
keep stable state storage alive
```

Queued native work that already holds `state.get()` still sees valid storage.

It must not see a stale freed state.

## Avoid strong-retention leaks

If `LogBridgeState` retains a strong JS `CallInvoker` or owner:

- clear those references when the bridge is inactive if queued work can safely handle absence;
- otherwise keep only the minimum module-lifetime reference necessary.

Do not retain every prior `CallInvoker` forever.

## Windows

Apply the same semantic ownership model.

Replace:

```text
retired state per uninstall
```

with:

```text
stable module-owned state
```

unless Windows lifetime semantics require a distinct bounded retirement mechanism.

## Module destruction

Luna Think must explicitly analyze module destruction separately from ordinary uninstall.

Questions to answer:

```text
Can native queued work still run after module destruction begins?
Who owns the final LogBridgeState storage?
Can queued work detect inactive/destroyed owner safely?
```

If module destruction can race accepted native work, retain exactly one retired state per destroyed module instance or use another bounded lifetime mechanism.

Do not retain one state per install cycle.

## Tests

### Allocation-count stress

Instrument state creation for tests.

Run:

```text
10,000 install/uninstall cycles
```

Assert state creation remains bounded.

For one module instance, expected state creation should normally be:

```text
1
```

or another fixed small constant justified by implementation.

### Delayed callback after uninstall

- native callback obtains user-data pointer;
- uninstall clears logical owner;
- delayed callback runs;
- state memory remains valid;
- no event goes to a removed consumer;
- owned payload is still released exactly once.

### Reinstall

- uninstall old logical owner;
- reinstall new logical owner using same stable state;
- delayed prior event must not be misattributed to a newly unrelated session/consumer.

Use existing session ID/sequence routing as the authority.

### Module destroy/recreate

- create module;
- install;
- queue callback;
- destroy module;
- process delayed callback;
- create new module;
- prove old queued work cannot target the new module.

## Sanitizers

Run focused bridge lifetime tests under the locally supported sanitizer environment where applicable.

Do not reopen the accepted FFmpeg TSan race.

## Documentation

Document the difference between:

```text
callback registration lifetime
logical consumer lifetime
callback user-data storage lifetime
```

These are not the same lifetime.

## Exit gate

R2 closes only when bridge state is memory-safe and bounded under repeated callback-demand cycles.

---

# 7. Functional finding R3 — stale old-ABI Flutter Web runtime remains a positive authority

## Severity

**High**

## Finding

The exact Review 25 wrapper snapshot still tracks:

```text
flutter/assets/wasm/ffmpegkit.mjs
flutter/assets/wasm/ffmpegkit.wasm
```

These bytes were already identified during Review 25 as using the historical callback ABI.

A positive custom-Web fixture still points to:

```text
../../../assets/wasm
```

This means repository tests/package source can continue treating an obsolete ABI runtime as a valid positive runtime fixture.

That creates a real functional testing risk:

- a test can pass against a runtime that does not implement the actual current callback ABI;
- package/runtime behavior can diverge from the runtime actually used by the current wrapper bridge.

This is not a documentation-only issue.

---

# 8. R25-R3 — Remove stale old-ABI runtime from positive test/runtime paths

## Objective

Ensure every positive runtime test that exercises the actual bridge uses the current structured callback ABI.

## Preferred cleanup

### Remove stale production runtime authority

Do not use:

```text
flutter/assets/wasm
```

as a positive runtime source if those files remain the old ABI.

Remove the stale runtime from the package source entirely. Let the build hook stage this during build using top level pubspec ffmpeg_kit_extended_config for testing only.

Do not silently replace it with another large binary just to satisfy staging tests.

## Separate staging tests from runtime tests

For tests whose only purpose is:

```text
hook selects source
hook stages coherent JS/Wasm pair
```

use tiny synthetic fixtures.

Those tests do not need a real FFmpeg runtime.

For positive browser/runtime tests:

```text
use the current local packaged 0.11.2 Wasm runtime
```

that implements the structured callback ABI.

## Fixture changes

Update any fixture such as:

```text
flutter/test/fixtures/custom_web_workspace/pubspec.yaml
```

that points at `../../../assets/wasm`.

If the fixture is only validating path/config/staging behavior, point it to a synthetic pair.

If it is validating runtime behavior, inject the current local Wasm artifact during the test setup.

Test runtime artifacts should not be included in the final flutter plugin package or git.

## Required tests

### Source scan

No positive runtime fixture may reference the historical old-ABI runtime path.

### Hook/staging unit tests

Keep synthetic-pair tests for:

- directory source;
- archive source;
- workspace staging;
- pair validation;
- hash/cache update behavior.

### Real browser test

Run current local Wasm:

```text
flutter build web --wasm --release
serve with COOP/COEP
run browser smoke
```

Require:

```text
STARTING
INITIALIZED
FFMPEG_OK
LOG_OK
FFPROBE_OK
MEDIA_INFO_OK
PASS
```

Retain FFplay browser coverage where supported.

The structured log callback must exercise the current five-argument ABI.

## Package hygiene

Ensure the publishable Flutter package does not present a historical executable runtime as the current default runtime.

If a historical negative fixture is retained:

- exclude it from publication;
- name it clearly as historical/old ABI;
- use it only in explicit negative tests.

## Documentation

Update only the runtime-authority wording affected by this change.

Do not create a broad documentation-remediation project.

## Exit gate

R3 closes only when a green positive Web runtime test necessarily exercises the current callback ABI.

---

# 9. R25-R4 — Focused local production regression after R1–R3

## Objective

Validate the code paths actually affected by the three functional remediations.

This is a validation goal, not a new finding.

Remote CI remains outside this plan.

## React Native Web

Run:

```text
npm run check
npm run test:web
npm run test:pack-web
```

plus the new R1 stress/lifetime tests.

Required assertions:

- stable retained callback pointer;
- no slot-reuse misdelivery;
- repeated initialize/uninitialize works;
- FFmpeg;
- FFprobe;
- media information;
- FFplay controls;
- structured log delivery remains ordered;
- no duplicate/missing logs.

## React Native native / Windows

Run locally available tests/builds for the bridge-state change.

At minimum:

- native C++ unit/source tests;
- Windows codegen/build if available;
- example executable build;
- new R2 lifetime stress test.

If Android/Apple code uses the same `FFmpegKitExtendedImpl` implementation, locally validate those targets where the toolchain is available.

Do not label unavailable targets as fixed by inference; record them as not executed.

## Flutter Web

Run:

```text
dart --disable-analytics analyze
flutter analyze
flutter test --no-pub --exclude-tags native
flutter build web --wasm --release
```

Then the real browser smoke using the current local Wasm artifact.

Verify synthetic staging fixtures remain separate from real runtime tests.

## Regression invariants

Preserve:

- one structured callback ABI;
- exact session ID;
- native sequence ordering;
- exact log level;
- owned message free exactly once;
- no steady-state full history polling;
- bounded terminal reconciliation;
- demand-driven activation;
- completion independence;
- `disableRedirection()` authority;
- no DataAssets reintroduction.

## Exit gate

All locally executable code paths touched by R1–R3 pass without introducing new callback or Web-runtime defects.

---

# 10. R25-R5 — Minimal tests/docs closeout

## Objective

Update only tests/docs directly affected by R1–R3.

Do not create goals for previously excluded policy or bookkeeping topics.

## Required documentation changes

### React Native callback lifetime

Document:

- callback unregistration is not queue draining;
- Wasm callback table slot is retained for module lifetime;
- logical demand can stop while pointer storage remains valid;
- native bridge user-data storage is module-lifetime/bounded.

### Flutter Web runtime fixtures

Document:

- synthetic staging fixtures are not executable runtime authority;
- real Web smoke uses the current structured-ABI runtime.

## Required test documentation

Update `react-native/TEST.md` / relevant Flutter test docs with:

- callback lifetime stress command;
- real Web runtime smoke command;
- distinction between synthetic staging tests and real runtime tests.

## Tracker closeout

Add only the actual functional findings/goals:

```text
R25-R1 callback slot lifetime
R25-R2 bridge-state lifetime
R25-R3 stale Web runtime authority
R25-R4 focused regression
R25-R5 closeout
```

Do not re-add excluded provenance/checksum/UBSAN/resolver-policy items as blockers.

## Exit gate

Current docs/tests describe the final code behavior with no stale positive runtime fixture or misleading callback-lifetime description.

---

# 11. Conditional native ABI work

Do **not** create a native ABI goal by default.

Open a native-first goal only if Luna proves that wrapper/module-lifetime state retention cannot safely cover already accepted native callback work.

If that proof exists:

```text
native design
-> native implementation
-> native gtests
-> Wasm tests
-> sanitizer tests
-> freeze native product source
-> rebuild local 0.11.2 artifacts
-> regenerate bindings
-> resume wrapper work
```

Native ABI/runtime version remains:

```text
0.11.2
```

Do not add `_v2` back.

---

# 12. Evidence discipline

For each goal, record:

```text
starting SHA
finding reproduced?
files changed
why each file changed
focused tests
full tests
exact commands
exact pass/fail counts
final SHA
residual functional risk
```

Do not fabricate results.

Do not hide mistakes.

Do not weaken tests to match implementation.

Name production variables/methods/files for their semantic role, not for Review 25 goal identifiers.

---

# 13. Final production-readiness definition for this remediation

This functional remediation is complete when:

1. React Native Web cannot recycle a callback table slot into a different callback while native work may still call the old pointer.
2. React Native native/Windows callback bridge state is bounded under repeated install/uninstall cycles.
3. Positive Flutter Web runtime tests cannot accidentally use the historical old callback ABI.
4. Current structured callback semantics still pass on the locally exercised affected platforms.
5. No DataAsset dependency is reintroduced.
6. No accepted FFmpeg/TLS/UBSAN disposition is reopened without new functional evidence.
7. Tests and documentation directly affected by R1–R3 match the final implementation.

Do not add blocker status for intentionally accepted policy choices or bookkeeping details.
