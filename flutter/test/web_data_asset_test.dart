import 'dart:io';

import 'package:data_assets/data_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../hook/build.dart' as build_hook;

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('ffmpeg_web_assets_');
  });

  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  test('rejects Web hooks when Flutter DataAssets are unavailable', () async {
    await expectLater(
      testBuildHook(
        mainMethod: build_hook.main,
        extensions: const [],
        check: (_, _) {},
      ),
      throwsA(
        predicate<Object>(
          (error) =>
              error.toString().contains('Flutter Web DataAssets are required'),
        ),
      ),
    );
  });

  test('emits the Web runtime only through Flutter DataAssets', () async {
    final workspaceRoot = Directory(p.join(tempRoot.path, 'workspace'))
      ..createSync();
    final runtimeRoot = Directory(p.join(workspaceRoot.path, 'runtime'))
      ..createSync();
    File(p.join(runtimeRoot.path, 'ffmpegkit.mjs')).writeAsStringSync('mjs');
    File(
      p.join(runtimeRoot.path, 'ffmpegkit.wasm'),
    ).writeAsBytesSync([1, 2, 3]);

    await testBuildHook(
      mainMethod: build_hook.main,
      extensions: [DataAssetsExtension()],
      userDefines: PackageUserDefines(
        workspacePubspec: PackageUserDefinesSource(
          defines: {'type': 'base', 'web': 'runtime'},
          basePath: workspaceRoot.uri,
        ),
      ),
      check: (input, output) {
        final assets = output.assets.encodedAssets
            .where((asset) => asset.isDataAsset)
            .map((asset) => asset.asDataAsset)
            .toList();

        expect(
          assets.map((asset) => asset.name).toSet(),
          equals({
            'wasm/ffmpegkit.mjs',
            'wasm/ffmpegkit.wasm',
            'wasm/ffmpegkit_bridge.mjs',
            'wasm/ffmpegkit_callback_runtime.mjs',
            'wasm/ffmpegkit_loader.mjs',
          }),
        );
        expect(assets, hasLength(5));
        expect(input.config.buildDataAssets, isTrue);
        expect(
          output.dependencies,
          containsAll(<Uri>[
            input.packageRoot.resolve('web/ffmpegkit_bridge.mjs'),
            input.packageRoot.resolve('web/ffmpegkit_callback_runtime.mjs'),
            input.packageRoot.resolve('web/ffmpegkit_loader.mjs'),
          ]),
        );
        expect(
          Directory(p.join(workspaceRoot.path, 'web')).existsSync(),
          isFalse,
        );
        expect(
          Directory(p.join(workspaceRoot.path, 'build', 'web')).existsSync(),
          isFalse,
        );
      },
    );
  });
}
