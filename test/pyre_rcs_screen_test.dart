import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/screens/chats/pyre_rcs_screen.dart';
import 'package:pyrechat_flutter/services/pyre_rcs.dart';
import 'package:pyrechat_flutter/theme/pyre_colors.dart';

class _TestRcsClient extends PyreRcsClient {
  _TestRcsClient({this.noMessages = false, this.seededMessages})
      : super(accountScope: 'widget-test-user');

  final bool noMessages;
  final List<PyreRcsMessage>? seededMessages;
  final sent = <String>[];
  Completer<void>? sendGate;
  bool previewsOn = true;
  final typingStates = <bool>[];
  final receipts = <({String peer, String id, bool read})>[];

  @override
  String? get handle => 'alice';

  @override
  String? get address => PyreRcsProtocol.sip('alice');

  @override
  Future<void> ready() async {}

  @override
  Future<List<PyreRcsMessage>> history({int maxMessages = 1000}) async {
    if (seededMessages != null) return seededMessages!;
    if (noMessages) return const [];
    return [
      PyreRcsMessage(
        id: 'widget-test-message-01',
        from: 'bob',
        to: 'alice',
        peer: 'bob',
        incoming: true,
        body: 'Hello on RCS',
        mime: 'text/plain; charset=utf-8',
        state: 'stored',
        sequence: 1,
        createdAt: DateTime.utc(2026, 10, 9),
      ),
      PyreRcsMessage(
        id: 'outgoing-test-message-02',
        from: 'alice',
        to: 'bob',
        peer: 'bob',
        incoming: false,
        body: 'Previously sent',
        mime: 'text/plain; charset=utf-8',
        state: 'queued',
        sequence: 2,
        createdAt: DateTime.utc(2026, 10, 9),
      ),
    ];
  }

  @override
  Future<String> status(String originalId) async {
    if (originalId == 'outgoing-test-message-02') return 'delivered';
    return 'unknown';
  }

  @override
  Future<void> connect() async {}

  @override
  Future<Map<String, dynamic>> send(
    String peer, String content, {
    String mime = 'text/plain; charset=utf-8',
    String? messageId,
  }) async {
    if (sendGate != null) await sendGate!.future;
    sent.add(content);
    return {'id': 'sent1234567890', 'state': 'server-accepted'};
  }

  @override
  Future<void> acknowledge(String peer, String originalId, {bool read = false}) async {
    receipts.add((peer: peer, id: originalId, read: read));
  }

  @override
  Future<void> typing(String peer, {required bool active}) async {}

  @override
  Future<bool> notificationPreviewsEnabled() async => previewsOn;

  @override
  Future<bool> setNotificationPreviewsEnabled(bool enabled) async {
    previewsOn = enabled;
    return true;
  }
}

class _FlakyRcsClient extends _TestRcsClient {
  bool failNextSend = true;

  @override
  Future<Map<String, dynamic>> send(
    String peer,
    String content, {
    String mime = 'text/plain; charset=utf-8',
    String? messageId,
  }) async {
    if (failNextSend) {
      failNextSend = false;
      throw StateError('temporary connection failure');
    }
    return super.send(peer, content, mime: mime, messageId: messageId);
  }
}

