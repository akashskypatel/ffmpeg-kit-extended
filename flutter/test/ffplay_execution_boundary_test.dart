import 'dart:async';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:ffmpeg_kit_extended_flutter/src/callback_manager.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/backend.dart'
    show SessionHandle;
import 'package:test/test.dart';

class _AsyncBoundarySession extends FFplaySession {
  _AsyncBoundarySession({
    this.fail = false,
    FFplaySessionCompleteCallback? completeCallback,
  }) : super.test(sessionId: _nextId++, completeCallback: completeCallback);

  static int _nextId = 700;
  final bool fail;
  bool terminalHistoryCommitted = false;
  SessionState observedState = SessionState.created;
  int playbackStartNotifications = 0;
  int releases = 0;

  @override
  SessionState executionStateForSubmission() => SessionState.created;

  @override
  SessionState getState() => observedState;

  @override
  void releaseHandle(SessionHandle handle) => releases++;

  @override
  void commitTerminalHistory() {
    terminalHistoryCommitted = true;
  }

  @override
  void executeAsynchronously() {
    if (fail) throw StateError('async startup failed');
    observedState = SessionState.completed;
    CallbackManager().dispatchFFplayComplete(sessionId);
  }

  @override
  void notifyPlaybackStarted() {
    playbackStartNotifications++;
  }
}

void main() {
  setUpAll(FFmpegKitExtended.initialize);

  tearDown(() {
    FFplayKit.setCurrentSessionForTest(null);
  });

  test('direct async execution commits playback identity once', () async {
    late final _AsyncBoundarySession session;
    var globalCallbackCalls = 0;
    CallbackManager().globalFFplaySessionCompleteCallback = (completed) {
      globalCallbackCalls++;
      expect(completed.isDisposed, isFalse);
    };
    addTearDown(
      () => CallbackManager().globalFFplaySessionCompleteCallback = null,
    );
    session = _AsyncBoundarySession(
      completeCallback: (completed) {
        expect(
          (completed as _AsyncBoundarySession).terminalHistoryCommitted,
          isTrue,
        );
        completed.dispose();
        expect(completed.isDisposed, isFalse);
      },
    );
    FFmpegKitExtended.registerCreatedSession(session);

    await session.executeAsync();

    expect(session.playbackStartNotifications, 1);
    expect(session.terminalHistoryCommitted, isTrue);
    expect(globalCallbackCalls, 1);
    expect(session.releases, 1);
    expect(session.isDisposed, isTrue);
  });

  test(
    'direct async startup failure does not commit playback identity',
    () async {
      final session = _AsyncBoundarySession(fail: true);

      await expectLater(session.executeAsync(), throwsStateError);

      expect(session.playbackStartNotifications, 0);
    },
  );

  test(
    'high-level start reuses the direct boundary without double commit',
    () async {
      final session = _AsyncBoundarySession();
      FFplayKit.setCurrentSessionForTest(session);

      FFplayKit.start();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(session.playbackStartNotifications, 1);
      expect(FFplayKit.currentSession, isNull);
    },
  );
}
