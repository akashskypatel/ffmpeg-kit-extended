// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'benchmark_capabilities.dart';
import 'benchmark_operation_exclusions.dart';

const benchmarkRunId = String.fromEnvironment(
  'BENCH_RUN_ID',
  defaultValue: '20261007-1722-apple-issue40',
);
const benchmarkStillWidth = int.fromEnvironment(
  'BENCH_STILL_WIDTH',
  defaultValue: 4032,
);
const benchmarkStillHeight = int.fromEnvironment(
  'BENCH_STILL_HEIGHT',
  defaultValue: 3024,
);
const benchmarkVideoWidth = 1920;
const benchmarkVideoHeight = 1080;
const benchmarkVideoDurationSeconds = int.fromEnvironment(
  'BENCH_VIDEO_DURATION_SECONDS',
  defaultValue: 3,
);
const benchmarkPass = String.fromEnvironment('BENCH_PASS', defaultValue: 'A');
const benchmarkPlatform = String.fromEnvironment(
  'BENCH_PLATFORM',
  defaultValue: 'unknown',
);
const benchmarkDevice = String.fromEnvironment(
  'BENCH_DEVICE',
  defaultValue: 'unknown',
);
const benchmarkFlutterVersion = String.fromEnvironment(
  'BENCH_FLUTTER_VERSION',
  defaultValue: 'not-specified',
);
const benchmarkCoreSha256 = String.fromEnvironment(
  'BENCH_CORE_SHA256',
  defaultValue: 'not-specified',
);
const benchmarkConfirmationOperation = String.fromEnvironment(
  'BENCH_CONFIRM_OPERATION',
);
const benchmarkNotMeasuredOperationIds = String.fromEnvironment(
  'BENCH_NOT_MEASURED_OPERATIONS',
);
const benchmarkNotMeasuredReason = String.fromEnvironment(
  'BENCH_NOT_MEASURED_REASON',
);
const benchmarkPreflightOnly =
    String.fromEnvironment('BENCH_PREFLIGHT_ONLY') == 'true';

class BenchmarkSessionResult {
  const BenchmarkSessionResult({
    required this.returnCode,
    required this.wallMicroseconds,
    this.durationMilliseconds,
    this.logs = '',
  });

  final int? returnCode;
  final int wallMicroseconds;
  final int? durationMilliseconds;
  final String logs;
}

class BenchmarkProbeResult {
  const BenchmarkProbeResult({required this.returnCode, required this.logs});

  final int? returnCode;
  final String logs;
}

abstract interface class BenchmarkAdapter {
  String get packageId;
  String get packageVersion;
  String get expectedNativeAbi;
  String get bundleSelector;

  Future<void> initialize();
  Future<BenchmarkSessionResult> execute(List<String> arguments);
  Future<BenchmarkProbeResult> probe(String path);
  Future<String?> ffmpegVersion();
  Future<String?> nativePackageName();
  Future<String?> nativeBundleType();
  Future<List<String>> externalLibraries();
}

class _Operation {
  const _Operation({
    required this.id,
    required this.description,
    required this.arguments,
    required this.output,
    required this.input,
    this.expectedWidth,
    this.expectedHeight,
    this.expectedCodec,
    this.requiredEncoder,
    this.requiredDecoder,
    this.requiredFilters = const <String>[],
    this.requiresVideoFixture = false,
    this.requiresWebpFixture = false,
    this.rawRgbStill = false,
    this.syntheticInput = false,
  });

  final String id;
  final String description;
  final List<String> Function(_FixtureSet fixtures, String outputPath)
  arguments;
  final String? Function(String directory) output;
  final String? Function(_FixtureSet fixtures) input;
  final int? expectedWidth;
  final int? expectedHeight;
  final String? expectedCodec;
  final String? requiredEncoder;
  final String? requiredDecoder;
  final List<String> requiredFilters;
  final bool requiresVideoFixture;
  final bool requiresWebpFixture;
  final bool rawRgbStill;
  final bool syntheticInput;
}

class _FixtureSet {
  const _FixtureSet({
    required this.photoPath,
    required this.videoPath,
    required this.webpPath,
    required this.photoSha256,
    required this.photoBytes,
    required this.videoSha256,
    required this.videoBytes,
    required this.webpSha256,
    required this.webpBytes,
  });

  final String photoPath;
  final String videoPath;
  final String webpPath;
  final String photoSha256;
  final int photoBytes;
  final String? videoSha256;
  final int? videoBytes;
  final String? webpSha256;
  final int? webpBytes;

  Map<String, Object?> toJson() => <String, Object?>{
    'photo_sha256': photoSha256,
    'photo_bytes': photoBytes,
    'video_sha256': videoSha256,
    'video_bytes': videoBytes,
    'webp_decode_fixture_sha256': webpSha256,
    'webp_decode_fixture_bytes': webpBytes,
  };
}

class _FileFingerprint {
  const _FileFingerprint({required this.bytes, required this.sha256});

  final int bytes;
  final String sha256;
}

