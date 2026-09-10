import 'package:ffmpeg_kit_extended_flutter/src/platform/backend.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/web/statistics_dispatcher.dart';
import 'package:test/test.dart';

void main() {
  const snapshots = <StatisticsSnapshot?>[
    StatisticsSnapshot(
      timeElapsed: 100,
      time: 90,
      size: 1,
      bitrate: 2,
      speed: 3,
      videoFrameNumber: 4,
      videoFps: 5,
      videoQuality: 6,
      dupFrames: 0,
      dropFrames: 0,
    ),
    null,
    StatisticsSnapshot(
      timeElapsed: 200,
      time: 190,
      size: 7,
      bitrate: 8,
      speed: 9,
      videoFrameNumber: 10,
      videoFps: 11,
      videoQuality: 12,
      dupFrames: 1,
      dropFrames: 2,
    ),
  ];

  test('drains each new snapshot once and advances past null entries', () {
    final delivered = <StatisticsSnapshot>[];

    final processed = dispatchStatisticsSnapshots(
      statisticsProcessed: 0,
      count: snapshots.length,
      getSnapshot: snapshots.elementAt,
      onSnapshot: delivered.add,
    );

    expect(processed, snapshots.length);
    expect(delivered, [snapshots[0], snapshots[2]]);
  });

  test('does not redeliver snapshots already processed', () {
    final delivered = <StatisticsSnapshot>[];

    final processed = dispatchStatisticsSnapshots(
      statisticsProcessed: snapshots.length,
      count: snapshots.length,
      getSnapshot: snapshots.elementAt,
      onSnapshot: delivered.add,
    );

    expect(processed, snapshots.length);
    expect(delivered, isEmpty);
  });
}
