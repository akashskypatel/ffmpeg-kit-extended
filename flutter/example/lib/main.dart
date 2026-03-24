import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_media_store/android_media_store.dart';
import 'package:path_provider/path_provider.dart'; // Import for getTemporaryDirectory

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _outputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _ffmpegCommandController =
      TextEditingController(text: "-version");
  final TextEditingController _ffprobeCommandController =
      TextEditingController(text: "-version");
  final TextEditingController _ffplayCommandController =
      TextEditingController(text: "-i test_video.mp4");
  String? _selectedProbePath;
  String _status = 'Ready';
  final _mediaStore = AndroidMediaStore.instance;
  late StreamSubscription<bool> _permissionStreamSub;
  LogLevel _currentLogLevel = LogLevel.info;

  // FFplay position tracking
  StreamSubscription<double>? _positionSub;
  double _playbackPosition = 0.0;
  bool _hasActiveSession = false;

  // Video dimensions updated via videoSizeStream when first frame is decoded
  StreamSubscription<(int, int)>? _videoSizeSub;
  int _videoWidth = 0;
  int _videoHeight = 0;
  bool _hasVideo = false;

  // Unified video surface for Android, Linux, Windows
  FFplaySurface? _surface;

  @override
  void dispose() {
    _permissionStreamSub.cancel();
    _positionSub?.cancel();
    _videoSizeSub?.cancel();
    _surface?.release();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializePlugin();
    _currentLogLevel = FFmpegKitConfig.getLogLevel();
    final tabController = TabController(length: 3, vsync: this);
    if (Platform.isAndroid) {
      // Listen for MANAGE_MEDIA permission changes.
      _permissionStreamSub =
          _mediaStore.onManageMediaPermissionChanged.listen((isGranted) {
        if (mounted) {
          setState(() {
            _status = isGranted
                ? 'Manage Media Permission: Granted'
                : 'Manage Media Permission: Denied';
            _addLog(_status);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_status)),
          );
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

  void _addLog(String log) {
    setState(() {
      _outputController.text += "$log\n";
    });
    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearLogs() {
    setState(() {
      _outputController.clear();
    });
  }

  // --- FFmpeg Examples ---

  Future<void> _runFFmpegVersion() async {
    _addLog("--- Running FFmpeg -version (Async) ---");

    // Async execution captures logs in real-time.
    await FFmpegKit.executeAsync("-version", onLog: (log) {
      _addLog(log.message);
    }, onComplete: (session) {
      _addLog("Return code: ${session.getReturnCode()}");
    });
  }

  void _runFFmpegInfoSync() {
    _addLog("--- Running FFmpeg -version (Sync) ---");
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
    final tempOutputPath = path.join(tempDir.path, 'test_video.mp4');
    _addLog("--- Generating Test Video to temporary path: $tempOutputPath ---");

    // Command from integration tests
    const command =
        "-hide_banner -loglevel info -f lavfi -i testsrc=duration=5:size=512x512:rate=30 -y";

    await FFmpegKit.executeAsync("$command \"$tempOutputPath\"", onLog: (log) {
      _addLog(log.message);
    }, onComplete: (session) {
      if (ReturnCode.isSuccess(session.getReturnCode())) {
        _addLog("✅ Video generated successfully!");
      } else {
        _addLog("❌ Generation failed. Code: ${session.getReturnCode()}");
      }
    });
  }

  Future<void> _generateTestAudio() async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = path.join(tempDir.path, 'test_audio.wav');
    _addLog("--- Generating Test Audio to: $outputPath ---");

    // Command from integration tests
    const command =
        "-hide_banner -loglevel info -f lavfi -i sine=frequency=1000:duration=10 -y";

    await FFmpegKit.executeAsync("$command \"$outputPath\"", onLog: (log) {
      _addLog(log.message);
    }, onComplete: (session) {
      if (ReturnCode.isSuccess(session.getReturnCode())) {
        _addLog("✅ Audio generated successfully!");
      } else {
        _addLog("❌ Generation failed. Code: ${session.getReturnCode()}");
      }
    });
  }

  Future<void> _showSystemInfo() async {
    _addLog("--- System & Config Information ---");
    _addLog("FFmpeg Version: ${FFmpegKitConfig.getFFmpegVersion()}");
    _addLog("FFmpegKit Version: ${FFmpegKitConfig.getVersion()}");
    _addLog("Build Date: ${FFmpegKitConfig.getBuildDate()}");
    _addLog("Package Name: ${FFmpegKitConfig.getPackageName()}");
    _addLog(
        "Log Level: ${FFmpegKitConfig.logLevelToString(FFmpegKitConfig.getLogLevel())}");
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
    _addLog("--- Running Custom FFmpeg: $command ---");
    await FFmpegKit.executeAsync(command, onLog: (log) {
      _addLog(log.message);
    }, onComplete: (session) {
      _addLog("Return code: ${session.getReturnCode()}");
    });
  }

  // --- FFprobe Examples ---

  Future<void> _runFFprobeVersion() async {
    _addLog("--- Running FFprobe -version (Async) ---");
    await FFprobeKit.executeAsync("-version", onComplete: (session) {
      final output = session.getOutput();
      _addLog(output ?? "No output found in session object.");
      _addLog("Return code: ${session.getReturnCode()}");
    });
  }

  void _runFFprobeInfoSync() {
    _addLog("--- Running FFprobe -version (Sync) ---");
    // Capturing output from synchronous ffprobe call.
    final session = FFprobeKit.execute("-version");
    final output = session.getOutput();

    _addLog("Output captured from sync ffprobe:");
    _addLog(output ?? "No output captured.");
    _addLog("Return code: ${session.getReturnCode()}");
  }

  Future<void> _pickProbeFile() async {
    final result = await FilePicker.platform.pickFiles();
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
    final localTestPath = path.join(tempDir.path, 'test_video.mp4');

    final String probePath;
    if (_selectedProbePath != null && File(_selectedProbePath!).existsSync()) {
      probePath = _selectedProbePath!;
    } else if (File(localTestPath).existsSync()) {
      probePath = localTestPath;
    } else {
      probePath =
          "https://raw.githubusercontent.com/tanersener/ffmpeg-kit/master/test-data/video.mp4";
    }

    _addLog("--- Getting Media Information for $probePath ---");

    await FFprobeKit.getMediaInformationAsync(probePath, onComplete: (session) {
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
                " Stream #$i: ${stream.type} (${stream.codec}) - ${stream.width}x${stream.height}");
          }
        } else {
          _addLog("Failed to retrieve media information. Check logs below:");
          _addLog(session.getLogs() ?? "Empty logs.");
        }
      }
    });
  }

  Future<void> _runCustomFFprobe() async {
    final command = _ffprobeCommandController.text;
    _addLog("--- Running Custom FFprobe: $command ---");
    await FFprobeKit.executeAsync(command, onComplete: (session) {
      final output = session.getOutput();
      if (output != null) _addLog(output);
      _addLog("Return code: ${session.getReturnCode()}");
    });
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
    });

    // Capture surface at subscription time to avoid race conditions.
    final surfaceToRelease = _surface;

    _positionSub = session.positionStream.listen(
      (pos) {
        if (mounted) setState(() => _playbackPosition = pos);
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
    final localPath = path.join(tempDir.path, fileName);

    if (!File(localPath).existsSync()) {
      _addLog("⚠️ File not found: $localPath. Please generate it first!");
      return;
    }

    _addLog("--- Starting FFplay for $localPath ---");

    // Clear existing surface and create new one.
    await _prepareSurface();
    final surface = await FFplaySurface.create();
    if (surface != null && mounted) {
      setState(() => _surface = surface);
    }

    final session = await FFplayKit.executeAsync("-i \"$localPath\"",
        onComplete: (session) {
      _addLog("FFplay playback of $fileName finished");
    });
    _attachPositionStream(session);
    _addLog("Playback started.");
  }

  Future<void> _runCustomFFplay() async {
    final command = _ffplayCommandController.text;
    _addLog("--- Running Custom FFplay: $command ---");

    await _prepareSurface();
    final surface = await FFplaySurface.create();
    if (surface != null && mounted) {
      setState(() => _surface = surface);
    }

    final session =
        await FFplayKit.executeAsync(command, onComplete: (session) {
      _addLog("FFplay playback finished");
    });
    _attachPositionStream(session);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;

      return Scaffold(
        appBar: AppBar(
          title: Text(isMobile ? 'FFmpeg Kit' : 'FFmpeg Kit Extended'),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                  icon: const Icon(Icons.movie),
                  text: isMobile ? null : "FFmpeg"),
              Tab(
                  icon: const Icon(Icons.info),
                  text: isMobile ? null : "FFprobe"),
              Tab(
                  icon: const Icon(Icons.play_arrow),
                  text: isMobile ? null : "FFplay"),
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
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showSystemInfo,
              tooltip: "System Info",
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
            )
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
    });
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildFFmpegTab(),
        _buildFFprobeTab(),
        _buildFFplayTab(),
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
          decoration: const InputDecoration(
            border: InputBorder.none,
          ),
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
              _demoButton(() async {
                _addLog("--- Running Help ---");
                await FFmpegKit.executeAsync("-h",
                    onLog: (l) => _addLog(l.message));
              }, Icons.help_outline, "Help"),
            ],
          ),
          const SizedBox(height: 24),
          _buildCustomCommandSection(_ffmpegCommandController, _runCustomFFmpeg,
              "Enter FFmpeg command"),
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
            Text("Selected: ${path.basename(_selectedProbePath!)}",
                style:
                    const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _demoButton(_pickProbeFile, Icons.file_open, "Pick File"),
              _demoButton(
                  _runMediaInformation, Icons.analytics, "Get Media Info"),
              _demoButton(_runFFprobeVersion, Icons.bolt, "Async Version"),
              _demoButton(_runFFprobeInfoSync, Icons.timer, "Sync Version"),
            ],
          ),
          const SizedBox(height: 24),
          _buildCustomCommandSection(_ffprobeCommandController,
              _runCustomFFprobe, "Enter FFprobe command"),
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
              child: SizedBox(
                width: _videoWidth.toDouble(),
                height: _videoHeight.toDouble(),
                child: _surface!.toWidget(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildCustomCommandSection(_ffplayCommandController, _runCustomFFplay,
              "Enter FFplay command"),
          const SizedBox(height: 20),
          const Text("1. Generate Media:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              _demoButton(_generateTestVideo, Icons.video_call, "Gen Video"),
              _demoButton(_generateTestAudio, Icons.audiotrack, "Gen Audio"),
            ],
          ),
          const SizedBox(height: 20),
          const Text("2. Play Generated:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              _demoButton(() => _runFFplay('test_video.mp4'),
                  Icons.play_circle_filled, "Play Video"),
              _demoButton(() => _runFFplay('test_audio.wav'), Icons.music_note,
                  "Play Audio"),
            ],
          ),
          const SizedBox(height: 20),
          const Text("Controls:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              IconButton(
                  onPressed: () => FFplayKit.pause(),
                  icon: const Icon(Icons.pause)),
              IconButton(
                  onPressed: () => FFplayKit.resume(),
                  icon: const Icon(Icons.play_arrow)),
              IconButton(
                  onPressed: () => FFplayKit.stop(),
                  icon: const Icon(Icons.stop)),
            ],
          ),
          const SizedBox(height: 8),
          if (_hasActiveSession) ...[
            Text(
                "State: ${FFplayKit.playing ? 'Playing' : (FFplayKit.paused ? 'Paused' : 'Stopped')}"),
            Text(
                "Position: ${_playbackPosition.toStringAsFixed(1)}s / ${FFplayKit.duration.toStringAsFixed(1)}s"),
            Slider(
              value: (_playbackPosition /
                      (FFplayKit.duration > 0 ? FFplayKit.duration : 1.0))
                  .clamp(0.0, 1.0),
              onChanged: (val) => FFplayKit.seek(val * FFplayKit.duration),
            ),
          ] else
            const Text("No active playback."),
        ],
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
      TextEditingController controller, VoidCallback onRun, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Custom Command:",
            style: TextStyle(fontWeight: FontWeight.bold)),
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
