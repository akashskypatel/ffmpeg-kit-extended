import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_flutter.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffmpeg_kit_flutter_loader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_ffmpeg_kit_bindings.dart';

void main() {
  late MockFFmpegKitBindings mockBindings;

  setUp(() {
    mockBindings = MockFFmpegKitBindings();
    setFFmpegKitBindings(mockBindings);
    setFFmpegLibrary(mockBindings.dynamicLibrary);
    Session.skipFinalizer = true;

    // Enable global callbacks so session-specific callbacks work
    FFmpegKitExtended.enableLogCallback();
    FFmpegKitExtended.enableStatisticsCallback();
    FFmpegKitExtended.enableFFmpegSessionCompleteCallback();
  });

  group('FFmpegKit', () {
    test('execute should return a session and complete synchronously', () {
      final session = FFmpegKit.execute('-version');
      expect(session, isNotNull);
      expect(session.getCommand(), equals('-version'));
      expect(session.getState(), equals(SessionState.completed));
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
    });

    test('executeAsync should execute in background and trigger callbacks',
        () async {
      bool completed = false;
      bool logReceived = false;
      bool statsReceived = false;

      FFmpegKit.executeAsync(
        '-version',
        onComplete: (s) => completed = true,
        onLog: (l) => logReceived = true,
        onStatistics: (s) => statsReceived = true,
      );

      // Give it a moment for the microtask and native listener to run
      await Future.delayed(const Duration(milliseconds: 1000));

      expect(completed, isTrue);
      expect(logReceived, isTrue);
      expect(statsReceived, isTrue);

      final session = FFmpegKit.getLastFFmpegSession();
      expect(session, isNotNull);
      expect(session!.getState(), equals(SessionState.completed));
    });

    test('getSessions should return all created sessions', () {
      FFmpegKit.execute('-v 1');
      FFmpegKit.execute('-v 2');

      final sessions = FFmpegKitExtended.getFFmpegSessions();
      expect(sessions.length, greaterThanOrEqualTo(2));
      expect(sessions[sessions.length - 2].getCommand(), equals('-v 1'));
      expect(sessions[sessions.length - 1].getCommand(), equals('-v 2'));
    });

    test('cancel should abort running sessions', () async {
      // In our mock, execute is sync, so we check cancel separately
      final session = await FFmpegKit.executeAsync('-i input.mp4 output.mp4');
      session.cancel();

      await Future.delayed(const Duration(milliseconds: 50));
      expect(session.isCancelled, isTrue);
    });
  });
}
