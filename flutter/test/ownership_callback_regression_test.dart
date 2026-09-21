import 'dart:async';

import 'package:ffmpeg_kit_extended_flutter/src/callback_manager.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffmpeg_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffplay_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffprobe_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/media_information_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/backend.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/session_finalizer.dart';
import 'package:ffmpeg_kit_extended_flutter/src/session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/session_queue_manager.dart';
import 'package:test/test.dart';

class _RecordingFinalizer implements SessionFinalizer {
  int attaches = 0;
  int detaches = 0;
  final List<String>? events;

  _RecordingFinalizer({this.events});

  @override
  void attach(Object owner, Object handle, {required Object detachToken}) {
    attaches++;
    events?.add('attach');
  }

  @override
  void detach(Object detachToken) {
    detaches++;
    events?.add('detach');
  }
}

class _ReleasableSession extends Session {
  int releases = 0;
  bool throwOnRelease = false;
  final List<String>? events;

  _ReleasableSession({super.finalizer, this.events}) {
    handle = const SessionHandle(Object());
    sessionId = 100;
    command = 'test';
  }

  _ReleasableSession.noFinalizer() : events = null, super.noFinalizer() {
    handle = const SessionHandle(Object());
    sessionId = 101;
    command = 'test';
  }

  @override
  void releaseHandle(SessionHandle handle) {
    releases++;
    events?.add('release');
    if (throwOnRelease) throw StateError('release failed');
  }
}

class _CleanupFailingSession extends _ReleasableSession {
  _CleanupFailingSession({super.finalizer}) : super();

  @override
  void onDispose() => throw StateError('cleanup failed');
}

class _NoopFFmpegSession extends FFmpegSession {
  _NoopFFmpegSession(int sessionId)
    : super.test(sessionId: sessionId, register: false);

  @override
  void dispatchPendingLogs() {}
}

class _NoopFFprobeSession extends FFprobeSession {
  _NoopFFprobeSession(int sessionId) : super.test(sessionId: sessionId);

  @override
  void dispatchPendingLogs() {}
}

class _NoopFFplaySession extends FFplaySession {
  _NoopFFplaySession(int sessionId) : super.test(sessionId: sessionId);

  @override
  void dispatchPendingLogs() {}
}

class _NoopMediaInformationSession extends MediaInformationSession {
  _NoopMediaInformationSession(int sessionId)
    : super.test(sessionId: sessionId);

  @override
  void dispatchPendingLogs() {}
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

    test('keeps ownership retryable when native release fails', () {
      final events = <String>[];
      final finalizer = _RecordingFinalizer(events: events);
      final session = _ReleasableSession(finalizer: finalizer, events: events);
      session.registerFinalizer();
      session.throwOnRelease = true;

      expect(session.dispose, throwsStateError);
      expect(session.isDisposed, isFalse);
      expect(finalizer.detaches, 0);
      expect(() => session.handle, returnsNormally);
      expect(session.releases, 1);

      session.throwOnRelease = false;
      session.dispose();
      session.dispose();

      expect(session.isDisposed, isTrue);
      expect(session.releases, 2);
      expect(finalizer.detaches, 1);
      expect(events, ['attach', 'release', 'release', 'detach']);
    });

    test('commits disposal when post-release cleanup fails', () {
      final finalizer = _RecordingFinalizer();
      final session = _CleanupFailingSession(finalizer: finalizer);
      session.registerFinalizer();

      expect(session.dispose, throwsStateError);
      expect(session.isDisposed, isTrue);
      expect(session.releases, 1);
      expect(finalizer.detaches, 1);

      session.dispose();
      expect(session.releases, 1);
      expect(finalizer.detaches, 1);
    });
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

