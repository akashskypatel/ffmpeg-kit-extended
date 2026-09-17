import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../hook/config.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('ffmpeg_kit_config_');
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('derives the staging root from the consuming app output path', () {
    final appRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'apps', 'app'),
    );
    final outputFile = p.join(
      appRoot.path,
      '.dart_tool',
      'hooks_runner',
      'ffmpeg_kit_extended_flutter',
      'checksum',
      'output.json',
    );

    expect(
      resolveStagingBaseDir(
        outputFile: outputFile,
        fallbackBaseDir: tempRoot.path,
      ),
      equals(p.normalize(appRoot.path)),
    );
  });

  test('root configuration takes precedence over workspace packages', () {
    final workspaceRoot = _createDirectory(tempRoot, 'workspace');
    final packageRoot = _createDirectory(tempRoot, 'package');
    final memberRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'apps', 'app'),
    );
    _writePubspec(workspaceRoot, '''
name: workspace
workspace:
  - apps/app
ffmpeg_kit_extended_config:
  type: video
''');
    _writePubspec(memberRoot, '''
name: app
ffmpeg_kit_extended_config:
  type: audio
''');
    _writePackageConfig(workspaceRoot, packageRoot, [memberRoot]);

    final result = resolveConfig(
      packageName: 'ffmpeg_kit_extended_flutter',
      packageRoot: packageRoot.path,
      packageConfig: _packageConfigUri(workspaceRoot),
      readPubspec: _readPubspec,
      log: (_) {},
      stagingBaseDir: memberRoot.path,
    );

    expect(result.config['type'], equals('video'));
    expect(result.configBaseDir, equals(workspaceRoot.path));
    expect(result.stagingBaseDir, equals(p.normalize(memberRoot.path)));
  });

  test('selects the only configured workspace package', () {
    final workspaceRoot = _createDirectory(tempRoot, 'workspace');
    final packageRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'packages', 'ffmpeg'),
    );
    final memberRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'apps', 'app'),
    );
    final externalRoot = _createDirectory(
      tempRoot,
      p.join('pub-cache', 'ffmpeg-dependency'),
    );
    _writePubspec(workspaceRoot, '''
name: workspace
workspace:
  - apps/app
''');
    _writePubspec(memberRoot, '''
name: app
ffmpeg_kit_extended_config:
  type: full
  gpl: true
''');
    _writePubspec(externalRoot, '''
name: cached_dependency
ffmpeg_kit_extended_config:
  type: audio
''');
    _writePackageConfig(
      workspaceRoot,
      packageRoot,
      [memberRoot],
      externalPackages: [externalRoot],
    );
    final dependencies = <Uri>[];

    final result = resolveConfig(
      packageName: 'ffmpeg_kit_extended_flutter',
      packageRoot: packageRoot.path,
      packageConfig: _packageConfigUri(workspaceRoot),
      readPubspec: _readPubspec,
      log: (_) {},
      addDependency: dependencies.add,
    );

    expect(result.config['type'], equals('full'));
    expect(result.config['gpl'], isTrue);
    expect(result.configBaseDir, equals(p.normalize(memberRoot.path)));
    expect(
      dependencies.map((uri) => p.normalize(uri.toFilePath())),
      containsAll(<String>[
        p.normalize(
          p.join(workspaceRoot.path, '.dart_tool', 'package_config.json'),
        ),
        p.normalize(p.join(workspaceRoot.path, 'pubspec.yaml')),
        p.normalize(p.join(memberRoot.path, 'pubspec.yaml')),
      ]),
    );
  });

  test('uses defaults when no workspace package is configured', () {
    final workspaceRoot = _createDirectory(tempRoot, 'workspace');
    final packageRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'packages', 'ffmpeg'),
    );
    _writePubspec(workspaceRoot, '''
name: workspace
workspace:
  - apps/app
''');
    _writePackageConfig(workspaceRoot, packageRoot, const []);
    final logs = <String>[];

    final result = resolveConfig(
      packageName: 'ffmpeg_kit_extended_flutter',
      packageRoot: packageRoot.path,
      packageConfig: _packageConfigUri(workspaceRoot),
      readPubspec: _readPubspec,
      log: logs.add,
    );

    expect(result.config['type'], equals('base'));
    expect(result.config['gpl'], isFalse);
    expect(result.config['small'], isTrue);
    expect(logs.join('\n'), contains('Dart Pub Workspace detected'));
    expect(
      logs.join('\n'),
      contains('Falling back to the default "base" LGPL small build.'),
    );
  });

  test(
    'selects a local package below the root without workspace membership',
    () {
      final projectRoot = _createDirectory(tempRoot, 'project');
      final packageRoot = _createDirectory(tempRoot, 'package');
      final localRoot = _createDirectory(
        tempRoot,
        p.join('project', 'local', 'app'),
      );
      _writePubspec(projectRoot, 'name: project\n');
      _writePubspec(localRoot, '''
name: local_app
ffmpeg_kit_extended_config:
  type: video
''');
      _writePackageConfig(projectRoot, packageRoot, [localRoot]);

      final result = resolveConfig(
        packageName: 'ffmpeg_kit_extended_flutter',
        packageRoot: packageRoot.path,
        packageConfig: _packageConfigUri(projectRoot),
        readPubspec: _readPubspec,
        log: (_) {},
      );

      expect(result.config['type'], equals('video'));
      expect(result.configBaseDir, equals(p.normalize(localRoot.path)));
    },
  );

  test('excludes ffmpeg_kit_extended_flutter from workspace candidates', () {
    final workspaceRoot = _createDirectory(tempRoot, 'workspace');
    final packageRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'packages', 'ffmpeg'),
    );
    _writePubspec(workspaceRoot, '''
name: workspace
workspace:
  - packages/ffmpeg
''');
    _writePubspec(packageRoot, '''
name: ffmpeg_kit_extended_flutter
ffmpeg_kit_extended_config:
  type: audio
''');
    _writePackageConfig(workspaceRoot, packageRoot, const []);

    final result = resolveConfig(
      packageName: 'ffmpeg_kit_extended_flutter',
      packageRoot: packageRoot.path,
      packageConfig: _packageConfigUri(workspaceRoot),
      readPubspec: _readPubspec,
      log: (_) {},
    );

    expect(result.config['type'], equals('base'));
  });

  test('reports ambiguity when multiple workspace packages are configured', () {
    final workspaceRoot = _createDirectory(tempRoot, 'workspace');
    final packageRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'packages', 'ffmpeg'),
    );
    final firstRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'apps', 'first'),
    );
    final secondRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'apps', 'second'),
    );
    _writePubspec(workspaceRoot, '''
name: workspace
workspace:
  - apps/first
  - apps/second
''');
    _writePubspec(firstRoot, '''
name: first
ffmpeg_kit_extended_config:
  type: video
''');
    _writePubspec(secondRoot, '''
name: second
ffmpeg_kit_extended_config:
  type: audio
''');
    _writePackageConfig(workspaceRoot, packageRoot, [firstRoot, secondRoot]);
    final logs = <String>[];

    expect(
      () => resolveConfig(
        packageName: 'ffmpeg_kit_extended_flutter',
        packageRoot: packageRoot.path,
        packageConfig: _packageConfigUri(workspaceRoot),
        readPubspec: _readPubspec,
        log: logs.add,
      ),
      throwsA(isA<ConfigResolutionException>()),
    );
    expect(logs.join('\n'), contains('multiple in-workspace packages'));
    expect(logs.join('\n'), contains(p.normalize(firstRoot.path)));
    expect(logs.join('\n'), contains(p.normalize(secondRoot.path)));
  });

  test('preserves package-local fallback without package metadata', () {
    final packageRoot = _createDirectory(tempRoot, 'package');
    _writePubspec(packageRoot, '''
name: ffmpeg_kit_extended_flutter
ffmpeg_kit_extended_config:
  type: audio
''');

    final result = resolveConfig(
      packageName: 'ffmpeg_kit_extended_flutter',
      packageRoot: packageRoot.path,
      packageConfig: null,
      readPubspec: _readPubspec,
      log: (_) {},
    );

    expect(result.config['type'], equals('audio'));
    expect(result.configBaseDir, equals(packageRoot.path));
  });

  test('keeps relative override baseDir at the selected pubspec root', () {
    final workspaceRoot = _createDirectory(tempRoot, 'workspace');
    final packageRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'packages', 'ffmpeg'),
    );
    final memberRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'apps', 'app'),
    );
    _writePubspec(workspaceRoot, '''
name: workspace
workspace:
  - apps/app
''');
    _writePubspec(memberRoot, '''
name: app
ffmpeg_kit_extended_config:
  windows: bundles/windows
''');
    _writePackageConfig(workspaceRoot, packageRoot, [memberRoot]);

    final result = resolveConfig(
      packageName: 'ffmpeg_kit_extended_flutter',
      packageRoot: packageRoot.path,
      packageConfig: _packageConfigUri(workspaceRoot),
      readPubspec: _readPubspec,
      log: (_) {},
    );

    expect(result.configBaseDir, equals(p.normalize(memberRoot.path)));
    expect(
      p.normalize(p.join(result.configBaseDir, 'bundles/windows')),
      equals(p.join(memberRoot.path, 'bundles', 'windows')),
    );
  });
}

