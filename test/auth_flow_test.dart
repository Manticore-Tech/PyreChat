import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/features/auth/widgets/idle_flame_view.dart';
import 'package:pyrechat_flutter/pages/onboarding/widgets/onboarding_choice_slide.dart';
import 'package:pyrechat_flutter/widgets/pyre_logo.dart';

void main() {
  testWidgets('PyreFire splits into the two auth choices', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingChoiceSlide(
            onLogin: () {},
            onSignup: () {},
          ),
        ),
      ),
    );

    expect(find.byType(IdleFlameView), findsOneWidget);
    expect(find.byType(PyreLogo), findsOneWidget);

    await tester.tap(find.byType(IdleFlameView));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.byType(IdleFlameView), findsNothing);
    expect(find.byType(PyreLogo), findsNWidgets(2));
  });
}
