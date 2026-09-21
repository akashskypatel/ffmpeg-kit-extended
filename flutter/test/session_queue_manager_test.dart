import 'dart:async';

import 'package:ffmpeg_kit_extended_flutter/src/platform/backend.dart';
import 'package:ffmpeg_kit_extended_flutter/src/session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/session_queue_manager.dart';
import 'package:test/test.dart';

class _QueueSession extends Session {
  _QueueSession({this.throwOnDiscard = false}) : super.noFinalizer() {
    handle = const SessionHandle(Object());
    sessionId = _nextId++;
    command = 'test';
  }

  static int _nextId = 1;
  SessionState state = SessionState.created;
  bool throwOnDiscard;
  bool throwOnStateRead = false;
  int transientStateReadFailures = 0;
  int discarded = 0;
  int cancellationDispatches = 0;
  int cancelCalls = 0;
  bool throwOnCancel = false;

  void submit() => claimExecutionSubmission();

  @override
  SessionState executionStateForSubmission() {
    if (throwOnStateRead) throw StateError('state read failed');
    if (transientStateReadFailures > 0) {
      transientStateReadFailures--;
      throw StateError('transient state read failed');
    }
    return state;
  }

  @override
  void dispatchNativeCancellation() {
    cancellationDispatches++;
  }

  @override
  void cancel() {
    cancelCalls++;
    if (throwOnCancel) throw StateError('cancel failed for $sessionId');
    super.cancel();
  }

  @override
  void onCancelledBeforeStart() {
    discarded++;
    if (throwOnDiscard) throw StateError('discard cleanup failed');
  }
}

