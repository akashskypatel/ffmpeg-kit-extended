// This is a comprehensive Flutter integration test for ffmpeg_kit_extended.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'dart:io';
import 'dart:async';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_flutter.dart';
import 'package:path/path.dart' as path;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Set SDL drivers to dummy to avoid window creation issues and ensure reliability
  FFmpegKitConfig.setEnvironmentVariable("SDL_VIDEODRIVER", "dummy");
  FFmpegKitConfig.setEnvironmentVariable("SDL_AUDIODRIVER", "dummy");

  String videoFile = "test_video.mp4";
  String audioFile = "test_audio.mp3";
  String videoPath = "";
  String audioPath = "";
  String outputDir = "";

  const String dummyVideoCommand =
      "-hide_banner -loglevel info -f lavfi -i testsrc=duration=5:size=512x512:rate=30";
  const String dummyAudioCommand =
      "-hide_banner -loglevel info -f lavfi -i sine=frequency=1000:duration=3";

  /// Helper to create a dummy video file
  Future<void> createDummyVideo() async {
    if (videoPath.isEmpty) {
      final currentDir = Directory.current.absolute.path;
      outputDir = path.join(currentDir, 'test_output');
      await Directory(outputDir).create(recursive: true);
      videoPath = path.join(outputDir, videoFile).replaceAll(r'\', '/');
      audioPath = path.join(outputDir, audioFile).replaceAll(r'\', '/');
    }

    if (!File(videoPath).existsSync()) {
      print("Creating test video at: $videoPath");
      FFmpegKit.execute("$dummyVideoCommand -y $videoPath");
      await SessionQueueManager().waitForAll();
      expect(File(videoPath).existsSync(), isTrue);
    }
  }

  /// Helper to create a dummy audio file
  Future<void> createDummyAudio() async {
    if (audioPath.isEmpty) {
      final currentDir = Directory.current.absolute.path;
      outputDir = path.join(currentDir, 'test_output');
      await Directory(outputDir).create(recursive: true);
      audioPath = path.join(outputDir, audioFile).replaceAll(r'\', '/');
    }

    if (!File(audioPath).existsSync()) {
      print("Creating test audio at: $audioPath");
      FFmpegKit.execute("$dummyAudioCommand -y $audioPath");
      await SessionQueueManager().waitForAll();
      expect(File(audioPath).existsSync(), isTrue);
    }
  }

  /// Helper to wait
  Future<void> wait(int seconds) async {
    await Future.delayed(Duration(seconds: seconds));
  }

  group('FFmpegKitConfig Tests', () {
    testWidgets('Get FFmpeg Version', (WidgetTester tester) async {
      final version = FFmpegKitConfig.getFFmpegVersion();
      print("FFmpeg Version: $version");
      expect(version, isNotNull);
      expect(version, isNotEmpty);
    });

    testWidgets('Get Package Name', (WidgetTester tester) async {
      final packageName = FFmpegKitConfig.getPackageName();
      print("Package Name: $packageName");
      expect(packageName, isNotNull);
      expect(packageName, isNotEmpty);
    });

    testWidgets('Get FFmpegKit Version', (WidgetTester tester) async {
      final version = FFmpegKitConfig.getVersion();
      print("FFmpegKit Version: $version");
      expect(version, isNotNull);
      expect(version, isNotEmpty);
    });

    testWidgets('Get Build Date', (WidgetTester tester) async {
      final buildDate = FFmpegKitConfig.getBuildDate();
      print("Build Date: $buildDate");
      expect(buildDate, isNotNull);
      expect(buildDate, isNotEmpty);
    });

    testWidgets('Log Level Configuration', (WidgetTester tester) async {
      FFmpegKitConfig.setLogLevel(LogLevel.quiet);
      expect(FFmpegKitConfig.getLogLevel(), LogLevel.quiet);

      FFmpegKitConfig.setLogLevel(LogLevel.info);
      expect(FFmpegKitConfig.getLogLevel(), LogLevel.info);

      FFmpegKitConfig.setLogLevel(LogLevel.verbose);
      expect(FFmpegKitConfig.getLogLevel(), LogLevel.verbose);
    });

    testWidgets('Session History Size', (WidgetTester tester) async {
      FFmpegKitConfig.setSessionHistorySize(10);
      expect(FFmpegKitConfig.getSessionHistorySize(), 10);

      FFmpegKitConfig.setSessionHistorySize(20);
      expect(FFmpegKitConfig.getSessionHistorySize(), 20);
    });

    testWidgets('Parse Arguments', (WidgetTester tester) async {
      final args = FFmpegKitConfig.parseArguments(
          "-i input.mp4 -c:v libx264 output.mp4");
      print("Parsed Arguments: $args");
      expect(args, isNotNull);
      expect(args.length, greaterThan(0));
      expect(args, contains("-i"));
      expect(args, contains("input.mp4"));
    });

    testWidgets('Arguments To String', (WidgetTester tester) async {
      final args = ["-i", "input.mp4", "-c:v", "libx264", "output.mp4"];
      final command = FFmpegKitConfig.argumentsToString(args);
      print("Command String: $command");
      expect(command, isNotNull);
      expect(command, contains("-i"));
      expect(command, contains("input.mp4"));
    });

    testWidgets('Log Level To String', (WidgetTester tester) async {
      final quietStr = FFmpegKitConfig.logLevelToString(LogLevel.quiet);
      final infoStr = FFmpegKitConfig.logLevelToString(LogLevel.info);
      print("Quiet: $quietStr, Info: $infoStr");
      expect(quietStr, isNotNull);
      expect(infoStr, isNotNull);
    });

    testWidgets('Session State To String', (WidgetTester tester) async {
      final createdStr =
          FFmpegKitConfig.sessionStateToString(SessionState.created);
      final runningStr =
          FFmpegKitConfig.sessionStateToString(SessionState.running);
      final completedStr =
          FFmpegKitConfig.sessionStateToString(SessionState.completed);
      print("States: $createdStr, $runningStr, $completedStr");
      expect(createdStr, isNotNull);
      expect(runningStr, isNotNull);
      expect(completedStr, isNotNull);
    });

    testWidgets('Enable/Disable Redirection', (WidgetTester tester) async {
      FFmpegKitConfig.enableRedirection();
      FFmpegKitConfig.disableRedirection();
      FFmpegKitConfig.enableRedirection();
    });
  });

  group('FFmpegKit Session Tests', () {
    setUp(() async {
      FFmpegKitConfig.disableRedirection();
      FFmpegKitConfig.enableRedirection();
      FFmpegKitConfig.setLogLevel(LogLevel.info);
    });

    testWidgets('Execute Sync - Version Command', (WidgetTester tester) async {
      final session = FFmpegKit.execute("-version");
      print("Session ID: ${session.sessionId}");
      print("Return Code: ${session.getReturnCode()}");
      print("State: ${session.getState()}");
      print("Test 1 Logs length: ${session.getLogs()?.length}");

      expect(session.getState(), SessionState.completed);
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
      expect(session.getCommand(), contains("-version"));
    });

    testWidgets('Execute Async - Version Command', (WidgetTester tester) async {
      final completer = Completer<FFmpegSession>();

      FFmpegKit.executeAsync('-version', onComplete: (session) {
        print("Async execution completed for Session: ${session.sessionId}");
        completer.complete(session);
      });

      final session = await completer.future;
      expect(session.getState(), SessionState.completed);
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
    });

    testWidgets('Create Session Without Execution',
        (WidgetTester tester) async {
      final session = FFmpegKit.createSession("-version");
      print("Created Session ID: ${session.sessionId}");
      expect(session.getState(), SessionState.created);
      expect(session.getCommand(), contains("-version"));
    });

    testWidgets('Session History Management', (WidgetTester tester) async {
      FFmpegKitConfig.setSessionHistorySize(10);

      // Create multiple sessions
      for (int i = 0; i < 3; i++) {
        final s = FFmpegKit.execute("-version");
        print("History Session ID: ${s.sessionId}");
      }

      final sessions = FFmpegKit.getFFmpegSessions();
      print("Sessions count: ${sessions.length}");
      expect(sessions.length, greaterThanOrEqualTo(3));

      final lastSession = FFmpegKit.getLastFFmpegSession();
      print("Last Session ID: ${lastSession?.sessionId}");
      expect(lastSession, isNotNull);
    });

    testWidgets('Session Cancel', (WidgetTester tester) async {
      await createDummyVideo();

      final session =
          FFmpegKit.createSession("-i $videoPath -c:v mpeg4 -f null -");

      // Start execution in background
      session.executeAsync();
      await wait(1);

      // Cancel the session
      FFmpegKit.cancel(session);
      await wait(1);

      // Session should be cancelled or completed
      expect(session.getState(),
          isIn([SessionState.completed, SessionState.failed]));
    });

    testWidgets('Session Output and Logs', (WidgetTester tester) async {
      final session = FFmpegKit.execute("-version");
      print("Test 6 Session ID: ${session.sessionId}");

      final output = session.getOutput();
      final logs = session.getLogs();

      print("Output length: ${output?.length}");
      print("Logs length: ${logs?.length}");
      if ((output?.length ?? 0) > 0)
        print(
            "Output sample: ${output!.substring(0, output.length > 100 ? 100 : output.length)}");
      if ((logs?.length ?? 0) > 0)
        print(
            "Logs sample: ${logs!.substring(0, logs.length > 100 ? 100 : logs.length)}");

      expect(output, isNotNull);
      expect(logs, isNotNull);
    });

    testWidgets('Session Timing Information', (WidgetTester tester) async {
      final session = FFmpegKit.execute("-version");

      final createTime = session.getCreateTime();
      final startTime = session.getStartTime();
      final endTime = session.getEndTime();
      final duration = session.getSessionDuration();

      print(
          "Create: $createTime, Start: $startTime, End: $endTime, Duration: $duration");

      expect(createTime, greaterThan(0));
      expect(startTime, greaterThanOrEqualTo(0));
      expect(endTime, greaterThanOrEqualTo(0));
    });

    testWidgets('Session Log Entries', (WidgetTester tester) async {
      FFmpegKitConfig.enableRedirection();
      final session = FFmpegKit.execute("-version");

      final logsCount = session.getLogsCount();
      print("Logs count: $logsCount");

      if (logsCount > 0) {
        final firstLog = session.getLogAt(0);
        final firstLogLevel = session.getLogLevelAt(0);
        print("First log: $firstLog");
        print("First log level: $firstLogLevel");
        expect(firstLog, isNotNull);
      }
    });

    testWidgets('Session Type Checks', (WidgetTester tester) async {
      final session = FFmpegKit.execute("-version");

      expect(session.isFFmpegSession(), isTrue);
      expect(session.isFFplaySession(), isFalse);
      expect(session.isFFprobeSession(), isFalse);
      expect(session.isMediaInformationSession(), isFalse);
    });

    testWidgets('Video Transcoding', (WidgetTester tester) async {
      await createDummyVideo();

      final outputPath =
          path.join(outputDir, 'transcoded.mp4').replaceAll(r'\', '/');
      final session =
          FFmpegKit.execute("-i $videoPath -c:v mpeg4 -q:v 5 -y $outputPath");

      print("Transcoding result: ${session.getReturnCode()}");
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
      expect(File(outputPath).existsSync(), isTrue);
    });

    testWidgets('Callbacks - Log and Statistics', (WidgetTester tester) async {
      await createDummyVideo();

      final completer = Completer<FFmpegSession>();
      final logs = <Log>[];
      final stats = <Statistics>[];

      final outputPath =
          path.join(outputDir, 'callback_test.mp4').replaceAll(r'\', '/');

      FFmpegKit.executeAsync(
        "-i $videoPath -c:v mpeg4 -q:v 5 -y $outputPath",
        onLog: (log) {
          logs.add(log);
        },
        onStatistics: (statistics) {
          stats.add(statistics);
        },
        onComplete: (session) {
          completer.complete(session);
        },
      );

      final session = await completer.future;

      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);

      if (logs.isEmpty) {
        print("Callback Logs were empty. Session Logs: \n${session.getLogs()}");
        print("Session Output: \n${session.getOutput()}");
      }
      expect(logs.length, greaterThan(0));
      print(logs);
      expect(stats.length, greaterThan(0));
      print(stats);
    });
  });

  group('FFprobeKit Tests', () {
    testWidgets('Execute Sync - Version', (WidgetTester tester) async {
      final session = FFprobeKit.execute("-version");

      expect(session.getState(), SessionState.completed);
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
      expect(session.isFFprobeSession(), isTrue);
    });

    testWidgets('Execute Async - Version', (WidgetTester tester) async {
      final completer = Completer<FFprobeSession>();

      FFprobeKit.executeAsync("-version", onComplete: (session) {
        completer.complete(session);
      });

      final session = await completer.future;
      expect(session.getState(), SessionState.completed);
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
    });

    testWidgets('Get Media Information - Video', (WidgetTester tester) async {
      await createDummyVideo();

      final session = FFprobeKit.getMediaInformation(videoPath);

      print("FFprobe result: ${session.getReturnCode()}");
      expect(session.getState(), SessionState.completed);
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);

      final mediaInfo = session.getMediaInformation();
      expect(mediaInfo, isNotNull);

      print("Filename: ${mediaInfo!.filename}");
      print("Format: ${mediaInfo.format}");
      print("Duration: ${mediaInfo.duration}");
      print("Streams: ${mediaInfo.streams.length}");

      expect(mediaInfo.filename, isNotNull);
      expect(mediaInfo.format, isNotNull);
      expect(mediaInfo.streams.length, greaterThan(0));
    });

    testWidgets('Get Media Information Async', (WidgetTester tester) async {
      await createDummyAudio();

      final completer = Completer<FFprobeSession>();

      FFprobeKit.getMediaInformationAsync(audioPath, onComplete: (session) {
        completer.complete(session);
      });

      final session = await completer.future;
      print("Return Code: ${session.getReturnCode()}");
      // Add more detailed check or print
      if (!ReturnCode.isSuccess(session.getReturnCode())) {
        print("FFprobe failed with return code: ${session.getReturnCode()}");
        print("FFprobe Logs: \n${session.getLogs()}");
        print("FFprobe Output: \n${session.getOutput()}");
        print("FFprobe StackTrace: \n${session.getFailStackTrace()}");
      }
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);

      final mediaInfo = session.getMediaInformation();
      expect(mediaInfo, isNotNull);
      print("Audio format: ${mediaInfo!.format}");
      print("Audio streams: ${mediaInfo.streams.length}");
    });

    testWidgets('Stream Information Details', (WidgetTester tester) async {
      await createDummyVideo();

      final session = FFprobeKit.getMediaInformation(videoPath);
      final mediaInfo = session.getMediaInformation();

      expect(mediaInfo, isNotNull);
      expect(mediaInfo!.streams.length, greaterThan(0));

      final stream = mediaInfo.streams.first;
      print("Stream type: ${stream.type}");
      print("Stream codec: ${stream.codec}");
      print("Stream width: ${stream.width}");
      print("Stream height: ${stream.height}");

      expect(stream.type, isNotNull);
      expect(stream.codec, isNotNull);
    });

    testWidgets('Create Session Without Execution',
        (WidgetTester tester) async {
      final session = FFprobeKit.createSession("-version");
      expect(session.getState(), SessionState.created);
    });

    testWidgets('Get FFprobe Sessions', (WidgetTester tester) async {
      FFprobeKit.execute("-version");
      FFprobeKit.execute("-version");

      final sessions = FFprobeKit.getFFprobeSessions();
      expect(sessions.length, greaterThanOrEqualTo(2));
    });

    testWidgets('Session Type Checks', (WidgetTester tester) async {
      final session = FFprobeKit.execute("-version");

      expect(session.isFFmpegSession(), isFalse);
      expect(session.isFFplaySession(), isFalse);
      expect(session.isFFprobeSession(), isTrue);
      expect(session.isMediaInformationSession(), isFalse);
    });
  });

  group('MediaInformationSession Tests', () {
    testWidgets('Media Information Type Check', (WidgetTester tester) async {
      await createDummyVideo();

      final session = FFprobeKit.getMediaInformation(videoPath);

      expect(session.isFFmpegSession(), isFalse);
      expect(session.isFFplaySession(), isFalse);
      expect(session.isFFprobeSession(), isFalse);
      expect(session.isMediaInformationSession(), isTrue);
    });

    testWidgets('Media Information Properties', (WidgetTester tester) async {
      await createDummyVideo();

      final session = FFprobeKit.getMediaInformation(videoPath);
      final mediaInfo = session.getMediaInformation();

      expect(mediaInfo, isNotNull);

      // Test all properties
      print("Filename: ${mediaInfo!.filename}");
      print("Format: ${mediaInfo.format}");
      print("Long Format: ${mediaInfo.longFormat}");
      print("Duration: ${mediaInfo.duration}");
      print("Start Time: ${mediaInfo.startTime}");
      print("Bitrate: ${mediaInfo.bitrate}");
      print("Size: ${mediaInfo.size}");

      // Test parsed properties
      final tags = mediaInfo.tags;
      final allProps = mediaInfo.allProperties;

      print("Tags: $tags");
      print("All Properties keys: ${allProps?.keys}");
    });

    testWidgets('Stream Information Properties', (WidgetTester tester) async {
      await createDummyVideo();

      final session = FFprobeKit.getMediaInformation(videoPath);
      final mediaInfo = session.getMediaInformation();

      expect(mediaInfo, isNotNull);
      expect(mediaInfo!.streams.length, greaterThan(0));

      for (var stream in mediaInfo.streams) {
        print("\n--- Stream ${stream.index} ---");
        print("Type: ${stream.type}");
        print("Codec: ${stream.codec}");
        print("Codec Long: ${stream.codecLong}");
        print("Format: ${stream.format}");
        print("Width: ${stream.width}");
        print("Height: ${stream.height}");
        print("Bitrate: ${stream.bitrate}");
        print("Sample Rate: ${stream.sampleRate}");
        print("Channel Layout: ${stream.channelLayout}");
        print("Frame Rate: ${stream.averageFrameRate}");
      }
    });
  });

  group('FFplayKit Tests', () {
    testWidgets('Play and Stop', (WidgetTester tester) async {
      await createDummyVideo();

      final session = await FFplayKit.executeAsync('-i $videoPath');
      await wait(2);

      expect(session.isPlaying(), isTrue);
      expect(FFplayKit.isPlaying(), isTrue);

      FFplayKit.stop();
      await wait(1);

      expect(session.getState(), SessionState.completed);
    });

    testWidgets('Pause and Resume', (WidgetTester tester) async {
      await createDummyVideo();

      final session = await FFplayKit.executeAsync('-i $videoPath');
      await wait(2);

      expect(session.isPlaying(), isTrue);

      session.pause();
      await wait(1);
      expect(session.isPaused(), isTrue);

      session.resume();
      await wait(1);
      expect(session.isPaused(), isFalse);
      expect(session.isPlaying(), isTrue);

      session.stop();
      await wait(1);
    });

    testWidgets('Seek Position', (WidgetTester tester) async {
      await createDummyVideo();

      final session = await FFplayKit.executeAsync('-i $videoPath');
      await wait(2);

      session.seek(3.0);
      await wait(1);

      final pos = session.getPosition();
      print("Position after seek: $pos");
      expect(pos, greaterThanOrEqualTo(2.0));

      session.stop();
    });

    testWidgets('Get Duration and Position', (WidgetTester tester) async {
      await createDummyVideo();

      final session = await FFplayKit.executeAsync('-i $videoPath');
      await wait(2);

      final duration = session.getDuration();
      final position = session.getPosition();

      print("Duration: $duration, Position: $position");

      expect(duration, greaterThan(0));
      expect(position, greaterThanOrEqualTo(0));

      session.stop();
    });

    testWidgets('Volume Control', (WidgetTester tester) async {
      await createDummyVideo();

      final session = await FFplayKit.executeAsync('-i $videoPath');
      await wait(1);

      session.setVolume(0.5);
      final volume = session.getVolume();

      print("Volume: $volume");
      expect(volume, greaterThanOrEqualTo(0.0));
      expect(volume, lessThanOrEqualTo(1.0));

      session.stop();
    });

    testWidgets('Global Controls', (WidgetTester tester) async {
      await createDummyVideo();

      await FFplayKit.executeAsync('-i $videoPath');
      await wait(2);

      FFplayKit.pause();
      await wait(1);
      expect(FFplayKit.isPaused(), isTrue);

      FFplayKit.resume();
      await wait(1);
      expect(FFplayKit.isPaused(), isFalse);

      FFplayKit.stop();
      await wait(1);
    });

    testWidgets('Concurrent Sessions - Terminate Strategy',
        (WidgetTester tester) async {
      await createDummyVideo();

      final session1 = await FFplayKit.executeAsync(
        '-i $videoPath',
        strategy: SessionConflictStrategy.terminate,
      );
      await wait(2);
      expect(session1.isPlaying(), isTrue);

      final session2 = await FFplayKit.executeAsync(
        '-i $videoPath',
        strategy: SessionConflictStrategy.terminate,
      );
      await wait(2);

      // Session1 should be terminated
      expect(session1.getState(), SessionState.completed);
      expect(session2.isPlaying(), isTrue);

      session2.stop();
    });

    testWidgets('Get Current Session', (WidgetTester tester) async {
      await createDummyVideo();

      final session = await FFplayKit.executeAsync('-i $videoPath');
      await wait(1);

      final currentSession = FFplayKit.getCurrentSession();
      expect(currentSession, isNotNull);
      expect(currentSession, equals(session));

      session.stop();
      await wait(1);
    });

    testWidgets('Session Type Checks', (WidgetTester tester) async {
      await createDummyVideo();

      final session = await FFplayKit.executeAsync('-i $videoPath');

      expect(session.isFFmpegSession(), isFalse);
      expect(session.isFFplaySession(), isTrue);
      expect(session.isFFprobeSession(), isFalse);
      expect(session.isMediaInformationSession(), isFalse);

      session.stop();
    });

    testWidgets('Create Session Without Execution',
        (WidgetTester tester) async {
      await createDummyVideo();

      final session = await FFplayKit.createSession('-i $videoPath');
      expect(session.getState(), SessionState.created);
    });
  });

  group('Return Code and Session State Tests', () {
    testWidgets('ReturnCode Success Check', (WidgetTester tester) async {
      expect(ReturnCode.isSuccess(0), isTrue);
      expect(ReturnCode.isSuccess(1), isFalse);
      expect(ReturnCode.isSuccess(255), isFalse);
    });

    testWidgets('ReturnCode Cancel Check', (WidgetTester tester) async {
      expect(ReturnCode.isCancel(255), isTrue);
      expect(ReturnCode.isCancel(0), isFalse);
      expect(ReturnCode.isCancel(1), isFalse);
    });

    testWidgets('SessionState FromValue', (WidgetTester tester) async {
      expect(SessionState.fromValue(0), SessionState.created);
      expect(SessionState.fromValue(1), SessionState.running);
      expect(SessionState.fromValue(2), SessionState.completed);
      expect(SessionState.fromValue(3), SessionState.failed);
      expect(
          SessionState.fromValue(999), SessionState.failed); // Default fallback
    });
  });

  group('SessionQueueManager Tests', () {
    testWidgets('Queue Strategy - Sequential Execution',
        (WidgetTester tester) async {
      await createDummyVideo();

      final completer1 = Completer<FFmpegSession>();
      final completer2 = Completer<FFmpegSession>();
      final completer3 = Completer<FFmpegSession>();

      final output1 =
          path.join(outputDir, 'queue_test1.mp4').replaceAll(r'\', '/');
      final output2 =
          path.join(outputDir, 'queue_test2.mp4').replaceAll(r'\', '/');
      final output3 =
          path.join(outputDir, 'queue_test3.mp4').replaceAll(r'\', '/');

      // Start three sessions with queue strategy (default)
      FFmpegKit.executeAsync(
        "-i $videoPath -c:v mpeg4 -q:v 5 -y $output1",
        strategy: SessionExecutionStrategy.queue,
        onComplete: completer1.complete,
      );

      FFmpegKit.executeAsync(
        "-i $videoPath -c:v mpeg4 -q:v 5 -y $output2",
        strategy: SessionExecutionStrategy.queue,
        onComplete: completer2.complete,
      );

      FFmpegKit.executeAsync(
        "-i $videoPath -c:v mpeg4 -q:v 5 -y $output3",
        strategy: SessionExecutionStrategy.queue,
        onComplete: completer3.complete,
      );

      // Check queue status
      final queueManager = SessionQueueManager();
      print("Queue length: ${queueManager.queueLength}");
      expect(queueManager.isBusy, isTrue);

      // Wait for all to complete
      final session1 = await completer1.future;
      final session2 = await completer2.future;
      final session3 = await completer3.future;

      // Ensure queue manager has processed the completion events
      await queueManager.waitForAll();

      expect(ReturnCode.isSuccess(session1.getReturnCode()), isTrue);
      expect(ReturnCode.isSuccess(session2.getReturnCode()), isTrue);
      expect(ReturnCode.isSuccess(session3.getReturnCode()), isTrue);

      expect(File(output1).existsSync(), isTrue);
      expect(File(output2).existsSync(), isTrue);
      expect(File(output3).existsSync(), isTrue);

      expect(queueManager.isBusy, isFalse);
      expect(queueManager.queueLength, 0);
    });

    testWidgets('CancelAndReplace Strategy', (WidgetTester tester) async {
      await createDummyVideo();

      final completer1 = Completer<FFmpegSession>();
      final completer2 = Completer<FFmpegSession>();

      final output1 =
          path.join(outputDir, 'cancel_test1.mp4').replaceAll(r'\', '/');
      final output2 =
          path.join(outputDir, 'cancel_test2.mp4').replaceAll(r'\', '/');

      // Start first session - use longer command to ensure overlap
      FFmpegKit.executeAsync(
        "-re $dummyVideoCommand -t 5 -y $output1",
        strategy: SessionExecutionStrategy.queue,
        onComplete: completer1.complete,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      // Start second session with cancelAndReplace - should cancel first
      FFmpegKit.executeAsync(
        "-i $videoPath -c:v mpeg4 -q:v 5 -y $output2",
        strategy: SessionExecutionStrategy.cancelAndReplace,
        onComplete: completer2.complete,
      );

      final session1 = await completer1.future;
      final session2 = await completer2.future;

      // Session 1 should be cancelled or completed
      print("Session 1 state: ${session1.getState()}");
      print("Session 1 return code: ${session1.getReturnCode()}");

      // Session 2 should complete successfully
      expect(ReturnCode.isSuccess(session2.getReturnCode()), isTrue);
      expect(File(output2).existsSync(), isTrue);
    });

    testWidgets('RejectIfBusy Strategy', (WidgetTester tester) async {
      await createDummyVideo();
      FFmpegKitConfig.setLogLevel(LogLevel.trace);
      final completer1 = Completer<FFmpegSession>();
      bool session2Failed = false;

      final output1 =
          path.join(outputDir, 'reject_test1.mp4').replaceAll(r'\', '/');

      // Start first session - use longer command to ensure overlap
      FFmpegKit.executeAsync("-re $dummyVideoCommand -t 5 -y $output1",
          strategy: SessionExecutionStrategy.queue, onComplete: (session) {
        print("Session 1 completed");
        completer1.complete(session);
      });

      // Try to start second session with rejectIfBusy - should throw
      try {
        await FFmpegKit.executeAsync(
            "-i $videoPath -c:v mpeg4 -q:v 5 -y $output1",
            strategy: SessionExecutionStrategy.rejectIfBusy,
            onComplete: (session) {
          print("Session 2 completed");
          completer1.complete(session);
        });
      } catch (e) {
        print("Expected exception: $e");
        expect(e, isA<SessionBusyException>());
        session2Failed = true;
      }

      expect(session2Failed, isTrue);

      // Wait for first session to complete
      final session1 = await completer1.future;
      expect(ReturnCode.isSuccess(session1.getReturnCode()), isTrue);
    });

    testWidgets('Queue Manager - Current Session', (WidgetTester tester) async {
      await createDummyVideo();

      final queueManager = SessionQueueManager();
      expect(queueManager.currentSession, isNull);
      final completer = Completer<FFmpegSession>();
      final output =
          path.join(outputDir, 'current_test.mp4').replaceAll(r'\', '/');

      FFmpegKit.executeAsync(
        "-re -i $videoPath -c:v mpeg4 -q:v 2 -y $output",
        onComplete: completer.complete,
      );

      // Give it a bit of time to start and stay active
      await Future.delayed(const Duration(milliseconds: 500));
      expect(queueManager.currentSession, isNotNull);
      expect(queueManager.isBusy, isTrue);

      await completer.future;
      await wait(1);

      expect(queueManager.currentSession, isNull);
      expect(queueManager.isBusy, isFalse);
    });

    testWidgets('Queue Manager - Cancel Current', (WidgetTester tester) async {
      await createDummyVideo();

      final queueManager = SessionQueueManager();
      final completer = Completer<FFmpegSession>();

      final output =
          path.join(outputDir, 'cancel_current.mp4').replaceAll(r'\', '/');

      FFmpegKit.executeAsync(
        "-re -i $videoPath -c:v mpeg4 -q:v 5 -y $output",
        onComplete: completer.complete,
      );

      await Future.delayed(const Duration(milliseconds: 500));
      expect(queueManager.isBusy, isTrue);

      queueManager.cancelCurrent();
      await wait(1);

      final session = await completer.future;
      print("Cancelled session state: ${session.getState()}");
    });

    testWidgets('Queue Manager - Clear Queue', (WidgetTester tester) async {
      await createDummyVideo();

      final queueManager = SessionQueueManager();
      final output =
          path.join(outputDir, 'clear_queue.mp4').replaceAll(r'\', '/');

      // Queue multiple sessions
      for (int i = 0; i < 3; i++) {
        FFmpegKit.executeAsync(
          "-re -i $videoPath -c:v mpeg4 -q:v 5 -y $output",
          strategy: SessionExecutionStrategy.queue,
        ).catchError((e) => FFmpegKit.createSession("-version"));
      }

      await Future.delayed(const Duration(milliseconds: 500));
      print("Queue length before clear: ${queueManager.queueLength}");
      expect(queueManager.queueLength, greaterThan(0));

      queueManager.clearQueue();
      expect(queueManager.queueLength, 0);

      // Cancel current to clean up
      queueManager.cancelCurrent();
      await wait(1);
    });

    testWidgets('Queue Manager - Cancel All', (WidgetTester tester) async {
      await createDummyVideo();

      final queueManager = SessionQueueManager();
      final output =
          path.join(outputDir, 'cancel_all.mp4').replaceAll(r'\', '/');

      // Queue multiple sessions
      for (int i = 0; i < 3; i++) {
        FFmpegKit.executeAsync(
          "-re -i $videoPath -c:v mpeg4 -q:v 5 -y $output",
          strategy: SessionExecutionStrategy.queue,
        ).catchError((e) {
          print("Caught expected error: $e");
          return FFmpegKit.createSession("-version");
        });
      }

      await Future.delayed(const Duration(milliseconds: 500));
      expect(queueManager.isBusy, isTrue);
      expect(queueManager.queueLength, greaterThan(0));

      queueManager.cancelAll();
      await wait(1);

      expect(queueManager.queueLength, 0);
    });

    testWidgets('Queue Manager - Wait For All', (WidgetTester tester) async {
      await createDummyVideo();

      final queueManager = SessionQueueManager();
      final output = path.join(outputDir, 'wait_all.mp4').replaceAll(r'\', '/');

      // Queue multiple quick sessions
      for (int i = 0; i < 2; i++) {
        FFmpegKit.executeAsync(
          "-i $videoPath -c:v mpeg4 -q:v 5 -t 1 -y $output",
          strategy: SessionExecutionStrategy.queue,
        );
      }

      expect(queueManager.isBusy, isTrue);

      await queueManager.waitForAll();

      expect(queueManager.isBusy, isFalse);
      expect(queueManager.queueLength, 0);
    });

    testWidgets('Mixed Session Types with Queue', (WidgetTester tester) async {
      await createDummyVideo();

      final queueManager = SessionQueueManager();
      final completer1 = Completer<FFmpegSession>();
      final completer2 = Completer<FFprobeSession>();
      final completer3 = Completer<FFmpegSession>();

      final output =
          path.join(outputDir, 'mixed_test.mp4').replaceAll(r'\', '/');

      // FFmpeg session
      FFmpegKit.executeAsync(
        "-re -i $videoPath -c:v mpeg4 -q:v 5 -y $output",
        strategy: SessionExecutionStrategy.queue,
        onComplete: completer1.complete,
      );

      // FFprobe session
      FFprobeKit.executeAsync(
        "-i $videoPath",
        strategy: SessionExecutionStrategy.queue,
        onComplete: completer2.complete,
      );

      // Another FFmpeg session
      FFmpegKit.executeAsync(
        "-version",
        strategy: SessionExecutionStrategy.queue,
        onComplete: completer3.complete,
      );

      await Future.delayed(const Duration(milliseconds: 500));
      expect(queueManager.isBusy, isTrue);

      final session1 = await completer1.future;
      final session2 = await completer2.future;
      final session3 = await completer3.future;

      await Future.delayed(const Duration(milliseconds: 500));
      expect(ReturnCode.isSuccess(session1.getReturnCode()), isTrue);
      expect(ReturnCode.isSuccess(session2.getReturnCode()), isTrue);
      expect(ReturnCode.isSuccess(session3.getReturnCode()), isTrue);
      expect(queueManager.isBusy, isFalse);
    });
  });

  group('Log and Statistics Tests', () {
    testWidgets('Log Level FromValue', (WidgetTester tester) async {
      expect(LogLevel.fromValue(-8), LogLevel.quiet);
      expect(LogLevel.fromValue(32), LogLevel.info);
      expect(LogLevel.fromValue(40), LogLevel.verbose);
      expect(LogLevel.fromValue(999), LogLevel.debug); // Default fallback
    });

    testWidgets('Log Object', (WidgetTester tester) async {
      final log = Log(1, 32, "Test message");

      expect(log.sessionId, 1);
      expect(log.level, 32);
      expect(log.message, "Test message");
      expect(log.logLevel, LogLevel.info);

      print(log.toString());
    });

    testWidgets('Statistics Object', (WidgetTester tester) async {
      final stats = Statistics(1, 1000, 2048, 128.5, 1.5, 30, 29.97, 23.0);

      expect(stats.sessionId, 1);
      expect(stats.time, 1000);
      expect(stats.size, 2048);
      expect(stats.bitrate, 128.5);
      expect(stats.speed, 1.5);
      expect(stats.videoFrameNumber, 30);
      expect(stats.videoFps, 29.97);
      expect(stats.videoQuality, 23.0);

      print(stats.toString());
    });
  });

  group('Memory Management Stress Tests', () {
    testWidgets('Stress Test - Version Strings', (WidgetTester tester) async {
      print("Starting Version Strings Stress Test...");
      // Repeatedly calling a function that returns a string allocated by MinGW
      // and freed by Dart via ffmpeg_kit_free.
      for (int i = 0; i < 500; i++) {
        final version = FFmpegKitConfig.getFFmpegVersion();
        expect(version, isNotNull);
        expect(version, isNotEmpty);
        if (i % 100 == 0) print("  Iterated $i times...");
      }
      print("Version Strings Stress Test completed successfully.");
    });

    testWidgets('Stress Test - Session Lists', (WidgetTester tester) async {
      print("Starting Session Lists Stress Test...");
      // getSessions allocates an array of pointers and then each command string.
      // Both the array and the strings must be freed correctly.
      for (int i = 0; i < 200; i++) {
        FFmpegKitConfig
            .clearSessions(); // Clear to keep list small but test the call
        FFmpegKit.execute("-version");
        final list = FFmpegKitExtended.getSessions();
        expect(list, isNotEmpty);
        if (i % 50 == 0) print("  Iterated $i times...");
      }
      print("Session Lists Stress Test completed successfully.");
    });

    testWidgets('Stress Test - Media Information', (WidgetTester tester) async {
      await createDummyVideo();
      print("Starting Media Information Stress Test...");
      // This is a heavy test because it involves many small string allocations
      // for all media properties, streams, and chapters.
      for (int i = 0; i < 50; i++) {
        final session = await FFprobeKit.getMediaInformationAsync(videoPath);
        final mediaInfo = session.getMediaInformation();
        expect(mediaInfo, isNotNull);
        expect(mediaInfo!.filename, isNotNull);
        if (i % 10 == 0) print("  Iterated $i times...");
      }
      print("Media Information Stress Test completed successfully.");
    });

    testWidgets('Stress Test - Argument Parsing', (WidgetTester tester) async {
      print("Starting Argument Parsing Stress Test...");
      const cmd =
          "-i input.mp4 -c:v libx264 -preset fast -crf 23 -f mp4 output.mp4";
      for (int i = 0; i < 300; i++) {
        final args = FFmpegKitConfig.parseArguments(cmd);
        expect(args.length, greaterThan(5));
        final backToCmd = FFmpegKitConfig.argumentsToString(args);
        expect(backToCmd, contains("-i"));
        if (i % 100 == 0) print("  Iterated $i times...");
      }
      print("Argument Parsing Stress Test completed successfully.");
    });
  });

  group('Cleanup Tests', () {
    testWidgets('Clear Sessions', (WidgetTester tester) async {
      FFmpegKit.execute("-version");
      FFmpegKit.execute("-version");

      FFmpegKitConfig.clearSessions();

      // Sessions should be cleared
      final sessions = FFmpegKit.getFFmpegSessions();
      print("Sessions after clear: ${sessions.length}");
    });

    testWidgets('Cleanup Test Files', (WidgetTester tester) async {
      if (outputDir.isNotEmpty && Directory(outputDir).existsSync()) {
        print("Cleaning up test output directory: $outputDir");
        try {
          await Directory(outputDir).delete(recursive: true);
        } catch (e) {
          print("Warning: Could not delete test directory: $e");
        }
      }
    });
  });
}
