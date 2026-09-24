package com.akashskypatel.ffmpeg_kit_extended_flutter

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

internal class SurfaceOwnerCoordinatorTest {
    @Test
    fun staleReleaseCannotClearTheLatestOwner() {
        val targets = mutableListOf<String?>()
        val coordinator = SurfaceOwnerCoordinator<Any> { owner ->
            targets += owner?.toString()
        }
        val first = Any()
        val second = Any()

        assertTrue(coordinator.install(first))
        assertTrue(coordinator.install(second))
        assertFalse(coordinator.uninstallIfOwned(first))
        assertTrue(coordinator.isOwner(second))
        assertTrue(coordinator.uninstallIfOwned(second))
        assertFalse(coordinator.isOwner(second))
        assertEquals(3, targets.size)
        assertEquals(null, targets.last())
    }

    @Test
    fun repeatedReplacementAndReleaseLeavesNoStaleOwner() {
        val coordinator = SurfaceOwnerCoordinator<Any> { }
        repeat(10_000) {
            val owner = Any()
            assertTrue(coordinator.install(owner))
            assertFalse(coordinator.uninstallIfOwned(Any()))
            assertTrue(coordinator.uninstallIfOwned(owner))
        }
    }
}
