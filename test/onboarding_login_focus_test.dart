import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/pages/onboarding/onboarding_page.dart';
import 'package:pyrechat_flutter/widgets/login_panel.dart';

Finder usernameField() => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Username',
    );

void configurePhone(WidgetTester tester) {
  const dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = const Size(360 * dpr, 780 * dpr);
  tester.view.viewInsets = const FakeViewPadding();
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    tester.view.resetViewInsets();
  });
}

Future<void> openLogin(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OnboardingPage(onAuthenticated: (_) {}),
    ),
  );
  await tester.tap(find.text('Log in').hitTestable().first);
  await tester.pump(const Duration(milliseconds: 1300));
  expect(find.text('Welcome back').hitTestable(), findsOneWidget);
}

void main() {
  testWidgets('hidden intro cannot navigate away from active login', (tester) async {
    configurePhone(tester);
    await openLogin(tester);
    await tester.tap(usernameField().hitTestable());
    await tester.pump();

    // The old always-mounted intro used to navigate back to choice at 3 seconds.
    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Welcome back').hitTestable(), findsOneWidget);
    expect(usernameField().hitTestable(), findsOneWidget);
  });

  testWidgets('keyboard resize preserves login field state and focus',
      (tester) async {
    configurePhone(tester);
    await openLogin(tester);

    final username = usernameField().hitTestable();
    await tester.tap(username);
    await tester.enterText(username, 'phoenix');
    await tester.pump();
    final initialPanelState = tester.state(find.byType(LoginPanel));
    final initialEditing = tester.widget<EditableText>(
      find.descendant(of: username, matching: find.byType(EditableText)),
    );
    expect(initialEditing.focusNode.hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 330 * 3);
    await tester.pump();

    expect(identical(tester.state(find.byType(LoginPanel)), initialPanelState), isTrue);
    final editing = tester.widget<EditableText>(
      find.descendant(of: usernameField(), matching: find.byType(EditableText)),
    );
    expect(editing.focusNode.hasFocus, isTrue);
    expect(tester.widget<TextField>(usernameField()).controller?.text, 'phoenix');
    expect(tester.takeException(), isNull);
  });
}