final _operations = <_Operation>[
  _Operation(
    id: 'webp_lossy',
    description: 'WebP lossy ${benchmarkStillWidth}x$benchmarkStillHeight',
    arguments: (fixtures, output) => <String>[
      '-y',
      '-i',
      fixtures.photoPath,
      '-c:v',
      'libwebp',
      '-quality',
      '82',
      '-pix_fmt',
      'yuv420p',
      output,
    ],
    output: (directory) => '$directory/webp-lossy.webp',
    input: (fixtures) => fixtures.photoPath,
    expectedWidth: benchmarkStillWidth,
    expectedHeight: benchmarkStillHeight,
    expectedCodec: 'webp',
    requiredEncoder: 'libwebp',
  ),
  _Operation(
    id: 'webp_lossless',
    description: 'WebP lossless ${benchmarkStillWidth}x$benchmarkStillHeight',
    arguments: (fixtures, output) => <String>[
      '-y',
      '-i',
      fixtures.photoPath,
      '-c:v',
      'libwebp',
      '-lossless',
      '1',
      '-compression_level',
      '4',
      output,
    ],
    output: (directory) => '$directory/webp-lossless.webp',
    input: (fixtures) => fixtures.photoPath,
    expectedWidth: benchmarkStillWidth,
    expectedHeight: benchmarkStillHeight,
    expectedCodec: 'webp',
    requiredEncoder: 'libwebp',
  ),
  _Operation(
    id: 'webp_decode',
    description: 'WebP decode to RGB24 raw frame',
    arguments: (fixtures, output) => <String>[
      '-y',
      '-i',
      fixtures.webpPath,
      '-frames:v',
      '1',
      '-pix_fmt',
      'rgb24',
      '-f',
      'rawvideo',
      output,
    ],
    output: (directory) => '$directory/webp-decode.rgb',
    input: (fixtures) => fixtures.webpPath,
    rawRgbStill: true,
    requiredDecoder: 'webp',
    requiresWebpFixture: true,
  ),
  _Operation(
    id: 'jpeg',
    description: 'JPEG still ${benchmarkStillWidth}x$benchmarkStillHeight',
    arguments: (fixtures, output) => <String>[
      '-y',
      '-i',
      fixtures.photoPath,
      '-q:v',
      '4',
      '-frames:v',
      '1',
      '-update',
      '1',
      output,
    ],
    output: (directory) => '$directory/still.jpg',
    input: (fixtures) => fixtures.photoPath,
    expectedWidth: benchmarkStillWidth,
    expectedHeight: benchmarkStillHeight,
    expectedCodec: 'mjpeg',
    requiredEncoder: 'mjpeg',
  ),
  _Operation(
    id: 'png',
    description: 'PNG still ${benchmarkStillWidth}x$benchmarkStillHeight',
    arguments: (fixtures, output) => <String>[
      '-y',
      '-i',
      fixtures.photoPath,
      '-frames:v',
      '1',
      '-update',
      '1',
      '-compression_level',
      '6',
      output,
    ],
    output: (directory) => '$directory/still.png',
    input: (fixtures) => fixtures.photoPath,
    expectedWidth: benchmarkStillWidth,
    expectedHeight: benchmarkStillHeight,
    expectedCodec: 'png',
    requiredEncoder: 'png',
  ),
  _Operation(
    id: 'avif',
    description: 'AVIF still via libaom-av1',
    arguments: (fixtures, output) => <String>[
      '-y',
      '-i',
      fixtures.photoPath,
      '-frames:v',
      '1',
      '-c:v',
      'libaom-av1',
      '-still-picture',
      '1',
      '-crf',
      '30',
      '-b:v',
      '0',
      '-cpu-used',
      '7',
      '-pix_fmt',
      'yuv420p',
      output,
    ],
    output: (directory) => '$directory/still.avif',
    input: (fixtures) => fixtures.photoPath,
    expectedWidth: benchmarkStillWidth,
    expectedHeight: benchmarkStillHeight,
    expectedCodec: 'av1',
    requiredEncoder: 'libaom-av1',
  ),
  _Operation(
    id: 'h264',
    description: 'H.264 video via libopenh264',
    arguments: (fixtures, output) => <String>[
      '-y',
      '-i',
      fixtures.videoPath,
      '-c:v',
      'libopenh264',
      '-qmin',
      '28',
      '-qmax',
      '28',
      '-an',
      output,
    ],
    output: (directory) => '$directory/video-h264.mp4',
    input: (fixtures) => fixtures.videoPath,
    expectedWidth: benchmarkVideoWidth,
    expectedHeight: benchmarkVideoHeight,
    expectedCodec: 'h264',
    requiredEncoder: 'libopenh264',
    requiresVideoFixture: true,
  ),
  _Operation(
    id: 'h265',
    description: 'H.265 video via libkvazaar',
    arguments: (fixtures, output) => <String>[
      '-y',
      '-i',
      fixtures.videoPath,
      '-c:v',
      'libkvazaar',
      '-kvazaar-params',
      'qp=28,preset=veryfast',
      '-an',
      output,
    ],
    output: (directory) => '$directory/video-h265.mp4',
    input: (fixtures) => fixtures.videoPath,
    expectedWidth: benchmarkVideoWidth,
    expectedHeight: benchmarkVideoHeight,
    expectedCodec: 'hevc',
    requiredEncoder: 'libkvazaar',
    requiresVideoFixture: true,
  ),
  _Operation(
    id: 'av1_video',
    description: 'AV1 video via libaom-av1',
    arguments: (fixtures, output) => <String>[
      '-y',
      '-i',
      fixtures.videoPath,
      '-c:v',
      'libaom-av1',
      '-crf',
      '35',
      '-b:v',
      '0',
      '-cpu-used',
      '7',
      '-row-mt',
      '1',
      '-an',
      output,
    ],
    output: (directory) => '$directory/video-av1.mp4',
    input: (fixtures) => fixtures.videoPath,
    expectedWidth: benchmarkVideoWidth,
    expectedHeight: benchmarkVideoHeight,
    expectedCodec: 'av1',
    requiredEncoder: 'libaom-av1',
    requiresVideoFixture: true,
  ),
  _Operation(
    id: 'gif',
    description: 'GIF palette filter path',
    arguments: (fixtures, output) => <String>[
      '-y',
      '-i',
      fixtures.videoPath,
      '-filter_complex',
      '[0:v]fps=15,scale=-1:480:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse',
      '-loop',
      '0',
      '-an',
      output,
    ],
    output: (directory) => '$directory/animated.gif',
    input: (fixtures) => fixtures.videoPath,
    expectedHeight: 480,
    expectedCodec: 'gif',
    requiredEncoder: 'gif',
    requiredFilters: <String>['palettegen', 'paletteuse'],
    requiresVideoFixture: true,
  ),
];

