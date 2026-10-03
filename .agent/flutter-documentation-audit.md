# Flutter Documentation and Public-Comment Audit

Date: 2026-10-03  
Repository: `akashskypatel/ffmpeg-kit-extended`  
Branch represented by audited source: `dev-wasm`  
Source authority: `1506c49f1eba4cf1d25af3fd8bcc438d039b117a`  
Audit type: frozen-source documentation/comment audit; no production behavior changes

## 1. Authority and scope

This audit uses the verified Review 51/52 wrapper source snapshot as the code authority. The native ABI/runtime remains frozen at `0.11.2`; `libs/libffmpegkit` remains frozen at `b74da2c5d1e294b87d15d73a6687393729e932b3` and was not re-reviewed.

The audit compares user-facing Flutter documentation and exported Dartdoc/comments against the implementation actually present in the frozen source. The audited documentation surface includes:

- `flutter/README.md`;
- `flutter/doc/index.md`, installation and quick-start material;
- `flutter/doc/api/*.md`;
- `flutter/doc/guides/*.md`;
- translated Flutter READMEs under `flutter/doc/README.*.md`;
- public Dartdoc/comments on exported Flutter classes under `flutter/lib/src/**`;
- examples where they are presented as canonical usage guidance.

The audit intentionally excludes style-only wording preferences, formatting nits, and internal comments that cannot affect users or maintainers interpreting public behavior.

## 2. Executive disposition

The Flutter implementation remains technically closed from the preceding cross-platform code reviews, but its user-facing documentation is **not documentation-clean**. Ten substantive documentation/comment gaps were found.

| ID | Severity | Area | Summary |
| --- | --- | --- | --- |
| D1 | High | Installation | Main README contains copy/paste-invalid YAML for `hooks.user_defines` |
| D2 | High | FFplay surface | Cross-platform examples expose native-only `textureId`; they do not compile against the Web `FFplaySurface` |
| D3 | Medium-High | FFplay lifecycle | Docs/comments claim one active session and automatic replacement, but code tracks overlapping executions and only changes the current global owner |
| D4 | Medium-High | Session history | Convenience APIs are documented as active/executed-session queries although they return retained native-layer history / creation order |
| D5 | Medium | Queue semantics | Queue guide and Dartdoc misstate `cancelCurrent`, queued-cancellation error delivery, and duplicate native-ID admission |
| D6 | Medium | API signatures | FFprobe/FFplay API references omit supported `onLog`; FFmpeg/FFplay argument-list factories and several config utilities are undocumented |
| D7 | Medium | FFplayView sizing | API reference describes width-capping/no-upscale behavior that the widget does not implement |
| D8 | Medium | Platform rendering | Linux/Apple/Web surface implementation descriptions are stale or incomplete; exported desktop-texture Dartdoc omits Apple support |
| D9 | Medium | Error handling | Guides over-center return codes and omit Future rejection / `SessionCancelledException` behavior of async queue paths |
| D10 | Medium | Translation parity | Translated READMEs carry stale architecture/rendering guidance relative to current hook/runtime behavior |

No native ABI, Flutter runtime, platform-native, or wrapper behavior change is required by these findings. Remediation is documentation, Dartdoc/comment, and documentation-regression coverage only.

---

## 3. D1 — main installation YAML is invalid

Severity: **High**

Affected file:

- `flutter/README.md:85-98`

The main README gives this `pubspec.yaml` example:

```yaml
hooks:
  user_defines:
    ffmpeg_kit_extended_flutter:
       type: "base"
      gpl: true
      small: true
```

In the frozen source, `type` is indented one space farther than its sibling keys. A normal YAML parser rejects the block. This is the primary installation path and is specifically presented as copy/paste configuration, so this is a user-blocking documentation defect.

The canonical quick-start block at `flutter/doc/quick-start.md:18-28` has the correct indentation and should be used as the source of truth.

A secondary inconsistency exists in the same README comment: it lists `debug, base, full, audio, video, video_hw`, while the build hook also accepts legacy `streaming` and normalizes it to `video` (`flutter/hook/build.dart` around the Web/native type normalization). The quick-start already mentions `streaming`.

