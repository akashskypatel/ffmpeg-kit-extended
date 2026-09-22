# Tracker

## Review 23 Tracker — cross-platform callback transport/performance — 2026-09-21

- Native plan: [ffmpegkit-review-23-native-callback-plan.md](./ffmpegkit-review-23-native-callback-plan.md).
- Cross-platform plan: [review-23-luna-cross-platform-production-readiness-plan.md](./review-23-luna-cross-platform-production-readiness-plan.md).
- Preparation status: **Native implementation through N6 complete; R23-G60 demand-driven activation is implemented and locally verified.** R23-G59 baseline and the exact G60 wrapper snapshot are recorded below.
- Wrapper starting SHA: `5d80c88e4b4dd8bac5df147e270bfcce1b9358c6` (`HEAD == origin/dev-wasm`, clean at preparation).
- Native builder starting SHA: `9047d9c03ba402b5a7eebed294698083c07eb3d3`; current pushed handoff SHA: `196567dae7fd1509c33bf32081f8237596ac8e5b` (`ffmpeg-kit-builders`, branch `dev`, clean).
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
| **R23-G62** | React Native v2 direct log path | **Complete — `727d732` pushed to `origin/dev-wasm`; local native/Web gates passed; packed-Web fixture remains blocked by Windows temp-path access** |
| **R23-G63** | Completion/final-log exact-once semantics | **Pending — ordered after R23-G61/R23-G62** |
| **R23-G64** | Redirection authority | **Pending — ordered after R23-G63** |
| **R23-G65** | Docs/compatibility/benchmark report | **Pending — ordered after R23-G64** |
| **R23-G66** | Cross-platform exact-SHA closeout and source snapshot | **Pending — ordered after R23-G65** |
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
- Full TSAN evidence at the exact final handoff SHA: the elevated `--test=thread` build followed by `setarch x86_64 -R ./build/tests/ffmpegkit_tests` in `FFmpegKit/test_tsan_review23_final.log` ran **111 tests from 17 suites**, passed **108**, and retained the same three known TLS failures plus **2 ThreadSanitizer warnings**. The earlier test-side callback-lifetime and concurrent `StressTest.ParallelSyncHammer` vector/release races were fixed in `7fa36fe8` without removing scenarios. Both final warnings are one underlying FFmpeg frame-data lifetime/publication race: `src/ffmpeg.c:503` (`frame_data_ensure`) reads an allocation while another decoder worker initializes it through `av_mallocz`, and `src/ffmpeg.c:551` frees the same frame-data allocation while the decoder worker still accesses it. The local frame-data mutex does not establish the required publication/lifetime ordering for the embedded FFmpeg `AVBufferRef` path; a safe resolution requires upstream/embedded FFmpeg synchronization rather than a local test workaround. Per the user directive, the residual TSAN evidence and potential source are documented and **not a goal blocker**; no sanitizer bypass or scenario weakening was used.
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
- Local Web/package evidence: `npm run test:web` passed the headless WebAssembly smoke (initialize, repeated initialize, FFmpeg, FFprobe, media info, FFplay pause/resume/stop); isolated-cache `npm run test:pack-types` passed. `npm run test:pack-web` reached the packed Vite fixture but failed because Windows esbuild could not read the temporary parent directory (`Cannot read directory "../../../..": Access is denied`); no SDK/toolchain or product workaround was added. This is retained as a packaging-environment limitation for the later G66 gate, not a G62 bridge correctness failure.

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
- Files changed: `flutter/hook/build.dart`, `flutter/hook/config.dart`, `flutter/test/hook_config_test.dart`, `flutter/test/user_defines_config_test.dart`, `flutter/test/web_data_asset_test.dart`, `flutter/test/fixtures/review16_data_assets_workspace/pubspec.yaml`, `flutter/test/fixtures/review16_data_assets_workspace/apps/app/pubspec.yaml`, `flutter/test/fixtures/review16_data_assets_workspace/apps/app/lib/main.dart`, `flutter/test/fixtures/review16_data_assets_workspace/apps/app/web/index.html`, `flutter/test/fixtures/review16_data_assets_workspace/runtime/ffmpegkit.mjs`, `flutter/test/fixtures/review16_data_assets_workspace/runtime/ffmpegkit.wasm`, `flutter/README.md`, `flutter/doc/installation.md`, and `flutter/doc/quick-start.md`.
- Why each changed: remove manual Web copies and staging-root inference; remove the no-longer-needed `ConfigResult.stagingBaseDir`; assert official DataAsset output and no guessed workspace writes; provide a bounded workspace fixture; and document the canonical workspace/DataAsset contract.
- Tests added/modified: real `testBuildHook` coverage with `DataAssetsExtension` asserts the five DataAsset names and no synthetic workspace `web/` or `build/web/` writes; the no-DataAsset path asserts the precise toolchain failure; configuration tests no longer preserve the removed staging-root behavior.
- Focused verification: direct bundled Dart `format --output=none --set-exit-if-changed` passed with 0 changes; `dart analyze hook test/hook_config_test.dart test/user_defines_config_test.dart test/web_runtime_pair_test.dart test/web_data_asset_test.dart` passed with no issues; the same focused `dart test` command passed with 35 tests and 0 failures; `git diff --check` passed.
- Bounded fixture verification: the direct Flutter 3.47.4 tool completed `pub get` for `flutter/test/fixtures/review16_data_assets_workspace` and accepted the workspace-root `hooks.user_defines` configuration. `flutter build web --wasm --no-pub` was then attempted from `apps/app` and stopped at the hook because the local stable SDK supplied `buildDataAssets: false`; `flutter config --list` reports `enable-dart-data-assets: true (Unavailable)`, and the documented `FLUTTER_DART_DATA_ASSETS=true` override cannot enable an unavailable stable feature. No manual staging fallback was restored.
- Documentation: the three maintained English guides now state workspace-root configuration as canonical, DataAssets as the shared Web build/run delivery path when enabled, and no writes into app `web/` or `build/web/` directories; the stale manual-staging and stable-DataAsset limitation statements are removed.
- Residual risk: a passing real Flutter Web build remains unverified until a Flutter toolchain that exposes/enables Dart DataAssets is available; G18 owns browser/runtime proof. The implementation intentionally fails fast rather than silently returning to guessed staging.
- Toolchain audit — 2026-09-21: the installed stable SDK's `features.dart` declares `dartDataAssets` with a `master` channel setting only; stable has no available setting. The official Flutter SDK archive currently schedules stable 3.47 for August 2026 and stable 3.50 for November 2026, while the upstream build-hooks tracker still lists `hook/build.dart` DataAssets support as ongoing work. This confirms the missing stable fixture is a Flutter release/toolchain boundary, not a package implementation failure.
- G16 evidence ledger — pure hook/build contract: `dart format --output=none --set-exit-if-changed` passed with 0 changes; `dart analyze hook test/hook_config_test.dart test/user_defines_config_test.dart test/web_runtime_pair_test.dart test/web_data_asset_test.dart` passed; the focused `dart test` command passed 35 tests. `web_data_asset_test.dart` proves the no-DataAsset diagnostic, five DataAsset names, workspace-root `hooks.user_defines`, three runtime-source dependencies, and no synthetic `workspace/web` or `workspace/build/web` writes.
- G16 evidence ledger — stable fixture: `flutter pub get` passed for `test/fixtures/review16_data_assets_workspace`; the workspace root configuration was accepted. From `apps/app`, `flutter build web --wasm --no-pub` reached the package hook and failed at the intentional guard because `buildDataAssets` was `false`. `flutter config --list` reported `enable-dart-data-assets: true (Unavailable)`; setting `FLUTTER_DART_DATA_ASSETS=true` could not override an unavailable stable feature. This is a verified negative-path/build blocker, not a package test failure.
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
