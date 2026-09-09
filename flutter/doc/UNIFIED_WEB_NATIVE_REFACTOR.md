# Unified Flutter Native/Web Refactor Baseline

Status: Goal 1 baseline. This document records the current coupling and the
architecture contract for the later refactor. It does not change runtime code.

## Contract

The package must expose one core Dart API on native and Web/Wasm:

`FFmpegKit`, `FFprobeKit`, `FFplayKit`, `FFmpegKitExtended`, `FFmpegKitConfig`,
`Session`, `FFmpegSession`, `FFprobeSession`, `FFplaySession`,
`MediaInformationSession`, `Statistics`, and the value objects exported by the
package barrel.

The shared API must depend only on a platform-neutral backend contract. Native
and Web bindings remain separate generated artifacts; pointer types, allocators,
finalizers, JavaScript interop, and Emscripten memory access stay behind the
backend or platform bridge.

```text
Flutter public API / session behavior
                 |
        platform-neutral backend
          /                     \
 native backend               Web/Wasm backend
 dart:ffi + ffigen          ffigen_js + Emscripten
```

No runtime behavior is intentionally changed by this baseline packet.

## Current public API split

`flutter/lib/ffmpeg_kit_extended_flutter.dart` exports one shared barrel on
native and Web. Platform operations are selected below that barrel through the
backend, callback, loader/memory, and rendering adapters. The former Web file
contained a second handwritten SDK implementation, including these duplicated
declarations:

- `Statistics`, `SessionCancelledException`, `Session`
- `FFmpegSession`, `FFprobeSession`, `MediaInformationSession`, `FFplaySession`
- `FFmpegKit`, `FFprobeKit`, `FFplayKit`, `FFmpegKitExtended`, `FFmpegKitConfig`
- `SessionQueueManager`
- Web FFplay surface/view/controller types and Wasm frame helpers

Those duplicate declarations have now been removed. Web rendering helpers
remain platform-specific behind the FFplay rendering adapter.

## Dependency inventory

| Concern | Current locations | Intended owner |
| --- | --- | --- |
| `dart:ffi`, `package:ffi`, `Pointer`, `calloc`/`malloc` | `session.dart`, `ffmpeg_session.dart`, `ffprobe_session.dart`, `ffplay_session.dart`, `media_information_session.dart`, `ffmpeg_kit_extended.dart` | Native backend and native marshaling helpers |
| `NativeFinalizer`, `Finalizable`, native release callback | `session.dart`, `ffmpeg_kit_extended_flutter_loader.dart` | Native lifetime adapter; explicit release remains part of common behavior |
| Native generated bindings | `generated/ffmpeg_kit_bindings_native.dart` and current native API/session files | Native backend/callback bridge only |
| `dart:js_interop`, `dart:js_interop_unsafe`, `package:web` | `platform/web/` and `web/ffplay_surface_web.dart` | Web loader/backend and Web rendering |
| `ffigen_js` pointer wrappers and `BigInt` ABI values | `generated/ffmpeg_kit_bindings_web.dart`, consumed by the Web backend | Web backend; normalize values to ordinary Dart types |
| Emscripten module access, `_malloc`, `_free`, `HEAPU8`, `HEAP32`, UTF-8 helpers | `platform/web/wasm_loader.dart`, `platform/web/wasm_memory.dart` | Web loader/memory adapter |
| callback function pointers and native callback signatures | `callback_manager.dart`, native generated bindings | Shared callback routing plus native/Web callback bridges |
| FFplay frame copy and `ui.decodeImageFromPixels` | `web/ffplay_surface_web.dart`; native surface/texture files | Platform-specific rendering; shared FFplay controls |
| Flutter UI surface types | `ffplay_surface.dart`, `ffplay_view.dart`, Android/desktop files, `web/ffplay_surface_web.dart` | Conditional rendering layer |

The generated binding files are not interchangeable: native uses `dart:ffi`
bindings while Web uses `ffigen_js` wrappers. Shared code must not import either
file after migration.

## Ownership boundaries

### Shared API and business logic

Own public classes, constructors, session properties, command semantics,
callback registration semantics, return-code/state conversion, configuration
facades, session history behavior, and neutral model/value objects. Shared code
must use a neutral `SessionHandle` whose `Object value` is interpreted only by a
backend.

