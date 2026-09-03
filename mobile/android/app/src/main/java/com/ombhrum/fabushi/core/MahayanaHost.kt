package com.ombhrum.fabushi.core

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.io.Closeable
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.spec.GCMParameterSpec


private object MobileAuthStoragePassphrase {
    private const val KEY_ALIAS = "fabushi-mahayana-storage-v1"
    private const val PREFS = "fabushi.mahayana.secure-storage"
    private const val CIPHERTEXT = "wrapped-passphrase"
    private const val IV = "wrapped-passphrase-iv"

    fun loadOrCreate(context: Context): String {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (!keyStore.containsAlias(KEY_ALIAS)) {
            val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            generator.init(
                KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build(),
            )
            generator.generateKey()
        }
        val key = checkNotNull(keyStore.getKey(KEY_ALIAS, null)) { "Android Keystore key is unavailable" }
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ciphertext = preferences.getString(CIPHERTEXT, null)
        val iv = preferences.getString(IV, null)
        val secret = if (ciphertext != null && iv != null) {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(
                Cipher.DECRYPT_MODE,
                key,
                GCMParameterSpec(128, Base64.decode(iv, Base64.NO_WRAP)),
            )
            cipher.doFinal(Base64.decode(ciphertext, Base64.NO_WRAP))
        } else {
            ByteArray(32).also { SecureRandom().nextBytes(it) }.also { generated ->
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(Cipher.ENCRYPT_MODE, key)
                val encrypted = cipher.doFinal(generated)
                check(
                    preferences.edit()
                        .putString(CIPHERTEXT, Base64.encodeToString(encrypted, Base64.NO_WRAP))
                        .putString(IV, Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
                        .commit(),
                ) { "Failed to persist Android Keystore wrapped Mahayana storage key" }
            }
        }
        check(secret.size == 32) { "Invalid Mahayana storage key length" }
        return Base64.encodeToString(secret, Base64.NO_WRAP)
    }
}

class MahayanaHost(context: Context, featureHostTest: Boolean = false) : Closeable {
    private val lifecycleLock = Any()
    @Volatile private var handle: Long

    init {
        System.loadLibrary("mahayana_app_host")
        val value = if (featureHostTest) {
            nativeCreateTest(context.filesDir.absolutePath)
        } else {
            nativeCreate(context.filesDir.absolutePath, MobileAuthStoragePassphrase.loadOrCreate(context))
        }
        check(value != 0L) { "Failed to initialize Mahayana Rust host" }
        handle = value
    }

    fun request(method: String, params: JSONObject = JSONObject()): JSONObject = synchronized(lifecycleLock) {
        val active = handle
        check(active != 0L) { "Mahayana host is closed" }
        val request = JSONObject().put("method", method).put("params", params)
        val response = JSONObject(nativeDispatch(active, request.toString()))
        if (!response.optBoolean("ok", false)) {
            error(response.optString("error", "Mahayana host request failed"))
        }
        response.optJSONObject("result") ?: JSONObject().put("value", response.opt("result"))
    }

    fun requestValue(method: String, params: JSONObject = JSONObject()): Any? = synchronized(lifecycleLock) {
        val active = handle
        check(active != 0L) { "Mahayana host is closed" }
        val request = JSONObject().put("method", method).put("params", params)
        val response = JSONObject(nativeDispatch(active, request.toString()))
        if (!response.optBoolean("ok", false)) error(response.optString("error", "Mahayana host request failed"))
        response.opt("result")
    }

    override fun close() {
        synchronized(lifecycleLock) {
            val active = handle
            if (active == 0L) return
            // Holding the same lock used by every JNI dispatch guarantees no
            // native call can still be dereferencing this pointer when it is freed.
            handle = 0L
            nativeDestroy(active)
        }
    }

    private external fun nativeCreate(appDataDir: String, storagePassphrase: String): Long
    private external fun nativeCreateTest(appDataDir: String): Long
    private external fun nativeDispatch(handle: Long, requestJson: String): String
    private external fun nativeDestroy(handle: Long)
}
