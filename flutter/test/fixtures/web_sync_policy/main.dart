// Phase 3 Web sync-request policy fixture (plan §P3.0a, W-F01 to W-F03).
//
// Built as a test entry for the Flutter Web wasm target. It calls the public
// synchronous APIs against the local fixture server and publishes one JSON
// report on globalThis.CODEX_phase3PolicyResult. It is test build output only.

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:ffmpeg_kit_extended_flutter/src/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffmpeg_kit_extended.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffmpeg_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffplay_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffprobe_kit.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/web/ffmpeg_kit_web_files.dart';
import 'package:ffmpeg_kit_extended_flutter/src/session.dart';

@JS('globalThis')
external JSObject get _globalThis;

const _timeout = Duration(seconds: 60);

Map<String, Object?> _case(
  String name,
  bool passed,
  String detail, {
  int? elapsedMs,
}) => {
  'name': name,
  'status': passed ? 'passed' : 'failed',
  'detail': detail,
  'elapsedMs': ?elapsedMs,
};

String _clip(String text) => text.length <= 600 ? text : text.substring(0, 600);

/// Runs [action], which must throw an UnsupportedError that names [replacement].
Map<String, Object?> _expectUnsupported(
  String name,
  String replacement,
  void Function() action,
) {
  final stopwatch = Stopwatch()..start();
  try {
    action();
  } catch (error) {
    final elapsed = stopwatch.elapsedMilliseconds;
    if (error is! UnsupportedError) {
      return _case(
        name,
        false,
        'unexpected ${error.runtimeType}: $error',
        elapsedMs: elapsed,
      );
    }
    final message = '${error.message}';
    return _case(
      name,
      message.contains(replacement),
      message,
      elapsedMs: elapsed,
    );
  }
  return _case(
    name,
    false,
    'no UnsupportedError was thrown',
    elapsedMs: stopwatch.elapsedMilliseconds,
  );
}

/// Checks the session left by a rejected synchronous FFmpeg execution.
///
/// Plan revision 5 (§P3.0a item 4): the native state may stay `created` because
/// no native execution happened. The check therefore requires `created`, which
/// proves that no C execute call ran, and the follow-up async case in [main]
/// proves the wrapper state is still usable.
Map<String, Object?> _rejectedSessionState(String name, String command) {
  final session = FFmpegSession.create(command);
  try {
    session.execute();
    return _case(name, false, 'no UnsupportedError was thrown');
  } catch (error) {
    if (error is! UnsupportedError) {
      return _case(name, false, 'unexpected ${error.runtimeType}: $error');
    }
    final state = session.getState();
    return _case(
      name,
      state == SessionState.created,
      'state=${state.name} error=${error.message}',
    );
  }
}

/// W-F04 (AUTH-FFPLAY-SYNC): the synchronous FFplay call is rejected on Web
/// before any backend call, so the native state stays created.
Map<String, Object?> _rejectedFFplayState(String name, String command) {
  final session = FFplaySession.create(command);
  try {
    // ignore: deprecated_member_use
    session.execute();
    return _case(name, false, 'no UnsupportedError was thrown');
  } catch (error) {
    if (error is! UnsupportedError) {
      return _case(name, false, 'unexpected ${error.runtimeType}: $error');
    }
    final message = '${error.message}';
    final state = session.getState();
    return _case(
      name,
      message.contains('FFplayKit.executeAsync') &&
          state == SessionState.created,
      'state=${state.name} error=$message',
    );
  }
}

Future<Uint8List> _fetchBytes(String url) async {
  final response = await _globalThis
      .callMethod<JSPromise<JSObject>>('fetch'.toJS, url.toJS)
      .toDart;
  if (!response.getProperty<JSBoolean>('ok'.toJS).toDart) {
    throw StateError('fetch failed for $url');
  }
  final buffer = await response
      .callMethod<JSPromise<JSArrayBuffer>>('arrayBuffer'.toJS)
      .toDart;
  return buffer.toDart.asUint8List();
}

void _publish(Map<String, Object?> report) {
  _globalThis.setProperty(
    'CODEX_phase3PolicyResult'.toJS,
    jsonEncode(report).toJS,
  );
}

