import 'dart:convert';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/packages.dart';

import 'benchmark_core.dart';

BenchmarkAdapter createBenchmarkAdapter() => NewFullBenchmarkAdapter();

class NewFullBenchmarkAdapter implements BenchmarkAdapter {
  @override
  String get packageId => 'ffmpeg_kit_flutter_new_full';

  @override
  String get packageVersion => '2.5.2';

  @override
  String get expectedNativeAbi => 'not-applicable';

  @override
  String get bundleSelector => 'new_full';

  @override
  Future<void> initialize() => FFmpegKitConfig.init();

  @override
  Future<BenchmarkSessionResult> execute(List<String> arguments) async {
    final stopwatch = Stopwatch()..start();
    final session = await FFmpegKit.executeWithArguments(arguments);
    final returnCode = await session.getReturnCode();
    stopwatch.stop();
    return BenchmarkSessionResult(
      returnCode: returnCode?.getValue(),
      wallMicroseconds: stopwatch.elapsedMicroseconds,
      durationMilliseconds: await session.getDuration(),
      logs: await session.getLogsAsString(),
    );
  }

  @override
  Future<BenchmarkProbeResult> probe(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final returnCode = await session.getReturnCode();
    final mediaInformation = session.getMediaInformation();
    final videoStreams =
        mediaInformation
            ?.getStreams()
            .where((stream) => stream.getType() == 'video')
            .toList(growable: false) ??
        const [];
    final video = videoStreams.isEmpty ? null : videoStreams.first;
    return BenchmarkProbeResult(
      returnCode: returnCode?.getValue(),
      logs: jsonEncode(<String, Object?>{
        'streams': <Map<String, Object?>>[
          if (video != null)
            <String, Object?>{
              'codec_type': video.getType(),
              'codec_name': video.getCodec(),
              'width': video.getWidth(),
              'height': video.getHeight(),
            },
        ],
        'format': <String, Object?>{
          'duration': mediaInformation?.getDuration(),
        },
      }),
    );
  }

  @override
  Future<String?> ffmpegVersion() => FFmpegKitConfig.getFFmpegVersion();

  @override
  Future<String?> nativePackageName() => Packages.getPackageName();

  @override
  Future<String?> nativeBundleType() async => null;

  @override
  Future<List<String>> externalLibraries() => Packages.getExternalLibraries();
}
