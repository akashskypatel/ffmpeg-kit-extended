/// WebAssembly FFplay frame surface.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../generated/ffmpeg_kit_bindings_web.dart' as bindings;
import '../platform/web/wasm_loader.dart';
import '../platform/web/wasm_memory.dart';

/// Flutter widget surface backed by frames copied from the Emscripten heap.
///
/// FFplay publishes the most recent RGBA frame through the wrapper ABI. The
/// reader owns its Wasm allocations and copies frame bytes before decoding so
/// the native buffer can be reused on the next poll.
class FFplaySurface {
  FFplaySurface._() {
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _poll());
  }

  final _WasmFrameReader _reader = _WasmFrameReader();
  final ValueNotifier<ui.Image?> _image = ValueNotifier<ui.Image?>(null);
  Timer? _timer;
  bool _decoding = false;
  bool _released = false;

  /// Creates a WebAssembly frame surface after package initialization.
  static Future<FFplaySurface?> create({int width = 1, int height = 1}) async {
    wasmLoader.requireInitialized();
    return FFplaySurface._();
  }

  void _poll() {
    if (_released || _decoding) return;
    final frame = _reader.copyLatest();
    if (frame == null) return;
    _decoding = true;
    ui.decodeImageFromPixels(
      frame.pixels,
      frame.width,
      frame.height,
      ui.PixelFormat.rgba8888,
      (image) {
        _decoding = false;
        if (_released) {
          image.dispose();
          return;
        }
        final previous = _image.value;
        _image.value = image;
        previous?.dispose();
      },
      rowBytes: frame.linesize,
    );
  }

  /// Returns the widget displaying the most recently decoded frame.
  Widget toWidget() => ValueListenableBuilder<ui.Image?>(
    valueListenable: _image,
    builder: (context, image, child) => image == null
        ? const SizedBox.expand()
        : RawImage(image: image, fit: BoxFit.contain),
  );

  /// Stops polling and releases Wasm and decoded-image resources.
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _timer?.cancel();
    _timer = null;
    _reader.dispose();
    _image.value?.dispose();
    _image.dispose();
  }
}

final class _WasmFrame {
  const _WasmFrame({
    required this.pixels,
    required this.width,
    required this.height,
    required this.linesize,
  });

  final Uint8List pixels;
  final int width;
  final int height;
  final int linesize;
}

final class _WasmFrameReader {
  _WasmFrameReader()
    : _metadata = wasmMemory.allocate<bindings.Uint8>(_metadataBytes);

  static const _metadataBytes = 24;

  final bindings.Pointer<bindings.Uint8> _metadata;
  bindings.Pointer<bindings.Uint8>? _pixels;
  int _capacity = 0;
  int _lastGeneration = -1;
  bool _disposed = false;

  bindings.Pointer<T> _metadataAt<T extends bindings.NativeType>(int offset) =>
      bindings.Pointer<T>.fromAddress(_metadata.address + offset);

  _WasmFrame? copyLatest() {
    if (_disposed) return null;
    wasmLoader.requireInitialized();

    final required = bindings.ffplay_kit_get_frame_buffer_size();
    if (required <= 0) return null;
    if (_capacity < required) {
      final oldPixels = _pixels;
      if (oldPixels != null) wasmMemory.free(oldPixels);
      _pixels = wasmMemory.allocate<bindings.Uint8>(required);
      _capacity = required;
    }

    final pixels = _pixels!;
    final result = bindings.ffplay_kit_copy_frame(
      pixels,
      _capacity,
      _metadataAt<bindings.Int32>(0),
      _metadataAt<bindings.Int32>(4),
      _metadataAt<bindings.Int32>(8),
      _metadataAt<bindings.Int64>(16),
    );
    if (result != 1) return null;

    final width = wasmMemory.readInt32(_metadataAt<bindings.Int32>(0));
    final height = wasmMemory.readInt32(_metadataAt<bindings.Int32>(4));
    final linesize = wasmMemory.readInt32(_metadataAt<bindings.Int32>(8));
    final generation = wasmMemory.readInt64(_metadataAt<bindings.Int64>(16));
    if (generation == _lastGeneration ||
        width <= 0 ||
        height <= 0 ||
        linesize <= 0) {
      return null;
    }

    final byteCount = linesize * height;
    if (byteCount > _capacity) return null;
    _lastGeneration = generation;
    return _WasmFrame(
      pixels: Uint8List.fromList(wasmMemory.readBytes(pixels, byteCount)),
      width: width,
      height: height,
      linesize: linesize,
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final pixels = _pixels;
    if (pixels != null) wasmMemory.free(pixels);
    wasmMemory.free(_metadata);
    _pixels = null;
    _capacity = 0;
  }
}
