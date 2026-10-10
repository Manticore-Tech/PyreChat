import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/capture/pyre_grades.dart';
import 'package:pyrechat_flutter/capture/pyre_lenses.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/chat_message.dart';
import 'package:pyrechat_flutter/models/chat_preview.dart';
import 'package:pyrechat_flutter/models/friend.dart';
import 'package:pyrechat_flutter/models/friend_adds.dart';
import 'package:pyrechat_flutter/models/snap_detail.dart';
import 'package:pyrechat_flutter/models/session.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/pages/onboarding/onboarding_page.dart';
import 'package:pyrechat_flutter/pages/onboarding/widgets/onboarding_login_slide.dart';
import 'package:pyrechat_flutter/screens/capture/capture_hud.dart';
import 'package:pyrechat_flutter/screens/chats/add_friends_screen.dart';
import 'package:pyrechat_flutter/screens/app_shell_screen.dart';
import 'package:pyrechat_flutter/screens/chats/chat_thread_screen.dart';
import 'package:pyrechat_flutter/screens/chats/chats_screen.dart';
import 'package:pyrechat_flutter/screens/chats/snap_viewer_screen.dart';
import 'package:pyrechat_flutter/screens/lens/lens_studio_screen.dart';
import 'package:pyrechat_flutter/screens/profile/profile_screen.dart';
import 'package:pyrechat_flutter/screens/profile/sessions_screen.dart';
import 'package:pyrechat_flutter/screens/profile/settings_screen.dart';
import 'package:pyrechat_flutter/screens/pyre/friend_pyre_screen.dart';
import 'package:pyrechat_flutter/screens/pyre/pyre_page_screen.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/services/pyre_hub.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/chat_row.dart';
import 'package:pyrechat_flutter/widgets/pyre_bottom_nav.dart';
import 'package:pyrechat_flutter/widgets/signup_question.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFriendsClient extends PyreClient {
  static const longFriend = PyreFriend(
    id: 'friend-1',
    username: 'avery_long_username_that_should_ellipsize',
    displayName: 'A Very Long Display Name That Must Stay Inside The Row',
  );

  @override
  Future<FriendAddsBundle> friendAdds() async {
    return const FriendAddsBundle(
      incoming: [longFriend],
      sent: [longFriend],
      hidden: [longFriend],
      deleted: [longFriend],
      suggestions: [longFriend],
    );
  }

  @override
  Future<List<PyreFriend>> searchUsers(String query) async => const [longFriend];

  @override
  Future<String> addFriend({String? username, String? userId}) async => 'ok';

  @override
  Future<void> dismissFriend({
    required String userId,
    required String kind,
  }) async {}

  @override
  Future<void> restoreFriend(String userId) async {}

  @override
  Future<void> removeFriend(String userId) async {}
}

class _FakeSessionsClient extends PyreClient {
  bool revoked = false;

  @override
  Future<List<PyreSession>> sessions() async => [
        PyreSession(
          id: 'current-session',
          label: 'PyreChat Android',
          current: true,
          deviceId: 'device-current-1234567890',
          createdAt: DateTime.utc(2026, 9, 29, 16, 0),
          expiresAt: DateTime.utc(2026, 10, 29, 16, 0),
        ),
        PyreSession(
          id: 'other-session',
          label: 'PyreChat Web',
          current: false,
          createdAt: DateTime.utc(2026, 9, 28, 12, 0),
          expiresAt: DateTime.utc(2026, 10, 28, 12, 0),
        ),
      ];

  @override
  Future<bool> revokeSession(String sessionId) async {
    revoked = sessionId == 'other-session';
    return false;
  }
}

class _FakeSnapClient extends PyreClient {
  static const detail = SnapDetail(
    id: 'snap-1',
    senderId: 'friend-1',
    kind: 'photo',
    caption:
        'A long caption that should wrap safely on a narrow phone without escaping the visible viewer bounds.',
    mediaUrl: 'https://example.invalid/snap.png',
    displayName:
        'A Very Long Friend Display Name That Must Ellipsize In The Viewer',
  );

  @override
  Future<SnapDetail> getSnap(String snapId) async => detail;

  @override
  Future<void> markSnapViewed(String snapId) async {}

  @override
  Future<Uint8List> fetchSnapMedia(SnapDetail snap) async {
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Z6KAAAAAASUVORK5CYII=',
    );
  }
}

