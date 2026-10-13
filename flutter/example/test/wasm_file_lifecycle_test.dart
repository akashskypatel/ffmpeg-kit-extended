import 'package:flutter_test/flutter_test.dart';

import 'package:ffmpeg_kit_extended_flutter_example/main.dart';

void main() {
  group('WebMediaOperationLeaseManager', () {
    test('keeps retired paths until every custom operation releases', () {
      final retiredPaths = <String>{'A'};
      var sessionsUsingA = 2;
      var deleteCount = 0;
      late WebMediaOperationLeaseManager leases;

      void cleanup() {
        if (leases.activeCount > 0 || sessionsUsingA > 0) return;
        if (retiredPaths.remove('A')) deleteCount++;
      }

      leases = WebMediaOperationLeaseManager();
      final releaseFirst = leases.begin(cleanup);
      final releaseSecond = leases.begin(cleanup);

      releaseSecond();
      sessionsUsingA--;
      expect(leases.activeCount, 1);
      expect(retiredPaths, contains('A'));
      expect(deleteCount, 0);

      sessionsUsingA--;
      releaseFirst();
      expect(leases.activeCount, 0);
      expect(retiredPaths, isEmpty);
      expect(deleteCount, 1);
    });

    test('retries cleanup when a terminal signal follows lease release', () {
      final retiredPaths = <String>{'A'};
      var sessionRunning = true;
      var deleteCount = 0;
      late WebMediaOperationLeaseManager leases;

      void cleanup() {
        if (leases.activeCount > 0 || sessionRunning) return;
        if (retiredPaths.remove('A')) deleteCount++;
      }

      leases = WebMediaOperationLeaseManager();
      final release = leases.begin(cleanup);

      release();
      expect(leases.activeCount, 0);
      expect(retiredPaths, contains('A'));

      sessionRunning = false;
      release();
      release();
      expect(retiredPaths, isEmpty);
      expect(deleteCount, 1);
    });
  });
}