final _syntheticVideoOperations = <_Operation>[
  _Operation(
    id: 'h264_lavfi',
    description: 'H.264 via libopenh264 from direct testsrc2 input',
    arguments: (fixtures, output) => <String>[
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=${benchmarkVideoWidth}x$benchmarkVideoHeight:duration=$benchmarkVideoDurationSeconds:rate=30',
      '-c:v',
      'libopenh264',
      '-qmin',
      '28',
      '-qmax',
      '28',
      '-an',
      output,
    ],
    output: (directory) => '$directory/video-h264-lavfi.mp4',
    input: (fixtures) => null,
    expectedWidth: benchmarkVideoWidth,
    expectedHeight: benchmarkVideoHeight,
    expectedCodec: 'h264',
    requiredEncoder: 'libopenh264',
    syntheticInput: true,
  ),
  _Operation(
    id: 'h265_lavfi',
    description: 'H.265 via libkvazaar from direct testsrc2 input',
    arguments: (fixtures, output) => <String>[
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=${benchmarkVideoWidth}x$benchmarkVideoHeight:duration=$benchmarkVideoDurationSeconds:rate=30',
      '-c:v',
      'libkvazaar',
      '-kvazaar-params',
      'qp=28,preset=veryfast',
      '-an',
      output,
    ],
    output: (directory) => '$directory/video-h265-lavfi.mp4',
    input: (fixtures) => null,
    expectedWidth: benchmarkVideoWidth,
    expectedHeight: benchmarkVideoHeight,
    expectedCodec: 'hevc',
    requiredEncoder: 'libkvazaar',
    syntheticInput: true,
  ),
  _Operation(
    id: 'av1_video_lavfi',
    description: 'AV1 via libaom-av1 from direct testsrc2 input',
    arguments: (fixtures, output) => <String>[
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=${benchmarkVideoWidth}x$benchmarkVideoHeight:duration=$benchmarkVideoDurationSeconds:rate=30',
      '-c:v',
      'libaom-av1',
      '-crf',
      '35',
      '-b:v',
      '0',
      '-cpu-used',
      '7',
      '-row-mt',
      '1',
      '-an',
      output,
    ],
    output: (directory) => '$directory/video-av1-lavfi.mp4',
    input: (fixtures) => null,
    expectedWidth: benchmarkVideoWidth,
    expectedHeight: benchmarkVideoHeight,
    expectedCodec: 'av1',
    requiredEncoder: 'libaom-av1',
    syntheticInput: true,
  ),
  _Operation(
    id: 'gif_lavfi',
    description: 'GIF palette filter from direct testsrc2 input',
    arguments: (fixtures, output) => <String>[
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=${benchmarkVideoWidth}x$benchmarkVideoHeight:duration=$benchmarkVideoDurationSeconds:rate=30',
      '-filter_complex',
      '[0:v]fps=15,scale=-1:480:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse',
      '-loop',
      '0',
      '-an',
      output,
    ],
    output: (directory) => '$directory/animated-lavfi.gif',
    input: (fixtures) => null,
    expectedHeight: 480,
    expectedCodec: 'gif',
    requiredEncoder: 'gif',
    requiredFilters: <String>['palettegen', 'paletteuse'],
    syntheticInput: true,
  ),
];

