import 'dart:convert';
import 'dart:io';

import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../hook/config.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('ffmpeg_user_defines_');
  });

  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  test('resolves standalone root userDefines with source metadata', () {
    final logs = <String>[];
    final root = Directory(p.join(tempRoot.path, 'app'))..createSync();

    final result = resolveUserDefines(
      read: (key) =>
          <String, Object?>{'type': 'video', 'gpl': true, 'small': false}[key],
      readPath: (_) => null,
      readBase: (_) => root.uri,
      packageRoot: tempRoot.path,
      addDependency: (_) {},
      log: logs.add,
    );

    expect(result, isNotNull);
    expect(
      result!.config,
      equals({'type': 'video', 'gpl': true, 'small': false}),
    );
    expect(result.configBaseDir, equals(p.normalize(root.path)));
    expect(result.source, equals('hooks.user_defines'));
    expect(logs.single, contains('hooks.user_defines'));
  });

  test(
    'reads official Hooks input.userDefines from a real hook input',
    () async {
      final workspaceRoot = Directory(p.join(tempRoot.path, 'workspace'))
        ..createSync();

      await testBuildHook(
        mainMethod: (arguments) {
          final configPath = arguments.single.substring('--config='.length);
          final input = BuildInput(
            jsonDecode(File(configPath).readAsStringSync())
                as Map<String, Object?>,
          );
          final output = BuildOutputBuilder();
          File.fromUri(
            input.outputFile,
          ).writeAsStringSync(jsonEncode(output.json));
        },
        extensions: const [],
        userDefines: PackageUserDefines(
          workspacePubspec: PackageUserDefinesSource(
            defines: {'type': 'video', 'gpl': true},
            basePath: workspaceRoot.uri,
          ),
        ),
        check: (input, _) {
          final result = resolveUserDefines(
            read: (key) => input.userDefines[key],
            readPath: (key) => input.userDefines.path(key),
            readBase: (key) => input.userDefines.baseUri([key]),
            packageRoot: input.packageRoot.toFilePath(),
            addDependency: (_) {},
            log: (_) {},
          );

          expect(result!.config['type'], equals('video'));
          expect(result.config['gpl'], isTrue);
          expect(result.source, equals('hooks.user_defines'));
          expect(result.configBaseDir, equals(p.normalize(workspaceRoot.path)));
        },
      );
    },
  );

  test('resolves workspace-root userDefines and relative local paths', () {
    final workspaceRoot = Directory(p.join(tempRoot.path, 'workspace'))
      ..createSync();
    final bundle = File(p.join(workspaceRoot.path, 'bundles', 'ios.zip'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    final dependencies = <Uri>[];

    final result = resolveUserDefines(
      read: (key) =>
          <String, Object?>{'type': 'base', 'ios': 'bundles/ios.zip'}[key],
      readPath: (key) => key == 'ios' ? bundle.uri : null,
      readBase: (_) => workspaceRoot.uri,
      packageRoot: p.join(workspaceRoot.path, 'packages', 'ffmpeg'),
      addDependency: dependencies.add,
      log: (_) {},
    );

    expect(result!.config['ios'], equals(bundle.path));
    expect(result.configBaseDir, equals(p.normalize(workspaceRoot.path)));
    expect(dependencies, contains(bundle.uri));
  });

  test('keeps unsupported URI-like overrides for hook validation', () {
    var pathReaderInvoked = false;
    final result = resolveUserDefines(
      read: (key) => key == 'linux' ? 'ftp://example.test/bundle.zip' : null,
      readPath: (_) {
        pathReaderInvoked = true;
        return null;
      },
      readBase: (_) => tempRoot.uri,
      packageRoot: tempRoot.path,
      addDependency: (_) {},
      log: (_) {},
    );

    expect(result!.config['linux'], 'ftp://example.test/bundle.zip');
    expect(pathReaderInvoked, isFalse);
  });

  test('does not convert a foreign-host file URI on non-Windows hosts', () {
    const rawWslPath = r'\\wsl.localhost\ManyLinux\bundle.zip';
    final authorityUri = Uri.parse('file://wsl.localhost/ManyLinux/bundle.zip');
    final dependencies = <Uri>[];

    final result = resolveUserDefines(
      read: (key) => key == 'linux' ? rawWslPath : null,
      readPath: (_) => authorityUri,
      readBase: (_) => tempRoot.uri,
      packageRoot: tempRoot.path,
      addDependency: dependencies.add,
      log: (_) {},
    );

    if (Platform.isWindows) {
      expect(result!.config['linux'], authorityUri.toFilePath(windows: true));
      expect(dependencies, contains(authorityUri));
    } else {
      expect(result!.config['linux'], rawWslPath);
      expect(dependencies, isEmpty);
    }
  });

  test('explicit userDefines take precedence for native and Web overrides', () {
    final user = ConfigResult(
      {'type': 'video', 'android': 'user-android', 'web': 'user-web'},
      tempRoot.path,
      source: 'hooks.user_defines',
    );
    var legacyCalled = false;

    final result = selectConfigSource(
      userDefines: user,
      legacy: () {
        legacyCalled = true;
        return ConfigResult({'type': 'audio'}, tempRoot.path);
      },
    );

    expect(result.config['type'], equals('video'));
    expect(result.config['android'], equals('user-android'));
    expect(result.config['web'], equals('user-web'));
    expect(legacyCalled, isFalse);
  });

  test('no userDefines preserves legacy native and Web compatibility', () {
    final result = selectConfigSource(
      userDefines: null,
      legacy: () => ConfigResult({
        'type': 'audio',
        'ios': 'legacy-ios',
        'wasm': 'legacy-wasm',
      }, tempRoot.path),
    );

    expect(result.config['type'], equals('audio'));
    expect(result.config['ios'], equals('legacy-ios'));
    expect(result.config['wasm'], equals('legacy-wasm'));
    expect(result.source, equals('legacy ffmpeg_kit_extended_config'));
  });

  test('neither source uses explicit defaults from the legacy resolver', () {
    final result = selectConfigSource(
      userDefines: null,
      legacy: () => ConfigResult(
        {'type': 'base', 'gpl': false, 'small': true},
        tempRoot.path,
        source: 'defaults',
      ),
    );

    expect(result.config['type'], equals('base'));
    expect(result.source, equals('defaults'));
  });

  test('reports invalid user-defined value types', () {
    expect(
      () => resolveUserDefines(
        read: (key) => key == 'gpl' ? 'yes' : null,
        readPath: (_) => null,
        readBase: (_) => null,
        packageRoot: tempRoot.path,
        addDependency: (_) {},
        log: (_) {},
      ),
      throwsA(
        predicate<ConfigResolutionException>(
          (error) => error.message.contains('hooks.user_defines.gpl'),
        ),
      ),
    );
  });

  test(
    'formats stable bundle diagnostics without exposing environment data',
    () {
      expect(
        configDiagnosticSummary({'type': 'video', 'gpl': true, 'small': false}),
        equals('video / GPL / small=false'),
      );
    },
  );
}
