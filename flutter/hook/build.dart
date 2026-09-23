import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'apple.dart';
import 'config.dart';
import 'native_artifact.dart';

const String _baseUrlTemplate =
    "https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download";
const _validTypes = ['debug', 'base', 'full', 'audio', 'video', 'video_hw'];
// This version is pinned per release. Changing this version manually may cause runtime failures. DO NOT CHANGE from official pinned version.
const String version = "0.11.2";
const String _extractMarkerFileName = '.extract_complete';
const String _wasmPlatformName = 'wasm';
const String _wasmArchitectureName = 'wasm32';
const String localArtifactOnlyEnvironmentVariable =
    'FFMPEG_KIT_EXTENDED_LOCAL_ONLY';

void _log(String message) => stderr.writeln('FFmpegKit [Build Hook]: $message');
Exception _exception(Object e) => Exception('FFmpegKit [Build Hook]: $e');

@visibleForTesting
bool isLocalArtifactOnlyEnabled([Map<String, String>? environment]) =>
    (environment ?? Platform.environment)[localArtifactOnlyEnvironmentVariable]
        ?.toLowerCase() ==
    'true';

late final OS targetOS;
late final Architecture targetArch;

void main(List<String> args) async {
  await build(args, (input, output) async {
    // Flutter Web builds do not expose a CodeAsset target. Resolve the
    // selected Wasm runtime and stage it into the consuming Web app instead.
    if (!input.config.buildCodeAssets) {
      await _buildWebAssets(input, output);
      return;
    }
    final packageName = input.packageName;
    targetOS = input.config.code.targetOS;
    targetArch = input.config.code.targetArchitecture;

    _log('Build Hook for $packageName on ${targetOS.name}-${targetArch.name}');
    _log(
      'Target: ${targetOS.name}-${targetArch.name}; '
      'SDK: ${_buildHookSdk(input)}',
    );
    validateTargetArchitecture(targetOS, targetArch);

    // 1. Load Configuration
    final configResult = _loadConfig(input, output);

    // 2. Resolve Artifact
    final artifact = await _resolveArtifact(
      configResult,
      input,
      output.dependencies.add,
    );
    if (artifact == null) {
      throw _exception(
        'Failed to resolve artifact for ${targetOS.name}-${targetArch.name}',
      );
    }

    // 3. Emit Assets
    await _emitAssets(artifact, input, output);
  });
}

Future<void> _buildWebAssets(
  BuildInput input,
  BuildOutputBuilder output,
) async {
  final configResult = _loadConfig(input, output);
  validateWebBundleSelection(configResult.config);

  final source = await _resolveWebArtifact(
    configResult,
    input,
    output.dependencies.add,
  );
  final runtimeDir = selectWebRuntimeDirectory(source.searchRoot);
  if (runtimeDir == null) {
    throw _exception(
      'WASM bundle must contain exactly one directory with both '
      'ffmpegkit.mjs and ffmpegkit.wasm under ${source.searchRoot.path}',
    );
  }

  for (final dependency in source.dependencies) {
    output.dependencies.add(dependency);
  }

  final packageRoot = p.normalize(input.packageRoot.toFilePath());
  final stagingBaseDirs = resolveWebStagingBaseDirs(
    packageName: input.packageName,
    packageRoot: packageRoot,
    packageConfig: Platform.packageConfig,
    configBaseDir: configResult.configBaseDir,
    outputFile: input.outputFile.toFilePath(),
    addDependency: output.dependencies.add,
    log: _log,
  );

  final bridgeSource = File(
    p.fromUri(input.packageRoot.resolve('web/ffmpegkit_bridge.mjs')),
  );
  final callbackRuntimeSource = File(
    p.fromUri(input.packageRoot.resolve('web/ffmpegkit_callback_runtime.mjs')),
  );
  final loaderSource = File(
    p.fromUri(input.packageRoot.resolve('web/ffmpegkit_loader.mjs')),
  );

  final runtimeFiles = <String, File>{
    'ffmpegkit.mjs': File(p.join(runtimeDir.path, 'ffmpegkit.mjs')),
    'ffmpegkit.wasm': File(p.join(runtimeDir.path, 'ffmpegkit.wasm')),
    'ffmpegkit_bridge.mjs': bridgeSource,
    'ffmpegkit_callback_runtime.mjs': callbackRuntimeSource,
    'ffmpegkit_loader.mjs': loaderSource,
  };

  for (final entry in runtimeFiles.entries) {
    if (!entry.value.existsSync()) {
      throw _exception(
        'Missing Web runtime file ${entry.key}: ${entry.value.path}',
      );
    }
  }

  output.dependencies.add(bridgeSource.uri);
  output.dependencies.add(callbackRuntimeSource.uri);
  output.dependencies.add(loaderSource.uri);

  await stageWebRuntimeFiles(
    files: runtimeFiles,
    stagingBaseDirs: stagingBaseDirs,
    packageName: input.packageName,
  );

  _log(
    'Staged selected Flutter Web runtime '
    '(${configDiagnosticSummary(configResult.config)}) for ${input.packageName} '
    'under assets/packages/${input.packageName}/wasm/ in '
    '${stagingBaseDirs.join(', ')}. Dart DataAssets are not required.',
  );
}