Future<void> runBenchmarkHarness(BenchmarkAdapter adapter) async {
  await adapter.initialize();

  String versionOutput = '';
  for (var index = 0; index < 5; index++) {
    final result = await adapter.execute(<String>[
      '-hide_banner',
      '-loglevel',
      'verbose',
      '-version',
    ]);
    _requireSuccess(result, 'FFmpeg -version warm-up ${index + 1}');
    if (index == 0) {
      versionOutput = result.logs;
      print('FFK_VERSION_OUTPUT_BEGIN');
      print(versionOutput);
      print('FFK_VERSION_OUTPUT_END');
    }
  }
  final encoderFailures = await _probeEncoders(adapter);

  final directory = await getTemporaryDirectory();
  final workDirectory = Directory(
    '${directory.path}${Platform.pathSeparator}ffk-native-bench-$benchmarkRunId-${adapter.packageId}',
  );
  if (workDirectory.existsSync()) {
    await workDirectory.delete(recursive: true);
  }
  await workDirectory.create(recursive: true);

  final photoPath = '${workDirectory.path}${Platform.pathSeparator}src.png';
  final videoPath = '${workDirectory.path}${Platform.pathSeparator}src.mp4';
  final webpPath =
      '${workDirectory.path}${Platform.pathSeparator}decode-fixture.webp';
  await _runFixtureCommand(adapter, <String>[
    '-y',
    '-f',
    'lavfi',
    '-i',
    'testsrc2=size=${benchmarkStillWidth}x$benchmarkStillHeight:duration=1:rate=1',
    '-frames:v',
    '1',
    '-update',
    '1',
    photoPath,
  ], 'photo fixture');
  String? videoFixtureIssue;
  if (!encoderFailures.containsKey('encoder:libopenh264')) {
    try {
      await _runFixtureCommand(adapter, <String>[
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=${benchmarkVideoWidth}x$benchmarkVideoHeight:duration=$benchmarkVideoDurationSeconds:rate=30',
        '-c:v',
        'libopenh264',
        '-qmin',
        '24',
        '-qmax',
        '24',
        videoPath,
      ], 'video fixture');
    } on StateError catch (error) {
      videoFixtureIssue = error.message;
    }
  } else {
    videoFixtureIssue = 'fixture encoder libopenh264 is unavailable';
  }

  String? webpFixtureIssue;
  if (!encoderFailures.containsKey('encoder:libwebp')) {
    try {
      await _runFixtureCommand(adapter, <String>[
        '-y',
        '-i',
        photoPath,
        '-c:v',
        'libwebp',
        '-quality',
        '82',
        '-pix_fmt',
        'yuv420p',
        webpPath,
      ], 'WebP decode fixture');
    } on StateError catch (error) {
      webpFixtureIssue = error.message;
    }
  } else {
    webpFixtureIssue = 'fixture encoder libwebp is unavailable';
  }

  final photo = await _fingerprint(File(photoPath));
  final video = videoFixtureIssue == null
      ? await _fingerprint(File(videoPath))
      : null;
  final webp = webpFixtureIssue == null
      ? await _fingerprint(File(webpPath))
      : null;
  final capabilities = await _readCapabilities(
    adapter,
    encoderFailures,
    webpFixtureAvailable: webp != null,
    webpPath: webpPath,
    webpFixtureIssue: webpFixtureIssue,
  );
  final fixtures = _FixtureSet(
    photoPath: photoPath,
    videoPath: videoPath,
    webpPath: webpPath,
    photoSha256: photo.sha256,
    photoBytes: photo.bytes,
    videoSha256: video?.sha256,
    videoBytes: video?.bytes,
    webpSha256: webp?.sha256,
    webpBytes: webp?.bytes,
  );

  final allOperations = <_Operation>[
    ..._operations,
    ..._syntheticVideoOperations,
  ];
  final requestedNotMeasured = parseBenchmarkNotMeasuredOperations(
    benchmarkNotMeasuredOperationIds,
    benchmarkNotMeasuredReason,
  );
  final operationsById = <String, _Operation>{
    for (final operation in allOperations) operation.id: operation,
  };
  final unknownNotMeasuredIds = requestedNotMeasured.keys
      .where((id) => !operationsById.containsKey(id))
      .toList(growable: false);
  if (unknownNotMeasuredIds.isNotEmpty) {
    throw ArgumentError.value(
      unknownNotMeasuredIds,
      'BENCH_NOT_MEASURED_OPERATIONS',
      'contains unknown benchmark operations',
    );
  }
  final notMeasuredOperations = <_Operation, String>{
    for (final entry in requestedNotMeasured.entries)
      operationsById[entry.key]!: entry.value,
  };
  final unsupportedOperations = <_Operation, String>{};
  for (final operation in allOperations) {
    final reason = _operationSkipReason(
      operation,
      capabilities,
      fixtures,
      videoFixtureIssue: videoFixtureIssue,
      webpFixtureIssue: webpFixtureIssue,
    );
    if (reason != null) unsupportedOperations[operation] = reason;
  }

  final metadata = <String, Object?>{
    'schema_version': 1,
    'run_id': benchmarkRunId,
    'package_id': adapter.packageId,
    'package_version': adapter.packageVersion,
    'native_abi_expected': adapter.expectedNativeAbi,
    'bundle_selector': adapter.bundleSelector,
    'ffmpeg_version': await adapter.ffmpegVersion(),
    'ffmpeg_version_output_first_run': versionOutput,
    'diagnostic_log_level':
        'verbose for unmeasured operation warm-ups; measured commands use default level',
    'native_package_name': await adapter.nativePackageName(),
    'native_bundle_type': await adapter.nativeBundleType(),
    'external_libraries': await adapter.externalLibraries(),
    'platform': benchmarkPlatform,
    'os': Platform.operatingSystem,
    'os_version': Platform.operatingSystemVersion,
    'device': benchmarkDevice,
    'device_architecture': Abi.current().toString(),
    'flutter_version': benchmarkFlutterVersion,
    'dart_version': Platform.version,
    'execution_mode': 'flutter test integration_test (device test mode)',
    'pass': benchmarkPass,
    'preflight_only': benchmarkPreflightOnly,
    'benchmark_core_sha256': benchmarkCoreSha256,
    'ffmpeg_capabilities': capabilities.toJson(),
    'fixture_issues': <String, String?>{
      ...?(videoFixtureIssue == null
          ? null
          : <String, String?>{'video': videoFixtureIssue}),
      ...?(webpFixtureIssue == null
          ? null
          : <String, String?>{'webp_decode': webpFixtureIssue}),
    },
    'unsupported_operations': <String, String>{
      for (final entry in unsupportedOperations.entries)
        entry.key.id: entry.value,
    },
    'not_measured_operations': <String, String>{
      for (final entry in notMeasuredOperations.entries)
        entry.key.id: entry.value,
    },
    'fixtures': fixtures.toJson(),
    'workload': <String, Object>{
      'still_width': benchmarkStillWidth,
      'still_height': benchmarkStillHeight,
      'still_megapixels': benchmarkStillWidth * benchmarkStillHeight / 1000000,
      'video_width': benchmarkVideoWidth,
      'video_height': benchmarkVideoHeight,
      'video_duration_seconds': benchmarkVideoDurationSeconds,
      'video_frames_at_30fps': benchmarkVideoDurationSeconds * 30,
    },
  };
  print('FFK_META:${jsonEncode(metadata)}');
  print(
    'FFK_FIXTURE:${jsonEncode(<String, Object?>{'schema_version': 1, 'run_id': benchmarkRunId, 'package_id': adapter.packageId, 'platform': benchmarkPlatform, ...fixtures.toJson()})}',
  );
  for (final entry in unsupportedOperations.entries) {
    _emitUnsupported(adapter, entry.key, entry.value);
  }
  for (final entry in notMeasuredOperations.entries) {
    _emitNotMeasured(adapter, entry.key, entry.value);
  }

  if (benchmarkPreflightOnly) return;

  if (benchmarkConfirmationOperation.isNotEmpty) {
    final operation = _operationById(benchmarkConfirmationOperation);
    final unsupportedReason = unsupportedOperations[operation];
    if (unsupportedReason != null ||
        notMeasuredOperations.containsKey(operation)) {
      return;
    }
    await _runOperationWarmup(adapter, operation, fixtures, workDirectory.path);
    for (var sample = 1; sample <= 5; sample++) {
      await _runOperationSample(
        adapter,
        operation,
        fixtures,
        workDirectory.path,
        pass: 'C',
        sample: sample,
        confirmation: true,
      );
    }
    await _validateOperation(adapter, operation, fixtures, workDirectory.path);
    return;
  }

  final supportedOperations = allOperations
      .where(
        (operation) =>
            !unsupportedOperations.containsKey(operation) &&
            !notMeasuredOperations.containsKey(operation),
      )
      .toList(growable: false);
  final operations = benchmarkPass.toUpperCase() == 'B'
      ? supportedOperations.reversed.toList(growable: false)
      : supportedOperations;
  for (final operation in operations) {
    await _runOperationWarmup(adapter, operation, fixtures, workDirectory.path);
    for (var sample = 1; sample <= 3; sample++) {
      await _runOperationSample(
        adapter,
        operation,
        fixtures,
        workDirectory.path,
        pass: benchmarkPass,
        sample: sample,
      );
    }
    await _validateOperation(adapter, operation, fixtures, workDirectory.path);
  }

  if (benchmarkPass.toUpperCase() == 'A') {
    if (capabilities.encoders.contains('png')) {
      await _runWrapperControls(adapter, workDirectory.path);
    } else {
      print(
        'FFK_UNSUPPORTED:${jsonEncode(<String, Object?>{'schema_version': 1, 'run_id': benchmarkRunId, 'package_id': adapter.packageId, 'platform': benchmarkPlatform, 'operation': 'wrapper_png_controls', 'reason': 'encoder png is unavailable'})}',
      );
    }
  }
}

