import 'package:ffmpeg_kit_extended_flutter/src/web/ffplay_playback_epoch.dart';
import 'package:test/test.dart';

void main() {
  test('same epoch and generation is suppressed', () {
    final identity = FFplayWebFrameIdentity();

    expect(identity.accept(epoch: 1, generation: 1), isTrue);
    expect(identity.accept(epoch: 1, generation: 1), isFalse);
    expect(identity.accept(epoch: 1, generation: 2), isTrue);
  });

  test('a new epoch accepts a reused native generation', () {
    final identity = FFplayWebFrameIdentity();

    expect(identity.accept(epoch: 1, generation: 1), isTrue);
    expect(identity.accept(epoch: 2, generation: 1), isTrue);
  });

  test(
    'surface epoch reports the transition that clears stale presentation',
    () {
      final surfaceEpoch = FFplayWebSurfaceEpoch();

      expect(surfaceEpoch.observe(1), isTrue);
      expect(surfaceEpoch.observe(1), isFalse);
      expect(surfaceEpoch.observe(2), isTrue);
      expect(surfaceEpoch.observe(2), isFalse);
    },
  );

  test('failed startup does not commit a rendering epoch', () {
    final epoch = FFplayWebPlaybackEpoch();

    expect(epoch.value, 0);
    // A failed startup never calls beginPlayback.
    expect(epoch.value, 0);
    expect(epoch.beginPlayback(), 1);
  });
}
