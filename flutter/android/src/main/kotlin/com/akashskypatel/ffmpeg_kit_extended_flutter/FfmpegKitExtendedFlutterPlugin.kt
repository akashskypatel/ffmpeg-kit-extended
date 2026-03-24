package com.akashskypatel.ffmpeg_kit_extended_flutter

import android.view.Surface
import com.akashskypatel.ffmpegkit.FFplayKitAndroid
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

class FfmpegKitExtendedFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var textureRegistry: TextureRegistry? = null

    /** Live surfaces keyed by Flutter texture ID.
     *  Triple: (SurfaceTextureEntry, Surface, nativeWindowPtr)
     *  nativeWindowPtr is stored so it can be released in onDetachedFromEngine
     *  even if releaseSurface was never called from the Dart side. */
    private val surfaces =
        mutableMapOf<Long, Triple<TextureRegistry.SurfaceTextureEntry, Surface, Long>>()

    // -------------------------------------------------------------------------
    // FlutterPlugin
    // -------------------------------------------------------------------------

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        textureRegistry = binding.textureRegistry
        channel = MethodChannel(binding.binaryMessenger, "ffplay_kit_android").also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        surfaces.values.forEach { (entry, surface, nativeWindowPtr) ->
            if (nativeWindowPtr != 0L) FFplayKitAndroid.releaseNativeWindowPtr(nativeWindowPtr)
            surface.release()
            entry.release()
        }
        surfaces.clear()
        textureRegistry = null
    }

    // -------------------------------------------------------------------------
    // MethodCallHandler
    // -------------------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createSurface" -> createSurface(call, result)
            "releaseSurface" -> releaseSurface(call, result)
            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------------------
    // Handlers
    // -------------------------------------------------------------------------

    private fun createSurface(call: MethodCall, result: MethodChannel.Result) {
        val registry = textureRegistry ?: run {
            result.error("NOT_INITIALIZED", "Plugin not attached to engine", null)
            return
        }

        // Optional hint for the initial SurfaceTexture buffer size.
        // ANativeWindow_setBuffersGeometry in ffplay_step() will resize it to
        // the actual video dimensions before the first blit.
        val width = (call.argument<Any>("width") as? Number)?.toInt() ?: 1
        val height = (call.argument<Any>("height") as? Number)?.toInt() ?: 1

        val entry = registry.createSurfaceTexture()
        entry.surfaceTexture().setDefaultBufferSize(width, height)
        val surface = Surface(entry.surfaceTexture())
        val textureId = entry.id()
        val nativeWindowPtr = FFplayKitAndroid.getNativeWindowPtr(surface)

        if (nativeWindowPtr == 0L) {
            surface.release()
            entry.release()
            result.error("SURFACE_ERROR", "ANativeWindow_fromSurface returned null", null)
            return
        }

        surfaces[textureId] = Triple(entry, surface, nativeWindowPtr)
        result.success(
            mapOf("textureId" to textureId, "nativeWindowPtr" to nativeWindowPtr)
        )
    }

    private fun releaseSurface(call: MethodCall, result: MethodChannel.Result) {
        val textureId =
            (call.argument<Any>("textureId") as? Number)?.toLong() ?: run {
                result.error("INVALID_ARG", "textureId required", null)
                return
            }
        val nativeWindowPtr =
            (call.argument<Any>("nativeWindowPtr") as? Number)?.toLong() ?: 0L

        if (nativeWindowPtr != 0L) {
            FFplayKitAndroid.releaseNativeWindowPtr(nativeWindowPtr)
        }
        surfaces.remove(textureId)?.let { (entry, surface, _) ->
            surface.release()
            entry.release()
        }
        result.success(null)
    }
}
