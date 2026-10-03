# React Native Generated API Documentation Follow-up Audit

Date: 2026-10-03
Repository: `akashskypatel/ffmpeg-kit-extended`
Branch represented by reviewed snapshot: `dev-wasm`
Review type: frozen-source documentation/type-surface review; substantive findings only

## 1. Authority and provenance

Review authority is the completed React Native API-documentation snapshot supplied by the user:

- source/snapshot SHA: `ef9359601cb96f7d9e588e0c3c4e6277abfe0020`
- workflow run: `37140928738`
- source artifact: `react-native-api-docs-source-snapshot-37140928738`
- artifact ID: `11279708885`
- GitHub artifact SHA-256: `626c3399e0cfa0d74265143e1b9c175982bd350c6f67c22d83001dc5ac0292df`
- embedded `source.tar.gz` SHA-256: `6799eb7c923685cd1bf5c37fda30296b51143049f40d17f303c18045f416755b`
- manifest: `1134/1134` verified
- symlinks: `0`
- `runtimeExecution=false`
- frozen native submodule: `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`

The source snapshot was independently downloaded and verified before review.

The implementation correctly added TypeDoc `0.28.20`, `typedoc-plugin-markdown` `4.13.1`, strict generation, committed Markdown under `react-native/doc/api`, deterministic drift checking, and documentation-contract tests. The final snapshot contains 44 generated Markdown files. Relative links within the generated tree were checked independently: 559 relative links were found and none pointed to a missing file.

## 2. Overall disposition

The major documentation-generation work is successful. The README/TSDoc factual corrections, generator setup, strict validation, drift checker, generated tree, and no-runtime-diff boundary are all materially present.

A small but substantive follow-up remains before calling the generated RN API reference fully consumer-clean.

| Area | Disposition |
| --- | --- |
| Generator/dependencies | Closed |
| Deterministic generated-doc drift gate | Closed |
| README factual corrections | Closed |
| Native/Web platform notes | Closed |
| Internal method exclusion | Mostly closed |
| Public generated signatures/type references | **Follow-up required** |
| Constructor presentation/guidance | **Follow-up required** |
| Runtime/native/Flutter/ABI | Closed; do not reopen |

## 3. Finding F1 — internal observer type still leaks into `Session` documentation

Severity: Medium

Affected source:

- `react-native/src/session.ts`
- generated `react-native/doc/api/classes/Session.md`

`Session` is declared as:

```ts
export abstract class Session implements RestoredSessionObservationTarget
```

`RestoredSessionObservationTarget` is an implementation-only observer interface and is intentionally not part of the generated public API. Its methods were correctly marked/excluded, but TypeDoc still renders the class-level implementation relationship:

```text
Implements
- RestoredSessionObservationTarget
```

and adds `Implementation of RestoredSessionObservationTarget.sessionId` / `.getState` annotations.

This contradicts the intended generated-doc boundary: the consumer reference still names the internal observer authority even though its page is absent.

### Required remediation

Remove the explicit `implements RestoredSessionObservationTarget` clause from the exported `Session` declaration if compilation confirms it is redundant. Keep structural type checking through the existing observer call sites, where `Session` instances are passed to APIs accepting `RestoredSessionObservationTarget`.

Do not change runtime methods or observer behavior.

Acceptance:

- generated `Session.md` contains no `RestoredSessionObservationTarget` text;
- observer TypeScript compilation remains green;
- restored-observer runtime tests remain unchanged/green.

## 4. Finding F2 — public queue API renders undocumented internal helper types

Severity: Medium-High

Affected source:

- `react-native/src/session-queue-manager.ts`
- generated `react-native/doc/api/classes/SessionQueueManager.md`

The generated public page currently exposes:

```text
activeSessions(): CancellableSession[]
cancelCurrent(): MaybePromise<void>
clearQueue(): MaybePromise<void>
cancelAll(): MaybePromise<void>
```

`CancellableSession` and `MaybePromise` are internal, intentionally-not-exported aliases. The generated docs therefore contain public signatures whose named types have no public page/import path.

The strict TypeDoc run passes only because those names are explicitly listed under `intentionallyNotExported`. That is a valid mechanism for truly internal references, but not a good final state when the names remain visible in consumer-facing method signatures.

### Required remediation

Make the documented/public signatures self-contained without changing runtime behavior.

Recommended shape:

1. Type `activeSessions` as the supported public `Session` abstraction (or another deliberately exported public read-only session type) rather than `CancellableSession`.
   - A type-only import is acceptable if needed.
   - Do not expose `prepareForExecution` or other queue plumbing merely to document this getter.
2. Spell the public return types of `cancelCurrent`, `clearQueue`, and `cancelAll` as `void | Promise<void>` rather than the private alias `MaybePromise<void>`.
   - Internal helpers may continue to use `MaybePromise`.
3. Remove `CancellableSession` / `MaybePromise` from `intentionallyNotExported` if no remaining generated public reflection requires the exemption. If private/internal reflections still require it, keep the narrow exemption but add a contract asserting the names never appear in generated consumer Markdown.

Acceptance:

- generated public signatures contain only exported/public or built-in types;
- no `CancellableSession` or `MaybePromise` text appears anywhere under `doc/api`;
- queue runtime code is byte-for-byte equivalent apart from erased TypeScript type annotations/comments;
- queue tests remain green.

## 5. Finding F3 — advanced native bridge page is opaque

Severity: Medium

Affected source:

- `react-native/src/NativeFFmpegKitExtended.ts`
- `react-native/src/index.ts`
- generated `react-native/doc/api/variables/NativeFFmpegKitExtended.md`

