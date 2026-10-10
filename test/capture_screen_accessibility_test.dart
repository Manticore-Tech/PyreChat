import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/screens/capture/capture_screen.dart';

void main() {
  testWidgets('camera loading state announces progress accessibly', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: CaptureScreen(active: false),
      ),
    );

    expect(find.bySemanticsLabel('Loading camera'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('desktop camera fallback announces the blocking reason', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: CaptureScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.bySemanticsLabel(RegExp(r'^Camera\. Pyre Camera runs on the Android/iOS alpha build\.')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Pyre Camera runs on the Android/iOS alpha build. '
        'Desktop stays available for the rest of the app preview.',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
