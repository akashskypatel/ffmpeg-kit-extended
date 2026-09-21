import 'dart:async';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:ffmpeg_kit_extended_flutter/src/callback_manager.dart'
    as callback_manager;
import 'package:test/test.dart';

class _FakeFFplaySession extends FFplaySession {
  _FakeFFplaySession(this.state, {this.paused = false})
    : super.test(sessionId: _nextId++);

  static int _nextId = 1;
  SessionState state;
  bool paused;
  int executeCalls = 0;
  int resumeCalls = 0;
  final Completer<void> execution = Completer<void>();

  @override
  SessionState getState() => state;

  @override
  bool isPaused() => paused;

  @override
  void resume() {
    resumeCalls++;
    paused = false;
  }

  @override
  Future<FFplaySession> executeAsync({
    int? timeout,
    FFplaySessionCompleteCallback? completeCallback,
    callback_manager.FFmpegLogCallback? logCallback,
  }) async {
    executeCalls++;
    await execution.future;
    return this;
  }
}

void main() {
  tearDown(() {
    FFplayKit.setCurrentSessionForTest(null);
  });

  test(
    'currentSession remains until execution settles and then clears',
    () async {
      final session = _FakeFFplaySession(SessionState.created);
      FFplayKit.trackExecutionForTest(session, session.executeAsync);

      expect(FFplayKit.currentSession, same(session));
      session.execution.complete();
      await Future<void>.delayed(Duration.zero);
      expect(FFplayKit.currentSession, isNull);
    },
  );

  test('an older execution cannot clear a newer current session', () async {
    final older = _FakeFFplaySession(SessionState.created);
    final newer = _FakeFFplaySession(SessionState.created);
    FFplayKit.trackExecutionForTest(older, older.executeAsync);
    FFplayKit.trackExecutionForTest(newer, newer.executeAsync);

    older.execution.complete();
    await Future<void>.delayed(Duration.zero);
    expect(FFplayKit.currentSession, same(newer));

    newer.execution.complete();
    await Future<void>.delayed(Duration.zero);
    expect(FFplayKit.currentSession, isNull);
  });

  test('execution errors still settle active ownership', () async {
    final session = _FakeFFplaySession(SessionState.created);
    final error = StateError('transport failed');
    FFplayKit.trackExecutionForTest(session, () => Future<void>.error(error));

    await Future<void>.delayed(Duration.zero);
    expect(FFplayKit.currentSession, isNull);
  });

  test(
    'start submits Created once, resumes paused Running, and ignores terminal',
    () async {
      final created = _FakeFFplaySession(SessionState.created);
      FFplayKit.setCurrentSessionForTest(created);
      FFplayKit.start();
      FFplayKit.start();
      expect(created.executeCalls, 1);
      created.execution.complete();
      await Future<void>.delayed(Duration.zero);

      final paused = _FakeFFplaySession(SessionState.running, paused: true);
      FFplayKit.setCurrentSessionForTest(paused);
      FFplayKit.start();
      expect(paused.resumeCalls, 1);
      expect(paused.executeCalls, 0);

      final terminal = _FakeFFplaySession(SessionState.completed);
      FFplayKit.setCurrentSessionForTest(terminal);
      FFplayKit.start();
      expect(terminal.executeCalls, 0);
      expect(terminal.resumeCalls, 0);
    },
  );
}
