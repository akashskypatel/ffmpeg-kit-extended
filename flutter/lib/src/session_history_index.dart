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
  int _nextCreationOrder = 0;

  Iterable<SessionHistoryEntry> get entries => _entries.values;

  SessionHistoryEntry? operator [](int sessionId) => _entries[sessionId];

  SessionHistoryEntry record(
    int sessionId,
    SessionHistoryType type, {
    Object? wrapper,
  }) {
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

  void clear() {
    _entries.clear();
    _nextCreationOrder = 0;
  }

  int get length => _entries.length;
}
