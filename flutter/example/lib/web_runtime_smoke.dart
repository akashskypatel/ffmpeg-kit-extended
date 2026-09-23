import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:web/web.dart' as web;

const _smokeMediaPath = '/runtime-smoke.mp4';

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
        '-hide_banner -nostdin -f lavfi -i '
        'testsrc=duration=1:size=64x64:rate=1 -f lavfi -i '
        'sine=frequency=1000:duration=1 -c:v mpeg2video -c:a aac '
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
      _addStatus('PASS');
    } catch (error) {
      _addStatus('FAIL: $error');
    } finally {
      try {
        FFmpegKitConfig.enableLogCallback(null);
      } catch (_) {
        // Initialization failures have no callback bridge to uninstall.
      }
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
      home: Scaffold(body: Center(child: SelectableText(_statuses.join('\n')))),
    );
  }
}