### Required remediation

1. Fix the indentation in `flutter/README.md` so `type`, `gpl`, `small`, and platform overrides are sibling keys.
2. Keep the supported bundle-type wording consistent between README, quick-start, and hook behavior. Prefer explaining `streaming` as a compatibility alias for `video` rather than presenting it as a distinct current artifact family.
3. Add a documentation contract test that extracts the canonical Hooks YAML example and parses it with the package's existing `yaml` dependency.
4. Do not introduce a second hand-maintained configuration snippet shape if the same example can be shared/kept structurally identical across README and quick-start.

---

## 4. D2 — cross-platform FFplay surface examples use a native-only property

Severity: **High**

Affected documentation:

- `flutter/doc/api/ffplay-kit.md:24-38`
- `flutter/doc/api/video-surface.md:7-60`
- `flutter/doc/api/data-models.md:57-95`

Relevant implementation:

- native `FFplaySurface`: `flutter/lib/src/platform/native/ffplay_surface_native.dart:18-72`
- Web `FFplaySurface`: `flutter/lib/src/web/ffplay_surface_web.dart`

The API reference presents `FFplaySurface.textureId` as a cross-platform property and shows:

```dart
final surface = await FFplaySurface.create();
Texture(textureId: surface.textureId)
```

This is not the shared API:

- native `FFplaySurface` has `textureId`;
- Web `FFplaySurface` does **not** have `textureId` and renders a copied Wasm frame via `toWidget()`;
- `FFplaySurface.create()` returns a nullable `Future<FFplaySurface?>`, so the example also dereferences a nullable value without checking it.

The user-facing abstraction that works on all supported targets is `surface.toWidget()` after checking that creation succeeded.

### Required remediation

1. Remove `textureId` from the **cross-platform** `FFplaySurface` contract in `api/video-surface.md` and `api/data-models.md`.
2. Replace direct `Texture(textureId: ...)` examples with:

```dart
final surface = await FFplaySurface.create();
if (surface == null) {
  // Handle surface creation failure.
  return;
}

final widget = surface.toWidget();
```

3. State explicitly that `textureId` is a native-only implementation detail available on the native surface/texture classes, not on Web.
4. Keep direct `FFplayAndroidSurface` / `FFplayDesktopTexture` docs clearly labeled as platform-specific lower-level APIs.
5. Add a source-contract test ensuring cross-platform documentation examples do not access `FFplaySurface.textureId`.

---

## 5. D3 — FFplay global lifecycle documentation describes a singleton execution model that code does not implement

Severity: **Medium-High**

Affected documentation/comments:

- `flutter/lib/src/ffplay_kit.dart:28-36`
- `flutter/doc/api/ffplay-kit.md:5-20`
- `flutter/doc/guides/playback-control.md:13-36,83-89`
- related wording in FFplay API session-management sections

Current implementation:

- `_activeFFplaySession` identifies the **current global control owner**;
- `_trackedExecutions` is a `Set<FFplaySession>` and may contain more than one submitted execution;
- starting another global session assigns a new `_activeFFplaySession` but does not cancel or stop an older tracked execution;
- `_releaseTrackedExecution()` selects the most recently tracked remaining owner when one execution settles;
- `FFplayKit.stop()` calls only `FFplaySession.stop()`;
- `FFplayKit.close()` calls only `FFplaySession.close()` and does not call `Session.dispose()`;
- tracked executions retain current/global ownership until their execution Future settles.

The documentation currently says, among other things:

- "Only one FFplay session can be active at a time";
- "Starting a new session automatically replaces any existing one";
- `stop()` "stops playback and closes the session";
- `close()` "shuts down the entire FFplay environment and releases resources";
- `getFFplaySessions()` is a list with at most one active session.

Those statements do not match the wrapper state machine.

### Required remediation

1. Replace the singleton-execution claim with a **current global control owner** model:
   - global controls target `currentSession` / `_activeFFplaySession`;
   - a newer global session becomes the current owner;
   - already tracked executions are not implicitly cancelled merely because a newer session is created.
