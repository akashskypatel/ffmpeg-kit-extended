import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const String _baseUrlTemplate =
    "https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download";
const _validTypes = ['debug', 'base', 'full', 'audio', 'video', 'video_hw'];
const String version = "0.9.1";

class ConfigResult {
  final dynamic config;
  final String baseDir;
  ConfigResult(this.config, this.baseDir);
}

void main(List<String> args) async {
  await build(args, (input, output) async {
    final packageName = input.packageName;
    final targetOS = input.config.code.targetOS;
    final targetArch = input.config.code.targetArchitecture;

    stdout.writeln(
      'FFmpegKit: Build Hook for $packageName on ${targetOS.name}-${targetArch.name}',
    );

    // 1. Load Configuration
    final configResult = _loadConfig(input);

    // 2. Resolve Artifact
    final artifact = await _resolveArtifact(
      configResult,
      targetOS,
      targetArch,
      input,
    );
    if (artifact == null) {
      throw Exception(
        'FFmpegKit: Failed to resolve artifact for ${targetOS.name}-${targetArch.name}',
      );
    }

    // 3. Emit Assets
    await _emitAssets(artifact, input, output, targetOS);
  });
}

ConfigResult _loadConfig(BuildInput input) {
  final packageRoot = p.normalize(input.packageRoot.toFilePath());
  final packageConfig = Platform.packageConfig;

  stdout.writeln('FFmpegKit: input.packageRoot: $packageRoot');
  stdout.writeln('FFmpegKit: Platform.packageConfig: $packageConfig');

  // 1. Prefer consuming app config via Platform.packageConfig anchor
  if (packageConfig != null) {
    // packageConfig is a file:/// URI pointing to .dart_tool/package_config.json
    final packageConfigPath = p.normalize(
      File.fromUri(Uri.parse(packageConfig)).path,
    );
    // appRoot is two levels up from .dart_tool/package_config.json
    final appRoot = p.dirname(p.dirname(packageConfigPath));
    final appPubspec = File(p.join(appRoot, 'pubspec.yaml'));

    if (appPubspec.existsSync()) {
      final config = _parsePubspec(appPubspec);
      if (config != null) {
        stdout.writeln(
          'FFmpegKit: Using app configuration from ${appPubspec.path}',
        );
        return ConfigResult(config, appRoot);
      }
      stdout.writeln(
        'FFmpegKit: Found app pubspec at $appRoot but no ffmpeg_kit_extended_config',
      );
    }
  }

  // 2. Fallback to package root only if we are building the package itself
  // (e.g. during local tests or examples within the same repo)
  final pkgPubspec = File(p.join(packageRoot, 'pubspec.yaml'));
  if (pkgPubspec.existsSync()) {
    final config = _parsePubspec(pkgPubspec);
    if (config != null) {
      stdout.writeln(
        'FFmpegKit: Using package-local configuration from ${pkgPubspec.path}',
      );
      return ConfigResult(config, packageRoot);
    }
  }

  // 3. Last Resort: Default Configuration
  stdout.writeln(
    'FFmpegKit: No configuration found. Using default "full" build.',
  );
  return ConfigResult({
    'type': 'full',
    'gpl': true,
    'small': false,
  }, packageRoot);
}

dynamic _parsePubspec(File file) {
  try {
    final content = file.readAsStringSync();
    final doc = loadYaml(content);
    return doc['ffmpeg_kit_extended_config'];
  } catch (e) {
    return null;
  }
}

class FFmpegArtifact {
  final File file;
  final Directory? extractedDir;
  final bool isAar;

  FFmpegArtifact({required this.file, this.extractedDir, this.isAar = false});
}

class AppleRuntimeLayout {
  final File frameworkBinary;
  final List<File> companionLibraries;

  AppleRuntimeLayout({
    required this.frameworkBinary,
    required this.companionLibraries,
  });
}