Future<void> main() async {
  final fixture = Uri.base.queryParameters['fixture'];
  final cases = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'contract': 'flutter-web-sync-policy',
    'status': 'running',
    'fixture': fixture,
    'cases': cases,
  };

  try {
    if (fixture == null || fixture.isEmpty) {
      throw ArgumentError('The fixture query parameter is required.');
    }
    final origin = Uri.parse(fixture);
    if (origin.scheme != 'http' && origin.scheme != 'https') {
      throw ArgumentError('The fixture URL must use HTTP or HTTPS.');
    }
    await FFmpegKitExtended.initialize().timeout(_timeout);

    final progressive = origin.resolve('/media/progressive.mp4').toString();
    final hls = origin.resolve('/hls/master.m3u8').toString();

    // W-F01: direct HTTP and HLS input through the three synchronous APIs.
    cases.add(
      _expectUnsupported(
        'W-F01 FFmpegKit.execute direct HTTP',
        'FFmpegKit.executeAsync',
        () => FFmpegKit.execute(
          '-hide_banner -nostdin -i "$progressive" -t 1 -f null -',
        ),
      ),
    );
    cases.add(
      _expectUnsupported(
        'W-F01 FFprobeKit.execute direct HLS',
        'FFprobeKit.executeAsync',
        () => FFprobeKit.execute('-v error -show_format "$hls"'),
      ),
    );
    cases.add(
      _expectUnsupported(
        'W-F01 FFprobeKit.getMediaInformation direct HLS',
        'FFprobeKit.getMediaInformationAsync',
        () => FFprobeKit.getMediaInformation(hls),
      ),
    );
    cases.add(
      _expectUnsupported(
        'W-F01 chained scheme hls+http',
        'FFprobeKit.executeAsync',
        () => FFprobeKit.execute('-v error -i "hls+$hls"'),
      ),
    );
    cases.add(
      _rejectedSessionState(
        'W-F01 FFmpeg session state after rejection',
        '-hide_banner -nostdin -i "$progressive" -t 1 -f null -',
      ),
    );

    // W-F04: synchronous FFplay is rejected on Web before any backend call.
    cases.add(
      _rejectedFFplayState(
        'W-F04 FFplaySession.execute rejected on Web',
        '-hide_banner -loglevel info -i "$hls"',
      ),
    );

    // W-F02: a local playlist whose segments are remote. Pre-flight cannot see
    // these opens, so the module must fail them finitely with EPERM.
    final segment = origin.resolve('/hls/segment-0.ts').toString();
    final playlist =
        '#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:2\n'
        '#EXTINF:1.0,\n$segment\n#EXT-X-ENDLIST\n';
    FFmpegKitWebFiles.writeFile(
      '/tmp/w-f02-playlist.m3u8',
      Uint8List.fromList(utf8.encode(playlist)),
    );
    final localStopwatch = Stopwatch()..start();
    final indirect = FFprobeKit.execute(
      '-v error -show_format /tmp/w-f02-playlist.m3u8',
    );
    final indirectOutput = indirect.getOutput() ?? '';
    final indirectReturn = indirect.getReturnCode();
    final indirectState = indirect.getState();
    final sawEperm =
        indirectOutput.contains('EPERM') ||
        indirectOutput.contains('Operation not permitted') ||
        indirectOutput.contains('pthread');
    cases.add(
      _case(
        'W-F02 local playlist with remote segment fails finitely',
        indirectReturn != 0 &&
            (indirectState == SessionState.completed ||
                indirectState == SessionState.failed) &&
            sawEperm,
        'state=${indirectState.name} rc=$indirectReturn '
            'output=${_clip(indirectOutput)}',
        elapsedMs: localStopwatch.elapsedMilliseconds,
      ),
    );

    // W-F03: local/MEMFS input keeps its synchronous success.
    final mediaBytes = await _fetchBytes(
      origin.resolve('/media/d2-same-h264-aac.mp4').toString(),
    );
    FFmpegKitWebFiles.writeFile('/tmp/w-f03-input.mp4', mediaBytes);
    final probe = FFprobeKit.execute(
      '-v error -show_entries format=format_name -of json /tmp/w-f03-input.mp4',
    );
    cases.add(
      _case(
        'W-F03 local MEMFS FFprobe synchronous',
        probe.getState() == SessionState.completed &&
            probe.getReturnCode() == 0,
        'state=${probe.getState().name} rc=${probe.getReturnCode()}',
      ),
    );
    final copy = FFmpegKit.execute(
      '-hide_banner -nostdin -y -i /tmp/w-f03-input.mp4 -t 1 -c copy /tmp/w-f03-copy.mkv',
    );
    cases.add(
      _case(
        'W-F03 local MEMFS FFmpeg copy synchronous',
        copy.getState() == SessionState.completed && copy.getReturnCode() == 0,
        'state=${copy.getState().name} rc=${copy.getReturnCode()}',
      ),
    );

    // W-F01 consistency: after the rejections, the same wrapper must still run
    // async work to completion (no stuck queue, leaked lease or stale state).
    final afterRejection = await FFmpegKit.executeAsync(
      '-hide_banner -nostdin -y -i /tmp/w-f03-input.mp4 -t 1 -c copy /tmp/w-f01-async.mkv',
    ).timeout(_timeout);
    cases.add(
      _case(
        'W-F01 async execution succeeds after the rejections',
        afterRejection.getState() == SessionState.completed &&
            afterRejection.getReturnCode() == 0,
        'state=${afterRejection.getState().name} '
            'rc=${afterRejection.getReturnCode()}',
      ),
    );

    report['status'] = cases.every((item) => item['status'] == 'passed')
        ? 'passed'
        : 'failed';
  } catch (error, stackTrace) {
    report['status'] = 'failed';
    report['error'] = '$error';
    report['stackTrace'] = '$stackTrace';
  }

  _publish(report);
}
