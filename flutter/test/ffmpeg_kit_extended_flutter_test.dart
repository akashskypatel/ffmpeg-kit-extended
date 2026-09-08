import 'package:flutter_test/flutter_test.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter_platform_interface.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFfmpegKitExtendedFlutterPlatform
    with MockPlatformInterfaceMixin
    implements FfmpegKitExtendedFlutterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FfmpegKitExtendedFlutterPlatform initialPlatform = FfmpegKitExtendedFlutterPlatform.instance;

  test('$MethodChannelFfmpegKitExtendedFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFfmpegKitExtendedFlutter>());
  });

  test('getPlatformVersion', () async {
    FfmpegKitExtendedFlutter ffmpegKitExtendedFlutterPlugin = FfmpegKitExtendedFlutter();
    MockFfmpegKitExtendedFlutterPlatform fakePlatform = MockFfmpegKitExtendedFlutterPlatform();
    FfmpegKitExtendedFlutterPlatform.instance = fakePlatform;

    expect(await ffmpegKitExtendedFlutterPlugin.getPlatformVersion(), '42');
  });
}
