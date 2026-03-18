/*
 * FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
 * Copyright (C) 2026 Akash Patel
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

// bin/configure.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

// =============================================================================
// RELEASE CONFIGURATION
// =============================================================================

const String _baseUrlTemplate =
    "https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download";
const String _githubApiUrl = "https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/releases";
const _validTypes = ['debug', 'base', 'full', 'audio', 'video', 'video_hw'];

// =============================================================================
// GITHUB API FUNCTIONS
// =============================================================================

/// Fetches the latest version for a specific platform from GitHub API
Future<String?> _getLatestVersionForPlatform(String platform, bool verbose) async {
  try {
    if (verbose) {
      stdout.writeln('FFmpegKit: Fetching latest version for $platform...');
    }

    final client = HttpClient();
    try {
      // Get all releases
      final request = await client.getUrl(Uri.parse(_githubApiUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        if (verbose) {
          stdout.writeln('FFmpegKit: Failed to fetch releases: ${response.statusCode}');
        }
        return null;
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final List<dynamic> releases = json.decode(responseBody);

      // Find the latest stable release for the specific platform (skip pre-releases)
      for (final release in releases) {
        if (release['prerelease'] == true) continue;
        final tagName = release['tag_name'] as String;
        if (tagName.endsWith('-$platform')) {
          // Extract version number (remove 'v' prefix and platform suffix)
          final version = tagName.substring(1, tagName.length - '-$platform'.length);
          if (verbose) {
            stdout.writeln('FFmpegKit: Found latest version for $platform: $version');
          }
          return version;
        }
      }

      if (verbose) {
        stdout.writeln('FFmpegKit: No release found for platform: $platform');
      }
      return null;
    } finally {
      client.close();
    }
  } catch (e) {
    if (verbose) {
      stdout.writeln('FFmpegKit: Error fetching version for $platform: $e');
    }
    return null;
  }
}

/// Gets the latest version, falling back to pubspec if GitHub API fails
Future<String> _getEffectiveVersion(dynamic config, String platform, bool verbose) async {
  // Try to get latest version from GitHub API first
  final latestVersion = await _getLatestVersionForPlatform(platform, verbose);
  
  if (latestVersion != null) {
    return latestVersion;
  }
  
  // Fallback to pubspec version
  final fallbackVersion = config['version']?.toString() ?? "0.0.0";
  if (verbose) {
    stdout.writeln('FFmpegKit: Using fallback version from pubspec: $fallbackVersion');
  }
  return fallbackVersion;
}
// =============================================================================
// CLI LOGIC
// =============================================================================

Future<void> main(List<String> args) async {
  final platforms = [];
  String? appRootPath;
  bool generateBindings = false;
  bool verbose = false;

  final supportedPlatforms = [
    'windows',
    'linux',
    'android'
  ]; // TODO: add 'macos', 'ios'

  // Simple Argument Parser
  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      stdout.write('''
Usage: dart run ffmpeg_kit_extended_flutter:configure [platforms] [options]

Platforms:
  Comma-separated list of platforms (e.g., windows,linux) or positional arguments.
  If omitted, the script will auto-detect supported platforms in the project root.

Options:
  --platform=<list>    Specify platforms to configure (e.g., windows,linux).
  --verbose            Enable verbose output.
  --generate-bindings  Generate Dart FFI bindings using ffigen.
  --app-root=<path>    Specify the path to the app root (defaults to CWD).
  --help, -h           Show this help message.

Configuration (pubspec.yaml):
  Add the following section to your pubspec.yaml:

  ffmpeg_kit_extended_config:
    # version: "1.0.0"   # Optional: Version fallback if GitHub API fails
    type: "full"       # $_validTypes
    gpl: true          # Include GPL libraries
    small: false       # Use smaller builds
    # Optional: overrides for specific platforms
    # windows: "C:\\\\path\\\\to\\\\bundle.zip"
    # linux: "https://example.com/bundle.zip"

Note: Version is automatically fetched from GitHub releases for each platform.
The version field in pubspec.yaml is only used as a fallback if GitHub API fails.
''');
      exit(0);
    } else if (arg == '--generate-bindings') {
      generateBindings = true;
    } else if (arg == '--verbose') {
      verbose = true;
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
    if (verbose) {
      stdout.writeln('FFmpegKit: Auto-detecting supported platforms...');
    }
    for (final pform in supportedPlatforms) {
      if (Directory(p.join(projectRoot.path, pform)).existsSync()) {
        platforms.add(pform);
      }
    }
  }

  if (verbose) {
    stdout.writeln('FFmpegKit: Project Root -> ${projectRoot.path}');
    stdout.writeln('FFmpegKit: Platforms -> ${platforms.join(', ')}');
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
      if (verbose) stdout.writeln('FFmpegKit: Configuring for $platform...');
      final binaryPath =
          await _configurePlatform(config, platform, projectRoot, verbose);
      if (binaryPath != null) {
        configuredPaths[platform] = binaryPath;
        // Success output for CMake/Scripts to verify (Legacy support)
        stdout.writeln('FFMPEG_KIT_PATH_$platform=$binaryPath');
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
    Directory projectRoot, bool verbose) async {
  // Parse Config values
  final version = await _getEffectiveVersion(config, platform, verbose);
  String type = config['type']?.toString() ?? "full";
  if (type == "streaming") {
    type =
        "video"; //XXX streaming added to all libraries. Streaming is same as video.
    stdout.writeln(
        "WARNING: Streaming libraries have been added to all bundles. Streaming type will be deprecated in future, switch to video.");
  }
  if (!_validTypes.contains(type)) {
    _logError(
        'Invalid bundle type: $type. Valid types are: ${_validTypes.join(', ')}');
    exit(1);
  }
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
  } else if (platform == 'android') {
    arch = '';
  } else {
    _logError('Unsupported platform: $platform');
    exit(1);
  }

  // Filename Construction
  String filename;
  String url;

  Future<bool> tryDownload(String url, File zipFile) async {
    bool downloadSuccess = false;
    int retries = 3;
    while (retries > 0) {
      try {
        if (await _downloadFile(url, zipFile)) {
          downloadSuccess = true;
          break;
        }
      } catch (e) {
        if (verbose) {
          stdout.writeln('FFmpegKit: Download error: $e');
        }
      }
      retries--;
      if (retries > 0) {
        if (verbose) {
          stdout.writeln('FFmpegKit: Retrying download...');
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return downloadSuccess;
  }

  bool skipExtract = false;

  if (overrideUrl != null) {
    if (_isUri(overrideUrl)) {
      url = overrideUrl;
      filename = p.basename(Uri.parse(url).path);
    } else if (_isFile(overrideUrl)) {
      final localFile = File(overrideUrl);
      if (localFile.existsSync()) {
        if (verbose) {
          stdout
              .writeln('FFmpegKit: Using local override -> ${localFile.path}');
        }
        if (FileSystemEntity.isDirectorySync(localFile.path)) {
          final finalDir = Directory(localFile.path);
          await _updateMetadata(finalDir, cacheDir, projectRoot, verbose);
          return finalDir.path;
        } else {
          filename = p.basename(localFile.path);
          url = ''; // Local handling
          final cacheFile = File(p.join(cacheDir.path, filename));
          if (!cacheFile.existsSync() ||
              cacheFile.lengthSync() != localFile.lengthSync()) {
            localFile.copySync(cacheFile.path);
          }

          if (platform == 'android') {
            final pathFile = File(p.join(cacheDir.path, 'current_path.txt'));
            pathFile.writeAsStringSync(cacheFile.path);
            return cacheFile.path;
          } else {
            await _extractFile(cacheFile, cacheDir.path, verbose);
            final extractedName = p.basenameWithoutExtension(filename);
            final finalDir = Directory(p.join(cacheDir.path, extractedName));
            await _updateMetadata(finalDir, cacheDir, projectRoot, verbose);
            return finalDir.path;
          }
        }
      } else {
        _logError('Local override path not found: $overrideUrl');
        exit(1);
      }
    } else {
      _logError('Invalid override URL: $overrideUrl');
      exit(1);
    }
  } else {
    // Resolve artifact properties
    final currentType = type == 'debug' ? 'base' : type;
    final license = gpl ? 'gpl' : 'lgpl';

    if (platform == 'android') {
      // Maven Central download for Android
      const groupIdPath = 'io/github/akashskypatel/ffmpegkit';
      final parts = ['bundle', currentType, 'shared'];

      if (type == 'debug') {
        parts.add('debug');
      } else if (small) {
        parts.add('small');
      }
      parts.add(license);

      final artifactId = parts.join('-');
      final remoteFilename = "$artifactId-$version.aar";

      // Save as .zip to ensure smooth extraction
      filename = "$artifactId-$version.zip";
      url =
          "https://repo1.maven.org/maven2/$groupIdPath/$artifactId/$version/$remoteFilename";

      // We MUST extract the AAR for Flutter plugins
      skipExtract = false;
    } else {
      // GitHub Releases for Desktop platforms
      final parts = ['bundle', currentType, platform, arch, 'shared'];

      if (type != 'debug' && small) {
        parts.add('small');
      }
      parts.add(license);

      filename = "${parts.join('-')}.zip";
      final tag = "v$version-$platform";
      url = "$_baseUrlTemplate/$tag/$filename";
    }
  }

  // --- Unified Caching Logic ---
  final targetFile = File(p.join(cacheDir.path, filename));
  final extractedFolderName = p.basenameWithoutExtension(filename);
  final destinationDir = Directory(p.join(cacheDir.path, extractedFolderName));

  // For Android, cache hit is just the AAR file existing. For desktop, it's the extracted folder.
  final bool cacheHit = skipExtract
      ? targetFile.existsSync()
      : (destinationDir.existsSync() && destinationDir.listSync().isNotEmpty);

  if (cacheHit) {
    if (verbose) {
      stdout.writeln(
          'FFmpegKit: Cache hit -> ${skipExtract ? targetFile.path : destinationDir.path}');
    }
  } else {
    if (verbose) {
      stdout.writeln('FFmpegKit: Downloading $url...');
    }

    if (!await tryDownload(url, targetFile)) {
      _logError('Error downloading from $url.');
      exit(1);
    }

    if (!skipExtract) {
      if (verbose) stdout.writeln('FFmpegKit: Extracting...');
      if (!await _extractFile(targetFile, cacheDir.path, verbose)) {
        _logError('Extraction failed.');
        exit(1);
      }
    }
  }

  // --- Output Resolution ---
  if (skipExtract) {
    // Android Output: Write the direct path to the AAR and return
    final pathFile = File(p.join(cacheDir.path, 'current_path.txt'));
    pathFile.writeAsStringSync(targetFile.path);
    return targetFile.path;
  } else {
    // Desktop Output: Resolve the extracted directory
    final finalDir = destinationDir.existsSync() ? destinationDir : cacheDir;
    await _updateMetadata(finalDir, cacheDir, projectRoot, verbose);
    return finalDir.path;
  }
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
    if (verbose) {
      stdout.writeln('FFmpegKit: Updating generic include path for ffigen...');
    }
    await _copyDirectory(sourceIncludeDir, fixedIncludeDir);
  } else {
    // If we can't find 'include' directly, maybe it's nested?
    // Some bundles might have top-level include, others generic.
    // For now, warning is enough.
    if (verbose) {
      stdout.writeln(
          'FFmpegKit: Warning - include directory not found in bundle.');
    }
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
  if (verbose) {
    stdout.writeln('FFmpegKit: Generated CMake config at ${configFile.path}');
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
        if (verbose) {
          stderr.writeln("Extract failed: ${res.stderr}");
        }
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
          if (verbose) {
            stderr.writeln("Extract failed: ${res2.stderr}");
          }
          return false;
        }
      }
    }
    return true;
  } catch (e) {
    if (verbose) {
      stderr.writeln("Extract exception: $e");
    }
    return false;
  }
}

Future<void> _runFfigen(Directory projectRoot, bool verbose) async {
  // Logic to locate ffigen config relative to package root
  // This is typically only run by developers of the plugin
  if (verbose) {
    stdout.writeln("FFmpegKit: Running ffigen...");
  }
  final result = await Process.run(
    'dart',
    ['run', 'ffigen', '--config', 'ffigen.yaml'],
    workingDirectory: projectRoot.path, // Assuming running from package root
    runInShell: true,
  );
  if (result.exitCode != 0) {
    stderr.writeln('FFmpegKit: ffigen failed: ${result.stderr}');
  } else {
    stdout.writeln('FFmpegKit: ffigen completed.');
  }
}

void _logError(String message) {
  stderr.writeln('FFmpegKit Error: $message');
}

bool _isUri(String path) {
  try {
    if(path.contains("\\\\wsl.")) {
      return false;
    }
    Uri.parse(path);
    return true;
  } catch (e) {
    return false;
  }
}

bool _isFile(String path) {
  try {
    File(path);
    return true;
  } catch (e) {
    return false;
  }
}
