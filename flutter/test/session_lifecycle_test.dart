import 'package:ffmpeg_kit_extended_flutter/src/platform/backend.dart';
import 'package:ffmpeg_kit_extended_flutter/src/session.dart';
import 'package:test/test.dart';

class _LifecycleSession extends Session {
  _LifecycleSession(this.state) : super.noFinalizer() {
    handle = const SessionHandle(Object());
    sessionId = 77;
    command = 'test';
  }

  SessionState state;
  int stateReads = 0;

  void claim() => claimExecutionSubmission();

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
  });
}

class _ThrowingStateSession extends _LifecycleSession {
  _ThrowingStateSession() : super(SessionState.created);

  @override
  SessionState executionStateForSubmission() => throw StateError('state read');
}
