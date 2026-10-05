import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:web/web.dart' as web;

const _smokeMediaPath = '/runtime-smoke.mp4';
const _smokeFrameSource =
    'color=c=red:size=512x512:rate=30:duration=2[red];'
    'color=c=green:size=512x512:rate=30:duration=2[green];'
    'color=c=blue:size=512x512:rate=30:duration=2[blue];'
    'color=c=white:size=512x512:rate=30:duration=2[white];'
    '[red][green][blue][white]concat=n=4:v=1:a=0';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  web.document.title = 'STARTING';
  runApp(const WebRuntimeSmokeApp());
}

class WebRuntimeSmokeApp extends StatefulWidget {
  const WebRuntimeSmokeApp({super.key});

  @override
  State<WebRuntimeSmokeApp> createState() => _WebRuntimeSmokeAppState();
}

class _WebRuntimeSmokeAppState extends State<WebRuntimeSmokeApp> {
  final _statuses = <String>['STARTING'];
  FFplaySurface? _surface;

  @override
  void initState() {
    super.initState();
    _runSmoke();
  }

  Future<void> _runSmoke() async {
    var logCount = 0;
    var firstLogLevel = -1;
    var firstLogMessage = '';
    try {
      await FFmpegKitExtended.initialize();
      await FFmpegKitExtended.initialize();
      _addStatus('INITIALIZED');

      FFmpegKitConfig.enableLogCallback((log) {
        logCount++;
        firstLogLevel = log.level;
        firstLogMessage = log.message;
      });

      final ffmpegSession = await FFmpegKit.executeAsync(
        '-hide_banner -nostdin -f lavfi -i "$_smokeFrameSource" -f lavfi -i '
        'sine=frequency=1000:duration=8 -c:v mpeg2video -c:a aac '
        '-shortest -y $_smokeMediaPath',
      );
      if (!ReturnCode.isSuccess(ffmpegSession.getReturnCode())) {
        throw StateError(
          'FFmpeg smoke command failed: ${ffmpegSession.getReturnCode()}',
        );
      }
      _addStatus('FFMPEG_OK');
      if (logCount == 0 || firstLogLevel < 0 || firstLogMessage.isEmpty) {
        throw StateError(
          'No non-empty structured log callback was observed '
          '(count=$logCount, level=$firstLogLevel).',
        );
      }
      _addStatus('LOG_OK');

      final ffprobeSession = await FFprobeKit.executeAsync('-version');
      if (!ReturnCode.isSuccess(ffprobeSession.getReturnCode())) {
        throw StateError(
          'FFprobe smoke command failed: ${ffprobeSession.getReturnCode()}',
        );
      }
      _addStatus('FFPROBE_OK');

      final mediaInformationSession = await FFprobeKit.getMediaInformationAsync(
        _smokeMediaPath,
      );
      if (!mediaInformationSession.isMediaInformationSession()) {
        throw StateError('Media-information session type was not returned.');
      }
      final mediaInformation =
          (mediaInformationSession as MediaInformationSession)
              .getMediaInformation();
      if (mediaInformation == null) {
        throw StateError('Media-information result was empty.');
      }
      _addStatus('MEDIA_INFO_OK');

      final surface = await FFplaySurface.create(width: 512, height: 512);
      if (surface == null) {
        throw StateError('Flutter Web FFplay surface could not be created.');
      }
      if (!mounted) {
        await surface.release();
        return;
      }
      setState(() => _surface = surface);

      final playbackCompleted = Completer<void>();
      final ffplaySession = await FFplayKit.executeAsync(
        '-loglevel fatal -f lavfi -i "$_smokeFrameSource" -t 8 -autoexit',
        onComplete: (_) {
          if (!playbackCompleted.isCompleted) playbackCompleted.complete();
        },
      );
      _addStatus('FFPLAY_STARTED');
      await playbackCompleted.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          if (FFplayKit.playing) FFplayKit.stop();
        },
      );
      if (ffplaySession.isPlaying()) {
        ffplaySession.stop();
      }
      _addStatus('FFPLAY_COMPLETE');
      _addStatus('PASS');
    } catch (error) {
      _addStatus('FAIL: $error');
    } finally {
      try {
        FFmpegKitConfig.enableLogCallback(null);
      } catch (_) {
        // Initialization failures have no callback bridge to uninstall.
      }
      final surface = _surface;
      _surface = null;
      await surface?.release();
    }
  }

  void _addStatus(String status) {
    if (!mounted) return;
    setState(() {
      _statuses.add(status);
      web.document.title = _statuses.join('|');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_surface != null)
              SizedBox(
                width: 320,
                height: 320,
                child: FFplayView(
                  surface: _surface!,
                  aspectRatio: 1,
                  videoWidth: 512,
                  videoHeight: 512,
                ),
              ),
            SelectableText(_statuses.join('\n')),
          ],
        ),
      ),
    );
  }
}
