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
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import java.util.concurrent.atomic.AtomicInteger

class PyreFirebaseMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        PyrePushTokenStore.save(this, token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        if (data["type"] == "pyre_rcs_wake") {
            val handle = data["handle"] ?: return
            // Current FCM uses "sender": the key "from" is reserved by Google.
            // Accept legacy internal aliases only for backward compatibility.
            val sender = data["sender"] ?: data["from"] ?: return
            val messageId = data["messageId"] ?: return
            if (!RCS_HANDLE.matches(handle) || !RCS_HANDLE.matches(sender) ||
                !RCS_MESSAGE_ID.matches(messageId)) return
            // Identity comes from the authenticated RCS sender handle, not FCM
            // aliases or plaintext. Future trusted directory/contact layers can
            // be supplied to the same resolver without changing push transport.
            val senderIdentity =
                PyreNotificationSenderIdentity.fromRcsHandle(sender) ?: return
            val senderTitle = senderIdentity.resolve().title

            // Critical: post the visible fallback BEFORE the bounded HTTPS
            // fetch in onWake(). Android may stop this FCM callback while the
            // phone is dozing or network requests are stalled. Legacy push
            // displayed without a network round trip; RCS must do so as well.
            val display = !PyreNotificationContextStore.shouldSuppress(this, null) &&
                !PyreQuietModeStore.suppressBackgroundNotification(this)
            val rcsNotificationId = RCS_NOTIFICATION_BASE or
                (("rcs:" + sender + ":" + messageId).hashCode() and RCS_NOTIFICATION_MASK)
            if (display) {
                showPrivateNotification(
                    title = senderTitle,
                    body = "New message",
                    conversationId = null,
                    snapId = null,
                    notificationIdOverride = rcsNotificationId,
                )
            }

            // Independently enqueue, securely fetch, and acknowledge the
            // content-free FCM wake. Failure does not retract the alert;
            // message history remains durable on our own RCS server.
            val nativeWake = mapOf(
                "type" to "pyre_rcs_wake",
                "handle" to handle,
                "from" to sender,
                "messageId" to messageId,
            )
            if (!PyreRcsBackgroundDelivery.onWake(this, nativeWake)) return

            // Upgrade the SAME notification once the exact CPIM has been
            // verified and stored locally. Never send message text to FCM.
            if (display && PyreRcsNotificationPreferences.previewsEnabled(this)) {
                val preview = PyreRcsBackgroundDelivery.notificationPreview(
                    this, sender, messageId,
                )
                if (preview != null) {
                    showPrivateNotification(
                        title = senderTitle,
                        body = preview,
                        conversationId = null,
                        snapId = null,
                        notificationIdOverride = rcsNotificationId,
                    )
                }
            }
            return
        }
        val kind = data["kind"] ?: "chat"
        if (
            PyreNotificationContextStore.shouldSuppress(this, data["conversationId"]) ||
            PyreQuietModeStore.suppressBackgroundNotification(this)
        ) {
            return
        }
        val body = when (kind) {
            "snap" -> "New Pyre"
            "friend", "friend_request" -> "Friend activity"
            else -> "New message"
        }

        showPrivateNotification(
            title = "PyreChat",
            body = body,
            conversationId = data["conversationId"],
            snapId = data["snapId"],
        )
    }

    private fun showPrivateNotification(
        title: String,
        body: String,
        conversationId: String?,
        snapId: String?,
        notificationIdOverride: Int? = null,
    ) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            manager.getNotificationChannel(CHANNEL_ID) == null
        ) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Messages and activity",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "PyreChat message and account activity"
                    lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                },
            )
        }

        val id = notificationIdOverride ?: notificationId.incrementAndGet()
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (!conversationId.isNullOrBlank()) {
                putExtra("pyre_conversation_id", conversationId)
            }
            if (!snapId.isNullOrBlank()) {
                putExtra("pyre_snap_id", snapId)
            }
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val notification = builder
            .setOnlyAlertOnce(notificationIdOverride != null)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        manager.notify(id, notification)
    }

    companion object {
        private const val CHANNEL_ID = "pyre_messages"
        private const val RCS_NOTIFICATION_BASE = 0x20000000
        private const val RCS_NOTIFICATION_MASK = 0x1fffffff
        private val RCS_HANDLE = Regex("^[a-z][a-z0-9._-]{2,31}$")
        private val RCS_MESSAGE_ID = Regex("^[A-Za-z0-9_.@-]{12,140}$")
        private val notificationId = AtomicInteger(4000)
    }
}

/** Device-local preference; does not alter FCM delivery or IMDN receipt rules. */
object PyreRcsNotificationPreferences {
    private const val PREFS = "pyre_rcs_notifications_v1"
    private const val SHOW_PREVIEWS = "show_message_previews"

    fun previewsEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(SHOW_PREVIEWS, true)

    fun setPreviewsEnabled(context: Context, enabled: Boolean): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(SHOW_PREVIEWS, enabled).commit()
}
