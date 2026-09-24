package com.akashskypatel.ffmpeg_kit_extended_flutter

import android.view.Surface
import com.akashskypatel.ffmpegkit.FFplayKitAndroid
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

class FfmpegKitExtendedFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private data class SurfaceState(
        val entry: TextureRegistry.SurfaceTextureEntry,
        val surface: Surface,
        val nativeWindowPtr: Long,
    )

    companion object {
        private val processOwner = SurfaceOwnerCoordinator<SurfaceState> { state ->
            FFplayKitAndroid.setAndroidSurface(state?.surface)
        }
    }

    private var channel: MethodChannel? = null
    private var textureRegistry: TextureRegistry? = null

    /** Live surfaces keyed by Flutter texture ID. */
    private val surfaces = mutableMapOf<Long, SurfaceState>()

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
        val detachedSurfaces = surfaces.values.toList()
        surfaces.clear()
        detachedSurfaces.forEach(::releaseSurfaceState)
        textureRegistry = null
    }

    // -------------------------------------------------------------------------
    // MethodCallHandler
    // -------------------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createSurface" -> createSurface(call, result)
            "bindSurface" -> bindSurface(call, result)
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

        surfaces[textureId] = SurfaceState(entry, surface, nativeWindowPtr)
        result.success(
            mapOf("textureId" to textureId, "nativeWindowPtr" to nativeWindowPtr)
        )
    }

    private fun bindSurface(call: MethodCall, result: MethodChannel.Result) {
        val textureId =
            (call.argument<Any>("textureId") as? Number)?.toLong() ?: run {
                result.error("INVALID_ARG", "textureId required", null)
                return
            }
        val state = surfaces[textureId] ?: run {
            result.error("NOT_FOUND", "Surface texture was already released", null)
            return
        }

        try {
            processOwner.install(state)
            result.success(null)
        } catch (error: Throwable) {
            result.error(
                "BIND_ERROR",
                error.message ?: "Could not bind FFplay surface",
                null,
            )
        }
    }

    private fun releaseSurface(call: MethodCall, result: MethodChannel.Result) {
        val textureId =
            (call.argument<Any>("textureId") as? Number)?.toLong() ?: run {
                result.error("INVALID_ARG", "textureId required", null)
                return
            }

        surfaces.remove(textureId)?.let(::releaseSurfaceState)
        result.success(null)
    }

    private fun releaseSurfaceState(state: SurfaceState) {
        processOwner.uninstallIfOwned(state)
        if (state.nativeWindowPtr != 0L) {
            FFplayKitAndroid.releaseNativeWindowPtr(state.nativeWindowPtr)
        }
        state.surface.release()
        state.entry.release()
    }
}
