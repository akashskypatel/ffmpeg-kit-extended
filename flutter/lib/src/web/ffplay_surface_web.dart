/// WebAssembly FFplay frame surface.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../generated/ffmpeg_kit_bindings_web.dart' as bindings;
import '../platform/web/wasm_loader.dart';
import '../platform/web/wasm_memory.dart';
import 'ffplay_playback_epoch.dart';

final FFplayWebPlaybackEpoch _playbackEpoch = FFplayWebPlaybackEpoch();
bool Function()? _isPlaybackReady;
bool _alwaysReady() => true;

/// Browser canvas surface backed by frames copied from the Emscripten heap.
///
/// FFplay publishes the most recent RGBA frame through the wrapper ABI. The
/// reader owns a Wasm scratch buffer and copies each new frame directly from
/// that buffer into browser image data before yielding to the event loop.
class FFplaySurface {
  FFplaySurface._() : _reader = _WasmFrameReader() {
    _timer = Timer.periodic(
      const Duration(milliseconds: kDebugMode ? 33 : 16),
      (_) => _poll(),
    );
  }

  @visibleForTesting
  FFplaySurface.test() : _reader = null;

  final _WasmFrameReader? _reader;
  final FFplayWebSurfaceEpoch _surfaceEpoch = FFplayWebSurfaceEpoch();
  web.HTMLCanvasElement? _canvas;
  web.CanvasRenderingContext2D? _context;
  web.ImageData? _imageData;
  Timer? _timer;
  bool _rendering = false;
  bool _released = false;

  /// Creates a WebAssembly frame surface after package initialization.
  static Future<FFplaySurface?> create({int width = 1, int height = 1}) async {
    wasmLoader.requireInitialized();
    return FFplaySurface._();
  }

  /// Commits a new rendering epoch after FFplay native startup succeeds.
  static void beginPlayback({required bool Function() isReady}) {
    _isPlaybackReady = isReady;
    _playbackEpoch.beginPlayback();
  }

  /// Stops reading the FFplay frame buffer after terminal cleanup.
  static void endPlayback() => _isPlaybackReady = null;

  void _poll() {
    if (_released || _rendering) return;
    final reader = _reader;
    final canvas = _canvas;
    final context = _context;
    if (reader == null || canvas == null || context == null) return;
    final epoch = _playbackEpoch.value;
    if (_surfaceEpoch.observe(epoch)) {
      context.clearRect(0, 0, canvas.width, canvas.height);
    }
    final isReady = _isPlaybackReady;
    if (isReady == null) return;
    try {
      if (!isReady()) return;
      _isPlaybackReady = _alwaysReady;
    } catch (_) {
      return;
    }
    final frame = reader.copyLatest(epoch: epoch);
    if (frame == null) return;

    if (canvas.width != frame.width) canvas.width = frame.width;
    if (canvas.height != frame.height) canvas.height = frame.height;
    final image = _imageDataFromFrame(frame);
    _rendering = true;
    unawaited(_renderFrame(image, epoch));
  }

  web.ImageData _imageDataFromFrame(_WasmFrame frame) {
    final rowBytes = frame.width * 4;
    var image = _imageData;
    if (image == null ||
        image.width != frame.width ||
        image.height != frame.height) {
      image = web.ImageData(frame.width.toJS, frame.height);
      _imageData = image;
    }
    final imagePixels = image.data;
    final source = wasmMemory
        .readBytes(frame.pixels, frame.linesize * frame.height)
        .toJS;
    if (frame.linesize == rowBytes) {
      imagePixels.callMethod<JSAny?>('set'.toJS, source);
    } else {
      for (var row = 0; row < frame.height; row++) {
        final sourceOffset = row * frame.linesize;
        final sourceRow = source.callMethod<JSUint8Array>(
          'subarray'.toJS,
          sourceOffset.toJS,
          (sourceOffset + rowBytes).toJS,
        );
        imagePixels.callMethod<JSAny?>(
          'set'.toJS,
          sourceRow,
          (row * rowBytes).toJS,
        );
      }
    }
    return image;
  }

