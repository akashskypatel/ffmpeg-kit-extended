import '../session_finalizer.dart';

SessionFinalizer createSessionFinalizer() => const WebSessionFinalizer();

final class WebSessionFinalizer implements SessionFinalizer {
  const WebSessionFinalizer();

  @override
  void attach(Object owner, Object handle, {required Object detachToken}) {}

  @override
  void detach(Object detachToken) {}
}
