import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'wasm_loader.dart';

/// Web/Wasm access to temporary files in FFmpegKit's Emscripten filesystem.
///
/// Call `FFmpegKitExtended.initialize()` before using this API. File paths must
/// be absolute flat paths directly under `/tmp/`; data remains in browser
/// memory and is discarded when the page/runtime is reloaded.
abstract final class FFmpegKitWebFiles {
  /// Copies [bytes] into the Wasm filesystem at [filePath].
  static void writeFile(String filePath, Uint8List bytes) {
    _validateFilePath(filePath);
    final fileSystem = _requireFileSystem();
    _method(
      fileSystem,
      'writeFile',
    ).callAsFunction(fileSystem, filePath.toJS, bytes.toJS);
  }

  /// Returns an independent byte copy from the Wasm filesystem.
  static Uint8List readFile(String filePath) {
    _validateFilePath(filePath);
    final fileSystem = _requireFileSystem();
    final result = _method(
      fileSystem,
      'readFile',
    ).callAsFunction(fileSystem, filePath.toJS);
    if (result == null || !result.isA<JSUint8Array>()) {
      throw StateError('The Wasm filesystem returned non-binary file data.');
    }
    return Uint8List.fromList((result as JSUint8Array).toDart);
  }

  /// Deletes a file from the Wasm filesystem.
  static void deleteFile(String filePath) {
    _validateFilePath(filePath);
    final fileSystem = _requireFileSystem();
    _method(fileSystem, 'unlink').callAsFunction(fileSystem, filePath.toJS);
  }

  /// Returns false only when the requested file does not exist.
  static bool exists(String filePath) {
    _validateFilePath(filePath);
    final fileSystem = _requireFileSystem();
    try {
      final result = _method(
        fileSystem,
        'stat',
      ).callAsFunction(fileSystem, filePath.toJS);
      if (result == null || !result.isA<JSObject>()) {
        throw StateError('The Wasm filesystem returned invalid file metadata.');
      }
      final mode = (result as JSObject)
          .getProperty<JSNumber>('mode'.toJS)
          .toDartInt;
      if ((mode & 0xF000) != 0x8000) {
        throw ArgumentError.value(
          filePath,
          'filePath',
          'must identify a regular file directly under /tmp/',
        );
      }
      return true;
    } catch (error) {
      if (_isMissingFileError(error)) return false;
      rethrow;
    }
  }

  static JSObject _requireFileSystem() {
    wasmLoader.requireInitialized();
    final value = wasmLoader.module.getProperty<JSAny?>('FS'.toJS);
    if (value == null || !value.isA<JSObject>()) {
      throw StateError(
        'Local Wasm runtime lacks exported FS; rebuild with FS in EXPORTED_RUNTIME_METHODS.',
      );
    }
    final fileSystem = value as JSObject;
    final missing = <String>[];
    for (final name in const ['writeFile', 'readFile', 'unlink', 'stat']) {
      final method = fileSystem.getProperty<JSAny?>(name.toJS);
      if (method == null || !method.isA<JSFunction>()) {
        missing.add(name);
      }
    }
    if (missing.isNotEmpty) {
      throw StateError(
        'Local Wasm runtime lacks exported FS methods: ${missing.join(', ')}; '
        'rebuild with FS in EXPORTED_RUNTIME_METHODS.',
      );
    }
    return fileSystem;
  }

  static JSFunction _method(JSObject fileSystem, String name) =>
      fileSystem.getProperty<JSFunction>(name.toJS);

  static bool _isMissingFileError(Object error) {
    if (!error.isA<JSObject>()) return false;
    final jsError = error as JSObject;
    final code = jsError.getProperty<JSAny?>('code'.toJS);
    if (code != null &&
        code.isA<JSString>() &&
        (code as JSString).toDart == 'ENOENT') {
      return true;
    }
    final name = jsError.getProperty<JSAny?>('name'.toJS);
    final errno = jsError.getProperty<JSAny?>('errno'.toJS);
    return name != null &&
        name.isA<JSString>() &&
        (name as JSString).toDart == 'ErrnoError' &&
        errno != null &&
        errno.isA<JSNumber>() &&
        (errno as JSNumber).toDartInt == 44;
  }

  static void _validateFilePath(String filePath) {
    if (!filePath.startsWith('/tmp/')) {
      throw ArgumentError.value(
        filePath,
        'filePath',
        'must be an absolute file path directly under /tmp/',
      );
    }
    final name = filePath.substring('/tmp/'.length);
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.contains('/') ||
        name.contains('\\') ||
        name.contains('\u0000')) {
      throw ArgumentError.value(
        filePath,
        'filePath',
        'must be an absolute flat file path directly under /tmp/',
      );
    }
  }
}
