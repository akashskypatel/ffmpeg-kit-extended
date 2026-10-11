// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../lib/benchmark/benchmark_adapter.dart';
import '../lib/benchmark/benchmark_core.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native FFmpeg library benchmark', (tester) async {
    final adapter = createBenchmarkAdapter();
    await tester.runAsync(() => runBenchmarkHarness(adapter));
  }, timeout: const Timeout(Duration(hours: 1)));
}
