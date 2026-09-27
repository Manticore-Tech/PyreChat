import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/widgets/pyre_night_backdrop.dart';

void main() {
  testWidgets('surface moods select the approved cinematic background family',
      (tester) async {
    Future<void> expectAsset(PyreSurfaceMood mood, String asset) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PyreNightBackdrop(
            mood: mood,
            child: const SizedBox.expand(),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image).first);
      expect(image.image, isA<AssetImage>());
      expect((image.image as AssetImage).assetName, asset);
    }

    await expectAsset(
      PyreSurfaceMood.chats,
      'assets/background_night.webp',
    );
    await expectAsset(
      PyreSurfaceMood.chatThread,
      'assets/background_night.webp',
    );
    await expectAsset(
      PyreSurfaceMood.addFriends,
      'assets/background_night.webp',
    );
    await expectAsset(
      PyreSurfaceMood.myPyre,
      'assets/background_sunset.webp',
    );
    await expectAsset(
      PyreSurfaceMood.friendPyre,
      'assets/background_sunset.webp',
    );
    await expectAsset(
      PyreSurfaceMood.profile,
      'assets/background_ember.webp',
    );
    await expectAsset(
      PyreSurfaceMood.settings,
      'assets/background_night.webp',
    );

    expect(tester.takeException(), isNull);
  });
}