Future<FFmpegArtifact?> _resolveArtifact(
  ConfigResult configResult,
  OS targetOS,
  Architecture targetArch,
  BuildInput input,
) async {
  final config = configResult.config;
  String type = config['type']?.toString() ?? "full";
  if (type == "streaming") type = "video";
  if (!_validTypes.contains(type)) {
    stderr.writeln(
      'Invalid bundle type: $type. Valid types are: ${_validTypes.join(', ')}',
    );
    exit(1);
  }

  final bool gpl = config['gpl'] == true;
  final bool small = config['small'] == true;
  final platformName = targetOS.name; // Use .name for stable keys
  final overrideUrl = config[platformName]?.toString();

  final cacheDir = Directory(
    p.fromUri(
      input.outputDirectoryShared.resolve('ffmpeg_kit_cache/$platformName/'),
    ),
  );
  if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);

  String filename;
  String url = '';

  if (overrideUrl != null) {
    if (_isUri(overrideUrl)) {
      url = overrideUrl;
      filename = p.basename(Uri.parse(url).path);
    } else {
      final localFile = p.isAbsolute(overrideUrl)
          ? File(overrideUrl)
          : File(p.join(configResult.baseDir, overrideUrl));

      if (localFile.existsSync()) {
        filename = p.basename(localFile.path);
        final cacheFile = File(p.join(cacheDir.path, filename));
        if (!cacheFile.existsSync() ||
            cacheFile.lengthSync() != localFile.lengthSync()) {
          localFile.copySync(cacheFile.path);
        }
        return _handleDownloadedFile(cacheFile, cacheDir, targetOS, input);
      }
      throw Exception(
        'FFmpegKit: Local override not found: $overrideUrl (resolved from ${configResult.baseDir})',
      );
    }
  } else {
    final license = gpl ? 'gpl' : 'lgpl';
    final currentType = type == 'debug' ? 'base' : type;

    if (targetOS == OS.android) {
      const groupIdPath = 'io/github/akashskypatel/ffmpegkit';
      final parts = ['bundle', currentType, 'shared'];
      if (type == 'debug') {
        parts.add('debug');
      } else if (small) {
        parts.add('small');
      }
      parts.add(license);
      final artifactId = parts.join('-');
      filename = "$artifactId-$version.aar";
      url =
          "https://repo1.maven.org/maven2/$groupIdPath/$artifactId/$version/$filename";
    } else if (targetOS == OS.iOS || targetOS == OS.macOS) {
      final parts = [
        'bundle',
        currentType,
        platformName,
        'universal',
        'shared',
      ];
      if (type != 'debug' && small) parts.add('small');
      parts.add(license);
      filename = "${parts.join('-')}.xcframework.zip";
      final tag = "v$version-$platformName";
      url = "$_baseUrlTemplate/$tag/$filename";
    } else {
      // Windows, Linux
      final archStr = targetArch == Architecture.x64
          ? 'x86_64'
          : (targetArch == Architecture.arm64 ? 'arm64' : 'x86_64');
      final parts = ['bundle', currentType, platformName, archStr, 'shared'];
      if (type != 'debug' && small) parts.add('small');
      parts.add(license);
      filename = "${parts.join('-')}.zip";
      final tag = "v$version-$platformName";
      url = "$_baseUrlTemplate/$tag/$filename";
    }
  }

  final targetFile = File(p.join(cacheDir.path, filename));
  if (!targetFile.existsSync()) {
    stdout.writeln('FFmpegKit: Downloading $url...');
    if (!await _downloadFile(url, targetFile)) {
      throw Exception('FFmpegKit: Failed to download $url');
    }
  }

  return _handleDownloadedFile(targetFile, cacheDir, targetOS, input);
}

Future<FFmpegArtifact> _handleDownloadedFile(
  File file,
  Directory cacheDir,
  OS targetOS,
  BuildInput input,
) async {
  if (file.path.endsWith('.aar')) {
    return FFmpegArtifact(file: file, isAar: true);
  }

  final extractedDir = Directory(
    p.join(cacheDir.path, p.basenameWithoutExtension(file.path)),
  );
  if (!extractedDir.existsSync() || extractedDir.listSync().isEmpty) {
    stdout.writeln('FFmpegKit: Extracting ${file.path}...');
    if (!await _extractFile(file, cacheDir.path)) {
      throw Exception('FFmpegKit: Failed to extract ${file.path}');
    }
  }
  return FFmpegArtifact(file: file, extractedDir: extractedDir);
}

