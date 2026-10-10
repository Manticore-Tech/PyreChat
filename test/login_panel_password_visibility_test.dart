import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/widgets/login_panel.dart';

Widget _login({
  required VoidCallback onSubmit,
  bool busy = false,
  String? error,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: LoginPanel(
          username: 'ember',
          password: '',
          onUsernameChanged: (_) {},
          onPasswordChanged: (_) {},
          onSubmit: onSubmit,
          busy: busy,
          error: error,
        ),
      ),
    ),
  );
}

TextField _passwordField(WidgetTester tester) {
  return tester.widget<TextField>(
    find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Password',
    ),
  );
}

void main() {
  testWidgets('login hides password by default and preserves it when toggled',
      (tester) async {
    var submissions = 0;
    await tester.pumpWidget(_login(onSubmit: () => submissions++));
    await tester.pump();

    expect(_passwordField(tester).obscureText, isTrue);
    expect(find.byTooltip('Show password'), findsOneWidget);

    final password = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Password',
    );
    await tester.enterText(password, 'example-value');
    await tester.pump();

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(_passwordField(tester).obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
    expect(tester.widget<TextField>(password).controller?.text, 'example-value');

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(_passwordField(tester).obscureText, isTrue);
    expect(tester.widget<TextField>(password).controller?.text, 'example-value');

    await tester.tap(find.text('Log in'));
    await tester.pump();
    expect(submissions, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('busy login disables submission and announces the pending state',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var submissions = 0;
    await tester.pumpWidget(
      _login(
        onSubmit: () => submissions++,
        busy: true,
        error: 'Could not log in',
      ),
    );
    await tester.pump();

    final submit = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(submit.onPressed, isNull);
    expect(find.bySemanticsLabel('Logging in'), findsOneWidget);
    expect(find.bySemanticsLabel('Login error: Could not log in'),
        findsOneWidget);
    expect(submissions, 0);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
