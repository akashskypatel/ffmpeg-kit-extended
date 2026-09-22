import 'package:ffmpeg_kit_extended_flutter/src/callback_manager.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffmpeg_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/log.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/callback_log_event.dart';
import 'package:test/test.dart';

class _RecordingFFmpegSession extends FFmpegSession {
  _RecordingFFmpegSession(int sessionId)
    : super.test(sessionId: sessionId, register: false);

  int historyCount = 0;
  int historyReads = 0;
  final List<Log> delivered = <Log>[];

  @override
  int getLogsCount() {
    historyReads++;
    return historyCount;
  }

  @override
  int getLogLevelAt(int index) => 100 + index;

  @override
  String getLogAt(int index) => 'history-$index';

  @override
  void onLogsDispatched(List<Log> batch) {
    delivered.addAll(batch);
  }
}

void main() {
  final manager = CallbackManager();

  setUp(manager.ffmpegSessions.clear);

  tearDown(manager.ffmpegSessions.clear);

  group('structured sequence-aware log delivery', () {
    test('delivers a contiguous event without reading session history', () {
      final session = _RecordingFFmpegSession(1);
      manager.registerFFmpegSession(session);

      manager.dispatchDirectLog(
        sessionId: 1,
        sequence: 0,
        level: 24,
        message: 'warning',
      );

      expect(session.historyReads, 0);
      expect(session.delivered, hasLength(1));
      expect(session.delivered.single.level, 24);
      expect(session.delivered.single.message, 'warning');
      expect(session.nextExpectedLogSequence, 1);
      expect(session.logsProcessed, 1);
    });

    test('ignores an older duplicate without dispatching it', () {
      final session = _RecordingFFmpegSession(2);
      manager.registerFFmpegSession(session);

      for (var attempt = 0; attempt < 2; attempt++) {
        manager.dispatchDirectLog(
          sessionId: 2,
          sequence: 0,
          level: 16,
          message: 'duplicate',
        );
      }

      expect(session.delivered, hasLength(1));
      expect(session.historyReads, 0);
      expect(session.nextExpectedLogSequence, 1);
    });

    test('reconciles only the missing history before a gap event', () {
      final session = _RecordingFFmpegSession(3)..historyCount = 2;
      manager.registerFFmpegSession(session);

      manager.dispatchDirectLog(
        sessionId: 3,
        sequence: 2,
        level: 32,
        message: 'direct-after-gap',
      );

      expect(session.historyReads, 1);
      expect(session.delivered.map((log) => log.message), <String>[
        'history-0',
        'history-1',
        'direct-after-gap',
      ]);
      expect(session.nextExpectedLogSequence, 3);
      expect(session.logsProcessed, 3);
    });

    test('drops an out-of-order event when the gap remains unresolved', () {
      final session = _RecordingFFmpegSession(6);
      manager.registerFFmpegSession(session);

      manager.dispatchDirectLog(
        sessionId: 6,
        sequence: 2,
        level: 32,
        message: 'out-of-order',
      );

      expect(session.historyReads, 1);
      expect(session.delivered, isEmpty);
      expect(session.nextExpectedLogSequence, 0);
      expect(session.logsProcessed, 0);
    });

    test('does not redeliver a direct event during completion flush', () {
      final session = _RecordingFFmpegSession(4)..historyCount = 1;
      manager.registerFFmpegSession(session);

      manager.dispatchDirectLog(
        sessionId: 4,
        sequence: 0,
        level: 8,
        message: 'terminal',
      );
      session.dispatchPendingLogs();

      expect(session.delivered.map((log) => log.message), <String>['terminal']);
      expect(session.historyReads, 1);
    });

    test('releases a decoded payload even when the session is unknown', () {
      var decodeCalls = 0;
      var releaseCalls = 0;

      consumeOwnedLogEvent<Object>(
        payload: Object(),
        isNull: false,
        decode: (_) {
          decodeCalls++;
          return 'unknown-session';
        },
        dispatch: (message) => manager.dispatchDirectLog(
          sessionId: 99,
          sequence: 0,
          level: 1,
          message: message,
        ),
        release: (_) => releaseCalls++,
      );

      expect(decodeCalls, 1);
      expect(releaseCalls, 1);
    });

    test('does not decode or release a null payload', () {
      var decodeCalls = 0;
      var releaseCalls = 0;
      String? dispatchedMessage = 'not-null';

      consumeOwnedLogEvent<Object>(
        payload: Object(),
        isNull: true,
        decode: (_) {
          decodeCalls++;
          return 'unexpected';
        },
        dispatch: (message) => dispatchedMessage = message,
        release: (_) => releaseCalls++,
      );

      expect(decodeCalls, 0);
      expect(releaseCalls, 0);
      expect(dispatchedMessage, isNull);
    });

    test(
      'releases duplicate payloads independently while dispatching once',
      () {
        final session = _RecordingFFmpegSession(5);
        manager.registerFFmpegSession(session);
        var releaseCalls = 0;

        for (var attempt = 0; attempt < 2; attempt++) {
          consumeOwnedLogEvent<Object>(
            payload: Object(),
            isNull: false,
            decode: (_) => 'duplicate',
            dispatch: (message) => manager.dispatchDirectLog(
              sessionId: 5,
              sequence: 0,
              level: 4,
              message: message,
            ),
            release: (_) => releaseCalls++,
          );
        }

        expect(session.delivered, hasLength(1));
        expect(releaseCalls, 2);
      },
    );

    test('keeps a dispatch error primary when release also fails', () {
      final primary = StateError('dispatch failed');
      final cleanup = StateError('release failed');
      var releaseCalls = 0;

      expect(
        () => consumeOwnedLogEvent<Object>(
          payload: Object(),
          isNull: false,
          decode: (_) => 'message',
          dispatch: (_) => throw primary,
          release: (_) {
            releaseCalls++;
            throw cleanup;
          },
        ),
        throwsA(same(primary)),
      );
      expect(releaseCalls, 1);
    });

    test('surfaces a release error when no primary callback error exists', () {
      final cleanup = StateError('release failed');

      expect(
        () => consumeOwnedLogEvent<Object>(
          payload: Object(),
          isNull: false,
          decode: (_) => 'message',
          dispatch: (_) {},
          release: (_) => throw cleanup,
        ),
        throwsA(same(cleanup)),
      );
    });
  });
}
