import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google Play en-US listing metadata stays within store limits', () {
    final title = File('store/google-play/en-US/title.txt').readAsStringSync().trim();
    final shortDescription =
        File('store/google-play/en-US/short-description.txt').readAsStringSync().trim();
    final fullDescription =
        File('store/google-play/en-US/full-description.txt').readAsStringSync().trim();

    expect(title, isNotEmpty);
    expect(title.length, lessThanOrEqualTo(30));

    expect(shortDescription, isNotEmpty);
    expect(shortDescription.length, lessThanOrEqualTo(80));

    expect(fullDescription, isNotEmpty);
    expect(fullDescription.length, lessThanOrEqualTo(4000));
    expect(fullDescription, contains('independent RCS-style messaging'));
    expect(fullDescription, contains('RCS text is not end-to-end encrypted'));
    expect(fullDescription, contains('https://pyre.social/account/delete'));
    expect(fullDescription, isNot(contains('camera effects')));
    expect(fullDescription.toLowerCase(), isNot(contains('fully end-to-end encrypted')));
    expect(fullDescription.toLowerCase(), isNot(contains('all messages are end-to-end encrypted')));
  });
}
