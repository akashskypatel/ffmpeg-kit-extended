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

  group('FFmpegKit Flutter Smoke Tests', () {
    test('Bindings are correctly injected and return mock version', () {
      final version = FFmpegKitConfig.getVersion();
      expect(version, equals('6.0.0-mock'));
    });
  });
}
