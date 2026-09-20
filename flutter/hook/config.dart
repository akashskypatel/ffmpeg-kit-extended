import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class PubspecData {
  final dynamic config;
  final bool isWorkspace;

  const PubspecData({this.config, this.isWorkspace = false});
}

class ConfigResult {
  final dynamic config;
  final String configBaseDir;
  final String? stagingBaseDir;
  final String source;

  const ConfigResult(
    this.config,
    this.configBaseDir,
    this.stagingBaseDir, {
    this.source = 'legacy ffmpeg_kit_extended_config',
  });
}

String configDiagnosticSummary(dynamic config) {
  final type = config['type']?.toString() ?? 'base';
  final license = config['gpl'] == true ? 'GPL' : 'LGPL';
  final small = config['small'] == true;
  return '$type / $license / small=$small';
}

typedef UserDefineReader = Object? Function(String key);
typedef UserDefinePathReader = Uri? Function(String key);
typedef UserDefineBaseReader = Uri? Function(String key);

const _userDefineKeys = <String>[
  'type',
  'gpl',
  'small',
  'android',
  'ios',
  'macos',
  'linux',
  'windows',
  'web',
  'wasm',
];

ConfigResult? resolveUserDefines({
  required UserDefineReader read,
  required UserDefinePathReader readPath,
  required UserDefineBaseReader readBase,
  required String packageRoot,
  required String? stagingBaseDir,
  required void Function(Uri uri) addDependency,
  required void Function(String message) log,
}) {
  final nested = read('config');
  final config = <String, Object?>{};
  Uri? configBaseUri;

  for (final key in _userDefineKeys) {
    final directValue = read(key);
    final hasDirectValue = directValue != null;
    final hasNestedValue = nested is Map && nested.containsKey(key);
    if (!hasDirectValue && !hasNestedValue) continue;

    final value = hasDirectValue ? directValue : (nested as Map)[key];
    if (value == null) continue;
    _validateUserDefine(key, value);
    config[key] = value;
    configBaseUri ??= readBase(key);

    if (_isPlatformOverrideKey(key) &&
        value is String &&
        !_looksLikeRemoteUri(value)) {
      final resolvedPath = readPath(key);
      if (resolvedPath != null) {
        config[key] = File.fromUri(resolvedPath).path;
        addDependency(resolvedPath);
      }
    }
  }

  if (config.isEmpty) return null;
  final configBaseDir = configBaseUri == null
      ? p.normalize(packageRoot)
      : p.normalize(Directory.fromUri(configBaseUri).path);
  log('Using configuration from hooks.user_defines');
  return ConfigResult(
    config,
    configBaseDir,
    stagingBaseDir,
    source: 'hooks.user_defines',
  );
}

ConfigResult selectConfigSource({
  required ConfigResult? userDefines,
  required ConfigResult Function() legacy,
}) => userDefines ?? legacy();

void _validateUserDefine(String key, Object value) {
  if (key == 'type' && value is! String) {
    throw ConfigResolutionException(
      'hooks.user_defines.$key must be a string, got ${value.runtimeType}',
    );
  }
  if ((key == 'gpl' || key == 'small') && value is! bool) {
    throw ConfigResolutionException(
      'hooks.user_defines.$key must be a boolean, got ${value.runtimeType}',
    );
  }
  if (_isPlatformOverrideKey(key) && value is! String) {
    throw ConfigResolutionException(
      'hooks.user_defines.$key must be a string path or URL, '
      'got ${value.runtimeType}',
    );
  }
}

bool _isPlatformOverrideKey(String key) => const {
  'android',
  'ios',
  'macos',
  'linux',
  'windows',
  'web',
  'wasm',
}.contains(key);

bool _looksLikeRemoteUri(String value) =>
    RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://').hasMatch(value);

String resolveStagingBaseDir({
  required String outputFile,
  required String fallbackBaseDir,
}) {
  var current = Directory(outputFile).parent;
  while (true) {
    if (p.basename(current.path) == '.dart_tool') {
      return p.normalize(current.parent.path);
    }
    final parent = current.parent;
    if (p.equals(parent.path, current.path)) break;
    current = parent;
  }
  return p.normalize(fallbackBaseDir);
}

typedef PubspecReader = PubspecData? Function(File file);

class ConfigResolutionException implements Exception {
  final String message;

  const ConfigResolutionException(this.message);

  @override
  String toString() => message;
}