class _FakeChatsClient extends PyreClient {
  @override
  Future<List<ChatPreview>> chats() async => const [
        ChatPreview(
          id: 'chat-top',
          title: 'Palm Beach Pete With A Longer Name',
          preview: 'Made it to the beach earlier today.',
          timeLabel: '2m',
          unread: 2,
          avatarInitials: 'P',
          lastKind: 'text',
          lastSenderId: 'friend-1',
          memberIds: ['me', 'friend-1'],
        ),
        ChatPreview(
          id: 'chat-two',
          title: 'Camp Crew',
          preview: 'Dinner around seven?',
          timeLabel: '1h',
          avatarKind: ChatAvatarKind.group,
          lastKind: 'text',
          lastSenderId: 'friend-2',
          memberIds: ['me', 'friend-2', 'friend-3'],
        ),
      ];
}

class _FakeThreadClient extends PyreClient {
  @override
  Future<List<ChatMessage>> messages(String chatId) async => const [];

  @override
  Future<String> sendMessage({
    required String chatId,
    required String text,
    String? clientId,
  }) async {
    return 'server-message-id';
  }
}

class _NotificationRaceThreadClient extends PyreClient {
  int calls = 0;

  @override
  Future<List<ChatMessage>> messages(String chatId) async {
    calls++;
    if (calls == 1) return const [];
    return const [
      ChatMessage(
        id: 'message-from-push',
        senderId: 'friend-1',
        kind: 'text',
        body: 'Fresh notification message',
        createdAt: '2026-09-29T16:55:00Z',
        displayName: 'Friend',
        username: 'friend',
      ),
    ];
  }
}

void _configurePhone(
  WidgetTester tester, {
  Size logicalSize = const Size(360, 780),
  double dpr = 3,
  double keyboardLogicalHeight = 0,
}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = logicalSize * dpr;
  tester.view.padding = FakeViewPadding(
    top: 24 * dpr,
    bottom: 24 * dpr,
  );
  tester.view.viewInsets = FakeViewPadding(
    bottom: keyboardLogicalHeight * dpr,
  );
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    tester.view.resetPadding();
    tester.view.resetViewInsets();
  });
}

Widget _app(Widget child, {double textScale = 1}) {
  return MaterialApp(
    theme: pyreTheme(),
    builder: (context, appChild) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: appChild!,
      );
    },
    home: child,
  );
}

