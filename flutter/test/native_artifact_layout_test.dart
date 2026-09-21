import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../hook/native_artifact.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('ffmpeg_native_artifact_');
  });

  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  File file(String relativePath) {
    final result = File('${tempRoot.path}/$relativePath')
      ..createSync(recursive: true);
    return result;
  }

  Directory directory(String relativePath) =>
      Directory('${tempRoot.path}/$relativePath')..createSync(recursive: true);

  test('Android exact main is accepted', () {
    final main = file('jni/arm64-v8a/libffmpegkit.so');
    expect(
      selectExactMainLibrary(
        [main, file('jni/arm64-v8a/libavcodec.so')],
        expectedBasename: 'libffmpegkit.so',
        platform: 'Android ABI arm64-v8a',
      ),
      same(main),
    );
  });

  test('Android companion-only artifact is rejected', () {
    expect(
      () => selectExactMainLibrary(
        [file('jni/arm64-v8a/libavcodec.so')],
        expectedBasename: 'libffmpegkit.so',
        platform: 'Android ABI arm64-v8a',
      ),
      throwsA(
        allOf(
          isA<StateError>(),
          predicate<StateError>(
            (error) => error.message.toString().contains('libffmpegkit.so'),
          ),
        ),
      ),
    );
  });

  test('Linux exact main is accepted', () {
    final main = file('lib/libffmpegkit.so');
    expect(
      selectExactMainLibrary(
        [main, file('lib/libavcodec.so')],
        expectedBasename: 'libffmpegkit.so',
        platform: 'Linux',
      ),
      same(main),
    );
  });

  test('Linux no main is rejected', () {
    expect(
      () => selectExactMainLibrary(
        [file('lib/libavcodec.so')],
        expectedBasename: 'libffmpegkit.so',
        platform: 'Linux',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('Linux multiple main roots are rejected', () {
    expect(
      () => selectExactMainLibrary(
        [file('lib/libffmpegkit.so'), file('root/libffmpegkit.so')],
        expectedBasename: 'libffmpegkit.so',
        platform: 'Linux',
      ),
      throwsA(
        predicate<StateError>(
          (error) => error.message.toString().contains('multiple'),
        ),
      ),
    );
  });

  test('Windows exact main is accepted', () {
    final main = file('bin/libffmpegkit.dll');
    expect(
      selectExactMainLibrary(
        [main, file('bin/avcodec.dll')],
        expectedBasename: 'libffmpegkit.dll',
        platform: 'Windows',
      ),
      same(main),
    );
  });

  test('Windows no main is rejected', () {
    expect(
      () => selectExactMainLibrary(
        [file('bin/avcodec.dll')],
        expectedBasename: 'libffmpegkit.dll',
        platform: 'Windows',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('Windows multiple main roots are rejected', () {
    expect(
      () => selectExactMainLibrary(
        [file('bin/libffmpegkit.dll'), file('lib/libffmpegkit.dll')],
        expectedBasename: 'libffmpegkit.dll',
        platform: 'Windows',
      ),
      throwsA(
        predicate<StateError>(
          (error) => error.message.toString().contains('multiple'),
        ),
      ),
    );
  });

  test('one Apple XCFramework root is accepted', () {
    final root = directory('bundle.xcframework');
    expect(
      p.normalize(selectAppleXcframeworkRoot(tempRoot).path),
      p.normalize(root.path),
    );
  });

  test('nested one Apple XCFramework root is accepted', () {
    final root = directory('nested/bundle.xcframework');
    expect(
      p.normalize(selectAppleXcframeworkRoot(tempRoot).path),
      p.normalize(root.path),
    );
  });

  test('archive wrapper with one nested Apple XCFramework is accepted', () {
    final root = directory('bundle.xcframework/bundle.xcframework');
    expect(
      p.normalize(
        selectAppleXcframeworkRoot(
          Directory('${tempRoot.path}/bundle.xcframework'),
        ).path,
      ),
      p.normalize(root.path),
    );
  });

  test('Apple multiple XCFramework roots are rejected', () {
    directory('one.xcframework');
    directory('nested/two.xcframework');
    expect(
      () => selectAppleXcframeworkRoot(tempRoot),
      throwsA(
        predicate<StateError>(
          (error) => error.message.toString().contains('multiple'),
        ),
      ),
    );
  });

  test('Apple no XCFramework root is rejected', () {
    directory('bundle');
    expect(
      () => selectAppleXcframeworkRoot(tempRoot),
      throwsA(isA<StateError>()),
    );
  });

  test('Apple framework metadata identifies each target variant', () {
    expect(
      appleFrameworkSupportedPlatform(macOS: false, simulator: false),
      'iPhoneOS',
    );
    expect(
      appleFrameworkSupportedPlatform(macOS: false, simulator: true),
      'iPhoneSimulator',
    );
    expect(
      appleFrameworkSupportedPlatform(macOS: true, simulator: false),
      'MacOSX',
    );
  });
}
