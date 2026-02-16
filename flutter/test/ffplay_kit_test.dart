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
  });

  group('FFplayKit', () {
    test('execute should start a session and respond to controls', () async {
      final session = await FFplayKit.execute('video.mp4');
      expect(session, isNotNull);

      expect(session.isPlaying(), isTrue);

      session.pause();
      expect(session.isPaused(), isTrue);

      session.resume();
      expect(session.isPaused(), isFalse);

      session.seek(5.0);
      expect(session.getPosition(), equals(5.0));

      session.stop();
      expect(session.isPlaying(), isFalse);
    }, skip: 'Calls actual API instead of mock implementation');

    test('global controls should affect current session', () async {
      final session = await FFplayKit.execute('video.mp4');

      FFplayKit.pause(); // Global pause
      expect(FFplayKit.isPaused(), isTrue);

      FFplayKit.resume();
      expect(FFplayKit.isPaused(), isFalse);

      FFplayKit.stop();
      expect(session.isPlaying(), isFalse);
    }, skip: 'Calls actual API instead of mock implementation');
  });
}
