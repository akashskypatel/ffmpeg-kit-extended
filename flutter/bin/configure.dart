// bin/configure.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

// =============================================================================
// RELEASE CONFIGURATION
// =============================================================================

const String _baseUrlTemplate =
    "https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download";

// =============================================================================
// CLI LOGIC
// =============================================================================

Future<void> main(List<String> args) async {
  final platforms = [];
  String? appRootPath;
  bool generateBindings = false;
  bool verbose = false;
  bool debug = false;

  final supportedPlatforms = [
    'windows',
    'linux'
  ]; // TODO: add 'macos', 'android', 'ios'

  // Simple Argument Parser
  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      print('''
Usage: dart run ffmpeg_kit_extended_flutter:configure [platforms] [options]

Platforms:
  Comma-separated list of platforms (e.g., windows,linux) or positional arguments.
  If omitted, the script will auto-detect supported platforms in the project root.

Options:
  --platform=<list>    Specify platforms to configure (e.g., windows,linux).
  --verbose            Enable verbose output.
  --debug              Enable debug mode. Fetches remote bundles with debug symbols.
                       Note: Only "base" bundle is published with debug symbols.
  --generate-bindings  Generate Dart FFI bindings using ffigen.
  --app-root=<path>    Specify the path to the app root (defaults to CWD).
  --help, -h           Show this help message.

Configuration (pubspec.yaml):
  Add the following section to your pubspec.yaml:

  ffmpeg_kit_extended_config:
    version: "1.0.0"   # Version of pre-bundled libraries
    type: "full"       # base, full, audio, video, streaming, video_hw
    gpl: true          # Include GPL libraries
    small: false       # Use smaller builds
    # Optional: overrides for specific platforms
    # windows: "C:\\\\path\\\\to\\\\bundle.zip"
    # linux: "https://example.com/bundle.zip"
''');
      exit(0);
    } else if (arg == '--generate-bindings') {
      generateBindings = true;
    } else if (arg == '--verbose') {
      verbose = true;
    } else if (arg == '--debug') {
      debug = true;
    } else if (arg.startsWith('--app-root=')) {
      appRootPath = arg.substring('--app-root='.length);
    } else if (arg.startsWith('--platform=')) {
      platforms.addAll(arg
          .substring('--platform='.length)
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty));
    } else {
      if (!arg.startsWith('-')) {
        platforms.addAll(arg
            .split(',')
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty));
      }
    }
  }

  // Determine Project Root
  Directory projectRoot;
  if (appRootPath != null) {
    projectRoot = Directory(appRootPath);
  } else {
    // Default to CWD, which is typically App Root in 'dart run' context
    projectRoot = Directory.current;
  }

  if (!projectRoot.existsSync()) {
    _logError('Project root does not exist: ${projectRoot.path}');
    exit(1);
  }

  // Auto-detect Supported Platforms
  if (platforms.isEmpty) {
    if (verbose) print('FFmpegKit: Auto-detecting supported platforms...');
    for (final pform in supportedPlatforms) {
      if (Directory(p.join(projectRoot.path, pform)).existsSync()) {
        platforms.add(pform);
      }
    }
  }

  if (verbose) {
    print('FFmpegKit: Project Root -> ${projectRoot.path}');
    print('FFmpegKit: Platforms -> ${platforms.join(', ')}');
    if (debug) print('FFmpegKit: Mode -> DEBUG (Fetching remote bundles)');
  }

  // Load Pubspec Configuration
  final pubspecFile = File(p.join(projectRoot.path, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) {
    _logError('pubspec.yaml not found at ${pubspecFile.path}.');
    exit(1);
  }

  final content = pubspecFile.readAsStringSync();
  dynamic doc;
  try {
    doc = loadYaml(content);
  } catch (e) {
    _logError('Failed to parse pubspec.yaml: $e');
    exit(1);
  }

  // Parse Configuration
  final config = doc['ffmpeg_kit_extended_config'];
  if (config == null) {
    _logError(
        'Missing "ffmpeg_kit_extended_config" in pubspec.yaml. Please add it.');
    exit(1);
  }

  // Platform Validation
  if (platforms.isEmpty) {
    _logError(
        'No platform specified and none detected. Usage: configure <platform1,platform2> [options]');
    exit(1);
  }

  for (final platform in platforms) {
    if (!supportedPlatforms.contains(platform)) {
      _logError('Unsupported platform: $platform');
      exit(1);
    }
  }

  // Execute Configuration
  try {
    final Map<String, String> configuredPaths = {};
    for (final platform in platforms) {
      if (verbose) print('FFmpegKit: Configuring for $platform...');
      final binaryPath = await _configurePlatform(
          config, platform, projectRoot, verbose, debug);
      if (binaryPath != null) {
        configuredPaths[platform] = binaryPath;
        // Success output for CMake/Scripts to verify (Legacy support)
        print('FFMPEG_KIT_PATH_$platform=$binaryPath');
      } else {
        _logError('Configuration failed for $platform');
        exit(1);
      }
    }

    if (configuredPaths.isNotEmpty) {
      await _writeCmakeConfig(projectRoot, configuredPaths, verbose);
    }

    if (generateBindings) {
      await _runFfigen(projectRoot, verbose);
    }
    exit(0);
  } catch (e) {
    _logError('Configuration failed: $e');
    exit(1);
  }
}

