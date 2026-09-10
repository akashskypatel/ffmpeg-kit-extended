import 'dart:async';

import 'package:ffmpeg_kit_extended_flutter/src/platform/backend.dart';
import 'package:ffmpeg_kit_extended_flutter/src/session.dart';
import 'package:test/test.dart';

class _TestSession extends Session {
  _TestSession() : super.noFinalizer() {
    handle = const SessionHandle(Object());
    sessionId = 17;
    command = 'test';
  }

  void track(Completer<void> completer) => trackExecution(completer);

  void onExecutionError(SessionExecutionErrorCallback callback) {
    registerExecutionErrorHandler(callback);
  }

  void completeWithError(
    Completer<void> completer,
    Object error,
    StackTrace stackTrace,
  ) {
    completeExecutionWithError(
      completer: completer,
      error: error,
      stackTrace: stackTrace,
      cleanup: () => throw StateError('cleanup failed'),
    );
  }
}

void main() {
  test('dispatches the polling error to the active execution', () async {
    final session = _TestSession();
    final completer = Completer<void>();
    final error = StateError('poll failed');
    final stackTrace = StackTrace.current;
    var dispatchCount = 0;

    session.track(completer);
    session.onExecutionError((receivedError, receivedStackTrace) {
      dispatchCount++;
      expect(receivedError, same(error));
      expect(receivedStackTrace, same(stackTrace));
      completer.completeError(receivedError, receivedStackTrace);
    });

    session.dispatchExecutionError(error, stackTrace);

    await expectLater(completer.future, throwsA(same(error)));
    expect(dispatchCount, 1);
  });

  test('falls back to tracked executions when no handler is installed', () async {
    final session = _TestSession();
    final completer = Completer<void>();
    final error = StateError('missing handler');
    final stackTrace = StackTrace.current;

    session.track(completer);
    session.dispatchExecutionError(error, stackTrace);

    await expectLater(completer.future, throwsA(same(error)));
  });

  test('preserves the original error when cleanup fails', () async {
    final session = _TestSession();
    final completer = Completer<void>();
    final error = StateError('transport failed');
    final stackTrace = StackTrace.current;

    session.completeWithError(completer, error, stackTrace);

    await expectLater(completer.future, throwsA(same(error)));
  });
}
