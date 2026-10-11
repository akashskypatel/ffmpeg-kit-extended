import 'package:flutter_test/flutter_test.dart';
import 'package:ffmpeg_kit_extended_flutter_example/benchmark/benchmark_operation_exclusions.dart';

void main() {
  group('parseBenchmarkNotMeasuredOperations', () {
    test('trims ids, removes empty entries, and deduplicates them', () {
      expect(
        parseBenchmarkNotMeasuredOperations(
          ' h265, h265_lavfi, , h265 ',
          'Android runtime abort',
        ),
        <String, String>{
          'h265': 'Android runtime abort',
          'h265_lavfi': 'Android runtime abort',
        },
      );
    });

    test('allows an empty selection without requiring a reason', () {
      expect(parseBenchmarkNotMeasuredOperations(' , ', ''), isEmpty);
    });

    test('requires an explanation for a non-empty selection', () {
      expect(
        () => parseBenchmarkNotMeasuredOperations('h265', '  '),
        throwsArgumentError,
      );
    });
  });
}