void main() {
  testWidgets('RCS send failure preserves draft and allows retry',
      (tester) async {
    final client = _FlakyRcsClient();
    await tester.pumpWidget(
      MaterialApp(home: PyreRcsThreadScreen(client: client, peer: 'bob')),
    );
    await tester.pumpAndSettle();
    final composer = find.byKey(const Key('rcs_composer'));
    final send = find.byKey(const Key('rcs_send'));
    await tester.enterText(composer, 'Unsent message');
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('RCS send failed. Retry.'), findsOneWidget);
    expect(tester.widget<TextField>(composer).controller?.text, 'Unsent message');
    expect(client.sent, isEmpty);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(client.sent, ['Unsent message']);
    expect(tester.widget<TextField>(composer).controller?.text, isEmpty);
    expect(find.text('RCS send failed. Retry.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });

  test('RCS receipt wording never treats server acceptance as delivery', () {
    expect(PyreRcsProtocol.messageStatusLabel('queued'), 'Sent');
    expect(PyreRcsProtocol.messageStatusLabel('server-accepted'), 'Sent');
    expect(PyreRcsProtocol.messageStatusLabel('delivered'), 'Delivered');
    expect(PyreRcsProtocol.messageStatusLabel('displayed'), 'Read');
  });

  testWidgets('RCS home shows conversations first and keeps identity in account sheet',
      (tester) async {
    final client = _TestRcsClient();
    await tester.pumpWidget(
      MaterialApp(
        home: PyreRcsInboxScreen(
          user: const PyreUser(
            id: 'user-1',
            username: 'tester',
            displayName: 'Tester',
          ),
          client: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.byKey(const Key('rcs_peer_bob')), findsOneWidget);
    expect(find.text('Previously sent'), findsOneWidget);
    expect(find.byKey(const Key('rcs_new_message')), findsOneWidget);
    expect(find.byKey(const Key('rcs_peer_handle')), findsNothing);
    expect(find.text('Direct to PyreSocial Messaging'), findsNothing);
    // Visiting only the inbox MUST NOT mark a conversation as read.
    expect(client.receipts.where((r) => r.read), isEmpty);
    expect(client.receipts.where((r) => !r.read), isNotEmpty);

    // The long technical address stays available, but off the main inbox.
    await tester.tap(find.byKey(const Key('rcs_account')));
    await tester.pumpAndSettle();
    expect(find.text('Your address'), findsOneWidget);
    expect(find.text('sip:alice@messages.pyre.social'), findsOneWidget);
    expect(find.byKey(const Key('rcs_copy_address')), findsOneWidget);
    expect(
      find.text('RCS text is not yet end-to-end encrypted. Do not send sensitive content.'),
      findsOneWidget,
    );
    // Dismiss the sheet explicitly; clipboard platform calls are not mocked
    // in this navigation smoke test.
    Navigator.of(tester.element(find.byKey(const Key('rcs_copy_address')))).pop();
    await tester.pumpAndSettle();

    // New message is a dedicated, validated Material 3 entry flow.
    await tester.tap(find.byKey(const Key('rcs_new_message')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rcs_peer_handle')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('rcs_peer_handle')),
      'sip:bob@messages.pyre.social',
    );
    await tester.tap(find.byKey(const Key('rcs_open_peer')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rcs_composer')), findsOneWidget);
    expect(find.text('Hello on RCS'), findsOneWidget);
    // Opening the thread auto-marks fetched messages as read, no bubble tap.
    expect(client.receipts.where((r) => r.read), isNotEmpty);
    expect(find.text('Tap to acknowledge read'), findsNothing);
    expect(find.text('Previously sent'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('RCS chat · Not end-to-end encrypted'), findsOneWidget);
    final incoming = tester.widget<Container>(
      find.byKey(const Key('rcs_bubble_widget-test-message-01')),
    );
    final outgoing = tester.widget<Container>(
      find.byKey(const Key('rcs_bubble_outgoing-test-message-02')),
    );
    final incomingCorners =
        (incoming.decoration! as BoxDecoration).borderRadius! as BorderRadius;
    final outgoingCorners =
        (outgoing.decoration! as BoxDecoration).borderRadius! as BorderRadius;
    expect(incomingCorners.bottomLeft, const Radius.circular(7));
    expect(incomingCorners.bottomRight, const Radius.circular(22));
    expect(outgoingCorners.bottomLeft, const Radius.circular(22));
    expect(outgoingCorners.bottomRight, const Radius.circular(7));
    // Received and sent text must support native long-press selection/copy.
    final incomingSelectable = find.descendant(
      of: find.byKey(const Key('rcs_bubble_widget-test-message-01')),
      matching: find.byType(SelectableText),
    );
    final outgoingSelectable = find.descendant(
      of: find.byKey(const Key('rcs_bubble_outgoing-test-message-02')),
      matching: find.byType(SelectableText),
    );
    expect(incomingSelectable, findsOneWidget);
    expect(outgoingSelectable, findsOneWidget);
    expect(tester.widget<SelectableText>(incomingSelectable).data, 'Hello on RCS');
    expect(tester.widget<SelectableText>(outgoingSelectable).data, 'Previously sent');
    await tester.enterText(find.byKey(const Key('rcs_composer')), 'Hello back!');
    // Rebuild the ValueListenableBuilder before tapping the enabled action.
    await tester.pump();
    await tester.tap(find.byKey(const Key('rcs_send')));
    await tester.pumpAndSettle();
    expect(client.sent, contains('Hello back!'));
    expect(tester.widget<TextField>(find.byKey(const Key('rcs_composer')))
        .controller?.text, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });

  testWidgets('compact RCS compose sheet stays usable above the keyboard',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.view.resetViewInsets();
    });

    final client = _TestRcsClient(noMessages: true);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.4),
          ),
          child: child!,
        ),
        home: PyreRcsInboxScreen(client: client),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rcs_new_message')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rcs_peer_handle')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const Key('rcs_peer_handle')),
      'sip:bob@messages.pyre.social',
    );
    // The compact sheet uses a lazily built scroll view when the keyboard is
    // large. Scroll until Continue is built, then verify it can be tapped.
    await tester.scrollUntilVisible(
      find.byKey(const Key('rcs_open_peer')),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('rcs_open_peer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rcs_composer')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });

  testWidgets('Android notification preview switch defaults on and turns off',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final client = _TestRcsClient(noMessages: true);
    await tester.pumpWidget(MaterialApp(home: PyreRcsInboxScreen(client: client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rcs_notification_settings')));
    await tester.pumpAndSettle();
    final control = find.byKey(const Key('rcs_notification_previews_switch'));
    expect(control, findsOneWidget);
    expect(tester.widget<SwitchListTile>(control).value, isTrue);
    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(client.previewsOn, isFalse);
    expect(tester.widget<SwitchListTile>(control).value, isFalse);
    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });


  testWidgets('RCS send action requires a nonblank draft and locks during send',
      (tester) async {
    final client = _TestRcsClient();
    final gate = Completer<void>();
    client.sendGate = gate;
    await tester.pumpWidget(
      MaterialApp(home: PyreRcsThreadScreen(client: client, peer: 'bob')),
    );
    await tester.pumpAndSettle();

    final send = find.byKey(const Key('rcs_send'));
    final composer = find.byKey(const Key('rcs_composer'));
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    await tester.enterText(composer, '   ');
    await tester.pump();
    expect(tester.widget<IconButton>(send).onPressed, isNull);

    await tester.enterText(composer, 'Ready to send');
    await tester.pump();
    expect(tester.widget<IconButton>(send).onPressed, isNotNull);
    await tester.tap(send);
    await tester.pump();
    expect(tester.widget<IconButton>(send).onPressed, isNull);

    gate.complete();
    await tester.pumpAndSettle();
    expect(client.sent, ['Ready to send']);
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });

  testWidgets('RCS composer text stays readable in light ambient theme',
      (tester) async {
    final client = _TestRcsClient();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: PyreRcsThreadScreen(client: client, peer: 'bob'),
      ),
    );
    await tester.pumpAndSettle();
    final composer = tester.widget<TextField>(
      find.byKey(const Key('rcs_composer')),
    );
    expect(composer.style?.color, PyreColors.nightText);
    expect(composer.cursorColor, PyreColors.emberGlow);
    expect(composer.decoration?.filled, isTrue);
    expect(composer.decoration?.fillColor, PyreColors.nightCardStrong);
    expect(composer.decoration?.hintStyle?.color, PyreColors.nightMuted);
    expect(composer.maxLines, 4);
    await tester.enterText(find.byKey(const Key('rcs_composer')),
        'Text I can actually read');
    await tester.pump();
    expect(find.text('Text I can actually read'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });

  testWidgets('keyboard shrinks thread and composer stays above it',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 820);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.view.resetViewInsets();
    });
    final client = _TestRcsClient();
    await tester.pumpWidget(
      MaterialApp(home: PyreRcsThreadScreen(client: client, peer: 'bob')),
    );
    await tester.pumpAndSettle();
    final composer = find.byKey(const Key('rcs_composer'));
    final thread = find.byKey(const Key('rcs_thread_messages'));
    expect(tester.widget<ListView>(thread).reverse, isTrue);
    final initialBottom = tester.getBottomRight(composer).dy;
    final initialThreadHeight = tester.getSize(thread).height;
    await tester.tap(composer);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(composer).dy,
        lessThan(initialBottom - 180));
    expect(tester.getSize(thread).height,
        lessThan(initialThreadHeight - 180));
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: thread, matching: find.byType(Scrollable)).first,
    );
    expect(scroll.position.pixels, closeTo(0, 1));
    expect(find.text('Previously sent'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });

  testWidgets('opening keyboard preserves position in older RCS messages',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 820);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.view.resetViewInsets();
    });
    final history = List.generate(45, (index) => PyreRcsMessage(
      id: 'older-message-${index.toString().padLeft(3, '0')}',
      from: 'bob',
      to: 'alice',
      peer: 'bob',
      incoming: true,
      body: 'Historical message ${index + 1}',
      mime: 'text/plain; charset=utf-8',
      state: 'stored',
      sequence: index + 1,
      createdAt: DateTime.utc(2026, 10, 10),
    ));
    final client = _TestRcsClient(seededMessages: history);
    await tester.pumpWidget(
      MaterialApp(home: PyreRcsThreadScreen(client: client, peer: 'bob')),
    );
    await tester.pumpAndSettle();
    final thread = find.byKey(const Key('rcs_thread_messages'));
    final scroller = tester.state<ScrollableState>(
      find.descendant(of: thread, matching: find.byType(Scrollable)).first,
    );
    expect(scroller.position.pixels, closeTo(0, 1));
    await tester.drag(thread, const Offset(0, 260));
    await tester.pumpAndSettle();
    final readingPosition = scroller.position.pixels;
    expect(readingPosition, greaterThan(30));
    // Keyboard/viewport resizing must not jump the reader to the latest text.
    tester.view.viewInsets = const FakeViewPadding(bottom: 270);
    await tester.pumpAndSettle();
    expect(scroller.position.pixels, closeTo(readingPosition, 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });

  testWidgets('empty RCS inbox has no exposed technical form or fake number',
      (tester) async {
    final client = _TestRcsClient(noMessages: true);
    await tester.pumpWidget(
      MaterialApp(home: PyreRcsInboxScreen(client: client)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No conversations yet'), findsOneWidget);
    expect(find.byKey(const Key('rcs_new_message')), findsOneWidget);
    expect(find.byKey(const Key('rcs_peer_handle')), findsNothing);
    expect(find.textContaining('sip:alice'), findsNothing);
    expect(find.textContaining('Pyre Number'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('RCS send completion preserves a draft typed during network wait',
      (tester) async {
    final client = _TestRcsClient();
    final gate = Completer<void>();
    client.sendGate = gate;
    await tester.pumpWidget(
      MaterialApp(home: PyreRcsThreadScreen(client: client, peer: 'bob')),
    );
    await tester.pumpAndSettle();
    final composer = find.byKey(const Key('rcs_composer'));
    await tester.enterText(composer, 'First message');
    // Rebuild the ValueListenableBuilder before tapping the enabled action.
    await tester.pump();
    await tester.tap(find.byKey(const Key('rcs_send')));
    await tester.pump();
    await tester.enterText(composer, 'Second draft while sending');
    gate.complete();
    await tester.pumpAndSettle();
    expect(client.sent, ['First message']);
    expect(tester.widget<TextField>(composer).controller?.text,
        'Second draft while sending');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });

}
