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
  static const overrideAssetRoot = WebAssetPaths.overrideAssetRoot;
  static const overrideManifest = WebAssetPaths.overrideManifest;

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
    final selectedAssetRoot = await _selectAssetRoot();
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
          StateError(
            'Unable to load $selectedAssetRoot/ffmpegkit_bridge.mjs',
          ),
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

  Future<String> _selectAssetRoot() async {
    try {
      final response = await web.window.fetch(overrideManifest.toJS).toDart;
      if (response.status == 404) return assetRoot;
      if (!response.ok) {
        throw StateError(
          'Unable to inspect the custom FFmpegKit Web runtime manifest '
          '(${response.status}).',
        );
      }
      final manifest = (await response.text().toDart).toDart;
      if (!manifest.contains('wasm_override')) {
        throw StateError(
          'The custom FFmpegKit Web runtime manifest does not identify '
          'wasm_override.',
        );
      }
      return overrideAssetRoot;
    } catch (error) {
      if (error is StateError) rethrow;
      // A missing optional DataAsset is expected for the stable default path.
      // The required default bridge load below still reports an unavailable
      // application asset as a normal initialization failure.
      return assetRoot;
    }
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
