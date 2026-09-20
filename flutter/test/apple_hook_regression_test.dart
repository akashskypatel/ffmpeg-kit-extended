import 'package:test/test.dart';

import '../hook/apple.dart';

void main() {
  final fixtures = <AppleSliceCandidate>[
    AppleSliceCandidate(
      identifier: 'ios-arm64',
      libraryPath: 'ffmpegkit.framework',
      platform: 'ios',
      variant: null,
      architectures: {'arm64'},
    ),
    AppleSliceCandidate(
      identifier: 'ios-arm64-simulator',
      libraryPath: 'ffmpegkit.framework',
      platform: 'ios',
      variant: 'simulator',
      architectures: {'arm64'},
    ),
    AppleSliceCandidate(
      identifier: 'ios-arm64_x86_64-simulator',
      libraryPath: 'ffmpegkit.framework',
      platform: 'ios',
      variant: 'simulator',
      architectures: {'arm64', 'x86_64'},
    ),
    AppleSliceCandidate(
      identifier: 'ios-x86_64-simulator',
      libraryPath: 'ffmpegkit.framework',
      platform: 'ios',
      variant: 'simulator',
      architectures: {'x86_64'},
    ),
    AppleSliceCandidate(
      identifier: 'macos-arm64_x86_64',
      libraryPath: 'ffmpegkit.framework',
      platform: 'macos',
      variant: null,
      architectures: {'arm64', 'x86_64'},
    ),
  ];

  test('fixture matrix keeps device and simulator variants separate', () {
    expect(
      selectAppleSlice(
        fixtures,
        const AppleSliceRequest(
          platform: 'ios',
          variant: null,
          architecture: 'arm64',
        ),
      )?.identifier,
      'ios-arm64',
    );
    expect(
      selectAppleSlice(
        fixtures,
        const AppleSliceRequest(
          platform: 'ios',
          variant: 'simulator',
          architecture: 'arm64',
        ),
      )?.identifier,
      'ios-arm64-simulator',
    );
  });

  test('simulator x86_64 selects x86_64 or a combined slice', () {
    final candidate = selectAppleSlice(
      fixtures,
      const AppleSliceRequest(
        platform: 'ios',
        variant: 'simulator',
        architecture: 'x86_64',
      ),
    );

    expect(candidate, isNotNull);
    expect(candidate!.architectures, contains('x86_64'));
  });

  test('arm64-only simulator has no x86_64 match', () {
    final arm64Only = fixtures.where(
      (candidate) => candidate.identifier == 'ios-arm64-simulator',
    );

    expect(
      selectAppleSlice(
        arm64Only,
        const AppleSliceRequest(
          platform: 'ios',
          variant: 'simulator',
          architecture: 'x86_64',
        ),
      ),
      isNull,
    );
  });

  test('macOS combined fixture supports both requested architectures', () {
    final macos = fixtures.where((candidate) => candidate.platform == 'macos');

    expect(
      selectAppleSlice(
        macos,
        const AppleSliceRequest(
          platform: 'macos',
          variant: null,
          architecture: 'arm64',
        ),
      )?.identifier,
      'macos-arm64_x86_64',
    );
    expect(
      selectAppleSlice(
        macos,
        const AppleSliceRequest(
          platform: 'macos',
          variant: null,
          architecture: 'x86_64',
        ),
      )?.identifier,
      'macos-arm64_x86_64',
    );
  });

  test('wrong platform variant is rejected', () {
    expect(
      selectAppleSlice(
        fixtures,
        const AppleSliceRequest(
          platform: 'ios',
          variant: 'macabi',
          architecture: 'arm64',
        ),
      ),
      isNull,
    );
  });
}
