// test/flutter_test_config.dart
import 'dart:async';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Enable leak tracking globally for all tests in this directory
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withTrackedAll();

  await testMain();
}
