/// Immutable identity metadata used to project native session history without
/// retaining every Dart session object.
enum SessionHistoryType { ffmpeg, ffprobe, ffplay, mediaInformation }

final class SessionHistoryEntry {
  SessionHistoryEntry({
    required this.sessionId,
    required this.type,
    required this.creationOrder,
  });

  final int sessionId;
  final SessionHistoryType type;
  final int creationOrder;

  /// History visibility is separate from execution ownership.  `clearSessions`
  /// can hide an active entry while its callback/session owner remains alive.
  bool visible = true;

  /// Set only after the execution boundary observes a terminal native state.
  ///
  /// Keeping this marker in the identity index lets capacity pruning happen at
  /// completion time without issuing a history read.
  bool terminal = false;

  WeakReference<Object>? _wrapper;

  Object? get wrapper => _wrapper?.target;

  void cacheWrapper(Object wrapper) {
    _wrapper = WeakReference<Object>(wrapper);
  }

  void clearWrapper() {
    _wrapper = null;
  }
}

/// Bounded-by-identities session history metadata.
///
/// The index deliberately stores only immutable identity/type/order metadata
/// plus weak wrapper references.  It never becomes the owner of a Dart
/// session object or of a native handle.
final class SessionHistoryIndex {
  final Map<int, SessionHistoryEntry> _entries = {};
  final Set<int> _abandonedSessionIds = <int>{};
  int _nextCreationOrder = 0;

  Iterable<SessionHistoryEntry> get entries => _entries.values;

  /// Returns a snapshot of ID-only Created abandonment authorities.
  Iterable<int> get abandonedSessionIds => _abandonedSessionIds.toList();

  SessionHistoryEntry? operator [](int sessionId) => _entries[sessionId];

  /// Returns whether a Created identity was explicitly abandoned before
  /// execution. The tombstone is an ID-only authority; it never retains a
  /// wrapper or native handle.
  bool isAbandoned(int sessionId) => _abandonedSessionIds.contains(sessionId);

  SessionHistoryEntry record(
    int sessionId,
    SessionHistoryType type, {
    Object? wrapper,
  }) {
    if (isAbandoned(sessionId)) {
      throw StateError('Session $sessionId was abandoned before execution');
    }
    final entry = _entries[sessionId] ??= SessionHistoryEntry(
      sessionId: sessionId,
      type: type,
      creationOrder: _nextCreationOrder++,
    );
    if (wrapper != null) entry.cacheWrapper(wrapper);
    return entry;
  }

  void remove(int sessionId) {
    _entries.remove(sessionId);
  }

  /// Makes a Created identity permanently non-reconstructable until the
  /// history authority is cleared.
  void abandon(int sessionId) {
    _entries.remove(sessionId);
    _abandonedSessionIds.add(sessionId);
  }

  /// Removes one abandonment authority after an independent backend probe has
  /// proved that the native identity no longer exists.
  void removeAbandoned(int sessionId) {
    _abandonedSessionIds.remove(sessionId);
  }

  /// Clears only abandonment authorities after a successful native history
  /// clear, preserving unrelated creation-order state for live wrappers.
  void clearAbandoned() {
    _abandonedSessionIds.clear();
  }

  /// Removes an identity that was hidden by a history clear while live.
  ///
  /// Hidden entries are outside public retained history and must not become
  /// invisible terminal metadata after their execution settles.
  bool removeHidden(int sessionId) {
    final entry = _entries[sessionId];
    if (entry == null || entry.visible) return false;
    _entries.remove(sessionId);
    return true;
  }

  void markTerminal(int sessionId) {
    _entries[sessionId]?.terminal = true;
  }

  /// Removes the oldest terminal identities until terminal metadata fits the
  /// native history capacity. Live identities are never removed here.
  void pruneTerminal(int capacity) {
    if (capacity < 0) return;
    final terminalEntries =
        _entries.values
            .where((entry) => entry.visible && entry.terminal)
            .toList()
          ..sort((left, right) => left.creationOrder - right.creationOrder);
    final removeCount = terminalEntries.length - capacity;
    if (removeCount <= 0) return;
    for (final entry in terminalEntries.take(removeCount)) {
      _entries.remove(entry.sessionId);
    }
  }

  void clear() {
    _entries.clear();
    _abandonedSessionIds.clear();
    _nextCreationOrder = 0;
  }

  int get length => _entries.length;
}
