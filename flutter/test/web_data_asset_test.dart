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

  test('uses ordinary package assets for the default Web runtime', () async {
    await expectLater(
      testBuildHook(
        mainMethod: build_hook.main,
        extensions: const [],
        check: (input, output) {
          expect(input.config.buildDataAssets, isFalse);
          expect(
            output.assets.encodedAssets.where((asset) => asset.isDataAsset),
            isEmpty,
          );
        },
      ),
      completes,
    );
  });

  test(
    'rejects custom Web hooks when Flutter DataAssets are unavailable',
    () async {
      await expectLater(
        testBuildHook(
          mainMethod: build_hook.main,
          extensions: const [],
          userDefines: PackageUserDefines(
            workspacePubspec: PackageUserDefinesSource(
              defines: {'type': 'base', 'web': 'runtime'},
              basePath: tempRoot.uri,
            ),
          ),
          check: (_, _) {},
        ),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains(
              'Custom or non-default Flutter Web Wasm configuration',
            ),
          ),
        ),
      );
    },
  );

  for (final buildDataAssets in [false, true]) {
    test(
      'rejects implicit Web debug before download with buildDataAssets=$buildDataAssets',
      () async {
        final extensions = buildDataAssets
            ? <ProtocolExtension>[DataAssetsExtension()]
            : const <ProtocolExtension>[];
        await expectLater(
          testBuildHook(
            mainMethod: build_hook.main,
            extensions: extensions,
            userDefines: PackageUserDefines(
              workspacePubspec: PackageUserDefinesSource(
                defines: {'type': 'debug'},
                basePath: tempRoot.uri,
              ),
            ),
            check: (_, _) {},
          ),
          throwsA(
            predicate<Object>(
              (error) =>
                  error.toString().contains(
                    'automatic prebuilt Flutter Web debug artifact is unsupported',
                  ) &&
                  !error.toString().contains('Downloading'),
            ),
          ),
        );
      },
    );
  }

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
          defines: {'type': 'debug', 'web': 'runtime'},
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
            'wasm_override/ffmpegkit.mjs',
            'wasm_override/ffmpegkit.wasm',
            'wasm_override/ffmpegkit_bridge.mjs',
            'wasm_override/ffmpegkit_callback_runtime.mjs',
            'wasm_override/ffmpegkit_loader.mjs',
            'wasm_override/ffmpegkit_wasm_manifest.json',
          }),
        );
        expect(assets, hasLength(6));
        expect(input.config.buildDataAssets, isTrue);
        expect(
          output.dependencies,
          containsAll(<Uri>[
            input.packageRoot.resolve('web/ffmpegkit_bridge.mjs'),
            input.packageRoot.resolve('web/ffmpegkit_callback_runtime.mjs'),
            input.packageRoot.resolve('web/ffmpegkit_loader.mjs'),
            input.packageRoot.resolve('web/ffmpegkit_wasm_manifest.json'),
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

  test('classifies only base/small/LGPL without an override as default', () {
    expect(
      build_hook.isDefaultWebRuntime({
        'type': 'base',
        'gpl': false,
        'small': true,
      }),
      isTrue,
    );
    expect(build_hook.isDefaultWebRuntime({'type': 'base'}), isFalse);
    expect(
      build_hook.isDefaultWebRuntime({
        'type': 'base',
        'gpl': false,
        'small': true,
        'wasm': 'runtime',
      }),
      isFalse,
    );
    expect(
      build_hook.isDefaultWebRuntime({
        'type': 'video',
        'gpl': false,
        'small': true,
      }),
      isFalse,
    );
    expect(
      () => build_hook.validateWebBundleSelection({'type': 'debug'}),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('browser-incompatible'),
        ),
      ),
    );
    expect(
      () => build_hook.validateWebBundleSelection({
        'type': 'debug',
        'web': 'https://example.test/runtime.zip',
      }),
      returnsNormally,
    );
    expect(
      () => build_hook.validateWebBundleSelection({
        'type': 'debug',
        'wasm': 'runtime',
      }),
      returnsNormally,
    );
  });
}