ConfigResult resolveConfig({
  required String packageName,
  required String packageRoot,
  required String? packageConfig,
  required PubspecReader readPubspec,
  required void Function(String message) log,
  void Function(Uri uri) addDependency = _ignoreDependency,
  String? stagingBaseDir,
}) {
  final normalizedPackageRoot = p.normalize(packageRoot);
  final normalizedStagingBaseDir = p.normalize(
    stagingBaseDir ?? normalizedPackageRoot,
  );
  var workspaceRootDetected = false;
  if (packageConfig != null) {
    // packageConfig is a file:/// URI pointing to .dart_tool/package_config.json
    final packageConfigUri = Uri.parse(packageConfig);
    final packageConfigPath = p.normalize(File.fromUri(packageConfigUri).path);
    final configRoot = p.dirname(p.dirname(packageConfigPath));
    final rootPubspec = File(p.join(configRoot, 'pubspec.yaml'));
    addDependency(packageConfigUri);
    final rootPubspecData = rootPubspec.existsSync()
        ? _readTrackedPubspec(rootPubspec, readPubspec, addDependency)
        : null;
    workspaceRootDetected = rootPubspecData?.isWorkspace ?? false;
    final packageGraph = _readPackageGraph(
      packageConfigUri.resolve('package_graph.json'),
      log,
      addDependency,
    );

    // 1. Prefer configuration from the package-config/workspace root.
    if (rootPubspecData?.config != null) {
      log('Using configuration from ${rootPubspec.path}');
      return ConfigResult(
        rootPubspecData!.config,
        configRoot,
        rootPubspecData.isWorkspace ? null : normalizedStagingBaseDir,
        source: 'legacy ffmpeg_kit_extended_config',
      );
    }

    // 2. If the root has no configuration, inspect package roots contained
    // in it. Only a workspace root depending on this package may supply the
    // configuration.
    final candidates = <_ConfigCandidate>[];
    for (final package in _readPackageEntries(packageConfigUri, log)) {
      if (package.name == packageName ||
          p.equals(package.root, normalizedPackageRoot)) {
        continue;
      }
      if (!_isWithin(configRoot, package.root)) continue;

      final packagePubspec = File(p.join(package.root, 'pubspec.yaml'));
      if (!packagePubspec.existsSync()) continue;
      final pubspec = _readTrackedPubspec(
        packagePubspec,
        readPubspec,
        addDependency,
      );
      if (pubspec?.config != null) {
        candidates.add(
          _ConfigCandidate(
            packageName: package.name,
            pubspec: packagePubspec,
            config: pubspec!.config,
          ),
        );
      }
    }

    final dependentRootNames = packageGraph?.dependentRootNames(packageName);
    final dependentCandidates = packageGraph == null
        ? candidates
        : candidates
              .where(
                (candidate) =>
                    dependentRootNames!.contains(candidate.packageName),
              )
              .toList();

    if (workspaceRootDetected &&
        dependentRootNames != null &&
        dependentRootNames.length > 1 &&
        dependentCandidates.isNotEmpty) {
      final paths = dependentCandidates
          .map(
            (candidate) =>
                '${candidate.packageName}: ${candidate.pubspec.path}',
          )
          .join('; ');
      final message =
          'Ambiguous FFmpegKit configuration: multiple workspace roots depend '
          'on $packageName, so the hook cannot identify which '
          'package-specific configuration applies. Place a shared '
          'configuration in ${rootPubspec.path} or configure only one '
          'workspace root (${dependentRootNames.join(', ')}): $paths';
      log('Error: $message');
      throw ConfigResolutionException(message);
    }

    if (dependentCandidates.length > 1) {
      final paths = dependentCandidates
          .map(
            (candidate) =>
                '${candidate.packageName}: ${candidate.pubspec.path}',
          )
          .join('; ');
      final message =
          'Ambiguous FFmpegKit configuration: multiple in-workspace packages '
          'define ffmpeg_kit_extended_config. Remove all but one configuration '
          'or place a shared configuration in ${rootPubspec.path}: $paths';
      log('Error: $message');
      throw ConfigResolutionException(message);
    }

    if (packageGraph == null && candidates.isNotEmpty) {
      final message =
          'Unable to determine which package may provide '
          'ffmpeg_kit_extended_config because .dart_tool/package_graph.json '
          'is unavailable. Run `flutter pub get` to rebuild package metadata, '
          'or define a shared configuration in ${rootPubspec.path}.';
      log('Error: $message');
      throw ConfigResolutionException(message);
    }

    if (dependentCandidates.length == 1) {
      final candidate = dependentCandidates.single;
      log(
        'Using dependent in-workspace package configuration from '
        '${candidate.pubspec.path}',
      );
      return ConfigResult(
        candidate.config,
        p.dirname(candidate.pubspec.path),
        p.dirname(candidate.pubspec.path),
        source: 'legacy ffmpeg_kit_extended_config',
      );
    }

    if (candidates.isNotEmpty && packageGraph != null) {
      log(
        'Ignoring configured workspace packages that are not package-graph '
        'roots depending on $packageName. Using the default configuration.',
      );
    }

    if (rootPubspecData != null) {
      if (workspaceRootDetected) {
        if (candidates.isNotEmpty && packageGraph != null) {
          log(
            'Warning: Dart Pub Workspace detected at $configRoot, but no '
            'dependent in-workspace package defines '
            'ffmpeg_kit_extended_config for $packageName. Falling back to '
            'the default "base" '
            'LGPL small build.',
          );
        } else {
          log(
            'Warning: Dart Pub Workspace detected at $configRoot, but no '
            'unique in-workspace package defines ffmpeg_kit_extended_config. '
            'Place one configuration in an in-workspace package or in '
            '${rootPubspec.path}. Falling back to the default "base" LGPL '
            'small build.',
          );
        }
      } else {
        log(
          'Found configuration-root pubspec at ${rootPubspec.path} but no '
          'ffmpeg_kit_extended_config',
        );
      }
    }
  }

  // Preserve the package-local fallback for callers without package metadata.
  // With package_config.json available, the package itself is deliberately
  // excluded from workspace candidates and must not be selected implicitly.
  if (packageConfig == null) {
    final packagePubspec = File(p.join(normalizedPackageRoot, 'pubspec.yaml'));
    if (packagePubspec.existsSync()) {
      final pubspec = _readTrackedPubspec(
        packagePubspec,
        readPubspec,
        addDependency,
      );
      if (pubspec?.config != null) {
        log('Using package-local configuration from ${packagePubspec.path}');
        return ConfigResult(
          pubspec!.config,
          normalizedPackageRoot,
          normalizedStagingBaseDir,
          source: 'legacy ffmpeg_kit_extended_config',
        );
      }
    }
  }

  // Last resort: default configuration.
  if (!workspaceRootDetected) {
    log('No configuration found. Using default "base" LGPL small build.');
  }
  return ConfigResult(
    {'type': 'base', 'gpl': false, 'small': true},
    normalizedPackageRoot,
    workspaceRootDetected ? null : normalizedStagingBaseDir,
    source: 'defaults',
  );
}

