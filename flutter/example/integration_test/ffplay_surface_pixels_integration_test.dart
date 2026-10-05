// ignore_for_file: avoid_print

import 'dart:async';
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
    'color=c=red:size=512x512:rate=30:duration=2[red];'
    'color=c=green:size=512x512:rate=30:duration=2[green];'
    'color=c=blue:size=512x512:rate=30:duration=2[blue];'
    'color=c=white:size=512x512:rate=30:duration=2[white];'
    '[red][green][blue][white]concat=n=4:v=1:a=0';

const _frameWidth = 512;
const _frameHeight = 512;
const _pixelTolerance = 40;

const _framePhases = <({String name, double atSeconds, List<int> rgba})>[
  (name: 'red', atSeconds: 0.5, rgba: [253, 0, 0, 255]),
  (name: 'green', atSeconds: 2.5, rgba: [0, 127, 0, 255]),
  (name: 'blue', atSeconds: 4.5, rgba: [0, 0, 254, 255]),
  (name: 'white', atSeconds: 6.5, rgba: [255, 255, 255, 255]),
];

const _frameSamples = <({String name, int x, int y})>[
  (name: 'top-left', x: 128, y: 128),
  (name: 'top-right', x: 384, y: 128),
  (name: 'bottom-left', x: 128, y: 384),
  (name: 'bottom-right', x: 384, y: 384),
];

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  await FFmpegKitExtended.initialize();

  late Directory outputDirectory;
  late String videoPath;
  late List<Uint8List> originalFrames;

  setUpAll(() async {
    outputDirectory = await Directory.systemTemp.createTemp(
      'ffmpeg_kit_extended_ffplay_surface_',
    );
    videoPath = path.join(outputDirectory.path, 'changing-frames.mp4');
    final generation = FFmpegKit.execute(
      '-hide_banner -loglevel error -f lavfi -i "$_frameSource" '
      '-f lavfi -i sine=frequency=1000:duration=8 '
      '-c:v mpeg2video -c:a aac -shortest -y "$videoPath"',
    );
    expect(
      ReturnCode.isSuccess(generation.getReturnCode()),
      isTrue,
      reason: 'Could not generate the changing-frame video',
    );
    expect(File(videoPath).existsSync(), isTrue);

    originalFrames = <Uint8List>[];
    for (final phase in _framePhases) {
      final framePath = path.join(
        outputDirectory.path,
        'original-${phase.name}.rgba',
      );
      final decode = FFmpegKit.execute(
        '-hide_banner -loglevel error -f lavfi -i "$_frameSource" '
        '-ss ${phase.atSeconds} -frames:v 1 -pix_fmt rgba '
        '-f rawvideo -y "$framePath"',
      );
      expect(
        ReturnCode.isSuccess(decode.getReturnCode()),
        isTrue,
        reason: 'Could not decode original ${phase.name} phase',
      );
      final frame = Uint8List.fromList(File(framePath).readAsBytesSync());
      expect(
        frame.length,
        greaterThanOrEqualTo(_frameWidth * _frameHeight * 4),
      );
      originalFrames.add(frame);
    }
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

  testWidgets('FFplay surface renders changing pixels throughout playback', (
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
                height: 320,
                child: RepaintBoundary(
                  key: const ValueKey<String>('ffplay.surface-under-test'),
                  child: FFplayView(
                    surface: surface!,
                    aspectRatio: 1,
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

      final renderedSignatures = <String>{};
      for (var phaseIndex = 0; phaseIndex < _framePhases.length; phaseIndex++) {
        final phase = _framePhases[phaseIndex];
        await session.positionStream
            .firstWhere((position) => position >= phase.atSeconds + 0.2)
            .timeout(
              const Duration(seconds: 4),
              onTimeout: () => throw TimeoutException(
                'Playback did not reach the ${phase.name} frame',
              ),
            );
        // Give the texture compositor another frame after the decoder
        // reports the timestamp, then capture the actual visible surface.
        await tester.pump(const Duration(milliseconds: 100));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey<String>('ffplay.surface-under-test')),
        );
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (data == null) {
            throw StateError('Could not read FFplay surface RGBA pixels');
          }
          final renderedFrame = data.buffer.asUint8List(
            data.offsetInBytes,
            data.offsetInBytes + data.lengthInBytes,
          );
          renderedSignatures.add(
            _expectSurfacePixels(
              width: image.width,
              height: image.height,
              rgba: renderedFrame,
              expectedFrame: originalFrames[phaseIndex],
              phase: phase,
            ),
          );
        } finally {
          image.dispose();
        }
      }
      expect(
        renderedSignatures,
        hasLength(_framePhases.length),
        reason: 'The rendered FFplay surface stayed static during playback',
      );
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
  }, timeout: const Timeout(Duration(seconds: 40)));
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

String _expectSurfacePixels({
  required int width,
  required int height,
  required Uint8List rgba,
  required Uint8List expectedFrame,
  required ({String name, double atSeconds, List<int> rgba}) phase,
}) {
  if (width <= 0 || height <= 0) {
    throw StateError('FFplay surface has no rendered size: ${width}x$height');
  }

  final signature = <String>[];
  for (final sample in _frameSamples) {
    final x = (sample.x / _frameWidth * width).round().clamp(0, width - 1);
    final y = (sample.y / _frameHeight * height).round().clamp(0, height - 1);
    final offset = (y * width + x) * 4;
    final actual = rgba.sublist(offset, offset + 4);
    final expectedOffset = (sample.y * _frameWidth + sample.x) * 4;
    final sourcePixel = expectedFrame.sublist(
      expectedOffset,
      expectedOffset + 4,
    );
    for (var channel = 0; channel < 4; channel++) {
      expect(
        (sourcePixel[channel] - phase.rgba[channel]).abs(),
        lessThanOrEqualTo(_pixelTolerance),
        reason:
            '${phase.name} original ${sample.name} pixel mismatch: '
            'expected RGBA=${phase.rgba}, actual=$sourcePixel',
      );
      expect(
        (actual[channel] - sourcePixel[channel]).abs(),
        lessThanOrEqualTo(_pixelTolerance),
        reason:
            '${phase.name} rendered ${sample.name} pixel mismatch at ($x, $y): '
            'expected original RGBA=$sourcePixel, actual=$actual',
      );
    }
    signature.add(actual.join(','));
  }
  return signature.join('|');
}
