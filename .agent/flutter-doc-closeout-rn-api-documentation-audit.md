# Flutter documentation closeout verification + React Native API documentation audit

Date: 2026-10-03
Repository: `akashskypatel/ffmpeg-kit-extended`
Branch represented by snapshot: `dev-wasm`
Audit type: frozen-source documentation/API-comment audit

## 1. Frozen source authority

This audit uses only the supplied Flutter-documentation source snapshot as repository authority:

- source SHA: `cacacf59ae43395ff0b6a7a7fe45fcc4c7809430`
- workflow run: `37134233105`
- source artifact: `flutter-docs-source-snapshot-37134233105`
- artifact ID: `11278430597`
- GitHub artifact SHA-256: `f66c4b0695c304daec9dc608ccfef17d06fed196a0672746d56b3caaeca9bb21`
- embedded `source.tar.gz` SHA-256: `a2bb9782507addee50bc673517f5eb0767a4ac97597799334f2b896a95e5c02e`
- manifest: `1084/1084` files verified
- symlinks: `0`
- `runtimeExecution=false`
- recursive native submodule: `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`
- native ABI/runtime: `0.11.2`, frozen and not re-reviewed

The outer ZIP digest, embedded archive checksum, every `SHA256SUMS` entry, `SUBMODULES.txt`, `SYMLINKS.tsv`, and `snapshot-metadata.json` were independently verified before extraction.

No current branch HEAD or piecemeal repository read is substituted for the snapshot.

---

# Part I — Flutter documentation closeout verification

## 2. Verdict

**Flutter documentation is closed out.**

The previously identified user-facing documentation gaps are materially corrected in the frozen source, the changes remain documentation/comment/test-only, and the bounded manual code-to-documentation consistency pass found no new substantive mismatch.

No further Flutter remediation goal is justified by this audit.

## 3. Boundary verification

Compared with the preceding verified wrapper source, the Flutter remediation is confined to:

- `flutter/README.md`;
- translated READMEs under `flutter/doc/`;
- Markdown API/guides under `flutter/doc/`;
- Dartdoc/comments in existing Flutter Dart sources;
- `flutter/test/documentation_contract_test.dart`.

There is no React Native production drift in the Flutter documentation snapshot and no native ABI, shared C/C++, platform-native, hook implementation, or `libs/libffmpegkit` production change attributable to the documentation remediation.

The tracker embedded in the frozen snapshot records all seven documentation goals complete. Its local validation records:

- documentation contract: `8/8`;
- hook configuration: `15/15`;
- FFplay fullscreen: `7/7`;
- queue: `20/20`;
- lifecycle: `11/11`;
- complete local non-native suite: `228/229`.

The one failed full-suite case is the previously existing Windows WSL-authority expectation in `user_defines_config_test.dart`; it is unrelated to documentation behavior and no runtime change was made to mask it.

## 4. Prior Flutter gaps rechecked

### F-DOC-1 — Hooks configuration and bundle aliases

Closed.

`flutter/README.md` now provides a parseable nested Hooks YAML example and the canonical docs explicitly state that legacy `streaming` is accepted as an alias for `video`.

`documentation_contract_test.dart` parses the README YAML using `package:yaml` rather than relying on text indentation heuristics.

### F-DOC-2 — cross-platform FFplay surface examples

Closed.

Canonical examples use the shared `FFplaySurface.toWidget()` contract rather than assuming every target exposes a native `textureId`. Web/Wasm guidance explicitly covers the copied-frame `RawImage` path.

### F-DOC-3 — FFplay lifecycle semantics

Closed.

The API/reference guides now distinguish:

- one current global control owner;
- independently tracked submitted FFplay executions;
- retained FFplay history;
- `stop()` versus `FFplayKit.close()`;
- `FFplaySession.dispose()`.

The stale singleton/replacement language is absent from the canonical references.

### F-DOC-4 — history versus active execution inventory

Closed.

FFmpeg, FFprobe, and FFplay history APIs are described as retained creation-order/native history rather than as the active execution list. Active execution inventory points to `SessionQueueManager().activeSessions`.