2. Explain that `stop()` requests playback stop and is distinct from `close()`.
3. Explain that `close()` invokes the FFplay close control; deterministic Session-handle ownership is still governed by `dispose()`/execution lifecycle.
4. Describe `getCurrentSession()`/`currentSession` as the current global control owner, not necessarily the only live FFplay history/execution object.
5. Remove "at most one" wording from `getFFplaySessions()`; that method is a typed history query, addressed again in D4.
6. Correct the source comment at `ffplay_kit.dart:28` and class Dartdoc so maintainers do not reintroduce singleton assumptions.
7. Add a semantic documentation contract that rejects phrases such as "starting a new session automatically replaces/cancels the previous one" unless code later implements that behavior explicitly.

---

## 6. D4 — convenience session queries are documented as active/executed queries but are history queries

Severity: **Medium-High**

Affected Dartdoc/API references:

- `flutter/lib/src/ffmpeg_kit.dart:70-76`
- `flutter/lib/src/ffprobe_kit.dart:79-81`
- `flutter/lib/src/ffplay_kit.dart:111-113`
- `flutter/doc/api/ffmpeg-kit.md:148-190`
- `flutter/doc/api/ffprobe-kit.md:214-225`
- `flutter/doc/api/ffplay-kit.md:430-449`

Authoritative implementation:

- `FFmpegKitExtended.getFFmpegSessions()` returns all FFmpeg sessions in native-layer history (`ffmpeg_kit_extended.dart:353-359`);
- `getFFprobeSessions()` and `getFFplaySessions()` do the equivalent typed history projection;
- `getLastFFmpegSession()` returns the **most recently created** typed history session (`ffmpeg_kit_extended.dart:450-457`), not necessarily the most recently completed/executed one;
- the dedicated `getLastCompletedSession()` exists for completed-session semantics.

The current convenience Dartdoc/API text says "all active" and "last executed". That changes how callers reason about counts, terminal sessions, and whether returned objects represent current work.

### Required remediation

1. Change convenience Dartdoc to say "retained history" / "most recently created retained history session".
2. Update API examples so they do not print "Active sessions" for history lists.
3. Document how callers should inspect `session.getState()` when they need to filter history for Running/terminal sessions.
4. If an active-only list is desired in examples, direct users to `SessionQueueManager().activeSessions` rather than history getters.
5. Add/update documentation for `FFmpegKitExtended.getLastCompletedSession()` and distinguish it from `getLast*Session()` creation-order queries.
6. Keep `MediaInformationSession` distinct from plain FFprobe typed history, matching the existing typed projection behavior.

---

## 7. D5 — queue documentation/comment semantics are inconsistent with implementation

Severity: **Medium**

Affected sources:

- `flutter/lib/src/session_queue_manager.dart:80-123`
- `flutter/doc/guides/session-queue-management.md:74-160`

### A. `cancelCurrent()`

The guide says:

```dart
// Cancel the "current" session (most recent one added to active list)
queueManager.cancelCurrent();
```

The implementation snapshots **all active sessions**, calls `cancel()` on every one, and rethrows the first cancellation error after all attempts. The API table later in the same guide correctly says "Attempts every active session".

### B. `clearQueue()` cancellation errors

The guide says `clearQueue()` "throws SessionCancelledException for each". The method itself returns `void`; it removes queued items and completes each **queued execution Future** with `SessionCancelledException` (or cleanup failure). The synchronous `clearQueue()` call is not a stream of thrown cancellation exceptions.

### C. duplicate native session IDs

`SessionQueueManager.executeSession()` Dartdoc says distinct Session objects remain eligible. The actual `_containsSession()` first checks `_reservedSessionIds`, so a different wrapper with the same native session ID is rejected while that ID is queued or active.

### D. `isBusy`

The public getter is implemented as `_activeSessions.isNotEmpty`. The guide table says "active or queued". Although normal queue operation generally implies queued work exists behind active work, documentation should state the actual contract: `isBusy` reflects active executions; use `queueLength` separately for pending work.

### Required remediation

