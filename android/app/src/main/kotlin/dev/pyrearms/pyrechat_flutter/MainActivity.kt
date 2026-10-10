package dev.pyrearms.pyrechat_flutter

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.core.net.toFile
import com.snap.camerakit.support.app.CameraActivity
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.charset.StandardCharsets
import java.security.GeneralSecurityException
import java.security.KeyStore
import java.util.concurrent.atomic.AtomicInteger
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import org.json.JSONObject

class MainActivity : FlutterFragmentActivity() {
    private var cameraKitResult: MethodChannel.Result? = null
    private var pendingNotificationConversationId: String? = null

    private val cameraKitCaptureLauncher =
        registerForActivityResult(CameraActivity.Capture) { captureResult ->
            val pending = cameraKitResult
            cameraKitResult = null

            if (pending == null) return@registerForActivityResult

            when (captureResult) {
                is CameraActivity.Capture.Result.Success.Video -> {
                    pending.success(
                        mapOf(
                            "path" to captureResult.uri.toFile().absolutePath,
                            "mime_type" to "video",
                        ),
                    )
                }
                is CameraActivity.Capture.Result.Success.Image -> {
                    pending.success(
                        mapOf(
                            "path" to captureResult.uri.toFile().absolutePath,
                            "mime_type" to "image",
                        ),
                    )
                }
                is CameraActivity.Capture.Result.Cancelled -> {
                    pending.success(null)
                }
                is CameraActivity.Capture.Result.Failure -> {
                    pending.error(
                        "camera_kit_failure",
                        captureResult.exception.message ?: "Camera Kit capture failed",
                        null,
                    )
                }
            }
        }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            VIDEO_PREVIEW_VIEW_TYPE,
            PyreVideoPreviewFactory(),
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VIDEO_PREVIEW_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "cacheVideo" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || bytes.isEmpty()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val path = runCatching {
                        File.createTempFile(
                            VIDEO_PREVIEW_FILE_PREFIX,
                            ".mp4",
                            cacheDir,
                        ).apply {
                            writeBytes(bytes)
                        }.absolutePath
                    }.getOrNull()
                    result.success(path)
                }
                "deleteCachedVideo" -> {
                    val path = call.argument<String>("path")
                    if (!path.isNullOrBlank()) {
                        runCatching {
                            val file = File(path)
                            val cacheRoot = cacheDir.canonicalFile
                            val candidate = file.canonicalFile
                            val insideCache =
                                candidate.parentFile?.canonicalFile == cacheRoot
                            if (
                                insideCache &&
                                candidate.name.startsWith(VIDEO_PREVIEW_FILE_PREFIX)
                            ) {
                                candidate.delete()
                            }
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EXTERNAL_LINKS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> {
                    val raw = call.argument<String>("url")
                    val uri = runCatching { Uri.parse(raw) }.getOrNull()
                    val allowed =
                        uri != null &&
                            uri.scheme.equals("https", ignoreCase = true) &&
                            (uri.host.equals("chat.pyrearms.dev", ignoreCase = true) ||
                                uri.host.equals("pyre.social", ignoreCase = true))
                    if (!allowed) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val opened = runCatching {
                        startActivity(Intent(Intent.ACTION_VIEW, uri))
                        true
                    }.getOrDefault(false)
                    result.success(opened)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MEDIA_SAVER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveMedia" -> {
                    val path = call.argument<String>("path")?.trim().orEmpty()
                    val bytes = call.argument<ByteArray>("bytes")
                    val mime = call.argument<String>("mime")?.trim().orEmpty()
                    val kind = call.argument<String>("kind")?.trim().orEmpty()
                    try {
                        val savedUri = saveMediaToGallery(path, bytes, mime, kind)
                        result.success(savedUri?.toString())
                    } catch (throwable: Throwable) {
                        result.error(
                            "media_save_failed",
                            throwable.message ?: "Could not save media to device",
                            null,
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }

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
                "readSecret" -> {
                    val name = call.argument<String>("name")
                    result.success(
                        if (name.isNullOrBlank()) null else readSecret(name),
                    )
                }
                "writeSecret" -> {
                    val name = call.argument<String>("name")
                    val value = call.argument<String>("value")
                    result.success(
                        !name.isNullOrBlank() &&
                            value != null &&
                            writeSecret(name, value),
                    )
                }
                "deleteSecret" -> {
                    val name = call.argument<String>("name")
                    if (!name.isNullOrBlank()) deleteSecret(name)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CAMERA_KIT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isConfigured" -> result.success(BuildConfig.CAMERA_KIT_CONFIGURED)
                "openCapture" -> {
                    if (!BuildConfig.CAMERA_KIT_CONFIGURED) {
                        result.error(
                            "camera_kit_not_configured",
                            "Camera Kit credentials are not configured for this build",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    if (cameraKitResult != null) {
                        result.error(
                            "camera_kit_busy",
                            "Camera Kit is already open",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    val lensGroupIds = BuildConfig.CAMERA_KIT_LENS_GROUP_IDS
                        .split(",")
                        .map { it.trim() }
                        .filter { it.isNotEmpty() }
                        .toTypedArray()

                    if (lensGroupIds.isEmpty()) {
                        result.error(
                            "camera_kit_no_groups",
                            "No Camera Kit Lens Group IDs are configured",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    cameraKitResult = result
                    try {
                        cameraKitCaptureLauncher.launch(
                            CameraActivity.Configuration.WithLenses(
                                cameraKitApiToken = BuildConfig.CAMERA_KIT_API_TOKEN,
                                lensGroupIds = lensGroupIds,
                                // Open on Camera Kit's idle slot: ordinary camera,
                                // no Lens applied. Lenses remain immediately
                                // available in the carousel to the right, matching
                                // the expected Snapchat-style capture flow.
                                disableIdleState = false,
                            ),
                        )
                    } catch (throwable: Throwable) {
                        cameraKitResult = null
                        result.error(
                            "camera_kit_launch_failed",
                            throwable.message ?: "Camera Kit could not open",
                            null,
                        )
                    }
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
                "getPushToken" -> {
                    PyrePushTokenStore.refresh(this) { token ->
                        runOnUiThread { result.success(token) }
                    }
                }
                "getRcsMessagePreviews" -> {
                    result.success(PyreRcsNotificationPreferences.previewsEnabled(this))
                }
                "setRcsMessagePreviews" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    result.success(
                        enabled != null &&
                            PyreRcsNotificationPreferences.setPreviewsEnabled(this, enabled)
                    )
                }
                "takeNotificationConversationId" -> {
                    result.success(takeNotificationConversationId())
                }
                "setNotificationContext" -> {
                    val foreground = call.argument<Boolean>("foreground") == true
                    val activeConversationId =
                        call.argument<String>("activeConversationId")
                    PyreNotificationContextStore.set(
                        this,
                        foreground,
                        activeConversationId,
                    )
                    result.success(null)
                }
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: "Pyre Social"
                    val body = call.argument<String>("body") ?: "New activity"
                    val payload = call.argument<String>("payload")
                    result.success(showNotification(title, body, payload))
                }
                "isQuietModeSupported" -> result.success(true)
                "isQuietModeEnabled" -> result.success(
                    getQuietModeLevel() != QUIET_MODE_OFF,
                )
                "getQuietModeLevel" -> result.success(getQuietModeLevel())
                "hasNotificationPolicyAccess" -> result.success(true)
                "openNotificationPolicyAccessSettings" -> result.success(null)
                "setQuietModeEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    result.success(
                        setQuietModeLevel(
                            if (enabled) QUIET_MODE_QUIET else QUIET_MODE_OFF,
                        ),
                    )
                }
                "setQuietModeLevel" -> {
                    val mode = call.argument<String>("mode") ?: QUIET_MODE_OFF
                    result.success(setQuietModeLevel(mode))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingNotificationConversationId =
            extractNotificationConversationId(intent)
    }

    override fun onResume() {
        super.onResume()
        PyreNotificationContextStore.setForeground(this, true)
    }

    override fun onPause() {
        PyreNotificationContextStore.setForeground(this, false)
        super.onPause()
    }

    private fun saveMediaToGallery(
        sourcePath: String,
        sourceBytes: ByteArray?,
        mime: String,
        kind: String,
    ): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw IllegalStateException("Saving to gallery requires Android 10 or newer")
        }

        val isVideo = kind.equals("video", ignoreCase = true) ||
            mime.startsWith("video/", ignoreCase = true)
        val safeMime = when {
            mime.isNotBlank() -> mime
            isVideo -> "video/mp4"
            else -> "image/jpeg"
        }
        val extension = when (safeMime.lowercase()) {
            "image/png" -> "png"
            "image/heic", "image/heif" -> "heic"
            "video/quicktime" -> "mov"
            else -> if (isVideo) "mp4" else "jpg"
        }
        val displayName = "PyreSocial_${System.currentTimeMillis()}.$extension"
        val collection = if (isVideo) {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }
        val relativePath = if (isVideo) {
            "${Environment.DIRECTORY_MOVIES}/Pyre Social"
        } else {
            "${Environment.DIRECTORY_PICTURES}/Pyre Social"
        }

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, safeMime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(collection, values)
            ?: throw IllegalStateException("Could not create gallery item")

        try {
            contentResolver.openOutputStream(uri)?.use { output ->
                if (sourcePath.isNotBlank()) {
                    File(sourcePath).inputStream().use { input -> input.copyTo(output) }
                } else if (sourceBytes != null && sourceBytes.isNotEmpty()) {
                    output.write(sourceBytes)
                } else {
                    throw IllegalArgumentException("No media source was provided")
                }
            } ?: throw IllegalStateException("Could not open gallery output stream")

            ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }.also { contentResolver.update(uri, it, null, null) }
            return uri
        } catch (throwable: Throwable) {
            contentResolver.delete(uri, null, null)
            throw throwable
        }
    }

    private fun getQuietModeLevel(): String =
        PyreQuietModeStore.level(this)

    private fun setQuietModeLevel(mode: String): Boolean =
        PyreQuietModeStore.setLevel(this, mode)

    private fun initNotifications() {
        createNotificationChannel()
        PyrePushTokenStore.refresh(this)

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

    private fun extractNotificationConversationId(source: Intent?): String? {
        if (source == null) return null

        val direct = source.getStringExtra(NOTIFICATION_CONVERSATION_EXTRA)
            ?: source.getStringExtra(FCM_CONVERSATION_EXTRA)
        if (!direct.isNullOrBlank()) return direct.trim()

        val payload = source.getStringExtra(NOTIFICATION_PAYLOAD_EXTRA)
        if (!payload.isNullOrBlank()) {
            try {
                val value = JSONObject(payload)
                    .optString("conversationId", "")
                    .trim()
                if (value.isNotEmpty()) return value
            } catch (_: Exception) {
                // Ignore stale or malformed local-notification payloads.
            }
        }

        return null
    }

    private fun takeNotificationConversationId(): String? {
        val conversationId =
            pendingNotificationConversationId
                ?: extractNotificationConversationId(intent)
        pendingNotificationConversationId = null
        intent?.removeExtra(NOTIFICATION_CONVERSATION_EXTRA)
        intent?.removeExtra(FCM_CONVERSATION_EXTRA)
        intent?.removeExtra(NOTIFICATION_PAYLOAD_EXTRA)
        return conversationId
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
                description = "Pyre Social message and account activity"
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            },
        )
    }

    private fun showNotification(
        title: String,
        body: String,
        payload: String?,
    ): Boolean {
        if (PyreQuietModeStore.level(this) != PyreQuietModeStore.OFF) {
            return false
        }
        createNotificationChannel()

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }

        val id = notificationId.incrementAndGet()
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (payload != null) {
                putExtra(NOTIFICATION_PAYLOAD_EXTRA, payload)
            }
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            id,
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
        manager.notify(id, notification)
        return true
    }

    private fun isSecureStorageSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M

    private fun writeToken(token: String): Boolean =
        writeSecurePayload(TOKEN_PAYLOAD_KEY, token)

    private fun readToken(): String? =
        readSecurePayload(TOKEN_PAYLOAD_KEY)

    private fun deleteToken() {
        deleteSecurePayload(TOKEN_PAYLOAD_KEY)
    }

    private fun secretPayloadKey(name: String): String {
        val encoded = Base64.encodeToString(
            name.toByteArray(StandardCharsets.UTF_8),
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
        )
        return SECRET_PAYLOAD_PREFIX + encoded
    }

    private fun writeSecret(name: String, value: String): Boolean {
        if (name.length > 240) return false
        return writeSecurePayload(secretPayloadKey(name), value)
    }

    private fun readSecret(name: String): String? {
        if (name.length > 240) return null
        return readSecurePayload(secretPayloadKey(name))
    }

    private fun deleteSecret(name: String) {
        if (name.length > 240) return
        deleteSecurePayload(secretPayloadKey(name))
    }

    private fun writeSecurePayload(storageKey: String, value: String): Boolean {
        if (!isSecureStorageSupported()) return false

        return try {
            val cipher = Cipher.getInstance(CIPHER_TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateSecretKey())

            val iv = Base64.encodeToString(cipher.iv, Base64.NO_WRAP)
            val ciphertext = Base64.encodeToString(
                cipher.doFinal(value.toByteArray(StandardCharsets.UTF_8)),
                Base64.NO_WRAP,
            )
            securePreferences()
                .edit()
                .putString(storageKey, "$iv:$ciphertext")
                .commit()
        } catch (_: GeneralSecurityException) {
            false
        } catch (_: IllegalArgumentException) {
            false
        }
    }

    private fun readSecurePayload(storageKey: String): String? {
        if (!isSecureStorageSupported()) return null

        val payload = securePreferences().getString(storageKey, null)
            ?: return null

        return try {
            val parts = payload.split(':', limit = 2)
            if (parts.size != 2) {
                clearCorruptPayload(storageKey)
                return null
            }

            val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
            val key = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
                ?: return null

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
            // Keystore access can fail transiently during device/app lifecycle
            // changes. Preserve the ciphertext so a later read can recover
            // instead of converting one failed read into a permanent logout.
            null
        } catch (_: IllegalArgumentException) {
            // Invalid Base64/payload structure is genuinely corrupt local data.
            clearCorruptPayload(storageKey)
            null
        }
    }

    private fun deleteSecurePayload(storageKey: String) {
        securePreferences()
            .edit()
            .remove(storageKey)
            .apply()
    }

    private fun clearCorruptPayload(storageKey: String) {
        deleteSecurePayload(storageKey)
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
        private const val CAMERA_KIT_CHANNEL =
            "dev.pyrearms.pyrechat/camera_kit"
        private const val MEDIA_SAVER_CHANNEL =
            "dev.pyrearms.pyrechat/media_saver"
        private const val SECURE_PREFS_NAME = "pyre_secure_session"
        private const val TOKEN_PAYLOAD_KEY = "token_payload_v1"
        private const val SECRET_PAYLOAD_PREFIX = "secret_payload_v1_"
        private const val KEY_ALIAS = "pyre_session_token_key_v1"
        private const val EXTERNAL_LINKS_CHANNEL = "dev.pyrearms.pyrechat/external_links"
        private const val VIDEO_PREVIEW_VIEW_TYPE = "pyrechat/video_preview"
        private const val VIDEO_PREVIEW_CHANNEL = "dev.pyrearms.pyrechat_flutter/video_preview"
        private const val VIDEO_PREVIEW_FILE_PREFIX = "pyre_video_"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val CIPHER_TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_BITS = 128

        private const val NOTIFICATION_CHANNEL_ID = "pyre_messages"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4001

        private const val QUIET_MODE_OFF = PyreQuietModeStore.OFF
        private const val QUIET_MODE_QUIET = PyreQuietModeStore.QUIET
        private const val QUIET_MODE_ABSOLUTE = PyreQuietModeStore.ABSOLUTE
        private const val NOTIFICATION_PAYLOAD_EXTRA = "pyre_notification_payload"
        private const val NOTIFICATION_CONVERSATION_EXTRA =
            "pyre_conversation_id"
        private const val FCM_CONVERSATION_EXTRA = "conversationId"
        private val notificationId = AtomicInteger(1000)
    }
}