Future<void> _emitAssets(
  FFmpegArtifact artifact,
  BuildInput input,
  BuildOutputBuilder output,
  OS targetOS,
) async {
  final packageName = input.packageName;

  if (targetOS == OS.android) {
    // Extract AAR to get .so files for the target architecture
    final tempDir = Directory(
      p.fromUri(input.outputDirectory.resolve('aar_extract/')),
    );
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync(recursive: true);

    await _extractFile(artifact.file, tempDir.path);

    // Find jniLibs
    final jniDir = Directory(p.join(tempDir.path, 'jni'));
    if (!jniDir.existsSync()) {
      throw Exception('FFmpegKit: Could not find jni directory in AAR');
    }

    final abi = _getAndroidAbi(input.config.code.targetArchitecture);
    final abiDir = Directory(p.join(jniDir.path, abi));
    if (!abiDir.existsSync()) {
      throw Exception('FFmpegKit: Could not find ABI directory $abi in AAR');
    }

    // Find all .so files
    final soFiles =
        abiDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.so'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    // Identify the main ffmpegkit library and companion libraries
    final mainLibrary = soFiles.firstWhere(
      (file) => p.basename(file.path) == 'libffmpegkit.so',
      orElse: () => soFiles.first,
    );

    // Add the main library
    final mainName = p
        .basenameWithoutExtension(mainLibrary.path)
        .replaceFirst('lib', '');
    output.assets.code.add(
      CodeAsset(
        package: packageName,
        name: mainName,
        linkMode: DynamicLoadingBundled(),
        file: Uri.file(mainLibrary.path),
      ),
    );

    // Add companion libraries with the 'native/' prefix
    for (final file in soFiles) {
      if (file.path != mainLibrary.path) {
        final name = p.basename(file.path);
        output.assets.code.add(
          CodeAsset(
            package: packageName,
            name: 'native/$name',
            linkMode: DynamicLoadingBundled(),
            file: Uri.file(file.path),
          ),
        );
      }
    }

    // Stage classes.jar path for the Android plugin build.
    // We write a properties file in input.outputDirectoryShared so Gradle can find it.
    final classesJar = File(p.join(tempDir.path, 'classes.jar'));
    if (classesJar.existsSync()) {
      final configDir = Directory(
        p.fromUri(input.outputDirectoryShared.resolve('android_config/')),
      );
      if (!configDir.existsSync()) configDir.createSync(recursive: true);

      final propsFile = File(p.join(configDir.path, 'paths.properties'));
      propsFile.writeAsStringSync('classes_jar=${classesJar.path}\n');
      stdout.writeln('FFmpegKit: Staged classes.jar path to ${propsFile.path}');
    }
  } else if (targetOS == OS.iOS || targetOS == OS.macOS) {
    final runtimeLayout = await _buildAppleRuntimeFramework(
      artifact: artifact,
      input: input,
      targetOS: targetOS,
    );

    output.assets.code.add(
      CodeAsset(
        package: packageName,
        name: 'ffmpegkit',
        linkMode: DynamicLoadingBundled(),
        file: Uri.file(runtimeLayout.frameworkBinary.path),
      ),
    );

    for (final companionLibrary in runtimeLayout.companionLibraries) {
      output.assets.code.add(
        CodeAsset(
          package: packageName,
          name: 'native/${p.basename(companionLibrary.path)}',
          linkMode: DynamicLoadingBundled(),
          file: Uri.file(companionLibrary.path),
        ),
      );
    }
  } else {
    // Windows, Linux
    final libDir = artifact.extractedDir!;
    final ext = targetOS == OS.windows ? '.dll' : '.so';

    // Find all library files in the bin directory (where DLLs are typically located)
    final libFiles = <File>[];

    // Look for files in bin directory first (common for Windows)
    final binDir = Directory('${libDir.path}/bin');
    if (binDir.existsSync()) {
      libFiles.addAll(
        binDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith(ext))
            .toList(),
      );
    }

    // Also look in lib directory (common for Linux)
    final libDirPath = Directory('${libDir.path}/lib');
    if (libDirPath.existsSync()) {
      libFiles.addAll(
        libDirPath
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith(ext))
            .toList(),
      );
    }

    // Also look in the root directory
    libFiles.addAll(
      libDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith(ext))
          .toList(),
    );

    // Remove duplicates and sort
    final uniqueLibFiles = libFiles.toSet().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (uniqueLibFiles.isEmpty) {
      stderr.writeln('FFmpegKit: No library files found in ${libDir.path}');
      return;
    }

    // Identify the main ffmpegkit library and companion libraries
    File mainLibrary;
    try {
      mainLibrary = uniqueLibFiles.firstWhere(
        (file) => p.basename(file.path).toLowerCase().contains('ffmpegkit'),
      );
    } catch (e) {
      // If no ffmpegkit library found, use the first library
      mainLibrary = uniqueLibFiles.first;
      stdout.writeln(
        'FFmpegKit: No ffmpegkit library found, using ${p.basename(mainLibrary.path)} as main library',
      );
    }

    // Add the main library
    var mainName = p.basenameWithoutExtension(mainLibrary.path);
    if (targetOS == OS.linux) mainName = mainName.replaceFirst('lib', '');
    output.assets.code.add(
      CodeAsset(
        package: packageName,
        name: mainName,
        linkMode: DynamicLoadingBundled(),
        file: Uri.file(mainLibrary.path),
      ),
    );

    // Add companion libraries with the 'native/' prefix
    for (final file in uniqueLibFiles) {
      if (file.path != mainLibrary.path) {
        final name = p.basename(file.path);
        // For Linux, remove 'lib' prefix from companion libraries as well
        var assetName = name;
        if (targetOS == OS.linux) {
          assetName = assetName.replaceFirst('lib', '');
          // Also remove the .so extension for the asset name
          if (assetName.endsWith('.so')) {
            assetName = assetName.substring(0, assetName.length - 3);
          }
        }
        output.assets.code.add(
          CodeAsset(
            package: packageName,
            name: 'native/$assetName',
            linkMode: DynamicLoadingBundled(),
            file: Uri.file(file.path),
          ),
        );
      }
    }
  }
}

