import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ffmpeg_kit_flutter_method_channel.dart';

abstract class FfmpegKitFlutterPlatform extends PlatformInterface {
  /// Constructs a FfmpegKitFlutterPlatform.
  FfmpegKitFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static FfmpegKitFlutterPlatform _instance = MethodChannelFfmpegKitFlutter();

  /// The default instance of [FfmpegKitFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelFfmpegKitFlutter].
  static FfmpegKitFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FfmpegKitFlutterPlatform] when
  /// they register themselves.
  static set instance(FfmpegKitFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
