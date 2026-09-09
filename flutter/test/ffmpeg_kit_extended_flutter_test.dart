import 'package:flutter_test/flutter_test.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void main() {
  test('exports the unified FFmpegKit API', () {
    expect(FFmpegKit, isA<Type>());
    expect(FFprobeKit, isA<Type>());
    expect(FFplayKit, isA<Type>());
    expect(Session, isA<Type>());
    expect(FFmpegSession, isA<Type>());
    expect(FFprobeSession, isA<Type>());
    expect(FFplaySession, isA<Type>());
    expect(MediaInformationSession, isA<Type>());
    expect(FFmpegKitExtended, isA<Type>());
    expect(FFmpegKitConfig, isA<Type>());
  });
}
