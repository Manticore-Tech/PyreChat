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
    expect(find.text("I've saved it"), findsOneWidget);

    await tester.tap(find.text("I've saved it"));
    await tester.pumpAndSettle();

    expect(find.text(recoveryKey), findsNothing);
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
