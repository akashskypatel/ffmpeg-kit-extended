# Luna Follow-up Plan — React Native API Documentation Consumer-Surface Closure

Date: 2026-10-03
Audience: Luna implementation/review model
Repository: `akashskypatel/ffmpeg-kit-extended`
Branch: `dev-wasm`
Starting frozen source: `ef9359601cb96f7d9e588e0c3c4e6277abfe0020`

## Mission

Finish the generated React Native API-reference work by removing the remaining **documentation/type-surface leaks** without changing runtime behavior, native code, Flutter, ABI, builders, or execution semantics.

The TypeDoc toolchain, generated Markdown, drift checker, README corrections, strict validation, and package tooling are already accepted. Do not redesign or replace them.

## Hard boundaries

- Do not change React Native runtime behavior.
- Do not change native C/C++, Java/Kotlin, Objective-C/Objective-C++, Swift, Windows C++, or Codegen method signatures.
- Keep native ABI/runtime `0.11.2` frozen.
- Keep `libs/libffmpegkit` frozen at `b74da2c5d1e294b87d15d73a6687393729e932b3`.
- Do not touch the ManyLinux builders checkout.
- Do not change Flutter code or documentation.
- Do not add a new documentation generator or replace TypeDoc.
- Do not broadly disable TypeDoc validation.
- Do not add generated docs to npm `files`; the accepted plan intentionally uses GitHub-linked committed Markdown.
- Do not run hosted Flutter/RN acceptance workflows.
- No simulator/device/application launch is required.
- Production/test/comment names must remain semantic; review/finding IDs belong only in tracker metadata.

## Goal tracker

| Goal | Objective | Expected production scope | Status |
| --- | --- | --- | --- |
| G1 | Remove internal observer/queue helper types from generated public signatures | `src/session.ts`, `src/session-queue-manager.ts`, `typedoc.json`, docs contract | Pending |
| G2 | Make the advanced native bridge reference self-contained | `src/NativeFFmpegKitExtended.ts`, native `src/index.ts`, TSDoc/generated docs | Pending |
| G3 | Correct constructor presentation and wrapper-construction guidance | TSDoc/modifier tags in public TS classes | Pending |
| G4 | Regenerate, strengthen documentation contracts, and close with zero runtime diff | `doc/api/**`, tests, tracker | Pending |

---

# G1 — remove internal observer/queue helper types from public generated output

## G1.1 Remove `RestoredSessionObservationTarget` from `Session` docs

Current problem:

```ts
export abstract class Session implements RestoredSessionObservationTarget
```

TypeDoc excludes the internal interface page/methods but still renders:

```text
Implements RestoredSessionObservationTarget
Implementation of RestoredSessionObservationTarget.sessionId
Implementation of RestoredSessionObservationTarget.getState
```

Required implementation:

1. Remove only the explicit `implements RestoredSessionObservationTarget` clause from `Session`.
2. Keep the imported type where still needed by surrounding structural typing; remove the import only if TypeScript proves it unused.
3. Do not change any `Session` property or method.
4. Rely on the existing calls into restored-session observation APIs to continue structurally checking that `Session` satisfies the required shape.

Required test:

- `npm run typecheck` must prove observer call sites remain structurally valid.
- Generated docs must contain zero occurrences of `RestoredSessionObservationTarget`.

Do not replace the interface with a new public observer interface. It is implementation plumbing.

## G1.2 Make `SessionQueueManager` public signatures self-contained

Current generated leaks:

```text
activeSessions: CancellableSession[]
cancelCurrent(): MaybePromise<void>
clearQueue(): MaybePromise<void>
cancelAll(): MaybePromise<void>
```

`CancellableSession` and `MaybePromise` are private helper aliases and have no consumer import path.

### `activeSessions`

Prefer a public `Session`-typed view for supported application use.

Suggested implementation:

```ts
import type {Session} from './session';

get activeSessions(): Session[] {
  return [...this.active] as Session[];
}
```

A type-only reverse import is acceptable because it is erased from runtime JavaScript. Validate declaration generation and do not introduce a runtime circular import.

If TypeScript/package architecture demonstrates that `Session[]` is not a sound supported contract, introduce a **deliberately public, consumer-safe** read-only session interface containing only supported members. Do not export the existing `CancellableSession` because it contains queue-internal preparation semantics.

### Public cancellation/clear return types

Keep internal `MaybePromise<T>` if useful, but spell consumer-facing public signatures explicitly:

```ts
cancelCurrent(): void | Promise<void>
clearQueue(): void | Promise<void>
cancelAll(): void | Promise<void>
```

Do not change synchronous/asynchronous runtime branches merely to force a single Promise shape.

