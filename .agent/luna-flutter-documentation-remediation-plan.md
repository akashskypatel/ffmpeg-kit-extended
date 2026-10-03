# Luna Plan — Flutter Documentation and Public-Comment Remediation

Date: 2026-10-03  
Audience: Luna implementation model  
Repository: `akashskypatel/ffmpeg-kit-extended`  
Branch: `dev-wasm`  
Starting frozen source authority: `1506c49f1eba4cf1d25af3fd8bcc438d039b117a`

## Mission

Bring Flutter user-facing documentation and exported Dartdoc/comments into exact agreement with the already-closed implementation. This is a **documentation/comment remediation**, not a runtime redesign.

The code behavior from the frozen source is authoritative. Do not modify wrapper/native behavior simply because older prose says something different.

The remediation must close these categories:

1. invalid installation/configuration examples;
2. incorrect session-history and queue semantics;
3. incorrect FFplay global lifecycle/control semantics;
4. cross-platform surface examples that are not actually cross-platform;
5. stale FFplayView sizing/platform descriptions;
6. incomplete API signatures and public API coverage;
7. incomplete async error/cancellation guidance;
8. translated factual drift;
9. missing documentation regression contracts.

## Hard boundaries

- Keep native ABI/runtime `0.11.2` frozen.
- Keep `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`.
- Do not edit native ABI sources or exported native symbols.
- Do not modify `flutter/android`, `flutter/ios`, `flutter/macos`, `flutter/linux`, `flutter/windows`, or shared native runtime behavior.
- Do not modify React Native.
- Do not change Dart wrapper semantics to make stale documentation become true.
- Dart source edits are limited to **Dartdoc/comment-only** corrections unless a documentation test seam requires a non-production test helper; no such helper is expected.
- Do not alter `SessionQueueManager`, `FFplayKit`, `FFplayView`, surface, history, or cancellation runtime logic.
- Do not enforce a one-FFplay-session runtime model.
- Do not add a Web `textureId` solely for documentation symmetry.
- Do not change FFplayView sizing behavior as part of this task.
- Do not fetch, rebuild, publish, or replace native artifacts.
- Do not run hosted Flutter/React Native build/test workflows.
- Use semantic production/test/document names. Do not embed audit finding IDs in user-facing docs, test names, or source comments.
- Record any unexpected test/build failures truthfully; do not weaken a contract test to make it green.

## Goal tracker

| Goal | Objective | Primary files | Status |
| --- | --- | --- | --- |
| G1 | Repair canonical installation/configuration documentation and add parse validation | `flutter/README.md`, `flutter/doc/quick-start.md`, documentation test | Pending |
| G2 | Align session history, queue, cancellation, and async-error documentation/comments with code | session API/guide docs, `ffmpeg_kit.dart`, `ffprobe_kit.dart`, `ffplay_kit.dart`, `session_queue_manager.dart` comments | Pending |
| G3 | Correct FFplay lifecycle/control API documentation and signatures | FFplay API/playback docs and Dartdoc | Pending |
| G4 | Make surface/rendering/sizing documentation genuinely cross-platform | video-surface/data-model/video-playback docs, FFplay surface/view Dartdoc | Pending |
| G5 | Complete public API reference coverage, including `FFmpegKitExtended` | API docs/index/config docs | Pending |
| G6 | Synchronize translations and add stable documentation-contract tests | translated READMEs, `flutter/test/**` | Pending |
| G7 | Run documentation-focused validation and final no-runtime-diff audit | Flutter docs/tests/comments only | Pending |

---

# Goal 1 — installation/configuration correctness

## 1.1 Fix the main README Hooks YAML

Target:

- `flutter/README.md`

Replace the malformed block with valid sibling indentation matching the canonical quick-start structure:

```yaml
hooks:
  user_defines:
    ffmpeg_kit_extended_flutter:
      type: "base"
      gpl: true
      small: true
      # windows: "path/to/ffmpeg-kit/libraries"
      # ios: "https://path/to/bundle.xcframework.zip"
```

