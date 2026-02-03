import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ffmpeg_kit_flutter_platform_interface.dart';

/// An implementation of [FfmpegKitFlutterPlatform] that uses method channels.
class MethodChannelFfmpegKitFlutter extends FfmpegKitFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ffmpeg_kit_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
