import 'dart:async';
import 'dart:ffi';

import 'package:ffmpeg_kit_extended_flutter/src/callback_manager.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffmpeg_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffplay_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffprobe_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/media_information_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/backend.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/native/backend_native.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/native/ffmpeg_kit_extended_flutter_loader.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/native/session_finalizer_native.dart';
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

  void adoptOwned(
    SessionHandle handle, {
    required int Function(SessionHandle) readSessionId,
    void Function()? onBeforeCommit,
  }) {
    adoptOwnedHandle(
      handle,
      readSessionId: readSessionId,
      onBeforeCommit: onBeforeCommit,
    );
  }
}

class _ThrowingFinalizer implements SessionFinalizer {
  final StateError failure = StateError('finalizer attach failed');

  @override
  void attach(Object owner, Object handle, {required Object detachToken}) {
    throw failure;
  }

  @override
  void detach(Object detachToken) {}
}

class _CleanupFailingSession extends _ReleasableSession {
  _CleanupFailingSession({super.finalizer}) : super();

  @override
  void onDispose() => throw StateError('cleanup failed');
}

class _NoopFFmpegSession extends FFmpegSession {
  SessionState restoredState = SessionState.created;
  bool throwOnStateRead = false;

  _NoopFFmpegSession(int sessionId)
    : super.test(sessionId: sessionId, register: false);

  @override
  void dispatchPendingLogs() {}

  @override
  SessionState executionStateForSubmission() {
    if (throwOnStateRead) throw StateError('state read failed');
    return restoredState;
  }

  void submitForTest() => claimExecutionSubmission();

  void settleForTest() => markExecutionSettled();

  void restoreForTest(SessionState state) {
    restoredState = state;
    adoptOwnedHandle(
      const SessionHandle(Object()),
      readSessionId: (_) => sessionId,
      restoredSession: true,
    );
  }
}

class _NoopFFprobeSession extends FFprobeSession {
  SessionState restoredState = SessionState.created;
  bool throwOnStateRead = false;

  _NoopFFprobeSession(int sessionId) : super.test(sessionId: sessionId);

  @override
  void dispatchPendingLogs() {}

  @override
  SessionState executionStateForSubmission() {
    if (throwOnStateRead) throw StateError('state read failed');
    return restoredState;
  }

  void submitForTest() => claimExecutionSubmission();

  void settleForTest() => markExecutionSettled();

  void restoreForTest(SessionState state) {
    restoredState = state;
    adoptOwnedHandle(
      const SessionHandle(Object()),
      readSessionId: (_) => sessionId,
      restoredSession: true,
    );
  }
}

class _NoopFFplaySession extends FFplaySession {
  SessionState restoredState = SessionState.created;
  bool throwOnStateRead = false;

  _NoopFFplaySession(int sessionId) : super.test(sessionId: sessionId);

  @override
  void dispatchPendingLogs() {}

  @override
  SessionState executionStateForSubmission() {
    if (throwOnStateRead) throw StateError('state read failed');
    return restoredState;
  }

  void submitForTest() => claimExecutionSubmission();

  void settleForTest() => markExecutionSettled();

  void restoreForTest(SessionState state) {
    restoredState = state;
    adoptOwnedHandle(
      const SessionHandle(Object()),
      readSessionId: (_) => sessionId,
      restoredSession: true,
    );
  }
}

class _NoopMediaInformationSession extends MediaInformationSession {
  SessionState restoredState = SessionState.created;
  bool throwOnStateRead = false;

  _NoopMediaInformationSession(int sessionId)
    : super.test(sessionId: sessionId);

  @override
  void registerFinalizer() {}

  @override
  void dispatchPendingLogs() {}

  @override
  SessionState executionStateForSubmission() {
    if (throwOnStateRead) throw StateError('state read failed');
    return restoredState;
  }

  void submitForTest() => claimExecutionSubmission();

  void settleForTest() => markExecutionSettled();

