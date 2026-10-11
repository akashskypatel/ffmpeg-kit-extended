import 'package:flutter_test/flutter_test.dart';
import 'package:ffmpeg_kit_extended_flutter_example/benchmark/benchmark_core.dart';

void main() {
  group('native benchmark workload', () {
    test('still fixture matches the issue 40 reference image', () {
      expect(benchmarkStillWidth, 4032);
      expect(benchmarkStillHeight, 3024);
      expect(benchmarkStillWidth * benchmarkStillHeight, 4032 * 3024);
    });

    test('video fixture matches the issue 40 reference workload', () {
      expect(benchmarkVideoWidth, 1920);
      expect(benchmarkVideoHeight, 1080);
      expect(benchmarkVideoDurationSeconds, 3);
      expect(benchmarkVideoDurationSeconds * 30, 90);
    });
  });
}