1. Make the guide and Dartdoc use the all-active `cancelCurrent()` semantics.
2. Explain that queue removal errors are delivered through the affected execution Futures.
3. Correct `executeSession()` Dartdoc to document native-session-ID reservation, not object identity only.
4. Align `isBusy` wording with its getter implementation.
5. Add a small documentation-contract test that checks these key semantic phrases against the API surface rather than relying on prose duplication.

---

## 8. D6 — API reference signatures and exported-surface coverage are stale

Severity: **Medium**

Affected references include:

- `flutter/doc/api/ffprobe-kit.md`
- `flutter/doc/api/ffplay-kit.md`
- `flutter/doc/api/ffmpeg-kit.md`
- `flutter/doc/api/config.md`
- `flutter/doc/index.md`

### Signature drift

Actual `FFprobeKit.executeAsync` and `createSession` accept `FFmpegLogCallback? onLog` (`flutter/lib/src/ffprobe_kit.dart`). The API reference omits that parameter.

Actual `FFplayKit.executeAsync` and `createSession` also accept `onLog`, and `FFplayKit` exposes `createSessionFromArguments(...)`. The API reference omits `onLog` and does not document the argument-list factory.

`FFmpegKit.createSessionFromArguments(...)` is exported but absent from the FFmpeg API reference.

### Configuration/API coverage

`FFmpegKitConfig` exports utilities not mentioned in `api/config.md`, including:

- `logLevelToString`;
- `sessionStateToString`;
- `messagesInTransmit`.

More broadly, `FFmpegKitExtended` is a public exported facade with package/build introspection, typed history lookup, last/completed lookup, audio device configuration, debug-log controls, and session factories, but the documentation index has no dedicated Extended API reference.

### Required remediation

1. Update signatures in API markdown to match exported Dart signatures exactly.
2. Add `createSessionFromArguments` for FFmpeg and FFplay, with argument-tokenization guidance (do not re-parse already-tokenized arguments).
3. Add missing config utility coverage.
4. Add `doc/api/ffmpeg-kit-extended.md` for the public Extended facade, or explicitly move all public Extended methods into logically appropriate existing API pages. A dedicated page is preferred because the class is already a public central facade.
5. Update `doc/index.md` to link the new/expanded surface.
6. Add an API-doc inventory test that checks selected exported public method names appear in the canonical API reference. Do not require every private/test-only symbol or perform brittle full-source snapshots.

---

## 9. D7 — FFplayView sizing reference does not match the widget

Severity: **Medium**

Affected docs/comments:

- `flutter/doc/api/video-surface.md:106-159`
- `flutter/lib/src/ffplay_view.dart:109-162`

The API reference claims:

- `videoWidth` caps width to `min(containerWidth, videoWidth)`;
- the widget "never upscales beyond native dimensions";
- `videoHeight` is informational;
- the sizing table uses `min(containerWidth, videoWidth)`.

The implementation does something different when an aspect ratio and source dimensions are present:

- it uses the full finite `constraints.maxWidth` as widget width;
- it derives source height from `videoHeight` or `videoWidth / aspectRatio`;
- it caps **height** at source height via `min(maxWidth / aspectRatio, sourceH)`;
- therefore the widget can occupy a width greater than native pixel width while limiting height;
- `videoHeight` directly participates in layout and is not purely informational.

The class-level Dartdoc already describes the full-width/height-cap model more accurately than the API markdown, but the `videoHeight` field comment still calls it informational.

### Required remediation

1. Rewrite the API sizing table to reflect the actual `_buildVideo()` algorithm.
2. Correct the `videoWidth` and `videoHeight` parameter descriptions.
3. Correct the `videoHeight` Dartdoc comment in `ffplay_view.dart`.
4. Decide whether the current full-width/height-cap behavior is the intended API. This remediation plan assumes **documentation follows current code**; do not change layout behavior as part of a docs audit.
5. Add a focused source/doc contract test using semantic snippets for the sizing rule, or reuse existing FFplayView layout tests as code authority and keep only one canonical prose explanation.

---

## 10. D8 — platform-rendering documentation and exported Dartdoc are stale

