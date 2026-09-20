import 'package:meta/meta.dart';

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
  final compatible = candidates.where((candidate) => candidate.supports(request));
  return compatible.isEmpty
      ? null
      : (compatible.toList()..sort((a, b) => a.identifier.compareTo(b.identifier))).first;
}

String describeAppleSlices(Iterable<AppleSliceCandidate> candidates) {
  final values = candidates.map((candidate) => candidate.toString()).toList()..sort();
  return values.isEmpty ? '(none)' : values.join(', ');
}
