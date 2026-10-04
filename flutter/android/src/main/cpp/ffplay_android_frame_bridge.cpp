// Android frame bridge for the Flutter FFplay surface.
//
// The frozen FFmpegKit ABI composes an RGBA frame and invokes its frame
// callback on the FFplay worker thread. This wrapper-owned bridge consumes
// that callback and presents the pixels to Flutter's SurfaceTexture through
// ANativeWindow. It intentionally does not call back into the ABI from the
// frame callback because the ABI holds its FFplay API mutex while delivering
// the frame.

#include <android/log.h>
#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <dlfcn.h>
#include <jni.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <mutex>

namespace {

constexpr char kLogTag[] = "FFmpegKitFlutterSurface";

using FrameCallback = void (*)(void*, const uint8_t*, int, int, int,
                               const char*);
using RegisterCallback = void (*)(FrameCallback, void*);
using UnregisterCallback = void (*)();

struct BridgeState {
  std::mutex mutex;
  ANativeWindow* window = nullptr;
  RegisterCallback register_callback = nullptr;
  UnregisterCallback unregister_callback = nullptr;
  bool callback_installed = false;
};

BridgeState g_state;
std::mutex g_operation_mutex;

template <typename Function>
Function ResolveSymbol(const char* name) {
  auto resolved = reinterpret_cast<Function>(dlsym(RTLD_DEFAULT, name));
  if (resolved) return resolved;

  // System.loadLibrary may keep the ABI library local to its loader. Probe
  // the already-loaded module explicitly without loading a second copy.
  static constexpr const char* kAbiNames[] = {"libffmpegkit.so", "ffmpegkit.so"};
  for (const char* abi_name : kAbiNames) {
    void* handle = dlopen(abi_name, RTLD_NOW | RTLD_NOLOAD);
    if (!handle) continue;
    resolved = reinterpret_cast<Function>(dlsym(handle, name));
    dlclose(handle);
    if (resolved) return resolved;
  }
  return nullptr;
}

bool ResolveFrameApiLocked() {
  std::lock_guard<std::mutex> lock(g_state.mutex);
  if (g_state.register_callback && g_state.unregister_callback) return true;

  g_state.register_callback =
      ResolveSymbol<RegisterCallback>("ffplay_kit_register_frame_callback");
  g_state.unregister_callback =
      ResolveSymbol<UnregisterCallback>("ffplay_kit_unregister_frame_callback");
  if (!g_state.register_callback || !g_state.unregister_callback) {
    g_state.register_callback = nullptr;
    g_state.unregister_callback = nullptr;
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "FFplay frame callback symbols are unavailable");
    return false;
  }
  return true;
}

void CopyFrameToWindow(void* userdata, const uint8_t* pixels, int width,
                       int height, int linesize, const char* format) {
  auto* state = static_cast<BridgeState*>(userdata);
  if (!state || !pixels || width <= 0 || height <= 0 || linesize <= 0) return;

  ANativeWindow* window = nullptr;
  {
    std::lock_guard<std::mutex> lock(state->mutex);
    if (!state->window) return;
    window = state->window;
    ANativeWindow_acquire(window);
  }

  if (ANativeWindow_setBuffersGeometry(window, width, height,
                                       WINDOW_FORMAT_RGBA_8888) != 0) {
    ANativeWindow_release(window);
    return;
  }

  ANativeWindow_Buffer buffer{};
  if (ANativeWindow_lock(window, &buffer, nullptr) != 0 || !buffer.bits) {
    ANativeWindow_release(window);
    return;
  }

  const int copy_width = std::min(width, static_cast<int>(buffer.stride));
  const int copy_height = std::min(height, static_cast<int>(buffer.height));
  const bool source_is_bgra = format && std::strcmp(format, "bgra") == 0;
  for (int row = 0; row < copy_height; ++row) {
    const auto* source = pixels + static_cast<size_t>(row) * linesize;
    auto* destination = static_cast<uint8_t*>(buffer.bits) +
                        static_cast<size_t>(row) * buffer.stride * 4;
    if (!source_is_bgra) {
      std::memcpy(destination, source, static_cast<size_t>(copy_width) * 4);
      continue;
    }
    for (int column = 0; column < copy_width; ++column) {
      const auto* source_pixel = source + column * 4;
      auto* destination_pixel = destination + column * 4;
      destination_pixel[0] = source_pixel[2];
      destination_pixel[1] = source_pixel[1];
      destination_pixel[2] = source_pixel[0];
      destination_pixel[3] = source_pixel[3];
    }
  }

  ANativeWindow_unlockAndPost(window);
  ANativeWindow_release(window);
}

void ClearSurfaceLocked() {
  UnregisterCallback unregister_callback = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_state.mutex);
    unregister_callback = g_state.unregister_callback;
  }

  // The frozen ABI waits for an in-flight callback before unregistering it.
  if (unregister_callback) {
    bool installed = false;
    {
      std::lock_guard<std::mutex> lock(g_state.mutex);
      installed = g_state.callback_installed;
      g_state.callback_installed = false;
    }
    if (installed) unregister_callback();
  }

  ANativeWindow* old_window = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_state.mutex);
    old_window = g_state.window;
    g_state.window = nullptr;
  }
  if (old_window) ANativeWindow_release(old_window);
}

bool BindSurface(JNIEnv* env, jobject surface) {
  std::lock_guard<std::mutex> operation_lock(g_operation_mutex);
  ClearSurfaceLocked();
  if (!surface || !ResolveFrameApiLocked()) return false;

  ANativeWindow* window = ANativeWindow_fromSurface(env, surface);
  if (!window) return false;

  {
    std::lock_guard<std::mutex> lock(g_state.mutex);
    g_state.window = window;
  }

  RegisterCallback register_callback = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_state.mutex);
    register_callback = g_state.register_callback;
  }
  register_callback(CopyFrameToWindow, &g_state);
  {
    std::lock_guard<std::mutex> lock(g_state.mutex);
    g_state.callback_installed = true;
  }
  return true;
}

void ClearSurface() {
  std::lock_guard<std::mutex> operation_lock(g_operation_mutex);
  ClearSurfaceLocked();
}

}  // namespace

extern "C" JNIEXPORT jboolean JNICALL
Java_com_akashskypatel_ffmpeg_1kit_1extended_1flutter_FFplayFrameBridge_bindSurface(
    JNIEnv* env, jclass /*clazz*/, jobject surface) {
  return BindSurface(env, surface) ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT void JNICALL
Java_com_akashskypatel_ffmpeg_1kit_1extended_1flutter_FFplayFrameBridge_clearSurface(
    JNIEnv* /*env*/, jclass /*clazz*/) {
  ClearSurface();
}