void _expectNoFlutterError(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('app shell announces offline connection state accessibly',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _configurePhone(tester);
    final semantics = tester.ensureSemantics();

    const user = PyreUser(
      id: 'shell-user',
      username: 'shell.user',
      displayName: 'Shell User',
    );

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: AppConnectionStatusLabel(
            key: ValueKey(user.id),
            status: PyreHubStatus.disconnected,
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0;
        i < 20 && find.bySemanticsLabel('You are offline').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.bySemanticsLabel('You are offline'), findsOneWidget);
    semantics.dispose();
    _expectNoFlutterError(tester);
  });

  testWidgets('login layout survives Samsung-sized viewport', (tester) async {
    _configurePhone(tester);

    await tester.pumpWidget(
      _app(
        Scaffold(
          resizeToAvoidBottomInset: true,
          body: OnboardingLoginSlide(
            username: 'max',
            password: '',
            onUsernameChanged: (_) {},
            onPasswordChanged: (_) {},
            onSubmit: () {},
            busy: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('login layout survives tall software keyboard', (tester) async {
    _configurePhone(tester, keyboardLogicalHeight: 330);

    await tester.pumpWidget(
      _app(
        Scaffold(
          resizeToAvoidBottomInset: true,
          body: OnboardingLoginSlide(
            username: 'max',
            password: '',
            onUsernameChanged: (_) {},
            onPasswordChanged: (_) {},
            onSubmit: () {},
            busy: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets(
      'login stays visible when focusing and typing with the keyboard open',
      (tester) async {
    _configurePhone(tester);

    await tester.pumpWidget(
      _app(
        OnboardingPage(
          onAuthenticated: (_) {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Log in').hitTestable().first);
    await tester.pump(const Duration(milliseconds: 1300));

    final username = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Username',
    ).hitTestable();
    expect(username, findsOneWidget);

    await tester.tap(username);
    tester.view.viewInsets = FakeViewPadding(bottom: 330 * 3);
    await tester.pump();
    await tester.enterText(username, 'max');
    await tester.pump();

    expect(find.text('Welcome back').hitTestable(), findsOneWidget);
    expect(username, findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('signup question survives keyboard and large text', (tester) async {
    _configurePhone(
      tester,
      logicalSize: const Size(360, 780),
      keyboardLogicalHeight: 330,
    );

    await tester.pumpWidget(
      _app(
        Scaffold(
          resizeToAvoidBottomInset: true,
          body: SignupQuestion(
            title: 'When is your birthday?',
            subtitle: 'You need to be at least 13 to use PyreChat.',
            error: 'Enter a real birthday in YYYY-MM-DD format.',
            input: const TextField(
              decoration: InputDecoration(hintText: 'YYYY  MM  DD'),
            ),
            onNext: () {},
          ),
        ),
        textScale: 1.3,
      ),
    );
    await tester.pump();

    expect(find.text('When is your birthday?'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('profile handles compact phone and large identity text', (tester) async {
    _configurePhone(tester, logicalSize: const Size(320, 568));

    const user = PyreUser(
      id: 'u1',
      username: 'avery_long_username_that_should_not_break_layout',
      displayName: 'A Very Long Display Name That Should Wrap Cleanly',
    );

    await tester.pumpWidget(_app(const ProfileScreen(user: user), textScale: 1.25));
    await tester.pump();

    expect(find.text('You'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('settings handles compact phone and long identity', (tester) async {
    _configurePhone(tester, logicalSize: const Size(320, 568));

    const user = PyreUser(
      id: 'u1',
      username: 'avery_long_username_that_should_not_break_layout',
      displayName: 'A Very Long Display Name That Should Wrap Cleanly',
    );

    await tester.pumpWidget(_app(const SettingsScreen(user: user), textScale: 1.25));
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Log out'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Log out'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('settings rows expose accessibility labels', (tester) async {
    _configurePhone(tester);
    final semantics = tester.ensureSemantics();

    const user = PyreUser(
      id: 'u-accessibility',
      username: 'ember.user',
      displayName: 'Ember User',
    );

    await tester.pumpWidget(_app(const SettingsScreen(user: user)));
    await tester.pump();

    expect(find.byTooltip('Back to profile'), findsOneWidget);
    expect(find.bySemanticsLabel('Name & username'), findsOneWidget);
    semantics.dispose();
    _expectNoFlutterError(tester);
  });

  testWidgets('normal users can edit username and admin handle stays locked',
      (tester) async {
    _configurePhone(tester);

    const normalUser = PyreUser(
      id: 'u-normal',
      username: 'ember.user',
      displayName: 'Ember User',
    );

    await tester.pumpWidget(_app(const SettingsScreen(user: normalUser)));
    await tester.pump();
    await tester.tap(find.text('Name & username'));
    await tester.pumpAndSettle();

    TextField usernameField() => tester.widget<TextField>(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Username',
          ),
        );

    expect(usernameField().enabled, isNot(false));
    expect(find.text('Display name'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    const adminUser = PyreUser(
      id: 'u-admin',
      username: 'maximuspyre',
      displayName: 'Maximus Pyre',
    );

    await tester.pumpWidget(_app(const SettingsScreen(user: adminUser)));
    await tester.pump();
    await tester.tap(find.text('Name & username'));
    await tester.pumpAndSettle();

    expect(usernameField().enabled, isFalse);
    expect(find.text('Admin username is fixed.'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('recovery key rotation requires deliberate password confirmation',
      (tester) async {
    _configurePhone(tester, logicalSize: const Size(360, 740));

    const user = PyreUser(
      id: 'u-recovery',
      username: 'ember.user',
      displayName: 'Ember User',
    );

    await tester.pumpWidget(_app(const SettingsScreen(user: user)));
    await tester.pump();

    await tester.tap(find.text('Recovery key'));
    await tester.pumpAndSettle();

    expect(find.text('Replace recovery key?'), findsOneWidget);
    expect(find.text('Current password'), findsOneWidget);
    expect(
      find.textContaining('old recovery key will stop working'),
      findsOneWidget,
    );
    expect(find.text('Replace key'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('signed-in devices marks current session and revokes another',
      (tester) async {
    _configurePhone(tester, logicalSize: const Size(360, 740));
    final semantics = tester.ensureSemantics();
    final client = _FakeSessionsClient();

    await tester.pumpWidget(_app(SessionsScreen(client: client)));
    await tester.pumpAndSettle();

    expect(find.text('Signed-in devices'), findsOneWidget);
    expect(find.text('PyreChat Android'), findsOneWidget);
    expect(find.text('PyreChat Web'), findsOneWidget);
    expect(find.text('THIS DEVICE'), findsOneWidget);
    expect(find.textContaining('Signed in 2026-09-29'), findsOneWidget);
    expect(find.textContaining('Expires 2026-10-29'), findsOneWidget);
    expect(find.textContaining('Signed in 2026-09-28'), findsOneWidget);
    expect(find.textContaining('Expires 2026-10-28'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.byTooltip('Back to settings'), findsOneWidget);
    expect(find.bySemanticsLabel('PyreChat Android, this device'), findsOneWidget);
    expect(find.bySemanticsLabel('Sign out PyreChat Web'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out this session?'), findsOneWidget);

    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();

    expect(client.revoked, isTrue);
    expect(find.text('PyreChat Web'), findsNothing);
    expect(find.text('PyreChat Android'), findsOneWidget);
    semantics.dispose();
    _expectNoFlutterError(tester);
  });

  testWidgets('add friends rows survive narrow phone and large text',
      (tester) async {
    _configurePhone(tester, logicalSize: const Size(320, 568));

    await tester.pumpWidget(
      _app(
        AddFriendsScreen(client: _FakeFriendsClient()),
        textScale: 1.35,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Add Friends'), findsOneWidget);
    expect(find.text('Added Me'), findsOneWidget);
    expect(find.text('Search by username'), findsOneWidget);
    _expectNoFlutterError(tester);

    await tester.tap(find.byType(IconButton).at(1));
    await tester.pumpAndSettle();

    expect(find.text('Ignored requests'), findsOneWidget);
    _expectNoFlutterError(tester);

    await tester.tap(find.text('Hidden suggestions'));
    await tester.pumpAndSettle();

    expect(find.text('Unhide'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    _expectNoFlutterError(tester);

    await tester.tap(find.byType(IconButton).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ignored requests'));
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('chat composer survives narrow phone keyboard and large text',
      (tester) async {
    _configurePhone(
      tester,
      logicalSize: const Size(320, 568),
      keyboardLogicalHeight: 250,
    );

    const me = PyreUser(
      id: 'me',
      username: 'max',
      displayName: 'Max',
    );
    final hub = PyreHub();

    await tester.pumpWidget(
      _app(
        ChatThreadScreen(
          chatId: 'chat-1',
          hub: hub,
          title: 'A Very Long Friend Name That Must Stay Inside The Header',
          me: me,
          client: _FakeThreadClient(),
          onGoCamera: () {},
        ),
        textScale: 1.3,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Message…'), findsOneWidget);
    expect(find.byTooltip('Open camera'), findsOneWidget);
    expect(find.byTooltip('Send message'), findsNothing);
    _expectNoFlutterError(tester);

    await tester.enterText(
      find.byType(TextField).last,
      'This is a long message draft that should not break the composer.',
    );
    await tester.pump();

    expect(find.byTooltip('Send message'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets(
      'notification-open retries a stale first thread fetch and reveals the message',
      (tester) async {
    _configurePhone(tester);

    const me = PyreUser(
      id: 'me',
      username: 'max',
      displayName: 'Max',
    );
    final hub = PyreHub();
    final client = _NotificationRaceThreadClient();

    await tester.pumpWidget(
      _app(
        ChatThreadScreen(
          chatId: 'chat-1',
          hub: hub,
          title: 'Friend',
          me: me,
          client: client,
          openedFromNotification: true,
        ),
      ),
    );

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(client.calls, greaterThanOrEqualTo(2));
    expect(find.text('Fresh notification message'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('chat row survives long real-world data at large text',
      (tester) async {
    _configurePhone(tester, logicalSize: const Size(320, 568));

    const chat = ChatPreview(
      id: 'chat-1',
      title: 'An Extremely Long Friend Display Name That Must Ellipsize',
      preview:
          'A very long preview message that should stay on one line and never push the camera control away.',
      timeLabel: '12/31',
      unread: 99999,
      avatarInitials: 'AF',
      lastKind: 'text',
      lastSenderId: 'friend-1',
      muted: true,
    );

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ChatRow(
            chat: chat,
            meId: 'me',
            onTap: () {},
            onCameraTap: () {},
          ),
        ),
        textScale: 1.35,
      ),
    );
    await tester.pump();

    expect(find.text(chat.title), findsOneWidget);
    expect(find.text('99999'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('dark chats screen survives compact phone and large text',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _configurePhone(tester, logicalSize: const Size(320, 568));

    const user = PyreUser(
      id: 'me',
      username: 'max',
      displayName: 'Max',
    );
    final hub = PyreHub();

    await tester.pumpWidget(
      _app(
        ChatsScreen(
          hub: hub,
          user: user,
          client: _FakeChatsClient(),
          onGoCamera: (_) {},
        ),
        textScale: 1.3,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Chats'), findsWidgets);
    expect(find.text('Palm Beach Pete With A Longer Name'), findsOneWidget);
    expect(find.text('Camp Crew'), findsOneWidget);
    expect(find.text('You’re caught up'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('My Pyre survives compact phone and large text', (tester) async {
    _configurePhone(tester, logicalSize: const Size(320, 568));

    const user = PyreUser(
      id: 'user-pyre-seed',
      username: 'avery_long_username_that_must_ellipsize',
      displayName: 'A Long Display Name For The Fire',
    );

    await tester.pumpWidget(
      _app(
        const PyrePageScreen(user: user),
        textScale: 1.3,
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('My Pyre'), findsOneWidget);
    expect(find.text('Quiet by design'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('Friend Pyre survives compact phone and large text',
      (tester) async {
    _configurePhone(tester, logicalSize: const Size(320, 568));

    await tester.pumpWidget(
      _app(
        FriendPyreScreen(
          displayName:
              'A Very Long Friend Display Name That Must Stay Inside The Pyre',
          seed: 42,
          onLeavePhoto: () {},
        ),
        textScale: 1.3,
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('Friend’s Pyre'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Leave a photo'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Leave a photo'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('No visit notifications. No streak. No score.'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(
      find.text('No visit notifications. No streak. No score.'),
      findsOneWidget,
    );
    _expectNoFlutterError(tester);
  });

  testWidgets('Snap viewer survives long name and caption on compact phone',
      (tester) async {
    _configurePhone(tester, logicalSize: const Size(320, 568));

    await tester.pumpWidget(
      _app(
        SnapViewerScreen(
          snapId: 'snap-1',
          markViewed: true,
          client: _FakeSnapClient(),
        ),
        textScale: 1.35,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(_FakeSnapClient.detail.displayName), findsOneWidget);
    expect(find.text(_FakeSnapClient.detail.caption), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('capture HUD survives compact phone and large text', (tester) async {
    _configurePhone(tester, logicalSize: const Size(320, 568));

    await tester.pumpWidget(
      _app(
        Scaffold(
          backgroundColor: Colors.black,
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
            cameraKitConfigured: false,
            onGoChats: () {},
            onGoProfile: () {},
          ),
        ),
        textScale: 1.35,
      ),
    );
    await tester.pump();

    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    _expectNoFlutterError(tester);

    final gradeButton = find.byIcon(Icons.tune_rounded);
    expect(gradeButton, findsOneWidget);
    await tester.tap(gradeButton);
    await tester.pumpAndSettle();

    expect(find.text('Color'), findsOneWidget);
    _expectNoFlutterError(tester);
  });

  testWidgets('Lens Studio controls survive compact keyboard viewport',
      (tester) async {
    _configurePhone(
      tester,
      logicalSize: const Size(320, 568),
      keyboardLogicalHeight: 250,
    );

    await tester.pumpWidget(
      _app(
        const LensStudioScreen(bootCamera: false),
        textScale: 1.35,
      ),
    );
    await tester.pump();

    expect(find.text('Lens Studio'), findsOneWidget);
    expect(find.text('Lens name'), findsOneWidget);
    expect(find.text('Place sticker'), findsOneWidget);
    _expectNoFlutterError(tester);

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    _expectNoFlutterError(tester);
  });

  testWidgets('bottom nav survives narrow phone and larger text', (tester) async {
    _configurePhone(tester, logicalSize: const Size(320, 568));

    await tester.pumpWidget(
      _app(
        Scaffold(
          bottomNavigationBar: PyreBottomNav(
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
        textScale: 1.3,
      ),
    );
    await tester.pump();

    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    _expectNoFlutterError(tester);
  });
}