Do not change configuration semantics.

## 1.2 Normalize bundle-type wording

Source behavior in `flutter/hook/build.dart`:

- supported actual types include `debug`, `base`, `full`, `audio`, `video`, `video_hw`;
- legacy `streaming` is normalized to `video` before validation.

Documentation should say exactly that. Do not present `streaming` as a separate artifact family.

Suggested wording:

> Native bundle types are `debug`, `base`, `full`, `audio`, `video`, and `video_hw`. The legacy `streaming` value is accepted as an alias for `video`.

Keep README and quick-start consistent.

## 1.3 Add a YAML contract test

Add a focused test under `flutter/test/`, e.g. `documentation_contract_test.dart` if no existing semantic doc test is appropriate.

Use the existing `yaml` package dependency.

Test shape:

1. read `README.md` relative to the Flutter package root;
2. locate the canonical fenced YAML block containing `hooks:` and `ffmpeg_kit_extended_flutter:`;
3. parse it with `loadYaml`;
4. assert the parsed map contains:
   - `hooks.user_defines.ffmpeg_kit_extended_flutter.type == 'base'`;
   - `gpl == true` in the example;
   - `small == true` in the example.

Avoid matching every character/whitespace of the README. The test should prove the example is valid YAML and has the intended hierarchy.

## 1.4 Validation for G1

Run:

```text
flutter test test/documentation_contract_test.dart
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
```

If dependency/package graph state prevents `--no-pub`, use the repository's established local package setup, but do not download native runtime artifacts merely for this documentation test.

---

# Goal 2 — session history, queue, cancellation, and async errors

## 2.1 Correct history semantics in convenience Dartdoc

Target Dart files:

- `flutter/lib/src/ffmpeg_kit.dart`
- `flutter/lib/src/ffprobe_kit.dart`
- `flutter/lib/src/ffplay_kit.dart`

Only change comments/Dartdoc.

### FFmpegKit

Change:

> Returns the last executed FFmpeg session.

To a semantic equivalent of:

> Returns the most recently created FFmpeg session retained in session history.

Change:

> Returns all active FFmpeg sessions.

To:

> Returns all retained FFmpeg sessions in session history.

### FFprobeKit / FFplayKit

Apply the same history wording. Do not claim active-only filtering.

## 2.2 Correct API markdown history examples

Targets:

- `flutter/doc/api/ffmpeg-kit.md`
- `flutter/doc/api/ffprobe-kit.md`
- `flutter/doc/api/ffplay-kit.md`
- `flutter/doc/api/sessions.md` as needed

Required points:

- `get*Sessions()` is typed history, not active execution inventory;
- `getLast*Session()` follows retained creation order;
- active asynchronous executions are available from `SessionQueueManager().activeSessions`;
- callers should inspect `getState()` when filtering history;
- `getLastCompletedSession()` is the API for most recent completed/failed history item.

Update examples such as:

```dart
print('Active sessions: ${sessions.length}');
```

so they say history/retained sessions.

## 2.3 Correct `SessionQueueManager.executeSession` Dartdoc

Target:

- `flutter/lib/src/session_queue_manager.dart`

The existing comment says distinct Session objects remain eligible. That is false while a native session ID is reserved.

Required semantic comment:

> Admission is unique by native session ID while queued or active. Re-submitting the same object or another wrapper for the same reserved ID fails without invoking discard cleanup.

Do not change `_containsSession()` or reservation behavior.

## 2.4 Correct queue guide cancellation semantics

Target:

- `flutter/doc/guides/session-queue-management.md`

### `cancelCurrent()`

Document that it attempts **every active session**, not one "most recent" current session.

### `clearQueue()`

Document that it removes all queued items and completes each queued execution Future with `SessionCancelledException` (unless discard cleanup produces another error). Do not say the `clearQueue()` call itself throws one exception per queued session.

### `cancelAll()`

Document:

1. waiting items are removed first;
2. active cancellations are then attempted for every active session;
3. queued execution Futures receive their cancellation/cleanup errors;
4. `cancelAll()` may rethrow the first active-cancellation error after all active targets were attempted.