// =============================================================================
// PLATFORM CONFIGURATION
// =============================================================================

Future<String?> _configurePlatform(dynamic config, String platform,
    Directory projectRoot, bool verbose, bool debug) async {
  // Parse Config values
  final version = config['version']?.toString() ?? "1.0.0";
  final type = config['type']?.toString() ?? "full";
  final bool gpl = config['gpl'] == true;
  final bool small = config['small'] == true;
  final overrideUrl = config[platform]?.toString();

  // Determine Destination (App Local Cache)
  final cacheDir = Directory(p.join(
      projectRoot.path, '.dart_tool', 'ffmpeg_kit_extended_flutter', platform));

  if (!cacheDir.existsSync()) {
    cacheDir.createSync(recursive: true);
  }

  // Architecture Resolution (For Windows/Linux detection)
  String arch = 'x86_64'; // Default
  if (platform == 'windows') {
    arch = 'x86_64';
  } else if (platform == 'linux') {
    // Detect host arch
    try {
      final res = Process.runSync('uname', ['-m']);
      final hostArch = res.stdout.toString().trim();
      if (hostArch == 'aarch64') arch = 'arm64';
    } catch (_) {}
  }

  // Filename Construction
  String filename;
  String url;

  if (debug) {
    // Debug mode: ignore small/type, ignore local override, fetch specific remote bundle
    final parts = [
      'bundle',
      'base',
      platform,
      arch,
      'shared',
      gpl ? 'gpl' : 'lgpl'
    ];
    filename = "${parts.join('-')}.zip";
    final tag = "v$version-$platform";
    url = "$_baseUrlTemplate/$tag/$filename";
  } else if (overrideUrl != null) {
    if (overrideUrl.startsWith('http')) {
      url = overrideUrl;
      filename = p.basename(Uri.parse(url).path);
    } else {
      // Local path override - just return it directly if valid
      final localFile = File(overrideUrl);
      if (localFile.existsSync()) {
        if (verbose)
          print('FFmpegKit: Using local override -> ${localFile.path}');
        // If it's a zip, extract it to cache. If it's a folder, use it.
        if (FileSystemEntity.isDirectorySync(localFile.path)) {
          final finalDir = Directory(localFile.path);
          await _updateMetadata(finalDir, cacheDir, projectRoot, verbose);
          return finalDir.path;
        } else {
          // Extract local zip to cache
          filename = p.basename(localFile.path);
          url = ''; // Local handling
          // Copy to cache to ensure consistency
          final cacheFile = File(p.join(cacheDir.path, filename));
          if (!cacheFile.existsSync() ||
              cacheFile.lengthSync() != localFile.lengthSync()) {
            localFile.copySync(cacheFile.path);
          }
          await _extractFile(cacheFile, cacheDir.path, verbose);
          // Assuming structure
          final extractedName = p.basenameWithoutExtension(filename);
          final finalDir = Directory(p.join(cacheDir.path, extractedName));
          await _updateMetadata(finalDir, cacheDir, projectRoot, verbose);
          return finalDir.path;
        }
      } else {
        throw Exception('Local override path not found: $overrideUrl');
      }
    }
  } else {
    // Standard Download
    final parts = ['bundle', type, platform, arch, 'shared'];
    if (small) parts.add('small');
    if (gpl) parts.add('gpl');
    filename = "${parts.join('-')}.zip";
    final tag = "v$version-$platform";
    url = "$_baseUrlTemplate/$tag/$filename";
  }

  final zipFile = File(p.join(cacheDir.path, filename));
  final extractedFolderName = p.basenameWithoutExtension(filename);
  final destinationDir = Directory(p.join(cacheDir.path, extractedFolderName));

  // Check if already exists and valid
  final bool cacheHit =
      destinationDir.existsSync() && destinationDir.listSync().isNotEmpty;

  if (cacheHit) {
    if (verbose) print('FFmpegKit: Cache hit -> ${destinationDir.path}');
  } else {
    if (verbose) print('FFmpegKit: Downloading $url...');

    bool downloadSuccess = false;
    int retries = 3;
    while (retries > 0) {
      try {
        if (await _downloadFile(url, zipFile)) {
          downloadSuccess = true;
          break;
        }
      } catch (e) {
        if (verbose) print('FFmpegKit: Download error: $e');
      }
      retries--;
      if (retries > 0) {
        if (verbose) print('FFmpegKit: Retrying download...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!downloadSuccess) {
      throw Exception('Failed to download $url after 3 attempts.');
    }

    if (verbose) print('FFmpegKit: Extracting...');
    if (!await _extractFile(zipFile, cacheDir.path, verbose)) {
      throw Exception('Extraction failed.');
    }
  }

  // Verify extraction
  Directory finalDir;
  if (destinationDir.existsSync()) {
    finalDir = destinationDir;
  } else {
    // Fallback
    finalDir = cacheDir;
  }

  // Create 'bin' alias for easier access by loader
  // We want .dart_tool/ffmpeg_kit_extended_flutter/{platform}/bin -> finalDir/bin (or finalDir if flat)
  // Actually, let's just symlink the whole directory to 'current'
  final currentLink = Link(p.join(cacheDir.path, 'current'));
  if (currentLink.existsSync()) {
    currentLink.deleteSync();
  }

  await _updateMetadata(finalDir, cacheDir, projectRoot, verbose);

  return finalDir.path;
}

Future<void> _updateMetadata(Directory finalDir, Directory cacheDir,
    Directory projectRoot, bool verbose) async {
  final pathFile = File(p.join(cacheDir.path, 'current_path.txt'));
  pathFile.writeAsStringSync(finalDir.path);

  // Copy include directory to a fixed location for ffigen
  final fixedIncludeDir = Directory(p.join(projectRoot.path, '.dart_tool',
      'ffmpeg_kit_extended_flutter', 'include'));
  if (fixedIncludeDir.existsSync()) {
    fixedIncludeDir.deleteSync(recursive: true);
  }
  // Ensure parent exists
  if (!fixedIncludeDir.parent.existsSync()) {
    fixedIncludeDir.parent.createSync(recursive: true);
  }
  fixedIncludeDir.createSync(recursive: true);

  final sourceIncludeDir = Directory(p.join(finalDir.path, 'include'));
  if (sourceIncludeDir.existsSync()) {
    if (verbose)
      print('FFmpegKit: Updating generic include path for ffigen...');
    await _copyDirectory(sourceIncludeDir, fixedIncludeDir);
  } else {
    // If we can't find 'include' directly, maybe it's nested?
    // Some bundles might have top-level include, others generic.
    // For now, warning is enough.
    if (verbose)
      print('FFmpegKit: Warning - include directory not found in bundle.');
  }
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await for (final entity in source.list(recursive: false)) {
    if (entity is Directory) {
      final newDirectory =
          Directory(p.join(destination.path, p.basename(entity.path)));
      await newDirectory.create();
      await _copyDirectory(entity.absolute, newDirectory);
    } else if (entity is File) {
      await entity.copy(p.join(destination.path, p.basename(entity.path)));
    }
  }
}

/// Writes a `config.cmake` file for CMake consumption.
Future<void> _writeCmakeConfig(Directory projectRoot,
    Map<String, String> configuredPaths, bool verbose) async {
  final configDir = Directory(
      p.join(projectRoot.path, '.dart_tool', 'ffmpeg_kit_extended_flutter'));
  if (!configDir.existsSync()) {
    configDir.createSync(recursive: true);
  }

  final configFile = File(p.join(configDir.path, 'config.cmake'));
  final buffer = StringBuffer();
  buffer.writeln('# Generated by ffmpeg-kit-extended configure.dart');
  buffer.writeln('# DO NOT EDIT MANUALLY');
  buffer.writeln();

  configuredPaths.forEach((platform, path) {
    // Normalize path for CMake
    final cmakePath = path.replaceAll('\\', '/');
    buffer.writeln(
        'set(FFMPEG_KIT_PATH_${platform.toUpperCase()} "$cmakePath" CACHE INTERNAL "")');
  });

  configFile.writeAsStringSync(buffer.toString());
  if (verbose) print('FFmpegKit: Generated CMake config at ${configFile.path}');
}

// =============================================================================
// UTILITIES
// =============================================================================

Future<bool> _downloadFile(String url, File target) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode == 200) {
      await response.pipe(target.openWrite());
      return true;
    } else {
      return false;
    }
  } finally {
    client.close();
  }
}