### F-DOC-5 — queue and cancellation semantics

Closed.

The queue guide now documents:

- every active session for aggregate cancellation;
- queued execution Future rejection;
- `SessionCancelledException`;
- native-session-ID uniqueness;
- `isBusy` as active work;
- `queueLength` separately for pending work.

### F-DOC-6 — canonical API reference coverage

Closed.

The frozen docs include the formerly missing argument-list factories, FFprobe/FFplay log callback signatures, configuration utilities, message/introspection methods, and a dedicated `FFmpegKitExtended` reference page.

### F-DOC-7 — FFplayView sizing

Closed.

The docs now match `_buildVideo`: the layout consumes available horizontal width and constrains the calculated height using the source-height authority when available. The stale native-width/no-upscale claim is gone.

### F-DOC-8 — platform rendering descriptions

Closed.

The documentation distinguishes the actual implementations:

- Android native surface;
- Apple Flutter texture / `CVPixelBuffer` path where applicable;
- Linux/Windows desktop callback-backed rendering;
- Web/Wasm copied RGBA frames rendered through `RawImage`.

The old Linux-owned-OpenGL description is no longer canonical.

### F-DOC-9 — asynchronous error guidance

Closed.

The error guide now distinguishes terminal FFmpeg return codes from rejected execution Futures, including pre-start queue cancellation/lifecycle/backend failures.

### F-DOC-10 — translated README factual drift

Closed.

The seven translated READMEs now retain the canonical platform/version/architecture/Web/Hook facts guarded by the documentation contract.

## 5. Flutter closeout conclusion

No new Flutter documentation or comment finding meets the substantive threshold.

Do not create another Flutter documentation remediation plan, validation cycle, code commit, or source snapshot solely because this audit was performed.

Reopen Flutter documentation only when a later production/API/configuration change makes the existing documentation stale or a concrete user-facing inconsistency is demonstrated.

---

# Part II — React Native API documentation/comment audit

## 6. Current React Native documentation state

The React Native package currently has strong narrative lifecycle documentation in `react-native/README.md` and useful TSDoc on many high-level classes, but it has **no generated API reference**.

Current package state:

- public native entry point: `react-native/src/index.ts`;
- browser entry point: `react-native/src/index.web.ts`;
- built declarations: `lib/typescript/src/index.d.ts` after Bob build;
- no `react-native/doc/` or `react-native/docs/` directory;
- no TypeDoc dependency;
- no API-doc generation script;
- no generated-doc drift check.

The root native entry exports:

- `NativeFFmpegKitExtended`;
- argument helpers;
- `FFmpegKit`;
- `FFmpegKitConfig`;
- `FFmpegKitExtended`;
- `FFplayKit`;
- `FFprobeKit`;
- media-information models;
- Session classes and history parsers;
- `SessionQueueManager`;
- public enums/types/callbacks;
- `FFmpegKitInitializeOptions`;
- `FFplayView`.

The browser entry exports the shared TypeScript API but deliberately omits `NativeFFmpegKitExtended` and resolves `FFplayView` through `ffplay-view.web.tsx`.

## 7. Positive baseline

The RN API comments are not starting from zero. The following surfaces already have generally useful semantic TSDoc:

- high-level FFmpeg/FFprobe/FFplay execution methods;
- initialization and wrapper facade behavior;
- cancellation and terminal lifecycle semantics;
- configuration methods;
- queue aggregate operations;
- log/statistics callback structures;
- stream/chapter/media-information data interfaces;
- FFplay controls;
- `FFplayView` native/Web intent;
- recent canonical-owner/cancellation comments from Reviews 44–51.

A generator can therefore use source comments as the primary authority instead of maintaining a second hand-written method inventory.

## 8. RN documentation findings

### RN-DOC-1 — High — no generated API reference or drift contract

There is no complete browsable reference generated from `src/index.ts` and no command that proves committed API docs match the exported source.

Consequences:

