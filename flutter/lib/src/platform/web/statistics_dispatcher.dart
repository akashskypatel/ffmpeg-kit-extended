import '../backend.dart';

/// Dispatches newly appended statistics snapshots exactly once.
///
/// Synchronous Web execution drains statistics from the Wasm session buffer
/// after the native call returns. Asynchronous execution receives statistics
/// through the generated callback bridge and does not use this helper.
int dispatchStatisticsSnapshots({
  required int statisticsProcessed,
  required int count,
  required StatisticsSnapshot? Function(int index) getSnapshot,
  required void Function(StatisticsSnapshot snapshot) onSnapshot,
}) {
  if (count <= statisticsProcessed) return statisticsProcessed;

  for (var index = statisticsProcessed; index < count; index++) {
    final snapshot = getSnapshot(index);
    if (snapshot != null) onSnapshot(snapshot);
  }
  return count;
}
