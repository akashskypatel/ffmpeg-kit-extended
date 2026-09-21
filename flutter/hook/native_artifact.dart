import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:path/path.dart' as p;

String androidAbiForArchitecture(Architecture architecture) {
  switch (architecture) {
    case Architecture.arm:
      return 'armeabi-v7a';
    case Architecture.arm64:
      return 'arm64-v8a';
    case Architecture.ia32:
      return 'x86';
    case Architecture.x64:
      return 'x86_64';
    default:
      throw StateError(
        'Unsupported Android target architecture "${architecture.name}"; '
        'supported architectures: arm, arm64, ia32, x64.',
      );
  }
}

String appleArtifactArchitecture(Architecture architecture) {
  switch (architecture) {
    case Architecture.arm64:
      return 'arm64';
    case Architecture.x64:
      return 'x86_64';
    default:
      throw StateError(
        'Unsupported Apple target architecture "${architecture.name}"; '
        'supported architectures: arm64, x64.',
      );
  }
}

String desktopArtifactArchitecture(
  Architecture architecture, {
  required String platform,
}) {
  switch (architecture) {
    case Architecture.arm64:
      return 'arm64';
    case Architecture.x64:
      return 'x86_64';
    default:
      throw StateError(
        'Unsupported $platform target architecture "${architecture.name}"; '
        'supported architectures: arm64, x64.',
      );
  }
}

void validateTargetArchitecture(OS targetOS, Architecture architecture) {
  switch (targetOS) {
    case OS.android:
      androidAbiForArchitecture(architecture);
    case OS.iOS:
    case OS.macOS:
      appleArtifactArchitecture(architecture);
    case OS.linux:
    case OS.windows:
      desktopArtifactArchitecture(architecture, platform: targetOS.name);
    default:
      throw StateError(
        'Unsupported target OS "${targetOS.name}"; supported target OSes: '
        'android, iOS, linux, macOS, windows.',
      );
  }
}

File selectExactMainLibrary(
  Iterable<File> candidates, {
  required String expectedBasename,
  required String platform,
}) {
  final matches =
      _uniqueFiles(
          candidates,
        ).where((file) => p.basename(file.path) == expectedBasename).toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (matches.isEmpty) {
    final available = _uniqueFiles(
      candidates,
    ).map((file) => p.basename(file.path)).toSet().toList()..sort();
    throw StateError(
      '$platform artifact must contain exactly one $expectedBasename; '
      'available files: ${available.isEmpty ? '(none)' : available.join(', ')}',
    );
  }
  if (matches.length > 1) {
    throw StateError(
      '$platform artifact contains multiple $expectedBasename files: '
      '${matches.map((file) => file.path).join(', ')}',
    );
  }
  return matches.single;
}

Directory selectAppleXcframeworkRoot(Directory extractRoot) {
  final nestedCandidates = <Directory>[];
  if (extractRoot.existsSync()) {
    nestedCandidates.addAll(
      extractRoot
          .listSync(recursive: true, followLinks: false)
          .whereType<Directory>()
          .where(
            (directory) => p.basename(directory.path).endsWith('.xcframework'),
          ),
    );
  }
  final candidates = nestedCandidates.isNotEmpty
      ? nestedCandidates
      : <Directory>[
          if (p.basename(extractRoot.path).endsWith('.xcframework'))
            extractRoot,
        ];

  final uniqueCandidates = <String, Directory>{};
  for (final candidate in candidates) {
    uniqueCandidates[p.normalize(candidate.path)] = candidate;
  }
  final orderedCandidates = uniqueCandidates.values.toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (orderedCandidates.isEmpty) {
    throw StateError(
      'Apple artifact must contain exactly one .xcframework root under '
      '${extractRoot.path}; none was found.',
    );
  }
  if (orderedCandidates.length > 1) {
    throw StateError(
      'Apple artifact contains multiple .xcframework roots: '
      '${orderedCandidates.map((directory) => directory.path).join(', ')}',
    );
  }
  return orderedCandidates.single;
}

String appleFrameworkSupportedPlatform({
  required bool macOS,
  required bool simulator,
}) {
  if (macOS) return 'MacOSX';
  return simulator ? 'iPhoneSimulator' : 'iPhoneOS';
}

List<File> _uniqueFiles(Iterable<File> files) {
  final unique = <String, File>{};
  for (final file in files) {
    unique[p.normalize(file.path)] = file;
  }
  return unique.values.toList();
}