The public native entry point explicitly exports `NativeFFmpegKitExtended` for advanced integration/diagnostics, and the generated page correctly says it is native-only. However its entire rendered signature is:

```text
NativeFFmpegKitExtended: Spec
```

`Spec` is not exported from the package root and has no generated page, even though it contains the actual low-level method contract. The result is a discoverable public advanced entry whose generated reference does not document its API.

### Required remediation

Choose one coherent public-documentation policy and enforce it. Recommended policy: because the runtime value is deliberately root-exported for advanced consumers, publish a stable **type-only** public name for its contract while preserving React Native Codegen's required `Spec` declaration/pattern.

Preferred outcome:

- retain Codegen-compatible `Spec` exactly where required;
- introduce a stable consumer-facing type name such as `NativeFFmpegKitExtendedSpec` and, if needed, a stable public log-event type name;
- export the type(s) from native `src/index.ts` using type-only exports;
- make generated documentation provide a navigable page/member inventory for that advanced contract;
- keep the Web entry explicit that the runtime native module is unavailable there.

Do not alter native method names, Codegen signatures, runtime registration, or generated native ABI.

If TypeDoc cannot render a clean alias without changing Codegen structure, the fallback is to mark the low-level runtime export as intentionally unsupported for consumer reference and remove the claim that it is a documented advanced integration API. Do not leave the current halfway state where the variable is advertised but its type is opaque.

Acceptance:

- `NativeFFmpegKitExtended.md` no longer ends at an unresolved bare `Spec`;
- representative low-level methods (`initialize`, `createFFmpegSession`, `getSessionJson`, `ffplayPause`, `clearSessions`) are discoverable through the generated reference or a clearly linked stable contract page;
- Web/native distinction remains explicit;
- Codegen/native source output does not change.

## 6. Finding F4 — constructor presentation remains misleading/incomplete

Severity: Medium

Affected generated docs include:

- `FFmpegKit`
- `FFprobeKit`
- `FFplayKit`
- `FFmpegKitConfig`
- `FFmpegKitExtended`
- `SessionQueueManager`
- `FFmpegSession`
- `FFprobeSession`
- `MediaInformationSession`
- `FFplaySession`

### Static/facade classes

TypeDoc currently renders ordinary zero-argument constructors such as:

```text
new FFmpegKit()
new FFmpegKitConfig()
new FFmpegKitExtended()
new FFplayKit()
new FFprobeKit()
```

These classes are used through static APIs. Showing constructors as normal usage paths adds noise and invites unsupported/meaningless instance creation.

Use documentation-only constructor hiding (for TypeDoc 0.28.20, `@hideconstructor` is supported) on static/facade classes where instance construction has no supported purpose. Do not change constructors to `private` merely for documentation, because that would alter the TypeScript API.

For `SessionQueueManager`, decide from current supported semantics whether consumers should instantiate independent managers. Current high-level sessions use `SessionQueueManager.shared`; if independent instances are not useful/supported for high-level execution, hide the constructor in generated docs and strengthen the `shared` guidance without changing runtime construction behavior.

### Session subclasses

Generated pages show public constructors accepting raw native session IDs but provide no warning about the identity contract. Add constructor TSDoc (or class-level constructor guidance that TypeDoc renders adjacent to construction) for:

- `FFmpegSession`
- `FFprobeSession`
- `MediaInformationSession`
- `FFplaySession`

State that normal applications obtain these wrappers from factory/execution/history APIs; constructing one with an arbitrary ID does **not** create a native session and requires a valid existing native identity.

Do not hide constructors if advanced wrapper reconstruction remains intentionally supported. Document the contract instead.

Acceptance:

- static facade docs no longer advertise meaningless construction;
- session wrapper constructors explain native-ID requirements;
- no runtime constructor accessibility changes.

## 7. Follow-up test gaps

Extend `react-native/tests/documentation-contract.test.js` so it catches the defects above rather than only selected internal method names.

Required assertions:

1. Entire generated tree contains none of:
   - `RestoredSessionObservationTarget`
   - `CancellableSession`
   - `MaybePromise`
2. Advanced native bridge docs do not expose an unresolved bare `Spec` contract.
3. Generated pages for static/facade APIs do not contain `new FFmpegKit()`, `new FFprobeKit()`, `new FFplayKit()`, `new FFmpegKitConfig()`, or `new FFmpegKitExtended()` after constructor hiding.
4. Session subclass pages contain semantic constructor guidance about existing native session IDs/factory/history creation.
5. Existing internal method exclusions remain enforced.
6. `docs:api:check` remains deterministic on Windows and a Unix-like host.

Do not test exact generated whitespace or entire page snapshots.

## 8. What is already closed and should not be reopened

No follow-up is required for:

- TypeDoc dependency choice and lockfile integration;
- committed `doc/api` structure;
- line-ending-normalized drift comparison;
- README link/generation instructions;
- Web `assetBaseUrl` documentation;
- FFplay newest-unsettled ownership wording;
- awaited playback-control examples;
- internal method exclusion by `@internal`;
- generated relative links (independent audit found zero broken relative targets);
- Flutter documentation;
- React Native runtime lifecycle behavior;
- platform-native code/shared C++;
- native ABI/runtime `0.11.2`;
- `libs/libffmpegkit`;
- ManyLinux builders.

## 9. Closeout criterion

After the four findings above are remediated, regenerate the Markdown and run the documentation/type/package gates. If the generated reference contains no internal/opaque type names, constructors are presented correctly, the native advanced contract is self-contained, and the executable/runtime diff remains zero, no further API-documentation remediation cycle is warranted.
