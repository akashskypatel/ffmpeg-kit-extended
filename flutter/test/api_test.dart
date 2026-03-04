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

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffmpeg_kit_flutter_loader.dart';
import 'package:ffmpeg_kit_extended_flutter/src/generated/ffmpeg_kit_bindings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

// Callback Signatures
typedef NativeLogCallback = Void Function(
    Pointer<Void> session, Pointer<Char> log, Pointer<Void> userData);
typedef NativeCompleteCallback = Void Function(
    Pointer<Void> session, Pointer<Void> userData);
typedef NativeStatisticsCallback = Void Function(
    Pointer<Void> session,
    Int64 time,
    Int64 size,
    Double bitrate,
    Double speed,
    Int64 videoFrameNumber,
    Double videoFps,
    Double videoQuality,
    Pointer<Void> userData);

// --- Helper Functions and Type Definitions ---

Pointer<Char> toNative(String s, Arena arena) =>
    s.toNativeUtf8(allocator: arena).cast<Char>();

String? _fromNative(Pointer<Char> ptr) {
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

extension ArenaTrackers on Arena {
  /// Tracks FFmpeg handles (Sessions, MediaInformation, etc.) to be released via handle_release.
  Pointer<Void> trackHandle(Pointer<Void> handle, FFmpegKitBindings bindings) {
    if (handle != nullptr) {
      this.using(handle, bindings.ffmpeg_kit_handle_release);
    }
    return handle;
  }

  /// Tracks pointers allocated internally by the C library that must be freed with ffmpeg_kit_free.
  Pointer<T> trackKitPointer<T extends NativeType>(
      Pointer<T> ptr, FFmpegKitBindings bindings) {
    if (ptr != nullptr) {
      this.using(ptr.cast<Void>(), bindings.ffmpeg_kit_free);
    }
    return ptr;
  }

  /// Tracks pointers typically allocated using standard malloc/calloc that require calloc.free.
  Pointer<T> trackCalloc<T extends NativeType>(Pointer<T> ptr) {
    if (ptr != nullptr) {
      this.using(ptr, calloc.free);
    }
    return ptr;
  }
}

class _CallbackCapturer {
  bool completeCalled = false;
  bool logCalled = false;
  bool statsCalled = false;
  Pointer<Void>? capturedSession;
}

class _GlobalCapturer {
  bool logCalled = false;
  bool statsCalled = false;
  int completeCount = 0;
  List<String> callbacks = [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tempDir = Directory.systemTemp.createTempSync('ffmpeg_kit_native_test');
  final testVideoFile = path.join(tempDir.path, 'dummy_video.mp4');
  final testAudioFile = path.join(tempDir.path, 'dummy_audio.wav');

  // Convert paths to native C strings for use in tests
  String getTestVideoFile() =>
      testVideoFile.replaceAll(r'\', '/'); // FFmpeg likes forward slashes
  String getTestAudioFile() => testAudioFile.replaceAll(r'\', '/');

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    FFmpegKitConfig.clearSessions();
  });

  late FFmpegKitBindings bindings;
  bool libraryLoaded = false;

  setUpAll(() {
    try {
      bindings = ffmpeg;
      libraryLoaded = true;
    } catch (e) {
      if (kDebugMode) {
        print('Warning: Failed to load FFmpegKit library: $e');
      }
    }
  });

  void checkLibraryLoaded() {
    if (!libraryLoaded) {
      if (kDebugMode) print('Native library not loaded');
      throw Exception('Native library not loaded');
    }
  }

  setUp(() => using((Arena arena) {
        try {
          checkLibraryLoaded();
          final dummyDevicePtr = toNative("dummy", arena);
          final sdlVideoDriverPtr = toNative("SDL_VIDEODRIVER", arena);
          final sdlAudioDriverPtr = toNative("SDL_AUDIODRIVER", arena);
          final displayPtr = toNative("DISPLAY", arena);
          final displayValuePtr = toNative(":0", arena);
          bindings.ffmpeg_kit_config_set_environment_variable(
              sdlVideoDriverPtr, dummyDevicePtr);
          bindings.ffmpeg_kit_config_set_environment_variable(
              sdlAudioDriverPtr, dummyDevicePtr);
          bindings.ffmpeg_kit_config_set_environment_variable(
              displayPtr, displayValuePtr);
          // Force a clean state before every test
          bindings.ffmpeg_kit_config_clear_sessions();
          bindings.ffmpeg_kit_config_set_log_level(
              FFmpegKitLogLevel.FFMPEG_KIT_LOG_LEVEL_INFO);
          bindings.ffmpeg_kit_config_enable_redirection();

          // Reset all global callbacks to nullptr to prevent ghost listeners
          bindings.ffmpeg_kit_config_enable_log_callback(nullptr, nullptr);
          bindings.ffmpeg_kit_config_enable_statistics_callback(
              nullptr, nullptr);
          bindings.ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
              nullptr, nullptr);
          bindings.ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
              nullptr, nullptr);
          bindings.ffmpeg_kit_config_enable_ffplay_session_complete_callback(
              nullptr, nullptr);
          bindings
              .ffmpeg_kit_config_enable_media_information_session_complete_callback(
                  nullptr, nullptr);
        } catch (e) {
          if (kDebugMode) {
            print('Warning: Failed to load FFmpegKit library: $e');
          }
        }
      }));

  tearDown(() async {
    bindings.ffplay_kit_stop();
    // 1. Disable all global callbacks immediately
    bindings.ffmpeg_kit_config_enable_log_callback(nullptr, nullptr);
    bindings.ffmpeg_kit_config_enable_statistics_callback(nullptr, nullptr);
    bindings.ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
        nullptr, nullptr);
    bindings.ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
        nullptr, nullptr);
    bindings.ffmpeg_kit_config_enable_ffplay_session_complete_callback(
        nullptr, nullptr);
    bindings
        .ffmpeg_kit_config_enable_media_information_session_complete_callback(
            nullptr, nullptr);
    bindings.ffmpeg_kit_config_clear_sessions();
    await Future.delayed(const Duration(milliseconds: 500));
  });

  File generateTestVideoFile() => using((Arena arena) {
        final cmdStr =
            "-hide_banner -loglevel fatal -f lavfi -i testsrc=duration=30:size=512x512:rate=30 -y ${getTestVideoFile()}";
        final cmd = toNative(cmdStr, arena);
        final session = arena.trackHandle(
            bindings.ffmpeg_kit_create_session(cmd), bindings);
        bindings.ffmpeg_kit_session_execute(session);
        return File(testVideoFile);
      });

  File generateTestAudioFile() => using((Arena arena) {
        final cmdStr =
            "-hide_banner -loglevel fatal -f lavfi -i sine=frequency=1000:duration=30 -y ${getTestAudioFile()}";
        final cmd = toNative(cmdStr, arena);
        final session = arena.trackHandle(
            bindings.ffmpeg_kit_create_session(cmd), bindings);
        bindings.ffmpeg_kit_session_execute(session);
        return File(testAudioFile);
      });

  Future<void> waitForSessionToSettle(Pointer<Void> session,
      {int timeoutMs = 10000}) async {
    final start = DateTime.now();
    final sessionId = bindings.ffmpeg_kit_session_get_session_id(session);

    while (DateTime.now().difference(start).inMilliseconds < timeoutMs) {
      final state = bindings.ffmpeg_kit_session_get_state(session);

      // 0 = no messages in transit, everything is flushed
      final messagesInTransmit =
          bindings.ffmpeg_kit_config_messages_in_transmit(sessionId);

      final isTerminal =
          state == FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED ||
              state == FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_FAILED;

      // Condition: Process has exited AND internal message queue is empty
      if (isTerminal && messagesInTransmit == 0) {
        // Final microscopic delay to let the JSON parser/Log list finalize
        await Future.delayed(const Duration(milliseconds: 50));
        return;
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  group('FFmpegKit C API Pairity Tests', () {
    // --- Core Wrapper Tests (mirroring wrapper_test.cpp) ---

    test('FFmpegKitTest VersionCheck', () {
      using((Arena arena) {
        // char *version = ffmpeg_kit_config_get_ffmpeg_version();
        final Pointer<Char> versionPtr =
            bindings.ffmpeg_kit_config_get_ffmpeg_version();

        // ASSERT_NE(version, nullptr);
        expect(versionPtr, isNot(nullptr));

        final String? version = _fromNative(versionPtr);

        // EXPECT_STRNE(version, "");
        expect(version, isNotNull);
        expect(version, isNotEmpty);

        if (kDebugMode) print("FFmpeg Version: $version");

        // free(version);
        // Ensure library-allocated memory is freed using the library's free function
        bindings.ffmpeg_kit_free(versionPtr.cast());
      });
    });

    test('FFmpegKitTest SplitSessionExecution', () {
      using((Arena arena) {
        final cmd = "-hide_banner -loglevel fatal -version"
            .toNativeUtf8(allocator: arena)
            .cast<Char>();

        // FFmpegSessionHandle session = ffmpeg_kit_create_session(...)
        final session = bindings.ffmpeg_kit_create_session(cmd);
        expect(session, isNot(nullptr));

        // FFmpegKitSessionState state = ffmpeg_kit_session_get_state(session);
        var state = bindings.ffmpeg_kit_session_get_state(session);
        expect(state,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_CREATED));

        // ffmpeg_kit_session_execute(session);
        bindings.ffmpeg_kit_session_execute(session);

        state = bindings.ffmpeg_kit_session_get_state(session);

        if (state != FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED) {
          final returnCode =
              bindings.ffmpeg_kit_session_get_return_code(session);
          if (kDebugMode) print("Return Code: $returnCode");

          final logsPtr =
              bindings.ffmpeg_kit_session_get_logs_as_string(session);
          if (logsPtr != nullptr) {
            if (kDebugMode) print("Logs:\n${_fromNative(logsPtr)}");
            bindings.ffmpeg_kit_free(logsPtr.cast());
          }

          final failStackTracePtr =
              bindings.ffmpeg_kit_session_get_fail_stack_trace(session);
          if (failStackTracePtr != nullptr) {
            if (kDebugMode) {
              print("Fail Stack Trace:\n${_fromNative(failStackTracePtr)}");
            }
            bindings.ffmpeg_kit_free(failStackTracePtr.cast());
          }
        }

        expect(state,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

        // Cleanup
        bindings.ffmpeg_kit_handle_release(session);
      });
    });

    test('FFmpegKitTest DebugLog', () {
      using((Arena arena) {
        final cmd = "-hide_banner -loglevel fatal -version"
            .toNativeUtf8(allocator: arena)
            .cast<Char>();

        // FFmpegSessionHandle session = ffmpeg_kit_create_session(...)
        final session = bindings.ffmpeg_kit_create_session(cmd);
        expect(session, isNot(nullptr));

        // FFmpegKitSessionState state = ffmpeg_kit_session_get_state(session);
        var state = bindings.ffmpeg_kit_session_get_state(session);
        expect(state,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_CREATED));

        // ffmpeg_kit_config_enable_debug_log(session);
        bindings.ffmpeg_kit_config_enable_debug_log(session);
        expect(
            bindings.ffmpeg_kit_config_is_debug_log_enabled(session), isTrue);

        // ffmpeg_kit_session_execute(session);
        bindings.ffmpeg_kit_session_execute(session);

        state = bindings.ffmpeg_kit_session_get_state(session);

        if (state != FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED) {
          final returnCode =
              bindings.ffmpeg_kit_session_get_return_code(session);
          if (kDebugMode) print("Return Code: $returnCode");

          final logsPtr =
              bindings.ffmpeg_kit_session_get_logs_as_string(session);
          if (logsPtr != nullptr) {
            if (kDebugMode) print("Logs:\n${_fromNative(logsPtr)}");
            bindings.ffmpeg_kit_free(logsPtr.cast());
          }
        }

        // char *debugLog = ffmpeg_kit_config_get_debug_log(session);
        final debugLogPtr = bindings.ffmpeg_kit_config_get_debug_log(session);
        expect(debugLogPtr, isNot(nullptr));
        if (kDebugMode) print("Debug Log:\n${_fromNative(debugLogPtr)}");
        bindings.ffmpeg_kit_free(debugLogPtr.cast());

        // ffmpeg_kit_config_disable_debug_log(session);
        bindings.ffmpeg_kit_config_disable_debug_log(session);
        expect(
            bindings.ffmpeg_kit_config_is_debug_log_enabled(session), isFalse);

        // ffmpeg_kit_config_clear_debug_log(session);
        bindings.ffmpeg_kit_config_clear_debug_log(session);
        final debugLogPtr2 = bindings.ffmpeg_kit_config_get_debug_log(session);
        expect(_fromNative(debugLogPtr2), isEmpty);
        bindings.ffmpeg_kit_free(debugLogPtr2.cast());

        expect(state,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

        // Cleanup
        bindings.ffmpeg_kit_handle_release(session);
      });
    });

    test('FFmpegKitTest ConfigurationSetters', () {
      using((Arena arena) {
        // ffmpeg_kit_config_set_log_level(FFMPEG_KIT_LOG_LEVEL_QUIET);
        bindings.ffmpeg_kit_config_set_log_level(
            FFmpegKitLogLevel.FFMPEG_KIT_LOG_LEVEL_QUIET);

        // EXPECT_EQ(ffmpeg_kit_config_get_log_level(), FFMPEG_KIT_LOG_LEVEL_QUIET);
        final level = bindings.ffmpeg_kit_config_get_log_level();
        expect(level, equals(FFmpegKitLogLevel.FFMPEG_KIT_LOG_LEVEL_QUIET));
      });
    });

    test('FFmpegKitTest SessionHistory', () {
      using((Arena arena) {
        // ffmpeg_kit_set_session_history_size(10);
        bindings.ffmpeg_kit_set_session_history_size(10);

        // int history_size = ffmpeg_kit_get_session_history_size();
        final historySize = bindings.ffmpeg_kit_get_session_history_size();
        if (kDebugMode) print("History size: $historySize");
        expect(historySize, equals(10));

        // Get initial count to compare later
        int initialCount = 0;
        final Pointer<FFmpegSessionHandle> initialSessionsPtr =
            bindings.ffmpeg_kit_get_sessions();
        if (initialSessionsPtr != nullptr) {
          final list = initialSessionsPtr.cast<Pointer<Void>>();
          while (list[initialCount] != nullptr) {
            bindings.ffmpeg_kit_handle_release(list[initialCount]);
            initialCount++;
          }
          bindings.ffmpeg_kit_free(initialSessionsPtr.cast());
        }

        // Create a few sessions to populate history
        final cmd = "-hide_banner -loglevel fatal -version"
            .toNativeUtf8(allocator: arena)
            .cast<Char>();
        for (int i = 0; i < 3; i++) {
          final s = bindings.ffmpeg_kit_create_session(cmd);
          bindings.ffmpeg_kit_session_execute(s);
          bindings.ffmpeg_kit_handle_release(s);
        }

        // FFmpegSessionHandle *sessions = ffmpeg_kit_get_sessions();
        final Pointer<FFmpegSessionHandle> sessionsPtr =
            bindings.ffmpeg_kit_get_sessions();
        expect(sessionsPtr, isNot(nullptr));

        int count = 0;
        final list = sessionsPtr.cast<Pointer<Void>>();
        while (list[count] != nullptr) {
          // ffmpeg_kit_handle_release(sessions[count]);
          bindings.ffmpeg_kit_handle_release(list[count]);
          count++;
        }

        // free(sessions);
        bindings.ffmpeg_kit_free(sessionsPtr.cast());

        if (kDebugMode) print("Count: $count, Initial Count: $initialCount");
        // EXPECT_GT(count, initial_count);
        expect(count, greaterThan(initialCount));
      });
    });

    test('FFmpegKitTest GenerateTestVideoFile', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        // FFmpegSessionHandle session = ffmpeg_kit_create_session(...)
        final cmdStr =
            "-hide_banner -loglevel fatal -f lavfi -i testsrc=duration=30:size=512x512:rate=30 -y ${getTestVideoFile()}";
        final cmd = cmdStr.toNativeUtf8(allocator: arena).cast<Char>();

        final session = bindings.ffmpeg_kit_create_session(cmd);
        expect(session, isNot(nullptr));

        // ffmpeg_kit_session_execute(session);
        bindings.ffmpeg_kit_session_execute(session);

        // EXPECT_EQ(ffmpeg_kit_session_get_state(session), FFMPEG_KIT_SESSION_STATE_COMPLETED);
        final state = bindings.ffmpeg_kit_session_get_state(session);
        expect(state,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

        // ffmpeg_kit_handle_release(session);
        bindings.ffmpeg_kit_handle_release(session);

        // EXPECT_TRUE(access(TEST_VIDEO_FILE, F_OK) == 0);
        final fileExists = await File(testVideoFile).exists();
        if (kDebugMode) print("File exists: $fileExists");
        expect(fileExists, isTrue);
      });
    });

    test('FFmpegKitTest GenerateTestAudioFile', () async {
      if (!File(getTestAudioFile()).existsSync()) {
        generateTestAudioFile();
      }
      await using((Arena arena) async {
        // FFmpegSessionHandle session = ffmpeg_kit_create_session(...)
        final cmdStr =
            "-hide_banner -loglevel fatal -f lavfi -i sine=frequency=1000:duration=5 -y ${getTestAudioFile()}";
        final cmd = cmdStr.toNativeUtf8(allocator: arena).cast<Char>();

        final session = bindings.ffmpeg_kit_create_session(cmd);
        expect(session, isNot(nullptr));

        // ffmpeg_kit_session_execute(session);
        bindings.ffmpeg_kit_session_execute(session);

        // EXPECT_EQ(ffmpeg_kit_session_get_state(session), FFMPEG_KIT_SESSION_STATE_COMPLETED);
        final state = bindings.ffmpeg_kit_session_get_state(session);
        expect(state,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

        // ffmpeg_kit_handle_release(session);
        bindings.ffmpeg_kit_handle_release(session);

        // EXPECT_TRUE(access(TEST_AUDIO_FILE, F_OK) == 0);
        final fileExists = await File(testAudioFile).exists();
        if (kDebugMode) print("File exists: $fileExists");
        expect(fileExists, isTrue);
      });
    });

    test('FFmpegKitTest MediaInformation', () {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      using((Arena arena) {
        // MediaInformationSessionHandle media_session = ffprobe_kit_get_media_information(TEST_VIDEO_FILE);
        final pathPtr = toNative(getTestVideoFile(), arena);
        final mediaSession =
            bindings.ffprobe_kit_get_media_information(pathPtr);
        if (kDebugMode) print("Media Session: $mediaSession");
        expect(mediaSession, isNot(nullptr));

        // FFmpegKitSessionState state = ffmpeg_kit_session_get_state(media_session);
        final state = bindings.ffmpeg_kit_session_get_state(mediaSession);

        if (state != FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED) {
          final logsPtr =
              bindings.ffmpeg_kit_session_get_logs_as_string(mediaSession);
          if (logsPtr != nullptr) {
            if (kDebugMode) print("Logs:\n${_fromNative(logsPtr)}");
            bindings.ffmpeg_kit_free(logsPtr.cast());
          }
        }
        expect(state,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

        // long create_time = ffmpeg_kit_session_get_create_time(media_session);
        final createTime =
            bindings.ffmpeg_kit_session_get_create_time(mediaSession);
        expect(createTime, greaterThan(0));

        // char *cmd = ffmpeg_kit_session_get_command(media_session);
        final cmdPtr = bindings.ffmpeg_kit_session_get_command(mediaSession);
        expect(cmdPtr, isNot(nullptr));
        bindings.ffmpeg_kit_free(cmdPtr.cast());

        // int log_count = ffmpeg_kit_session_get_logs_count(media_session);
        final logCount =
            bindings.ffmpeg_kit_session_get_logs_count(mediaSession);
        expect(logCount, greaterThanOrEqualTo(0));

        // MediaInformationHandle info = media_information_session_get_media_information(media_session);
        final info = bindings
            .media_information_session_get_media_information(mediaSession);
        expect(info, isNot(nullptr));

        // char *filename = media_information_get_filename(info);
        final filenamePtr = bindings.media_information_get_filename(info);
        expect(filenamePtr, isNot(nullptr));
        bindings.ffmpeg_kit_free(filenamePtr.cast());

        // char *duration = media_information_get_duration(info);
        final durationPtr = bindings.media_information_get_duration(info);
        expect(durationPtr, isNot(nullptr));
        bindings.ffmpeg_kit_free(durationPtr.cast());

        // char *bitrate = media_information_get_bitrate(info);
        final bitratePtr = bindings.media_information_get_bitrate(info);
        expect(bitratePtr, isNot(nullptr));
        bindings.ffmpeg_kit_free(bitratePtr.cast());

        // char *size = media_information_get_size(info);
        final sizePtr = bindings.media_information_get_size(info);
        expect(sizePtr, isNot(nullptr));
        bindings.ffmpeg_kit_free(sizePtr.cast());

        // int streams_count = media_information_get_streams_count(info);
        final streamsCount = bindings.media_information_get_streams_count(info);
        expect(streamsCount, greaterThanOrEqualTo(1));

        if (streamsCount > 0) {
          // StreamInformationHandle stream = media_information_get_stream_at(info, 0);
          final stream = bindings.media_information_get_stream_at(info, 0);
          expect(stream, isNot(nullptr));

          // long index = stream_information_get_index(stream);
          expect(bindings.stream_information_get_index(stream),
              greaterThanOrEqualTo(0));

          final typePtr = bindings.stream_information_get_type(stream);
          if (typePtr != nullptr) bindings.ffmpeg_kit_free(typePtr.cast());

          final codecPtr = bindings.stream_information_get_codec(stream);
          if (codecPtr != nullptr) bindings.ffmpeg_kit_free(codecPtr.cast());

          final codecLongPtr =
              bindings.stream_information_get_codec_long(stream);
          if (codecLongPtr != nullptr) {
            bindings.ffmpeg_kit_free(codecLongPtr.cast());
          }

          final formatPtr = bindings.stream_information_get_format(stream);
          if (formatPtr != nullptr) bindings.ffmpeg_kit_free(formatPtr.cast());

          final bitrateSPtr = bindings.stream_information_get_bitrate(stream);
          if (bitrateSPtr != nullptr) {
            bindings.ffmpeg_kit_free(bitrateSPtr.cast());
          }

          final sampleRatePtr =
              bindings.stream_information_get_sample_rate(stream);
          if (sampleRatePtr != nullptr) {
            bindings.ffmpeg_kit_free(sampleRatePtr.cast());
          }

          expect(bindings.stream_information_get_width(stream),
              greaterThanOrEqualTo(0));
          expect(bindings.stream_information_get_height(stream),
              greaterThanOrEqualTo(0));

          final tagsPtr = bindings.stream_information_get_tags_json(stream);
          if (tagsPtr != nullptr) bindings.ffmpeg_kit_free(tagsPtr.cast());

          final sampleFormatPtr =
              bindings.stream_information_get_sample_format(stream);
          if (sampleFormatPtr != nullptr) {
            bindings.ffmpeg_kit_free(sampleFormatPtr.cast());
          }

          final darPtr =
              bindings.stream_information_get_display_aspect_ratio(stream);
          if (darPtr != nullptr) bindings.ffmpeg_kit_free(darPtr.cast());

          final afrPtr =
              bindings.stream_information_get_average_frame_rate(stream);
          if (afrPtr != nullptr) bindings.ffmpeg_kit_free(afrPtr.cast());

          final rfrPtr =
              bindings.stream_information_get_real_frame_rate(stream);
          if (rfrPtr != nullptr) bindings.ffmpeg_kit_free(rfrPtr.cast());

          final tbPtr = bindings.stream_information_get_time_base(stream);
          if (tbPtr != nullptr) bindings.ffmpeg_kit_free(tbPtr.cast());

          final clPtr = bindings.stream_information_get_channel_layout(stream);
          if (clPtr != nullptr) bindings.ffmpeg_kit_free(clPtr.cast());

          final sarPtr =
              bindings.stream_information_get_sample_aspect_ratio(stream);
          if (sarPtr != nullptr) bindings.ffmpeg_kit_free(sarPtr.cast());

          final ctbPtr =
              bindings.stream_information_get_codec_time_base(stream);
          if (ctbPtr != nullptr) bindings.ffmpeg_kit_free(ctbPtr.cast());

          final stringPropPtr = bindings.stream_information_get_string_property(
              stream, toNative("codec_name", arena));
          if (stringPropPtr != nullptr) {
            bindings.ffmpeg_kit_free(stringPropPtr.cast());
          }

          expect(
              bindings.stream_information_get_number_property(
                  stream, toNative("index", arena)),
              greaterThanOrEqualTo(0));

          final allStreamPropsPtr =
              bindings.stream_information_get_all_properties_json(stream);
          if (allStreamPropsPtr != nullptr) {
            bindings.ffmpeg_kit_free(allStreamPropsPtr.cast());
          }

          bindings.ffmpeg_kit_handle_release(stream);
        }

        final chaptersCount =
            bindings.media_information_get_chapters_count(info);
        expect(chaptersCount, greaterThanOrEqualTo(0));

        if (chaptersCount > 0) {
          final chapter = bindings.media_information_get_chapter_at(info, 0);
          expect(chapter, isNot(nullptr));
          expect(bindings.chapter_get_id(chapter), greaterThanOrEqualTo(0));

          final startTimePtr = bindings.chapter_get_start_time(chapter);
          if (startTimePtr != nullptr) {
            bindings.ffmpeg_kit_free(startTimePtr.cast());
          }

          final endTimePtr = bindings.chapter_get_end_time(chapter);
          if (endTimePtr != nullptr) {
            bindings.ffmpeg_kit_free(endTimePtr.cast());
          }

          bindings.ffmpeg_kit_handle_release(chapter);
        }

        final allInfoPropsPtr =
            bindings.media_information_get_all_properties_json(info);
        expect(allInfoPropsPtr, isNot(nullptr));
        bindings.ffmpeg_kit_free(allInfoPropsPtr.cast());

        bindings.ffmpeg_kit_handle_release(info);
        bindings.ffmpeg_kit_handle_release(mediaSession);
      });
    });
    test('FFmpegKitTest MediaInformationSessionAPIs', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        final cmdStr =
            "-v error -hide_banner -print_format json -show_format -show_streams -show_chapters -i ${getTestVideoFile()}";
        final cmd = toNative(cmdStr, arena);

        // MediaInformationSessionHandle session = media_information_create_session(command);
        final session = bindings.media_information_create_session(cmd);
        if (kDebugMode) print("Media Information Session: $session");
        expect(session, isNot(nullptr));

        // media_information_session_execute_async(session, 1000);
        bindings.media_information_session_execute_async(session, 1000);

        // std::this_thread::sleep_for(std::chrono::seconds(2));
        await Future.delayed(const Duration(seconds: 2));

        // EXPECT_EQ(ffmpeg_kit_session_get_state(session), FFMPEG_KIT_SESSION_STATE_COMPLETED);
        final state = bindings.ffmpeg_kit_session_get_state(session);
        if (kDebugMode) print("Media Information Session State: $state");
        expect(state,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));
        final info =
            bindings.media_information_session_get_media_information(session);
        expect(info, isNot(nullptr));
        final allInfoPropsPtr =
            bindings.media_information_get_all_properties_json(info);
        expect(allInfoPropsPtr, isNot(nullptr));
        final allInfoProps = _fromNative(allInfoPropsPtr);
        if (kDebugMode) print("All Info Props: $allInfoProps");
        bindings.ffmpeg_kit_free(allInfoPropsPtr.cast());
        bindings.ffmpeg_kit_handle_release(info);
        // ffmpeg_kit_handle_release(session);
        bindings.ffmpeg_kit_handle_release(session);
      });
    });
    test('FFplayKitTest FFplaySession', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        // 1. Set SDL drivers to dummy for headless execution
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_VIDEODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_AUDIODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("DISPLAY", arena), toNative(":0", arena));

        // 2. Run ffplay
        final cmdStr = "-loglevel fatal -autoexit -t 2 ${getTestVideoFile()}";
        final cmd = toNative(cmdStr, arena);

        // FFplaySessionHandle play_session = ffplay_kit_execute(command, 1000);
        final playSession = bindings.ffplay_kit_execute(cmd, 1000);
        if (kDebugMode) print("FFplay Session: $playSession");
        expect(playSession, isNot(nullptr));

        // FFmpegKitSessionState state = ffmpeg_kit_session_get_state(play_session);
        final state = bindings.ffmpeg_kit_session_get_state(playSession);

        if (state != FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED) {
          if (kDebugMode) print("FFplay Session failed with state: $state");
          final logsPtr =
              bindings.ffmpeg_kit_session_get_logs_as_string(playSession);
          if (logsPtr != nullptr) {
            if (kDebugMode) print("Logs:\n${_fromNative(logsPtr)}");
            bindings.ffmpeg_kit_free(logsPtr.cast());
          }
        }

        if (kDebugMode) print("State: $state");
        expect(state,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

        final returnCode =
            bindings.ffmpeg_kit_session_get_return_code(playSession);
        if (kDebugMode) print("Return Code: $returnCode");
        expect(returnCode, equals(0));

        // Cleanup
        bindings.ffmpeg_kit_handle_release(playSession);
      });
    });

    test('FFplayKitInteractiveTest PlayPauseResume', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        // Set SDL drivers to dummy for headless execution
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_VIDEODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_AUDIODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("DISPLAY", arena), toNative(":0", arena));

        final videoFile = getTestVideoFile();
        final cmdStr = "-loglevel fatal -i $videoFile";
        final cmd = toNative(cmdStr, arena);

        // FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
        final session =
            bindings.ffplay_kit_execute_async(cmd, nullptr, nullptr, 1000);
        if (kDebugMode) print("FFplay Session: $session");
        expect(session, isNot(nullptr));

        // WaitForSeconds(2);
        await Future.delayed(const Duration(seconds: 2));

        // EXPECT_EQ(ffplay_kit_session_is_playing(session), 1);
        final isPlaying = bindings.ffplay_kit_session_is_playing(session);
        if (kDebugMode) print("Is Playing: $isPlaying");
        expect(isPlaying, isTrue);

        // ffplay_kit_session_pause(session);
        bindings.ffplay_kit_session_pause(session);
        await Future.delayed(const Duration(seconds: 1));

        // EXPECT_EQ(ffplay_kit_session_is_paused(session), 1);
        final isPaused = bindings.ffplay_kit_session_is_paused(session);
        if (kDebugMode) print("Is Paused: $isPaused");
        expect(isPaused, isTrue);

        // ffplay_kit_session_resume(session);
        bindings.ffplay_kit_session_resume(session);
        await Future.delayed(const Duration(seconds: 1));

        // EXPECT_EQ(ffplay_kit_session_is_paused(session), 0);
        expect(bindings.ffplay_kit_session_is_paused(session), isFalse);

        // EXPECT_EQ(ffplay_kit_session_is_playing(session), 1);
        expect(bindings.ffplay_kit_session_is_playing(session), isTrue);

        // Cleanup
        bindings.ffmpeg_kit_handle_release(session);
      });
    });

    test('FFplayKitInteractiveTest Seek', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        // Ensure test video exists
        if (!File(testVideoFile).existsSync()) {
          generateTestVideoFile();
        }

        final videoFile = getTestVideoFile();
        final cmdStr = "-loglevel fatal -i $videoFile";
        final cmd = toNative(cmdStr, arena);

        // Execute session
        final session =
            bindings.ffplay_kit_execute_async(cmd, nullptr, nullptr, 1000);
        expect(session, isNot(nullptr));

        await Future.delayed(const Duration(seconds: 2));

        // Seek Absolute
        bindings.ffplay_kit_session_seek(session, 10.0);
        await Future.delayed(const Duration(seconds: 1));

        final double pos = bindings.ffplay_kit_session_get_position(session);
        if (kDebugMode) print("Position: $pos");
        expect(pos, greaterThanOrEqualTo(5.0));

        // Seek Relative Backward
        bindings.ffplay_kit_session_seek(session, -5.0);
        await Future.delayed(const Duration(seconds: 1));

        final double newPos = bindings.ffplay_kit_session_get_position(session);
        if (kDebugMode) print("New Position: $newPos");
        expect(newPos, lessThan(pos));

        bindings.ffmpeg_kit_handle_release(session.cast<Void>());
      });
    });

    test('FFplayKitInteractiveTest ConcurrentSessions', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        // Set SDL drivers to dummy for headless execution
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_VIDEODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_AUDIODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("DISPLAY", arena), toNative(":0", arena));

        final videoFile = getTestVideoFile();
        final cmdStr = "-loglevel fatal -i $videoFile";
        final cmd = toNative(cmdStr, arena);

        // Start Session 1
        final session1 =
            bindings.ffplay_kit_execute_async(cmd, nullptr, nullptr, 1000);
        if (kDebugMode) print("FFplay Session 1: $session1");
        expect(session1, isNot(nullptr));
        await Future.delayed(const Duration(seconds: 2));

        // Session 2 should stop Session 1 automatically
        final session2 =
            bindings.ffplay_kit_execute_async(cmd, nullptr, nullptr, 1000);
        if (kDebugMode) print("FFplay Session 2: $session2");
        expect(session2, isNot(nullptr));
        await Future.delayed(const Duration(seconds: 2));

        // Verify Session 1 is completed
        final state1 = bindings.ffmpeg_kit_session_get_state(session1);
        if (kDebugMode) print("State 1: $state1");
        expect(state1,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

        // Verify Session 2 is the one currently playing
        final isPlaying2 = bindings.ffplay_kit_session_is_playing(session2);
        if (kDebugMode) print("Is Playing 2: $isPlaying2");
        expect(isPlaying2, isTrue);

        // Cleanup native handles
        bindings.ffmpeg_kit_handle_release(session1);
        bindings.ffmpeg_kit_handle_release(session2);
      });
    });

    test('FFplayKitInteractiveTest GlobalControls', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        // Set SDL drivers to dummy for headless execution
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_VIDEODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_AUDIODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("DISPLAY", arena), toNative(":0", arena));

        final videoFile = getTestVideoFile();
        final cmdStr = "-loglevel fatal -i $videoFile";
        final cmd = toNative(cmdStr, arena);

        // FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
        final session =
            bindings.ffplay_kit_execute_async(cmd, nullptr, nullptr, 1000);
        if (kDebugMode) print("FFplay Session: $session");
        expect(session, isNot(nullptr));
        await Future.delayed(const Duration(seconds: 2));

        // ffplay_kit_pause();
        bindings.ffplay_kit_pause();
        await Future.delayed(const Duration(seconds: 1));
        final isPaused = bindings.ffplay_kit_is_paused();
        if (kDebugMode) print("Is Paused: $isPaused");
        expect(isPaused, isTrue);

        // ffplay_kit_resume();
        bindings.ffplay_kit_resume();
        await Future.delayed(const Duration(seconds: 1));
        final isPausedAfterResume = bindings.ffplay_kit_is_paused();
        if (kDebugMode) print("Is Paused: $isPausedAfterResume");
        expect(isPausedAfterResume, isFalse);

        // ffplay_kit_stop();
        bindings.ffplay_kit_stop();
        await Future.delayed(const Duration(seconds: 1));

        // FFmpegKitSessionState state = ffmpeg_kit_session_get_state(session);
        final state = bindings.ffmpeg_kit_session_get_state(session);
        if (kDebugMode) print("State: $state");
        expect(state,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

        // Cleanup
        bindings.ffmpeg_kit_handle_release(session);
      });
    });

    test('FFplayKitInteractiveTest GlobalSeek', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        // Set SDL drivers to dummy for headless execution
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_VIDEODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_AUDIODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("DISPLAY", arena), toNative(":0", arena));

        final videoFile = getTestVideoFile();
        final cmdStr = "-loglevel fatal -i $videoFile";
        final cmd = toNative(cmdStr, arena);

        // FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
        final session =
            bindings.ffplay_kit_execute_async(cmd, nullptr, nullptr, 1000);
        if (kDebugMode) print("FFplay Session: $session");
        expect(session, isNot(nullptr));
        await Future.delayed(const Duration(seconds: 2));

        // Global Set Position
        // ffplay_kit_set_position(10.0);
        bindings.ffplay_kit_set_position(10.0);
        await Future.delayed(const Duration(seconds: 1));

        // double pos = ffplay_kit_get_position();
        final double pos = bindings.ffplay_kit_get_position();
        if (kDebugMode) print("Position: $pos");
        expect(pos, greaterThanOrEqualTo(9.0));

        // Global Seek (Relative)
        // ffplay_kit_seek(-5.0);
        bindings.ffplay_kit_seek(-5.0);
        await Future.delayed(const Duration(seconds: 1));

        final double newPos = bindings.ffplay_kit_get_position();
        if (kDebugMode) print("New Position: $newPos");
        expect(newPos, lessThan(pos));

        // ffplay_kit_stop();
        bindings.ffplay_kit_stop();
        await Future.delayed(const Duration(seconds: 1));

        // Cleanup
        bindings.ffmpeg_kit_handle_release(session);
      });
    });
    test('FFplayKitInteractiveTest SessionAPIs', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        // Set SDL drivers to dummy for headless execution
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_VIDEODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_AUDIODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("DISPLAY", arena), toNative(":0", arena));

        final videoFile = getTestVideoFile();
        final cmdStr = "-loglevel fatal -i $videoFile";
        final cmd = toNative(cmdStr, arena);

        // FFplaySessionHandle session = ffplay_kit_create_session(command);
        final session = bindings.ffplay_kit_create_session(cmd);
        if (kDebugMode) print("Session: $session");
        expect(session, isNot(nullptr));

        // ffplay_kit_session_execute_async(session, 1000);
        bindings.ffplay_kit_session_execute_async(session, 1000);
        await Future.delayed(const Duration(seconds: 2));

        // ffplay_kit_session_set_volume(session, 0.5f);
        bindings.ffplay_kit_session_set_volume(session, 0.5);
        await Future.delayed(const Duration(seconds: 1));
        final volume = bindings.ffplay_kit_session_get_volume(session);
        if (kDebugMode) print("Volume: $volume");
        expect(volume, closeTo(0.5, 0.01));

        // ffplay_kit_session_set_position(session, 5.0);
        bindings.ffplay_kit_session_set_position(session, 5.0);
        await Future.delayed(const Duration(seconds: 1));
        final position = bindings.ffplay_kit_session_get_position(session);
        if (kDebugMode) print("Position: $position");
        expect(position, greaterThanOrEqualTo(4.0));

        // printf("Duration: %f\n", ffplay_kit_session_get_duration(session));
        final duration = bindings.ffplay_kit_session_get_duration(session);
        if (kDebugMode) print("Duration: $duration");
        expect(duration, greaterThan(0.0));

        // ffplay_kit_session_stop(session);
        bindings.ffplay_kit_session_stop(session);
        await Future.delayed(const Duration(seconds: 1));
        final state = bindings.ffmpeg_kit_session_get_state(session);
        if (kDebugMode) print("State: $state");
        expect(state,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

        // ffplay_kit_session_close(session);
        bindings.ffplay_kit_session_close(session);

        // Create and manual start test (Session 2)
        final session2 = bindings.ffplay_kit_create_session(cmd);
        if (kDebugMode) print("Session2: $session2");
        expect(session2, isNot(nullptr));

        bindings.ffplay_kit_session_execute_async(session2, 1000);
        await Future.delayed(const Duration(seconds: 2));

        bindings.ffplay_kit_session_pause(session2);
        await Future.delayed(const Duration(seconds: 1));

        bindings.ffplay_kit_session_resume(session2);
        await Future.delayed(const Duration(seconds: 1));

        final isPlaying2 = bindings.ffplay_kit_session_is_playing(session2);
        if (kDebugMode) print("Session2 is playing: $isPlaying2");
        expect(isPlaying2, isTrue);

        // Cleanup
        bindings.ffmpeg_kit_handle_release(session2);
        bindings.ffmpeg_kit_handle_release(session);
      });
    });

    test('FFplayKitInteractiveTest GlobalAPIs', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        // Updated helper to avoid the 'allocator' named parameter error
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        // Set environment variables for headless execution
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_VIDEODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_AUDIODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("DISPLAY", arena), toNative(":0", arena));

        final videoFile = getTestVideoFile();
        final cmdStr = "-loglevel fatal -i $videoFile";
        final cmd = toNative(cmdStr, arena);

        // FFplaySessionHandle session = ffplay_kit_execute_async(command, nullptr, nullptr, 1000);
        final session =
            bindings.ffplay_kit_execute_async(cmd, nullptr, nullptr, 1000);
        if (kDebugMode) print("Session: $session");
        expect(session, isNot(nullptr));

        // WaitForSeconds(2);
        await Future.delayed(const Duration(seconds: 2));

        // ffplay_kit_set_volume(0.5f);
        bindings.ffplay_kit_set_volume(0.5);
        await Future.delayed(const Duration(seconds: 1));

        final volume = bindings.ffplay_kit_get_volume();
        if (kDebugMode) print("Volume: $volume");
        expect(volume, closeTo(0.5, 0.01));

        // printf("Duration: %f\n", ffplay_kit_get_duration());
        final duration = bindings.ffplay_kit_get_duration();
        if (kDebugMode) print("Duration: $duration");
        expect(duration, greaterThan(0.0));

        // ffplay_kit_start();
        bindings.ffplay_kit_start();
        await Future.delayed(const Duration(seconds: 1));

        // ffplay_kit_stop();
        bindings.ffplay_kit_stop();
        await Future.delayed(const Duration(seconds: 1));

        // ffplay_kit_close();
        bindings.ffplay_kit_close();

        // Cleanup handle
        bindings.ffmpeg_kit_handle_release(session);
      });
    });

    test('FFplayKitInteractiveTest TimeoutSession', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        // Set SDL drivers to dummy for headless execution
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_VIDEODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_AUDIODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("DISPLAY", arena), toNative(":0", arena));

        final videoFile = getTestVideoFile();
        final cmdStr = "-loglevel fatal -i $videoFile";
        final cmd = toNative(cmdStr, arena);

        // 1. Start Session 1 normally
        final session1 =
            bindings.ffplay_kit_execute_async(cmd, nullptr, nullptr, 1000);
        if (kDebugMode) print("Session 1: $session1");
        expect(session1, isNot(nullptr));

        await Future.delayed(const Duration(seconds: 2));

        final isPlaying1 = bindings.ffplay_kit_session_is_playing(session1);
        if (kDebugMode) print("Session 1 is playing: $isPlaying1");
        expect(isPlaying1, isTrue);

        // 2. Create Session 2
        final session2 = bindings.ffplay_kit_create_session(cmd);
        if (kDebugMode) print("Session 2: $session2");
        expect(session2, isNot(nullptr));

        // 3. Execute Session 2 with a very short timeout (5ms)
        // This should fail because Session 1 is running and won't stop instantly
        bindings.ffplay_kit_session_execute_async(session2, 5);

        // Wait for async execution to process
        await Future.delayed(const Duration(seconds: 1));

        // 4. Verify Session 2 failed
        final state2 = bindings.ffmpeg_kit_session_get_state(session2);

        if (state2 != FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_FAILED) {
          if (kDebugMode) print("Session 2 state: $state2");
          final failStackTracePtr =
              bindings.ffmpeg_kit_session_get_fail_stack_trace(session2);
          if (failStackTracePtr != nullptr) {
            if (kDebugMode) {
              print("Fail Stack Trace:\n${_fromNative(failStackTracePtr)}");
            }
            bindings.ffmpeg_kit_free(failStackTracePtr.cast());
          }
        }
        // Wait for async execution to process
        await Future.delayed(const Duration(seconds: 1));
        if (kDebugMode) print("State 2: $state2");
        expect(state2,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_FAILED));

        // Cleanup
        bindings.ffmpeg_kit_handle_release(session1);
        bindings.ffmpeg_kit_handle_release(session2);
      });
    });

    test('FFmpegKitTest PackageName', () async {
      await using((Arena arena) async {
        // char *pkg = ffmpeg_kit_packages_get_package_name();
        final pkgPtr = bindings.ffmpeg_kit_packages_get_package_name();

        expect(pkgPtr, isNot(nullptr));

        final pkgName = _fromNative(pkgPtr);
        if (kDebugMode) print("Package Name: $pkgName");

        expect(pkgName, isNotNull);
        expect(pkgName, isNotEmpty);

        // free(pkg);
        bindings.ffmpeg_kit_free(pkgPtr.cast());
      });
    });

    test('FFmpegKitTest AudioDeviceManagement', () async {
      if (!File(getTestAudioFile()).existsSync()) {
        generateTestAudioFile();
      }
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        // Force dummy audio for headless environments
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_AUDIODRIVER", arena), toNative("dummy", arena));

        // 1. List devices
        final devicesPtr =
            bindings.ffmpeg_kit_config_list_audio_output_devices();
        if (devicesPtr != nullptr) {
          if (kDebugMode) print("Audio Devices: ${_fromNative(devicesPtr)}");
          bindings.ffmpeg_kit_free(devicesPtr.cast());
        }

        // 2. Set Device (API Verification)
        bindings.ffmpeg_kit_config_set_audio_output_device(
            toNative("Test Device", arena));

        // Reset to default before playback
        bindings.ffmpeg_kit_config_set_audio_output_device(nullptr);

        // 3. Verify Playback Path
        if (await File(testAudioFile).exists()) {
          final cmdStr =
              "-loglevel fatal -autoexit -t 0.5 ${getTestAudioFile()}";
          final cmd = toNative(cmdStr, arena);

          final session = bindings.ffplay_kit_execute(cmd, 2000);

          if (session != nullptr) {
            bindings.ffmpeg_kit_handle_release(session);
          }
        }

        bindings.ffmpeg_kit_config_set_audio_output_device(nullptr);
      });
    });
    test('FFmpegKitTest ConcurrentOperations', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        const outputFile = "concurrent_output.mp4";

        // 1. Create a slow FFmpeg session (e.g., generating a long video)
        final ffmpegCmd = toNative(
            "-hide_banner -loglevel fatal -f lavfi -i testsrc=duration=5:size=128x128:rate=10 -y $outputFile",
            arena);
        final ffmpegSession = bindings.ffmpeg_kit_create_session(ffmpegCmd);
        if (kDebugMode) print("FFmpeg Session: $ffmpegSession");
        expect(ffmpegSession, isNot(nullptr));

        // 2. Create a FFprobe session to run at the same time
        final ffprobeCmd = toNative(
            "-hide_banner -loglevel fatal -show_format -i ${getTestVideoFile()}",
            arena);
        final ffprobeSession = bindings.ffprobe_kit_create_session(ffprobeCmd);
        if (kDebugMode) print("FFprobe Session: $ffprobeSession");
        expect(ffprobeSession, isNot(nullptr));

        // 3. Execute both asynchronously
        bindings.ffmpeg_kit_session_execute_async(ffmpegSession);
        bindings.ffprobe_kit_session_execute_async(ffprobeSession);

        // 4. Wait for both to complete
        int totalWait = 0;
        while (totalWait < 10000) {
          // 10s max
          final state1 = bindings.ffmpeg_kit_session_get_state(ffmpegSession);
          final state2 = bindings.ffmpeg_kit_session_get_state(ffprobeSession);

          if (state1 ==
                  FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED &&
              state2 ==
                  FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED) {
            break;
          }

          if (state1 == FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_FAILED ||
              state2 == FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_FAILED) {
            break;
          }

          await Future.delayed(const Duration(milliseconds: 100));
          totalWait += 100;
        }

        // 5. Verify results
        final finalState1 =
            bindings.ffmpeg_kit_session_get_state(ffmpegSession);
        final finalState2 =
            bindings.ffmpeg_kit_session_get_state(ffprobeSession);
        if (kDebugMode) print("FFmpeg Session State: $finalState1");
        if (kDebugMode) print("FFprobe Session State: $finalState2");

        expect(finalState1,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));
        expect(finalState2,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

        // Cleanup native handles
        bindings.ffmpeg_kit_handle_release(ffmpegSession);
        bindings.ffmpeg_kit_handle_release(ffprobeSession);

        // Remove temporary file
        final file = File(outputFile);
        if (await file.exists()) {
          await file.delete();
        }
      });
    });
    test('FFmpegKitTest ConcurrentFFmpegSessions', () async {
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        const outputFile1 = "concurrent1.mp4";
        const outputFile2 = "concurrent2.mp4";

        // 1. Create two FFmpeg sessions
        final cmd1 = toNative(
            "-hide_banner -loglevel fatal -f lavfi -i testsrc=duration=3:size=128x128:rate=10 -y $outputFile1",
            arena);
        final cmd2 = toNative(
            "-hide_banner -loglevel fatal -f lavfi -i testsrc=duration=3:size=128x128:rate=10 -y $outputFile2",
            arena);

        final ffmpegSession1 = bindings.ffmpeg_kit_create_session(cmd1);
        final ffmpegSession2 = bindings.ffmpeg_kit_create_session(cmd2);

        if (kDebugMode) print("FFmpeg Session 1: $ffmpegSession1");
        if (kDebugMode) print("FFmpeg Session 2: $ffmpegSession2");

        expect(ffmpegSession1, isNot(nullptr));
        expect(ffmpegSession2, isNot(nullptr));

        // 2. Execute both asynchronously
        bindings.ffmpeg_kit_session_execute_async(ffmpegSession1);
        bindings.ffmpeg_kit_session_execute_async(ffmpegSession2);

        // 3. Wait for both to complete
        int totalWait = 0;
        while (totalWait < 10000) {
          final state1 = bindings.ffmpeg_kit_session_get_state(ffmpegSession1);
          final state2 = bindings.ffmpeg_kit_session_get_state(ffmpegSession2);

          if (state1 ==
                  FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED &&
              state2 ==
                  FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED) {
            break;
          }

          if (state1 == FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_FAILED ||
              state2 == FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_FAILED) {
            break;
          }

          await Future.delayed(const Duration(milliseconds: 100));
          totalWait += 100;
        }

        // 4. Verify results
        final finalState1 =
            bindings.ffmpeg_kit_session_get_state(ffmpegSession1);
        final finalState2 =
            bindings.ffmpeg_kit_session_get_state(ffmpegSession2);
        if (kDebugMode) print("FFmpeg Session 1 State: $finalState1");
        if (kDebugMode) print("FFmpeg Session 2 State: $finalState2");

        expect(finalState1,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));
        expect(finalState2,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

        // Cleanup
        bindings.ffmpeg_kit_handle_release(ffmpegSession1);
        bindings.ffmpeg_kit_handle_release(ffmpegSession2);

        final file1 = File(outputFile1);
        if (await file1.exists()) {
          await file1.delete();
        }
        final file2 = File(outputFile2);
        if (await file2.exists()) {
          await file2.delete();
        }
      });
    });

    test(
        'FFplayWithFFmpegConcurrency',
        () => using((Arena arena) async {
              final outputFile1 = path
                  .join(tempDir.path, 'ffplay_concurrent.mp4')
                  .replaceAll(r'\', '/');
              final cmd1 = toNative(
                  "-hide_banner -loglevel fatal -f lavfi -i testsrc=duration=5:size=128x128:rate=10 -y $outputFile1",
                  arena);
              final s1 = arena.trackHandle(
                  bindings.ffmpeg_kit_create_session(cmd1), bindings);

              if (kDebugMode) print("Session 1: $s1");
              expect(s1, isNotNull);
              bindings.ffmpeg_kit_session_execute_async(s1);

              final startTime = DateTime.now();
              bool done = false;
              while (!done) {
                final st1 = bindings.ffmpeg_kit_session_get_state(s1);
                if (DateTime.now().difference(startTime).inSeconds > 15) {
                  fail("Parallel execution timed out");
                }
                if (st1 ==
                        FFmpegKitSessionState
                            .FFMPEG_KIT_SESSION_STATE_COMPLETED ||
                    st1 ==
                        FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_FAILED) {
                  done = true;
                } else {
                  await Future.delayed(const Duration(milliseconds: 100));
                }
              }

              if (kDebugMode) {
                print(
                    "Session 1 state: ${bindings.ffmpeg_kit_session_get_state(s1)}");
              }
              expect(
                  bindings.ffmpeg_kit_session_get_state(s1),
                  equals(FFmpegKitSessionState
                      .FFMPEG_KIT_SESSION_STATE_COMPLETED));
              await File(outputFile1).delete();
            }));

    test('FFplayKitInteractiveTest FFplayWithFFmpegConcurrency', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        // Set SDL drivers to dummy for headless execution
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_VIDEODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_AUDIODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("DISPLAY", arena), toNative(":0", arena));

        const concurrentOutputFile = "ffplay_concurrent.mp4";

        // 1. Start a slow FFmpeg session
        final ffmpegCmd = toNative(
            "-hide_banner -loglevel fatal -f lavfi -i testsrc=duration=5:size=128x128:rate=10 -y $concurrentOutputFile",
            arena);
        final ffmpegSession = bindings.ffmpeg_kit_create_session(ffmpegCmd);
        bindings.ffmpeg_kit_session_execute_async(ffmpegSession);

        // 2. Start FFplay session
        final videoFile = getTestVideoFile();
        final playCmd = toNative("-loglevel fatal -i $videoFile", arena);
        final playSession =
            bindings.ffplay_kit_execute_async(playCmd, nullptr, nullptr, 1000);

        if (kDebugMode) print("FFplay Session: $playSession");
        expect(playSession, isNot(nullptr));

        // WaitForSeconds(2);
        await Future.delayed(const Duration(seconds: 2));

        // 3. Verify both are running
        final isPlaying = bindings.ffplay_kit_session_is_playing(playSession);
        if (kDebugMode) print("FFplay Session Is Playing: $isPlaying");
        expect(isPlaying, isTrue);

        final ffmpegState =
            bindings.ffmpeg_kit_session_get_state(ffmpegSession);
        if (kDebugMode) print("FFmpeg Session State: $ffmpegState");
        expect(
            ffmpegState ==
                    FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_RUNNING ||
                ffmpegState ==
                    FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED,
            isTrue);

        // 4. Cleanup
        bindings.ffmpeg_kit_handle_release(playSession);

        // Wait for FFmpeg to finish if it hasn't
        int waitTotal = 0;
        while (bindings.ffmpeg_kit_session_get_state(ffmpegSession) ==
                FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_RUNNING &&
            waitTotal < 5000) {
          await Future.delayed(const Duration(seconds: 1));
          waitTotal += 1000;
        }

        bindings.ffmpeg_kit_handle_release(ffmpegSession);

        final file = File(concurrentOutputFile);
        if (await file.exists()) {
          await file.delete();
        }
      });
    });
    test('FFplayKitInteractiveTest FFplayWithFFprobeConcurrency', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        // Helper to convert Dart strings to native C strings using the arena for lifecycle management
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        // Set SDL drivers to dummy for headless execution
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_VIDEODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_AUDIODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("DISPLAY", arena), toNative(":0", arena));

        final videoFile = getTestVideoFile();
        final playCmd = toNative("-loglevel fatal -i $videoFile", arena);

        // 1. Start FFplay session
        final playSession =
            bindings.ffplay_kit_execute_async(playCmd, nullptr, nullptr, 1000);
        if (kDebugMode) print("FFplay Session: $playSession");
        expect(playSession, isNot(nullptr));

        await Future.delayed(const Duration(seconds: 1));

        // 2. Run FFprobe session concurrently (synchronous execution)
        final probeCmd = toNative(
            "-hide_banner -loglevel fatal -show_format -i $videoFile", arena);
        final probeSession = bindings.ffprobe_kit_execute(probeCmd);
        if (kDebugMode) print("FFprobe Session: $probeSession");
        expect(probeSession, isNot(nullptr));

        // 3. Verify FFplay is still playing and probe finished
        final isPlaying = bindings.ffplay_kit_session_is_playing(playSession);
        if (kDebugMode) print("FFplay Session Is Playing: $isPlaying");
        expect(isPlaying, isTrue);

        final probeState = bindings.ffmpeg_kit_session_get_state(probeSession);
        if (kDebugMode) print("FFprobe Session State: $probeState");
        expect(probeState,
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

        // 4. Cleanup native handles
        bindings.ffmpeg_kit_handle_release(playSession);
        bindings.ffmpeg_kit_handle_release(probeSession);
      });
    });
    test('FFmpegKitTest ConcurrentFFprobeSessions', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        final videoFile = getTestVideoFile();
        final cmd = toNative(
            "-hide_banner -loglevel fatal -show_format -i $videoFile", arena);

        final completer = Completer<void>();
        int completedSessions = 0;
        const int expectedSessions = 2;

        // Use a listener to synchronize the FFI callback with Dart's event loop
        final completeCallback =
            NativeCallable<NativeCompleteCallback>.listener(
          (Pointer<Void> session, Pointer<Void> userData) {
            completedSessions++;
            if (completedSessions == expectedSessions &&
                !completer.isCompleted) {
              completer.complete();
            }
          },
        );

        // 1. Create two FFprobe sessions
        final ffprobeSession1 = bindings.ffprobe_kit_create_session(cmd);
        final ffprobeSession2 = bindings.ffprobe_kit_create_session(cmd);

        expect(ffprobeSession1, isNot(nullptr));
        expect(ffprobeSession2, isNot(nullptr));

        // Attach callbacks to the sessions
        bindings.ffprobe_kit_set_complete_callback(
            ffprobeSession1, completeCallback.nativeFunction, nullptr);
        bindings.ffprobe_kit_set_complete_callback(
            ffprobeSession2, completeCallback.nativeFunction, nullptr);

        // 2. Execute both asynchronously
        bindings.ffprobe_kit_session_execute_async(ffprobeSession1);
        bindings.ffprobe_kit_session_execute_async(ffprobeSession2);

        // 3. Wait deterministically for both to complete
        await completer.future.timeout(const Duration(seconds: 10),
            onTimeout: () {
          throw TimeoutException(
              'Timed out waiting for concurrent FFprobe sessions');
        });

        // 4. Verify results
        expect(bindings.ffmpeg_kit_session_get_state(ffprobeSession1),
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));
        expect(bindings.ffmpeg_kit_session_get_state(ffprobeSession2),
            equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));
        if (kDebugMode) print("Completed sessions: $completedSessions");
        expect(completedSessions, equals(expectedSessions));
        if (kDebugMode) print("Session Complete: ${completer.isCompleted}");
        expect(completer.isCompleted, isTrue);

        // Cleanup
        completeCallback.close();
        bindings.ffmpeg_kit_handle_release(ffprobeSession1);
        bindings.ffmpeg_kit_handle_release(ffprobeSession2);
      });
    });
    test('FFmpegKitTest SessionManagement', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        // Updated helper to avoid the 'allocator' named parameter error
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        // 1. Clear sessions
        bindings.ffmpeg_kit_clear_sessions();

        // 2. Create multiple types of sessions
        final ffmpeg =
            bindings.ffmpeg_kit_create_session(toNative("-version", arena));
        final ffprobe =
            bindings.ffprobe_kit_create_session(toNative("-version", arena));
        final ffplay =
            bindings.ffplay_kit_create_session(toNative("-version", arena));

        final mediaCmd =
            "-v error -hide_banner -print_format json -show_format -show_streams -show_chapters -i ${getTestVideoFile()}";
        final media = bindings
            .media_information_create_session(toNative(mediaCmd, arena));

        // 3. Check last session
        final last = bindings.ffmpeg_kit_get_last_session();
        if (kDebugMode) print("Last Session: $last");
        expect(last, isNot(nullptr));
        bindings.ffmpeg_kit_handle_release(last);

        final lastFFmpeg = bindings.ffmpeg_kit_get_last_ffmpeg_session();
        if (kDebugMode) print("Last FFmpeg Session: $lastFFmpeg");
        expect(lastFFmpeg, isNot(nullptr));
        bindings.ffmpeg_kit_handle_release(lastFFmpeg);

        final lastFFprobe = bindings.ffmpeg_kit_get_last_ffprobe_session();
        if (kDebugMode) print("Last FFprobe Session: $lastFFprobe");
        expect(lastFFprobe, isNot(nullptr));
        bindings.ffmpeg_kit_handle_release(lastFFprobe);

        final lastFFplay = bindings.ffmpeg_kit_get_last_ffplay_session();
        if (kDebugMode) print("Last FFplay Session: $lastFFplay");
        expect(lastFFplay, isNot(nullptr));
        bindings.ffmpeg_kit_handle_release(lastFFplay);

        final lastMedia =
            bindings.ffmpeg_kit_get_last_media_information_session();
        if (kDebugMode) print("Last Media Information Session: $lastMedia");
        expect(lastMedia, isNot(nullptr));
        bindings.ffmpeg_kit_handle_release(lastMedia);

        // 4. List sessions
        final sessionsPtr = bindings.ffmpeg_kit_get_sessions();
        int count = 0;
        if (sessionsPtr != nullptr) {
          final list = sessionsPtr.cast<Pointer<Void>>();
          while (list[count] != nullptr) {
            bindings.ffmpeg_kit_handle_release(list[count]);
            count++;
          }
          bindings.ffmpeg_kit_free(sessionsPtr.cast());
        }
        if (kDebugMode) print("Session Count: $count");
        expect(count, greaterThanOrEqualTo(4));

        // 5. List FFmpeg sessions
        final ffmpegSessionsPtr = bindings.ffmpeg_kit_get_ffmpeg_sessions();
        int ffmpegCount = 0;
        if (ffmpegSessionsPtr != nullptr) {
          final list = ffmpegSessionsPtr.cast<Pointer<Void>>();
          while (list[ffmpegCount] != nullptr) {
            bindings.ffmpeg_kit_handle_release(list[ffmpegCount]);
            ffmpegCount++;
          }
          bindings.ffmpeg_kit_free(ffmpegSessionsPtr.cast());
        }
        if (kDebugMode) print("FFmpeg Session Count: $ffmpegCount");
        expect(ffmpegCount, greaterThanOrEqualTo(1));

        // 6. Cleanup
        bindings.ffmpeg_kit_handle_release(ffmpeg);
        bindings.ffmpeg_kit_handle_release(ffprobe);
        bindings.ffmpeg_kit_handle_release(ffplay);
        bindings.ffmpeg_kit_handle_release(media);
      });
    });
    test('FFmpegKitTest LastCompletedSession', () async {
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        // ffmpeg_kit_clear_sessions();
        bindings.ffmpeg_kit_clear_sessions();

        // FFmpegSessionHandle session = ffmpeg_kit_execute("-version");
        final cmd = toNative("-version", arena);
        final session = bindings.ffmpeg_kit_execute(cmd);

        // ASSERT_NE(session, nullptr);
        expect(session, isNot(nullptr));

        // FFmpegSessionHandle last_completed = ffmpeg_kit_get_last_completed_session();
        final lastCompleted = bindings.ffmpeg_kit_get_last_completed_session();

        // EXPECT_NE(last_completed, nullptr);
        expect(lastCompleted, isNot(nullptr));

        if (lastCompleted != nullptr) {
          // EXPECT_EQ(ffmpeg_kit_session_get_state(last_completed), FFMPEG_KIT_SESSION_STATE_COMPLETED);
          final state = bindings.ffmpeg_kit_session_get_state(lastCompleted);
          expect(state,
              equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

          // ffmpeg_kit_handle_release(last_completed);
          bindings.ffmpeg_kit_handle_release(lastCompleted);
        }

        // ffmpeg_kit_handle_release(session);
        bindings.ffmpeg_kit_handle_release(session);
      });
    });
    test('FFmpegKitTest SessionProperties', () async {
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        // FFmpegSessionHandle session = ffmpeg_kit_execute(...)
        final cmd = toNative(
            "-hide_banner -loglevel fatal -f lavfi -i sine=frequency=1000:duration=1 -y test_props.wav",
            arena);
        final session = bindings.ffmpeg_kit_execute(cmd);

        // ASSERT_NE(session, nullptr);
        expect(session, isNot(nullptr));

        // long create_time = ffmpeg_kit_session_get_create_time(session);
        final createTime = bindings.ffmpeg_kit_session_get_create_time(session);
        // long start_time = ffmpeg_kit_session_get_start_time(session);
        final startTime = bindings.ffmpeg_kit_session_get_start_time(session);
        // long end_time = ffmpeg_kit_session_get_end_time(session);
        final endTime = bindings.ffmpeg_kit_session_get_end_time(session);
        // long duration = ffmpeg_kit_session_get_duration(session);
        final duration = bindings.ffmpeg_kit_session_get_duration(session);

        if (kDebugMode) print("Create Time: $createTime");
        if (kDebugMode) print("Start Time: $startTime");
        if (kDebugMode) print("End Time: $endTime");
        if (kDebugMode) print("Duration: $duration");

        // EXPECT_GT assertions
        expect(createTime, greaterThan(0));
        expect(startTime, greaterThan(0));
        expect(endTime, greaterThan(0));
        expect(endTime, greaterThanOrEqualTo(startTime));
        expect(duration, greaterThanOrEqualTo(0));

        // Cleanup
        bindings.ffmpeg_kit_handle_release(session);

        final file = File("test_props.wav");
        if (await file.exists()) {
          await file.delete();
        }
      });
    });
    test('FFmpegKitTest Statistics', () async {
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        // FFmpegSessionHandle session = ffmpeg_kit_execute(...)
        final cmd = toNative(
            "-hide_banner -loglevel fatal -f lavfi -i testsrc=duration=2:size=128x128:rate=30 -vcodec mpeg4 -y test_stats.mp4",
            arena);
        final session = bindings.ffmpeg_kit_execute(cmd);

        // ASSERT_NE(session, nullptr);
        expect(session, isNot(nullptr));

        // int stats_count = ffmpeg_kit_session_get_statistics_count(session);
        final statsCount =
            bindings.ffmpeg_kit_session_get_statistics_count(session);
        if (kDebugMode) print("Statistics Count: $statsCount");

        if (statsCount > 0) {
          // StatisticsHandle stats = ffmpeg_kit_session_get_statistics_at(session, 0);
          final stats =
              bindings.ffmpeg_kit_session_get_statistics_at(session, 0);
          expect(stats, isNot(nullptr));

          // int frame_number = ffmpeg_kit_statistics_get_video_frame_number(stats);
          final frameNumber =
              bindings.ffmpeg_kit_statistics_get_video_frame_number(stats);
          // float fps = ffmpeg_kit_statistics_get_video_fps(stats);
          final fps = bindings.ffmpeg_kit_statistics_get_video_fps(stats);
          // double time = ffmpeg_kit_statistics_get_time(stats);
          final time = bindings.ffmpeg_kit_statistics_get_time(stats);

          if (kDebugMode) print("Frame Number: $frameNumber");
          if (kDebugMode) print("FPS: $fps");
          if (kDebugMode) print("Time: $time");

          // EXPECT_GE assertions
          expect(frameNumber, greaterThanOrEqualTo(0));
          expect(fps, greaterThanOrEqualTo(0.0));
          expect(time, greaterThanOrEqualTo(0.0));

          // ffmpeg_kit_handle_release(stats);
          bindings.ffmpeg_kit_handle_release(stats);
        }

        // ffmpeg_kit_handle_release(session);
        bindings.ffmpeg_kit_handle_release(session);

        final file = File("test_stats.mp4");
        if (await file.exists()) {
          await file.delete();
        }
      });
    });
    test('FFprobeKitTest LastSessionAliases', () async {
      await using((Arena arena) async {
        // Helper to convert Dart strings to native C strings
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        // ffmpeg_kit_clear_sessions();
        bindings.ffmpeg_kit_clear_sessions();

        // FFprobeSessionHandle session = ffprobe_kit_execute("-hide_banner -version");
        final cmd = toNative("-hide_banner -version", arena);
        final session = bindings.ffprobe_kit_execute(cmd);

        // ASSERT_NE(session, nullptr);
        expect(session, isNot(nullptr));

        // FFprobeSessionHandle last = ffprobe_kit_get_last_session();
        final last = bindings.ffprobe_kit_get_last_session();

        // EXPECT_NE(last, nullptr);
        expect(last, isNot(nullptr));
        if (last != nullptr) {
          bindings.ffmpeg_kit_handle_release(last);
        }

        // FFprobeSessionHandle last_comp = ffprobe_kit_get_last_completed_session();
        final lastComp = bindings.ffprobe_kit_get_last_completed_session();

        // EXPECT_NE(last_comp, nullptr);
        expect(lastComp, isNot(nullptr));
        if (lastComp != nullptr) {
          bindings.ffmpeg_kit_handle_release(lastComp);
        }

        // ffmpeg_kit_handle_release(session);
        bindings.ffmpeg_kit_handle_release(session);
      });
    });
    test('FFmpegKitTest SessionListingAliases', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        // ffmpeg_kit_clear_sessions();
        bindings.ffmpeg_kit_clear_sessions();

        // 1. FFmpeg Listing
        final ffmpeg =
            bindings.ffmpeg_kit_create_session(toNative("-version", arena));
        final ffmpegListPtr = bindings.ffmpeg_kit_list_sessions();
        int ffmpegCount = 0;
        if (ffmpegListPtr != nullptr) {
          final list = ffmpegListPtr.cast<Pointer<Void>>();
          while (list[ffmpegCount] != nullptr) {
            bindings.ffmpeg_kit_handle_release(list[ffmpegCount]);
            ffmpegCount++;
          }
          bindings.ffmpeg_kit_free(ffmpegListPtr.cast());
        }
        if (kDebugMode) print("FFmpeg List Count: $ffmpegCount");
        expect(ffmpegCount, greaterThanOrEqualTo(1));

        // 2. FFprobe Listing
        final ffprobe =
            bindings.ffprobe_kit_create_session(toNative("-version", arena));
        final ffprobeListPtr = bindings.ffprobe_kit_list_sessions();
        int ffprobeCount = 0;
        if (ffprobeListPtr != nullptr) {
          final list = ffprobeListPtr.cast<Pointer<Void>>();
          while (list[ffprobeCount] != nullptr) {
            bindings.ffmpeg_kit_handle_release(list[ffprobeCount]);
            ffprobeCount++;
          }
          bindings.ffmpeg_kit_free(ffprobeListPtr.cast());
        }
        if (kDebugMode) print("FFprobe List Count: $ffprobeCount");
        expect(ffprobeCount, greaterThanOrEqualTo(1));

        // 3. Media Information Listing
        final mediaCmd = "-v error -i ${getTestVideoFile()}";
        final media = bindings
            .media_information_create_session(toNative(mediaCmd, arena));
        final mediaListPtr = bindings.media_information_kit_list_sessions();
        int mediaCount = 0;
        if (mediaListPtr != nullptr) {
          final list = mediaListPtr.cast<Pointer<Void>>();
          while (list[mediaCount] != nullptr) {
            bindings.ffmpeg_kit_handle_release(list[mediaCount]);
            mediaCount++;
          }
          bindings.ffmpeg_kit_free(mediaListPtr.cast());
        }
        if (kDebugMode) print("Media Info List Count: $mediaCount");
        expect(mediaCount, greaterThanOrEqualTo(1));

        // Cleanup
        bindings.ffmpeg_kit_handle_release(ffmpeg);
        bindings.ffmpeg_kit_handle_release(ffprobe);
        bindings.ffmpeg_kit_handle_release(media);
      });
    });
    test('FFmpegKitTest HandleManagement', () async {
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        // 1. Create a session and get a handle
        final session =
            bindings.ffmpeg_kit_create_session(toNative("-version", arena));
        expect(session, isNot(nullptr));

        // 2. First release - should work normally
        bindings.ffmpeg_kit_handle_release(session);

        // 3. Second release (Double Free) - should be caught by protection and NOT crash
        bindings.ffmpeg_kit_handle_release(session);

        // 4. Release nullptr - should be no-op
        bindings.ffmpeg_kit_handle_release(nullptr);
      });
    });

    test('FFmpegKitTest ConcurrentHandleRelease', () async {
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        // Create a session
        final session =
            bindings.ffmpeg_kit_create_session(toNative("-version", arena));
        expect(session, isNot(nullptr));

        // Multiple "threads" (Futures) trying to release the SAME handle simultaneously
        const int taskCount = 10;
        final tasks = List.generate(taskCount, (_) async {
          bindings.ffmpeg_kit_handle_release(session);
        });

        await Future.wait(tasks);

        // If we reached here without crashing, the test passed
      });
    });
    test('StressTest SerialSyncHammer', () async {
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        const int iterations = 50;
        for (int i = 0; i < iterations; ++i) {
          final session =
              bindings.ffmpeg_kit_execute(toNative("-version", arena));
          expect(session, isNot(nullptr));
          expect(bindings.ffmpeg_kit_session_get_state(session),
              equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));
          bindings.ffmpeg_kit_handle_release(session);
        }
      });
    });

    test('StressTest ParallelSyncHammer', () async {
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        const int threadCount = 10;
        const int iterationsPerThread = 10;

        final tasks = List.generate(threadCount, (_) async {
          for (int i = 0; i < iterationsPerThread; ++i) {
            final session =
                bindings.ffprobe_kit_execute(toNative("-version", arena));
            if (session != nullptr) {
              bindings.ffmpeg_kit_handle_release(session);
            }
          }
        });

        await Future.wait(tasks);
      });
    });

    test('StressTest AsyncBurstHammer', () async {
      await using((Arena arena) async {
        const int burstSize = 50;
        int completedCount = 0;
        final completer = Completer<void>();

        final completeCallback =
            NativeCallable<NativeCompleteCallback>.listener(
          (Pointer<Void> session, Pointer<Void> userData) {
            completedCount++;
            if (completedCount == burstSize && !completer.isCompleted) {
              completer.complete();
            }
          },
        );

        final List<Pointer<Void>> handles = [];
        final cmd = toNative("-version", arena);

        for (int i = 0; i < burstSize; ++i) {
          final session = bindings.ffmpeg_kit_execute_async(
            cmd,
            completeCallback.nativeFunction,
            nullptr,
          );
          if (session != nullptr) {
            handles.add(session);
          }
        }

        await completer.future.timeout(const Duration(seconds: 30),
            onTimeout: () {
          throw TimeoutException('Timed out waiting for burst completions');
        });

        expect(completedCount, equals(burstSize));

        completeCallback.close();
        for (final handle in handles) {
          bindings.ffmpeg_kit_handle_release(handle);
        }
      });
    });

    test('StressTest SessionHistoryConcurrency', () async {
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        bool stop = false;
        final List<Pointer<Void>> handles = [];

        // Task 1: Constantly creating sessions
        final creator = () async {
          while (!stop) {
            final s = bindings.ffmpeg_kit_execute_async(
                toNative("-version", arena), nullptr, nullptr);
            if (s != nullptr) {
              handles.add(s);
            }
            await Future.delayed(const Duration(milliseconds: 2));
          }
        }();

        // Task 2: Constantly clearing history
        final cleaner = () async {
          while (!stop) {
            bindings.ffmpeg_kit_config_clear_sessions();
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }();

        stop = true;
        await Future.wait([creator, cleaner]);

        await Future.delayed(const Duration(seconds: 5));

        for (final handle in handles) {
          bindings.ffmpeg_kit_handle_release(handle);
        }
      });
    });

    test('StressTest FFplaySessionRecycling', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        // Set SDL dummy drivers
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_VIDEODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_AUDIODRIVER", arena), toNative("dummy", arena));

        const int iterations = 10;
        for (int i = 0; i < iterations; ++i) {
          final cmd = toNative("-autoexit -t 0.1 ${getTestVideoFile()}", arena);
          final session = bindings.ffplay_kit_execute(cmd, 1000);
          if (session != nullptr) {
            bindings.ffmpeg_kit_handle_release(session);
          }
        }
      });
    });

    test('StressTest MixedHammer', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        const int iterations = 20;
        for (int i = 0; i < iterations; ++i) {
          final s1 = bindings.ffmpeg_kit_execute_async(
              toNative("-version", arena), nullptr, nullptr);
          final s2 = bindings.ffprobe_kit_execute_async(
              toNative("-version", arena), nullptr, nullptr);
          final s3 = bindings.ffprobe_kit_get_media_information_async(
              toNative(getTestVideoFile(), arena), nullptr, nullptr);

          if (s1 != nullptr) bindings.ffmpeg_kit_handle_release(s1);
          if (s2 != nullptr) bindings.ffmpeg_kit_handle_release(s2);
          if (s3 != nullptr) bindings.ffmpeg_kit_handle_release(s3);
        }
      });
    });
    test('FFmpegKitConfigTest Redirection', () async {
      await using((Arena arena) async {
        // Verify methods can be called without crashing
        bindings.ffmpeg_kit_config_enable_redirection();
        bindings.ffmpeg_kit_config_disable_redirection();
      });
    });

    test('FFmpegKitConfigTest EnvironmentVariable', () async {
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        // Set a dummy env var
        final int result = bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("FFMPEG_KIT_TEST_VAR", arena), toNative("1234", arena));

        // ffmpeg_kit_config_set_environment_variable returns 0 on success
        expect(result, equals(0));
      });
    });

    test('FFmpegKitConfigTest IgnoreSignal', () async {
      await using((Arena arena) async {
        // ffmpeg_kit_config_ignore_signal(FFMPEG_KIT_SIGNAL_SIGPIPE);
        bindings.ffmpeg_kit_config_ignore_signal(
            FFmpegKitSignal.FFMPEG_KIT_SIGNAL_SIGPIPE);
      });
    });

    test('FFmpegKitConfigTest FontDirectory', () async {
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        bindings.ffmpeg_kit_config_set_font_directory(
            toNative("/tmp/fonts", arena), nullptr);

        final fontDirs = arena<Pointer<Char>>(2);
        fontDirs[0] = toNative("/tmp/fonts1", arena);
        fontDirs[1] = toNative("/tmp/fonts2", arena);

        bindings.ffmpeg_kit_config_set_font_directory_list(
            fontDirs, 2, nullptr);
      });
    });

    test('FFmpegKitConfigTest LogLevelToString', () async {
      await using((Arena arena) async {
        // char* str = ffmpeg_kit_config_log_level_to_string(FFMPEG_KIT_LOG_LEVEL_DEBUG);
        final strPtr = bindings.ffmpeg_kit_config_log_level_to_string(
            FFmpegKitLogLevel.FFMPEG_KIT_LOG_LEVEL_DEBUG);

        expect(strPtr, isNot(nullptr));
        final str = _fromNative(strPtr);
        expect(str, isNotEmpty);

        bindings.ffmpeg_kit_free(strPtr.cast());
      });
    });

    test('FFmpegKitConfigTest SessionStateToString', () async {
      await using((Arena arena) async {
        // char* str = ffmpeg_kit_config_session_state_to_string(FFMPEG_KIT_SESSION_STATE_COMPLETED);
        final strPtr = bindings.ffmpeg_kit_config_session_state_to_string(
            FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED);

        expect(strPtr, isNot(nullptr));
        final str = _fromNative(strPtr);
        expect(str, isNotEmpty);

        bindings.ffmpeg_kit_free(strPtr.cast());
      });
    });

    test('FFmpegKitConfigTest ArgumentsToString', () async {
      await using((Arena arena) async {
        Pointer<Char> toNative(String s, Arena arena) =>
            arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

        final args = arena<Pointer<Char>>(5);
        args[0] = toNative("ffmpeg", arena);
        args[1] = toNative("-i", arena);
        args[2] = toNative("test.mp4", arena);
        args[3] = toNative("-vcodec", arena);
        args[4] = toNative("copy", arena);

        // char* str = ffmpeg_kit_config_arguments_to_string((char**)args, 5);
        final strPtr = bindings.ffmpeg_kit_config_arguments_to_string(args, 5);

        expect(strPtr, isNot(nullptr));
        final str = _fromNative(strPtr);
        expect(str, isNotEmpty);

        bindings.ffmpeg_kit_free(strPtr.cast());
      });
    });
  });

  test('FFmpegKitTest RobustnessTest', () async {
    await using((Arena arena) async {
      Pointer<Char> toNative(String s, Arena arena) =>
          arena.using(s.toNativeUtf8(), calloc.free).cast<Char>();

      // 1. Create a session and execute it to ensure it's in history
      final session =
          bindings.ffmpeg_kit_create_session(toNative("-version", arena));
      expect(session, isNot(nullptr));

      bindings.ffmpeg_kit_session_execute(session);

      // 2. Get session ID
      final id = bindings.ffmpeg_kit_session_get_session_id(session);
      expect(id, greaterThan(0));

      // 3. Release handle
      bindings.ffmpeg_kit_handle_release(session);

      // 4. Try to use released handle (should NOT crash)
      // Wrapper logic should return -1/nullptr because the handle is purged from the active map
      expect(bindings.ffmpeg_kit_session_get_session_id(session), equals(-1));
      expect(bindings.ffmpeg_kit_session_get_output(session), equals(nullptr));

      // 5. Try with "fake" handle (ID as pointer)
      // Convert the integer ID into a Pointer address.
      // The native layer should detect this is not in active_handles and check session history.
      final fakeHandle = Pointer<Void>.fromAddress(id);

      expect(
          bindings.ffmpeg_kit_session_get_session_id(fakeHandle), equals(id));

      final outputPtr = bindings.ffmpeg_kit_session_get_output(fakeHandle);
      expect(outputPtr, isNot(nullptr));

      if (outputPtr != nullptr) {
        final output = _fromNative(outputPtr);
        if (kDebugMode) print("Output from fake handle: $output");
        bindings.ffmpeg_kit_free(outputPtr.cast());
      }
    });
  });

  group('CallbackTests', () {
    setUp(() {
      bindings.ffmpeg_kit_config_clear_sessions();
      bindings.ffmpeg_kit_config_enable_redirection();
    });

    test('CallbackTest FFmpegAsyncExecute', () async {
      await using((Arena arena) async {
        final capturer = _CallbackCapturer();
        final completer = Completer<void>();

        final completeCallback =
            NativeCallable<NativeCompleteCallback>.listener(
          (Pointer<Void> session, Pointer<Void> userData) {
            capturer.completeCalled = true;
            capturer.capturedSession = session;
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );

        final session = bindings.ffmpeg_kit_execute_async(
          toNative("-version", arena),
          completeCallback.nativeFunction,
          nullptr,
        );

        expect(session, isNot(nullptr));

        await completer.future.timeout(const Duration(seconds: 10),
            onTimeout: () {
          throw TimeoutException('Timed out waiting for complete callback');
        });

        expect(capturer.completeCalled, isTrue);
        expect(
            bindings.ffmpeg_kit_session_get_session_id(session),
            equals(bindings
                .ffmpeg_kit_session_get_session_id(capturer.capturedSession!)));

        completeCallback.close();
        bindings.ffmpeg_kit_handle_release(session);
      });
    });

    test('CallbackTest FFmpegAsyncExecuteFull', () async {
      await using((Arena arena) async {
        bindings.ffmpeg_kit_config_set_log_level(
            FFmpegKitLogLevel.FFMPEG_KIT_LOG_LEVEL_INFO);
        final capturer = _CallbackCapturer();
        final completer = Completer<void>();

        // 1. For CompleteCallback
        final completeCallback =
            NativeCallable<NativeCompleteCallback>.listener(
          (Pointer<Void> session, Pointer<Void> userData) {
            capturer.completeCalled = true;
            capturer.capturedSession = session;
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );

        // 2. For LogCallback
        final logCb = NativeCallable<NativeLogCallback>.listener(
          (Pointer<Void> session, Pointer<Char> log, Pointer<Void> userData) {
            capturer.logCalled = true;
          },
        );

        // 3. For StatisticsCallback
        final statsCb = NativeCallable<NativeStatisticsCallback>.listener(
          (Pointer<Void> session,
              int time,
              int size,
              double bitrate,
              double speed,
              int videoFrameNumber,
              double videoFps,
              double videoQuality,
              Pointer<Void> userData) {
            capturer.statsCalled = true;
          },
        );

        const cmd =
            "-hide_banner -loglevel info -f lavfi -i testsrc=duration=30:size=512x512:rate=30 -vcodec mpeg4 -y test_stats.mp4";
        final session = bindings.ffmpeg_kit_execute_async_full(
          toNative(cmd, arena),
          completeCallback.nativeFunction,
          logCb.nativeFunction,
          statsCb.nativeFunction,
          nullptr,
          0,
        );

        await completer.future.timeout(const Duration(seconds: 15),
            onTimeout: () {
          throw TimeoutException('Timed out waiting for complete callback');
        });

        if (kDebugMode) print("completeCalled: ${capturer.completeCalled}");
        if (kDebugMode) print("logCalled: ${capturer.logCalled}");
        if (kDebugMode) print("statsCalled: ${capturer.statsCalled}");
        expect(capturer.completeCalled, isTrue);
        expect(capturer.logCalled, isTrue);
        expect(capturer.statsCalled, isTrue);

        completeCallback.close();
        logCb.close();
        statsCb.close();
        bindings.ffmpeg_kit_handle_release(session);
      });
    });

    test('CallbackTest MediaInformationAsync', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        final capturer = _CallbackCapturer();
        final completer = Completer<void>();

        final mediaInfoCb = NativeCallable<NativeCompleteCallback>.listener(
          (Pointer<Void> cbSession, Pointer<Void> userData) {
            capturer.completeCalled = true;
            capturer.capturedSession = cbSession;
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );

        final inputFile = getTestVideoFile();
        final session = bindings.ffprobe_kit_get_media_information_async(
          toNative(inputFile, arena),
          mediaInfoCb.nativeFunction,
          nullptr,
        );

        expect(session, isNot(nullptr));

        await completer.future.timeout(const Duration(seconds: 10),
            onTimeout: () {
          throw TimeoutException(
              'Timed out waiting for media info complete callback');
        });

        expect(capturer.completeCalled, isTrue);
        expect(capturer.capturedSession, isNot(nullptr));

        // session handle (returned by async call) and capturer.capturedSession handle
        // (passed to callback) should be the same handle.
        expect(session.address, equals(capturer.capturedSession!.address));

        // Use the original handle returned by the async call to inspect
        final mediaInfo =
            bindings.media_information_session_get_media_information(session);

        expect(mediaInfo, isNot(nullptr));
        if (kDebugMode) print("Media Info: $mediaInfo");
        final allPropsPtr =
            bindings.media_information_get_all_properties_json(mediaInfo);
        final allProps = _fromNative(allPropsPtr);
        if (kDebugMode) print("All Props: $allProps");
        expect(allProps, isNot(nullptr));
        expect(allProps, isNot(''));
        if (mediaInfo != nullptr) {
          final formatPtr = bindings.media_information_get_format(mediaInfo);
          if (formatPtr != nullptr) {
            bindings.ffmpeg_kit_free(formatPtr.cast());
          }
          bindings.ffmpeg_kit_handle_release(mediaInfo);
        }

        mediaInfoCb.close();
        bindings.ffmpeg_kit_free(allPropsPtr.cast());
        bindings.ffmpeg_kit_handle_release(session);
      });
    });

    test('CallbackTest GlobalCallbacks', () async {
      if (!File(getTestVideoFile()).existsSync()) {
        generateTestVideoFile();
      }
      await using((Arena arena) async {
        bindings.ffmpeg_kit_config_set_log_level(
            FFmpegKitLogLevel.FFMPEG_KIT_LOG_LEVEL_INFO);
        final capturer = _GlobalCapturer();
        final completer = Completer<void>();
        const expectedCompletions = 4;

        // Setup Global Callbacks
        final logCb = NativeCallable<NativeLogCallback>.listener(
          (Pointer<Void> session, Pointer<Char> log, Pointer<Void> userData) {
            capturer.logCalled = true;
          },
        );
        final statsCb = NativeCallable<NativeStatisticsCallback>.listener(
          (Pointer<Void> session,
              int time,
              int size,
              double bitrate,
              double speed,
              int videoFrameNumber,
              double videoFps,
              double videoQuality,
              Pointer<Void> userData) {
            capturer.statsCalled = true;
          },
        );
        final completeCb = NativeCallable<NativeCompleteCallback>.listener(
          (Pointer<Void> session, Pointer<Void> userData) {
            capturer.completeCount++;
            if (capturer.completeCount == expectedCompletions &&
                !completer.isCompleted) {
              completer.complete();
            }
          },
        );

        bindings.ffmpeg_kit_config_enable_log_callback(
            logCb.nativeFunction, nullptr);
        bindings.ffmpeg_kit_config_enable_statistics_callback(
            statsCb.nativeFunction, nullptr);
        bindings.ffmpeg_kit_config_enable_ffmpeg_session_complete_callback(
            completeCb.nativeFunction, nullptr);
        bindings.ffmpeg_kit_config_enable_ffprobe_session_complete_callback(
            completeCb.nativeFunction, nullptr);
        bindings.ffmpeg_kit_config_enable_ffplay_session_complete_callback(
            completeCb.nativeFunction, nullptr);
        bindings
            .ffmpeg_kit_config_enable_media_information_session_complete_callback(
                completeCb.nativeFunction, nullptr);

        // Environment for FFplay
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_VIDEODRIVER", arena), toNative("dummy", arena));
        bindings.ffmpeg_kit_config_set_environment_variable(
            toNative("SDL_AUDIODRIVER", arena), toNative("dummy", arena));

        // Launch multiple sessions
        final s1 = bindings.ffmpeg_kit_execute_async(
            toNative(
                "-loglevel fatal -hide_banner -f lavfi -i testsrc=duration=2:size=128x128:rate=30 -f null -",
                arena),
            nullptr,
            nullptr);
        final s2 = bindings.ffprobe_kit_execute_async(
            toNative("-version", arena), nullptr, nullptr);
        final s3 = bindings.ffplay_kit_execute_async(
            toNative(
                "-hide_banner -loglevel fatal -autoexit -t 0.5 ${getTestVideoFile()}",
                arena),
            nullptr,
            nullptr,
            5000);
        final s4 = bindings.ffprobe_kit_get_media_information_async(
            toNative(getTestVideoFile(), arena), nullptr, nullptr);

        final sessions = [s1, s2, s3, s4];

        await completer.future.timeout(const Duration(seconds: 10),
            onTimeout: () {
          throw TimeoutException(
              'Timed out waiting for global complete callbacks');
        });

        expect(capturer.completeCount, equals(4));
        expect(capturer.logCalled, isTrue);

        // Disable Globals
        bindings.ffmpeg_kit_config_enable_log_callback(nullptr, nullptr);
        bindings.ffmpeg_kit_config_enable_statistics_callback(nullptr, nullptr);

        logCb.close();
        statsCb.close();
        completeCb.close();
        for (final s in sessions) {
          bindings.ffmpeg_kit_handle_release(s);
        }
      });
    });

    group('FFmpegKit Create Session Completer Tests', () {
      test('CallbackTest FFmpegCreateSessionWithCallbacks', () async {
        await using((Arena arena) async {
          final completer = Completer<void>();
          bool logCalled = false;
          bool statsCalled = false;

          final completeCb = NativeCallable<NativeCompleteCallback>.listener(
              (Pointer<Void> s, Pointer<Void> _) => completer.complete());
          final logCb = NativeCallable<NativeLogCallback>.listener(
              (Pointer<Void> s, Pointer<Char> l, Pointer<Void> _) =>
                  logCalled = true);
          final statsCb = NativeCallable<NativeStatisticsCallback>.listener(
              (Pointer<Void> s, int t, int sz, double b, double sp, int vf,
                      double vfps, double vq, Pointer<Void> _) =>
                  statsCalled = true);

          final session = bindings.ffmpeg_kit_create_session_with_callbacks(
            toNative("-version", arena),
            completeCb.nativeFunction,
            logCb.nativeFunction,
            statsCb.nativeFunction,
            nullptr,
          );

          expect(session, isNot(nullptr));
          bindings.ffmpeg_kit_session_execute_async(session);

          // Wait for the native callback to signal via the completer
          await completer.future.timeout(const Duration(seconds: 5));

          // Ensure logs/stats are fully flushed
          await waitForSessionToSettle(session);

          expect(logCalled, isTrue);
          expect(statsCalled, isTrue);
          expect(bindings.ffmpeg_kit_session_get_state(session),
              equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

          bindings.ffmpeg_kit_set_callbacks(
              session, nullptr, nullptr, nullptr, nullptr);
          await Future.delayed(const Duration(milliseconds: 50));

          for (var cb in [completeCb, logCb, statsCb]) {
            cb.close();
          }
          bindings.ffmpeg_kit_handle_release(session);
        });
      });

      test('CallbackTest FFprobeCreateSessionWithCallbacks', () async {
        await using((Arena arena) async {
          final completer = Completer<void>();

          final completeCb = NativeCallable<NativeCompleteCallback>.listener(
              (Pointer<Void> s, Pointer<Void> _) => completer.complete());

          final session = bindings.ffprobe_kit_create_session_with_callbacks(
            toNative("-version", arena),
            completeCb.nativeFunction,
            nullptr,
            nullptr,
          );

          expect(session, isNot(nullptr));
          bindings.ffprobe_kit_session_execute_async(session);

          await completer.future.timeout(const Duration(seconds: 5));
          await waitForSessionToSettle(session);

          expect(bindings.ffmpeg_kit_session_get_state(session),
              equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

          bindings.ffmpeg_kit_set_callbacks(
              session, nullptr, nullptr, nullptr, nullptr);
          await Future.delayed(const Duration(milliseconds: 50));

          completeCb.close();
          bindings.ffmpeg_kit_handle_release(session);
        });
      });

      test('CallbackTest MediaInformationCreateSessionWithCallbacks', () async {
        await using((Arena arena) async {
          final completer = Completer<void>();

          final completeCb = NativeCallable<NativeCompleteCallback>.listener(
            (Pointer<Void> s, Pointer<Void> _) {
              if (!completer.isCompleted) completer.complete();
            },
          );

          final cmd =
              "-v error -hide_banner -print_format json -show_format -show_streams -show_chapters -i ${getTestVideoFile()}";
          final session =
              bindings.media_information_create_session_with_callbacks(
            toNative(cmd, arena),
            completeCb.nativeFunction,
            nullptr,
            nullptr,
          );

          expect(session, isNot(nullptr));
          bindings.media_information_session_execute_async(session, 5000);

          await completer.future.timeout(const Duration(seconds: 10));
          await waitForSessionToSettle(session);

          final state = bindings.ffmpeg_kit_session_get_state(session);
          expect(
              state ==
                      FFmpegKitSessionState
                          .FFMPEG_KIT_SESSION_STATE_COMPLETED ||
                  state ==
                      FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_FAILED,
              isTrue);

          bindings.ffmpeg_kit_set_callbacks(
              session, nullptr, nullptr, nullptr, nullptr);
          await Future.delayed(const Duration(milliseconds: 50));

          completeCb.close();
          bindings.ffmpeg_kit_handle_release(session);
        });
      });

      test('CallbackTest SessionCallbackStressTest', () async {
        await using((Arena arena) async {
          final completer = Completer<void>();
          bool logCalled = false;
          bool statsCalled = false;

          final completeCb = NativeCallable<NativeCompleteCallback>.listener(
              (Pointer<Void> s, Pointer<Void> _) => completer.complete());
          final logCb = NativeCallable<NativeLogCallback>.listener(
              (Pointer<Void> s, Pointer<Char> l, Pointer<Void> _) =>
                  logCalled = true);
          final statsCb = NativeCallable<NativeStatisticsCallback>.listener(
              (Pointer<Void> s, int t, int sz, double b, double sp, int vf,
                      double vfps, double vq, Pointer<Void> _) =>
                  statsCalled = true);

          const cmd =
              "-hide_banner -loglevel info -f lavfi -i testsrc=duration=2:size=128x128:rate=30 -f null -";
          final session = bindings.ffmpeg_kit_execute_async_full(
            toNative(cmd, arena),
            completeCb.nativeFunction,
            logCb.nativeFunction,
            statsCb.nativeFunction,
            nullptr,
            0,
          );

          bool stopStress = false;
          final stressFuture = Future(() async {
            while (!stopStress) {
              bindings.ffmpeg_kit_set_callbacks(
                session,
                completeCb.nativeFunction,
                logCb.nativeFunction,
                statsCb.nativeFunction,
                nullptr,
              );
              await Future.delayed(Duration.zero);
            }
          });

          await completer.future.timeout(const Duration(seconds: 15));
          await waitForSessionToSettle(session);

          stopStress = true;
          await stressFuture;

          expect(bindings.ffmpeg_kit_session_get_state(session),
              equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

          bindings.ffmpeg_kit_set_callbacks(
              session, nullptr, nullptr, nullptr, nullptr);
          await Future.delayed(const Duration(milliseconds: 50));

          expect(completer.isCompleted, isTrue);
          expect(logCalled, isTrue);
          expect(statsCalled, isTrue);

          for (var cb in [completeCb, logCb, statsCb]) {
            cb.close();
          }
          bindings.ffmpeg_kit_handle_release(session);
        });
      });
    });
  });
}
