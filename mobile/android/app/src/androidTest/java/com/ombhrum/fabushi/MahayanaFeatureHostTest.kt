package com.ombhrum.fabushi

import androidx.test.platform.app.InstrumentationRegistry
import com.ombhrum.fabushi.core.MahayanaHost
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class MahayanaFeatureHostTest {
    @Test
    fun nativeBridgeExecutesReadOnlyFeatureHostJourneys() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        MahayanaHost(context).use { host ->
            val info = host.request("feature.info")
            assertEquals("android", info.getString("platform"))
            assertFalse(info.getString("protocolVersion").isBlank())

            host.request("feature.auth.status")
            host.request("feature.auth.providers")

            val commands = listOf("automation.list", "group.list", "teach.status")
            commands.forEachIndexed { index, type ->
                val requestId = "android-native-$index"
                val accepted = host.request(
                    "feature.execute",
                    JSONObject().put(
                        "command",
                        JSONObject()
                            .put("type", type)
                            .put("requestId", requestId),
                    ),
                )
                assertEquals(requestId, accepted.getString("requestId"))
            }
        }
    }
}