### Native backend

Own native UTF-8 and argv allocation, generated native binding calls,
`DynamicLibrary`/loader integration, `NativeFinalizer`, native pointer release,
and native callback function-pointer trampolines. Native handles must never
escape into the shared API as `Pointer` values.

### Web backend

Own Emscripten module initialization, generated Web binding calls, Web string
and argument marshaling, `BigInt`/ABI-width normalization, Wasm allocation and
heap views, and Web callback interop. Raw JavaScript calls are restricted to
Emscripten runtime services such as module loading, `_malloc`, `_free`, heap
views, and UTF-8 helpers; C wrapper symbols must be called through generated
Web bindings.

### Callback bridges

`CallbackManager` should eventually retain only neutral session lookup,
registration, and Dart callback dispatch. Native and Web bridges convert their
platform callback arguments into ordinary Dart values and dispatch through that
same manager. There must not be a second Web session map or duplicate dispatch
rules.

### FFplay rendering

`FFplaySession` and `FFplayKit` own common playback controls and state. Native
texture/Android surfaces remain native-specific. Web frame copying, Wasm heap
reads, `ffplay_kit_get_frame_buffer_size`, `ffplay_kit_copy_frame`, and Flutter
Web image decoding remain Web-specific. Rendering must not require a second
Web `FFplaySession` class.

## Handle and memory rules

The proposed neutral handle is:

```dart
final class SessionHandle {
  final Object value;
  const SessionHandle(this.value);
}
```

Native interprets the value as its FFI pointer and owns native finalization.
Web interprets it as its `ffigen_js` pointer and owns Wasm memory operations.
Shared code must not call `calloc`, `malloc`, `NativeFinalizer`,
`Pointer.fromAddress`, `_free`, or UTF-8 runtime helpers directly. Explicit
session close/release must remain deterministic on both platforms.

## Migration invariants

1. The public package import and core class names remain unchanged.
2. Native C ABI and generated bindings are not changed by the API refactor.
3. Web C calls use `ffmpeg_kit_bindings_web.dart`, not string-dispatched C symbols.
4. Generated bindings are regenerated, not manually mirrored in shared code.
5. Native finalizer behavior and explicit cleanup remain intact.
6. FFplay frame delivery may differ internally, but playback controls remain
   shared and the frame ABI remains `ffplay_kit_get_frame_buffer_size` plus
   `ffplay_kit_copy_frame`.
7. The old Web API file has been removed after the shared API compiled and the
   Web backend took ownership of every remaining Web-specific operation.

## Baseline evidence and limitations

The inventory was verified against the current source files listed below:

- public barrels: `lib/ffmpeg_kit_extended_flutter.dart`,
  `lib/src/ffmpeg_kit_extended_flutter_native.dart`
- Web backend: `lib/src/platform/web/backend_web.dart`
- sessions and API: `lib/src/session.dart`, `ffmpeg_session.dart`,
  `ffprobe_session.dart`, `ffplay_session.dart`,
  `media_information_session.dart`, `ffmpeg_kit.dart`, `ffprobe_kit.dart`,
  `ffplay_kit.dart`, `ffmpeg_kit_extended.dart`, `ffmpeg_kit_config.dart`
- callback/lifetime infrastructure: `lib/src/callback_manager.dart`,
  `lib/src/ffmpeg_kit_extended_flutter_loader.dart`
- generated transport: `lib/src/generated/ffmpeg_kit_bindings_native.dart`,
  `ffmpeg_kit_bindings_web.dart`
- rendering: `ffplay_surface.dart`, `ffplay_view.dart`,
  `ffplay_desktop_texture.dart`, `ffplay_android_surface.dart`,
  `ffplay_kit_android.dart`

The graph index is current but reports best-effort parse-partial markers on
several Dart files (notably conditional-export lines and Web/FFplay files).
Those flagged ranges were checked directly from source; conclusions here are
therefore source-backed, with graph results used for structural discovery.

## Scope of this packet

This packet creates the architecture contract and dependency inventory only.
It does not add a backend, change conditional exports, alter generated files,
change Web bundle selection, or change runtime behavior.