- users must search implementation files for method signatures;
- root exports are not systematically discoverable;
- additions/removals can silently drift from README documentation;
- current comments are not automatically validated for broken links or undocumented public symbols.

Required direction: generate committed Markdown API docs from the canonical TypeScript entry point and add a deterministic stale-doc check.

### RN-DOC-2 — Medium-High — `FFplayKit.executeAsync()` current-session TSDoc is inaccurate

Current comment says:

> The active session remains current until this method's Promise settles.

The implementation maintains `unsettledSessions` and `getNewestUnsettledSession()`. With overlapping high-level FFplay calls, the current global high-level control owner is the **most recently submitted unsettled** session; an older session does not necessarily remain current until its own Promise settles.

Required correction: describe newest-unsettled ownership and fallback to the next newest still-unsettled session when a newer one settles.

### RN-DOC-3 — Medium — README says FFplay exposes position/dimension “streams”

The Features section currently says:

> Real-time Streaming: Position and video dimension streams for live playback monitoring.

The public `FFplaySession` surface exposes synchronous state queries such as `getPosition()`, `getVideoWidth()`, and `getVideoHeight()`. It does not expose public position/dimension observable streams.

Required correction: describe live position/video-dimension **queries** instead of streams.

### RN-DOC-4 — Medium — README playback-control example ignores Promise semantics

The README currently shows:

```ts
session.pause();
session.seek(10);
session.resume();
session.setVolume(0.5);
```

Those methods return `Promise<void>` and can reject on backend/native errors. The user-facing example should use `await` (or explicitly demonstrate concurrent Promise handling) so control ordering and failure handling are truthful.

### RN-DOC-5 — High for generated-reference quality — observer/lifecycle implementation seams are public in TypeScript and would be presented as normal user API

`Session` currently exposes several public methods/accessors used by internal queue/restored-observer coordination:

- `isRestoredRunning`;
- `observeRestoredRunning()`;
- `prepareForExecution()`;
- `pollRestoredCallbacks()`;
- `settleRestoredObservation()`;
- `releaseRestoredHandle()`;
- `invalidateRestoredObservation()`;
- `reportRestoredObserverError()`.

These are not normal application operations. Publishing them beside `cancel()`, state getters, and session output APIs would imply a supported user contract that the wrapper does not intend.

Required direction: mark genuinely internal lifecycle seams with TSDoc `@internal` and configure the generator with `excludeInternal: true`. Do **not** remove or rename runtime members in this documentation task, and do not enable TypeScript `stripInternal`.

### RN-DOC-6 — Medium-High — queue implementation seams need an explicit documentation boundary

`SessionQueueManager` is public and useful, but not every public method is an application-level API.

Normal user-facing queue controls include:

- `shared`;
- `activeSessions` / counts;
- `queueLength` / `isBusy`;
- `maxConcurrentSessions`;
- `cancelCurrent()`;
- `clearQueue()`;
- `cancelAll()`;
- `waitForAll()`.

Implementation plumbing currently also appears public:

- `executeSession()`;
- `cancelQueued()`;
- `findManagedSessionById()`;
- `isSessionActiveById()`;
- `cancelBySessionId()`.

Several of those use the non-exported `CancellableSession` structural type and exist primarily for Session/FFmpegKitExtended coordination.

Required direction: classify the implementation-only queue methods with `@internal` if the maintainer confirms they are not supported direct consumer API. Do not change their runtime availability or behavior in this task. Keep the normal queue inventory/control methods generated and documented.

If TypeDoc reports the non-exported `CancellableSession` type because a genuinely public member still exposes it (notably `activeSessions`), resolve it deliberately; do not silence all `notExported` diagnostics globally.

### RN-DOC-7 — Medium — important exported data surfaces are incompletely documented

Examples found in the frozen source:

- `FFmpegKitInitializeOptions` lacks an interface-level description even though `assetBaseUrl` is documented;
- `Session.sessionId`, `Session.command`, and `Session.type` lack member comments;
- many `SessionSnapshot` fields lack property-level comments;
- `MediaInformation` class properties are not individually documented even though the corresponding `MediaInformationData` fields are;
- `Signal` members lack individual descriptions;
- `LogRedirectionStrategy` members lack individual descriptions;
- several exported constructors rely only on class-level prose and provide little generated parameter guidance.

