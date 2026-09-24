import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../hook/build.dart';
import '../hook/native_artifact.dart';

void main() {
  test('maps supported Android architectures explicitly', () {
    expect(androidAbiForArchitecture(Architecture.arm), 'armeabi-v7a');
    expect(androidAbiForArchitecture(Architecture.arm64), 'arm64-v8a');
    expect(androidAbiForArchitecture(Architecture.x64), 'x86_64');
  });

  test('maps supported Apple architectures per platform', () {
    expect(iosArtifactArchitecture(Architecture.arm64), 'arm64');
    expect(macosArtifactArchitecture(Architecture.arm64), 'arm64');
    expect(macosArtifactArchitecture(Architecture.x64), 'x86_64');
  });

  test('maps supported Linux and Windows architectures explicitly', () {
    expect(linuxArtifactArchitecture(Architecture.x64), 'x86_64');
    expect(windowsArtifactArchitecture(Architecture.x64), 'x86_64');
  });

  test('rejects unsupported Android architectures clearly', () {
    final supported = <Architecture>{
      Architecture.arm,
      Architecture.arm64,
      Architecture.x64,
    };
    for (final architecture in Architecture.values) {
      if (supported.contains(architecture)) continue;
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

  test('rejects unsupported Apple architectures clearly', () {
    for (final architecture in Architecture.values) {
      if (architecture != Architecture.arm64) {
        expect(
          () => iosArtifactArchitecture(architecture),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              allOf(contains('iOS'), contains(architecture.name)),
            ),
          ),
        );
      }
      if (architecture != Architecture.arm64 &&
          architecture != Architecture.x64) {
        expect(
          () => macosArtifactArchitecture(architecture),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              allOf(contains('macOS'), contains(architecture.name)),
            ),
          ),
        );
      }
    }
  });

  test('rejects unsupported Linux and Windows architectures clearly', () {
    for (final architecture in Architecture.values) {
      if (architecture != Architecture.x64) {
        expect(
          () => linuxArtifactArchitecture(architecture),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              allOf(contains('Linux'), contains(architecture.name)),
            ),
          ),
        );
        expect(
          () => windowsArtifactArchitecture(architecture),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              allOf(contains('Windows'), contains(architecture.name)),
            ),
          ),
        );
      }
    }
  });

  test('validates target architecture before artifact resolution', () async {
    expect(
      () => validateTargetArchitecture(OS.android, Architecture.arm64),
      returnsNormally,
    );
    expect(
      () => validateTargetArchitecture(OS.iOS, Architecture.arm64),
      returnsNormally,
    );
    expect(
      () => validateTargetArchitecture(OS.linux, Architecture.x64),
      returnsNormally,
    );
    expect(
      () => validateTargetArchitecture(OS.windows, Architecture.x64),
      returnsNormally,
    );
    expect(
      () => validateTargetArchitecture(OS.iOS, Architecture.x64),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'does not invoke artifact resolution for an unsupported target',
    () async {
      var resolved = false;
      await expectLater(
        resolveAfterTargetArchitectureValidation(
          targetOS: OS.windows,
          targetArch: Architecture.arm64,
          resolve: () async {
            resolved = true;
            return true;
          },
        ),
        throwsA(isA<StateError>()),
      );
      expect(resolved, isFalse);
    },
  );

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