@visibleForTesting
List<Directory> webRuntimeStagingDirectories({
  required String stagingBaseDir,
  required String packageName,
}) => <Directory>[
  Directory(
    p.join(
      stagingBaseDir,
      'build',
      'web',
      'assets',
      'packages',
      packageName,
      'wasm',
    ),
  ),
  Directory(
    p.join(stagingBaseDir, 'web', 'assets', 'packages', packageName, 'wasm'),
  ),
];

@visibleForTesting
Future<void> stageWebRuntimeFiles({
  required Map<String, File> files,
  required Iterable<String> stagingBaseDirs,
  required String packageName,
}) async {
  final sourceHashes = <String, String?>{};
  for (final entry in files.entries) {
    if (!entry.value.existsSync()) {
      throw _exception(
        'Missing Web runtime file ${entry.key}: ${entry.value.path}',
      );
    }
    sourceHashes[entry.key] = await _computeFileSha256(entry.value);
  }

  for (final stagingBaseDir in stagingBaseDirs) {
    for (final webAssetDir in webRuntimeStagingDirectories(
      stagingBaseDir: stagingBaseDir,
      packageName: packageName,
    )) {
      webAssetDir.createSync(recursive: true);
      for (final entry in files.entries) {
        final destination = File(p.join(webAssetDir.path, entry.key));
        final destinationHash = destination.existsSync()
            ? await _computeFileSha256(destination)
            : null;
        if (destinationHash != sourceHashes[entry.key]) {
          entry.value.copySync(destination.path);
        }
      }
    }
  }
}

/// Rejects the known-invalid automatic Web debug artifact before any
/// download, cache, extraction, or staging work can begin.
@visibleForTesting
void validateWebBundleSelection(dynamic config) {
  final type = config['type']?.toString() ?? 'base';
  final override = config['web']?.toString() ?? config['wasm']?.toString();
  if (type == 'debug' && (override == null || override.trim().isEmpty)) {
    throw _exception(
      'The automatic prebuilt Flutter Web debug artifact is unsupported '
      'because the published artifact is browser-incompatible. For Web '
      'debug/custom development, provide an explicit web/wasm override '
      'containing one coherent ffmpegkit.mjs + ffmpegkit.wasm pair.',
    );
  }
}

@visibleForTesting
Directory? selectWebRuntimeDirectory(Directory extractedDir) {
  if (!extractedDir.existsSync()) return null;

  final candidateDirectories = <String, Directory>{};
  for (final entity in extractedDir.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (name == 'ffmpegkit.mjs' || name == 'ffmpegkit.wasm') {
      final parent = entity.parent;
      candidateDirectories[p.normalize(parent.path)] = parent;
    }
  }

  final completeDirectories = candidateDirectories.values
      .where(
        (directory) =>
            File(p.join(directory.path, 'ffmpegkit.mjs')).existsSync() &&
            File(p.join(directory.path, 'ffmpegkit.wasm')).existsSync(),
      )
      .toList();
  return completeDirectories.length == 1 ? completeDirectories.single : null;
}

@visibleForTesting
WebRuntimeSource? resolveLocalWebDirectory({
  required String overridePath,
  required String configBaseDir,
}) {
  final localPath = p.isAbsolute(overridePath)
      ? overridePath
      : p.join(configBaseDir, overridePath);
  if (FileSystemEntity.typeSync(localPath, followLinks: false) !=
      FileSystemEntityType.directory) {
    return null;
  }

  final searchRoot = Directory(localPath);
  final runtimeDir = selectWebRuntimeDirectory(searchRoot);
  if (runtimeDir == null) {
    throw _exception(
      'Local Web override directory must contain exactly one directory '
      'with both ffmpegkit.mjs and ffmpegkit.wasm: $localPath',
    );
  }
  return WebRuntimeSource(
    searchRoot: searchRoot,
    dependencies: [
      File(p.join(runtimeDir.path, 'ffmpegkit.mjs')).uri,
      File(p.join(runtimeDir.path, 'ffmpegkit.wasm')).uri,
    ],
  );
}

