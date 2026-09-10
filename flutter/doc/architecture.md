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
 native callbacks      polling + JS bridge
 Android/desktop       Wasm memory + RGBA frames
 FFplay surfaces       Web FFplay surface
```

The main shared layer is under `lib/src/`: `session.dart`, the FFmpeg/FFprobe/FFplay session and kit classes, media models, `callback_manager.dart`, and the backend/finalizer interfaces. `lib/ffmpeg_kit_extended_flutter.dart` is the public entry point and `ffmpeg_kit_extended.dart` owns initialization and the common API facade.

## Platform boundaries

Native-only code lives under `lib/src/platform/native/` and includes `backend_native.dart`, `callback_bridge_native.dart`, `session_finalizer_native.dart`, the native loader, native FFplay surfaces, and `generated/ffmpeg_kit_bindings_native.dart`. It loads the native code asset, converts Dart strings and argument arrays to native memory, invokes the C wrapper, routes callbacks, and releases native handles.

Web-only code lives under `lib/src/platform/web/` and `lib/src/web/`. `backend_web.dart` invokes `generated/ffmpeg_kit_bindings_web.dart` through `wasm_loader.dart`; `wasm_memory.dart` reads and writes the Emscripten heap; `callback_bridge_web.dart` adapts Web events; and `web/ffplay_surface_web.dart` renders copied RGBA frames. `web/ffmpegkit_bridge.mjs` supplies Emscripten runtime services and is staged beside the Wasm data asset by `hook/build.dart`.

Conditional exports are concentrated in the platform barrels (`ffmpeg_kit_extended_flutter_native.dart` and `ffplay_surface.dart`). Shared session/business logic must not import `dart:ffi`, `package:ffi`, JS interop, generated platform bindings, or platform surface implementations.

## Generated bindings

`ffigen_native.yaml` generates `lib/src/generated/ffmpeg_kit_bindings_native.dart` for Dart FFI. `ffigen_js.yaml` generates `lib/src/generated/ffmpeg_kit_bindings_web.dart` for the Web ABI and restricts symbols to the FFmpegKit/FFprobeKit/FFplayKit wrapper surface. Generated files are transport declarations and must not be hand-edited. Regenerate them whenever `FFmpegKit/src/ffmpegkit_wrapper.h` changes:

```powershell
cd flutter
dart run ffigen --config ffigen_native.yaml
dart run ffigen --config ffigen_js.yaml
```

The Web generator is currently sourced from the `akashskypatel/ffigen_js`
fork at commit `429ef72aa61cd509296215d84ce910b578f321a9`, which contains the
required Wasm `uint64` interop support. Keep this exact SHA in `pubspec.yaml`;
when upstream incorporates the fix, migrate the dependency only after
regenerating the bindings and rerunning the analyzer, package tests, and Web
Wasm/browser verification.

## Initialization and execution

Applications call `await FFmpegKitExtended.initialize()` once after `WidgetsFlutterBinding.ensureInitialized()` and before creating sessions. Backend selection is compile-time conditional. Native initialization loads the code asset and installs native callback/finalizer support. Web initialization loads the staged `ffmpegkit.mjs`/`ffmpegkit.wasm` pair and exposes the generated module to the Web backend. Calls made before initialization are rejected by the backend contract.

Note that the WebAssembly bundle has pthread support by default. For a `non-pthread` build, a custom build of the WebAssembly dependencies and bundle is required using <https://github.com/akashskypatel/ffmpeg-kit-builders>.

The build hook resolves the configured bundle, verifies its SHA-256, requires both `ffmpegkit.mjs` and `ffmpegkit.wasm`, and stages them under the package Web asset directory. The Web build must use `flutter build web --wasm`. Pthread-enabled bundles require the deployed document to be cross-origin isolated:

```http
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

The runtime check is `window.crossOriginIsolated === true`. Without it, `SharedArrayBuffer` and Emscripten pthread workers cannot be used reliably.

## Callback routing

`CallbackManager` is platform-neutral: it registers sessions, dispatches logs/statistics, and completes FFmpeg, FFprobe, FFplay, and media-information sessions. Native callback bridges translate C callbacks into that manager. The synchronized Web bundles expose a mutable but fixed-size Wasm table with no usable callback capacity: the current bundles have only the reserved null slot available, and `WebAssembly.Table.grow()` fails. Because `ffigen_js.addFunction()` requires a free table slot, `WebFFmpegKitBackend` polls session state and pending logs/statistics, then dispatches the same shared callbacks. This is an intentional transport fallback, not a separate SDK behavior.

## Handles, finalizers, and memory

Backends create and release opaque session and information handles. Shared sessions store only a neutral `SessionHandle` and call the backend for lifecycle operations. Native handles are pointers and use `NativeFinalizer` where appropriate; explicit release remains the primary cleanup path. Web handles are Wasm-side numeric values and use the Web backend’s release operations.

Native strings and argument vectors are allocated for the duration of the call and freed by the native backend. Web strings and arrays are encoded into Emscripten memory through `wasm_memory.dart`, passed to the generated bindings, and freed after the wrapper call. Returned strings are copied before their Wasm allocations can be reused. Treat all Wasm pointers as invalid after the corresponding allocation is freed.

## FFplay rendering

`FFplaySession` and `FFplayKit` remain shared. Native `FFplaySurface` uses an Android surface or desktop texture. Web `FFplaySurface` polls `ffplay_kit_get_frame_buffer_size` and `ffplay_kit_copy_frame`, copies RGBA pixels from the Wasm heap, decodes them with Flutter, and renders a `RawImage` with `BoxFit.contain`. `FFplayView` fills available horizontal space and caps the surface at the source video height while preserving aspect ratio.

Web rendering is a copied-frame path; it does not create an SDL window or native texture. Frame polling and image decoding therefore have higher CPU/memory cost than native surfaces.

## Build and verification commands

```powershell
cd flutter
dart --suppress-analytics analyze
dart --suppress-analytics test
node --check web/ffmpegkit_bridge.mjs
cd example
flutter build web --wasm --no-pub
```

`dart test` can be blocked in restricted environments when its build hook cannot update the Dart telemetry session file; that is an environment limitation, not a substitute for the analyzer or Web build. Use `git diff --check` before handoff.

## Known limitations and maintenance rules

- Web deployment must serve the document and pthread assets with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` when using pthread-enabled bundles; verify `window.crossOriginIsolated` at runtime.
- Web completion, log, and statistics delivery currently uses polling because the synchronized bundles lack usable callback-table slots; callback-table registration must remain disabled until a bundle with reserved or growable slots and a validated pthread callback path is available.
- The hook’s Web asset staging follows the current Flutter data-asset behavior and contains a compatibility fallback for direct build output staging.
- Native and Web generated bindings are build contracts. Regenerate both after wrapper-header changes and verify native and Wasm builds.
- Keep platform-specific imports below the platform directories and preserve the shared backend interfaces when extending the API.
