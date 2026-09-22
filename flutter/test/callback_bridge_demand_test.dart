import 'package:ffmpeg_kit_extended_flutter/src/callback_manager.dart';
import 'package:ffmpeg_kit_extended_flutter/src/log.dart';
import 'package:ffmpeg_kit_extended_flutter/src/statistics.dart';
import 'package:test/test.dart';

void main() {
  final manager = CallbackManager();

  void clearGlobalCallbacks() {
    manager.setGlobalLogCallback(null, install: () {}, uninstall: () {});
    manager.setGlobalStatisticsCallback(null, install: () {}, uninstall: () {});
    manager.setGlobalFFmpegSessionCompleteCallback(
      null,
      install: () {},
      uninstall: () {},
    );
    manager.setGlobalFFprobeSessionCompleteCallback(
      null,
      install: () {},
      uninstall: () {},
    );
    manager.setGlobalFFplaySessionCompleteCallback(
      null,
      install: () {},
      uninstall: () {},
    );
    manager.setGlobalMediaInformationSessionCompleteCallback(
      null,
      install: () {},
      uninstall: () {},
    );
    manager.globalLogCallback = null;
    manager.globalStatisticsCallback = null;
    manager.globalFFmpegSessionCompleteCallback = null;
    manager.globalFFprobeSessionCompleteCallback = null;
    manager.globalFFplaySessionCompleteCallback = null;
    manager.globalMediaInformationSessionCompleteCallback = null;
  }

  setUp(clearGlobalCallbacks);
  tearDown(clearGlobalCallbacks);

  test('installs once and uninstalls after the last lease', () {
    var installs = 0;
    var uninstalls = 0;

    final first = manager.acquireBridge(
      CallbackBridgeKind.log,
      install: () => installs++,
      uninstall: () => uninstalls++,
    );
    final second = manager.acquireBridge(
      CallbackBridgeKind.log,
      install: () => installs++,
      uninstall: () => uninstalls++,
    );

    expect(installs, 1);
    expect(manager.bridgeLeaseCount(CallbackBridgeKind.log), 2);
    expect(manager.isBridgeActive(CallbackBridgeKind.log), isTrue);

    first.release();
    first.release();
    expect(uninstalls, 0);
    expect(manager.bridgeLeaseCount(CallbackBridgeKind.log), 1);

    second.release();
    expect(uninstalls, 1);
    expect(manager.bridgeLeaseCount(CallbackBridgeKind.log), 0);
    expect(manager.isBridgeActive(CallbackBridgeKind.log), isFalse);
  });

  test('failed installation leaves the bridge unowned', () {
    expect(
      () => manager.acquireBridge(
        CallbackBridgeKind.statistics,
        install: () => throw StateError('install failed'),
        uninstall: () {},
      ),
      throwsA(isA<StateError>()),
    );

    expect(manager.bridgeLeaseCount(CallbackBridgeKind.statistics), 0);
    expect(manager.isBridgeActive(CallbackBridgeKind.statistics), isFalse);
  });

  test('failed uninstall resets ownership so the bridge can be retried', () {
    var installs = 0;
    var shouldThrow = true;

    final first = manager.acquireBridge(
      CallbackBridgeKind.ffmpegCompletion,
      install: () => installs++,
      uninstall: () {
        if (shouldThrow) {
          shouldThrow = false;
          throw StateError('uninstall failed');
        }
      },
    );

    expect(first.release, throwsA(isA<StateError>()));
    expect(manager.bridgeLeaseCount(CallbackBridgeKind.ffmpegCompletion), 0);
    expect(
      manager.isBridgeActive(CallbackBridgeKind.ffmpegCompletion),
      isFalse,
    );

    final retry = manager.acquireBridge(
      CallbackBridgeKind.ffmpegCompletion,
      install: () => installs++,
      uninstall: () {},
    );
    expect(installs, 2);
    retry.release();
  });

  test('completion and optional statistics demand are independent', () {
    final completionLease = manager.acquireBridge(
      CallbackBridgeKind.ffmpegCompletion,
      install: () {},
      uninstall: () {},
    );
    final statisticsLease = manager.acquireBridge(
      CallbackBridgeKind.statistics,
      install: () {},
      uninstall: () {},
    );

    statisticsLease.release();
    expect(manager.isBridgeActive(CallbackBridgeKind.ffmpegCompletion), isTrue);
    expect(manager.isBridgeActive(CallbackBridgeKind.statistics), isFalse);

    completionLease.release();
    expect(
      manager.isBridgeActive(CallbackBridgeKind.ffmpegCompletion),
      isFalse,
    );
  });

  test(
    'global callback setter owns one lease and rolls back failed install',
    () {
      var installs = 0;
      var uninstalls = 0;

      manager.setGlobalLogCallback(
        (Log _) {},
        install: () => installs++,
        uninstall: () => uninstalls++,
      );
      manager.setGlobalLogCallback(
        (Log _) {},
        install: () => installs++,
        uninstall: () => uninstalls++,
      );

      expect(installs, 1);
      expect(manager.bridgeLeaseCount(CallbackBridgeKind.log), 1);

      manager.setGlobalLogCallback(null, install: () {}, uninstall: () {});
      expect(uninstalls, 1);
      expect(manager.globalLogCallback, isNull);

      expect(
        () => manager.setGlobalStatisticsCallback(
          (Statistics _) {},
          install: () => throw StateError('install failed'),
          uninstall: () {},
        ),
        throwsA(isA<StateError>()),
      );
      expect(manager.globalStatisticsCallback, isNull);
      expect(manager.bridgeLeaseCount(CallbackBridgeKind.statistics), 0);
    },
  );
}
