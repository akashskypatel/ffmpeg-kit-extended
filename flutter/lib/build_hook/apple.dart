import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

/// The platform/SDK/architecture tuple requested by one Apple hook run.
@immutable
class AppleSliceRequest {
  final String platform;
  final String? variant;
  final String architecture;

  const AppleSliceRequest({
    required this.platform,
    required this.variant,
    required this.architecture,
  });

  @override
  String toString() =>
      '$platform${variant == null ? '' : '-$variant'}-$architecture';
}

/// A single `AvailableLibraries` entry from an XCFramework Info.plist.
@immutable
class AppleSliceCandidate {
  final String identifier;
  final String libraryPath;
  final String platform;
  final String? variant;
  final Set<String> architectures;

  AppleSliceCandidate({
    required this.identifier,
    required this.libraryPath,
    required this.platform,
    required this.variant,
    required Set<String> architectures,
  }) : architectures = Set.unmodifiable(architectures);

  bool supports(AppleSliceRequest request) =>
      platform == request.platform &&
      variant == request.variant &&
      architectures.contains(request.architecture);

  @override
  String toString() =>
      '$identifier ($platform${variant == null ? '' : '-$variant'}; '
      '${architectures.toList()..sort()})';
}

/// Selects an XCFramework entry without relying on directory enumeration order.
AppleSliceCandidate? selectAppleSlice(
  Iterable<AppleSliceCandidate> candidates,
  AppleSliceRequest request,
) {
  final compatible = candidates.where(
    (candidate) => candidate.supports(request),
  );
  return compatible.isEmpty
      ? null
      : (compatible.toList()
              ..sort((a, b) => a.identifier.compareTo(b.identifier)))
            .first;
}

String describeAppleSlices(Iterable<AppleSliceCandidate> candidates) {
  final values = candidates.map((candidate) => candidate.toString()).toList()
    ..sort();
  return values.isEmpty ? '(none)' : values.join(', ');
}

String appleSliceSelectionFailureMessage({
  required AppleSliceRequest request,
  required String root,
  required Iterable<AppleSliceCandidate> candidates,
}) {
  final available = describeAppleSlices(candidates);
  if (request.platform == 'ios' &&
      request.variant == 'simulator' &&
      request.architecture == 'x86_64') {
    return 'iOS simulator x86_64 was requested, but no compatible x86_64 '
        'XCFramework slice exists in $root. Available slices: $available. '
        'An arm64-only simulator artifact cannot be copied or relabeled as '
        'x86_64, and Podfile EXCLUDED_ARCHS cannot manufacture a hook asset.';
  }
  return 'Could not find Apple slice for $request in $root. Available slices: '
      '$available';
}

/// Reads the small subset of the XCFramework property list needed for slice
/// selection. XCFramework Info.plists are XML, so keeping this parser local
/// avoids making the build hook depend on a platform-specific plist utility.
List<AppleSliceCandidate> readAppleSliceCandidates(File infoPlist) {
  final document = _PlistParser(infoPlist.readAsStringSync()).parse();
  final libraries = document is Map ? document['AvailableLibraries'] : null;
  if (libraries is! List) return const [];

  return [
    for (final library in libraries.whereType<Map>())
      if (library['LibraryIdentifier'] is String &&
          library['LibraryPath'] is String &&
          library['SupportedPlatform'] is String)
        AppleSliceCandidate(
          identifier: library['LibraryIdentifier'] as String,
          libraryPath: library['LibraryPath'] as String,
          platform: library['SupportedPlatform'] as String,
          variant: library['SupportedPlatformVariant'] as String?,
          architectures: {
            for (final architecture
                in (library['SupportedArchitectures'] is List
                    ? (library['SupportedArchitectures'] as List)
                    : const <Object?>[]))
              if (architecture is String) architecture,
          },
        ),
  ];
}

/// Builds a narrow filename-layout fallback for older/nonstandard archives.
/// The caller must still inspect the selected Mach-O before emitting it.
List<AppleSliceCandidate> filenameAppleSliceCandidates(
  Directory xcframeworkRoot, {
  required String platform,
  required String? variant,
}) {
  if (!xcframeworkRoot.existsSync()) return const [];
  final prefix = '$platform-';
  return [
    for (final directory
        in xcframeworkRoot.listSync(followLinks: false).whereType<Directory>())
      if (p.basename(directory.path).startsWith(prefix))
        if (_filenameSliceVariant(p.basename(directory.path), platform) ==
            variant)
          AppleSliceCandidate(
            identifier: p.basename(directory.path),
            libraryPath: 'ffmpegkit.framework',
            platform: platform,
            variant: variant,
            architectures: _filenameSliceArchitectures(
              p.basename(directory.path),
              platform,
              variant,
            ),
          ),
  ];
}

String? _filenameSliceVariant(String identifier, String platform) {
  if (platform == 'ios' && identifier.endsWith('-simulator')) {
    return 'simulator';
  }
  return null;
}

Set<String> _filenameSliceArchitectures(
  String identifier,
  String platform,
  String? variant,
) {
  var architecturePart = identifier.substring('$platform-'.length);
  if (variant != null) {
    architecturePart = architecturePart.replaceFirst('-$variant', '');
  }
  return architecturePart.split('_').where((value) => value.isNotEmpty).toSet();
}

class _PlistParser {
  final List<String> _tokens;
  var _index = 0;

  _PlistParser(String source)
    : _tokens = RegExp(
        r'<[^>]*>|[^<]+',
      ).allMatches(source).map((match) => match.group(0)!).toList();

  Object? parse() {
    while (_index < _tokens.length) {
      final token = _tokens[_index];
      if (token.startsWith('<plist')) {
        _index++;
        return _parseValue();
      }
      _index++;
    }
    return null;
  }

