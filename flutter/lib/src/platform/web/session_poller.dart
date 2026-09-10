import 'dart:async';

/// Tracks active Web session pollers and guarantees cleanup after completion
/// or failure.
final class SessionPollRegistry {
  final Set<int> _activeSessions = <int>{};

  bool add(int sessionId) => _activeSessions.add(sessionId);

  void remove(int sessionId) => _activeSessions.remove(sessionId);

  bool contains(int sessionId) => _activeSessions.contains(sessionId);

  Future<void> run(int sessionId, Future<void> Function() action) {
    if (!add(sessionId)) return Future<void>.value();
    return Future<void>.sync(action).whenComplete(() => remove(sessionId));
  }
}

/// Runs the WebAssembly session poll loop with injectable transport and
/// callback operations.
Future<void> pollSessionUntilTerminal({
  required int Function() getState,
  required void Function() dispatchLogs,
  required void Function() dispatchStatistics,
  required void Function() onComplete,
  Duration interval = const Duration(milliseconds: 16),
}) async {
  while (true) {
    dispatchLogs();
    dispatchStatistics();
    if (getState() >= 2) break;
    await Future<void>.delayed(interval);
  }

  // Drain work emitted between the last poll and the terminal state.
  dispatchLogs();
  dispatchStatistics();
  onComplete();
}
