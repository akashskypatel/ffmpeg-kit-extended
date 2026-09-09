/// Web compatibility surface for the native desktop FFplay texture.
library;

import 'package:flutter/widgets.dart';

/// Native desktop textures are unavailable on Web.
class FFplayDesktopTexture {
  final int textureId;

  FFplayDesktopTexture._({required this.textureId});

  static Future<FFplayDesktopTexture?> create() async => null;

  Widget toWidget() => const SizedBox.shrink();

  void bindToFFplay() {}

  Future<void> release() async {}
}
