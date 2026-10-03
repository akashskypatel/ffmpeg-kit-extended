# Luna plan — React Native generated API documentation closure

Date: 2026-10-03
Audience: Luna implementation/review model
Repository: `akashskypatel/ffmpeg-kit-extended`
Branch: `dev-wasm`
Starting frozen source authority: `cacacf59ae43395ff0b6a7a7fe45fcc4c7809430`

## Mission

Create a complete, generated, maintainable React Native API reference from the package's TypeScript source comments, while correcting current user-facing documentation mismatches and preventing implementation-only lifecycle seams from being presented as supported application API.

This is a **documentation/TSDoc/tooling task**. Do not change React Native runtime behavior, native bridges, Flutter runtime/docs, native ABI, builders, or exported native symbols.

The preceding Flutter documentation remediation is closed. Do not reopen Flutter unless implementation of this plan produces direct evidence of a Flutter documentation defect.

---

## Hard boundaries

- Keep native ABI/runtime `0.11.2` frozen.
- Keep `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`.
- Do not edit native ABI sources or exported native symbols.
- Do not edit `react-native/cpp/**`, `react-native/android/**`, `react-native/ios/**`, `react-native/macos/**`, `react-native/appletvos/**`, or `react-native/windows/**`.
- Do not edit Flutter production code or Flutter documentation as part of this task.
- Do not edit the ManyLinux builders checkout.
- Do not download, rebuild, stage, or publish a native ABI artifact.
- Do not run hosted Flutter/React Native acceptance workflows for documentation generation.
- Do not launch applications, simulators, devices, or interactive Web UI.
- Do not change API runtime behavior merely to make a documentation generator happy.
- Adding documentation-generation **dev dependencies is explicitly authorized**.
- Generated Markdown may be committed.
- Production/test/comment names must be semantic; do not put review/goal identifiers into source comments, symbols, generated docs, or user-facing README text.
- Record generator warnings, failures, retries, exclusions, and suppressions truthfully. Do not disable broad validation just to obtain green output.

---

# Goal tracker

| Goal | Objective | Expected scope | Status |
| --- | --- | --- | --- |
| G1 | Correct factual RN README/TSDoc mismatches before generation | `README.md`, selected `src/*.ts(x)` comments only | Pending |
| G2 | Define the generated public-documentation boundary and complete missing TSDoc | selected TypeScript comments/tags only | Pending |
| G3 | Add TypeDoc + Markdown generation and committed API reference | `package.json`, lockfile, `typedoc.json`, `doc/api/**` | Pending |
| G4 | Add deterministic generated-doc drift validation and package scripts | `scripts/check-api-docs.js`, package scripts/tests | Pending |
| G5 | Validate generated API completeness, native/Web platform notes, packaging compatibility, and no-runtime-diff closure | docs/tests/tracker only unless evidence requires comment fixes | Pending |

Do not mark a goal complete because files were generated once. Each goal requires the specified source and validation evidence.

---

# Goal 1 — correct factual README/TSDoc mismatches before generation

## G1.1 README: replace nonexistent FFplay “streams” language

Current Features text says position and video dimensions are exposed as streams.

The public API actually exposes synchronous state queries on `FFplaySession`, including:

```text
getPosition()
getVideoWidth()
getVideoHeight()
```

Change the feature description to semantic wording such as:

```text
Playback monitoring: live position and video-dimension queries for FFplay sessions.
```

Do not imply an Observable/EventEmitter/stream API that does not exist.

## G1.2 README: await Promise-returning playback controls

Current example:

```ts
session.pause();
session.seek(10);
session.resume();
session.setVolume(0.5);
```

These return `Promise<void>`.

Use an async example with explicit awaits:

```ts
await session.pause();
await session.seek(10);
await session.resume();
await session.setVolume(0.5);
```

If showing concurrent control intentionally, use `Promise.all` and explain why. Default documentation should preserve sequential control ordering and surface failures.

## G1.3 Correct `FFplayKit.executeAsync()` ownership TSDoc

Current wording says the active session remains current until that call's Promise settles.

Implementation authority is:

```text
unsettledSessions Map
current = most recently submitted high-level FFplay session whose execution Promise remains unsettled
```

Required comment semantics:

