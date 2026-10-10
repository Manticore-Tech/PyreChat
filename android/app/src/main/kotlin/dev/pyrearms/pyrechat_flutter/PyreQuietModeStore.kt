package dev.pyrearms.pyrechat_flutter

import android.content.Context

object PyreQuietModeStore {
    private const val PREFS = "pyre_quiet_mode"
    private const val LEVEL_KEY = "level"
    private const val ENABLED_KEY = "enabled"

    const val OFF = "off"
    const val QUIET = "quiet"
    const val ABSOLUTE = "absolute"

    fun level(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val stored = prefs.getString(LEVEL_KEY, null)
        if (stored == OFF || stored == QUIET || stored == ABSOLUTE) {
            return stored
        }

        val migrated = if (prefs.getBoolean(ENABLED_KEY, false)) QUIET else OFF
        prefs.edit()
            .putString(LEVEL_KEY, migrated)
            .apply()
        return migrated
    }

    fun setLevel(context: Context, mode: String): Boolean {
        val normalized = when (mode) {
            QUIET -> QUIET
            ABSOLUTE -> ABSOLUTE
            else -> OFF
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(LEVEL_KEY, normalized)
            .putBoolean(ENABLED_KEY, normalized != OFF)
            .apply()
        return true
    }

    fun suppressBackgroundNotification(context: Context): Boolean =
        level(context) == ABSOLUTE
}
