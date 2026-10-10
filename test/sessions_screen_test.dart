import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/models/session.dart';
import 'package:pyrechat_flutter/screens/profile/sessions_screen.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';

class _FakePyreClient extends PyreClient {
  _FakePyreClient({
    required Future<List<PyreSession>> sessionsFuture,
    this.sessionsError,
    Future<bool>? revokeFuture,
  })  : _sessionsFuture = sessionsFuture,
        _revokeFuture = revokeFuture ?? Future<bool>.value(false);

  final Future<List<PyreSession>> _sessionsFuture;
  final Object? sessionsError;
  final Future<bool> _revokeFuture;
  final List<String> revokedIds = [];

  @override
  Future<List<PyreSession>> sessions() async {
    if (sessionsError case final error?) throw error;
    return _sessionsFuture;
  }

  @override
  Future<bool> revokeSession(String sessionId) {
    revokedIds.add(sessionId);
    return _revokeFuture;
  }
}

void main() {
  testWidgets('signed-in devices loading state is announced accessibly',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final completer = Completer<List<PyreSession>>();
    final client = _FakePyreClient(sessionsFuture: completer.future);

    await tester.pumpWidget(
      MaterialApp(home: SessionsScreen(client: client)),
    );
    await tester.pump();

    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Loading signed-in devices'),
      ),
      matchesSemantics(
        label: 'Loading signed-in devices',
        isLiveRegion: true,
      ),
    );

    completer.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('No active sessions were returned.'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('signed-in devices errors are announced and remain retryable',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final client = _FakePyreClient(
      sessionsFuture: Future<List<PyreSession>>.value(const []),
      sessionsError: PyreApiException('Session lookup failed', 503),
    );

    await tester.pumpWidget(
      MaterialApp(home: SessionsScreen(client: client)),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(
        find.bySemanticsLabel(
          'Signed-in devices error: Service temporarily unavailable. Try again shortly.',
        ),
      ),
      matchesSemantics(
        label: 'Signed-in devices error: Service temporarily unavailable. Try again shortly.',
        isLiveRegion: true,
      ),
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Session lookup failed'), findsNothing);

    semantics.dispose();
  });

  testWidgets('session revocation errors do not expose backend details',
      (tester) async {
    final completer = Completer<bool>();
    final client = _FakePyreClient(
      sessionsFuture: Future<List<PyreSession>>.value([
        const PyreSession(
          id: 'current',
          label: 'This phone',
          current: true,
        ),
        const PyreSession(
          id: 'other',
          label: 'Other phone',
          current: false,
        ),
      ]),
      revokeFuture: completer.future,
    );

    await tester.pumpWidget(
      MaterialApp(home: SessionsScreen(client: client)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pump();
    expect(client.revokedIds, ['other']);

    completer.completeError(
      PyreApiException('Internal session token diagnostic', 403),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('You cannot manage these signed-in devices.'),
      findsOneWidget,
    );
    expect(find.text('Internal session token diagnostic'), findsNothing);
    expect(find.bySemanticsLabel('Sign out Other phone'), findsOneWidget);
  });

  testWidgets('session revoke control exposes progress semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final revokeCompleter = Completer<bool>();
    final client = _FakePyreClient(
      sessionsFuture: Future<List<PyreSession>>.value(
        [
          PyreSession(
            id: 'current',
            label: 'Pixel 9',
            current: true,
            createdAt: DateTime.utc(2026, 10, 7, 12),
          ),
          PyreSession(
            id: 'laptop',
            label: 'Laptop',
            current: false,
            createdAt: DateTime.utc(2026, 10, 6, 12),
          ),
        ],
      ),
      revokeFuture: revokeCompleter.future,
    );

    await tester.pumpWidget(
      MaterialApp(home: SessionsScreen(client: client)),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Pixel 9, this device'), findsOneWidget);
    expect(find.bySemanticsLabel('Sign out Laptop'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out this session?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pump();

    expect(client.revokedIds, ['laptop']);
    expect(
      tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.refresh_rounded),
      ).onPressed,
      isNull,
      reason: 'Do not refresh a stale device list while session revocation is pending.',
    );
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Signing out Laptop'),
      ),
      matchesSemantics(
        label: 'Signing out Laptop',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        isLiveRegion: true,
      ),
    );

    revokeCompleter.complete(false);
    await tester.pumpAndSettle();

    expect(find.text('Session signed out.'), findsOneWidget);
    expect(find.bySemanticsLabel('Sign out Laptop'), findsNothing);

    semantics.dispose();
  });

  testWidgets('current device is first and expired sessions are obvious',
      (tester) async {
    final client = _FakePyreClient(
      sessionsFuture: Future<List<PyreSession>>.value(
        [
          PyreSession(
            id: 'expired-laptop',
            label: 'Old laptop',
            current: false,
            createdAt: DateTime(2026, 10, 7, 9),
            expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
          PyreSession(
            id: 'current',
            label: 'Pixel 9',
            current: true,
            createdAt: DateTime(2026, 10, 6, 12),
            expiresAt: DateTime.now().add(const Duration(days: 30)),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: SessionsScreen(client: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Expired'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Pixel 9')).dy,
      lessThan(tester.getTopLeft(find.text('Old laptop')).dy),
    );
  });
}
