import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/widgets/pyre_night_backdrop.dart';

void main() {
  testWidgets('utility surfaces stay calm while personal Pyres keep artwork',
      (tester) async {
    Future<void> expectArtwork(PyreSurfaceMood mood, bool expected) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PyreNightBackdrop(
            mood: mood,
            child: const SizedBox.expand(),
          ),
        ),
      );

      expect(find.byType(Image), expected ? findsWidgets : findsNothing);
      expect(tester.takeException(), isNull);
    }

    await expectArtwork(PyreSurfaceMood.chats, false);
    await expectArtwork(PyreSurfaceMood.chatThread, false);
    await expectArtwork(PyreSurfaceMood.addFriends, false);
    await expectArtwork(PyreSurfaceMood.profile, false);
    await expectArtwork(PyreSurfaceMood.settings, false);

    await expectArtwork(PyreSurfaceMood.myPyre, true);
    await expectArtwork(PyreSurfaceMood.friendPyre, true);
  });
}
