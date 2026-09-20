import 'dart:io';

import 'package:test/test.dart';

import '../hook/apple.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('ffmpeg_apple_hook_');
  });

  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

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
    expect(
      appleSliceSelectionFailureMessage(
        request: const AppleSliceRequest(
          platform: 'ios',
          variant: 'simulator',
          architecture: 'x86_64',
        ),
        root: '/fixture.xcframework',
        candidates: arm64Only,
      ),
      allOf(
        contains('iOS simulator x86_64 was requested'),
        contains('arm64-only simulator artifact'),
        contains('EXCLUDED_ARCHS'),
      ),
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

  test('reads AvailableLibraries from an XCFramework Info.plist', () {
    final infoPlist = File('${tempRoot.path}/Info.plist')
      ..writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com">
<plist version="1.0">
<dict>
  <key>AvailableLibraries</key>
  <array>
    <dict>
      <key>LibraryIdentifier</key><string>ios-arm64-simulator</string>
      <key>LibraryPath</key><string>ffmpegkit.framework</string>
      <key>SupportedPlatform</key><string>ios</string>
      <key>SupportedPlatformVariant</key><string>simulator</string>
      <key>SupportedArchitectures</key><array><string>arm64</string></array>
    </dict>
    <dict>
      <key>LibraryIdentifier</key><string>ios-x86_64-simulator</string>
      <key>LibraryPath</key><string>ffmpegkit.framework</string>
      <key>SupportedPlatform</key><string>ios</string>
      <key>SupportedPlatformVariant</key><string>simulator</string>
      <key>SupportedArchitectures</key><array><string>x86_64</string></array>
    </dict>
  </array>
</dict>
</plist>
''');

    final candidates = readAppleSliceCandidates(infoPlist);

    expect(candidates, hasLength(2));
    expect(
      selectAppleSlice(
        candidates,
        const AppleSliceRequest(
          platform: 'ios',
          variant: 'simulator',
          architecture: 'x86_64',
        ),
      )?.identifier,
      'ios-x86_64-simulator',
    );
  });

  test('parses thin and fat lipo architecture reports', () {
    expect(
      parseAppleLipoArchitectures(
        'Architectures in the fat file: ffmpegkit are: arm64 x86_64',
      ),
      equals({'arm64', 'x86_64'}),
    );
    expect(
      parseAppleLipoArchitectures(
        'Non-fat file: ffmpegkit is architecture: arm64',
      ),
      equals({'arm64'}),
    );
  });

  test(
    'thins a fat binary and verifies the requested output architecture',
    () async {
      final source = File('${tempRoot.path}/fat')..writeAsBytesSync([1]);
      final destination = File('${tempRoot.path}/arm64');
      final architectures = <String, Set<String>>{
        source.path: {'arm64', 'x86_64'},
      };

      final result = await materializeAppleBinary(
        source: source,
        destination: destination,
        architecture: 'arm64',
        diagnosticContext: 'Target: ios-arm64; SDK: iPhoneOS',
        runner: _fakeLipo(architectures),
      );

      expect(result.sourceArchitectures, equals({'arm64', 'x86_64'}));
      expect(result.outputArchitectures, equals({'arm64'}));
      expect(destination.existsSync(), isTrue);
    },
  );

  test(
    'copies an exact thin binary without invoking a thinning fallback',
    () async {
      final source = File('${tempRoot.path}/thin')..writeAsBytesSync([2]);
      final destination = File('${tempRoot.path}/copy');
      final architectures = <String, Set<String>>{
        source.path: {'arm64'},
        destination.path: {'arm64'},
      };

      final result = await materializeAppleBinary(
        source: source,
        destination: destination,
        architecture: 'arm64',
        diagnosticContext: 'Target: macos-arm64; SDK: macOS',
        runner: _fakeLipo(architectures),
      );

      expect(result.outputArchitectures, equals({'arm64'}));
      expect(destination.readAsBytesSync(), equals([2]));
    },
  );

  test('fails when the requested architecture is missing', () async {
    final source = File('${tempRoot.path}/arm64-only')..writeAsBytesSync([3]);
    final destination = File('${tempRoot.path}/wrong-arch');
    final architectures = <String, Set<String>>{
      source.path: {'arm64'},
    };

    await expectLater(
      materializeAppleBinary(
        source: source,
        destination: destination,
        architecture: 'x86_64',
        diagnosticContext: 'Target: ios-x86_64; SDK: iPhoneSimulator',
        runner: _fakeLipo(architectures),
      ),
      throwsA(
        predicate<AppleBinaryException>(
          (error) =>
              error.message.contains('requested architecture x86_64') &&
              error.message.contains('arm64'),
        ),
      ),
    );
    expect(destination.existsSync(), isFalse);
  });

  test('does not copy the source when lipo fails', () async {
    final source = File('${tempRoot.path}/fat-error')..writeAsBytesSync([4]);
    final destination = File('${tempRoot.path}/not-an-x86_64-binary');
    final architectures = <String, Set<String>>{
      source.path: {'arm64', 'x86_64'},
    };

    Future<ProcessResult> failingRunner(
      String executable,
      List<String> args,
    ) async {
      if (args.contains('-thin')) {
        return ProcessResult(1, 1, '', 'simulated lipo failure');
      }
      return _fakeLipo(architectures)(executable, args);
    }

    await expectLater(
      materializeAppleBinary(
        source: source,
        destination: destination,
        architecture: 'x86_64',
        diagnosticContext: 'Target: ios-x86_64; SDK: iPhoneSimulator',
        runner: failingRunner,
      ),
      throwsA(isA<AppleBinaryException>()),
    );
    expect(destination.existsSync(), isFalse);
  });

  test(
    'fails when the post-thin output is not one verified architecture',
    () async {
      final source = File('${tempRoot.path}/fat-output-error')
        ..writeAsBytesSync([5]);
      final destination = File('${tempRoot.path}/invalid-output');
      final architectures = <String, Set<String>>{
        source.path: {'arm64', 'x86_64'},
      };

      Future<ProcessResult> invalidOutputRunner(
        String executable,
        List<String> args,
      ) async {
        if (args.contains('-thin')) {
          final output = args[args.indexOf('-output') + 1];
          File(output).writeAsBytesSync([5]);
          architectures[output] = {'arm64', 'x86_64'};
          return ProcessResult(0, 0, '', '');
        }
        return _fakeLipo(architectures)(executable, args);
      }

      await expectLater(
        materializeAppleBinary(
          source: source,
          destination: destination,
          architecture: 'arm64',
          diagnosticContext: 'Target: macos-arm64; SDK: macOS',
          runner: invalidOutputRunner,
        ),
        throwsA(
          predicate<AppleBinaryException>(
            (error) => error.message.contains('expected only arm64'),
          ),
        ),
      );
    },
  );
}

AppleCommandRunner _fakeLipo(Map<String, Set<String>> architectures) =>
    (executable, args) async {
      if (args.length >= 3 && args[1] == '-info') {
        final path = args[2];
        final values = architectures[path] ?? const <String>{};
        final output = values.length > 1
            ? 'Architectures in the fat file: $path are: ${values.join(' ')}'
            : 'Non-fat file: $path is architecture: ${values.single}';
        return ProcessResult(0, 0, output, '');
      }
      if (args.contains('-thin')) {
        final output = args[args.indexOf('-output') + 1];
        final architecture = args[args.indexOf('-thin') + 1];
        File(output).writeAsBytesSync([9]);
        architectures[output] = {architecture};
        return ProcessResult(0, 0, '', '');
      }
      if (args.contains('-verify_arch')) {
        final verifyIndex = args.indexOf('-verify_arch');
        final architecture = args[verifyIndex + 1];
        final path = args.sublist(1, verifyIndex).single;
        final valid =
            architectures[path]?.length == 1 &&
            architectures[path]!.contains(architecture);
        return ProcessResult(valid ? 0 : 1, valid ? 0 : 1, '', '');
      }
      return ProcessResult(1, 1, '', 'unknown fake lipo command');
    };