Future<AppleRuntimeLayout> _buildAppleRuntimeFramework({
  required FFmpegArtifact artifact,
  required BuildInput input,
  required OS targetOS,
}) async {
  final libDir = artifact.extractedDir!;
  final archStr = _getAppleArch(input.config.code.targetArchitecture);
  final slicePrefix = targetOS == OS.iOS ? 'ios-' : 'macos-';
  final sliceDir = Directory(
    libDir
        .listSync(followLinks: false)
        .whereType<Directory>()
        .map((d) => d.path)
        .firstWhere(
          (path) => p.basename(path).startsWith(slicePrefix),
          orElse: () => throw Exception(
            'FFmpegKit: Could not find Apple slice starting with $slicePrefix in ${libDir.path}',
          ),
        ),
  );

  final sourceDylibs =
      sliceDir
          .listSync(followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dylib'))
          .where((f) => !FileSystemEntity.isLinkSync(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final sourceMainDylib = sourceDylibs.firstWhere(
    (f) => p.basename(f.path) == 'libffmpegkit.dylib',
    orElse: () => throw Exception(
      'FFmpegKit: libffmpegkit.dylib not found in ${sliceDir.path}',
    ),
  );

  final frameworkRoot = Directory(
    p.fromUri(input.outputDirectory.resolve('ffmpegkit.framework/')),
  );
  if (frameworkRoot.existsSync()) {
    frameworkRoot.deleteSync(recursive: true);
  }

  final frameworkBinary = targetOS == OS.macOS
      ? File(p.join(frameworkRoot.path, 'Versions', 'A', 'ffmpegkit'))
      : File(p.join(frameworkRoot.path, 'ffmpegkit'));
  final headersDir = targetOS == OS.macOS
      ? Directory(p.join(frameworkRoot.path, 'Versions', 'A', 'Headers'))
      : Directory(p.join(frameworkRoot.path, 'Headers'));
  final resourcesDir = targetOS == OS.macOS
      ? Directory(p.join(frameworkRoot.path, 'Versions', 'A', 'Resources'))
      : frameworkRoot;
  final companionDir = Directory(
    p.fromUri(input.outputDirectory.resolve('native/')),
  );

  headersDir.createSync(recursive: true);
  resourcesDir.createSync(recursive: true);
  if (companionDir.existsSync()) {
    companionDir.deleteSync(recursive: true);
  }
  companionDir.createSync(recursive: true);

  await _thinOrCopyAppleBinary(
    source: sourceMainDylib,
    destination: frameworkBinary,
    archStr: archStr,
  );

  final companionLibraries = <File>[];
  for (final dylib in sourceDylibs) {
    if (dylib.path == sourceMainDylib.path) continue;
    final destination = File(p.join(companionDir.path, p.basename(dylib.path)));
    await _thinOrCopyAppleBinary(
      source: dylib,
      destination: destination,
      archStr: archStr,
    );
    companionLibraries.add(destination);
  }

  final sourceHeadersDir = Directory(p.join(sliceDir.path, 'Headers'));
  if (sourceHeadersDir.existsSync()) {
    await _copyDirectory(sourceHeadersDir, headersDir);
  }

  final infoPlist = File(p.join(resourcesDir.path, 'Info.plist'));
  infoPlist.writeAsStringSync(_appleFrameworkInfoPlist(targetOS));

  if (targetOS == OS.macOS) {
    _createFrameworkSymlink(
      frameworkRoot,
      'Headers',
      'Versions/Current/Headers',
    );
    _createFrameworkSymlink(
      frameworkRoot,
      'Resources',
      'Versions/Current/Resources',
    );
    _createFrameworkSymlink(
      frameworkRoot,
      'ffmpegkit',
      'Versions/Current/ffmpegkit',
    );
    _createFrameworkSymlink(frameworkRoot, 'Versions/Current', 'A');
  }

  return AppleRuntimeLayout(
    frameworkBinary: frameworkBinary,
    companionLibraries: companionLibraries,
  );
}

Future<void> _thinOrCopyAppleBinary({
  required File source,
  required File destination,
  required String archStr,
}) async {
  destination.parent.createSync(recursive: true);
  stdout.writeln(
    'FFmpegKit: Thinning ${p.basename(source.path)} to $archStr...',
  );

  final lipoRes = await Process.run('lipo', [
    source.path,
    '-thin',
    archStr,
    '-output',
    destination.path,
  ]);

  if (lipoRes.exitCode != 0) {
    source.copySync(destination.path);
  }
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  if (!destination.existsSync()) {
    destination.createSync(recursive: true);
  }
  await for (final entity in source.list(
    recursive: false,
    followLinks: false,
  )) {
    final targetPath = p.join(destination.path, p.basename(entity.path));
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(targetPath));
    } else if (entity is File) {
      entity.copySync(targetPath);
    }
  }
}

void _createFrameworkSymlink(
  Directory frameworkRoot,
  String name,
  String target,
) {
  final link = Link(p.join(frameworkRoot.path, name));
  if (link.existsSync()) {
    link.deleteSync();
  }
  link.createSync(target);
}

String _appleFrameworkInfoPlist(OS targetOS) {
  final platform = targetOS == OS.macOS ? 'MacOSX' : 'iPhoneOS';
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>ffmpegkit</string>
  <key>CFBundleIdentifier</key>
  <string>io.github.akashskypatel.ffmpegkit</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>ffmpegkit</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleSupportedPlatforms</key>
  <array>
    <string>$platform</string>
  </array>
</dict>
</plist>
''';
}

String _getAndroidAbi(Architecture arch) {
  if (arch == Architecture.arm) return 'armeabi-v7a';
  if (arch == Architecture.arm64) return 'arm64-v8a';
  if (arch == Architecture.ia32) return 'x86';
  if (arch == Architecture.x64) return 'x86_64';
  return 'arm64-v8a';
}

String _getAppleArch(Architecture arch) {
  if (arch == Architecture.arm64) return 'arm64';
  if (arch == Architecture.x64) return 'x86_64';
  return 'arm64';
}

Future<bool> _downloadFile(String url, File target) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode == 200) {
      await response.pipe(target.openWrite());
      return true;
    }
    return false;
  } finally {
    client.close();
  }
}

Future<bool> _extractFile(File zipFile, String destPath) async {
  try {
    if (Platform.isWindows) {
      final res = await Process.run('powershell', [
        '-command',
        'Expand-Archive -Path "${zipFile.path}" -DestinationPath "$destPath" -Force',
      ]);
      return res.exitCode == 0;
    } else {
      final res = await Process.run('unzip', [
        '-o',
        zipFile.path,
        '-d',
        destPath,
      ]);
      if (res.exitCode != 0) {
        final res2 = await Process.run('tar', [
          '-xf',
          zipFile.path,
          '-C',
          destPath,
        ]);
        return res2.exitCode == 0;
      }
      return true;
    }
  } catch (e) {
    return false;
  }
}

bool _isUri(String path) {
  try {
    if (path.contains("\\\\wsl.")) return false;
    final uri = Uri.parse(path);
    return uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'ftp');
  } catch (e) {
    return false;
  }
}
