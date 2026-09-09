import 'dart:convert';
import 'dart:typed_data';

import '../../generated/ffmpeg_kit_bindings_web.dart' as bindings;

/// Owns WebAssembly heap access and pointer/string lifetime conventions.
final class WasmMemory {
  const WasmMemory();

  bindings.Pointer<T> allocate<T extends bindings.NativeType>(int bytes) =>
      bindings.malloc<T>(bytes);

  void free(bindings.Pointer pointer) => bindings.free(pointer);

  bindings.Pointer<bindings.Char> stackUtf8(String value) =>
      value.toNativeUtf8();

  bindings.Pointer<bindings.Char> allocateUtf8(String value) {
    final bytes = utf8.encode(value);
    final pointer = allocate<bindings.Char>(bytes.length + 1);
    final output = pointer.cast<bindings.Uint8>().asTypedList(bytes.length + 1);
    output.setRange(0, bytes.length, bytes);
    output[bytes.length] = 0;
    return pointer;
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
