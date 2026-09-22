import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../generated/ffmpeg_kit_bindings_web.dart' as bindings;
import 'retryable_initialization.dart';
import 'web_asset_paths.dart';

/// Loads the Emscripten module and connects ffigen_js to that module instance.
final class WasmLoader {
  WasmLoader._();

  static final instance = WasmLoader._();
  static const assetRoot = WebAssetPaths.defaultAssetRoot;

  final _initialization = RetryableInitialization<JSObject>();

  bool get initialized => _initialization.initialized;

  JSObject get module {
    if (!initialized) {
      throw StateError(
        'FFmpegKitExtended.initialize() must be awaited before using Web.',
      );
    }
    return _initialization.value;
  }

  Future<void> initialize() async {
    await _initialization.initialize(_loadAndCommit);
  }

  Future<JSObject> _loadAndCommit() async {
    final module = await _loadModule();
    bindings.NativeLibrary.instance = module as bindings.NativeLibrary;
    bindings.ffmpeg_kit_initialize();
    return module;
  }

  Future<JSObject> _loadModule() async {
    const selectedAssetRoot = assetRoot;
    final existing = globalContext.getProperty<JSAny?>(
      'ffmpegKitExtendedModuleFactory'.toJS,
    );
    if (existing == null) {
      final loaded = Completer<void>();
      final script = web.HTMLScriptElement()
        ..type = 'module'
        ..src = '$selectedAssetRoot/ffmpegkit_bridge.mjs';
      script.addEventListener(
        'load',
        ((web.Event _) => loaded.complete()).toJS,
        web.AddEventListenerOptions(once: true),
      );
      script.addEventListener(
        'error',
        ((web.Event _) => loaded.completeError(
          StateError('Unable to load $selectedAssetRoot/ffmpegkit_bridge.mjs'),
        )).toJS,
        web.AddEventListenerOptions(once: true),
      );
      web.document.head!.append(script);
      await loaded.future;
    }

    final factory = globalContext.getProperty<JSFunction>(
      'ffmpegKitExtendedModuleFactory'.toJS,
    );
    final result = factory.callAsFunction();
    if (result == null) {
      throw StateError('FFmpegKit Web module factory returned no Promise.');
    }
    final promise = result as JSPromise<JSObject>;
    return promise.toDart;
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
