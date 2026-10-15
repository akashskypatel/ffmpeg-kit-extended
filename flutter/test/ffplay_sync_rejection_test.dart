// W-F04 (plan §P3.0a item 3, AUTH-FFPLAY-SYNC granted by the owner on
// 2026-10-15): the synchronous FFplaySession.execute() is deprecated and
// always rejected before any backend call, on every platform.

import 'package:ffmpeg_kit_extended_flutter/src/callback_manager.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffplay_session.dart';
import 'package:test/test.dart';

void main() {
  final callbacks = CallbackManager();

  setUp(() {
    callbacks.ffplaySessions.clear();
    callbacks.globalFFplaySessionCompleteCallback = null;
  });

  tearDown(() {
    callbacks.ffplaySessions.clear();
    callbacks.globalFFplaySessionCompleteCallback = null;
  });

  // The library is deliberately not initialized here. A call that reached
  // initialization, registration or the backend would fail with a different
  // error, so an UnsupportedError proves the rejection came first.
  test('FFplaySession.execute throws UnsupportedError on every platform', () {
    final session = _ProbeFFplaySession(501);

    // ignore: deprecated_member_use
    expect(session.execute, throwsA(isA<UnsupportedError>()));
  });

  test('the rejection names the async replacement', () {
    final session = _ProbeFFplaySession(502);

    expect(
      // ignore: deprecated_member_use
      session.execute,
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          allOf(contains('FFplayKit.executeAsync'), contains('executeAsync()')),
        ),
      ),
    );
  });

  test('the rejected session is never registered or submitted', () {
    final session = _ProbeFFplaySession(503);

    // ignore: deprecated_member_use
    expect(session.execute, throwsA(isA<UnsupportedError>()));

    expect(callbacks.ffplaySessions.containsKey(503), isFalse);
    expect(session.started, isFalse);
  });

  test('the rejection is repeatable and leaves no state behind', () {
    final session = _ProbeFFplaySession(504);

    for (var attempt = 0; attempt < 3; attempt++) {
      // ignore: deprecated_member_use
      expect(session.execute, throwsA(isA<UnsupportedError>()));
    }

    expect(callbacks.ffplaySessions.containsKey(504), isFalse);
    expect(session.settled, isFalse);
  });
}

/// Exposes the protected execution flags to these assertions.
class _ProbeFFplaySession extends FFplaySession {
  _ProbeFFplaySession(int sessionId) : super.test(sessionId: sessionId);

  bool get started => hasExecutionStarted;

  bool get settled => hasExecutionSettled;
}
