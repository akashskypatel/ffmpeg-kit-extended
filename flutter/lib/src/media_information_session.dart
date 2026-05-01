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
import 'dart:developer';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../ffmpeg_kit_extended_flutter.dart';
import 'callback_manager.dart';
import 'chapter_information.dart';
import 'generated/ffmpeg_kit_bindings.dart' as ffmpeg;
import 'stream_information.dart';

/// A specialised [FFprobeSession] for retrieving detailed media information.
///
/// Internally runs an ffprobe command with `-print_format json -show_format
/// -show_streams -show_chapters` and parses the result into a [MediaInformation]
/// object that can be retrieved via [getMediaInformation].
class MediaInformationSession extends FFprobeSession {
  MediaInformationSessionCompleteCallback? _mediaInfoCompleteCallback;

  int _timeout;

  bool _registered = false;

  // ---------------------------------------------------------------------------
  // Default ffprobe command fragments
  // ---------------------------------------------------------------------------

  static const String _defaultCommandPrefix = '-v error -hide_banner';
  static const String _defaultCommand =
      '-v error -hide_banner -print_format json -show_format -show_streams -show_chapters -i';

  // ---------------------------------------------------------------------------
  // Callback accessors / mutators
  // ---------------------------------------------------------------------------

  /// The callback invoked once when information retrieval completes.
  MediaInformationSessionCompleteCallback? get mediaInfoCompleteCallback =>
      _mediaInfoCompleteCallback;

  /// Overrides the base [completeCallback] getter to surface the typed callback
  /// as a [FFprobeSessionCompleteCallback] so that shared session-management
  /// code that only knows about [FFprobeSession] can still invoke it.
  ///
  /// Safe because [MediaInformationSession] IS-A [FFprobeSession].
  @override
  FFprobeSessionCompleteCallback? get completeCallback =>
      _mediaInfoCompleteCallback != null
      ? (s) => _mediaInfoCompleteCallback!(s as MediaInformationSession)
      : null;

  /// Sets or replaces the completion callback.
  void setMediaInfoCompleteCallback(
    MediaInformationSessionCompleteCallback? cb,
  ) {
    _mediaInfoCompleteCallback = cb;
    _ensureRegistered();
  }

  /// Clears the completion callback and unregisters from [CallbackManager].
  void removeMediaInfoCompleteCallback() {
    _mediaInfoCompleteCallback = null;
    _unregister();
  }

  /// Kept for API compatibility with callers that hold an [FFprobeSession]
  /// reference; routes to [setMediaInfoCompleteCallback] with a safe cast.
  @override
  void setCompleteCallback(FFprobeSessionCompleteCallback? completeCallback) {
    if (completeCallback == null) {
      removeMediaInfoCompleteCallback();
    } else {
      setMediaInfoCompleteCallback((s) => completeCallback(s));
    }
  }

  /// Clears all completion callbacks.
  @override
  void removeCompleteCallback() => removeMediaInfoCompleteCallback();

  // ---------------------------------------------------------------------------
  // Timeout
  // ---------------------------------------------------------------------------

  /// The connection timeout in milliseconds.
  int get timeout => _timeout;

