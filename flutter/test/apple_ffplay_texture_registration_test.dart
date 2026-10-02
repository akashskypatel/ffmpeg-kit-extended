import 'dart:io';

import 'package:test/test.dart';

void main() {
  final sources = <String, String>{
    'CocoaPods': 'ios/Classes/FfplayKitPlugin.m',
    'SwiftPM':
        'ios/ffmpeg_kit_extended_flutter/Classes/ffmpeg_kit_native/'
        'FfplayKitPlugin.m',
  };

  test(
    'both Apple packaging sources reject failed texture registration before publication',
    () {
      final packageRoot = _findPackageRoot();
      String? expectedCode;
      String? expectedMessage;

      for (final entry in sources.entries) {
        final source = File(_join(packageRoot.path, entry.value));
        expect(
          source.existsSync(),
          isTrue,
          reason: '${entry.key} source is missing',
        );

        final contents = source.readAsStringSync();
        final methodStart = contents.indexOf('- (void)handleCreateTexture:');
        final methodEnd = contents.indexOf(
          '- (void)handleReleaseTexture:',
          methodStart,
        );
        expect(
          methodStart,
          greaterThanOrEqualTo(0),
          reason: '${entry.key} create method is missing',
        );
        expect(
          methodEnd,
          greaterThan(methodStart),
          reason: '${entry.key} create method boundary is missing',
        );

        final method = contents.substring(methodStart, methodEnd);
        final registration = method.indexOf(
          'int64_t tid = [_textureRegistry registerTexture:tex];',
        );
        final failureGuard = method.indexOf('if (tid == 0)', registration);
        final failureCode = method.indexOf(
          'TEXTURE_REGISTRATION_FAILED',
          failureGuard,
        );
        final failureMessage = method.indexOf(
          'Flutter could not register the FFplay texture',
          failureGuard,
        );
        final failureReturn = method.indexOf('return;', failureGuard);

        expect(
          registration,
          greaterThanOrEqualTo(0),
          reason: '${entry.key} does not assign registerTexture result',
        );
        expect(
          failureGuard,
          greaterThan(registration),
          reason: '${entry.key} does not check the Darwin failure sentinel',
        );
        expect(failureCode, greaterThan(failureGuard));
        expect(failureMessage, greaterThan(failureGuard));
        expect(failureReturn, greaterThan(failureMessage));

        final publicationAnchors = <String>[
          'tex.onFrameAvailable',
          '_texture = tex',
          '_textureId = tid',
          '__bridge_retained',
          'FfplayInstallOwner',
          'result(@{@"textureId" : @(tid)})',
        ];
        for (final anchor in publicationAnchors) {
          final publication = method.indexOf(anchor, failureGuard);
          expect(
            publication,
            greaterThan(failureReturn),
            reason: '${entry.key} publishes $anchor before failure returns',
          );
        }

        final code = _quotedValue(method, failureCode, 'errorWithCode:@"');
        final message = _quotedValue(method, failureMessage, 'message:@"');
        expectedCode ??= code;
        expectedMessage ??= message;
        expect(code, expectedCode, reason: '${entry.key} error code diverges');
        expect(
          message,
          expectedMessage,
          reason: '${entry.key} error message diverges',
        );
      }
    },
  );
}

Directory _findPackageRoot() {
  var candidate = Directory.current;
  while (true) {
    final pubspec = File(_join(candidate.path, 'pubspec.yaml'));
    final iosDirectory = Directory(_join(candidate.path, 'ios'));
    if (pubspec.existsSync() && iosDirectory.existsSync()) return candidate;

    final parent = candidate.parent;
    if (parent.path == candidate.path) {
      throw StateError('Could not locate the Flutter package root');
    }
    candidate = parent;
  }
}

String _join(String base, String relative) =>
    '$base${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}';

String _quotedValue(String source, int start, String prefix) {
  final valueStart = source.indexOf(prefix, start);
  if (valueStart < 0) return '';
  final contentStart = valueStart + prefix.length;
  final contentEnd = source.indexOf('"', contentStart);
  return contentEnd < 0 ? '' : source.substring(contentStart, contentEnd);
}
