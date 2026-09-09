import '../../generated/ffmpeg_kit_bindings_web.dart' as bindings;

/// Owns Web-generated callback values passed to the C ABI.
///
/// The current Web runtime completes sessions through its shared polling
/// path, so these are null callback pointers. Keeping their construction here
/// prevents generated binding details from leaking into the shared callback
/// router and leaves one seam for generated Web callbacks to be wired later.
final class WebCallbackBridge {
  bindings.DartFFmpegKitCompleteCallback get nullFFmpegComplete =>
      const bindings.Pointer<
        bindings.NativeFunction<bindings.FFmpegKitCompleteCallbackFunction>
      >.fromAddress(0);

  bindings.DartFFprobeKitCompleteCallback get nullFFprobeComplete =>
      const bindings.Pointer<
        bindings.NativeFunction<bindings.FFprobeKitCompleteCallbackFunction>
      >.fromAddress(0);

  bindings.Pointer<bindings.Void> get nullPointer =>
      const bindings.Pointer<bindings.Void>.fromAddress(0);
}

final webCallbackBridge = WebCallbackBridge();
