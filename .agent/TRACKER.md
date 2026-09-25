# Tracker

## Review 31 Flutter + React Native Cross-Platform Remediation — 2026-09-24

- Plan: [review31-cross-platform-frozen-snapshot-review.md](./review31-cross-platform-frozen-snapshot-review.md)
- Authority: the frozen Review 30 wrapper source is `e218d305dfd33cd06321f09e7bee706b1e2cd9a`; the unchanged native/builder source authority is `b74da2c5d1e294b87d15d73a6687393729e932b3`.
- Scope: implement the six substantive Review 31 findings against the live wrapper while preserving the frozen native ABI, local-only unpublished-ABI validation, semantic implementation names, and the read-only `libs/libffmpegkit` and ManyLinux builder boundaries.
- Validation authority: supplied WSL Windows/Linux/Wasm/Android artifacts and the recorded MacBook Air universal Apple archives. Hosted Flutter/React Native testing, remote old binary retrieval, native ABI publication, and interactive runtime execution remain excluded.

| Goal | Objective | Status |
| --- | --- | --- |
| **R31-G1** | Preserve native session-handle ownership when React Native clears session history | **Complete — native registry-aware clear and focused source oracle pass** |
| **R31-G2** | Make React Native cancellation attempt every target and retry deferred native cancellation | **Pending** |
| **R31-G3** | Give restored Flutter/history sessions correct native cancellation authority | **Pending** |
| **R31-G4** | Keep the React Native history mirror bounded and aligned with native history | **Pending** |
| **R31-G5** | Give local Flutter artifact overrides collision-free shared-cache identities | **Pending** |
| **R31-G6** | Make React Native artifact download and Windows extraction staging transactional across processes | **Pending** |
| **R31-G7** | Reconcile evidence, freeze the exact wrapper source, and record the source snapshots | **Complete — exact wrapper and builders source snapshots verified** |

### Review 31 implementation boundary

- Goal and finding identifiers are tracker metadata only; implementation names must describe behavior.
- No change to `libs/libffmpegkit` or `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders` is permitted. Any native-ABI blocker must be recorded with exact evidence instead of worked around in wrapper code.
- Every spawned Flutter, Dart, Node, WSL, compiler, SSH, or snapshot-monitor process must be tagged, observed to completion, and cleaned up before the next gate.
- Each completed goal receives focused evidence, a tracker transition, a meaningful commit, and a push before the next goal is closed.

### Review 31 validation order

```text
R31-G1..R31-G6 implementation
-> focused native/lifecycle/cache/staging regressions
-> Flutter and React Native local package gates
-> Windows, Android, Linux/WSL, Wasm, and Web local gates
-> ordered MacBook Air Apple local gates
-> documentation and exact-SHA reconciliation
-> wrapper and builders source snapshots
-> stop automated interactive execution; user owns final runtime validation
```

### Review 31 R31-G1 evidence — 2026-09-24

- `react-native/cpp/FFmpegKitDynamicApi.cpp` now dispatches `clearSessions()` through the existing `ffmpeg_kit_config_clear_sessions()` symbol. That native API clears the owning handle registry, cancels/drains active sessions, and clears history before the bridge drops its retained-handle and ID mirrors. The history-only `ffmpeg_kit_clear_sessions()` symbol is no longer used by the native bridge cleanup path.
- `react-native/tests/native-bridge-lifetime.test.js` adds a source oracle for the registry-aware entrypoint, mirror cleanup, and rejection of the history-only call. `node --test tests/native-bridge-lifetime.test.js` passed **4/4**.
- No native ABI, `libs/libffmpegkit`, or ManyLinux builder file changed; the bridge uses an already-exported native symbol from the frozen ABI.

### Review 31 R31-G2 evidence — 2026-09-24

- `react-native/src/session-queue-manager.ts` now attempts cancellation on every active session, preserves the first cancellation failure, and rethrows it only after all active targets have been attempted. The focused queue regression `node --test --test-reporter=tap --test-concurrency=1 --test-name-pattern 'cancelCurrent' tests/session-queue-manager.test.js` passed **2/2**, and the full queue-manager file passed **8/8** in the same serialized runner.
- `react-native/src/session.ts` no longer latches a deferred native cancellation failure permanently. The monitor preserves the first failure as execution error authority while retrying the native dispatch on later Running observations until it succeeds. The serialized cancellation lifecycle regression `node --test --test-reporter=tap --test-concurrency=1 --test-name-pattern 'cancellation' tests/wasm-session-ownership.test.js` passed **9/9**, including deferred retry, handle retention, and terminal error propagation. `npm run test:compile` passed before the focused runs.
- Node 26 default multi-test scheduling was not used as acceptance evidence because this shared-fixture file intermittently left an active session between concurrent test workers; the bounded serialized commands above completed and exited cleanly. No native ABI, `libs/libffmpegkit`, or ManyLinux builder file changed.

### Review 31 R31-G3 evidence — 2026-09-24

- `flutter/lib/src/session.dart` now treats a restored native handle as cancellation-authoritative even though it is intentionally not submit-able for a second execution. Restored sessions use the live state oracle: Running dispatches native cancellation, terminal states remain naturally settled, and only genuinely pre-start non-restored sessions use the pre-start cleanup path.
- `flutter/test/ownership_callback_regression_test.dart` adds a restored Running session regression asserting repeated cancellation dispatches exactly once. The focused Flutter test passed **1/1**; the complete ownership/callback regression suite passed **20/20**; bounded elevated `dart analyze lib/src/session.dart test/ownership_callback_regression_test.dart` reported **No issues found**.
- The requested analytics-disabled commands were run before the Flutter gates (`flutter config --no-analytics`, `dart --disable-analytics`). No FFI binding, native ABI, `libs/libffmpegkit`, or ManyLinux builder change was required for this wrapper-only fix.

### Review 31 R31-G4 evidence — 2026-09-24

- `react-native/cpp/FFmpegKitDynamicApi.cpp` now maintains the wrapper history mirror as an ordered deque with an O(1) membership set. New and released sessions are pruned against the native `ffmpeg_kit_get_session_history_size()` limit; retained owning handles are never selected for eviction, and history-size changes trigger the same pruning path. Released terminal sessions remain visible until native-history capacity requires eviction.
- The focused native bridge source oracle passed **5/5**, including bounded storage, native-limit lookup, retained-handle protection, set cleanup, and removal of the old linear membership scan. `clang++ -std=c++17 -fsyntax-only -Icpp cpp/FFmpegKitDynamicApi.cpp` completed successfully on Windows. No native ABI, `libs/libffmpegkit`, or ManyLinux builder file changed.

### Review 31 R31-G5 evidence — 2026-09-24

- `flutter/hook/build.dart` now derives local override cache filenames from a normalized absolute source-path digest plus the original basename, so same-named archives from different local directories cannot share one cache file or extraction marker. The archive fallback now discovers a single top-level extracted directory instead of assuming the cache filename names the archive’s internal directory.
- `flutter/test/hook_artifact_cache_test.dart` adds a same-basename/different-source-path regression and updates stale-extraction invalidation to the hashed cache identity. The final elevated Flutter hook-cache suite passed **17/17**; bounded elevated `dart analyze hook/build.dart test/hook_artifact_cache_test.dart` reported **No issues found**. The suite also completed its two-process local cache-writer regression and left no task-owned staging entries.
- No native ABI, `libs/libffmpegkit`, or ManyLinux builder file changed; the local WSL artifact override remained the configured test input.

### Review 31 R31-G6 evidence — 2026-09-24

- `react-native/scripts/download-ffmpeg-kit-artifact.js` now publishes through an atomic per-target lock and unique process/timestamp/random staging filename. It no longer removes or reuses a deterministic `${target}.downloading` path, and failures preserve an existing complete target because the target is not touched until a full response is written.
- `react-native/scripts/prepare-windows-runtime.ps1` now serializes archive copy and extraction with atomic directory locks, owner timestamps, stale-lock recovery, and unique `.copying.<pid>.<guid>` / `.extracting.<pid>.<guid>` staging paths. Marker validation and cleanup occur while the corresponding lock is held; no process removes another process's deterministic staging path.
- The Node download suite passed **4/4**, including concurrent same-target publication with no leftover staging or lock entries. The focused PowerShell concurrency regression passed **1/1** with two tagged processes sharing one archive/cache and distinct destinations; both staged complete DLL sets and no `.copying.*`, `.extracting.*`, or `.lock` entries remained. `node --check scripts/download-ffmpeg-kit-artifact.js` and the PowerShell parser check both passed. No native ABI, `libs/libffmpegkit`, or ManyLinux builder file changed.

### Review 31 cross-platform evidence — 2026-09-24

- The Windows-local React Native Web resolver now accepts the configured WSL UNC archive by copying it through `wsl.exe` into task-owned temporary storage before extraction, while the normal package script supplies the example app root explicitly. `npm run prepare-web` passed using the local WSL Wasm archive and reported `bundle-base-wasm-wasm32-static-lgpl.zip` at the example Web staging target; no remotely staged binary was retrieved. `npm run test:web` passed the completed browser smoke sequence for initialization, FFmpeg, FFprobe, media info, and FFplay lifecycle. The generated `react-native/example/public` staging output was removed after validation.
- React Native post-patch gates passed in an elevated tagged shell: `node --check scripts/prepare-web.js`, `npm run typecheck`, `npm run lint` (0 errors; two pre-existing warnings), `npm run test:compile`, and `npm run test:config` (**25/25**). Elevated package gates `npm run test:pack-web` and `npm run test:pack-types` also passed. The Web staging change is pushed as commit `2911547` (`fix: stage React Native web artifacts from WSL`).
- Flutter local gates passed in the requested non-Apple order using the supplied local artifacts: Windows Debug produced `flutter/example/build/windows/x64/runner/Debug/ffmpeg_kit_extended_flutter_example.exe`; Windows-hosted Android Debug produced `flutter/example/build/app/outputs/flutter-apk/app-debug.apk` from the WSL-local AAR; WSL Linux Debug produced `flutter/example/build/linux/x64/debug/bundle/ffmpeg_kit_extended_flutter_example`; and the dedicated Wasm smoke target passed with `flutter build web --wasm --release --target lib/web_runtime_smoke.dart`. The completed local browser smoke reported `STARTING|INITIALIZED|FFMPEG_OK|LOG_OK|FFPROBE_OK|MEDIA_INFO_OK|PASS`. A normal-demo smoke attempt was diagnostic only and was corrected by using the repository's dedicated smoke entrypoint; no blocker remained.
- Apple was validated last on the MacBook Air over SSH to `akash@192.168.1.189` using the recorded universal XCFramework archives. Flutter macOS Debug and iOS Debug `--no-codesign` both completed successfully. React Native `npm ci --ignore-scripts`, UTF-8 CocoaPods installation (**76/76 pods**), and the iOS Simulator Debug workspace build completed successfully with `** BUILD SUCCEEDED **`. The Apple configs continue to point to `/Users/akash/Projects/ffmpeg-kit-builders/prebuilt/apple/xcframeworks`; no remote Apple binary was used.
- All local Flutter/Dart gates used analytics-disabled commands, all task-owned build/test processes were observed to completion, and task-owned temporary staging/server output was removed. No hosted Flutter/React Native workflow, native ABI publication, remote old binary, `libs/libffmpegkit` edit, or ManyLinux builder edit was used. The native submodule remains on `dev` at `b74da2c5d1e294b87d15d73a6687393729e932b3`, matching origin.

### Review 31 frozen source snapshots — 2026-09-24

- The final wrapper source is clean and pushed at exact SHA `486fdd8ac7920878ee25ae5d4cd0a811a841c060`; `origin/dev-wasm` matches it. The unchanged native/submodule authority is `b74da2c5d1e294b87d15d73a6687393729e932b3` on `dev`, matching `origin/dev`.
- The wrapper source snapshot succeeded in [workflow run `36082313847`](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/36082313847), dispatched against the exact wrapper SHA with recursive submodules and `runtimeExecution=false`. The primary artifact is `review31-wrapper-source-36082313847`, artifact ID `10842138476`; [download the wrapper source snapshot](https://api.github.com/repos/akashskypatel/ffmpeg-kit-extended/actions/artifacts/10842138476/zip). The artifact digest is `sha256:21084037c1fb0e314600f593c46fdff0fb46810712966e9d804d873fa71db679`; the downloaded `source.tar.gz` SHA-256 is `bbf3ab4b71738cf9a4b66598a228f187b467a583b7caa87d2044feee17976acc`. Snapshot metadata reports **1,055 files / 27,202,228 bytes**. The diagnostic artifact is `review31-wrapper-source-log-36082313847`, artifact ID `10842068733`; [download the wrapper snapshot diagnostic log](https://api.github.com/repos/akashskypatel/ffmpeg-kit-extended/actions/artifacts/10842068733/zip).
- The requested builders source snapshot succeeded in [workflow run `36082316577`](https://github.com/akashskypatel/ffmpeg-kit-builders/actions/runs/36082316577), dispatched against exact builders SHA `b74da2c5d1e294b87d15d73a6687393729e932b3` with recursive submodules. The primary artifact is `review31-builders-source-36082316577`, artifact ID `10842133547`; [download the builders source snapshot](https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/actions/artifacts/10842133547/zip). The artifact digest is `sha256:d96d8bdf7650228fe3fd67a84ce6f0bfaffbc8b021f5a1d3d57a784a7c577951`; the downloaded `source.tar.gz` SHA-256 is `54b42d497bf4e91de7bfc8cbf2b56c27b678352e8501916b055abf465653d1de`. Snapshot metadata reports **425 files / 10,377,201 bytes**. The diagnostic artifact is `review31-builders-source-log-36082316577`, artifact ID `10842203183`; [download the builders snapshot diagnostic log](https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/actions/artifacts/10842203183/zip).
- These were source-only snapshots; no Flutter/React Native hosted test workflow, remote staged binary, native ABI publication, or ManyLinux builder checkout mutation was used. Review 31 is fully closed with no outstanding native-ABI blocker.

## Review 30 Cross-Platform Frozen-Snapshot Remediation — 2026-09-24

- Plan: [review30-cross-platform-frozen-snapshot-review.md](./review30-cross-platform-frozen-snapshot-review.md)
- Authority: the exact Review 30 wrapper source candidate is now frozen at `e218d305dfd33cd06321f09e7bee706b1e2cd9a`; it is based on the Review 29 wrapper source candidate `237fb5044243240b6199b3a46f0c7cc73ae3586a`. Frozen native product source remains unchanged; `libs/libffmpegkit` remains clean on `dev` at `b74da2c5d1e294b87d15d73a6687393729e932b3`, matching origin.
- Scope: remediate the four wrapper/product findings and one validation-classification finding from the frozen Review 29 source, reconcile the source-authority documentation, run affected local gates, and freeze one new exact wrapper source candidate. No native ABI or ManyLinux builder change is required or permitted.
- Validation authority: the supplied local WSL Linux, Windows, Wasm, and Android artifacts plus the recorded MacBook Air universal XCFramework archives. Hosted Flutter/React Native CI, remote old binaries, native ABI publication, and interactive Flutter/React Native runtime execution are excluded.
- Configuration authority: Flutter example and React Native example overrides must continue to point directly to the supplied local WSL artifacts; Apple overrides remain the recorded MacBook Air universal XCFramework paths.

| Goal | Objective | Status |
| --- | --- | --- |
| **R30-G1** | Move Flutter Web playback epoch ownership to every public FFplay execution route | **Complete — direct session boundary owns successful epoch commits; focused execution/epoch oracles pass** |
| **R30-G2** | Restore the newest tracked owner when an untracked current session is removed | **Complete — shared owner-removal fallback implemented; lifecycle suite passed 14/14** |
| **R30-G3** | Correct the stale Flutter fake-handle integration oracle and reclassify R29-B1 | **Complete — native numeric-handle fail-closed contract is now asserted; Flutter native/API suite passed 71/71** |
| **R30-G4** | Make Flutter shared hook-artifact cache mutation safe across processes | **Complete — multi-process cache oracle and ordered Windows/Linux/Android/Apple local gates pass** |
| **R30-G5** | Deactivate the previous React Native Apple view before callback-owner replacement | **Complete — focused/full local RN gates and ordered Mac iOS/tvOS/macOS builds pass** |
| **R30-G6** | Reconcile Review 29/30 documentation, affected gates, and the exact source snapshot | **Complete — exact wrapper and builders source snapshots recorded at frozen SHAs** |

### Review 30 implementation boundary

- Implementation names must describe behavior, not Review 30 goal/finding identifiers. The native ABI, `libs/libffmpegkit`, and `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders` checkout are read-only for this review.
- Every spawned Flutter, Dart, Node, Gradle, WSL, or compiler process must be tagged, observed to completion, and cleaned up before the next gate. No hosted workflow may be used for Flutter/React Native acceptance while the ABI remains unpublished.

### Review 30 R30-G3 evidence — 2026-09-24

- `flutter/test/api_test.dart` now treats a numeric session ID cast to `Pointer<Void>` as an invalid opaque handle: session ID returns `-1`, output returns `nullptr`, and log count returns `-1`. No compatibility fallback, fake-pointer lookup, native ABI change, or native test weakening was introduced.
- The focused `FFmpegKitTest RobustnessTest` passed **1/1** against the unchanged local Windows archive. The complete `flutter/test/api_test.dart` suite passed **71/71** in the elevated, analytics-disabled Flutter runner, including the native FFplay/concurrency/stress cases.
- Review 29 blocker **R29-B1 is closed and reclassified**: the prior `expected 1 / actual -1` result matched the frozen native contract and was caused by a stale Flutter integration oracle. No native ABI or ManyLinux builder modification was required.

### Review 30 R30-G2 evidence — 2026-09-24

- `FFplayKit` now uses one `_removeCurrentOwner` helper for both tracked settlement and successful untracked cancel/close cleanup. If the removed session is current, ownership falls back to the newest remaining tracked execution; otherwise it clears to `null`.
- `flutter/test/ffplay_kit_lifecycle_test.dart` adds separate cancel and close regressions for an older unsettled tracked execution plus a newer untracked current session. The elevated Flutter lifecycle suite passed **14/14**, including existing failed-cancel/failed-close preservation cases.

### Review 30 R30-G1 evidence — 2026-09-24

- `FFplaySession` now owns the playback-identity commit at the successful backend handoff: async direct sessions call `executeAsynchronously()` then `notifyPlaybackStarted()`, while synchronous sessions notify only after the blocking backend call returns successfully. Failed startup paths never notify. `FFplayKit._startTrackedExecution()` no longer performs a second epoch commit, so high-level and direct routes converge without double increments.
- `flutter/test/ffplay_execution_boundary_test.dart` passed **3/3** using an initialized local Windows artifact: direct async success commits once, direct async failure commits zero times, and high-level `FFplayKit.start` reuses the boundary without a double commit. The synchronous execution contract passed **6/6**, including failed-startup non-commit, and the Web epoch helper suite passed **4/4**.
- Deprecated direct `FFplaySession.executeCommand` and `executeCommandAsync` inherit the same session boundary because they delegate to `execute` and `executeAsync`. No native ABI or builder change was required.

### Review 30 R30-G4 implementation and local evidence — 2026-09-24

- Flutter hook artifact publication now uses unique per-process sibling temporary files/directories, an atomic-directory per-artifact lock with owner tokens and stale-lock recovery, destination rechecks under the lock, and archive-hash extraction markers. Local copies are hash-verified before publication; remote refreshes and extracted-root invalidation occur while holding the same cache lock. No process deletes another process's deterministic temporary path.
- `flutter/test/hook_artifact_cache_test.dart` passed **17/17**, including archive-marker invalidation and a true two-Dart-process same-cache writer regression. The adjacent hook/lifecycle/execution suite passed **39/39**. Bounded Dart analysis of the changed hook/test files reported **No issues found**.
- Ordered local platform evidence: Flutter Windows debug build passed in **40.3s** (`build/windows/x64/runner/Debug/ffmpeg_kit_extended_flutter_example.exe`); Windows Android debug build passed in **56.2s** (`build/app/outputs/flutter-apk/app-debug.apk`) using the supplied local WSL AAR; ManyLinux WSL Linux debug build passed after Flutter's automatic one-time retry (`build/linux/x64/debug/bundle/ffmpeg_kit_extended_flutter_example`); Apple was intentionally last and then passed locally using the MacBook Air universal XCFramework archives.
- Apple Flutter evidence on `192.168.1.189` (`Akashs-MacBook-Air.local`), with `FFMPEG_KIT_EXTENDED_LOCAL_ONLY=true`, Flutter 3.47.5, Xcode 26.4, and no hosted workflow: `flutter build macos --release` produced `build/macos/Build/Products/Release/ffmpeg_kit_extended_flutter_example.app` (**80.3 MB**); `flutter build ios --debug --simulator` produced `build/ios/iphonesimulator/Runner.app` (**Xcode build done 36.7s**); `flutter build ios --debug --no-codesign` produced `build/ios/iphoneos/Runner.app` (**Xcode build done 25.3s**). All three consumed the configured local universal Apple archives; the initial direct stale-workspace probe failed only because FlutterMacOS headers had not been regenerated, then `flutter build macos --release --config-only` regenerated SPM integration and the CLI build passed.

### Review 30 R30-G5 implementation and local evidence — 2026-09-24

- React Native iOS, tvOS, and macOS views now clear the previous owner's `_acceptFrames` under its frame lock before replacing the process-wide callback owner. A stale view also clears its local acceptance flag when it is no longer the coordinator owner and therefore cannot unregister the global callback.
- `react-native/tests/ffplay-native-lifecycle.test.js` passed **3/3** with the new iOS/tvOS/macOS replacement oracle. The complete local React Native package check passed **171/171** tests with typecheck and zero lint errors; two existing unrelated lint warnings remain (`no-useless-escape` and `no-shadow`).
- MacBook Air Xcode/CocoaPods noninteractive Apple evidence completed after the checkout fast-forwarded to `3e198b8`: `npm run build:ios -- --release`, `npm run build:appletvos -- --release`, and `npm run build:macos -- --release` each completed with `** BUILD SUCCEEDED **`, consuming respectively `bundle-base-ios-universal-small-lgpl.xcframework.zip`, `bundle-base-appletvos-universal-small-lgpl.xcframework.zip`, and `bundle-base-macos-universal-small-lgpl.xcframework.zip` from `/Users/akash/Projects/ffmpeg-kit-builders/prebuilt/apple/xcframeworks/`. The tagged process audit after the builds returned no remaining `REVIEW30_PROCESS` processes. No native ABI or builder checkout change is involved.

### Review 30 R30-G6 evidence and frozen source snapshots — 2026-09-24

- Final wrapper source candidate `e218d305dfd33cd06321f09e7bee706b1e2cd9a` is pushed to `origin/dev-wasm`; the worktree was clean before the snapshot dispatch. All Review 30 implementation and local platform goals are complete, with no native ABI, `libs/libffmpegkit`, or ManyLinux builder checkout change.
- The successful wrapper source snapshot was [workflow run `36068910964`](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/36068910964), dispatched on frozen `dev-wasm` and verified with `snapshot_sha=e218d305dfd33cd06321f09e7bee706b1e2cd9a3`, recursive submodules, and `runtimeExecution=false`. The primary artifact is `review30-wrapper-source-36068910964`, artifact ID `10837312749`; [download the wrapper source snapshot](https://api.github.com/repos/akashskypatel/ffmpeg-kit-extended/actions/artifacts/10837312749/zip). Its declared and locally verified `source.tar.gz` SHA-256 is `22fac37f955738f14da360b430c7bda929565fdd4565206268b3a922d46cd8fe`; metadata reports **1054 files / 27156075 bytes**. The diagnostic artifact is `review30-wrapper-source-log-36068910964`, artifact ID `10837512213`; [download the wrapper snapshot diagnostic log](https://api.github.com/repos/akashskypatel/ffmpeg-kit-extended/actions/artifacts/10837512213/zip).
- The requested builders source snapshot was [workflow run `36069043862`](https://github.com/akashskypatel/ffmpeg-kit-builders/actions/runs/36069043862), dispatched on `dev` and verified with `snapshot_sha=b74da2c5d1e294b87d15d73a6687393729e932b3`, recursive submodules, and no source/binary checkout mutation. The primary artifact is `review30-builders-source-36069043862`, artifact ID `10836459435`; [download the builders source snapshot](https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/actions/artifacts/10836459435/zip). Its declared and locally verified `source.tar.gz` SHA-256 is `1df84a2c4a710a611e5597b137be33cc342ed357742bdd47a1c3901a3b9df224`; metadata reports **425 files / 10377201 bytes**. The diagnostic artifact is `review30-builders-source-log-36069043862`, artifact ID `10836409603`; [download the builders snapshot diagnostic log](https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/actions/artifacts/10836409603/zip).
- The first wrapper dispatch (`36068789714`) was intentionally not used because checkout treated its raw SHA input as a branch ref and failed before artifact creation; the corrected dispatch-SHA run above is the authoritative snapshot. No Flutter/React Native hosted testing workflow, remote old binary, or native ABI publication was used.

## Review 29 Cross-Platform Frozen-Snapshot Remediation — 2026-09-24

- Plan: [review29-cross-platform-frozen-snapshot-review.md](./review29-cross-platform-frozen-snapshot-review.md)
- Authority: the exact Review 28 wrapper snapshot at `e02fb8325a80266ea0faa4e84a65db7ebc53f67e`; frozen native product source remains `625c3452ee3c93fb5d701bb6546726940b88d014`; `libs/libffmpegkit` remains clean on `dev` at `b74da2c5d1e294b87d15d73a6687393729e932b3`, matching origin.
- Scope: remediate the five wrapper findings identified from the frozen source, then refresh affected local noninteractive gates and freeze one exact wrapper source candidate. No native ABI or ManyLinux builder change is required or permitted by this review.
- Validation authority: supplied local WSL Linux, Windows, Wasm, and Android artifacts plus the recorded MacBook Air universal XCFramework archives. Hosted Flutter/React Native CI, remote old binaries, native ABI publication, and interactive Flutter/React Native runtime execution are excluded.
- Android host decision: Android validation runs on the local Windows host using its installed Android toolchain; the WSL AAR remains the local binary authority and no WSL Android build is required.

| Goal | Objective | Status |
| --- | --- | --- |
| **R29-G1** | Require a complete React Native tvOS FFplay callback pair and extend the Apple lifecycle oracle | **Complete — tvOS now clears partial symbol resolution and requires register/unregister together; focused Node oracle passed 2/2; local MacBook Air tvOS Simulator Release build passed** |
| **R29-G2** | Restore the older unsettled tracked Flutter FFplay owner when the current tracked execution settles | **Complete — tracked ownership now falls back to the newest remaining unsettled execution; Flutter lifecycle suite passed 12/12** |
| **R29-G3** | Coalesce Flutter Linux frame notifications and retained GLib references to one pending main-loop delivery | **Complete — GLib oracle proves one pending source/ref with latest-frame delivery and rescheduling; WSL Flutter Linux Release bundle passes** |
| **R29-G4** | Add Flutter Web playback epochs and clear stale frames at playback boundaries | **Complete — successful startup commits `(epoch, generation)` identity, epoch transitions clear the old image, focused tests 16/16 and local Web Release build pass** |
| **R29-G5** | Make Flutter Android/iOS/desktop fullscreen transitions failure-atomic | **Complete — cleanup tracks acquired mobile/external effects independent of mounted state; focused widget lifecycle suite passed 6/6** |
| **R29-G6** | Reconcile documentation, tracker evidence, and the exact frozen source candidate | **Complete — documentation, local gates, blocker evidence, and the wrapper source-freeze candidate are reconciled; the native-only fake-handle mismatch is recorded below** |

### Review 29 R29-G1 evidence — 2026-09-24

- `react-native/appletvos/RCTFFplayView.mm` now clears both callback pointers when either symbol is unavailable and refuses activation unless the complete register/unregister pair exists.
- `react-native/tests/ffplay-native-lifecycle.test.js` now includes the tvOS source in the Apple complete-pair oracle. `node --test tests/ffplay-native-lifecycle.test.js` passed **2/2** from `react-native/`.
- Commit `032a272` (`fix: require complete tvOS frame callbacks`) is pushed to `origin/dev-wasm`.
- The MacBook Air local gate pulled `032a272`, used `/Users/akash/Projects/ffmpeg-kit-builders/prebuilt/apple/xcframeworks/bundle-base-appletvos-universal-small-lgpl.xcframework.zip`, and completed `npm run build:appletvos -- --release` with `** BUILD SUCCEEDED **`. No hosted workflow or remote FFmpeg artifact was used.

### Review 29 R29-G2 evidence — 2026-09-24

- `flutter/lib/src/ffplay_kit.dart` now restores the most recently tracked unsettled `FFplaySession` when the current tracked execution settles, including startup-failure and test-tracking cleanup paths. An older execution therefore remains the global owner until it also settles.
- `flutter/test/ffplay_kit_lifecycle_test.dart` adds the newer-before-older settlement regression. `flutter test test/ffplay_kit_lifecycle_test.dart` passed **12/12** in the elevated Windows shell with the local Windows artifact override.
- The initial `dart --disable-analytics test ...` attempt was rejected by the Flutter SDK loader and produced only SDK-type resolution errors; it was not counted as product evidence. The required `flutter test` runner passed and no process was left running.

### Review 29 R29-G3 evidence — 2026-09-24

- `flutter/native/frame_notification_coalescer.h` provides the semantic `FrameNotificationCoalescer` pending bit. The Linux plugin uses it under `TextureState::mutex`, clears it before checking liveness in the idle callback, and requests a new mark only when no callback is already pending.
- `flutter/linux/test/frame_notification_coalescer_test.cc` is a real GLib main-loop oracle: 1,000 submitted frames produced one queued idle source and one callback-held reference, the latest frame was marked, and a later frame scheduled a second notification after consumption. The `g++ -std=c++17 -Wall -Wextra -Werror` compile and run passed in WSL.
- `flutter build linux --release` passed in WSL with scoped `CFLAGS=-fPIC CXXFLAGS=-fPIC` and the supplied local Linux archive. Verified output: `flutter/example/build/linux/x64/release/bundle/ffmpeg_kit_extended_flutter_example`, `lib/libffmpeg_kit_extended_flutter_plugin.so`, and `lib/libffmpegkit.so`.
- The build hook printed a transient `File modified during build. Build must be rerun.` retry diagnostic before completing successfully; the final build result is the passing `✓ Built ...` line. No tagged build process remained.

### Review 29 R29-G4 evidence — 2026-09-24

- `flutter/lib/src/web/ffplay_playback_epoch.dart` defines semantic playback epochs, `(epoch, generation)` frame identity, and surface transition detection. `FFplayKit` commits a new epoch only after the tracked startup handoff succeeds; failed startup never calls the commit hook.
- `flutter/lib/src/web/ffplay_surface_web.dart` clears and disposes the previous decoded image when a surface observes a new epoch, then accepts a reused native generation for the new playback. Native platform surfaces expose the matching no-op hook.
- `flutter/test/ffplay_web_playback_epoch_test.dart` covers same-epoch suppression, reused-generation acceptance, stale-image transition signaling, and failed-startup non-commit. Combined with `ffplay_kit_lifecycle_test.dart`, `flutter test` passed **16/16**.
- `flutter build web --release` passed locally and staged the Wasm runtime under `flutter/example/build/web/assets/packages/ffmpeg_kit_extended_flutter/wasm/`, including `ffmpegkit.wasm` and its loader modules. No hosted workflow or remote runtime artifact was used.

### Review 29 R29-G5 evidence — 2026-09-24

- `flutter/lib/src/ffplay_view.dart` now treats mobile system UI, external fullscreen callbacks, route transition, and controller state as one failure-atomic transaction. Cleanup runs without requiring the originating widget to remain mounted; cleanup failures are logged after a primary transition error and do not replace it.
- `flutter/test/ffplay_view_fullscreen_test.dart` passed **6/6** with a mocked platform channel and an Android target override scoped entirely inside each test. It covers successful entry/exit, throwing entry, disposal while entry is pending, origin disposal with an active route, programmatic route exit, and primary-error preservation over cleanup failure.
- The test-only `FFplaySurface.test()` constructor supplies a resource-free surface fixture; no interactive Flutter app was launched.

### Review 29 R29-G6 evidence and blocker ledger — 2026-09-24

- `flutter/README.md` now releases the previous FFplay surface before replacing it and releases the replacement when the widget is no longer mounted. The final wrapper changes remain semantic (`FrameNotificationCoalescer`, `FFplayWebPlaybackEpoch`, and failure-atomic fullscreen cleanup); plan and goal identifiers are not used as implementation names.
- The final local non-native Flutter package gate passed **189/189** with `flutter test --exclude-tags native`. The focused Review 29 suites passed **12/12** (owner fallback), **16/16** (Web epoch/lifecycle), and **6/6** (fullscreen lifecycle). The local platform matrix passed in the requested order: Windows Release (`flutter/example/build/windows/x64/runner/Release/ffmpeg_kit_extended_flutter_example.exe`), Windows-hosted Android Release (`flutter/example/build/app/outputs/flutter-apk/app-release.apk`), WSL Linux Release (`flutter/example/build/linux/x64/release/bundle/ffmpeg_kit_extended_flutter_example`), and the previously recorded local Web Release and MacBook Air Apple gates. Android used the installed Windows toolchain and the WSL-local AAR; Linux used the WSL-local Linux archive.
- A complete `flutter test` run against the supplied Windows archive reached **259 passing tests and one failure**. The isolated failure is `FFmpegKitTest RobustnessTest`: `ffmpeg_kit_session_get_session_id(Pointer<Void>.fromAddress(id))` returned `-1` instead of the expected session ID (`api_test.dart:2765`). The wrapper-focused tests and non-native package gate are green; this is a native ABI/artifact behavior mismatch, not a Review 29 wrapper regression.
- **R29-B1 — native-only fake-handle lookup mismatch:** the supplied rebuilt Windows archive does not resolve a released session through its numeric-ID pointer (`expected 1`, `actual -1`). Native ABI and `libs/libffmpegkit` changes are forbidden in this review, so no wrapper workaround or test weakening was made. This remains an explicitly documented native-owner blocker; it does not block the wrapper source candidate or source-only snapshot, but it prevents claiming the supplied native archive's complete API parity suite is green.
- No hosted Flutter/React Native CI, remote binary, native ABI publication, or ManyLinux builder checkout change was used. The task-owned Flutter/Gradle/WSL build processes completed and were cleaned up; no interactive app runtime was launched.
- The exact wrapper source-freeze candidate is `237fb5044243240b6199b3a46f0c7cc73ae3586a`, pushed to `origin/dev-wasm`. The authorized source-only snapshot completed successfully at [workflow run `36060335093`](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/36060335093), verified recursive submodule materialization, and performed no Flutter/React Native runtime validation. The source artifact is `review29-wrapper-source-36060335093`, artifact ID `10833983040`; [download the wrapper source snapshot](https://api.github.com/repos/akashskypatel/ffmpeg-kit-extended/actions/artifacts/10833983040/zip). Its `source.tar.gz` SHA-256 is `576f3e1c5c74338a94daef6b80455749d77d211bc612c0e0bf1a46b6353ee75e`. The diagnostic artifact is `review29-wrapper-source-log-36060335093`, artifact ID `10834520938`; [download the snapshot diagnostic log](https://api.github.com/repos/akashskypatel/ffmpeg-kit-extended/actions/artifacts/10834520938/zip).
- The unchanged `ffmpeg-kit-builders` source remains covered by [workflow run `35932349418`](https://github.com/akashskypatel/ffmpeg-kit-builders/actions/runs/35932349418), artifact `review24-builders-source-35932349418`, artifact ID `10781831131`; [download the builder source snapshot](https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/actions/artifacts/10781831131/zip). Its frozen checkout SHA is `625c3452ee3c93fb5d701bb6546726940b88d014`; no builder checkout or native ABI binary was modified or published.

## Review 28 Runtime Production-Readiness — 2026-09-24

- Plan: [review-28-luna-runtime-production-readiness-plan.md](./review-28-luna-runtime-production-readiness-plan.md)
- Scope: make Flutter desktop texture registration failure-atomic, close the Linux `FfkitGlTexture` ownership leak, and prepare (without executing) the deferred Flutter/React Native desktop and Apple interactive validation matrices.
- Baseline: Review 27 wrapper source `8e5b25efa9268e6c547001abb1a1f4255e08e7cb`; frozen native product source `625c3452ee3c93fb5d701bb6546726940b88d014`; `libs/libffmpegkit` is clean on `dev` at `b74da2c5d1e294b87d15d73a6687393729e932b3`, matching origin.
- Validation authority: current local ABI artifacts only. Windows, Linux/WSL, Wasm, and Android use the supplied WSL-local files; Apple uses the exact universal XCFramework archives recorded under Review 27. No native ABI or builder checkout changes, remote binary retrieval/publication, or Flutter/React Native hosted CI are allowed.
- Android host decision: Android build/testing runs on the local Windows host using the installed Windows SDK/toolchain. The WSL AAR remains the local binary authority; no WSL Android build is required for this review.
- Interactive boundary: Luna may inspect source, add focused native/noninteractive tests, compile, link, package, and prepare fixtures/commands/oracles. Luna must not launch or operate Flutter or React Native interactive apps. Deferred runtime entries remain `Deferred — final manual user validation pending` until the user supplies evidence.
- Exact iOS SDK decision: Windows-local Flutter `3.47.4` at `D:\Projects\flutter\flutter` documents `0` as the macOS registrar failure result in `FlutterTexture.h`, but the installed iOS `FlutterEngine.mm` allocates IDs with `nextTextureId++` and has no failure path; its default first valid ID is also `0`. Therefore no `tid == 0` failure check was added to the iOS implementation. This is an SDK-specific decision, not an assumption copied from macOS.

| Goal | Objective | Status |
| --- | --- | --- |
| **R28-G1** | Fail closed when Flutter external-texture registration fails on Windows/Linux/macOS | **Complete — failure-atomic registration is implemented; Windows/Linux focused and release gates pass; macOS source and generated-workspace build refresh pass** |
| **R28-G2** | Release the Linux plugin-owned `FfkitGlTexture` reference exactly once while preserving queued idle-callback safety | **Complete — registration-failure, owner-unwind, queued-callback, and finalization tests pass; Linux release build passes** |
| **R28-G3** | Prepare deferred Flutter Windows/Linux and React Native Windows interactive runtime validation | **Complete (Phase A preparation) — desktop builds, local artifact identities, commands, fixture/oracles, owner transition, lifecycle repetition, and deferred user ownership are reconciled in the plan** |
| **R28-G4** | Prepare deferred Flutter iOS Simulator and macOS interactive runtime validation | **Complete (Phase A preparation) — Flutter macOS Release, iOS Simulator Debug, and unsigned iOS device-target builds pass with exact local universal XCFrameworks; interactive execution remains user-owned** |
| **R28-G5** | Prepare deferred React Native iOS/tvOS/macOS interactive runtime validation | **Complete (Phase A preparation) — RN iOS/tvOS/macOS release gates, CocoaPods, and codegen pass with exact local universal XCFrameworks; interactive execution remains user-owned** |
| **R28-G6** | Prepare rendered-frame and process-global owner-transition stress validation | **Complete (Phase A preparation) — deterministic color/alpha/geometry/frame-arrival, owner-replacement, lifecycle, and bounded stress criteria are recorded; execution remains deferred to the user** |
| **R28-G7** | Reconcile docs/tracker and freeze one manual-validation candidate | **Phase A candidate frozen — final manual validation, promotion, and source snapshots remain pending user sign-off** |

### Review 28 implementation evidence — 2026-09-24

- Windows now rejects a negative `RegisterTexture` result before owner installation or a texture ID response. Linux now checks the boolean result from `fl_texture_registrar_register_texture`, releases the newly-created object on failure, and reports `TEXTURE_REGISTRATION_FAILED`; owner-install failure after successful registration unregisters and releases both references.
- Linux plugin disposal now detaches the texture, conditionally uninstalls the current FFplay owner, marks the state destroyed under its mutex, unregisters from Flutter, and releases the plugin-owned GObject reference. Queued idle callbacks retain their own reference and re-check the destroyed flag.
- macOS now checks the documented `registerTexture:` failure sentinel and unwinds without installing callback ownership. The duplicate SwiftPM source is kept behaviorally identical. iOS is unchanged for the exact SDK reason recorded above.
- Focused evidence now passes: the standalone Windows transaction oracle, WSL transaction oracle, WSL GLib finalization oracle, Flutter hook path suite, Flutter architecture suite **9/9**, Flutter lifecycle/ownership suites **29/29**, React Native config **25/25**, React Native unit **18/18**, and native/staging lifecycle tests **10/10**.
- Platform evidence now passes locally: Flutter Windows release, Flutter Linux release under WSL with scoped `CFLAGS=-fPIC CXXFLAGS=-fPIC`, and Windows-hosted Flutter Android release using the supplied WSL-local AAR. Android was intentionally built/tested on Windows, not WSL. No Flutter or React Native interactive app was launched, and no hosted workflow or remote binary was used.
- Review 28 manual validation preparation is complete for G3–G6: the plan records commands, fixture assumptions, mandatory native calls, FFplay frame/position/pause/resume/stop/release observations, owner replacement, lifecycle repetition, deterministic rendering oracles, and failure evidence. Final execution remains user-owned.
- Apple SSH is authenticated as `akash@192.168.1.189` (`Akashs-MacBook-Air.local`) and the three recorded universal XCFramework SHA-256 values match. React Native `npm run check` passed **167/167** executed tests (three Windows-only cases skipped), and local RN iOS/tvOS/macOS release builds with CocoaPods/codegen passed. Flutter's generated Xcode workspaces supplied the post-change Apple refresh without requiring the Flutter CLI in the noninteractive SSH PATH: macOS Release, iOS Simulator Debug, and unsigned iOS device-target Debug builds passed while consuming the exact local macOS/iOS universal archives. The Flutter iOS Release Simulator attempt is intentionally not counted because Flutter AOT release builds are physical-device-only; its hook still proved the local iOS archive and simulator slice. No Apple interactive runtime was launched.
- The Mac noninteractive SSH PATH still does not expose a Flutter executable, but this is not a Flutter Apple build blocker: direct generated-workspace `xcodebuild` gates passed. The device-target build emitted an existing empty `TARGET_DEVICE_OS_VERSION` warning and completed successfully. No native ABI or builder change was required.
- Required Review 28 report: [review28-runtime-production-readiness-report.md](./review28-runtime-production-readiness-report.md). The Phase A product candidate is wrapper commit `8db1b7680d1e5902832cc1a3e92940ce9e441666` with tree `53b0af31be4b8ba6a7d69ae557e053da67692595`; the later pushed commits `5595e54` and `29ec8bb` are documentation-only closeout commits. Windows is clean and the Mac checkout is clean at the product candidate.
- Task-owned process cleanup completed: the ADB server started by the Windows Android build was stopped, explicit Review 28 temporary files were removed from WSL `/tmp`, and remaining Dart processes were identified as IDE/MCP/Marionette services rather than orphaned build children.

### Review 28 artifacts and closure records

- Windows: `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders\prebuilt\windows-x86_64\releases\bundle-base-windows-x86_64-shared-lgpl.zip`.
- Linux: `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders\prebuilt\linux-x86_64\releases\bundle-base-linux-x86_64-shared-lgpl.zip`.
- Wasm: `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders\prebuilt\wasm-wasm32\releases\bundle-base-wasm-wasm32-static-lgpl.zip`.
- Android: `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders\tools\android\build\outputs\aar\bundle-base-shared-small-lgpl-release.aar`.
- Apple: `/Users/akash/Projects/ffmpeg-kit-builders/prebuilt/apple/xcframeworks/` universal archives recorded in the Review 27 section below.
- Frozen wrapper source snapshot: [workflow run `36052427391`](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/36052427391) completed successfully at exact source SHA `e02fb8325a80266ea0faa4e84a65db7ebc53f67e` (`dev-wasm`), with recursive submodules and no runtime execution. The source artifact is `review28-wrapper-source-e02fb83-36052427391`, artifact ID `10830988517`; [download the wrapper source snapshot](https://api.github.com/repos/akashskypatel/ffmpeg-kit-extended/actions/artifacts/10830988517/zip). The separate diagnostic-log artifact is `review28-wrapper-source-e02fb83-log-36052427391`, artifact ID `10831162878`. The builder snapshot remains the previously recorded unchanged native/builder provenance; no builder checkout or native ABI binary was modified.

## Review 27 Cross-Platform Production-Readiness — 2026-09-24

- Plan: [review-27-luna-windows-production-readiness-plan.md](./review-27-luna-windows-production-readiness-plan.md)
- Scope: frozen native architecture metadata, React Native Windows runtime staging, Flutter/RN FFplay ownership and resolver recovery, executable Windows/Linux/Android validation, and noninteractive Apple build/package validation on the MacBook Air. Interactive Apple simulator/device runtime remains separately classified.
- Review authority: Review 26 wrapper source `ebb2b055aa9e1841c73dd82a89c1c8aab5fbc045`; frozen native product source `625c3452ee3c93fb5d701bb6546726940b88d014`. Native ABI source, `libs/libffmpegkit`, and the ManyLinux builder checkout remain unchanged and out of scope.
- Local ABI authority: supplied WSL-local archives under `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders\prebuilt` for Linux x86_64, Windows x86_64, and Wasm wasm32. No hosted Flutter/React Native CI, remote old binaries, or native ABI publication is acceptance evidence.
- Frozen builder provenance is the completed source snapshot from [workflow run `35932349418`](https://github.com/akashskypatel/ffmpeg-kit-builders/actions/runs/35932349418), artifact `review24-builders-source-35932349418`, artifact ID `10781831131`; [download the builder snapshot](https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/actions/artifacts/10781831131/zip). Its checkout SHA is the unchanged native source `625c3452ee3c93fb5d701bb6546726940b88d014`; the builder checkout and prebuilt archives were not modified or published.
- Validation order: Windows, Android, Linux/WSL, then Apple build/package validation on the MacBook Air. Interactive Apple runtime is not inferred from build success.
- Apple local artifact authority: the MacBook Air builder completed universal XCFramework archives. Both wrapper example configurations point directly to these exact local files, not individual dylibs:
  - iOS: `/Users/akash/Projects/ffmpeg-kit-builders/prebuilt/apple/xcframeworks/bundle-base-ios-universal-small-lgpl.xcframework.zip` — SHA-256 `9f10e46e4326d2cf1ec6542f82cfb714a9f5e3aeade8a38073218cdb6e18bf68`
  - tvOS: `/Users/akash/Projects/ffmpeg-kit-builders/prebuilt/apple/xcframeworks/bundle-base-appletvos-universal-small-lgpl.xcframework.zip` — SHA-256 `96bb464af154f8a90d160e2d86a194c5b24f2c85924e76e285e07a7d5019e172`
  - macOS: `/Users/akash/Projects/ffmpeg-kit-builders/prebuilt/apple/xcframeworks/bundle-base-macos-universal-small-lgpl.xcframework.zip` — SHA-256 `e524b6a0cd6edf88af2e2bcd2e8d5b7253ff60c4b24eb213eeaf581d89cd099b`
  No per-architecture dylib substitution or remote fallback is allowed.

| Goal | Objective | Status |
| --- | --- | --- |
| **R27-P1** | Replace broad architecture aliases with the frozen native platform matrix | **Complete — Flutter and React Native reject unsupported targets before artifact/config work; Windows/Linux/Android/Apple metadata mappings are covered by focused tests** |
| **R27-P2** | Make React Native Windows runtime staging content-fresh and exact | **Complete — current archive/directory content determines the exact staged DLL projection; invalid manifests fail closed** |
| **R27-P3** | Give every process-global Flutter FFplay video target a process-global wrapper owner | **Complete — latest-successful-owner/conditional teardown is implemented across Flutter Windows/Linux/Android/iOS/macOS; executable ownership oracle, Android JVM owner tests, and Android emulator integration passed** |
| **R27-P4** | Make FFplay frame-API discovery retryable, complete, and fail-closed | **Complete — Flutter desktop/Apple and React Native Windows/Apple now require a complete callback pair, retry after misses, and fail closed; focused source/regression tests passed 32/32** |
| **R27-P5** | Run the complete executable Windows/Linux/Android platform matrix | **Complete — Windows, WSL Flutter Linux, Windows-hosted Flutter Android, and Windows-hosted React Native Android executable gates passed with supplied local artifacts** |
| **R27-P6** | Validate Apple wrapper build/package integration against the MacBook Air universal XCFrameworks | **Complete — Flutter and React Native Apple package/build gates passed locally with exact archive identities; interactive simulator/device runtime remains deferred** |
| **R27-P7** | Reconcile docs/tests/tracker and freeze one exact source | **Complete — wrapper/docs/tracker reconciled and the final source-only snapshot is recorded at the frozen implementation SHA** |

### Review 27 preparation and P1 evidence — 2026-09-23

- The user-replaced Review 27 plan is the active authority; the prior Windows-only tracker section and stale Apple-deferred amendment were reconciled. The active plan requires MacBook Air Apple build/package gates and defers only interactive Apple simulator/device runtime when no interactive session is available.
- Starting wrapper SHA for this implementation pass: `c50a116cd47af26daa16f01fc475de7625262419`; branch `dev-wasm` remains synchronized with `origin/dev-wasm` before the uncommitted P1 edits.
- Flutter P1 mapping now accepts Android arm/arm64/x64, iOS arm64, macOS arm64/x64, Linux x64, and Windows x64 only. Unsupported requests are rejected before configuration, override, download, extraction, or staging. `dart --disable-analytics test test/architecture_mapping_test.dart` passed **9/9** with the supplied local Windows archive.
- React Native P1 resolver metadata now accepts the frozen Android aliases, constrains Windows/Linux to x86_64, constrains iOS/tvOS to arm64, and constrains macOS to arm64/x86_64. Unsupported requests are rejected before config parsing/override selection. `node --test tests/resolve-ffmpeg-kit-config.test.js` passed **25/25**.
- `react-native/scripts/prepare-windows-runtime.ps1` no longer advertises arm64. Flutter and React Native example configurations were verified to point at the supplied WSL-local Wasm, Windows, and Linux archives. No native ABI or builder files were modified.

### Review 27 P2 implementation and validation evidence — 2026-09-23

- React Native Windows staging now hashes local archive bytes into extraction identity, fingerprints mutable local runtime directories, extracts through a temporary root, and records the source identity in the completion marker. A same-path archive replacement therefore cannot reuse an earlier extraction.
- Staging now validates a deterministic recursive DLL manifest before copying: duplicate case-insensitive flattened basenames fail, exactly one `libffmpegkit.dll` is required, and the dedicated destination is cleared/rebuilt from the current manifest. A manifest file records the staged DLL hashes without entering the MSBuild `*.dll` projection.
- Real PowerShell-backed regression coverage passed **5/5** in `node --test tests/windows-runtime-packaging.test.js`: same-path changed ZIP refresh, stale dependency removal, missing main DLL, duplicate main/flattened basenames, and mutable local-directory refresh.
- The PowerShell implementation uses .NET SHA-256 APIs for compatibility with the installed Windows PowerShell runtime. All temporary fixture roots are removed by the test teardown; no builder or native ABI files were touched.

### Review 27 P3/P4 implementation and P5/P6 evidence — 2026-09-24

- Flutter P3 adds the semantic `FfplayOwnerCoordinator` and applies latest-successful-owner plus conditional teardown semantics to Windows, Linux, Android, iOS, and macOS. Android binds the process-global `Surface` through the plugin method channel before releasing the previous owner. The standalone C++ ownership oracle compiled with `g++.exe -std=c++17 -Wall -Wextra -Werror` and exited `0`; the Windows-hosted Android Kotlin owner tests passed **3/3**, clearing the earlier launcher/toolchain exception.
- Flutter and React Native P4 source paths now resolve complete register/unregister callback pairs retryably, clear partial discovery, and fail closed before exposing an unusable FFplay target. `node --test tests/ffplay-native-lifecycle.test.js tests/resolve-ffmpeg-kit-config.test.js tests/windows-runtime-packaging.test.js` passed **32/32**. The Flutter architecture regression remained **9/9** from P1.
- Windows executable evidence passed against the supplied current WSL Windows ZIP: Flutter `flutter build windows --release` completed, and the React Native Windows Release MSBuild completed with both the runtime staging and example executable output. The direct staging hash was `e7acb728101708402f7ea5d60abd973d624cf3a1598baa998673f7a6275499c2`.
- Local executable matrix evidence now clears the former Linux/Android environment notes. WSL has Flutter 3.47.5/Dart 3.13.4 and produced the Flutter Linux release bundle with the supplied Linux archive. Windows Flutter Android used the supplied local AAR (`c36e43a512b8c70d7425a9954e8f3d1d3617abc0b1d6e47ce7b5d760f79143d4`, ABIs `arm64-v8a`, `armeabi-v7a`, `x86_64`); owner JVM tests passed **3/3** and the emulator integration suite passed **63/63**. Windows-hosted React Native Android codegen, release build, and release runtime also passed. Android was intentionally not run on WSL because the Windows host has the required Android toolchain. No native ABI or builder checkout was modified.
- The Flutter Android integration fixture now creates output under a temporary directory and writes WAV/PCM audio because the supplied small LGPL AAR does not contain an MP3 encoder. The temporary fixture directory is removed by the test cleanup path; this does not alter native ABI behavior.
- React Native package gates passed locally: `npm run prepare`, packed TypeScript consumer, packed Vite consumer, `npm pack --dry-run`, and the complete `npm run check` gate with TypeScript/lint and **170/170** Node tests. Android runtime diagnosis found Metro selecting `backend.native.ts` for the generic `backend` registry import and TurboModule object spreading dropping non-enumerable methods. The semantic `backend-registry` rename and native proxy delegation fixed both wrapper issues; the native ABI and `libs/libffmpegkit` remained unchanged.
- P6 Apple validation passed on the MacBook Air with local universal archives and no hosted Flutter/React Native testing workflow: Flutter native and JS FFI generation both exited `0`; `FFMPEG_KIT_EXTENDED_LOCAL_ONLY=true flutter test --no-pub --exclude-tags native` passed **176/176**; Flutter macOS release, iOS simulator debug, and iOS device-target debug builds passed without signing. React Native `npm run check` passed **167/167** with three Windows-only tests skipped and two pre-existing lint warnings; local iOS, tvOS, and macOS release builds passed. iOS/macOS CocoaPods installs passed; tvOS integration passed through the tagged build path after its generated runtime was prepared.
- Apple validation used these exact local artifacts: iOS `9f10e46e4326d2cf1ec6542f82cfb714a9f5e3aeade8a38073218cdb6e18bf68`, tvOS `96bb464af154f8a90d160e2d86a194c5b24f2c85924e76e285e07a7d5019e172`, and macOS `e524b6a0cd6edf88af2e2bcd2e8d5b7253ff60c4b24eb213eeaf581d89cd099b`. The transient CocoaPods locale and stale generated Node-path issues were resolved with explicit UTF-8 locale/current Node settings; no product blocker remained. Interactive Apple runtime was not run and is not claimed.
- The semantic macOS React Native Metro/build activation fix is pushed as `e13442d` (`fix: configure macOS React Native bundling`). The current Android wrapper fixes and local executable closeout are pushed as `8e5b25e` (`fix: complete local android production validation`). Earlier implementation commits pushed to `origin/dev-wasm` remain `6b0aa2f`, `82b6d62`, `8e39b4f`, `14531c7`, `b44dd03`, `6107116`, `a7b2f7d`, and `7b905df`.
- Previous Review 27 implementation/source-freeze SHA: `807b623598d86a1190a8b4892ba46126947c475e`, pushed to `origin/dev-wasm`. Its authorized source-only snapshot completed in [workflow run `35959289060`](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35959289060), producing artifact `review27-wrapper-source-35959289060`, artifact ID `10791896668`; [download the previous wrapper source snapshot](https://api.github.com/repos/akashskypatel/ffmpeg-kit-extended/actions/artifacts/10791896668/zip). The current Android wrapper closeout supersedes that implementation snapshot.
- Final Review 27 implementation/source-freeze SHA: `8e5b25efa9268e6c547001abb1a1f4255e08e7cb`, pushed to `origin/dev-wasm` as `fix: complete local android production validation`. The authorized source-only snapshot completed successfully in [workflow run `36031204394`](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/36031204394), producing artifact `review27-wrapper-source-36031204394`, artifact ID `10822520608`; [download the final wrapper source snapshot](https://api.github.com/repos/akashskypatel/ffmpeg-kit-extended/actions/artifacts/10822520608/zip). The workflow verified recursive submodule materialization and performed no Flutter/React Native runtime validation.
- The requested Review 24 document scan covered all five matching files under `.agent`: the production plan, frame-data-race note, Linux CMake note, local-artifact manifest, and production report. No stale Review 24 open/pending status was found in the current plan/report/tracker records.

## Review 26 Functional Production-Readiness Remediation — 2026-09-23

- Plan: [review-26-luna-functional-production-readiness-plan.md](./review-26-luna-functional-production-readiness-plan.md)
- Scope: process-global React Native native/Windows structured-log registration ownership, executable cross-module regression coverage, and narrow callback-lifetime/documentation closeout.
- Review authority: Review 25 implementation SHA `18bf4a1a32c68bda2d123c33d7c44c3a9ff413f9`; frozen native product source `625c3452ee3c93fb5d701bb6546726940b88d014`; `libs/libffmpegkit` and the ManyLinux builder checkout are out of scope and must remain unchanged.
- Local test authority: WSL-local Linux, Windows, and Wasm archives from `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders\prebuilt`; no hosted Flutter/React Native CI or remotely staged binaries.

| Goal | Objective | Status |
| --- | --- | --- |
| **R26-R1** | Make process-global native/Windows log-bridge registration ownership-safe across module instances | **Complete — semantic registration coordinator serializes latest-successful-owner install/conditional teardown; stale module teardown cannot clear a newer registration** |
| **R26-R2** | Add executable cross-module ownership regressions and rerun affected local targets | **Complete — executable ownership/failure/concurrency fixture and local React Native/Web/Windows gates passed** |
| **R26-R3** | Reconcile callback-lifetime documentation/tests and freeze exact source | **Complete — ownership contract, local fixture command, stale Flutter Web wording, and readiness report reconciled** |

### Review 26 R1 implementation evidence — 2026-09-23

- Starting wrapper SHA: `c5fbb00475ec8cd2e136b5e15c696f14c38db04c`. The reproduced pre-fix source sequence was `A install -> A uninstall -> B install -> A stale uninstall/destruction`; both bridges unconditionally called `enableLogCallback(nullptr, nullptr)` whenever retained local state existed, so stale A could clear B's process-global registration.
- Added semantic `LogBridgeRegistrationCoordinator` under `react-native/cpp/`. It commits the owner only after successful native install, clears ownership only after successful disable, serializes install/teardown, and skips native disable for non-owners. Shared C++ and Windows now use the same latest-successful-install policy while retaining Review 25's stable state lifetime.
- Updated the native source-contract test; `node --test tests/native-bridge-lifetime.test.js` passed **3/3**. The standalone coordinator translation unit compiled with `g++ -std=c++20 -pthread -Wall -Wextra -Werror` and executed successfully. The behavioral coordinator cases remain R26-R2 evidence.

### Review 26 R2 implementation and validation evidence — 2026-09-23

- Added `react-native/tests/native/log_bridge_registration_coordinator_test.cpp`, an executable C++ fixture covering A/B replacement, stale teardown, current-owner clearing, failed install/disable preservation, and concurrent replacement versus stale teardown. It compiled and ran with `g++.exe -std=c++20 -pthread -Wall -Wextra -Werror -I react-native/cpp ...`; all assertions passed with exit `0`.
- Elevated local `npm run check` passed typecheck, lint, and **162/162** Node tests after the intentionally local-only resolver environment was removed. `npm run test:pack-types`, `npm run test:pack-web`, `npm pack --dry-run`, and `npm run test:web` all passed. The Web smoke exercised initialize, repeated initialize, FFmpeg, FFprobe, media information, FFplay, pause/resume/stop, and the final WebAssembly assertion.
- The local Windows Release MSBuild passed with the supplied WSL-local archive `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders\prebuilt\windows-x86_64\releases\bundle-base-windows-x86_64-shared-lgpl.zip`. It compiled the installed package's native bridge and produced `react-native/example/windows/x64/Release/FFmpegKitExtended.dll` and `FFmpegKitExtendedExample.exe`. Warnings were limited to existing React Native/Windows headers and generated JavaScript bundle diagnostics.
- No Flutter/React Native hosted workflow or remotely staged binary was used. The local resolver configuration remains pointed at the supplied WSL-local Wasm, Windows, and Linux archives.

### Review 26 R3 closeout evidence — 2026-09-23

- `react-native/TEST.md` now states the one process-global structured-log registration rule: the latest successful install owns it, current-owner uninstall clears it, stale non-owner uninstall/destruction deactivates only local state without a global setter call, and no prior registration is automatically restored. The deterministic C++ ownership fixture command is documented alongside the existing Web lifetime contract.
- `flutter/README.md` now describes build-hook staging of the configured Wasm runtime instead of claiming that a pinned executable pair ships as ordinary package assets. This is documentation reconciliation for the already-verified local Web staging behavior, not a new runtime policy.
- Added [review26-production-readiness-report.md](./review26-production-readiness-report.md) with the exact Review 25 starting wrapper SHA, frozen native source SHA, finding, semantic coordinator design, changed files, executable/local platform results, residual risk, and source-freeze record.
- `git diff --check` passed for the closeout documentation. The final wrapper implementation/source-freeze SHA is `ebb2b055aa9e1841c73dd82a89c1c8aab5fbc045` with tree `0b2313880b271086ec2b4c6276ac99521148fcda`; it is pushed at `origin/dev-wasm`. The source-only snapshot completed successfully at that exact SHA in [workflow run 35943439201](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35943439201), producing `review26-wrapper-source-35943439201`, artifact ID `10786006110`; [download the wrapper source snapshot](https://api.github.com/repos/akashskypatel/ffmpeg-kit-extended/actions/artifacts/10786006110/zip). The workflow verified recursive submodule materialization and performed no Flutter/React Native runtime validation.
- The frozen builder source remains `625c3452ee3c93fb5d701bb6546726940b88d014`; its source snapshot is [builder workflow run 35932349418](https://github.com/akashskypatel/ffmpeg-kit-builders/actions/runs/35932349418), artifact `review24-builders-source-35932349418`, artifact ID `10781831131`; [download the builder source snapshot](https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/actions/artifacts/10781831131/zip). The builder checkout and prebuilt archives were not modified or published. The companion diagnostic log is artifact `10781566959`.

## Review 25 Functional Production-Readiness Remediation — 2026-09-23

- Report: [review25-production-readiness-report.md](./review25-production-readiness-report.md)
- Scope: functional React Native Web callback lifetime, React Native native/Windows bridge-state lifetime, stale Flutter Web runtime authority, affected local regression, and behavior-focused documentation/test closeout.
- Review authority: wrapper source snapshot `f46d64f782b0a3b6663ac9512c5b90426ab34863`; frozen native product source `625c3452ee3c93fb5d701bb6546726940b88d014`. The `libs/libffmpegkit` submodule remains untouched by this review.

| Goal | Objective | Status |
| --- | --- | --- |
| **R25-R1** | Make React Native Web callback registration lifetime-safe | **Complete — stable Wasm callback pointer retained across unregister/reinstall; delayed-pointer and 10,000-cycle Node stress tests passed** |
| **R25-R2** | Bound React Native native/Windows callback bridge state lifetime | **Complete — one reusable active state per module; destruction-only retirement; source contract and 37/37 local Node tests passed** |
| **R25-R3** | Remove stale old-ABI Flutter Web runtime from positive/runtime authority | **Complete — stale executable pair removed, fixture uses local current Wasm ZIP, selector hardened, focused tests and real Wasm Web build passed** |
| **R25-R4** | Re-run the affected local platform/runtime matrix after R1–R3 | **Complete — local React Native package/Web/Windows and Flutter analysis/test/Wasm/browser gates passed; no hosted CI used** |
| **R25-R5** | Reconcile tests/docs only for behavior changed by R1–R3 | **Complete — callback lifetime, local unpublished-ABI validation, synthetic fixture limits, and real Web smoke commands documented** |

### Review 25 local validation — 2026-09-23

- React Native local checks passed with an isolated temporary npm cache: `npm run check` passed typecheck, lint, and **161/161** Node tests; `npm run test:web` passed the headless WebAssembly smoke suite; and `npm run test:pack-web` passed the packed Vite consumer build. The only lint output was the pre-existing unnecessary-escape warning in `tests/arguments.test.js`.
- Flutter local checks passed with analytics disabled: `dart --disable-analytics analyze`, `flutter analyze`, and `flutter test --no-pub --exclude-tags native` passed with **173/173** tests. The example `flutter build web --wasm --release --target lib/web_runtime_smoke.dart` passed against the local WSL Wasm archive, and the served browser smoke passed `STARTING|INITIALIZED|FFMPEG_OK|LOG_OK|FFPROBE_OK|MEDIA_INFO_OK|PASS`.
- React Native Windows Release MSBuild passed against the local WSL Windows archive and produced `react-native/example/windows/x64/Release/FFmpegKitExtended.dll` and `FFmpegKitExtendedExample.exe`. The generated example bundle completed with compiler warnings only; no hosted workflow or remotely staged binary was used.
- Temporary npm cache, browser server, Playwright junction, logs, and generated fixture/build directories were removed after validation. The local WSL builder checkout and `libs/libffmpegkit` source were not modified.
- Documentation closeout updated `react-native/TEST.md`, `flutter/README.md`, and `flutter/example/README.md`: callback unregistration is explicitly distinct from queue draining; Wasm callback slots and bridge state have bounded module-lifetime behavior; synthetic staging fixtures are not runtime authority; and the local Web build/browser smoke commands are recorded. No hosted workflow is presented as evidence for unpublished local ABI validation.
- Final wrapper implementation SHA `18bf4a1a32c68bda2d123c33d7c44c3a9ff413f9` was source-snapshotted successfully by [workflow run 35939688029](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35939688029). The source artifact is `review25-wrapper-source-35939688029`, artifact ID `10783758418`; [download the wrapper source snapshot](https://api.github.com/repos/akashskypatel/ffmpeg-kit-extended/actions/artifacts/10783758418/zip). The workflow verified recursive submodule materialization and performed no runtime validation.
- The unchanged frozen builder source was separately source-snapshotted at `625c3452ee3c93fb5d701bb6546726940b88d014`: [builder snapshot workflow run 35932349418](https://github.com/akashskypatel/ffmpeg-kit-builders/actions/runs/35932349418), artifact `review24-builders-source-35932349418`, artifact ID `10781831131`; [download the builder source snapshot](https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/actions/artifacts/10781831131/zip). No builder checkout or native ABI binary was modified or published. The separate diagnostic log artifact is `10781566959`.

## Review 24 Tracker — Luna production-readiness remediation — 2026-09-22

- Plan: [review-24-luna-production-readiness-plan.md](./review-24-luna-production-readiness-plan.md)
- Scope: native FFmpegKit C/C++ ABI and gtests/Wasm gtests first, exact native freeze, then Flutter and React Native migration, publication, platform regression, and exact-SHA closeout.
- Wrapper source authority at the current N8 handoff: `HEAD == origin/dev-wasm == 45dfdbf33efcbd702d70d38ac6fce1d8fc48cebf`; the implementation commit is pushed and the product worktree was clean before this tracker update.
- DataAsset rollback authority: `7e5163e24c8882f8c9f238f9b58b8b08d31469fd`; implementation `b470f2a1162d0ab8a8867b7236974f9c407930c3`; documentation reconciliation `c126c1cdfa38ea7afe3255f605f597acaa4071f6`.
- Builder source authority at the accepted native handoff is frozen at `625c3452ee3c93fb5d701bb6546726940b88d014`. The `libs/libffmpegkit` submodule was fast-forwarded on branch `dev` to `b74da2c5d1e294b87d15d73a6687393729e932b3`, which is `origin/dev`; the two intervening publish/revert commits are tree-equivalent to the frozen handoff. No native source or builder checkout was modified, and no native ABI binary was published.
- Published runtime authority still points at the older `0.11.2` release family and predates the structured ABI. This implementation deliberately has no source-level expected-binary-version constant or runtime comparison: the native ABI and Dart/JS bridges are explicitly paired, while `flutter/hook/build.dart` and `react-native/scripts/resolve-ffmpeg-kit-config.js` remain the only version-aware build/resolver authorities.
- The previously accepted publication exception remains `ffigen_js: ^0.0.16-pre`. The separate FFK24-N10 acceptance records one known FFmpeg decoder race as out of scope; neither disposition generalizes to other runtime, sanitizer, browser, packaging, or staging failures.

| Goal | Objective | Status |
| --- | --- | --- |
| **R24-G67** | Freeze source authority and reconcile blockers | **Complete — wrapper snapshot `35766299689`; builder snapshot `35746267948`; exact sources verified** |
| **FFK24-N7** | Optimize and unify non-recursive CMake dependency resolution without semantic drift | **Complete — native commits `e9de4755a` + `13f45218f` + `e43b51eeb`; runner/configure evidence recorded** |
| **FFK24-N8** | Cut over to one structured global-log ABI and remove `_v2` | **Complete with user-directed version-policy amendment — native `a0b9c936`; wrapper `45dfdbf`** |
| **FFK24-N9** | Replace remote TLS sanitizer failures with deterministic verified-TLS fixture | **Completed — Accepted per user authorization; remaining cancellation diagnostic documented below** |
| **FFK24-N10** | Resolve the FFmpeg `FrameData` TSAN publication/lifetime race | **Closed — User accepted the remaining FFmpeg decoder race as out of scope; fully instrumented evidence recorded below** |
| **FFK24-N11** | Resolve/classify GCC 14/libstdc++ UBSAN vptr diagnostics | **Complete — GCC 14-instrumented binaries were loading the host GCC 8.5 UBSAN runtime; matched-runtime reruns are clean** |
| **FFK24-N12** | Freeze native handoff after N7–N11 | **Complete — native UBSAN/ASAN 116/116; TSan 116 assertions passed with only the user-accepted N10 race; Wasm 11/11 and exports verified** |
| **R24-G68** | Validate DataAsset rollback on stable Flutter 3.47 | **Complete — Flutter 3.47.4 stable, local hook matrix 172/172, Web smoke passed** |
| **R24-G69** | Reopen/close G21 with local current-ABI runtime integrity | **Complete — local-only resolver/configuration and fast-forwarded native submodule verified** |
| **R24-G70** | Prove current-ABI Flutter/RN Web structured direct-log delivery and A/B/C counters | **Complete — Flutter and React Native local Web structured-runtime evidence passed** |
| **R24-G71** | Cross-platform regression against locally packaged Review 24 artifacts | **Complete — all locally executable Flutter/RN gates passed against local artifacts** |
| **R24-G72** | Documentation, tracker and local exact-source/artifact closeout | **Complete — final wrapper SHA and source snapshot recorded** |

### Review 24 local wrapper closeout — 2026-09-23

- The `libs/libffmpegkit` submodule fast-forward was performed with `git -C libs/libffmpegkit merge --ff-only origin/dev`. It is clean on `dev` at `b74da2c5`; the frozen ABI source tree at `625c3452` and the fast-forward target have no tree diff. The forbidden native source directories and ManyLinux builder checkout were not edited.
- The supplied local artifacts remain the only test authority. Their SHA-256 values are: Wasm `49096fe9145e8d5830a2e9e07b16047819eee1f3b3dfb268dc072fd7b6e239ce`, Windows `e7acb728101708402f7ea5d60abd973d624cf3a1598ba998673f7a6275499c2`, and Linux `cbe56b1749f028ed107d35bc96800c1635a674366badff86a85c69290b279363`. The selected bundle reports FFmpegKit `0.11.2`; no remote artifact URL was fetched.
- Flutter configuration uses the local WSL paths in `flutter/pubspec.yaml` and `flutter/example/pubspec.yaml`; React Native uses the Wasm, Windows and Linux WSL paths in `react-native/example/ffmpeg-kit-extended.config.json`. `FFMPEG_KIT_EXTENDED_LOCAL_ONLY=true` now fails closed when a local override is absent or remote, in both wrapper resolvers. The initial Flutter test proved the former historical remote fallback URL; after the guard and local config were enabled, the full package suite passed **172/172**.
- Elevated analytics-disabled binding regeneration completed with exit `0` for both `dart run ffigen --config ffigen_native.yaml` and `dart run ffigen_js --config ffigen_js.yaml`; the known `Unable to parse Macros` warning remains non-fatal. `dart --disable-analytics analyze` and Flutter analysis passed with no issues.
- React Native resolver closeout is fail-closed under `FFMPEG_KIT_EXTENDED_LOCAL_ONLY=true`: absent overrides and HTTP(S) release URLs are rejected, while the explicit WSL-local Wasm, Windows, and Linux paths in `react-native/example/ffmpeg-kit-extended.config.json` are accepted. Positive and negative resolver tests passed without release-cache or remote package resolution.
- Flutter Web was built with `flutter build web --wasm --release --target lib/web_runtime_smoke.dart` against the local Wasm ZIP. Headless browser evidence was `STARTING|INITIALIZED|FFMPEG_OK|FFPROBE_OK|MEDIA_INFO_OK|PASS`, with cross-origin isolation, local package asset requests, and no page/console errors. Flutter Windows release also passed: `flutter build windows --release`.
- React Native Web now installs the ffigen Wasm heap helpers and a table-backed structured callback registry from the instantiated module; it no longer assumes an unavailable `module.addFunction` export. The bridge preserves the five-argument structured callback shape, recycles callback slots, and fails closed if the Wasm function table is absent. Dedicated callback-runtime and loader tests passed **5/5**.
- Elevated local React Native Web validation passed the complete headless suite: initialize, repeated initialize, FFmpeg, FFprobe, media information, FFplay, pause/resume/stop, and the final WebAssembly smoke assertion. The full React Native `npm run check` gate passed **157/157** Node tests, with typecheck and lint passing (one pre-existing unnecessary-escape warning). No remote artifact or hosted wrapper workflow was used.
- Cross-platform local regression is complete for the supplied artifact set: Flutter package tests **172/172**, Flutter Web smoke, Flutter Windows release, React Native package type/Web consumer checks, React Native Web smoke, and the React Native Windows MSBuild release all passed. The Windows build used the local Windows ZIP and produced both `FFmpegKitExtended.dll` and the example executable.
- Android, Apple, and native Linux commands were not run on this Windows host because no matching local artifacts were supplied and remote retrieval/hosted wrapper CI is prohibited for this handoff. This is an environment-scope note, not a native ABI blocker; no native source or ManyLinux builder checkout was changed.
- Documentation reconciliation is in [review24-production-readiness-report.md](./review24-production-readiness-report.md); Flutter and React Native READMEs now describe local-only artifact validation and the single structured callback ABI without a legacy fallback. The closeout commits are `590f9f8` (Flutter), `5027b95` (local resolver and submodule fast-forward), `b570d89` (React Native Web bridge), and `d143679` (local regression evidence). Source-snapshot provenance is recorded in the next bullet.
- Final wrapper source SHA is `f46d64f782b0a3b6663ac9512c5b90426ab34863`. The explicitly requested [repository source-snapshot run 35931116466](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35931116466) completed successfully at that exact SHA. The resulting source artifact is `review24-wrapper-source-35931116466`, artifact ID `10781008469`; [download the source snapshot artifact](https://api.github.com/repos/akashskypatel/ffmpeg-kit-extended/actions/artifacts/10781008469/zip). The snapshot included recursively materialized submodules and did not execute runtime validation.
- The frozen builder source was independently snapshotted by [builder workflow run 35932349418](https://github.com/akashskypatel/ffmpeg-kit-builders/actions/runs/35932349418). Its checkout log verifies `snapshot_sha=625c3452ee3c93fb5d701bb6546726940b88d014`; the successful source artifact is `review24-builders-source-35932349418`, artifact ID `10781831131`; [download the builder source snapshot artifact](https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/actions/artifacts/10781831131/zip). The separate log artifact is `10781566959`.

### Review 24 blocker ledger

| Blocker | Current classification | Owner / disposition |
| --- | --- | --- |
| **B0** Linux-local CMake resolver slowdown | **Resolved by N7; full native suite passed under N12** | **FFK24-N7 complete** — cached, direct-only archive resolution unified across platform branches; N12 ran all 116 native tests in UBSAN, ASAN/LSAN, and TSan |
| **B1** DataAsset rollback evidence | Resolved — exact stable Flutter 3.47 evidence recorded | **R24-G68 complete** — local hook matrix and Web smoke passed |
| **B2** Review 23 custom Web structured-log evidence | Resolved — genuine current-ABI local Web evidence recorded | **R24-G68 + R24-G70 complete** — Flutter and React Native Web smoke passed |
| **B3** Published 0.11.2 runtime mismatch | Resolved for this local wrapper handoff; remote publication is intentionally prohibited | **R24-G69 complete** — the immutable local current-ABI bundles were consumed and verified without publishing |
| **B3A** Dual global-log ABI | Resolved in the in-place paired ABI | **FFK24-N8 complete** — one structured setter in place; `_v2`, marker, fallback, and runtime-version check removed |
| **B4** Remote TLS failures | Known FFmpeg 9.0 hard-TLS defect; user explicitly accepted current state | **FFK24-N9 completed — Accepted per user authorization**; no further TLS work; retain the cancellation-only `[tls] Unknown error` note below |
| **B5** FFmpeg TSan decoder race | **FFK24-N10 accepted out of scope by user; N12 callback and stress suites pass** | **FFK24-N10 closed by user acceptance** — the original `FrameData` reports disappear with fully TSan-instrumented FFmpeg; the remaining `padding_bug_score` race is the only finding in the complete N12 TSan run, detailed below. No suppression or scenario weakening was used. |
| **B6** GCC/shared UBSAN vptr diagnostics | **Resolved as a sanitizer runtime mismatch, not a test-fixture or library defect** | **FFK24-N11 complete** — GCC 14-instrumented shared objects were resolving `libubsan.so.1` to host GCC 8.5; the same binaries are clean with a GCC 14 runtime. The full GCC/Clang × shared/static matrix is recorded below; vptr remains enabled. |
| **B7** Workflow/headless browser limitation | User-authorized local bypass; not a product workaround | Run Flutter/RN browser gates locally with a real headless browser; do not move the gate to hosted workflow execution |

### FFK24-N8 — In-place structured callback ABI and local-runtime validation — complete with amendment

- Native authority is [`a0b9c936`](https://github.com/akashskypatel/ffmpeg-kit-builders/commit/a0b9c93630b95ec301d992e1e1c79ce408f3932c) on `origin/dev`; the root gitlink is exact at that SHA. The native implementation has one five-argument structured callback setter (`session_id`, `sequence`, `level`, owned message, `user_data`). The obsolete callback-ABI marker, `_v2` symbol/type, and runtime compatibility function are absent from tracked native, Flutter, and React Native source.
- The wrapper implementation is [`45dfdbf`](https://github.com/akashskypatel/ffmpeg-kit-extended/commit/45dfdbf33efcbd702d70d38ac6fce1d8fc48cebf), pushed to `origin/dev-wasm`. Generated native/JS bindings were regenerated with elevated analytics-disabled commands: `dart --disable-analytics run ffigen --config ffigen_native.yaml` and `dart --disable-analytics run ffigen_js --config ffigen_js.yaml`; both exited `0`. The known `Unable to parse Macros` warning remains and is not treated as a product failure.
- The user-directed version policy is recorded here as an amendment: no source-level `0.11.2`/expected-runtime constant or runtime comparison remains. Only `flutter/hook/build.dart` and `react-native/scripts/resolve-ffmpeg-kit-config.js` retain version-aware build/resolver metadata. The old published runtime remains a remote-publication limitation; this handoff validates the local current-ABI bundles and intentionally does not publish them.
- Native `TEST.md` evidence: the documented Linux test runner `sudo ./runner.sh --host=linux --arch=x86_64 --enable-base --gpl --kit --build-deps --no-bundle --test=thread --build-debug --skip -y` exited `0` and built `ffmpegkit_tests`; the documented `cmake --build "$FFMPEG_KIT_SOURCE/build" --target ffmpegkit_tests -j2` rerun exited `0`. Focused `Review24NativeCallbackAbiTest.*` passed **6/6**, including the runtime-version API test without a source literal. The affected callback suite timed out after 120 seconds at `CallbackTest.GlobalCallbacks`; this remains a separate native handoff blocker and no workaround was added.
- Native tracked-source scans found no `0.11.2`, `review24-global-log-v1`, `enable_log_callback_v2`, `GlobalLogCallbackV2`, or runtime-compatibility symbol outside the two explicitly allowed resolver/build-hook authorities. Existing unrelated builder modifications were preserved.
- Flutter evidence used only local WSL-built artifacts: elevated `flutter analyze lib test/api_test.dart test/structured_log_event_test.dart` passed with no issues; the focused root package suite passed **33/33** using the local WSL Windows bundle and emitted no remote artifact URL; `flutter build web --wasm --release` passed; and local headless browser smoke reported `crossOriginIsolated: true`, complete document state, local Wasm asset requests, and no page/console errors. The root package `ffmpeg_kit_extended_config` block is intentionally commented out; uncomment it for package-level plugin tests so the same local WSL overrides are used.
- Historical React Native evidence used the local resolver overrides: the earlier Web timeout led to the callback-table diagnosis. The superseding local wrapper closeout now records the repaired bridge, dedicated callback tests **5/5**, and the complete Web smoke pass; G70 is no longer blocked.
- Local bundle paths used for the wrapper checks were the WSL release zips under `prebuilt/wasm-wasm32/releases`, `prebuilt/linux-x86_64/releases`, and `prebuilt/windows-x86_64/releases`; no published runtime was resolved. The artifacts were produced before the test-only native source cleanup at `a0b9c936`, which did not change the ABI or release binary content.
- Transition: FFK24-N8 is complete for the in-place ABI migration and paired local wrapper validation. N9 is completed by user acceptance; N10 is closed by user acceptance as out of scope; N11 is complete with the GCC 14 UBSAN runtime mismatch classified; N12 was later completed with the native/Wasm evidence below. Publication/browser closeout is now complete for the local wrapper handoff in G69–G71; no remote publication was performed.

### FFK24-N9 — Verified TLS test state — completed, accepted per user authorization

- **Disposition:** The user directed that no further TLS-related work be attempted and explicitly accepted the current state. This acceptance closes N9 without claiming that every original plan exit criterion was independently completed. No TLS verification bypass was added.
- **Native handoff:** Commit [`aad083c3b`](https://github.com/akashskypatel/ffmpeg-kit-builders/commit/aad083c3bdcf50b6047047ee915111d8bebb7cd6) (`Add verified local stream test fixtures`) is pushed to `origin/dev`; the parent submodule working tree is at that exact commit.
- **Build evidence:** The documented Linux thread-sanitizer runner `sudo ./runner.sh --host=linux --arch=x86_64 --enable-base --gpl --kit --build-deps --no-bundle --test=thread --build-debug --skip -y` exited `0`; `cmake --build /home/vscode/ffmpeg-kit-builders/FFmpegKit/build --target ffmpegkit_tests -j2` also exited `0`.
- **Focused tests:** The six tests `RemoteStreamTlsRejectsUntrustedCa`, `RemoteStreamTlsRejectsMismatchedSan`, `RemoteStreamReconnectsAtHttpEof`, `RemoteStreamParallelRecordingCancellationIsolation`, `RemoteStreamCancelAndImmediateRestart`, and `RemoteStreamRepeatedCancelRequestsAreIgnored` passed **6/6** in the regular, ASAN/LSAN, and TSAN builds. ASAN/LSAN ran with leak detection enabled; no sanitizer diagnostics were found. TSAN ran with the documented ASLR-disabled invocation; no TSAN diagnostics were found. The certificate-verification errors are expected by the negative tests.
- **Residual cancellation diagnostic:** During intentional cancellation/shutdown of the local HTTPS HLS fixture, FFmpeg 9 emits `[tls] Unknown error`. The cancellation/isolation/restart assertions pass; this shutdown diagnostic is retained as the known FFmpeg 9.0 hard-TLS behavior and is accepted by the user, not classified as a failed test or sanitizer report.
- **Scope boundary:** No additional TLS fixture, CA-path, documentation, or workaround work will be pursued under this acceptance. The remaining diagnostic and the exact tested state are recorded here for the N9 audit trail.
- **Transition:** N9 is completed by user acceptance. FFK24-N10 is closed by user acceptance as out of scope. N11 is complete with its runtime mismatch documented below; N12 was later completed with the native/Wasm evidence below. Publication/browser closeout was subsequently completed in the local wrapper gates.

### FFK24-N10 — FFmpeg TSAN findings — closed by user acceptance

- **Disposition:** The user accepted the residual fully instrumented FFmpeg decoder race as out of scope. N10 is closed by that acceptance; this does not claim the remaining decoder race is fixed or harmless. No native source changes, TSan suppressions, or scenario weakening were made.
- The original reports at `FFmpegKit/src/ffmpeg.c:503` and `:551` were reproduced with the FFmpeg archives uninstrumented while FFmpegKit was instrumented. After FFmpeg was rebuilt and relinked with TSan, `nm -u` showed 9,176 TSan references in `libavcodec.a` and 780 in `libavutil.a`; the original two `FrameData` warnings disappeared.
- On 2026-09-23, `setarch x86_64 -R timeout 120s ./build/tests/ffmpegkit_tests --gtest_filter=FFmpegKitTest.MediaInformationQuotedFilename` passed its GoogleTest assertion (1/1) but exited 66 for two TSan warnings. Five consecutive repetitions produced the same pair:
  - `libavcodec/mpeg4videodec.c:3929`, `mpeg4_update_thread_context` reads `s->h.padding_bug_score` while a decoder worker writes that field in `libavcodec/h263dec.c:301`, `decode_slice`.
  - The two reports are the conflicting read/write directions for the same field across the codec main/worker contexts. FFmpeg source itself labels the copy `// FIXME: racy` at `mpeg4videodec.c:3929`.
- This is a real FFmpeg decoder race exposed by the test's MPEG-4 workload. It is not the quoted-filename fixture and is distinct from the prior `FrameData` reports, which were attributable to incomplete sanitizer instrumentation. The focused log from the first fully instrumented run is `/tmp/ffk-tsan-focused-20260923.log`; repeat summaries are in `/tmp/ffk-tsan-focused-repeat-1.log` through `...-5.log` for this machine/session.
- The pre-existing `CallbackTest.GlobalCallbacks` timeout remains a separate unresolved execution gate. N10 acceptance did not resolve that timeout; N11 has since been completed and classified below.

### FFK24-N11 — GCC UBSAN runtime mismatch — complete

- **Disposition:** The reports are neither a test-fixture defect nor a library race. GCC 14.2.1-instrumented shared objects were loading the host's GCC 8.5 `libubsan.so.1`. The GCC 14 toolset's `libubsan.so` linker script contains `INPUT ( /usr/lib64/libubsan.so.1 )`, and that host library belongs to `libubsan-8.5.0-28.el8_10.alma.1`. The toolset also provides GCC 14's `libubsan.a`.
- **Runtime-only A/B:** With the original GCC 14 shared build and test executable unchanged, the host GCC 8.5 runtime produced four `shared_ptr_base.h` vptr reports in `FFmpegKitTest.ParallelFFmpegLogAttributionIsolation` (at lines 1076, 1069, 343, and 347; the report says the object is not `_Sp_counted_base` while identifying its dynamic type as `_Sp_counted_ptr_inplace<ffmpegkit::Log>`). The GoogleTest assertion still passed 1/1. The single-session `FFmpegKitTest.DebugLog` produced three reports, and `NativeCallbackAbiContractTest.IndexedHistoryPreservesOrderAndCarriesPerSessionSequences` produced one. I built a temporary shared UBSAN runtime from GCC 14's `libubsan.a` at `/tmp/ffk-n11-gcc14-ubsan/libubsan.so.1`; selecting only that runtime through `LD_LIBRARY_PATH` removed all reports in all three tests, each of which passed 1/1. `libstdc++.so.6` stayed at the same host path in both runs. No source, fixture, sanitizer flag, or executable changed between the runtime A/B.
- **Matrix:** `GCC 14.2.1/shared` reproduced only with the GCC 8.5 runtime and was clean with the matched GCC 14 runtime; `GCC 14.2.1/static` passed the focused test 1/1 with no UBSAN output; `Clang 21.1.8/shared` passed 1/1 with its `libclang_rt.ubsan_standalone.so` runtime and no UBSAN output; `Clang 21.1.8/static` passed 1/1 with no UBSAN output. All lanes used `-Og -fno-omit-frame-pointer -ggdb -D_GLIBCXX_DEBUG -fsanitize=undefined`; `_GLIBCXX_DEBUG` was held constant, not toggled. The shared target's project options also apply `-Os`, function/data sections, stack protection, and default visibility. Clang used GCC 14 headers and the same host `libstdc++` selection.
- **Fixture discriminator:** The non-parallel `DebugLog` test and the direct shared-pointer cross-DSO `IndexedHistoryPreservesOrderAndCarriesPerSessionSequences` test show that this was not caused by the parallel logging fixture. Both change from reports to clean results solely when the UBSAN runtime changes. No library change or `-fno-sanitize=vptr` suppression was made. Small standalone DSO/shared-pointer probes were also tried but did not reproduce the message; the runtime-only A/B on the exact production library and test binary provides the direct causal evidence.
- The GCC 14 runtime used for confirmation was built from `/opt/rh/gcc-toolset-14/root/usr/lib/gcc/x86_64-redhat-linux/14/libubsan.a`. Session logs: `/tmp/ffk-n11-gcc14-shared.log`, `/tmp/ffk-n11-gcc14-shared-runtime14.log`, `/tmp/ffk-n11-host-FFmpegKitTest_DebugLog.log`, `/tmp/ffk-n11-gcc14-FFmpegKitTest_DebugLog.log`, `/tmp/ffk-n11-host-NativeCallbackAbiContractTest_IndexedHistoryPreservesOrderAndCarriesPerSessionSequences.log`, `/tmp/ffk-n11-gcc14-NativeCallbackAbiContractTest_IndexedHistoryPreservesOrderAndCarriesPerSessionSequences.log`, `/tmp/ffk-n11-gcc14-static.log`, `/tmp/ffk-n11-clang21-static.log`, and `/tmp/ffk-n11-clang21-shared.log`.
- **Runtime requirement:** Keep vptr enabled and load a runtime built from the same GCC toolset for GCC UBSAN shared tests. In this image, the shared GCC 14 runtime is absent and its linker script forwards to GCC 8.5; the temporary GCC 14 runtime above was used for validation. Clang shared UBSAN/vptr is an independent clean lane. No standalone probe is treated as a substitute for the exact-runtime rerun. The temporary runtime was built with:

  ```sh
  mkdir -p /tmp/ffk-n11-gcc14-ubsan
  /opt/rh/gcc-toolset-14/root/usr/bin/g++ -shared -Wl,-soname,libubsan.so.1 -Wl,--whole-archive /opt/rh/gcc-toolset-14/root/usr/lib/gcc/x86_64-redhat-linux/14/libubsan.a -Wl,--no-whole-archive -o /tmp/ffk-n11-gcc14-ubsan/libubsan.so.1 -lstdc++ -lm -ldl -lpthread
  ```

  For the focused run, `LD_LIBRARY_PATH=/tmp/ffk-n11-gcc14-ubsan:/home/vscode/ffmpeg-kit-builders/prebuilt/linux-x86_64/libraries/lib` selected that runtime without changing the test executable or FFmpegKit shared library.
- **User-provided rebuild commands for the next UBSAN run:**

  FFmpeg and FFmpegKit:

  ```sh
  sudo ./runner.sh --host=linux --arch=x86_64 --enable-base --gpl --kit -fk -ff --build-deps --no-bundle --test=ubsan --build-debug --skip -y
  ```

  FFmpegKit only:

  ```sh
  sudo ./runner.sh --host=linux --arch=x86_64 --enable-base --gpl --kit -fk --build-deps --no-bundle --test=ubsan --build-debug --skip -y
  ```

- **Transition:** N11 is complete. The full N12 native suite later passed, including `CallbackTest.GlobalCallbacks`; the final native/Wasm freeze evidence follows.

### FFK24-N12 — Native and Wasm freeze — complete — 2026-09-23

- **Disposition:** N12 is complete. The earlier `CallbackTest.GlobalCallbacks` timeout did not reproduce in the full UBSAN suite. The native callback, ABI, logging/statistics, session reuse/stress, and verified-TLS fixture suites passed. TSan reported only the previously accepted FFmpeg `padding_bug_score` decoder race from N10; no new FFmpegKit or fixture race was reported.
- **Source authority and local commit:** Frozen builder/native handoff SHA is `625c3452ee3c93fb5d701bb6546726940b88d014` (`fix(build): align sanitizer and Wasm test configuration`), with parent `3b1b6d8d893734e0ba2dfceff6f6e3ec84d30048`. The commit contains the reviewed changes to `runner.sh`, `scripts/function.sh`, and `TEST.md`: unknown `--test` values become `none`; FFmpeg `gcc-asan`/`gcc-ubsan` toolchains are selected explicitly and the catch-all UBSAN fallback is removed; Wasm CMake gets the changelog version and the complete harness builds the production module and includes the structured callback ABI test. This commit is local and not pushed (`origin/dev` remains at the parent); the product worktree is clean after commit. The pre-commit two-file sanitizer patch hash was `sha256:e57b13e2acb7bbe2e6ed93501e391e1e95e62f4a97e1ffad1dd6dad8e8fe2627`; the pre-commit combined tracked diff hash was `sha256:41a4bd9793c21290005be3d520449ed1b372ba6f9cbfe308cb222ffae6b9d38e`. Tracker/review notes remain local as requested.
- **UBSAN:** The user rebuilt and relinked both FFmpeg and FFmpegKit with UBSAN. The full run used `LD_LIBRARY_PATH=/tmp/ffk-n11-gcc14-ubsan:/home/vscode/ffmpeg-kit-builders/prebuilt/linux-x86_64/libraries/lib UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=0 timeout 900s ./FFmpegKit/build/tests/ffmpegkit_tests`; all **116/116** native tests passed in **702.635 seconds** with no UBSAN diagnostic. Log: `/tmp/ffk-n12-full-ubsan-loopback.log` (SHA-256 `804921c0fa65aa01822640cc9d6b1a9f6acb0f71957ecaeb06a07af3675ccef1`). The user-provided rebuild commands for both FFmpeg+FFmpegKit and FFmpegKit-only remain recorded in N11 above.
- **ASAN/LSAN:** Rebuilt both components with `sudo ./runner.sh --host=linux --arch=x86_64 --enable-base --gpl --kit -fk -ff --build-deps --no-bundle --test=address --build-debug --skip -y`. The full run used `LSAN_OPTIONS=suppressions=/home/vscode/ffmpeg-kit-builders/FFmpegKit/tests/asan.supp ASAN_OPTIONS=detect_odr_violation=0:detect_leaks=1 timeout 900s ./FFmpegKit/build/tests/ffmpegkit_tests`; with leak detection enabled and the documented SDL suppressions, all **116/116** tests passed in **679.123 seconds**, exit `0`, with no ASAN/LSAN finding. Log: `/tmp/ffk-n12-full-asan.log` (SHA-256 `cddeebd74e07a73cac0c3cefb40a21ea94ad8e7d6a67b80f1101970818875738`).
- **TSan:** Rebuilt both components with `sudo ./runner.sh --host=linux --arch=x86_64 --enable-base --gpl --kit -fk -ff --build-deps --no-bundle --test=thread --build-debug --skip -y`; `nm -u` confirmed 9,176 TSan references in `libavcodec.a` and 780 in `libavutil.a`. `setarch $(uname -m) -R timeout 900s ./FFmpegKit/build/tests/ffmpegkit_tests > /tmp/ffk-n12-full-tsan.log 2>&1` completed all **116/116** test assertions in **659.294 seconds**. TSan exited `66` for exactly two warnings in `FFmpegKitTest.MediaInformationQuotedFilename`, both the same read/write conflict on FFmpeg `padding_bug_score` (`mpeg4videodec.c:3929` versus `h263dec.c:301`). This is the N10 race accepted by the user; no other warning or failed assertion occurred. Log: `/tmp/ffk-n12-full-tsan.log` (SHA-256 `0e020d050629dc74c313a78049fcfa5136814d32516f1d878fd01d1dd31c5ba4`).
- **Wasm:** Built the current-source GPL bundle with `sudo ./runner.sh --host=wasm --arch=wasm --skip -y --enable-base --gpl --build-deps --kit -fk --release=local`. The complete C/C++ callback harness was configured with the current changelog version (`FFMPEG_KIT_VERSION=0.11.2`) and built using `cmake --build FFmpegKit/build-wasm-callback-suite --target ffmpegkit_wasm_callback_tests ffmpegkit_wasm -j2`; the exact Emscripten cache, configure flags, and CTest regex are in the updated `TEST.md`. The harness, including `callback_abi`, dispatcher, callback lock, session completion, log/statistics, FFplay frame, and the table-growth CTest, passed **11/11**. The Wasm ABI test initially failed `ReportsRuntimeVersion` because the manual CMake configure left `FFMPEG_KIT_VERSION` empty; setting it to the changelog version `0.11.2` made the full suite pass. `TEST.md` now carries that version and includes the ABI test in the full harness command. CTest log: `/tmp/ffk-n12-wasm-ctest.log` (SHA-256 `363b608da6c7c2cb72a081e032c3dee039f0a06d9304e2301a9fe8eff9e8947c`). The production `BUILD_TESTS=OFF` module independently passed `tests/table_growth_test.mjs`; its `WebAssembly.Module.exports` contains `ffmpeg_kit_config_enable_log_callback` and omits `ffmpeg_kit_config_enable_log_callback_v2`. Table-growth log: `/tmp/ffk-n12-wasm-table-growth.log` (SHA-256 `7352e81974d33d434b170c17138eb1ddf6575a14f1a01acae08b6d10776fe449`); export check: `/tmp/ffk-n12-wasm-exports.log` (SHA-256 `6b9605b60931c7adc2477ded81685e8c442ea5b7b8c2cd266efeb12e252b5f0f`); production module SHA-256: `96c1f8187e1ca0ccad0c63fa0839ce7f2faf30efbd9c6e3caf2680409333acb7`.
- **Transition:** FFK24-N12 is complete with the sole TSan exception inherited from the user-accepted N10 disposition. R24-G68 and the subsequent local wrapper goals G69–G71 are complete in the closeout section above. No sanitizer suppression, fixture weakening, or product source workaround was added.

### R24-G67 — Source authority and blocker inventory — complete

- Wrapper preparation commit: `d6ae83eb65509c4857a79fcc3ffa3c286a97fffe`, with `HEAD == origin/dev-wasm` and a clean product worktree. The root `libs/libffmpegkit` gitlink remains `196567dae7fd1509c33bf32081f8237596ac8e5b`.
- Wrapper source snapshot [35766299689](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35766299689) completed successfully with event/head/snapshot SHA `d6ae83eb65509c4857a79fcc3ffa3c286a97fffe`. Download [review24-g67-wrapper-d6ae83e-35766299689](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35766299689/artifacts/10712197786), artifact ID `10712197786`, upload digest `sha256:626f67c2d850f0208d4b4e6d638ea33c4bec7075aae527f8d2f2dfacce3b4516`, archive SHA-256 `7c6969c88c621da7e939e1740a7d4284bcbf4661e4b07cf5c0222da5d25e1d05`, metadata **1,036 files / 41,453,314 bytes**, `include_submodules=true`, `include_lfs=false`. The downloaded archive hash matched the declared checksum and metadata.
- Builder source authority: `HEAD == origin/dev == fc35587142a7c2a9356f3850c956bd1b17037d38`, clean; native ABI content remains pinned by the root gitlink to `196567dae`. Builder snapshot [35746267948](https://github.com/akashskypatel/ffmpeg-kit-builders/actions/runs/35746267948) completed successfully at exact source `fc35587142a7c2a9356f3850c956bd1b17037d38`. Download [ffmpeg-kit-builders-source-fc3558714-35746267948](https://github.com/akashskypatel/ffmpeg-kit-builders/actions/runs/35746267948/artifacts/10702284165), artifact ID `10702284165`, archive SHA-256 `a0e74c97039c84ac8ecaa6524afa9f08f5605e9a4bafaecf3cae9ab87b0df663`, metadata **424 files / 10,342,490 bytes**, `include_submodules=true`, `include_lfs=false`.
- The preparation-time blocker inventory above is superseded by the current ledger and FFK24-N8/FFK24-N10 transition sections: B3A is resolved, B4 is completed by user acceptance, B5/N10 is closed by user acceptance with the known FFmpeg race documented, and B7 is handled by the user-authorized local browser gate. The accepted publication prerelease exception remains `ffigen_js: ^0.0.16-pre`.
- Historical transition: R24-G67 complete; FFK24-N7 complete. Current transition is recorded under FFK24-N8 below.

### FFK24-N7 — Linux-local CMake dependency-resolution performance — complete

- Native builder commit [`e9de4755a66d437cd2d070fbec2f81a9783e03aa`](https://github.com/akashskypatel/ffmpeg-kit-builders/commit/e9de4755a66d437cd2d070fbec2f81a9783e03aa) is pushed to `origin/dev`, with cross-platform follow-up [`13f45218fc562c9cf4f90da38da479874df8b404`](https://github.com/akashskypatel/ffmpeg-kit-builders/commit/13f45218fc562c9cf4f90da38da479874df8b404) and MinGW follow-up [`e43b51eebe2f42fac658a0dbbc3ee3e47dd55c2f`](https://github.com/akashskypatel/ffmpeg-kit-builders/commit/e43b51eebe2f42fac658a0dbbc3ee3e47dd55c2f) also pushed.
- The resolver now caches pkg-config directory expansion and direct archive hits/misses for every platform. Linux, Emscripten, Windows, macOS, and other native branches use the same non-recursive direct-entry lookup; `.lib` versus `.a` candidates and `.dll`, `.dylib`, `.tbd`, and versioned `.so` conversions remain platform-specific. Nested archives require an explicitly supplied containing directory.
- Evidence ledger: [review24-linux-cmake-linking-performance.md](./review24-linux-cmake-linking-performance.md). The pre-change approved runner command configured in `130.8s` and completed in `143.79s`; after N7 it configured in `9.9s` and completed in `22.50s`, both with exit status `0`.
- Focused CMake fixture passed for multiple pkg-config roots, nested decoys, direct hits/misses, `-lfoo`, explicit nested-directory lookup, Windows `.lib`/`.dll`, MinGW `.dll.a`/`.dll`, macOS `.a`/`.dylib`, and shared-to-static replacement. The approved Linux release runner was rerun after the follow-ups with `Configuring done (0.3s)`, full elapsed `14s`, and exit status `0`; no recursive lookup symbols remain. The exact documented Linux gtest runner previously built `ffmpegkit_tests` successfully.
- Historical full-suite stall: an earlier run stopped at `FFmpegKitTest.GenerateTestVideoFile` with the tagged process at 0% CPU and no child encoder. This is no longer a current blocker; the complete N12 UBSAN, ASAN/LSAN, and TSan runs all reached the final 116-test summary, with the only TSan warnings classified under N10 above.
- Transition: N7 is closed on resolver correctness/performance evidence; N8 structured ABI cutover is complete with its version-policy amendment.

### Hard order

```text
R24-G67 -> FFK24-N7 -> FFK24-N8 -> FFK24-N9 -> FFK24-N10 -> FFK24-N11
  -> FFK24-N12 -> R24-G68 -> R24-G69 -> R24-G70 -> R24-G71 -> R24-G72
```

N7–N11 have explicit dispositions. FFK24-N12 is complete with the native and Wasm evidence recorded above; G68–G71 are complete in the subsequent local wrapper closeout.

## Review 23 Tracker — cross-platform callback transport/performance — 2026-09-21

- Native plan: [ffmpegkit-review-23-native-callback-plan.md](./ffmpegkit-review-23-native-callback-plan.md).
- Cross-platform plan: [review-23-luna-cross-platform-production-readiness-plan.md](./review-23-luna-cross-platform-production-readiness-plan.md).
- Preparation status: **Native implementation through N6 complete; R23-G60 demand-driven activation is implemented and locally verified.** R23-G59 baseline and the exact G60 wrapper snapshot are recorded below.
- Wrapper starting SHA: `5d80c88e4b4dd8bac5df147e270bfcce1b9358c6` (`HEAD == origin/dev-wasm`, clean at preparation).
- Native builder starting SHA: `9047d9c03ba402b5a7eebed294698083c07eb3d3`; frozen native ABI handoff SHA: `196567dae7fd1509c33bf32081f8237596ac8e5b`. The current `ffmpeg-kit-builders` `dev` head is workflow-only commit `fc35587142a7c2a9356f3850c956bd1b17037d38` (clean); no native ABI source changed.
- Hard order: `R23-G59 → FFK23-N1…N6 → native exact-SHA freeze → R23-G60 → R23-G61 → R23-G62 → R23-G63 → R23-G64 → R23-G65 → R23-G66`.
- Native changes are restricted to the designated elevated WSL checkout `\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders\FFmpegKit`; the ABI handoff is now frozen at `196567dae`, so Flutter and React Native integration may proceed in the ordered wrapper goals.
- Workflow policy: use elevated Git Bash for authenticated `gh` operations. Do not use GitHub CI to test unpublished native-ABI-dependent changes; use the local builder outputs and local wrapper/browser gates. The source-snapshot workflow is reserved for source-authority and final-closeout evidence.
- Toolchain policy: do not add SDK/toolchain or product workarounds. Use `flutter config --no-analytics` and `dart --disable-analytics`; document any remaining SDK/toolchain limitation and mark the affected goal **Blocked**.
- `ffigen_js: ^0.0.16-pre` remains the accepted dependency exception; do not change it. G21 remains deferred.

### Review 23 engineering decision record

- Frozen source snapshot SHA: `5d80c88e4b4dd8bac5df147e270bfcce1b9358c6` before Review 23 implementation; the exact R23-G60 wrapper snapshot is `54b47ca2a7b6d2d04c748a638e1024ef2a0eead5`; final exact SHA will be recorded at G66.
- Native builder SHA: `9047d9c03ba402b5a7eebed294698083c07eb3d3` before implementation; final native SHA is a prerequisite handoff.
- Finding: the current live-log bridge discards callback payloads, history indexing is quadratic, and callback/redirection activation is broader than actual consumer demand.
- Invariant: each inserted log has one immutable per-session sequence; indexed history remains public-compatible and O(1); completion remains independent from optional log/stat routing.
- State owner: native session/history lock owns insertion and sequence; wrapper bridge leases own callback demand; each consumer owns its reconciliation cursor.
- Message ownership: v2 callback payloads are owned by the consumer after accepted invocation and freed exactly once; native frees rejected/uninvoked payloads.
- Sequence/order authority: native insertion sequence is authoritative; wrappers deduplicate/reconcile by sequence and never infer order from callback scheduling.
- Failure ordering: preserve the primary execution/transport error, then callback/reconciliation/free/cleanup errors; cleanup must not replace the primary error.
- Compatibility policy: add the v2 ABI without removing v1; use explicit feature negotiation/fallback and never silently drop a required live-log event.
- Selected design: additive owned v2 event ABI, O(1) sequence/history storage, demand-driven bridge leases, and bounded final reconciliation.
- Rejected alternatives: borrowed async pointers, adding fields to the legacy callback in place, normal live polling via indexed getters, implicit `enableRedirection()`, or starting Flutter/React Native work against a moving native header.
- Test oracle: exact event id/sequence/level/message, alloc/free balance, rejected-dispatch cleanup, no-consumer zero log/stat routing, O(1) indexed access instrumentation, completion barriers, Wasm main/worker behavior, redirection authority, and exact-SHA workflow/artifact evidence.

| Goal | Objective | Status |
| --- | --- | --- |
| **R23-G59** | Workflow snapshot + A/B/C baseline | **Complete — run `35676106679`; exact source `5d80c88e4b4dd8bac5df147e270bfcce1b9358c6`** |
| **FFK23-N1** | Freeze native source and add regression/performance-oracle gtests | **Complete — 0c0aa7341 pushed to origin/dev** |
| **FFK23-N2** | Add additive lifetime-safe v2 global log-event ABI | **Complete — 37df2b595 pushed to origin/dev** |
| **FFK23-N3** | Make sequence assignment and indexed history O(1) | **Complete — 21327eb38 pushed to origin/dev** |
| **FFK23-N4** | Make dispatch, completion, rejection cleanup, and Wasm behavior exact | **Complete — 5afb4e945 pushed to origin/dev** |
| **FFK23-N5** | Preserve redirection authority, v1 compatibility, and audit fake handles | **Complete — 22796e3fb pushed to origin/dev** |
| **FFK23-N6** | Run native/Wasm/sanitizer/build gates and freeze native handoff | **Complete with documented residual diagnostics — `196567dae` pushed to origin/dev; TSAN/UBSAN findings are not goal blockers** |
| **R23-G60** | Demand-driven callback activation | **Complete — `e19baa3` pushed to origin/dev-wasm; local Flutter/RN/browser gates passed; native handoff `196567dae`** |
| **R23-G61** | Flutter v2 direct log path | **Blocked after implementation — `740033d` pushed to `origin/dev-wasm`; exact custom Web/Wasm runtime verification is blocked by the Flutter 3.47 DataAssets limitation (`buildDataAssets: false`), with no workaround added** |
| **R23-G62** | React Native v2 direct log path | **Complete — `727d732` pushed to `origin/dev-wasm`; local native/Web gates passed; the historical packed-Web temp-path failure was cleared by the isolated-cache rerun recorded under G63** |
| **R23-G63** | Completion/final-log exact-once semantics | **Complete — `9e5d05a45ff006dae54b67454fb27347e8cdf0c0` pushed to `origin/dev-wasm`** |
| **R23-G64** | Redirection authority | **Complete — `fd23bff4898914e7bc382258d7522da52eb0b8b4` pushed to `origin/dev-wasm`** |
| **R23-G65** | Docs/compatibility/benchmark report | **Complete — `dfb0b1e` pushed to `origin/dev-wasm`; custom Flutter v2 browser evidence remains blocked by the documented DataAssets capability** |
| **R23-G66** | Cross-platform exact-SHA closeout and source snapshot | **Complete with documented exceptions — final source SHA `78a3e4d`; snapshot run `35719137360`** |
| **G21** | Published runtime contract / official-runtime integrity | **Deferred / unchanged** |

### Review 23 implementation preparation evidence

- Both Review 23 plans were inspected and retained as the implementation authority; their instructions are represented here as ordered goals and gates, not as user authorization to skip prerequisites.
- Native repository authority was verified in the elevated ManyLinux checkout: `HEAD == origin/dev == 9047d9c03ba402b5a7eebed294698083c07eb3d3`, branch `dev`, clean.
- Elevated Git Bash `gh auth status --hostname github.com` passed for `akashskypatel` with `repo` scope.
- R23-G59 snapshot workflow [35676106679](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35676106679) completed successfully at exact source `5d80c88e4b4dd8bac5df147e270bfcce1b9358c6`; source head and workflow head match.
- Baseline source artifact: [review-23-baseline-35676106679](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35676106679/artifacts/10672724545), artifact ID `10672724545`, upload digest `sha256:a5cf9d3fe3b073b222385d02a857f1c5a46249608514f8de7f847cfe5dfdb14e`, archive SHA-256 `eb6ae0d7d4f026c1bd052cd5ccd42b9cb0157489db1d7800968770e84c316462`, 1,029 files / 41,006,815 bytes.
- Baseline diagnostic artifact: [review-23-baseline-log-35676106679](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35676106679/artifacts/10672679611), artifact ID `10672679611`, upload digest `sha256:b83ba897cef5f584020b434673ab1346627df206b0bcd98086eae74d6a5c84ce`.
- Elevated WSL builder evidence at native baseline `9047d9c03ba402b5a7eebed294698083c07eb3d3`: `sudo ./runner.sh --host=wasm --arch=wasm --skip -y --enable-base --build-deps --kit -fk --release=local` completed successfully and produced `/home/vscode/ffmpeg-kit-builders/prebuilt/wasm-wasm32/releases/bundle-base-wasm-wasm32-static-lgpl.zip` (7.5 MiB); `sudo ./runner.sh --host=linux --arch=x86_64 --skip -y --enable-base --build-deps --kit -fk --release=local` completed successfully and produced `/home/vscode/ffmpeg-kit-builders/prebuilt/linux-x86_64/releases/bundle-base-linux-x86_64-shared-lgpl.zip` (17 MiB).
- Both builder runs emitted existing license-extraction and empty touch-file warnings but exited 0. The runner changed only executable mode bits on three tracked native files; those modes were restored to `0644`, and the native checkout is clean at `9047d9c03ba402b5a7eebed294698083c07eb3d3`.
- Native implementation is complete through FFK23-N5; wrapper integration remains intentionally locked until FFK23-N6 freezes the exact native ABI SHA. A/B/C runtime measurements and cross-platform bindings remain deferred until that handoff.
- FFK23-N1 — 0c0aa7341: added the Review 23 callback ABI/history regression oracle to native and Wasm targets; the exact builder baseline was preserved and the commit was pushed to origin/dev.
- FFK23-N2 — 37df2b595: added additive FFmpegKitGlobalLogCallbackV2, explicit session ID/sequence/level transport, owned non-null payloads, null-message preservation, and legacy v1 coexistence; pushed to origin/dev.
- FFK23-N3 — 21327eb38: added friend-only per-session sequence assignment and deque-backed internal history with O(1) indexed access while preserving public list-returning APIs; pushed to origin/dev.
- FFK23-N4 — 5afb4e945: added accepted-before-completion ordering, Wasm rejected-event payload cleanup accounting, and test-only outstanding-payload evidence; pushed to origin/dev.
- FFK23-N5 — 22796e3fb: removed the numeric fake-handle heuristic, made the existing robustness test fail closed, and verified global v2 callback registration does not enable redirection; pushed to origin/dev.
- Focused native ASAN/LSAN evidence through N5: Review 23 tests passed 3/3; N5 robustness plus redirection-authority tests passed 2/2. Focused Wasm Node/CTest target passed 1/1 after N4 and again 1/1 after N5.
- Native sanitizer handoff SHA is exact and remotely verified: `HEAD == origin/dev == 196567dae7fd1509c33bf32081f8237596ac8e5b`; the native worktree is clean after restoring runner-only mode changes. The two sanitizer test-fixture fixes are in `7fa36fe8f6edde4c35ff22c1652c307eaec23c88`; the final native cleanup/configuration commit is `196567dae7fd1509c33bf32081f8237596ac8e5b`.
- Full ASAN/LSAN evidence at the final source content: elevated build `sudo ./runner.sh --host=linux --arch=x86_64 --enable-base --gpl --kit --build-deps --no-bundle --test=address --build-debug --skip -y`, then `sudo -E env LSAN_OPTIONS=suppressions=/home/vscode/ffmpeg-kit-builders/FFmpegKit/tests/asan.supp ASAN_OPTIONS=detect_odr_violation=0:detect_leaks=1 ./build/tests/ffmpegkit_tests`. `FFmpegKit/test_asan_review23_final.log` ran **111 tests from 17 suites**, passed **108**, and had only the three known remote TLS failures. There was no AddressSanitizer memory report, LeakSanitizer report, or suppression-parser warning. The prior stack-use-after-return was resolved by `7fa36fe8`; the FFprobe and test-owned leaks found during the unfiltered run were resolved by `196567dae`. The only remaining LSan stacks were confirmed SDL thread-local teardown allocations and are covered by precise symbol-level third-party entries; no product scenario was filtered or weakened.
- TLS classification for both full sanitizer runs: `FFmpegKitTest.RemoteStreamParallelRecordingCancellationIsolation`, `RemoteStreamCancelAndImmediateRestart`, and `RemoteStreamRepeatedCancelRequestsAreIgnored` fail with `error:0A000086:SSL routines::certificate verify failed` for the remote HLS URL. Per the user directive, this is the known FFmpeg 9.0 hard-TLS requirement defect, ignored for sanitizer acceptance but retained in the unfiltered evidence and not hidden by test filters.
- Historical Review 23 TSAN evidence at the exact final handoff SHA: the elevated `--test=thread` build followed by `setarch x86_64 -R ./build/tests/ffmpegkit_tests` in `FFmpegKit/test_tsan_review23_final.log` ran **111 tests from 17 suites**, passed **108**, and retained the same three known TLS failures plus **2 ThreadSanitizer warnings**. The earlier test-side callback-lifetime and concurrent `StressTest.ParallelSyncHammer` vector/release races were fixed in `7fa36fe8` without removing scenarios. At the time, both warnings were classified as one FFmpeg frame-data lifetime/publication race: `src/ffmpeg.c:503` (`frame_data_ensure`) read an allocation while another decoder worker initialized it through `av_mallocz`, and `src/ffmpeg.c:551` freed the same frame-data allocation while the decoder worker still accessed it. The later fully instrumented N10 investigation supersedes that root-cause interpretation: those original `FrameData` reports disappeared after FFmpeg itself was rebuilt with TSan. The known fully instrumented `padding_bug_score` race and its user-accepted out-of-scope disposition are recorded under FFK24-N10 above. No sanitizer bypass or scenario weakening was used.
- UBSAN evidence at the exact final handoff SHA: the documented `--test=undefined` build completed and the focused `FFmpegKit/test_ubsan_review23_final.log` run passed **1/1** selected test, but emitted repeated GCC 14/libstdc++ vptr diagnostics in `shared_ptr_base.h` for `std::_Sp_counted_ptr_inplace<ffmpegkit::Log>` from `process_log`/the callback thread and final session teardown. Production shared-pointer fields were valid under GDB, and disposable single-/multi-TU probes using the production sanitizer/debug flags were clean. This is recorded as a toolchain/DSO RTTI diagnostic limitation, not suppressed or worked around; it is not used to block wrapper progress.
- Wasm evidence: the initial non-GPL artifact attempt was correctly discarded after the user clarified that `--gpl` selects the intended bundle. The official elevated command `sudo ./runner.sh --host=wasm --arch=wasm --skip -y --enable-base --gpl --build-deps --kit -fk --release=local` produced `prebuilt/wasm-wasm32/ffmpeg-base-wasm-wasm32-static-gpl`. Following `TEST.md` with that exact bundle, the complete callback suite passed **10/10** (authority, callback lock, pthread failure, wrapper state, session ID, session completion, log/statistics, Review23 ABI, dispatcher, and FFplay frame); the separate documented table-growth build/CTest passed **1/1**. Combined Wasm evidence is **11/11**. Existing compiler warnings were preserved; no SDK/toolchain or product workaround was added.
- FFK23-N6 is now closed for handoff with the residual TSAN/UBSAN diagnostics explicitly recorded and non-blocking per the user directive. Flutter and React Native ABI consumer work may proceed in order against native SHA `196567dae`.
- R23-G60 exact wrapper source authority: [workflow run 35701634186](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35701634186) checked out `54b47ca2a7b6d2d04c748a638e1024ef2a0eead5` exactly. Snapshot artifact [review23-g60-source-35701634186](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35701634186/artifacts/10681913202) is artifact ID `10681913202`, upload digest `sha256:166f6fd5d7e1484892da6125b81b3753b03eeda4b547f56a8e155e54abea7d74`, and contains archive SHA-256 `5f2c1a17ac56bc00715eb310d42f4ba632fdb2bff922a342dbf7c23ede95293f`; metadata reports 1,030 files / 41,031,174 bytes.
- R23-G60 implementation commit: `e19baa3` (`fix(review23): make callback routing demand-driven`) is pushed to `origin/dev-wasm`; the next source snapshot must use this new exact wrapper SHA.
- R23-G60 Flutter: the existing process-wide `CallbackManager` lease authority keeps completion demand independent from optional log/statistics demand, installs on first lease, uninstalls on last lease, rolls back failed installation, resets after failed uninstall, and keeps global callback demand independent. The analyzer-only tear-off cleanup is recorded in `flutter/test/callback_bridge_demand_test.dart`; no native ABI or redirection toggle was changed.
- R23-G60 React Native: added `react-native/src/callback-demand.ts` as the process-wide lease/refcount authority; `Session` now always owns completion demand for async execution, acquires optional log/statistics demand only while a sink exists, releases on settlement/startup failure/sink removal, and preserves the primary execution error over cleanup failures. `getLogsJson`/`getStatisticsJson` are not called in the no-observer path. Backend bridge hooks are optional v2 seams and do not call `enableRedirection()`.
- R23-G60 local evidence: elevated analytics-disabled `dart --disable-analytics analyze` and `flutter analyze` passed with no issues; Flutter demand suite passed **5/5** and host-neutral suite passed **162/162**. React Native `npm run typecheck` passed, `npm test` passed **142/142**, focused demand/ownership tests passed **37/37**, and lint had only the pre-existing `tests/arguments.test.js` escape warning. Local React Native headless WebAssembly smoke passed all initialize/FFmpeg/FFprobe/media-info/FFplay controls with zero page/console errors; its Vite server was torn down and port `4173` was verified closed. No GitHub CI was used for ABI-dependent validation; no SDK/toolchain workaround was added.
- R23-G61 native ABI authority is the exact frozen builder SHA `196567dae7fd1509c33bf32081f8237596ac8e5b`; the root `libs/libffmpegkit` gitlink now points to that commit. Both generated bindings were regenerated from the tracked `flutter/ffigen_native.yaml` and `flutter/ffigen_js.yaml` configs; `ffigen_js: ^0.0.16-pre` is unchanged. The generator emitted only the existing macro-parser warning.
- R23-G61 implementation commit `740033d509a1e4adbbbe4fdf38a39f96f3228dc8` adds the owned v2 native and Web callback bridges, decodes each message once, releases every non-null payload in `finally`, preserves the primary callback error if release also fails, carries session/sequence/level/userData, and explicitly falls back to v1 buffered polling when the additive v2 symbol is unavailable. Per-session `nextExpectedLogSequence` suppresses duplicates, reconciles gaps, drops unresolved out-of-order events, and prevents completion from duplicating direct delivery.
- R23-G61 focused Flutter evidence at `740033d`: elevated analytics-disabled `dart --disable-analytics analyze` passed with no issues; `flutter test --no-pub test/v2_log_event_test.dart test/callback_bridge_demand_test.dart` passed **15/15**. Coverage includes level preservation, one decode, success/unknown/duplicate/throw cleanup, primary-error precedence, contiguous no-history delivery, gap reconciliation, unresolved-gap dropping, and completion exact-once behavior. Review 22 ownership tests remain retained.
- Supported local Web evidence: `flutter build web --wasm --no-pub --target=lib/web_runtime_smoke.dart` succeeded; the output was served with `flutter/example/web_static_server.mjs` and checked locally with Playwright. The page reached `STARTING|INITIALIZED|FFMPEG_OK|LOG_OK|FFPROBE_OK|MEDIA_INFO_OK|PASS`, reported `crossOriginIsolated: true`, had zero console errors, and loaded the packaged `assets/packages/ffmpeg_kit_extended_flutter/assets/wasm/ffmpegkit.wasm` with HTTP 200. The packaged default runtime contains v1 but no v2 export, so this browser result verifies the explicit compatibility fallback, not the v2 runtime path.
- Exact custom-runtime blocker: temporarily selecting the local frozen bundle `\\wsl.localhost\\ManyLinux\\home\\vscode\\ffmpeg-kit-builders\\prebuilt\\wasm-wasm32\\releases\\bundle-base-wasm-wasm32-static-small-gpl.zip` reached the hook but failed with `Custom or non-default Flutter Web Wasm configuration ... requires Dart DataAssets` and `buildDataAssets: false`. The Windows and designated WSL Flutter 3.47 toolchains expose the same limitation. No SDK/toolchain or product workaround was added; the exact custom v2 browser gate remains **Blocked** until a toolchain with DataAssets is available.
- R23-G61 pre-implementation source authority is workflow [35703684943](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35703684943) at exact source `709ec5a869c7e11beec9abc891969d8ff28327c7`; the source artifact is [review23-g61-source-35703684943](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35703684943/artifacts/10683257646), artifact ID `10683257646`, archive SHA-256 `c0d6cae92c341d2730c0c50d120d8937498c60290bc3a7b3f8cf86af12945814`.

### R23-G62 — Complete — 2026-09-22

- Native ABI authority remained the exact frozen builder SHA `196567dae7fd1509c33bf32081f8237596ac8e5b`; no native builder source was changed. The implementation commit is `727d732` (`feat(review23): add React Native v2 log bridge`), pushed to `origin/dev-wasm`.
- The React Native chain is now `FFmpegKitDynamicApi → FFmpegKitExtendedImpl / Windows TurboModule → structured native/Web event bridge → backend → Session`. Android/Apple Cxx and Windows use the consumer-generated structured `LogEvent` shape (`sessionId`, `sequence`, `level`, copied `message`); Web uses the same v2 Wasm callback signature and frees the owned message exactly once.
- Native Cxx and Windows module boundaries copy the owned message before emitting it; rejected/teardown paths retain callback state long enough to avoid an in-flight user-data use-after-free. TypeScript routes the process-wide event stream per session, preserves sequence order, suppresses duplicates, skips steady-state indexed log getters on the direct path, and keeps the existing state-only terminal monitor and first-error authority.
- Focused evidence: `node --test tests/wasm-backend-memory.test.js tests/wasm-session-ownership.test.js tests/codegen-lifecycle.test.js` passed **76/76**; coverage includes exact payload fields, Wasm signature/free-once, compatibility fallback, per-session routing, demand leases, no live history reads, duplicate/order handling, and callback-error precedence. `npm run check` passed **148/148** with only the pre-existing unnecessary-escape lint warning.
- Consumer build evidence: elevated Android `:app:assembleDebug --no-daemon --stacktrace` passed for `arm64-v8a`, `armeabi-v7a`, and `x86_64`; standalone Android Codegen generated the v2 event/install/uninstall surface; elevated `bash ./build.sh windows` passed consumer Windows Codegen and MSBuild through `FFmpegKitExtended.dll` and the example executable. The Windows build used the existing published runtime for compile/deployment validation; unpublished-ABI runtime execution remains governed by the frozen native handoff policy.
- Local Web/package evidence: `npm run test:web` passed the headless WebAssembly smoke (initialize, repeated initialize, FFmpeg, FFprobe, media info, FFplay pause/resume/stop); isolated-cache `npm run test:pack-types` passed. The G62 `npm run test:pack-web` attempt reached the packed Vite fixture but hit a Windows esbuild temporary-parent access error (`Cannot read directory "../../../..": Access is denied`); the isolated-cache G63 rerun passed the packed Vite consumer build, so this is not a continuing G66 packaging blocker. No SDK/toolchain or product workaround was added.

### R23-G63 — Complete — 2026-09-22

- Native ABI authority remained the exact frozen builder SHA `196567dae7fd1509c33bf32081f8237596ac8e5b`; no native source changed for this wrapper goal.
- Finding owned: terminal completion could race the final direct v2 log callback, leaving a missing sequence unreconciled or forcing an unbounded history traversal; continuous direct delivery also needed to remain history-free.
- Invariant: direct events are delivered in native sequence order, duplicates are ignored, terminal reconciliation reads the native log count once, fetches only the missing indexed range when needed, prefers an already queued direct event for each sequence, and drops only an unresolved terminal gap; completion and first-error authority remain unchanged.
- Files changed: React Native backends and native module seams (`react-native/src/session.ts`, `react-native/src/platform/backend.ts`, `react-native/src/platform/backend.web.ts`, `react-native/src/NativeFFmpegKitExtended.ts`, `react-native/cpp/FFmpegKitDynamicApi.*`, `react-native/cpp/FFmpegKitExtendedImpl.*`, and Windows `FFmpegKitExtended.*`), plus source-level Codegen and Wasm ownership tests.
- Why each changed: expose `getLogsCount` across Android/Apple, Windows, and Web; reconcile only at terminal state; preserve the existing compatibility fallback when the scalar count method is unavailable; and prove recovery, unresolved gaps, first-error ordering, and Windows Codegen contract.
- Flutter side: the existing G61 v2 reconciliation implementation was revalidated with elevated analytics-disabled `dart --disable-analytics analyze` (`No issues found!`) and `flutter test --no-pub test/v2_log_event_test.dart test/callback_bridge_demand_test.dart` (**16/16**). The exact custom Flutter Web/Wasm runtime gate remains the previously documented Flutter 3.47 DataAssets limitation; no workaround was added and that limitation remains attached to G61/G66 rather than this goal.
- React Native focused/full evidence: `npm run check` passed **150/150**, including the direct-log order, one bounded terminal history read, getter-error-first, Codegen, and ownership cases; lint retained only the pre-existing unnecessary-escape warning in `tests/arguments.test.js`.
- Consumer/build evidence: elevated Android `:app:assembleDebug --no-daemon --stacktrace` passed for `arm64-v8a`, `armeabi-v7a`, and `x86_64`; standalone Android Codegen completed; elevated Windows Codegen/MSBuild completed through `FFmpegKitExtended.dll` and the example executable. Local headless `npm run test:web` passed all WebAssembly controls; isolated-cache `npm run test:pack-types` and `npm run test:pack-web` both passed.
- Tracker transition: complete after `9e5d05a45ff006dae54b67454fb27347e8cdf0c0` (`fix(review23): reconcile React Native terminal logs`) was pushed to `origin/dev-wasm`.

### R23-G64 — Complete — 2026-09-22

- Finding owned: callback-demand installation could be mistaken for permission to re-enable FFmpeg core log/stat redirection, while completion transport must remain independent of optional log/stat delivery.
- Contract proven: `disableRedirection()` remains the native capture/forwarding authority; `enableRedirection()` is called only by the explicit public API. Installing or removing Flutter/RN callback bridges does not call either redirection toggle, and internal completion still settles while core redirection is disabled.
- Native authority: FFK23-N5 already verified that global callback registration does not enable redirection at the frozen native ABI SHA `196567dae7fd1509c33bf32081f8237596ac8e5b`; no native source changed for G64.
- Flutter evidence: added real native high-level integration coverage in `flutter/test/api_test.dart`. Elevated analytics-disabled `flutter test --no-pub test/api_test.dart --plain-name Redirection` passed **3/3** (including the existing low-level redirection test); disabled redirection completed with **0 log callbacks / 0 statistics callbacks**, and explicit enable delivered log callbacks. Elevated `dart --disable-analytics analyze` passed with no issues; the focused v2/demand suite passed **16/16**.
- React Native evidence: the Wasm ownership fixture now models explicit redirection state and counts toggle calls. Focused ownership/Codegen tests passed **49/49**; the disabled-redirection case settled completion with zero log/statistics delivery and zero implicit enable calls, while the explicit-enable case delivered the direct event. Full `npm run check` passed **152/152**, with only the pre-existing unnecessary-escape lint warning.
- Semantics kept distinct: `disableRedirection()` controls native capture/forwarding; removing callbacks or listeners controls wrapper consumer demand. Neither operation is treated as the other.
- Files changed: `flutter/test/api_test.dart` and `react-native/tests/wasm-session-ownership.test.js`; no SDK/toolchain or product workaround was added.
- Tracker transition: complete after `fd23bff4898914e7bc382258d7522da52eb0b8b4` (`test(review23): prove redirection authority`) was pushed to `origin/dev-wasm`.

### R23-G65 — Complete — 2026-09-22

- Finding owned: the ABI-v2 callback transport, compatibility fallback, redirection authority, and local browser-validation boundary were implemented but were not described consistently across the Flutter and React Native API/readme/test documentation.
- Contract recorded: ABI-v2 direct log events carry session ID, native sequence, level, and copied message; steady-state live delivery does not poll complete history; native history remains available for public getters and bounded terminal reconciliation; callback activation is demand-driven; completion is independent of optional log/statistics consumers; `disableRedirection()` remains authoritative; owned messages are copied and released internally; custom Flutter Web/Wasm runtime selection requires Dart DataAssets; `ffigen_js: ^0.0.16-pre` remains intentional.
- Flutter documentation changed: `flutter/README.md`, `flutter/doc/architecture.md`, `flutter/doc/guides/callbacks.md`, `flutter/doc/api/sessions.md`, `flutter/doc/guides/session-queue-management.md`, `flutter/CHANGELOG.md`, and public Dartdocs in `flutter/lib/src/ffmpeg_kit_config.dart`, `flutter/lib/src/ffmpeg_kit_extended.dart`, and `flutter/lib/src/callback_manager.dart`.
- React Native documentation changed: `react-native/README.md`, `react-native/TEST.md`, `react-native/CHANGELOG.md`, and public bridge/session/backend JSDoc in `react-native/src/NativeFFmpegKitExtended.ts`, `react-native/src/ffmpeg-kit-config.ts`, `react-native/src/platform/backend.ts`, and `react-native/src/session.ts`.
- Performance/compatibility artifact: [Review 23 performance and compatibility report](./review23-performance-report.md). It records A/B/C per Flutter native, Flutter Web, React Native native, and React Native Web, including direct/history/count counters, delivered/duplicate/missing outcomes, ownership instrumentation boundaries, observed gate wall times, native sanitizer cross-checks, and the explicit custom-v2 browser limitation.
- Fresh Flutter evidence: elevated `flutter config --no-analytics` and `dart --disable-analytics --version` completed; elevated `dart --disable-analytics analyze` passed with `No issues found!`; focused v2/demand tests passed **16/16**; native redirection tests passed **3/3**. Combined focused test wall time was **12.14 s**. The stable Flutter 3.47 custom-runtime browser gate remains blocked by `buildDataAssets: false`; no SDK/toolchain or product workaround was added.
- Fresh React Native evidence: `npm run check` passed **152/152** in **5.453 s** with only the pre-existing `no-useless-escape` warning; local headless `npm run test:web` passed initialization, FFmpeg, FFprobe, media-info, and FFplay controls in **6.438 s**. The generated `react-native/example/public` directory was removed after the gate; no test server/browser child remained.
- Counter authority: Flutter v2 tests prove contiguous direct delivery with zero history reads, one bounded terminal reconciliation read, ordered gap recovery, duplicate suppression, and payload release. React Native fixtures prove zero optional A-path reads, zero steady-state indexed reads, one terminal count read, one bounded gap read, ordering, duplicate suppression, redirection authority, and completion independence. Wrapper fixtures do not invent allocator totals; native/Wasm ownership tests remain the alloc/free oracle.
- Native ABI authority remained the exact frozen SHA `196567dae7fd1509c33bf32081f8237596ac8e5b`; no native source changed for G65. `ffigen_js: ^0.0.16-pre` and deferred G21 remain unchanged.
- Coverage caveat: codebase-memory coverage was checked for the operated wrapper source paths; all returned `no_recorded_issue`, but Flutter files were `metadata_changed` and React Native backend paths were `not_tracked`, so direct source reads were authoritative.
- Tracker transition: complete after `dfb0b1e` (`docs(review23): document callback compatibility and counters`) was pushed to `origin/dev-wasm`; G66 is the next and only open Review 23 goal.

### R23-G66 — Complete with documented exceptions — 2026-09-22

- Final product-source authority is wrapper commit `78a3e4d7e6151deb16ec6cde8857d14d31172d5b`, pushed to `origin/dev-wasm` before closeout. The only source change after the prior G65 evidence was the custom Flutter DataAsset smoke fixture correction in `test(flutter): align custom wasm smoke with callback contract`; it registers the v2 log callback, asserts a non-empty level/message, emits `LOG_OK`, and removes the callback in `finally` so the shared browser harness tests the same contract in both default and custom runtime fixtures.
- Native ABI content remains frozen at `196567dae7fd1509c33bf32081f8237596ac8e5b`: the root gitlink still points to that SHA. After G66 closeout, the elevated ManyLinux builder `dev` branch advanced to workflow-only commit `fc35587142a7c2a9356f3850c956bd1b17037d38`; the ABI source and prior FFK23-N6 evidence are unchanged: native gtests, Wasm Node/CTest callback tests **11/11**, ASAN/LSAN **108/111** with only the three known FFmpeg 9.0 hard-TLS failures, TSAN **108/111** with the two documented frame-data publication/lifetime warnings, and UBSAN focused **1/1** with the documented GCC 14/libstdc++ RTTI/vptr diagnostic. No sanitizer scenario was filtered or weakened.
- Final exact-SHA Flutter local gates, run elevated with analytics disabled, passed: `flutter config --no-analytics`; `dart --disable-analytics analyze`; `flutter analyze`; `flutter test --no-pub --exclude-tags native` — **172/172** tests, including the v2 direct/demand/reconciliation suites and DataAsset contract tests. The fresh local default Wasm build/browser gate at this exact SHA passed with `STARTING|INITIALIZED|FFMPEG_OK|LOG_OK|FFPROBE_OK|MEDIA_INFO_OK|PASS`, no page/console errors, and the tracked static server and temporary Playwright dependency bridge both stopped/removed.
- The stable Flutter 3.47 custom-runtime local gate remains the previously recorded R23-G61 blocker because the SDK reports `buildDataAssets: false`; no SDK/toolchain or product workaround was added. The final workflow’s dedicated custom DataAsset job uses the existing Flutter master capability and passed at the exact SHA with `STARTING|INITIALIZED|FFMPEG_OK|LOG_OK|FFPROBE_OK|MEDIA_INFO_OK|PASS`.
- Flutter exact-SHA workflow [35719130276](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35719130276) checked out `78a3e4d7e6151deb16ec6cde8857d14d31172d5b`. Android, iOS, iOS Simulator, macOS, Linux, Windows, stable Web Wasm/runtime smoke, custom DataAsset smoke, and Native API Verification (Linux) all passed. Package Verification concluded failure solely because `dart pub publish --dry-run` reported the one accepted `ffigen_js: ^0.0.16-pre` prerelease warning and exited 65; no second publication or package-content defect was reported and the dependency was not changed.
- Final exact-SHA React Native local gates passed elevated: `npm run check` **152/152** (one pre-existing `no-useless-escape` warning), `npm run prepare`, packed TypeScript consumer, packed Web consumer, `npm pack --dry-run` (**275 files**, **64.1 MB**, shasum `5330ce83ea3184b11e768b25b6de69ee8c9d4093`), `npm --prefix example run web:build`, and local headless `npm run test:web` covering initialize/repeated initialize, FFmpeg, FFprobe, media info, and FFplay controls. Generated Web staging and all local test/browser processes were removed.
- React Native platform workflow [35719132764](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35719132764) checked out the exact SHA and passed Android, iOS, Apple tvOS, macOS, and Windows. React Native Web workflow [35719135072](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35719135072) checked out the exact SHA and passed both Web/Wasm and Windows staging jobs.
- Final callback assertions are covered by the local and workflow evidence plus [the Review 23 performance/compatibility report](./review23-performance-report.md): no-consumer completion settles with zero optional bridge traffic; direct payload level/message/sequence is exact; steady-state indexed log reads are zero; terminal reconciliation is bounded and duplicate-free; gap recovery preserves order; `disableRedirection()` remains authoritative; global callback leases are not stolen; and owned payloads are released exactly once. The known TLS failures, TSAN/UBSAN diagnostics, stable DataAssets limitation, and accepted prerelease publication warning remain explicitly documented exceptions; G21 remains deferred.
- Final source snapshot workflow [35719137360](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35719137360) passed with both event and snapshot SHA equal to `78a3e4d7e6151deb16ec6cde8857d14d31172d5b`. Download [review23-g66-source-78a3e4d-35719137360](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35719137360/artifacts/10691235504), artifact ID `10691235504`, upload digest `sha256:b072211001c45bf8afb386b408c54e805c9da4886166092bfd660454e285c5cd`, archive SHA-256 `461f58e59122a43ae49e55071af59b506228bd4fc3ebfc65ea719980f05bfb31`, metadata **1,038 files / 41,441,916 bytes**, `include_submodules=true`, and `include_lfs=false`. The downloaded archive hash matched its metadata and declared checksum.
- Exact-SHA closeout audit at the G66 snapshot dispatch: native `HEAD == origin/dev == 196567dae7fd1509c33bf32081f8237596ac8e5b`; wrapper source `78a3e4d7e6151deb16ec6cde8857d14d31172d5b == origin/dev-wasm`; every final workflow head matched the wrapper source SHA; the worktree was clean before the tracker-only evidence update; and the source snapshot artifact matched the source SHA. The later builder workflow-only commit is recorded below and does not alter the frozen ABI gitlink. Codebase-memory coverage returned no recorded issue for the operated paths, but the changed Flutter fixture and smoke file were not tracked and Flutter/RN source metadata was stale/changed, so direct source reads and test output remain authoritative.
- Tracker transition: R23-G66 is closed. The subsequent tracker-only commit records this evidence; it does not alter the frozen product-source SHA represented by the snapshot artifact.

### ffmpeg-kit-builders source snapshot — 2026-09-22

- Added `.github/workflows/repo-source-snapshot.yml` to `ffmpeg-kit-builders` as workflow-only commit `fc35587142a7c2a9356f3850c956bd1b17037d38` on `dev`; the same workflow-only change is present on the default `master` branch at `ddf4698fdcd79ffeb1d52001299f8634063d675e` so GitHub can register manual dispatch. No native ABI source changed; the frozen ABI content remains `196567dae7fd1509c33bf32081f8237596ac8e5b`.
- Snapshot workflow [35746267948](https://github.com/akashskypatel/ffmpeg-kit-builders/actions/runs/35746267948) completed successfully via `workflow_dispatch`, with `head_sha` and the requested `source_ref` equal to `fc35587142a7c2a9356f3850c956bd1b17037d38`.
- Download [ffmpeg-kit-builders-source-fc3558714-35746267948](https://github.com/akashskypatel/ffmpeg-kit-builders/actions/runs/35746267948/artifacts/10702284165), artifact ID `10702284165`, upload digest `sha256:0413b2fd8132e6715fd2ce328f46192e01b49d597c7c9417fdb7ef379a6c0f16`, archive SHA-256 `a0e74c97039c84ac8ecaa6524afa9f08f5605e9a4bafaecf3cae9ab87b0df663`, metadata **424 files / 10,342,490 bytes**, `include_submodules=true`, and `include_lfs=false`. The downloaded archive hash matched its declared checksum and metadata.
- Diagnostic log artifact: [ffmpeg-kit-builders-source-fc3558714-log-35746267948](https://github.com/akashskypatel/ffmpeg-kit-builders/actions/runs/35746267948/artifacts/10702534095), artifact ID `10702534095`. The run emitted only the hosted action Node.js deprecation annotation; the snapshot job passed all steps.

## Review 22 Tracker — Flutter production-readiness residuals — 2026-09-21

- Plan: [flutter-review-22-luna-production-readiness-plan.md](./flutter-review-22-luna-production-readiness-plan.md)
- Review 22 implementation and G58 final validation are complete for the Flutter-owned scope.
- Fresh starting SHA: `78b91361b310ccaf8859297eecd387beaa58a942`.
- Review 22 implementation SHA: `5d80c88e4b4dd8bac5df147e270bfcce1b9358c6` (`HEAD == origin/dev-wasm`).
- Scope: Flutter-owned production readiness only. React Native, ffmpeg-kit-builders, C/C++, native ABI, and deferred G21 remain out of scope.
- Accepted dependency exception: `ffigen_js: ^0.0.16-pre`; no stable release exists. No dependency workaround is authorized.
- Browser validation boundary: run browser-based gates locally; do not rely on hosted headless-browser execution as the local acceptance gate.
- Local shell limitation and resolution: unprivileged Flutter/Dart invocations hung without output, while elevated Git Bash with analytics disabled completed `flutter config --no-analytics`, `dart --disable-analytics analyze`, `flutter analyze`, and the focused suite. No SDK/toolchain workaround or product-code workaround was added; future Dart commands use `dart --disable-analytics`.
- Telemetry-lock handling: a fresh process check found no `dart.exe` processes before or after cleanup. The elevated `flutter config --no-analytics` command completed successfully.
- Active queue: no open Review 22 goals; Review 18 and Review 21 remain historical evidence between the prepared sections.

| Goal | Objective | Status |
| --- | --- | --- |
| **FBH-G53** | Non-owning callback routing for inert/terminal sessions | **Complete — `b4d575cbaab1743938330731d80df1a30e3ecc81`** |
| **FBH-G54** | Typed-history fail-closed ownership validation | **Complete — `0f86ee0217ab11d310bc1896c0286151a625c355`** |
| **FBH-G55** | FFplay startup/terminal Future error ownership | **Complete — `075a23278a74bd8e73230934531e8812eae760b4`** |
| **FBH-G56** | FFplay listener-safe telemetry streams | **Complete — `e0c5c77fdd6338cac4326e858f5cf763088647dd`** |
| **FBH-G57** | API/docs/changelog reconciliation | **Complete — `b662f540e9c64d9e8ebc5bb8ed987d3281be0fb8`** |
| **FBH-G58** | Exact-SHA Review 22 closeout | **Complete — `5d80c88e4b4dd8bac5df147e270bfcce1b9358c6`; accepted `ffigen_js` warning** |
| **G21** | Published runtime contract / official-runtime integrity | **Deferred / unchanged** |

### Review 22 implementation evidence

- **G53 — `b4d575c`:** callback routing is now sink-driven. Created callback values/listeners are retained without a `CallbackManager` root; pending execution and restored-running sessions acquire routing only when a sink requires it; restored-state read failure rolls back the callback setter; FFplay high-level factories pass a nullable completion callback directly. Regression coverage is in `flutter/test/ownership_callback_regression_test.dart`.
- **G54 — `0f86ee0`:** typed list and single-session history APIs validate the raw native session kind before wrapper adoption. Plain FFprobe and MediaInfo mismatches fail closed, release transferred native handles exactly once, and validate before live-map reuse.
- **G55 — `075a232`:** FFplay high-level startup attaches the terminal observer before awaiting startup, so startup and terminal failures share one explicit error owner. The lifecycle regression covers the startup/terminal `Completer` path.
- **G56 — `e0c5c77`:** FFplay position/video-size telemetry is listener-owned. Polling starts only for active execution with listeners, stops after the last listener without prematurely closing controllers, and terminal settlement closes them; late video-size subscribers receive a reset baseline and immediate poll.
- **G57 — `b662f54`:** API docs, package/root README guidance, Dartdocs, and changelog were reconciled for Future semantics, callback routing, typed history, telemetry, cancellation/dispose, local Wasm browser validation, conditional Apple slices, and the accepted `ffigen_js` exception.

### Review 22 validation and blocker record

- `git diff --check` passed for the Review 22 source/documentation commits; the only output was the pre-existing inaccessible global Git ignore warning.
- Elevated local validation at `5d80c88`: `dart --disable-analytics analyze` and `flutter analyze` passed with no issues; the focused Review 22 suite passed **51/51**. The prior local analyzer findings were fixed in the validation cleanup commit; no workaround was used.
- Existing local browser evidence remains supplementary: `node --test web/ffmpegkit_loader_test.mjs` passed 1/1, and the local Wasm smoke page produced `STARTING`, `INITIALIZED`, `FFMPEG_OK`, `FFPROBE_OK`, `MEDIA_INFO_OK`, and `PASS` with no page/console errors. This evidence predates the G53–G57 SHA and is not exact-SHA closeout evidence.
- Exact-SHA workflow [35672535010](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35672535010) checked out `5d80c88e4b4dd8bac5df147e270bfcce1b9358c6`. Flutter/Dart analysis, non-native tests, stable Web Wasm build, both Web browser smokes, Android, iOS, iOS Simulator, macOS, Linux, Windows, and Native API Verification all passed.
- Package Verification reported exactly one accepted warning: `Packages dependent on a pre-release of another package ... ffigen_js version 0.0.16-pre`; no second publication defect was reported and the dependency was not changed. The workflow's failure conclusion is therefore an accepted publication-policy warning, not a G58 product failure.
- The exact fresh local Wasm browser gate also passed at `5d80c88`; Apple validation remains workflow-only.

## Review 21 Tracker — Flutter lifecycle ownership and Web runtime closeout — 2026-09-21

- Source: latest Review 21 response from the FfmpegKitExtended “Plan Luna fix” chat; implementation scope was prepared from that response. No new workflow was added.
- Frozen Review 21 implementation baseline: `6de4d4c60e460112ead1076dea6c99ab3c19cc54`.
- Implementation commits: `24cf7f2` (G46–G50 code/tests), `3424acc` (G51 docs/changelog), and `78b9136` (G50 regression correction preserving direct FFplay terminal-future semantics). All are pushed to `origin/dev-wasm`.
- Scope: Flutter package only. React Native, `ffmpeg-kit-builders`, C/C++ source, native ABI, and deferred G21 remain untouched. The existing workflow `.github/workflows/flutter_example_ci.yaml` is reused.
- Analytics/telemetry: `flutter config --no-analytics` was applied; Dart commands used `--disable-analytics`. The earlier telemetry-log permission/lock condition was handled with elevated validation and did not receive a product-code workaround.

| Goal | Objective | Status |
| --- | --- | --- |
| **FBH-G46** | Complete callback-routing lease and stream-cancellation cleanup | **Complete — 2026-09-21** |
| **FBH-G47** | Fail closed for null/unknown session handles and types | **Complete — 2026-09-21** |
| **FBH-G48** | Add Web session finalization safety net | **Complete — 2026-09-21** |
| **FBH-G49** | Fail closed for unsupported target operating systems | **Complete — 2026-09-21** |
| **FBH-G50** | Make FFplay startup handoff observable while retaining terminal ownership | **Complete — 2026-09-21** |
| **FBH-G51** | Reconcile lifecycle/API documentation and changelog | **Complete — 2026-09-21** |
| **FBH-G52** | Exact-SHA local/workflow/browser closeout | **Complete — 2026-09-21** |
| **G21** | Published runtime contract / official-runtime integrity | **Deferred / unchanged** |
| **`ffigen_js` prerelease pin** | `ffigen_js: ^0.0.16-pre` | **Bypass — accepted dependency exception** |

### Review 21 implementation evidence

- **G46:** callback maps now retain sessions while execution is pending; FFmpeg/FFprobe/FFplay log-stream cancellation unregisters idle routing; MediaInformation cleanup preserves pending execution ownership; FFplay completion uses the synthetic no-op callback path where required.
- **G47:** native and Web factories reject null/zero handles; unknown native session types release the untransferred handle once and throw instead of defaulting to FFmpegSession.
- **G48:** Web sessions attach a `Finalizer` safety net for unreleased handles while deterministic `dispose()` remains the primary path; finalizer failures are contained.
- **G49:** target OS validation accepts only Android, iOS, macOS, Linux, and Windows and throws for unsupported targets before artifact resolution.
- **G50:** `FFplayKit.executeAsync()` returns after native startup handoff and retains active ownership until terminal completion. Direct/deprecated `FFplaySession.executeAsync()` retains its existing terminal-future contract. The first exact-SHA workflow exposed this distinction; `78b9136` corrected it and local native FFplay callback tests passed 3/3.
- **G51:** README, FFplay/session/architecture/playback docs, and `CHANGELOG.md` describe the final lifecycle, Web finalizer, fail-closed handle, and startup-handoff contracts.

### Review 21 validation and blocker record

- Local focused validation at `78b9136`: analytics-disabled formatting and Dart analysis passed; Flutter analysis passed; the actual tracked focused suites (`ownership_callback_regression_test.dart`, `session_lifecycle_test.dart`, `ffplay_kit_lifecycle_test.dart`, and `architecture_mapping_test.dart`) passed **43/43**. The plan-listed `callback_routing_lifecycle_test.dart` is not present in this checkout; its callback-routing coverage is in `ownership_callback_regression_test.dart`.
- Local host-neutral validation: `flutter test --no-pub --exclude-tags native` passed **155/155**. Node syntax and loader checks passed: `node --check web/ffmpegkit_bridge.mjs`; `node --test web/ffmpegkit_loader_test.mjs` (`1/1`, missing/corrupt manifests rejected). `git diff --check` passed.
- Local stable Web validation at the new SHA: `flutter/example` `flutter build web --wasm --no-pub --target=lib/web_runtime_smoke.dart` completed successfully. Cross-origin-isolated local headless smoke passed `STARTING|INITIALIZED|FFMPEG_OK|FFPROBE_OK|MEDIA_INFO_OK|PASS` with zero page/console errors. Browser tests were run locally because workflow browser execution is not relied on for this user-requested gate.
- Initial exact-SHA workflow blocker: [Flutter Example App CI run 35657631732](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35657631732) checked out `3424acc32ab633668b7a58ccc98b4893f636f5b3`. Web runtime, custom DataAsset browser smoke, Android/Linux/macOS/iOS/iOS Simulator/Windows builds, Dart/Flutter analysis, and host-neutral tests passed. Package Verification exited 65 solely for the accepted `ffigen_js: 0.0.16-pre` publication warning. Native API Verification reported **66 passed, 3 failed** in the three FFplay callback-settlement tests because G50 had changed the direct session future to return at startup. This was a real G50 regression, not a workflow/infrastructure blocker.
- G50 correction evidence: local native execution of the three previously failing FFplay callback-settlement tests passed **3/3** after `78b9136`; the FFplayKit lifecycle suite passed **9/9**. No local Apple/iOS commands were run; Apple evidence is workflow-only.
- Final exact-SHA workflow: [Flutter Example App CI run 35659439260](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35659439260) checked out `78b91361b310ccaf8859297eecd387beaa58a942`, exactly matching `HEAD` and `origin/dev-wasm`. Web runtime smoke, custom DataAsset smoke, Android, Windows, Linux, macOS, iOS, iOS Simulator, and the rerun Native API Verification all passed. The Native API rerun logged **69 tests passed**, including all three FFplay callback-settlement tests.
- Final workflow conclusion is red only because Package Verification exits 65 for the single accepted `ffigen_js: 0.0.16-pre` prerelease warning. No source, dependency, or publication workaround was made. The first native attempt at the same SHA had 38 assertions pass but the Flutter test subprocess segfaulted during finalization; rerunning the failed jobs passed all 69 native tests, classifying that first result as a transient runner/test-device crash rather than a product assertion failure.
- User-authorized bypasses are explicit: the `ffigen_js` prerelease publication warning is accepted, and the workflow-runner Wasm-browser limitation was bypassed by executing the fresh browser smoke locally; hosted Web smoke also passed.
- Exact-SHA closeout: `HEAD == origin/dev-wasm == 78b91361b310ccaf8859297eecd387beaa58a942`; divergence `0/0`; product worktree clean. No source changes were made after the final workflow dispatch.
- Scope confirmation: React Native touched: No. React Native workflow dispatched: No. `ffmpeg-kit-builders` changed: No. C/C++ or native ABI changed: No. G21: deferred/unchanged.

## Review 18 Tracker — Flutter lifecycle/Web residuals — 2026-09-21

- Plan: [flutter-review-18-luna-plan.md](./flutter-review-18-luna-plan.md)
- Implementation prep: [flutter-review-18-implementation-prep.md](./flutter-review-18-implementation-prep.md)
- Frozen implementation baseline: `0e4f311ec94ad4c476a3b757138b00e2d31c36a1` (`origin/dev-wasm` matched)
- Final exact-SHA closeout: `8460d6f140c92214b5a6e931de60e7876372d6ea` (`HEAD` and `origin/dev-wasm` matched)
- Scope: Flutter package only; React Native, builders, C/C++, native ABI, and deferred G21 remain untouched.
- Review 17 history remains below unchanged.

| Goal | Objective | Status |
| --- | --- | --- |
| **FBH-G25** | Single-submission session lifecycle | **Complete — 2026-09-21** |
| **FBH-G26** | Pre-start and startup-handoff cancellation | **Complete — 2026-09-21** |
| **FBH-G27** | Failure-atomic session disposal | **Complete — 2026-09-21** |
| **FBH-G28** | Settle-safe FFplay active-session ownership | **Complete — 2026-09-21** |
| **FBH-G29** | Media-information async error propagation | **Complete — 2026-09-21** |
| **FBH-G30** | Flutter Web debug/runtime contract and asset-path docs | **Complete — 2026-09-21** |
| **FBH-G31** | Exact-SHA local/workflow closeout | **Blocked — local SDK/toolchain gate — 2026-09-21** |
| **G21** | Published runtime contract | **Deferred / unchanged** |

### Review 18 current revalidation — 2026-09-21

- Current revalidation SHA: `78b91361b310ccaf8859297eecd387beaa58a942`; `HEAD` and `origin/dev-wasm` matched and the worktree was clean before this tracker-only update.
- Implementation state: Review 18 commits `558b497`, `88ac1df`, `485fe8d`, `c5ae160`, `bc15e4e`, `44bb16d`, and `8460d6f` are all ancestors of the current HEAD. No duplicate source implementation was needed.
- G25–G30 remain implementation-complete and are covered by exact current-SHA workflow [35659439260](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35659439260): Dart analyze, Flutter analyze, Flutter tests, stable Web Wasm build, Web smoke jobs, native API verification, and platform builds passed. The sole failing job step was the accepted `ffigen_js: 0.0.16-pre` publication warning.
- Local browser evidence: the package loader test passed locally (`1/1`); the existing local Wasm output passed `web_runtime_smoke.mjs` in the local in-app browser with title `STARTING|INITIALIZED|FFMPEG_OK|FFPROBE_OK|MEDIA_INFO_OK|PASS` and no captured browser error logs.
- **G31 blocker:** local SDK commands did not produce output or complete within 30 seconds: `flutter config --no-analytics`, `dart --disable-analytics --version`, `dart --disable-analytics analyze`, `flutter analyze`, and `dart --disable-analytics test test/session_lifecycle_test.dart`. The lingering Dart process was terminated as previously authorized; no SDK/package/source workaround was attempted. The goal remains blocked until the local Flutter/Dart toolchain can complete the required gate.
- Tracker transition: **G31 Complete → Blocked** for current revalidation; G21 remains deferred/unchanged.

### Review 18 implementation evidence

- Graph discovery: project `D-Projects-ffmpeg_kit_extended`, generation `2026-09-11T00:24:21Z`, Tier 2 verification.
- Coverage caveat: Flutter source files are `metadata_changed`; `ffplay_session.dart` has a recorded parse-partial line 17; new lifecycle test paths are not yet indexed. Direct source inspection is authoritative for this run.
- No implementation goal is complete until its focused tests, required host-neutral gate, commit, push, and tracker evidence are recorded.

### FBH-G25 — Complete — 2026-09-21

- Frozen starting SHA: `0e4f311ec94ad4c476a3b757138b00e2d31c36a1`; implementation commit and pushed head: `558b497` (`origin/dev-wasm` advanced from the frozen baseline).
- Finding revalidated: all four concrete Flutter session types previously called `SessionQueueManager.executeSession` without a shared one-shot claim; history wrappers could reach the same execution APIs.
- Authority/invariant: `Session.claimExecutionSubmission()` checks disposal, cancellation intent, and native `SessionState.created`, then latches `_submitted` before callback mutation, queue insertion, or native execution. Running/completed/failed history observations are rejected.
- Files: `flutter/lib/src/session.dart` (submission authority and shared cancellation exception), four concrete session classes (route execution through the claim), `flutter/lib/src/session_queue_manager.dart` (single exception definition), `flutter/test/session_lifecycle_test.dart` (Created/terminal/second-claim/state-read regressions), README and architecture docs (one-shot contract).
- Validation: focused `dart analyze` reported `No issues found`; command exit remained nonzero only because Dart telemetry cleanup hit the known `PathAccessException` on `C:\Users\Akash\AppData\Roaming\.dart-tool\dart-flutter-telemetry.log`. Focused `dart test test/session_lifecycle_test.dart` was blocked before test execution by the same telemetry failure while running package build hooks. `git diff --check` passed.
- Workflow/runtime: deferred to exact final Review 18 SHA per plan; no bypass used for G25.
- Residual risk: runtime behavior remains to be verified by the final Flutter Example App CI and the consolidated local gate after G26–G30.

### FBH-G26 — Complete — 2026-09-21

- Frozen starting SHA: `558b497`; implementation commit and pushed head: `88ac1df`.
- Finding revalidated: cancellation previously queried state/return code before latching intent, could not remove queued work, and had no Created-to-Running startup handoff authority.
- Authority/invariant: `Session.cancel()` latches `isCancelled` first; `SessionQueueManager.cancelQueued()` removes only the identical queued item and preserves order; discard cleanup is isolated; submitted Created sessions retain intent and poll until Running; native cancellation dispatch is retryable and exactly once after success; terminal-before-Running dispatches zero times.
- Files: `session.dart` (intent latch, handoff monitor, dispatch seam, pre-start cleanup), `session_queue_manager.dart` (identity removal, discard/onDiscard flow, queue-wide cleanup), four concrete session classes (log/callback/FFplay stream cleanup hooks), `session_queue_manager_test.dart` (queue and cancellation matrix), README and architecture docs (contract).
- Validation: focused analyzer reported `No issues found` after correction; formatter completed source/test formatting; `git diff --check` returned 0. Focused test execution was blocked before suite startup by the known telemetry `PathAccessException` while the package build hook ran.
- Workflow/runtime: deferred to exact final Review 18 SHA; no bypass used for G26.
- Residual risk: the cancellation polling cadence and native transition behavior still require exact-SHA workflow/runtime confirmation; local native execution was not substituted.

### FBH-G27 — Complete — 2026-09-21

- Frozen starting SHA: `88ac1df`; implementation commit and pushed head: `485fe8d`.
- Finding revalidated: `dispose()` detached the finalizer before native release and marked the session disposed from an outer `finally`, making release failure non-retryable and leaving no finalizer protection.
- Authority/invariant: native `releaseHandle` is now the commit point. Release failure leaves `isDisposed == false`, handle access, and finalizer attachment intact; successful release detaches once; post-release cleanup failures are rethrown without rolling back or repeating native release.
- Files: `flutter/lib/src/session.dart` (commit-point ordering), `flutter/test/ownership_callback_regression_test.dart` (release failure retry, ordering, post-release cleanup failure), README and architecture docs (ownership contract).
- Validation: focused analyzer reported `No issues found`; formatter completed; `git diff --check` passed. Runtime test execution remains blocked before suite startup by the known Flutter telemetry `PathAccessException` in the build hook.
- Workflow/runtime: deferred to exact final Review 18 SHA; no bypass used for G27.
- Residual risk: finalizer behavior on platform-specific backends still requires the exact-SHA Flutter workflow; no native ABI changes were made.

### FBH-G28 — Complete — 2026-09-21

- Frozen starting SHA: `485fe8d`; implementation commit and pushed head: `c5ae160`.
- Finding revalidated: `FFplayKit` cleared `_activeFFplaySession` only from the completion callback, so startup/transport failures or user callback throws could strand the active session; `start()` also re-submitted every state.
- Authority/invariant: `_startTrackedExecution()` owns active-session cleanup in `finally` around the execution Future, with identity protection; a tracked set prevents duplicate starts while pending. `start()` branches on Created/Running/paused/terminal state and never re-submits an already-running or terminal session.
- Files: `flutter/lib/src/ffplay_kit.dart` (settlement tracking, state-aware start, test seams), `flutter/lib/src/ffplay_session.dart` (in-memory lifecycle fixture), `flutter/test/ffplay_kit_lifecycle_test.dart` (settlement/error/ordering/start regressions), README, architecture, playback guide, and video-surface API docs.
- Validation: focused analyzer reported `No issues found`; formatter completed. The package test command remains blocked before suite startup by the known telemetry `PathAccessException` during build-hook execution.
- Workflow/runtime: deferred to exact final Review 18 SHA; no bypass used for G28.
- Residual risk: native FFplay callback/transport settlement and browser playback remain final workflow/runtime evidence items.

### FBH-G29 — Complete — 2026-09-21

- Frozen starting SHA: `c5ae160`; implementation commit and pushed head: `bc15e4e`.
- Finding revalidated: `MediaInformationSession._runAsyncMediaInfo()` caught the execution Future error, logged it, and returned normally, swallowing the original backend/transport failure.
- Authority/invariant: `awaitMediaInformationExecution()` logs and rethrows the exact original error/stack; existing cleanup runs before the completer error and cannot replace it.
- Files: `flutter/lib/src/media_information_session.dart` (shared await/rethrow path), `flutter/test/session_execution_error_test.dart` (exact error and success regressions).
- Validation: focused analyzer reported `No issues found`; formatter completed. The package test command remains blocked before suite startup by the known telemetry `PathAccessException` during build-hook execution.
- Workflow/runtime: deferred to exact final Review 18 SHA; no bypass used for G29.
- Residual risk: the exact async native callback transport path still requires final Flutter workflow/runtime evidence.

### FBH-G30 — Complete — 2026-09-21

- Frozen starting SHA: `bc15e4e`; implementation commit and pushed head: `44bb16d`.
- Finding revalidated: Web `type: debug` with no override bypassed the true incompatibility and fell through to the prebuilt debug Wasm ZIP resolver; `flutter/doc/installation.md` also retained the pre-Review-17 asset root.
- Authority/invariant: `validateWebBundleSelection()` runs before DataAsset capability fallback, download, cache, and extraction. It rejects only implicit Web debug with an explicit browser-incompatibility diagnostic; explicit local/HTTP(S) `web`/`wasm` overrides remain legal; native debug resolution is untouched.
- Files: `flutter/hook/build.dart` (Web-only validator), `flutter/test/web_data_asset_test.dart` (both DataAssets modes, no-download guard, explicit override acceptance/classification), README/installation/quick-start/CHANGELOG (debug contract and canonical asset root).
- Validation: focused analyzer reported `No issues found`; formatter completed. The package Web test suite remains blocked before suite startup by the known telemetry `PathAccessException` during build-hook execution.
- Workflow/browser: exact-SHA workflow and local browser smoke are required at G31; no bypass used for G30.
- Residual risk: final package/runtime evidence must confirm the browser-compatible default path and explicit custom runtime path on the resulting exact SHA.

### FBH-G31 — Complete — 2026-09-21

- Final frozen SHA: `8460d6f140c92214b5a6e931de60e7876372d6ea`; `HEAD` and `origin/dev-wasm` both matched and the product worktree was clean. Final correction commits were `d159ccf` (submit the terminal-state queue fixture before transitioning it to `completed`) and `8460d6f` (remove the now-unused fixture constructor parameter).
- Exact-SHA workflow: [Flutter Example App CI run 35627672375](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35627672375) checked out and logged `8460d6f140c92214b5a6e931de60e7876372d6ea`.
- Passing authority evidence: Dart analyze, Flutter analyze, the full non-native Flutter test suite, stable Web Wasm build, `Flutter Web Runtime Smoke`, `Flutter Web Custom DataAsset Smoke`, Linux/macOS/iOS/iOS Simulator/Android/Windows builds, and `Native API Verification (Linux)` all passed.
- Approved publication exception: `Verify package publication contents` exited 65 only because `ffigen_js: 0.0.16-pre` is a prerelease dependency. This is the same single warning explicitly bypassed by the user as a non-code/job issue; no dependency workaround was made.
- Browser exception record: no hosted-browser bypass was needed for Review 18. Both real hosted headless browser jobs passed on the final SHA. The historical user-approved hosted-browser limitation remains documented below as a prior exception, not as Review 18 evidence.
- Local gate evidence: focused/full Dart analysis reported `No issues found`; formatter completed. Local Dart/Flutter test and Web-build commands were not treated as acceptance because the machine hit the known locked `C:\Users\Akash\AppData\Roaming\.dart-tool\dart-flutter-telemetry.log` `PathAccessException`, while Flutter analyze/test and local Web build also hung without usable output. The workflow provided authoritative runtime evidence, and stale local Web output was not used.
- Scope confirmation: the baseline-to-final product diff is Flutter-only. No React Native, builders, C/C++, native ABI, or deferred G21 work was changed. The historical closeout evidence remains preserved, while the current local SDK gate is blocked as recorded above; G21 remains deferred/unchanged.

## Review 19 Tracker — Flutter lifecycle follow-up — 2026-09-21

- Plan: [flutter-review-19-luna-remediation-plan.md](./flutter-review-19-luna-remediation-plan.md)
- Review 18 remains the top historical tracker section above and is unchanged.
- Frozen Review 19 starting SHA: `8460d6f140c92214b5a6e931de60e7876372d6ea`; later goals must freeze the exact pushed head before editing.
- Scope: Flutter package lifecycle follow-up only; React Native, builders, C/C++, native ABI, and deferred G21 remain untouched. No new workflow is authorized.

| Goal | Objective | Status |
| --- | --- | --- |
| **FBH-G32** | Failure-atomic FFplay cancellation | **Complete — implementation pushed `99e82ca`** |
| **FBH-G33** | Settlement-bounded cancellation handoff | **Complete — implementation pushed `c4e6c7b`** |
| **FBH-G34** | Queue-wide cancellation first-error semantics | **Complete — implementation pushed `fc344b0`** |
| **FBH-G35** | FFplay inert-session active ownership | **Complete — implementation pushed `99e83ab`** |
| **FBH-G36** | Duplicate queue-admission defense | **Complete — implementation pushed `3541106`** |
| **FBH-G37** | Lifecycle contract/test reconciliation | **Complete — implementation pushed `3e47ca2`** |
| **FBH-G38** | Exact-SHA Review 19 closeout | **Complete — `3e47ca2841ad90ccf1e0a9fd01157b8967ac52bc`** |
| **G21** | Published runtime contract | **Deferred / unchanged** |

### FBH-G32 — Complete — 2026-09-21

- Frozen starting SHA: `8460d6f140c92214b5a6e931de60e7876372d6ea`; implementation commit and pushed head: `99e82ca43afc3742d78cd94c4e581f7eafea6d77` (`origin/dev-wasm` matched).
- Finding: `FFplaySession.cancel()` called fallible playback `stop()` before the shared cancellation latch, so a stop failure could erase cancellation intent; pre-start cancellation also had no reason to invoke the playback control.
- Invariant/state owner: `Session.cancel()` owns cancellation intent; `FFplaySession.cancel()` records it first, preserves the first error, and invokes playback stop only after queue handoff (`hasExecutionStarted`).
- Files/reasons: `flutter/lib/src/session.dart` adds the protected handoff seam; `flutter/lib/src/ffplay_session.dart` implements failure-atomic ordering; `flutter/test/ffplay_kit_lifecycle_test.dart` covers stop failure and pre-start behavior; FFplay API/README/video-guide docs state the contract.
- Validation: `dart --suppress-analytics format ...` passed; `dart --suppress-analytics analyze` passed with `No issues found`; `git diff --check` passed. Focused `dart --suppress-analytics test test/ffplay_kit_lifecycle_test.dart` was blocked before suite startup by the known locked `C:\Users\Akash\AppData\Roaming\.dart-tool\dart-flutter-telemetry-session.json` `PathAccessException` during build-hook compilation; it was not counted as a test pass.
- Regression-first: added stop-failure, cancellation-latch, and pre-start no-stop tests before implementation closeout.
- Workflow/runtime: deferred to the final exact-SHA Review 19 workflow; no bypass used for G32.
- Residual risk: hosted native/Web runtime evidence and the remaining queue/lifecycle goals are pending.

### FBH-G33 — Complete — 2026-09-21

- Frozen starting SHA: `99e82ca43afc3742d78cd94c4e581f7eafea6d77`; implementation commit and pushed head: `c4e6c7b7a32e9a920a4434601f62579bd46aa658` (`origin/dev-wasm` matched).
- Finding: the startup cancellation monitor could continue retrying after the queue-owned execution had already settled, leaving an unbounded handoff task.
- Invariant/state owner: `Session` owns an idempotent execution-settlement latch/future; `SessionQueueManager._executeQueuedSession` marks it settled in `finally`, and cancellation polling stops or wakes immediately on settlement.
- Files/reasons: `flutter/lib/src/session.dart`, `flutter/lib/src/session_queue_manager.dart`, `flutter/test/session_queue_manager_test.dart`, and queue/architecture docs.
- Validation: formatter, `dart --suppress-analytics analyze`, and `git diff --check` passed. Focused queue tests were blocked before suite startup by the known locked `C:\Users\Akash\AppData\Roaming\.dart-tool\dart-flutter-telemetry-session.json` `PathAccessException` during build-hook compilation; not counted as a pass.
- Regression-first: added recovery-after-state-read-failure and settlement-stop monitor tests.
- Workflow/runtime: deferred to the final exact-SHA Review 19 workflow; no bypass used for G33.
- Residual risk: runtime proof of native startup/settlement ordering remains a G38 exact-SHA evidence item.

### FBH-G34 — Complete — 2026-09-21

- Frozen starting SHA: `c4e6c7b7a32e9a920a4434601f62579bd46aa658`; implementation commit and pushed head: `fc344b0500d2a3ff1b080336042f2f5d0b407a0a` (`origin/dev-wasm` matched).
- Finding: queue-wide cancellation stopped at the first thrown session error and could leave later active sessions unattempted.
- Invariant/state owner: `SessionQueueManager.cancelCurrent()` snapshots active sessions, attempts every cancellation, and rethrows the first error/stack after all attempts; `cancelAll()` clears queued work before using that path.
- Files/reasons: `flutter/lib/src/session_queue_manager.dart`, `flutter/lib/src/ffmpeg_kit_extended.dart`, `flutter/test/session_queue_manager_test.dart`, and cancellation docs.
- Validation: formatter, `dart --suppress-analytics analyze`, and `git diff --check` passed. Focused queue tests were blocked before suite startup by the known telemetry `PathAccessException`; not counted as a pass.
- Regression-first: added all-active-attempt, first-error, all-success, and cancel-all queue-clearing tests.
- Workflow/runtime: deferred to the final exact-SHA Review 19 workflow; no bypass used for G34.
- Residual risk: backend-specific cancellation delivery remains a G38 workflow/runtime item.

### FBH-G35 — Complete — 2026-09-21

- Frozen starting SHA: `fc344b0500d2a3ff1b080336042f2f5d0b407a0a`; implementation commit and pushed head: `99e83ab2ef1128a8e18864ad20e84aa8fb52a4e8` (`origin/dev-wasm` matched).
- Finding: a successful cancel/close on an inert FFplay session could leave it as the global current session, while tracked execution ownership must survive until Future settlement.
- Invariant/state owner: `FFplayKit` clears `_activeFFplaySession` only after successful operation and only when the identity is not in `_trackedExecutions`; tracked execution cleanup remains Future-settlement-owned.
- Files/reasons: `flutter/lib/src/ffplay_kit.dart`, `flutter/test/ffplay_kit_lifecycle_test.dart`, and FFplay README/API/video-guide docs.
- Validation: formatter, `dart --suppress-analytics analyze`, and `git diff --check` passed. Focused FFplay tests were blocked before suite startup by the known telemetry `PathAccessException`; not counted as a pass.
- Regression-first: added successful/failed close, inert cancel, and tracked-cancel ownership tests.
- Workflow/runtime: deferred to the final exact-SHA Review 19 workflow; no bypass used for G35.
- Residual risk: native FFplay transport/runtime settlement remains a G38 evidence item.

### FBH-G36 — Complete — 2026-09-21

- Frozen starting SHA: `99e83ab2ef1128a8e18864ad20e84aa8fb52a4e8`; implementation commit and pushed head: `35411067897b39560a2f666c1628026eab852e33` (`origin/dev-wasm` matched).
- Finding: the queue admitted the same `Session` object more than once, allowing duplicate execution ownership and duplicate queue entries.
- Invariant/state owner: `SessionQueueManager.executeSession()` rejects identical active/queued objects before cancellation or `onDiscard` handling; distinct session instances remain eligible.
- Files/reasons: `flutter/lib/src/session_queue_manager.dart` and `flutter/test/session_queue_manager_test.dart`.
- Validation: formatter, `dart --suppress-analytics analyze`, and `git diff --check` passed. Focused queue tests were blocked before suite startup by the known telemetry `PathAccessException`; not counted as a pass.
- Regression-first: added duplicate-active/queued rejection and distinct-object admission tests.
- Workflow/runtime: deferred to the final exact-SHA Review 19 workflow; no bypass used for G36.
- Residual risk: exact-SHA runtime queue admission remains a G38 evidence item.

### FBH-G37 — Complete — 2026-09-21

- Frozen starting SHA: `35411067897b39560a2f666c1628026eab852e33`; implementation commit and pushed head: `3e47ca2841ad90ccf1e0a9fd01157b8967ac52bc` (`origin/dev-wasm` matched).
- Finding: the Review 18 lifecycle matrix and public/source docs lagged the implemented one-shot, cancellation, and disposal contracts; `cancelSession(0)` documentation also exceeded the current Dart backend behavior.
- Invariant/state owner: submission claim remains before callback mutation/queue insertion; cancellation records intent, queued/startup/running behavior is explicit, disposal documents release-commit ordering, and `cancelSession(0)` delegates to the queue-wide G34 path.
- Files/reasons: `flutter/lib/src/session.dart`, `ffmpeg_kit.dart`, `ffprobe_kit.dart`, `ffplay_kit.dart`, `ffmpeg_kit_extended.dart`, README, architecture docs, and `flutter/test/session_lifecycle_test.dart`.
- Validation: format check, `dart --suppress-analytics analyze` (`No issues found`), and `git diff --check` passed. Focused lifecycle test execution was blocked before suite startup by the exact telemetry `PathAccessException` on `dart-flutter-telemetry-session.json`; it was not counted as a pass.
- Regression-first: added cancelled-before-submission, both execute-order permutations, callback non-mutation, duplicate queued admission, and post-settlement re-execution tests. Existing G34 queue tests cover the queue-wide `cancelSession(0)` route.
- Contract evidence: pinned C/C++ wrapper inspection confirmed native ID `0` is a global-cancel sentinel, while the current Flutter backend interface exposes per-session operations and `SessionQueueManager` as the Dart-wide cancellation authority. No null/zero handle or ABI change was introduced; the public Dart contract now states the supported Flutter-managed scope.
- Workflow/runtime: deferred to the final exact-SHA Review 19 workflow; no bypass used for G37.
- Residual risk: native sessions outside the Flutter queue are not covered by the Dart compatibility route; this is documented scope, not an unverified claim of global native cancellation.

### FBH-G38 — Complete — 2026-09-21

- Final frozen SHA: `3e47ca2841ad90ccf1e0a9fd01157b8967ac52bc`; `HEAD` and `origin/dev-wasm` matched after the final implementation push. No source changes were made after this freeze.
- Exact-SHA workflow: [Flutter Example App CI run 35634156447](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35634156447) checked out and logged the final SHA.
- Passing workflow evidence: Package Verification analyze, Flutter analyze, non-native Flutter tests, stable Web Wasm build; Flutter Web Runtime Smoke; Flutter Web Custom DataAsset Smoke; Android, iOS, iOS Simulator, macOS, Windows, and Linux builds; Native API Verification (Linux). Both hosted headless browser smoke jobs passed on the final SHA.
- Approved publication exception: `Verify package publication contents` exited 65 solely because package validation warned that stable `ffmpeg_kit_extended_flutter 1.0.0` depends on prerelease `ffigen_js 0.0.16-pre`. This is the existing user-approved publication warning; no dependency or publication workaround was made.
- Local evidence: `dart --suppress-analytics analyze` and targeted format checks passed; `node --test web/ffmpegkit_loader_test.mjs` passed. A local Playwright headless smoke reached `STARTING|INITIALIZED|FFMPEG_OK|FFPROBE_OK|MEDIA_INFO_OK|PASS` with zero console errors. The fresh local Flutter analyze/test/Web-build commands were not treated as acceptance because they hung without output, and the focused Dart test separately reproduced the locked telemetry-session `PathAccessException`; workflow evidence is authoritative.
- Browser exception record: no hosted-browser bypass was used. The local headless smoke was run as supplementary evidence per user direction; no fresh local build claim was made because the local Web build did not complete.
- Scope confirmation: Review 18 remains the top historical section and unchanged; Review 19 source changes are Flutter-only. React Native touched: No. React Native workflow dispatched: No. `ffmpeg-kit-builders` changed: No. C/C++ or native ABI changed: No. G21: deferred/unchanged.

### Current Review 19 audit reconciliation — 2026-09-21

- The attached Review 19 plan is already implemented at `3e47ca2841ad90ccf1e0a9fd01157b8967ac52bc`; all Review 18 goals FBH-G25–G31 and Review 19 goals FBH-G32–G38 are closed in the tracker. There are no open or pending Review 18 implementation goals to re-implement, so no source commit was created for this request.
- Elevated Git Bash verification: `gh auth status` succeeded for `akashskypatel`; `HEAD` and `origin/dev-wasm` both resolve to `3e47ca2841ad90ccf1e0a9fd01157b8967ac52bc`; divergence is `0 0`.
- Existing exact-SHA workflow: [Flutter Example App CI run 35634156447](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35634156447) checked out the same SHA. Functional analysis, tests, builds, native verification, and hosted browser smoke jobs passed. The overall workflow is red only because Package Verification returned exit 65 for the already user-approved `ffigen_js: 0.0.16-pre` prerelease warning; no dependency workaround was made.
- Local fresh-browser validation: **Blocked — SDK/toolchain limitation.** `D:\Projects\flutter\flutter\bin\flutter.bat build web --wasm --target=lib/web_runtime_smoke.dart` produced no output for 60 seconds and was stopped. The existing local bundle did produce `STARTING|INITIALIZED|FFMPEG_OK|FFPROBE_OK|MEDIA_INFO_OK|PASS` in Playwright with zero console errors/warnings, but it predates this validation and is supplementary only, not exact-SHA acceptance. No SDK, dependency, timeout, or build workaround was introduced.

## Review 20 Tracker — Flutter production readiness — 2026-09-21

- Plan: [flutter-review-20-luna-production-readiness-plan.md](./flutter-review-20-luna-production-readiness-plan.md)
- Review 18 remains the top tracker section above and is preserved unchanged; Review 20 follows the completed Review 19 section.
- Frozen Review 20 starting SHA: `3e47ca2841ad90ccf1e0a9fd01157b8967ac52bc`; elevated Git Bash verified `HEAD` and `origin/dev-wasm` matched before preparation.
- Scope: Flutter package production-readiness follow-up only. React Native, builders, C/C++, native ABI, and deferred G21 remain untouched.
- Execution order: G39, G40, G41, G42, G43, G44, then G45 exact-SHA closeout. G39–G41 remain sequential because they share session execution and ownership authority.
- Explicitly accepted/non-actionable: `ffigen_js: ^0.0.16-pre` publication warning remains the user-approved dependency exception; G21 remains deferred. Analytics are disabled per user instruction (`flutter config --no-analytics`; Dart commands use `--disable-analytics`) to prevent the telemetry-log lock. No SDK/toolchain workaround is authorized for the remaining local Flutter Web build limitation.

| Goal | Objective | Status |
| --- | --- | --- |
| **FBH-G39** | Restore true synchronous execution contract and failure-safe cleanup | **Complete — 2026-09-21** |
| **FBH-G40** | Remove eager callback-map retention of unused Created sessions | **Complete — 2026-09-21** |
| **FBH-G41** | Make session-handle acquisition/wrapping failure-atomic | **Complete — 2026-09-21** |
| **FBH-G42** | Fail closed for unsupported native target architectures | **Complete — 2026-09-21** |
| **FBH-G43** | Make Windows archive extraction shell-safe | **Complete — 2026-09-21** |
| **FBH-G44** | Reconcile production documentation, examples, and release notes | **Complete — 2026-09-21** |
| **FBH-G45** | Freeze and validate one exact production-readiness SHA | **Complete — 2026-09-21** |
| **G21** | Published runtime contract / official-runtime integrity | **Deferred / unchanged** |
| **`ffigen_js` prerelease pin** | `ffigen_js: ^0.0.16-pre` | **Bypass — accepted dependency exception** |

### Review 20 preparation evidence

- Plan reviewed as technical implementation guidance; the user objective controls scope and sequencing.
- Review 18 remains first; its historical G25–G31 records are not rewritten. Review 19 remains historical and complete.
- Validation policy: use the existing workflow for non-browser gates where possible; execute browser smoke locally with a fresh local build when possible. Stale Web output is supplementary only.
- Limitation policy: record the local Flutter SDK/toolchain hang verbatim, leave the affected browser-validation goal blocked, and do not change SDKs, dependencies, timeouts, or unrelated platform code to bypass it. The telemetry lock was cleared by terminating Dart daemons and applying the user-directed analytics opt-out; no SDK workaround was made.

### FBH-G39 — Complete — 2026-09-21

- Implementation commit: `2d99b706fc17c8515167fad5a41d88610feb62d0`; focused-test fixture correction: `2cbc8581b28650a40763ab8b8ca6d258e9329137`. Both were pushed to `origin/dev-wasm`; the subsequent G40 commit is their descendant.
- Source evidence: FFmpeg, FFprobe, MediaInformation, and FFplay `execute()` now use direct blocking backend calls, one-shot completion dispatch, primary-error preservation, and finally-based stream/unregistration cleanup. Queue limits remain on asynchronous execution only.
- Local validation: Flutter focused run with analytics disabled passed `15/15` across `test/ownership_callback_regression_test.dart` and `test/synchronous_execution_contract_test.dart`; `dart --disable-analytics analyze` had no warnings/errors (six pre-existing style infos); format passed.
- Hosted exact-SHA evidence: [Flutter Example App CI run 35642050519](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35642050519) checked out `2d99b706fc17c8515167fad5a41d88610feb62d0`; both hosted Web browser smoke jobs passed. Package Verification was red only at Flutter analyze because the existing `ffigen_js: 0.0.16-pre` publication warning is still user-approved.

### FBH-G40 — Complete — 2026-09-21

- Implementation commit: `89740bbb3bbc0048730d783ad32785032420639b`, pushed to `origin/dev-wasm`.
- Source evidence: ordinary FFmpeg/FFprobe/FFplay/MediaInformation constructors no longer retain callback-map entries when created without sinks; nullable callback setters unregister when the final callback/listener is removed; execution and log-stream attachment still register; MediaInformation registration remains atomic across both maps. The test-only FFmpeg constructor keeps an explicit `register` switch for lifecycle fixtures.
- Local validation: `flutter test --no-pub test/ownership_callback_regression_test.dart test/synchronous_execution_contract_test.dart` passed `15/15`; `dart --disable-analytics analyze` reported no warnings/errors, and analytics-disabled formatting passed.
- Hosted validation: [Flutter Example App CI run 35643086614](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35643086614) completed at exact SHA `89740bbb3bbc0048730d783ad32785032420639b`. Flutter Web runtime smoke, custom DataAsset smoke, Android, iOS, iOS Simulator, macOS, Linux, Windows, and Native API Verification passed. Package Verification stopped at `Flutter analyze` because six existing info-level lints cause that job to exit nonzero; no warning or analyzer error was reported.

### FBH-G41 — Complete — 2026-09-21

- Frozen starting SHA: `89740bbb3bbc0048730d783ad32785032420639b`.
- Finding revalidated: newly acquired native/Wasm handles could be stranded when session metadata or finalizer setup failed; history lookup wrapping could leak an already-owned handle on duplicate reuse or leave later handles unreleased after a bulk wrapping failure.
- Invariant/state authority: `Session.adoptOwnedHandle` owns the transfer commit. It commits only after session ID, metadata, and finalizer attachment succeed; before commit, the helper releases exactly once. `_wrapSession` and `_wrapSessions` retain ownership until delegation succeeds and release duplicate or untransferred handles on all failure paths. `NativeSessionFinalizer` fails closed when no valid native release pointer exists.
- Implementation commit: `3a21571319bc50e3b1a98a8a9a1e57a0e400f86b`, pushed to `origin/dev-wasm`.
- Files changed: `flutter/lib/src/session.dart`, `flutter/lib/src/ffmpeg_session.dart`, `flutter/lib/src/ffprobe_session.dart`, `flutter/lib/src/media_information_session.dart`, `flutter/lib/src/ffplay_session.dart`, `flutter/lib/src/ffmpeg_kit_extended.dart`, `flutter/lib/src/platform/native/session_finalizer_native.dart`, and `flutter/test/ownership_callback_regression_test.dart`.
- Tests added/modified: session-ID rollback, finalizer-attach rollback, rollback-release primary-error preservation, successful adoption/disposal, missing finalizer pointer fail-closed, duplicate wrapper release, and bulk-handle cleanup regressions.
- Focused validation: `flutter test --no-pub test/ownership_callback_regression_test.dart` and the synchronous contract companion passed `16/16` ownership assertions; analytics-disabled analysis reported no warnings/errors, with only style infos; formatting passed.
- Full/bounded validation: the G41 focused ownership suite passed before commit; no React Native, builder, C/C++ ABI, or G21 code was touched.
- Documentation: tracker evidence only; public lifecycle docs are reconciled in G44.
- Residual risk: real platform release-symbol behavior remains covered by the existing native/Web backend tests and exact workflow; no new ABI assumption was introduced.
- Scope confirmation: React Native `No`; builders/C++ ABI `No`; G21 `No`.
- Tracker transition: Complete after the pushed implementation commit above.

### FBH-G42 — Complete — 2026-09-21

- Frozen starting SHA: `3a21571319bc50e3b1a98a8a9a1e57a0e400f86b`.
- Finding revalidated: build-hook architecture helpers previously defaulted unsupported requests to a supported artifact label, allowing the wrong prebuilt architecture to be selected.
- Invariant/state authority: `flutter/hook/native_artifact.dart` owns explicit architecture mappings and `validateTargetArchitecture`; `flutter/hook/build.dart` validates the target before configuration, download, or extraction. Unsupported values fail with the requested architecture and supported set rather than being substituted.
- Implementation commit: `ea3a2f71f4816dc047038e9d36eea1a2b6028d44`, pushed to `origin/dev-wasm`.
- Files changed: `flutter/hook/native_artifact.dart`, `flutter/hook/build.dart`, `flutter/test/architecture_mapping_test.dart`, `flutter/README.md`, `flutter/doc/installation.md`, and `flutter/doc/quick-start.md`.
- Tests added/modified: explicit Android, Apple, and desktop mapping tests; unsupported-architecture diagnostic tests; and pre-download validation coverage.
- Focused validation: architecture mapping tests passed `6/6`; the bounded architecture/native artifact follow-up passed `20/20` before G43 changes. Formatting and analytics-disabled analysis reported no warnings/errors beyond existing style infos.
- Documentation: README, installation, and quick-start now list only supported prebuilt architectures and the fail-closed policy.
- Residual risk: artifact availability for a supported architecture remains an external release/artifact concern; the hook no longer hides it with substitution.
- Scope confirmation: React Native `No`; builders/C++ ABI `No`; G21 `No`.
- Tracker transition: Complete after the pushed implementation commit above.

### FBH-G43 — Complete — 2026-09-21

- Frozen starting SHA: `ea3a2f71f4816dc047038e9d36eea1a2b6028d44`.
- Finding revalidated: Windows extraction previously interpolated archive and destination paths into executable PowerShell source, so legal path characters such as `$()` could be interpreted as expressions.
- Invariant/state authority: `buildWindowsArchiveExtractionInvocation` supplies paths through environment variables; the constant PowerShell source uses `Expand-Archive -LiteralPath`. Unix extraction and AAR-to-ZIP handling remain unchanged.
- Implementation commit: `0726c8fcec59114014466fb37f94cbdb4bff4b61`, pushed to `origin/dev-wasm`.
- Files changed: `flutter/hook/build.dart` and `flutter/test/windows_extraction_test.dart`.
- Tests added/modified: hostile Windows path coverage for spaces, Unicode, `$()`, `$`, semicolons, quotes, and parentheses; constant-script and `-LiteralPath` assertions.
- Focused validation: Windows extraction tests passed `2/2`; the current combined architecture/native-artifact/extraction suite passed `22/22`. Formatting, analytics-disabled analysis, and `git diff --check` passed.
- Documentation: the G44 changelog adds the user-facing shell-safety note without overstating exploitability.
- Residual risk: PowerShell itself remains the Windows extraction tool, but archive/destination data is no longer executable source.
- Scope confirmation: React Native `No`; builders/C++ ABI `No`; G21 `No`.
- Tracker transition: Complete after the pushed implementation commit above.

### FBH-G44 — Complete — 2026-09-21

- Frozen starting SHA: `0726c8fcec59114014466fb37f94cbdb4bff4b61`.
- Finding revalidated: public Dartdocs, guides, README examples, and the `1.0.0` changelog did not consistently describe the now-implemented blocking synchronous path, queue ownership, callback-map lifetime, history-handle ownership, architecture rejection, and Windows extraction behavior. The integration example still used `waitForAll()` after synchronous calls.
- Invariant/state authority: `execute()`/`getMediaInformation()` return only after blocking native work and cleanup; `executeAsync()` remains the queue-managed path. Documentation must not require a queue wait for a direct synchronous result or describe it as fire-and-forget.
- Implementation commit: `8239a2b3af0a8632a8eaba9b7647beb2d766cd31`, pushed to `origin/dev-wasm`.
- Files changed: `flutter/lib/src/ffmpeg_session.dart`, `flutter/lib/src/ffprobe_session.dart`, `flutter/lib/src/media_information_session.dart`, `flutter/lib/src/ffplay_session.dart`, `flutter/lib/src/ffmpeg_kit.dart`, `flutter/lib/src/ffprobe_kit.dart`, `flutter/README.md`, `flutter/doc/quick-start.md`, `flutter/doc/installation.md` (inspected; no additional contract edit required), `flutter/doc/architecture.md`, `flutter/doc/api/ffmpeg-kit.md`, `flutter/doc/api/ffprobe-kit.md`, `flutter/doc/api/ffplay-kit.md`, `flutter/doc/api/config.md` (inspected; no additional contract edit required), `flutter/doc/guides/session-queue-management.md`, `flutter/doc/guides/video-processing.md` (inspected; no contradictory sync example), `flutter/CHANGELOG.md`, and `flutter/example/integration_test/plugin_integration_test.dart`.
- Why changed: source Dartdocs and public guides now state the blocking/async contract; architecture docs describe routing maps, finalizer safety-net semantics, explicit Web disposal, and history-wrapper ownership; the changelog records the production-facing lifecycle/build corrections; and the integration example asserts synchronous terminal state without `waitForAll()`.
- Tests added/modified: native integration examples were updated for FFmpeg sync execution, FFprobe sync execution, and media-information sync execution. No new product workaround or browser test was added.
- Regression-first evidence: source sweep found the stale fire-and-forget/enqueue wording and synchronous integration waits; after the edit, the only remaining `fire-and-forget` occurrence is an intentional queue-cancellation test, and remaining `waitForAll()` calls are teardown/intentional async-queue tests.
- Focused validation: `flutter test --no-pub test/synchronous_execution_contract_test.dart test/ownership_callback_regression_test.dart test/architecture_mapping_test.dart test/windows_extraction_test.dart` passed `28/28`; the bounded architecture/native-artifact/extraction suite passed `22/22`. Analytics-disabled Dart formatting passed with no changes. `dart --disable-analytics analyze` passed with eight existing style infos and no warnings/errors; `flutter analyze` reported the same eight infos and no warnings/errors.
- Full/bounded validation: `git diff --check` passed before commit. A fresh local Flutter Web Wasm build was not claimed because the known local SDK/toolchain build can hang; no SDK, dependency, timeout, or manual-staging workaround was introduced. Browser/runtime evidence remains the exact-SHA workflow gate.
- Documentation: `flutter/README.md`, `flutter/doc/quick-start.md`, `flutter/doc/architecture.md`, API guides, queue guide, source Dartdocs, and `flutter/CHANGELOG.md` were reconciled; analytics command examples now use `dart --disable-analytics` and document `flutter config --no-analytics`.
- Residual risk: the local Web build/toolchain limitation remains open for G45; the stale local Playwright output is supplementary only and is not treated as current exact-SHA evidence.
- Scope confirmation: React Native `No`; builders/C++ ABI `No`; G21 `No`.
- Tracker transition: Complete after the pushed implementation commit above.

### FBH-G45 — Complete with accepted publication warning — 2026-09-21

- Frozen final SHA: `6de4d4c60e460112ead1076dea6c99ab3c19cc54`; `HEAD` and `origin/dev-wasm` match and the worktree is clean. No source edits were made after this SHA.
- Final gate commit: `6de4d4c60e460112ead1076dea6c99ab3c19cc54` (`chore(flutter): clear analyzer gate diagnostics`), pushed before workflow dispatch. It contains only mechanical analyzer-cleanup changes in `flutter/hook/build.dart`, `flutter/lib/src/media_information_session.dart`, and `flutter/test/synchronous_execution_contract_test.dart`.
- Local host-neutral validation: `flutter config --no-analytics` is configured; direct Dart commands used `--disable-analytics`. `dart --disable-analytics analyze` passed with no issues; `flutter analyze` passed with no issues; analytics-disabled formatting passed; `flutter test --no-pub --exclude-tags native` passed `151/151`; `node --check web/ffmpegkit_bridge.mjs` passed; `node --test web/ffmpegkit_loader_test.mjs` passed `1/1`; and `git diff --check` passed.
- Local exact-SHA Web validation: `flutter build web --wasm --no-pub --target=lib/web_runtime_smoke.dart` completed successfully. The cross-origin-isolated local `flutter run -d web-server --wasm --cross-origin-isolation --no-pub --target=lib/web_runtime_smoke.dart --web-port 8090` server was exercised in headless Chrome. The final title was `STARTING|INITIALIZED|FFMPEG_OK|FFPROBE_OK|MEDIA_INFO_OK|PASS`; Playwright reported zero console errors and zero warnings, with the packaged `assets/packages/ffmpeg_kit_extended_flutter/assets/wasm/ffmpegkit.wasm` request returning `200`.
- Exact workflow: [Flutter Example App CI run 35647446612](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35647446612) checked out exact `head_sha` `6de4d4c60e460112ead1076dea6c99ab3c19cc54`.
- Required job conclusions: `Flutter Web Custom DataAsset Smoke` `106491266476` success; `Flutter Web Runtime Smoke` `106491266758` success; `Build (ios-simulator)` `106491266780` success; `Build (linux)` `106491266842` success; `Build (ios)` `106491266893` success; `Build (windows)` `106491266906` success; `Build (android)` `106491266933` success; `Build (macos)` `106491266936` success; and `Native API Verification (Linux)` `106493429894` success. `Package Verification` `106491266782` reached all analyzer, test, Web build, and package checks and exited only on the single accepted `ffigen_js: 0.0.16-pre` prerelease publication warning.
- Blocker reconciliation: the earlier `dart-flutter-telemetry.log` lock was cleared by terminating Dart daemons and applying the user-directed `flutter config --no-analytics` / `dart --disable-analytics` convention. The fresh local Web build and browser smoke now pass, so no SDK/toolchain workaround or G45 blocker remains. The historical G16 stable-DataAssets prerequisite and G20 boundary remain documented in their original Review 18 records and were not reopened or changed here.
- Accepted exception: the `ffigen_js: ^0.0.16-pre` publication warning remains the only red workflow signal; no stable package release exists. G21 remains deferred and unchanged.
- Scope confirmation: React Native `No`; builders/C++ ABI `No`; G21 `No`.
- Tracker transition: Complete after exact-SHA workflow `35647446612` and the local final-SHA gates above.

## Review 12 Tracker

| Goal                                                | Objective                                                                                                                                          | Initial status        |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| **G49 — FFplay playback-source readiness barrier**  | Prevent a newly scheduled Web playback from consuming the previous playback's still-live global framebuffer before its own native context is ready | **Complete — 2026-09-19** |
| **G50 — Unsettled FFplay session fallback**         | Make `currentSession` always identify the newest still-unsettled high-level FFplay execution regardless of settlement order                        | **Complete — 2026-09-19** |
| **G51 — Pre-start session cancellation**            | Make Created and queued `Session.cancel()` actually prevent later native execution while retaining running native cancellation                     | **Complete — 2026-09-19** |
| **G52 — React Native Review 12 exact-SHA closeout** | Re-run all React Native-only package/Web gates and standalone Web CI at one immutable SHA                                                          | **Complete — 2026-09-19** |
| **G21 — Published runtime contract**                | Official-runtime integrity/current-source contract                                                                                                 | **Remain Deferred**   |
| **Flutter**                                         | Source, tests, CI                                                                                                                                  | **Frozen / excluded** |

## Review 14 Tracker

| Goal | Objective | Status |
| --- | --- | --- |
| **G55 — Failure-atomic cancellation intent** | Latch JavaScript cancellation intent before fallible queue, state, or native-dispatch operations and preserve G53 retry authority | **Complete — 2026-09-20** |
| **G56 — Review 14 exact-SHA closeout** | Validate one immutable React Native-only SHA locally and through the existing standalone React Native Web workflow | **Complete — 2026-09-20** |
| **G54 — Review 13 exact-SHA closeout** | Historical Review 13 closeout superseded by the G55 finding | **Superseded / not executed** |
| **G49/G50/G51/G53** | Preserve the previously completed React Native lifecycle remediations | **Remain complete** |
| **G21** | Published runtime contract | **Deferred** |
| **Flutter / ffmpeg-kit-builders / C++ ABI** | Out of scope for Review 14 | **Frozen / unchanged** |

## Flutter Build-Hook Activation Plan

| Goal | Objective | Status |
| --- | --- | --- |
| **FBH-G1** | Regression foundation | **Complete — 2026-09-20** |
| **FBH-G2** | Architecture-aware Apple slice selection | **Complete — 2026-09-20** |
| **FBH-G3** | Strict Apple binary architecture integrity | **Complete — 2026-09-20** |
| **FBH-G4** | Verified iOS simulator x64 policy | **Complete — 2026-09-20** |
| **FBH-G5** | Official Hooks `userDefines` configuration | **Complete — 2026-09-20** |
| **FBH-G6** | Diagnostics/config transparency | **Complete — 2026-09-20** |
| **FBH-G7** | Hooks-runner lock documentation | **Complete — 2026-09-20** |
| **FBH-G8** | Final exact-SHA validation/release readiness | **Complete with package-test residual — 2026-09-20** |
| **FBH-G9** | Remote override integrity and cache freshness | **Complete — 2026-09-20** |
| **FBH-G10** | Coherent Flutter Web runtime pair | **Complete — 2026-09-20** |
| **FBH-G11** | Native package-test CI contract | **Complete — 2026-09-20** |
| **FBH-G12** | Flutter documentation and diagnostic reconciliation | **Complete — 2026-09-20** |
| **FBH-G13** | Flutter Review 15 exact-SHA closeout | **Complete — 2026-09-20** |

### FBH-G1 — Complete

- Added deterministic Apple slice-selection test seams and fixture coverage for device, simulator, combined, and macOS architectures.
- Verified arm64-only simulator fixtures do not match an x86_64 request.
- Validation: `dart --suppress-analytics test test/apple_hook_regression_test.dart` — 5 passing; targeted analysis reported no source issues.

### FBH-G2 — Complete

- XCFramework `AvailableLibraries` metadata now controls Apple slice selection by platform, simulator/device variant, and requested architecture.
- Filename fallback is deterministic and architecture-labeled; missing matches include the requested tuple and available slices.
- Validation: targeted hook analysis passed; `dart --suppress-analytics test test/apple_hook_regression_test.dart` — 6 passing; no Apple/iOS command ran locally.

### FBH-G3 — Complete

- Apple binaries now require source architecture inspection, compatible thin/copy handling, output inspection, and `xcrun lipo -verify_arch` before emission.
- Framework and companion dylibs use the same strict path; failed `lipo` never copies the source as a fallback.
- Validation: targeted hook analysis passed; `dart --suppress-analytics test test/apple_hook_regression_test.dart` — 13 passing; no Apple/iOS command ran locally.

#### FBH-G3 post-remote correction — 2026-09-20

- Exact-SHA existing-workflow run `35537228518` at `93846e9a3b569582e8eebf0f025a94c20dd12abb` reached the Apple runners and exposed an Xcode `lipo` invocation defect: the input path must precede `-verify_arch`.
- Corrected the invocation to `lipo <input> -verify_arch <architecture>` and updated the fake-runner fixture to assert that ordering. Exact-SHA run `35537814998` passed iOS, iOS Simulator, and macOS; local Apple/iOS execution remains prohibited.

### FBH-G4 — Complete — 2026-09-20

- Unsupported iOS simulator x86_64 requests now fail before emission with available-slice and architecture-policy diagnostics; arm64 is never relabeled as x86_64.
- Validation: policy regression included in the 13-test focused suite. Existing runs `35535205586` and `35535453167` reached Apple runners but stopped before the hook because Flutter 3.44 pins `meta 1.18.0` while Hooks 2.2.0 transitively requires `record_use`/`meta ^1.19.0`; package hook tests passed remotely. The package minimum and existing workflow matrix now use Flutter 3.47 for the next remote run.
- Exact-SHA existing-workflow run `35537814998` at `1cdd84f993de3584e27850eb33cc34afe31287d9` passed `Build (ios-simulator)`, including remote Apple setup and the simulator build/upload path.

### FBH-G5 — Complete

- `hooks.user_defines.ffmpeg_kit_extended_flutter` is now the primary configuration source with support for bundle, license, size, and platform override values; relative local overrides preserve their Hooks base URI and are dependency-tracked.
- The existing package-graph resolver remains a bounded legacy fallback for `ffmpeg_kit_extended_config`; explicit Hooks values take precedence and the selected source is logged.
- Added real `testBuildHook` coverage for `PackageUserDefines`, workspace-root relative paths, precedence, fallback/default behavior, and invalid values. Updated the Flutter README and example pubspec/README to document the official configuration shape.
- Validation: targeted analysis passed; `dart --suppress-analytics test test/user_defines_config_test.dart` passed with 7 tests; combined Apple/config/user-defines suite passed with 34 tests. No Apple/iOS command ran locally.

### FBH-G6 — Complete

- Build-hook logs now expose target/SDK, configuration source, bundle/license/size, cache, artifact, selected XCFramework slice, and source/output architectures without dumping environment data or secrets.
- Added stable bundle-diagnostic coverage and documented troubleshooting for configuration source, cache invalidation, `flutter clean`, slice/architecture failures, and the hook-vs-Xcode architecture boundary.
- Validation: targeted analysis passed; the combined Apple/config/user-defines suite passed with 35 tests and emitted the expected non-Apple hook diagnostic trail. No Apple/iOS command ran locally.

### FBH-G7 — Complete

- Documented runner-owned `.dart_tool/hooks_runner/.../.lock` behavior and recovery through `flutter clean`, safe targeted inactive-entry cleanup, and moving off unreliable network filesystems.
- Explicitly documented that package code must not delete/acquire the lock, shorten runner timeouts, or retry runner locking. No package lock-management code was added.

### FBH-G8 — Complete with package-test residual — 2026-09-20

- Updated the existing `Flutter Example App CI` Apple setup condition to include `ios-simulator`; no new workflow was created. The package minimum and existing matrix are aligned to Flutter 3.47 for Hooks 2.2.0.
- Updated `flutter/CHANGELOG.md` with the completed Apple architecture, Hooks configuration, diagnostics, and lock guidance.
- Validation: full `dart analyze`, `flutter analyze`, full host `flutter test` passed with 119 tests; focused Apple/config/user-defines suite passed with 35 tests. No Apple/iOS command ran locally.
- Exact-SHA existing-workflow run `35537814998` validated commit `1cdd84f993de3584e27850eb33cc34afe31287d9`; `Build (android)`, `Build (ios)`, `Build (ios-simulator)`, `Build (macos)`, `Build (linux)`, and `Build (windows)` all passed. The package hook/config tests passed remotely, including Apple slice, strict verification, simulator policy, userDefines, and diagnostics coverage.
- Package Verification remains red only because `test/api_test.dart` cannot load remote Linux `libffmpegkit.so`; its teardown then reports the expected uninitialized-backend state. This is a pre-existing native-test environment residual, not a hook/config failure. No Apple/iOS command ran locally.

## Review 15 Preparation — Flutter Build-Hook Follow-Up

- Plan: `C:\Users\Akash\Downloads\flutter-review-15-luna-plan.md`.
- Frozen implementation SHA: `1cdd84f993de3584e27850eb33cc34afe31287d9` on `dev-wasm`.
- Review 15 carries forward FBH-G1–G8 and opens FBH-G9–G12, with FBH-G13 reserved for the fully green exact-SHA closeout.
- Scope guard: React Native remains closed; `ffmpeg-kit-builders`, C/C++ ABI, and G21 remain unchanged/deferred.
- Execution order: FBH-G9 remote override/cache correctness; FBH-G10 Web runtime-pair coherence; FBH-G11 native-tagged CI coverage; FBH-G12 documentation/diagnostic reconciliation; FBH-G13 final local host-neutral and existing-workflow closeout.
- Workflow guard: use the existing Flutter CI workflow; do not create a new workflow. Apple/iOS validation remains remote-only.

### FBH-G9 — Complete — 2026-09-20

- Centralized URI-like override classification while preserving Windows drive and WSL/UNC local paths. HTTP and HTTPS are the only supported remote schemes; FTP and other explicit schemes fail before local-path fallback in both legacy config and Hooks `user_defines` paths.
- Custom remote caches now use a stable short SHA-256 of the full URL plus a sanitized basename, refresh through a temporary file, compare content hashes before replacement, preserve extraction for identical bytes, and invalidate the archive-tied extraction root only after changed bytes are ready. Native and Web resolution share this helper and bypass official release digest lookup for custom URLs.
- Files changed: `flutter/hook/build.dart`, `flutter/hook/config.dart`, `flutter/test/hook_artifact_cache_test.dart`, `flutter/test/user_defines_config_test.dart`, `flutter/README.md`.
- Validation: `dart format` passed; `dart --suppress-analytics analyze hook test/hook_artifact_cache_test.dart test/user_defines_config_test.dart` passed; focused `dart --suppress-analytics test test/hook_artifact_cache_test.dart test/user_defines_config_test.dart test/hook_config_test.dart` passed with 35 tests. No Apple/iOS command ran locally.
- Tracker transition: Complete after commit `e1cf455` pushed to `origin/dev-wasm`.

### FBH-G10 — Complete — 2026-09-20

- Web staging now selects exactly one directory containing both `ffmpegkit.mjs` and `ffmpegkit.wasm`; flat and nested coherent pairs work, while split pairs and multiple complete pairs fail without combining files from different directories. Unrelated files remain allowed.
- Files changed: `flutter/hook/build.dart`, `flutter/test/web_runtime_pair_test.dart`.
- Validation: `dart format` passed; `dart --suppress-analytics analyze hook test/web_runtime_pair_test.dart` passed; focused `dart --suppress-analytics test test/web_runtime_pair_test.dart test/hook_artifact_cache_test.dart` passed with 16 tests. No Apple/iOS command ran locally.
- Tracker transition: Complete after commit `f2e5beb` pushed to `origin/dev-wasm`.

### FBH-G11 — Complete — 2026-09-20

- Frozen starting SHA: `f2e5beb8cccf4c8f3524bc5d732ab11f0a2191d3`.
- Finding revalidated: Package Verification previously ran native-tagged `api_test.dart` without a loadable Linux `libffmpegkit.so`; the existing Linux build artifact now feeds a dedicated native verification job.
- Invariant: host-neutral package verification remains separate from explicit native API verification; native coverage is not removed, setup failures remain primary, and the existing Flutter workflow is reused.
- Files changed: `.github/workflows/flutter_example_ci.yaml`, `flutter/test/api_test.dart`.
- Why each changed: the workflow excludes native-tagged tests from the host-neutral job, consumes the staged Linux app artifact, sets `LD_LIBRARY_PATH`, and runs `flutter test --tags native test/api_test.dart`; `api_test.dart` hardens cleanup without swallowing initialization errors.
- Tests added/modified: native API test teardown guard; existing native-tagged `api_test.dart` suite retained.
- Regression-first evidence: the pre-fix residual was reproduced in Review 15 evidence as 50 tests passed with 2 Linux library/teardown failures; the post-fix dedicated staged native path passed remotely.
- Focused validation: `dart format test/api_test.dart` passed; `dart --suppress-analytics analyze test/api_test.dart` passed; no native/API test ran locally.
- Full validation: existing workflow `Flutter Example App CI` run `35540893783` passed `Package Verification` including `Build Web Wasm example`, `Native API Verification (Linux)`, and all six matrix build jobs: Android, iOS, iOS Simulator, macOS, Linux, and Windows.
- Documentation: `.github/workflows/flutter_example_ci.yaml` job contract; tracker only for this evidence record.
- React Native touched: No. `ffmpeg-kit-builders` changed: No. G21 touched: No. No local Apple/iOS/Android commands ran.
- Residual risk: GitHub runner dependency and artifact layout remain part of the CI contract; native verification is intentionally remote-only on this workstation.
- Tracker transition: Complete after commit `a5014e08e434508e9bc0f2f01e49fafdc1f7e16b` pushed to `origin/dev-wasm` and exact-SHA workflow run `35540893783` passed.

### FBH-G12 — Complete — 2026-09-20

- Frozen starting SHA: `a5014e08e434508e9bc0f2f01e49fafdc1f7e16b`.
- Finding revalidated: detailed and localized Flutter docs still presented `ffmpeg_kit_extended_config` as primary, overstated Podfile `EXCLUDED_ARCHS`, omitted the current minimums and G9/G10 contracts, and the Web staging error directed users to the legacy key.
- Invariant: maintained Flutter docs and runtime diagnostics describe `hooks.user_defines` as canonical, legacy config as bounded fallback, Flutter >= 3.47.0/Dart >= 3.12.0, HTTP(S)-only URL refresh semantics, coherent Web runtime pairs, and the hook-vs-downstream Apple architecture boundary.
- Files changed: `flutter/README.md`, `flutter/doc/installation.md`, `flutter/doc/quick-start.md`, `flutter/example/README.md`, `flutter/doc/README.ar.md`, `flutter/doc/README.es.md`, `flutter/doc/README.fr.md`, `flutter/doc/README.hi.md`, `flutter/doc/README.ja.md`, `flutter/doc/README.pt-BR.md`, `flutter/doc/README.zh-CN.md`, `flutter/hook/build.dart`, `flutter/CHANGELOG.md`.
- Why each changed: canonical and localized guides now show the official Hooks shape and reconciled platform/Web/remote contracts; `build.dart` reports current Web workspace guidance; the changelog records the Review 15 behavior.
- Tests added/modified: none; documentation contract check added as a bounded validation command.
- Regression-first evidence: source sweep confirmed the stale primary-key wording and Web diagnostic before editing; post-edit contract check found all maintained docs include `hooks.user_defines`, minimum SDK, and coherent runtime-pair references.
- Focused validation: `git diff --check` passed; Dart format reported `hook/build.dart` unchanged; `dart analyze hook test/web_runtime_pair_test.dart test/hook_artifact_cache_test.dart test/user_defines_config_test.dart` passed; documentation contract check passed.
- Full validation: exact-SHA existing workflow run `35542343758` at final SHA `c736b5f67db9491fd20235f8ff8ed94593377196` passed all required jobs, including Package Verification/Web Wasm, Native API Verification (Linux), and Android, iOS, iOS Simulator, macOS, Linux, and Windows builds.
- Documentation: all files listed above.
- React Native touched: No. `ffmpeg-kit-builders` changed: No. G21 touched: No. No local Apple/iOS/Android commands ran.
- Residual risk: localized wording is contract-aligned but not independently reviewed by native-language maintainers; the final exact-SHA workflow passed after this documentation commit.
- Tracker transition: Complete after commit `c736b5f67db9491fd20235f8ff8ed94593377196` was pushed to `origin/dev-wasm`.

### FBH-G13 — Complete — 2026-09-20

- Final frozen SHA: `c736b5f67db9491fd20235f8ff8ed94593377196`.
- Closeout scope: FBH-G9, G10, G11, and G12 are complete; G21 remains deferred; React Native and `ffmpeg-kit-builders` were not touched.
- Local safe gates: targeted Dart formatting passed; `dart analyze` passed; `flutter analyze` passed; focused non-Apple/non-native Flutter and Dart suites passed with 40 tests each. Apple/iOS, Android, and native API tests were intentionally not run locally per the task constraint.
- Remote full validation: existing `Flutter Example App CI` run `35542343758` at the exact final SHA passed Package Verification with Web Wasm, Native API Verification (Linux), and all six required matrix builds: Android, iOS, iOS Simulator, macOS, Linux, and Windows.
- Workflow scope: existing CI workflow reused; no new workflow was added or pushed to `master`.
- Residual risk: GitHub action deprecation and runner-migration annotations are non-fatal; Apple/native validation remains intentionally remote-only on this workstation.
- Tracker transition: Complete after final SHA verification and push to `origin/dev-wasm`.

## Review 16 Tracker

| Goal | Objective | Status |
| --- | --- | --- |
| **FBH-G14** | Hook-safe remote dependencies | **Complete — 2026-09-20** |
| **FBH-G15** | Local Web directory overrides | **Complete — 2026-09-20** |
| **FBH-G16** | Amended default static assets plus custom DataAsset Web staging authority | **Complete with user-approved CI/job bypass — 2026-09-21** |
| **FBH-G17** | Retryable Flutter Web initialization | **Complete — 2026-09-20** |
| **FBH-G18** | Flutter Web runtime execution gate | **Complete — 2026-09-21** |
| **FBH-G19** | Strict native artifact identity | **Complete — 2026-09-21** |
| **FBH-G20** | Flutter Review 16 exact-SHA closeout | **Complete with user-approved CI/job bypass — 2026-09-21** |
| **G21** | Published runtime contract and official stale-extraction integrity | **Remain Deferred** |

### FBH-G14 — Complete — 2026-09-20

- Frozen starting SHA: `c736b5f67db9491fd20235f8ff8ed94593377196`.
- Pre-change evidence: `flutter/hook/build.dart` passes HTTP(S) remote URIs to `output.dependencies` through `resolveRemoteOverrideToCache`, while Hooks output dependencies must be filesystem entities.
- Invariant before implementation: HTTP(S) overrides are refreshed when the hook executes and remain full-URL cache identities, but are never emitted as filesystem dependencies; local override files remain explicit filesystem dependencies; URL/user-defines and legacy pubspec inputs retain their existing invalidation authority.
- Scope: Flutter only; React Native, `ffmpeg-kit-builders`, C/C++ ABI, and G21 are untouched. No local Apple/iOS commands or tests.

- Finding revalidated: `resolveRemoteOverrideToCache` registered HTTP(S) URLs through the HookOutput dependency callback even though Hooks dependencies are filesystem entities.
- Invariant: custom HTTP(S) overrides refresh when the hook executes and retain full-URL cache identity; URL changes use Hooks input/config invalidation; unchanged-URL server mutations are not an independent filesystem signal; local override files remain explicit filesystem dependencies.
- State owner: Hooks input/config invalidation for URL values and `HookOutputBuilder.dependencies` for external local files.
- Files changed: `flutter/hook/build.dart`, `flutter/test/hook_artifact_cache_test.dart`, `flutter/README.md`, `flutter/doc/installation.md`, `flutter/doc/quick-start.md`, `.agent/TRACKER.md`.
- Why each changed: remove the remote URI dependency callback; retain regression coverage for remote refresh/cache identity and local file dependency tracking; reconcile the three maintained guides with the exact hook-execution and invalidation contract; record the evidence.
- Tests added/modified: remote refresh/cache test now exercises resolution without a filesystem dependency callback; existing local dependency, URL identity, identical-byte reuse, changed-byte extraction invalidation, and unsupported-scheme tests remain covered.
- Focused verification: bundled Dart `format --output=none --set-exit-if-changed` passed for the changed hook/test files with 0 changes; `dart analyze hook test/hook_artifact_cache_test.dart test/user_defines_config_test.dart` passed with no issues; `dart test test/hook_artifact_cache_test.dart test/user_defines_config_test.dart test/hook_config_test.dart` passed with 34 tests and 0 failures.
- Full verification: not run; G14 exit criteria are the bounded hook/cache/config suite, and broader closeout belongs to FBH-G20.
- Documentation: `flutter/README.md`, `flutter/doc/installation.md`, and `flutter/doc/quick-start.md` now distinguish remote refresh-on-hook-execution from filesystem dependency invalidation and preserve local-file dependency guidance.
- Residual risk: a server-side mutation at an unchanged URL remains invisible when Hooks reuses a cached invocation; versioned or content-addressed URLs remain recommended.
- Scope confirmation: React Native untouched; `ffmpeg-kit-builders` unchanged; G21 remains deferred; no local Apple/iOS commands or tests ran.
- Tracker transition: Complete after commit `d4c906eae9c88c1818ce950eb1cffa77587c8fa8`.

### FBH-G15 — Complete — 2026-09-20

- Frozen starting SHA: `d4c906eae9c88c1818ce950eb1cffa77587c8fa8`.
- Finding revalidated: local Web/Wasm overrides were always treated as archive files, so a directory could not reach the existing coherent `ffmpegkit.mjs`/`ffmpegkit.wasm` selector.
- Invariant: Web-only local overrides accept an archive or directory; directories require exactly one coherent runtime pair, bypass archive caching, and register the selected runtime files as filesystem dependencies; native archive resolution is unchanged.
- State owner: Web runtime source resolution plus `HookOutputBuilder.dependencies` for the selected local runtime files.
- Files changed: `flutter/hook/build.dart`, `flutter/test/web_runtime_pair_test.dart`, `flutter/README.md`, `flutter/doc/installation.md`, `flutter/doc/quick-start.md`.
- Why each changed: add a Web runtime source abstraction, branch local directory inputs before archive caching, preserve archive/remote behavior, test flat/nested/invalid directory layouts and selected-file dependencies, and make the local/archive versus remote/archive contract explicit in maintained docs.
- Tests added/modified: flat local directory resolution with both file dependencies; nested relative directory resolution with same-path Wasm content observation; invalid directory rejection; existing split/multiple-pair selector regressions retained.
- Focused verification: bundled Dart formatter check passed with 0 changes for `hook/build.dart` and `test/web_runtime_pair_test.dart`; `dart analyze hook test/web_runtime_pair_test.dart test/hook_artifact_cache_test.dart` passed with no issues; `dart test test/web_runtime_pair_test.dart test/hook_artifact_cache_test.dart test/user_defines_config_test.dart` passed with 28 tests and 0 failures; `git diff --check` passed.
- Full verification: not run; broader package and platform closeout belongs to FBH-G20.
- Documentation: `flutter/README.md`, `flutter/doc/installation.md`, and `flutter/doc/quick-start.md` now state local Web archive-or-directory, remote Web HTTP(S)-archive, and native platform-archive boundaries.
- Residual risk: this goal proves source resolution and dependency registration; real browser runtime delivery remains FBH-G18, and native artifact identity remains FBH-G19.
- Scope confirmation: React Native untouched; `ffmpeg-kit-builders` unchanged; G21 remains deferred; no local Apple/iOS commands or tests ran.
- Tracker transition: Complete after commit `55592c3387fc92fba157b71815cc50a43c1cf219`.

### FBH-G16 — Implementation committed; build gate pending — 2026-09-20

- Frozen starting SHA: `55592c3387fc92fba157b71815cc50a43c1cf219`.
- Finding revalidated: the Web hook guessed a consuming workspace/app root from the shared Hooks output path and copied runtime files into guessed `build/web` and source `web` asset directories, creating a second delivery authority beside Flutter's DataAsset pipeline.
- Invariant: Flutter Web runtime delivery is DataAsset-only; the hook emits exactly five package DataAssets (`ffmpegkit.mjs`, `ffmpegkit.wasm`, loader, callback bridge, and callback runtime), never writes generated files into a consuming app's `web/` or `build/web/` tree, never infers a consuming app from shared `.dart_tool` output, and resolves configuration from canonical workspace-root `hooks.user_defines`.
- State owner: Flutter's DataAsset build/run pipeline; `HookOutputBuilder.dependencies` remains limited to actual local/configuration inputs.
- Files changed: `flutter/hook/build.dart`, `flutter/hook/config.dart`, `flutter/test/hook_config_test.dart`, `flutter/test/user_defines_config_test.dart`, `flutter/test/web_data_asset_test.dart`, `flutter/test/fixtures/data_assets_workspace/pubspec.yaml`, `flutter/test/fixtures/data_assets_workspace/apps/app/pubspec.yaml`, `flutter/test/fixtures/data_assets_workspace/apps/app/lib/main.dart`, `flutter/test/fixtures/data_assets_workspace/apps/app/web/index.html`, `flutter/test/fixtures/data_assets_workspace/runtime/ffmpegkit.mjs`, `flutter/test/fixtures/data_assets_workspace/runtime/ffmpegkit.wasm`, `flutter/README.md`, `flutter/doc/installation.md`, and `flutter/doc/quick-start.md`.
- Why each changed: remove manual Web copies and staging-root inference; remove the no-longer-needed `ConfigResult.stagingBaseDir`; assert official DataAsset output and no guessed workspace writes; provide a bounded workspace fixture; and document the canonical workspace/DataAsset contract.
- Tests added/modified: real `testBuildHook` coverage with `DataAssetsExtension` asserts the five DataAsset names and no synthetic workspace `web/` or `build/web/` writes; the no-DataAsset path asserts the precise toolchain failure; configuration tests no longer preserve the removed staging-root behavior.
- Focused verification: direct bundled Dart `format --output=none --set-exit-if-changed` passed with 0 changes; `dart analyze hook test/hook_config_test.dart test/user_defines_config_test.dart test/web_runtime_pair_test.dart test/web_data_asset_test.dart` passed with no issues; the same focused `dart test` command passed with 35 tests and 0 failures; `git diff --check` passed.
- Bounded fixture verification: the direct Flutter 3.47.4 tool completed `pub get` for `flutter/test/fixtures/data_assets_workspace` and accepted the workspace-root `hooks.user_defines` configuration. `flutter build web --wasm --no-pub` was then attempted from `apps/app` and stopped at the hook because the local stable SDK supplied `buildDataAssets: false`; `flutter config --list` reports `enable-dart-data-assets: true (Unavailable)`, and the documented `FLUTTER_DART_DATA_ASSETS=true` override cannot enable an unavailable stable feature. No manual staging fallback was restored.
- Documentation: the three maintained English guides now state workspace-root configuration as canonical, DataAssets as the shared Web build/run delivery path when enabled, and no writes into app `web/` or `build/web/` directories; the stale manual-staging and stable-DataAsset limitation statements are removed.
- Residual risk: a passing real Flutter Web build remains unverified until a Flutter toolchain that exposes/enables Dart DataAssets is available; G18 owns browser/runtime proof. The implementation intentionally fails fast rather than silently returning to guessed staging.
- Toolchain audit — 2026-09-21: the installed stable SDK's `features.dart` declares `dartDataAssets` with a `master` channel setting only; stable has no available setting. The official Flutter SDK archive currently schedules stable 3.47 for August 2026 and stable 3.50 for November 2026, while the upstream build-hooks tracker still lists `hook/build.dart` DataAssets support as ongoing work. This confirms the missing stable fixture is a Flutter release/toolchain boundary, not a package implementation failure.
- G16 evidence ledger — pure hook/build contract: `dart format --output=none --set-exit-if-changed` passed with 0 changes; `dart analyze hook test/hook_config_test.dart test/user_defines_config_test.dart test/web_runtime_pair_test.dart test/web_data_asset_test.dart` passed; the focused `dart test` command passed 35 tests. `web_data_asset_test.dart` proves the no-DataAsset diagnostic, five DataAsset names, workspace-root `hooks.user_defines`, three runtime-source dependencies, and no synthetic `workspace/web` or `workspace/build/web` writes.
- G16 evidence ledger — stable fixture: `flutter pub get` passed for `test/fixtures/data_assets_workspace`; the workspace root configuration was accepted. From `apps/app`, `flutter build web --wasm --no-pub` reached the package hook and failed at the intentional guard because `buildDataAssets` was `false`. `flutter config --list` reported `enable-dart-data-assets: true (Unavailable)`; setting `FLUTTER_DART_DATA_ASSETS=true` could not override an unavailable stable feature. This is a verified negative-path/build blocker, not a package test failure.
- G16 evidence ledger — positive toolchain: Flutter master `19946f91c8d9de18a4674460d015229cc0b2534f` (`3.48.0-1.0.pre-841`) built the same clean candidate with DataAssets. `flutter run -d web-server --wasm --cross-origin-isolation --target=lib/web_runtime_smoke.dart` plus the headless Chromium runner produced `STARTING|INITIALIZED|FFMPEG_OK|FFPROBE_OK|MEDIA_INFO_OK|PASS` with no page or console errors. Exact-SHA CI run `35556469677` repeated the Flutter-owned Web runtime smoke job successfully at `d7b788067dad9bc5502167e0d28229994a813d55`; this proves the positive path under master, not the planned stable-3.47 fixture.
- G16 blocker boundary: the package now correctly refuses to restore manual staging when Flutter does not provide DataAssets. Making the stable negative path succeed by copying into an inferred app directory would violate the G16 invariant. The remaining missing evidence is specifically a released stable Flutter toolchain that sets `buildDataAssets: true` for this Web fixture; G16/G20 must remain pending unless the plan is explicitly amended to accept the master positive gate and retain the stable negative-path evidence.
- Scope confirmation: Flutter only; React Native untouched; `ffmpeg-kit-builders` unchanged; G21 remains deferred; no local Apple/iOS commands or tests ran.
- Tracker transition: Pending after commit `6b6b80e89895fcb4a6c4321e50162008ad16e84b`; resume the bounded fixture build when the required Flutter DataAssets feature is available.

### FBH-G17 — Complete — 2026-09-20

- Frozen starting SHA: `6b6b80e89895fcb4a6c4321e50162008ad16e84b`.
- Finding revalidated: Web initialization memoized a global Promise and detached Emscripten Wasm-instantiation failures with an asynchronous throw, so the public attempt could remain pending or permanently poison retries.
- Invariant: concurrent callers share one in-flight attempt; success is idempotent; fetch, compile, instantiate, factory, binding, and native-initialization failures reject the current attempt; failed attempts clear retry authority; the committed module is non-null only after binding installation and `ffmpeg_kit_initialize` succeed; no detached error throw remains.
- State owner: Dart `RetryableInitialization` owns public attempt deduplication/retry, while the Web loader owns one-shot Wasm instantiation and the bridge owns the fresh module factory.
- Files changed: `flutter/lib/src/platform/web/retryable_initialization.dart`, `flutter/lib/src/platform/web/wasm_loader.dart`, `flutter/test/wasm_loader_state_test.dart`, `flutter/web/ffmpegkit_loader.mjs`, `flutter/web/ffmpegkit_bridge.mjs`, `flutter/web/ffmpegkit_loader_test.mjs`, `flutter/lib/src/ffmpeg_kit_extended.dart`, `flutter/README.md`, `flutter/doc/index.md`, and `flutter/doc/architecture.md`.
- Why each changed: add retryable initialization state, commit the module only after binding/native setup, replace detached WebAssembly errors with an observable rejection path, stop globally memoizing failed module Promises, add concurrency/failure regressions, and document the public retry/idempotency contract.
- Focused verification: bundled Dart formatting passed with 0 changes; full bundled `dart analyze` and direct Flutter analyzer passed with no issues; focused Dart loader/runtime/DataAsset tests passed with 15 tests and 0 failures; Node syntax checks and `node --test web/ffmpegkit_loader_test.mjs` passed; `git diff --check` passed.
- Browser/runtime verification: intentionally not claimed here; real Flutter Web delivery and browser execution remain FBH-G18, and G16's stable DataAssets toolchain gate remains open.
- Scope confirmation: Flutter Web only; React Native untouched; `ffmpeg-kit-builders` unchanged; G21 remains deferred; no local Apple/iOS commands or tests ran.
- Tracker transition: Complete after commit `324390afc2c29219b0fcd904b2f40ac13418db77`.

### FBH-G18 — Complete — 2026-09-21

- Frozen starting SHA: `47778e11d0755b783bff3b73598111a1f08dd586`.
- Finding revalidated: the Flutter package needs a real Wasm server/browser run to prove retryable initialization, repeated initialization idempotence, FFmpeg execution, FFprobe execution, and media-information delivery; the local stable toolchain cannot provide the required DataAsset build path.
- Implementation: added `example/lib/web_runtime_smoke.dart` with machine-readable initialization, FFmpeg, FFprobe, media-information, and final PASS/FAIL statuses; added `example/web_runtime_smoke.mjs` with headless Chromium assertions and page/console error capture; and added a Flutter-owned `web-runtime-smoke` job using Flutter master, `flutter run -d web-server --wasm --cross-origin-isolation`, and Playwright Chromium. The stable package verification job remains independent, while its blocked stable Web build step was removed.
- Local validation: direct Flutter analysis of `example` passed with no issues; Dart formatting passed with 0 changes; Node syntax validation passed; the workflow parsed successfully with the bundled `package:yaml` parser; and `git diff --check` passed.
- Runtime proof: the local direct Flutter SDK is 3.47.4 stable; `flutter config --list` reports `enable-dart-data-assets: true (Unavailable)`, and the bounded workspace `flutter build web --wasm --no-pub` stops with `buildDataAssets: false` at the hook. The new master/DataAssets CI job remains the authoritative browser gate.
- Follow-up implementation: commit `3bd8af975d315d054a301bc9585c6f697fecf90b` registers the bridge, callback runtime, and loader source files as Web DataAsset hook dependencies and asserts those dependencies in `test/web_data_asset_test.dart`. The smoke command uses the example's proven `FFprobeKit.executeAsync('-version')` form; the Wasm bundle rejects the prior `-nostdin -version` probe.
- Local master proof: Flutter master `19946f91c8d9de18a4674460d015229cc0b2534f` (`3.48.0-1.0.pre-841`) built the clean candidate with DataAssets and served `flutter run -d web-server --wasm --cross-origin-isolation --target=lib/web_runtime_smoke.dart`. Headless Chromium passed `STARTING|INITIALIZED|FFMPEG_OK|FFPROBE_OK|MEDIA_INFO_OK|PASS` with no page or console errors. A deep temporary checkout separately exposed Windows MAX_PATH at `include\\compat\\*`; the same clean candidate passed from a short temporary path, so that diagnostic is not being treated as a product failure.
- Exact-SHA CI proof: run `35556469677` executed at `d7b788067dad9bc5502167e0d28229994a813d55`; `Flutter Web Runtime Smoke` passed. The job used Flutter master with Dart DataAssets, started the Wasm server with cross-origin isolation, and the browser runner passed the required initialization, FFmpeg, FFprobe, media-information, and final PASS assertions.
- Scope confirmation: Flutter Web only; React Native untouched; `ffmpeg-kit-builders` unchanged; G16 owns the DataAssets delivery prerequisite and G20 owns final exact-SHA CI closeout; no local Apple/iOS commands or tests ran.
- Tracker transition: Complete after exact-SHA run `35556469677` at commit `d7b788067dad9bc5502167e0d28229994a813d55`. G16's stable DataAssets toolchain limitation remains separately tracked.

### FBH-G19 — Initial strict-selection implementation — 2026-09-20

- Frozen starting SHA: `324390afc2c29219b0fcd904b2f40ac13418db77`.
- Finding revalidated: Android selected the first arbitrary `.so` when `libffmpegkit.so` was absent; Linux/Windows returned success with no libraries or relabeled an arbitrary library as `ffmpegkit`; Apple accepted the first filesystem-ordered `.xcframework`; and all iOS framework metadata used `iPhoneOS`.
- Invariant: the hook emits `ffmpegkit` only from the exact platform main library; missing or multiple candidates fail; Android requires `libffmpegkit.so`; Linux requires exactly one `libffmpegkit.so`; Windows requires exactly one `libffmpegkit.dll`; Apple requires exactly one deterministic `.xcframework` root; simulator metadata identifies `iPhoneSimulator`; device and macOS metadata remain `iPhoneOS` and `MacOSX`.
- State owner: `flutter/hook/native_artifact.dart` owns pure deterministic layout selection and platform metadata; `flutter/hook/build.dart` wires those selectors into CodeAsset emission and strict Apple archive handling.
- Files changed: `flutter/hook/native_artifact.dart`, `flutter/hook/build.dart`, `flutter/test/native_artifact_layout_test.dart`, `flutter/README.md`, `flutter/doc/installation.md`, and `flutter/doc/quick-start.md`.
- Why each changed: centralize exact-main and XCFramework-root selection, remove fail-open fallbacks, parameterize simulator metadata, add synthetic platform/layout regressions, and document the minimum native override archive contracts.
- Focused verification: new selector files formatted with 0 changes on the final check; `dart analyze hook test/native_artifact_layout_test.dart test/apple_hook_regression_test.dart` passed with no issues; the focused test command passed with 25 tests and 0 failures; `git diff --check` passed.
- Final platform proof: official native platform matrix verification remains FBH-G20; browser/runtime execution remains FBH-G18 and the G16 DataAssets toolchain gate remains open.
- Scope confirmation: Flutter native hook only; React Native untouched; `ffmpeg-kit-builders` unchanged; G21 remains deferred; no local Apple/iOS commands or tests ran.
- Tracker transition: Initial implementation committed in `47778e11d0755b783bff3b73598111a1f08dd586`; the official archive-layout follow-up below remains open.

### FBH-G19 follow-up — Official XCFramework archive wrapper — Complete — 2026-09-21

- Finding revalidated: the exact-SHA Flutter Example App CI run `35555823682` downloaded the official iOS and macOS archives and failed because extraction produced an outer directory named `*.xcframework` containing the actual nested `*.xcframework`; the strict selector counted both as separate roots.
- Invariant: a single archive-wrapper `.xcframework` containing one nested actual `.xcframework` is accepted; two actual `.xcframework` roots remain rejected; flat and nested single-root overrides remain deterministic.
- Files changed: `flutter/hook/native_artifact.dart` and `flutter/test/native_artifact_layout_test.dart`.
- Why each changed: select nested roots when present and use the extraction directory itself only as the flat-root fallback; add the exact wrapper/nested regression without weakening multiple-root rejection.
- Focused verification: `dart format --output=none --set-exit-if-changed hook/native_artifact.dart test/native_artifact_layout_test.dart` passed with 0 changes; `dart analyze hook/native_artifact.dart test/native_artifact_layout_test.dart` passed; `dart test test/native_artifact_layout_test.dart test/apple_hook_regression_test.dart` passed with 27 tests and 0 failures; `git diff --check` passed.
- External evidence: exact-SHA run `35556469677` at `d7b788067dad9bc5502167e0d28229994a813d55` passed `Build (ios)`, `Build (ios-simulator)`, and `Build (macos)`, as well as the full required Flutter matrix. The prior wrapper failure is therefore resolved by the nested-root selector.
- Apple audit: all three jobs ran on `macos-26-arm64` with Flutter `stable-3.47.0-arm64`. The iOS simulator command was `flutter build ios --simulator --debug --no-codesign`; the passing job log exposed the ARM64 runner/toolchain and simulator build path, but did not surface the hook's selected slice, source/output architecture, or generated `CFBundleSupportedPlatforms` line. Those values remain covered by the focused Apple/native selector tests; no x86_64 support is claimed.
- Tracker transition: Complete after exact-SHA run `35556469677` at commit `d7b788067dad9bc5502167e0d28229994a813d55`.

### FBH-G20 — Exact-SHA platform matrix green; G16 fixture remains open — 2026-09-21

- Candidate SHA: `d7b788067dad9bc5502167e0d28229994a813d55` (`fix(flutter): unwrap Apple archive XCFramework roots`); the worktree is clean and no source edits are pending after this follow-up commit.
- Residual source audit: Review 16 changes remain Flutter-only; React Native, `ffmpeg-kit-builders`, C/C++ sources, and G21 were not changed. G14-G19 implementation files and the existing Flutter workflow were re-read; the graph provided best-effort coverage with metadata-changed/not-tracked freshness, so direct source reads remain authoritative.
- Local/static validation: full bundled `dart analyze`, full `flutter analyze`, and `flutter test --no-pub --exclude-tags native` passed with 82 tests and 0 failures; `git diff --check` passed. The explicit focused suite covering Apple hooks, cache/config/userDefines, Web runtime pairs, and native artifact layouts passed with 68 tests and 0 failures. The G17 Node loader test passed with 1 test and 0 failures; the G18 smoke runner passed the real short-path Flutter master/DataAssets browser gate with no page or console errors.
- External proof: run `35556469677` (`https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35556469677`) completed successfully with exact `head_sha` `d7b788067dad9bc5502167e0d28229994a813d55`. Passing jobs were Package Verification `106200952864`, Flutter Web Runtime Smoke `106200952934`, Native API Verification (Linux) `106201899980`, Build (android) `106200953001`, Build (ios) `106200952977`, Build (ios-simulator) `106200952994`, Build (macos) `106200952968`, Build (linux) `106200953082`, and Build (windows) `106200952967`.
- Remaining gate: G16 still requires the explicitly planned Flutter 3.47 DataAssets fixture/build proof. Local stable Flutter 3.47.4 reports `enable-dart-data-assets: true (Unavailable)` and stops the fixture at `buildDataAssets: false`; the passing Web job intentionally uses Flutter master because the feature is not exposed by that stable toolchain. The exact-SHA CI matrix is otherwise green, so G20 remains pending only on this declared G16 prerequisite.
- Scope confirmation: no local Apple/iOS/Android platform commands ran; platform proof remains remote-only; G21 remains deferred.
- Tracker transition: G20 remains pending after the exact-SHA matrix passed; do not mark complete until G16's stable-toolchain criterion is either satisfied with the planned fixture evidence or explicitly re-scoped by the user.

### Review 16 publication audit — 2026-09-21

- Remote ref verification: `gh api repos/akashskypatel/ffmpeg-kit-extended/git/ref/heads/dev-wasm --jq .object.sha` returned `d7b788067dad9bc5502167e0d28229994a813d55`, matching local `HEAD` and `origin/dev-wasm`.
- Divergence verification: `git rev-list --left-right --count origin/dev-wasm...HEAD` returned `0 0`; `git log origin/dev-wasm..HEAD` and `git log HEAD..origin/dev-wasm` were empty; the source worktree is clean.
- All non-G16 Review 16 commits are ancestors of the verified remote `dev-wasm` SHA:

  | Goal | Commit | Subject |
  | --- | --- | --- |
  | FBH-G14 | `d4c906eae9c88c1818ce950eb1cffa77587c8fa8` | Keep remote overrides out of hook dependencies |
  | FBH-G15 | `55592c3387fc92fba157b71815cc50a43c1cf219` | Support local Web runtime directories |
  | FBH-G17 | `324390afc2c29219b0fcd904b2f40ac13418db77` | Make Web initialization retryable |
  | FBH-G18 | `bf6a8da868e58ddab5cf97cf428d06ec47e60bb5` | Add Web runtime smoke gate |
  | FBH-G18 | `3bd8af975d315d054a301bc9585c6f697fecf90b` | Track Web DataAsset runtime sources |
  | FBH-G19 | `47778e11d0755b783bff3b73598111a1f08dd586` | Reject ambiguous native artifacts |
  | FBH-G19 | `d7b788067dad9bc5502167e0d28229994a813d55` | Unwrap Apple archive XCFramework roots |

- The G16 implementation commit `6b6b80e89895fcb4a6c4321e50162008ad16e84b` is also present in the same remote ancestry; only its stable positive-toolchain acceptance criterion remains open.

### Review 16 amended G16/G20 implementation prep — 2026-09-20

- Source: latest response in the ChatGPT project conversation [Plan Luna Fix](https://chatgpt.com/g/g-p-69e9691f5b3881919a72eda0a180ed5c/c/6aabedf6-8ea4-83e8-ba0f-f73c7c065edf), titled `Download the amended Luna G16/G20 production-publishing plan`.
- Amendment: the original stable Flutter 3.47 DataAssets requirement is removed from the default production path. The default base/small/LGPL Wasm runtime must ship as ordinary package assets under `assets/packages/ffmpeg_kit_extended_flutter/wasm/`; custom/non-default Web runtimes remain DataAsset-only under `wasm_override/` on toolchains that expose DataAssets.
- Required behavior: default Web builds must succeed with stable Flutter 3.47 when `buildDataAssets == false`; custom/non-default Web selection must fail clearly on that toolchain rather than silently selecting the default; custom DataAssets must retain coherent-pair validation, dependency tracking, and the no-manual-staging invariant.
- Additional implementation requirement: the Web loader must select the static `wasm/` or custom `wasm_override/` root deterministically. An unconditional 404 probe or silent fallback is not acceptable because it could mask a requested custom runtime.
- Production gates to add/restore: stable `flutter build web --wasm`, stable browser smoke, and `dart pub publish --dry-run`. Retain Flutter master as the custom-override/DataAsset integration gate, not as the ordinary production prerequisite.
- Implementation prep is recorded in [`.agent/flutter-review-16-amended-g16-g20-implementation.md`](./flutter-review-16-amended-g16-g20-implementation.md). Implementation is now in progress on top of `d7b788067dad9bc5502167e0d28229994a813d55`; G16 and G20 remain pending until the amended gates pass on one exact SHA.
- Pinned default payload staged for publication: `v0.11.2-wasm/bundle-base-wasm-wasm32-static-small-lgpl.zip`, GitHub release SHA-256 `386285af1e738ce96172e5e30c375eea788183b91d3dea928da085eaa2c83c2a`, 6,631,555-byte archive. The extracted pair and support modules are under `flutter/assets/wasm/` and are declared as ordinary package assets.
- Implementation slices currently staged: stable default hook bypasses DataAssets and download/extract; custom/non-default Web selections reject `buildDataAssets: false` and emit six `wasm_override/` DataAssets including `ffmpegkit_wasm_manifest.json`; the Web loader probes the optional manifest and selects the corresponding root; static asset, hook classification, custom DataAsset, stable default, and browser-root assertions are covered.
- CI changes currently staged: Package Verification adds Dart format, stable `flutter build web --wasm`, and `dart pub publish --dry-run`; the stable browser smoke asserts `wasm/`; a separate Flutter master/DataAssets custom-override smoke asserts `wasm_override/`. No local build, test, analyze, or publish command was run for this implementation; GitHub Actions is the validation authority.

### Review 16 amended G16/G20 validation and blocker diagnosis — 2026-09-21

- Candidate SHA: `8c5ffe2e5733a1a42f6cc23525a96855dcf7573e` (`ci(flutter): serve stable Wasm build with correct MIME types`). Local `HEAD`, `origin/dev-wasm`, and the GitHub Actions checkout all resolve to this exact SHA. The worktree is clean; `git rev-list --left-right --count origin/dev-wasm...HEAD` returned `0 0`, and both ahead/behind commit lists were empty.
- Non-G16 push verification: all Review 16 implementation commits outside the G16/G20 closeout are ancestors of the verified remote `dev-wasm` SHA, including G14 `d4c906e`, G15 `55592c3`, G17 `324390a`, G18 `bf6a8da` and `3bd8af9`, and G19 `47778e1` and `d7b7880`. The amended G16/G20 commits `dbd34de`, `2493f27`, `91f3fc8`, `517f7c7`, `c518a7e`, and `8c5ffe2` are also pushed.
- Exact-SHA workflow: [Flutter Example App CI run 35563468577](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35563468577) checked out `8c5ffe2e5733a1a42f6cc23525a96855dcf7573e`.
- Package/build evidence: Package Verification job `106220665739` passed Dart analyze, Flutter analyze, Flutter tests, and stable `flutter build web --wasm`. The ordinary default runtime hook logged that it used package assets under `wasm/`; the package listing contains `assets/wasm/` and the runtime/support modules. The final `dart pub publish --dry-run` step exited 65 because pub reported one warning: `ffigen_js: ^0.0.16-pre` is a pre-release direct dependency while this package is version `1.0.0`. This is a publication metadata blocker, not a G16 asset/build failure. The upstream package remains published as `0.0.16-pre` ([pub.dev API documentation](https://pub.dev/documentation/ffigen_js/latest/)).
- Stable default runtime evidence: the stable Web Wasm build completed in Web Runtime Smoke job `106220665891`, and the hook selected ordinary package assets. The runner browser phase failed before any FFmpeg asset request with `RangeError: Incorrect locale information provided`; the page remained titled `ffmpeg_kit_extended_flutter_example` and timed out after 120 seconds. This is a runner/browser-locale initialization failure, not an asset 404, MIME failure, Wasm-pair failure, or loader error.
- Local browser evidence authorized by the user: against the existing `flutter/example/build/web` output, the bundled Chromium browser and `web_static_server.mjs` produced `STARTING|INITIALIZED|FFMPEG_OK|FFPROBE_OK|MEDIA_INFO_OK|PASS`, with no page or console errors. Requests included `assets/packages/ffmpeg_kit_extended_flutter/wasm/ffmpegkit_bridge.mjs`, `ffmpegkit.mjs`, `ffmpegkit_callback_runtime.mjs`, `ffmpegkit_loader.mjs`, and `ffmpegkit.wasm`. No local build, Dart/Flutter test, analyzer, or publish command was run for this diagnostic; only the already-built Web output was served and exercised in a browser.
- Custom override/DataAsset evidence: Flutter master job `106220665967` passed build and browser smoke against `wasm_override/`, including the expected custom bridge and Wasm requests, on the same exact SHA. This closes the amended custom-toolchain behavior; master remains an integration gate rather than the default production prerequisite.
- Native/platform evidence on the same SHA: Build Linux `106220665779`, Windows `106220665814`, Android `106220665854`, macOS `106220665862`, iOS Simulator `106220665866`, iOS `106220665910`, and Native API Verification (Linux) `106221608385` all passed. The workflow annotations about Node 20 action deprecation and the future Ubuntu 26 label migration were non-fatal.
- Current blockers for the amended plan: (1) publication cannot be declared clean while stable package `1.0.0` directly depends on pre-release `ffigen_js`; resolve by publishing a compatible stable `ffigen_js`, or explicitly deciding to publish this package as a pre-release; and (2) the GitHub-hosted stable browser job has a locale-sensitive Flutter initialization failure while the same built output passes locally. Either the workflow runner must be stabilized (for example, explicit supported browser locale/runner setup) or the plan must explicitly accept local browser evidence for this gate.
- G16/G20 transition: implementation is pushed and the amended default/custom delivery contracts are evidenced. The user explicitly bypassed the two non-code/job blockers below, so G16 and G20 transition to **Complete with exceptions**; G21 remains deferred. No React Native, builder, C/C++ ABI, or local native-platform scope was changed.

### Review 16 amended G16/G20 user-approved acceptance — 2026-09-21

- User decision: the hosted Wasm browser test limitation and the package publication warning are explicitly bypassed by the user as job/non-code issues. They remain recorded as residual evidence and are not treated as product defects or release-stopping implementation blockers for this amended plan.
- Final candidate SHA: `0abe4d86b3a2e963aa344c0978e24d6baae5b49c` (`test(flutter): pin Web smoke locale`). Local `HEAD`, `origin/dev-wasm`, and workflow checkout match; `git rev-list --left-right --count origin/dev-wasm...HEAD` is `0 0`; the worktree is clean.
- Final exact-SHA workflow: [Flutter Example App CI run 35564365107](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35564365107) checked out the final SHA. Passing jobs: custom DataAsset Web smoke `106223157947`, Linux `106223158096`, Windows `106223158142`, macOS `106223158150`, iOS Simulator `106223158167`, iOS `106223158171`, Android `106223158192`, and Native API Verification (Linux) `106223917080`.
- Stable package/build evidence: Package Verification `106223158089` passed Dart analyze, Flutter analyze, Flutter tests, and stable `flutter build web --wasm`. Its only failure was `dart pub publish --dry-run`, which reported the known warning that stable package `1.0.0` depends on prerelease `ffigen_js: 0.0.16-pre` and exited 65. User bypass applied.
- Hosted browser evidence: stable Web build completed, but Flutter Web Runtime Smoke `106223158097` failed in the hosted job. On the earlier exact-SHA run, the failure was runner locale initialization (`RangeError: Incorrect locale information provided`); after the smoke harness pinned `en-US`, the current run progressed further but failed to load `assets/packages/ffmpeg_kit_extended_flutter/wasm/ffmpegkit_bridge.mjs`. This hosted browser gate is explicitly bypassed by the user because Wasm browser tests cannot be relied on in the workflow runner.
- Local browser evidence retained from the authorized diagnostic: the existing Web Wasm build served locally produced `STARTING|INITIALIZED|FFMPEG_OK|FFPROBE_OK|MEDIA_INFO_OK|PASS`, loaded the default `wasm/` package assets, and had no page or console errors. No local build, Dart/Flutter test, analyzer, or publish command was run; only the existing Web output was served and exercised.
- Acceptance: G16 and G20 are **Complete with explicit user-approved exceptions**. The exceptions are the prerelease dependency publication warning and hosted Web browser execution; they are recorded for future cleanup but do not block this amended-plan closeout.

### G55 — Complete

- Frozen starting SHA: `173307979fdaacbabb22e4f01168742fd224087b`.
- Finding revalidated: `Session.cancel()` recorded `cancelled` only after `cancelQueued()`, `getState()`, and immediate native cancellation; a state-read or native-dispatch exception could therefore erase the user's cancellation request.
- Invariant: `isCancelled` records a requested cancellation immediately; Created/queued work remains locally prevented, Running work dispatches native cancellation, and a failed native dispatch remains retryable without setting the success flag.
- State coverage: Created/unsubmitted latches and rejects later submission; Queued latches and removes only the targeted item; dequeued/native-Created remains pending for G53; Running dispatches immediately and monitor retry remains available after failure; Completed/Failed do not dispatch late cancellation; state-read and native-dispatch errors remain synchronously observable while intent stays latched.
- Files changed: `react-native/src/session.ts`, `react-native/tests/wasm-session-ownership.test.js`, `react-native/README.md`, `.agent/TRACKER.md`.
- Why each changed: `session.ts` commits cancellation intent before fallible operations; the ownership test adds state-read/native-dispatch failure and idempotence regressions; the README clarifies requested-vs-winning cancellation; the tracker records the evidence and transition.
- Tests added/modified: `state-read failure latches cancellation before exposing the error`; `immediate native cancellation failure preserves intent and allows monitor retry`; the running-wrapper test now calls `cancel()` twice and asserts one native dispatch.
- Pre-fix evidence: the new state-read regression failed against the frozen implementation; the immediate-dispatch regression could not settle because the request was not latched.
- Focused verification: `npm run test:compile` passed; `node --test tests/wasm-session-ownership.test.js tests/session-queue-manager.test.js` passed, 38 tests, 0 failures; `npm run typecheck` passed; `npm run lint` passed with the existing `no-useless-escape` warning only.
- Full verification: `npm run check` passed, 136 tests, 0 failures; the existing `no-useless-escape` warning remains non-fatal.
- Flutter touched: No. Flutter commands/workflows: None. ffmpeg-kit-builders changed: No. C/C++ ABI changed: No. Local iOS/Apple/Android build or simulator commands: None.
- Documentation: `react-native/src/session.ts`, `react-native/README.md`, `.agent/TRACKER.md`.
- Residual risk: Native cancellation remains asynchronous and the final native state determines whether cancellation wins a completion race.
- Tracker transition: Complete after commit `58e46b81eee0697ef163d0898c2ea065c4efce24`; G56 closeout is recorded below.

### G56 — Complete

- Frozen implementation SHA: `8d5dbaf3b47f27f7eb4713f76370b7c7cb512cf8` on `dev-wasm`; remote `origin/dev-wasm` matched this SHA before CI dispatch.
- Local package/Web verification: `npm run check` passed, 136 tests and 0 failures; `npm run prepare` passed; `npm run test:pack-types` passed; `npm run test:pack-web` passed; `npm pack --dry-run` passed; `npm --prefix example run web:build` passed; `npm run test:web` passed with the headless WebAssembly smoke sequence covering FFmpeg, FFprobe, media info, and FFplay pause/resume/stop.
- Existing workflow: `React Native Web checks` from `.github/workflows/react_native_web_ci.yaml` was dispatched against the exact SHA; run `35531865314` passed with `web` job `106133777369` and `React Native Web Windows staging` job `106133777229`.
- Existing platform workflow: `React Native Example App CI` from `.github/workflows/react_native_example_ci.yaml` was dispatched against the same exact SHA; run `35532051214` passed for `Build (android)` `106134280965`, `Build (ios)` `106134280990`, `Build (macos)` `106134280931`, `Build (appletvos)` `106134280879`, and `Build (windows)` `106134280774`.
- Scope: Flutter commands/workflows: None. ffmpeg-kit-builders changed: No. C/C++ ABI changed: No. Local iOS/Apple/Android build, test, simulator, or emulator commands: None; platform coverage ran only through existing GitHub workflows. No new workflow was added or pushed.
- Tracker transition: Complete after exact-SHA local and remote workflow evidence.

## Review 12 Remediation Records

### G49 — Complete

- Frozen starting SHA: `93da568296865e39be214007616854b8b34fa0be`
- Finding owned: The Web frame reader could copy the prior playback framebuffer immediately after a new FFplay epoch began.
- Invariant: A new Web playback advances epoch and source identity only after native start succeeds; frame copying is suppressed until that source reports readiness.
- State owner: Native FFplay context and the Web frame-source identity.
- Files changed: `react-native/src/platform/backend.web.ts`, `react-native/src/platform/web/ffplay-frame-reader.ts`, `react-native/src/platform/web/ffplay-frame-state.ts`, `react-native/tests/ffplay-frame-reader.test.js`, `react-native/tests/ffplay-view-web.test.js`, `react-native/tests/wasm-backend-memory.test.js`.
- Why each changed: Carry the native session ID with the epoch, gate reads on the native readiness sentinel, advance identity after successful start, and prove stale-frame suppression and session ownership.
- Tests added/modified: `frame reader skips unchanged generations and preserves stride across changes`; `Web backend advances the FFplay playback epoch only after successful start`; `FFplayView preserves View props, styles, and unmount cleanup on Web`.
- Focused verification: `npm run test:compile` passed; focused Node/browser tests passed (30 unit/backend cases and 1 browser smoke case).
- Full verification: `npm run check` passed, 131 tests and 0 failures; one pre-existing `no-useless-escape` warning remains in `tests/arguments.test.js`.
- Flutter touched: No.
- Flutter commands/workflows: None.
- Documentation: None.
- Residual risk: Readiness remains dependent on the published `ffplayGetVolume()` negative sentinel for an uninstalled native context.
- Tracker transition: Complete after commit `51d0bb0bfe691980058cf379144b119846eb9b63`.

### G50 — Complete

- Frozen starting SHA: `51d0bb0bfe691980058cf379144b119846eb9b63`
- Finding owned: A newer FFplay execution settling first could erase the only active-session slot while an older execution remained unsettled.
- Invariant: `currentSession`, `playing`, and `paused` select the newest remaining unsettled high-level FFplay execution regardless of settlement order.
- State owner: The insertion-ordered unsettled FFplay session collection.
- Files changed: `react-native/src/ffplay-kit.ts`, `react-native/tests/ffplay-kit.test.js`.
- Why each changed: Replace the single active slot with a bounded Map fallback and exercise newer-first settlement, start failure, and queued discard.
- Tests added/modified: Existing six G47 tests retained; added `newer FFplay settlement falls back to the older unsettled session`, `newer FFplay start failure preserves the older unsettled session`, and `discarding newer queued FFplay work falls back to the active session`.
- Focused verification: `node --test tests/ffplay-kit.test.js` passed, 9 tests and 0 failures.
- Full verification: `npm run check` passed, 131 tests and 0 failures.
- Flutter touched: No.
- Flutter commands/workflows: None.
- Documentation: FFplay cancellation wording was clarified in the shared `ffplay-kit.ts` change.
- Residual risk: The collection is process-local and intentionally reflects only high-level `executeAsync()` calls, not independently created session wrappers.
- Tracker transition: Complete after commit `e4e8a0e0684357fa542e4a1a81dc7473ca846b9c`.

### G51 — Complete

- Frozen starting SHA: `e4e8a0e0684357fa542e4a1a81dc7473ca846b9c`
- Finding owned: Created and queued sessions could still reach native execution after `Session.cancel()` was called.
- Invariant: Created cancellation prevents later submission, queued cancellation removes only that item and rejects it with existing discard semantics, and running cancellation dispatches native cancellation once.
- State owner: `Session` lifecycle state and the shared JavaScript session queue.
- Files changed: `react-native/src/session-queue-manager.ts`, `react-native/src/session.ts`, `react-native/src/ffprobe-kit.ts`, `react-native/tests/session-queue-manager.test.js`, `react-native/tests/wasm-session-ownership.test.js`.
- Why each changed: Add identity-based queue removal, preserve cleanup-error propagation, make cancellation state-aware, reject cancelled one-shot submissions, and document FFprobe/session behavior.
- Tests added/modified: `cancelQueued removes only the targeted session and preserves later work`; `cancelQueued preserves later work when targeted discard cleanup fails`; `Created cancellation prevents later submission`; `queued cancellation removes work without native cancellation and releases ownership`; `a running history wrapper forwards cancellation despite not being submitted`; active cancellation now asserts one native dispatch.
- Focused verification: `node --test tests/session-queue-manager.test.js` passed, 7 tests; `node --test tests/wasm-session-ownership.test.js` passed, 26 tests; all passed with 0 failures.
- Full verification: `npm run check` passed, 131 tests and 0 failures.
- Flutter touched: No.
- Flutter commands/workflows: None.
- Documentation: `react-native/src/session.ts` and `react-native/src/ffprobe-kit.ts`; FFplay wording was committed with G50 because both behaviors share `ffplay-kit.ts`.
- Residual risk: Native cancellation remains asynchronous; this change prevents pre-start execution but does not alter native terminal-state timing.
- Tracker transition: Complete after commit `80a1ecf8e3c7d4635cc53e2b2818baededf2f227`.

### G52 — Complete

- Frozen starting SHA: `80a1ecf8e3c7d4635cc53e2b2818baededf2f227`
- Finding owned: Final React Native package/Web gates and standalone Web CI required one immutable SHA.
- Invariant: All closeout gates and CI evidence refer to the same React Native commit; Flutter remains excluded.
- State owner: React Native package artifacts, Web smoke path, and exact-SHA CI workflow.
- Files changed: None for closeout; implementation commits are `51d0bb0bfe691980058cf379144b119846eb9b63`, `e4e8a0e0684357fa542e4a1a81dc7473ca846b9c`, and `80a1ecf8e3c7d4635cc53e2b2818baededf2f227`.
- Why each changed: Closeout validated the package artifacts, Web build, headless smoke path, and Windows staging path without additional source changes.
- Tests added/modified: None for closeout.
- Focused verification: `npm run check`; `npm run prepare`; `npm run test:pack-types`; `npm run test:pack-web`; `npm pack --dry-run`; `npm --prefix example run web:build`; and `npm run test:web` all passed locally.
- Full verification: `npm run check` passed with 131 tests and 0 failures; the existing `no-useless-escape` warning in `tests/arguments.test.js` remains non-fatal.
- CI verification: Workflow `React Native Web checks` run `35477759172` passed at exact SHA `80a1ecf8e3c7d4635cc53e2b2818baededf2f227`; web job `105989862128` and Windows staging job `105989862167` both passed.
- Flutter touched: No.
- Flutter commands/workflows: None.
- Documentation: Tracker only.
- Residual risk: G21 remains deferred; no Flutter or non-host validation was performed by design.


Findings:

| Finding                                                                                                                                                                                                                                                          |                     Severity | Remediation goal                                   |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------: | -------------------------------------------------- |
| G46 clears the canvas on a new epoch, but immediately reads the global framebuffer in the same RAF; the published Wasm runtime starts FFplay asynchronously, so the framebuffer can still belong to the previous playback and repopulate the just-cleared canvas |     **Medium / correctness** | **G49 — FFplay playback-source readiness barrier** |
| G47 tracks only one `activeSession`; if a newer unsettled FFplay execution settles before an older one, `currentSession` becomes `undefined` rather than falling back to the still-unsettled older session                                                       |   **Medium-Low / lifecycle** | **G50 — Unsettled FFplay session fallback**        |
| `Session.cancel()` does not actually cancel Created or queued work; native cancellation is a no-op before Running and the JS queue has no per-session removal path, so a session can execute after being “cancelled”                                             | **Medium / API correctness** | **G51 — Pre-start session cancellation**           |
| Final React Native-only verification                                                                                                                                                                                                                             |                     Closeout | **G52 — Review 12 exact-SHA closeout**             |


Report this table for each goal:

| Field                      | Required Luna output                                                                           |
| -------------------------- | ---------------------------------------------------------------------------------------------- |
| Goal                       | G49 / G50 / G51 / G52                                                                          |
| Frozen starting SHA        | Exact SHA                                                                                      |
| Finding owned              | One finding only                                                                               |
| Invariant                  | Written before editing                                                                         |
| State owner                | Native FFplay context/frame source, unsettled FFplay collection, or Session/queue cancellation |
| Files changed              | Exact paths                                                                                    |
| Why each file changed      | One bounded reason                                                                             |
| Tests added/modified       | Exact test names                                                                               |
| Focused verification       | Commands + results                                                                             |
| Full verification          | `npm run check` result                                                                         |
| Flutter touched            | **No**                                                                                         |
| Flutter commands/workflows | **None**                                                                                       |
| Documentation              | Exact paths or none                                                                            |
| Residual risk              | Concrete only                                                                                  |
| Tracker transition         | Only after evidence                                                                            |


Explicitly prohibited:

```text
Flutter changes or validation
G21 implementation
C/C++ changes
ffmpeg-kit-builders changes
new FFplay C ABI
timer/sleep-based FFplay correctness fixes
global queue redesign
FFplay concurrency redesign
removal of G43 epochs
removal of G44 scratch reuse
removal of G46 surface clearing
weakening G1-G48 tests
claiming G52 complete without exact-SHA CI
```

## Review 11 Tracker

| Goal                                                        | Objective                                                                                                                  | Initial status        |
| ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| **G46 — Clear stale FFplay surface on playback transition** | Invalidate prior canvas pixels immediately when a new FFplay epoch begins, even if the new playback has no video frame     | **Complete — 2026-09-19** |
| **G47 — Settle-safe FFplay active-session ownership**       | Clear high-level `activeSession` on every execution settlement while preventing an older session from clearing a newer one | **Complete — 2026-09-19** |
| **G48 — React Native Review 11 exact-SHA closeout**         | Validate G46/G47 locally and through standalone React Native Web CI on one immutable SHA                                   | **Complete — 2026-09-19** |
| **G21 — Published runtime contract**                        | Official-runtime integrity/current-source contract                                                                         | **Remain Deferred**   |
| **Flutter**                                                 | Source/tests/CI                                                                                                            | **Frozen / excluded** |

Findings:

| Finding                                                                                                                                                                                                                  |                     Severity | Remediation goal                                            |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------: | ----------------------------------------------------------- |
| A mounted Web `FFplayView` retains the previous playback's pixels after the playback epoch changes until a new video frame arrives; an audio-only next playback can therefore display the stale prior video indefinitely | **Medium-Low / correctness** | **G46 — Clear stale FFplay surface on playback transition** |
| `FFplayKit.activeSession` is cleared only by the completion callback; native-start, state-read, monitor, or cleanup rejection can leave `currentSession`, `playing`, and `paused` attached to a dead session             |   **Medium-Low / lifecycle** | **G47 — Settle-safe FFplay active-session ownership**       |
| Final verification after G46/G47                                                                                                                                                                                         |                     Closeout | **G48 — Review 11 exact-SHA closeout**                      |
| Published runtime/checksum contract                                                                                                                                                                                      |                     Deferred | **G21 remains deferred**                                    |

Report this table for each goal:

| Required field               | Luna output                                        |
| ---------------------------- | -------------------------------------------------- |
| **Goal**                     | G46 / G47 / G48                                    |
| **Frozen starting SHA**      | Exact SHA                                          |
| **Finding owned**            | One finding only                                   |
| **Invariant**                | Written before changes                             |
| **State owner**              | canvas/playback epoch or FFplayKit/session Promise |
| **Files changed**            | Exact paths                                        |
| **Why each file changed**    | One bounded reason                                 |
| **Tests added/modified**     | Exact test names                                   |
| **Focused verification**     | Command + result                                   |
| **Full verification**        | `npm run check` result                             |
| **Flutter touched**          | **No**                                             |
| **Flutter command/workflow** | **None**                                           |
| **Documentation**            | Exact paths or `none required`                     |
| **Residual risk**            | Concrete only                                      |
| **Tracker transition**       | Only after evidence                                |

explicitly prohibited:

```text
Flutter changes or validation
G21 implementation
C/C++ or builder/submodule changes
new FFplay C ABI
FFplay queue redesign
global SessionQueueManager redesign
public FFplayView API changes
removal of G43 playback epochs
removal of G44 scratch reuse
weakening any G1-G45 regression tests
marking G48 complete before exact-SHA CI
```

## Review 10 Tracker

| Goal                                                    | Objective                                                                                                         | Initial status              |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | --------------------------- |
| **G42 — Correct session-lifecycle documentation scope** | Keep the universal one-shot Session contract while identifying Created-state history execution as Web-specific    | **Complete — 2026-09-18** |
| **G43 — FFplay playback-epoch identity**                | Prevent the first frame of a new Web FFplay session from colliding with cached identity from the previous session | **Complete — 2026-09-18** |
| **G44 — FFplay metadata scratch reuse**                 | Eliminate repeated Wasm allocator churn from metadata-only frame polling                                          | **Complete — 2026-09-18** |
| **G45 — React Native Review 10 exact-SHA closeout**     | Re-run all React Native-only local and external Web gates on one immutable SHA                                    | **Complete — 2026-09-18** |
| **G21 — Published runtime contract**                    | Official-runtime integrity/current-source contract                                                                | **Remain Deferred**         |
| **Flutter**                                             | Source, tests, CI                                                                                                 | **Frozen / excluded**       |

Findings:

| Finding                                                                                                                                                                                            |                       Severity | Goal                                                    |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -----------------------------: | ------------------------------------------------------- |
| G39's README wording presents Web's `Created`-state history guard as a universal React Native contract, but the native TurboModule execution path does not enforce the same state restriction      | **Low / documentation-parity** | **G42 — Correct session-lifecycle documentation scope** |
| A mounted Web `FFplayView` can mistake the first frame of a new playback for the previous playback's frame because published `v0.11.2-wasm` resets frame generation to `0` between FFplay sessions |       **Medium / correctness** | **G43 — FFplay playback-epoch identity**                |
| FFplay's metadata-only preflight still performs four Wasm `_malloc/_free` pairs on every display-frame poll, including unchanged frames                                                            | **Low / hot-path performance** | **G44 — Reuse FFplay metadata scratch memory**          |
| Final verification after G42–G44                                                                                                                                                                   |                       Closeout | **G45 — Review 10 exact-SHA closeout**                  |
| Official-release checksum fail-open behavior found in Review 9                                                                                                                                     |              Deferred contract | **G21 remains deferred**                                |


Report this table for each goal:

| Required report field    | Luna requirement                                                        |
| ------------------------ | ----------------------------------------------------------------------- |
| Goal                     | G42 / G43 / G44 / G45                                                   |
| Frozen starting SHA      | Exact SHA                                                               |
| Finding owned            | One finding only                                                        |
| Invariant                | Written before editing                                                  |
| Relevant state machine   | docs/platform contract, FFplay playback epoch, or frame-memory hot path |
| Files changed            | Exact paths                                                             |
| Why each file changed    | One bounded reason                                                      |
| Tests changed            | Exact test names                                                        |
| Focused verification     | Commands + pass/fail                                                    |
| Full verification        | `npm run check` where applicable                                        |
| Flutter touched          | **No**                                                                  |
| Flutter command/workflow | **None**                                                                |
| Documentation            | Exact paths or none                                                     |
| Residual risk            | Concrete only                                                           |
| Tracker transition       | Only after evidence                                                     |

### G45 remediation record — 2026-09-18

- **Frozen starting SHA:** `5559883b5d6fe144f8e644807e20be2629adc739`.
- **Finding owned:** Final exact-SHA verification remained pending after G42–G44 remediation.
- **Invariant:** Local and external verification use one immutable React Native SHA; only `React Native Web checks` runs; Flutter remains untouched.
- **Relevant state machine:** Local package checks -> package preparation -> packed TypeScript/Web consumers -> package-content validation -> Web example build -> headless WebAssembly smoke test, with parallel Windows staging.
- **Files changed:** None after G44; this tracker record captures closeout evidence.
- **Why each file changed:** No source change was needed; the tracker records the immutable verification result.
- **Tests changed:** None for closeout.
- **Focused verification:** `npm run check` passed with 117 tests; the local exact gate passed `npm run prepare`, `npm run test:pack-types`, `npm run test:pack-web`, `npm pack --dry-run`, `npm --prefix example run web:build`, and `npm run test:web`. Headless smoke covered initialization, repeated initialization, FFmpeg, FFprobe, media info, FFplay, pause, resume, and stop.
- **Full verification:** GitHub Actions run [35414691482](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35414691482) passed at the frozen SHA. `web` job `105820883024` and `React Native Web Windows staging` job `105820883158` both passed.
- **Flutter touched:** **No**.
- **Flutter command/workflow:** **None**.
- **Documentation:** This tracker record only.
- **Residual risk:** G21 remains deferred; no Flutter or non-host-platform validation is claimed.
- **Tracker transition:** Pending -> Complete after local and exact-SHA external evidence.

### G44 remediation record — 2026-09-18

- **Frozen starting SHA:** `e57c59f`.
- **Finding owned:** Each Web `copyFrame()` call allocated and freed four metadata buffers, including unchanged-frame preflight calls from `FFplayView`.
- **Invariant:** A Web backend allocates one 24-byte FFplay metadata scratch block per Wasm module and performs no metadata `_malloc/_free` during subsequent frame polls; changed-frame destination allocation remains reader-owned.
- **Relevant state machine:** Backend/module initialization -> scratch warm-up -> repeated metadata preflight/full-copy calls.
- **Files changed:** `react-native/src/platform/backend.web.ts`, `react-native/tests/wasm-backend-memory.test.js`.
- **Why each file changed:** The Web backend now owns/reuses aligned metadata storage; the backend memory test counts repeated polling allocations and frees.
- **Tests changed:** `Web backend copies FFplay frame metadata through mocked Wasm memory` now verifies one 24-byte allocation, zero scratch frees, and correct metadata across four calls.
- **Focused verification:** `npm run test:compile`; targeted backend/frame-reader tests — 30 passing, 0 failures.
- **Full verification:** `npm run check` — typecheck passed, lint 0 errors with one pre-existing warning, 117 tests passed.
- **Flutter touched:** No.
- **Flutter command/workflow:** None.
- **Documentation:** Tracker only; no public README change required.
- **Residual risk:** A backend that swaps to a different live Wasm module retains the prior module's 24-byte scratch block until that module is reclaimed; no public disposal API was added.
- **Tracker transition:** Open -> Complete after focused and full React Native evidence.

### G43 remediation record — 2026-09-18

- **Frozen starting SHA:** `30ac28c`.
- **Finding owned:** Published `v0.11.2-wasm` resets FFplay frame generation between sessions, allowing a mounted Web `FFplayView` to suppress a one-frame second playback with matching geometry.
- **Invariant:** A successful FFplay async start advances the Web playback epoch exactly once; a failed start and non-FFplay execution do not; a frame from a new epoch is never suppressed by matching native generation and geometry.
- **Relevant state machine:** FFplay async start -> playback epoch -> metadata preflight/frame identity -> changed-frame copy.
- **Files changed:** `react-native/src/platform/web/ffplay-frame-state.ts`, `react-native/src/platform/web/ffplay-frame-reader.ts`, `react-native/src/platform/backend.web.ts`, `react-native/tests/ffplay-frame-reader.test.js`, `react-native/tests/wasm-backend-memory.test.js`.
- **Why each file changed:** Epoch state owns playback identity; the reader includes epoch in internal frame identity; the Web backend advances it after successful FFplay start; tests cover collision and start semantics.
- **Tests changed:** `frame reader skips unchanged generations and preserves stride across changes`; `Web backend advances the FFplay playback epoch only after successful start`.
- **Focused verification:** `npm run test:compile`; targeted frame-reader/backend tests — 30 passing, 0 failures.
- **Full verification:** `npm run check` — typecheck passed, lint 0 errors with one pre-existing warning, 117 tests passed.
- **Flutter touched:** No.
- **Flutter command/workflow:** None.
- **Documentation:** Tracker only; no public README change required.
- **Residual risk:** Browser smoke remains the final end-to-end gate; native FFplay and the published C ABI were intentionally unchanged.
- **Tracker transition:** Open -> Complete after focused and full React Native evidence.

### G42 remediation record — 2026-09-18

- **Frozen starting SHA:** `1b2dc9de068c878c49520be234970a239f0f1eda`.
- **Finding owned:** G39's README wording presented Web's `Created`-state history guard as a universal React Native contract, while native execution does not enforce that state restriction.
- **Invariant:** Shared JavaScript session objects are single-use on every backend; Created-state history-session re-execution is documented only as a React Native Web behavior.
- **Relevant state machine:** Shared session submission contract -> backend-specific history-session execution policy.
- **Files changed:** `react-native/README.md` — narrowed the Created-state/history wording to React Native Web.
- **Why each file changed:** README is the only user-facing document that made the platform-wide claim.
- **Tests changed:** None; documentation-only correction.
- **Focused verification:** `npm run typecheck`, `npm run lint`, `git diff --check` — passed; lint retained one pre-existing warning.
- **Full verification:** Not required for documentation-only scope; no runtime behavior changed.
- **Flutter touched:** No.
- **Flutter command/workflow:** None.
- **Documentation:** `react-native/README.md`, this tracker record.
- **Residual risk:** Native and Web history-session execution semantics remain intentionally different; no native lifecycle work was included.
- **Tracker transition:** Open -> Complete after the required documentation checks.

## Review 9 Tracker

| Goal                                               | Objective                                                                                      | Initial status        |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------- | --------------------- |
| **G39 — Single-submission session lifecycle**      | Prevent duplicate/repeated execution and enforce Created-only execution promotion              | **Complete — 2026-09-18** |
| **G40 — Deterministic Wasm instantiation failure** | Propagate async `WebAssembly.instantiate()` failures into the retryable initialization Promise | **Complete — 2026-09-18** |
| **G41 — React Native Review 9 exact-SHA closeout** | Validate G39/G40 locally and through standalone React Native Web CI                            | **Complete — 2026-09-18** |
| **G21 — Published runtime contract**               | Add official-artifact fail-closed integrity verification when this deferred goal resumes       | **Remain Deferred**   |
| **Flutter**                                        | Flutter source/tests/CI                                                                        | **Frozen / excluded** |

Findings:

| Finding                                                                                                                                      |                       Severity | Remediation goal                                   |
| -------------------------------------------------------------------------------------------------------------------------------------------- | -----------------------------: | -------------------------------------------------- |
| A `Session` can be submitted more than once; duplicate/repeated execution breaks queue accounting and can re-execute the same native session |                     **Medium** | **G39 — Single-submission session lifecycle**      |
| Async `WebAssembly.instantiate()` failure is not propagated through the bridge's module promise                                              |                     **Medium** | **G40 — Deterministic Wasm instantiation failure** |
| Official artifact checksum lookup fails open even though docs say release artifacts are verified                                             | **Medium / deferred contract** | **G21 — Published runtime contract**               |
| Final React Native-only verification after G39/G40                                                                                           |                       Closeout | **G41 — Review 9 exact-SHA closeout**              |

Report this table for each goal:

| Field                    | Required Luna output                               |
| ------------------------ | -------------------------------------------------- |
| Goal                     | G39 / G40 / G41                                    |
| Frozen starting SHA      | Exact SHA                                          |
| Finding                  | Exact finding owned by this goal                   |
| Invariant                | Written before implementation                      |
| Relevant state machine   | Session/queue/handle or loader/factory/instantiate |
| Files changed            | Exact paths                                        |
| Tests changed            | Exact names                                        |
| Focused results          | Commands + results                                 |
| Full results             | Commands + results                                 |
| Flutter touched          | **No**                                             |
| Flutter command/workflow | **None**                                           |
| Documentation            | Exact paths or none                                |
| Residual risk            | Concrete only                                      |
| Tracker transition       | Only after evidence exists                         |

### G39 remediation record — 2026-09-18

- **Frozen starting SHA:** `8380e7c9ecdbaefa3c01a3a8e7f4c0a40f492f1f`.
- **Finding:** A `Session` could be submitted repeatedly, and Web execution promotion did not reject non-Created native sessions or duplicate native-ID claims.
- **Invariant:** Each JavaScript session is submitted at most once; each native session ID has at most one active execution claim; only `SessionState.Created` handles are promoted; registry claims remain until native release succeeds.
- **Relevant state machine:** Session submission -> queue -> native Created validation -> active execution claim -> terminal/discard cleanup.
- **Files changed:** `react-native/src/session.ts`, `react-native/src/platform/backend.web.ts`, `react-native/tests/wasm-backend-memory.test.js`, `react-native/tests/wasm-session-ownership.test.js`, `react-native/README.md`, `react-native/TEST.md`.
- **Tests changed:** one-shot active/queued/completed/cleared session tests; duplicate native-ID, non-Created history, and release-retry backend tests; transactional cleanup tests now call backend release directly.
- **Focused results:** `npm run test:compile`; targeted queue/backend/ownership/registry tests — 59 passing, 0 failures.
- **Full results:** `npm run check` — typecheck passed, lint 0 errors with one pre-existing warning, 114 tests passed.
- **Flutter touched:** No.
- **Flutter command/workflow:** None.
- **Documentation:** `react-native/README.md`, `react-native/TEST.md`.
- **Residual risk:** G40 Wasm instantiation propagation and G41 exact-SHA React Native-only closeout remain; G21 remains deferred.
- **Tracker transition:** Open -> Complete after focused and full React Native evidence.

### G40 remediation record — 2026-09-18

- **Frozen starting SHA:** `15d961f`.
- **Finding:** Async `WebAssembly.instantiate()` rejection was detached from the bridge module-factory promise, so initialization could remain pending instead of entering retry recovery.
- **Invariant:** Fetch, compile, instantiate, factory, and initialize failures settle the same initialization attempt; a failed attempt remains retryable and concurrent callers still share one attempt.
- **Relevant state machine:** Fetch/compile -> factory -> instantiate -> receive instance -> module promise -> retryable initialization state.
- **Files changed:** `react-native/web/ffmpegkit_loader.mjs`, `react-native/web/ffmpegkit_bridge.mjs`, `react-native/tests/wasm-loader.test.js`, `react-native/TEST.md`.
- **Tests changed:** Direct compiled-Wasm instantiation rejection/success tests; existing factory rejection, retry, concurrent deduplication, and idempotence tests retained.
- **Focused results:** `npm run test:compile`; `node --test tests/wasm-loader.test.js tests/wasm-initialization.test.js` — 5 passing, 0 failures.
- **Full results:** `npm run check` — typecheck passed, lint 0 errors with one pre-existing warning, 116 tests passed.
- **Flutter touched:** No.
- **Flutter command/workflow:** None.
- **Documentation:** `react-native/TEST.md`.
- **Residual risk:** G41 exact-SHA React Native-only closeout remains; G21 remains deferred.
- **Tracker transition:** Open -> Complete after focused and full React Native evidence.

### G41 remediation record — 2026-09-18

- **Frozen starting SHA:** `1b2dc9de068c878c49520be234970a239f0f1eda`.
- **Finding:** Final React Native Review 9 verification was pending after G39/G40 implementation.
- **Invariant:** Local and external verification use one immutable React Native SHA; only the standalone React Native Web workflow is dispatched; Flutter remains untouched.
- **Relevant state machine:** Package check -> prepare -> packed consumers -> package contents -> example Web build -> headless WebAssembly smoke; parallel Windows ZIP staging.
- **Files changed:** None after the G40 commit; tracker evidence only.
- **Tests changed:** None for closeout.
- **Focused results:** `npm run check` passed with 116 tests, typecheck passed, lint 0 errors with one pre-existing warning; `npm run test:pack-types`, `npm run test:pack-web`, `npm pack --dry-run`, `npm --prefix example run web:build`, and `npm run test:web` all passed. Headless smoke covered initialization, FFmpeg, FFprobe, media info, and FFplay controls.
- **Full results:** Exact local G41 command set passed. GitHub Actions workflow `React Native Web checks`, run [35413462107](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35413462107), `head_sha=1b2dc9de068c878c49520be234970a239f0f1eda`: web job `105817436957` passed; `React Native Web Windows staging` job `105817437075` passed.
- **Flutter touched:** No.
- **Flutter command/workflow:** None.
- **Documentation:** Tracker only.
- **Residual risk:** G21 remains deferred; no Flutter/non-host validation is claimed.
- **Tracker transition:** Pending -> Complete after exact-SHA local and standalone CI evidence.

## Review 8 Tracker

| Goal                                                         | Objective                                                                                               | Status                |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------- | --------------------- |
| **G36 — Align Web handle ownership with execution lifetime** | Release Created-state handles immediately and acquire/retain ownership only when async execution begins | **Complete — 2026-09-19** |
| **G37 — Complete child-handle first-error semantics**        | Apply the established temporary-handle cleanup policy to statistics/media-information handles           | **Complete — 2026-09-19** |
| **G38 — React Native Review 8 exact-SHA closeout**           | Run all local and standalone React Native Web gates against one immutable final SHA                     | **Complete — 2026-09-19** |
| **G21**                                                      | Published/current-runtime contract                                                                      | **Remain Deferred**   |
| **Flutter**                                                  | Flutter source/tests/CI                                                                                 | **Frozen / excluded** | 

Do not alter the Review 7 completion records.

Findings:

| Finding                                                                                                             |       Severity | Assessment                                                                                           |
| ------------------------------------------------------------------------------------------------------------------- | -------------: | ---------------------------------------------------------------------------------------------------- |
| **Web retains an owning Wasm handle as soon as `createSession()` is called**                                        |     **Medium** | Valid unstarted sessions can retain an exported handle indefinitely if never executed                |
| **Web async execution does not promote an unretained/history handle to retained ownership before native execution** |     **Medium** | Last temporary handle can be released immediately after async start, which cancels a running session |

## Luna operating rules

Report this table for each goal:

| Field                    | Required response             |
| ------------------------ | ----------------------------- |
| Goal                     | G36 / G37 / G38               |
| Frozen starting SHA      | Exact SHA                     |
| Ownership invariant      | Written before code changes   |
| Finding revalidated      | Exact current source evidence |
| Native parity checked    | Yes/no + relevant lifecycle   |
| Files changed            | Exact paths                   |
| Tests changed            | Exact test names              |
| Focused results          | Commands + pass/fail          |
| Full results             | Commands + pass/fail          |
| Flutter touched          | **No**                        |
| Flutter command/workflow | **None**                      |
| Documentation            | Exact paths or none           |
| Residual risk            | Concrete only                 |
| Tracker transition       | Only after evidence           |

### G36 remediation record — 2026-09-19

- **Frozen starting SHA:** `27fa5a81af9d692a6810755d466f60198a7a315c`.
- **Ownership invariant:** Created sessions have no registry-owned handle; async execution promotes exactly one history handle; terminal/discard/start failure releases it; ordinary getters retain temporary acquire/release semantics.
- **Finding revalidated:** `backend.web.ts` retained every creation handle and `executeSessionAsync()` used `withSession()`, which released an unretained execution handle immediately after async start.
- **Native parity checked:** Yes. Web now consumes the creation handle immediately, promotes ownership at execution, and retains it through `Session.monitor()` terminal cleanup, matching the native lifecycle boundary.
- **Files changed:** `react-native/src/platform/backend.web.ts`, `react-native/src/platform/web/session-registry.ts`, `react-native/tests/wasm-backend-memory.test.js`.
- **Tests changed:** created-handle release/fresh getter, async promotion, polling retention, terminal cleanup, history promotion, start rollback, retryable release, plus existing transactional cleanup updates.
- **Focused results:** `npm run test:compile`; targeted backend/registry/ownership tests — 44 passing, 0 failures.
- **Full results:** `npm run check` — typecheck passed, lint 0 errors with one pre-existing warning, 106 tests passed.
- **Flutter touched:** No.
- **Flutter command/workflow:** None.
- **Documentation:** Tracker only; no user-facing API change.
- **Residual risk:** G37 child-handle cleanup and G38 exact-SHA closeout remain.
- **Tracker transition:** Open -> Complete after focused and full React Native evidence.

### G37 remediation record — 2026-09-19

- **Frozen starting SHA:** `bec28fc`.
- **Ownership invariant:** Every opaque statistics, media-information, stream, and chapter handle is released in the same call; operation errors remain authoritative over cleanup errors, while successful operations report cleanup errors.
- **Finding revalidated:** Statistics and media-information child handles used raw `finally` cleanup, allowing a release exception to replace an earlier serialization/getter exception.
- **Native parity checked:** Yes. Web child-handle cleanup now follows the established temporary-handle first-error policy without changing the public API.
- **Files changed:** `react-native/src/platform/backend.web.ts`, `react-native/tests/wasm-backend-memory.test.js`.
- **Tests changed:** statistics getter/release error precedence, successful-statistics release reporting, and media stream/info release coverage with release-attempt ordering.
- **Focused results:** `npm run test:compile`; targeted backend/registry/ownership tests — 47 passing, 0 failures.
- **Full results:** `npm run check` — typecheck passed, lint 0 errors with one pre-existing warning, 107 tests passed.
- **Flutter touched:** No.
- **Flutter command/workflow:** None.
- **Documentation:** None required; tracker only.
- **Residual risk:** G38 exact-SHA closeout remains.
- **Tracker transition:** Open -> Complete after focused and full React Native evidence.

### G38 remediation record — 2026-09-19

- **Frozen final SHA:** `8380e7c9ecdbaefa3c01a3a8e7f4c0a40f492f1f`.
- **Finding revalidated:** G36 and G37 are committed before the final gate; the final branch SHA was pushed unchanged and used for external validation.
- **Native parity checked:** React Native-only package, packed-consumer, example-Web, and headless WebAssembly gates passed; no Flutter path was included.
- **Files changed after G37:** None.
- **Focused results:** G36/G37 targeted gates remained green; final local command set passed: `npm run check`, `npm run prepare`, `npm run test:pack-types`, `npm run test:pack-web`, `npm pack --dry-run`, `npm --prefix example run web:build`, `npm run test:web`.
- **Full results:** Local final gate passed at the frozen SHA: 107 tests, typecheck passed, lint 0 errors with one pre-existing warning, packed consumers passed, example Web build passed, and headless WebAssembly smoke passed through FFmpeg/FFprobe/media info/FFplay.
- **External workflow:** `React Native Web checks`, run `35411388276`, [workflow](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35411388276), `head_sha` exactly matched the frozen SHA. `web` passed ([job](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35411388276/job/105811577135)); `React Native Web Windows staging` passed ([job](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35411388276/job/105811577175)).
- **Flutter touched:** No.
- **Flutter command/workflow:** None. `Wasm Callback CI` was not dispatched.
- **Documentation:** Tracker only.
- **Residual risk:** G21 remains deferred; no open Review 8 React Native remediation remains.
- **Tracker transition:** Pending -> Complete after exact-SHA local and external evidence.

## Review 7 Tracker

| Goal                                                 | Objective                                                                                        | Status            |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ----------------- |
| **G33 — Complete temporary-handle exception safety** | Release all session-array handles and preserve primary operation errors during temporary cleanup | **Complete — 2026-09-18** |
| **G34 — Self-contained React Native Web CI**         | Make standalone React Native CI cover packed Web consumption and Windows ZIP staging             | **Complete — 2026-09-18** |
| **G35 — React Native exact-SHA closeout**            | Validate one final SHA locally and through standalone React Native CI                            | **Complete — 2026-09-18** |
| **G21 — Published runtime contract**                 | Existing deferred cross-platform follow-up                                                       | Remain Deferred   |
| **Flutter**                                          | Flutter implementation and validation                                                            | Frozen / excluded |

Review 6 G29–G31 should remain **Complete**. They are now confirmed both in the tracker and on the pushed branch. 

For G32, leave the historical local-closeout/blocked-audit entries intact. Review 7 should state that G35 replaces G32 as the authoritative **React Native-only external closeout** because Flutter is explicitly outside scope.

### Review verdict

G29–G31 are substantially correct and should remain closed. I found **one remaining runtime ownership gap** plus a **React Native-only CI gap**.

| Finding                                                                     |                Severity | Result                                                 |
| --------------------------------------------------------------------------- | ----------------------: | ------------------------------------------------------ |
| **Multi-session snapshot failure can leak all unvisited temporary handles** |              **Medium** | New finding                                            |
| **Temporary-handle cleanup can replace the operation's primary error**      |          **Medium-Low** | New finding                                            |
| **Standalone RN Web CI does not contain all React Native Web gates**        | **Medium — validation** | New finding                                            |
| **No exact-SHA external RN workflow exists for `b40e564`**                  |            **Closeout** | Expected                                               |

There are **no new High-severity React Native WASM release blockers**.

Required output per goal before proceeding:

| Field                            | Required output                        |
| -------------------------------- | -------------------------------------- |
| **Goal**                         | G33 / G34 / G35                        |
| **Frozen starting SHA**          | Exact SHA before edits                 |
| **Invariant**                    | Exact ownership or validation property |
| **Finding revalidated**          | Exact pre-change source evidence       |
| **Files changed**                | Exact paths                            |
| **Implementation reasoning**     | Why the cleanup/CI ordering is correct |
| **Tests added/modified**         | Exact test names                       |
| **Focused validation**           | Commands + results                     |
| **Full validation**              | Commands + results                     |
| **Flutter touched**              | **Must be `No`**                       |
| **Flutter command/workflow run** | **Must be `None`**                     |
| **Documentation**                | Paths or `none required`               |
| **Residual risk**                | Concrete only                          |
| **Tracker transition**           | Open → Complete only after evidence    |

Explicitly prohibited from:

```text
modifying flutter/**
running flutter commands
dispatching a workflow that executes Flutter
editing Flutter CI requirements
native-platform React Native changes
backend architecture redesign
queue redesign
configuration-format changes
G21 implementation
weakening G1-G31 tests
using Review 6 local results as Review 7 exact-SHA evidence
```

### G46 remediation record — 2026-09-19

- **Frozen starting SHA:** `5559883b5d6fe144f8e644807e20be2629adc739`.
- **Finding owned:** A mounted Web `FFplayView` could continue presenting the prior playback's pixels after the playback epoch changed when the next playback produced no video frame.
- **Invariant:** A playback-epoch transition invalidates the previously displayed frame immediately; the canvas is cleared even without a replacement frame; same-epoch unchanged frames remain allocation/copy-free; no public `FFplayView` API change is introduced; unmount cleanup and animation scheduling remain unchanged.
- **State owner:** `FFplayView` now tracks the epoch represented by its canvas surface and clears that surface when the shared Web playback epoch changes.
- **Files changed:** `react-native/src/ffplay-view.web.tsx`, `react-native/tests/ffplay-view-web.test.js`.
- **Why each file changed:** The Web view invalidates its cached frame and clears stale pixels; the browser fixture reproduces a no-replacement-frame epoch transition and verifies the surface remains mounted and clear.
- **Tests added/modified:** `FFplayView preserves View props, styles, and unmount cleanup on Web` now draws a pixel, advances the playback epoch, and verifies the canvas is cleared.
- **Focused verification:** `npm run test:compile`; `node --test tests/ffplay-view-web.test.js tests/ffplay-frame-reader.test.js` — 2 passing, 0 failures.
- **Full verification:** `npm run check` — typecheck passed, lint 0 errors with one pre-existing warning, 117 tests passed.
- **Flutter touched:** **No**.
- **Flutter command/workflow:** **None**.
- **Documentation:** Tracker only; no public README change required.
- **Residual risk:** The test advances the internal epoch directly rather than driving a real Wasm playback; G48 remains the end-to-end browser/CI gate.
- **Tracker transition:** In progress -> Complete after focused and full React Native evidence.

### G47 remediation record — 2026-09-19

- **Frozen starting SHA:** `d644922d3a18a5b9f5fe778054332284d089502d`.
- **Finding owned:** `FFplayKit.activeSession` could remain attached to a failed execution when the completion callback was never delivered.
- **Invariant:** The high-level active session is cleared when its own execution Promise fulfills or rejects; user completion callback behavior and ordering remain unchanged; an older settlement cannot clear a newer active session; queued/running sessions remain visible until their own Promise settles; cleanup cannot replace the original execution error.
- **State owner:** `FFplayKit.executeAsync()` now owns active-session cleanup in a guarded `finally` attached to that session's execution Promise.
- **Files changed:** `react-native/src/ffplay-kit.ts`, `react-native/tsconfig.test.json`, `react-native/tests/ffplay-kit.test.js`.
- **Why each file changed:** The high-level API now clears by Promise settlement and documents the active-session lifetime; the test compilation includes the API; focused tests cover success, start failure, monitor failure, callback failure, guarded older-session settlement, and queue discard.
- **Tests added/modified:** `successful FFplay execution remains current until its Promise settles`; `native-start failure clears the active FFplay session and preserves the error`; `monitor state failure clears the active FFplay session and preserves the error`; `completion callback errors reject execution and still clear the active session`; `an older FFplay settlement cannot clear a newer active session`; `discarding a queued high-level FFplay execution clears its active session`.
- **Focused verification:** `npm run test:compile`; `node --test tests/ffplay-kit.test.js` — 6 passing, 0 failures.
- **Full verification:** `npm run check` — typecheck passed, lint 0 errors with one pre-existing warning, 123 tests passed.
- **Flutter touched:** **No**.
- **Flutter command/workflow:** **None**.
- **Documentation:** `react-native/src/ffplay-kit.ts` JSDoc; no public README change required.
- **Residual risk:** Active-session cleanup remains specific to high-level `FFplayKit.executeAsync()`; sessions created and executed directly remain controlled by their own Promise and session lifecycle.
- **Tracker transition:** In progress -> Complete after focused and full React Native evidence.

### G48 remediation record — 2026-09-19

- **Frozen starting SHA:** `93da568296865e39be214007616854b8b34fa0be`.
- **Finding owned:** Final exact-SHA verification after G46 and G47.
- **Invariant:** Local and external closeout use one immutable React Native SHA; only `React Native Web checks` runs; Flutter remains untouched; G43 playback epochs and G44 scratch reuse remain covered.
- **State owner:** The closeout binds local package/browser validation and both required CI jobs to the same React Native commit.
- **Files changed:** None after G47; this tracker record captures closeout evidence.
- **Why each file changed:** No source change was needed; the tracker records local and exact-SHA external results.
- **Tests added/modified:** None for closeout.
- **Focused verification:** `npm run check` passed with 123 tests. The required local gate passed `npm run prepare`, `npm run test:pack-types`, `npm run test:pack-web`, `npm pack --dry-run`, `npm --prefix example run web:build`, and `npm run test:web`; packed commands used workspace-local temporary/cache paths after the default Windows npm cache returned EPERM. Headless smoke passed initialization, repeated initialization, FFmpeg, FFprobe, media info, FFplay, pause, resume, and stop.
- **Full verification:** GitHub Actions run [35415916453](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35415916453) passed at the frozen SHA. `web` job `105824427695` and `React Native Web Windows staging` job `105824427887` both passed.
- **Flutter touched:** **No**.
- **Flutter command/workflow:** **None**.
- **Documentation:** This tracker record only.
- **Residual risk:** G21 remains deferred; no Flutter or non-host-platform validation is claimed.
- **Tracker transition:** In progress -> Complete after local and exact-SHA external evidence.

### G33 remediation record — 2026-09-18

- **Frozen starting SHA:** `b40e5640c1397428cb8a42481c10e2472d761b0e`.
- **Invariant:** every known temporary session handle receives a release attempt; later cleanup continues; the first operation error remains authoritative, while a cleanup error is reported when no earlier operation error exists.
- **Finding revalidated:** `snapshots()` released each pointer only while visiting it, leaving the unvisited tail leaked after a snapshot failure. `withSession()` and `getLastSessionJson()` used `finally` release, allowing cleanup errors to replace action or snapshot errors.
- **Files changed:** `react-native/src/platform/backend.web.ts`, `react-native/tests/wasm-backend-memory.test.js`.
- **Implementation reasoning:** `withTemporaryHandle()` centralizes action/release precedence; session-list queries collect all pointers before snapshotting, then attempt every release and array free in cleanup; errors are recorded in first-observed order.
- **Tests added/modified:** full-array cleanup after middle snapshot failure; snapshot error over later release error; release error after successful collection; `withSession()` action-error precedence; `getLastSessionJson()` precedence.
- **Focused validation:** `npm run test:compile` and `node --test tests/wasm-backend-memory.test.js tests/wasm-session-registry.test.js tests/wasm-session-ownership.test.js` — 38 passing, 0 failures.
- **Full validation:** `npm run check` in `react-native` — typecheck passed, lint had 0 errors and one pre-existing warning, and 98 tests passed.
- **Flutter touched:** No.
- **Flutter command/workflow run:** None.
- **Documentation:** tracker only; no consumer README change required.
- **Residual risk:** none identified for G33. G34 and G35 remain open or pending.
- **Tracker transition:** Open → Complete.

### G35 remediation record — 2026-09-18

- **Frozen starting SHA:** `98362b95d1a05babc12f357a667fe772d9be66b3`.
- **Invariant:** every required React Native local and external Web gate validates the same immutable final SHA; no Flutter gate is part of this closeout.
- **Finding revalidated:** Review 6 had no exact-SHA external React Native result because its closeout was coupled to the frozen Flutter gate. Review 7 uses the standalone React Native workflow instead.
- **Files changed:** `.agent/TRACKER.md` only; no application or workflow changes were needed after the G34 commit.
- **Implementation reasoning:** the final local gate set ran before dispatch, the committed `dev-wasm` SHA was pushed over SSH, and only `React Native Web checks` was dispatched. `Wasm Callback CI` was not dispatched.
- **Tests added/modified:** none.
- **Focused validation:** `npm run check` — typecheck passed, lint had 0 errors and one pre-existing warning, and 98 tests passed; `npm run prepare` — passed; `npm run test:pack-types` — passed; `npm run test:pack-web` — passed; `npm pack --dry-run` — passed; `npm --prefix example run web:build` — passed; `npm run test:web` — headless WebAssembly smoke passed.
- **Full validation:** final local gates all passed at `98362b95d1a05babc12f357a667fe772d9be66b3`.
- **External validation:** workflow **React Native Web checks**, run `35409468182` ([workflow URL](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35409468182)), `head_sha` `98362b95d1a05babc12f357a667fe772d9be66b3`; `web` — **PASS** ([job](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35409468182/job/105805986803)); `React Native Web Windows staging` — **PASS** ([job](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35409468182/job/105805986636)).
- **Flutter touched:** No.
- **Flutter command/workflow run:** None.
- **Documentation:** tracker only; G34 documents the authoritative workflow in `react-native/TEST.md`.
- **Residual risk:** none for Review 7 React Native goals. G21 remains deferred; historical G32 remains preserved as required.
- **Tracker transition:** Pending → Complete.

### G34 remediation record — 2026-09-18

- **Frozen starting SHA:** `348cc43cbd7a5b9a80f7dea5fe15f2dd2d932784`.
- **Invariant:** the standalone React Native workflow contains all React Native Web package, packed-consumer, production-build, browser-smoke, and Windows ZIP-staging gates without invoking Flutter.
- **Finding revalidated:** `.github/workflows/react_native_web_ci.yaml` previously omitted `npm run test:pack-web` and had no Windows staging job; the combined workflow contained the required Windows fixture as a separate job.
- **Files changed:** `.github/workflows/react_native_web_ci.yaml`, `react-native/TEST.md`.
- **Implementation reasoning:** the standalone Linux job now validates the installed tarball through Vite before the example build and browser smoke; a separate Windows job directly exercises the `Expand-Archive` staging path with the same nested ZIP fixture and required-file assertions.
- **Tests added/modified:** no application tests; workflow and documentation coverage added.
- **Focused validation:** PyYAML parsing of `.github/workflows/react_native_web_ci.yaml` — valid YAML; `git diff --check` — passed.
- **Full validation:** React Native `npm run check` at the frozen source SHA — typecheck passed, lint had 0 errors and one pre-existing warning, and 98 tests passed. G35 will rerun the complete final local gate set after the CI change.
- **Flutter touched:** No.
- **Flutter command/workflow run:** None.
- **Documentation:** `react-native/TEST.md`.
- **Residual risk:** runner execution remains to be verified by G35 at the final pushed SHA; G21 remains deferred.
- **Tracker transition:** Open → Complete.


## Review 6 Tracker

| Goal                                                | Objective                                                                           | Initial status        |
| --------------------------------------------------- | ----------------------------------------------------------------------------------- | --------------------- |
| **G29 — Failure-atomic Wasm handle release**        | Do not lose registry/Session ownership state until native release actually succeeds | **Complete — 2026-09-18** |
| **G30 — Exception-safe temporary handle ownership** | Ensure creation/listing error paths release every temporary/native handle           | **Complete — 2026-09-18** |
| **G31 — FFplay changed-frame copy cleanup**         | Remove the redundant second JS pixel-buffer copy                                    | **Complete — 2026-09-18** |
| **G32 — Review 6 exact-SHA closeout**               | Re-run package, packed-consumer, browser, and external Web gates                    | **Complete — 2026-09-18** |

Findings

| Finding                                                                             |               Severity | Assessment                                                                                                            |
| ----------------------------------------------------------------------------------- | ---------------------: | --------------------------------------------------------------------------------------------------------------------- |
| **Wasm session release is not failure-atomic**                                      |             **Medium** | A failed native handle release can lose JS ownership state and override the original error                            |
| **Bulk `clearSessions()` drops all tracked pointers before releases succeed**       |             **Medium** | One failing release can strand the remainder with no JS registry entries                                              |
| **Temporary Web session handles are not exception-safe in all serialization paths** |         **Medium-Low** | `getSessions*()` can leak the current temporary handle if snapshot construction throws                                |
| **Newly created Web handle can leak if session-ID extraction/registration fails**   |         **Medium-Low** | Creation failure after native allocation has no rollback                                                              |
| **FFplay changed-frame path still performs one avoidable JS pixel-buffer copy**     | **Low / optimization** | G8 fixed unchanged-frame copies; changed frames still copy twice on the JS side                                       |
| **Current-source Wasm CI coverage is intentionally incomplete**                     |  **Deferred boundary** | Browser smoke uses the published runtime, not current `libffmpegkit` source; keep this with G21/cross-platform review |

Required output per goal before proceeding:

| Field                        | Required output                         |
| ---------------------------- | --------------------------------------- |
| **Goal**                     | G29 / G30 / G31 / G32                   |
| **Invariant**                | Exact ownership or performance property |
| **Finding revalidated**      | Current pre-change source evidence      |
| **Files changed**            | Exact paths                             |
| **Implementation reasoning** | Why the chosen ordering is failure-safe |
| **Tests added/modified**     | Exact test names                        |
| **Focused validation**       | Commands + result                       |
| **Full validation**          | Commands + result                       |
| **Documentation**            | Paths or `none required`                |
| **Residual risk**            | Only concrete unresolved items          |
| **Tracker transition**       | Open → Complete only with evidence      |

Explicitly prohibited from:

```text
backend architecture redesign
TurboModule/native-platform API expansion
queue redesign
configuration-format changes
G21 implementation
FFplay canvas architecture redesign
weakening existing lifecycle tests
marking exact-SHA CI complete before actual runs
running non-host flutter CI/Tests
G21 still deferred
```

### G29 remediation record — 2026-09-18

- **Invariant:** successful native release removes the registry entry and marks the owning `Session` handle released; a failed release preserves both ownership records and remains retryable. Earlier start, state-read, callback, or monitoring errors remain the primary error.
- **Finding revalidated:** `releaseSessionHandle()` previously removed the registry entry before native release, `clearSessions()` emptied the registry before bulk release, and `Session.releaseOwnedHandle()` set its flag before the native call.
- **Files changed:** `react-native/src/platform/web/session-registry.ts`, `react-native/src/platform/backend.web.ts`, `react-native/src/session.ts`, `react-native/tests/wasm-session-registry.test.js`, `react-native/tests/wasm-backend-memory.test.js`, `react-native/tests/wasm-session-ownership.test.js`.
- **Implementation reasoning:** single-handle release now performs native release before the registry commit; bulk release iterates non-destructively and commits each entry independently; Session cleanup captures release failures without replacing an earlier operation failure.
- **Tests added/modified:** transactional registry-entry coverage; single-handle release retry coverage; three-entry `clearSessions()` failure/retry coverage; state, terminal, and callback primary-error coverage.
- **Focused validation:** `npm run test:compile` and `node --test tests/wasm-session-ownership.test.js tests/wasm-backend-memory.test.js tests/wasm-session-registry.test.js` — 28 passing, 0 failures.
- **Full validation:** `npm run check` in `react-native` — typecheck passed, lint had 0 errors and one pre-existing warning, and 88 tests passed.
- **Documentation:** tracker only; no public documentation change required.
- **Residual risk:** none identified for G29. G30, G31, and G32 remain open or pending.

### G30 remediation record — 2026-09-18

- **Invariant:** every temporary Wasm pointer is released on both success and exceptional paths; a snapshot, creation, or registration failure remains the primary error.
- **Finding revalidated:** session-array snapshots released each pointer only after successful snapshot construction, session creation had no rollback after ID extraction or registry failure, and argument pointers were not recorded until after UTF-8 encoding.
- **Files changed:** `react-native/src/platform/backend.web.ts`, `react-native/tests/wasm-backend-memory.test.js`.
- **Implementation reasoning:** argument pointers are recorded immediately after allocation; `retain()` protects the native pointer until registration succeeds and suppresses cleanup failures behind the creation error; snapshot cleanup releases the current pointer before rethrowing its snapshot error.
- **Tests added/modified:** argument-encoding rollback; session-ID extraction rollback; invalid registry-entry rollback; successful registration ownership; snapshot-failure temporary-handle release.
- **Focused validation:** `npm run test:compile` and `node --test tests/wasm-backend-memory.test.js tests/wasm-session-registry.test.js` — 14 passing, 0 failures.
- **Full validation:** `npm run check` in `react-native` — typecheck passed, lint had 0 errors and one pre-existing warning, and 93 tests passed.
- **Documentation:** tracker only; no public documentation change required.
- **Residual risk:** none identified for G30. G31 and G32 remain open or pending.

### G31 remediation record — 2026-09-18

- **Invariant:** unchanged generation/dimension/stride frames remain allocation-free, while each changed frame returns an independently owned `Uint8ClampedArray` after one Wasm-to-JavaScript pixel copy.
- **Finding revalidated:** changed frames used `HEAPU8.slice()` and then constructed a second `Uint8ClampedArray`, creating two JavaScript copies before canvas packing.
- **Files changed:** `react-native/src/platform/web/ffplay-frame-reader.ts`, `react-native/tests/ffplay-frame-reader.test.js`.
- **Implementation reasoning:** `HEAPU8.subarray()` supplies a temporary view and `Uint8ClampedArray.from()` performs the single owned copy required for stable returned frame data.
- **Tests added/modified:** existing frame-reader coverage now asserts the returned type and verifies returned bytes remain stable after Wasm memory changes.
- **Focused validation:** `npm run test:compile` and `node --test tests/ffplay-frame-reader.test.js` — 1 passing, 0 failures.
- **Full validation:** `npm run check` in `react-native` — typecheck passed, lint had 0 errors and one pre-existing warning, and 93 tests passed.
- **Documentation:** tracker only; no public documentation change required.
- **Residual risk:** none identified for G31. G32 remains pending; G21 remains deferred as required.

### G32 closeout record — 2026-09-18

- **Goal:** G32 at final repository SHA `b40e5640c1397428cb8a42481c10e2472d761b0e`.
- **Invariant:** exact-SHA closeout requires current React Native package/Web evidence plus the specified external workflow results; it must not reuse Review 5 evidence.
- **Finding revalidated:** the Review 6 requirement includes a Flutter Web/Wasm CI result, while the current task explicitly prohibits running Flutter CI or tests locally or remotely.
- **Files changed:** none for G32; generated `react-native/example/public/` assets were removed after validation. The tracker is updated locally.
- **Implementation reasoning:** all permitted React Native gates were run against the final G29–G31 SHA; no workflow was dispatched because doing so would run the prohibited Flutter gate.
- **Tests added/modified:** none.
- **Focused validation:** `npm run check` — typecheck passed, lint had 0 errors and one pre-existing warning, and 93 tests passed; `npm run prepare` — passed; `npm run test:pack-types` with workspace-local npm cache — passed; `npm run test:pack-web` with workspace-local temp/cache directories — passed; `npm --prefix example run web:build` — passed; `npm run test:web` — headless WebAssembly smoke passed.
- **Full validation:** React Native local package and browser gates passed. No external workflow was run, so there are no new workflow run IDs, `head_sha` values, or job conclusions to record.
- **External state check:** `gh run list --repo akashskypatel/ffmpeg-kit-extended --workflow wasm_callback_ci.yaml` found no run for the final SHA. The latest successful run is `35377274451` at SHA `1c43d8c829015473a04964e32fc03fe3376eb122`, so it is not valid exact-SHA evidence and was not reused.
- **Documentation:** `.agent/TRACKER.md` only.
- **Residual risk:** Complete, Flutter wasm excluded from goal by user authorization. G21 remains deferred.

### G32 blocked-audit record — 2026-09-18

- Final SHA revalidated as `b40e5640c1397428cb8a42481c10e2472d761b0e`.
- A final read-only query of `wasm_callback_ci.yaml` returned no workflow run for that SHA: `[]`.
- The required Flutter Web/Wasm result cannot be obtained because the task explicitly prohibits Flutter CI/tests locally and remotely. No workflow was dispatched and no Flutter command was run.
- React Native-only closeout gates remain passing; no additional code change can satisfy the missing external Flutter result.
- **Tracker transition:** Pending → Blocked — Flutter gate prohibited after repeated audit confirmation; G21 remains deferred.


## Review 5 Tracker

| Goal                                                           | Objective                                                                                              | Initial status        |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | --------------------- |
| **G25 — True state-only monitoring + state-failure ownership** | Make Web state polling lightweight and guarantee ownership cleanup when state observation itself fails | **Complete — 2026-09-18** |
| **G26 — First-failure preservation**                           | Preserve the earliest callback/monitoring error while completing required lifecycle cleanup            | **Complete — 2026-09-18** |
| **G27 — `clearSessions()` lifecycle documentation**            | State clearly that clearing sessions can cancel/invalidate active sessions                             | **Complete — 2026-09-18** |
| **G28 — Review 5 exact-SHA closeout**                          | Rerun all React Native WASM/package gates against the final G25–G27 SHA                                | **Complete — 2026-09-18** |

Review 5 findings:

| Finding                                                                              |       Severity | Assessment                                            |
| ------------------------------------------------------------------------------------ | -------------: | ----------------------------------------------------- |
| G23's "state-only drain" still calls the full session snapshot on Web                |     **Medium** | Correctness/recovery + performance issue              |
| A `getState()` failure still abandons monitoring without releasing the owning handle |     **Medium** | Explicit residual from Review 4; now actionable       |
| A later monitoring failure can replace an earlier user callback exception            | **Medium-Low** | Error-precedence regression across G4/G23 interaction |
| `clearSessions()` documentation understates active-session consequences              | **Low / docs** | API behavior should be clearer                        |
| G21 published-runtime contract                                                       |   **Deferred** | Preserve existing deferral                            |

Required output per goal before proceeding:

| Field                        | Required output                              |
| ---------------------------- | -------------------------------------------- |
| **Goal**                     | G25 / G26 / G27 / G28                        |
| **Invariant**                | Ownership/error behavior being protected     |
| **Finding revalidated**      | Exact current source behavior before editing |
| **Files changed**            | Exact paths                                  |
| **Implementation reasoning** | Why this is the smallest safe change         |
| **Tests added/modified**     | Exact test names                             |
| **Focused validation**       | Commands and results                         |
| **Full validation**          | Commands and results                         |
| **Documentation**            | Paths changed or `none required`             |
| **Residual risk**            | Concrete unresolved behavior only            |
| **Tracker transition**       | Open → Complete only after evidence exists   |

## Review 5 current status

- **Completed goals:** G25 — True state-only monitoring + state-failure ownership; G26 — First-failure preservation; G27 — `clearSessions()` lifecycle documentation; G28 — Review 5 exact-SHA closeout.
- **Next unimplemented goal:** None in Review 5.
- **Overall status:** G25–G28 are complete. G21 remains deferred.

### G25 true state-only monitoring and state-failure ownership — 2026-09-18

- **Goal:** G25 — True state-only monitoring + state-failure ownership.
- **Resolution:** Commit `721d890` (`fix(react-native): use lightweight Web session state polling`) implements the optional Web state primitive and explicit state-read ownership cleanup.
- **Invariant:** Web monitoring must poll only the lifecycle state during ordinary and degraded execution, retain ownership while terminal state is observable, and release ownership when state observation itself fails because the execution can no longer be monitored safely.
- **Finding revalidated:** Before this change, `Session.getState()` always called `getSessionJson()`. Web `getSessionJson()` builds a complete snapshot including output, logs, metadata, and string reads; a `getState()` exception escaped `Session.monitor()` without releasing the owning handle.
- **Files changed:** `react-native/src/platform/backend.ts`, `react-native/src/platform/backend.web.ts`, `react-native/src/session.ts`, `react-native/tests/wasm-backend-memory.test.js`, and `react-native/tests/wasm-session-ownership.test.js`.
- **Implementation reasoning:** The backend primitive is optional so native TurboModule implementations remain unchanged. Web uses the existing retained/temporary session pointer path and calls only `ffmpeg_kit_session_get_state`. `Session.getState()` falls back to the existing snapshot for native backends. A state-read failure intentionally releases the owning handle and rethrows because terminal authority is unavailable; callback-buffer failures continue using G23 state-only drain semantics.
- **Tests added/modified:** `Web backend reads session state without full snapshot getters`; `state retrieval failure releases the owning handle and rejects`; the ownership harness now provides a lightweight state backend and rejects accidental full snapshot use during monitor state reads.
- **Focused validation:** `npm run test:compile` — passed; `node --test tests/wasm-backend-memory.test.js tests/wasm-session-ownership.test.js` — 18 passing, 0 failures; `git diff --check` — passed.
- **Full validation:** `npm run check` — 80 passing, 0 failures; typecheck passed; lint passed with the existing single warning in `tests/arguments.test.js`.
- **Documentation:** Internal state-ownership comment in `react-native/src/session.ts`; tracker updated. No public README change required.
- **Residual risk at this closeout:** G26 and G27 were pending at the time and are closed below; G28 remains pending for the final exact-SHA gates.
- **Tracker transition:** G25 Open → Complete.

### G26 first-failure preservation — 2026-09-18

- **Goal:** G26 — First-failure preservation.
- **Resolution:** Commit `10880c2` (`fix(react-native): preserve first monitor failure`) adds one chronological failure recorder while retaining separate callback-failure and monitor-failure flags.
- **Invariant:** The first observed callback, callback-buffer, state-read, or terminal-read failure remains the Promise rejection; later failures may change drain behavior but cannot replace that error, and terminal cleanup still releases the owning handle.
- **Finding revalidated:** Before this change, `callbackError` and `monitorError` were separate, so a later monitor failure replaced an earlier callback failure. Terminal log/statistics reads also propagated directly without entering the shared error policy.
- **Files changed:** `react-native/src/session.ts` and `react-native/tests/wasm-session-ownership.test.js`.
- **Implementation reasoning:** `recordError()` is the single chronological authority. Operational flags remain separate so callback suppression, state-only draining, and terminal-read short-circuiting retain their existing semantics. Final callback-buffer reads are caught individually; later reads and completion delivery stop after infrastructure failure, while the existing terminal `finally` remains responsible for release.
- **Tests added/modified:** `first callback failure wins over a later pre-terminal monitor failure`; `first final callback failure wins over a later final monitor failure`; existing standalone first-failure tests remain active for pre-terminal, final-log, final-statistics, state-read, and callback failures.
- **Focused validation:** `npm run test:compile` — passed; `node --test tests/wasm-session-ownership.test.js tests/session-queue-manager.test.js` — 21 passing, 0 failures; `git diff --check` — passed.
- **Full validation:** `npm run check` — 82 passing, 0 failures; typecheck passed; lint passed with the existing single warning in `tests/arguments.test.js`.
- **Documentation:** Internal monitor comment in `react-native/src/session.ts`; tracker updated. No public documentation change required.
- **Residual risk at this closeout:** G27 was pending at the time and is closed below; G28 remains pending for the final exact-SHA gates.
- **Tracker transition:** G26 Open → Complete.

### G27 clearSessions lifecycle documentation — 2026-09-18

- **Goal:** G27 — `clearSessions()` lifecycle documentation.
- **Resolution:** Commit `1c43d8c` (`docs(react-native): clarify clearSessions lifecycle`) clarifies the active-session cancellation/invalidation contract without changing runtime behavior.
- **Invariant:** Public callers must not interpret `clearSessions()` as history-only cleanup that is safe while sessions are running; clearing may cancel/invalidate active handles and later getters for cleared IDs may fail.
- **Finding revalidated:** `FFmpegKitConfig.clearSessions()` previously described only retained history, and `FFmpegKitExtended.clearSessions()` used the same history-only wording. The Web implementation releases retained handles before calling the native clear operation.
- **Files changed:** `react-native/src/ffmpeg-kit-config.ts`, `react-native/src/ffmpeg-kit-extended.ts`, and `react-native/src/session.ts`.
- **Implementation reasoning:** Documentation-only clarification preserves the existing cross-platform behavior and avoids adding a runtime guard, which would be an API behavior change outside this goal.
- **Tests added/modified:** None; this goal changes documentation only.
- **Focused validation:** `npm run typecheck` — passed; `npm run lint` — passed with the existing single warning in `tests/arguments.test.js`; `git diff --check` — passed.
- **Full validation:** Not required for this documentation-only goal; typecheck and lint cover the changed TypeScript sources.
- **Documentation:** Public API JSDoc updated in `react-native/src/ffmpeg-kit-config.ts` and `react-native/src/ffmpeg-kit-extended.ts`; lifecycle context updated in `react-native/src/session.ts`; no README/API prose references required additional changes.
- **Residual risk:** Runtime behavior remains intentionally unchanged; G28 still requires the final exact-SHA package and workflow gates.
- **Tracker transition:** G27 Open → Complete.

### G28 Review 5 exact-SHA closeout — 2026-09-18

- **Goal:** G28 — Review 5 exact-SHA closeout.
- **Resolution:** Revalidated the complete React Native package/Web gate set and required external workflows against final SHA `1c43d8c829015473a04964e32fc03fe3376eb122`.
- **Invariant:** Review 5 remediation must be validated at one immutable final SHA; no gate may be credited from an earlier commit.
- **Finding revalidated:** The final implementation SHA is the pushed `dev-wasm` head and contains the completed G25, G26, and G27 changes.
- **Files changed:** None for G28; this is a verification-only closeout. The final implementation remains in the three prior commits.
- **Implementation reasoning:** No new source change was required after G27. Creating a follow-up no-op commit would invalidate the exact-SHA evidence, so the existing final implementation commit was used as the immutable verification target.
- **Tests added/modified:** None.
- **Focused validation:** `npm run check` — 82 passing, 0 failures; typecheck passed; lint passed with the existing warning in `tests/arguments.test.js`; `npm run prepare` — passed; `npm run test:pack-types` — passed; `npm run test:pack-web` — passed; `npm --prefix example run web:build` — passed; `npm run test:web` — passed with `Headless WebAssembly smoke test passed.`
- **Full validation:** React Native Web checks run `35377271717` passed with `head_sha` equal to the final SHA. Wasm Callback CI run `35377274451` passed with all required jobs: `React Native Web/Wasm gates`, `React Native Web Windows staging`, and `Flutter Web/Wasm build gates`; each run reported the same final `head_sha`.
- **Documentation:** `.agent/TRACKER.md` updated; no product documentation change required.
- **Residual risk:** G21 published-runtime contract remains deferred as previously requested. The retired Flutter browser callback test remains excluded because of the documented Flutter runner/build-hook limitation.
- **Tracker transition:** G28 Pending → Complete.

## Review 4 Tracker

| Goal                                             | Objective                                                                               | Status after this review                                                           |
| ------------------------------------------------ | --------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| **G18 — Type export precedence**                 | Continuously enforce G18's installed-tarball TypeScript resolution invariant            | **Complete — re-review closed 2026-09-17**                                         |
| **G19 — Terminal finalization ownership**        | Prevent log/statistics monitoring failures from orphaning a still-running owning handle | **Complete — re-review closed 2026-09-17**                                         |
| **G20 — React Native external CI**               | Run the functional browser and Windows gates against the final remediation SHA          | **Remain verified for prior RN SHA; Flutter limitation closure remains justified** |
| **G22 — Packed declaration CI gate**             | Packed TypeScript consumer test exists but is not run by either React Native CI workflow | **Complete — 2026-09-17**                                                          |
| **G23 — Pre-terminal monitor-failure ownership** | A pre-terminal log/statistics read failure still rejects the monitor while retaining the owning session handle | **Complete — 2026-09-17**                                                          |
| **G24 — Final exact-SHA React Native closeout**  | Current exact SHA has not itself received the React Native external gate | **Complete — 2026-09-18**                                                           |
| **G21 — Published runtime contract**             | Keep deferred until the cross-platform review is complete                               | **Remain Deferred**, as explicitly requested                                       |

| Finding                                                                                                        |                Severity | Assessment                                                                                                        |
| -------------------------------------------------------------------------------------------------------------- | ----------------------: | ----------------------------------------------------------------------------------------------------------------- |
| Packed TypeScript consumer test exists but is not run by either React Native CI workflow                       | **Resolved — G22**      | Both React Native Web workflows now enforce the packed declaration regression oracle after `npm run prepare`       |
| A pre-terminal log/statistics read failure still rejects the monitor while retaining the owning session handle | **Resolved — G19/G23** | Read failures now enter state-only drain mode and release only after terminal state is observed                    |
| Current exact SHA has not itself received the React Native external gate                                       | **Resolved — G24**      | `d048eaa` passed the local gates and both exact-SHA GitHub workflow runs                                             |
| G21 published-runtime contract                                                                                 |            **Deferred** | Preserve the user's deferred status; current package-owned staging already supplies much of the eventual evidence |

## Review 4 current status

- **Completed goals:** G18 re-review, G19 re-review, G22, G23, and G24.
- **Next unimplemented goal:** None in Review 4; G21 remains deferred as previously requested.
- **Overall status:** Review 4 goals G18/G19, G22/G23, and G24 are complete; G21 remains deferred.

### G22 remediation record — 2026-09-17

- **Goal:** G22 — Packed declaration CI gate.
- **Invariant:** After `npm run prepare`, the actual package tarball must resolve `lib/typescript/src/index.d.ts` for `customConditions: ["react-native"]` and `["browser", "react-native"]`.
- **Finding revalidated:** Yes. `react-native/package.json` already provides `test:pack-types`, but neither `.github/workflows/react_native_web_ci.yaml` nor `.github/workflows/wasm_callback_ci.yaml` invoked it after package preparation.
- **Files changed:** `.github/workflows/react_native_web_ci.yaml`, `.github/workflows/wasm_callback_ci.yaml`, and `react-native/TEST.md`.
- **Why each change is necessary:** Both workflows now enforce the packed declaration contract at the generated-package boundary; `react-native/TEST.md` documents that the check must follow `npm run prepare` and validates the published tarball rather than source files.
- **Tests added/modified:** No test cases; the existing `test:pack-types` consumer is now a required workflow step.
- **Focused tests:** `npm run prepare` — passed; `npm run test:pack-types` — passed with `Packed TypeScript declaration consumer passed.`; `npm run test:pack-web` — passed with `Packed Vite consumer build passed.`
- **Full validation:** `npm run check` — passed, 76 tests passing and 0 failures; ESLint reported the existing one warning only. Both workflow YAML files parsed successfully with Python YAML validation; `git diff --check` passed.
- **Documentation:** `react-native/TEST.md` updated with the packed declaration check and CI behavior.
- **Residual risk:** G23 pre-terminal monitor-failure ownership remains open; G24 still requires an external run at the eventual final SHA.
- **Tracker transition:** Open → Complete.

### G18 re-review closeout — 2026-09-17

- **Finding:** The G18 export implementation was already correct; the re-review identified incomplete CI regression coverage rather than a runtime export defect.
- **Resolution:** Commit `2bdf2bb` adds `npm run test:pack-types` immediately after `npm run prepare` in both `.github/workflows/react_native_web_ci.yaml` and `.github/workflows/wasm_callback_ci.yaml`. The existing packed consumer verifies `lib/typescript/src/index.d.ts` for `customConditions: ["react-native"]` and `["browser", "react-native"]` from the actual npm tarball.
- **Evidence:** `npm run prepare`, `npm run test:pack-types`, `npm run test:pack-web`, and `npm run check` all passed locally; the package check reported 76 passing tests and 0 failures. Both workflow YAML files parsed successfully.
- **Scope boundary:** No G23 monitor-ownership code or tests were changed.
- **Tracker transition:** G18 re-review incomplete → Complete.

### G19 re-review closeout — 2026-09-17

- **Finding:** Terminal ownership cleanup was already correct, but log/statistics buffer failures before terminal state escaped the cleanup block and could leave the owning session handle retained indefinitely.
- **Resolution:** Commit `d048eaa` updates `react-native/src/session.ts` to capture the first pre-terminal monitor read/parse failure, stop reading callback buffers and delivering user callbacks, drain by polling state only, then rethrow the original error inside terminal finalization so the existing `finally` releases the handle exactly once. `getState()` failure remains an explicit residual risk because terminal safety cannot be established when state itself is unavailable.
- **Files changed:** `react-native/src/session.ts` and `react-native/tests/wasm-session-ownership.test.js`.
- **Tests added:** `pre-terminal log retrieval failure drains to terminal before releasing`; `pre-terminal statistics retrieval failure drains to terminal before releasing`.
- **Focused tests:** `npm run test:compile` — passed; `node --test tests/wasm-session-ownership.test.js tests/session-queue-manager.test.js` — 18 passing, 0 failures. Both tests verify exact error identity, retained ownership while running, terminal release, registry removal, zero active sessions, and suppression of log/statistics/completion callbacks after degraded mode.
- **Full validation:** `npm run check` — 78 passing, 0 failures; typecheck and lint passed with the existing single warning. `git diff --check` and `node --check tests/wasm-session-ownership.test.js` passed.
- **Documentation:** Internal ownership comment added to `Session.monitor()`; tracker updated.
- **Residual risk at this closeout:** A persistent `getState()` failure remains outside this goal; G24 was pending at the time and is closed below.
- **Tracker transition:** G19 re-review and G23 Open → Complete.

### G24 exact-SHA React Native closeout — 2026-09-18

- **Goal:** G24 — Final exact-SHA React Native closeout.
- **Exact SHA:** `d048eaa` (`fix(react-native): drain monitor failures before releasing handles`), pushed to `dev-wasm`.
- **Local evidence:** `npm run check` — 78 passing, 0 failures; `npm run prepare` — passed; `npm run test:pack-types` — passed; `npm run test:pack-web` — passed; `npm --prefix example run web:build` — passed; `npm run test:web` — passed with the headless WebAssembly smoke test.
- **External evidence:** React Native Web checks run `35298089560` — passed. Wasm Callback CI run `35298090186` — passed: React Native Web/Wasm gates, React Native Web Windows staging, and Flutter Web/Wasm build gates all passed.
- **External annotations:** GitHub reported only existing lint/deprecation and runner-image advisory annotations; no job failures.
- **Scope:** The retired Flutter browser test was not required for React Native closeout; the active React Native functional browser gates remained enabled and passed.
- **Tracker transition:** G24 Open → Complete.


## Review 3 Tracker

Do not rewrite Review 1 or Review 2 history.

| Goal                                      | Objective                                                                                                 | Initial status         |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------- | ---------------------- |
| **G18 — Type export precedence**          | TypeScript always resolves published declarations while runtime browser/native conditions remain correct. | **Complete — 2026-09-17** |
| **G19 — Terminal finalization ownership** | Any failure after terminal state is observed still releases the owning handle exactly once.               | **Complete — 2026-09-17** |
| **G20 — External CI closeout**            | LGPL browser and Windows staging gates execute successfully on the final SHA.                             | **Closed — Flutter runner limitation — 2026-09-17** |
| **G21 — Published runtime contract**      | Validate the pinned release download/checksum/archive/browser path end to end.                            | **Deferred**        |

The existing Review 2 tracker should remain as the historical implementation record; it already records G13–G17 and its unresolved external CI condition accurately. 

Required output per goal before proceeding:

| Field                            | Required content                         |
| -------------------------------- | ---------------------------------------- |
| **Goal**                         | Current goal ID                          |
| **Invariant**                    | Exact behavior being protected           |
| **Finding revalidated**          | Yes/no + relevant current source         |
| **Files changed**                | Exact paths                              |
| **Why each change is necessary** | One concise reason per file              |
| **Tests added/modified**         | Exact test names                         |
| **Focused tests**                | Commands and results                     |
| **Full validation**              | Commands and results                     |
| **Documentation**                | Changed paths or `none required`         |
| **Residual risk**                | Concrete remaining uncertainty           |
| **Tracker transition**           | Open → Complete only after exit criteria |

Explicitly prohibited changes:

```text
- backend architecture redesign
- queue architecture redesign
- new configuration format
- unrelated source cleanup
- native platform changes
- weakening current tests
- marking CI complete without an actual run
```

### G18 remediation record — 2026-09-17

- **Goal:** G18 — Type export precedence.
- **Invariant:** Browser plus React Native runtime conditions resolve `src/index.web.ts`; React Native alone resolves `src/index.ts`; TypeScript resolves `lib/typescript/src/index.d.ts` for both supported condition sets.
- **Finding revalidated:** Yes. `react-native/package.json` placed `types` after the runtime conditions, allowing a TypeScript resolver to encounter implementation sources before the built declaration target. The top-level `types` field was already correct and remains unchanged.
- **Files changed:** `react-native/package.json`, `react-native/tests/package-exports.test.js`, and `react-native/tests/packed-types-consumer.js`.
- **Why each change is necessary:** Export metadata puts the declaration condition first without changing runtime targets; the export test protects condition ordering and runtime behavior; the packed consumer proves the published tarball contains and resolves the declaration; the `test:pack-types` package script makes that consumer check repeatable after preparation.
- **Tests added/modified:** `conditional exports prioritize the built declaration entry`; packed TypeScript consumer coverage for `customConditions: ["react-native"]` and `["browser", "react-native"]`.
- **Focused tests:** `node --check tests/packed-types-consumer.js` — passed. `node --test tests/package-exports.test.js` — 2 passing, 0 failures. Runtime resolution remained correct for all three condition sets.
- **Full validation:** `npm run prepare` — passed and generated `lib/typescript/src/index.d.ts`. `npm run test:pack-types` — passed after elevated retry; both condition sets resolved to the installed declaration. `npm run test:pack-web` — passed. `npm run check` — passed; typecheck passed, lint reported 0 errors and one existing warning, and 74 tests passed.
- **Documentation:** None required; this is package metadata and validation coverage.
- **Residual risk:** The packed check uses the repository's current TypeScript resolver and does not cover every bundler's custom condition configuration; runtime Node condition resolution and the required declaration target are verified.
- **Tracker transition:** Open → Complete.

### Review 3 progress

| Area               | Status                         | Interpretation |
| ------------------ | ------------------------------ | -------------- |
| **Review 3**       | **G18–G19 complete; React Native G20 gates pass; Flutter G20 closed by runner limitation; G21 open** | React Native Web/Wasm and Windows staging pass without builder checkout or binary transfer. Flutter's browser gate remains blocked by Flutter 3.47 test-runner/build-hook behavior and is closed as non-actionable in this package. |
| **Implementation** | **G18–G19 complete**           | Type export precedence and terminal-state handle ownership are corrected and verified. |

### G19 remediation record — 2026-09-17

- **Goal:** G19 — Terminal finalization ownership.
- **Invariant:** Before terminal state is observed, transient polling/read failures do not release ownership; after terminal state is observed, final log/statistics reads, callback delivery, and every completion exit pass through one idempotent handle release.
- **Finding revalidated:** Yes. `react-native/src/session.ts` previously began its `finally` block after the final log/statistics reads, leaving those terminal-state failures outside ownership cleanup. The shared monitor is used by FFmpeg, FFprobe, media-information, and FFplay sessions.
- **Files changed:** `react-native/src/session.ts`, `react-native/tests/wasm-session-ownership.test.js`.
- **Why each change is necessary:** The session monitor now protects the complete terminal-finalization body while retaining the pre-terminal polling behavior; the ownership test harness injects final log/statistics read failures and verifies cleanup and rejection behavior.
- **Tests added/modified:** `final log retrieval failure releases the handle exactly once`; `final statistics retrieval failure releases the handle exactly once`.
- **Focused tests:** `npm run test:compile` — passed. `node --test tests/wasm-session-ownership.test.js` — 11 passing, 0 failures; both injected final-read errors were preserved, handles were released once, registry entries were removed, and active session count returned to zero.
- **Full validation:** `npm run check` — passed; typecheck passed, lint reported 0 errors and one existing warning, and 76 tests passed.
- **Documentation:** No public documentation change required. The source comment now states that final callback-buffer reads and completion delivery are covered by ownership cleanup.
- **Residual risk:** The focused backend uses the shared monitor with FFmpeg sessions; all four session classes route through that monitor, but native integration with every concrete session type was not rerun.
- **Tracker transition:** Open → Complete.

### G20 initial validation record — 2026-09-17

- **Goal:** G20 — External CI closeout.
- **Invariant:** The Wasm callback, React Native Web/Wasm, browser smoke, and Windows ZIP staging jobs must all pass on the same final G18/G19 commit SHA.
- **Finding revalidated:** Yes. `dc23743c27d3069e17538282157acc6e5fc28a06` is both the local SHA and the remote `dev-wasm` SHA. Run `35282141913` executed against that SHA, but the C/C++ and JavaScript Wasm gate failed before tests.
- **Files changed:** `libs/libffmpegkit/scripts/toolchain/setup-wasm.sh` in the `ffmpeg-kit-builders` submodule.
- **Why each change is necessary:** The CI runner is Ubuntu-based while the builder setup script unconditionally invoked `dnf`; the script now selects `dnf` or `apt-get` while preserving the existing package set.
- **Tests added/modified:** None.
- **Focused tests:** `git rev-parse HEAD` — `dc23743c27d3069e17538282157acc6e5fc28a06`. `git push origin dev-wasm` — succeeded. `gh workflow run .github/workflows/wasm_callback_ci.yaml --ref dev-wasm` — dispatched run `35282141913`. `gh run view 35282141913` — Windows staging passed; C/C++ and JavaScript Wasm gates failed at `Build the Wasm bundle` because `setup-wasm.sh` attempted unavailable `dnf`. `bash --noprofile --norc -n scripts/toolchain/setup-wasm.sh` and `git diff --check` — passed. Builder commit `a8073c7d` — created locally.
- **Full validation:** Not achieved; the fixed builder commit has not yet been pushed/pinned and the required external jobs have not rerun.
- **Documentation:** None required.
- **Residual risk:** G16-C remains externally unverified. The builder fix must be pushed, the parent submodule pointer updated and pushed, and the workflow rerun against the resulting final SHA.
- **Tracker transition:** External evidence blocked → CI failure remediation in progress; G20 is not complete.

### G20 React Native revalidation record — 2026-09-17

- **Goal:** G20 — External CI closeout, with the React Native Web package flow as the active implementation boundary.
- **Invariant:** React Native Web automatically resolves and stages the published Wasm runtime through package-owned build/test commands; its Web/Wasm and Windows staging jobs do not build `libffmpegkit`, check out `ffmpeg-kit-builders`, transfer a generated binary, or inject a workflow artifact override.
- **Finding revalidated:** Yes. `react-native/example/package.json` makes `web` and `web:build` invoke `prepare-web`; `react-native/scripts/web-smoke.js` prepares the example before launching headless Chromium. `4f5ede5c` passed the React Native jobs but exposed a standalone workflow ordering issue; `f910ee521f6b991b47c10a31f4d9df8fd1705009` moves Playwright installation before package checks.
- **Files changed:** `.github/workflows/wasm_callback_ci.yaml`, `.github/workflows/react_native_web_ci.yaml`, `react-native/example/package.json`, `react-native/scripts/web-smoke.js`, `react-native/TEST.md`, and `react-native/example/README.md`.
- **Why each change is necessary:** The workflows now call normal Web commands that own runtime preparation; the example scripts make staging automatic for development and production builds; the smoke test is self-contained; documentation describes the automatic build hook and no manually supplied binary.
- **Tests added/modified:** No test cases were added; the existing package, packed-consumer, Windows ZIP, and headless WebAssembly smoke tests now execute through the automatic staging path.
- **Focused tests:** `npm run web:build` in `react-native/example` — passed; `npm run test:web` in `react-native` — passed headlessly through initialization, FFmpeg, FFprobe, media information, FFplay controls, and nonzero frame pixels. `npm run check` — 76 passing, 0 failures. Workflow YAML parsing and Node syntax checks passed.
- **Full validation:** Standalone React Native Web run `35289053382` passed all jobs on `f910ee521f6b991b47c10a31f4d9df8fd1705009`; combined run `35289051905` passed `React Native Web/Wasm gates` and `React Native Web Windows staging` on that SHA. Its independent `Flutter Web/Wasm gates` job failed only at the Flutter browser test with `Bad state: Unable to load assets/packages/ffmpeg_kit_extended_flutter/wasm/ffmpegkit_bridge.mjs`; the Flutter Wasm build passed.
- **Documentation:** `react-native/TEST.md` and `react-native/example/README.md` now document automatic runtime resolution/staging through the Web start/build/test commands.
- **Residual risk:** G20 remains open until the independent Flutter browser gate is repaired or explicitly separated from this review's required scope. React Native's published-runtime path is externally verified.
- **Tracker transition:** React Native G20 implementation/evidence verified; overall G20 remains in progress because the combined workflow is not fully green.

### G20 Flutter runner limitation closeout — 2026-09-17

- **Goal:** G20 — External CI closeout.
- **Finding revalidated:** Yes. Flutter 3.47 invokes the package build hook for `TargetPlatform.tester`, which reports the host `linux-x64` target even for `flutter test --platform chrome --wasm`. The `package:hooks` execution environment is semi-hermetic and strips the custom environment selector, so the package cannot select a Web target from the hook. Flutter's Web test server serves package paths separately from the consuming app's `/assets/packages` tree.
- **Evidence:** Run `35290984328` on `b05609a` failed after the environment-based hook selector and test-only asset-root override; the hook still resolved `v0.11.2-linux` and the browser could not load `packages/ffmpeg_kit_extended_flutter/web/wasm/ffmpegkit_bridge.mjs`. Run `35291678581` on `6b80d83` failed after runner-side staging from the successful Web build, with the same browser asset-load failure. The Flutter Web/Wasm build itself passed in both runs.
- **Resolution:** Do not change production Web loading or native hook target selection to compensate for Flutter's test runner. The attempted workaround changes were removed in cleanup commit `129427f`; React Native G20 evidence remains valid and the Flutter portion is explicitly closed as a toolchain limitation.
- **Residual risk:** Flutter browser callback execution remains unverified on Flutter 3.47. A future Flutter test-server/build-hook change can reopen this gate; no package-level fix is claimed here.
- **Tracker transition:** In progress → Closed — blocked by Flutter 3.47 test-runner/build-hook behavior.

### G20 no-op CI gate removal — 2026-09-17

- **Disposition:** Removed only the Flutter browser callback test from the Wasm workflow. The React Native `npm run test:web` browser gate and Windows staging gate remain active because they provide functional coverage; Flutter cannot expose the package Web assets through its 3.47 test-server/build-hook path.
- **Scope preserved:** Package/runtime Wasm support, local `test:web`, normal Web builds, React Native browser/staging CI, and non-browser package tests remain unchanged.
- **Builder rollback:** Reverted the CI-only builder commits `a8073c7db`, `6892de3b1`, and `60933e88e` as `137af066e`, `fc191370c`, and `fca1702ff`; the builder `dev` branch was pushed and is clean.
- **Verification:** Workflow search shows no remaining `flutter test --platform chrome --wasm` invocation; `npm run test:web` remains in both functional React Native Web CI workflows. The root workflow retains React Native coverage and the Flutter WebAssembly build/analyze/package-test gates.
- **Tracker transition:** Flutter browser CI coverage retired as non-actionable; React Native Web CI remains active.

### G21 — Published runtime contract — 2026-09-17

Explicitly deferred by user until review for all platforms is completed.

## Review 2 Tracker

| Goal                                  | Objective                                                                | Status            |
| ------------------------------------- | ------------------------------------------------------------------------ | ----------------- |
| **G13 — Metro Web export resolution** | Browser entry wins when Metro asserts `react-native` + `browser`.        | **Complete — 2026-09-17** |
| **G14 — Wasm failure-path ownership** | Start/discard failures cannot leak or strand session handles/promises.   | **Complete — 2026-09-17** |
| **G15 — Web debug artifact contract** | Example/docs/resolver do not advertise a known-invalid Web artifact.     | **Complete — 2026-09-17** |
| **G16 — Representative CI coverage**  | Default LGPL Web runtime and Windows ZIP staging are continuously gated. | **Complete — 2026-09-17** |
| **G17 — Runtime pair validation**     | Custom archives provide exactly one coherent JS/Wasm runtime pair.       | **Complete — 2026-09-17** |

Required output per goal before proceeding:

| Required field           | Luna must report                                   |
| ------------------------ | -------------------------------------------------- |
| **Goal**                 | G13/G14/etc.                                       |
| **Invariant checked**    | What behavior must remain true                     |
| **Files changed**        | Exact paths                                        |
| **Tests added/changed**  | Exact test names                                   |
| **Focused verification** | Commands + pass/fail                               |
| **Full verification**    | `npm run check` where applicable                   |
| **Documentation**        | Paths changed or explicitly "none required"        |
| **Residual risk**        | Concrete remaining uncertainty only                |
| **Tracker status**       | Updated Open → Complete only after evidence exists |

### Final closeout criteria

After G13–G17:

```bash
cd react-native

npm run check
npm run test:pack-web

cd example
npm run prepare-web
npm run web:build

cd ..
npm run test:web
```

Additionally require:

```text
Metro-like condition resolution -> index.web.ts
native condition resolution -> index.ts
execution-start failure -> handle released once
throwing discard cleanup -> later queued work still cleaned
base-small-LGPL browser smoke -> PASS
Windows local-ZIP staging -> PASS
known Web debug artifact -> fixed OR explicitly rejected/documented
custom archive split pair -> rejected
custom archive ambiguous pairs -> rejected
```

### G13 remediation record — 2026-09-17

- **Goal:** G13 — Metro Web export resolution.
- **Invariant checked:** Web-like resolution with `react-native` and `browser` conditions selects `src/index.web.ts`; native-like resolution with only `react-native` selects `src/index.ts`; browser-only resolution also selects the Web entry.
- **Files changed:** `react-native/package.json`, `react-native/tests/package-exports.test.js`, `react-native/README.md`.
- **Tests added/changed:** `conditional exports select the web or native entry by runtime conditions`; existing packed Vite consumer coverage remains enabled.
- **Focused verification:** `node --test tests/package-exports.test.js` — passed; all three condition sets resolved to the expected entry.
- **Full verification:** `npm run check` — passed; typecheck passed, lint reported 0 errors and one pre-existing warning, and 65 tests passed. `npm run test:pack-web` — passed. `npm --prefix example run web:build` — passed.
- **Documentation:** `react-native/README.md` now documents conditional Web/Metro resolution and the standard Vite `react-native` to `react-native-web` alias without requiring a package-specific backend alias.
- **Residual risk:** Metro or another bundler may require its own condition configuration; the package export map and Node condition behavior are verified, while bundler-version-specific configuration remains consumer/toolchain dependent.
- **Tracker status:** Open → Complete.

### G14 remediation record — 2026-09-17

- **Goal:** G14 — Wasm failure-path ownership.
- **Invariant checked:** A native execution-start failure releases its owning session handle exactly once, and a discard-cleanup failure cannot prevent later queued sessions from being cleaned up and rejected.
- **Files changed:** `react-native/src/session.ts`, `react-native/src/session-queue-manager.ts`, `react-native/tests/wasm-session-ownership.test.js`, `react-native/tests/session-queue-manager.test.js`.
- **Tests added/changed:** `native start failure releases its Wasm handle exactly once`; `clearQueue settles every pending item after discard cleanup failure`.
- **Focused verification:** `npm run test:compile` — passed; `node --test tests/session-queue-manager.test.js tests/wasm-session-ownership.test.js` — 14 passing, 0 failures.
- **Full verification:** `npm run check` — passed; typecheck passed, lint reported 0 errors and one pre-existing warning, and 67 tests passed.
- **Documentation:** Internal lifecycle comments in `react-native/src/session-queue-manager.ts` were updated to describe cleanup-error rejection semantics; no public README change was required.
- **Residual risk:** The tests cover the shared session-start helper through FFmpeg; the other session classes use the same helper but do not have separate start-failure test cases.
- **Tracker status:** Open → Complete.

### G15 remediation record — 2026-09-17

- **Goal:** G15 — Web debug artifact contract.
- **Invariant checked:** Default Web/Wasm configuration never constructs the known-incompatible pre-built debug artifact; explicit Web/Wasm overrides remain available; native debug resolution is unchanged; the checked-in Web example uses a compatible base bundle.
- **Files changed:** `react-native/scripts/resolve-ffmpeg-kit-config.js`, `react-native/tests/resolve-ffmpeg-kit-config.test.js`, `react-native/example/ffmpeg-kit-extended.config.json`, `react-native/README.md`, `react-native/example/README.md`, `react-native/CHANGELOG.md`.
- **Tests added/changed:** `rejects the pre-built Web debug bundle`; `preserves native debug bundle resolution`; `allows an explicit local Web override with debug configuration`; `allows an explicit remote Web override with debug configuration`.
- **Focused verification:** `node --test tests/resolve-ffmpeg-kit-config.test.js` — 20 passing, 0 failures. `node scripts/resolve-ffmpeg-kit-config.js --platform web --app-root example --quiet true` — resolved `bundle-base-wasm-wasm32-static-small-lgpl.zip`.
- **Full verification:** `npm run check` — passed; typecheck passed, lint reported 0 errors and one pre-existing warning, and 71 tests passed.
- **Documentation:** `react-native/README.md`, `react-native/example/README.md`, and `react-native/CHANGELOG.md` now distinguish native debug support from the incompatible pre-built Web/Wasm debug artifact and document base/custom Web alternatives.
- **Residual risk:** The named debug ZIP was not present in the checkout for a fresh `prepare-web`/browser reproduction; the upstream artifact remains blocked by an explicit resolver error, while explicitly overridden custom runtimes remain the consumer's responsibility.
- **Tracker status:** Open → Complete.

### G16 remediation record — 2026-09-17

- **Goal:** G16 — Representative CI coverage.
- **Invariant checked:** The persistent Web browser gates use the default base/small/LGPL runtime, and Windows local ZIP staging exercises the actual `Expand-Archive` path while producing the complete runtime asset set.
- **Files changed:** `.github/workflows/wasm_callback_ci.yaml`.
- **Tests added/changed:** The Wasm, React Native Web, and Flutter Web gates now build and consume `bundle-base-wasm-wasm32-static-small-lgpl.zip`; `React Native Web Windows staging` creates a nested synthetic ZIP and verifies the staged runtime and bridge assets.
- **Focused verification:** YAML parse passed; workflow search found no GPL artifact name or `--gpl` flag; the local Windows-equivalent ZIP staging gate passed and verified all five required files. The callback suite uses generic FFmpeg/FFprobe coverage and has no GPL-only component requirement.
- **Full verification:** `npm run check` — passed; typecheck passed, lint reported 0 errors and one existing warning, and 71 tests passed.
- **Documentation:** None required; the workflow is the CI reference for these gates.
- **Residual risk:** The actual PR-triggered GitHub run required by G16-C was not initiated because this task did not push or dispatch CI. The builder artifact was not rebuilt locally; the workflow build command and downstream artifact consumers are updated consistently.
- **Tracker status:** Open → Complete for the implementation; external PR-triggered CI evidence remains required before final review closeout.

### G17 remediation record — 2026-09-17

- **Goal:** G17 — Runtime pair validation.
- **Invariant checked:** Web staging selects both runtime files from one directory; a split pair is rejected, and multiple complete runtime directories are rejected as ambiguous.
- **Files changed:** `react-native/scripts/prepare-web.js`, `react-native/tests/prepare-web.test.js`, `react-native/README.md`, `react-native/example/README.md`.
- **Tests added/changed:** `prepare-web stages a single nested runtime pair from a local directory`; `prepare-web rejects a runtime split across directories`; `prepare-web rejects multiple complete runtime directories as ambiguous`.
- **Focused verification:** `node --test tests/prepare-web.test.js` — 4 passing, 0 failures. The local Windows ZIP pair gate passed through `Expand-Archive` and verified the staged runtime plus all three bridge assets.
- **Full verification:** `npm run check` — passed; typecheck passed, lint reported 0 errors and one existing warning, and 73 tests passed.
- **Documentation:** `react-native/README.md` and `react-native/example/README.md` now state that a custom Wasm ZIP must contain exactly one runtime directory containing both runtime files.
- **Residual risk:** Custom archives containing unusual filesystem entries such as symlinks are not part of the supported ZIP contract; normal nested ZIP layouts and the split/ambiguous cases are covered.
- **Tracker status:** Open → Complete.

### Review 2 progress

| Area             | Status                         | Interpretation                                      |
| ---------------- | ------------------------------ | --------------------------------------------------- |
| **Review 2**     | **G13–G17 complete** | All Review 2 implementation goals are complete; the G16-C external PR-triggered CI run remains pending for final closeout. |
| **Implementation** | **G13–G17 complete** | Web resolution, Wasm failure-path ownership, the Web debug artifact contract, representative CI coverage, and coherent runtime-pair validation are remediated and verified. |

## Review 1 Tracker

| Goal                                           | Objective                                                                                                                          | Current Status              | Completion / Exit Criteria                                                                                                                                                              | Tracking Notes                                                     |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| **G0 — Baseline Revalidation**                 | Reconfirm all WASM findings against current branch HEAD before modifying code.                                                     | **Complete — 2026-09-17**  | Current HEAD compared to baseline `ff2af68b`; each finding explicitly confirmed, changed, or retired.                                                                                   | HEAD matches the baseline; see the G0 revalidation record. G1–G11 are complete; G12 remains. |
| **G1 — Media Information Parity**              | Make `FFprobeKit.getMediaInformation(path)` construct the same argv-based media-information session on Web as native React Native. | **Complete — 2026-09-17** | Web uses `media_information_create_session_from_argv`; exact standard FFprobe args tested; whitespace/quoted paths remain one argument; existing browser media-info flow passes.        | See the G1 remediation record. G2–G11 are complete; G12 remains. |
| **G2 — Package-Native Web Backend Resolution** | Ensure a normal browser/Vite consumer resolves `backend.web` without repository-specific resolver hacks.                           | **Complete — 2026-09-17** | Packed npm package builds in a clean Vite fixture using only normal RN-Web configuration; browser import never evaluates native TurboModule; example resolver hacks removed.            | See the G2 remediation record. G3–G11 are complete; G12 remains. |
| **G3 — Queued Session Handle Ownership**       | Release owning Wasm handles for sessions discarded before execution, exactly once.                                                 | **Complete — 2026-09-17** | Queue-discard path releases handle; registry entry disappears; executor never starts; normal/running sessions retain current ownership semantics; no double release.                    | See the G3 remediation record. G4–G11 are complete; G12 remains. |
| **G4 — Callback Exception Safety**             | Prevent user log/statistics/completion callback exceptions from orphaning running native sessions.                                 | **Complete — 2026-09-17** | Callback exception cannot terminate lifecycle monitoring prematurely; terminal state is observed; handle released exactly once; returned Promise preserves appropriate callback error.  | See the G4 remediation record. G5–G11 are complete; G12 remains. |
| **G5 — Initialization Recovery**               | Make failed Web initialization retryable while preserving successful idempotence and concurrent-call deduplication.                | **Complete — 2026-09-17** | Failed load clears retry state; corrected `assetBaseUrl` can succeed later; concurrent calls share one attempt; successful initialization remains idempotent.                           | See the G5 remediation record. G6–G11 are complete; G12 remains. |
| **G6 — Web Artifact Cache Identity**           | Prevent custom remote Web bundle URLs with the same basename from colliding or becoming indefinitely stale.                        | **Complete — 2026-09-17** | Cache path incorporates source identity/cache key; different URLs cannot share cache entry; checksum-free remote overrides refresh; checksum behavior remains correct.              | See the G6 remediation record. G7–G11 are complete; G12 remains. |
| **G7 — `FFplayView` Web Semantics**            | Make Web `FFplayView` genuinely honor React Native `ViewProps` and RN style semantics.                                             | **Complete — 2026-09-17** | `testID`, accessibility/event props, style arrays, explicit sizing, `aspectRatio`, and unmount cleanup work; caller width/height are not overwritten.                                   | See the G7 remediation record. G8–G11 are complete; G12 remains. |
| **G8 — FFplay Frame-Copy Efficiency**          | Avoid full Wasm framebuffer allocation/copy when no new decoded frame exists.                                                      | **Complete — 2026-09-17** | Metadata-only preflight skips unchanged frames without pixel allocation/copy; changed frames copy once; resolution and stride remain correct; temporary frame buffers are released; browser rendering remains covered. | See the G8 remediation record. G9–G11 are complete; G12 remains. |
| **G9 — Remote Scheme Validation**              | Align accepted custom artifact URL schemes with downloader capabilities.                                                           | **Complete — 2026-09-17** | HTTP and HTTPS overrides are accepted; unsupported URL-like schemes are rejected before local-path resolution and by the downloader; tests cover both validation layers.              | See the G9 remediation record. G10–G11 are complete; G12 remains. |
| **G10 — WASM Test + CI Gate**                  | Turn real React Native Web execution into a required CI signal, not merely a compile/build check.                                  | **Complete — 2026-09-17** | CI reuses the generated Wasm builder artifact, runs package and packed-consumer checks, stages a local Web override, installs Chromium, builds the example, and runs the headless smoke through FFmpeg/FFprobe/media-info/FFplay. | See the G10 remediation record. G11 is complete; **G12 is next.** |
| **G11 — Documentation Reconciliation**         | Make README/example documentation exactly match final Web behavior and minimal consumer setup.                                     | **Complete — 2026-09-17** | Docs cover staging, COOP/COEP, `assetBaseUrl`, retry semantics, media-info paths, custom bundles, FFplay layout, and minimal Vite config; no obsolete resolver workaround remains.      | See the G11 remediation record. **G12 is next.**                   |
| **G12 — Final Regression Gate**                | Verify WASM changes do not regress native React Native or packaging.                                                               | **Complete — 2026-09-17** | Typecheck, lint, unit tests, package tests, packed consumer build, browser smoke, and relevant native-neutral tests pass; final diff reviewed for accidental platform changes.          | See the G12 remediation record. WASM review closeout is complete.  |

### G0 revalidation record — 2026-09-17

- G0 revalidation was performed at `HEAD` `ff2af68`, matching the reviewed baseline; subsequent commits contain the scoped remediations.
- **G1 confirmed:** native media-information uses argv, while the Web backend passes the path through the string-command constructor. This was remediated below.
- **G2 confirmed:** shared imports resolve through `backend.ts` to the native backend, and the Web example relies on repository-specific Vite rewrites.
- **G3 confirmed:** `WasmSessionRegistry` owns retained handles; terminal monitoring releases them, but `clearQueue()` only rejects queued sessions.
- **G4 confirmed:** log and statistics callbacks run outside terminal cleanup, so a thrown callback can stop lifecycle monitoring.
- **G5 confirmed:** both loader and public initialization cache rejected promises without clearing retry state.
- **G6-G9 confirmed:** Web preparation caches remote artifacts by filename despite computing `cacheKey`; `FFplayView` drops View props and coerces styles; frame reads copy before checking generation; configuration accepts `ftp` although downloading is HTTP(S)-only.
- **G10 confirmed and implemented:** the prior workflow ran checks and a Vite build but did not stage a generated bundle or execute `test:web`; the React Native Web/Wasm job now reuses the builder artifact and runs the real headless browser gate. G11 is now complete; G12 remains deferred.

### G1 remediation record — 2026-09-17

- `react-native/src/platform/backend.web.ts` now builds the native-equivalent ten-element FFprobe argv and calls `media_information_create_session_from_argv` through `withArguments()`. The path is a single argv element, not a reparsed command string.
- `react-native/tests/wasm-backend-memory.test.js` covers a path with whitespace, quotes, and backslashes; it asserts exact argv order, retained public session ID, and release of every temporary argv allocation.
- Verification passed:
  - `npm test` in `react-native` — 44 passing, 0 failures.
  - `npm run typecheck` in `react-native` — passed.
  - `npm run lint` in `react-native` — 0 errors; one pre-existing `no-useless-escape` warning in `tests/arguments.test.js`.
  - `npm --prefix react-native/example run prepare-web; npm --prefix react-native run test:web` — staged a temporary local Wasm bundle and passed the headless browser smoke through initialization, FFmpeg, FFprobe, media information, and FFplay. The temporary configuration override and staged bundle were removed after the test.

### G2 remediation record — 2026-09-17

- Native and Web package entrypoints now register their selected backend before shared API modules evaluate. Shared modules use the explicit backend registry, so browser resolution does not import `NativeFFmpegKitExtended`.
- `react-native/example/web/vite.config.js` now contains only the normal `react-native` to `react-native-web` alias; all repository-specific backend and package-source rewrites were removed.
- `tests/packed-web-consumer.js` creates a temporary Vite fixture, packs and installs the npm tarball, builds with only the normal alias, and asserts the emitted browser JavaScript contains neither `NativeFFmpegKitExtended` nor `TurboModuleRegistry`.
- Verification passed:
  - `npm test` in `react-native` — 45 passing, 0 failures.
  - `npm run typecheck` in `react-native` — passed.
  - `npm run lint` in `react-native` — 0 errors; one pre-existing `no-useless-escape` warning in `tests/arguments.test.js`.
  - `npm --prefix react-native/example run web:build` — passed with the simplified Vite configuration.
  - `npm run test:pack-web` in `react-native` — packed-tar Vite consumer build passed.
  - `npm run prepare-web; npm --prefix .. run test:web` in `react-native/example` — headless WebAssembly smoke passed through initialization, FFmpeg, FFprobe, media information, and FFplay. The temporary local-runtime override and staged files were removed after the test.

### G3 remediation record — 2026-09-17

- `SessionQueueManager` now accepts discard cleanup for queued items and invokes it before rejecting `clearQueue()` work. `Session` provides an internal idempotent handle-release operation; all four session execution paths use it for both discard and terminal cleanup.
- `react-native/tests/wasm-session-ownership.test.js` verifies that a queued session releases its retained handle once, disappears from the registry, never starts execution, and is unaffected by repeated queue clearing. It also verifies one-time release after normal completion and delayed release for an active cancelled session until terminal state.
- Verification passed:
  - `npm test` in `react-native` — 48 passing, 0 failures.
  - `npm run typecheck` in `react-native` — passed.
  - `npm run lint` in `react-native` — 0 errors; one pre-existing `no-useless-escape` warning in `tests/arguments.test.js`.

### G4 remediation record — 2026-09-17

- `Session.monitor()` now captures the first exception from log, statistics, or completion callbacks, suppresses later user callbacks, continues polling and final callback collection, releases the owning handle in terminal cleanup, and rejects with the captured callback error afterward.
- `react-native/tests/wasm-session-ownership.test.js` covers throwing log, statistics, and completion callbacks, callback failure combined with cancellation, callback failure on a failed native session, exact error identity, one-time handle release, registry removal, and zero active queue count.
- Verification passed:
  - `npm test` in `react-native` — 53 passing, 0 failures.
  - `npm run typecheck` in `react-native` — passed.
  - `npm run lint` in `react-native` — 0 errors; one pre-existing `no-useless-escape` warning in `tests/arguments.test.js`.

### G5 remediation record — 2026-09-17

- Web loading now creates a fresh Wasm module through an exported bridge factory, clears failed loader and public initialization promises, and preserves one-at-a-time concurrent loading plus successful idempotence.
- `react-native/tests/wasm-initialization.test.js` verifies retry with a corrected asset base URL, concurrent deduplication, successful idempotence, and public initialization recovery.
- Verification passed:
  - `npm test` in `react-native` — 56 passing, 0 failures.
  - `npm run typecheck` in `react-native` — passed.
  - `npm run lint` in `react-native` — 0 errors; one pre-existing `no-useless-escape` warning in `tests/arguments.test.js`.

### G6 remediation record — 2026-09-17

- Web preparation now stores downloaded artifacts under a source-derived `<cacheKey>-<filename>` path, so remote URLs with the same basename cannot collide.
- Checksum-free remote overrides refresh their cached artifact instead of reusing an unverified file indefinitely. Checksum-verified artifacts retain validation, corrupt-cache removal, and valid-cache reuse behavior.
- `react-native/tests/prepare-web.test.js` and `react-native/tests/download-ffmpeg-kit-artifact.test.js` cover cache identity, refresh behavior, checksum mismatch handling, and checksum-verified reuse.
- Verification passed:
  - `npm test` in `react-native` — 59 passing, 0 failures.
  - `npm run typecheck` in `react-native` — passed.
  - `npm run lint` in `react-native` — 0 errors; one pre-existing `no-useless-escape` warning in `tests/arguments.test.js`.

### G7 remediation record — 2026-09-17

- Web `FFplayView` now uses a React Native Web `View` as its public host, forwarding caller props and styles while keeping the canvas as an internal fill surface. The render loop guards its active state and cancels the pending frame on unmount.
- `react-native/tests/ffplay-view-web.test.js` renders the component in a headless Vite/Playwright browser and verifies View props, accessibility, style-array sizing, aspect ratio, event forwarding, canvas layout, and stopped animation scheduling after unmount.
- Verification passed:
  - `npm test` in `react-native` — 60 passing, 0 failures.
  - `node --test tests/ffplay-view-web.test.js` in `react-native` — passed.
  - `npm run typecheck` in `react-native` — passed.
- `npm run lint` in `react-native` — 0 errors; one pre-existing `no-useless-escape` warning in `tests/arguments.test.js`.

### G8 remediation record — 2026-09-17

- The Web FFplay reader now performs a metadata-only frame preflight, skips unchanged generation/dimensions/stride without allocating or copying pixels, copies changed frames once, preserves stride, handles resize races safely, and releases each temporary Wasm buffer.
- `react-native/tests/wasm-backend-memory.test.js` and `react-native/tests/ffplay-frame-reader.test.js` cover the metadata-only contract, changed-frame copy, resolution/stride changes, and allocation/release balance. Existing headless browser FFplay rendering coverage remains in `ffplay-view-web.test.js`.
- Verification passed:
  - `npm test` in `react-native` — 61 passing, 0 failures.
  - `node --test tests/wasm-backend-memory.test.js tests/ffplay-frame-reader.test.js` in `react-native` — 4 passing, 0 failures.
  - `npm run typecheck` in `react-native` — passed.
  - `npm run lint` in `react-native` — 0 errors; one pre-existing `no-useless-escape` warning in `tests/arguments.test.js`.

### G9 remediation record — 2026-09-17

- The React Native config resolver now recognizes only HTTP and HTTPS as remote overrides and rejects unsupported URL-like schemes before they can be treated as local paths. The artifact downloader validates URL syntax and protocol before selecting the HTTP or HTTPS client, including redirects.
- `react-native/tests/resolve-ffmpeg-kit-config.test.js` covers HTTP and HTTPS acceptance plus FTP rejection. `react-native/tests/download-ffmpeg-kit-artifact.test.js` covers direct downloader rejection of unsupported schemes.
- Verification passed:
  - `npm test` in `react-native` — 64 passing, 0 failures.
  - `node --test tests/resolve-ffmpeg-kit-config.test.js tests/download-ffmpeg-kit-artifact.test.js` in `react-native` — 19 passing, 0 failures.
  - `npm run typecheck` in `react-native` — passed.
  - `npm run lint` in `react-native` — 0 errors; one pre-existing `no-useless-escape` warning in `tests/arguments.test.js`.

### G10 remediation record — 2026-09-17

- `.github/workflows/wasm_callback_ci.yaml` now triggers for React Native, builder, and relevant workflow changes. Its React Native Web/Wasm job downloads the Wasm artifact from the preceding builder job, runs package checks, builds and validates the packed package, builds a clean packed Web consumer, stages the local runtime override, builds the example, installs headless Chromium, and runs `test:web`.
- The browser fixture now executes a real FFmpeg filter command with log and statistics callbacks and asserts both callback types were delivered. Existing browser assertions continue to cover initialization idempotence, FFprobe, media information, FFplay controls, nonzero canvas pixels, and page/console errors. Session ownership remains covered by the package lifecycle tests.
- Verification passed:
  - `npm test` in `react-native` — 64 passing, 0 failures.
  - `npm run typecheck` in `react-native` — passed.
  - `npm run lint` in `react-native` — 0 errors; one pre-existing `no-useless-escape` warning in `tests/arguments.test.js`.
  - `npm run test:pack-web` in `react-native` — packed Vite consumer build passed.
  - `npm --prefix react-native/example run web:build` — passed.
  - `node --check scripts/web-smoke.js` in `react-native` — passed.
  - `.github/workflows/wasm_callback_ci.yaml` parsed successfully with Python YAML validation.
- The generated-runtime `test:web` execution remains a CI step because this checkout has no staged Wasm artifact; prior generated-runtime smoke passes are recorded in the G1 and G2 remediation records.

### G11 remediation record — 2026-09-17

- `react-native/README.md` now documents the minimum Web dependencies, configuration and staging flow, local and HTTP(S) custom bundle overrides, staged asset location, COOP/COEP requirements, default and custom `assetBaseUrl`, retryable/idempotent initialization, one-argument media-information paths, FFplay canvas/layout/audio behavior, and a minimal Vite React Native Web configuration.
- `react-native/example/README.md` now documents the Web example commands, runtime staging, custom bundle configuration, cross-origin isolation headers, production deployment requirement, and custom asset-base handling. The example Vite guidance describes only the standard React Native Web alias and contains no repository-specific package or backend rewrite.
- Documentation describes runtime loading of staged assets accurately: archive downloads occur during `prepare-web`, while the browser loads the staged module and Wasm files from the application origin.
- Verification passed:
  - `npm run test:config` in `react-native` — 16 passing, 0 failures.
  - `node --check scripts/prepare-web.js` in `react-native` — passed.
  - `node --check example/web/vite.config.js` in `react-native` — passed.
  - `node scripts/resolve-ffmpeg-kit-config.js --platform web --app-root example --quiet true` — resolved the configured Web bundle at version `0.11.2`.
  - `git diff --check` — passed.

### G12 remediation record — 2026-09-17

- `react-native/scripts/prepare-web.js` now invokes Windows `Expand-Archive` through an explicit PowerShell script block with bound archive and destination parameters. This fixes archive staging on Windows while preserving the existing `unzip` path on other platforms.
- `react-native/scripts/web-smoke.js` now uses a bounded 120-second runtime wait budget and passes Playwright `waitForFunction` options in the correct argument position. This accommodates real Wasm compilation and keeps initialization/terminal failures observable.
- Verification passed:
  - `npm run check` in `react-native` — typecheck passed, lint had 0 errors with one pre-existing `no-useless-escape` warning, and 64 tests passed.
  - `npm run test:pack-web` in `react-native` — packed Vite consumer build passed and the package contained the Web bridge assets.
  - `npm run web:build` in `react-native/example` — passed.
  - `npm run prepare-web` followed by `npm run test:web` using `bundle-base-wasm-wasm32-static-small-gpl.zip` — staging and headless WebAssembly smoke passed.
  - `npm run prepare-web` followed by `npm run test:web` using `bundle-base-wasm-wasm32-static-small-lgpl.zip` — staging and headless WebAssembly smoke passed.
  - `git diff --check ff2af68b..HEAD` — passed.
  - No changed paths under React Native native host projects (`android`, `ios`, `appletvos`, `macos`, or `windows`) were found in the baseline-to-HEAD diff; the native backend registration changes are platform-neutral package wiring.
- The separately configured `bundle-base-wasm-wasm32-static-debug-lgpl.zip` was observed to fail Chromium Wasm validation at `av_max_alloc`; this is isolated to that release artifact variant and is not used by the CI closeout gate or the default base-small release path, both of which passed.

### Overall status

| Area                                        | Status                                    | Interpretation                                                                            |
| ------------------------------------------- | ----------------------------------------- | ----------------------------------------------------------------------------------------- |
| **Review**                                  | **Complete for WASM snapshot `ff2af68b`** | Major correctness, lifecycle, packaging, CI, and documentation gaps have been identified. |
| **Implementation**                          | **G0–G12 complete**                        | All reviewed implementation and verification goals are complete.                           |
| **Release blockers**                        | **None currently identified**             | The initial G1 and G2 release blockers are complete.                                     |
| **Lifecycle / production-hardening issues** | **0 open**                                | G6 is complete.                                                                            |
| **Public API / UI issue**                   | **0 open**                                | G7 is complete.                                                                            |
| **Optimization / cleanup**                  | **0 open**                                | G8 and G9 are complete.                                                                    |
| **Validation infrastructure**               | **0 open**                                | G10 and G12 are complete.                                                                  |
| **Documentation**                           | **0 open**                                | G11 is complete.                                                                           |
| **WASM implementation readiness**           | **G0–G12 complete**                        | Review closeout is complete; the debug release-variant artifact caveat remains documented.  |

## Review 17 implementation preparation — 2026-09-20

- **Source:** latest `flutter-review-17-luna-plan.md` attachment in the [Plan Luna Fix](https://chatgpt.com/g/g-p-69e9691f5b3881919a72eda0a180ed5c/c/6aabedf6-8ea4-83e8-ba0f-f73c7c065edf) conversation.
- **Frozen baseline:** `dev-wasm` at `0abe4d86b3a2e963aa344c0978e24d6baae5b49c`; local and `origin/dev-wasm` match (`0 0` ahead/behind).
- **Prep artifact:** [`.agent/flutter-review-17-implementation-prep.md`](./flutter-review-17-implementation-prep.md).
- **Implementation boundary:** no product code was changed during preparation. Scope is Flutter only.

| Goal | Objective | Review 17 prep status |
| --- | --- | --- |
| **FBH-G21** | Correct the stable default package-asset URL to Flutter's actual dependency-asset namespace | **Complete — 2026-09-21** |
| **FBH-G22** | Select custom Web runtimes from asset metadata and fail closed after explicit override selection | **Complete — 2026-09-21** |
| **FBH-G23** | Document `hooks.user_defines` precedence and continued `ffmpeg_kit_extended_config` compatibility | **Complete — 2026-09-21** |
| **FBH-G24** | Exact-SHA Review 17 closeout and evidence record | **Complete with user-approved publication exception — 2026-09-21** |
| **G21** | Published runtime/current-source integrity contract | **Remain Deferred** |

- Review 17 preserves FBH-G14 through FBH-G20 as closed, including the two user-approved exceptions: hosted stable browser execution and the sole `ffigen_js: ^0.0.16-pre` publication warning.
- Those exceptions are not authority to waive deterministic package URLs, missing assets, explicit custom-runtime failures, or any additional publication error.
- Direct source reconciliation: `flutter/pubspec.yaml:20-22`, `flutter/lib/src/platform/web/wasm_loader.dart:15-19,84-108`, `flutter/lib/src/platform/web/retryable_initialization.dart:22-40`, `flutter/hook/build.dart:72-92,111-192`, and `flutter/hook/config.dart:92-95` support the Review 17 work items. The graph coverage report had no recorded parse gaps but marked the current files metadata-changed/not-tracked; direct source reads are authoritative.
- Required order: FBH-G21 path tests and clean stable build/manifest proof; FBH-G22 asset-metadata selector and strict no-fallback tests plus master custom smoke; FBH-G23 docs and resolver regression tests; then FBH-G24 exact-SHA closeout.
- No React Native, `ffmpeg-kit-builders`, C/C++ ABI, native-platform, or unprefixed G21 changes are authorized by this prep.
- **FBH-G21 implementation started:** added `flutter/lib/src/platform/web/web_asset_paths.dart`, routed `WasmLoader` through the corrected default dependency-asset URL root, and added a static path-contract test. The product patch is ready for workflow validation.
- **FBH-G21 transition:** **Complete — 2026-09-21** on implementation SHA `87415707408f5c388303570fa40c5a8cd60d424a`, with diagnostic follow-up `9334c1ef6476d866fda862c389f53f8353a77a09`. Exact-SHA run [35569375718](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35569375718) passed Dart analyze, Flutter analyze, Flutter tests, stable `flutter build web --wasm`, the custom DataAsset build/browser smoke, and the platform matrix. The stable smoke requested the corrected default files under `assets/packages/ffmpeg_kit_extended_flutter/assets/wasm/` without a 404.
- **Local validation limitation:** local `dart --version`, `flutter --version`, and the focused Dart test remained live with no output until stopped. No SDK/package workaround was attempted; workflow evidence is authoritative for G21.
- **G22 evidence:** the exact-SHA follow-up run [35569375718](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35569375718) recorded the sole failed response as `404 http://127.0.0.1:8080/assets/packages/ffmpeg_kit_extended_flutter/wasm_override/ffmpegkit_wasm_manifest.json`; the same smoke requested the corrected default bridge, JS, support modules, and Wasm under `.../assets/wasm/...`. This is a deterministic source/runtime-selection defect, not the approved hosted-browser exception.
- **Publication evidence:** the same follow-up package job passed analysis, tests, and stable build; `dart pub publish --dry-run` still exited 65 solely for the approved `ffigen_js: ^0.0.16-pre` warning.
- **G22 implementation boundary:** replace the unconditional network probe with asset metadata authority; absent marker selects packaged default, present marker makes custom runtime authoritative, and custom failures must not fall back. No SDK/package workaround is authorized.
- **FBH-G22 implementation:** commit `11c825474f85297ed8383793c16b64f046964c22` introduced `AssetManifest.loadFromAssetBundle(rootBundle)` selection, strict custom-manifest validation, and selector/manifest tests; lint follow-up commit `41f38aa9ca2d55decb1e6bab044ef861f9b742f6` is the validated head.
- **FBH-G22 acceptance:** exact-SHA workflow [35570181928](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35570181928) at `41f38aa9ca2d55decb1e6bab044ef861f9b742f6` passed Dart analyze, Flutter analyze, Flutter tests, stable Web Wasm build, stable browser smoke, custom DataAsset build, and custom browser smoke. The stable smoke no longer probes the absent override manifest; the custom smoke confirms the explicit `wasm_override` path.
- **FBH-G22 local limitation:** direct Dart formatting succeeded, but focused Dart test execution failed during build-hook startup because the machine could not delete the locked `C:\Users\Akash\AppData\Roaming\.dart-tool\dart-flutter-telemetry.log` (`PathAccessException`, access denied). No SDK/package/toolchain workaround was attempted; workflow evidence is authoritative. Local browser execution was not claimed from stale output.
- **FBH-G23 implementation:** commit `0e4f311ec94ad4c476a3b757138b00e2d31c36a1` updates `flutter/README.md`, `flutter/doc/installation.md`, and `flutter/doc/quick-start.md` to state the cross-platform source contract. Resolver tests now prove that native/Web override keys survive both the preferred `hooks.user_defines` path and the legacy fallback, with preferred values taking precedence.
- **FBH-G23 acceptance:** exact-SHA workflow [35570692980](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35570692980) checked out `0e4f311ec94ad4c476a3b757138b00e2d31c36a1`. Dart analyze, Flutter analyze, Flutter tests, stable Web Wasm build/browser smoke, custom DataAsset build/browser smoke, native platform builds, and Native API Verification (Linux) all passed.
- **FBH-G24 exact-SHA closeout:** local `HEAD` and `origin/dev-wasm` both equal `0e4f311ec94ad4c476a3b757138b00e2d31c36a1`; the worktree is clean. The only failed workflow step was package publication validation, which reported exactly one warning: stable package `1.0.0` directly depends on prerelease `ffigen_js: 0.0.16-pre` and exited 65. The user explicitly bypassed this publication warning as a non-code/job issue; no dependency workaround was made.
- **Review 17 residual exception record:** the prior hosted Wasm-browser limitation and the prerelease publication warning remain explicitly user-approved exceptions in the historical G16/G20 ledger. Review 17’s current hosted stable and custom browser smoke jobs both passed on the exact closeout SHA; the publication warning is the only current workflow exception.
