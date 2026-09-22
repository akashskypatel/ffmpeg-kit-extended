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
  int stopCalls = 0;
  int closeCalls = 0;
  int cancellationDispatches = 0;
  bool throwOnStop = false;
  bool throwOnClose = false;
  bool throwOnCancellation = false;
  final Completer<void> execution = Completer<void>();
  Completer<void>? startupCompleter;

  @override
  SessionState getState() => state;

  @override
  bool isPaused() => paused;

  @override
  void resume() {
    resumeCalls++;
    paused = false;
  }

  void submit() => claimExecutionSubmission();

  void markStartedForTest() => markExecutionStarted();

  @override
  void dispatchNativeCancellation() {
    cancellationDispatches++;
    if (throwOnCancellation) throw StateError('cancellation failed');
  }

  @override
  void stop() {
    stopCalls++;
    if (throwOnStop) throw StateError('stop failed');
  }

  @override
  void close() {
    closeCalls++;
    if (throwOnClose) throw StateError('close failed');
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

  @override
  Future<void>? get startupFutureForTracking => startupCompleter?.future;
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

  test('startup and terminal failures share one tracked observer', () async {
    final session = _FakeFFplaySession(SessionState.created);
    session.startupCompleter = Completer<void>();
    FFplayKit.setCurrentSessionForTest(session);
    FFplayKit.start();

    final startupError = StateError('startup failed');
    session.startupCompleter!.completeError(startupError);
    await Future<void>.value();
    expect(FFplayKit.currentSession, same(session));

    final terminalError = StateError('terminal failed');
    session.execution.completeError(terminalError);
    await Future<void>.value();
    await Future<void>.value();
    expect(FFplayKit.currentSession, isNull);
  });

  test('telemetry stream controllers remain reusable after last listener ends', () async {
    final session = _FakeFFplaySession(SessionState.created);
    final firstPosition = session.positionStream.listen((_) {});
    final firstVideoSize = session.videoSizeStream.listen((_) {});
    await firstPosition.cancel();
    await firstVideoSize.cancel();

    final secondPosition = session.positionStream.listen((_) {});
    final secondVideoSize = session.videoSizeStream.listen((_) {});
    await secondPosition.cancel();
    await secondVideoSize.cancel();
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

  test('cancellation is latched before a fallible FFplay stop', () {
    final session = _FakeFFplaySession(SessionState.created);
    session.submit();
    session.state = SessionState.running;
    session.markStartedForTest();
    session.throwOnStop = true;

    expect(session.cancel, throwsStateError);
    expect(session.isCancelled, isTrue);
    expect(session.cancellationDispatches, 1);
    expect(session.stopCalls, 1);
  });

  test('pre-start cancellation does not invoke FFplay stop', () {
    final session = _FakeFFplaySession(SessionState.created);
    session.submit();

    session.cancel();

    expect(session.isCancelled, isTrue);
    expect(session.stopCalls, 0);
    expect(session.cancellationDispatches, 0);
  });

  test('successful cancellation clears an untracked current session', () {
    final session = _FakeFFplaySession(SessionState.created);
    FFplayKit.setCurrentSessionForTest(session);

    FFplayKit.cancel(session);

    expect(FFplayKit.currentSession, isNull);
  });

  test(
    'tracked cancellation retains current ownership until settlement',
    () async {
      final session = _FakeFFplaySession(SessionState.created);
      FFplayKit.trackExecutionForTest(session, session.executeAsync);

      FFplayKit.cancel(session);
      expect(FFplayKit.currentSession, same(session));

      session.execution.complete();
      await Future<void>.delayed(Duration.zero);
      expect(FFplayKit.currentSession, isNull);
    },
  );

  test(
    'successful close clears current ownership but failed close does not',
    () {
      final session = _FakeFFplaySession(SessionState.created);
      FFplayKit.setCurrentSessionForTest(session);

      FFplayKit.close();
      expect(session.closeCalls, 1);
      expect(FFplayKit.currentSession, isNull);

      final failed = _FakeFFplaySession(SessionState.created);
      failed.throwOnClose = true;
      FFplayKit.setCurrentSessionForTest(failed);

      expect(FFplayKit.close, throwsStateError);
      expect(FFplayKit.currentSession, same(failed));
    },
  );
}
