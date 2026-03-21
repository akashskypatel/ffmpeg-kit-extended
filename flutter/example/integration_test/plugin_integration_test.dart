/*
 * FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
 * Copyright (C) 2026 Akash Patel
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

// This is a comprehensive Flutter integration test for ffmpeg_kit_extended.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'dart:io';
import 'dart:async';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:path/path.dart' as path;

void main() async {
  await FFmpegKitExtended.initialize();
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
      if (kDebugMode) print("Creating test video at: $videoPath");
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
      if (kDebugMode) print("Creating test audio at: $audioPath");
      FFmpegKit.execute("$dummyAudioCommand -y $audioPath");
      await SessionQueueManager().waitForAll();
      expect(File(audioPath).existsSync(), isTrue);
    }
  }

  /// Helper to wait
  Future<void> wait(int seconds) async {
    await Future.delayed(Duration(seconds: seconds));
  }

  setUpAll() async {
    await FFmpegKitExtended.initialize();
  }

  setUp(() async {
    await setUpAll();
    await createDummyVideo();
    await createDummyAudio();
    FFmpegKitConfig.setLogLevel(LogLevel.fatal);
    FFmpegKitConfig.setEnvironmentVariable("SDL_VIDEODRIVER", "dummy");
    FFmpegKitConfig.setEnvironmentVariable("SDL_AUDIODRIVER", "dummy");
    FFmpegKitConfig.setEnvironmentVariable("DISPLAY", ":0");
    FFmpegKitConfig.clearSessions();
    FFmpegKitConfig.enableRedirection();
  });

  tearDown(() async {
    FFmpegKitExtended.clearSessions();
  });

  group('FFmpegKitConfig Tests', () {
    setUp(() async => await setUpAll());
    testWidgets('Get FFmpeg Version', (WidgetTester tester) async {
      final version = FFmpegKitConfig.getFFmpegVersion();
      if (kDebugMode) print("FFmpeg Version: $version");
      expect(version, isNotNull);
      expect(version, isNotEmpty);
    });

    testWidgets('Get Package Name', (WidgetTester tester) async {
      final packageName = FFmpegKitConfig.getPackageName();
      if (kDebugMode) print("Package Name: $packageName");
      expect(packageName, isNotNull);
      expect(packageName, isNotEmpty);
    });

    testWidgets('Get FFmpegKit Version', (WidgetTester tester) async {
      final version = FFmpegKitConfig.getVersion();
      if (kDebugMode) print("FFmpegKit Version: $version");
      expect(version, isNotNull);
      expect(version, isNotEmpty);
    });

    testWidgets('Get Build Date', (WidgetTester tester) async {
      final buildDate = FFmpegKitConfig.getBuildDate();
      if (kDebugMode) print("Build Date: $buildDate");
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
      if (kDebugMode) print("Parsed Arguments: $args");
      expect(args, isNotNull);
      expect(args.length, greaterThan(0));
      expect(args, contains("-i"));
      expect(args, contains("input.mp4"));
    });

    testWidgets('Arguments To String', (WidgetTester tester) async {
      final args = ["-i", "input.mp4", "-c:v", "libx264", "output.mp4"];
      final command = FFmpegKitConfig.argumentsToString(args);
      if (kDebugMode) print("Command String: $command");
      expect(command, isNotNull);
      expect(command, contains("-i"));
      expect(command, contains("input.mp4"));
    });

    testWidgets('Log Level To String', (WidgetTester tester) async {
      final quietStr = FFmpegKitConfig.logLevelToString(LogLevel.quiet);
      final infoStr = FFmpegKitConfig.logLevelToString(LogLevel.info);
      if (kDebugMode) print("Quiet: $quietStr, Info: $infoStr");
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
      if (kDebugMode) print("States: $createdStr, $runningStr, $completedStr");
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
    setUp(() async => await setUpAll());
    setUp(() async {
      FFmpegKitConfig.disableRedirection();
      FFmpegKitConfig.enableRedirection();
      FFmpegKitConfig.setLogLevel(LogLevel.info);
      await createDummyVideo();
      await createDummyAudio();
    });

    testWidgets('Debug Log', (WidgetTester tester) async {
      final session = FFmpegKit.createSession("-version");
      session.enableDebugLog();
      session.execute();
      await SessionQueueManager().waitForAll();
      if (kDebugMode) print("Session ID: ${session.sessionId}");
      if (kDebugMode) print("Debug enabled: ${session.isDebugLogEnabled()}");
      if (kDebugMode) print("Return Code: ${session.getReturnCode()}");
      if (kDebugMode) print("State: ${session.getState()}");
      if (kDebugMode) print("Logs length: ${session.getDebugLog().length}");

      expect(session.getState(), SessionState.completed);
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
      expect(session.getCommand(), contains("-version"));
      expect(session.isDebugLogEnabled(), isTrue);
      expect(session.getDebugLog().length, greaterThan(0));
      session.disableDebugLog();
      expect(session.isDebugLogEnabled(), isFalse);
      session.clearDebugLog();
      expect(session.getDebugLog().length, 0);
      if (kDebugMode) print(session.getDebugLog());
    });

    testWidgets('Execute Async - Version Command', (WidgetTester tester) async {
      final session = await FFmpegKit.executeAsync('-version');
      if (kDebugMode) {
        print("Async execution completed for Session: ${session.sessionId}");
      }
      expect(session.getState(), SessionState.completed);
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
      if (kDebugMode) print(session.getOutput());
    });

    testWidgets('Create Session Without Execution',
        (WidgetTester tester) async {
      final session = FFmpegKit.createSession("-version");
      if (kDebugMode) print("Created Session ID: ${session.sessionId}");
      expect(session.getState(), SessionState.created);
      expect(session.getCommand(), contains("-version"));
      if (kDebugMode) print(session.getOutput());
    });

    testWidgets('Session History Management', (WidgetTester tester) async {
      FFmpegKitConfig.setSessionHistorySize(10);

      // Create multiple sessions
      for (int i = 0; i < 3; i++) {
        final s = FFmpegKit.execute("-version");
        if (kDebugMode) print("History Session ID: ${s.sessionId}");
        if (kDebugMode) print(s.getOutput());
      }
      await SessionQueueManager().waitForAll();

      final sessions = FFmpegKit.getFFmpegSessions();
      if (kDebugMode) print("Sessions count: ${sessions.length}");
      expect(sessions.length, greaterThanOrEqualTo(3));

      final lastSession = FFmpegKit.getLastFFmpegSession();
      if (kDebugMode) print("Last Session ID: ${lastSession?.sessionId}");
      expect(lastSession, isNotNull);
      if (kDebugMode) print(lastSession?.getOutput());
    });

    testWidgets('Session Cancel', (WidgetTester tester) async {
      final session =
          FFmpegKit.createSession("-i $videoPath -c:v mpeg4 -f null -");

      // Start execution in background
      await session.executeAsync();
      await wait(1);

      // Cancel the session
      FFmpegKit.cancel(session);
      await wait(1);

      // Session should be cancelled or completed
      expect(session.getState(),
          isIn([SessionState.completed, SessionState.failed]));
      if (kDebugMode) print(session.getOutput());
    });

    testWidgets('Session Output and Logs', (WidgetTester tester) async {
      final session = FFmpegKit.execute("-version");
      await SessionQueueManager().waitForAll();
      if (kDebugMode) print("Test 6 Session ID: ${session.sessionId}");

      final output = session.getOutput();
      final logs = session.getLogs();

      if (kDebugMode) print("Output length: ${output?.length}");
      if (kDebugMode) print("Logs length: ${logs?.length}");
      if ((output?.length ?? 0) > 0) {
        if (kDebugMode) {
          print(
              "Output sample: ${output!.substring(0, output.length > 100 ? 100 : output.length)}");
        }
      }
      if ((logs?.length ?? 0) > 0) {
        if (kDebugMode) {
          print(
              "Logs sample: ${logs!.substring(0, logs.length > 100 ? 100 : logs.length)}");
        }
      }

      expect(output, isNotNull);
      expect(logs, isNotNull);
    });

    testWidgets('Session Timing Information', (WidgetTester tester) async {
      final session = FFmpegKit.execute("-version");
      await SessionQueueManager().waitForAll();

      final createTime = session.getCreateTime();
      final startTime = session.getStartTime();
      final endTime = session.getEndTime();
      final duration = session.getDuration();

      if (kDebugMode) {
        print(
            "Create: $createTime, Start: $startTime, End: $endTime, Duration: $duration");
      }

      expect(createTime.millisecondsSinceEpoch, greaterThan(0));
      expect(startTime, isNotNull);
      expect(endTime, isNotNull);
      expect(duration, greaterThanOrEqualTo(0));
      if (kDebugMode) print(session.getOutput());
    });

    testWidgets('Session Log Entries', (WidgetTester tester) async {
      FFmpegKitConfig.enableRedirection();
      final session = FFmpegKit.execute("-version");
      await SessionQueueManager().waitForAll();

      final logsCount = session.getLogsCount();
      if (kDebugMode) print("Logs count: $logsCount");

      if (logsCount > 0) {
        final firstLog = session.getLogAt(0);
        final firstLogLevel = session.getLogLevelAt(0);
        if (kDebugMode) print("First log: $firstLog");
        if (kDebugMode) print("First log level: $firstLogLevel");
        expect(firstLog, isNotNull);
      }
      if (kDebugMode) print(session.getOutput());
    });

    testWidgets('Session Type Checks', (WidgetTester tester) async {
      final session = FFmpegKit.execute("-version");
      // No need to wait for type check, type is static
      expect(session.isFFmpegSession(), isTrue);
      expect(session.isFFplaySession(), isFalse);
      expect(session.isFFprobeSession(), isFalse);
      expect(session.isMediaInformationSession(), isFalse);
      if (kDebugMode) print(session.getOutput());
    });

    testWidgets('Video Transcoding', (WidgetTester tester) async {
      final outputPath =
          path.join(outputDir, 'transcoded.mp4').replaceAll(r'\', '/');
      final session =
          FFmpegKit.execute("-i $videoPath -c:v mpeg4 -q:v 5 -y $outputPath");
      await SessionQueueManager().waitForAll();

      if (kDebugMode) print("Transcoding result: ${session.getReturnCode()}");
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
      expect(File(outputPath).existsSync(), isTrue);
      if (kDebugMode) print(session.getOutput());
    });

    testWidgets('Callbacks - Log and Statistics', (WidgetTester tester) async {
      final logs = <Log>[];
      final stats = <Statistics>[];

      final outputPath =
          path.join(outputDir, 'callback_test.mp4').replaceAll(r'\', '/');

      final session = await FFmpegKit.executeAsync(
        "-i $videoPath -c:v mpeg4 -q:v 5 -y $outputPath",
        onLog: (log) {
          logs.add(log);
        },
        onStatistics: (statistics) {
          stats.add(statistics);
        },
      );

      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);

      if (logs.isEmpty) {
        if (kDebugMode) {
          print(
              "Callback Logs were empty. Session Logs: \n${session.getLogs()}");
        }
        if (kDebugMode) print("Session Output: \n${session.getOutput()}");
      }
      expect(logs.length, greaterThan(0));
      if (kDebugMode) print(logs);
      expect(stats.length, greaterThan(0));
      if (kDebugMode) print(stats);
    });
  });

  group('Output Capture and Synchronization Tests', () {
    setUp(() async => await setUpAll());
    setUp(() async {
      FFmpegKitConfig.setLogLevel(LogLevel.trace);
      await createDummyVideo();
      await createDummyAudio();
    });

    testWidgets('Sync Execution - Ensure Output Captured (-version)',
        (WidgetTester tester) async {
      final session = FFmpegKit.execute("-version");
      await SessionQueueManager().waitForAll();

      final output = session.getOutput();
      if (kDebugMode) print("Sync FFmpeg -version output: \n$output");
      if (kDebugMode) {
        print("Sync FFmpeg -version logs count: ${session.getLogsCount()}");
      }

      expect(output, isNotNull);
      expect(output,
          anyOf(contains("ffmpeg-kit version"), contains("ffmpeg version"),
              contains("ffplay version")));
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
    });

    testWidgets('Async Execution - Ensure Output Captured (-version)',
        (WidgetTester tester) async {
      final session = await FFmpegKit.executeAsync("-version");
      final output = session.getOutput();
      if (kDebugMode) print("Async FFmpeg -version output: \n$output");

      expect(output, isNotNull);
      expect(output,
          anyOf(contains("ffmpeg-kit version"), contains("ffmpeg version"),
              contains("ffplay version")));
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
    });

    testWidgets('Sync Execution - Help Output (-h)',
        (WidgetTester tester) async {
      final session = FFmpegKit.execute("-h");
      //await SessionQueueManager().waitForAll();

      final output = session.getOutput();
      if (kDebugMode) {
        print(
            "Sync FFmpeg -h output (partial): \n${output?.substring(0, output.length > 500 ? 500 : output.length)}");
      }
      if (kDebugMode) print("Sync FFmpeg -h output: \n$output");

      expect(output, isNotNull);
      // Banner should always be there
      expect(
          output,
          anyOf(
              contains("ffmpeg-kit version"),
              contains("ffmpeg version"),
              contains("Configuration:"),
              contains("Universal media converter")));
      // Help content check
      expect(
          output,
          anyOf(contains("Universal media converter"), contains("usage:"),
              contains("Hyper fast")));
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
    });

    testWidgets('FFprobe Sync Execution - Output Captured (-version)',
        (WidgetTester tester) async {
      final session = FFprobeKit.execute("-version");
      await SessionQueueManager().waitForAll();

      final output = session.getOutput();
      if (kDebugMode) print("Sync FFprobe -version output: \n$output");

      expect(output, isNotNull);
      expect(
          output,
          anyOf(contains("ffprobe version"), contains("ffmpeg-kit version"),
              contains("ffmpeg version"), contains("ffplay version")));
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
      if (kDebugMode) print(output);
    });
  });

  group('FFprobeKit Tests', () {
    setUp(() async => await setUpAll());
    setUp(() async {
      await createDummyVideo();
      await createDummyAudio();
    });
    testWidgets('Execute Sync - Version', (WidgetTester tester) async {
      final session = FFprobeKit.execute("-version");
      await SessionQueueManager().waitForAll();

      expect(session.getState(), SessionState.completed);
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
      expect(session.isFFprobeSession(), isTrue);
      if (kDebugMode) print(session.getOutput());
    });

    testWidgets('Execute Async - Version', (WidgetTester tester) async {
      final session = await FFprobeKit.executeAsync("-version");
      expect(session.getState(), SessionState.completed);
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);
      if (kDebugMode) print(session.getOutput());
    });

    testWidgets('Get Media Information - Video', (WidgetTester tester) async {
      final session = FFprobeKit.getMediaInformation(videoPath);
      await SessionQueueManager().waitForAll();

      if (kDebugMode) print("FFprobe result: ${session.getReturnCode()}");
      if (kDebugMode) print("FFprobe output: ${session.getOutput()}");
      expect(session.getState(), SessionState.completed);
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);

      final mediaInfo = session.getMediaInformation();
      expect(mediaInfo, isNotNull);

      if (kDebugMode) print("Filename: ${mediaInfo!.filename}");
      if (kDebugMode) print("Format: ${mediaInfo!.format}");
      if (kDebugMode) print("Duration: ${mediaInfo!.duration}");
      if (kDebugMode) print("Streams: ${mediaInfo!.streams.length}");

      expect(mediaInfo!.filename, isNotNull);
      expect(mediaInfo.format, isNotNull);
      expect(mediaInfo.streams.length, greaterThan(0));
      if (kDebugMode) print(session.getOutput());
    });

    testWidgets('Get Media Information Async', (WidgetTester tester) async {
      final session = await FFprobeKit.getMediaInformationAsync(audioPath);
      if (kDebugMode) print("Return Code: ${session.getReturnCode()}");
      // Add more detailed check or print
      if (!ReturnCode.isSuccess(session.getReturnCode())) {
        if (kDebugMode) {
          print("FFprobe failed with return code: ${session.getReturnCode()}");
        }
        if (kDebugMode) print("FFprobe Logs: \n${session.getLogs()}");
        if (kDebugMode) print("FFprobe Output: \n${session.getOutput()}");
        if (kDebugMode) {
          print("FFprobe StackTrace: \n${session.getFailStackTrace()}");
        }
      }
      expect(ReturnCode.isSuccess(session.getReturnCode()), isTrue);

      final mediaInfo = session.getMediaInformation();
      expect(mediaInfo, isNotNull);
      if (kDebugMode) print("Audio format: ${mediaInfo!.format}");
      if (kDebugMode) print("Audio streams: ${mediaInfo!.streams.length}");
    });

    testWidgets('Stream Information Details', (WidgetTester tester) async {
      final session = FFprobeKit.getMediaInformation(videoPath);
      await SessionQueueManager().waitForAll();
      final mediaInfo = session.getMediaInformation();

      expect(mediaInfo, isNotNull);
      expect(mediaInfo!.streams.length, greaterThan(0));

      final stream = mediaInfo.streams.first;
      if (kDebugMode) print("Stream type: ${stream.type}");
      if (kDebugMode) print("Stream codec: ${stream.codec}");
      if (kDebugMode) print("Stream width: ${stream.width}");
      if (kDebugMode) print("Stream height: ${stream.height}");

      expect(stream.type, isNotNull);
      expect(stream.codec, isNotNull);
      if (kDebugMode) print(session.getOutput());
    });

    testWidgets('Create Session Without Execution',
        (WidgetTester tester) async {
      final session = FFprobeKit.createSession("-version");
      expect(session.getState(), SessionState.created);
    });

    testWidgets('Get FFprobe Sessions', (WidgetTester tester) async {
      FFprobeKit.execute("-version");
      FFprobeKit.execute("-version");
      await SessionQueueManager().waitForAll();

      final sessions = FFprobeKit.getFFprobeSessions();
      for (var session in sessions) {
        if (kDebugMode) print(session.getOutput());
      }
      expect(sessions.length, greaterThanOrEqualTo(2));
    });

    testWidgets('Session Type Checks', (WidgetTester tester) async {
      final session = FFprobeKit.execute("-version");

      expect(session.isFFmpegSession(), isFalse);
      expect(session.isFFplaySession(), isFalse);
      expect(session.isFFprobeSession(), isTrue);
      expect(session.isMediaInformationSession(), isFalse);
      if (kDebugMode) print(session.getOutput());
    });
  });

  group('MediaInformationSession Tests', () {
    setUp(() async => await setUpAll());
    setUp(() async {
      await createDummyVideo();
      await createDummyAudio();
    });
    testWidgets('Media Information Type Check', (WidgetTester tester) async {
      final session = FFprobeKit.getMediaInformation(videoPath);
      // Ensure completion before checking properties that might depend on state, though type check is static
      await SessionQueueManager().waitForAll();

      expect(session.isFFmpegSession(), isFalse);
      expect(session.isFFplaySession(), isFalse);
      expect(session.isFFprobeSession(), isFalse);
      expect(session.isMediaInformationSession(), isTrue);
      if (kDebugMode) print(session.getOutput());
    });

    testWidgets('Media Information Properties', (WidgetTester tester) async {
      final session = FFprobeKit.getMediaInformation(videoPath);
      await SessionQueueManager().waitForAll();
      final mediaInfo = session.getMediaInformation();

      expect(mediaInfo, isNotNull);

      // Test all properties
      if (kDebugMode) print("Filename: ${mediaInfo!.filename}");
      if (kDebugMode) print("Format: ${mediaInfo!.format}");
      if (kDebugMode) print("Long Format: ${mediaInfo!.longFormat}");
      if (kDebugMode) print("Duration: ${mediaInfo!.duration}");
      if (kDebugMode) print("Start Time: ${mediaInfo!.startTime}");
      if (kDebugMode) print("Bitrate: ${mediaInfo!.bitrate}");
      if (kDebugMode) print("Size: ${mediaInfo!.size}");

      // Test parsed properties
      final tags = mediaInfo!.tags;
      final allProps = mediaInfo.allProperties;

      if (kDebugMode) print("Tags: $tags");
      if (kDebugMode) print("All Properties keys: ${allProps?.keys}");
      if (kDebugMode) print(session.getOutput());
    });

    testWidgets('Stream Information Properties', (WidgetTester tester) async {
      final session = FFprobeKit.getMediaInformation(videoPath);
      await SessionQueueManager().waitForAll();
      final mediaInfo = session.getMediaInformation();

      expect(mediaInfo, isNotNull);
      expect(mediaInfo!.streams.length, greaterThan(0));
      if (kDebugMode) print(session.getOutput());
      for (var stream in mediaInfo.streams) {
        if (kDebugMode) print("\n--- Stream ${stream.index} ---");
        if (kDebugMode) print("Type: ${stream.type}");
        if (kDebugMode) print("Codec: ${stream.codec}");

        if (kDebugMode) print("Codec Long: ${stream.codecLong}");
        if (kDebugMode) print("Format: ${stream.format}");
        if (kDebugMode) print("Width: ${stream.width}");
        if (kDebugMode) print("Height: ${stream.height}");
        if (kDebugMode) print("Bitrate: ${stream.bitrate}");
        if (kDebugMode) print("Sample Rate: ${stream.sampleRate}");
        if (kDebugMode) print("Channel Layout: ${stream.channelLayout}");
        if (kDebugMode) print("Frame Rate: ${stream.averageFrameRate}");
      }
    });
  });

  group('FFplayKit Tests', () {
    setUp(() async => await setUpAll());
    setUp(() async {
      await createDummyVideo();
      await createDummyAudio();
    });
    testWidgets('Play and Stop', (WidgetTester tester) async {
      final session = await FFplayKit.executeAsync('-i $videoPath');
      await wait(2);

      expect(session.isPlaying(), isTrue);
      expect(FFplayKit.isPlaying(), isTrue);

      FFplayKit.stop();
      await wait(1);

      expect(session.getState(), SessionState.completed);
      if (kDebugMode) print(session.getOutput());
    });

    testWidgets('Pause and Resume', (WidgetTester tester) async {
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
      if (kDebugMode) print(session.getOutput());
      session.close();
    });

    testWidgets('Seek Position', (WidgetTester tester) async {
      final session = await FFplayKit.executeAsync('-i $videoPath');
      await wait(2);

      session.seek(3.0);
      await wait(1);

      final pos = session.getPosition();
      if (kDebugMode) print("Position after seek: $pos");
      expect(pos, greaterThanOrEqualTo(2.0));

      session.stop();
      await wait(1);
      if (kDebugMode) print(session.getOutput());
      session.close();
    });

    testWidgets('Get Duration and Position', (WidgetTester tester) async {
      final session = await FFplayKit.executeAsync('-i $videoPath');
      await wait(2);

      final duration = session.getMediaDuration();
      final position = session.getPosition();

      if (kDebugMode) print("Duration: $duration, Position: $position");

      expect(duration, greaterThan(0));
      expect(position, greaterThanOrEqualTo(0));

      session.stop();
      await wait(1);
      if (kDebugMode) print(session.getOutput());
      session.close();
    });

    testWidgets('Volume Control', (WidgetTester tester) async {
      final session = await FFplayKit.executeAsync('-i $videoPath');
      await wait(1);

      session.setVolume(0.5);
      final volume = session.getVolume();

      if (kDebugMode) print("Volume: $volume");
      expect(volume, greaterThanOrEqualTo(0.0));
      expect(volume, lessThanOrEqualTo(1.0));

      session.stop();
      await wait(1);
      if (kDebugMode) print(session.getOutput());
      session.close();
    });

    testWidgets('Global Controls', (WidgetTester tester) async {
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
      if (kDebugMode) print(FFplayKit.getCurrentSession()?.getOutput());
      FFplayKit.close();
    });

    testWidgets('FFplay Global Session Enforcement',
        (WidgetTester tester) async {
      final session1 = await FFplayKit.executeAsync('-i $videoPath');
      await wait(2);
      expect(session1.isPlaying(), isTrue);

      final session2 = await FFplayKit.executeAsync('-i $videoPath');
      await wait(2);

      // Since FFplay automatically handles global session by stopping the previous one
      // in its internal logic (wrapped in CallbackManager or similar),
      // session1 should be completed or cancelled.
      expect(session1.getState(), SessionState.completed);
      expect(session2.isPlaying(), isTrue);

      session2.stop();
      await wait(1);
      if (kDebugMode) print(session2.getOutput());
      session2.close();
    });

    testWidgets('Get Current Session', (WidgetTester tester) async {
      final session = await FFplayKit.executeAsync('-i $videoPath');
      await wait(1);

      final currentSession = FFplayKit.getCurrentSession();
      expect(currentSession, isNotNull);
      expect(currentSession, equals(session));

      session.stop();
      await wait(1);
      if (kDebugMode) print(session.getOutput());
      session.close();
    });

    testWidgets('Session Type Checks', (WidgetTester tester) async {
      final session = await FFplayKit.executeAsync('-i $videoPath');

      expect(session.isFFmpegSession(), isFalse);
      expect(session.isFFplaySession(), isTrue);
      expect(session.isFFprobeSession(), isFalse);
      expect(session.isMediaInformationSession(), isFalse);

      session.stop();
      await wait(1);
      if (kDebugMode) print(session.getOutput());
      session.close();
    });

    testWidgets('Create Session Without Execution',
        (WidgetTester tester) async {
      final session = await FFplayKit.createSession('-i $videoPath');
      expect(session.getState(), SessionState.created);
    });
  });

  group('Return Code and Session State Tests', () {
    setUp(() async => await setUpAll());
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
    setUp(() async => await setUpAll());
    setUp(() async {
      await createDummyVideo();
      await createDummyAudio();
      SessionQueueManager().maxConcurrentSessions = 8; // Reset to default
    });

    tearDown(() async {
      try {
        SessionQueueManager().cancelAll();
      } catch (e) {
        if (kDebugMode) {
          print("DEBUG: Suppressed error during tearDown cancelAll: $e");
        }
      }
      await SessionQueueManager().waitForAll();
    });

    testWidgets('Concurrency Limit and Queue Processing',
        (WidgetTester tester) async {
      final queueManager = SessionQueueManager();
      queueManager.maxConcurrentSessions = 2;

      final output1 =
          path.join(outputDir, 'queue_test1.mp4').replaceAll(r'\', '/');
      final output2 =
          path.join(outputDir, 'queue_test2.mp4').replaceAll(r'\', '/');
      final output3 =
          path.join(outputDir, 'queue_test3.mp4').replaceAll(r'\', '/');

      // Check initial state - should be empty
      expect(queueManager.activeSessionCount, 0);
      expect(queueManager.queueLength, 0);

      // Execute three sessions sequentially, checking the queue state
      final s1 = await FFmpegKit.executeAsync(
          "-re $dummyVideoCommand -t 2 -y $output1");
      expect(ReturnCode.isSuccess(s1.getReturnCode()), isTrue);

      final s2 = await FFmpegKit.executeAsync(
          "-re $dummyVideoCommand -t 2 -y $output2");
      expect(ReturnCode.isSuccess(s2.getReturnCode()), isTrue);

      final s3 = await FFmpegKit.executeAsync(
          "-re $dummyVideoCommand -t 2 -y $output3");
      expect(ReturnCode.isSuccess(s3.getReturnCode()), isTrue);

      // After all complete, queue should be empty
      expect(queueManager.isBusy, isFalse);
      expect(queueManager.queueLength, 0);
    });

    testWidgets('Queue Manager - Cancel Current', (WidgetTester tester) async {
      final queueManager = SessionQueueManager();
      final completer = Completer<FFmpegSession>();
      final output =
          path.join(outputDir, 'cancel_current.mp4').replaceAll(r'\', '/');

      if (kDebugMode) print("DEBUG: Starting Cancel Current session...");
      // Fire-and-forget: the session must run in the background so we can
      // check isBusy and cancel it while it is still active.
      unawaited(FFmpegKit.executeAsync(
          "-re $dummyVideoCommand -t 10 -y $output",
          onComplete: (s) => completer.complete(s)));

      await Future.delayed(const Duration(milliseconds: 1000));
      if (kDebugMode) {
        print(
            "DEBUG: isBusy=${queueManager.isBusy}, activeSessionCount=${queueManager.activeSessionCount}");
      }
      expect(queueManager.isBusy, isTrue);

      if (kDebugMode) print("DEBUG: Cancelling current...");
      queueManager.cancelCurrent();

      int attempts = 0;
      bool cancelled = false;
      while (attempts < 5 && !cancelled) {
        final session = await completer.future;
        final rc = session.getReturnCode();
        if (kDebugMode) {
          print(
              "DEBUG: Attempt $attempts, Session ID: ${session.sessionId}, RC: $rc");
        }
        if (ReturnCode.isCancel(rc)) {
          cancelled = true;
          break;
        }

        if (session.getState() == SessionState.completed) {
          if (kDebugMode) {
            print(
                "DEBUG: Session completed before cancel. OK for concurrency check.");
          }
          cancelled = true;
        }

        attempts++;
        if (!cancelled) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      int cleanupAttempts = 0;
      while (cleanupAttempts < 5 && queueManager.isBusy) {
        if (kDebugMode) {
          print(
              "DEBUG: Cleanup attempt $cleanupAttempts, isBusy=${queueManager.isBusy}");
        }
        await Future.delayed(const Duration(milliseconds: 1000));
        cleanupAttempts++;
      }
      expect(queueManager.isBusy, isFalse);
    });

    testWidgets('Queue Manager - Clear Queue', (WidgetTester tester) async {
      final queueManager = SessionQueueManager();
      queueManager.maxConcurrentSessions = 1;
      final cancelCompleter = Completer<void>();

      // Start one session and queue others — fire-and-forget so both sessions
      // remain in-flight while we inspect and manipulate the queue.
      if (kDebugMode) print("DEBUG: Starting first session for Clear Queue...");
      unawaited(FFmpegKit.executeAsync(
          "-re $dummyVideoCommand -t 5 -y ${path.join(outputDir, 'q1.mp4')}"));

      if (kDebugMode) print("DEBUG: Queueing second session...");
      bool caughtCancelled = false;
      unawaited(FFmpegKit.executeAsync("-version").catchError((e) {
        if (kDebugMode) print("DEBUG: Caught expected error: $e");
        if (e is SessionCancelledException) {
          caughtCancelled = true;
          cancelCompleter.complete();
        }
        return FFmpegKit.createSession("-version");
      }));

      await Future.delayed(const Duration(milliseconds: 1000));
      if (kDebugMode) print("DEBUG: queueLength=${queueManager.queueLength}");
      expect(queueManager.queueLength, greaterThan(0));

      if (kDebugMode) print("DEBUG: Clearing queue...");
      queueManager.clearQueue();
      expect(queueManager.queueLength, 0);

      await cancelCompleter.future.timeout(const Duration(seconds: 2),
          onTimeout: () {
        if (kDebugMode) print("DEBUG: Timeout waiting for cancel exception");
      });
      expect(caughtCancelled, isTrue);

      queueManager.cancelCurrent();
      await queueManager.waitForAll();
    });

    testWidgets('Queue Manager - Cancel All', (WidgetTester tester) async {
      final queueManager = SessionQueueManager();
      queueManager.maxConcurrentSessions = 1;

      // Fire-and-forget so both sessions remain in-flight while we check
      // state and then cancel them.
      if (kDebugMode) print("DEBUG: Starting session 1 for Cancel All...");
      unawaited(FFmpegKit.executeAsync(
          "-re $dummyVideoCommand -t 5 -y ${path.join(outputDir, 'a1.mp4')}"));

      if (kDebugMode) print("DEBUG: Queueing session 2 for Cancel All...");
      unawaited(FFmpegKit.executeAsync("-version").catchError((e) {
        if (kDebugMode) print("DEBUG: Session 2 caught expected error: $e");
        return FFmpegSession.create("-version");
      }));

      await Future.delayed(const Duration(milliseconds: 1000));
      if (kDebugMode) {
        print(
            "DEBUG: isBusy=${queueManager.isBusy}, queueLength=${queueManager.queueLength}");
      }
      expect(queueManager.isBusy, isTrue);
      expect(queueManager.queueLength, 1);

      if (kDebugMode) print("DEBUG: Cancelling all...");
      try {
        queueManager.cancelAll();
      } catch (e) {
        if (kDebugMode) {
          print("DEBUG: Caught expected exception during cancelAll: $e");
        }
      }
      await Future.delayed(const Duration(milliseconds: 3000));

      int cleanupAttempts = 0;
      while (cleanupAttempts < 5 && queueManager.isBusy) {
        if (kDebugMode) {
          print(
              "DEBUG: Cleanup attempt $cleanupAttempts, isBusy=${queueManager.isBusy}");
        }
        await Future.delayed(const Duration(milliseconds: 1000));
        cleanupAttempts++;
      }

      expect(queueManager.isBusy, isFalse);
      expect(queueManager.queueLength, 0);
    });
  });

  group('Log and Statistics Tests', () {
    setUp(() async => await setUpAll());
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

      if (kDebugMode) print(log.toString());
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

      if (kDebugMode) print(stats.toString());
    });
  });

  group('Memory Management Stress Tests', () {
    setUp(() async => await setUpAll());
    setUp(() async {
      await createDummyVideo();
      await createDummyAudio();
    });
    testWidgets('Stress Test - Version Strings', (WidgetTester tester) async {
      if (kDebugMode) print("Starting Version Strings Stress Test...");
      // Repeatedly calling a function that returns a string allocated by MinGW
      // and freed by Dart via ffmpeg_kit_free.
      for (int i = 0; i < 500; i++) {
        final version = FFmpegKitConfig.getFFmpegVersion();
        expect(version, isNotNull);
        expect(version, isNotEmpty);
        if (i % 100 == 0) if (kDebugMode) print("  Iterated $i times...");
      }
      if (kDebugMode) {
        print("Version Strings Stress Test completed successfully.");
      }
    });

    testWidgets('Stress Test - Session Lists', (WidgetTester tester) async {
      if (kDebugMode) print("Starting Session Lists Stress Test...");
      // getSessions allocates an array of pointers and then each command string.
      // Both the array and the strings must be freed correctly.
      for (int i = 0; i < 200; i++) {
        FFmpegKitConfig
            .clearSessions(); // Clear to keep list small but test the call
        FFmpegKit.execute("-version");
        final list = FFmpegKitExtended.getSessions();
        expect(list, isNotEmpty);
        if (i % 50 == 0) if (kDebugMode) print("  Iterated $i times...");
      }
      if (kDebugMode) {
        print("Session Lists Stress Test completed successfully.");
      }
    });

    testWidgets('Stress Test - Media Information', (WidgetTester tester) async {
      if (kDebugMode) print("Starting Media Information Stress Test...");
      // This is a heavy test because it involves many small string allocations
      // for all media properties, streams, and chapters.
      for (int i = 0; i < 50; i++) {
        final session = await FFprobeKit.getMediaInformationAsync(videoPath);
        final mediaInfo = session.getMediaInformation();
        expect(mediaInfo, isNotNull);
        expect(mediaInfo!.filename, isNotNull);
        if (i % 10 == 0) if (kDebugMode) print("  Iterated $i times...");
      }
      if (kDebugMode) {
        print("Media Information Stress Test completed successfully.");
      }
    });

    testWidgets('Stress Test - Argument Parsing', (WidgetTester tester) async {
      if (kDebugMode) print("Starting Argument Parsing Stress Test...");
      const cmd =
          "-i input.mp4 -c:v libx264 -preset fast -crf 23 -f mp4 output.mp4";
      for (int i = 0; i < 300; i++) {
        final args = FFmpegKitConfig.parseArguments(cmd);
        expect(args.length, greaterThan(5));
        final backToCmd = FFmpegKitConfig.argumentsToString(args);
        expect(backToCmd, contains("-i"));
        if (i % 100 == 0) if (kDebugMode) print("  Iterated $i times...");
      }
      if (kDebugMode) {
        print("Argument Parsing Stress Test completed successfully.");
      }
    });
  });

  group('Cleanup Tests', () {
    setUp(() async => await setUpAll());
    testWidgets('Clear Sessions', (WidgetTester tester) async {
      final session1 = FFmpegKit.execute("-version");
      final session2 = FFmpegKit.execute("-version");

      FFmpegKitConfig.clearSessions();

      // Sessions should be cleared
      final sessions = FFmpegKit.getFFmpegSessions();
      if (kDebugMode) print("Sessions after clear: ${sessions.length}");
      if (kDebugMode) print(session1.getOutput());
      if (kDebugMode) print(session2.getOutput());
    });

    testWidgets('Cleanup Test Files', (WidgetTester tester) async {
      if (outputDir.isNotEmpty && Directory(outputDir).existsSync()) {
        if (kDebugMode) print("Cleaning up test output directory: $outputDir");
        try {
          await Directory(outputDir).delete(recursive: true);
        } catch (e) {
          if (kDebugMode) print("Warning: Could not delete test directory: $e");
        }
      }
    });
  });
}
