# Flutter architecture and maintenance handoff

## Contract and architecture

Flutter Web uses the same FFmpegKit Dart SDK implementation as native. Only platform integration layers differ. Shared sessions, models, callbacks, and public APIs depend on the platform backend contract; native and Web provide the transport, memory, loading, and rendering details.

```text
Public API and shared session lifecycle
                |
       platform/backend.dart
          /             \
 Native backend        Web/Wasm backend
 dart:ffi + assets      ffigen_js + Emscripten
          |             |
 native callbacks      Wasm callbacks + JS bridge
 Android/desktop       Wasm memory + RGBA frames
 FFplay surfaces       Web FFplay surface
```

The main shared layer is under `lib/src/`: `session.dart`, the FFmpeg/FFprobe/FFplay session and kit classes, media models, `callback_manager.dart`, and the backend/finalizer interfaces. `lib/ffmpeg_kit_extended_flutter.dart` is the public entry point and `ffmpeg_kit_extended.dart` owns initialization and the common API facade.

## Platform boundaries

Native-only code lives under `lib/src/platform/native/` and includes `backend_native.dart`, `callback_bridge_native.dart`, `session_finalizer_native.dart`, the native loader, native FFplay surfaces, and `generated/ffmpeg_kit_bindings_native.dart`. It loads the native code asset, converts Dart strings and argument arrays to native memory, invokes the C wrapper, routes callbacks, and releases native handles.

Web-only code lives under `lib/src/platform/web/` and `lib/src/web/`. `backend_web.dart` invokes `generated/ffmpeg_kit_bindings_web.dart` through `wasm_loader.dart`; `wasm_memory.dart` reads and writes the Emscripten heap; `callback_bridge_web.dart` adapts Web events; and `web/ffplay_surface_web.dart` renders copied RGBA frames. `hook/build.dart` resolves the selected default or custom Wasm pair and stages it with `web/ffmpegkit_bridge.mjs` and its support modules at the canonical `assets/packages/ffmpeg_kit_extended_flutter/wasm/` browser root.

Conditional exports are concentrated in the platform barrels (`ffmpeg_kit_extended_flutter_native.dart` and `ffplay_surface.dart`). Shared session/business logic must not import `dart:ffi`, `package:ffi`, JS interop, generated platform bindings, or platform surface implementations.

## Generated bindings

`ffigen_native.yaml` generates `lib/src/generated/ffmpeg_kit_bindings_native.dart` for Dart FFI. `ffigen_js.yaml` generates `lib/src/generated/ffmpeg_kit_bindings_web.dart` for the Web ABI and restricts symbols to the FFmpegKit/FFprobeKit/FFplayKit wrapper surface. Generated files are transport declarations and must not be hand-edited. Regenerate them whenever `FFmpegKit/src/ffmpegkit_wrapper.h` changes:

```powershell
cd flutter
dart run ffigen --config ffigen_native.yaml
dart run ffigen_js --config ffigen_js.yaml
```

The Web generator currently uses the accepted published prerelease
`ffigen_js: ^0.0.16-pre`, which contains the required Wasm `uint64` interop
support. Keep this dependency exception until a stable publication is
available; migrate only after regenerating the bindings and rerunning the
analyzer, package tests, and Web Wasm/browser verification.

## Initialization and execution

Applications call `await FFmpegKitExtended.initialize()` once after `WidgetsFlutterBinding.ensureInitialized()` and before creating sessions. Backend selection is compile-time conditional. Native initialization loads the code asset and installs native callback/finalizer support. Web initialization loads the build-hook-selected runtime from the single canonical `wasm/` asset root, then exposes the generated module to the Web backend. Successful initialization is idempotent, concurrent calls share one attempt, and a failed Web attempt can be retried. Calls made before initialization are rejected by the backend contract.

Note that the WebAssembly bundle has pthread support by default. For a `non-pthread` build, a custom build of the WebAssembly dependencies and bundle is required using <https://github.com/akashskypatel/ffmpeg-kit-builders>.

For every Web selection, the build hook resolves the configured bundle, verifies official/downloaded artifacts as applicable, requires both `ffmpegkit.mjs` and `ffmpegkit.wasm` in one coherent runtime directory, and stages the runtime plus bridge/support files into the consuming app's source and build Web trees. Default, non-default, local, and HTTP(S) override selections all use this path on stable Flutter 3.47 without Dart DataAssets. The Web build must use `flutter build web --wasm`. Pthread-enabled bundles require the deployed document to be cross-origin isolated:

