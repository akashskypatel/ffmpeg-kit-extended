package com.akashskypatel.ffmpeg_kit_extended_flutter

/**
 * Serializes ownership of one process-global Android video target.
 *
 * The owner is compared by object identity. A stale Flutter engine can
 * release its own state without clearing a newer engine's target.
 */
internal class SurfaceOwnerCoordinator<T : Any>(
    private val setNativeTarget: (T?) -> Unit,
) {
    private var owner: T? = null

    @Synchronized
    fun install(candidate: T): Boolean {
        setNativeTarget(candidate)
        owner = candidate
        return true
    }

    @Synchronized
    fun uninstallIfOwned(candidate: T): Boolean {
        if (owner !== candidate) return false
        setNativeTarget(null)
        owner = null
        return true
    }

    @Synchronized
    fun isOwner(candidate: T): Boolean = owner === candidate
}