  Future<void> _renderFrame(web.ImageData image, int epoch) async {
    try {
      final bitmap = await web.window.createImageBitmap(image).toDart;
      try {
        if (_released || _playbackEpoch.value != epoch) return;
        final context = _context;
        if (context == null) return;
        context.drawImage(bitmap, 0, 0);
      } finally {
        bitmap.close();
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'FFplay web surface',
        ),
      );
    } finally {
      _rendering = false;
    }
  }

  /// Creates the DOM canvas used to display the latest copied frame.
  Widget toWidget() {
    if (_reader == null) return const SizedBox.expand();
    return HtmlElementView.fromTagName(
      tagName: 'canvas',
      onElementCreated: (element) {
        final canvas = element as web.HTMLCanvasElement;
        canvas.style
          ..display = 'block'
          ..width = '100%'
          ..height = '100%'
          ..setProperty('object-fit', 'contain');
        _canvas = canvas;
        _context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      },
    );
  }

  /// Stops polling and releases Wasm and decoded-image resources.
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _timer?.cancel();
    _timer = null;
    _reader?.dispose();
    final canvas = _canvas;
    if (canvas != null) {
      canvas.width = 0;
      canvas.height = 0;
    }
    _canvas = null;
    _context = null;
    _imageData = null;
  }
}

final class _WasmFrame {
  const _WasmFrame({
    required this.pixels,
    required this.width,
    required this.height,
    required this.linesize,
  });

  final bindings.Pointer<bindings.Uint8> pixels;
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
  final FFplayWebFrameIdentity _frameIdentity = FFplayWebFrameIdentity();
  int _capacity = 0;
  bool _disposed = false;

  bindings.Pointer<T> _metadataAt<T extends bindings.NativeType>(int offset) =>
      bindings.Pointer<T>.fromAddress(_metadata.address + offset);

  _WasmFrame? copyLatest({required int epoch}) {
    if (_disposed) return null;
    wasmLoader.requireInitialized();

    // Read frame metadata first. The 16 ms timer often polls faster than the
    // video frame rate, so avoid copying an unchanged RGBA frame out of Wasm.
    bindings.ffplay_kit_copy_frame(
      const bindings.Pointer<bindings.Uint8>.fromAddress(0),
      0,
      _metadataAt<bindings.Int32>(0),
      _metadataAt<bindings.Int32>(4),
      _metadataAt<bindings.Int32>(8),
      _metadataAt<bindings.Int64>(16),
    );
    final width = wasmMemory.readInt32(_metadataAt<bindings.Int32>(0));
    final height = wasmMemory.readInt32(_metadataAt<bindings.Int32>(4));
    final linesize = wasmMemory.readInt32(_metadataAt<bindings.Int32>(8));
    final generation = wasmMemory.readInt64(_metadataAt<bindings.Int64>(16));
    if (width <= 0 ||
        height <= 0 ||
        linesize < width * 4 ||
        _frameIdentity.isDuplicate(epoch: epoch, generation: generation)) {
      return null;
    }
    final required = linesize * height;
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

    final copiedWidth = wasmMemory.readInt32(_metadataAt<bindings.Int32>(0));
    final copiedHeight = wasmMemory.readInt32(_metadataAt<bindings.Int32>(4));
    final copiedLinesize = wasmMemory.readInt32(_metadataAt<bindings.Int32>(8));
    final copiedGeneration = wasmMemory.readInt64(
      _metadataAt<bindings.Int64>(16),
    );
    if (copiedWidth <= 0 ||
        copiedHeight <= 0 ||
        copiedLinesize < copiedWidth * 4) {
      return null;
    }

    final byteCount = copiedLinesize * copiedHeight;
    if (byteCount > _capacity) return null;
    if (!_frameIdentity.accept(epoch: epoch, generation: copiedGeneration)) {
      return null;
    }
    return _WasmFrame(
      pixels: pixels,
      width: copiedWidth,
      height: copiedHeight,
      linesize: copiedLinesize,
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
