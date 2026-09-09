import 'backend.dart';
import 'native/backend_native.dart'
    if (dart.library.js_interop) 'web/backend_web.dart';

/// The platform backend selected for the current Dart target.
final FFmpegKitBackend ffmpegKitBackend = createPlatformBackend();
