package dev.pyrearms.pyrechat_flutter

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.util.Base64
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import org.json.JSONObject

/**
 * Native, private RCS delivery agent. Firebase starts PyreFirebaseMessagingService
 * even when the Flutter UI is not running (unless the user force-stops the app).
 *
 * A scoped delivery grant is encrypted with the SAME AndroidKeyStore key as the
 * Flutter secure-blob store. Never expose message text or bearer tokens to FCM.
 *
 * A separate device-delivered IMDN is sent only after the exact CPIM is
 * encrypted locally. Public Delivered already follows recipient mailbox storage;
 * physical device confirmation remains supplementary reliability evidence.
 */
object PyreRcsBackgroundDelivery {
    private const val GRANT_NAME = "pyre_rcs_native_delivery_grant_v1"
    private const val SECURE_PREFS = "pyre_secure_session"
    private const val ENCRYPTED_PREFIX = "secret_payload_v1_"
    private const val KEY_ALIAS = "pyre_session_token_key_v1"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val CIPHER = "AES/GCM/NoPadding"
    private const val PENDING_PREFS = "pyre_rcs_pending_v1"
    private const val CPIM_PREFIX = "rcs_received_cpim_v1_"
    private const val RCS_ORIGIN = "https://messages.pyre.social"
    private const val JOB_ID = 672193
    private const val MAX_BATCH = 8
    private const val MAX_PENDING = 80
    private const val MAX_SAVED_CPIM = 128
    private val HANDLE_PATTERN = Regex("^[a-z][a-z0-9._-]{2,31}$")
    private val MESSAGE_PATTERN = Regex("^[A-Za-z0-9_.@-]{12,140}$")
    private val DEVICE_PATTERN = Regex("^[A-Za-z0-9_-]{16,80}$")
    private val secretName = ENCRYPTED_PREFIX + Base64.encodeToString(
        GRANT_NAME.toByteArray(StandardCharsets.UTF_8),
        Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
    )