## G1.3 Narrow TypeDoc exemptions

After the signature fixes:

- remove `CancellableSession` and `MaybePromise` from `intentionallyNotExported` if TypeDoc no longer requires them;
- if private/internal excluded reflections still trigger legitimate strict-validation references, retain only the minimum necessary exemptions;
- regardless of exemptions, generated consumer Markdown must contain neither name.

Do not solve this by turning off `validation.notExported` or `treatValidationWarningsAsErrors`.

## G1.4 G1 tests

Extend `tests/documentation-contract.test.js` to concatenate the generated tree and assert no occurrence of:

```text
RestoredSessionObservationTarget
CancellableSession
MaybePromise
```

Retain all existing internal method-name exclusions.

Run:

```text
npm run typecheck
npm run test:compile
npm run docs:api
npm run docs:api:check
node --test tests/documentation-contract.test.js tests/documentation-drift.test.js
```

---

# G2 — make the advanced native bridge reference self-contained

## G2.1 Problem

The package intentionally exports `NativeFFmpegKitExtended` from native `src/index.ts` for advanced use, but generated documentation shows only:

```text
NativeFFmpegKitExtended: Spec
```

`Spec` is not a root-exported public type and has no generated page. The advanced page therefore does not expose the methods it claims advanced consumers can use.

## G2.2 Preserve React Native Codegen structure

`src/NativeFFmpegKitExtended.ts` is a Codegen contract. Do not casually rename/remove the Codegen `Spec` interface or alter its method signatures.

The remediation must be type-only/documentation-only from the runtime perspective.

## G2.3 Recommended public type policy

Expose a stable consumer-facing type name for the already-public native module contract, while keeping Codegen's internal declaration pattern intact.

Target outcome:

```text
NativeFFmpegKitExtended
  -> documented stable native-only contract type
  -> documented native method inventory
```

Candidate approach:

1. Add a stable exported type name, for example `NativeFFmpegKitExtendedSpec`, backed by the existing Codegen `Spec`.
2. Export that type through **native `src/index.ts` only** using `export type` so it adds no runtime JavaScript.
3. If the stable contract exposes the structured native log event type, provide a stable public type name for that event as well.
4. Keep `src/index.web.ts` free of the runtime native module and clearly document the native-only distinction.
5. Regenerate docs and inspect actual TypeDoc output. The native variable page must link to or otherwise expose the stable documented contract, not an unresolved bare `Spec`.

Because TypeDoc rendering of aliases depends on reflection structure, do not assume the first alias shape is sufficient. Inspect the generated Markdown and adjust **type-only** aliases/comments rather than altering Codegen runtime behavior.

## G2.4 Acceptable fallback

If a clean navigable public type cannot be produced without risking Codegen semantics, change the documentation policy coherently:

- mark the raw native module as an unsupported escape hatch rather than a documented advanced integration API;
- exclude it from consumer API generation;
- revise `src/index.ts` comments/README accordingly.

Do not leave the current mixed state (publicly advertised advanced API + opaque undocumented type).

## G2.5 Required generated-doc assertions

Add semantic assertions that:

- `NativeFFmpegKitExtended.md` does not contain only an unresolved `Spec` signature;
- the advanced contract reference makes representative methods discoverable:
  - `initialize`
  - `createFFmpegSession`
  - `getSessionJson`
  - `ffplayPause`
  - `clearSessions`
- the docs still state that the runtime native module is absent from Web.

Run `npm run prepare` and `npm run test:pack-types` after any root type-export change.

---

# G3 — correct constructor presentation and wrapper-construction guidance

## G3.1 Hide meaningless static-facade constructors in docs only

The generated reference currently advertises zero-argument construction for static utility/facade classes such as:

```text
new FFmpegKit()
new FFprobeKit()
new FFplayKit()
new FFmpegKitConfig()
new FFmpegKitExtended()
```

Do not make constructors private solely for docs; that would change the TypeScript API.

Use TypeDoc's documentation-only constructor hiding (`@hideconstructor` in the installed TypeDoc 0.28.20) on classes where instance construction is not a supported usage path.

Apply at least to:

- `FFmpegKit`
- `FFprobeKit`
- `FFplayKit`
- `FFmpegKitConfig`
- `FFmpegKitExtended`

Review `SessionQueueManager` separately. High-level sessions always use `SessionQueueManager.shared`. If an independently constructed manager has no supported high-level purpose, hide its constructor in generated docs and make `shared` the documented entry point. Do not change runtime constructor accessibility.

## G3.2 Document Session subclass constructors

Do not simply hide all Session subclass constructors without deciding their supported advanced role.

Add semantic constructor TSDoc for:

