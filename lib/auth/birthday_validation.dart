import 'package:pyrechat_flutter/auth/birthday_input.dart';

/// Validates the birthday and PyreChat's minimum account age.
///
/// Input punctuation is normalized client-side so users never need to manually
/// match the API's canonical YYYY-MM-DD representation.
String? validatePyreBirthday(String raw, {DateTime? today}) {
  final value = normalizeBirthdayInput(raw);
  if (value == null) return 'Enter a valid birthday';

  final parts = value.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final day = int.parse(parts[2]);

  late final DateTime birthday;
  try {
    birthday = DateTime(year, month, day);
  } catch (_) {
    return 'Enter a valid birthday';
  }

  if (birthday.year != year || birthday.month != month || birthday.day != day) {
    return 'Enter a valid birthday';
  }

  final now = today ?? DateTime.now();
  final reference = DateTime(now.year, now.month, now.day);
  if (birthday.isAfter(reference)) return 'Enter a valid birthday';

  var age = reference.year - birthday.year;
  final birthdayThisYear = DateTime(reference.year, birthday.month, birthday.day);
  if (reference.isBefore(birthdayThisYear)) age--;

  if (age < 13) return 'You must be at least 13 to use PyreChat';
  return null;
}
