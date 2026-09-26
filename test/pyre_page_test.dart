import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/screens/pyre/pyre_page_screen.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

void main() {
  testWidgets(
      'My Pyre is a quiet per-account surface with no engagement-loop controls',
      (tester) async {
    const user = PyreUser(
      id: 'u1',
      username: 'max',
      displayName: 'Max',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: pyreTheme(),
        home: const Scaffold(
          body: PyrePageScreen(user: user),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('My Pyre'), findsOneWidget);
    expect(find.text('Quiet by design'), findsOneWidget);
    expect(find.text('Max'), findsOneWidget);
    expect(find.text('@max'), findsOneWidget);
    expect(find.text('Moments'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Chat room'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Mail'), findsOneWidget);
    expect(find.text('Chat room'), findsOneWidget);

    expect(find.text('The Pyre'), findsNothing);
    expect(find.text('Pull up a chair'), findsNothing);
    expect(find.text('Head out'), findsNothing);
    expect(find.byType(TextField), findsNothing);

    expect(tester.takeException(), isNull);
  });
}
