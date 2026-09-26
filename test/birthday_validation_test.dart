import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/auth/birthday_validation.dart';

void main() {
  final today = DateTime(2026, 9, 16);

  test('accepts a user who is exactly 13 today', () {
    expect(validatePyreBirthday('2013-09-16', today: today), isNull);
  });

  test('rejects a user who turns 13 tomorrow', () {
    expect(
      validatePyreBirthday('2013-09-17', today: today),
      'You must be at least 13 to use PyreChat',
    );
  });

  test('accepts unformatted digits and common pasted date formats', () {
    expect(validatePyreBirthday('20010916', today: today), isNull);
    expect(validatePyreBirthday('09/16/2001', today: today), isNull);
    expect(validatePyreBirthday('2001/9/16', today: today), isNull);
  });

  test('rejects incomplete and impossible dates', () {
    expect(
      validatePyreBirthday('2001-09', today: today),
      'Enter a valid birthday',
    );
    expect(
      validatePyreBirthday('02/31/2001', today: today),
      'Enter a valid birthday',
    );
  });

  test('rejects a birthday in the future', () {
    expect(
      validatePyreBirthday('2030-01-01', today: today),
      'Enter a valid birthday',
    );
  });
}
