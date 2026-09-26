import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/widgets/logout_dialog.dart';

void main() {
  testWidgets('logout dialog warns about one unsent draft', (tester) async {
    var confirmed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                confirmed = await confirmLogout(context, draftCount: 1);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Log out of PyreChat?'), findsOneWidget);
    expect(
      find.text(
        'You have 1 unsent draft. Logging out will clear it from this device.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(confirmed, isFalse);
    expect(find.text('Log out of PyreChat?'), findsNothing);
  });

  testWidgets('logout dialog confirms and pluralizes draft warning', (
    tester,
  ) async {
    bool? confirmed;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                confirmed = await confirmLogout(context, draftCount: 3);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'You have 3 unsent drafts. Logging out will clear them from this device.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
  });
}
