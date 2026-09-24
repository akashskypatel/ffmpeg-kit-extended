import 'package:ffmpeg_kit_extended_flutter/src/callback_manager.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffmpeg_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffplay_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffprobe_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/media_information_session.dart';
import 'package:ffmpeg_kit_extended_flutter/src/session.dart';
import 'package:test/test.dart';

mixin _SynchronousFixture {
  final List<String> events = <String>[];
  SessionState state = SessionState.created;
  bool fail = false;
  final StateError failure = StateError('synchronous backend failed');

  void dispatchPendingLogs() {}

  bool get started;
  bool get settled;

  void recordNativeExecution() {
    events.add('execute');
    expect(started, isTrue, reason: 'start must be recorded before backend');
    if (fail) throw failure;
    state = SessionState.completed;
  }
}

class _SynchronousFFmpegSession extends FFmpegSession with _SynchronousFixture {
  _SynchronousFFmpegSession({super.completeCallback})
    : super.test(sessionId: 401);

  @override
  SessionState executionStateForSubmission() => state;

  @override
  void requireInitializedForExecution() => events.add('initialized');

  @override
  void enableNativeLogCallback() => events.add('log');

  @override
  void configureSynchronousNativeCallbacks() => events.add('configure');

  @override
  void executeSynchronously() => recordNativeExecution();

  @override
  bool get started => hasExecutionStarted;

  @override
  bool get settled => hasExecutionSettled;
}

class _SynchronousFFprobeSession extends FFprobeSession
    with _SynchronousFixture {
  _SynchronousFFprobeSession() : super.test(sessionId: 402);

  @override
  SessionState executionStateForSubmission() => state;

  @override
  void requireInitializedForExecution() => events.add('initialized');

  @override
  void enableNativeLogCallback() => events.add('log');

  @override
  void configureSynchronousNativeCallbacks() => events.add('configure');

  @override
  void executeSynchronously() => recordNativeExecution();

  @override
  bool get started => hasExecutionStarted;

  @override
  bool get settled => hasExecutionSettled;
}

class _SynchronousMediaInformationSession extends MediaInformationSession
    with _SynchronousFixture {
  _SynchronousMediaInformationSession() : super.test(sessionId: 403);

  @override
  SessionState executionStateForSubmission() => state;

  @override
  void requireInitializedForExecution() => events.add('initialized');

  @override
  void enableNativeLogCallback() => events.add('log');

  @override
  void configureSynchronousNativeCallbacks() => events.add('configure');

  @override
  void executeSynchronously() => recordNativeExecution();

  @override
  bool get started => hasExecutionStarted;

  @override
  bool get settled => hasExecutionSettled;
}

class _SynchronousFFplaySession extends FFplaySession with _SynchronousFixture {
  _SynchronousFFplaySession() : super.test(sessionId: 404);

  @override
  SessionState executionStateForSubmission() => state;

  @override
  void requireInitializedForExecution() => events.add('initialized');

  @override
  void enableNativeLogCallback() => events.add('log');

  @override
  void configureSynchronousNativeCallbacks() => events.add('configure');

  @override
  void executeSynchronously() => recordNativeExecution();

  @override
  void notifyPlaybackStarted() => events.add('playback-started');

  @override
  bool get started => hasExecutionStarted;

  @override
  bool get settled => hasExecutionSettled;
}

void main() {
  final callbacks = CallbackManager();

  setUp(() {
    callbacks.ffmpegSessions.clear();
    callbacks.ffprobeSessions.clear();
    callbacks.ffplaySessions.clear();
    callbacks.mediaInformationSessions.clear();
    callbacks.globalFFmpegSessionCompleteCallback = null;
    callbacks.globalFFprobeSessionCompleteCallback = null;
    callbacks.globalMediaInformationSessionCompleteCallback = null;
    callbacks.globalFFplaySessionCompleteCallback = null;
  });

  tearDown(() {
    callbacks.ffmpegSessions.clear();
    callbacks.ffprobeSessions.clear();
    callbacks.ffplaySessions.clear();
    callbacks.mediaInformationSessions.clear();
    callbacks.globalFFmpegSessionCompleteCallback = null;
    callbacks.globalFFprobeSessionCompleteCallback = null;
    callbacks.globalMediaInformationSessionCompleteCallback = null;
    callbacks.globalFFplaySessionCompleteCallback = null;
  });

  test('FFmpeg synchronous execution waits, dispatches once, and settles', () {
    var localCalls = 0;
    var globalCalls = 0;
    final session = _SynchronousFFmpegSession(
      completeCallback: (_) => localCalls++,
    );
    callbacks.globalFFmpegSessionCompleteCallback = (_) => globalCalls++;

    session.execute();

    // No log sink is attached, so the optional process-global log bridge is
    // intentionally not installed for this synchronous execution.
    expect(session.events, ['initialized', 'configure', 'execute']);
    expect(session.state, SessionState.completed);
    expect(session.started, isTrue);
    expect(session.settled, isTrue);
    expect(localCalls, 1);
    expect(globalCalls, 1);
    expect(callbacks.ffmpegSessions.containsKey(session.sessionId), isFalse);
  });

  test('FFprobe synchronous execution rethrows the backend error', () {
    final session = _SynchronousFFprobeSession()..fail = true;

    expect(session.execute, throwsA(same(session.failure)));
    expect(session.started, isTrue);
    expect(session.settled, isTrue);
    expect(callbacks.ffprobeSessions.containsKey(session.sessionId), isFalse);
  });

  test('media-information synchronous execution settles before returning', () {
    final session = _SynchronousMediaInformationSession();

    session.execute();

    expect(session.state, SessionState.completed);
    expect(session.settled, isTrue);
    expect(
      callbacks.mediaInformationSessions.containsKey(session.sessionId),
      isFalse,
    );
  });

  test('FFplay synchronous execution uses the direct blocking path', () {
    final session = _SynchronousFFplaySession();

    session.execute();

    expect(session.events, ['initialized', 'execute', 'playback-started']);
    expect(session.settled, isTrue);
    expect(callbacks.ffplaySessions.containsKey(session.sessionId), isFalse);
  });

  test('failed FFplay synchronous startup does not commit playback identity', () {
    final session = _SynchronousFFplaySession()..fail = true;

    expect(session.execute, throwsA(same(session.failure)));
    expect(session.events, ['initialized', 'execute']);
    expect(session.settled, isTrue);
  });

  test('completion callback failure does not skip the global callback', () {
    var globalCalls = 0;
    final session = _SynchronousFFmpegSession(
      completeCallback: (_) => throw StateError('local callback'),
    );
    callbacks.globalFFmpegSessionCompleteCallback = (_) => globalCalls++;

    session.execute();
    expect(globalCalls, 1);
    expect(session.settled, isTrue);
  });
}