PubspecData? _readTrackedPubspec(
  File file,
  PubspecReader readPubspec,
  void Function(Uri uri) addDependency,
) {
  addDependency(file.uri);
  return readPubspec(file);
}

void _ignoreDependency(Uri uri) {}

class _ConfigCandidate {
  final String packageName;
  final File pubspec;
  final dynamic config;

  const _ConfigCandidate({
    required this.packageName,
    required this.pubspec,
    required this.config,
  });
}

class _PackageEntry {
  final String name;
  final String root;

  const _PackageEntry(this.name, this.root);
}

class _PackageGraph {
  final Set<String> roots;
  final Map<String, List<String>> dependencies;

  const _PackageGraph({required this.roots, required this.dependencies});

  List<String> dependentRootNames(String targetName) => [
    for (final root in roots)
      if (dependsOn(root, targetName)) root,
  ];

  bool dependsOn(String rootName, String targetName) {
    final pending = <String>[rootName];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (!visited.add(current)) continue;
      if (current == targetName) return true;
      pending.addAll(dependencies[current] ?? const <String>[]);
    }
    return false;
  }
}

_PackageGraph? _readPackageGraph(
  Uri packageGraphUri,
  void Function(String message) log,
  void Function(Uri uri) addDependency,
) {
  final file = File.fromUri(packageGraphUri);
  if (!file.existsSync()) return null;

  addDependency(packageGraphUri);
  try {
    final document = jsonDecode(file.readAsStringSync());
    if (document is! Map<String, dynamic> || document['configVersion'] != 1) {
      return null;
    }
    final roots = document['roots'];
    final packages = document['packages'];
    if (roots is! List || packages is! List) return null;

    final dependencies = <String, List<String>>{};
    for (final package in packages) {
      if (package is! Map) continue;
      final name = package['name'];
      if (name is! String) continue;
      final packageDependencies = <String>[];
      final values = package['dependencies'];
      if (values is List) {
        packageDependencies.addAll(values.whereType<String>());
      }
      dependencies[name] = packageDependencies;
    }
    return _PackageGraph(
      roots: roots.whereType<String>().toSet(),
      dependencies: dependencies,
    );
  } catch (error) {
    log('Could not read package graph at ${file.path}: $error');
    return null;
  }
}

Iterable<_PackageEntry> _readPackageEntries(
  Uri packageConfigUri,
  void Function(String message) log,
) sync* {
  try {
    final document = jsonDecode(
      File.fromUri(packageConfigUri).readAsStringSync(),
    );
    final packages = document is Map<String, dynamic>
        ? document['packages']
        : null;
    if (packages is! List) return;

    for (final package in packages) {
      if (package is! Map) continue;
      final name = package['name'];
      final rootUri = package['rootUri'];
      if (name is! String || rootUri is! String) continue;
      final resolvedRoot = packageConfigUri.resolve(rootUri);
      if (resolvedRoot.scheme != 'file') continue;
      yield _PackageEntry(name, p.normalize(File.fromUri(resolvedRoot).path));
    }
  } catch (error) {
    log(
      'Could not read package configuration at ${packageConfigUri.path}: $error',
    );
  }
}

bool _isWithin(String parent, String child) =>
    p.equals(parent, child) || p.isWithin(parent, child);