- the Promise normally remains pending for playback lifetime;
- `getCurrentSession()` / `currentSession` select the **newest unsettled high-level FFplay session**;
- a later submission becomes current even while an older session remains unsettled;
- when the newest session settles, control can fall back to the next newest unsettled session;
- use an explicitly created `FFplaySession` reference when controlling a particular playback identity.

Do not call this a singleton execution model.

## G1.4 Review examples for Promise error semantics

Search README/TSDoc examples for un-awaited calls to public methods returning `Promise`.

For each example:

- await sequential actions;
- or assign/return the Promise intentionally;
- or explicitly state that the call is fire-and-forget only if the API is designed that way.

Do not mechanically add `await` to synchronous getters.

## G1.5 G1 validation

Use focused source checks or a small documentation-contract Node test to assert:

- README no longer calls FFplay position/dimension APIs “streams”;
- control example includes awaits;
- `FFplayKit.executeAsync` TSDoc contains newest-unsettled semantics and no false per-call current-owner guarantee.

Then run:

```text
npm run typecheck
npm run lint
```

Comment-only edits must not require runtime code changes.

---

# Goal 2 — define the generated public-documentation boundary and complete missing TSDoc

## G2.1 Principle

The generator must document the **supported consumer-facing API**, not every public-looking method that happens to be reachable because TypeScript is used internally for coordination.

Do not remove runtime methods in this task.

Use documentation metadata (`@internal`, categories, warnings) to describe intent while preserving declaration/runtime compatibility.

## G2.2 Mark restored-observer lifecycle seams `@internal`

Audit and mark the following `Session` members internal unless source evidence shows a documented consumer use:

```text
isRestoredRunning
observeRestoredRunning()
prepareForExecution()
pollRestoredCallbacks()
settleRestoredObservation()
releaseRestoredHandle()
invalidateRestoredObservation()
reportRestoredObserverError()
```

Required pattern:

```ts
/**
 * ...brief implementation invariant...
 * @internal
 */
```

Keep useful semantic maintenance comments. `@internal` means “not supported consumer API”; it is not permission to make these members undocumented internally.

Do **not** enable TypeScript `stripInternal`. The runtime and `.d.ts` shape must remain compatible. The TypeDoc configuration will use `excludeInternal: true` only for generated reference output.

## G2.3 Classify queue-manager implementation plumbing

Review these methods:

```text
executeSession()
cancelQueued()
findManagedSessionById()
isSessionActiveById()
cancelBySessionId()
```

They are used for Session/FFmpegKitExtended queue coordination and several expose the non-exported structural type `CancellableSession`.

Preferred outcome if they are not intended as direct supported consumer API:

- add `@internal`;
- retain the runtime methods unchanged;
- exclude them from generated docs.

Keep the following documented as consumer-facing queue functionality:

```text
SessionQueueManager.shared
activeSessions
activeSessionCount
queueLength
isBusy
maxConcurrentSessions
cancelCurrent()
clearQueue()
cancelAll()
waitForAll()
```

If repository intent says one of the listed implementation methods is deliberately public, do not hide it. Instead give it complete TSDoc and a clear **Advanced queue control** category.

Do not make this judgment from generator convenience alone.

## G2.4 Handle `CancellableSession` deliberately

TypeDoc validation may report `CancellableSession` because public queue properties reference a non-exported structural type.

Do not disable `validation.notExported` globally.

Resolution order:

1. first exclude truly internal methods that unnecessarily expose the alias;
2. regenerate and inspect the remaining warning;
3. if `activeSessions` still legitimately exposes `CancellableSession`, document that this is an intentional structural implementation type and use a narrow `intentionallyNotExported` entry if TypeDoc requires it;
4. do not introduce a runtime/API signature change solely to silence the generator without explicit evidence that the public type shape itself is defective.

If an additive exported public interface is ultimately judged necessary, stop and record it as an API-shape change before implementing it. It is outside the default documentation-only plan.

## G2.5 Complete `FFmpegKitInitializeOptions`

Add interface-level TSDoc stating:

- these options configure package initialization;
- `assetBaseUrl` is the browser/WebAssembly asset base override;
- native targets normally do not need it;
- failed initialization may be retried through the documented `FFmpegKitExtended.initialize()` semantics.

Keep the existing property-level comment.

## G2.6 Document `Session` public identity fields

Add concise TSDoc to:

```text
sessionId
command
type
```

