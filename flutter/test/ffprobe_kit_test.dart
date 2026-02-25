import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffmpeg_kit_flutter_loader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_data.dart';
import 'mocks/mock_ffmpeg_kit_bindings.dart';

void main() {
  late MockFFmpegKitBindings mockBindings;

  setUp(() {
    mockBindings = MockFFmpegKitBindings();
    setFFmpegKitBindings(mockBindings);
    setFFmpegLibrary(mockBindings.dynamicLibrary);

    // Ensure SessionQueueManager is clean
    SessionQueueManager().cancelAll();
    SessionQueueManager().maxConcurrentSessions = 8;
    FFmpegKitConfig.clearSessions();

    // Enable global callback to help with debugging if needed (though not strictly required for local callbacks)
    FFmpegKitConfig.enableFFprobeSessionCompleteCallback();
  });

  group('FFprobeKit', () {
    test('getMediaInformation should return parsed media info', () async {
      print("[TEST] setting mock info");
      final mockInfo = MockMediaInformation(
          filename: "video.mp4",
          format: "mp4",
          duration: "10.500",
          bitrate: "2000000",
          streams: [
            MockStreamInformation(
                index: 0,
                type: "video",
                codec: "h264",
                width: 1280,
                height: 720),
            MockStreamInformation(
                index: 1, type: "audio", codec: "aac", sampleRate: "44100"),
          ],
          chapters: [
            MockChapterInformation(id: 1, startTime: "0.000", endTime: "5.000"),
          ]);

      mockBindings.setMockMediaInformation("video.mp4", mockInfo);

      print("[TEST] Getting media info...");
      final session = FFprobeKit.getMediaInformation("video.mp4");
      print("[TEST] Session state: ${session.getState()}");

      expect(session, isNotNull);
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);

      final info = session.getMediaInformation();
      expect(info, isNotNull);
      expect(info!.filename, equals("video.mp4"));
      expect(info.format, equals("mp4"));
      expect(info.duration, equals("10.500"));

      final streams = info.streams;
      expect(streams.length, equals(2));
      expect(streams[0].type, equals("video"));
      expect(streams[0].width, equals(1280));
      expect(streams[1].type, equals("audio"));
      expect(streams[1].sampleRate, equals("44100"));

      final chapters = info.chapters;
      expect(chapters.length, equals(1));
      expect(chapters[0].startTime, equals("0.000"));
    });

    test('getMediaInformationAsync should trigger callback', () async {
      final mockInfo = MockMediaInformation(filename: "async.mp4");
      mockBindings.setMockMediaInformation("async.mp4", mockInfo);

      bool completed = false;

      final sessionFuture = FFprobeKit.getMediaInformationAsync("async.mp4",
          onComplete: (session) {
        completed = true;
      });

      // We await the sessionFuture to ensure proper async flow test
      await sessionFuture;

      expect(completed, isTrue);
    });

    test('execute should return a session and complete eventually', () async {
      final session = FFprobeKit.execute('-show_format video.mp4');
      expect(session, isNotNull);

      // Since execute is non-blocking but runs in background, we poll for completion
      // In real app, use executeAsync to await directly.
      int retries = 0;
      while (session.getState() != SessionState.completed && retries < 20) {
        await Future.delayed(const Duration(milliseconds: 50));
        retries++;
      }

      expect(session.getState(), equals(SessionState.completed));
    });
  });
}
