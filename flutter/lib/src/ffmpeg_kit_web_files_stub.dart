import 'dart:typed_data';

/// Web/Wasm access to temporary files in FFmpegKit's Emscripten filesystem.
///
/// These operations are available only on Flutter Web. Native calls throw
/// [UnsupportedError].
abstract final class FFmpegKitWebFiles {
  /// Copies [bytes] into [filePath], which must be a flat file under `/tmp/`.
  static void writeFile(String filePath, Uint8List bytes) => _unsupported();

  /// Returns an independent byte copy of [filePath] under `/tmp/`.
  static Uint8List readFile(String filePath) => _unsupported();

  /// Deletes [filePath] under `/tmp/`.
  static void deleteFile(String filePath) => _unsupported();

  /// Returns whether a regular file exists at [filePath] under `/tmp/`.
  static bool exists(String filePath) => _unsupported();

  static Never _unsupported() => throw UnsupportedError(
    'FFmpegKitWebFiles is available only on Flutter Web with an initialized Wasm runtime.',
  );
}