The generated reference should make clear:

- `sessionId` is the process-unique native identity;
- `command` is the normalized/original command representation associated with the wrapper;
- `type` is the session kind (`ffmpeg`, `ffprobe`, `ffplay`, or media-information type as defined by `SessionType`).

Do not claim IDs persist across process restarts.

## G2.7 Complete `SessionSnapshot` property comments

Every public snapshot property should state its unit/meaning where applicable.

At minimum document currently bare fields:

```text
sessionId
type
state
returnCode
command
output
logs
failStackTrace
logsCount
statisticsCount
debugLogEnabled
```

Preserve the existing timestamp and duration unit comments.

Be precise about retained history and terminal/default values; do not infer meanings not established by code/native JSON contract.

## G2.8 Complete `MediaInformation` concrete properties

`MediaInformationData` already documents the raw fields. Mirror the user-facing meaning on the concrete `MediaInformation` readonly properties so generated class docs remain self-contained.

Do not rely on users navigating to a separate interface to understand the class they receive from `MediaInformationSession.getMediaInformation()`.

Also review `StreamInformation` and `ChapterInformation` concrete properties. If TypeDoc renders interface-inherited descriptions clearly, duplication is optional; verify actual generated output before deciding.

## G2.9 Document enum members

Add member-level comments where generated docs otherwise show unexplained numbers/names, especially:

```text
LogRedirectionStrategy
Signal
```

For `LogRedirectionStrategy`, explain the callback-presence condition represented by each enum value without claiming the TypeScript callback bridge overrides native redirection authority.

For `Signal`, identify the conventional signal (`SIGINT`, `SIGQUIT`, `SIGPIPE`, `SIGTERM`, `SIGXCPU`).

Do not invent platform support beyond the native runtime's existing contract.

## G2.10 Constructor documentation

Inspect generated output for constructors of:

```text
FFmpegSession
FFprobeSession
MediaInformationSession
FFplaySession
StreamInformation
ChapterInformation
MediaInformation
SessionCancelledException
```

Add constructor TSDoc/`@param` only where the generated page is ambiguous.

Do not encourage applications to manually construct session wrappers with arbitrary native IDs. For Session subclasses, state that normal applications obtain instances from factory/history APIs and constructors are primarily wrapper construction surfaces.

## G2.11 Preserve intentionally exported advanced helpers

Keep these root exports documented rather than hiding them:

```text
sessionFromSnapshot()
parseSessionJson()
parseSessionsJson()
```

Classify them under a category such as:

```text
Advanced / history reconstruction
```

State that normal application code should prefer `FFmpegKitExtended` history APIs.

Keep `NativeFFmpegKitExtended` documented under:

```text
Advanced / native bridge
```

with a prominent warning that it is native-entry-only and bypasses wrapper lifecycle safeguards.

## G2.12 Native/Web platform notes

Ensure generated TSDoc clearly communicates:

### `NativeFFmpegKitExtended`

- exported by `src/index.ts` on native React Native targets;
- not exported by `src/index.web.ts`;
- advanced/lower-level integration and diagnostics only.

### `FFmpegKitInitializeOptions.assetBaseUrl`

- Web/Wasm staging option;
- not normally required on native targets.

### `FFplayView`

- one public component API;
- native resolver uses platform host view;
- Web resolver uses `ffplay-view.web.tsx` canvas rendering;
- mount before video playback when a visible surface is required.

## G2.13 Use categories for navigability

Add `@category` tags to top-level public symbols where helpful. Suggested categories:

```text
Execution
Configuration
Sessions
Queue and cancellation
FFplay UI
Media information
Callbacks and types
Utilities
Advanced / history
Advanced / native bridge
```

Do not add categories to every member if it creates noise. Prefer class/module-level organization where the generated hierarchy is already clear.

## G2.14 G2 validation

Before installing/generating docs, run:

```text
npm run typecheck
npm run lint
npm run test:compile
```

Then after TypeDoc is available, strict documentation validation becomes the authoritative completeness gate described in Goal 3.

---

# Goal 3 — add TypeDoc Markdown generation and commit the API reference

## G3.1 Dependencies

Add development dependencies using normal npm package management so `package-lock.json` is updated consistently:

```json
"typedoc": "^0.28.20",
"typedoc-plugin-markdown": "^4.13.1"
```

