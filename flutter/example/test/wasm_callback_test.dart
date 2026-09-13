import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(FFmpegKitExtended.initialize);

  setUp(() {
    FFmpegKitExtended.clearSessions();
  });

  testWidgets('FFmpeg Web callbacks deliver one completion and events', (
    WidgetTester tester,
  ) async {
    var completionCount = 0;
    var completionSessionId = -1;
    final logs = <Log>[];
    final statistics = <Statistics>[];

    final session = await FFmpegKit.executeAsync(
      '-nostdin -threads 1 -hide_banner -loglevel info -f lavfi '
      '-i testsrc=duration=0.2:size=64x64:rate=10 -frames:v 1 -f null -',
      onComplete: (completedSession) {
        completionCount++;
        completionSessionId = completedSession.getSessionId();
      },
      onLog: logs.add,
      onStatistics: statistics.add,
    );

    expect(session.getState(), SessionState.completed);
    expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
    expect(completionCount, 1);
    expect(completionSessionId, session.getSessionId());
    expect(logs, isNotEmpty);
    expect(statistics, isNotEmpty);
  });

  testWidgets('FFprobe Web callbacks deliver completion and logs', (
    WidgetTester tester,
  ) async {
    var completionCount = 0;
    var completionSessionId = -1;
    final logs = <Log>[];

    final session = await FFprobeKit.executeAsync(
      '-nostdin -hide_banner -loglevel info -f lavfi '
      '-i testsrc=duration=1:size=32x32:rate=1 -show_streams -of json',
      onComplete: (completedSession) {
        completionCount++;
        completionSessionId = completedSession.getSessionId();
      },
      onLog: logs.add,
    );

    expect(session.getState(), SessionState.completed);
    expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
    expect(completionCount, 1);
    expect(completionSessionId, session.getSessionId());
    expect(logs, isNotEmpty);
  });

  testWidgets('FFplay Web callbacks deliver terminal completion', (
    WidgetTester tester,
  ) async {
    var completionCount = 0;
    var completionSessionId = -1;

    final session = await FFplayKit.createSession(
      '-nostdin -threads 1 -nodisp -autoexit -an -f lavfi '
      '-i testsrc=duration=0.1:size=32x32:rate=1',
      onComplete: (completedSession) {
        completionCount++;
        completionSessionId = completedSession.getSessionId();
      },
    );
    await session.executeAsync().timeout(const Duration(seconds: 15));

    expect(session.getState(), SessionState.completed);
    expect(completionCount, 1);
    expect(completionSessionId, session.getSessionId());
  });

  testWidgets('Media-information Web callback delivers completion', (
    WidgetTester tester,
  ) async {
    var completionCount = 0;
    var completionSessionId = -1;

    final session = MediaInformationSession.createWithArguments(
      const [
        '-print_format',
        'json',
        '-nostdin',
        '-show_format',
        '-show_streams',
        '-show_chapters',
        '-f',
        'lavfi',
        '-i',
        'testsrc=duration=1:size=32x32:rate=1',
      ],
      completeCallback: (completedSession) {
        completionCount++;
        completionSessionId = completedSession.getSessionId();
      },
    );
    await session.executeAsync();

    expect(session.getState(), SessionState.completed);
    expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
    expect(completionCount, 1);
    expect(completionSessionId, session.getSessionId());
    expect(session.getMediaInformation(), isNotNull);
  });

  testWidgets('Web callbacks support replacement and unregister', (
    WidgetTester tester,
  ) async {
    var originalCompletions = 0;
    var replacementCompletions = 0;
    try {
      FFmpegKitConfig.enableFFmpegSessionCompleteCallback((_) {
        originalCompletions++;
      });
      await FFmpegKit.executeAsync('-nostdin -version');
      FFmpegKitConfig.enableFFmpegSessionCompleteCallback((_) {
        replacementCompletions++;
      });
      await FFmpegKit.executeAsync('-nostdin -version');
      FFmpegKitConfig.enableFFmpegSessionCompleteCallback(null);
      await FFmpegKit.executeAsync('-nostdin -version');

      expect(originalCompletions, 1);
      expect(replacementCompletions, 1);
    } finally {
      FFmpegKitConfig.enableFFmpegSessionCompleteCallback(null);
    }
  });

  testWidgets('Web callback exceptions do not stop queue progression', (
    WidgetTester tester,
  ) async {
    var localCompletions = 0;
    var globalCompletions = 0;
    FFmpegKitConfig.enableFFmpegSessionCompleteCallback((_) {
      globalCompletions++;
      throw StateError('intentional global callback failure');
    });
    try {
      final throwingSession = await FFmpegKit.executeAsync(
        '-nostdin -version',
        onComplete: (_) {
          localCompletions++;
          throw StateError('intentional local callback failure');
        },
      );
      final followUpSession = await FFmpegKit.executeAsync('-nostdin -version');

      expect(ReturnCode.isSuccess(throwingSession.getReturnCode()), isTrue);
      expect(ReturnCode.isSuccess(followUpSession.getReturnCode()), isTrue);
      expect(localCompletions, 1);
      expect(globalCompletions, 2);
    } finally {
      FFmpegKitConfig.enableFFmpegSessionCompleteCallback(null);
    }
  });

  testWidgets('Web callback routing remains stable across repeated sessions', (
    WidgetTester tester,
  ) async {
    const sessionCount = 256;
    final callbackCounts = <int, int>{};
    final sessionIds = <int>{};

    for (var index = 0; index < sessionCount; index++) {
      final session = await FFmpegKit.executeAsync(
        '-nostdin -version',
        onComplete: (completedSession) {
          final sessionId = completedSession.getSessionId();
          sessionIds.add(sessionId);
          callbackCounts.update(
            sessionId,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        },
      );

      expect(session.getState(), SessionState.completed);
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
    }

    expect(sessionIds.length, sessionCount);
    expect(callbackCounts.length, sessionCount);
    expect(callbackCounts.values, everyElement(1));
  });

  testWidgets('Web callbacks remain isolated across concurrent sessions', (
    WidgetTester tester,
  ) async {
    const sessionCount = 8;
    final callbackCounts = <int, int>{};
    final futures = <Future<FFmpegSession>>[];
    for (var index = 0; index < sessionCount; index++) {
      futures.add(
        FFmpegKit.executeAsync(
          '-nostdin -version',
          onComplete: (session) {
            final sessionId = session.getSessionId();
            callbackCounts.update(
              sessionId,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          },
        ),
      );
    }

    final sessions = await Future.wait(futures).timeout(
      const Duration(seconds: 30),
    );
    expect(sessions, hasLength(sessionCount));
    expect(callbackCounts, hasLength(sessionCount));
    expect(callbackCounts.values, everyElement(1));
    expect(
      sessions,
      everyElement(
        predicate<FFmpegSession>(
          (session) =>
              session.getState() == SessionState.completed &&
              ReturnCode.isSuccess(session.getReturnCode()),
        ),
      ),
    );
  });

  testWidgets('Web cancellation settles the session and callback once', (
    WidgetTester tester,
  ) async {
    var completionCount = 0;
    final session = FFmpegSession.create(
      '-nostdin -re -threads 1 -f lavfi '
      '-i testsrc=duration=5:size=32x32:rate=10 -f null -',
      completeCallback: (_) => completionCount++,
    );
    final future = session.executeAsync();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(session.getState(), SessionState.running);
    session.cancel();

    final cancelled = await future.timeout(const Duration(seconds: 15));
    expect(cancelled.isCancelled, isTrue);
    expect(cancelled.getState(), SessionState.completed);
    expect(
      ReturnCode.isCancel(cancelled.getReturnCode()) ||
          ReturnCode.isSuccess(cancelled.getReturnCode()),
      isTrue,
    );
    expect(completionCount, 1);
  });
}
