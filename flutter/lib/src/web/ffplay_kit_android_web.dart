/// Web compatibility surface for the native Android FFplay helper.
library;

/// Android FFplay surface binding is unavailable on Web.
class FFplayKitAndroid {
  static void setAndroidSurface(int nativeWindowPtr) {}

  static void clearAndroidSurface() {}

  static void clearAndroidSurfaceIfMatches(int nativeWindowPtr) {}

  static void releaseNativeWindowPtr(int nativeWindowPtr) {
    throw UnsupportedError('Android FFplay surfaces are unavailable on Web.');
  }
}