Future<WebRuntimeSource> _resolveWebArtifact(
  ConfigResult configResult,
  BuildInput input,
  void Function(Uri uri) addDependency,
) async {
  final config = configResult.config;
  var type = config['type']?.toString() ?? 'base';
  if (type == 'streaming') type = 'video';
  if (type == 'debug') type = 'debug';
  if (!_validTypes.contains(type)) {
    throw _exception('Invalid bundle type: $type');
  }

  final gpl = config['gpl'] == true;
  final small = config['small'] == true;
  final cacheDir = Directory(
    p.fromUri(input.outputDirectoryShared.resolve('ffmpeg_kit_cache/wasm/')),
  )..createSync(recursive: true);
  final overrideUrl = config['web']?.toString() ?? config['wasm']?.toString();
  validateLocalArtifactSelection(
    platformName: 'Web',
    overrideValue: overrideUrl,
    localOnly: isLocalArtifactOnlyEnabled(),
  );

  String filename;
  String url;
  if (overrideUrl != null) {
    final overrideUri = parseRemoteOverride(overrideUrl);
    if (overrideUri == null) {
      final localPath = p.isAbsolute(overrideUrl)
          ? overrideUrl
          : p.join(configResult.configBaseDir, overrideUrl);
      final localType = FileSystemEntity.typeSync(
        localPath,
        followLinks: false,
      );
      final localDirectory = resolveLocalWebDirectory(
        overridePath: overrideUrl,
        configBaseDir: configResult.configBaseDir,
      );
      if (localDirectory != null) return localDirectory;
      if (localType != FileSystemEntityType.file &&
          localType != FileSystemEntityType.notFound) {
        throw _exception(
          'Local Web override must be a file or directory: $localPath',
        );
      }
      final target = await resolveLocalOverrideToCache(
        overridePath: overrideUrl,
        configBaseDir: configResult.configBaseDir,
        cacheDir: cacheDir,
        addDependency: addDependency,
      );
      final artifact = await _handleDownloadedFile(
        target,
        cacheDir,
        input,
        useExtractionRoot: true,
      );
      return _webRuntimeSourceFromArtifact(artifact);
    }
    final target = await resolveRemoteOverrideToCache(
      overrideUrl: overrideUri.toString(),
      cacheDir: cacheDir,
    );
    final artifact = await _handleDownloadedFile(
      target,
      cacheDir,
      input,
      useExtractionRoot: true,
    );
    return _webRuntimeSourceFromArtifact(artifact);
  } else {
    final currentType = type == 'debug' ? 'base' : type;
    final parts = [
      'bundle',
      currentType,
      _wasmPlatformName,
      _wasmArchitectureName,
      'static',
    ];
    if (type == 'debug') {
      parts.add('debug');
    }
    if (small) {
      parts.add('small');
    }
    parts.add(gpl ? 'gpl' : 'lgpl');
    filename = '${parts.join('-')}.zip';
    url = '$_baseUrlTemplate/v$version-wasm/$filename';
  }

  final targetFile = File(p.join(cacheDir.path, filename));
  if (!targetFile.existsSync()) {
    _log('Downloading $url...');
    if (!await _downloadFile(url, targetFile)) {
      throw _exception('Failed to download WASM bundle from $url');
    }
  }
  _log('Verifying SHA256 hash from $url');
  final expectedHash = await _fetchSha256Hash(
    url,
    platformName: _wasmPlatformName,
  );
  if (expectedHash == null) {
    _log('No SHA256 hash found for $url; skipping verification');
  } else {
    final actualHash = await _computeFileSha256(targetFile);
    if (actualHash == null) {
      _log(
        'Failed to compute SHA256 hash for $targetFile; skipping verification',
      );
    } else if (actualHash != expectedHash) {
      deleteCorruptArtifact(targetFile, log: _log);
      throw _exception(
        'SHA256 hash mismatch: expected $expectedHash, got $actualHash',
      );
    }
    _log('SHA256 verification passed');
  }
  final artifact = await _handleDownloadedFile(
    targetFile,
    cacheDir,
    input,
    useExtractionRoot: true,
  );
  return _webRuntimeSourceFromArtifact(artifact);
}

WebRuntimeSource _webRuntimeSourceFromArtifact(FFmpegArtifact artifact) {
  final searchRoot = artifact.extractedDir;
  if (searchRoot == null || !searchRoot.existsSync()) {
    throw _exception('Could not find extracted WASM bundle for web build');
  }
  return WebRuntimeSource(searchRoot: searchRoot);
}

ConfigResult _loadConfig(BuildInput input, BuildOutputBuilder output) {
  final packageRoot = p.normalize(input.packageRoot.toFilePath());
  _log('input.packageRoot: $packageRoot');
  _log('Platform.packageConfig: ${Platform.packageConfig}');

  final userDefinesResult = resolveUserDefines(
    read: (key) => input.userDefines[key],
    readPath: (key) => input.userDefines.path(key),
    readBase: (key) => input.userDefines.baseUri([key]),
    packageRoot: packageRoot,
    addDependency: output.dependencies.add,
    log: _log,
  );
  final result = selectConfigSource(
    userDefines: userDefinesResult,
    legacy: () => resolveConfig(
      packageName: input.packageName,
      packageRoot: packageRoot,
      packageConfig: Platform.packageConfig,
      readPubspec: _readPubspec,
      log: _log,
      addDependency: output.dependencies.add,
    ),
  );
  _log('Configuration source: ${result.source}');
  return result;
}

