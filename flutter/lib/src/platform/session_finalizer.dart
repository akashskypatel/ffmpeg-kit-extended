import 'native/session_finalizer_native.dart'
    if (dart.library.js_interop) 'web/session_finalizer_web.dart';

/// Platform-specific lifetime hook used by the shared session class.
abstract interface class SessionFinalizer {
  void attach(Object owner, Object handle, {required Object detachToken});

  void detach(Object detachToken);
}

final SessionFinalizer sessionFinalizer = createSessionFinalizer();
