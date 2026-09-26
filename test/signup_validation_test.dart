import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/auth/signup_validation.dart';

void main() {
  group('display name validation', () {
    test('requires a visible name', () {
      expect(validateDisplayName('   '), isNotNull);
      expect(validateDisplayName('Phoenix'), isNull);
    });

    test('rejects control characters and excessive length', () {
      expect(validateDisplayName('A\u0000B'), isNotNull);
      expect(validateDisplayName('x' * 51), isNotNull);
    });
  });

  group('username validation', () {
    test('matches the 3-24 character UI contract', () {
      expect(validateUsername('ab'), isNotNull);
      expect(validateUsername('abc'), isNull);
      expect(validateUsername('a' * 24), isNull);
      expect(validateUsername('a' * 25), isNotNull);
    });

    test('accepts only letters numbers dots and underscores', () {
      expect(validateUsername('max.pyre_01'), isNull);
      expect(validateUsername('max-pyre'), isNotNull);
      expect(validateUsername('max pyre'), isNotNull);
    });
  });

  group('password validation', () {
    test('allows long passphrases without arbitrary complexity rules', () {
      expect(validateSignupPassword('1234567'), isNotNull);
      expect(validateSignupPassword('correct horse battery staple'), isNull);
      expect(validateSignupPassword('x' * 129), isNotNull);
    });
  });
}
