import 'dart:async';

import 'package:ffmpeg_kit_extended_flutter/src/callback_manager.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffmpeg_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/backend.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/session_finalizer.dart';
import 'package:ffmpeg_kit_extended_flutter/src/session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/session_queue_manager.dart';
import 'package:test/test.dart';

class _RecordingFinalizer implements SessionFinalizer {
  int attaches = 0;
  int detaches = 0;

  @override
  void attach(Object owner, Object handle, {required Object detachToken}) {
    attaches++;
  }

  @override
  void detach(Object detachToken) => detaches++;
}

class _ReleasableSession extends Session {
  int releases = 0;

  _ReleasableSession({super.finalizer}) {
    handle = const SessionHandle(Object());
    sessionId = 100;
    command = 'test';
  }

  _ReleasableSession.noFinalizer() : super.noFinalizer() {
    handle = const SessionHandle(Object());
    sessionId = 101;
    command = 'test';
  }

  @override
  void releaseHandle(SessionHandle handle) => releases++;
}

void main() {
  final manager = CallbackManager();

  setUp(() {
    manager.ffmpegSessions.clear();
    manager.ffprobeSessions.clear();
    manager.ffplaySessions.clear();
    manager.mediaInformationSessions.clear();
    manager.globalFFmpegSessionCompleteCallback = null;
    manager.globalFFprobeSessionCompleteCallback = null;
    manager.globalFFplaySessionCompleteCallback = null;
    manager.globalMediaInformationSessionCompleteCallback = null;
    manager.globalLogCallback = null;
    manager.globalStatisticsCallback = null;
  });

  tearDown(() {
    manager.ffmpegSessions.clear();
    manager.ffprobeSessions.clear();
    manager.ffplaySessions.clear();
    manager.mediaInformationSessions.clear();
    manager.globalFFmpegSessionCompleteCallback = null;
    manager.globalFFprobeSessionCompleteCallback = null;
    manager.globalFFplaySessionCompleteCallback = null;
    manager.globalMediaInformationSessionCompleteCallback = null;
    manager.globalLogCallback = null;
    manager.globalStatisticsCallback = null;
  });

  group('Session lifetime', () {
    test(
      'disposes once, detaches finalizer, and rejects later handle queries',
      () {
        final finalizer = _RecordingFinalizer();
        final session = _ReleasableSession(finalizer: finalizer);
        session.registerFinalizer();

        session.dispose();
        session.dispose();

        expect(finalizer.attaches, 1);
        expect(finalizer.detaches, 1);
        expect(session.releases, 1);
        expect(session.isDisposed, isTrue);
        expect(() => session.handle, throwsStateError);
      },
    );
  });

  group('Callback isolation', () {
    test('continues to global callback when local callback throws', () {
      var localCalls = 0;
      var globalCalls = 0;
      FFmpegSession.test(
        sessionId: 200,
        completeCallback: (_) {
          localCalls++;
          throw StateError('local');
        },
      );
      manager.globalFFmpegSessionCompleteCallback = (_) {
        globalCalls++;
        throw StateError('global');
      };

      manager.dispatchFFmpegComplete(200);

      expect(localCalls, 1);
      expect(globalCalls, 1);
    });

    test('safe invocation does not stop queue continuation', () async {
      final events = <String>[];
      final first = _ReleasableSession.noFinalizer();
      final second = _ReleasableSession.noFinalizer();
      final queue = SessionQueueManager();

      await Future.wait([
        queue.executeSession(first, () async {
          CallbackManager().invokeSafely('test', 1, () {
            throw StateError('callback');
          });
          events.add('first');
        }),
        queue.executeSession(second, () async {
          events.add('second');
        }),
      ]);

      expect(events, ['first', 'second']);
    });
  });
}