  Object? _parseValue() {
    _skipWhitespace();
    if (_index >= _tokens.length) return null;
    final token = _tokens[_index];
    if (token.startsWith('<dict')) return _parseDict();
    if (token.startsWith('<array')) return _parseArray();
    if (token.startsWith('<string')) return _parseScalar('string');
    if (token.startsWith('<integer')) return _parseScalar('integer');
    if (token.startsWith('<real')) return _parseScalar('real');
    if (token.startsWith('<true')) {
      _index++;
      return true;
    }
    if (token.startsWith('<false')) {
      _index++;
      return false;
    }
    _index++;
    return null;
  }

  Map<String, Object?> _parseDict() {
    _index++;
    final result = <String, Object?>{};
    while (_index < _tokens.length) {
      _skipWhitespace();
      if (_tokens[_index].startsWith('</dict')) {
        _index++;
        break;
      }
      final key = _parseScalar('key');
      result[key?.toString() ?? ''] = _parseValue();
    }
    return result;
  }

  List<Object?> _parseArray() {
    _index++;
    final result = <Object?>[];
    while (_index < _tokens.length) {
      _skipWhitespace();
      if (_tokens[_index].startsWith('</array')) {
        _index++;
        break;
      }
      result.add(_parseValue());
    }
    return result;
  }

  String? _parseScalar(String name) {
    final opening = _tokens[_index++];
    if (opening.endsWith('/>')) return '';
    final closing = '</$name>';
    final buffer = StringBuffer();
    while (_index < _tokens.length && _tokens[_index] != closing) {
      buffer.write(_tokens[_index++]);
    }
    if (_index < _tokens.length) _index++;
    return _decodeXml(buffer.toString().trim());
  }

  void _skipWhitespace() {
    while (_index < _tokens.length &&
        !_tokens[_index].startsWith('<') &&
        _tokens[_index].trim().isEmpty) {
      _index++;
    }
  }
}

String _decodeXml(String value) => value
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

typedef AppleCommandRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

class AppleBinaryException implements Exception {
  final String message;

  const AppleBinaryException(this.message);

  @override
  String toString() => message;
}

class AppleBinaryVerification {
  final Set<String> sourceArchitectures;
  final Set<String> outputArchitectures;

  const AppleBinaryVerification({
    required this.sourceArchitectures,
    required this.outputArchitectures,
  });
}

Set<String> parseAppleLipoArchitectures(String output) {
  final fatMatch = RegExp(
    r'\bare:\s*(.+)',
    caseSensitive: false,
  ).firstMatch(output);
  if (fatMatch != null) {
    return fatMatch
        .group(1)!
        .trim()
        .split(RegExp(r'\s+'))
        .where((architecture) => architecture.isNotEmpty)
        .toSet();
  }

  final thinMatch = RegExp(
    r'\bis architecture:\s*([^\s]+)',
    caseSensitive: false,
  ).firstMatch(output);
  return thinMatch == null ? const {} : {thinMatch.group(1)!};
}

Future<ProcessResult> _runAppleCommand(
  String executable,
  List<String> arguments,
) => Process.run(executable, arguments);

Future<Set<String>> inspectAppleBinaryArchitectures(
  File binary, {
  AppleCommandRunner runner = _runAppleCommand,
}) async {
  final result = await runner('xcrun', ['lipo', '-info', binary.path]);
  final output = '${result.stdout}\n${result.stderr}';
  if (result.exitCode != 0) {
    throw AppleBinaryException(
      'Unable to inspect Apple binary ${binary.path}: ${output.trim()}',
    );
  }
  final architectures = parseAppleLipoArchitectures(output);
  if (architectures.isEmpty) {
    throw AppleBinaryException(
      'Apple binary ${binary.path} reported no architectures: ${output.trim()}',
    );
  }
  return architectures;
}

Future<AppleBinaryVerification> materializeAppleBinary({
  required File source,
  required File destination,
  required String architecture,
  required String diagnosticContext,
  AppleCommandRunner runner = _runAppleCommand,
}) async {
  if (destination.existsSync()) destination.deleteSync();

  final sourceArchitectures = await inspectAppleBinaryArchitectures(
    source,
    runner: runner,
  );
  if (!sourceArchitectures.contains(architecture)) {
    throw AppleBinaryException(
      '$diagnosticContext: requested architecture $architecture is not '
      'available in ${source.path}; detected architectures: '
      '${sourceArchitectures.toList()..sort()}',
    );
  }

  if (sourceArchitectures.length > 1) {
    final result = await runner('xcrun', [
      'lipo',
      source.path,
      '-thin',
      architecture,
      '-output',
      destination.path,
    ]);
    if (result.exitCode != 0) {
      throw AppleBinaryException(
        '$diagnosticContext: lipo failed while selecting $architecture from '
        '${source.path}: ${result.stderr}',
      );
    }
  } else {
    source.copySync(destination.path);
  }

  final outputArchitectures = await inspectAppleBinaryArchitectures(
    destination,
    runner: runner,
  );
  if (outputArchitectures.length != 1 ||
      !outputArchitectures.contains(architecture)) {
    throw AppleBinaryException(
      '$diagnosticContext: output ${destination.path} has architectures '
      '${outputArchitectures.toList()..sort()}, expected only $architecture',
    );
  }

  final verification = await runner('xcrun', [
    'lipo',
    destination.path,
    '-verify_arch',
    architecture,
  ]);
  if (verification.exitCode != 0) {
    throw AppleBinaryException(
      '$diagnosticContext: lipo verification failed for $architecture at '
      '${destination.path}: ${verification.stderr}',
    );
  }
  return AppleBinaryVerification(
    sourceArchitectures: sourceArchitectures,
    outputArchitectures: outputArchitectures,
  );
}
