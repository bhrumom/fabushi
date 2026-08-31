package com.ombhrum.fabushi

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class FabushiDeviceDirectPathTest {
    @Test
    fun parsesStunServerReflexiveIpv4Candidate() {
        val transaction = ByteArray(12) { (it + 1).toByte() }
        val mappedPort = 54321
        val xorPort = mappedPort xor 0x2112
        val address = intArrayOf(203, 0, 113, 7)
        val cookie = intArrayOf(0x21, 0x12, 0xA4, 0x42)
        val response = byteArrayOf(
            0x01, 0x01, 0x00, 0x0c, 0x21, 0x12, 0xA4.toByte(), 0x42,
            *transaction,
            0x00, 0x20, 0x00, 0x08, 0x00, 0x01,
            (xorPort ushr 8).toByte(), xorPort.toByte(),
            *((0 until 4).map { (address[it] xor cookie[it]).toByte() }.toByteArray())
        )
        val candidate = FabushiDeviceDirectPath.parseStunMappedAddress(response, transaction)
        assertNotNull(candidate)
        assertEquals("srflx", candidate?.scope)
        assertEquals("203.0.113.7", candidate?.host)
        assertEquals(mappedPort, candidate?.port)
    }
}