Severity: **Medium**

Affected sources include:

- `flutter/README.md:27-37`
- `flutter/doc/guides/video-playback.md:5-24`
- `flutter/doc/api/video-surface.md:7-20`
- `flutter/doc/api/data-models.md:57-95`
- `flutter/lib/src/platform/native/ffplay_desktop_texture.dart:24-76`
- translated READMEs

### Linux

The README still advertises "OpenGL integration" for Linux. Current Flutter Linux ownership uses the pixel-buffer texture path established by the platform plugin; user-facing sections later in the same README correctly say Linux/Windows use pixel-buffer textures with frame callbacks.

### Apple

The unified surface implementation explicitly routes iOS and macOS through `FFplayDesktopTexture.create()` / the Apple Flutter texture implementations. Several API/guide pages describe only Android and Linux/Windows, omitting Apple from the cross-platform rendering matrix.

The exported `FFplayDesktopTexture` Dartdoc says it is a Linux/Windows desktop surface and says Android returns null, but `create()` explicitly supports Linux, Windows, iOS, and macOS.

### Web

The video playback guide overview says the unified API works across Android, Linux, and Windows, despite the current package and surface implementation supporting iOS, macOS, and Web as well.

### Required remediation

1. Establish one canonical rendering matrix:
   - Android: SurfaceTexture/ANativeWindow path;
   - iOS/macOS: Flutter texture backed by CVPixelBuffer Apple implementation;
   - Linux/Windows: Flutter pixel-buffer texture/frame-callback implementation;
   - Web: copied Wasm RGBA frames rendered via Flutter `RawImage` through `FFplaySurface.toWidget()`.
2. Replace the stale Linux "OpenGL integration" marketing line.
3. Correct `FFplayDesktopTexture` Dartdoc to explicitly include Apple and avoid claiming the Linux/Windows C++ path applies to Apple.
4. Make lower-level native classes clearly platform-specific while keeping `FFplaySurface` as the recommended user abstraction.
5. Synchronize all API and guide pages to the same matrix.

---

## 11. D9 — async error/cancellation guidance does not describe Future rejection semantics

Severity: **Medium**

Affected documentation:

- `flutter/doc/guides/error-handling.md`
- `flutter/doc/guides/session-queue-management.md`
- relevant quick-start examples

The error guide says `ReturnCode` is the primary way to determine success/failure and mostly demonstrates terminal return-code inspection. That is correct for a session that successfully reaches a terminal native state, but it is incomplete for the current asynchronous wrapper lifecycle.

The async queue path can complete its returned Future with an exception before a usable terminal Session result is returned, including:

- queued/pre-execution removal (`SessionCancelledException`);
- duplicate session/native-ID admission (`StateError`);
- disposed-session execution (`StateError`);
- initialization/state/start/backend errors propagated from the executor;
- cleanup/ownership failures when those are the authoritative public error.

A running native cancellation may instead finish as a terminal session with a cancel return code. These are different caller contracts.

### Required remediation

1. Add an "Async Future errors vs terminal return codes" section.
2. Show `try/catch` around `await FFmpegKit.executeAsync(...)` and distinguish:
   - `SessionCancelledException` for queue/pre-start cancellation Future rejection;
   - terminal `ReturnCode.cancel` when native execution reaches a cancelled terminal result;
   - `StateError`/backend exceptions for lifecycle/admission/start failures.
3. Explain that callbacks are not a replacement for awaiting/handling the returned Future when the caller needs startup/execution errors.
4. Correct the queue guide's exception wording as described in D5.
5. Keep the guidance platform-neutral and avoid promising a specific native return code for failures that occur before native terminal state.

---

## 12. D10 — translated README parity is stale

Severity: **Medium**

Affected files:

- `flutter/doc/README.es.md`
- `flutter/doc/README.fr.md`
- `flutter/doc/README.hi.md`
- `flutter/doc/README.ar.md`
- `flutter/doc/README.ja.md`
- `flutter/doc/README.pt-BR.md`
- `flutter/doc/README.zh-CN.md`

