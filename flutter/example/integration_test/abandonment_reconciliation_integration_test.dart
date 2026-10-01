// ignore_for_file: avoid_print

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/backend_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(FFmpegKitExtended.initialize);

  tearDown(() {
    FFmpegKitExtended.clearSessions();
    FFmpegKitExtended.sessionHistoryIndex.clear();
  });

  test('Created abandonment oracle observes frozen native ID lifetime', () {
    final session = FFmpegSession.create('-hide_banner -version');
    final id = session.sessionId;

    session.cancel();
    expect(FFmpegKitExtended.isSessionAbandoned(id), isTrue);

    final temporaryHandle = ffmpegKitBackend.getSessionById(id);
    expect(temporaryHandle, isNotNull);
    expect(
      ffmpegKitBackend.getSessionState(temporaryHandle!),
      SessionState.created.value,
    );
    ffmpegKitBackend.releaseSession(temporaryHandle);

    session.dispose();
    final afterOwnerRelease = ffmpegKitBackend.getSessionById(id);
    final remainsAfterOwnerRelease = afterOwnerRelease != null;
    if (afterOwnerRelease != null) {
      ffmpegKitBackend.releaseSession(afterOwnerRelease);
    }

    // This is intentionally observational: the frozen ABI may retain a
    // Created history identity until clearSessions(). The output is recorded
    // in the Review 37 tracker and controls the wrapper reconciliation policy.
    print(
      'ABANDONMENT_ORACLE id=$id '
      'remainsAfterOwnerRelease=$remainsAfterOwnerRelease',
    );

    FFmpegKitExtended.clearSessions();
    expect(FFmpegKitExtended.isSessionAbandoned(id), isFalse);
  });

  test('history-capacity oracle observes Created eviction behavior', () {
    final previousCapacity = ffmpegKitBackend.getSessionHistorySize();
    ffmpegKitBackend.setSessionHistorySize(1);
    try {
      final first = FFmpegSession.create('-hide_banner -version');
      final second = FFmpegSession.create('-hide_banner -version');
      final firstProbe = ffmpegKitBackend.getSessionById(first.sessionId);
      final secondProbe = ffmpegKitBackend.getSessionById(second.sessionId);
      final firstRemains = firstProbe != null;
      final secondRemains = secondProbe != null;
      if (firstProbe != null) ffmpegKitBackend.releaseSession(firstProbe);
      if (secondProbe != null) ffmpegKitBackend.releaseSession(secondProbe);
      print(
        'HISTORY_CAPACITY_ORACLE firstRemains=$firstRemains '
        'secondRemains=$secondRemains',
      );
      first.dispose();
      second.dispose();
    } finally {
      ffmpegKitBackend.setSessionHistorySize(previousCapacity);
    }
  });
}
