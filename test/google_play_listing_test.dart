import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google Play title and short description stay within limits', () {
    final title = File('store/google-play/en-US/title.txt').readAsStringSync().trim();
    final shortDescription = File('store/google-play/en-US/short-description.txt').readAsStringSync().trim();

    expect(title, 'Pyre Social');
    expect(title.runes.length, lessThanOrEqualTo(30));
    expect(shortDescription.runes.length, lessThanOrEqualTo(80));
  });

  test('Google Play copy preserves the reviewed encryption boundary', () {
    final listing = File('docs/GOOGLE_PLAY_LISTING_PACKAGE.md').readAsStringSync();

    expect(listing, contains('RCS text is **not end-to-end encrypted**'));
    expect(listing, contains('Do not claim:'));
    expect(listing, contains('carrier RCS/GSMA Universal Profile certification'));
    expect(listing, contains('cross-device secret recovery'));
    expect(listing, isNot(contains("private-message text uses Pyre Social's reviewed MLS encryption path")));
  });
}
