/// Platform-appropriate FFplay rendering surface.
///
/// The session and control API is shared. Only the surface implementation is
/// selected per target because native Flutter textures and WebAssembly frame
/// copies use different rendering paths.
library;

export 'platform/native/ffplay_surface_native.dart'
    if (dart.library.js_interop) 'web/ffplay_surface_web.dart';
