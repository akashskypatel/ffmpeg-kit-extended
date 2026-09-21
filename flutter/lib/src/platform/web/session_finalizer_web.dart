import '../backend.dart';
import '../backend_selector.dart';
import '../session_finalizer.dart';

SessionFinalizer createSessionFinalizer() => const WebSessionFinalizer();

final class WebSessionFinalizer implements SessionFinalizer {
  const WebSessionFinalizer();

  static final Finalizer<_WebFinalizerToken> _finalizer = Finalizer((
    _WebFinalizerToken token,
  ) {
    try {
      ffmpegKitBackend.releaseSession(SessionHandle(token.handle));
    } catch (_) {
      // Finalizers cannot surface errors to the owning isolate. Explicit
      // dispose remains the deterministic path; this is only the leak
      // safety net for an otherwise unreachable Web session wrapper.
    }
  });

  @override
  void attach(Object owner, Object handle, {required Object detachToken}) {
    _finalizer.attach(owner, _WebFinalizerToken(handle), detach: detachToken);
  }

  @override
  void detach(Object detachToken) {
    _finalizer.detach(detachToken);
  }
}

final class _WebFinalizerToken {
  final Object handle;

  const _WebFinalizerToken(this.handle);
}
