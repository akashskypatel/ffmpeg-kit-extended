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

  const ConfigResult(this.config, this.configBaseDir, this.stagingBaseDir);
}

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

    // 1. Prefer configuration from the package-config/workspace root.
    if (rootPubspecData?.config != null) {
      log('Using configuration from ${rootPubspec.path}');
      return ConfigResult(
        rootPubspecData!.config,
        configRoot,
        rootPubspecData.isWorkspace ? null : normalizedStagingBaseDir,
      );
    }

    // 2. If the root has no configuration, inspect package roots contained
    // in it. A unique candidate is required before selecting its configuration.
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

    if (candidates.length == 1) {
      final candidate = candidates.single;
      log(
        'Using in-workspace package configuration from '
        '${candidate.pubspec.path}',
      );
      return ConfigResult(
        candidate.config,
        p.dirname(candidate.pubspec.path),
        p.dirname(candidate.pubspec.path),
      );
    }
    if (candidates.length > 1) {
      final paths = candidates
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

    if (rootPubspecData != null) {
      if (workspaceRootDetected) {
        log(
          'Warning: Dart Pub Workspace detected at $configRoot, but no '
          'unique in-workspace package defines ffmpeg_kit_extended_config. '
          'Place one configuration in an in-workspace package or in '
          '${rootPubspec.path}. Falling back to the default "base" LGPL '
          'small build.',
        );
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
