import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Test Crash', (WidgetTester tester) async {
    final completer = Completer<void>();
    FFmpegKit.executeAsync('-version', onComplete: (session) {
      completer.complete();
    });
    await completer.future;
    print("Done!");
  });
}
