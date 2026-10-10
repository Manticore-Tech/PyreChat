import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/pages/onboarding/widgets/onboarding_choice_slide.dart';
import 'package:pyrechat_flutter/widgets/pyre_campfire_backdrop.dart';
import 'package:pyrechat_flutter/widgets/login_panel.dart';
import 'package:pyrechat_flutter/widgets/signup_question.dart';

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
    expect(find.text('Pyre Social'), findsOneWidget);
    expect(find.text('Chats, Pyres, and your people.'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);

    await tester.tap(find.text('Log in'));
    await tester.pump();
    expect(loginTapped, isTrue);

    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(signupTapped, isTrue);
  });
  testWidgets('login fields own typing state without parent rebuilds', (tester) async {
    var username = '';
    var password = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginPanel(
            username: '',
            password: '',
            onUsernameChanged: (value) => username = value,
            onPasswordChanged: (value) => password = value,
            onSubmit: () {},
            busy: false,
          ),
        ),
      ),
    );

    FilledButton loginButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Log in'));

    expect(loginButton().onPressed, isNull);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'max');
    await tester.pump();
    expect(username, 'max');
    expect(loginButton().onPressed, isNull);

    await tester.enterText(fields.at(1), 'password123');
    await tester.pump();
    expect(password, 'password123');
    expect(loginButton().onPressed, isNotNull);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('login password visibility toggle is accessible and reversible',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginPanel(
            username: 'max',
            password: 'password123',
            onUsernameChanged: (_) {},
            onPasswordChanged: (_) {},
            onSubmit: () {},
            busy: false,
          ),
        ),
      ),
    );

    TextField passwordField() => tester.widget<TextField>(find.byType(TextField).at(1));

    expect(passwordField().obscureText, isTrue);
    expect(find.byTooltip('Show password'), findsOneWidget);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();

    expect(passwordField().obscureText, isTrue);
    expect(find.byTooltip('Show password'), findsOneWidget);
  });

  testWidgets('auth errors are announced as accessibility live regions',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginPanel(
            username: 'max',
            password: 'password123',
            onUsernameChanged: (_) {},
            onPasswordChanged: (_) {},
            onSubmit: () {},
            busy: false,
            error: 'Invalid username or password',
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(
        find.bySemanticsLabel(
          'Login error: Invalid username or password',
        ),
      ),
      matchesSemantics(
        label: 'Login error: Invalid username or password',
        isLiveRegion: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignupQuestion(
            title: 'Choose a username',
            input: const TextField(),
            onNext: () {},
            error: 'That username is already taken',
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(
        find.bySemanticsLabel(
          'Sign up error: That username is already taken',
        ),
      ),
      matchesSemantics(
        label: 'Sign up error: That username is already taken',
        isLiveRegion: true,
      ),
    );

    semantics.dispose();
  });

  testWidgets('busy login keeps an accessible progress label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginPanel(
            username: 'max',
            password: 'password123',
            onUsernameChanged: (_) {},
            onPasswordChanged: (_) {},
            onSubmit: () {},
            busy: true,
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Logging in')),
      matchesSemantics(
        label: 'Logging in',
        isButton: true,
        hasEnabledState: true,
        isLiveRegion: true,
      ),
    );

    semantics.dispose();
  });

}
