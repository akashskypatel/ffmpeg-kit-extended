import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ffmpeg_kit_extended_flutter_example/main.dart';

void main() {
  testWidgets('exposes the semantic selector contract', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 100));

    for (final id in [
      'app.root',
      'logs.output',
      'toolbar.log-level',
      'toolbar.system-info',
      'toolbar.clear-logs',
      'toolbar.permissions',
      'tab.ffmpeg',
      'tab.stream',
      'tab.ffprobe',
      'tab.ffplay',
      'tab.transcode',
      'ffmpeg.generate-video',
      'ffmpeg.generate-audio',
      'ffmpeg.version.async',
      'ffmpeg.version.awaited',
      'ffmpeg.help',
      'ffmpeg.command.input',
      'ffmpeg.command.run',
    ]) {
      expect(find.byKey(ValueKey<String>(id)), findsOneWidget, reason: id);
    }

    await tester.tap(find.byKey(const ValueKey<String>('tab.stream')));
    await tester.pumpAndSettle();
    for (final id in ['stream.url.input', 'stream.record', 'stream.refresh']) {
      expect(find.byKey(ValueKey<String>(id)), findsOneWidget, reason: id);
    }

    await tester.tap(find.byKey(const ValueKey<String>('tab.ffprobe')));
    await tester.pumpAndSettle();
    for (final id in [
      'ffprobe.pick-file',
      'ffprobe.media-info',
      'ffprobe.version.async',
      'ffprobe.version.awaited',
      'ffprobe.command.input',
      'ffprobe.command.run',
    ]) {
      expect(find.byKey(ValueKey<String>(id)), findsOneWidget, reason: id);
    }

    await tester.tap(find.byKey(const ValueKey<String>('tab.ffplay')));
    await tester.pumpAndSettle();
    for (final id in [
      'ffplay.generate-video',
      'ffplay.generate-audio',
      'ffplay.play-video',
      'ffplay.play-audio',
      'ffplay.pause',
      'ffplay.resume',
      'ffplay.stop',
      'ffplay.seek-back',
      'ffplay.seek-forward',
      'ffplay.command.input',
      'ffplay.command.run',
    ]) {
      expect(find.byKey(ValueKey<String>(id)), findsOneWidget, reason: id);
    }

    await tester.tap(find.byKey(const ValueKey<String>('tab.transcode')));
    await tester.pumpAndSettle();
    for (final id in ['transcode.pick-input', 'transcode.run']) {
      expect(find.byKey(ValueKey<String>(id)), findsOneWidget, reason: id);
    }
  });
}
