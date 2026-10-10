import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/capture/pyre_grades.dart';
import 'package:pyrechat_flutter/capture/pyre_lenses.dart';
import 'package:pyrechat_flutter/screens/capture/capture_hud.dart';

void main() {
  Widget buildHud({bool cameraKitConfigured = false}) {
    return MaterialApp(
      home: Scaffold(
        body: CaptureHud(
          lens: PyreLensId.none,
          customLens: null,
          customLenses: const [],
          grade: PyreGradeId.none,
          busy: false,
          lastShot: null,
          onLensSelected: (_) {},
          onCustomLensSelected: (_) {},
          onOpenStudio: () {},
          onGradeSelected: (_) {},
          onCapture: () {},
          onFlip: () {},
          onOpenCameraKit: () {},
          cameraKitConfigured: cameraKitConfigured,
          onGoChats: () {},
          onGoProfile: () {},
        ),
      ),
    );
  }

  testWidgets('camera HUD exposes only available labeled controls',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(buildHud());

    expect(find.bySemanticsLabel('Open Snap Camera Kit lenses'), findsNothing);
    for (final label in ['Color filters', 'Switch camera']) {
      final control = find.bySemanticsLabel(label);
      expect(control, findsOneWidget);
      final size = tester.getSize(control);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }

    expect(find.bySemanticsLabel('Lens Off'), findsOneWidget);
    expect(find.bySemanticsLabel('Make a lens'), findsOneWidget);
    semanticsHandle.dispose();
  });

  testWidgets('configured Camera Kit is discoverable as a Lenses control',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(buildHud(cameraKitConfigured: true));

    expect(find.text('Lenses'), findsOneWidget);
    final control = find.bySemanticsLabel('Open Snap Camera Kit lenses');
    expect(control, findsOneWidget);
    final size = tester.getSize(control);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    semanticsHandle.dispose();
  });

  testWidgets('color filter choices expose selected semantics', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(buildHud());

    await tester.tap(find.bySemanticsLabel('Color filters'));
    await tester.pumpAndSettle();

    final original = find.bySemanticsLabel('Color filter Original');
    expect(original, findsOneWidget);

    expect(
      tester.getSemantics(original),
      matchesSemantics(
        label: 'Color filter Original',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    semanticsHandle.dispose();
  });
}