Do not hand-edit lockfile resolution blocks.

Rationale at plan creation time:

- TypeDoc 0.28.20 is the current npm release;
- TypeDoc 0.28.18 added TypeScript 6.0 support;
- `typedoc-plugin-markdown` 4.13.1 is current;
- plugin 4.5.x–4.13.x declares compatibility with TypeDoc 0.28.x;
- the package itself currently declares TypeScript `^6.0.3`.

After installation, record the actually resolved versions from `package-lock.json`. If npm resolves a newer compatible patch/minor within those ranges, validate it rather than assuming the plan-time exact version.

## G3.2 Add `typedoc.json`

Create `react-native/typedoc.json`.

Recommended baseline:

```json
{
  "$schema": "node_modules/typedoc-plugin-markdown/typedoc-plugin-markdown.schema.json",
  "entryPoints": ["src/index.ts"],
  "entryPointStrategy": "resolve",
  "tsconfig": "tsconfig.json",
  "plugin": ["typedoc-plugin-markdown"],
  "out": "doc/api",
  "router": "member",
  "readme": "none",
  "cleanOutputDir": true,
  "disableSources": true,
  "excludePrivate": true,
  "excludeProtected": true,
  "excludeInternal": true,
  "validation": {
    "notExported": true,
    "invalidLink": true,
    "invalidPath": true,
    "rewrittenLink": true,
    "notDocumented": true,
    "unusedMergeModuleWith": true
  },
  "requiredToBeDocumented": [
    "Enum",
    "EnumMember",
    "Variable",
    "Function",
    "Class",
    "Interface",
    "Accessor",
    "TypeAlias",
    "Property",
    "Method"
  ],
  "treatValidationWarningsAsErrors": true
}
```

### Important: validate actual supported `requiredToBeDocumented` kinds

TypeDoc validates option names/kinds. If `Property` or `Method` is not accepted by the installed TypeDoc release's `requiredToBeDocumented` option, use the supported reflection kinds rather than disabling `notDocumented`.

Start from TypeDoc's documented defaults and expand only with accepted kinds needed to enforce this package's public-comment standard.

Do not blindly copy this JSON if the installed schema rejects it.

## G3.3 Why use only `src/index.ts`

Use `src/index.ts` as the canonical generated entry point.

Do not generate separate complete trees from both native and Web entries because nearly every shared export would be duplicated.

Represent platform differences with TSDoc on:

- `NativeFFmpegKitExtended`;
- initialization options;
- `FFplayView`;
- other truly platform-specific behavior.

## G3.4 Output layout

Commit generated Markdown under:

```text
react-native/doc/api/
```

Use the Markdown plugin's member router so exported classes/functions/types receive stable individual pages grouped by kind.

Expected root:

```text
react-native/doc/api/README.md
```

Do not hand-edit generated files.

If a short human-authored landing page is useful, put it outside the generated directory, for example:

```text
react-native/doc/README.md
```

and link from it to `api/README.md`.

## G3.5 Add package scripts

Add:

```json
"docs:api": "typedoc",
"docs:api:check": "node scripts/check-api-docs.js"
```

After the check is reliable, include it in the local aggregate gate:

```json
"check": "npm run typecheck && npm run lint && npm test && npm run docs:api:check"
```

Do not add docs generation to `prepare`; npm install/package preparation should not silently rewrite tracked documentation.

## G3.6 README API Reference section

Add a concise `## API Reference` section to `react-native/README.md` linking to:

```text
doc/api/README.md
```

State:

- the API reference is generated from source TSDoc;
- generated pages must not be hand-edited;
- run `npm run docs:api` after public API/TSDoc changes;
- run `npm run docs:api:check` to detect stale committed output.

Keep usage guidance/examples in README. Do not replace the README with generated API output.

## G3.7 Initial generation triage

Run:

```text
npm run docs:api
```

Treat every validation warning as work to classify.

Allowed resolutions:

1. add missing meaningful public TSDoc;
2. fix a broken `{@link}`;
3. add `@internal` to an actual internal seam;
4. use a narrowly scoped `intentionallyNotExported` or `intentionallyNotDocumented` entry with recorded rationale when the symbol is intentionally outside generated public docs.

Forbidden resolutions:

