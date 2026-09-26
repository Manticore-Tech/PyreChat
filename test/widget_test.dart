import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/widgets/pyre_logo.dart';

void main() {
  testWidgets('canonical PyreFire renders from the app asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PyreLogo(size: 160),
          ),
        ),
      ),
    );

    expect(find.byType(PyreLogo), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