PubspecData? _readPubspec(File file) {
  try {
    final content = file.readAsStringSync();
    final doc = loadYaml(content);
    if (doc is! YamlMap) return null;
    return PubspecData(
      config: doc['ffmpeg_kit_extended_config'],
      isWorkspace: doc.containsKey('workspace'),
    );
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

class WebRuntimeSource {
  final Directory searchRoot;
  final List<Uri> dependencies;

  const WebRuntimeSource({
    required this.searchRoot,
    this.dependencies = const <Uri>[],
  });
}

class AppleRuntimeLayout {
  final File frameworkBinary;
  final List<File> companionLibraries;

  AppleRuntimeLayout({
    required this.frameworkBinary,
    required this.companionLibraries,
  });
}

@visibleForTesting
File tempDownloadFileFor(File target) => File('${target.path}.downloading');

@visibleForTesting
Directory extractRootFor(File file, Directory cacheDir) =>
    Directory(p.join(cacheDir.path, p.basenameWithoutExtension(file.path)));

@visibleForTesting
File extractCompletionMarkerFor(Directory extractRoot) =>
    File(p.join(extractRoot.path, _extractMarkerFileName));

@visibleForTesting
void cleanupStaleDownload(File target, {void Function(String message)? log}) {
  final tempTarget = tempDownloadFileFor(target);
  if (tempTarget.existsSync()) {
    log?.call('Removing stale partial download ${tempTarget.path}');
    tempTarget.deleteSync();
  }
}

@visibleForTesting
void deleteIfExists(FileSystemEntity entity) {
  if (entity.existsSync()) {
    entity.deleteSync(recursive: true);
  }
}

@visibleForTesting
void deleteCorruptArtifact(
  File targetFile, {
  void Function(String message)? log,
}) {
  if (targetFile.existsSync()) {
    log?.call('Deleting corrupt artifact ${targetFile.path}');
    targetFile.deleteSync();
  }
}

@visibleForTesting
Future<Directory> prepareExtractedArtifact(
  File file,
  Directory cacheDir,
  Future<bool> Function(File zipFile, String destPath) extractFile,
) async {
  final extractRoot = extractRootFor(file, cacheDir);
  final marker = extractCompletionMarkerFor(extractRoot);
  final hasPayload =
      extractRoot.existsSync() &&
      extractRoot.listSync().any(
        (entity) => p.basename(entity.path) != _extractMarkerFileName,
      );

  final hasCompletedExtract =
      extractRoot.existsSync() && marker.existsSync() && hasPayload;
  if (hasCompletedExtract) {
    return extractRoot;
  }

  if (extractRoot.existsSync()) {
    deleteIfExists(extractRoot);
  }

  final tempExtractRoot = Directory('${extractRoot.path}.extracting');
  deleteIfExists(tempExtractRoot);
  tempExtractRoot.createSync(recursive: true);

  try {
    final extracted = await extractFile(file, tempExtractRoot.path);
    if (!extracted) {
      throw _exception('Failed to extract ${file.path}');
    }

    File(p.join(tempExtractRoot.path, _extractMarkerFileName)).createSync();
    tempExtractRoot.renameSync(extractRoot.path);
    return extractRoot;
  } catch (_) {
    deleteIfExists(tempExtractRoot);
    rethrow;
  }
}

Future<FFmpegArtifact?> _resolveArtifact(
  ConfigResult configResult,
  BuildInput input,
  void Function(Uri uri) addDependency,
) async {
  final config = configResult.config;
  String type = config['type']?.toString() ?? "base";
  if (type == "streaming") type = "video";
  if (type == "full") {
    _log(
      "Full bundle is a heavyweight package and may increase your app size significantly. "
      "Please review all included libraries to make sure you need all bundled features. "
      "Bundle content: https://github.com/akashskypatel/ffmpeg-kit-extended#supported-external-libraries "
      "If you don't need all the libraries included in full bundle, consider using other bundles for smaller app sizes.",
    );
  }
  if (!_validTypes.contains(type)) {
    _log(
      'Invalid bundle type: $type. Valid types are: ${_validTypes.join(', ')}',
    );
    exit(1);
  }

  final bool gpl = config['gpl'] == true;
  final bool small = config['small'] == true;
  _log('Bundle: ${configDiagnosticSummary(config)}');
  final platformName = targetOS.name; // Use .name for stable keys
  final overrideUrl = config[platformName]?.toString();
  validateLocalArtifactSelection(
    platformName: platformName,
    overrideValue: overrideUrl,
    localOnly: isLocalArtifactOnlyEnabled(),
  );

  final cacheDir = Directory(
    p.fromUri(
      input.outputDirectoryShared.resolve('ffmpeg_kit_cache/$platformName/'),
    ),
  );
  if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);
  _log('Artifact cache: ${cacheDir.path}');

  String filename = '';
  String url = '';

  if (overrideUrl != null) {
    final overrideUri = parseRemoteOverride(overrideUrl);
    if (overrideUri != null) {
      _log('Artifact: remote override $overrideUrl');
      final targetFile = await resolveRemoteOverrideToCache(
        overrideUrl: overrideUri.toString(),
        cacheDir: cacheDir,
      );
      return await _handleDownloadedFile(
        targetFile,
        cacheDir,
        input,
        requireAppleFramework: targetOS == OS.iOS || targetOS == OS.macOS,
      );
    } else {
      _log('Artifact: local override $overrideUrl');
      final cacheFile = await resolveLocalOverrideToCache(
        overridePath: overrideUrl,
        configBaseDir: configResult.configBaseDir,
        cacheDir: cacheDir,
        addDependency: addDependency,
      );
      return await _handleDownloadedFile(
        cacheFile,
        cacheDir,
        input,
        requireAppleFramework: targetOS == OS.iOS || targetOS == OS.macOS,
      );
    }
  } else {
    final license = gpl ? 'gpl' : 'lgpl';
    final currentType = type == 'debug' ? 'base' : type;

    if (targetOS == OS.android) {
      final parts = ['bundle', currentType, 'shared'];
      if (type == 'debug') {
        parts.add('debug');
      } else if (small) {
        parts.add('small');
      }
      parts.add(license);
      final artifactId = parts.join('-');
      filename = "$artifactId-release.aar";
      final tag = "v$version-$platformName";
      url = "$_baseUrlTemplate/$tag/$filename";
    } else if (targetOS == OS.iOS || targetOS == OS.macOS) {
      final parts = ['bundle', currentType, platformName, 'universal'];
      if (type == 'debug') {
        parts.add('debug');
      } else if (small) {
        parts.add('small');
      }
      parts.add(license);
      filename = "${parts.join('-')}.xcframework.zip";
      final tag = "v$version-$platformName";
      url = "$_baseUrlTemplate/$tag/$filename";
    } else {
      // Windows, Linux
      final archStr = desktopArtifactArchitecture(
        targetArch,
        platform: targetOS.name,
      );
      final parts = ['bundle', currentType, platformName, archStr, 'shared'];
      if (type == 'debug') {
        parts.add('debug');
      } else if (small) {
        parts.add('small');
      }
      parts.add(license);
      filename = "${parts.join('-')}.zip";
      final tag = "v$version-$platformName";
      url = "$_baseUrlTemplate/$tag/$filename";
    }
  }

  _log('Artifact: $url');
  final targetFile = File(p.join(cacheDir.path, filename));
  if (!targetFile.existsSync()) {
    _log('Downloading $url...');
    if (!await _downloadFile(url, targetFile)) {
      throw _exception(
        'Failed to download from $url. If you are using official bundles, please upgrade your package version immediately and run `flutter clean` then re-build to download updated binaries.',
      );
    }
  }

  _log('Verifying SHA256 hash from $url');

  final expectedHash = await _fetchSha256Hash(url);
  if (expectedHash == null) {
    _log('No SHA256 hash found for $url; skipping verification');
  } else {
    final calculatedHash = await _computeFileSha256(targetFile);
    if (calculatedHash == null) {
      _log(
        'Failed to compute SHA256 hash for $targetFile; skipping verification',
      );
    } else if (expectedHash != calculatedHash) {
      deleteCorruptArtifact(targetFile, log: _log);
      throw _exception(
        'SHA256 hash mismatch: expected $expectedHash, got $calculatedHash',
      );
    }
    _log('SHA256 verification passed');
  }

  return _handleDownloadedFile(
    targetFile,
    cacheDir,
    input,
    requireAppleFramework: targetOS == OS.iOS || targetOS == OS.macOS,
  );
}

Future<FFmpegArtifact> _handleDownloadedFile(
  File file,
  Directory cacheDir,
  BuildInput input, {
  bool useExtractionRoot = false,
  bool requireAppleFramework = false,
}) async {
  if (file.path.endsWith('.aar')) {
    return FFmpegArtifact(file: file, isAar: true);
  }

  final extractRoot = await prepareExtractedArtifact(
    file,
    cacheDir,
    _extractFile,
  );
  final finalExtractedDir = requireAppleFramework
      ? selectAppleXcframeworkRoot(extractRoot)
      : extractRoot.listSync().whereType<Directory>().firstWhere(
          (d) => p.basename(d.path).endsWith('.xcframework'),
          orElse: () => Directory(
            p.join(extractRoot.path, p.basename(extractRoot.path)),
          ), // flat zip fallback
        );
  return FFmpegArtifact(
    file: file,
    extractedDir: useExtractionRoot ? extractRoot : finalExtractedDir,
  );
}

Future<void> _emitAssets(
  FFmpegArtifact artifact,
  BuildInput input,
  BuildOutputBuilder output,
) async {
  final packageName = input.packageName;

  if (targetOS == OS.android) {
    // Extract AAR to get .so files for the target architecture
    final tempDir = Directory(
      p.fromUri(input.outputDirectory.resolve('aar_extract/')),
    );
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync(recursive: true);

    if (await _extractFile(artifact.file, tempDir.path)) {
      _log('Extracted ${artifact.file.path} to ${tempDir.path}');
    } else {
      throw _exception('Failed to extract ${artifact.file.path}');
    }
    output.dependencies.add(artifact.file.uri);
    // Find jniLibs
    final jniDir = Directory(p.join(tempDir.path, 'jni'));
    if (!jniDir.existsSync()) {
      throw _exception('Could not find jni directory in AAR');
    }

    final abi = _getAndroidAbi();
    final abiDir = Directory(p.join(jniDir.path, abi));
    if (!abiDir.existsSync()) {
      throw _exception('Could not find ABI directory $abi in AAR');
    }

    // Find all .so files
    final soFiles =
        abiDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.contains('.so'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    // Identify the main ffmpegkit library and companion libraries
    final mainLibrary = selectExactMainLibrary(
      soFiles,
      expectedBasename: 'libffmpegkit.so',
      platform: 'Android ABI $abi',
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
  } else if (targetOS == OS.iOS || targetOS == OS.macOS) {
    final runtimeLayout = await _buildAppleRuntimeFramework(
      artifact: artifact,
      input: input,
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
            .where((file) => file.path.contains(ext))
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

    final expectedMainName = targetOS == OS.windows
        ? 'libffmpegkit.dll'
        : 'libffmpegkit.so';
    final mainLibrary = selectExactMainLibrary(
      uniqueLibFiles,
      expectedBasename: expectedMainName,
      platform: targetOS == OS.windows ? 'Windows' : 'Linux',
    );

    // Add the main library
    output.assets.code.add(
      CodeAsset(
        package: packageName,
        // Keep this stable across physical filenames such as
        // libffmpegkit.dll/libffmpegkit.so. It must match DefaultAsset in the
        // generated Dart bindings and ffigen.yaml.
        name: 'ffmpegkit',
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
          if (assetName.contains('.so')) {
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
}) async {
  final libDir = artifact.extractedDir!;
  final archStr = _getAppleArch();

  // Determine if we need a simulator or device slice.
  // For iOS, check the target SDK to disambiguate between
  // e.g. ios-arm64 and ios-arm64-simulator.
  final bool wantsSimulator =
      targetOS == OS.iOS &&
      input.config.code.iOS.targetSdk == IOSSdk.iPhoneSimulator;

  final request = AppleSliceRequest(
    platform: targetOS == OS.iOS ? 'ios' : 'macos',
    variant: wantsSimulator ? 'simulator' : null,
    architecture: archStr,
  );
  final xcframeworkInfoPlist = File(p.join(libDir.path, 'Info.plist'));
  final candidates = xcframeworkInfoPlist.existsSync()
      ? readAppleSliceCandidates(xcframeworkInfoPlist)
      : filenameAppleSliceCandidates(
          libDir,
          platform: request.platform,
          variant: request.variant,
        );
  final selectedSlice = selectAppleSlice(candidates, request);

  if (selectedSlice == null) {
    throw _exception(
      appleSliceSelectionFailureMessage(
        request: request,
        root: libDir.path,
        candidates: candidates,
      ),
    );
  }
  final sliceDir = Directory(p.join(libDir.path, selectedSlice.identifier));
  _log(
    'XCFramework slice: ${selectedSlice.identifier} '
    '(${selectedSlice.architectures.toList()..sort()})',
  );
  final libraryEntry = File(p.join(sliceDir.path, selectedSlice.libraryPath));
  final libraryRoot = Directory(libraryEntry.path);
  final sourceFrameworkBinary = libraryRoot.existsSync()
      ? File(p.join(libraryRoot.path, 'ffmpegkit'))
      : libraryEntry;

  final sourceDylibs =
      sliceDir
          .listSync(followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dylib'))
          .where((f) => !FileSystemEntity.isLinkSync(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final sourceMainDylib = sourceFrameworkBinary.existsSync()
      ? sourceFrameworkBinary
      : sourceDylibs.firstWhere(
          (f) => p.basename(f.path) == 'libffmpegkit.dylib',
          orElse: () {
            throw _exception(
              'ffmpegkit.framework/ffmpegkit or libffmpegkit.dylib not found in ${sliceDir.path}',
            );
          },
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

  final frameworkVerification = await _thinOrCopyAppleBinary(
    source: sourceMainDylib,
    destination: frameworkBinary,
    archStr: archStr,
    diagnosticContext: _appleDiagnosticContext(input),
  );
  _log(
    'Source architectures: '
    '${frameworkVerification.sourceArchitectures.toList()..sort()}; '
    'Output architecture: '
    '${frameworkVerification.outputArchitectures.toList()..sort()}',
  );

  final companionLibraries = <File>[];
  for (final dylib in sourceDylibs) {
    if (dylib.path == sourceMainDylib.path) continue;
    final destination = File(p.join(companionDir.path, p.basename(dylib.path)));
    final companionVerification = await _thinOrCopyAppleBinary(
      source: dylib,
      destination: destination,
      archStr: archStr,
      diagnosticContext: _appleDiagnosticContext(input),
    );
    _log(
      'Companion ${p.basename(dylib.path)} source architectures: '
      '${companionVerification.sourceArchitectures.toList()..sort()}; '
      'output architecture: '
      '${companionVerification.outputArchitectures.toList()..sort()}',
    );
    companionLibraries.add(destination);
  }

  final sourceHeadersDir = sourceFrameworkBinary.existsSync()
      ? Directory(p.join(libraryRoot.path, 'Headers'))
      : Directory(p.join(sliceDir.path, 'Headers'));
  if (sourceHeadersDir.existsSync()) {
    await _copyDirectory(sourceHeadersDir, headersDir);
  }

  final infoPlist = File(p.join(resourcesDir.path, 'Info.plist'));
  infoPlist.writeAsStringSync(
    _appleFrameworkInfoPlist(simulator: wantsSimulator),
  );

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

Future<AppleBinaryVerification> _thinOrCopyAppleBinary({
  required File source,
  required File destination,
  required String archStr,
  required String diagnosticContext,
}) async {
  destination.parent.createSync(recursive: true);
  _log('Preparing ${p.basename(source.path)} for $archStr...');
  return materializeAppleBinary(
    source: source,
    destination: destination,
    architecture: archStr,
    diagnosticContext: diagnosticContext,
  );
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

String _appleFrameworkInfoPlist({required bool simulator}) {
  final platform = appleFrameworkSupportedPlatform(
    macOS: targetOS == OS.macOS,
    simulator: simulator,
  );
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

String _getAndroidAbi() => androidAbiForArchitecture(targetArch);

String _getAppleArch() => appleArtifactArchitecture(targetArch);

String _appleDiagnosticContext(BuildInput input) {
  final sdk = targetOS == OS.iOS
      ? input.config.code.iOS.targetSdk.type
      : 'macOS';
  return 'Target: ${targetOS.name}-${targetArch.name}; SDK: $sdk';
}

String _buildHookSdk(BuildInput input) =>
    targetOS == OS.iOS ? input.config.code.iOS.targetSdk.type : targetOS.name;

Future<bool> _downloadFile(String url, File target) async {
  final client = HttpClient();
  cleanupStaleDownload(target, log: _log);
  final tempTarget = tempDownloadFileFor(target);
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode == 200) {
      await response.pipe(tempTarget.openWrite());
      tempTarget.renameSync(target.path);
      return true;
    }
    await response.drain<void>();
    return false;
  } catch (e) {
    // Clean up partial download
    if (tempTarget.existsSync()) tempTarget.deleteSync();
    rethrow;
  } finally {
    client.close();
  }
}

const String windowsArchiveExtractionScript = r'''
$ErrorActionPreference = 'Stop'
Expand-Archive -LiteralPath $env:FFMPEG_KIT_ARCHIVE -DestinationPath $env:FFMPEG_KIT_DESTINATION -Force
''';

@visibleForTesting
class WindowsArchiveExtractionInvocation {
  final List<String> arguments;
  final Map<String, String> environment;

  WindowsArchiveExtractionInvocation({
    required this.arguments,
    required Map<String, String> environment,
  }) : environment = Map.unmodifiable(environment);
}

@visibleForTesting
WindowsArchiveExtractionInvocation buildWindowsArchiveExtractionInvocation(
  String archivePath,
  String destinationPath,
) => WindowsArchiveExtractionInvocation(
  arguments: const [
    '-NoProfile',
    '-NonInteractive',
    '-Command',
    windowsArchiveExtractionScript,
  ],
  environment: {
    'FFMPEG_KIT_ARCHIVE': archivePath,
    'FFMPEG_KIT_DESTINATION': destinationPath,
  },
);

Future<bool> _extractFile(File zipFile, String destPath) async {
  File? tempZipFile;
  try {
    if (Platform.isWindows) {
      final fileExt = zipFile.path.split('.').last.toLowerCase();
      if (fileExt == "aar") {
        //create temp renamed files with .aar replaced with .zip extension
        tempZipFile = zipFile.copySync(
          zipFile.path.replaceFirst('.$fileExt', '.zip'),
        );
        zipFile = tempZipFile;
      }
      final invocation = buildWindowsArchiveExtractionInvocation(
        zipFile.path,
        destPath,
      );
      final res = await Process.run(
        'powershell',
        invocation.arguments,
        environment: invocation.environment,
        includeParentEnvironment: true,
      );
      if (res.exitCode != 0) {
        _log(
          'PowerShell Expand-Archive failed for ${zipFile.path} '
          'to $destPath',
        );
        _log('Error: ${res.stderr}');
      }
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
        if (res2.exitCode != 0) {
          _log('Command: tar -xf ${zipFile.path} -C $destPath');
          _log('Failed to extract ${zipFile.path}');
          _log('Error: ${res2.stderr}');
        }
        return res2.exitCode == 0;
      }
      return true;
    }
  } catch (e) {
    return false;
  } finally {
    tempZipFile?.deleteSync();
  }
}

@visibleForTesting
Uri? parseRemoteOverride(String value) {
  if (!isUriLikeOverride(value)) return null;

  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) {
    throw _exception('Invalid remote override URI: $value');
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    throw _exception(
      'Unsupported remote override scheme "$scheme"; '
      'only http:// and https:// are supported',
    );
  }
  if (uri.host.isEmpty) {
    throw _exception('Remote override URI must include a host: $value');
  }
  return uri;
}

@visibleForTesting
void validateLocalArtifactSelection({
  required String platformName,
  required String? overrideValue,
  required bool localOnly,
}) {
  if (!localOnly) return;
  if (overrideValue == null || overrideValue.trim().isEmpty) {
    throw _exception(
      'Local-only artifact validation for $platformName requires an explicit '
      'local bundle override; default and remote resolution are disabled.',
    );
  }
  final remote = parseRemoteOverride(overrideValue);
  if (remote != null) {
    throw _exception(
      'Local-only artifact validation for $platformName rejects remote '
      'bundle overrides (${remote.scheme}); configure a local filesystem '
      'bundle instead.',
    );
  }
}

String _remoteCacheIdentity(Uri uri) =>
    sha256.convert(utf8.encode(uri.toString())).toString().substring(0, 16);

@visibleForTesting
File remoteCacheFileFor(Uri uri, Directory cacheDir) {
  var basename = p.posix.basename(uri.path);
  if (basename.isEmpty || basename == '.' || basename == '..') {
    basename = 'artifact';
  }
  basename = basename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  return File(p.join(cacheDir.path, '${_remoteCacheIdentity(uri)}-$basename'));
}

typedef RemoteOverrideDownloader = Future<bool> Function(Uri uri, File target);

@visibleForTesting
Future<bool> syncRemoteOverrideToCache({
  required Uri uri,
  required File cacheFile,
  required Directory cacheDir,
  RemoteOverrideDownloader? download,
}) async {
  cacheDir.createSync(recursive: true);
  final tempFile = File('${cacheFile.path}.refreshing');
  deleteIfExists(tempFile);
  cleanupStaleDownload(tempFile);
  try {
    final downloaded = await (download ?? _downloadRemoteOverride)(
      uri,
      tempFile,
    );
    if (!downloaded) {
      throw _exception('Failed to download remote override from $uri');
    }

    final downloadedHash = await _computeFileSha256(tempFile);
    if (downloadedHash == null) {
      throw _exception('Unable to hash downloaded remote override from $uri');
    }
    final cachedHash = cacheFile.existsSync()
        ? await _computeFileSha256(cacheFile)
        : null;
    if (downloadedHash == cachedHash) return false;

    cacheFile.parent.createSync(recursive: true);
    if (cacheFile.existsSync()) cacheFile.deleteSync();
    tempFile.renameSync(cacheFile.path);
    deleteIfExists(extractRootFor(cacheFile, cacheDir));
    return true;
  } finally {
    deleteIfExists(tempFile);
    cleanupStaleDownload(tempFile);
  }
}

Future<bool> _downloadRemoteOverride(Uri uri, File target) =>
    _downloadFile(uri.toString(), target);

@visibleForTesting
Future<File> resolveRemoteOverrideToCache({
  required String overrideUrl,
  required Directory cacheDir,
  RemoteOverrideDownloader? download,
}) async {
  final uri = parseRemoteOverride(overrideUrl);
  if (uri == null) {
    throw _exception('Expected an HTTP(S) remote override: $overrideUrl');
  }
  final cacheFile = remoteCacheFileFor(uri, cacheDir);
  await syncRemoteOverrideToCache(
    uri: uri,
    cacheFile: cacheFile,
    cacheDir: cacheDir,
    download: download,
  );
  return cacheFile;
}

Future<String?> _fetchSha256Hash(String url, {String? platformName}) async {
  final client = HttpClient();
  try {
    // if github, use github api to get the file hash
    // https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/releases/${id}
    // https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/releases/${id}
    // https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/releases/tags/${tag}
    final tag = "v$version-${platformName ?? targetOS.name}";
    final releaseName = p.basename(url);
    final request = await client.getUrl(
      Uri.parse(
        'https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/releases/tags/$tag',
      ),
    );
    final response = await request.close();
    if (response.statusCode == 200) {
      //parse json response to extract asset url
      final content = await response.transform(utf8.decoder).join();
      final json = jsonDecode(content);
      final assets = json['assets'] as List;
      for (final asset in assets) {
        if (asset['name'] == releaseName) {
          final digest = asset['digest'] as String?;
          if (digest == null || digest.isEmpty) {
            return null;
          }
          // parse 'sha256:...' format
          final parts = digest.split(':');
          if (parts.length == 2) {
            return parts[1].toLowerCase();
          }
          return digest.toLowerCase();
        }
      }
    } else {
      await response.drain<void>();
    }
    return null;
  } catch (e) {
    return null;
  } finally {
    client.close();
  }
}

Future<String?> _computeFileSha256(File file) async {
  try {
    final stream = file.openRead();
    final hash = await sha256.bind(stream).first;
    return hash.toString();
  } catch (e) {
    return null;
  }
}

@visibleForTesting
Future<bool> syncLocalOverride(File source, File destination) async {
  final sourceHash = await _computeFileSha256(source);
  if (sourceHash == null) {
    throw _exception('Unable to read local override: ${source.path}');
  }

  final destinationHash = destination.existsSync()
      ? await _computeFileSha256(destination)
      : null;
  if (sourceHash == destinationHash) return false;

  destination.parent.createSync(recursive: true);
  await source.copy(destination.path);
  return true;
}

@visibleForTesting
Future<File> resolveLocalOverrideToCache({
  required String overridePath,
  required String configBaseDir,
  required Directory cacheDir,
  required void Function(Uri uri) addDependency,
}) async {
  final localFile = p.isAbsolute(overridePath)
      ? File(overridePath)
      : File(p.join(configBaseDir, overridePath));
  if (!localFile.existsSync()) {
    throw _exception('Local override not found: ${localFile.path}');
  }

  addDependency(localFile.uri);
  final cacheFile = File(p.join(cacheDir.path, p.basename(localFile.path)));
  final changed = await syncLocalOverride(localFile, cacheFile);
  if (changed) {
    deleteIfExists(extractRootFor(cacheFile, cacheDir));
  }
  return cacheFile;
}