  void restoreForTest(SessionState state) {
    restoredState = state;
    adoptOwnedHandle(
      const SessionHandle(Object()),
      readSessionId: (_) => sessionId,
      restoredSession: true,
    );
  }
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
    test('native session factories reject null handles', () {
      expect(
        () => requireNativeSessionHandle(
          Pointer<Void>.fromAddress(0),
          'test_create_session',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('test_create_session returned a null session handle'),
          ),
        ),
      );

      final handle = requireNativeSessionHandle(
        Pointer<Void>.fromAddress(1),
        'test_create_session',
      );
      expect((handle.value as Pointer<Void>).address, 1);
    });

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

  group('Owned handle adoption', () {
    test('session-ID failure releases the newly acquired handle once', () {
      final finalizer = _RecordingFinalizer();
      final session = _ReleasableSession(finalizer: finalizer);
      final failure = StateError('session ID failed');

      expect(
        () => session.adoptOwned(
          const SessionHandle('owned-id-failure'),
          readSessionId: (_) => throw failure,
        ),
        throwsA(same(failure)),
      );

      expect(session.releases, 1);
      expect(finalizer.attaches, 0);
    });

    test('finalizer attachment failure rolls back the handle once', () {
      final finalizer = _ThrowingFinalizer();
      final session = _ReleasableSession(finalizer: finalizer);

      expect(
        () => session.adoptOwned(
          const SessionHandle('owned-finalizer-failure'),
          readSessionId: (_) => 410,
        ),
        throwsA(same(finalizer.failure)),
      );

      expect(session.releases, 1);
    });

    test('rollback release failure does not replace the primary error', () {
      final session = _ReleasableSession()..throwOnRelease = true;
      final failure = StateError('primary adoption failure');

      expect(
        () => session.adoptOwned(
          const SessionHandle('owned-rollback-failure'),
          readSessionId: (_) => throw failure,
        ),
        throwsA(same(failure)),
      );

      expect(session.releases, 1);
    });

    test('successful adoption transfers release authority to dispose', () {
      final finalizer = _RecordingFinalizer();
      final session = _ReleasableSession(finalizer: finalizer);

      session.adoptOwned(
        const SessionHandle('owned-success'),
        readSessionId: (_) => 411,
      );

      expect(session.sessionId, 411);
      expect(session.releases, 0);
      expect(finalizer.attaches, 1);

      session.dispose();
      session.dispose();

      expect(session.releases, 1);
      expect(finalizer.detaches, 1);
    });

    test(
      'native finalizer fails closed when release symbol is unavailable',
      () {
        final previousPointer = ffmpegKitHandleReleasePtr;
        ffmpegKitHandleReleasePtr = null;
        try {
          final finalizer = NativeSessionFinalizer();
          expect(
            () => finalizer.attach(
              Object(),
              Pointer<Void>.fromAddress(1),
              detachToken: Object(),
            ),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                contains('handle-release symbol'),
              ),
            ),
          );
        } finally {
          ffmpegKitHandleReleasePtr = previousPointer;
        }
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

    test('Created callbacks retain values without a callback-manager root', () {
      final ffmpeg = _NoopFFmpegSession(310);
      final ffprobe = _NoopFFprobeSession(311);
      final ffplay = _NoopFFplaySession(312);
      final mediaInfo = _NoopMediaInformationSession(313);

      ffmpeg.setCompleteCallback((_) {});
      ffprobe.setCompleteCallback((_) {});
      ffplay.setCompleteCallback((_) {});
      mediaInfo.setMediaInfoCompleteCallback((_) {});

      expect(ffmpeg.completeCallback, isNotNull);
      expect(ffprobe.completeCallback, isNotNull);
      expect(ffplay.completeCallback, isNotNull);
      expect(mediaInfo.mediaInfoCompleteCallback, isNotNull);
      expect(manager.ffmpegSessions, isNot(contains(310)));
      expect(manager.ffprobeSessions, isNot(contains(311)));
      expect(manager.ffplaySessions, isNot(contains(312)));
      expect(manager.mediaInformationSessions, isNot(contains(313)));
      expect(manager.ffprobeSessions, isNot(contains(313)));

      ffmpeg.submitForTest();
      ffprobe.submitForTest();
      ffplay.submitForTest();
      mediaInfo.submitForTest();
      ffmpeg.setCompleteCallback(ffmpeg.completeCallback);
      ffprobe.setCompleteCallback(ffprobe.completeCallback);
      ffplay.setCompleteCallback(ffplay.completeCallback);
      mediaInfo.setMediaInfoCompleteCallback(
        mediaInfo.mediaInfoCompleteCallback,
      );

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

    test('restored routing is state-aware and rolls back failed reads', () {
      final ffmpeg = _NoopFFmpegSession(325);
      final ffprobe = _NoopFFprobeSession(326);
      final ffplay = _NoopFFplaySession(327);
      final mediaInfo = _NoopMediaInformationSession(328);

      ffmpeg.restoreForTest(SessionState.running);
      ffprobe.restoreForTest(SessionState.running);
      ffplay.restoreForTest(SessionState.running);
      mediaInfo.restoreForTest(SessionState.running);
      ffmpeg.setCompleteCallback((_) {});
      ffprobe.setCompleteCallback((_) {});
      ffplay.setCompleteCallback((_) {});
      mediaInfo.setMediaInfoCompleteCallback((_) {});

      expect(manager.ffmpegSessions, contains(325));
      expect(manager.ffprobeSessions, contains(326));
      expect(manager.ffplaySessions, contains(327));
      expect(manager.mediaInformationSessions, contains(328));
      expect(manager.ffprobeSessions, contains(328));

      final terminal = _NoopFFmpegSession(329);
      terminal.restoreForTest(SessionState.completed);
      terminal.setCompleteCallback((_) {});
      expect(manager.ffmpegSessions, isNot(contains(329)));

      final failedRead = _NoopFFmpegSession(330);
      failedRead.restoreForTest(SessionState.running);
      failedRead.throwOnStateRead = true;
      expect(
        () => failedRead.setCompleteCallback((_) {}),
        throwsA(isA<StateError>()),
      );
      expect(failedRead.completeCallback, isNull);
      expect(manager.ffmpegSessions, isNot(contains(330)));
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

    test(
      'Created log listeners do not retain sessions before execution',
      () async {
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

        expect(manager.ffmpegSessions, isNot(contains(340)));
        expect(manager.ffprobeSessions, isNot(contains(341)));
        expect(manager.ffplaySessions, isNot(contains(342)));
        expect(manager.mediaInformationSessions, isNot(contains(343)));
        expect(manager.ffprobeSessions, isNot(contains(343)));

        ffmpeg.submitForTest();
        ffprobe.submitForTest();
        ffplay.submitForTest();
        mediaInfo.submitForTest();
        ffmpeg.setCompleteCallback((_) {});
        ffprobe.setCompleteCallback((_) {});
        ffplay.setCompleteCallback((_) {});
        mediaInfo.setMediaInfoCompleteCallback((_) {});

        expect(manager.ffmpegSessions, contains(340));
        expect(manager.ffprobeSessions, contains(341));
        expect(manager.ffplaySessions, contains(342));
        expect(manager.mediaInformationSessions, contains(343));
        expect(manager.ffprobeSessions, contains(343));

        await Future.wait(
          subscriptions.map((subscription) => subscription.cancel()),
        );

        expect(manager.ffmpegSessions, contains(340));
        expect(manager.ffprobeSessions, contains(341));
        expect(manager.ffplaySessions, contains(342));
        expect(manager.mediaInformationSessions, contains(343));
        expect(manager.ffprobeSessions, contains(343));
        ffmpeg.settleForTest();
        ffprobe.settleForTest();
        ffplay.settleForTest();
        mediaInfo.settleForTest();

        ffmpeg.removeCompleteCallback();
        ffprobe.removeCompleteCallback();
        ffplay.removeCompleteCallback();
        mediaInfo.removeMediaInfoCompleteCallback();

        expect(manager.ffmpegSessions, isNot(contains(340)));
        expect(manager.ffprobeSessions, isNot(contains(341)));
        expect(manager.ffplaySessions, isNot(contains(342)));
        expect(manager.mediaInformationSessions, isNot(contains(343)));
        expect(manager.ffprobeSessions, isNot(contains(343)));
      },
    );

    test(
      'pending execution keeps callback routing after the last sink closes',
      () async {
        final ffmpeg = _NoopFFmpegSession(350);
        final ffprobe = _NoopFFprobeSession(351);
        final ffplay = _NoopFFplaySession(352);
        final mediaInfo = _NoopMediaInformationSession(353);
        ffmpeg.submitForTest();
        ffprobe.submitForTest();
        ffplay.submitForTest();
        mediaInfo.submitForTest();

        final subscriptions = [
          ffmpeg.logBatchStream.listen((_) {}),
          ffprobe.logBatchStream.listen((_) {}),
          ffplay.logBatchStream.listen((_) {}),
          mediaInfo.logBatchStream.listen((_) {}),
        ];
        await Future.wait(
          subscriptions.map((subscription) => subscription.cancel()),
        );

        expect(manager.ffmpegSessions, contains(350));
        expect(manager.ffprobeSessions, contains(351));
        expect(manager.ffplaySessions, contains(352));
        expect(manager.mediaInformationSessions, contains(353));
        expect(manager.ffprobeSessions, contains(353));

        ffmpeg.settleForTest();
        ffprobe.settleForTest();
        ffplay.settleForTest();
        mediaInfo.settleForTest();
        ffmpeg.removeLogCallback();
        ffprobe.removeLogCallback();
        ffplay.removeLogCallback();
        mediaInfo.removeMediaInfoCompleteCallback();

        expect(manager.ffmpegSessions, isNot(contains(350)));
        expect(manager.ffprobeSessions, isNot(contains(351)));
        expect(manager.ffplaySessions, isNot(contains(352)));
        expect(manager.mediaInformationSessions, isNot(contains(353)));
        expect(manager.ffprobeSessions, isNot(contains(353)));
      },
    );
  });
}