- disabling `validation.notDocumented` globally;
- disabling `validation.notExported` globally;
- excluding whole source files that contain public exports;
- adding empty comments only to silence warnings;
- changing runtime behavior/signatures without a separately proven API defect.

## G3.8 Inspect generated coverage

The generated root/navigation must make these areas discoverable:

```text
FFmpegKit
FFprobeKit
FFplayKit
FFmpegKitExtended
FFmpegKitConfig
Session
FFmpegSession
FFprobeSession
FFplaySession
MediaInformationSession
SessionQueueManager
SessionCancelledException
FFplayView / FFplayViewProps
MediaInformation / StreamInformation / ChapterInformation
argument helpers
ReturnCode / SessionState / LogLevel / LogRedirectionStrategy / Signal
Log / Statistics / SessionSnapshot
execution callback/options types
FFmpegKitInitializeOptions
advanced history parsers
NativeFFmpegKitExtended (native-only warning)
```

If an actual root export is absent, determine why before closeout.

---

# Goal 4 — deterministic generated-doc drift validation

## G4.1 Add `scripts/check-api-docs.js`

Implement a cross-platform Node script.

Required algorithm:

1. create a uniquely named temporary directory using Node's `fs.mkdtemp` under `os.tmpdir()`;
2. invoke the package-local `docs:api` command with TypeDoc output overridden to the temporary directory;
3. recursively enumerate generated files and committed `doc/api` files;
4. compare relative path sets;
5. compare text content after normalizing `CRLF`/`LF` only;
6. report every added, missing, and changed relative path;
7. exit nonzero on any difference or generator warning/error;
8. always remove the temporary directory in `finally`;
9. never mutate committed `doc/api` during the check.

## G4.2 Cross-platform local binary invocation

Do not call a global TypeDoc installation.

A robust approach is to spawn npm itself:

```text
npm run docs:api -- --out <temp-dir>
```

From Node, choose the correct npm executable for the host (`npm.cmd` on Windows when required) and use argument arrays rather than shell-concatenated command strings.

Validate this path on Windows and at least one Unix-like host.

Do not use `npx` in a way that can fetch an uninstalled package from the network.

## G4.3 Determinism rules

The check may normalize:

- line endings.

It must not normalize away:

- symbol changes;
- signatures;
- descriptions;
- headings;
- links;
- ordering;
- missing/extra pages.

`disableSources: true` is recommended specifically to avoid machine-specific source URLs/paths.

Do not strip version text unless it proves nondeterministic and is intentionally excluded in generator configuration.

## G4.4 Add focused tests for the drift checker

Prefer a small Node test or testable helper module covering:

- identical directories -> success;
- generated extra file -> failure;
- committed extra file -> failure;
- content difference -> failure;
- CRLF vs LF only -> success;
- temporary directory is cleaned after success/failure.

Do not test by modifying the real committed docs tree in place.

## G4.5 Run immediately after generation

The required invariant is:

```text
npm run docs:api
npm run docs:api:check
```

Both pass with no intervening source change.

Then make a controlled TSDoc edit in a temporary/copied fixture or unit-test seam and prove the check detects drift. Revert the temporary edit afterward.

---

# Goal 5 — final API-doc quality and closure validation

## G5.1 TypeScript/static gates

Run locally from `react-native/`:

```text
npm run typecheck
npm run lint
npm run test:compile
npm run prepare
npm run test:pack-types
npm run docs:api
npm run docs:api:check
```

Because comments, dev dependencies, scripts, and generated docs are the intended change surface, native platform builds are not required unless executable source unexpectedly changes.

Run the full Node suite once after the final package/lockfile changes:

```text
npm test
```

This catches accidental tooling/package-script regressions.

## G5.2 Declaration compatibility check

After `npm run prepare`, verify:

- no supported runtime method disappeared from generated declarations;
- `@internal` annotations used for docs did **not** strip declarations;
- package `types` entry remains `./lib/typescript/src/index.d.ts`;
- packed type consumer still passes;
- browser/native package exports remain unchanged.

Do not enable `stripInternal` in `tsconfig`.

## G5.3 Native/Web API documentation audit

Manually inspect generated pages and confirm:

### Native-only

`NativeFFmpegKitExtended` visibly says native only and lower level.

### Web/Wasm

`FFmpegKitInitializeOptions.assetBaseUrl` visibly says Web/Wasm.

### Shared