  group('Lazy callback registration', () {
    test('fresh sessions with no sinks are not retained', () {
      final sessions = <Session>[
        _NoopFFmpegSession(300),
        _NoopFFprobeSession(301),
        _NoopFFplaySession(302),
        _NoopMediaInformationSession(303),
      ];

      expect(sessions, hasLength(4));
      expect(manager.ffmpegSessions, isNot(contains(300)));
      expect(manager.ffprobeSessions, isNot(contains(301)));
      expect(manager.ffplaySessions, isNot(contains(302)));
      expect(manager.mediaInformationSessions, isNot(contains(303)));
      expect(manager.ffprobeSessions, isNot(contains(303)));
    });

    test('callbacks register the owning session', () {
      final ffmpeg = _NoopFFmpegSession(310);
      final ffprobe = _NoopFFprobeSession(311);
      final ffplay = _NoopFFplaySession(312);
      final mediaInfo = _NoopMediaInformationSession(313);

      ffmpeg.setCompleteCallback((_) {});
      ffprobe.setCompleteCallback((_) {});
      ffplay.setCompleteCallback((_) {});
      mediaInfo.setMediaInfoCompleteCallback((_) {});

      expect(manager.ffmpegSessions, contains(310));
      expect(manager.ffprobeSessions, contains(311));
      expect(manager.ffplaySessions, contains(312));
      expect(manager.mediaInformationSessions, contains(313));
      expect(manager.ffprobeSessions, contains(313));
    });

    test('null callback setters do not create registrations', () {
      final ffmpeg = _NoopFFmpegSession(320);
      final ffprobe = _NoopFFprobeSession(321);
      final ffplay = _NoopFFplaySession(322);
      final mediaInfo = _NoopMediaInformationSession(323);

      ffmpeg.setCompleteCallback(null);
      ffmpeg.setLogCallback(null);
      ffmpeg.setStatisticsCallback(null);
      ffprobe.setCompleteCallback(null);
      ffprobe.setLogCallback(null);
      ffplay.setCompleteCallback(null);
      ffplay.setLogCallback(null);
      mediaInfo.setMediaInfoCompleteCallback(null);

      expect(manager.ffmpegSessions, isNot(contains(320)));
      expect(manager.ffprobeSessions, isNot(contains(321)));
      expect(manager.ffplaySessions, isNot(contains(322)));
      expect(manager.mediaInformationSessions, isNot(contains(323)));
      expect(manager.ffprobeSessions, isNot(contains(323)));
    });

    test('clearing the last callback unregisters each session', () {
      final ffmpeg = _NoopFFmpegSession(330);
      final ffprobe = _NoopFFprobeSession(331);
      final ffplay = _NoopFFplaySession(332);
      final mediaInfo = _NoopMediaInformationSession(333);

      ffmpeg.setLogCallback((_) {});
      ffprobe.setLogCallback((_) {});
      ffplay.setLogCallback((_) {});
      mediaInfo.setMediaInfoCompleteCallback((_) {});

      ffmpeg.removeLogCallback();
      ffprobe.removeLogCallback();
      ffplay.removeLogCallback();
      mediaInfo.removeMediaInfoCompleteCallback();

      expect(manager.ffmpegSessions, isNot(contains(330)));
      expect(manager.ffprobeSessions, isNot(contains(331)));
      expect(manager.ffplaySessions, isNot(contains(332)));
      expect(manager.mediaInformationSessions, isNot(contains(333)));
      expect(manager.ffprobeSessions, isNot(contains(333)));
    });

    test('log stream listeners register before the first drain', () async {
      final ffmpeg = _NoopFFmpegSession(340);
      final ffprobe = _NoopFFprobeSession(341);
      final ffplay = _NoopFFplaySession(342);
      final mediaInfo = _NoopMediaInformationSession(343);

      final subscriptions = [
        ffmpeg.logBatchStream.listen((_) {}),
        ffprobe.logBatchStream.listen((_) {}),
        ffplay.logBatchStream.listen((_) {}),
        mediaInfo.logBatchStream.listen((_) {}),
      ];

      expect(manager.ffmpegSessions, contains(340));
      expect(manager.ffprobeSessions, contains(341));
      expect(manager.ffplaySessions, contains(342));
      expect(manager.mediaInformationSessions, contains(343));
      expect(manager.ffprobeSessions, contains(343));

      await Future.wait(
        subscriptions.map((subscription) => subscription.cancel()),
      );
      ffmpeg.removeLogCallback();
      ffprobe.removeLogCallback();
      ffplay.removeLogCallback();
      mediaInfo.removeMediaInfoCompleteCallback();
    });
  });
}
