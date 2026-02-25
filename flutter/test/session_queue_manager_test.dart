import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffmpeg_kit_flutter_loader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_ffmpeg_kit_bindings.dart';

void main() {
  late MockFFmpegKitBindings mockBindings;

  setUp(() {
    mockBindings = MockFFmpegKitBindings();
    setFFmpegKitBindings(mockBindings);
    setFFmpegLibrary(mockBindings.dynamicLibrary);
    SessionQueueManager().cancelAll();
    FFmpegKitConfig.clearSessions();
    FFmpegKitConfig.setMaxConcurrentSessions(8);
  });

  group('SessionQueueManager (Unit)', () {
    test('maxConcurrentSessions should limit active sessions', () async {
      FFmpegKitConfig.setMaxConcurrentSessions(2);

      final sessions = <FFmpegSession>[];
      final completionFlags = <int, bool>{};

      // Start 5 sessions
      for (int i = 0; i < 5; i++) {
        final session = FFmpegKit.createSession('-i input$i.mp4 output$i.mp4');
        sessions.add(session);
        completionFlags[session.getSessionId()] = false;

        // Execute async manually to control flow (returns immediately)
        session.executeAsync(completeCallback: (s) {
          completionFlags[s.getSessionId()] = true;
        });
      }

      // At this point, 2 should be running or starting
      await Future.delayed(const Duration(milliseconds: 50));

      final activeCount = FFmpegKitExtended.getFFmpegSessions()
          .where((s) => s.getState() == SessionState.running)
          .length;
      expect(activeCount, lessThanOrEqualTo(2));

      // Wait for batches to complete (mock has 100ms delay, 3 batches)
      int waited = 0;
      while (waited < 1000 && !completionFlags.values.every((v) => v)) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited += 100;
      }

      expect(completionFlags.values.every((v) => v), isTrue);
    });

    test('cancelAll should clear sessions', () async {
      FFmpegKitConfig.setMaxConcurrentSessions(1);

      final s1 = FFmpegKitExtended.createFFmpegSession('-i 1.mp4 1.out');
      final s2 = FFmpegKitExtended.createFFmpegSession('-i 2.mp4 2.out');
      s1.executeAsync();
      s2.executeAsync();

      await Future.delayed(
          const Duration(milliseconds: 10)); // Ensure s1 starts

      FFmpegKitExtended.cancelAllSessions();

      await Future.delayed(const Duration(milliseconds: 50));
      expect(s1.isCancelled, isTrue); // Active session cancelled
      // s2 might be cancelled in queue or if started.
      // If we called cancelAll, queue is cleared.
    });
  });
}
