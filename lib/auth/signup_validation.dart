/// Lightweight client-side validation for the active PyreChat signup flow.
///
/// The backend remains authoritative. These checks keep obviously invalid input
/// from being sent and keep the UI contract consistent with the text we show.
String? validateDisplayName(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'Enter your name';
  if (value.length > 50) return 'Keep your name under 50 characters';
  if (value.runes.any((r) => r < 0x20 || r == 0x7f)) {
    return 'Your name contains unsupported characters';
  }
  return null;
}

String? validateUsername(String raw) {
  final value = raw.trim();
  if (value.length < 3 || value.length > 24) {
    return 'Username must be 3–24 characters';
  }
  if (!RegExp(r'^[A-Za-z0-9._]+$').hasMatch(value)) {
    return 'Use only letters, numbers, dots, or underscores';
  }
  return null;
}

String? validateSignupPassword(String raw) {
  if (raw.length < 8) return 'Password must be at least 8 characters';
  if (raw.length > 128) return 'Password must be 128 characters or fewer';
  return null;
}
