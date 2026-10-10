package dev.pyrearms.pyrechat_flutter

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging

object PyrePushTokenStore {
    private const val PREFS = "pyre_push"
    private const val TOKEN_KEY = "fcm_token"

    fun save(context: Context, token: String) {
        if (token.isBlank()) return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(TOKEN_KEY, token.trim())
            .apply()
    }

    fun read(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(TOKEN_KEY, null)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }

    fun refresh(
        context: Context,
        onComplete: ((String?) -> Unit)? = null,
    ) {
        val app = try {
            FirebaseApp.initializeApp(context)
        } catch (_: Exception) {
            null
        }
        if (app == null) {
            onComplete?.invoke(read(context))
            return
        }

        try {
            FirebaseMessaging.getInstance().token
                .addOnCompleteListener { task ->
                    val token = if (task.isSuccessful) task.result?.trim() else null
                    if (!token.isNullOrEmpty()) save(context, token)
                    onComplete?.invoke(token?.takeIf { it.isNotEmpty() } ?: read(context))
                }
        } catch (_: Exception) {
            // Firebase config is optional in local/dev builds.
            onComplete?.invoke(read(context))
        }
    }
}


object PyreNotificationContextStore {
    private const val PREFS = "pyre_notification_context"
    private const val FOREGROUND_KEY = "foreground"
    private const val ACTIVE_CONVERSATION_KEY = "active_conversation"

    fun set(
        context: Context,
        foreground: Boolean,
        activeConversationId: String?,
    ) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(FOREGROUND_KEY, foreground)
            .apply {
                val value = activeConversationId?.trim().orEmpty()
                if (value.isEmpty()) {
                    remove(ACTIVE_CONVERSATION_KEY)
                } else {
                    putString(ACTIVE_CONVERSATION_KEY, value)
                }
            }
            .apply()
    }

    fun setForeground(context: Context, foreground: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(FOREGROUND_KEY, foreground)
            .apply()
    }

    fun shouldSuppress(
        context: Context,
        conversationId: String?,
    ): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.getBoolean(FOREGROUND_KEY, false)) return true
        return false
    }
}