### `isBusy`

Document exact getter behavior:

> `isBusy` is true while at least one session is active. Check `queueLength` separately for pending work.

Do not change the getter merely to match the previous prose.

## 2.5 Add async error guidance

Targets:

- `flutter/doc/guides/error-handling.md`
- `flutter/doc/quick-start.md` where useful
- `flutter/doc/api/sessions.md` if it improves discoverability

Add a section similar to:

```dart
try {
  final session = await FFmpegKit.executeAsync(command);

  if (ReturnCode.isSuccess(session.getReturnCode())) {
    // Native execution reached successful terminal state.
  } else if (ReturnCode.isCancel(session.getReturnCode())) {
    // Native execution reached a cancelled terminal state.
  }
} on SessionCancelledException catch (e) {
  // Queue/pre-start execution was cancelled before a terminal native result.
} on StateError catch (e) {
  // Initialization, disposed-session, duplicate-admission, or lifecycle error.
} catch (e) {
  // Backend/start/state/cleanup failure propagated by the Future.
}
```

Do not assert that every `StateError` necessarily has only the listed causes; phrase them as common wrapper lifecycle examples.

Explain:

- return codes describe terminal native executions;
- async Future rejection is the error channel for failures before/around terminal execution where no normal session result is returned;
- awaiting the Future remains necessary even when callbacks are installed.

## 2.6 Tests for G2

Extend `documentation_contract_test.dart` with narrow semantic assertions, for example:

- queue guide does not contain the stale comment `Cancel the "current" session (most recent one added to active list)`;
- queue guide contains `every active`/equivalent wording for `cancelCurrent`;
- API pages do not describe `getFFmpegSessions`, `getFFprobeSessions`, or `getFFplaySessions` as "all active";
- the error guide mentions `SessionCancelledException` and `executeAsync` Future errors.

Do not enforce exact paragraphs.

---

# Goal 3 — FFplay lifecycle/control/API semantics

## 3.1 Correct the FFplayKit source comment and Dartdoc

Target:

- `flutter/lib/src/ffplay_kit.dart`

Remove/replace:

```text
Only one FFplay session can be active at a time.
```

The code's actual model is:

- one **current global control owner** (`_activeFFplaySession`);
- potentially multiple `_trackedExecutions` while earlier execution Futures have not settled;
- creating/starting a newer global session changes current ownership but does not implicitly cancel an older tracked execution;
- when the current tracked owner settles, another remaining tracked session may become current.

Use comments that describe this model without exposing unnecessary private implementation details.

## 3.2 Fix FFplay API overview and playback-control guide

Targets:

- `flutter/doc/api/ffplay-kit.md`
- `flutter/doc/guides/playback-control.md`
- related lifecycle text in `flutter/doc/guides/video-playback.md`

Remove claims that:

- only one FFplay execution can be active;
- starting a new one automatically replaces/stops the previous execution;
- FFplay necessarily opens a separate native window;
- `stop()` also closes;
- `close()` is equivalent to Session handle disposal.

Required semantic distinctions:

### Current owner

`FFplayKit` global controls act on the current global session. A newer global session becomes current; this does not itself cancel an older tracked execution.

### stop

`FFplayKit.stop()` delegates to `FFplaySession.stop()` for current playback.

### close

`FFplayKit.close()` delegates to `FFplaySession.close()` for the current session. A tracked execution remains globally owned until its execution Future settles.

### dispose

`Session.dispose()` is the deterministic wrapper/session-handle release API and is distinct from FFplay playback controls.

### start

`FFplayKit.start()` is fire-and-forget for a Created current session; startup errors are logged by the tracked execution path rather than synchronously returned from `start()`. If callers need startup failure propagation, prefer `await FFplayKit.executeAsync(...)`.

Do not overpromise behavior that is not represented in the public API.

## 3.3 Correct FFplay API signatures

Document actual signatures:

