# Review 28 Runtime Production-Readiness Report

Date: 2026-09-24

## Authority and candidate

- Review 27 starting wrapper SHA: `8e5b25efa9268e6c547001abb1a1f4255e08e7cb`.
- Review 28 Phase A candidate wrapper SHA: `8db1b7680d1e5902832cc1a3e92940ce9e441666`.
- Candidate tree SHA: `53b0af31be4b8ba6a7d69ae557e053da67692595`.
- Frozen native product source SHA: `625c3452ee3c93fb5d701bb6546726940b88d014`.
- `libs/libffmpegkit` remains clean on `dev` at `b74da2c5d1e294b87d15d73a6687393729e932b3`, matching origin. The native ABI and ManyLinux builder checkout were not modified.
- This is the clean Phase A manual-validation candidate. It is not yet promoted to a final runtime-validated source until the user completes the deferred interactive matrices.

## Findings and implementation

Review 28 found that Flutter Windows/Linux/macOS texture-registration failure was not handled before process-global FFplay ownership could be installed. Linux also retained a plugin-owned `FfkitGlTexture` GObject reference after Flutter disposal.

- Windows and Linux now fail closed before installing FFplay ownership or returning a texture ID when the registrar rejects registration.
- macOS checks its documented `registerTexture:` failure sentinel and unwinds. The duplicate SwiftPM source is behaviorally identical.
- iOS was intentionally left unchanged: the installed Flutter SDK's iOS engine allocates IDs with `nextTextureId++` and has no failure result; zero is a valid first ID for that SDK.
- Linux disposal marks the texture destroyed under its mutex, unregisters it, and releases the plugin-owned reference exactly once. Queued idle callbacks retain their own reference and re-check destruction before touching the texture.
- The semantic transaction helper and focused lifecycle fixtures cover registration failure, owner unwind, queued callbacks, and finalization.

## Embedder contracts used by G1

- Windows registrar registration returns a negative `int64_t` on failure; the wrapper treats any negative result as failure.
- Linux `fl_texture_registrar_register_texture` returns a boolean; false causes object cleanup and a `TEXTURE_REGISTRATION_FAILED` error.
- macOS `FlutterTextureRegistrar` documents texture ID `0` as its registration failure sentinel; the wrapper only applies this contract to macOS.
- The exact installed iOS SDK was inspected before deciding not to apply the macOS sentinel to iOS.

## Files changed

- `flutter/windows/ffmpeg_kit_extended_flutter_plugin.cpp`
- `flutter/linux/ffmpeg_kit_extended_flutter_plugin.cc`
- `flutter/linux/test/ffmpeg_kit_extended_flutter_plugin_test.cc`
- `flutter/macos/Classes/FfplayKitPlugin.m`
- `flutter/macos/ffmpeg_kit_extended_flutter/Classes/ffmpeg_kit_native/FfplayKitPlugin.m`
- `flutter/native/texture_registration_transaction.h`
- `flutter/test/native/texture_registration_transaction_test.cpp`
- `flutter/hook/build.dart`
- `flutter/test/hook_artifact_cache_test.dart`
- `.agent/TRACKER.md`

## Focused and local validation

- Standalone Windows transaction oracle: passed.
- WSL transaction oracle: passed.
- WSL GLib finalization oracle: passed.
- Flutter hook path suite: passed.
- Flutter architecture suite: **9/9**.
- Flutter lifecycle/ownership suites: **29/29**.
- React Native config suite: **25/25**.
- React Native unit suite: **18/18**.
- Native/staging lifecycle tests: **10/10**.
- Flutter Windows Release: passed with the supplied WSL-local Windows ZIP.
- Flutter Linux Release: passed under WSL with scoped `CFLAGS=-fPIC CXXFLAGS=-fPIC` and the supplied WSL-local Linux ZIP.
- Flutter Android Release: passed on the local Windows host with the supplied WSL-local AAR. No WSL Android build was required.
- React Native Windows and Android local gates: passed with supplied local artifacts.
- No Flutter/React Native interactive app was launched and no hosted Flutter/React Native workflow or remotely staged old binary was used.

## Apple noninteractive refresh

The MacBook Air checkout at `akash@192.168.1.189` was fast-forwarded to the candidate. The local universal archives remained the artifact authority:

- iOS: `9f10e46e4326d2cf1ec6542f82cfb714a9f5e3aeade8a38073218cdb6e18bf68`.
- tvOS: `96bb464af154f8a90d160e2d86a194c5b24f2c85924e76e285e07a7d5019e172`.
- macOS: `e524b6a0cd6edf88af2e2bcd2e8d5b7253ff60c4b24eb213eeaf581d89cd099b`.

Results:

- Flutter generated Xcode workspace macOS Release build: passed; local macOS universal archive and arm64/x86_64 slices were selected.
- Flutter generated Xcode workspace iOS Simulator Debug build: passed; local iOS archive and `ios-arm64-simulator` slice were selected.
- Flutter generated Xcode workspace iOS unsigned device-target Debug build: passed; local iOS archive and `ios-arm64` slice were selected.
- Flutter iOS Release Simulator was intentionally not counted: Flutter AOT release builds are physical-device-only. The attempted build reached the hook and selected the correct local simulator slice before the expected AOT-target rejection.
- React Native `npm run check`: **167/167** executed tests passed; three Windows-only tests were skipped and two existing lint warnings remained.
- React Native iOS, tvOS, and macOS Release builds: passed with local universal archives, CocoaPods, and codegen.
- No Apple interactive host was launched. No `xcodebuild`, CocoaPods, Ruby, npm, or Node process from these gates remains running.

The Flutter CLI is not present in the noninteractive SSH PATH. This is not a build blocker because the existing generated Flutter Xcode workspaces supplied the required post-change noninteractive Apple build gates.

## Deferred manual-runtime matrices

- Windows Flutter/RN: prepared in the Review 28 plan; not launched by Luna.
- Linux Flutter: prepared in the Review 28 plan; not launched by Luna.
- macOS Flutter/RN: prepared; noninteractive builds passed, interactive runtime remains user-owned.
- iOS Simulator Flutter/RN: prepared; Flutter simulator build evidence passed, interactive runtime remains user-owned.
- tvOS Simulator RN: prepared; package/build evidence passed, interactive runtime remains user-owned.
- Physical iOS/tvOS devices: not run and not claimed.
- Rendered-frame and process-global owner-transition stress: deterministic fixtures and pass/fail oracles are prepared; execution remains deferred to the user.

## Remaining risk and promotion

No open Phase A wrapper finding remains. The remaining risk is runtime behavior that only an interactive host/device can expose, including FFplay frame rendering, owner replacement, pause/resume/stop/release behavior, and repeated lifecycle transitions. If the user finds a defect, open a new tracker finding, classify its owner, and re-run the affected gates before promotion.

The candidate must remain the exact tested source until manual sign-off. Source and builder snapshots are intentionally not recorded here yet; they are authorized only after the user promotes this candidate to final following the deferred manual phase.
