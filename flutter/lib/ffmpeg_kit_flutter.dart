import 'ffmpeg_kit_flutter_platform_interface.dart';

class FfmpegKitFlutter {
  Future<String?> getPlatformVersion() =>
      FfmpegKitFlutterPlatform.instance.getPlatformVersion();
}
