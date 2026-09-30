import 'package:flutter_test/flutter_test.dart';

import 'package:ffmpeg_kit_extended_flutter/src/session_history_index.dart';

void main() {
  test(
    'records stable identity, type, and creation order without ownership',
    () {
      final index = SessionHistoryIndex();

      final first = index.record(11, SessionHistoryType.ffmpeg);
      final second = index.record(12, SessionHistoryType.ffprobe);

      expect(first.sessionId, 11);
      expect(first.type, SessionHistoryType.ffmpeg);
      expect(first.creationOrder, lessThan(second.creationOrder));
      expect(index.length, 2);
      expect(first.visible, isTrue);
    },
  );

  test('re-recording an identity does not reorder or re-show it', () {
    final index = SessionHistoryIndex();
    final entry = index.record(21, SessionHistoryType.ffplay);
    entry.visible = false;

    final rerecorded = index.record(21, SessionHistoryType.ffplay);

    expect(identical(rerecorded, entry), isTrue);
    expect(rerecorded.creationOrder, entry.creationOrder);
    expect(rerecorded.visible, isFalse);
  });

  test('wrapper cache is weak and can be cleared independently', () {
    final index = SessionHistoryIndex();
    final entry = index.record(31, SessionHistoryType.mediaInformation);
    final wrapper = Object();

    entry.cacheWrapper(wrapper);
    expect(identical(entry.wrapper, wrapper), isTrue);

    entry.clearWrapper();
    expect(entry.wrapper, isNull);
  });

  test('clear removes all metadata and resets creation ordering', () {
    final index = SessionHistoryIndex();
    index.record(41, SessionHistoryType.ffmpeg);
    index.clear();

    final next = index.record(42, SessionHistoryType.ffmpeg);
    expect(index.length, 1);
    expect(next.creationOrder, 0);
  });

  test('completion pruning removes oldest terminal identities only', () {
    final index = SessionHistoryIndex();
    index.record(51, SessionHistoryType.ffmpeg);
    index.record(52, SessionHistoryType.ffprobe);
    index.record(53, SessionHistoryType.ffplay);
    index.markTerminal(51);
    index.markTerminal(52);

    index.pruneTerminal(1);

    expect(index[51], isNull);
    expect(index[52], isNotNull);
    expect(index[53], isNotNull);
    expect(index[53]!.terminal, isFalse);
  });

  test('non-terminal disposal can remove a live identity', () {
    final index = SessionHistoryIndex();
    index.record(61, SessionHistoryType.mediaInformation);
    index.remove(61);

    expect(index.length, 0);
  });

  test('abandoned Created identities cannot be recorded again', () {
    final index = SessionHistoryIndex();
    index.record(65, SessionHistoryType.ffmpeg);

    index.abandon(65);

    expect(index[65], isNull);
    expect(index.isAbandoned(65), isTrue);
    expect(() => index.record(65, SessionHistoryType.ffmpeg), throwsStateError);

    index.clear();
    expect(index.isAbandoned(65), isFalse);
  });

  test('independent reconciliation removes only a proven dead tombstone', () {
    final index = SessionHistoryIndex();
    index.record(66, SessionHistoryType.ffmpeg);
    index.abandon(66);

    expect(index.abandonedSessionIds, contains(66));
    index.removeAbandoned(66);

    expect(index.isAbandoned(66), isFalse);
    expect(index.record(66, SessionHistoryType.ffmpeg).sessionId, 66);
  });

  test('clearAbandoned preserves live identity metadata', () {
    final index = SessionHistoryIndex();
    index.record(67, SessionHistoryType.ffprobe);
    index.abandon(68);

    index.clearAbandoned();

    expect(index.length, 1);
    expect(index[67], isNotNull);
    expect(index.isAbandoned(68), isFalse);
  });

  test('cancellation intent is independent from Created abandonment', () {
    final index = SessionHistoryIndex();

    index.recordCancellationIntent(69);
    expect(index.isCancellationRequested(69), isTrue);
    expect(index.isAbandoned(69), isFalse);

    index.abandon(69);
    expect(index.isCancellationRequested(69), isTrue);
    expect(index.isAbandoned(69), isTrue);

    index.clearCancellationIntent(69);
    expect(index.isCancellationRequested(69), isFalse);
    expect(index.isAbandoned(69), isTrue);

    index.clear();
    expect(index.isCancellationRequested(69), isFalse);
    expect(index.isAbandoned(69), isFalse);
  });

  test('hidden identities are removed when their live execution settles', () {
    final index = SessionHistoryIndex();
    final entry = index.record(71, SessionHistoryType.ffmpeg);
    entry.visible = false;
    entry.terminal = true;

    expect(index.removeHidden(71), isTrue);
    expect(index.removeHidden(71), isFalse);
    expect(index.length, 0);
  });
}
