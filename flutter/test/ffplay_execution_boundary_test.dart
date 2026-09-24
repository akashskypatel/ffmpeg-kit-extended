import 'dart:async';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:ffmpeg_kit_extended_flutter/src/callback_manager.dart';
import 'package:test/test.dart';

class _AsyncBoundarySession extends FFplaySession {
  _AsyncBoundarySession({this.fail = false}) : super.test(sessionId: _nextId++);

  static int _nextId = 700;
  final bool fail;
  int playbackStartNotifications = 0;

  @override
  SessionState executionStateForSubmission() => SessionState.created;

  @override
  SessionState getState() => SessionState.created;

  @override
  void executeAsynchronously() {
    if (fail) throw StateError('async startup failed');
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
    final session = _AsyncBoundarySession();

    await session.executeAsync();

    expect(session.playbackStartNotifications, 1);
  });

  test('direct async startup failure does not commit playback identity', () async {
    final session = _AsyncBoundarySession(fail: true);

    await expectLater(session.executeAsync(), throwsStateError);

    expect(session.playbackStartNotifications, 0);
  });

  test('high-level start reuses the direct boundary without double commit', () async {
    final session = _AsyncBoundarySession();
    FFplayKit.setCurrentSessionForTest(session);

    FFplayKit.start();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(session.playbackStartNotifications, 1);
    expect(FFplayKit.currentSession, isNull);
  });
}
