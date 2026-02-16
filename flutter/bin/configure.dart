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
  String? platform;
  String? appRootPath;
  bool generateBindings = false;
  bool verbose = false;

  // Simple Argument Parser
  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--generate-bindings') {
      generateBindings = true;
    } else if (arg == '--verbose') {
      verbose = true;
    } else if (arg.startsWith('--app-root=')) {
      appRootPath = arg.substring('--app-root='.length);
    } else {
      if (!arg.startsWith('-')) {
        platform = arg.toLowerCase();
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

  if (verbose) {
    print('FFmpegKit: Project Root -> ${projectRoot.path}');
    print('FFmpegKit: Platform -> $platform');
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

  // Platform Detection / Validation
  if (platform == null) {
    _logError('No platform specified. Usage: configure <platform> [options]');
    exit(1);
  }

  final supportedPlatforms = ['windows', 'linux', 'macos', 'android', 'ios'];
  if (!supportedPlatforms.contains(platform)) {
    _logError('Unsupported platform: $platform');
    exit(1);
  }

  // Execute Configuration
  try {
    final binaryPath =
        await _configurePlatform(config, platform, projectRoot, verbose);
    if (binaryPath != null) {
      // Success output for CMake/Scripts to verify
      print('FFMPEG_KIT_PATH=$binaryPath');

      if (generateBindings) {
        await _runFfigen(projectRoot, verbose);
      }
      exit(0);
    } else {
      exit(1);
    }
  } catch (e) {
    _logError('Configuration failed: $e');
    exit(1);
  }
}

// =============================================================================
// PLATFORM CONFIGURATION
// =============================================================================

Future<String?> _configurePlatform(dynamic config, String platform,
    Directory projectRoot, bool verbose) async {
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
  } else if (platform == 'macos') {
    // Universal binary usually provided or we pick one.
    // For simplicity assuming x86_64 or universal.
    // Actually our builders might provide specific archs.
    // Let's assume standard 'x86_64' for now or 'universal' if available.
    // If bundles are separate, we might need to download both and lipo?
    // For this example, let's stick to simple single-arch logic or the provided pattern.
  }

  // Filename Construction
  String filename;
  String url;

  if (overrideUrl != null) {
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
