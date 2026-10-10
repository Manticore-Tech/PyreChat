import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/widgets/send_snap_sheet.dart';

void main() {
  testWidgets('Pyre composer icon actions expose accessible labels', (tester) async {
    final imageBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Z6KAAAAAASUVORK5CYII=',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  showSendSnapSheet(
                    context: context,
                    imageBytes: imageBytes,
                    conversationId: 'chat-1',
                    recipientIds: const ['friend-1'],
                    recipientLabel: 'Test Friend',
                  );
                },
                child: const Text('Open composer'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open composer'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Close Pyre composer'), findsOneWidget);
    expect(find.bySemanticsLabel('Add caption'), findsOneWidget);
    expect(find.bySemanticsLabel('Choose recipients'), findsOneWidget);
    expect(find.bySemanticsLabel('Save to device'), findsOneWidget);
  });
}
