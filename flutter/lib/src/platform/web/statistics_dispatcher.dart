import '../backend.dart';

/// Dispatches newly appended statistics snapshots exactly once.
///
/// Web execution reads statistics from the Wasm session buffer because the
/// published bundle cannot install native callback function pointers. Keeping
/// the cursor in this helper lets synchronous execution and the asynchronous
/// poller share the same drain semantics.
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