_Operation _operationById(String id) =>
    <_Operation>[..._operations, ..._syntheticVideoOperations].firstWhere(
      (operation) => operation.id == id,
      orElse: () => throw ArgumentError.value(id, 'BENCH_CONFIRM_OPERATION'),
    );

const _probedEncoders = <String>{
  'gif',
  'libaom-av1',
  'libkvazaar',
  'libopenh264',
  'libwebp',
  'mjpeg',
  'png',
};

Future<Map<String, String>> _probeEncoders(BenchmarkAdapter adapter) async {
  final failures = <String, String>{};
  for (final encoder in _probedEncoders) {
    final arguments = <String>[
      '-hide_banner',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=32x32:duration=0.2:rate=5',
      '-frames:v',
      '1',
      '-c:v',
      encoder,
      if (encoder == 'libaom-av1') ...<String>[
        '-crf',
        '35',
        '-b:v',
        '0',
        '-cpu-used',
        '7',
      ],
      if (encoder == 'libkvazaar') ...<String>[
        '-kvazaar-params',
        'qp=28,preset=veryfast',
      ],
      if (encoder == 'libopenh264') ...<String>['-qmin', '24', '-qmax', '24'],
      if (encoder == 'libwebp') ...<String>[
        '-quality',
        '82',
        '-pix_fmt',
        'yuv420p',
      ],
      '-f',
      'null',
      '-',
    ];
    final result = await adapter.execute(arguments);
    if (result.returnCode != 0) {
      failures['encoder:$encoder'] = _probeFailure(result);
    }
  }
  return failures;
}

