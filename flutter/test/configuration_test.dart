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

  group('FFmpegKitConfig', () {
    test('getVersion should return mock version', () {
      expect(FFmpegKitConfig.getVersion(), equals('6.0.0-mock'));
    });

    test('getFFmpegVersion should return mock ffmpeg version', () {
      expect(FFmpegKitConfig.getFFmpegVersion(), equals('6.0-mock'));
    });

    test('getBuildDate should return mock build date', () {
      expect(FFmpegKitConfig.getBuildDate(), equals('20260101'));
    });

    test('logLevel should be gettable and settable', () {
      FFmpegKitConfig.setLogLevel(LogLevel.info);
      expect(FFmpegKitConfig.getLogLevel(), equals(LogLevel.info));
    });

    test('sessionHistorySize should be gettable and settable', () {
      FFmpegKitConfig.setSessionHistorySize(20);
      expect(FFmpegKitConfig.getSessionHistorySize(), equals(20));
    });

    test('registerNewFFmpegPipe should return a pipe path', () {
      final pipe = FFmpegKitConfig.registerNewFFmpegPipe();
      expect(pipe, startsWith('\\\\.\\pipe\\ffmpegkit_'));
    });

    test('setEnvironmentVariable should succeed', () {
      // This doesn't throw, we just verify it calls native
      FFmpegKitConfig.setEnvironmentVariable("MY_VAR", "VALUE");
    });

    test('ignoreSignal should succeed', () {
      FFmpegKitConfig.ignoreSignal(Signal.sigint);
    });
  });
}
