import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../ffmpeg_kit_extended_flutter_loader.dart';
import '../../generated/ffmpeg_kit_bindings_native.dart' as bindings;
import '../backend.dart';

FFmpegKitBackend createPlatformBackend() => NativeFFmpegKitBackend();

final class NativeFFmpegKitBackend implements FFmpegKitBackend {
  @override
  Future<void> initialize() => initializeFFmpegKit();

  @override
  bool get initialized => isFFmpegKitInitialized;

  @override
  void requireInitialized() {
    if (!initialized) {
      throw StateError(
        'FFmpegKit is not initialized. Call FFmpegKitExtended.initialize() '
        'before using the backend.',
      );
    }
  }

  Pointer<Void> _pointer(SessionHandle handle) => handle.value as Pointer<Void>;

  String? _stringAndFree(Pointer<Char> pointer) {
    if (pointer.address == 0) return null;
    try {
      return pointer.cast<Utf8>().toDartString();
    } finally {
      bindings.ffmpeg_kit_free(pointer.cast());
    }
  }

  @override
  SessionHandle createFFmpegSession(String command) {
    requireInitialized();
    final commandPointer = command.toNativeUtf8(allocator: calloc);
    try {
      return SessionHandle(
        bindings.ffmpeg_kit_create_session(commandPointer.cast()),
      );
    } finally {
      calloc.free(commandPointer);
    }
  }

  @override
  SessionHandle createFFmpegSessionFromArguments(List<String> arguments) {
    requireInitialized();
    final argv = calloc<Pointer<Char>>(arguments.length);
    final strings = <Pointer<Utf8>>[];
    try {
      for (var i = 0; i < arguments.length; i++) {
        final value = arguments[i].toNativeUtf8(allocator: calloc);
        strings.add(value);
        argv[i] = value.cast();
      }
      return SessionHandle(
        bindings.ffmpeg_kit_create_session_from_argv(arguments.length, argv),
      );
    } finally {
      for (final value in strings) {
        calloc.free(value);
      }
      calloc.free(argv);
    }
  }

  @override
  int getSessionState(SessionHandle handle) {
    requireInitialized();
    return bindings.ffmpeg_kit_session_get_state(_pointer(handle)).value;
  }

  @override
  int getReturnCode(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_return_code(_pointer(handle));

  @override
  int getSessionId(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_session_id(_pointer(handle));

  @override
  int getCreateTime(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_create_time(_pointer(handle));

  @override
  int getStartTime(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_start_time(_pointer(handle));

  @override
  int getEndTime(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_end_time(_pointer(handle));

  @override
  int getDuration(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_duration(_pointer(handle));

  @override
  String? getCommand(SessionHandle handle) =>
      _stringAndFree(bindings.ffmpeg_kit_session_get_command(_pointer(handle)));

  @override
  String? getOutput(SessionHandle handle) =>
      _stringAndFree(bindings.ffmpeg_kit_session_get_output(_pointer(handle)));

  @override
  String? getLogsAsString(SessionHandle handle) => _stringAndFree(
    bindings.ffmpeg_kit_session_get_logs_as_string(_pointer(handle)),
  );

  @override
  String? getFailStackTrace(SessionHandle handle) => _stringAndFree(
    bindings.ffmpeg_kit_session_get_fail_stack_trace(_pointer(handle)),
  );

  @override
  int getLogsCount(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_get_logs_count(_pointer(handle));

  @override
  String? getLogAt(SessionHandle handle, int index) => _stringAndFree(
    bindings.ffmpeg_kit_session_get_log_at(_pointer(handle), index),
  );

  @override
  int getLogLevelAt(SessionHandle handle, int index) =>
      bindings.ffmpeg_kit_session_get_log_level_at(_pointer(handle), index);

  @override
  void cancelSession(SessionHandle handle) =>
      bindings.ffmpeg_kit_session_cancel(_pointer(handle));

  @override
  void releaseSession(SessionHandle handle) =>
      bindings.ffmpeg_kit_handle_release(_pointer(handle));
}
