import 'dart:async';

import 'package:ffmpeg_kit_extended_flutter/src/platform/backend.dart';
import 'package:ffmpeg_kit_extended_flutter/src/session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/session_queue_manager.dart';
import 'package:test/test.dart';

class _LifecycleSession extends Session {
  _LifecycleSession(this.state) : super.noFinalizer() {
    handle = const SessionHandle(Object());
    sessionId = 77;
    command = 'test';
  }

  SessionState state;
  int stateReads = 0;
  Object? completeCallback;

  void claim() => claimExecutionSubmission();

  void execute({Object? callback}) {
    claim();
    if (callback != null) completeCallback = callback;
  }

  Future<void> executeAsync({Object? callback}) async {
    claim();
    if (callback != null) completeCallback = callback;
  }

  void settle() => markExecutionSettled();

  @override
  SessionState executionStateForSubmission() {
    stateReads++;
    return state;
  }
}

void main() {
  group('one-shot session submission', () {
    test('accepts Created once and rejects a second claim', () {
      final session = _LifecycleSession(SessionState.created);

      session.claim();

      expect(session.stateReads, 1);
      expect(session.claim, throwsStateError);
      expect(session.stateReads, 1);
    });

    for (final state in [
      SessionState.running,
      SessionState.completed,
      SessionState.failed,
    ]) {
      test('rejects a history/session handle in $state', () {
        final session = _LifecycleSession(state);

        expect(session.claim, throwsStateError);
        expect(session.stateReads, 1);
      });
    }

    test('does not claim when the state oracle fails', () {
      final session = _ThrowingStateSession();

      expect(session.claim, throwsStateError);
      expect(session.claim, throwsStateError);
    });

    test('rejects submission after cancellation before execution', () {
      final session = _LifecycleSession(SessionState.created);

      session.cancel();

      expect(session.claim, throwsA(isA<SessionCancelledException>()));
      expect(session.stateReads, 0);
    });

    test(
      'rejects executeAsync after execute without changing its callback',
      () {
        final session = _LifecycleSession(SessionState.created);
        final firstCallback = Object();
        final secondCallback = Object();

        session.execute(callback: firstCallback);

        expect(
          session.executeAsync(callback: secondCallback),
          throwsStateError,
        );
        expect(identical(session.completeCallback, firstCallback), isTrue);
      },
    );

    test(
      'rejects execute after executeAsync without changing its callback',
      () async {
        final session = _LifecycleSession(SessionState.created);
        final firstCallback = Object();
        final secondCallback = Object();

        await session.executeAsync(callback: firstCallback);

        expect(
          () => session.execute(callback: secondCallback),
          throwsStateError,
        );
        expect(identical(session.completeCallback, firstCallback), isTrue);
      },
    );

    test(
      'rejects a duplicate queued submission without a second queue item',
      () async {
        final queue = SessionQueueManager();
        final session = _LifecycleSession(SessionState.created);
        final gate = Completer<void>();
        final previousLimit = queue.maxConcurrentSessions;
        queue.maxConcurrentSessions = 1;

        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
          queue.clearQueue();
          queue.maxConcurrentSessions = previousLimit;
        });

        session.claim();
        final first = queue.executeSession(session, () => gate.future);
        await Future<void>.delayed(Duration.zero);

        expect(queue.activeSessionCount, 1);
        expect(queue.queueLength, 0);
        await expectLater(
          queue.executeSession(session, () async {}),
          throwsStateError,
        );
        expect(queue.queueLength, 0);

        gate.complete();
        await first;
      },
    );

    test('rejects concrete session re-execution after settlement', () {
      final session = _LifecycleSession(SessionState.created);

      session.claim();
      session.settle();

      expect(session.claim, throwsStateError);
    });
  });
}

class _ThrowingStateSession extends _LifecycleSession {
  _ThrowingStateSession() : super(SessionState.created);

  @override
  SessionState executionStateForSubmission() => throw StateError('state read');
}
