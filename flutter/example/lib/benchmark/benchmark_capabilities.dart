class FfmpegCapabilities {
  const FfmpegCapabilities({
    required this.encoders,
    required this.decoders,
    required this.filters,
    this.failures = const <String, String>{},
  });

  final Set<String> encoders;
  final Set<String> decoders;
  final Set<String> filters;
  final Map<String, String> failures;

  String? missingRequirement({
    String? encoder,
    String? decoder,
    Iterable<String> requiredFilters = const <String>[],
  }) {
    if (encoder != null && !encoders.contains(encoder)) {
      return failures['encoder:$encoder'] ?? 'encoder $encoder is unavailable';
    }
    if (decoder != null && !decoders.contains(decoder)) {
      return failures['decoder:$decoder'] ?? 'decoder $decoder is unavailable';
    }
    for (final filter in requiredFilters) {
      if (!filters.contains(filter)) {
        return failures['filter:$filter'] ?? 'filter $filter is unavailable';
      }
    }
    return null;
  }

  Map<String, Object> toJson() => <String, Object>{
    'encoders': encoders.toList()..sort(),
    'decoders': decoders.toList()..sort(),
    'filters': filters.toList()..sort(),
    'failures': failures,
  };
}