Examples of current drift:

- translated platform tables still list Linux and Windows as `x86_64` only, while current hook selection supports `arm64` and `x64` for both;
- translations repeat the stale Linux "OpenGL integration" description;
- platform-surface details lag the current Apple/Web/pixel-buffer model;
- English canonical installation and hook behavior has accumulated fixes that are not consistently mirrored in translations.

### Required remediation

1. Fix English canonical docs first.
2. Update all translations from the corrected English behavioral facts; preserve natural language quality but do not translate code identifiers/config keys.
3. At minimum synchronize:
   - supported platforms and architectures;
   - build-hook configuration precedence;
   - Web/Wasm staging and cross-origin requirements;
   - FFplay rendering matrix;
   - initialization requirement;
   - current session/cancellation semantics if those sections are present.
4. Add a lightweight translation-parity contract that validates factual tokens/tables (platform names, architecture identifiers, minimum Flutter/Dart versions, primary config keys) without attempting to machine-compare prose translations.

---

## 13. Recommended remediation grouping

The findings should be fixed in six bounded documentation goals rather than ten independent edits:

1. **Installation/configuration correctness** — D1 plus canonical bundle/config wording.
2. **Session/history/queue semantics** — D4, D5, and async cancellation/error portion of D9.
3. **FFplay lifecycle/API semantics** — D3 plus FFplay portions of D6.
4. **Cross-platform surface and layout documentation** — D2, D7, D8.
5. **Public API completeness and error guidance** — remaining D6 and D9, including a dedicated `FFmpegKitExtended` reference.
6. **Translation synchronization + documentation contracts** — D10 and final regression coverage.

## 14. Files expected to change

Likely canonical documentation/comment changes:

- `flutter/README.md`
- `flutter/doc/index.md`
- `flutter/doc/quick-start.md`
- `flutter/doc/api/ffmpeg-kit.md`
- `flutter/doc/api/ffprobe-kit.md`
- `flutter/doc/api/ffplay-kit.md`
- `flutter/doc/api/config.md`
- `flutter/doc/api/sessions.md`
- `flutter/doc/api/video-surface.md`
- `flutter/doc/api/data-models.md`
- new `flutter/doc/api/ffmpeg-kit-extended.md`
- `flutter/doc/guides/session-queue-management.md`
- `flutter/doc/guides/playback-control.md`
- `flutter/doc/guides/video-playback.md`
- `flutter/doc/guides/error-handling.md`
- seven translated `flutter/doc/README.*.md` files
- public Dartdoc/comment-only changes in:
  - `flutter/lib/src/ffmpeg_kit.dart`
  - `flutter/lib/src/ffprobe_kit.dart`
  - `flutter/lib/src/ffplay_kit.dart`
  - `flutter/lib/src/session_queue_manager.dart`
  - `flutter/lib/src/ffplay_view.dart`
  - `flutter/lib/src/platform/native/ffplay_desktop_texture.dart`

Expected test additions should remain under `flutter/test/` and validate documentation contracts only.

## 15. Non-goals

Do not change runtime behavior merely to make existing prose true. In particular, this audit does **not** request:

- FFplay singleton enforcement;
- queue cancellation behavior changes;
- new active-session APIs;
- FFplayView sizing behavior changes;
- a cross-platform `textureId` property;
- native ABI changes;
- platform-native rendering changes;
- native bundle/build-hook behavior changes.

Documentation must be corrected to the frozen implementation unless a separate product decision explicitly changes behavior later.

## 16. Closeout criterion

The Flutter documentation audit is closed only when:

- every D1-D10 mismatch above is corrected or explicitly superseded by a documented product decision;
- canonical English docs and exported Dartdoc agree with source behavior;
- translated factual platform/config tables match the canonical English facts;
- documentation examples avoid platform-only APIs when presented as cross-platform;
- the main installation YAML parses;
- selected public API signature/inventory contracts are covered by focused tests;
- documentation tests are semantic and targeted, not full-file snapshots;
- no runtime, native ABI, platform-native, or wrapper behavior change is introduced solely to satisfy documentation.