    private fun decodeEncrypted(context: Context, prefKey: String): String? {
        val encoded = context.getSharedPreferences(SECURE_PREFS, Context.MODE_PRIVATE)
            .getString(prefKey, null) ?: return null
        return runCatching {
            val pair = encoded.split(':', limit = 2)
            if (pair.size != 2) return null
            val keystore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
            val key = keystore.getKey(KEY_ALIAS, null) as? SecretKey ?: return null
            val iv = Base64.decode(pair[0], Base64.NO_WRAP)
            val ciphertext = Base64.decode(pair[1], Base64.NO_WRAP)
            String(Cipher.getInstance(CIPHER).apply {
                init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, iv))
            }.doFinal(ciphertext), StandardCharsets.UTF_8)
        }.getOrNull()
    }

    private fun encryptReceived(context: Context, sender: String, messageId: String, cpim: String): Boolean {
        if (cpim.toByteArray(StandardCharsets.UTF_8).size > 99000) return false
        return runCatching {
            val keystore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
            val key = keystore.getKey(KEY_ALIAS, null) as? SecretKey ?: return false
            val cipher = Cipher.getInstance(CIPHER).apply { init(Cipher.ENCRYPT_MODE, key) }
            val iv = Base64.encodeToString(cipher.iv, Base64.NO_WRAP)
            val data = Base64.encodeToString(
                cipher.doFinal(cpim.toByteArray(StandardCharsets.UTF_8)), Base64.NO_WRAP
            )
            val prefs = context.getSharedPreferences(SECURE_PREFS, Context.MODE_PRIVATE)
            // Each RCS message ID belongs to a particular sender. Never let
            // separate senders' identical client-generated IDs collide.
            val keyName = CPIM_PREFIX + sender + "_" + messageId
            val stored = prefs.edit().putString(keyName, "$iv:$data")
                .putLong(keyName + "_time", System.currentTimeMillis()).commit()
            if (stored) {
                val keys = prefs.all.keys.filter {
                    it.startsWith(CPIM_PREFIX) && !it.endsWith("_time")
                }
                if (keys.size > MAX_SAVED_CPIM) {
                    val old = keys.sortedBy { prefs.getLong(it + "_time", 0) }
                        .take(keys.size - MAX_SAVED_CPIM)
                    prefs.edit().apply {
                        old.forEach { remove(it); remove(it + "_time") }
                    }.apply()
                }
            }
            stored
        }.getOrDefault(false)
    }

    private fun grant(context: Context): JSONObject? = runCatching {
        val data = decodeEncrypted(context, secretName) ?: return null
        val json = JSONObject(data)
        val handle = json.optString("handle")
        val deviceId = json.optString("deviceId")
        val key = json.optString("deliveryKey")
        if (!HANDLE_PATTERN.matches(handle) || !DEVICE_PATTERN.matches(deviceId) ||
            key.length < 40 || json.optLong("expiresAtMs", 0) <= System.currentTimeMillis()) {
            return null
        }
        json
    }.getOrNull()

    /** Persist the content-free wake BEFORE attempting network acknowledgement. */
    fun onWake(context: Context, data: Map<String, String>): Boolean {
        if (data["type"] != "pyre_rcs_wake") return false
        val handle = data["handle"] ?: return false
        val sender = data["from"] ?: return false
        val messageId = data["messageId"] ?: return false
        if (!HANDLE_PATTERN.matches(handle) || !HANDLE_PATTERN.matches(sender) ||
            !MESSAGE_PATTERN.matches(messageId)) return false
        val job = JSONObject()
            .put("handle", handle).put("from", sender).put("messageId", messageId)
        val prefs = context.getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
        val name = "pending_" + sender + "_" + messageId
        synchronized(this) {
            val pending = prefs.all.keys.filter { it.startsWith("pending_") }
            if (pending.size >= MAX_PENDING && !prefs.contains(name)) {
                // Server stores every CPIM; retry prior pending deliveries.
                scheduleRetry(context)
                return false
            }
            if (!prefs.edit().putString(name, job.toString()).commit()) return false
        }
        // Schedule recovery before network I/O. If Android stops this FCM
        // callback during a slow request, the pending wake still gets retried.
        scheduleRetry(context)
        if (flush(context)) {
            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE)
                as JobScheduler
            runCatching { scheduler.cancel(JOB_ID) }
        }
        return true
    }

    /**
     * Network operations are bounded to small batches/timeouts. The Android
     * JobScheduler retries when the phone regains network access.
     */
    fun flush(context: Context): Boolean {
        val credential = grant(context) ?: return false
        val prefs = context.getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
        val entries = synchronized(this) {
            prefs.all.entries
                .filter { it.key.startsWith("pending_") && it.value is String }
                .take(MAX_BATCH).map { it.key to (it.value as String) }
        }
        if (entries.isEmpty()) return true
        var allDone = true
        for ((name, payload) in entries) {
            val wake = runCatching { JSONObject(payload) }.getOrNull() ?: continue
            if (credential.optString("handle") != wake.optString("handle")) {
                // This might be from a prior device identity; never acknowledge
                // another account's messages with the present device grant.
                allDone = false
                continue
            }
            val success = tryDeliver(context, credential, wake)
            if (success) {
                synchronized(this) {
                    // A newer wake with the same key must not be discarded.
                    if (prefs.getString(name, null) == payload) {
                        prefs.edit().remove(name).commit()
                    }
                }
            } else allDone = false
        }
        val remaining = prefs.all.keys.any { it.startsWith("pending_") }
        return allDone && !remaining
    }

    private fun tryDeliver(context: Context, credential: JSONObject, wake: JSONObject): Boolean {
        val body = JSONObject().put("handle", credential.optString("handle"))
            .put("deviceId", credential.optString("deviceId"))
            .put("deliveryKey", credential.optString("deliveryKey"))
            .put("from", wake.optString("from"))
            .put("messageId", wake.optString("messageId"))
        val fetched = postJson("/v1/rcs/push/receive", body) ?: return false
        if (fetched.optString("id") != wake.optString("messageId") ||
            fetched.optString("from") != wake.optString("from")) return false
        val cpim = fetched.optString("cpim")
        val from = "From: <sip:" + wake.optString("from") + "@messages.pyre.social>\r\n"
        val to = "To: <sip:" + credential.optString("handle") + "@messages.pyre.social>\r\n"
        val id = "imdn.Message-ID: " + wake.optString("messageId") + "\r\n"
        if (!cpim.startsWith(from + to) || !cpim.contains("\r\n" + id) ||
            cpim.indexOf("\r\n\r\n") < 0) return false
        if (!encryptReceived(context, wake.optString("from"), wake.optString("messageId"), cpim)) return false
        val delivered = postJson("/v1/rcs/push/delivered", body) ?: return false
        return delivered.optBoolean("ok") && delivered.optString("state") == "delivered"
    }

    private fun postJson(path: String, data: JSONObject): JSONObject? {
        var connection: HttpURLConnection? = null
        return try {
            connection = URL(RCS_ORIGIN + path).openConnection() as HttpURLConnection
            val active = connection
            active.requestMethod = "POST"
            active.instanceFollowRedirects = false
            active.connectTimeout = 3500
            active.readTimeout = 4000
            active.doOutput = true
            active.setRequestProperty("Accept", "application/json")
            active.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            active.outputStream.use {
                it.write(data.toString().toByteArray(StandardCharsets.UTF_8))
            }
            if (active.responseCode !in 200..299) return null
            val content = active.inputStream.bufferedReader(StandardCharsets.UTF_8).use {
                it.readText()
            }
            if (content.length > 99000) return null
            JSONObject(content)
        } catch (_: Exception) {
            null // Never leak bearer/device grants or message content into logcat.
        } finally {
            connection?.disconnect()
        }
    }

    /**
     * Build a local notification preview only AFTER a verified HTTPS fetch
     * has been encrypted in AndroidKeyStore-backed app storage. The FCM wake
     * contains no text. Never preview opaque MLS/ciphertext MIME content.
     */
    fun notificationPreview(context: Context, sender: String, messageId: String): String? {
        if (!HANDLE_PATTERN.matches(sender) || !MESSAGE_PATTERN.matches(messageId)) return null
        val cpim = decodeEncrypted(context, CPIM_PREFIX + sender + "_" + messageId)
            ?: return null
        if (!cpim.startsWith("From: <sip:$sender@messages.pyre.social>\r\n") ||
            !cpim.contains("\r\nimdn.Message-ID: $messageId\r\n")) return null
        val first = cpim.indexOf("\r\n\r\n")
        if (first < 0) return null
        val second = cpim.indexOf("\r\n\r\n", first + 4)
        if (second < 0) return null
        val mimeHeaders = cpim.substring(first + 4, second)
        if (!mimeHeaders.split("\r\n").any {
            it.trim().equals("Content-type: text/plain; charset=utf-8", ignoreCase = true)
        }) return null
        val body = cpim.substring(second + 4)
            .replace(Regex("[\\r\\n\\t]+"), " ").trim()
        return body.take(180).ifBlank { null }
    }

    fun scheduleRetry(context: Context) {
        val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        val job = JobInfo.Builder(JOB_ID,
            ComponentName(context, PyreRcsDeliveryJobService::class.java))
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .setBackoffCriteria(30000L, JobInfo.BACKOFF_POLICY_EXPONENTIAL)
            .build()
        runCatching { scheduler.schedule(job) }
    }
}
