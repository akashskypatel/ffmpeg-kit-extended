import 'package:flutter_test/flutter_test.dart';

import 'package:ffmpeg_kit_extended_flutter/src/session_history_index.dart';

void main() {
  test('records stable identity, type, and creation order without ownership', () {
    final index = SessionHistoryIndex();

    final first = index.record(11, SessionHistoryType.ffmpeg);
    final second = index.record(12, SessionHistoryType.ffprobe);

    expect(first.sessionId, 11);
    expect(first.type, SessionHistoryType.ffmpeg);
    expect(first.creationOrder, lessThan(second.creationOrder));
    expect(index.length, 2);
    expect(first.visible, isTrue);
  });

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
}