Future<FfmpegCapabilities> _readCapabilities(
  BenchmarkAdapter adapter,
  Map<String, String> encoderFailures, {
  required bool webpFixtureAvailable,
  required String webpPath,
  required String? webpFixtureIssue,
}) async {
  final failures = <String, String>{...encoderFailures};
  final encoders = _probedEncoders
      .where((encoder) => !failures.containsKey('encoder:$encoder'))
      .toSet();

  final decoders = <String>{};
  if (webpFixtureAvailable) {
    final result = await adapter.execute(<String>[
      '-hide_banner',
      '-i',
      webpPath,
      '-frames:v',
      '1',
      '-f',
      'null',
      '-',
    ]);
    if (result.returnCode == 0) {
      decoders.add('webp');
    } else {
      failures['decoder:webp'] = _probeFailure(result);
    }
  } else {
    failures['decoder:webp'] =
        'decoder probe unavailable because the WebP fixture failed: '
        '${webpFixtureIssue ?? 'fixture missing'}';
  }

  final filters = <String>{};
  final filterProbe = await adapter.execute(<String>[
    '-hide_banner',
    '-f',
    'lavfi',
    '-i',
    'testsrc2=size=32x32:duration=0.2:rate=5',
    '-filter_complex',
    '[0:v]fps=15,scale=-1:32:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse',
    '-frames:v',
    '1',
    '-f',
    'null',
    '-',
  ]);
  if (filterProbe.returnCode == 0) {
    filters.addAll(<String>['palettegen', 'paletteuse']);
  } else {
    final reason = _probeFailure(filterProbe);
    failures['filter:palettegen'] = reason;
    failures['filter:paletteuse'] = reason;
  }

  return FfmpegCapabilities(
    encoders: encoders,
    decoders: decoders,
    filters: filters,
    failures: failures,
  );
}

String _probeFailure(BenchmarkSessionResult result) {
  final lines = result.logs
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim().replaceAll(RegExp(r'\s+'), ' '))
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) return 'probe returned code ${result.returnCode}';
  final diagnostic = lines.lastWhere(
    (line) =>
        line.contains('Unknown encoder') ||
        line.contains('No such filter') ||
        line.contains('not found') ||
        line.contains('not available'),
    orElse: () => lines.last,
  );
  return diagnostic.length <= 240
      ? diagnostic
      : '${diagnostic.substring(0, 237)}...';
}

String? _operationSkipReason(
  _Operation operation,
  FfmpegCapabilities capabilities,
  _FixtureSet fixtures, {
  required String? videoFixtureIssue,
  required String? webpFixtureIssue,
}) {
  final missing = capabilities.missingRequirement(
    encoder: operation.requiredEncoder,
    decoder: operation.requiredDecoder,
    requiredFilters: operation.requiredFilters,
  );
  if (missing != null) return missing;
  if (operation.requiresVideoFixture && fixtures.videoSha256 == null) {
    return videoFixtureIssue ?? 'required video fixture is unavailable';
  }
  if (operation.requiresWebpFixture && fixtures.webpSha256 == null) {
    return webpFixtureIssue ?? 'required WebP decode fixture is unavailable';
  }
  return null;
}

void _emitUnsupported(
  BenchmarkAdapter adapter,
  _Operation operation,
  String reason,
) {
  print(
    'FFK_UNSUPPORTED:${jsonEncode(<String, Object?>{'schema_version': 1, 'run_id': benchmarkRunId, 'package_id': adapter.packageId, 'platform': benchmarkPlatform, 'operation': operation.id, 'reason': reason})}',
  );
}

void _emitNotMeasured(
  BenchmarkAdapter adapter,
  _Operation operation,
  String reason,
) {
  print(
    'FFK_NOT_MEASURED:${jsonEncode(<String, Object?>{'schema_version': 1, 'run_id': benchmarkRunId, 'package_id': adapter.packageId, 'platform': benchmarkPlatform, 'operation': operation.id, 'reason': reason})}',
  );
}

Future<void> _runFixtureCommand(
  BenchmarkAdapter adapter,
  List<String> arguments,
  String label,
) async {
  final result = await adapter.execute(arguments);
  _requireSuccess(result, label);
}

Future<void> _runOperationWarmup(
  BenchmarkAdapter adapter,
  _Operation operation,
  _FixtureSet fixtures,
  String directory,
) async {
  final outputPath = operation.output(directory);
  if (outputPath != null) {
    final output = File(outputPath);
    if (output.existsSync()) await output.delete();
  }
  final arguments = operation.arguments(fixtures, outputPath ?? '');
  final result = await adapter.execute(<String>[
    '-hide_banner',
    '-loglevel',
    'verbose',
    ...arguments,
  ]);
  print(
    'FFK_DIAGNOSTIC_LOG_BEGIN:${jsonEncode(<String, Object?>{'package_id': adapter.packageId, 'platform': benchmarkPlatform, 'operation': operation.id})}',
  );
  print(result.logs);
  print('FFK_DIAGNOSTIC_LOG_END');
  _requireSuccess(result, '${operation.id} unmeasured warm-up');
}

