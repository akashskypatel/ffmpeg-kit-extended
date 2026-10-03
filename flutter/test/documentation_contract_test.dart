import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final readme = File('README.md').readAsStringSync();
  final quickStart = File('doc/quick-start.md').readAsStringSync();
  final ffmpegApi = File('doc/api/ffmpeg-kit.md').readAsStringSync();
  final ffprobeApi = File('doc/api/ffprobe-kit.md').readAsStringSync();
  final ffplayApi = File('doc/api/ffplay-kit.md').readAsStringSync();
  final playbackGuide = File(
    'doc/guides/playback-control.md',
  ).readAsStringSync();
  final queueGuide = File(
    'doc/guides/session-queue-management.md',
  ).readAsStringSync();
  final errorGuide = File('doc/guides/error-handling.md').readAsStringSync();

  test('canonical Hooks installation example is valid YAML', () {
    final block = RegExp(r'```yaml\s*(.*?)```', dotAll: true)
        .allMatches(readme)
        .map((match) => match.group(1)!)
        .firstWhere(
          (candidate) =>
              candidate.contains('hooks:') &&
              candidate.contains('ffmpeg_kit_extended_flutter:'),
        );
    final parsed = loadYaml(block) as YamlMap;
    final packageConfig =
        (parsed['hooks'] as YamlMap)['user_defines'] as YamlMap;
    final pluginConfig =
        packageConfig['ffmpeg_kit_extended_flutter'] as YamlMap;

    expect(pluginConfig['type'], 'base');
    expect(pluginConfig['gpl'], true);
    expect(pluginConfig['small'], true);
  });

  test('bundle type documentation describes the legacy alias', () {
    expect(
      readme,
      contains(
        'The legacy `streaming` value is accepted as an alias for `video`.',
      ),
    );
    expect(
      quickStart,
      contains('The legacy `streaming` value is accepted as an alias for'),
    );
    expect(quickStart, contains('`video`.'));
  });

  test(
    'history references describe retained sessions rather than active-only lists',
    () {
      expect(
        ffmpegApi,
        contains('retained FFmpeg sessions in session history'),
      );
      expect(ffmpegApi, isNot(contains('Returns all active FFmpeg sessions')));
      expect(ffmpegApi, isNot(contains("print('Active sessions:")));
      expect(
        ffprobeApi,
        contains('retained FFprobe sessions in session history'),
      );
      expect(
        ffprobeApi,
        isNot(contains('Returns all active FFprobe sessions')),
      );
      expect(
        ffplayApi,
        contains('retained FFplay sessions in session history'),
      );
      expect(ffplayApi, isNot(contains('always a single element or empty')));
    },
  );

  test('queue and async-error guidance matches Future-based behavior', () {
    expect(queueGuide, contains('every active session'));
    expect(queueGuide, contains('queued execution Future'));
    expect(queueGuide, contains('unique by native session ID'));
    expect(queueGuide, contains('check `queueLength` separately'));
    expect(queueGuide, isNot(contains('most recent one added to active list')));
    expect(
      errorGuide,
      contains('Async Future errors versus terminal return codes'),
    );
    expect(errorGuide, contains('SessionCancelledException'));
    expect(errorGuide, contains('await FFmpegKit.executeAsync'));
  });

  test('FFplay lifecycle guidance matches the global-owner model', () {
    expect(ffplayApi, contains('current global control owner'));
    expect(ffplayApi, contains('FFmpegLogCallback? onLog'));
    expect(ffplayApi, contains('createSessionFromArguments'));
    expect(ffplayApi, contains('FFplaySession.dispose'));
    expect(ffplayApi, contains('Stop is distinct'));
    expect(
      ffplayApi,
      isNot(contains('Only one FFplay session can be active at a time')),
    );
    expect(
      ffplayApi,
      isNot(contains('Starting a new session automatically replaces')),
    );
    expect(playbackGuide, contains('current global control owner'));
    expect(playbackGuide, contains('FFplaySession.dispose'));
    expect(playbackGuide, isNot(contains('manages it as a singleton')));
  });
}
