// W-F05 (plan §P3.0a): the Web-only network guard does not run on native
// backends. A synchronous FFprobe over direct HTTP must still succeed natively.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:test/test.dart';

/// Serves [filePath] over loopback HTTP from a separate isolate.
///
/// A separate isolate is required because the synchronous call under test
/// blocks the test isolate, so the server cannot run there.
Future<(Isolate, int)> _serveFile(String filePath) async {
  final ready = ReceivePort();
  final isolate = await Isolate.spawn(_serveMain, (ready.sendPort, filePath));
  final port = await ready.first as int;
  ready.close();
  return (isolate, port);
}

Future<void> _serveMain((SendPort, String) arguments) async {
  final (ready, filePath) = arguments;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  ready.send(server.port);
  await for (final request in server) {
    request.response.add(await File(filePath).readAsBytes());
    await request.response.close();
  }
}

void main() {
  test('native synchronous FFprobe accepts a direct HTTP command', () async {
    await FFmpegKitExtended.initialize();
    final directory = await Directory.systemTemp.createTemp('w-f05-');
    addTearDown(() => directory.delete(recursive: true));
    final media = '${directory.path}/input.mp4';

    final generated = FFmpegKit.execute(
      '-hide_banner -nostdin -y -f lavfi -i testsrc=size=64x64:rate=10 '
      '-t 1 -c:v mpeg4 "$media"',
    );
    expect(generated.getReturnCode(), 0, reason: generated.getOutput());

    final (server, port) = await _serveFile(media);
    addTearDown(server.kill);

    final probe = FFprobeKit.execute(
      '-v error -show_format "http://127.0.0.1:$port/input.mp4"',
    );
    expect(probe.getReturnCode(), 0, reason: probe.getOutput());
    expect(probe.getOutput(), contains('format_name='));
  });
}
