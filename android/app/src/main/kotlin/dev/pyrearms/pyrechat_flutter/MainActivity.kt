package dev.pyrearms.pyrechat_flutter

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets
import java.security.GeneralSecurityException
import java.security.KeyStore
import java.util.concurrent.atomic.AtomicInteger
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SECURE_SESSION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(isSecureStorageSupported())
                "readToken" -> result.success(readToken())
                "writeToken" -> {
                    val token = call.argument<String>("token")
                    result.success(token != null && writeToken(token))
                }
                "deleteToken" -> {
                    deleteToken()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATIONS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initNotifications" -> {
                    initNotifications()
                    result.success(null)
                }
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: "PyreChat"
                    val body = call.argument<String>("body") ?: "New activity"
                    val payload = call.argument<String>("payload")
                    result.success(showNotification(title, body, payload))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initNotifications() {
        createNotificationChannel()

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST,
            )
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID) != null) {
            return
        }

        manager.createNotificationChannel(
            NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Messages and activity",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "PyreChat message and account activity"
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            },
        )
    }

    private fun showNotification(
        title: String,
        body: String,
        payload: String?,
    ): Boolean {
        createNotificationChannel()

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (payload != null) {
                putExtra(NOTIFICATION_PAYLOAD_EXTRA, payload)
            }
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val notification = builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId.incrementAndGet(), notification)
        return true
    }

    private fun isSecureStorageSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M

    private fun writeToken(token: String): Boolean {
        if (!isSecureStorageSupported()) return false

        return try {
            val cipher = Cipher.getInstance(CIPHER_TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateSecretKey())

            val iv = Base64.encodeToString(cipher.iv, Base64.NO_WRAP)
            val ciphertext = Base64.encodeToString(
                cipher.doFinal(token.toByteArray(StandardCharsets.UTF_8)),
                Base64.NO_WRAP,
            )
            securePreferences()
                .edit()
                .putString(TOKEN_PAYLOAD_KEY, "$iv:$ciphertext")
                .commit()
        } catch (_: GeneralSecurityException) {
            false
        } catch (_: IllegalArgumentException) {
            false
        }
    }

    private fun readToken(): String? {
        if (!isSecureStorageSupported()) return null

        val payload = securePreferences().getString(TOKEN_PAYLOAD_KEY, null)
            ?: return null

        return try {
            val parts = payload.split(':', limit = 2)
            if (parts.size != 2) {
                clearCorruptPayload()
                return null
            }

            val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
            val key = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
                ?: run {
                    clearCorruptPayload()
                    return null
                }

            val iv = Base64.decode(parts[0], Base64.NO_WRAP)
            val ciphertext = Base64.decode(parts[1], Base64.NO_WRAP)

            val cipher = Cipher.getInstance(CIPHER_TRANSFORMATION)
            cipher.init(
                Cipher.DECRYPT_MODE,
                key,
                GCMParameterSpec(GCM_TAG_BITS, iv),
            )

            String(cipher.doFinal(ciphertext), StandardCharsets.UTF_8)
        } catch (_: GeneralSecurityException) {
            clearCorruptPayload()
            null
        } catch (_: IllegalArgumentException) {
            clearCorruptPayload()
            null
        }
    }

    private fun deleteToken() {
        securePreferences()
            .edit()
            .remove(TOKEN_PAYLOAD_KEY)
            .apply()
    }

    private fun clearCorruptPayload() {
        securePreferences()
            .edit()
            .remove(TOKEN_PAYLOAD_KEY)
            .apply()
    }

    private fun securePreferences() =
        getSharedPreferences(SECURE_PREFS_NAME, Context.MODE_PRIVATE)

    private fun getOrCreateSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val existing = keyStore.getKey(KEY_ALIAS, null)
        if (existing is SecretKey) return existing

        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEYSTORE,
        )
        keyGenerator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return keyGenerator.generateKey()
    }

    companion object {
        private const val SECURE_SESSION_CHANNEL =
            "dev.pyrearms.pyrechat/secure_session"
        private const val NOTIFICATIONS_CHANNEL =
            "dev.pyrearms.pyrechat/notifications"
        private const val SECURE_PREFS_NAME = "pyre_secure_session"
        private const val TOKEN_PAYLOAD_KEY = "token_payload_v1"
        private const val KEY_ALIAS = "pyre_session_token_key_v1"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val CIPHER_TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_BITS = 128

        private const val NOTIFICATION_CHANNEL_ID = "pyre_messages"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4001
        private const val NOTIFICATION_PAYLOAD_EXTRA = "pyre_notification_payload"
        private val notificationId = AtomicInteger(1000)
    }
}
