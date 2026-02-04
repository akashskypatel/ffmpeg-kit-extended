import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_flutter.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_flutter_method_channel.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_flutter_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFfmpegKitFlutterPlatform
    with MockPlatformInterfaceMixin
    implements FfmpegKitFlutterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FfmpegKitFlutterPlatform initialPlatform =
      FfmpegKitFlutterPlatform.instance;

  test('$MethodChannelFfmpegKitFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFfmpegKitFlutter>());
  });

  test('getPlatformVersion', () async {
    final FfmpegKitFlutter ffmpegKitFlutterPlugin = FfmpegKitFlutter();
    final MockFfmpegKitFlutterPlatform fakePlatform =
        MockFfmpegKitFlutterPlatform();
    FfmpegKitFlutterPlatform.instance = fakePlatform;

    expect(await ffmpegKitFlutterPlugin.getPlatformVersion(), '42');
  });
}