- `FFmpegSession`
- `FFprobeSession`
- `MediaInformationSession`
- `FFplaySession`

Required meaning:

- normal applications should obtain sessions from `FFmpegKit` / `FFprobeKit` / `FFplayKit` / `FFmpegKitExtended` factories or history APIs;
- the constructor wraps an **existing valid native session ID**;
- constructing with an arbitrary ID does not create a native session and can make getters/execution/control fail because no native identity exists;
- preserve timeout-unit documentation for session types with `timeoutMs`.

Do not claim arbitrary manual wrapper construction is unsupported if the source intentionally permits advanced reconstruction; document the precondition instead.

## G3.3 Constructor contract tests

Generated-doc contract should assert:

- static/facade pages do not contain their `new ClassName()` constructor blocks;
- session subclass pages contain language equivalent to `existing native session ID` and point normal users to factory/history APIs.

Avoid exact whole-paragraph snapshots.

---

# G4 — regenerate, validate, and close

## G4.1 Regenerate

Run:

```text
npm run docs:api
npm run docs:api:check
```

Review every changed generated page. Do not hand-edit `doc/api/**`.

The page count may legitimately change if a stable advanced native contract type becomes newly documented. Update tests to assert semantic inventory, not a hard-coded total count unless the count itself is intentionally contractual.

## G4.2 Focused gates

Run locally:

```text
npm run typecheck
npm run test:compile
node --test tests/documentation-contract.test.js tests/documentation-drift.test.js
npm run lint
npm run prepare
npm run test:pack-types
npm run docs:api:check
```

Then run the full Node suite once after final type/export changes:

```text
npm test
```

A native/Web type-only entrypoint change also requires the existing packed Web/type consumer gates if they are part of current package practice.

No native platform build is required unless a non-type executable source change appears unexpectedly.

## G4.3 Cross-host drift gate

Repeat:

```text
npm run docs:api:check
```

on Windows and one Unix-like host (WSL or macOS). Preserve the current line-ending-only normalization policy.

## G4.4 Generated-reference audit

Final generated tree must satisfy all of the following:

- zero broken relative Markdown links;
- zero `RestoredSessionObservationTarget` references;
- zero `CancellableSession` references;
- zero `MaybePromise` references;
- no unresolved bare native `Spec` consumer contract;
- no meaningless static-facade constructors;
- session constructors explain existing-native-ID semantics;
- internal observer/queue methods remain absent;
- Web/native distinctions remain correct;
- current FFplay ownership and awaited-control guidance remain unchanged.

## G4.5 No-runtime-diff audit

Compare against starting SHA `ef9359601cb96f7d9e588e0c3c4e6277abfe0020`.

Allowed production changes should be limited to:

- comments/TSDoc/modifier tags;
- erased TypeScript type annotations/type-only exports needed to make the docs self-contained.

There must be no change to emitted runtime behavior. If a source change would alter emitted JavaScript, stop and justify it as a separately proven API defect before proceeding.

Keep frozen:

- Flutter all paths;
- RN native/platform code;
- shared C++;
- native ABI and builders;
- `libs/libffmpegkit` SHA.

## G4.6 Snapshot policy

Only create a new wrapper source snapshot after the follow-up is implemented, local documentation/type/package validation passes, and the final no-runtime-diff audit is clean.

Record:

- exact implementation SHA;
- workflow run/artifact IDs;
- outer artifact digest;
- embedded source archive digest;
- manifest count;
- symlink count;
- `runtimeExecution=false`;
- frozen submodule SHA.

Do not create a native/builders snapshot.

---

# Definition of done

The RN generated API documentation is fully closed when:

- [ ] internal observer type names do not leak into `Session` docs;
- [ ] queue public signatures contain only public/exported or built-in types;
- [ ] generated docs contain no `CancellableSession` or `MaybePromise`;
- [ ] the advanced native bridge has a self-contained stable documented contract, or is coherently excluded as unsupported;
- [ ] static facade constructors are hidden from generated docs without changing runtime accessibility;
- [ ] Session subclass constructors document valid-existing-ID/factory-history semantics;
- [ ] strict TypeDoc generation has zero warnings;
- [ ] documentation-contract tests cover these boundaries;
- [ ] `docs:api:check` passes on Windows and a Unix-like host;
- [ ] packed declarations/type consumer pass;
- [ ] full local Node tests pass;
- [ ] generated relative-link audit has zero broken links;
- [ ] executable/runtime behavior diff is zero;
- [ ] Flutter/native/ABI/builder boundaries remain unchanged;
- [ ] one final exact-SHA wrapper source snapshot is verified.

If all items pass, no further RN API-documentation remediation goals are warranted.
