import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const receiverPath =
      'android/app/src/main/kotlin/dev/pyrearms/pyrechat_flutter/'
      'PyreFirebaseMessagingService.kt';

  test('RCS FCM posts a safe visible alert before network fetch', () {
    final source = File(receiverPath).readAsStringSync();
    final rcs = source.indexOf('if (data["type"] == "pyre_rcs_wake")');
    final legacy = source.indexOf('val kind = data["kind"]', rcs);
    expect(rcs, greaterThan(-1));
    expect(legacy, greaterThan(rcs));
    final handler = source.substring(rcs, legacy);
    final fallback = handler.indexOf('body = "New message"');
    final fetch = handler.indexOf('PyreRcsBackgroundDelivery.onWake(this, nativeWake)');
    expect(fallback, greaterThan(-1));
    expect(fetch, greaterThan(fallback),
        reason: 'RCS alert must show before any network/CPIM fetch');
    expect(handler, contains('RCS_HANDLE.matches(handle)'));
    expect(handler, contains('RCS_MESSAGE_ID.matches(messageId)'));
    expect(handler, contains('data["sender"] ?: data["from"]'));
    expect(handler, contains('"from" to sender'));
    expect(handler, contains('PyreRcsBackgroundDelivery.onWake(this, nativeWake)'));
  });

  test('message preview updates same notification without FCM plaintext', () {
    final source = File(receiverPath).readAsStringSync();
    final start = source.indexOf('if (data["type"] == "pyre_rcs_wake")');
    final end = source.indexOf('val kind = data["kind"]', start);
    final handler = source.substring(start, end);
    expect(RegExp(r'notificationIdOverride = rcsNotificationId')
        .allMatches(handler).length, 2);
    expect(handler, contains('PyreRcsNotificationPreferences.previewsEnabled'));
    expect(handler, contains('PyreRcsBackgroundDelivery.notificationPreview'));
    expect(handler, contains('body = preview'));
    expect(source, contains('.setOnlyAlertOnce(notificationIdOverride != null)'));
    expect(source, contains('Manifest.permission.POST_NOTIFICATIONS'));
    expect(source, contains('PyreQuietModeStore.suppressBackgroundNotification'));
  });

  test('initial and preview alerts show the same validated RCS sender title', () {
    final source = File(receiverPath).readAsStringSync();
    final start = source.indexOf('if (data["type"] == "pyre_rcs_wake")');
    final end = source.indexOf('val kind = data["kind"]', start);
    final handler = source.substring(start, end);
    expect(handler, contains(
      'PyreNotificationSenderIdentity.fromRcsHandle(sender) ?: return'));
    expect(handler, contains('val senderTitle = senderIdentity.resolve().title'));
    expect(RegExp(r'title = senderTitle,').allMatches(handler).length, 2,
        reason: 'Initial and preview updates must retain one sender identity');
    expect(handler, isNot(contains('title = "Pyre Social"')));
    expect(handler.indexOf('val senderTitle'), lessThan(
      handler.indexOf('body = "New message"')));
    expect(handler, isNot(contains('data["displayName"]')));
    expect(handler, isNot(contains('data["pyreNumber"]')));
    expect(handler, isNot(contains('data["contactName"]')));
  });

  test('notification identity layers retain RCS address as the safe default', () {
    const identityPath =
        'android/app/src/main/kotlin/dev/pyrearms/pyrechat_flutter/'
        'PyreNotificationSenderIdentity.kt';
    final source = File(identityPath).readAsStringSync();
    expect(source, contains(r'"sip:$rcsHandle@messages.pyre.social"'));
    expect(source, contains('RCS_HANDLE.matches(value)'));
    final contact = source.indexOf('safeLabel(localContactName)?.let');
    final number = source.indexOf('safeLabel(verifiedPyreNumber)?.let');
    final fallback = source.indexOf(
      'rcsAddress, PyreNotificationIdentityLayer.RCS_ADDRESS');
    expect(contact, greaterThan(-1));
    expect(number, greaterThan(contact));
    expect(fallback, greaterThan(number));
    expect(source, contains('Character.isISOControl(it)'));
    expect(source, contains('trusted, address-bound lookups'));
  });
}
