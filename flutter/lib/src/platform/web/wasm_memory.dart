import 'dart:convert';
import 'dart:typed_data';

import '../../generated/ffmpeg_kit_bindings_web.dart' as bindings;

/// Operations used by [WasmMemory] to own temporary Wasm allocations.
///
/// The default implementation delegates to the generated FFmpegKit bindings.
/// Keeping the operations behind this small interface also makes the lifetime
/// contract testable without requiring a browser or a loaded Wasm module.
abstract interface class WasmAllocator {
  bindings.Pointer<T> allocate<T extends bindings.NativeType>(int bytes);

  void free(bindings.Pointer pointer);

  void writeUtf8(bindings.Pointer<bindings.Char> pointer, List<int> bytes);

  void writePointer(
    bindings.Pointer<bindings.PointerClass<bindings.Char>> array,
    int index,
    bindings.Pointer<bindings.Char> value,
  );
}

final class _BindingsWasmAllocator implements WasmAllocator {
  const _BindingsWasmAllocator();

  @override
  bindings.Pointer<T> allocate<T extends bindings.NativeType>(int bytes) =>
      bindings.malloc<T>(bytes);

  @override
  void free(bindings.Pointer pointer) =>
      bindings.ffmpeg_kit_free(pointer.cast());

  @override
  void writeUtf8(bindings.Pointer<bindings.Char> pointer, List<int> bytes) {
    final output = pointer.cast<bindings.Uint8>().asTypedList(bytes.length + 1);
    output.setRange(0, bytes.length, bytes);
    output[bytes.length] = 0;
  }

  @override
  void writePointer(
    bindings.Pointer<bindings.PointerClass<bindings.Char>> array,
    int index,
    bindings.Pointer<bindings.Char> value,
  ) {
    array[index] = value;
  }
}

/// Owns WebAssembly heap access and pointer/string lifetime conventions.
final class WasmMemory {
  final WasmAllocator _allocator;

  const WasmMemory({this._allocator = const _BindingsWasmAllocator()});

  bindings.Pointer<T> allocate<T extends bindings.NativeType>(int bytes) =>
      _allocator.allocate<T>(bytes);

  void free(bindings.Pointer pointer) => _allocator.free(pointer);

  T withUtf8<T>(
    String value,
    T Function(bindings.Pointer<bindings.Char> pointer) action,
  ) {
    final pointer = allocateUtf8(value);
    try {
      return action(pointer);
    } finally {
      free(pointer);
    }
  }

  bindings.Pointer<bindings.Char> allocateUtf8(String value) {
    final bytes = utf8.encode(value);
    final pointer = allocate<bindings.Char>(bytes.length + 1);
    try {
      _allocator.writeUtf8(pointer, bytes);
      return pointer;
    } catch (_) {
      free(pointer);
      rethrow;
    }
  }

  T withArguments<T>(
    List<String> arguments,
    T Function(bindings.Pointer<bindings.PointerClass<bindings.Char>> argv)
    action,
  ) {
    // The Web bundle targets wasm32, so each argv slot is one 32-bit pointer.
    final argv = allocate<bindings.PointerClass<bindings.Char>>(
      4 * arguments.length,
    );
    final values = <bindings.Pointer<bindings.Char>>[];
    try {
      for (var i = 0; i < arguments.length; i++) {
        final value = allocateUtf8(arguments[i]);
        values.add(value);
        _allocator.writePointer(argv, i, value);
      }
      return action(argv);
    } finally {
      for (final value in values) {
        free(value);
      }
      free(argv.cast());
    }
  }

  String? read(bindings.Pointer<bindings.Char> pointer) {
    if (pointer.address == 0) return null;
    return pointer.toDartString();
  }

  String? readAndFree(bindings.Pointer<bindings.Char> pointer) {
    if (pointer.address == 0) return null;
    try {
      return pointer.toDartString();
    } finally {
      // Strings returned by the FFmpegKit C ABI are owned by the caller.
      bindings.ffmpeg_kit_free(pointer.cast());
    }
  }

  int readInt32(bindings.Pointer<bindings.Int32> pointer) => pointer.getValue();

  int readInt64(bindings.Pointer<bindings.Int64> pointer) => pointer.getValue();

  Uint8List readBytes(bindings.Pointer<bindings.Uint8> pointer, int length) =>
      pointer.asTypedList(length);
}

const wasmMemory = WasmMemory();
