import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:ffmpeg_kit_extended_flutter/src/platform/backend.dart';
import 'package:ffmpeg_kit_extended_flutter/src/platform/web/backend_web.dart';
import 'package:ffmpeg_kit_extended_flutter/src/session.dart' show SessionState;

@JS('globalThis')
external JSObject get _globalThis;

const _sessionTimeout = Duration(seconds: 30);
const _cleanupTimeout = Duration(seconds: 5);

bool _isTerminal(SessionState state) =>
    state == SessionState.completed || state == SessionState.failed;

Future<SessionState> _waitForTerminal(
  WebFFmpegKitBackend backend,
  SessionHandle handle,
  Duration timeout,
) async {
  final stopwatch = Stopwatch()..start();
  var state = SessionState.fromValue(backend.getSessionState(handle));
  while (!_isTerminal(state) && stopwatch.elapsed < timeout) {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    state = SessionState.fromValue(backend.getSessionState(handle));
  }
  if (!_isTerminal(state)) {
    throw TimeoutException(
      'FFprobe session did not finish within $timeout.',
      timeout,
    );
  }
  return state;
}

Future<Map<String, Object?>> _runProbeCase(
  WebFFmpegKitBackend backend, {
  required String name,
  required String command,
  required bool expectSuccess,
}) async {
  final result = <String, Object?>{
    'name': name,
    'command': command,
    'status': 'running',
    'sessionId': null,
    'nativeState': null,
    'returnCode': null,
    'handleReleased': false,
  };
  SessionHandle? handle;
  var executionAttempted = false;
  try {
    handle = backend.createFFprobeSession(command);
    result['sessionId'] = backend.getSessionId(handle);
    if ((result['sessionId'] as int) <= 0) {
      throw StateError('FFprobe returned an invalid session ID.');
    }
    if (!backend.isFFprobeSession(handle)) {
      throw StateError('The created handle is not an FFprobe session.');
    }

    executionAttempted = true;
    backend.executeFFprobeSessionAsync(handle);
    final state = await _waitForTerminal(backend, handle, _sessionTimeout);
    final returnCode = backend.getReturnCode(handle);
    final output = backend.getOutput(handle) ?? '';
    final logs = backend.getLogsAsString(handle) ?? '';
    result['nativeState'] = state.name;
    result['returnCode'] = returnCode;
    result['output'] = output;
    if (logs.isNotEmpty) {
      result['logsTail'] = logs.length <= 4000
          ? logs
          : logs.substring(logs.length - 4000);
    }

    if (expectSuccess) {
      if (state != SessionState.completed || returnCode != 0) {
        throw StateError(
          'FFprobe did not succeed (state=${state.name}, returnCode=$returnCode).',
        );
      }
      final decoded = jsonDecode(output) as Map<String, dynamic>;
      final streams = (decoded['streams'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final codecs = streams
          .map((stream) => stream['codec_name'])
          .whereType<String>()
          .toSet();
      if (!codecs.contains('h264') || !codecs.contains('aac')) {
        throw StateError('Expected H.264 and AAC streams, got $codecs.');
      }
      result['format'] =
          (decoded['format'] as Map<String, dynamic>?)?['format_name'];
      result['codecs'] = codecs.toList()..sort();
    } else if (!_isTerminal(state) || returnCode == 0) {
      throw StateError(
        'HTTP 403 should fail with a nonzero FFprobe return code (state=${state.name}, returnCode=$returnCode).',
      );
    }
    result['status'] = 'passed';
  } catch (error, stackTrace) {
    result['status'] = 'failed';
    result['error'] = error.toString();
    result['stackTrace'] = stackTrace.toString();
    if (handle != null) {
      try {
        result['nativeState'] = SessionState.fromValue(
          backend.getSessionState(handle),
        ).name;
        result['returnCode'] = backend.getReturnCode(handle);
        result['output'] = backend.getOutput(handle) ?? '';
        result['logsTail'] = backend.getLogsAsString(handle) ?? '';
        result['failStackTrace'] = backend.getFailStackTrace(handle) ?? '';
      } catch (diagnosticError) {
        result['diagnosticError'] = diagnosticError.toString();
      }
    }
  } finally {
    if (handle != null) {
      if (executionAttempted) {
        try {
          final state = SessionState.fromValue(backend.getSessionState(handle));
          if (!_isTerminal(state)) {
            backend.cancelSession(handle);
            final cleanupState = await _waitForTerminal(
              backend,
              handle,
              _cleanupTimeout,
            );
            result['cleanupState'] = cleanupState.name;
          }
        } catch (cleanupError) {
          result['cleanupError'] = cleanupError.toString();
          result['status'] = 'failed';
        }
      }
      try {
        backend.releaseSession(handle);
        result['handleReleased'] = true;
      } catch (releaseError) {
        result['releaseError'] = releaseError.toString();
        result['status'] = 'failed';
      }
    }
  }
  return result;
}

void _publish(Map<String, Object?> report) {
  _globalThis.setProperty(
    'CODEX_flutterAdapterResult'.toJS,
    jsonEncode(report).toJS,
  );
}

Future<void> main() async {
  final fixture = Uri.base.queryParameters['fixture'];
  final report = <String, Object?>{
    'contract': 'flutter-web-native-bridge',
    'status': 'running',
    'fixture': fixture,
    'coverageGaps': <String>[
      'This fixture exercises the internal WebFFmpegKitBackend, not public FFmpegKit wrapper orchestration.',
      'A fresh module reload is owned by the parent browser runner.',
    ],
    'cases': <Map<String, Object?>>[],
  };

  try {
    if (fixture == null || fixture.isEmpty) {
      throw ArgumentError('The fixture query parameter is required.');
    }
    final fixtureOrigin = Uri.parse(fixture);
    if (fixtureOrigin.scheme != 'http' && fixtureOrigin.scheme != 'https') {
      throw ArgumentError('The fixture URL must use HTTP or HTTPS.');
    }

    final backend = WebFFmpegKitBackend();
    await backend.initialize().timeout(const Duration(seconds: 30));
    report['backendInitialized'] = backend.initialized;
    if (!backend.initialized) {
      throw StateError(
        'WebFFmpegKitBackend.initialize() did not commit the Wasm module.',
      );
    }

    final mediaUrl = fixtureOrigin
        .resolve('/media/d2-same-h264-aac.mp4?token=flutter-native-bridge')
        .toString();
    final success = await _runProbeCase(
      backend,
      name: 'remote MP4 FFprobe',
      command:
          '-v error -show_entries format=format_name:stream=codec_name -of json $mediaUrl',
      expectSuccess: true,
    );
    (report['cases']! as List<Map<String, Object?>>).add(success);

    final forbiddenUrl = fixtureOrigin.resolve(
      '/status/403?token=flutter-native-bridge',
    );
    final http403 = await _runProbeCase(
      backend,
      name: 'HTTP 403 FFprobe failure',
      command:
          '-v error -show_entries format=format_name:stream=codec_name -of json $forbiddenUrl',
      expectSuccess: false,
    );
    (report['cases']! as List<Map<String, Object?>>).add(http403);

    report['status'] =
        success['status'] == 'passed' && http403['status'] == 'passed'
        ? 'passed'
        : 'failed';
  } catch (error, stackTrace) {
    report['status'] = 'failed';
    report['error'] = error.toString();
    report['stackTrace'] = stackTrace.toString();
  }

  _publish(report);
}