With `validation.notDocumented` enabled, these should be filled in or intentionally exempted with a narrow documented reason.

### RN-DOC-8 — Medium — platform-specific export differences need first-class API notes

Generated docs from the native entry point must not imply identical runtime exports on Web.

Required explicit notes:

- `NativeFFmpegKitExtended` is native-only, advanced/lower-level, and is not exported by `index.web.ts`;
- `FFmpegKitInitializeOptions.assetBaseUrl` is specifically relevant to Web/Wasm staging;
- `FFplayView` is one public component with native host implementations and a `.web.tsx` canvas resolver;
- native-only diagnostics/raw bridge calls should not be presented as the recommended cross-platform path.

### RN-DOC-9 — Medium — advanced but intentionally exported helpers need categorization

The package root intentionally exports:

- `sessionFromSnapshot()`;
- `parseSessionJson()`;
- `parseSessionsJson()`.

Do not silently hide these just to make generated docs smaller. They are real root exports. Document them under an **Advanced / history reconstruction** category and explain that normal applications should prefer `FFmpegKitExtended` history APIs.

Likewise, `NativeFFmpegKitExtended` should remain documented under an **Advanced / native bridge** category rather than being omitted from the native API reference.

### RN-DOC-10 — Medium — no deterministic generated-doc check

Once generated API Markdown is committed, a simple `typedoc` generation script is insufficient: stale generated files can be committed or source comments can change without regeneration.

Required direction: add a cross-platform Node check that generates into a temporary directory, compares the generated tree against committed `react-native/doc/api`, normalizes line endings only, reports added/missing/changed files, exits nonzero on drift, and cleans the temporary directory.

Do not depend on `git diff` as the only check because validation runs in mounted/copied/package contexts as well as ordinary Git worktrees.

## 9. Recommended generator

Use TypeDoc plus the official/common Markdown renderer integration:

- `typedoc` `^0.28.20`;
- `typedoc-plugin-markdown` `^4.13.1`.

At audit time:

- TypeDoc 0.28.20 is the current npm release;
- TypeDoc 0.28.18 introduced TypeScript 6.0 support, matching this package's `typescript: ^6.0.3` line;
- `typedoc-plugin-markdown` 4.13.1 is current and its compatibility table maps plugin 4.5.x–4.13.x to TypeDoc 0.28.x.

The dependencies should be dev dependencies only and `react-native/package-lock.json` must be updated by normal npm resolution.

## 10. Recommended output contract

Generate committed Markdown under:

```text
react-native/doc/api/
```

Use `src/index.ts` as the single canonical entry point.

Do not generate independently from both `src/index.ts` and `src/index.web.ts`: that would duplicate most symbols. Instead, document browser/native differences on the affected exported symbols.

Recommended TypeDoc characteristics:

- Markdown plugin enabled;
- member router for one page per exported class/function/type;
- `excludePrivate: true`;
- `excludeProtected: true`;
- `excludeInternal: true`;
- `disableSources: true` for deterministic repository Markdown without workstation-specific source links;
- documentation validation enabled for undocumented symbols, broken links, and accidentally referenced non-exported types;
- validation warnings treated as errors;
- committed generated output cleaned/replaced on each generation.

The package README should link to the generated API index and state that files under `doc/api/` are generated from source TSDoc and must not be hand-edited.

## 11. RN audit conclusion

React Native runtime/platform code remains closed from the prior cross-platform reviews. This audit identifies a **documentation publication and TSDoc-boundary task**, not a runtime remediation task.

The recommended work is:

1. correct the few factual README/TSDoc mismatches;
2. explicitly mark internal lifecycle seams so they do not become advertised API;
3. fill missing public comments needed for strict generation;
4. add TypeDoc + Markdown generation;
5. commit the generated API reference;
6. add deterministic local drift validation;
7. preserve all runtime/native files unchanged.

