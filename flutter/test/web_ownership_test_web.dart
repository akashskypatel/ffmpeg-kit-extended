import 'package:ffmpeg_kit_extended_flutter/src/generated/ffmpeg_kit_bindings_web.dart'
    as bindings;
import 'package:ffmpeg_kit_extended_flutter/src/platform/web/wasm_memory.dart';
import 'package:test/test.dart';

class _RecordingAllocator implements WasmAllocator {
  int _nextAddress = 16;
  final List<int> allocations = <int>[];
  final List<int> frees = <int>[];
  final List<String> strings = <String>[];
  int pointerWrites = 0;

  @override
  bindings.Pointer<T> allocate<T extends bindings.NativeType>(int bytes) {
    allocations.add(bytes);
    final pointer = bindings.Pointer<T>.fromAddress(_nextAddress);
    _nextAddress += 4;
    return pointer;
  }

  @override
  void free(bindings.Pointer pointer) => frees.add(pointer.address);

  @override
  void writeUtf8(bindings.Pointer<bindings.Char> pointer, List<int> bytes) {
    strings.add(String.fromCharCodes(bytes));
  }

  @override
  void writePointer(
    bindings.Pointer<bindings.PointerClass<bindings.Char>> array,
    int index,
    bindings.Pointer<bindings.Char> value,
  ) => pointerWrites++;
}

void main() {
  group('Web ownership', () {
    test('releases temporary UTF-8 input on success and error', () {
      final allocator = _RecordingAllocator();
      final memory = WasmMemory(allocator: allocator);

      memory.withUtf8('input', (_) => 7);
      expect(allocator.allocations, [6]);
      expect(allocator.frees, hasLength(1));

      expect(
        () => memory.withUtf8('failure', (_) => throw StateError('boom')),
        throwsStateError,
      );
      expect(allocator.frees, hasLength(2));
    });

    test('releases argv strings and block when command throws', () {
      final allocator = _RecordingAllocator();
      final memory = WasmMemory(allocator: allocator);

      expect(
        () => memory.withArguments(['-version', '-nostdin'], (_) {
          throw StateError('boom');
        }),
        throwsStateError,
      );
      expect(allocator.allocations, [8, 8, 8]);
      expect(allocator.frees, hasLength(3));
      expect(allocator.pointerWrites, 2);
    });
  });
}