FFmpeg/FFprobe/FFplay/session/config/media APIs are described as shared where the implementation supports both entry points.

### FFplayView

Generated docs describe native host rendering plus Web canvas resolver without inventing a texture ID API.

## G5.4 Lifecycle documentation audit

Spot-check generated pages against frozen code for:

- single-use Session submission;
- queued versus active work;
- cancellation Future behavior;
- retained history versus active executions;
- canonical native-ID cancellation ownership;
- terminal cancellation-intent retirement;
- FFplay newest-unsettled current owner;
- stop/close/session disposal differences;
- retained-handle cleanup not presented as user-callable lifecycle operations.

Internal restored-observer methods must not appear in the generated consumer reference.

## G5.5 Public-type/data audit

Ensure generated docs explain:

- units for Statistics fields;
- timestamp units for SessionSnapshot;
- media-information string fields and parsed JSON accessors;
- ReturnCode helpers;
- signal names;
- log redirection strategies;
- execution callback signatures and poll interval behavior.

Do not fill native semantics from assumption. If source does not establish a detail, document only what source guarantees.

## G5.6 README consistency

The narrative README and generated API reference must agree on:

- initialization;
- async execution;
- FFplay controls;
- history;
- cancellation;
- Web setup;
- FFplayView platform behavior.

README remains task-oriented. Generated docs remain signature/reference-oriented.

## G5.7 Dependency/package audit

Verify:

- TypeDoc packages are under `devDependencies` only;
- package-lock changes are limited to normal dependency resolution;
- no native package/binary is downloaded by docs scripts;
- `npm pack --dry-run` or the existing packed consumer flow still behaves as intended;
- generated `doc/api` does not accidentally become package runtime input.

Do not add `doc` to npm `files` merely because docs are committed unless publishing the Markdown inside the npm tarball is a deliberate requirement. GitHub-linked documentation is sufficient for this plan.

## G5.8 Cross-host determinism

Run `npm run docs:api:check` on:

1. Windows;
2. WSL/Linux or macOS.

Both should accept the same committed docs tree.

If output differs, identify the exact generator/path/line-ending source and fix determinism. Do not maintain host-specific generated documentation variants.

## G5.9 No-runtime-diff audit

Before closeout, confirm executable production diff is zero except documentation metadata in comments.

Expected production/comment files may include:

```text
react-native/src/index.ts
react-native/src/ffplay-kit.ts
react-native/src/session.ts
react-native/src/session-queue-manager.ts
react-native/src/types.ts
react-native/src/media-information.ts
react-native/src/platform/backend-registry.ts
react-native/src/ffplay-view.tsx
```

but changes in those files should be comment/TSDoc-only.

Expected tooling/docs files:

```text
react-native/package.json
react-native/package-lock.json
react-native/typedoc.json
react-native/scripts/check-api-docs.js
react-native/tests/... documentation tooling test if added
react-native/doc/api/**
react-native/doc/README.md (optional)
react-native/README.md
```

Any executable logic change in `src/**` is a stop-and-investigate event.

## G5.10 Semantic identifier audit

Search changed source/docs/tests for task/review goal identifiers.

No historical review IDs belong in:

- TSDoc;
- public docs;
- generated docs;
- test names;
- script names.

Tracker metadata may record them.

---

# Recommended `typedoc.json` final shape

Use this as a starting point, then validate against the installed schema:

```json
{
  "$schema": "node_modules/typedoc-plugin-markdown/typedoc-plugin-markdown.schema.json",
  "entryPoints": ["src/index.ts"],
  "entryPointStrategy": "resolve",
  "tsconfig": "tsconfig.json",
  "plugin": ["typedoc-plugin-markdown"],
  "out": "doc/api",
  "router": "member",
  "readme": "none",
  "cleanOutputDir": true,
  "disableSources": true,
  "excludePrivate": true,
  "excludeProtected": true,
  "excludeInternal": true,
  "validation": {
    "notExported": true,
    "invalidLink": true,
    "invalidPath": true,
    "rewrittenLink": true,
    "notDocumented": true,
    "unusedMergeModuleWith": true
  },
  "treatValidationWarningsAsErrors": true
}
```

Then add `requiredToBeDocumented` with the installed version's schema-supported reflection kinds once initial warning volume is understood. The intended policy is strict public API documentation, not broad suppression.

