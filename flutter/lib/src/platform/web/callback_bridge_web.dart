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

  bindings.DartFFmpegKitLogCallback get nullLog =>
      const bindings.Pointer<
        bindings.NativeFunction<bindings.FFmpegKitLogCallbackFunction>
      >.fromAddress(0);

  bindings.DartFFmpegKitStatisticsCallback get nullStatistics =>
      const bindings.Pointer<
        bindings.NativeFunction<bindings.FFmpegKitStatisticsCallbackFunction>
      >.fromAddress(0);

  bindings.DartFFplayKitCompleteCallback get nullFFplayComplete =>
      const bindings.Pointer<
        bindings.NativeFunction<bindings.FFplayKitCompleteCallbackFunction>
      >.fromAddress(0);

  bindings.DartMediaInformationSessionCompleteCallback
  get nullMediaInformationComplete =>
      const bindings.Pointer<
        bindings.NativeFunction<
          bindings.MediaInformationSessionCompleteCallbackFunction
        >
      >.fromAddress(0);

  bindings.Pointer<bindings.Void> get nullPointer =>
      const bindings.Pointer<bindings.Void>.fromAddress(0);
}

final webCallbackBridge = WebCallbackBridge();
