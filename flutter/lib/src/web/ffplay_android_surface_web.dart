/// Web compatibility surface for the native Android FFplay texture.
library;

import 'package:flutter/widgets.dart';

/// Android textures are unavailable on Web.
class FFplayAndroidSurface {
  final int textureId;
  final int nativeWindowPtr;

  FFplayAndroidSurface._({
    required this.textureId,
    required this.nativeWindowPtr,
  });

  static Future<FFplayAndroidSurface?> create({
    int width = 1,
    int height = 1,
  }) async => null;

  Widget toWidget() => const SizedBox.shrink();

  void bindToFFplay() {}

  Future<void> release() async {}
}
