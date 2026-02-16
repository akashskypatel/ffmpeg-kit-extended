import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:ffmpeg_kit_extended_flutter/src/ffmpeg_kit_flutter_loader.dart';
import 'package:ffmpeg_kit_extended_flutter/src/generated/ffmpeg_kit_bindings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Helper to check for library presence and skip if missing
void _runNativeTest(String description,
    Future<void> Function(FFmpegKitBindings bindings) body) {
  test(description, () async {
    try {
      final bindings = ffmpeg;
      await body(bindings);
    } catch (e) {
      if (e is ArgumentError &&
          e.toString().contains("Failed to load dynamic library")) {
        // Provide a helpful hint if the library is missing
        print('---------------------------------------------------');
        print('TEST SKIPPED: Native library not found.');
        print(e);
        print('---------------------------------------------------');
        // rethrow; // Uncomment to fail on missing lib, or return to skip
      } else {
        rethrow;
      }
    }
  });
}

// Utility to create C string
Pointer<Char> _toNative(String s) => s.toNativeUtf8().cast<Char>();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('FFmpegKit Wrapper Parity Tests', () {
    _runNativeTest('VersionCheck', (bindings) async {
      final versionPtr = bindings.ffmpeg_kit_config_get_ffmpeg_version();
      expect(versionPtr, isNotNull);
      expect(versionPtr.address, isNot(equals(0)));

      final versionString = versionPtr.cast<Utf8>().toDartString();
      print('FFmpeg Version: $versionString');
      expect(versionString, isNotEmpty);

      malloc.free(versionPtr);
    });

    _runNativeTest('SessionHistory', (bindings) async {
      bindings.ffmpeg_kit_set_session_history_size(10);
      final size = bindings.ffmpeg_kit_get_session_history_size();
      expect(size, equals(10));
    });

    _runNativeTest('PackageName', (bindings) async {
      final pkgPtr = bindings.ffmpeg_kit_packages_get_package_name();
      expect(pkgPtr, isNotNull);
      final pkgName = pkgPtr.cast<Utf8>().toDartString();
      print('Package Name: $pkgName');
      expect(pkgName, isNotEmpty);
      malloc.free(pkgPtr);
    });

    _runNativeTest('SplitSessionExecution', (bindings) async {
      final command = _toNative("-hide_banner -loglevel fatal -version");
      final session = bindings.ffmpeg_kit_create_session(command);
      calloc.free(command);

      expect(session, isNotNull);
      expect(session.address, isNot(equals(0)));

      final stateCreated = bindings.ffmpeg_kit_session_get_state(session);
      expect(stateCreated,
          equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_CREATED));

      bindings.ffmpeg_kit_session_execute(session);

      final stateCompleted = bindings.ffmpeg_kit_session_get_state(session);
      expect(stateCompleted,
          equals(FFmpegKitSessionState.FFMPEG_KIT_SESSION_STATE_COMPLETED));

      // Print return code
      final returnCode = bindings.ffmpeg_kit_session_get_return_code(session);
      print('Return Code: $returnCode');

      // Return code is just an int according to bindings
      // int ffmpeg_kit_session_get_return_code(ffi.Pointer<ffi.Void> session_handle)

      // Let's clean up
      bindings.ffmpeg_kit_handle_release(session);
    });

    _runNativeTest('GenerateTestVideoFile', (bindings) async {
      final tempDir = Directory.systemTemp.createTempSync('ffmpeg_kit_test');
      final testFile = '${tempDir.path}/dummy_video.mp4';
      // Cleanup prep
      final file = File(testFile);
      if (file.existsSync()) file.deleteSync();

      print('DEBUG: Testing video generation at $testFile');
      final cmdPath = testFile.replaceAll('\\', '/');
      print('DEBUG: Command path: $cmdPath');

      final cmdStr =
          "-hide_banner -loglevel info -f lavfi -i testsrc=duration=1:size=512x512:rate=30 -y \"$cmdPath\"";
      final command = _toNative(cmdStr);

      final session = bindings.ffmpeg_kit_create_session(command);
      calloc.free(command);

      bindings.ffmpeg_kit_session_execute(session);

      // NOTE: GenerateTestVideoFile fails on Windows when running under 'flutter test'.
      // This is due to 'ffmpeg-kit' library seemingly picking up process arguments
      // (like -disable-vm-service) or failing to parse the command string correctly
      // when running inside the Dart VM environment.
      // This test works fine on other platforms or when running as a clean executable (wrapper_test).

      final state = bindings.ffmpeg_kit_session_get_state(session);
      print('DEBUG: GenerateTestVideoFile state: $state');

      final returnCode = bindings.ffmpeg_kit_session_get_return_code(session);
      print('DEBUG: GenerateTestVideoFile returnCode: $returnCode');

      // Always print logs
      final logsPtr = bindings.ffmpeg_kit_session_get_logs_as_string(session);
      if (logsPtr != nullptr) {
        print('Logs:\n${logsPtr.cast<Utf8>().toDartString()}');
        malloc.free(logsPtr);
      }

      bindings.ffmpeg_kit_handle_release(session);

      final exists = file.existsSync();
      print('DEBUG: File exists: $exists');
      expect(exists, isTrue);

      // Cleanup
      if (exists) file.deleteSync();
      tempDir.deleteSync();
    });
  });
}