```http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

The runtime check is `window.crossOriginIsolated === true`. Without it, `SharedArrayBuffer` and Emscripten pthread workers cannot be used reliably.

## Callback routing

`CallbackManager` is platform-neutral: it registers sessions, dispatches logs/statistics, and completes FFmpeg, FFprobe, FFplay, and media-information sessions. Native callback bridges translate C callbacks into that manager. On ABI-v2-capable runtimes, the Web and native bridges carry an owned structured event containing the session ID, native sequence, level, and copied message; normal live delivery does not poll indexed history. The v1 buffered-history path remains available when v2 is not exported. Callback pointers and owned payloads remain internal to the bridge until the callback slots are disabled and the event-loop lifetime barrier has elapsed.

The callback maps are routing state, not a lifetime registry for every created
session. A session is registered when a callback, listener, or execution needs
routing and is removed when that need settles. A created-but-unused session can
therefore be disposed deterministically without relying on callback-map
retention.

### Callback demand, redirection, and reconciliation

Completion transport is required for an asynchronous execution. Log and
statistics transport is installed only while a matching consumer is present,
so callback demand cannot make completion depend on optional observers. The
wrapper does not call `enableRedirection()` as a side effect of installing a
bridge. `FFmpegKitConfig.disableRedirection()` remains the authoritative
native capture/forwarding switch.

The direct v2 log path orders and deduplicates events by the native sequence.
At terminal state it reads the retained log count once and fetches only a
bounded missing range when a direct event was late; native history getters
remain available for inspection and this reconciliation path. If v2 is absent,
the wrapper explicitly falls back to indexed history polling. Messages are
copied into managed objects and native payload memory is released inside the
bridge; callers never receive a borrowed pointer.

Custom or non-default Web/Wasm runtime selection uses the same direct staging
path as the default runtime and is supported on stable Flutter 3.47 without
Dart DataAssets. The package intentionally keeps `ffigen_js: ^0.0.16-pre`
because no stable release exists.

## Handles, finalizers, and memory

Backends create and release opaque session and information handles. Shared sessions store only a neutral `SessionHandle` and call the backend for lifecycle operations. Native handles are pointers and use `NativeFinalizer` as a safety net; explicit release remains the deterministic cleanup path. Web handles use the Web backend’s release operations and a `Finalizer` safety net for abandoned wrappers; callers should still explicitly dispose sessions when deterministic release timing matters. History and lookup wrappers adopt their acquired handles and are independently disposable. A zero factory handle or an unknown history type is rejected and released rather than wrapped as the wrong session subtype.

Native strings and argument vectors are allocated for the duration of the call and freed by the native backend. Web strings and arrays are encoded into Emscripten memory through `wasm_memory.dart`, passed to the generated bindings, and freed after the wrapper call. Returned strings are copied before their Wasm allocations can be reused. Treat all Wasm pointers as invalid after the corresponding allocation is freed.

## FFplay rendering

`FFplaySession` and `FFplayKit` remain shared. Native `FFplaySurface` uses an Android surface or desktop texture. Web `FFplaySurface` polls `ffplay_kit_get_frame_buffer_size` and `ffplay_kit_copy_frame`, copies RGBA pixels from the Wasm heap, decodes them with Flutter, and renders a `RawImage` with `BoxFit.contain`. `FFplayView` fills available horizontal space and caps the surface at the source video height while preserving aspect ratio.

Web rendering is a copied-frame path; it does not create an SDL window or native texture. Frame polling and image decoding therefore have higher CPU/memory cost than native surfaces.

## Build and verification commands

```powershell
cd flutter
dart --disable-analytics analyze
dart --disable-analytics test
node --check web/ffmpegkit_bridge.mjs
cd example
flutter build web --wasm --no-pub
```

Configure Flutter analytics once with `flutter config --no-analytics`, and use
`dart --disable-analytics` for direct Dart commands. If an already-running Dart
daemon has locked `dart-flutter-telemetry.log`, terminate that daemon and retry;
do not add product code to work around the local telemetry file.

Flutter's test runner evaluates the native-assets build hook for the host
`TargetPlatform.tester`. Consequently, `flutter test` cannot select this
package's assets for a non-host target. This applies to all target platforms.
Use the platform-specific build or run command—for
example, `flutter build web --wasm` and a served Web application for Web asset
validation—and do not treat `flutter test` as coverage of non-host hook
selection.

The Flutter Web runtime smoke entrypoint is
`example/lib/web_runtime_smoke.dart`; its Playwright runner is
`example/web_runtime_smoke.mjs`. Run that smoke locally through a
cross-origin-isolated Web server. A workflow compile/build result is not a
browser-runtime result because the hosted runner does not provide the required
browser environment; do not use a workflow run as a substitute for the local
browser gate.

## Known limitations and maintenance rules

- Web deployment must serve the document and pthread assets with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` when using pthread-enabled bundles; verify `window.crossOriginIsolated` at runtime.
- Web completion, log, and statistics delivery uses generated callback pointers. The bridge requires a bundle with a usable Wasm function table and a browser deployment that supports the bundle's pthread configuration.
- The hook directly stages the selected Web runtime into the consuming app's source `web/` and generated `build/web/` trees at the canonical package URL; Dart DataAssets are not a runtime-delivery prerequisite.
- ABI-v2 direct log delivery is demand-driven and history-free during steady state; native history remains the public inspection and bounded terminal-reconciliation fallback.
- `disableRedirection()` is authoritative. Installing a Flutter callback bridge does not implicitly enable native redirection, and completion remains independent of optional log/statistics consumers.
- Native and Web generated bindings are build contracts. Regenerate both after wrapper-header changes and verify native and Wasm builds.
- Keep platform-specific imports below the platform directories and preserve the shared backend interfaces when extending the API.
### Session submission authority

Each Flutter session claims execution once while its native state is `Created`.
The claim happens before callback registration or queue insertion, so repeated
calls and history wrappers for running or terminal sessions cannot submit the
same native handle again. A new execution requires a new session object.

Cancellation is latched before queue/state/native operations. Queued sessions
are removed by identity and discarded in order-preserving fashion; a submitted
session that is still in native startup retains its request until the state is
`Running`, when one native cancellation is dispatched. The queue marks every
started execution settled from its `finally` block, bounding cancellation
handoff retries even when state reads fail or startup never reports `Running`.
Repeated cancellation can retry a failed native delivery, while natural
completion can still win the cancellation race; `isCancelled` records intent,
not the terminal result.

Disposal follows the same ownership boundary: native release is the commit
point. Release failure leaves the session live and retryable; finalizer detach
and Dart cleanup happen only after release succeeds. The cleanup order is
finalizer detach, execution error-handler clear, then `onDispose()`; later
cleanup errors cannot roll back or repeat the native release.

FFplayKit ownership follows Future settlement rather than only the completion
callback. The newest active session remains current until its tracked
execution settles, and an older session cannot clear a newer one.
The FFplay startup Future completes at the native handoff so callers can attach
surfaces and controls without waiting for full playback.
