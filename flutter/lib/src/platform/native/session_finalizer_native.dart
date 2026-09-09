import 'dart:ffi';

import 'ffmpeg_kit_extended_flutter_loader.dart';
import '../session_finalizer.dart';

SessionFinalizer createSessionFinalizer() => NativeSessionFinalizer();

final class NativeSessionFinalizer implements SessionFinalizer {
  NativeFinalizer? _finalizer;
  final Expando<_FinalizableHolder> _holders = Expando<_FinalizableHolder>();

  NativeFinalizer get _nativeFinalizer {
    if (_finalizer != null) return _finalizer!;
    final releasePointer = ffmpegKitHandleReleasePtr;
    _finalizer = NativeFinalizer(releasePointer ?? Pointer.fromAddress(0));
    return _finalizer!;
  }

  @override
  void attach(Object owner, Object handle, {required Object detachToken}) {
    final holder = _FinalizableHolder();
    _holders[owner] = holder;
    _nativeFinalizer.attach(
      holder,
      handle as Pointer<Void>,
      detach: detachToken,
    );
  }

  @override
  void detach(Object detachToken) {
    _nativeFinalizer.detach(detachToken);
  }
}

final class _FinalizableHolder implements Finalizable {}
