import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../generated/ffmpeg_kit_bindings_web.dart' as bindings;

/// Loads the Emscripten module and connects ffigen_js to that module instance.
final class WasmLoader {
  WasmLoader._();

  static final instance = WasmLoader._();
  static const assetRoot = 'assets/packages/ffmpeg_kit_extended_flutter/wasm';

  JSObject? _module;
  Future<void>? _initializing;

  bool get initialized => _module != null;

  JSObject get module {
    final value = _module;
    if (value == null) {
      throw StateError(
        'FFmpegKitExtended.initialize() must be awaited before using Web.',
      );
    }
    return value;
  }

  Future<void> initialize() => _initializing ??= _load();

  Future<void> _load() async {
    final existing = globalContext.getProperty<JSAny?>(
      'ffmpegKitExtendedModulePromise'.toJS,
    );
    if (existing == null) {
      final loaded = Completer<void>();
      final script = web.HTMLScriptElement()
        ..type = 'module'
        ..src = '$assetRoot/ffmpegkit_bridge.mjs';
      script.addEventListener(
        'load',
        ((web.Event _) => loaded.complete()).toJS,
        web.AddEventListenerOptions(once: true),
      );
      script.addEventListener(
        'error',
        ((web.Event _) => loaded.completeError(
          StateError('Unable to load $assetRoot/ffmpegkit_bridge.mjs'),
        )).toJS,
        web.AddEventListenerOptions(once: true),
      );
      web.document.head!.append(script);
      await loaded.future;
    }

    final promise = globalContext.getProperty<JSPromise<JSObject>>(
      'ffmpegKitExtendedModulePromise'.toJS,
    );
    _module = await promise.toDart;
    bindings.NativeLibrary.instance = _module! as bindings.NativeLibrary;
    bindings.ffmpeg_kit_initialize();
  }

  void requireInitialized() {
    if (!initialized) {
      throw StateError(
        'FFmpegKitExtended.initialize() must be awaited before using Web.',
      );
    }
  }
}

final wasmLoader = WasmLoader.instance;