```dart
static Future<FFplaySession> executeAsync(
  String command, {
  FFplaySessionCompleteCallback? onComplete,
  FFmpegLogCallback? onLog,
})
```

```dart
static Future<FFplaySession> createSession(
  String command, {
  FFplaySessionCompleteCallback? onComplete,
  FFmpegLogCallback? onLog,
})
```

Add:

```dart
static Future<FFplaySession> createSessionFromArguments(
  List<String> arguments, {
  FFplaySessionCompleteCallback? onComplete,
  FFmpegLogCallback? onLog,
})
```

Provide one example using `onLog` and one using pre-tokenized arguments.

## 3.4 Preserve correct startup/terminal Future distinction

Keep and reinforce the already-correct distinction:

- `FFplayKit.executeAsync()` returns after startup handoff;
- `FFplaySession.executeAsync()` represents the session's queued execution and completes after terminal execution/cleanup;
- `onComplete` is the terminal callback.

Do not accidentally rewrite `FFplayKit.executeAsync()` as a terminal Future while fixing other prose.

## 3.5 FFplay documentation tests

Add semantic assertions that:

- the canonical FFplay API page includes `onLog`;
- it includes `createSessionFromArguments`;
- it does not contain "Only one FFplay session can be active at a time";
- it does not say `stop()` closes the session;
- it distinguishes `dispose()` from FFplay `close()`.

---

# Goal 4 — cross-platform FFplay surface, platform matrix, and sizing

## 4.1 Make `FFplaySurface.toWidget()` the canonical display API

Targets:

- `flutter/doc/api/ffplay-kit.md`
- `flutter/doc/api/video-surface.md`
- `flutter/doc/api/data-models.md`
- any quick-start/readme examples that claim to be cross-platform

Required canonical usage:

```dart
final surface = await FFplaySurface.create();
if (surface == null) {
  // Surface creation failed or target is unsupported.
  return;
}

return surface.toWidget();
```

Do not use `surface.textureId` in cross-platform examples.

## 4.2 Describe platform-specific properties accurately

`FFplaySurface.textureId` exists only in the native conditional implementation. It must not be listed as a property of the shared cross-platform contract.

If documenting `textureId`, document it under native-only lower-level types.

## 4.3 Establish the canonical rendering matrix

Use the actual implementation model:

| Platform | Surface behavior |
| --- | --- |
| Android | SurfaceTexture/ANativeWindow path; `FFplayAndroidSurface` binds to FFplay |
| iOS/macOS | Apple Flutter texture path backed by CVPixelBuffer platform plugin implementation |
| Linux/Windows | Flutter pixel-buffer texture path fed by FFplay frame callbacks |
| Web | Copies RGBA frames from Wasm memory and renders Flutter images via `FFplaySurface.toWidget()` |

Apply this matrix consistently to:

- main README features;
- video playback guide;
- video surface API;
- data model reference;
- architecture user-facing summary where appropriate;
- translated READMEs.

Replace the stale Linux "OpenGL integration" statement.

## 4.4 Correct `FFplayDesktopTexture` Dartdoc

Target:

- `flutter/lib/src/platform/native/ffplay_desktop_texture.dart`

Current `create()` supports Linux, Windows, iOS, and macOS. The class-level Dartdoc currently describes only Linux/Windows C++ behavior.

Rewrite it to separate:

- Linux/Windows frame-callback/pixel-buffer implementation;
- iOS/macOS Apple Flutter texture implementation reached through the same Dart wrapper;
- Android unsupported/null behavior.

Do not imply the C++ desktop implementation is used on Apple.

## 4.5 Correct FFplayView sizing documentation/comments

Targets:

- `flutter/doc/api/video-surface.md`
- `flutter/lib/src/ffplay_view.dart` comment for `videoHeight`

Code authority in `_buildVideo()`:

```text
aspectRatio == null
  -> expand to parent

aspectRatio != null and no source dimensions
  -> AspectRatio(aspectRatio)

aspectRatio != null and source width/height exists
  -> width = finite container max width (or source-derived fallback)
  -> sourceHeight = videoHeight ?? videoWidth / aspectRatio
  -> height = min(width / aspectRatio, sourceHeight)
```

