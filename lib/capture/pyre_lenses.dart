/// AR face-locked overlays — mirrors `src/lib/lenses.ts` LENSES.
enum PyreLensId { none, skull, fire, crown, shade, ember }

class PyreLens {
  const PyreLens({required this.id, required this.label});

  final PyreLensId id;
  final String label;
}

abstract final class PyreLenses {
  static const all = [
    PyreLens(id: PyreLensId.none, label: 'Off'),
    PyreLens(id: PyreLensId.skull, label: 'Skull'),
    PyreLens(id: PyreLensId.fire, label: 'Fire'),
    PyreLens(id: PyreLensId.crown, label: 'Crown'),
    PyreLens(id: PyreLensId.shade, label: 'Shades'),
    PyreLens(id: PyreLensId.ember, label: 'Ember'),
  ];

  /// Thumbnail icons for the lens carousel.
  static String? iconAsset(PyreLensId id) => switch (id) {
        PyreLensId.none => null,
        PyreLensId.skull => 'assets/icons/profile_flame.png',
        PyreLensId.fire => 'assets/icons/flame.png',
        PyreLensId.crown => 'assets/icons/star_filled.png',
        PyreLensId.shade => 'assets/icons/eye_off.png',
        PyreLensId.ember => 'assets/icons/flame_sparkle.png',
      };

  static String apiName(PyreLensId id) => switch (id) {
        PyreLensId.none => 'none',
        PyreLensId.skull => 'skull',
        PyreLensId.fire => 'fire',
        PyreLensId.crown => 'crown',
        PyreLensId.shade => 'shade',
        PyreLensId.ember => 'ember',
      };
}
