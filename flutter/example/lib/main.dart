import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_media_store/android_media_store.dart';
import 'package:path_provider/path_provider.dart'; // Import for getTemporaryDirectory
import 'package:window_manager/window_manager.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'web_download_stub.dart'
    if (dart.library.js_interop) 'web_download.dart'
    as web_download;
import 'platform_flags.dart' as platform;

const _ffplayFrameSource =
    'color=c=red:size=512x512:rate=30:duration=2[red];'
    'color=c=green:size=512x512:rate=30:duration=2[green];'
    'color=c=blue:size=512x512:rate=30:duration=2[blue];'
    'color=c=white:size=512x512:rate=30:duration=2[white];'
    '[red][green][blue][white]concat=n=4:v=1:a=0';

const _ffplayFramePhases = <({String name, double atSeconds, List<int> rgba})>[
  (name: 'red phase', atSeconds: 0.5, rgba: [253, 0, 0, 255]),
  (name: 'green phase', atSeconds: 2.5, rgba: [0, 127, 0, 255]),
  (name: 'blue phase', atSeconds: 4.5, rgba: [0, 0, 254, 255]),
  (name: 'white phase', atSeconds: 6.5, rgba: [255, 255, 255, 255]),
];

/// ABI of the Phase 2 Web bundle that supports direct HTTP(S) input.
const _ffplayFrameWidth = 512;
const _ffplayFrameHeight = 512;
const _ffplayFrameRgbaTolerance = 32;

class WebMediaOperationLeaseManager {
  int activeCount = 0;

  void Function() begin(void Function() onTerminalSignal) {
    activeCount++;
    var released = false;
    return () {
      if (!released) {
        released = true;
        activeCount--;
      }
      onTerminalSignal();
    };
  }
}

