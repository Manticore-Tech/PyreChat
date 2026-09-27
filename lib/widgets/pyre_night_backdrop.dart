import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/services/appearance_prefs.dart';

enum PyreSurfaceMood {
  chats,
  chatThread,
  addFriends,
  myPyre,
  friendPyre,
  profile,
  settings,
}

class _PyreBackdropSpec {
  const _PyreBackdropSpec({
    required this.asset,
    required this.alignment,
    required this.topShade,
    required this.midShade,
    required this.bottomShade,
    this.glowColor,
    this.glowAlpha = 0,
    this.glowAlignment = Alignment.center,
  });

  final String asset;
  final Alignment alignment;
  final double topShade;
  final double midShade;
  final double bottomShade;
  final Color? glowColor;
  final double glowAlpha;
  final Alignment glowAlignment;

  _PyreBackdropSpec copyWith({
    String? asset,
    Alignment? alignment,
  }) {
    return _PyreBackdropSpec(
      asset: asset ?? this.asset,
      alignment: alignment ?? this.alignment,
      topShade: topShade,
      midShade: midShade,
      bottomShade: bottomShade,
      glowColor: glowColor,
      glowAlpha: glowAlpha,
      glowAlignment: glowAlignment,
    );
  }
}

class PyreNightBackdrop extends StatelessWidget {
  const PyreNightBackdrop({
    super.key,
    required this.child,
    this.mood = PyreSurfaceMood.chats,
    this.showEmbers = true,
  });

  final Widget child;
  final PyreSurfaceMood mood;

  // Retained for source compatibility with screens that intentionally choose
  // a calmer background. The photographic assets already contain restrained
  // embers, so no procedural particles are drawn on top.
  final bool showEmbers;

  _PyreBackdropSpec get _moodSpec => switch (mood) {
        PyreSurfaceMood.chats => const _PyreBackdropSpec(
            asset: 'assets/background_night.webp',
            alignment: Alignment(0, -0.62),
            topShade: 0.38,
            midShade: 0.30,
            bottomShade: 0.76,
            glowColor: Color(0xFFFF6A2A),
            glowAlpha: 0.08,
            glowAlignment: Alignment(0.72, -0.14),
          ),
        PyreSurfaceMood.chatThread => const _PyreBackdropSpec(
            asset: 'assets/background_night.webp',
            alignment: Alignment(0, -0.42),
            topShade: 0.60,
            midShade: 0.49,
            bottomShade: 0.88,
          ),
        PyreSurfaceMood.addFriends => const _PyreBackdropSpec(
            asset: 'assets/background_night.webp',
            alignment: Alignment(-0.10, -0.55),
            topShade: 0.48,
            midShade: 0.37,
            bottomShade: 0.82,
          ),
        PyreSurfaceMood.myPyre => const _PyreBackdropSpec(
            asset: 'assets/background_sunset.webp',
            alignment: Alignment(0, -0.36),
            topShade: 0.24,
            midShade: 0.18,
            bottomShade: 0.63,
            glowColor: Color(0xFFFF7A2F),
            glowAlpha: 0.12,
            glowAlignment: Alignment(0.10, 0.10),
          ),
        PyreSurfaceMood.friendPyre => const _PyreBackdropSpec(
            asset: 'assets/background_sunset.webp',
            alignment: Alignment(0.10, -0.30),
            topShade: 0.28,
            midShade: 0.21,
            bottomShade: 0.68,
            glowColor: Color(0xFFFF934E),
            glowAlpha: 0.10,
            glowAlignment: Alignment(0.26, 0.04),
          ),
        PyreSurfaceMood.profile => const _PyreBackdropSpec(
            asset: 'assets/background_ember.webp',
            alignment: Alignment(0, -0.48),
            topShade: 0.40,
            midShade: 0.31,
            bottomShade: 0.78,
            glowColor: Color(0xFFFF5F2B),
            glowAlpha: 0.11,
            glowAlignment: Alignment(0.50, -0.08),
          ),
        PyreSurfaceMood.settings => const _PyreBackdropSpec(
            asset: 'assets/background_night.webp',
            alignment: Alignment(0, -0.45),
            topShade: 0.62,
            midShade: 0.52,
            bottomShade: 0.90,
          ),
      };

  _PyreBackdropSpec _resolveSpec(PyreBackgroundMode mode) {
    final spec = _moodSpec;
    return switch (mode) {
      PyreBackgroundMode.dynamic => spec,
      PyreBackgroundMode.night => spec.copyWith(
          asset: 'assets/background_night.webp',
          alignment: const Alignment(0, -0.50),
        ),
      PyreBackgroundMode.sunset => spec.copyWith(
          asset: 'assets/background_sunset.webp',
          alignment: const Alignment(0, -0.34),
        ),
      PyreBackgroundMode.ember => spec.copyWith(
          asset: 'assets/background_ember.webp',
          alignment: const Alignment(0, -0.42),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final appearance = AppearancePrefs.instance;

    return AnimatedBuilder(
      animation: appearance,
      builder: (context, _) {
        final spec = _resolveSpec(appearance.backgroundMode);
        final visibility = appearance.backgroundVisibility;
        final extraShade = (1.0 - visibility) * 0.42;

        double shade(double base) {
          return (base + extraShade).clamp(0.0, 0.96).toDouble();
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF08090B)),
            Positioned.fill(
              child: Image.asset(
                spec.asset,
                fit: BoxFit.cover,
                alignment: spec.alignment,
                filterQuality: FilterQuality.high,
              ),
            ),
            if (spec.glowColor != null && spec.glowAlpha > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: spec.glowAlignment,
                        radius: 0.94,
                        colors: [
                          spec.glowColor!.withValues(
                            alpha: spec.glowAlpha * visibility,
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0, 1],
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: shade(spec.topShade)),
                        Colors.black.withValues(alpha: shade(spec.midShade)),
                        Colors.black.withValues(alpha: shade(spec.bottomShade)),
                      ],
                      stops: const [0, 0.46, 1],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}
