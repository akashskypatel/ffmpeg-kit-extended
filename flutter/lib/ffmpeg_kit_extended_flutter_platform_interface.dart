import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ffmpeg_kit_extended_flutter_method_channel.dart';

abstract class FfmpegKitExtendedFlutterPlatform extends PlatformInterface {
  /// Constructs a FfmpegKitExtendedFlutterPlatform.
  FfmpegKitExtendedFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static FfmpegKitExtendedFlutterPlatform _instance = MethodChannelFfmpegKitExtendedFlutter();

  /// The default instance of [FfmpegKitExtendedFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelFfmpegKitExtendedFlutter].
  static FfmpegKitExtendedFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FfmpegKitExtendedFlutterPlatform] when
  /// they register themselves.
  static set instance(FfmpegKitExtendedFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
