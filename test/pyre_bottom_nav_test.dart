import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/widgets/pyre_bottom_nav.dart';

void main() {
  testWidgets('bottom navigation routes taps to the selected tab',
      (tester) async {
    var selected = -1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: PyreBottomNav(
            selectedIndex: 0,
            onSelected: (index) => selected = index,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Camera'));
    await tester.pump();

    expect(selected, 1);
  });

  testWidgets('bottom navigation tolerates large accessibility text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.5),
          ),
          child: Scaffold(
            bottomNavigationBar: PyreBottomNav(
              selectedIndex: 2,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });
}
