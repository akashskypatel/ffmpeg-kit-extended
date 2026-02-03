import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_flutter_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelFfmpegKitFlutter platform = MethodChannelFfmpegKitFlutter();
  const MethodChannel channel = MethodChannel('ffmpeg_kit_flutter');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
