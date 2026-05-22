import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_media_store/android_media_store.dart';
import 'package:path_provider/path_provider.dart'; // Import for getTemporaryDirectory
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
  }
  await FFmpegKitExtended.initialize();
  runApp(const MyApp());
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
    text: "-version",
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
    _surface?.release();
    _fsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fsController = FFplayViewController(
      onEnterFullscreen:
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
          ? () => windowManager.setFullScreen(true)
          : null,
      onExitFullscreen:
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
          ? () => windowManager.setFullScreen(false)
          : null,
    );
    _initializePlugin();
    _currentLogLevel = FFmpegKitConfig.getLogLevel();
    final tabController = TabController(length: 5, vsync: this);
    if (Platform.isAndroid) {
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
    if (!Platform.isAndroid) return;
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
    if (!Platform.isAndroid) return;
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
      print(log);
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
      "-version",
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
    // Synchronous execution blocks the current isolate.
    final session = FFmpegKit.execute("-version");
    final output = session.getOutput();

    _addLog("Output captured from sync session:");
    _addLog(output ?? "No output captured.");
    _addLog("Return code: ${session.getReturnCode()}");
  }

  Future<void> _generateTestVideo() async {
    // Use temporary directory for FFmpeg output.
    final tempDir = await getTemporaryDirectory();
    final exampleDir = Directory(
      path.join(tempDir.path, 'ffmpeg_kit_extended_flutter_example'),
    );
    await exampleDir.create(recursive: true);
    final tempOutputPath = path.join(exampleDir.path, 'test_video.mp4');
    _addLog(
      "--- Generating Test Video with Audio to temporary path: $tempOutputPath ---",
      printToConsole: true,
    );

    // Command with both video and audio streams
    const command =
        "-hide_banner -loglevel quiet -f lavfi -i testsrc=duration=5:size=512x512:rate=30 -f lavfi -i sine=frequency=1000:duration=5 -c:v mpeg2video -c:a aac -shortest -y";

    await FFmpegKit.executeAsync(
      "$command \"$tempOutputPath\"",
      onLog: (log) {
        _addLog(log.message);
      },
      onComplete: (session) {
        if (ReturnCode.isSuccess(session.getReturnCode())) {
          _addLog("✅ Video with audio generated successfully!");
        } else {
          _addLog("❌ Generation failed. Code: ${session.getReturnCode()}");
        }
      },
    );
  }

  Future<void> _generateTestAudio() async {
    final tempDir = await getTemporaryDirectory();
    final exampleDir = Directory(
      path.join(tempDir.path, 'ffmpeg_kit_extended_flutter_example'),
    );
    await exampleDir.create(recursive: true);
    final outputPath = path.join(exampleDir.path, 'test_audio.wav');
    _addLog(
      "--- Generating Test Audio to: $outputPath ---",
      printToConsole: true,
    );

    // Command from integration tests
    const command =
        "-hide_banner -loglevel quiet -f lavfi -i sine=frequency=1000:duration=10 -y";

    await FFmpegKit.executeAsync(
      "$command \"$outputPath\"",
      onLog: (log) {
        _addLog(log.message);
      },
      onComplete: (session) {
        if (ReturnCode.isSuccess(session.getReturnCode())) {
          _addLog("✅ Audio generated successfully!");
        } else {
          _addLog("❌ Generation failed. Code: ${session.getReturnCode()}");
        }
      },
    );
  }

  Future<void> _pickTranscodeFile() async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      final pickedPath = result.files.single.path!;
      final pickedDir = path.dirname(pickedPath);
      final baseName = path.basenameWithoutExtension(pickedPath);
      setState(() {
        _transcodeInputPath = pickedPath;
        _transcodeOutputPath = path.join(
          pickedDir,
          '${baseName}_transcoded.avi',
        );
      });
      _addLog("Selected file: $pickedPath");
    }
  }

  Future<void> _transcodeVideo() async {
    if (_isTranscoding) {
      _addLog("Transcode already in progress.");
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final exampleDir = Directory(
      path.join(tempDir.path, 'ffmpeg_kit_extended_flutter_example'),
    );
    await exampleDir.create(recursive: true);

    // Use picked file or generate test video
    String inputPath;
    String outputPath;

    if (_transcodeInputPath != null &&
        File(_transcodeInputPath!).existsSync()) {
      inputPath = _transcodeInputPath!;
      outputPath =
          _transcodeOutputPath ?? path.join(exampleDir.path, 'test_video.avi');
    } else {
      inputPath = path.join(exampleDir.path, 'test_video.mp4');
      outputPath = path.join(exampleDir.path, 'test_video.avi');

      // Check if source file exists
      if (!File(inputPath).existsSync()) {
        _addLog("⚠️ Source video not found. Generating test video first...");
        await _generateTestVideo();
        // Wait a bit for generation to complete (simplified approach)
        await Future.delayed(const Duration(seconds: 6));
      }

      if (!File(inputPath).existsSync()) {
        _addLog("❌ Failed to generate source video.");
        return;
      }
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

    final command =
        "-hide_banner -i \"$inputPath\" -c:v mpeg4 -c:a aac -b:v 2M -y \"$outputPath\"";

    await FFmpegKit.executeAsync(
      command,
      onLog: (log) {
        _addLog(log.message);
      },
      onStatistics: (statistics) {
        if (mounted) {
          setState(() {
            _transcodeProgress = statistics.transcodingProgress ?? 0.0;
            _transcodeStatus =
                'Time: ${(statistics.time / 1000).toStringAsFixed(1)}s | '
                'Speed: ${statistics.speed.toStringAsFixed(2)}x | '
                'Frame: ${statistics.videoFrameNumber}';
          });
        }
      },
      onComplete: (session) {
        if (mounted) {
          setState(() {
            _isTranscoding = false;
            if (ReturnCode.isSuccess(session.getReturnCode())) {
              _transcodeProgress = 1.0;
              _transcodeStatus = '✅ Transcode complete!';
              _addLog("✅ Video transcoded successfully to AVI!");
            } else {
              _transcodeStatus = '❌ Transcode failed.';
              _addLog("❌ Transcode failed. Code: ${session.getReturnCode()}");
            }
          });
        }
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
    final command = _ffmpegCommandController.text;
    _addLog("--- Running Custom FFmpeg: $command ---", printToConsole: true);
    await FFmpegKit.executeAsync(
      command,
      onLog: (log) {
        _addLog(log.message);
      },
      onComplete: (session) {
        _addLog("Return code: ${session.getReturnCode()}");
      },
    );
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
    if (Platform.isWindows) {
      return input.replaceAll('\\', '/');
    }
    return input;
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
    final result = await FilePicker.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedProbePath = result.files.single.path;
      });
      _addLog("Selected for probe: $_selectedProbePath");
    }
  }

  Future<void> _runMediaInformation() async {
    // Use picked file, local test video, or remote URL fallback.
    final tempDir = await getTemporaryDirectory();
    final exampleDir = Directory(
      path.join(tempDir.path, 'ffmpeg_kit_extended_flutter_example'),
    );
    await exampleDir.create(recursive: true);
    final localTestPath = path.join(exampleDir.path, 'test_video.mp4');

    final String probePath;
    if (_selectedProbePath != null && File(_selectedProbePath!).existsSync()) {
      probePath = _selectedProbePath!;
    } else if (File(localTestPath).existsSync()) {
      probePath = localTestPath;
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
      },
    );
  }

  Future<void> _runCustomFFprobe() async {
    final command = _ffprobeCommandController.text;
    _addLog("--- Running Custom FFprobe: $command ---", printToConsole: true);
    await FFprobeKit.executeAsync(
      command,
      onComplete: (session) {
        final output = session.getOutput();
        if (output != null) _addLog(output);
        _addLog("Return code: ${session.getReturnCode()}");
      },
    );
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

  void _attachPositionStream(FFplaySession session) {
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
        if (mounted) {
          setState(() {
            _playbackPosition = pos;
          });
        }
      },
      onDone: () {
        if (mounted) setState(() => _hasActiveSession = false);
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
    final tempDir = await getTemporaryDirectory();
    final exampleDir = Directory(
      path.join(tempDir.path, 'ffmpeg_kit_extended_flutter_example'),
    );
    await exampleDir.create(recursive: true);
    final localPath = path.join(exampleDir.path, fileName);

    if (!File(localPath).existsSync()) {
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
      "-hide_banner -loglevel quiet -autoexit -i \"$localPath\"",
      onComplete: (session) {
        _addLog("FFplay playback of $fileName finished");
      },
    );
    _attachPositionStream(session);
    _addLog("Playback started.");
  }

  Future<void> _runCustomFFplay() async {
    final command = _ffplayCommandController.text;
    _addLog("--- Running Custom FFplay: $command ---", printToConsole: true);

    await _prepareSurface();
    final surface = await FFplaySurface.create();
    if (surface != null && mounted) {
      setState(() => _surface = surface);
    }

    final session = await FFplayKit.executeAsync(
      command,
      onComplete: (session) {
        final output = session.getOutput();
        _addLog("FFplay playback finished. Output: $output");
      },
    );
    _attachPositionStream(session);
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
          appBar: AppBar(
            title: Text(isMobile ? 'FFmpeg Kit' : 'FFmpeg Kit Extended'),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: const Icon(Icons.movie),
                  text: isMobile ? null : "FFmpeg",
                ),
                Tab(
                  icon: const Icon(Icons.sensors),
                  text: isMobile ? null : "Stream",
                ),
                Tab(
                  icon: const Icon(Icons.info),
                  text: isMobile ? null : "FFprobe",
                ),
                Tab(
                  icon: const Icon(Icons.play_arrow),
                  text: isMobile ? null : "FFplay",
                ),
                Tab(
                  icon: const Icon(Icons.transform),
                  text: isMobile ? null : "Transcode",
                ),
              ],
            ),
            actions: [
              PopupMenuButton<LogLevel>(
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
                icon: const Icon(Icons.delete),
                onPressed: _clearLogs,
                tooltip: "Clear Logs",
              ),
              IconButton(
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
              _demoButton(_generateTestVideo, Icons.video_call, "Gen Video"),
              _demoButton(_generateTestAudio, Icons.audiotrack, "Gen Audio"),
              _demoButton(_runFFmpegVersion, Icons.bolt, "Async Version"),
              _demoButton(_runFFmpegInfoSync, Icons.timer, "Sync Version"),
              _demoButton(
                () async {
                  _addLog("--- Running Help ---", printToConsole: true);
                  await FFmpegKit.executeAsync(
                    "-h",
                    onLog: (l) => _addLog(l.message),
                  );
                },
                Icons.help_outline,
                "Help",
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildCustomCommandSection(
            _ffmpegCommandController,
            _runCustomFFmpeg,
            "Enter FFmpeg command",
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
          _buildRemoteRecordingScenarioSection(),
          const SizedBox(height: 20),
          _buildActiveSessionsPanel(),
        ],
      ),
    );
  }

  Widget _buildFFprobeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedProbePath != null) ...[
            Text(
              "Selected: ${path.basename(_selectedProbePath!)}",
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _demoButton(_pickProbeFile, Icons.file_open, "Pick File"),
              _demoButton(
                _runMediaInformation,
                Icons.analytics,
                "Get Media Info",
              ),
              _demoButton(_runFFprobeVersion, Icons.bolt, "Async Version"),
              _demoButton(_runFFprobeInfoSync, Icons.timer, "Sync Version"),
            ],
          ),
          const SizedBox(height: 24),
          _buildCustomCommandSection(
            _ffprobeCommandController,
            _runCustomFFprobe,
            "Enter FFprobe command",
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
              _demoButton(_generateTestVideo, Icons.video_call, "Gen Video"),
              _demoButton(_generateTestAudio, Icons.audiotrack, "Gen Audio"),
            ],
          ),
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
              ),
              _demoButton(
                () => _runFFplay('test_audio.wav'),
                Icons.music_note,
                "Play Audio",
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
                onPressed: () => FFplayKit.pause(),
                icon: const Icon(Icons.pause),
              ),
              IconButton(
                onPressed: () => FFplayKit.resume(),
                icon: const Icon(Icons.play_arrow),
              ),
              IconButton(
                onPressed: () => FFplayKit.stop(),
                icon: const Icon(Icons.stop),
              ),
              IconButton(
                onPressed: () => _seekForward(),
                icon: const Icon(Icons.fast_forward),
              ),
              IconButton(
                onPressed: () => _seekBackward(),
                icon: const Icon(Icons.fast_rewind),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_hasActiveSession) ...[
            Text(
              "State: ${FFplayKit.playing ? 'Playing' : (FFplayKit.paused ? 'Paused' : 'Stopped')}",
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
                  if (_transcodeInputPath != null) ...[
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
                              path.basename(_transcodeInputPath!),
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: _isTranscoding
                                ? null
                                : () {
                                    setState(() {
                                      _transcodeInputPath = null;
                                      _transcodeOutputPath = null;
                                    });
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
              ),
            ],
          ),
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

  Widget _demoButton(VoidCallback onPressed, IconData icon, String label) {
    return ElevatedButton.icon(
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
    String hint,
  ) {
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
            _demoButton(onRun, Icons.play_arrow, "Run"),
          ],
        ),
      ],
    );
  }
}
