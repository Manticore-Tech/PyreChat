import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/pages/onboarding/widgets/onboarding_choice_slide.dart';
import 'package:pyrechat_flutter/widgets/pyre_campfire_backdrop.dart';

void main() {
  testWidgets('launch screen exposes primary auth choices', (tester) async {
    var loginTapped = false;
    var signupTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingChoiceSlide(
            onLogin: () => loginTapped = true,
            onSignup: () => signupTapped = true,
          ),
        ),
      ),
    );

    expect(find.byType(PyreCampfireBackdrop), findsOneWidget);
    expect(find.text('PyreChat'), findsOneWidget);
    expect(find.text('Private conversations, yours to keep.'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);

    await tester.tap(find.text('Log in'));
    await tester.pump();
    expect(loginTapped, isTrue);

    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(signupTapped, isTrue);
  });
}