Future<bool> _extractFile(File zipFile, String destPath, bool verbose) async {
  try {
    if (Platform.isWindows) {
      final res = await Process.run('powershell', [
        '-command',
        'Expand-Archive -Path "${zipFile.path}" -DestinationPath "$destPath" -Force'
      ]);
      if (res.exitCode != 0) {
        if (verbose) print("Extract failed: ${res.stderr}");
        return false;
      }
    } else {
      final res =
          await Process.run('unzip', ['-o', zipFile.path, '-d', destPath]);
      if (res.exitCode != 0) {
        // Tar fallback
        final res2 =
            await Process.run('tar', ['-xf', zipFile.path, '-C', destPath]);
        if (res2.exitCode != 0) {
          if (verbose) print("Extract failed: ${res2.stderr}");
          return false;
        }
      }
    }
    return true;
  } catch (e) {
    if (verbose) print("Extract exception: $e");
    return false;
  }
}

Future<void> _runFfigen(Directory projectRoot, bool verbose) async {
  // Logic to locate ffigen config relative to package root
  // This is typically only run by developers of the plugin
  if (verbose) print("FFmpegKit: Running ffigen...");
  final result = await Process.run(
    'dart',
    ['run', 'ffigen', '--config', 'ffigen.yaml'],
    workingDirectory: projectRoot.path, // Assuming running from package root
    runInShell: true,
  );
  if (result.exitCode != 0) {
    print('FFmpegKit: ffigen failed: ${result.stderr}');
  } else {
    print('FFmpegKit: ffigen completed.');
  }
}

void _logError(String message) {
  stderr.writeln('FFmpegKit Error: $message');
}
