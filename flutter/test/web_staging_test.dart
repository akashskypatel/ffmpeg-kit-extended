import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../hook/build.dart' as build_hook;
import '../hook/config.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('ffmpeg_web_staging_');
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('stages selected runtime into source and build roots', () async {
    final runtime = Directory(p.join(tempRoot.path, 'runtime'))..createSync();
    final files = <String, File>{};
    for (final name in <String>[
      'ffmpegkit.mjs',
      'ffmpegkit.wasm',
      'ffmpegkit_bridge.mjs',
      'ffmpegkit_callback_runtime.mjs',
      'ffmpegkit_loader.mjs',
    ]) {
      final file = File(p.join(runtime.path, name));
      if (name.endsWith('.wasm')) {
        file.writeAsBytesSync(<int>[0, 97, 115, 109]);
      } else {
        file.writeAsStringSync('source:$name');
      }
      files[name] = file;
    }

    final app = Directory(p.join(tempRoot.path, 'app'))..createSync();
    await build_hook.stageWebRuntimeFiles(
      files: files,
      stagingBaseDirs: <String>[app.path],
      packageName: 'ffmpeg_kit_extended_flutter',
    );

    final destinations = build_hook.webRuntimeStagingDirectories(
      stagingBaseDir: app.path,
      packageName: 'ffmpeg_kit_extended_flutter',
    );
    expect(destinations, hasLength(2));
    for (final destination in destinations) {
      for (final entry in files.entries) {
        expect(
          File(p.join(destination.path, entry.key)).readAsBytesSync(),
          orderedEquals(entry.value.readAsBytesSync()),
        );
      }
    }
  });

  test('app-scoped configuration stages only into that app', () {
    final plugin = Directory(p.join(tempRoot.path, 'plugin'))..createSync();
    final app = Directory(p.join(tempRoot.path, 'app'))..createSync();
    File(p.join(app.path, 'pubspec.yaml')).writeAsStringSync('name: app\\n');
    Directory(p.join(app.path, 'web')).createSync();

    final roots = resolveWebStagingBaseDirs(
      packageName: 'ffmpeg_kit_extended_flutter',
      packageRoot: plugin.path,
      packageConfig: null,
      configBaseDir: app.path,
      outputFile: p.join(app.path, '.dart_tool', 'hooks', 'output.json'),
      addDependency: (_) {},
      log: (_) {},
    );

    expect(roots, <String>[p.normalize(app.path)]);
  });

  test('shared workspace configuration resolves dependent Web roots', () {
    final workspace = Directory(p.join(tempRoot.path, 'workspace'))..createSync();
    final dartTool = Directory(p.join(workspace.path, '.dart_tool'))..createSync();
    final plugin = Directory(p.join(tempRoot.path, 'plugin'))..createSync();
    final app = Directory(p.join(workspace.path, 'apps', 'app'))
      ..createSync(recursive: true);
    File(p.join(app.path, 'pubspec.yaml')).writeAsStringSync('name: app\\n');
    Directory(p.join(app.path, 'web')).createSync();

    final packageConfig = File(p.join(dartTool.path, 'package_config.json'));
    packageConfig.writeAsStringSync(
      jsonEncode(<String, Object?>{
        'configVersion': 2,
        'packages': <Object?>[
          <String, Object?>{
            'name': 'app',
            'rootUri': '../apps/app/',
            'packageUri': 'lib/',
          },
          <String, Object?>{
            'name': 'ffmpeg_kit_extended_flutter',
            'rootUri': plugin.uri.toString(),
            'packageUri': 'lib/',
          },
        ],
      }),
    );
    File(p.join(dartTool.path, 'package_graph.json')).writeAsStringSync(
      jsonEncode(<String, Object?>{
        'configVersion': 1,
        'roots': <String>['app'],
        'packages': <Object?>[
          <String, Object?>{
            'name': 'app',
            'dependencies': <String>['ffmpeg_kit_extended_flutter'],
          },
          <String, Object?>{
            'name': 'ffmpeg_kit_extended_flutter',
            'dependencies': <String>[],
          },
        ],
      }),
    );

    final roots = resolveWebStagingBaseDirs(
      packageName: 'ffmpeg_kit_extended_flutter',
      packageRoot: plugin.path,
      packageConfig: packageConfig.uri.toString(),
      configBaseDir: workspace.path,
      outputFile: p.join(dartTool.path, 'hooks_runner', 'output.json'),
      addDependency: (_) {},
      log: (_) {},
    );

    expect(roots, <String>[p.normalize(app.path)]);
  });

  test('implicit Web debug still fails closed before staging', () {
    expect(
      () => build_hook.validateWebBundleSelection(<String, Object?>{
        'type': 'debug',
      }),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains(
            'automatic prebuilt Flutter Web debug artifact is unsupported',
          ),
        ),
      ),
    );
  });

  test('build hook source has no DataAsset delivery gate', () {
    final source = File('hook/build.dart').readAsStringSync();
    expect(source, isNot(contains('buildDataAssets')));
    expect(source, isNot(contains('DataAsset(')));
    expect(source, isNot(contains('wasm_override')));
  });
}