Directory _createDirectory(Directory tempRoot, String relativePath) =>
    Directory(p.join(tempRoot.path, relativePath))..createSync(recursive: true);

String _packageConfigUri(Directory root) =>
    Uri.file(p.join(root.path, '.dart_tool', 'package_config.json')).toString();

void _writePackageConfig(
  Directory workspaceRoot,
  Directory packageRoot,
  List<Directory> members, {
  List<Directory> externalPackages = const [],
}) {
  final entries = <Map<String, String>>[
    _packageEntry('ffmpeg_kit_extended_flutter', packageRoot, workspaceRoot),
    for (final member in members)
      _packageEntry(p.basename(member.path), member, workspaceRoot),
    for (final package in externalPackages)
      _packageEntry(p.basename(package.path), package, workspaceRoot),
  ];
  File(p.join(workspaceRoot.path, '.dart_tool', 'package_config.json'))
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode({'configVersion': 2, 'packages': entries}));
}

Map<String, String> _packageEntry(
  String name,
  Directory root,
  Directory workspaceRoot,
) {
  final normalizedRoot = p.normalize(root.path);
  final normalizedWorkspaceRoot = p.normalize(workspaceRoot.path);
  final packageConfigDirectory = p.join(normalizedWorkspaceRoot, '.dart_tool');
  final rootUri =
      p.equals(normalizedRoot, normalizedWorkspaceRoot) ||
          p.isWithin(normalizedWorkspaceRoot, normalizedRoot)
      ? '${p.relative(normalizedRoot, from: packageConfigDirectory).replaceAll('\\', '/')}/'
      : Uri.file(normalizedRoot).toString();
  return {
    'name': name,
    'rootUri': rootUri,
    'packageUri': 'lib/',
    'languageVersion': '3.12',
  };
}

void _writePubspec(Directory root, String content) {
  File(p.join(root.path, 'pubspec.yaml'))
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}

PubspecData? _readPubspec(File file) {
  final doc = loadYaml(file.readAsStringSync());
  if (doc is! YamlMap) return null;
  return PubspecData(
    config: doc['ffmpeg_kit_extended_config'],
    isWorkspace: doc.containsKey('workspace'),
  );
}