Future<void> _runOperationSample(
  BenchmarkAdapter adapter,
  _Operation operation,
  _FixtureSet fixtures,
  String directory, {
  required String pass,
  required int sample,
  bool confirmation = false,
}) async {
  final outputPath = operation.output(directory);
  if (outputPath != null) {
    final output = File(outputPath);
    if (output.existsSync()) await output.delete();
  }
  final arguments = operation.arguments(fixtures, outputPath ?? '');
  final result = await adapter.execute(arguments);
  _requireSuccess(result, '${operation.id} pass $pass sample $sample');

  _FileFingerprint? fingerprint;
  if (outputPath != null) {
    final output = File(outputPath);
    if (!await output.exists()) {
      throw StateError('${operation.id} did not create $outputPath');
    }
    fingerprint = await _fingerprint(output);
    if (fingerprint.bytes <= 0) {
      throw StateError('${operation.id} created an empty output');
    }
    final expectedRawRgbBytes = benchmarkStillWidth * benchmarkStillHeight * 3;
    if (operation.rawRgbStill && fingerprint.bytes != expectedRawRgbBytes) {
      throw StateError(
        'Decoded RGB byte count ${fingerprint.bytes} != $expectedRawRgbBytes',
      );
    }
  }

  _emitSample(<String, Object?>{
    'schema_version': 1,
    'run_id': benchmarkRunId,
    'platform': benchmarkPlatform,
    'device': benchmarkDevice,
    'device_architecture': Abi.current().toString(),
    'package_id': adapter.packageId,
    'package_version': adapter.packageVersion,
    'operation': operation.id,
    'description': operation.description,
    'pass': pass,
    'sample': sample,
    'confirmation': confirmation,
    'arguments': arguments,
    'wall_us': result.wallMicroseconds,
    'session_duration_ms': result.durationMilliseconds,
    'return_code': result.returnCode,
    'input_path': operation.input(fixtures),
    'input_sha256': _inputHash(operation, fixtures),
    'synthetic_input': operation.syntheticInput,
    'output_path': outputPath,
    'output_bytes': fingerprint?.bytes,
    'output_sha256': fingerprint?.sha256,
    'fixture_photo_sha256': fixtures.photoSha256,
    'fixture_video_sha256': fixtures.videoSha256,
    'fixture_webp_sha256': fixtures.webpSha256,
  });
}

String? _inputHash(_Operation operation, _FixtureSet fixtures) {
  final inputPath = operation.input(fixtures);
  if (inputPath == null) return null;
  if (inputPath == fixtures.photoPath) {
    return fixtures.photoSha256;
  }
  if (inputPath == fixtures.videoPath) {
    return fixtures.videoSha256;
  }
  if (inputPath == fixtures.webpPath) {
    return fixtures.webpSha256;
  }
  return null;
}

Future<void> _validateOperation(
  BenchmarkAdapter adapter,
  _Operation operation,
  _FixtureSet fixtures,
  String directory,
) async {
  final outputPath = operation.output(directory);
  if (outputPath == null) return;
  if (operation.rawRgbStill) {
    final actual = await File(outputPath).length();
    final expectedRawRgbBytes = benchmarkStillWidth * benchmarkStillHeight * 3;
    if (actual != expectedRawRgbBytes) {
      throw StateError('${operation.id} output is $actual bytes');
    }
    print(
      'FFK_VALIDATION:${jsonEncode(<String, Object?>{'operation': operation.id, 'bytes': actual, 'expected_bytes': expectedRawRgbBytes, 'status': 'valid'})}',
    );
    return;
  }

  final probe = await adapter.probe(outputPath);
  if (probe.returnCode != 0) {
    throw StateError('${operation.id} FFprobe returned ${probe.returnCode}');
  }
  final jsonText = _extractJson(probe.logs);
  final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
  final streams = decoded['streams'] as List<dynamic>? ?? const <dynamic>[];
  final stream = streams.cast<Map<String, dynamic>>().firstWhere(
    (entry) => entry['codec_type'] == 'video',
    orElse: () => <String, dynamic>{},
  );
  if (stream.isEmpty) throw StateError('${operation.id} has no video stream');
  if (operation.expectedWidth != null &&
      stream['width'] != operation.expectedWidth) {
    throw StateError('${operation.id} width=${stream['width']}');
  }
  if (operation.expectedHeight != null &&
      stream['height'] != operation.expectedHeight) {
    throw StateError('${operation.id} height=${stream['height']}');
  }
  if (operation.expectedCodec != null &&
      stream['codec_name'] != operation.expectedCodec) {
    throw StateError('${operation.id} codec=${stream['codec_name']}');
  }
  final format = decoded['format'] as Map<String, dynamic>?;
  final duration = double.tryParse('${format?['duration'] ?? ''}');
  if ((operation.id == 'h264' ||
          operation.id == 'h265' ||
          operation.id == 'av1_video' ||
          operation.id == 'gif' ||
          operation.id == 'h264_lavfi' ||
          operation.id == 'h265_lavfi' ||
          operation.id == 'av1_video_lavfi' ||
          operation.id == 'gif_lavfi') &&
      (duration == null ||
          duration < benchmarkVideoDurationSeconds - 0.2 ||
          duration > benchmarkVideoDurationSeconds + 0.2)) {
    throw StateError('${operation.id} duration=$duration');
  }
  print(
    'FFK_VALIDATION:${jsonEncode(<String, Object?>{'operation': operation.id, 'width': stream['width'], 'height': stream['height'], 'codec': stream['codec_name'], 'duration_seconds': duration, 'output_bytes': await File(outputPath).length(), 'status': 'valid'})}',
  );
}

