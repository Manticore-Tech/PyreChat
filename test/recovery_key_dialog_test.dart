import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/widgets/recovery_key_dialog.dart';

void main() {
  testWidgets('recovery key must be acknowledged before continuing', (tester) async {
    const recoveryKey = 'pyre-recovery-test-key';

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showRecoveryKeyDialog(
                context: context,
                recoveryKey: recoveryKey,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Save your recovery key'), findsOneWidget);
    expect(find.text(recoveryKey), findsOneWidget);
    expect(
      find.text('I saved this recovery key somewhere safe.'),
      findsOneWidget,
    );

    FilledButton savedButton() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, "I've saved it"),
        );

    expect(savedButton().onPressed, isNull);

    await tester.tap(find.text('I saved this recovery key somewhere safe.'));
    await tester.pump();

    expect(savedButton().onPressed, isNotNull);

    await tester.tap(find.text("I've saved it"));
    await tester.pumpAndSettle();

    expect(find.text(recoveryKey), findsNothing);
  });

  testWidgets('recovery key dialog survives compact height and large text', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    const recoveryKey =
        'pyre-recovery-test-key-with-extra-length-for-wrapping-and-accessibility';

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.6),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showRecoveryKeyDialog(
                context: context,
                recoveryKey: recoveryKey,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.text('Save your recovery key'), findsOneWidget);
    expect(find.text(recoveryKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copied recovery key clears itself after one minute', (tester) async {
    const recoveryKey = 'pyre-recovery-test-key';
    String? clipboard;

    await copyRecoveryKeyToClipboard(
      recoveryKey,
      readClipboard: () async => clipboard,
      writeClipboard: (text) async {
        clipboard = text;
      },
    );

    expect(clipboard, recoveryKey);

    await tester.pump(recoveryClipboardLifetime);
    await tester.pump();

    expect(clipboard, isEmpty);
  });

  testWidgets('clipboard guard does not erase content copied afterward', (
    tester,
  ) async {
    const recoveryKey = 'pyre-recovery-test-key';
    const laterClipboardText = 'something else';
    String? clipboard;

    await copyRecoveryKeyToClipboard(
      recoveryKey,
      clearAfter: const Duration(seconds: 1),
      readClipboard: () async => clipboard,
      writeClipboard: (text) async {
        clipboard = text;
      },
    );
    clipboard = laterClipboardText;

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(clipboard, laterClipboardText);
  });
}
