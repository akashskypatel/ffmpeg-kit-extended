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