void main() {
  final queue = SessionQueueManager();

  setUp(() {
    queue.clearQueue();
    queue.maxConcurrentSessions = 1;
  });

  tearDown(() async {
    queue.clearQueue();
    await queue.waitForAll();
    queue.maxConcurrentSessions = 8;
  });

  test(
    'cancelQueued removes only the exact item and preserves later order',
    () async {
      final firstGate = Completer<void>();
      final first = _QueueSession();
      final second = _QueueSession();
      final third = _QueueSession();
      final events = <int>[];

      final firstFuture = queue.executeSession(first, () async {
        events.add(first.sessionId);
        await firstGate.future;
      });
      final secondFuture = queue.executeSession(second, () async {
        events.add(second.sessionId);
      });
      final thirdFuture = queue.executeSession(third, () async {
        events.add(third.sessionId);
      });

      second.cancel();
      await expectLater(
        secondFuture,
        throwsA(isA<SessionCancelledException>()),
      );

      firstGate.complete();
      await firstFuture;
      await thirdFuture;

      expect(events, [first.sessionId, third.sessionId]);
      expect(second.discarded, 1);
    },
  );

  test(
    'discard cleanup failure rejects only its Future and does not strand later work',
    () async {
      final firstGate = Completer<void>();
      final first = _QueueSession();
      final second = _QueueSession(throwOnDiscard: true);
      final third = _QueueSession();
      var thirdRan = false;

      final firstFuture = queue.executeSession(first, () async {
        await firstGate.future;
      });
      final secondFuture = queue.executeSession(second, () async {});
      final thirdFuture = queue.executeSession(third, () async {
        thirdRan = true;
      });

      second.cancel();
      await expectLater(secondFuture, throwsStateError);

      firstGate.complete();
      await firstFuture;
      await thirdFuture;
      expect(thirdRan, isTrue);
    },
  );

  test(
    'clearQueue cleans up every queued session and preserves cancellation intent',
    () async {
      final gate = Completer<void>();
      final first = _QueueSession();
      final second = _QueueSession();
      final third = _QueueSession();

      final firstFuture = queue.executeSession(first, () async {
        await gate.future;
      });
      final secondFuture = queue.executeSession(second, () async {});
      final thirdFuture = queue.executeSession(third, () async {});

      queue.clearQueue();
      await expectLater(
        secondFuture,
        throwsA(isA<SessionCancelledException>()),
      );
      await expectLater(thirdFuture, throwsA(isA<SessionCancelledException>()));
      expect(second.discarded, 1);
      expect(third.discarded, 1);
      expect(second.isCancelled, isTrue);
      expect(third.isCancelled, isTrue);

      gate.complete();
      await firstFuture;
    },
  );

  test('running cancellation is idempotent', () async {
    final gate = Completer<void>();
    final session = _QueueSession();
    session.submit();

    final future = queue.executeSession(session, () async {
      session.state = SessionState.running;
      await gate.future;
    });

    await Future<void>.delayed(Duration.zero);
    session.cancel();
    session.cancel();

    expect(session.cancellationDispatches, 1);
    gate.complete();
    await future;
  });

  test(
    'cancelCurrent attempts every active session and throws the first error',
    () async {
      queue.maxConcurrentSessions = 3;
      final gates = List.generate(3, (_) => Completer<void>());
      final sessions = List.generate(3, (_) => _QueueSession());
      sessions.first.throwOnCancel = true;
      sessions[2].throwOnCancel = true;
      final futures = <Future<void>>[];

      for (var i = 0; i < sessions.length; i++) {
        futures.add(queue.executeSession(sessions[i], () => gates[i].future));
      }

      expect(queue.cancelCurrent, throwsA(isA<StateError>()));
      expect(sessions.map((session) => session.cancelCalls), [1, 1, 1]);

      for (final gate in gates) {
        gate.complete();
      }
      await Future.wait(futures);
    },
  );

  test(
    'cancelCurrent succeeds after attempting all sessions when none fail',
    () async {
      queue.maxConcurrentSessions = 2;
      final firstGate = Completer<void>();
      final secondGate = Completer<void>();
      final first = _QueueSession();
      final second = _QueueSession();
      final firstFuture = queue.executeSession(first, () => firstGate.future);
      final secondFuture = queue.executeSession(
        second,
        () => secondGate.future,
      );

      queue.cancelCurrent();

      expect(first.cancelCalls, 1);
      expect(second.cancelCalls, 1);
      firstGate.complete();
      secondGate.complete();
      await Future.wait([firstFuture, secondFuture]);
    },
  );

  test(
    'cancelAll clears queued sessions and attempts every active session',
    () async {
      queue.maxConcurrentSessions = 2;
      final firstGate = Completer<void>();
      final secondGate = Completer<void>();
      final queued = _QueueSession();
      final first = _QueueSession()..throwOnCancel = true;
      final second = _QueueSession();
      final firstFuture = queue.executeSession(first, () => firstGate.future);
      final secondFuture = queue.executeSession(
        second,
        () => secondGate.future,
      );
      final queuedFuture = queue.executeSession(queued, () async {});

      expect(queue.cancelAll, throwsA(isA<StateError>()));
      expect(first.cancelCalls, 1);
      expect(second.cancelCalls, 1);
      await expectLater(
        queuedFuture,
        throwsA(isA<SessionCancelledException>()),
      );

      firstGate.complete();
      secondGate.complete();
      await Future.wait([firstFuture, secondFuture]);
    },
  );

  test(
    'duplicate admission rejects without changing the queue or discarding',
    () async {
      final gate = Completer<void>();
      final session = _QueueSession();
      var discardCalls = 0;
      final firstFuture = queue.executeSession(session, () => gate.future);
      final queueLengthBeforeDuplicate = queue.queueLength;

      final duplicateFuture = queue.executeSession(
        session,
        () async {},
        onDiscard: () => discardCalls++,
      );

      await expectLater(duplicateFuture, throwsStateError);
      expect(queue.queueLength, queueLengthBeforeDuplicate);
      expect(discardCalls, 0);
      expect(session.cancelCalls, 0);

      gate.complete();
      await firstFuture;
    },
  );

  test(
    'distinct session objects can still be admitted independently',
    () async {
      final gate = Completer<void>();
      final first = _QueueSession();
      final second = _QueueSession();
      queue.maxConcurrentSessions = 1;

      final firstFuture = queue.executeSession(first, () => gate.future);
      final secondFuture = queue.executeSession(second, () async {});

      expect(queue.queueLength, 1);
      gate.complete();
      await Future.wait([firstFuture, secondFuture]);
    },
  );

  test(
    'state-read failure retains cancellation intent without native dispatch',
    () async {
      final gate = Completer<void>();
      final session = _QueueSession();
      session.submit();
      session.throwOnStateRead = true;

      final future = queue.executeSession(session, () async {
        await gate.future;
      });

      await Future<void>.delayed(Duration.zero);
      expect(session.cancel, throwsStateError);
      expect(session.isCancelled, isTrue);
      expect(session.cancellationDispatches, 0);

      gate.complete();
      await future;
    },
  );

  test('state-read retry dispatches while execution is live', () async {
    final gate = Completer<void>();
    final session = _QueueSession();
    session.submit();
    session.state = SessionState.running;
    session.transientStateReadFailures = 1;

    final future = queue.executeSession(session, () async {
      await gate.future;
    });

    expect(session.cancel, throwsStateError);
    expect(session.cancellationDispatches, 1);

    gate.complete();
    await future;
  });

  test('state-read retry stops at execution settlement', () async {
    final gate = Completer<void>();
    final session = _QueueSession();
    session.submit();
    session.throwOnStateRead = true;

    final future = queue.executeSession(session, () async {
      await gate.future;
    });

    expect(session.cancel, throwsStateError);
    expect(session.cancellationDispatches, 0);

    gate.complete();
    await future;
    session.state = SessionState.running;
    expect(session.cancellationDispatches, 0);
  });

  test('startup cancellation waits for Running and dispatches once', () async {
    final gate = Completer<void>();
    final session = _QueueSession();
    session.submit();

    final future = queue.executeSession(session, () async {
      await gate.future;
    });

    await Future<void>.delayed(Duration.zero);
    session.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(session.cancellationDispatches, 0);

    session.state = SessionState.running;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(session.cancellationDispatches, 1);

    session.state = SessionState.completed;
    gate.complete();
    await future;
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(session.cancellationDispatches, 1);
  });

  test(
    'terminal state before startup does not dispatch native cancellation',
    () async {
      final session = _QueueSession();
      session.submit();
      session.state = SessionState.completed;

      final future = queue.executeSession(session, () async {});
      await Future<void>.delayed(Duration.zero);
      session.cancel();

      expect(session.cancellationDispatches, 0);
      await future;
    },
  );
}
