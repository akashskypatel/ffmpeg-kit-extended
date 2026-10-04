// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;

const _frameSource =
    'color=c=black:size=160x90:rate=30:duration=5,'
    'drawbox=x=0:y=0:w=80:h=45:color=red:t=fill,'
    'drawbox=x=80:y=0:w=80:h=45:color=green:t=fill,'
    'drawbox=x=0:y=45:w=80:h=45:color=blue:t=fill,'
    'drawbox=x=80:y=45:w=80:h=45:color=white:t=fill';

const _frameWidth = 160;
const _frameHeight = 90;
const _pixelTolerance = 40;

const _frameSamples = <({String name, int x, int y, List<int> rgba})>[
  (name: 'top-left red', x: 20, y: 20, rgba: [253, 0, 0, 255]),
  (name: 'top-right green', x: 100, y: 20, rgba: [0, 127, 0, 255]),
  (name: 'bottom-left blue', x: 20, y: 65, rgba: [0, 0, 254, 255]),
  (name: 'bottom-right white', x: 100, y: 65, rgba: [255, 255, 255, 255]),
];

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();

  late Directory outputDirectory;
  late String videoPath;
  late Uint8List originalFrame;

  setUpAll(() async {
    outputDirectory = await Directory.systemTemp.createTemp(
      'ffmpeg_kit_extended_ffplay_surface_',
    );
    videoPath = path.join(outputDirectory.path, 'frame-contract.mp4');
    final generation = FFmpegKit.execute(
      '-hide_banner -loglevel error -f lavfi -i "$_frameSource" '
      '-f lavfi -i sine=frequency=1000:duration=5 '
      '-c:v mpeg2video -c:a aac -shortest -y "$videoPath"',
    );
    expect(
      ReturnCode.isSuccess(generation.getReturnCode()),
      isTrue,
      reason: 'Could not generate the frame-contract video',
    );
    expect(File(videoPath).existsSync(), isTrue);

    final originalFramePath = path.join(outputDirectory.path, 'original.rgba');
    final originalDecode = FFmpegKit.execute(
      '-hide_banner -loglevel error -f lavfi -i "$_frameSource" '
      '-frames:v 1 -pix_fmt rgba -f rawvideo -y "$originalFramePath"',
    );
    expect(
      ReturnCode.isSuccess(originalDecode.getReturnCode()),
      isTrue,
      reason: 'Could not decode the original input frame',
    );
    originalFrame = Uint8List.fromList(
      File(originalFramePath).readAsBytesSync(),
    );
    expect(
      originalFrame.length,
      greaterThanOrEqualTo(_frameWidth * _frameHeight * 4),
    );
  });

  tearDownAll(() async {
    if (!outputDirectory.existsSync()) return;
    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        await outputDirectory.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    throw StateError(
      'Could not clean up FFplay surface test directory: '
      '${outputDirectory.path}',
    );
  });

  testWidgets('FFplay surface renders the original frame pixel contract', (
    tester,
  ) async {
    final surface = await FFplaySurface.create(
      width: _frameWidth,
      height: _frameHeight,
    );
    expect(
      surface,
      isNotNull,
      reason: 'Native FFplay surface could not be created',
    );

    FFplaySession? session;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 180,
                child: RepaintBoundary(
                  key: const ValueKey<String>('ffplay.surface-under-test'),
                  child: FFplayView(
                    surface: surface!,
                    aspectRatio: _frameWidth / _frameHeight,
                    videoWidth: _frameWidth,
                    videoHeight: _frameHeight,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      session = await FFplayKit.executeAsync(
        '-hide_banner -loglevel error -autoexit -i "$videoPath"',
      );
      final size = await session.videoSizeStream
          .firstWhere(
            (value) => value.$1 == _frameWidth && value.$2 == _frameHeight,
          )
          .timeout(const Duration(seconds: 10));
      expect(size, (_frameWidth, _frameHeight));

      // Let the texture compositor present the decoded frame before taking
      // the screenshot. The assertion below reads the rendered surface, not
      // the source file or FFplay's decoded-file output.
      await tester.pump(const Duration(milliseconds: 750));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey<String>('ffplay.surface-under-test')),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) {
          throw StateError('Could not read FFplay surface RGBA pixels');
        }
        _expectSurfacePixels(
          width: image.width,
          height: image.height,
          rgba: data.buffer.asUint8List(
            data.offsetInBytes,
            data.offsetInBytes + data.lengthInBytes,
          ),
          expectedFrame: originalFrame,
        );
      } finally {
        image.dispose();
      }
    } finally {
      try {
        session?.stop();
      } catch (_) {
        // The session may already have reached its terminal state.
      }
      await _waitForSessionToStop(session);
      await surface!.release();
      await tester.pump();
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}

Future<void> _waitForSessionToStop(FFplaySession? session) async {
  if (session == null) return;
  for (var attempt = 0; attempt < 40; attempt++) {
    final state = session.getState();
    if (state == SessionState.completed || state == SessionState.failed) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void _expectSurfacePixels({
  required int width,
  required int height,
  required Uint8List rgba,
  required Uint8List expectedFrame,
}) {
  if (width <= 0 || height <= 0) {
    throw StateError('FFplay surface has no rendered size: ${width}x$height');
  }

  for (final sample in _frameSamples) {
    final x = (sample.x / _frameWidth * width).round().clamp(0, width - 1);
    final y = (sample.y / _frameHeight * height).round().clamp(0, height - 1);
    final offset = (y * width + x) * 4;
    final actual = rgba.sublist(offset, offset + 4);
    final expectedOffset = (sample.y * _frameWidth + sample.x) * 4;
    final expected = expectedFrame.sublist(expectedOffset, expectedOffset + 4);
    for (var channel = 0; channel < 4; channel++) {
      expect(
        (expected[channel] - sample.rgba[channel]).abs(),
        lessThanOrEqualTo(_pixelTolerance),
        reason:
            '${sample.name} original input pixel mismatch: '
            'expected RGBA=${sample.rgba}, actual=$expected',
      );
      expect(
        (actual[channel] - expected[channel]).abs(),
        lessThanOrEqualTo(_pixelTolerance),
        reason:
            '${sample.name} rendered surface pixel mismatch at ($x, $y): '
            'expected original RGBA=$expected, actual=$actual',
      );
    }
  }
}
