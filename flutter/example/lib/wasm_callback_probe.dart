import 'dart:async';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ProbeApp());
}

Future<String> _runCallbackProbe() async {
  try {
    await FFmpegKitExtended.initialize();
    FFmpegKitExtended.clearSessions();

    var ffmpegCompletions = 0;
    var ffmpegCompletionSessionId = -1;
    final ffmpegLogs = <Log>[];
    final ffmpegStatistics = <Statistics>[];
    final ffmpegSession = await FFmpegKit.executeAsync(
      '-nostdin -threads 1 -hide_banner -loglevel info -f lavfi '
      '-i testsrc=duration=0.2:size=64x64:rate=10 -frames:v 1 -f null -',
      onComplete: (session) {
        ffmpegCompletions++;
        ffmpegCompletionSessionId = session.getSessionId();
      },
      onLog: ffmpegLogs.add,
      onStatistics: ffmpegStatistics.add,
    );

    if (!ReturnCode.isSuccess(ffmpegSession.getReturnCode()) ||
        ffmpegCompletions != 1 ||
        ffmpegCompletionSessionId != ffmpegSession.getSessionId() ||
        ffmpegLogs.isEmpty ||
        ffmpegStatistics.isEmpty) {
      return 'FAIL: FFmpeg callback result was incomplete.';
    }

    var ffprobeCompletions = 0;
    var ffprobeCompletionSessionId = -1;
    final ffprobeLogs = <Log>[];
    final ffprobeSession = await FFprobeKit.executeAsync(
      '-nostdin -hide_banner -loglevel info -f lavfi '
      '-i testsrc=duration=1:size=32x32:rate=1 -show_streams -of json',
      onComplete: (session) {
        ffprobeCompletions++;
        ffprobeCompletionSessionId = session.getSessionId();
      },
      onLog: ffprobeLogs.add,
    );

    if (!ReturnCode.isSuccess(ffprobeSession.getReturnCode()) ||
        ffprobeCompletions != 1 ||
        ffprobeCompletionSessionId != ffprobeSession.getSessionId() ||
        ffprobeLogs.isEmpty) {
      return 'FAIL: FFprobe callbacks were incomplete '
          '(returnCode=${ffprobeSession.getReturnCode()}, '
          'completions=$ffprobeCompletions, logs=${ffprobeLogs.length}).';
    }

    var ffplayCompletions = 0;
    var ffplayCompletionSessionId = -1;
    final ffplaySession = await FFplayKit.createSession(
      '-nostdin -threads 1 -nodisp -autoexit -an -f lavfi '
      '-i testsrc=duration=0.1:size=32x32:rate=1',
      onComplete: (session) {
        ffplayCompletions++;
        ffplayCompletionSessionId = session.getSessionId();
      },
    );
    try {
      await ffplaySession.executeAsync().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      return 'FAIL: FFplay did not settle within the browser probe timeout.';
    }

    if (ffplaySession.getState() != SessionState.completed ||
        ffplayCompletions != 1 ||
        ffplayCompletionSessionId != ffplaySession.getSessionId()) {
      return 'FAIL: FFplay callbacks were incomplete '
          '(returnCode=${ffplaySession.getReturnCode()}, '
          'completions=$ffplayCompletions).';
    }

    var mediaInfoCompletions = 0;
    var mediaInfoCompletionSessionId = -1;
    final mediaInfoSession = MediaInformationSession.createWithArguments(
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
      completeCallback: (session) {
        mediaInfoCompletions++;
        mediaInfoCompletionSessionId = session.getSessionId();
      },
    );
    await mediaInfoSession.executeAsync();

    if (!ReturnCode.isSuccess(mediaInfoSession.getReturnCode()) ||
        mediaInfoCompletions != 1 ||
        mediaInfoCompletionSessionId != mediaInfoSession.getSessionId() ||
        mediaInfoSession.getMediaInformation() == null) {
      return 'FAIL: media-information callback result was incomplete.';
    }

    var originalGlobalCompletions = 0;
    var replacementGlobalCompletions = 0;
    try {
      FFmpegKitConfig.enableFFmpegSessionCompleteCallback((_) {
        originalGlobalCompletions++;
      });
      await FFmpegKit.executeAsync('-nostdin -version');
      FFmpegKitConfig.enableFFmpegSessionCompleteCallback((_) {
        replacementGlobalCompletions++;
      });
      await FFmpegKit.executeAsync('-nostdin -version');
      FFmpegKitConfig.enableFFmpegSessionCompleteCallback(null);
      await FFmpegKit.executeAsync('-nostdin -version');
      if (originalGlobalCompletions != 1 || replacementGlobalCompletions != 1) {
        return 'FAIL: callback replacement or unregister was incomplete '
            '(original=$originalGlobalCompletions, '
            'replacement=$replacementGlobalCompletions).';
      }
    } finally {
      FFmpegKitConfig.enableFFmpegSessionCompleteCallback(null);
    }

    var throwingLocalCompletions = 0;
    var throwingGlobalCompletions = 0;
    FFmpegKitConfig.enableFFmpegSessionCompleteCallback((_) {
      throwingGlobalCompletions++;
      throw StateError('intentional global callback failure');
    });
    try {
      final throwingSession = await FFmpegKit.executeAsync(
        '-nostdin -version',
        onComplete: (_) {
          throwingLocalCompletions++;
          throw StateError('intentional local callback failure');
        },
      );
      final followUpSession = await FFmpegKit.executeAsync('-nostdin -version');
      if (!ReturnCode.isSuccess(throwingSession.getReturnCode()) ||
          !ReturnCode.isSuccess(followUpSession.getReturnCode()) ||
          throwingLocalCompletions != 1 ||
          throwingGlobalCompletions != 2) {
        return 'FAIL: callback exception isolation or queue continuation '
            'was incomplete '
            '(local=$throwingLocalCompletions, '
            'global=$throwingGlobalCompletions).';
      }
    } finally {
      FFmpegKitConfig.enableFFmpegSessionCompleteCallback(null);
    }

    const repeatedSessionCount = 256;
    final repeatedSessionIds = <int>{};
    final repeatedCompletionCounts = <int, int>{};
    for (var index = 0; index < repeatedSessionCount; index++) {
      final repeatedSession = await FFmpegKit.executeAsync(
        '-nostdin -version',
        onComplete: (session) {
          final sessionId = session.getSessionId();
          repeatedSessionIds.add(sessionId);
          repeatedCompletionCounts.update(
            sessionId,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        },
      );
      if (!ReturnCode.isSuccess(repeatedSession.getReturnCode()) ||
          repeatedSession.getState() != SessionState.completed) {
        return 'FAIL: repeated session stress did not settle successfully '
            '(index=$index, returnCode=${repeatedSession.getReturnCode()}).';
      }
    }
    if (repeatedSessionIds.length != repeatedSessionCount ||
        repeatedCompletionCounts.length != repeatedSessionCount ||
        repeatedCompletionCounts.values.any((count) => count != 1)) {
      return 'FAIL: repeated session stress did not preserve callback identity '
          '(sessions=${repeatedSessionIds.length}, '
          'callbacks=${repeatedCompletionCounts.length}).';
    }

    const concurrentSessionCount = 8;
    final concurrentCompletionCounts = <int, int>{};
    final concurrentFutures = <Future<FFmpegSession>>[];
    for (var index = 0; index < concurrentSessionCount; index++) {
      concurrentFutures.add(
        FFmpegKit.executeAsync(
          '-nostdin -version',
          onComplete: (session) {
            final sessionId = session.getSessionId();
            concurrentCompletionCounts.update(
              sessionId,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          },
        ),
      );
    }
    final concurrentSessions = await Future.wait(concurrentFutures).timeout(
      const Duration(seconds: 30),
    );
    if (concurrentSessions.length != concurrentSessionCount ||
        concurrentCompletionCounts.length != concurrentSessionCount ||
        concurrentCompletionCounts.values.any((count) => count != 1) ||
        concurrentSessions.any(
          (session) =>
              !ReturnCode.isSuccess(session.getReturnCode()) ||
              session.getState() != SessionState.completed,
        )) {
      return 'FAIL: concurrent session stress did not preserve exactly-once '
          'completion (sessions=${concurrentSessions.length}, '
          'callbacks=${concurrentCompletionCounts.length}).';
    }

    var cancellationCompletions = 0;
    final cancellableSession = FFmpegSession.create(
      '-nostdin -re -threads 1 -f lavfi '
      '-i testsrc=duration=5:size=32x32:rate=10 -f null -',
      completeCallback: (_) => cancellationCompletions++,
    );
    final cancellationFuture = cancellableSession.executeAsync();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (cancellableSession.getState() != SessionState.running) {
      return 'FAIL: cancellation workload did not remain running before '
          'cancellation.';
    }
    cancellableSession.cancel();
    final cancelledSession = await cancellationFuture.timeout(
      const Duration(seconds: 15),
    );
    final cancellationReturnCode = cancelledSession.getReturnCode();
    if (!cancelledSession.isCancelled ||
        cancelledSession.getState() != SessionState.completed ||
        (!ReturnCode.isCancel(cancellationReturnCode) &&
            !ReturnCode.isSuccess(cancellationReturnCode)) ||
        cancellationCompletions != 1) {
      return 'FAIL: cancellation did not settle exactly once '
          '(isCancelled=${cancelledSession.isCancelled}, '
          'returnCode=$cancellationReturnCode, '
          'state=${cancelledSession.getState()}, '
          'callbacks=$cancellationCompletions).';
    }

    return 'PASS: FFmpeg callbacks (logs=${ffmpegLogs.length}, '
        'statistics=${ffmpegStatistics.length}), FFprobe logs '
        '(${ffprobeLogs.length}), FFplay terminal completion, and '
        'media-information completion delivered exactly once; callback replacement, '
        'unregister, exception isolation, and $repeatedSessionCount repeated '
        'sessions preserved queue progression; concurrent execution and '
        'cancellation settled exactly once.';
  } catch (error, stackTrace) {
    return 'FAIL: $error\n$stackTrace';
  }
}

class _ProbeApp extends StatefulWidget {
  const _ProbeApp();

  @override
  State<_ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<_ProbeApp> {
  String result = 'Running callback probe...';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final probeResult = await _runCallbackProbe();
    debugPrint(probeResult);
    if (mounted) setState(() => result = probeResult);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SelectableText(
          result,
          key: const Key('callback-probe-result'),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
