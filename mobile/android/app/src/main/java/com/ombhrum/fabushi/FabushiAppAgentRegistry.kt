package com.ombhrum.fabushi

/**
 * Process-wide semantic surface shared by Compose and the signed device agent.
 * The surface is cleared whenever no Fabushi activity is foreground, so a
 * background service never pretends that stale UI callbacks remain operable.
 */
object FabushiAppAgentRegistry {
    val surface = FabushiAppAgentSurface()

    fun setApplicationForeground(foreground: Boolean) {
        if (!foreground) surface.clear()
    }
}