---

# Required final manual API inventory

Before declaring API docs complete, compare generated output to this root-export inventory.

## Core execution

- `FFmpegKit`
- `FFprobeKit`
- `FFplayKit`
- `FFmpegKitExtended`
- `FFmpegKitConfig`

## Sessions

- `Session`
- `FFmpegSession`
- `FFprobeSession`
- `MediaInformationSession`
- `FFplaySession`
- `SessionCancelledException`

## Queue

- `SessionQueueManager` public consumer controls

## FFplay UI

- `FFplayView`
- `FFplayViewProps`

## Media information

- `MediaInformation`
- `MediaInformationData`
- `StreamInformation`
- `StreamInformationData`
- `ChapterInformation`
- `ChapterInformationData`

## Arguments/utilities

- `parseArguments`
- `argumentsToString`
- `isSuccessReturnCode`
- `isCancelReturnCode`

## Types

- `ReturnCode`
- `SessionState`
- `SessionType`
- `LogLevel`
- `LogRedirectionStrategy`
- `Signal`
- `Log`
- `Statistics`
- `SessionSnapshot`
- `SessionCompleteCallback`
- `LogCallback`
- `StatisticsCallback`
- `ExecuteOptions`
- `FFmpegExecuteOptions`
- `FFmpegKitInitializeOptions`

## Advanced / history

- `sessionFromSnapshot`
- `parseSessionJson`
- `parseSessionsJson`

## Advanced / native-only

- `NativeFFmpegKitExtended`

If the generated docs contain additional root exports, classify them intentionally. If this inventory names something no longer exported at implementation time, update the inventory from source rather than forcing the old item back into the package.

---

# Definition of done

The RN API documentation task is complete only when all of the following are true:

- [ ] README no longer describes FFplay position/dimension queries as streams.
- [ ] Promise-returning playback-control examples await or deliberately handle their Promises.
- [ ] `FFplayKit.executeAsync()` documents newest-unsettled current-session behavior accurately.
- [ ] internal restored-observer Session seams are excluded from consumer docs with `@internal` and no runtime removal.
- [ ] queue-manager implementation seams are intentionally classified; consumer queue APIs remain documented.
- [ ] no broad validation suppression hides accidental public API gaps.
- [ ] `FFmpegKitInitializeOptions` is documented at interface level.
- [ ] Session public identity fields are documented.
- [ ] all required `SessionSnapshot` properties are documented.
- [ ] `MediaInformation` concrete class properties are understandable from its own generated page.
- [ ] `Signal` and `LogRedirectionStrategy` members have useful descriptions.
- [ ] advanced history parser exports are documented rather than silently omitted.
- [ ] `NativeFFmpegKitExtended` is documented as native-only/advanced and absent from Web entry semantics.
- [ ] TypeDoc and typedoc-plugin-markdown are dev dependencies with lockfile updates.
- [ ] `typedoc.json` uses `src/index.ts` as the canonical entry point.
- [ ] generated Markdown is committed under `react-native/doc/api/`.
- [ ] README links to the generated API index and says generated pages are not hand-edited.
- [ ] `npm run docs:api` passes with strict validation.
- [ ] `npm run docs:api:check` passes immediately after generation.
- [ ] the drift checker detects controlled stale output and is cross-platform.
- [ ] `npm run typecheck` passes.
- [ ] `npm run lint` passes under the repository's accepted warning policy.
- [ ] `npm run test:compile` passes.
- [ ] `npm run prepare` passes.
- [ ] `npm run test:pack-types` passes and supported declarations remain intact.
- [ ] full local Node tests pass or every unrelated pre-existing failure is recorded truthfully.
- [ ] docs drift check passes on Windows and one Unix-like environment.
- [ ] native/Web platform differences are visible in generated docs.
- [ ] internal observer/release methods do not appear as consumer API.
- [ ] no executable RN runtime behavior changed.
- [ ] no Flutter/native/platform-native/ABI/builder file changed.
- [ ] no remote native artifact was retrieved or published.
- [ ] no hosted RN/Flutter acceptance workflow was run solely for documentation generation.

After these conditions hold, freeze/push the documentation/tooling source according to the repository's normal process. A source snapshot is useful only if the project wants a new documentation-authority artifact; do not create redundant snapshots merely for procedural ceremony.

