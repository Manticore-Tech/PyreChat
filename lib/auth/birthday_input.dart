import 'package:flutter/services.dart';

final RegExp _nonDigits = RegExp(r'\D');

/// Converts birthday digits to the canonical YYYY-MM-DD shape as the user types.
///
/// The user never needs to type separators. Extra characters are ignored and the
/// value is capped at the eight date digits expected by the signup API.
String formatBirthdayDigits(String rawDigits) {
  var digits = rawDigits.replaceAll(_nonDigits, '');
  if (digits.length > 8) {
    digits = digits.substring(0, 8);
  }

  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 4 || i == 6) {
      buffer.write('-');
    }
    buffer.write(digits[i]);
  }

  // Once a complete year or month has been entered, show the separator
  // immediately so the next digit naturally lands in the next segment.
  if (digits.length == 4 || digits.length == 6) {
    buffer.write('-');
  }

  return buffer.toString();
}

/// Normalizes common birthday representations to YYYY-MM-DD.
///
/// Normal typing uses YYYYMMDD and is formatted live. This also accepts common
/// pasted/autofilled forms such as YYYY/MM/DD and MM/DD/YYYY so users are never
/// required to repair punctuation themselves.
String? normalizeBirthdayInput(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final yearFirst =
      RegExp(r'^(\d{4})\D+(\d{1,2})\D+(\d{1,2})$').firstMatch(value);
  if (yearFirst != null) {
    return '${yearFirst.group(1)}-${_pad2(yearFirst.group(2)!)}-${_pad2(yearFirst.group(3)!)}';
  }

  final monthFirst =
      RegExp(r'^(\d{1,2})\D+(\d{1,2})\D+(\d{4})$').firstMatch(value);
  if (monthFirst != null) {
    return '${monthFirst.group(3)}-${_pad2(monthFirst.group(1)!)}-${_pad2(monthFirst.group(2)!)}';
  }

  final digits = value.replaceAll(_nonDigits, '');
  if (digits.length != 8) return null;

  final currentYear = DateTime.now().year;
  final firstFour = int.tryParse(digits.substring(0, 4)) ?? 0;
  final lastFour = int.tryParse(digits.substring(4, 8)) ?? 0;

  // Normal PyreChat entry is YYYYMMDD.
  if (firstFour >= 1900 && firstFour <= currentYear) {
    return '${digits.substring(0, 4)}-${digits.substring(4, 6)}-${digits.substring(6, 8)}';
  }

  // Be friendly to US-style autofill/paste that arrives as MMDDYYYY.
  if (lastFour >= 1900 && lastFour <= currentYear) {
    return '${digits.substring(4, 8)}-${digits.substring(0, 2)}-${digits.substring(2, 4)}';
  }

  return '${digits.substring(0, 4)}-${digits.substring(4, 6)}-${digits.substring(6, 8)}';
}

String _pad2(String value) => value.padLeft(2, '0');

/// Numeric birthday formatter that inserts separators automatically.
class BirthdayInputFormatter extends TextInputFormatter {
  const BirthdayInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(_nonDigits, '');
    var digitsBeforeCursor = newValue.selection.extentOffset <= 0
        ? 0
        : newValue.text
            .substring(
              0,
              newValue.selection.extentOffset.clamp(0, newValue.text.length),
            )
            .replaceAll(_nonDigits, '')
            .length;

    final oldDigits = oldValue.text.replaceAll(_nonDigits, '');

    // If backspace targeted one of our generated separators, remove the digit
    // immediately before it instead of making the user press backspace twice.
    if (newValue.text.length < oldValue.text.length &&
        digits.length == oldDigits.length &&
        digits.isNotEmpty &&
        digitsBeforeCursor > 0) {
      final removeAt = (digitsBeforeCursor - 1).clamp(0, digits.length - 1);
      digits = digits.substring(0, removeAt) + digits.substring(removeAt + 1);
      digitsBeforeCursor = removeAt;
    }

    if (digits.length > 8) {
      digits = digits.substring(0, 8);
    }
    if (digitsBeforeCursor > digits.length) {
      digitsBeforeCursor = digits.length;
    }

    final normalized = normalizeBirthdayInput(newValue.text);
    final looksLikeExternalCompleteDate =
        digits.length == 8 &&
        (newValue.text.length == 8 ||
            RegExp(r'[/\.\s]').hasMatch(newValue.text) ||
            RegExp(r'^\d{1,2}-\d{1,2}-\d{4}$').hasMatch(newValue.text));

    if (normalized != null && looksLikeExternalCompleteDate) {
      return TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }

    final formatted = formatBirthdayDigits(digits);
    var cursor = _offsetAfterDigits(formatted, digitsBeforeCursor);
    if (cursor < formatted.length && formatted[cursor] == '-') {
      cursor++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}

int _offsetAfterDigits(String formatted, int digitCount) {
  if (digitCount <= 0) return 0;

  var seen = 0;
  for (var i = 0; i < formatted.length; i++) {
    if (formatted.codeUnitAt(i) >= 48 && formatted.codeUnitAt(i) <= 57) {
      seen++;
      if (seen == digitCount) {
        return i + 1;
      }
    }
  }
  return formatted.length;
}
