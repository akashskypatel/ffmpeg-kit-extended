import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

void main() {
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    // Async execution allows capturing logs in real-time or at the end
    await FFmpegKit.executeAsync("-version", onLog: (log) {
      _addLog(log.message);
    }, onComplete: (session) {
      _addLog("Return code: ${session.getReturnCode()}");
    });
  }

  void _runFFmpegInfoSync() {
    _addLog("--- Running FFmpeg -version (Sync) ---");
    // Synchronous execution blocks the current isolate
    // We capture the output from the session object after it returns
    final session = FFmpegKit.execute("-version");
    final output = session.getOutput();

    _addLog("Output captured from sync session:");
    _addLog(output ?? "No output captured.");
    _addLog("Return code: ${session.getReturnCode()}");
  }

  Future<void> _generateTestVideo() async {
    final outputPath = path.join(Directory.current.path, 'test_video.mp4');
    _addLog("--- Generating Test Video to: $outputPath ---");

    // Command from integration tests
    const command =
        "-hide_banner -loglevel info -f lavfi -i testsrc=duration=5:size=512x512:rate=30 -y";

    await FFmpegKit.executeAsync("$command \"$outputPath\"", onLog: (log) {
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
    final outputPath = path.join(Directory.current.path, 'test_audio.mp3');
    _addLog("--- Generating Test Audio to: $outputPath ---");

    // Command from integration tests
    const command =
        "-hide_banner -loglevel info -f lavfi -i sine=frequency=1000:duration=3 -y";

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
    _addLog("Log Level: ${FFmpegKitConfig.getLogLevel()}");
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
    // Capturing output from synchronous ffprobe call
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
    // 1. Use picked file if available
    // 2. Otherwise use local test_video.mp4
    // 3. Finally fall back to remote URL
    final localTestPath = path.join(Directory.current.path, 'test_video.mp4');

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
  Future<void> _runFFplay(String fileName) async {
    final localPath = path.join(Directory.current.path, fileName);

    if (!File(localPath).existsSync()) {
      _addLog("⚠️ File not found: $localPath. Please generate it first!");
      return;
    }

    _addLog("--- Starting FFplay for $localPath ---");

    await FFplayKit.executeAsync("-i \"$localPath\"", onComplete: (session) {
      _addLog("FFplay playback of $fileName finished");
    });

    _addLog("Playback started.");
  }

  Future<void> _runCustomFFplay() async {
    final command = _ffplayCommandController.text;
    _addLog("--- Running Custom FFplay: $command ---");
    await FFplayKit.executeAsync(command, onComplete: (session) {
      _addLog("FFplay playback finished");
    });
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
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showSystemInfo,
              tooltip: "System Info",
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _clearLogs,
              tooltip: "Clear Logs",
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
              _demoButton(() => _runFFplay('test_audio.mp3'), Icons.music_note,
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
          StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                final active = FFplayKit.getCurrentSession() != null;
                if (!active) return const Text("No active playback.");

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "State: ${FFplayKit.playing ? 'Playing' : (FFplayKit.paused ? 'Paused' : 'Stopped')}"),
                    Text(
                        "Position: ${FFplayKit.position.toStringAsFixed(1)}s / ${FFplayKit.duration.toStringAsFixed(1)}s"),
                    Slider(
                      value: (FFplayKit.position /
                              (FFplayKit.duration > 0
                                  ? FFplayKit.duration
                                  : 1.0))
                          .clamp(0.0, 1.0),
                      onChanged: (val) =>
                          FFplayKit.seek(val * FFplayKit.duration),
                    ),
                  ],
                );
              }),
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