Document this algorithm. Remove "never upscales beyond native dimensions" and width-capped-to-native claims.

Change `videoHeight` Dartdoc from "informational" to language stating it participates in the source-height cap when supplied.

Do **not** change `_buildVideo()`.

## 4.6 Surface/layout documentation tests

Add targeted tests:

- canonical cross-platform docs contain `surface.toWidget()`;
- canonical cross-platform docs do not contain `Texture(textureId: surface.textureId)`;
- video-surface API does not list `textureId` as a universal FFplaySurface property;
- platform matrix includes Android, iOS, macOS, Linux, Windows, Web;
- canonical docs no longer advertise Linux FFplay as an OpenGL-owned texture path.

---

# Goal 5 — public API reference completeness

## 5.1 FFmpegKit argument-list factory

Add `FFmpegKit.createSessionFromArguments(List<String>)` to `api/ffmpeg-kit.md`.

Explain that callers should use this when they already have tokenized arguments and should not manually join/reparse tokens first.

## 5.2 FFprobe log callback signatures

Update `api/ffprobe-kit.md`:

- `executeAsync(..., onLog: ...)`;
- `createSession(..., onLog: ...)`.

Add a short log example.

## 5.3 FFmpegKitConfig utility coverage

Expand `api/config.md` for:

- `logLevelToString(LogLevel)`;
- `sessionStateToString(SessionState)`;
- `messagesInTransmit(int)`.

For callback APIs, say passing `null` deregisters the corresponding global callback where the implementation does so. Avoid the blanket word "enable" as if null has no effect.

## 5.4 Add `FFmpegKitExtended` API page

Create:

- `flutter/doc/api/ffmpeg-kit-extended.md`

Cover public user-relevant sections from the exported class:

### Initialization

- `initialize()`;
- `initialized`;
- initialization StateError contract.

### Session factories

- `createFFmpegSession`;
- `createFFprobeSession`;
- `createFFplaySession`;
- `createMediaInformationSession`.

### Session management/history

- `cancelSession(0)` compatibility meaning;
- `cancelAllSessions`;
- `listSessions` / `getSessions`;
- typed history getters;
- `getSession`;
- `getLastSession`, typed last-session getters;
- `getLastCompletedSession`;
- `clearSessions`.

Internal lifecycle-maintenance helpers such as abandonment/tombstone controls are public in Dart syntax but should be documented cautiously. If they are not intended for end-user use, mark their Dartdoc as advanced/internal lifecycle support rather than advertising them as primary API. Do not hide their existence by making behavior claims that conflict with public export.

### Package/build introspection

Document:

- FFmpeg version/architecture;
- wrapper version/package/bundle;
- GPL/nonfree flags;
- external libraries;
- registered codec/encoder/decoder/muxer/demuxer/filter/protocol/bitstream-filter strings;
- build configuration/date.

### Audio/environment/debug utilities

Document:

- audio output device set/list;
- environment variable;
- signal ignore;
- per-session debug log helpers;
- argument conversion;
- messages-in-transmit.

## 5.5 Update documentation index

Add the Extended API page under API Reference and make it clear when users should choose:

- convenience execution classes (`FFmpegKit`, `FFprobeKit`, `FFplayKit`);
- global configuration (`FFmpegKitConfig`);
- advanced central facade/history/introspection (`FFmpegKitExtended`).

## 5.6 API inventory test

Do not attempt to parse Dart fully.

Create a selected public-contract list in the documentation test for APIs that have historically drifted, e.g.:

```text
FFmpegKit.createSessionFromArguments
FFprobeKit.executeAsync onLog
FFprobeKit.createSession onLog
FFplayKit.executeAsync onLog
FFplayKit.createSession onLog
FFplayKit.createSessionFromArguments
FFmpegKitConfig.logLevelToString
FFmpegKitConfig.sessionStateToString
FFmpegKitConfig.messagesInTransmit
FFmpegKitExtended.getLastCompletedSession
FFmpegKitExtended.getFFmpegArchitecture
FFmpegKitExtended.getRegisteredEncoders
```

