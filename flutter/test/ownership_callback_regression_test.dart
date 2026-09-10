import 'dart:async';

import 'package:ffmpeg_kit_extended_flutter/src/callback_manager.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffmpeg_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/generated/ffmpeg_kit_bindings_web.dart'
    as bindings;
import 'package:ffmpeg_kit_extended_flutter/src/platform/backend.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/session_finalizer.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/web/session_poller.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/web/wasm_memory.dart';
import 'package:ffmpeg_kit_extended_flutter/src/session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/session_queue_manager.dart';
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

class _RecordingFinalizer implements SessionFinalizer {
  int attaches = 0;
  int detaches = 0;

  @override
  void attach(Object owner, Object handle, {required Object detachToken}) {
    attaches++;
  }

  @override
  void detach(Object detachToken) => detaches++;
}

class _ReleasableSession extends Session {
  int releases = 0;

  _ReleasableSession({super.finalizer}) {
    handle = const SessionHandle(Object());
    sessionId = 100;
    command = 'test';
  }

  _ReleasableSession.noFinalizer() : super.noFinalizer() {
    handle = const SessionHandle(Object());
    sessionId = 101;
    command = 'test';
  }

  @override
  void releaseHandle(SessionHandle handle) => releases++;
}

void main() {
  final manager = CallbackManager();

  setUp(() {
    manager.ffmpegSessions.clear();
    manager.ffprobeSessions.clear();
    manager.ffplaySessions.clear();
    manager.mediaInformationSessions.clear();
    manager.globalFFmpegSessionCompleteCallback = null;
    manager.globalFFprobeSessionCompleteCallback = null;
    manager.globalFFplaySessionCompleteCallback = null;
    manager.globalMediaInformationSessionCompleteCallback = null;
    manager.globalLogCallback = null;
    manager.globalStatisticsCallback = null;
  });

  tearDown(() {
    manager.ffmpegSessions.clear();
    manager.ffprobeSessions.clear();
    manager.ffplaySessions.clear();
    manager.mediaInformationSessions.clear();
    manager.globalFFmpegSessionCompleteCallback = null;
    manager.globalFFprobeSessionCompleteCallback = null;
    manager.globalFFplaySessionCompleteCallback = null;
    manager.globalMediaInformationSessionCompleteCallback = null;
    manager.globalLogCallback = null;
    manager.globalStatisticsCallback = null;
  });

  group('Wasm ownership', () {
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

  group('Session lifetime', () {
    test(
      'disposes once, detaches finalizer, and rejects later handle queries',
      () {
        final finalizer = _RecordingFinalizer();
        final session = _ReleasableSession(finalizer: finalizer);
        session.registerFinalizer();

        session.dispose();
        session.dispose();

        expect(finalizer.attaches, 1);
        expect(finalizer.detaches, 1);
        expect(session.releases, 1);
        expect(session.isDisposed, isTrue);
        expect(() => session.handle, throwsStateError);
      },
    );
  });

  group('Callback isolation', () {
    test('continues to global callback when local callback throws', () {
      var localCalls = 0;
      var globalCalls = 0;
      FFmpegSession.test(
        sessionId: 200,
        completeCallback: (_) {
          localCalls++;
          throw StateError('local');
        },
      );
      manager.globalFFmpegSessionCompleteCallback = (_) {
        globalCalls++;
        throw StateError('global');
      };

      manager.dispatchFFmpegComplete(200);

      expect(localCalls, 1);
      expect(globalCalls, 1);
    });

    test('safe invocation does not stop queue continuation', () async {
      final events = <String>[];
      final first = _ReleasableSession.noFinalizer();
      final second = _ReleasableSession.noFinalizer();
      final queue = SessionQueueManager();

      await Future.wait([
        queue.executeSession(first, () async {
          CallbackManager().invokeSafely('test', 1, () {
            throw StateError('callback');
          });
          events.add('first');
        }),
        queue.executeSession(second, () async {
          events.add('second');
        }),
      ]);

      expect(events, ['first', 'second']);
    });
  });

  group('Web polling', () {
    test('completes once after terminal state and final drain', () async {
      var stateReads = 0;
      var logCalls = 0;
      var statisticsCalls = 0;
      var completions = 0;

      await pollSessionUntilTerminal(
        getState: () => ++stateReads == 3 ? 2 : 1,
        dispatchLogs: () => logCalls++,
        dispatchStatistics: () => statisticsCalls++,
        onComplete: () => completions++,
        interval: Duration.zero,
      );

      expect(completions, 1);
      expect(logCalls, 4);
      expect(statisticsCalls, 4);
    });

    test('cleans the poll registry after success and failure', () async {
      final registry = SessionPollRegistry();
      var runs = 0;
      await registry.run(300, () async {
        runs++;
      });
      expect(runs, 1);
      expect(registry.contains(300), isFalse);

      final failure = registry.run(
        301,
        () async => throw StateError('poll failure'),
      );
      await expectLater(failure, throwsStateError);
      expect(registry.contains(301), isFalse);

      final first = registry.run(302, () async {
        await Future<void>.delayed(Duration.zero);
      });
      final second = registry.run(302, () async {
        runs++;
      });
      await Future.wait([first, second]);
      expect(runs, 1);
    });

    test('stops polling when the state becomes terminal', () async {
      var reads = 0;
      var completions = 0;

      await pollSessionUntilTerminal(
        getState: () => ++reads == 2 ? 2 : 1,
        dispatchLogs: () {},
        dispatchStatistics: () {},
        onComplete: () => completions++,
        interval: Duration.zero,
      );

      expect(reads, 2);
      expect(completions, 1);
    });

    test('propagates state, log, and statistics failures', () async {
      int throwState() => throw StateError('state');
      for (final failure in ['state', 'logs', 'statistics']) {
        final future = pollSessionUntilTerminal(
          getState: failure == 'state' ? throwState : () => 2,
          dispatchLogs: failure == 'logs'
              ? () => throw StateError('logs')
              : () {},
          dispatchStatistics: failure == 'statistics'
              ? () => throw StateError('statistics')
              : () {},
          onComplete: () {},
          interval: Duration.zero,
        );
        await expectLater(future, throwsStateError);
      }
    });
  });
}
