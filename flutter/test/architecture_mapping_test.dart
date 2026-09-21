import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../hook/native_artifact.dart';

void main() {
  test('maps supported Android architectures explicitly', () {
    expect(androidAbiForArchitecture(Architecture.arm), 'armeabi-v7a');
    expect(androidAbiForArchitecture(Architecture.arm64), 'arm64-v8a');
    expect(androidAbiForArchitecture(Architecture.ia32), 'x86');
    expect(androidAbiForArchitecture(Architecture.x64), 'x86_64');
  });

  test('maps supported Apple architectures explicitly', () {
    expect(appleArtifactArchitecture(Architecture.arm64), 'arm64');
    expect(appleArtifactArchitecture(Architecture.x64), 'x86_64');
  });

  test('maps supported desktop architectures explicitly', () {
    expect(
      desktopArtifactArchitecture(Architecture.arm64, platform: 'windows'),
      'arm64',
    );
    expect(
      desktopArtifactArchitecture(Architecture.x64, platform: 'linux'),
      'x86_64',
    );
  });

  test('rejects unsupported Android architectures clearly', () {
    final supported = <Architecture>{
      Architecture.arm,
      Architecture.arm64,
      Architecture.ia32,
      Architecture.x64,
    };
    for (final architecture in Architecture.values) {
      if (supported.contains(architecture)) {
        continue;
      }
      expect(
        () => androidAbiForArchitecture(architecture),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains(architecture.name),
              contains('supported architectures'),
            ),
          ),
        ),
      );
    }
  });

  test('rejects unsupported Apple and desktop architectures clearly', () {
    for (final architecture in Architecture.values) {
      if (architecture != Architecture.arm64 &&
          architecture != Architecture.x64) {
        expect(
          () => appleArtifactArchitecture(architecture),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              allOf(
                contains(architecture.name),
                contains('supported architectures'),
              ),
            ),
          ),
        );
        expect(
          () => desktopArtifactArchitecture(architecture, platform: 'linux'),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              allOf(contains('linux'), contains(architecture.name)),
            ),
          ),
        );
      }
    }
  });

  test('validates target architecture before artifact resolution', () {
    expect(
      () => validateTargetArchitecture(OS.android, Architecture.arm64),
      returnsNormally,
    );
    expect(
      () => validateTargetArchitecture(OS.iOS, Architecture.x64),
      returnsNormally,
    );
    expect(
      () => validateTargetArchitecture(OS.linux, Architecture.x64),
      returnsNormally,
    );
  });

  test('rejects unsupported target operating systems explicitly', () {
    final supported = [OS.android, OS.iOS, OS.linux, OS.macOS, OS.windows];
    for (final targetOS in OS.values) {
      if (supported.any((value) => value == targetOS)) continue;
      expect(
        () => validateTargetArchitecture(targetOS, Architecture.x64),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains(targetOS.name), contains('supported target OSes')),
          ),
        ),
      );
    }
  });
}
