import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

import 'benchmark_core.dart';

BenchmarkAdapter createBenchmarkAdapter() => ExtendedBenchmarkAdapter();

class ExtendedBenchmarkAdapter implements BenchmarkAdapter {
  @override
  String get packageId => 'ffmpeg_kit_extended_flutter';

  @override
  String get packageVersion => '1.0.0';

  @override
  String get expectedNativeAbi => '0.11.2';

  @override
  String get bundleSelector => 'full';

  @override
  Future<void> initialize() => FFmpegKitExtended.initialize();

  @override
  Future<BenchmarkSessionResult> execute(List<String> arguments) async {
    final session = FFmpegKit.createSessionFromArguments(arguments);
    final stopwatch = Stopwatch()..start();
    await session.executeAsync();
    stopwatch.stop();
    return BenchmarkSessionResult(
      returnCode: session.getReturnCode(),
      wallMicroseconds: stopwatch.elapsedMicroseconds,
      durationMilliseconds: session.getDuration(),
      logs: session.getLogsAsString() ?? '',
    );
  }

  @override
  Future<BenchmarkProbeResult> probe(String path) async {
    final ffmpegPath = path.replaceAll(r'\', '/');
    final session = await FFprobeKit.executeAsync(
      '-v error -show_entries stream=codec_type,codec_name,width,height:format=duration -of json "$ffmpegPath"',
    );
    return BenchmarkProbeResult(
      returnCode: session.getReturnCode(),
      logs: session.getLogsAsString() ?? '',
    );
  }

  @override
  Future<String?> ffmpegVersion() async => FFmpegKitExtended.getFFmpegVersion();

  @override
  Future<String?> nativePackageName() async =>
      FFmpegKitExtended.getPackageName();

  @override
  Future<String?> nativeBundleType() async => FFmpegKitExtended.getBundleType();

  @override
  Future<List<String>> externalLibraries() async =>
      FFmpegKitExtended.getExternalLibraries().split(',');
}