Assert their canonical API pages mention them. Keep the list curated and semantic; do not build a fragile regex mirror of every implementation method.

---

# Goal 6 — translation parity and documentation regression coverage

## 6.1 Update English first

Do not translate stale content. Complete G1-G5 English canonical changes before editing translations.

## 6.2 Synchronize seven translated READMEs

Targets:

- `flutter/doc/README.es.md`
- `flutter/doc/README.fr.md`
- `flutter/doc/README.hi.md`
- `flutter/doc/README.ar.md`
- `flutter/doc/README.ja.md`
- `flutter/doc/README.pt-BR.md`
- `flutter/doc/README.zh-CN.md`

Required factual parity:

- Flutter minimum `3.47.0`;
- Dart minimum `3.12.0`;
- supported platforms include Web/Wasm;
- Android architectures: arm/arm64/ia32/x64;
- Linux architectures: arm64/x64;
- Windows architectures: arm64/x64;
- Apple current documented selection behavior;
- `hooks.user_defines.ffmpeg_kit_extended_flutter` is primary configuration;
- legacy config is fallback only;
- Web uses the stable build-hook staging path and cross-origin isolation for pthread builds;
- rendering matrix matches G4;
- Linux is not described as the old OpenGL-owned texture implementation.

Do not translate code keys such as `hooks`, `user_defines`, `ffmpeg_kit_extended_flutter`, `type`, `gpl`, `small`, platform override names, method/class identifiers, architecture tokens, or command-line flags.

## 6.3 Translation parity test

Add a lightweight factual test that reads all translated READMEs and asserts presence of canonical tokens:

- `3.47.0`;
- `3.12.0`;
- `arm64`;
- `x86_64` or the translation's table token that still contains literal architecture names;
- `wasm32`;
- `hooks.user_defines` or literal code tokens `hooks`, `user_defines`;
- `ffmpeg_kit_extended_flutter`.

Also assert the obsolete literal `OpenGL` is not used specifically as the Linux FFplay surface implementation claim. Be careful not to reject legitimate bundle/library feature tables that mention FFmpeg OpenGL support generally. Scope the check to the platform-support/FFplay description section or use nearby text matching.

Do not machine-translate or compare natural-language sentences for equality.

## 6.4 Documentation contract suite structure

Prefer one file such as:

```text
flutter/test/documentation_contract_test.dart
```

Group tests semantically:

- installation YAML is parseable;
- cross-platform FFplay examples use `toWidget`;
- history APIs are not described as active-only;
- FFplay singleton/replacement stale claims are absent;
- queue cancellation wording is aligned;
- selected public API methods/signatures are represented;
- translation factual tokens are synchronized.

Use bounded file reads and targeted regex/substring assertions. Do not snapshot entire Markdown files.

---

# Goal 7 — validation and final documentation-only audit

## 7.1 Format/documentation sanity