  /// Sets the connection [timeout] in milliseconds.
  void setTimeout(int timeout) => _timeout = timeout;

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Creates a [MediaInformationSession] from a custom ffprobe [command].
  ///
  /// [command] is prefixed with `-v error -hide_banner` before being sent to
  /// the native layer.
  MediaInformationSession(
    String command, {
    MediaInformationSessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) : _timeout = timeout,
       super.internal() {
    FFmpegKitExtended.requireInitialized();
    final finalCommand = '$_defaultCommandPrefix $command';
    this.command = finalCommand;

    final cmdPtr = finalCommand.toNativeUtf8(allocator: calloc);
    try {
      try {
        handle = ffmpeg.media_information_create_session(cmdPtr.cast());
      } catch (e, st) {
        log(
          'MediaInformationSession: error creating session media_information_create_session $finalCommand',
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
      try {
        sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
      } catch (e, st) {
        log(
          'MediaInformationSession: error getting session id for ffmpeg_kit_session_get_session_id $finalCommand',
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
      registerFinalizer();
    } finally {
      calloc.free(cmdPtr);
    }

    _mediaInfoCompleteCallback = completeCallback;
    CallbackManager().registerMediaInformationSession(this);
    _registered = true;
  }

  // ---------------------------------------------------------------------------
  // Named constructors
  // ---------------------------------------------------------------------------

  /// Restores a [MediaInformationSession] from a native [handle].
  MediaInformationSession.fromHandle(Pointer<Void> handle, String command)
    : _timeout = 500,
      super.internal() {
    FFmpegKitExtended.requireInitialized();
    this.handle = handle;
    this.command = command;

    try {
      sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
    } catch (e, st) {
      log(
        'MediaInformationSession.fromHandle: error getting session id for ffmpeg_kit_session_get_session_id $command',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    registerFinalizer();
    // No callback registration: restored sessions have no active callbacks.
  }

  /// Creates a [MediaInformationSession] for a local [file].
  MediaInformationSession.fromFile(
    File file, {
    MediaInformationSessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) : _timeout = timeout,
       super.internal() {
    FFmpegKitExtended.requireInitialized();
    final finalCommand = '$_defaultCommand ${file.path}';
    command = finalCommand;

    final cmdPtr = finalCommand.toNativeUtf8(allocator: calloc);
    try {
      try {
        handle = ffmpeg.media_information_create_session(cmdPtr.cast());
      } catch (e, st) {
        log(
          'MediaInformationSession.fromFile: error creating session media_information_create_session $finalCommand',
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
      try {
        sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
      } catch (e, st) {
        log(
          'MediaInformationSession.fromFile: error getting session id for ffmpeg_kit_session_get_session_id $finalCommand',
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
      registerFinalizer();
    } catch (e, st) {
      log(
        'MediaInformationSession.fromFile: failed to create session',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } finally {
      calloc.free(cmdPtr);
    }

    _mediaInfoCompleteCallback = completeCallback;
    CallbackManager().registerMediaInformationSession(this);
    _registered = true;
  }

  /// Creates a [MediaInformationSession] for a network [uri].
  MediaInformationSession.fromUri(
    Uri uri, {
    MediaInformationSessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) : _timeout = timeout,
       super.internal() {
    FFmpegKitExtended.requireInitialized();
    final finalCommand = '$_defaultCommand ${uri.toString()}';
    command = finalCommand;

    final cmdPtr = finalCommand.toNativeUtf8(allocator: calloc);
    try {
      try {
        handle = ffmpeg.media_information_create_session(cmdPtr.cast());
      } catch (e, st) {
        log(
          'MediaInformationSession.fromUri: error creating session media_information_create_session $finalCommand',
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
      try {
        sessionId = ffmpeg.ffmpeg_kit_session_get_session_id(handle);
      } catch (e, st) {
        log(
          'MediaInformationSession.fromUri: error getting session id for ffmpeg_kit_session_get_session_id $finalCommand',
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
      registerFinalizer();
    } catch (e, st) {
      log(
        'MediaInformationSession.fromUri: failed to create session',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } finally {
      calloc.free(cmdPtr);
    }

    _mediaInfoCompleteCallback = completeCallback;
    CallbackManager().registerMediaInformationSession(this);
    _registered = true;
  }

  // ---------------------------------------------------------------------------
  // Static factories
  // ---------------------------------------------------------------------------

  /// Creates a [MediaInformationSession] from a file path or URI string.
  static MediaInformationSession fromPath(
    String path, {
    MediaInformationSessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) {
    if (_hasUriScheme(path)) {
      return MediaInformationSession.fromUri(
        Uri.parse(path),
        completeCallback: completeCallback,
        timeout: timeout,
      );
    }
    return MediaInformationSession.fromFile(
      File(path),
      completeCallback: completeCallback,
      timeout: timeout,
    );
  }

  /// Returns `true` when [path] appears to contain an explicit URI scheme
  /// (e.g. `http://`, `rtmp://`, `file://`).
  static bool _hasUriScheme(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null) return false;
    return uri.hasScheme &&
        const {
          'http',
          'https',
          'rtmp',
          'rtsp',
          'ftp',
          'file',
        }.contains(uri.scheme.toLowerCase());
  }

  /// Equivalent to [MediaInformationSession.new].
  static MediaInformationSession create(
    String command, {
    MediaInformationSessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) => MediaInformationSession(
    command,
    timeout: timeout,
    completeCallback: completeCallback,
  );

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  /// Enqueues this session for synchronous native execution and returns `this`
  /// immediately (fire-and-forget).
  @override
  MediaInformationSession execute() {
    SessionQueueManager()
        .executeSession(this, () async {
          try {
            ffmpeg.media_information_session_execute(handle, _timeout);
          } catch (e, st) {
            log(
              'MediaInformationSession.execute: error executing media_information_session_execute $command',
              error: e,
              stackTrace: st,
            );
            rethrow;
          }
          try {
            _mediaInfoCompleteCallback?.call(this);
          } catch (e, st) {
            log(
              'MediaInformationSession.execute: error in completeCallback',
              error: e,
              stackTrace: st,
            );
            rethrow;
          } finally {
            _unregister();
          }
        })
        .catchError((Object e, StackTrace st) {
          log(
            'MediaInformationSession.execute: queue error',
            error: e,
            stackTrace: st,
          );
        });
    return this;
  }

  /// Creates and enqueues a session for synchronous execution.
  static MediaInformationSession executeCommand(
    String command, {
    MediaInformationSessionCompleteCallback? completeCallback,
    int timeout = 500,
  }) => MediaInformationSession.create(
    command,
    timeout: timeout,
    completeCallback: completeCallback,
  ).execute();

  /// Executes this session asynchronously and returns a [Future] that
  /// resolves when information retrieval finishes.
  @override
  Future<MediaInformationSession> executeAsync({
    FFprobeSessionCompleteCallback? completeCallback,
  }) async {
    // Accept the base-class typed callback for call-site compatibility;
    // wrap it into the correct MediaInformation type.
    if (completeCallback != null) {
      _mediaInfoCompleteCallback = (s) => completeCallback(s);
    }
    _ensureRegistered();

    await SessionQueueManager().executeSession(this, _runAsyncMediaInfo);
    return this;
  }

  // ---------------------------------------------------------------------------
  // Media information extraction
  // ---------------------------------------------------------------------------

  /// Retrieves the [MediaInformation] parsed from the ffprobe output.
  ///
  /// Returns `null` if the session has not completed or the output could not
  /// be parsed.
  @override
  MediaInformation? getMediaInformation() {
    FFmpegKitExtended.requireInitialized();
    final mediaInfoHandle = ffmpeg
        .media_information_session_get_media_information(handle);
    if (mediaInfoHandle == nullptr) return null;

    try {
      // ---------- chapters ----------
      final chaptersCount = ffmpeg.media_information_get_chapters_count(
        mediaInfoHandle,
      );
      final chapters = <ChapterInformation>[];
      for (int i = 0; i < chaptersCount; i++) {
        final chapterHandle = ffmpeg.media_information_get_chapter_at(
          mediaInfoHandle,
          i,
        );
        if (chapterHandle == nullptr) continue;
        try {
          chapters.add(
            ChapterInformation(
              id: ffmpeg.chapter_get_id(chapterHandle),
              timeBase: _str(ffmpeg.chapter_get_time_base(chapterHandle)),
              start: ffmpeg.chapter_get_start(chapterHandle),
              startTime: _str(ffmpeg.chapter_get_start_time(chapterHandle)),
              end: ffmpeg.chapter_get_end(chapterHandle),
              endTime: _str(ffmpeg.chapter_get_end_time(chapterHandle)),
              tagsJson: _str(ffmpeg.chapter_get_tags_json(chapterHandle)),
              allPropertiesJson: _str(
                ffmpeg.chapter_get_all_properties_json(chapterHandle),
              ),
            ),
          );
        } catch (e, st) {
          log(
            'MediaInformationSession: error reading chapter $i',
            error: e,
            stackTrace: st,
          );
        } finally {
          ffmpeg.ffmpeg_kit_handle_release(chapterHandle);
        }
      }

      // ---------- streams ----------
      final streamsCount = ffmpeg.media_information_get_streams_count(
        mediaInfoHandle,
      );
      final streams = <StreamInformation>[];
      for (int i = 0; i < streamsCount; i++) {
        final streamHandle = ffmpeg.media_information_get_stream_at(
          mediaInfoHandle,
          i,
        );
        if (streamHandle == nullptr) continue;
        try {
          streams.add(
            StreamInformation(
              index: ffmpeg.stream_information_get_index(streamHandle),
              type: _str(ffmpeg.stream_information_get_type(streamHandle)),
              codec: _str(ffmpeg.stream_information_get_codec(streamHandle)),
              codecLong: _str(
                ffmpeg.stream_information_get_codec_long(streamHandle),
              ),
              format: _str(ffmpeg.stream_information_get_format(streamHandle)),
              width: ffmpeg.stream_information_get_width(streamHandle),
              height: ffmpeg.stream_information_get_height(streamHandle),
              bitrate: _str(
                ffmpeg.stream_information_get_bitrate(streamHandle),
              ),
              sampleRate: _str(
                ffmpeg.stream_information_get_sample_rate(streamHandle),
              ),
              sampleFormat: _str(
                ffmpeg.stream_information_get_sample_format(streamHandle),
              ),
              channelLayout: _str(
                ffmpeg.stream_information_get_channel_layout(streamHandle),
              ),
              sampleAspectRatio: _str(
                ffmpeg.stream_information_get_sample_aspect_ratio(streamHandle),
              ),
              displayAspectRatio: _str(
                ffmpeg.stream_information_get_display_aspect_ratio(
                  streamHandle,
                ),
              ),
              averageFrameRate: _str(
                ffmpeg.stream_information_get_average_frame_rate(streamHandle),
              ),
              realFrameRate: _str(
                ffmpeg.stream_information_get_real_frame_rate(streamHandle),
              ),
              timeBase: _str(
                ffmpeg.stream_information_get_time_base(streamHandle),
              ),
              codecTimeBase: _str(
                ffmpeg.stream_information_get_codec_time_base(streamHandle),
              ),
              tagsJson: _str(
                ffmpeg.stream_information_get_tags_json(streamHandle),
              ),
              allPropertiesJson: _str(
                ffmpeg.stream_information_get_all_properties_json(streamHandle),
              ),
            ),
          );
        } catch (e, st) {
          log(
            'MediaInformationSession: error reading stream $i',
            error: e,
            stackTrace: st,
          );
        } finally {
          ffmpeg.ffmpeg_kit_handle_release(streamHandle);
        }
      }

      return MediaInformation(
        filename: _str(ffmpeg.media_information_get_filename(mediaInfoHandle)),
        format: _str(ffmpeg.media_information_get_format(mediaInfoHandle)),
        longFormat: _str(
          ffmpeg.media_information_get_long_format(mediaInfoHandle),
        ),
        duration: _str(ffmpeg.media_information_get_duration(mediaInfoHandle)),
        startTime: _str(
          ffmpeg.media_information_get_start_time(mediaInfoHandle),
        ),
        bitrate: _str(ffmpeg.media_information_get_bitrate(mediaInfoHandle)),
        size: _str(ffmpeg.media_information_get_size(mediaInfoHandle)),
        tagsJson: _str(ffmpeg.media_information_get_tags_json(mediaInfoHandle)),
        allPropertiesJson: _str(
          ffmpeg.media_information_get_all_properties_json(mediaInfoHandle),
        ),
        streams: streams,
        chapters: chapters,
      );
    } catch (e, st) {
      log(
        'MediaInformationSession.getMediaInformation',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } finally {
      ffmpeg.ffmpeg_kit_handle_release(mediaInfoHandle);
    }
  }

  // ---------------------------------------------------------------------------
  // Session type identity
  // ---------------------------------------------------------------------------

  /// Returns true if this is an FFmpeg session.
  @override
  bool isFFmpegSession() => false;

  /// Returns true if this is an FFplay session.
  @override
  bool isFFplaySession() => false;

  /// Returns true if this is an FFprobe session.
  @override
  bool isFFprobeSession() => false;

  /// Returns true if this is a media information session.
  @override
  bool isMediaInformationSession() => true;

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Executes this session asynchronously and invokes the complete callback when done.
  Future<void> _runAsyncMediaInfo() async {
    FFmpegKitExtended.requireInitialized();
    final sessionCompleter = Completer<void>();
    final userCb = _mediaInfoCompleteCallback;

    _mediaInfoCompleteCallback = (MediaInformationSession s) {
      // Restore and unregister before calling user code or completing the
      // future, so the session is fully settled from any observer's perspective.
      _mediaInfoCompleteCallback = userCb;
      _unregister();

      try {
        userCb?.call(s);
      } catch (e, st) {
        log(
          'MediaInformationSession: error in completeCallback for session '
          '$sessionId',
          error: e,
          stackTrace: st,
        );
      }

      // Complete last — everything is torn down, so any awaiter gets a fully
      // settled session.
      if (!sessionCompleter.isCompleted) sessionCompleter.complete();
    };

    // Register the global native callback for media information completion.
    try {
      ffmpeg
          .ffmpeg_kit_config_enable_media_information_session_complete_callback(
            nativeMediaInfoComplete.nativeFunction,
            nullptr,
          );
    } catch (e, st) {
      log(
        'MediaInformationSession: error registering global callback for session ffmpeg_kit_config_enable_media_information_session_complete_callback '
        '$sessionId',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    try {
      ffmpeg.media_information_session_execute_async(handle, _timeout);
    } catch (e, st) {
      log(
        'MediaInformationSession: error starting async session for media_information_session_execute_async '
        '$sessionId',
        error: e,
        stackTrace: st,
      );
      _unregister();
      if (!sessionCompleter.isCompleted) sessionCompleter.complete();
      rethrow;
    }

    try {
      await sessionCompleter.future;
    } catch (e, st) {
      log(
        'MediaInformationSession: error awaiting session '
        '$sessionId',
        error: e,
        stackTrace: st,
      );
    }
    // No post-await restore needed — already done inside the callback above.
  }

  /// Ensures this session is registered with the callback manager.
  void _ensureRegistered() {
    if (_registered) return;
    CallbackManager().registerMediaInformationSession(this);
    _registered = true;
  }

  /// Unregisters this session from the callback manager.
  void _unregister() {
    if (!_registered) return;
    _registered = false;
    CallbackManager().unregisterMediaInformationSession(sessionId);
  }

  /// Reads a heap-allocated C string into a Dart [String] and frees it.
  /// Returns `null` for a null pointer.
  static String? _str(Pointer<Char> ptr) {
    FFmpegKitExtended.requireInitialized();
    if (ptr == nullptr) return null;
    final result = ptr.cast<Utf8>().toDartString();
    ffmpeg.ffmpeg_kit_free(ptr.cast());
    return result;
  }
}
