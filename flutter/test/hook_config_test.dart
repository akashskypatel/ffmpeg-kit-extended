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
    );

    expect(result.config['type'], equals('video'));
    expect(result.configBaseDir, equals(workspaceRoot.path));
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
  type: video
  gpl: true
  small: true
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
    _writePackageGraph(
      workspaceRoot,
      roots: ['app'],
      dependencies: {
        'app': ['ffmpeg_kit_extended_flutter'],
        'ffmpeg_kit_extended_flutter': const [],
      },
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

    expect(result.config['type'], equals('video'));
    expect(result.config['gpl'], isTrue);
    expect(result.config['small'], isTrue);
    expect(result.configBaseDir, equals(p.normalize(memberRoot.path)));
    expect(
      dependencies.map((uri) => p.normalize(uri.toFilePath())),
      containsAll(<String>[
        p.normalize(
          p.join(workspaceRoot.path, '.dart_tool', 'package_config.json'),
        ),
        p.normalize(p.join(workspaceRoot.path, 'pubspec.yaml')),
        p.normalize(
          p.join(workspaceRoot.path, '.dart_tool', 'package_graph.json'),
        ),
        p.normalize(p.join(memberRoot.path, 'pubspec.yaml')),
      ]),
    );
  });

  test('ignores a dev-only dependency of a second workspace root', () {
    final workspaceRoot = _createDirectory(tempRoot, 'workspace');
    final packageRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'packages', 'ffmpeg'),
    );
    final appRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'apps', 'app'),
    );
    final toolsRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'tools', 'tools'),
    );
    _writePubspec(workspaceRoot, '''
name: workspace
workspace:
  - apps/app
  - tools/tools
''');
    _writePubspec(appRoot, '''
name: app
ffmpeg_kit_extended_config:
  type: video
''');
    _writePubspec(toolsRoot, 'name: tools\n');
    _writePackageConfig(workspaceRoot, packageRoot, [appRoot, toolsRoot]);
    _writePackageGraph(
      workspaceRoot,
      roots: ['app', 'tools'],
      dependencies: {
        'app': ['ffmpeg_kit_extended_flutter'],
        'tools': const [],
        'ffmpeg_kit_extended_flutter': const [],
      },
      devDependencies: {
        'tools': ['ffmpeg_kit_extended_flutter'],
      },
    );

    final result = resolveConfig(
      packageName: 'ffmpeg_kit_extended_flutter',
      packageRoot: packageRoot.path,
      packageConfig: _packageConfigUri(workspaceRoot),
      readPubspec: _readPubspec,
      log: (_) {},
    );

    expect(result.config['type'], equals('video'));
  });

  test('does not traverse dev dependencies of an intermediate package', () {
    final workspaceRoot = _createDirectory(tempRoot, 'workspace');
    final packageRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'packages', 'ffmpeg'),
    );
    final appRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'apps', 'app'),
    );
    final helperRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'packages', 'helper'),
    );
    _writePubspec(workspaceRoot, '''
name: workspace
workspace:
  - apps/app
  - packages/helper
''');
    _writePubspec(appRoot, 'name: app\n');
    _writePubspec(helperRoot, '''
name: helper
ffmpeg_kit_extended_config:
  type: audio
''');
    _writePackageConfig(workspaceRoot, packageRoot, [appRoot, helperRoot]);
    _writePackageGraph(
      workspaceRoot,
      roots: ['app'],
      dependencies: {
        'app': ['helper'],
        'helper': const [],
        'ffmpeg_kit_extended_flutter': const [],
      },
      devDependencies: {
        'helper': ['ffmpeg_kit_extended_flutter'],
      },
    );

    final result = resolveConfig(
      packageName: 'ffmpeg_kit_extended_flutter',
      packageRoot: packageRoot.path,
      packageConfig: _packageConfigUri(workspaceRoot),
      readPubspec: _readPubspec,
      log: (_) {},
    );

    expect(result.config['type'], equals('base'));
  });

  test('ignores configuration from a root with only a dev dependency', () {
    final workspaceRoot = _createDirectory(tempRoot, 'workspace');
    final packageRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'packages', 'ffmpeg'),
    );
    final toolsRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'tools', 'tools'),
    );
    _writePubspec(workspaceRoot, '''
name: workspace
workspace:
  - tools/tools
''');
    _writePubspec(toolsRoot, '''
name: tools
ffmpeg_kit_extended_config:
  type: full
''');
    _writePackageConfig(workspaceRoot, packageRoot, [toolsRoot]);
    _writePackageGraph(
      workspaceRoot,
      roots: ['tools'],
      dependencies: {
        'tools': const [],
        'ffmpeg_kit_extended_flutter': const [],
      },
      devDependencies: {
        'tools': ['ffmpeg_kit_extended_flutter'],
      },
    );

    final result = resolveConfig(
      packageName: 'ffmpeg_kit_extended_flutter',
      packageRoot: packageRoot.path,
      packageConfig: _packageConfigUri(workspaceRoot),
      readPubspec: _readPubspec,
      log: (_) {},
    );

    expect(result.config['type'], equals('base'));
  });

  test('ignores configured packages outside the dependency closure', () {
    final workspaceRoot = _createDirectory(tempRoot, 'workspace');
    final packageRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'packages', 'ffmpeg'),
    );
    final dependentAppRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'apps', 'editor'),
    );
    final unrelatedConfiguredRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'apps', 'transcoder'),
    );
    _writePubspec(workspaceRoot, '''
name: workspace
workspace:
  - apps/editor
  - apps/transcoder
''');
    _writePubspec(dependentAppRoot, 'name: editor\n');
    _writePubspec(unrelatedConfiguredRoot, '''
name: transcoder
ffmpeg_kit_extended_config:
  type: full
''');
    _writePackageConfig(workspaceRoot, packageRoot, [
      dependentAppRoot,
      unrelatedConfiguredRoot,
    ]);
    _writePackageGraph(
      workspaceRoot,
      roots: ['editor', 'transcoder'],
      dependencies: {
        'editor': ['ffmpeg_kit_extended_flutter'],
        'transcoder': const [],
        'ffmpeg_kit_extended_flutter': const [],
      },
    );
    final logs = <String>[];

    final result = resolveConfig(
      packageName: 'ffmpeg_kit_extended_flutter',
      packageRoot: packageRoot.path,
      packageConfig: _packageConfigUri(workspaceRoot),
      readPubspec: _readPubspec,
      log: logs.add,
    );

    expect(result.config['type'], equals('base'));
    expect(logs.join('\n'), contains('not package-graph roots'));
  });

  test(
    'does not guess when the package graph has multiple workspace roots',
    () {
      // Pub package-graph roots do not identify which workspace package
      // Flutter is currently building, so the hook must preserve ambiguity.
      final workspaceRoot = _createDirectory(tempRoot, 'workspace');
      final packageRoot = _createDirectory(
        tempRoot,
        p.join('workspace', 'packages', 'ffmpeg'),
      );
      final editorRoot = _createDirectory(
        tempRoot,
        p.join('workspace', 'apps', 'editor'),
      );
      final transcoderRoot = _createDirectory(
        tempRoot,
        p.join('workspace', 'apps', 'transcoder'),
      );
      _writePubspec(workspaceRoot, '''
name: workspace
workspace:
  - apps/editor
  - apps/transcoder
''');
      _writePubspec(editorRoot, 'name: editor\n');
      _writePubspec(transcoderRoot, '''
name: transcoder
ffmpeg_kit_extended_config:
  type: full
''');
      _writePackageConfig(workspaceRoot, packageRoot, [
        editorRoot,
        transcoderRoot,
      ]);
      _writePackageGraph(
        workspaceRoot,
        roots: ['editor', 'transcoder'],
        dependencies: {
          'editor': ['ffmpeg_kit_extended_flutter'],
          'transcoder': ['ffmpeg_kit_extended_flutter'],
          'ffmpeg_kit_extended_flutter': const [],
        },
      );
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
      expect(logs.join('\n'), contains('multiple workspace roots'));
    },
  );

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

  test('ignores nested local packages when package graph is available', () {
    final projectRoot = _createDirectory(tempRoot, 'project');
    final packageRoot = _createDirectory(
      tempRoot,
      p.join('project', 'packages', 'ffmpeg'),
    );
    final localRoot = _createDirectory(
      tempRoot,
      p.join('project', 'local', 'media'),
    );
    _writePubspec(projectRoot, 'name: app\n');
    _writePubspec(localRoot, '''
name: local_media
ffmpeg_kit_extended_config:
  type: video
''');
    _writePackageConfig(projectRoot, packageRoot, [projectRoot, localRoot]);
    _writePackageGraph(
      projectRoot,
      roots: ['app'],
      dependencies: {
        'app': ['local_media'],
        'local_media': ['ffmpeg_kit_extended_flutter'],
        'ffmpeg_kit_extended_flutter': const [],
      },
    );
    final logs = <String>[];

    final result = resolveConfig(
      packageName: 'ffmpeg_kit_extended_flutter',
      packageRoot: packageRoot.path,
      packageConfig: _packageConfigUri(projectRoot),
      readPubspec: _readPubspec,
      log: logs.add,
    );

    expect(result.config['type'], equals('base'));
    expect(logs.join('\n'), contains('not package-graph roots'));
  });

  test('fails when a configured candidate has no package graph', () {
    final workspaceRoot = _createDirectory(tempRoot, 'workspace');
    final packageRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'packages', 'ffmpeg'),
    );
    final appRoot = _createDirectory(
      tempRoot,
      p.join('workspace', 'apps', 'app'),
    );
    _writePubspec(workspaceRoot, '''
name: workspace
workspace:
  - apps/app
''');
    _writePubspec(appRoot, '''
name: app
ffmpeg_kit_extended_config:
  type: video
''');
    _writePackageConfig(workspaceRoot, packageRoot, [appRoot]);
    final logs = <String>[];

    expect(
      () => resolveConfig(
        packageName: 'ffmpeg_kit_extended_flutter',
        packageRoot: packageRoot.path,
        packageConfig: _packageConfigUri(workspaceRoot),
        readPubspec: _readPubspec,
        log: logs.add,
      ),
      throwsA(
        predicate<ConfigResolutionException>(
          (error) =>
              error.message.contains('package_graph.json') &&
              error.message.contains('flutter pub get'),
        ),
      ),
    );
  });

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
    _writePackageGraph(
      workspaceRoot,
      roots: ['app'],
      dependencies: {
        'app': ['ffmpeg_kit_extended_flutter'],
        'ffmpeg_kit_extended_flutter': const [],
      },
    );

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

void _writePackageGraph(
  Directory workspaceRoot, {
  required List<String> roots,
  required Map<String, List<String>> dependencies,
  Map<String, List<String>> devDependencies = const {},
}) {
  final packages = [
    for (final entry in dependencies.entries)
      {
        'name': entry.key,
        'dependencies': entry.value,
        'devDependencies': devDependencies[entry.key] ?? const <String>[],
      },
    for (final entry in devDependencies.entries)
      if (!dependencies.containsKey(entry.key))
        {
          'name': entry.key,
          'dependencies': const <String>[],
          'devDependencies': entry.value,
        },
  ];
  File(p.join(workspaceRoot.path, '.dart_tool', 'package_graph.json'))
    ..createSync(recursive: true)
    ..writeAsStringSync(
      jsonEncode({'roots': roots, 'packages': packages, 'configVersion': 1}),
    );
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