void main() {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    if (platform.isDesktop) {
      await windowManager.ensureInitialized();
    }
    await FFmpegKitExtended.initialize();
  }

  void _retry() {
    setState(() {
      _initialization = _initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const MyApp();
        }

        return MaterialApp(
          title: 'FFmpeg Kit Extended Demo',
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: snapshot.hasError
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48),
                            const SizedBox(height: 16),
                            const Text(
                              'Unable to initialize FFmpeg Kit',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SelectableText(
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _retry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 20),
                            Text('Loading FFmpeg Kit...'),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FFmpeg Kit Extended Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _RemoteRecordingScenarioJob {
  _RemoteRecordingScenarioJob({required this.label, required this.outputPath});

  final String label;
  final String outputPath;
  FFmpegSession? session;
  int? sessionId;
  final Completer<void> startedWriting = Completer<void>();
  bool completed = false;
  bool requestedCancel = false;
  int? returnCode;
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _outputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _ffmpegCommandController = TextEditingController(
    text: "-nostdin -version",
  );
  final TextEditingController _ffprobeCommandController = TextEditingController(
    text: "-version",
  );
  final TextEditingController _ffplayCommandController = TextEditingController(
    text: "-i test_video.mp4",
  );
  final TextEditingController _remoteStreamUrlController =
      TextEditingController(
        text: "https://endpnt.com/hls/nasa4k/playlist.m3u8",
      );
  String? _selectedProbePath;
  String? _selectedWebMediaPath;
  final Set<String> _retiredWebMediaPaths = <String>{};
  final WebMediaOperationLeaseManager _customWebMediaOperations =
      WebMediaOperationLeaseManager();
  final Set<String> _webDownloadableFiles = <String>{};
  String _status = 'Ready';
  final _mediaStore = AndroidMediaStore.instance;
  StreamSubscription<bool>? _permissionStreamSub;
  LogLevel _currentLogLevel = LogLevel.info;

  // FFplay position tracking
  StreamSubscription<double>? _positionSub;
  double _playbackPosition = 0.0;
  bool _hasActiveSession = false;

  // Volume control
  double _volume = 0.5;

  // Video dimensions updated via videoSizeStream when first frame is decoded
  StreamSubscription<(int, int)>? _videoSizeSub;
  int _videoWidth = 0;
  int _videoHeight = 0;
  bool _hasVideo = false;

  final List<_RemoteRecordingScenarioJob> _remoteScenarioJobs = [];
  String? _remoteScenarioLogPath;
  Future<void> _remoteScenarioLogQueue = Future.value();
  String _pendingOutputLogs = '';
  Timer? _outputLogFlushTimer;
  bool _outputScrollScheduled = false;
  String _pendingRemoteScenarioFileLogs = '';
  Timer? _remoteScenarioFileFlushTimer;
  DateTime _lastRemoteScenarioStatsUiUpdate =
      DateTime.fromMillisecondsSinceEpoch(0);
  int _recordingCounter = 1;

  // Transcode state
  double _transcodeProgress = 0.0;
  bool _isTranscoding = false;
  String _transcodeStatus = '';
  String? _transcodeInputPath;
  String? _transcodeOutputPath;

  // Unified video surface for Android, Linux, Windows
  FFplaySurface? _surface;
  late FFplayViewController _fsController;

  @override
  void dispose() {
    _permissionStreamSub?.cancel();
    _positionSub?.cancel();
    _videoSizeSub?.cancel();
    _outputLogFlushTimer?.cancel();
    _remoteScenarioFileFlushTimer?.cancel();
    _remoteStreamUrlController.dispose();
    _webRemoteUrlController.dispose();
    _surface?.release();
    _fsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fsController = FFplayViewController(
      onEnterFullscreen: platform.isDesktop
          ? () => windowManager.setFullScreen(true)
          : null,
      onExitFullscreen: platform.isDesktop
          ? () => windowManager.setFullScreen(false)
          : null,
    );
    _initializePlugin();
    _currentLogLevel = FFmpegKitExtended.initialized
        ? FFmpegKitConfig.getLogLevel()
        : LogLevel.info;
    final tabController = TabController(length: 5, vsync: this);
    if (platform.isAndroid) {
      // Listen for MANAGE_MEDIA permission changes.
      _permissionStreamSub = _mediaStore.onManageMediaPermissionChanged.listen((
        isGranted,
      ) {
        if (mounted) {
          setState(() {
            _status = isGranted
                ? 'Manage Media Permission: Granted'
                : 'Manage Media Permission: Denied';
            _addLog(_status);
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_status)));
        }
      });
    }
    _tabController = tabController;
  }

  Future<void> _initializePlugin() async {
    if (!platform.isAndroid) return;
    try {
      await AndroidMediaStore.ensureInitialized();
      setState(() {
        _status = 'Plugin initialized successfully';
        _addLog(_status);
      });
      await _checkPermissions(silent: true);
    } catch (e) {
      setState(() {
        _status = 'Initialization failed: $e';
        _addLog(_status);
      });
    }
  }

  Future<void> _checkPermissions({bool silent = false}) async {
    if (!platform.isAndroid) return;
    if (!silent) {
      setState(() {
        _status = 'Checking permissions...';
        _addLog(_status);
      });
    }
    try {
      // Check standard storage/media permissions.
      await [
        Permission.photos,
        Permission.audio,
        Permission.videos,
        Permission.storage,
      ].request();

      // Check Android 12+ Manage Media Access.
      bool canManageMedia = await _mediaStore.canManageMedia();

      if (!canManageMedia) {
        setState(() {
          _status = 'Missing Manage Media Permission';
          _addLog(_status);
        });
        await _mediaStore
            .requestManageMedia(); // Will trigger the stream when user returns
      } else {
        setState(() {
          _status = 'All permissions look good!';
          _addLog(_status);
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Permission check error: $e';
        _addLog(_status);
      });
    }
  }

  void _addLog(String log, {bool printToConsole = false}) {
    if (printToConsole) {
      debugPrint(log);
    }
    _pendingOutputLogs += "$log\n";
    _outputLogFlushTimer ??= Timer(
      const Duration(milliseconds: 150),
      _flushOutputLogs,
    );
  }

  void _flushOutputLogs() {
    _outputLogFlushTimer?.cancel();
    _outputLogFlushTimer = null;
    if (_pendingOutputLogs.isEmpty) {
      return;
    }

    final chunk = _pendingOutputLogs;
    _pendingOutputLogs = '';
    _outputController.text += chunk;

    if (_outputScrollScheduled) {
      return;
    }

    _outputScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _outputScrollScheduled = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _logRemoteScenario(String message) {
    _addLog(message, printToConsole: true);
    _queueRemoteScenarioLog(message);
  }

  void _queueRemoteScenarioLog(String message) {
    final logPath = _remoteScenarioLogPath;
    if (logPath == null) {
      return;
    }

    final stamp = DateTime.now().toIso8601String();
    _pendingRemoteScenarioFileLogs += '[$stamp] $message\n';
    _remoteScenarioFileFlushTimer ??= Timer(
      const Duration(milliseconds: 250),
      () => _flushRemoteScenarioLogQueue(logPath),
    );
  }

  void _flushRemoteScenarioLogQueue(String logPath) {
    _remoteScenarioFileFlushTimer?.cancel();
    _remoteScenarioFileFlushTimer = null;
    if (_pendingRemoteScenarioFileLogs.isEmpty) {
      return;
    }

    final chunk = _pendingRemoteScenarioFileLogs;
    _pendingRemoteScenarioFileLogs = '';
    _remoteScenarioLogQueue = _remoteScenarioLogQueue
        .then((_) async {
          await File(
            logPath,
          ).writeAsString(chunk, mode: FileMode.append, flush: true);
        })
        .catchError((_) {});
  }

  void _clearLogs() {
    setState(() {
      _outputController.clear();
    });
  }

  // --- FFmpeg Examples ---

  Future<void> _runFFmpegVersion() async {
    _addLog("--- Running FFmpeg -version (Async) ---", printToConsole: true);

    // Async execution captures logs in real-time.
    await FFmpegKit.executeAsync(
      "-nostdin -version",
      onLog: (log) {
        _addLog(log.message);
      },
      onComplete: (session) {
        _addLog("Return code: ${session.getReturnCode()}");
      },
    );
  }

  void _runFFmpegInfoSync() {
    _addLog("--- Running FFmpeg -version (Sync) ---", printToConsole: true);
    try {
      // Synchronous execution blocks the current isolate.
      final session = FFmpegKit.execute("-nostdin -version");
      final output = session.getOutput();

      _addLog("Output captured from sync session:");
      _addLog(output ?? "No output captured.");
      _addLog("Return code: ${session.getReturnCode()}");
    } catch (error, stackTrace) {
      _addLog(
        "FFmpeg sync execution failed: $error\n$stackTrace",
        printToConsole: true,
      );
    }
  }

  Future<String> _exampleDirectoryPath() async {
    if (kIsWeb) {
      // Web FFmpeg uses Emscripten's temporary in-memory filesystem. Keep all
      // demo and imported media under the same flat /tmp/ namespace.
      return '/tmp';
    }

    final tempDir = await getTemporaryDirectory();
    final exampleDir = Directory(
      path.join(tempDir.path, 'ffmpeg_kit_extended_flutter_example'),
    );
    await exampleDir.create(recursive: true);
    return exampleDir.path;
  }

  bool _exampleFileExists(String filePath) =>
      kIsWeb ? FFmpegKitWebFiles.exists(filePath) : File(filePath).existsSync();

  String _importWebMedia(String fileName, Uint8List bytes) {
    final baseName = fileName.replaceAll('\\', '/').split('/').last;
    final safeName = baseName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final suffix = safeName.isEmpty ? 'media.bin' : safeName;
    var unique = DateTime.now().microsecondsSinceEpoch;
    var virtualPath = '/tmp/ffmpeg-kit-import-$unique-$suffix';
    while (FFmpegKitWebFiles.exists(virtualPath)) {
      unique++;
      virtualPath = '/tmp/ffmpeg-kit-import-$unique-$suffix';
    }
    FFmpegKitWebFiles.writeFile(virtualPath, bytes);
    return virtualPath;
  }

  bool _webMediaPathIsInUse(String filePath) =>
      FFmpegKitExtended.listSessions().any((session) {
        final state = session.getState();
        return (state == SessionState.created ||
                state == SessionState.running) &&
            session.getCommand().contains(filePath);
      });

  void _retireWebMediaPath(String filePath) {
    if (!kIsWeb) return;
    _retiredWebMediaPaths.add(filePath);
    _cleanupRetiredWebMediaPaths();
  }

  void _cleanupRetiredWebMediaPaths() {
    if (!kIsWeb ||
        _retiredWebMediaPaths.isEmpty ||
        _customWebMediaOperations.activeCount > 0) {
      return;
    }
    for (final filePath in _retiredWebMediaPaths.toList()) {
      if (_webMediaPathIsInUse(filePath)) continue;
      try {
        if (FFmpegKitWebFiles.exists(filePath)) {
          FFmpegKitWebFiles.deleteFile(filePath);
        }
        _retiredWebMediaPaths.remove(filePath);
      } catch (error) {
        _addLog('Unable to remove retired Web media $filePath: $error');
      }
    }
  }

  void Function() _beginCustomWebMediaOperation() {
    if (!kIsWeb) return () {};
    return _customWebMediaOperations.begin(_cleanupRetiredWebMediaPaths);
  }

  Future<void> _downloadWebFile(String filePath) async {
    if (!kIsWeb) return;
    try {
      if (!FFmpegKitWebFiles.exists(filePath)) {
        throw StateError('No Wasm file exists at $filePath.');
      }
      final fileName = path.basename(filePath);
      final extension = path.extension(fileName).toLowerCase();
      final mimeType = switch (extension) {
        '.mp4' => 'video/mp4',
        '.wav' => 'audio/wav',
        '.avi' => 'video/x-msvideo',
        _ => 'application/octet-stream',
      };
      web_download.downloadBytes(
        fileName,
        FFmpegKitWebFiles.readFile(filePath),
        mimeType,
      );
      _addLog('Browser download requested for $fileName.');
    } catch (error) {
      _addLog('Web file download failed for $filePath: $error');
    }
  }

  Future<void> _generateTestVideo() async {
    final exampleDirPath = await _exampleDirectoryPath();
    final tempOutputPath = path.join(exampleDirPath, 'test_video.mp4');
    _addLog(
      "--- Generating Test Video with Audio to temporary path: $tempOutputPath ---",
      printToConsole: true,
    );

    // Command with both video and audio streams
    final command =
        // "-hide_banner -nostdin -loglevel ${_currentLogLevel.name} -f lavfi -i testsrc=duration=5:size=512x512:rate=30 -f lavfi -i sine=frequency=1000:duration=5 -c:v mpeg2video -c:a aac -shortest -y";
        "-hide_banner -nostdin -loglevel ${_currentLogLevel.name} -f lavfi -i \"$_ffplayFrameSource\" -f lavfi -i sine=frequency=1000:duration=8 -c:v mpeg2video -c:a aac -shortest -y";

    if (kIsWeb) {
      setState(() => _webDownloadableFiles.remove(tempOutputPath));
    }

    await FFmpegKit.executeAsync(
      "$command \"$tempOutputPath\"",
      onLog: (log) {
        _addLog(log.message);
      },
      onComplete: (session) {
        if (ReturnCode.isSuccess(session.getReturnCode())) {
          if (kIsWeb && mounted) {
            setState(() => _webDownloadableFiles.add(tempOutputPath));
          }
          _addLog("✅ Video with audio generated successfully!");
        } else {
          _addLog("❌ Generation failed. Code: ${session.getReturnCode()}");
        }
      },
    );
    if (!kIsWeb) {
      await _verifyGeneratedVideoPixels(tempOutputPath);
    }
  }

  Future<List<int>> _decodeFrameRgba({
    required String inputArguments,
    required String outputPath,
    required String label,
  }) async {
    final outputFile = File(outputPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }
    final session = await FFmpegKit.executeAsync(
      '-hide_banner -loglevel info $inputArguments '
      '-frames:v 1 -pix_fmt rgba -f rawvideo -y "$outputPath"',
    );
    if (!ReturnCode.isSuccess(session.getReturnCode())) {
      throw StateError(
        '$label frame decode failed: '
        '${session.getReturnCode()}',
      );
    }
    if (!await outputFile.exists()) {
      throw StateError('$label frame decode did not produce $outputPath');
    }
    final bytes = await outputFile.readAsBytes();
    final expectedLength = _ffplayFrameWidth * _ffplayFrameHeight * 4;
    if (bytes.length < expectedLength) {
      throw StateError(
        '$label frame decode produced ${bytes.length} bytes; '
        'expected at least $expectedLength',
      );
    }
    return bytes;
  }

  Future<void> _verifyGeneratedVideoPixels(String videoPath) async {
    _addLog(
      '--- Verifying decoded video frame pixels against original input ---',
    );
    final directory = path.dirname(videoPath);
    final originalFramePath = path.join(
      directory,
      '.ffplay-original-frame.rgba',
    );
    final outputFramePath = path.join(directory, '.ffplay-output-frame.rgba');
    try {
      final originalSignatures = <String>{};
      final outputSignatures = <String>{};
      for (final phase in _ffplayFramePhases) {
        final originalFrame = await _decodeFrameRgba(
          inputArguments:
              '-f lavfi -i "$_ffplayFrameSource" -ss ${phase.atSeconds}',
          outputPath: originalFramePath,
          label: 'Original input at ${phase.atSeconds}s',
        );
        final outputFrame = await _decodeFrameRgba(
          inputArguments: '-ss ${phase.atSeconds} -i "$videoPath"',
          outputPath: outputFramePath,
          label: 'Final output at ${phase.atSeconds}s',
        );
        final offset =
            ((_ffplayFrameHeight ~/ 2) * _ffplayFrameWidth +
                (_ffplayFrameWidth ~/ 2)) *
            4;
        final originalPixel = originalFrame.sublist(offset, offset + 4);
        final outputPixel = outputFrame.sublist(offset, offset + 4);
        if (originalPixel.asMap().entries.any(
          (entry) =>
              (entry.value - phase.rgba[entry.key]).abs() >
              _ffplayFrameRgbaTolerance,
        )) {
          throw StateError(
            'Original input pixel mismatch for ${phase.name}: '
            'expected RGBA=${phase.rgba}, actual=$originalPixel',
          );
        }
        if (outputPixel.asMap().entries.any(
          (entry) =>
              (entry.value - originalPixel[entry.key]).abs() >
              _ffplayFrameRgbaTolerance,
        )) {
          throw StateError(
            'Final output frame differs from original input for ${phase.name}: '
            'original RGBA=$originalPixel, final RGBA=$outputPixel',
          );
        }
        originalSignatures.add(originalPixel.join(','));
        outputSignatures.add(outputPixel.join(','));
        _addLog(
          'Verified ${phase.name} at ${phase.atSeconds}s: '
          'original RGBA=${originalPixel.join(',')}, '
          'final RGBA=${outputPixel.join(',')}',
        );
      }
      if (originalSignatures.length != _ffplayFramePhases.length ||
          outputSignatures.length != _ffplayFramePhases.length) {
        throw StateError(
          'Generated video did not change pixel values across all four '
          'playback phases',
        );
      }
    } finally {
      for (final file in [File(originalFramePath), File(outputFramePath)]) {
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  Future<void> _generateTestAudio() async {
    final exampleDirPath = await _exampleDirectoryPath();
    final outputPath = path.join(exampleDirPath, 'test_audio.wav');
    _addLog(
      "--- Generating Test Audio to: $outputPath ---",
      printToConsole: true,
    );

    // Command from integration tests
    final command =
        "-hide_banner -nostdin -loglevel ${_currentLogLevel.name} -f lavfi -i sine=frequency=1000:duration=10 -y";

    if (kIsWeb) {
      setState(() => _webDownloadableFiles.remove(outputPath));
    }

    await FFmpegKit.executeAsync(
      "$command \"$outputPath\"",
      onLog: (log) {
        _addLog(log.message);
      },
      onComplete: (session) {
        if (ReturnCode.isSuccess(session.getReturnCode())) {
          if (kIsWeb && mounted) {
            setState(() => _webDownloadableFiles.add(outputPath));
          }
          _addLog("✅ Audio generated successfully!");
        } else {
          _addLog("❌ Generation failed. Code: ${session.getReturnCode()}");
        }
      },
    );
  }

  Future<void> _pickTranscodeFile() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.video);
      if (result.isEmpty) return;
      final file = result.single;
      final previousWebPath = _selectedWebMediaPath;
      final pickedPath = kIsWeb
          ? _importWebMedia(file.name, await file.readAsBytes())
          : file.path;
      if (pickedPath == null) {
        _addLog('The selected file did not provide a local path.');
        return;
      }
      final pickedDir = kIsWeb ? '/tmp' : path.dirname(pickedPath);
      final baseName = path.basenameWithoutExtension(pickedPath);
      setState(() {
        _transcodeInputPath = pickedPath;
        _transcodeOutputPath = path.join(
          pickedDir,
          '${baseName}_transcoded.avi',
        );
        if (kIsWeb) {
          _selectedWebMediaPath = pickedPath;
          _selectedProbePath = pickedPath;
        }
      });
      if (kIsWeb && previousWebPath != null && previousWebPath != pickedPath) {
        _retireWebMediaPath(previousWebPath);
      }
      _addLog("Selected file: $pickedPath");
    } catch (error) {
      _addLog('Unable to import the selected video: $error');
    }
  }

  Future<void> _transcodeVideo() async {
    if (_isTranscoding) {
      _addLog("Transcode already in progress.");
      return;
    }

    final exampleDirPath = await _exampleDirectoryPath();

    // Use picked file or generate test video
    String inputPath;
    String outputPath;

    final selectedInputPath = kIsWeb
        ? _selectedWebMediaPath
        : _transcodeInputPath;
    if (selectedInputPath != null && _exampleFileExists(selectedInputPath)) {
      inputPath = selectedInputPath;
      outputPath =
          _transcodeOutputPath ?? path.join(exampleDirPath, 'test_video.avi');
    } else {
      inputPath = path.join(exampleDirPath, 'test_video.mp4');
      outputPath = path.join(exampleDirPath, 'test_video.avi');

      // Check if source file exists
      if (!_exampleFileExists(inputPath)) {
        _addLog("⚠️ Source video not found. Generating test video first...");
        await _generateTestVideo();
      }

      if (!_exampleFileExists(inputPath)) {
        _addLog("❌ Failed to generate source video.");
        return;
      }
    }

    if (kIsWeb) {
      setState(() => _webDownloadableFiles.remove(outputPath));
    }

    setState(() {
      _isTranscoding = true;
      _transcodeProgress = 0.0;
      _transcodeStatus = 'Starting transcode...';
    });

    _addLog(
      "--- Transcoding: $inputPath → $outputPath ---",
      printToConsole: true,
    );

    final mediaInfoSession = FFprobeKit.getMediaInformation(inputPath);
    final mediaInfo = mediaInfoSession.getMediaInformation();
    final duration =
        (double.tryParse((mediaInfo?.duration ?? "0")) ?? 0) * 1000;

    final command =
        "-hide_banner -nostdin -i \"$inputPath\" -c:v mpeg4 -c:a aac -b:v 2M -y \"$outputPath\"";

    final session = FFmpegKit.createSession(command);
    session.setExpectedTranscodingDuration(
      Duration(milliseconds: duration.toInt()),
    );

    await session.executeAsync(
      logCallback: (log) {
        _addLog(log.message);
      },
      statisticsCallback: (statistics) {
        if (mounted) {
          setState(() {
            _transcodeProgress = statistics.transcodingProgress ?? 0.0;
            _transcodeStatus =
                'Time: ${(statistics.time / 1000).toStringAsFixed(1)}s | '
                'Time Elapsed: ${(statistics.timeElapsed / 1000).toStringAsFixed(1)}s | '
                'Speed: ${statistics.speed.toStringAsFixed(2)}x | '
                'Frame: ${statistics.videoFrameNumber} | '
                'Quality: ${statistics.videoQuality.toStringAsFixed(2)} | '
                'Progress: ${(statistics.transcodingProgressPercent ?? 0.0).toStringAsFixed(1)}% | '
                'Transcoding Progress: ${(statistics.transcodingProgress ?? 0.0).toStringAsFixed(1)} | '
                'Video Bitrate: ${statistics.bitrate} | '
                'Video FPS: ${statistics.videoFps} | '
                'Drop Frames: ${statistics.dropFrames} | '
                'Dup Frames: ${statistics.dupFrames}';
            _addLog(_transcodeStatus);
          });
        }
      },
      completeCallback: (session) {
        if (mounted) {
          setState(() {
            _isTranscoding = false;
            if (ReturnCode.isSuccess(session.getReturnCode())) {
              _transcodeProgress = 1.0;
              _transcodeStatus = '✅ Transcode complete!';
              if (kIsWeb) _webDownloadableFiles.add(outputPath);
              _addLog("✅ Video transcoded successfully to AVI!");
            } else {
              _transcodeStatus = '❌ Transcode failed.';
              _addLog("❌ Transcode failed. Code: ${session.getReturnCode()}");
            }
          });
        }
        _cleanupRetiredWebMediaPaths();
      },
    );
  }

  Future<void> _showSystemInfo() async {
    _addLog("--- System & Config Information ---", printToConsole: true);
    _addLog("FFmpeg Version: ${FFmpegKitConfig.getFFmpegVersion()}");
    _addLog("FFmpegKit Version: ${FFmpegKitConfig.getVersion()}");
    _addLog("Build Date: ${FFmpegKitConfig.getBuildDate()}");
    _addLog("Package Name: ${FFmpegKitConfig.getPackageName()}");
    _addLog(
      "Log Level: ${FFmpegKitConfig.logLevelToString(FFmpegKitConfig.getLogLevel())}",
    );
  }

  // Introspection API methods
  Future<void> _showFFmpegVersion() async {
    _addLog("--- FFmpeg Version ---", printToConsole: true);
    _addLog(FFmpegKitExtended.getFFmpegVersion());
  }

  Future<void> _showFFmpegArchitecture() async {
    _addLog("--- FFmpeg Architecture ---", printToConsole: true);
    _addLog(FFmpegKitExtended.getFFmpegArchitecture());
  }

  Future<void> _showFFmpegKitVersion() async {
    _addLog("--- FFmpegKit Version ---", printToConsole: true);
    _addLog(FFmpegKitExtended.getVersion());
  }

  Future<void> _showPackageName() async {
    _addLog("--- Package Name ---", printToConsole: true);
    _addLog(FFmpegKitExtended.getPackageName());
  }

  Future<void> _showExternalLibraries() async {
    _addLog("--- External Libraries ---", printToConsole: true);
    final libraries = FFmpegKitExtended.getExternalLibraries();
    if (libraries.isEmpty) {
      _addLog("No external libraries bundled");
    } else {
      _addLog(libraries);
    }
  }

  Future<void> _showBundleType() async {
    _addLog("--- Bundle Type ---", printToConsole: true);
    _addLog(FFmpegKitExtended.getBundleType());
  }

  Future<void> _showGplStatus() async {
    _addLog("--- GPL Status ---", printToConsole: true);
    _addLog(FFmpegKitExtended.isGpl() ? "GPL enabled" : "GPL disabled");
  }

  Future<void> _showNonfreeStatus() async {
    _addLog("--- Non-Free Status ---", printToConsole: true);
    _addLog(
      FFmpegKitExtended.isNonfree() ? "Non-free enabled" : "Non-free disabled",
    );
  }

  Future<void> _showRegisteredCodecs() async {
    _addLog("--- Registered Codecs ---", printToConsole: true);
    final codecs = FFmpegKitExtended.getRegisteredCodecs();
    _addLog(codecs.isEmpty ? "No codecs found" : codecs);
  }

  Future<void> _showRegisteredEncoders() async {
    _addLog("--- Registered Encoders ---", printToConsole: true);
    final encoders = FFmpegKitExtended.getRegisteredEncoders();
    _addLog(encoders.isEmpty ? "No encoders found" : encoders);
  }

  Future<void> _showRegisteredDecoders() async {
    _addLog("--- Registered Decoders ---", printToConsole: true);
    final decoders = FFmpegKitExtended.getRegisteredDecoders();
    _addLog(decoders.isEmpty ? "No decoders found" : decoders);
  }

  Future<void> _showRegisteredMuxers() async {
    _addLog("--- Registered Muxers ---", printToConsole: true);
    final muxers = FFmpegKitExtended.getRegisteredMuxers();
    _addLog(muxers.isEmpty ? "No muxers found" : muxers);
  }

  Future<void> _showRegisteredDemuxers() async {
    _addLog("--- Registered Demuxers ---", printToConsole: true);
    final demuxers = FFmpegKitExtended.getRegisteredDemuxers();
    _addLog(demuxers.isEmpty ? "No demuxers found" : demuxers);
  }

  Future<void> _showRegisteredFilters() async {
    _addLog("--- Registered Filters ---", printToConsole: true);
    final filters = FFmpegKitExtended.getRegisteredFilters();
    _addLog(filters.isEmpty ? "No filters found" : filters);
  }

  Future<void> _showRegisteredProtocols() async {
    _addLog("--- Registered Protocols ---", printToConsole: true);
    final protocols = FFmpegKitExtended.getRegisteredProtocols();
    _addLog(protocols.isEmpty ? "No protocols found" : protocols);
  }

  Future<void> _showRegisteredBitstreamFilters() async {
    _addLog("--- Registered Bitstream Filters ---", printToConsole: true);
    final bitstreamFilters = FFmpegKitExtended.getRegisteredBitstreamFilters();
    _addLog(
      bitstreamFilters.isEmpty
          ? "No bitstream filters found"
          : bitstreamFilters,
    );
  }

  Future<void> _showBuildConfiguration() async {
    _addLog("--- Build Configuration ---", printToConsole: true);
    final config = FFmpegKitExtended.getBuildConfiguration();
    _addLog(config.isEmpty ? "No build configuration found" : config);
  }

  Future<void> _showBuildDate() async {
    _addLog("--- Build Date ---", printToConsole: true);
    _addLog(FFmpegKitExtended.getBuildDate());
  }

  void _setLogLevel(LogLevel level) {
    setState(() {
      _currentLogLevel = level;
    });
    FFmpegKitConfig.setLogLevel(level);
    _addLog("Log level set to: ${FFmpegKitConfig.logLevelToString(level)}");
  }

  Future<void> _runCustomFFmpeg() async {
    final command = _ensureNoStdin(_ffmpegCommandController.text);
    _addLog("--- Running Custom FFmpeg: $command ---", printToConsole: true);
    await FFmpegKit.executeAsync(
      command,
      onLog: (log) {
        _addLog(log.message);
      },
      onComplete: (session) {
        _addLog("Return code: ${session.getReturnCode()}");
        _cleanupRetiredWebMediaPaths();
      },
    );
  }

  // --- Web remote URL: direct HTTP(S) input through the async APIs only ---

  // A ?remoteUrl= query parameter prefills the field on Web (a deep link). It
  // never starts an operation by itself.
  final TextEditingController _webRemoteUrlController = TextEditingController(
    text: kIsWeb && Uri.base.queryParameters['remoteUrl'] != null
        ? Uri.base.queryParameters['remoteUrl']!
        : "https://endpnt.com/hls/nasa4k/playlist.m3u8",
  );
  String _webRemoteState = "idle";
  String _webRemoteDetail = "";
  String? _webRemoteRecordingPath;
  void Function()? _webRemoteCancelAction;
  bool _webRemoteCancelRequested = false;
  int _webRemoteRecordingCounter = 0;

  bool get _webRemoteBusy =>
      _webRemoteState == "loading" ||
      _webRemoteState == "playing" ||
      _webRemoteState == "recording";

  /// Returns a finite validation message, or null when [raw] is a direct URL.
  String? _validateWebRemoteUrl(String raw) {
    final url = raw.trim();
    final uri = Uri.tryParse(url);
    if (url.isEmpty || uri == null || uri.host.isEmpty) {
      return "Enter a direct http:// or https:// URL.";
    }
    if (uri.scheme != "http" && uri.scheme != "https") {
      return "Only direct http:// and https:// URLs run on Web. RTMP, RTSP, file and chained schemes such as hls+https:// are not supported.";
    }
    if (url.contains('"') || url.contains(RegExp(r"\s"))) {
      return "The URL must not contain spaces or double quotes.";
    }
    return null;
  }

  /// Maps captured FFmpeg output to a short, honest failure reason.
  String _diagnoseWebRemoteFailure(String output) {
    final text = output.toLowerCase();
    if (text.contains("eperm") ||
        text.contains("operation not permitted") ||
        text.contains("pthread")) {
      return "The Web runtime could not open this network input (EPERM). Check that the URL is a direct media URL. Remote segments listed in a local playlist fail the same way.";
    }
    if (text.contains("403")) {
      return "The server refused the request (HTTP 403).";
    }
    if (text.contains("404")) return "The media was not found (HTTP 404).";
    if (text.contains("cors") ||
        text.contains("failed to fetch") ||
        text.contains("cross-origin")) {
      return "The browser blocked the request (CORS). The server must allow this page's origin and expose Content-Range.";
    }
    return "The command failed. See the output below.";
  }

  void _setWebRemote(String state, [String detail = ""]) {
    if (!mounted) return;
    setState(() {
      _webRemoteState = state;
      _webRemoteDetail = detail;
    });
  }

  /// Keeps a cancel action only while the operation is still running.
  void _trackWebRemoteAction(void Function() cancel) {
    if (!_webRemoteBusy) return;
    if (_webRemoteCancelRequested) {
      cancel();
    } else {
      _webRemoteCancelAction = cancel;
    }
  }

  Future<void> _runWebRemoteFFprobe(String command, String label) async {
    _webRemoteCancelRequested = false;
    _setWebRemote("loading", label);
    try {
      // Register the cancel action before waiting, so Stop works during the probe.
      final session = FFprobeKit.createSession(command);
      _trackWebRemoteAction(session.cancel);
      await session.executeAsync(
        completeCallback: (completed) {
          _webRemoteCancelAction = null;
          final output = completed.getOutput() ?? "";
          if (_webRemoteCancelRequested) {
            _setWebRemote("cancelled", "Probe cancelled.");
          } else if (completed.getReturnCode() == 0) {
            _setWebRemote("completed", output);
          } else {
            _setWebRemote(
              "failed",
              "${_diagnoseWebRemoteFailure(output)}\n\n$output",
            );
          }
        },
      );
    } catch (error) {
      _webRemoteCancelAction = null;
      _setWebRemote("failed", "$error");
    }
  }

  Future<void> _runWebRemoteProbe() async {
    final url = _webRemoteUrlController.text.trim();
    final invalid = _validateWebRemoteUrl(url);
    if (invalid != null) {
      _setWebRemote("failed", invalid);
      return;
    }
    await _runWebRemoteFFprobe(
      '-hide_banner -v error -show_format -show_streams -of json "$url"',
      "Probing $url",
    );
  }

  Future<void> _runWebRemotePlay() async {
    final url = _webRemoteUrlController.text.trim();
    final invalid = _validateWebRemoteUrl(url);
    if (invalid != null) {
      _setWebRemote("failed", invalid);
      return;
    }
    _webRemoteCancelRequested = false;
    _setWebRemote("loading", "Starting playback of $url");
    try {
      await _prepareSurface();
      final surface = await FFplaySurface.create();
      if (surface != null && mounted) {
        setState(() => _surface = surface);
      }
      final session = await FFplayKit.executeAsync(
        '-hide_banner -loglevel info -i "$url"',
        onComplete: (session) {
          _webRemoteCancelAction = null;
          final output = session.getOutput() ?? "";
          if (_webRemoteCancelRequested) {
            _setWebRemote("cancelled", "Playback stopped.");
          } else if (session.getReturnCode() == 0) {
            _setWebRemote(
              "completed",
              "Playback reached the end of the media.",
            );
          } else {
            _setWebRemote(
              "failed",
              "${_diagnoseWebRemoteFailure(output)}\n\n$output",
            );
          }
        },
      );
      _attachPositionStream(session);
      if (_webRemoteState == "loading" && !_webRemoteCancelRequested) {
        _setWebRemote(
          "playing",
          "Playing $url. Video renders in the FFplay tab.",
        );
      }
      _trackWebRemoteAction(session.stop);
    } catch (error) {
      _webRemoteCancelAction = null;
      _setWebRemote("failed", "$error");
    }
  }

  Future<void> _runWebRemoteRecord() async {
    final url = _webRemoteUrlController.text.trim();
    final invalid = _validateWebRemoteUrl(url);
    if (invalid != null) {
      _setWebRemote("failed", invalid);
      return;
    }
    _webRemoteRecordingCounter++;
    final previousPath = _webRemoteRecordingPath;
    if (previousPath != null && FFmpegKitWebFiles.exists(previousPath)) {
      FFmpegKitWebFiles.deleteFile(previousPath);
    }
    // Recordings live in the Wasm MEMFS until the user downloads them.
    final outputPath =
        "/tmp/web-remote-recording-$_webRemoteRecordingCounter.mkv";
    if (FFmpegKitWebFiles.exists(outputPath)) {
      FFmpegKitWebFiles.deleteFile(outputPath);
    }
    _webRemoteRecordingPath = null;
    _webRemoteCancelRequested = false;
    _setWebRemote("recording", "Recording 15 seconds to $outputPath");
    try {
      // Register the cancel action before waiting, so Stop works during the recording.
      final session = FFmpegKit.createSession(
        '-hide_banner -nostdin -y -t 15 -i "$url" '
        '-map 0:v:0 -map 0:a:0? -c copy -f matroska "$outputPath"',
      );
      _trackWebRemoteAction(session.cancel);
      await session.executeAsync(
        statisticsCallback: (statistics) {
          if (_webRemoteCancelRequested) return;
          final elapsed = (statistics.time / 1000).clamp(0, 15).toDouble();
          final percent =
              statistics.transcodingProgressPercent ??
              (elapsed / 15 * 100).round().clamp(0, 100);
          _setWebRemote(
            "recording",
            "Recording: $percent% · ${statistics.size} bytes · "
                "${elapsed.toStringAsFixed(1)} / 15 s",
          );
        },
        completeCallback: (completed) {
          _webRemoteCancelAction = null;
          final output = completed.getOutput() ?? "";
          if (_webRemoteCancelRequested) {
            if (FFmpegKitWebFiles.exists(outputPath)) {
              FFmpegKitWebFiles.deleteFile(outputPath);
            }
            _setWebRemote("cancelled", "Recording cancelled.");
            return;
          }
          final bytes = FFmpegKitWebFiles.exists(outputPath)
              ? FFmpegKitWebFiles.readFile(outputPath).length
              : 0;
          if (completed.getReturnCode() == 0 && bytes > 0) {
            _webRemoteRecordingPath = outputPath;
            _setWebRemote(
              "completed",
              "Recorded $bytes bytes to $outputPath. Probe or download it.",
            );
          } else {
            if (FFmpegKitWebFiles.exists(outputPath)) {
              FFmpegKitWebFiles.deleteFile(outputPath);
            }
            _setWebRemote(
              "failed",
              "${_diagnoseWebRemoteFailure(output)}\n\n$output",
            );
          }
        },
      );
    } catch (error) {
      _webRemoteCancelAction = null;
      if (FFmpegKitWebFiles.exists(outputPath)) {
        FFmpegKitWebFiles.deleteFile(outputPath);
      }
      _setWebRemote("failed", "$error");
    }
  }

  /// Cancels the running Web remote operation once.
  void _cancelWebRemote() {
    if (!_webRemoteBusy || _webRemoteCancelRequested) return;
    final cancel = _webRemoteCancelAction;
    _webRemoteCancelAction = null;
    _webRemoteCancelRequested = true;
    try {
      cancel?.call();
    } catch (error) {
      _addLog("Web remote cancel failed: $error");
    }
    // Completion owns the terminal state; another operation cannot start yet.
    if (_webRemoteBusy) {
      _setWebRemote(
        _webRemoteState,
        "Cancellation requested; waiting for completion.",
      );
    }
  }

  Future<void> _runRemoteRecordingScenario() async {
    final url = _remoteStreamUrlController.text.trim();
    if (url.isEmpty) {
      _addLog("Remote stream URL is empty.");
      return;
    }

    _remoteScenarioLogQueue = Future.value();
    if (mounted) {
      setState(() {});
    }

    final tempDir = await getTemporaryDirectory();
    final scenarioDir = Directory(
      path.join(tempDir.path, "ffmpeg_kit_extended_flutter_example"),
    );
    await scenarioDir.create(recursive: true);

    final logFile = File(
      path.join(scenarioDir.path, "ffmpeg_kit_extended_flutter_example.log"),
    );
    await logFile.writeAsString('', flush: true);
    _remoteScenarioLogPath = logFile.path;

    _logRemoteScenario("--- Running remote stream recording ---");
    _logRemoteScenario("Source: $url");
    _logRemoteScenario("Output dir: ${scenarioDir.path}");
    _logRemoteScenario("Log file: ${logFile.path}");

    final outputFile = path.join(
      scenarioDir.path,
      "remote_recording_${_recordingCounter++}.ts",
    );

    if (File(outputFile).existsSync()) {
      File(outputFile).deleteSync();
    }

    final job = _startRemoteRecordingJob(
      label: _recordingCounter.toString(),
      url: url,
      outputPath: outputFile,
    );

    _remoteScenarioJobs.add(job);
    if (mounted) {
      setState(() {});
    }

    _launchRemoteRecordingJob(job);
  }

  _RemoteRecordingScenarioJob _startRemoteRecordingJob({
    required String label,
    required String url,
    required String outputPath,
    VoidCallback? onFirstComplete,
  }) {
    final job = _RemoteRecordingScenarioJob(
      label: label,
      outputPath: outputPath,
    );

    final normalizedOutputPath = _normalizeFfmpegPath(outputPath);
    final outputFile = File(normalizedOutputPath);
    if (outputFile.existsSync()) {
      outputFile.deleteSync();
    }

    final command = [
      '-y',
      '-nostdin',
      '-hide_banner',
      '-loglevel',
      'error',
      '-reconnect',
      '1',
      '-reconnect_at_eof',
      '1',
      '-reconnect_streamed',
      '1',
      '-reconnect_delay_max',
      '5',
      '-rw_timeout',
      '5000000',
      '-max_delay',
      '5000000',
      '-i',
      '"$url"',
      '-map',
      '0',
      '-c',
      'copy',
      '-f',
      'mpegts',
      '"$normalizedOutputPath"',
    ].join(' ');

    final session = FFmpegKit.createSession(command);
    job.session = session;
    job.sessionId = session.getSessionId();

    session.setLogCallback((log) {
      _queueRemoteScenarioLog(
        "[$label][log][session=${log.sessionId}] ${log.message}",
      );
      if (log.logLevel.value <= LogLevel.warning.value) {
        _addLog("[$label] ${log.message}", printToConsole: true);
      }
    });

    session.setStatisticsCallback((statistics) {
      job.sessionId = statistics.sessionId;
      _queueRemoteScenarioLog(
        "[$label][stats][session=${statistics.sessionId}] "
        "time=${statistics.time} size=${statistics.size} "
        "bitrate=${statistics.bitrate} speed=${statistics.speed} "
        "fps=${statistics.videoFps} frame=${statistics.videoFrameNumber}",
      );
      if (statistics.size > 0 && !job.startedWriting.isCompleted) {
        job.startedWriting.complete();
        _logRemoteScenario(
          "[$label] started writing output (${statistics.size} bytes)",
        );
      }

      final now = DateTime.now();
      if (mounted &&
          now.difference(_lastRemoteScenarioStatsUiUpdate) >=
              const Duration(milliseconds: 500)) {
        _lastRemoteScenarioStatsUiUpdate = now;
        setState(() {});
      }
    });

    session.setCompleteCallback((completedSession) {
      job.completed = true;
      job.returnCode = completedSession.getReturnCode();
      final returnCode = completedSession.getReturnCode();
      _logRemoteScenario(
        "[$label] complete. sessionId=${completedSession.getSessionId()} returnCode=$returnCode",
      );
      if (mounted) {
        setState(() {});
      }

      if (onFirstComplete != null) {
        onFirstComplete();
      }

      _logRemoteScenario(
        "[$label] complete callback fired. sessionId=${completedSession.getSessionId()} returnCode=${completedSession.getReturnCode()}",
      );
    });

    _logRemoteScenario(
      "[$label] session started. sessionId=${job.sessionId} output=${job.outputPath}",
    );
    if (mounted) {
      setState(() {});
    }
    return job;
  }

  void _launchRemoteRecordingJob(_RemoteRecordingScenarioJob job) {
    final session = job.session;
    if (session == null) {
      return;
    }

    unawaited(() async {
      try {
        await session.executeAsync();
      } catch (error, stackTrace) {
        _logRemoteScenario(
          "[${job.label}] session execution failed: $error\n$stackTrace",
        );
        job.completed = true;
        if (mounted) {
          setState(() {});
        }
      }
    }());
  }

  String _normalizeFfmpegPath(String input) {
    if (platform.isWindows) {
      return input.replaceAll('\\', '/');
    }
    return input;
  }

  String _commandWithInputFile(String command, String filePath) {
    final inputPattern = RegExp(
      r"""(^|\s)-i(?=\s|$)(?:\s+(?:"(?:\\.|[^"])*"|'(?:\\.|[^'])*'|[^\s]+))?""",
    );
    final quotedPath = '"$filePath"';
    final match = inputPattern.firstMatch(command);
    if (match != null) {
      return command.replaceRange(
        match.start,
        match.end,
        '${match.group(1)}-i $quotedPath',
      );
    }

    final appendBase = command
        .replaceFirst(RegExp(r'(^|\s)-version(?=\s|$)'), '')
        .trim();
    final prefix = appendBase.isEmpty ? '' : '$appendBase ';
    return '$prefix-i $quotedPath';
  }

  String _ensureNoStdin(String command) {
    final trimmed = command.trim();
    if (RegExp(r'(^|\s)-nostdin(?:\s|$)').hasMatch(trimmed)) {
      return trimmed;
    }
    return '-nostdin $trimmed';
  }

  String _removeNoStdin(String command) {
    return command
        .replaceAll(RegExp(r'(^|\s)-nostdin(?=\s|$)'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  // --- FFprobe Examples ---

  Future<void> _runFFprobeVersion() async {
    _addLog("--- Running FFprobe -version (Async) ---", printToConsole: true);
    await FFprobeKit.executeAsync(
      "-version",
      onComplete: (session) {
        final output = session.getOutput();
        _addLog(output ?? "No output found in session object.");
        _addLog("Return code: ${session.getReturnCode()}");
      },
    );
  }

  void _runFFprobeInfoSync() {
    _addLog("--- Running FFprobe -version (Sync) ---", printToConsole: true);
    // Capturing output from synchronous ffprobe call.
    final session = FFprobeKit.execute("-version");
    final output = session.getOutput();

    _addLog("Output captured from sync ffprobe:");
    _addLog(output ?? "No output captured.");
    _addLog("Return code: ${session.getReturnCode()}");
  }

  Future<void> _pickProbeFile() async {
    try {
      final result = await FilePicker.pickFiles();
      if (result.isEmpty) return;
      final file = result.single;
      final previousWebPath = _selectedWebMediaPath;
      final pickedPath = kIsWeb
          ? _importWebMedia(file.name, await file.readAsBytes())
          : file.path;
      if (pickedPath == null) {
        _addLog('The selected file did not provide a local path.');
        return;
      }
      setState(() {
        _selectedProbePath = pickedPath;
        if (kIsWeb) {
          _selectedWebMediaPath = pickedPath;
          _transcodeInputPath = pickedPath;
          _transcodeOutputPath = path.join(
            '/tmp',
            '${path.basenameWithoutExtension(pickedPath)}_transcoded.avi',
          );
        }
      });
      if (kIsWeb && previousWebPath != null && previousWebPath != pickedPath) {
        _retireWebMediaPath(previousWebPath);
      }
      _addLog("Selected for probe: $pickedPath");
    } catch (error) {
      _addLog('Unable to import the selected media: $error');
    }
  }

  Future<void> _pickCommandInputFile(TextEditingController controller) async {
    if (!kIsWeb) return;
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result.isEmpty) return;
      final file = result.single;
      final previousWebPath = _selectedWebMediaPath;
      final pickedPath = _importWebMedia(file.name, await file.readAsBytes());
      final baseName = path.basenameWithoutExtension(pickedPath);
      controller.text = _commandWithInputFile(controller.text, pickedPath);
      setState(() {
        _selectedProbePath = pickedPath;
        _selectedWebMediaPath = pickedPath;
        _transcodeInputPath = pickedPath;
        _transcodeOutputPath = path.join('/tmp', '${baseName}_transcoded.avi');
      });
      if (previousWebPath != null && previousWebPath != pickedPath) {
        _retireWebMediaPath(previousWebPath);
      }
      _addLog('Selected input file: $pickedPath');
    } catch (error) {
      _addLog('Unable to import the selected input file: $error');
    }
  }

  Future<void> _runMediaInformation() async {
    // Use picked file, local test video, or remote URL fallback.
    final exampleDirPath = await _exampleDirectoryPath();
    final localTestPath = path.join(exampleDirPath, 'test_video.mp4');

    final String probePath;
    if (kIsWeb &&
        _selectedWebMediaPath != null &&
        _exampleFileExists(_selectedWebMediaPath!)) {
      probePath = _selectedWebMediaPath!;
    } else if (_selectedProbePath != null &&
        _exampleFileExists(_selectedProbePath!)) {
      probePath = _selectedProbePath!;
    } else if (_exampleFileExists(localTestPath)) {
      probePath = localTestPath;
    } else if (kIsWeb) {
      _addLog(
        'Pick a local file or generate the example video before probing.',
      );
      return;
    } else {
      probePath =
          "https://raw.githubusercontent.com/tanersener/ffmpeg-kit/master/test-data/video.mp4";
    }

    _addLog(
      "--- Getting Media Information for $probePath ---",
      printToConsole: true,
    );

    await FFprobeKit.getMediaInformationAsync(
      probePath,
      onComplete: (session) {
        if (session.isMediaInformationSession()) {
          final mediaInfoSession = session as MediaInformationSession;
          final info = mediaInfoSession.getMediaInformation();
          if (info != null) {
            _addLog("Format: ${info.format}");
            _addLog("Duration: ${info.duration}s");
            _addLog("Bitrate: ${info.bitrate}");
            _addLog("Streams count: ${info.streams.length}");
            _addLog("Media Information: ${info.allPropertiesJson}");
            for (var i = 0; i < info.streams.length; i++) {
              final stream = info.streams[i];
              _addLog(
                " Stream #$i: ${stream.type} (${stream.codec}) - ${stream.width}x${stream.height}",
              );
            }
          } else {
            _addLog("Failed to retrieve media information. Check logs below:");
            _addLog(session.getLogs() ?? "Empty logs.");
          }
        }
        _cleanupRetiredWebMediaPaths();
      },
    );
  }

  Future<void> _runCustomFFprobe() async {
    final command = _removeNoStdin(_ffprobeCommandController.text);
    _addLog("--- Running Custom FFprobe: $command ---", printToConsole: true);
    final releaseMediaOperation = _beginCustomWebMediaOperation();
    var submitted = false;
    try {
      await FFprobeKit.executeAsync(
        command,
        onComplete: (session) {
          try {
            final output = session.getOutput();
            if (output != null) _addLog(output);
            _addLog("Return code: ${session.getReturnCode()}");
          } finally {
            releaseMediaOperation();
          }
        },
      );
      submitted = true;
    } catch (_) {
      if (!submitted) releaseMediaOperation();
      rethrow;
    }
  }

  // --- FFplay Example ---

  Future<void> _prepareSurface() async {
    final old = _surface;
    if (mounted) {
      setState(() {
        _surface = null;
        _hasVideo = false;
      });
    }
    await old?.release();
  }

  void _attachPositionStream(
    FFplaySession session, {
    void Function()? onTerminal,
  }) {
    _positionSub?.cancel();
    _videoSizeSub?.cancel();
    setState(() {
      _hasActiveSession = true;
      _playbackPosition = 0.0;
      _videoWidth = 0;
      _videoHeight = 0; // Reset until actual dimensions arrive
      _hasVideo = false; // Unknown until first frame arrives
      _volume = session.getVolume(); // Sync volume with current session
      _addLog("Volume: $_volume");
    });

    // Capture surface at subscription time to avoid race conditions.
    final surfaceToRelease = _surface;

    _positionSub = session.positionStream.listen(
      (pos) {
        // The position label only displays tenths of a second. Avoid rebuilding
        // the full example screen for every ~16 ms stream tick, especially in
        // Flutter's instrumented Web debug build.
        if (mounted && (pos - _playbackPosition).abs() >= 0.1) {
          setState(() {
            _playbackPosition = pos;
          });
        }
      },
      onDone: () {
        if (mounted) setState(() => _hasActiveSession = false);
        _cleanupRetiredWebMediaPaths();
        onTerminal?.call();
        surfaceToRelease?.release().then((_) {
          if (mounted) {
            setState(() {
              // Only clear if this is still the current surface
              if (_surface == surfaceToRelease) {
                _surface = null;
              }
            });
          }
        });
      },
    );
    _videoSizeSub = session.videoSizeStream.listen((size) {
      final (w, h) = size;
      if (mounted && w > 0 && h > 0) {
        setState(() {
          _videoWidth = w;
          _videoHeight = h;
          _hasVideo = true;
        });
      }
    });
  }

  Future<void> _runFFplay(String fileName) async {
    final exampleDirPath = await _exampleDirectoryPath();
    final localPath = path.isAbsolute(fileName)
        ? fileName
        : path.join(exampleDirPath, fileName);

    if (!_exampleFileExists(localPath)) {
      _addLog("⚠️ File not found: $localPath. Please generate it first!");
      return;
    }

    _addLog("--- Starting FFplay for $localPath ---", printToConsole: true);

    // Clear existing surface and create new one.
    await _prepareSurface();
    final surface = await FFplaySurface.create();
    if (surface != null && mounted) {
      setState(() => _surface = surface);
    }

    final session = await FFplayKit.executeAsync(
      "-hide_banner -loglevel ${_currentLogLevel.name} "
      "-autoexit -i \"$localPath\"",
      onComplete: (session) {
        _addLog("FFplay playback of $fileName finished");
        _cleanupRetiredWebMediaPaths();
      },
      onLog: (log) => _addLog("FFplay: ${log.message}"),
    );
    _attachPositionStream(session);
    _addLog("Playback started.");
  }

  Future<void> _playImportedMedia() async {
    final filePath = kIsWeb
        ? _selectedWebMediaPath
        : _selectedProbePath ?? _transcodeInputPath;
    if (filePath == null || !_exampleFileExists(filePath)) {
      _addLog('Pick a local media file before playing imported media.');
      return;
    }
    await _runFFplay(filePath);
  }

  Future<void> _runCustomFFplay() async {
    final command = _ffplayCommandController.text.trim();
    _addLog("--- Running Custom FFplay: $command ---", printToConsole: true);

    final releaseMediaOperation = _beginCustomWebMediaOperation();
    var submitted = false;
    try {
      await _prepareSurface();
      final surface = await FFplaySurface.create();
      if (surface != null && mounted) {
        setState(() => _surface = surface);
      }

      final session = await FFplayKit.executeAsync(
        command,
        onComplete: (session) {
          try {
            final output = session.getOutput();
            _addLog("FFplay playback finished. Output: $output");
          } finally {
            releaseMediaOperation();
          }
        },
      );
      submitted = true;
      _attachPositionStream(session, onTerminal: releaseMediaOperation);
    } catch (_) {
      if (!submitted) releaseMediaOperation();
      rethrow;
    }
  }

  void _seekForward() {
    if (_hasActiveSession) {
      final newPosition = FFplayKit.position + 1.0;
      FFplayKit.seek(newPosition);
    }
  }

  void _seekBackward() {
    if (_hasActiveSession) {
      final newPosition = (FFplayKit.position - 1.0).clamp(
        0.0,
        double.infinity,
      );
      FFplayKit.seek(newPosition);
    }
  }

  void _setVolume(double volume) {
    if (_hasActiveSession) {
      final session = FFplayKit.getCurrentSession();
      if (session != null) {
        session.setVolume(volume);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Scaffold(
          key: const ValueKey<String>('app.root'),
          appBar: AppBar(
            title: Text(isMobile ? 'FFmpeg Kit' : 'FFmpeg Kit Extended'),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  key: const ValueKey<String>('tab.ffmpeg'),
                  icon: const Icon(Icons.movie),
                  text: isMobile ? null : "FFmpeg",
                ),
                Tab(
                  key: const ValueKey<String>('tab.stream'),
                  icon: const Icon(Icons.sensors),
                  text: isMobile ? null : "Stream",
                ),
                Tab(
                  key: const ValueKey<String>('tab.ffprobe'),
                  icon: const Icon(Icons.info),
                  text: isMobile ? null : "FFprobe",
                ),
                Tab(
                  key: const ValueKey<String>('tab.ffplay'),
                  icon: const Icon(Icons.play_arrow),
                  text: isMobile ? null : "FFplay",
                ),
                Tab(
                  key: const ValueKey<String>('tab.transcode'),
                  icon: const Icon(Icons.transform),
                  text: isMobile ? null : "Transcode",
                ),
              ],
            ),
            actions: [
              PopupMenuButton<LogLevel>(
                key: const ValueKey<String>('toolbar.log-level'),
                icon: const Icon(Icons.tune),
                tooltip: "Log Level",
                onSelected: _setLogLevel,
                itemBuilder: (BuildContext context) {
                  return LogLevel.values.map((LogLevel level) {
                    return PopupMenuItem<LogLevel>(
                      value: level,
                      child: Row(
                        children: [
                          Icon(
                            _currentLogLevel == level
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(level.name.toUpperCase()),
                        ],
                      ),
                    );
                  }).toList();
                },
              ),
              PopupMenuButton<String>(
                key: const ValueKey<String>('toolbar.system-info'),
                icon: const Icon(Icons.settings),
                tooltip: "System Info",
                onSelected: (String value) {
                  switch (value) {
                    case 'basic_info':
                      _showSystemInfo();
                      break;
                    case 'ffmpeg_version':
                      _showFFmpegVersion();
                      break;
                    case 'ffmpeg_arch':
                      _showFFmpegArchitecture();
                      break;
                    case 'ffmpegkit_version':
                      _showFFmpegKitVersion();
                      break;
                    case 'package_name':
                      _showPackageName();
                      break;
                    case 'external_libs':
                      _showExternalLibraries();
                      break;
                    case 'bundle_type':
                      _showBundleType();
                      break;
                    case 'gpl_status':
                      _showGplStatus();
                      break;
                    case 'nonfree_status':
                      _showNonfreeStatus();
                      break;
                    case 'codecs':
                      _showRegisteredCodecs();
                      break;
                    case 'encoders':
                      _showRegisteredEncoders();
                      break;
                    case 'decoders':
                      _showRegisteredDecoders();
                      break;
                    case 'muxers':
                      _showRegisteredMuxers();
                      break;
                    case 'demuxers':
                      _showRegisteredDemuxers();
                      break;
                    case 'filters':
                      _showRegisteredFilters();
                      break;
                    case 'protocols':
                      _showRegisteredProtocols();
                      break;
                    case 'bitstream_filters':
                      _showRegisteredBitstreamFilters();
                      break;
                    case 'build_config':
                      _showBuildConfiguration();
                      break;
                    case 'build_date':
                      _showBuildDate();
                      break;
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    const PopupMenuItem<String>(
                      key: ValueKey<String>('system-info.basic'),
                      value: 'basic_info',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline),
                          SizedBox(width: 8),
                          Text('Basic System Info'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      key: ValueKey<String>('system-info.ffmpeg-version'),
                      value: 'ffmpeg_version',
                      child: Row(
                        children: [
                          Icon(Icons.verified),
                          SizedBox(width: 8),
                          Text('FFmpeg Version'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'ffmpeg_arch',
                      child: Row(
                        children: [
                          Icon(Icons.memory),
                          SizedBox(width: 8),
                          Text('FFmpeg Architecture'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      key: ValueKey<String>('system-info.ffmpegkit-version'),
                      value: 'ffmpegkit_version',
                      child: Row(
                        children: [
                          Icon(Icons.info),
                          SizedBox(width: 8),
                          Text('FFmpegKit Version'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'package_name',
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined),
                          SizedBox(width: 8),
                          Text('Package Name'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'external_libs',
                      child: Row(
                        children: [
                          Icon(Icons.library_books),
                          SizedBox(width: 8),
                          Text('External Libraries'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      key: ValueKey<String>('system-info.bundle'),
                      value: 'bundle_type',
                      child: Row(
                        children: [
                          Icon(Icons.category),
                          SizedBox(width: 8),
                          Text('Bundle Type'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'gpl_status',
                      child: Row(
                        children: [
                          Icon(Icons.gavel),
                          SizedBox(width: 8),
                          Text('GPL Status'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'nonfree_status',
                      child: Row(
                        children: [
                          Icon(Icons.lock),
                          SizedBox(width: 8),
                          Text('Non-Free Status'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'codecs',
                      child: Row(
                        children: [
                          Icon(Icons.video_settings),
                          SizedBox(width: 8),
                          Text('Registered Codecs'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'encoders',
                      child: Row(
                        children: [
                          Icon(Icons.upload),
                          SizedBox(width: 8),
                          Text('Registered Encoders'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'decoders',
                      child: Row(
                        children: [
                          Icon(Icons.download),
                          SizedBox(width: 8),
                          Text('Registered Decoders'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'muxers',
                      child: Row(
                        children: [
                          Icon(Icons.merge_type),
                          SizedBox(width: 8),
                          Text('Registered Muxers'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'demuxers',
                      child: Row(
                        children: [
                          Icon(Icons.call_split),
                          SizedBox(width: 8),
                          Text('Registered Demuxers'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'filters',
                      child: Row(
                        children: [
                          Icon(Icons.filter_alt),
                          SizedBox(width: 8),
                          Text('Registered Filters'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'protocols',
                      child: Row(
                        children: [
                          Icon(Icons.link),
                          SizedBox(width: 8),
                          Text('Registered Protocols'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'bitstream_filters',
                      child: Row(
                        children: [
                          Icon(Icons.tune),
                          SizedBox(width: 8),
                          Text('Registered Bitstream Filters'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'build_config',
                      child: Row(
                        children: [
                          Icon(Icons.build),
                          SizedBox(width: 8),
                          Text('Build Configuration'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      key: ValueKey<String>('system-info.build-date'),
                      value: 'build_date',
                      child: Row(
                        children: [
                          Icon(Icons.date_range),
                          SizedBox(width: 8),
                          Text('Build Date'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
              IconButton(
                key: const ValueKey<String>('toolbar.clear-logs'),
                icon: const Icon(Icons.delete),
                onPressed: _clearLogs,
                tooltip: "Clear Logs",
              ),
              IconButton(
                key: const ValueKey<String>('toolbar.permissions'),
                icon: const Icon(Icons.verified_user),
                onPressed: _checkPermissions,
                tooltip: "Check / Request Permissions",
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(flex: isMobile ? 3 : 2, child: _buildTabBarView()),
              const Divider(height: 1),
              Expanded(flex: isMobile ? 2 : 1, child: _buildLogView()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildFFmpegTab(),
        _buildStreamScenarioTab(),
        _buildFFprobeTab(),
        _buildFFplayTab(),
        _buildTranscodeTab(),
      ],
    );
  }

  Widget _buildLogView() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: TextField(
          key: const ValueKey<String>('logs.output'),
          controller: _outputController,
          maxLines: null,
          readOnly: true,
          style: const TextStyle(
            color: Colors.greenAccent,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
          decoration: const InputDecoration(border: InputBorder.none),
        ),
      ),
    );
  }

  Widget _buildFFmpegTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _demoButton(
                _generateTestVideo,
                Icons.video_call,
                "Gen Video",
                key: const ValueKey<String>('ffmpeg.generate-video'),
              ),
              _demoButton(
                _generateTestAudio,
                Icons.audiotrack,
                "Gen Audio",
                key: const ValueKey<String>('ffmpeg.generate-audio'),
              ),
              _demoButton(
                _runFFmpegVersion,
                Icons.bolt,
                "Async Version",
                key: const ValueKey<String>('ffmpeg.version.async'),
              ),
              _demoButton(
                _runFFmpegInfoSync,
                Icons.timer,
                "Sync Version",
                key: const ValueKey<String>('ffmpeg.version.awaited'),
              ),
              _demoButton(
                () async {
                  _addLog("--- Running Help ---", printToConsole: true);
                  await FFmpegKit.executeAsync(
                    "-nostdin -h",
                    onLog: (l) => _addLog(l.message),
                  );
                },
                Icons.help_outline,
                "Help",
                key: const ValueKey<String>('ffmpeg.help'),
              ),
            ],
          ),
          if (kIsWeb &&
              (_webDownloadableFiles.contains('/tmp/test_video.mp4') ||
                  _webDownloadableFiles.contains('/tmp/test_audio.wav'))) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (_webDownloadableFiles.contains('/tmp/test_video.mp4'))
                  _demoButton(
                    () => _downloadWebFile('/tmp/test_video.mp4'),
                    Icons.download,
                    'Download MP4',
                    key: const ValueKey<String>('ffmpeg.download-mp4'),
                  ),
                if (_webDownloadableFiles.contains('/tmp/test_audio.wav'))
                  _demoButton(
                    () => _downloadWebFile('/tmp/test_audio.wav'),
                    Icons.download,
                    'Download WAV',
                    key: const ValueKey<String>('ffmpeg.download-wav'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          _buildCustomCommandSection(
            _ffmpegCommandController,
            _runCustomFFmpeg,
            "Enter FFmpeg command",
            inputKey: const ValueKey<String>('ffmpeg.command.input'),
            runKey: const ValueKey<String>('ffmpeg.command.run'),
            onPickFile: kIsWeb
                ? () => _pickCommandInputFile(_ffmpegCommandController)
                : null,
            pickKey: const ValueKey<String>('ffmpeg.command.pick-file'),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamScenarioTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Native builds keep the dart:io recording scenario. Web uses the
          // MEMFS-backed remote URL panel instead.
          if (kIsWeb)
            _buildWebRemoteSection()
          else
            _buildRemoteRecordingScenarioSection(),
          const SizedBox(height: 20),
          _buildActiveSessionsPanel(),
        ],
      ),
    );
  }

  Widget _buildFFprobeTab() {
    final selectedProbePath = kIsWeb
        ? _selectedWebMediaPath
        : _selectedProbePath;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedProbePath != null) ...[
            Text(
              "Selected: ${path.basename(selectedProbePath)}",
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _demoButton(
                _pickProbeFile,
                Icons.file_open,
                "Pick File",
                key: const ValueKey<String>('ffprobe.pick-file'),
              ),
              _demoButton(
                _runMediaInformation,
                Icons.analytics,
                "Get Media Info",
                key: const ValueKey<String>('ffprobe.media-info'),
              ),
              _demoButton(
                _runFFprobeVersion,
                Icons.bolt,
                "Async Version",
                key: const ValueKey<String>('ffprobe.version.async'),
              ),
              _demoButton(
                _runFFprobeInfoSync,
                Icons.timer,
                "Sync Version",
                key: const ValueKey<String>('ffprobe.version.awaited'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildCustomCommandSection(
            _ffprobeCommandController,
            _runCustomFFprobe,
            "Enter FFprobe command",
            inputKey: const ValueKey<String>('ffprobe.command.input'),
            runKey: const ValueKey<String>('ffprobe.command.run'),
          ),
        ],
      ),
    );
  }

  Widget _buildFFplayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasVideo && _surface != null) ...[
            Center(
              child: Stack(
                children: [
                  FFplayView(
                    key: const ValueKey<String>('ffplay.video-surface'),
                    surface: _surface!,
                    controller: _fsController,
                    aspectRatio: _videoWidth > 0 && _videoHeight > 0
                        ? _videoWidth / _videoHeight
                        : null,
                    videoWidth: _videoWidth > 0 ? _videoWidth : null,
                    videoHeight: _videoHeight > 0 ? _videoHeight : null,
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: ListenableBuilder(
                      listenable: _fsController,
                      builder: (ctx, _) => IconButton(
                        icon: Icon(
                          _fsController.isFullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                        ),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                        ),
                        onPressed: () => _fsController.isFullscreen
                            ? _fsController.exitFullscreen()
                            : _fsController.enterFullscreen(ctx),
                        tooltip: _fsController.isFullscreen
                            ? 'Exit fullscreen'
                            : 'Fullscreen',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildCustomCommandSection(
            _ffplayCommandController,
            _runCustomFFplay,
            "Enter FFplay command",
            inputKey: const ValueKey<String>('ffplay.command.input'),
            runKey: const ValueKey<String>('ffplay.command.run'),
            onPickFile: kIsWeb
                ? () => _pickCommandInputFile(_ffplayCommandController)
                : null,
            pickKey: const ValueKey<String>('ffplay.command.pick-file'),
          ),
          const SizedBox(height: 20),
          const Text(
            "1. Generate Media:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              _demoButton(
                _generateTestVideo,
                Icons.video_call,
                "Gen Video",
                key: const ValueKey<String>('ffplay.generate-video'),
              ),
              _demoButton(
                _generateTestAudio,
                Icons.audiotrack,
                "Gen Audio",
                key: const ValueKey<String>('ffplay.generate-audio'),
              ),
            ],
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 12),
            _demoButton(
              _playImportedMedia,
              Icons.play_circle_outline,
              'Play Imported File',
              key: const ValueKey<String>('ffplay.play-imported'),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            "2. Play Generated:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              _demoButton(
                () => _runFFplay('test_video.mp4'),
                Icons.play_circle_filled,
                "Play Video",
                key: const ValueKey<String>('ffplay.play-video'),
              ),
              _demoButton(
                () => _runFFplay('test_audio.wav'),
                Icons.music_note,
                "Play Audio",
                key: const ValueKey<String>('ffplay.play-audio'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            "Controls:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              IconButton(
                key: const ValueKey<String>('ffplay.pause'),
                onPressed: () => FFplayKit.pause(),
                icon: const Icon(Icons.pause),
              ),
              IconButton(
                key: const ValueKey<String>('ffplay.resume'),
                onPressed: () => FFplayKit.resume(),
                icon: const Icon(Icons.play_arrow),
              ),
              IconButton(
                key: const ValueKey<String>('ffplay.stop'),
                onPressed: () => FFplayKit.stop(),
                icon: const Icon(Icons.stop),
              ),
              IconButton(
                key: const ValueKey<String>('ffplay.seek-forward'),
                onPressed: () => _seekForward(),
                icon: const Icon(Icons.fast_forward),
              ),
              IconButton(
                key: const ValueKey<String>('ffplay.seek-back'),
                onPressed: () => _seekBackward(),
                icon: const Icon(Icons.fast_rewind),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_hasActiveSession) ...[
            Text(
              "State: ${FFplayKit.playing ? 'Playing' : (FFplayKit.paused ? 'Paused' : 'Stopped')}",
              key: const ValueKey<String>('ffplay.position'),
            ),
            Text(
              "Position: ${_playbackPosition.toStringAsFixed(1)}s / ${FFplayKit.duration.toStringAsFixed(1)}s",
            ),
            Slider(
              value:
                  (_playbackPosition /
                          (FFplayKit.duration > 0 ? FFplayKit.duration : 1.0))
                      .clamp(0.0, 1.0),
              onChanged: (val) => FFplayKit.seek(val * FFplayKit.duration),
            ),
            const SizedBox(height: 16),
            const Text(
              "Volume:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                const Icon(Icons.volume_down),
                Expanded(
                  child: Slider(
                    key: const ValueKey<String>('ffplay.volume'),
                    value: _volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (val) {
                      _addLog("Current volume: $_volume, new volume: $val");
                      setState(() {
                        _volume = val;
                      });
                      _setVolume(val);
                    },
                  ),
                ),
                const Icon(Icons.volume_up),
                SizedBox(
                  width: 40,
                  child: Text(
                    "${(_volume * 100).round()}%",
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ] else
            const Text("No active playback."),
        ],
      ),
    );
  }

  Widget _buildTranscodeTab() {
    final selectedInputPath = kIsWeb
        ? _selectedWebMediaPath
        : _transcodeInputPath;
    final webTranscodeOutputPath =
        _transcodeOutputPath ?? (kIsWeb ? '/tmp/test_video.avi' : null);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Video Transcode (MP4 → AVI)",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            "Converts a video from MP4 to AVI format with progress tracking.",
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          // File picker section
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Input File",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (selectedInputPath != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.video_file, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              path.basename(selectedInputPath),
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            key: const ValueKey<String>(
                              'transcode.clear-input',
                            ),
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: _isTranscoding
                                ? null
                                : () {
                                    final previousWebPath =
                                        _selectedWebMediaPath;
                                    setState(() {
                                      _transcodeInputPath = null;
                                      _transcodeOutputPath = null;
                                      if (kIsWeb) {
                                        _selectedWebMediaPath = null;
                                        _selectedProbePath = null;
                                      }
                                    });
                                    if (previousWebPath != null) {
                                      _retireWebMediaPath(previousWebPath);
                                    }
                                  },
                            tooltip: "Clear selection",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Output: ${path.basename(_transcodeOutputPath ?? 'output.avi')}",
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ] else
                    Text(
                      "No file selected (will use generated test video)",
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    key: const ValueKey<String>('transcode.pick-input'),
                    onPressed: _isTranscoding ? null : _pickTranscodeFile,
                    icon: const Icon(Icons.file_open, size: 18),
                    label: const Text("Pick Video File"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Progress section
          if (_isTranscoding || _transcodeProgress > 0) ...[
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isTranscoding ? 'Transcoding...' : 'Complete',
                          key: const ValueKey<String>('transcode.status'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${(_transcodeProgress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        key: const ValueKey<String>('transcode.progress'),
                        value: _transcodeProgress,
                        minHeight: 12,
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _transcodeProgress >= 1.0
                              ? Colors.green
                              : Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _transcodeStatus,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          // Action buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _demoButton(
                _transcodeVideo,
                Icons.transform,
                _isTranscoding ? "Transcoding..." : "Transcode MP4 → AVI",
                key: const ValueKey<String>('transcode.run'),
              ),
            ],
          ),
          if (kIsWeb &&
              webTranscodeOutputPath != null &&
              _webDownloadableFiles.contains(webTranscodeOutputPath)) ...[
            const SizedBox(height: 12),
            _demoButton(
              () => _downloadWebFile(webTranscodeOutputPath),
              Icons.download,
              'Download AVI',
              key: const ValueKey<String>('transcode.download-avi'),
            ),
          ],
          const SizedBox(height: 24),
          // Info card
          Card(
            elevation: 1,
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "About Transcoding",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "• Input: test_video.mp4 (generated via FFmpeg testsrc)",
                    style: TextStyle(fontSize: 12),
                  ),
                  const Text(
                    "• Output: [input_name]_transcoded.avi (MPEG-4 video, AAC audio)",
                    style: TextStyle(fontSize: 12),
                  ),
                  const Text(
                    "• Progress tracked via FFmpegKit statistics callback",
                    style: TextStyle(fontSize: 12),
                  ),
                  const Text(
                    "• Shows: time elapsed, processing speed, frame count",
                    style: TextStyle(fontSize: 12),
                  ),
                  const Text(
                    "• Optional: pick your own video file to transcode",
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _webRemoteButton(
    String label,
    IconData icon,
    FutureOr<void> Function()? onPressed,
    String key,
  ) {
    return ElevatedButton.icon(
      key: ValueKey<String>(key),
      onPressed: onPressed == null ? null : () => onPressed(),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _buildWebRemoteSection() {
    final validation = _validateWebRemoteUrl(_webRemoteUrlController.text);
    final busy = _webRemoteBusy;
    final canStart = !busy && validation == null;
    final recordingPath = _webRemoteRecordingPath;
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Remote URL (Web)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Direct http:// and https:// URLs run through the async APIs. Recordings stay in browser memory until you download them. Video renders in the FFplay tab.",
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('web.remote.url'),
              controller: _webRemoteUrlController,
              enabled: !busy,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "Direct media URL",
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
            ),
            if (validation != null) ...[
              const SizedBox(height: 8),
              Text(
                validation,
                key: const ValueKey<String>('web.remote.validation'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.orangeAccent,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _webRemoteButton(
                  "Probe",
                  Icons.info_outline,
                  canStart ? _runWebRemoteProbe : null,
                  'web.remote.probe',
                ),
                _webRemoteButton(
                  "Play",
                  Icons.play_circle_outline,
                  canStart ? _runWebRemotePlay : null,
                  'web.remote.play',
                ),
                _webRemoteButton(
                  "Record 15 s",
                  Icons.fiber_manual_record,
                  canStart ? _runWebRemoteRecord : null,
                  'web.remote.record',
                ),
                _webRemoteButton(
                  "Stop",
                  Icons.stop,
                  busy && !_webRemoteCancelRequested ? _cancelWebRemote : null,
                  'web.remote.cancel',
                ),
                _webRemoteButton(
                  "Probe Recording",
                  Icons.search,
                  !busy && recordingPath != null
                      ? () => _runWebRemoteFFprobe(
                          '-hide_banner -v error -show_format -show_streams -of json "$recordingPath"',
                          "Probing $recordingPath",
                        )
                      : null,
                  'web.remote.probe-recording',
                ),
                _webRemoteButton(
                  "Download Recording",
                  Icons.download,
                  !busy && recordingPath != null
                      ? () => _downloadWebFile(recordingPath)
                      : null,
                  'web.remote.download',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "State: $_webRemoteState",
              key: const ValueKey<String>('web.remote.state'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_webRemoteDetail.isNotEmpty) ...[
              const SizedBox(height: 4),
              // Plain Text keeps the detail in the accessibility tree, where the
              // acceptance harness reads it. SelectableText does not.
              Text(
                _webRemoteDetail,
                key: const ValueKey<String>('web.remote.detail'),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteRecordingScenarioSection() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Remote Stream Recording",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Stream a remote URL and record it to local files.",
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('stream.url.input'),
              controller: _remoteStreamUrlController,
              decoration: const InputDecoration(
                labelText: "Remote stream URL",
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _demoButton(
                  () async {
                    await _runRemoteRecordingScenario();
                  },
                  Icons.cloud_download,
                  "Record Stream",
                  key: const ValueKey<String>('stream.record'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionsPanel() {
    final activeSessions =
        _remoteScenarioJobs
            .where((job) => job.session != null && !job.completed)
            .toList()
          ..sort((a, b) => (a.sessionId ?? 0).compareTo(b.sessionId ?? 0));

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Currently Running Sessions",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Sessions: ${activeSessions.length}",
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('stream.refresh'),
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    final sessions = FFmpegKitExtended.listSessions();
                    for (final session in sessions) {
                      debugPrint(
                        "Session ID: ${session.getSessionId()}, State: ${session.getState()}",
                      );
                    }
                    for (final job in _remoteScenarioJobs) {
                      if (job.session != null) {
                        final sessionId = job.session!.getSessionId();
                        final isActive = sessions.any(
                          (s) => s.getSessionId() == sessionId,
                        );
                        if (!isActive) {
                          job.completed = true;
                        }
                      }
                    }
                    _addLog("Refreshed sessions: ${sessions.length} active");
                    setState(() {});
                  },
                  tooltip: "Refresh session list",
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (activeSessions.isEmpty)
              const Text("No active streaming jobs.")
            else
              Column(
                children: activeSessions.map((job) {
                  final session = job.session!;
                  final command = session.getCommand();
                  final isRunning = !job.completed;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Session ${job.sessionId ?? session.getSessionId()} • ${job.requestedCancel ? 'cancelling' : 'running'}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                command.length > 120
                                    ? '${command.substring(0, 120)}...'
                                    : command,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                job.startedWriting.isCompleted
                                    ? "Output started"
                                    : "Waiting for output",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          key: ValueKey<String>(
                            'stream.cancel.${job.sessionId ?? session.getSessionId()}',
                          ),
                          onPressed: isRunning
                              ? () {
                                  job.requestedCancel = true;
                                  FFmpegKit.cancel(session);
                                  _addLog(
                                    "Requested cancel for session ${job.sessionId ?? session.getSessionId()}",
                                  );
                                  if (mounted) {
                                    setState(() {});
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text("Cancel"),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _demoButton(
    VoidCallback onPressed,
    IconData icon,
    String label, {
    Key? key,
  }) {
    return ElevatedButton.icon(
      key: key,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildCustomCommandSection(
    TextEditingController controller,
    VoidCallback onRun,
    String hint, {
    Key? inputKey,
    Key? runKey,
    VoidCallback? onPickFile,
    Key? pickKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Custom Command:",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: inputKey,
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            if (onPickFile != null) ...[
              _demoButton(
                onPickFile,
                Icons.file_open,
                "Pick File",
                key: pickKey,
              ),
              const SizedBox(width: 8),
            ],
            _demoButton(onRun, Icons.play_arrow, "Run", key: runKey),
          ],
        ),
      ],
    );
  }
}
