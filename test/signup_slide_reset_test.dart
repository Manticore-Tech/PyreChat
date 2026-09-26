import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/auth/auth_form_state.dart';
import 'package:pyrechat_flutter/pages/onboarding/widgets/onboarding_signup_slide.dart';

void main() {
  testWidgets('signup reset clears the visible field as well as backing state', (
    tester,
  ) async {
    final forms = AuthFormState();
    final key = GlobalKey<OnboardingSignupSlideState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingSignupSlide(
            key: key,
            forms: forms,
            onChanged: () {},
            onSubmit: () {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'Old Name');
    expect(forms.displayName, 'Old Name');

    forms.resetSignup();
    key.currentState!.resetToFirstStep();
    await tester.pump();

    expect(forms.displayName, isEmpty);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text,
      isEmpty,
    );
  });
}