Run the package's supported formatting/lint checks for any changed Dart test/comment files:

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
```

If the repository normally formats only changed Dart files, use that narrower command instead of reformatting unrelated source.

Markdown need not be auto-reflowed if that would create noisy unrelated diffs.

## 7.2 Focused tests

Run:

```text
flutter test test/documentation_contract_test.dart
```

Then run relevant existing source-contract tests that overlap documentation facts if inexpensive, such as:

```text
flutter test test/user_defines_config_test.dart
flutter test test/hook_config_test.dart
flutter test test/ffplay_view_fullscreen_test.dart
flutter test test/session_queue_manager_test.dart
flutter test test/session_lifecycle_test.dart
```

Do not weaken existing behavior tests if they expose a documentation assumption as wrong. Update prose to code unless the user separately approves a behavior change.

## 7.3 Full package test policy

Because this task changes comments/docs/tests only, full native platform rebuilds are not required merely for ceremony.

Run the complete Flutter package test suite if the local environment is already configured and doing so does not fetch forbidden remote native artifacts. Record exact pass/fail/skip counts.

Do not run app-hosted native integration tests simply because Markdown changed unless a source/comment change unexpectedly touches runtime code (which should be treated as scope violation).

## 7.4 No-runtime-diff audit

Before closeout, verify `git diff` shows no runtime logic change.

Allowed production-source diffs are Dartdoc/comment-only in the listed Dart files.

Reject/stop if executable statements change in:

- `flutter/lib/src/**`;
- `flutter/hook/**`;
- any native platform directory.

The only executable new code should be documentation tests under `flutter/test/`.

## 7.5 Final audit checklist

Answer from the final source, not intent:

1. Does the main README Hooks YAML parse?
2. Does it represent the actual primary `hooks.user_defines` hierarchy?
3. Are bundle types/aliases consistent with hook behavior?
4. Do cross-platform FFplay examples use `FFplaySurface.toWidget()` rather than native-only `textureId`?
5. Do FFplay docs avoid a false singleton-execution/automatic-replacement claim?
6. Are `stop`, `close`, and `dispose` distinguished?
7. Are typed session getters documented as history rather than active-only lists?
8. Is `getLastFFmpegSession` documented as creation-order history rather than "last executed"?
9. Is `cancelCurrent()` documented as all-active cancellation?
10. Are queued cancellation exceptions described as Future errors rather than synchronous `clearQueue()` throws?
11. Does queue Dartdoc acknowledge duplicate native-ID reservation?
12. Does `isBusy` wording match the active-session getter?
13. Do FFprobe/FFplay API signatures include `onLog`?
14. Are FFmpeg/FFplay argument-list factories documented?
15. Are the missing config utilities documented?
16. Is `FFmpegKitExtended` meaningfully documented and linked from the index?
17. Does FFplayView sizing prose match `_buildVideo()`?
18. Does the platform rendering matrix cover Android, iOS, macOS, Linux, Windows, and Web accurately?
19. Does `FFplayDesktopTexture` Dartdoc acknowledge Apple support?
20. Does async error guidance distinguish Future rejection from terminal return codes?
21. Do all translated README architecture/platform facts match current canonical facts?
22. Are all documentation-contract tests semantic and targeted rather than full-file snapshots?
23. Did no wrapper/native behavior change?
24. Did no native artifact get downloaded, rebuilt, or published for this task?

If any answer is no or uncertain, do not mark documentation remediation complete.

## Definition of done

- [ ] Main README Hooks YAML is valid and tested.
- [ ] Bundle type/alias wording is consistent with hook behavior.
- [ ] FFmpeg/FFprobe/FFplay history query docs match native-layer history semantics.
- [ ] Queue cancellation/admission docs match `SessionQueueManager` behavior.
- [ ] Async error guide covers Future rejection and `SessionCancelledException`.
- [ ] FFplay docs describe current-owner/tracked-execution semantics rather than false singleton replacement.
- [ ] `stop`, `close`, and `dispose` are clearly distinct.
- [ ] FFplay API references include actual callback parameters and argument-list factory.
- [ ] Cross-platform surface examples use `toWidget()` and handle nullable creation.
- [ ] Cross-platform docs do not advertise a universal `FFplaySurface.textureId`.
- [ ] Rendering matrix reflects Android, Apple, Linux/Windows, and Web implementations.
- [ ] FFplayView sizing documentation matches `_buildVideo()`.
- [ ] `FFplayDesktopTexture` Dartdoc reflects Apple support and platform-specific implementation differences.
- [ ] Missing Config helpers are documented.
- [ ] `FFmpegKitExtended` has a discoverable API reference.
- [ ] Translation factual/platform/architecture guidance is synchronized.
- [ ] Documentation-contract tests pass.
- [ ] Relevant existing Flutter tests remain green.
- [ ] Final diff contains no runtime behavior modification.
- [ ] Native ABI/submodule/platform-native code remains untouched.
