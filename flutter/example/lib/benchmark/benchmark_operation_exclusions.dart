Map<String, String> parseBenchmarkNotMeasuredOperations(
  String operationIds,
  String reason,
) {
  final ids = <String>{
    for (final value in operationIds.split(','))
      if (value.trim().isNotEmpty) value.trim(),
  };
  if (ids.isEmpty) return const <String, String>{};

  final normalizedReason = reason.trim();
  if (normalizedReason.isEmpty) {
    throw ArgumentError.value(reason, 'reason', 'must explain the exclusion');
  }
  return Map<String, String>.unmodifiable(<String, String>{
    for (final id in ids) id: normalizedReason,
  });
}
