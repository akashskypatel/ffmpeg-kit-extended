import 'package:flutter_test/flutter_test.dart';
import 'package:ffmpeg_kit_extended_flutter_example/benchmark/benchmark_capabilities.dart';

void main() {
  group('FfmpegCapabilities', () {
    test('retains probed encoders, decoders, and filters', () {
      const capabilities = FfmpegCapabilities(
        encoders: <String>{'libopenh264', 'libkvazaar'},
        decoders: <String>{'h264', 'webp'},
        filters: <String>{'palettegen', 'paletteuse'},
      );

      expect(capabilities.encoders, <String>{'libopenh264', 'libkvazaar'});
      expect(capabilities.decoders, <String>{'h264', 'webp'});
      expect(capabilities.filters, <String>{'palettegen', 'paletteuse'});
    });

    test('reports the first exact missing requirement', () {
      const capabilities = FfmpegCapabilities(
        encoders: <String>{'libopenh264', 'libkvazaar'},
        decoders: <String>{'h264', 'webp'},
        filters: <String>{'palettegen', 'paletteuse'},
        failures: <String, String>{
          'encoder:libaom-av1': 'Unknown encoder libaom-av1',
        },
      );

      expect(
        capabilities.missingRequirement(encoder: 'libaom-av1'),
        'Unknown encoder libaom-av1',
      );
      expect(
        capabilities.missingRequirement(
          decoder: 'webp',
          requiredFilters: <String>['palettegen', 'missing_filter'],
        ),
        'filter missing_filter is unavailable',
      );
      expect(
        capabilities.missingRequirement(
          encoder: 'libopenh264',
          decoder: 'webp',
          requiredFilters: <String>['palettegen', 'paletteuse'],
        ),
        isNull,
      );
    });
  });
}