String _extractJson(String logs) {
  final start = logs.indexOf('{');
  final end = logs.lastIndexOf('}');
  if (start < 0 || end < start) {
    throw FormatException('FFprobe did not return JSON: $logs');
  }
  return logs.substring(start, end + 1);
}

Future<void> _runWrapperControls(
  BenchmarkAdapter adapter,
  String directory,
) async {
  for (var sample = 1; sample <= 50; sample++) {
    final versionArguments = <String>[
      '-hide_banner',
      '-loglevel',
      'verbose',
      '-version',
    ];
    final result = await adapter.execute(versionArguments);
    _requireSuccess(result, 'wrapper version control $sample');
    _emitControl(adapter, 'wrapper_version', sample, result, versionArguments);
  }

  await _runPngControl(adapter, directory, 'wrapper_png_64x64', 64, 64, 30);
  await _runPngControl(adapter, directory, 'wrapper_png_640x480', 640, 480, 20);
}

Future<void> _runPngControl(
  BenchmarkAdapter adapter,
  String directory,
  String id,
  int width,
  int height,
  int count,
) async {
  final outputPath = '$directory/$id.png';
  final arguments = <String>[
    '-hide_banner',
    '-y',
    '-f',
    'lavfi',
    '-i',
    'testsrc2=size=${width}x$height:duration=1:rate=1',
    '-frames:v',
    '1',
    '-update',
    '1',
    outputPath,
  ];
  final output = File(outputPath);
  if (output.existsSync()) await output.delete();
  final warmup = await adapter.execute(arguments);
  _requireSuccess(warmup, '$id unmeasured warm-up');
  for (var sample = 1; sample <= count; sample++) {
    if (output.existsSync()) await output.delete();
    final result = await adapter.execute(arguments);
    _requireSuccess(result, '$id sample $sample');
    final fingerprint = await _fingerprint(output);
    _emitSample(<String, Object?>{
      'schema_version': 1,
      'run_id': benchmarkRunId,
      'platform': benchmarkPlatform,
      'device': benchmarkDevice,
      'device_architecture': Abi.current().toString(),
      'package_id': adapter.packageId,
      'package_version': adapter.packageVersion,
      'operation': id,
      'pass': benchmarkPass,
      'sample': sample,
      'arguments': arguments,
      'wall_us': result.wallMicroseconds,
      'session_duration_ms': result.durationMilliseconds,
      'return_code': result.returnCode,
      'output_path': outputPath,
      'output_bytes': fingerprint.bytes,
      'output_sha256': fingerprint.sha256,
    });
  }
  final probe = await adapter.probe(outputPath);
  if (probe.returnCode != 0) throw StateError('$id FFprobe failed');
  final decoded = jsonDecode(_extractJson(probe.logs)) as Map<String, dynamic>;
  final stream = (decoded['streams'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .first;
  if (stream['width'] != width || stream['height'] != height) {
    throw StateError('$id dimensions=${stream['width']}x${stream['height']}');
  }
}

void _emitControl(
  BenchmarkAdapter adapter,
  String operation,
  int sample,
  BenchmarkSessionResult result,
  List<String> arguments,
) {
  _emitSample(<String, Object?>{
    'schema_version': 1,
    'run_id': benchmarkRunId,
    'platform': benchmarkPlatform,
    'device': benchmarkDevice,
    'device_architecture': Abi.current().toString(),
    'package_id': adapter.packageId,
    'package_version': adapter.packageVersion,
    'operation': operation,
    'pass': benchmarkPass,
    'sample': sample,
    'arguments': arguments,
    'wall_us': result.wallMicroseconds,
    'session_duration_ms': result.durationMilliseconds,
    'return_code': result.returnCode,
  });
}

Future<_FileFingerprint> _fingerprint(File file) async {
  final bytes = await file.readAsBytes();
  return _FileFingerprint(
    bytes: bytes.length,
    sha256: sha256.convert(bytes).toString(),
  );
}

void _requireSuccess(BenchmarkSessionResult result, String operation) {
  if (result.returnCode != 0) {
    final excerpt = result.logs.length > 3000
        ? result.logs.substring(result.logs.length - 3000)
        : result.logs;
    throw StateError('$operation failed rc=${result.returnCode}\n$excerpt');
  }
}

void _emitSample(Map<String, Object?> record) {
  print('FFK_BENCH:${jsonEncode(record)}');
}
