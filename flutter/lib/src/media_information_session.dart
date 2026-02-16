/**
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

import 'package:ffi/ffi.dart';

import 'callback_manager.dart';
import 'chapter_information.dart';
import 'ffmpeg_kit_flutter_loader.dart';
import 'ffprobe_session.dart';
import 'generated/ffmpeg_kit_bindings.dart';
import 'media_information.dart';
import 'session_queue_manager.dart';
import 'stream_information.dart';

/// A specialized [FFprobeSession] for retrieving detailed media information.
///
/// This session type is optimized for getting [MediaInformation] objects
/// from a media source path.
class MediaInformationSession extends FFprobeSession {
  FFprobeSessionCompleteCallback? _completeCallback;
  late String _path;

  /// The callback invoked when the session completes.
  @override
  FFprobeSessionCompleteCallback? get completeCallback => _completeCallback;

  /// Sets or updates the [completeCallback] for this session.
  @override
  void setCompleteCallback(FFprobeSessionCompleteCallback? completeCallback) {
    if (completeCallback != null) {
      _completeCallback = completeCallback;
      final int callbackId = CallbackManager().nextCallbackId++;
      CallbackManager().callbackIdToSessionId[callbackId] = sessionId;
      CallbackManager().ffprobeSessions[sessionId] = this;
    }
  }

  /// Removes the [completeCallback] for this session.
  void removeCompleteCallback() {
    _completeCallback = null;
    CallbackManager().callbackIdToSessionId.remove(sessionId);
    CallbackManager().ffprobeSessions.remove(sessionId);
  }

  int _timeout = 500;

  /// The connection timeout in milliseconds.
  int get timeout => _timeout;

  /// Sets the connection [timeout] in milliseconds.
  void setTimeout(int timeout) {
    _timeout = timeout;
  }

  /// Creates a new [MediaInformationSession] for the given [command].
  ///
  /// - [command]: The media source or probe command.
  /// - [completeCallback]: Optional callback invoked when information retrieval ends.
  /// - [timeout]: Connection timeout in milliseconds.
  MediaInformationSession(
    String command, {
    FFprobeSessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) : super.internal() {
    this._timeout = timeout;
    this._path = command;

    String finalCommand = command;
    if (!command.contains('-show_format') &&
        !command.contains('-show_streams')) {
      finalCommand = "-show_format -show_streams -print_format json $command";
    }
    this.command = finalCommand;

    final cmdPtr = finalCommand.toNativeUtf8();
    try {
      this.handle = ffmpeg.media_information_create_session(cmdPtr.cast());
      this.startTime = DateTime.now();
      this.sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
      this.registerFinalizer();
    } finally {
      calloc.free(cmdPtr);
    }

    if (completeCallback != null) {
      this._completeCallback = completeCallback;
      final int callbackId = CallbackManager().nextCallbackId++;
      CallbackManager().callbackIdToSessionId[callbackId] = sessionId;
      CallbackManager().ffprobeSessions[sessionId] = this;
    }
  }

  /// Creates a [MediaInformationSession] from a native [handle] and the [command].
  MediaInformationSession.fromHandle(Pointer<Void> handle, String command)
      : super.fromHandle(handle, command);

  /// Facilitates creating a new [MediaInformationSession].
  static MediaInformationSession create(String command,
          {FFprobeSessionCompleteCallback? completeCallback,
          int timeout = 500}) =>
      MediaInformationSession(command,
          timeout: timeout, completeCallback: completeCallback);

  /// Executes this session synchronously.
  @override
  MediaInformationSession execute({
    SessionExecutionStrategy strategy = SessionExecutionStrategy.queue,
  }) {
    // Truly synchronous execution blocks the current isolate
    ffmpeg.media_information_session_execute(handle, _timeout);
    return this;
  }

  /// Creates and executes a [MediaInformationSession] synchronously.
  static MediaInformationSession executeCommand(
    String command, {
    FFprobeSessionCompleteCallback? completeCallback,
    int timeout = 500,
    SessionExecutionStrategy strategy = SessionExecutionStrategy.queue,
  }) {
    final session = MediaInformationSession.create(command,
        timeout: timeout, completeCallback: completeCallback);
    return session.execute(strategy: strategy);
  }

  /// Executes this session asynchronously.
  @override
  Future<MediaInformationSession> executeAsync({
    FFprobeSessionCompleteCallback? completeCallback,
    SessionExecutionStrategy strategy = SessionExecutionStrategy.queue,
  }) async {
    if (completeCallback != null) this._completeCallback = completeCallback;

    // Start execution through queue manager
    await SessionQueueManager().executeSession(
      this,
      () async {
        final sessionCompleter = Completer<void>();

        // Store the original callback
        final originalCallback = this._completeCallback;

        // Wrap the callback to complete our completer
        this._completeCallback = (session) {
          originalCallback?.call(session);
          if (!sessionCompleter.isCompleted) {
            sessionCompleter.complete();
          }
        };

        final cmdPtr = _path.toNativeUtf8();
        final int callbackId = CallbackManager().nextCallbackId++;
        CallbackManager().callbackIdToFFprobeSession[callbackId] = this;

        CallbackManager().ffprobeSessions.remove(sessionId);

        MediaInformationSessionHandle newHandle;
        try {
          newHandle = ffmpeg.ffprobe_kit_get_media_information_async(
              cmdPtr.cast(),
              nativeMediaInfoComplete.nativeFunction,
              Pointer<Void>.fromAddress(callbackId));
        } finally {
          calloc.free(cmdPtr);
        }

        this.handle = newHandle;
        this.sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
        this.registerFinalizer();

        CallbackManager().callbackIdToSessionId[callbackId] = sessionId;
        CallbackManager().ffprobeSessions[sessionId] = this;

        // Wait for the session to complete
        await sessionCompleter.future;
      },
      strategy: strategy,
    );

    return this;
  }

  /// Retrieves the collected [MediaInformation] from the session results.
  ///
  /// Returns null if the information is not yet available or retrieval failed.
  MediaInformation? getMediaInformation() {
    final mediaInfoHandle =
        ffmpeg.media_information_session_get_media_information(handle);
    if (mediaInfoHandle == nullptr) return null;

    /// Internal helper to safely get and free C strings.
    String? getString(Pointer<Char> Function(Pointer<Void>) func) {
      final ptr = func(mediaInfoHandle);
      if (ptr == nullptr) return null;
      final res = ptr.cast<Utf8>().toDartString();
      ffmpeg.ffmpeg_kit_free(ptr.cast());
      return res;
    }

    // Release handles
    try {
      // Chapters
      final chaptersCount =
          ffmpeg.media_information_get_chapters_count(mediaInfoHandle);
      final chapters = <ChapterInformation>[];
      for (int i = 0; i < chaptersCount; i++) {
        final chapterHandle =
            ffmpeg.media_information_get_chapter_at(mediaInfoHandle, i);
        if (chapterHandle != nullptr) {
          try {
            String? getChapterString(
                Pointer<Char> Function(Pointer<Void>) func) {
              final ptr = func(chapterHandle);
              if (ptr == nullptr) return null;
              final res = ptr.cast<Utf8>().toDartString();
              ffmpeg.ffmpeg_kit_free(ptr.cast());
              return res;
            }

            chapters.add(ChapterInformation(
              id: ffmpeg.chapter_get_id(chapterHandle),
              timeBase:
                  getChapterString((h) => ffmpeg.chapter_get_time_base(h)),
              start: ffmpeg.chapter_get_start(chapterHandle),
              startTime:
                  getChapterString((h) => ffmpeg.chapter_get_start_time(h)),
              end: ffmpeg.chapter_get_end(chapterHandle),
              endTime: getChapterString((h) => ffmpeg.chapter_get_end_time(h)),
              tagsJson:
                  getChapterString((h) => ffmpeg.chapter_get_tags_json(h)),
              allPropertiesJson: getChapterString(
                  (h) => ffmpeg.chapter_get_all_properties_json(h)),
            ));
          } finally {
            ffmpeg.ffmpeg_kit_handle_release(chapterHandle);
          }
        }
      }

      // Streams
      final streamsCount =
          ffmpeg.media_information_get_streams_count(mediaInfoHandle);
      final streams = <StreamInformation>[];
      for (int i = 0; i < streamsCount; i++) {
        final streamHandle =
            ffmpeg.media_information_get_stream_at(mediaInfoHandle, i);
        if (streamHandle != nullptr) {
          try {
            String? getStreamString(
                Pointer<Char> Function(Pointer<Void>) func) {
              final ptr = func(streamHandle);
              if (ptr == nullptr) return null;
              final res = ptr.cast<Utf8>().toDartString();
              ffmpeg.ffmpeg_kit_free(ptr.cast());
              return res;
            }

            streams.add(StreamInformation(
              index: ffmpeg.stream_information_get_index(streamHandle),
              type:
                  getStreamString((h) => ffmpeg.stream_information_get_type(h)),
              codec: getStreamString(
                  (h) => ffmpeg.stream_information_get_codec(h)),
              codecLong: getStreamString(
                  (h) => ffmpeg.stream_information_get_codec_long(h)),
              format: getStreamString(
                  (h) => ffmpeg.stream_information_get_format(h)),
              width: ffmpeg.stream_information_get_width(streamHandle),
              height: ffmpeg.stream_information_get_height(streamHandle),
              bitrate: getStreamString(
                  (h) => ffmpeg.stream_information_get_bitrate(h)),
              sampleRate: getStreamString(
                  (h) => ffmpeg.stream_information_get_sample_rate(h)),
              sampleFormat: getStreamString(
                  (h) => ffmpeg.stream_information_get_sample_format(h)),
              channelLayout: getStreamString(
                  (h) => ffmpeg.stream_information_get_channel_layout(h)),
              sampleAspectRatio: getStreamString(
                  (h) => ffmpeg.stream_information_get_sample_aspect_ratio(h)),
              displayAspectRatio: getStreamString(
                  (h) => ffmpeg.stream_information_get_display_aspect_ratio(h)),
              averageFrameRate: getStreamString(
                  (h) => ffmpeg.stream_information_get_average_frame_rate(h)),
              realFrameRate: getStreamString(
                  (h) => ffmpeg.stream_information_get_real_frame_rate(h)),
              timeBase: getStreamString(
                  (h) => ffmpeg.stream_information_get_time_base(h)),
              codecTimeBase: getStreamString(
                  (h) => ffmpeg.stream_information_get_codec_time_base(h)),
              tagsJson: getStreamString(
                  (h) => ffmpeg.stream_information_get_tags_json(h)),
              allPropertiesJson: getStreamString(
                  (h) => ffmpeg.stream_information_get_all_properties_json(h)),
            ));
          } finally {
            ffmpeg.ffmpeg_kit_handle_release(streamHandle);
          }
        }
      }

      return MediaInformation(
        filename: getString((h) => ffmpeg.media_information_get_filename(h)),
        format: getString((h) => ffmpeg.media_information_get_format(h)),
        longFormat:
            getString((h) => ffmpeg.media_information_get_long_format(h)),
        duration: getString((h) => ffmpeg.media_information_get_duration(h)),
        startTime: getString((h) => ffmpeg.media_information_get_start_time(h)),
        bitrate: getString((h) => ffmpeg.media_information_get_bitrate(h)),
        size: getString((h) => ffmpeg.media_information_get_size(h)),
        tagsJson: getString((h) => ffmpeg.media_information_get_tags_json(h)),
        allPropertiesJson: getString(
            (h) => ffmpeg.media_information_get_all_properties_json(h)),
        streams: streams,
        chapters: chapters,
      );
    } finally {
      ffmpeg.ffmpeg_kit_handle_release(mediaInfoHandle);
    }
  }

  @override
  bool isFFmpegSession() => false;

  @override
  bool isFFplaySession() => false;

  @override
  bool isFFprobeSession() => false;

  @override
  bool isMediaInformationSession() => true;
}
