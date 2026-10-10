package dev.pyrearms.pyrechat_flutter

/**
 * Notification identity layers, independent of the FCM transport.
 *
 * A first-party RCS wake carries only a validated account handle. It must never
 * carry a claimed display name, Pyre Number, or a local contact's private name.
 * Verified Pyre Numbers will come from the account identity directory; contacts
 * will be resolved locally with the user's permission. Both must be keyed to
 * this same RCS identity before being passed to resolve().
 */
internal enum class PyreNotificationIdentityLayer {
    RCS_ADDRESS,
    PYRE_NUMBER,
    LOCAL_CONTACT,
}

internal data class PyreNotificationIdentityLabel(
    val title: String,
    val layer: PyreNotificationIdentityLayer,
)

/** Stable first-party RCS identity; no phone number or contact lookup today. */
internal class PyreNotificationSenderIdentity private constructor(
    val rcsHandle: String,
) {
    val rcsAddress: String get() = "sip:$rcsHandle@messages.pyre.social"

    /**
     * Display order: local contact name > verified Pyre Number > RCS address.
     * The optional layers must come from trusted, address-bound lookups, NEVER
     * untrusted Firebase data or message text. Absent layers have no effect.
     */
    fun resolve(
        verifiedPyreNumber: String? = null,
        localContactName: String? = null,
    ): PyreNotificationIdentityLabel {
        safeLabel(localContactName)?.let {
            return PyreNotificationIdentityLabel(it, PyreNotificationIdentityLayer.LOCAL_CONTACT)
        }
        safeLabel(verifiedPyreNumber)?.let {
            return PyreNotificationIdentityLabel(it, PyreNotificationIdentityLayer.PYRE_NUMBER)
        }
        return PyreNotificationIdentityLabel(
            rcsAddress, PyreNotificationIdentityLayer.RCS_ADDRESS,
        )
    }

    companion object {
        private val RCS_HANDLE = Regex("^[a-z][a-z0-9._-]{2,31}$")

        fun fromRcsHandle(value: String): PyreNotificationSenderIdentity? =
            if (RCS_HANDLE.matches(value)) PyreNotificationSenderIdentity(value) else null

        private fun safeLabel(value: String?): String? {
            val label = value?.trim() ?: return null
            if (label.isEmpty() || label.length > 80 || label.any {
                Character.isISOControl(it) ||
                    it == '\u2028' || it == '\u2029' ||
                    it in '\u202a'..'\u202e' || it in '\u2066'..'\u2069'
            }) return null
            return label
        }
    }
}
