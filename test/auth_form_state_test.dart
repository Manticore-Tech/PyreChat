import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/auth/auth_form_state.dart';
import 'package:pyrechat_flutter/auth/signup_step.dart';

void main() {
  test('resetSignup clears stale signup data and returns to first step', () {
    final forms = AuthFormState()
      ..signupStep = SignupStep.password
      ..displayName = 'Max'
      ..signupUsername = 'max.pyre'
      ..birthday = '2001-01-30'
      ..signupPassword = 'secret password'
      ..signupError = 'old error'
      ..signupBusy = true;

    forms.resetSignup();

    expect(forms.signupStep, SignupStep.displayName);
    expect(forms.displayName, isEmpty);
    expect(forms.signupUsername, isEmpty);
    expect(forms.birthday, isEmpty);
    expect(forms.signupPassword, isEmpty);
    expect(forms.signupError, isNull);
    expect(forms.signupBusy, isFalse);
  });
}
