import 'dart:ffi';

import '../session_finalizer.dart';
import 'ffmpeg_kit_extended_flutter_loader.dart';

SessionFinalizer createSessionFinalizer() => NativeSessionFinalizer();

final class NativeSessionFinalizer implements SessionFinalizer {
  NativeFinalizer? _finalizer;
  final Expando<_FinalizableHolder> _holders = Expando<_FinalizableHolder>();

  NativeFinalizer get _nativeFinalizer {
    if (_finalizer != null) return _finalizer!;
    final releasePointer = ffmpegKitHandleReleasePtr;
    if (releasePointer == null || releasePointer.address == 0) {
      throw StateError(
        'FFmpegKit native handle-release symbol is unavailable; '
        'cannot attach a session finalizer.',
      );
    }
    _finalizer = NativeFinalizer(releasePointer);
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
