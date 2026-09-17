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
    expect(result.baseDir, equals(workspaceRoot.path));
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
    _writePackageConfig(workspaceRoot, packageRoot, [memberRoot]);

    final result = resolveConfig(
      packageName: 'ffmpeg_kit_extended_flutter',
      packageRoot: packageRoot.path,
      packageConfig: _packageConfigUri(workspaceRoot),
      readPubspec: _readPubspec,
      log: (_) {},
    );

    expect(result.config['type'], equals('full'));
    expect(result.config['gpl'], isTrue);
    expect(result.baseDir, equals(p.normalize(memberRoot.path)));
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
    expect(logs.join('\n'), contains('multiple workspace packages'));
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
    expect(result.baseDir, equals(packageRoot.path));
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

    expect(result.baseDir, equals(p.normalize(memberRoot.path)));
    expect(
      p.normalize(p.join(result.baseDir, 'bundles/windows')),
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
  List<Directory> members,
) {
  final entries = <Map<String, String>>[
    _packageEntry('ffmpeg_kit_extended_flutter', packageRoot),
    for (final member in members)
      _packageEntry(p.basename(member.path), member),
  ];
  File(p.join(workspaceRoot.path, '.dart_tool', 'package_config.json'))
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode({'configVersion': 2, 'packages': entries}));
}

Map<String, String> _packageEntry(String name, Directory root) => {
  'name': name,
  'rootUri': Uri.file(root.path).toString(),
  'packageUri': 'lib/',
  'languageVersion': '3.12',
};

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
