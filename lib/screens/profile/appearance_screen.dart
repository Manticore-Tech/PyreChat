import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/services/appearance_prefs.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/pyre_glass_surface.dart';
import 'package:pyrechat_flutter/widgets/pyre_night_backdrop.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  static const _previewAssets = <PyreBackgroundMode, String>{
    PyreBackgroundMode.dynamic: 'assets/background_night.webp',
    PyreBackgroundMode.night: 'assets/background_night.webp',
    PyreBackgroundMode.sunset: 'assets/background_sunset.webp',
    PyreBackgroundMode.ember: 'assets/background_ember.webp',
  };

  @override
  Widget build(BuildContext context) {
    final appearance = AppearancePrefs.instance;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: PyreColors.night,
      body: AnimatedBuilder(
        animation: appearance,
        builder: (context, _) {
          return PyreNightBackdrop(
            mood: PyreSurfaceMood.settings,
            showEmbers: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(18, top + 10, 18, 34),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.26),
                        foregroundColor: PyreColors.nightText,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Appearance',
                        style: TextStyle(
                          color: PyreColors.nightText,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Make PyreChat yours.',
                  style: TextStyle(
                    color: PyreColors.nightText,
                    fontSize: 26,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Choose the atmosphere you want across the signed-in app. '
                  'The login screen keeps the PyreChat identity.',
                  style: TextStyle(
                    color: PyreColors.nightMuted,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('BACKGROUND'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.93,
                  children: [
                    for (final mode in PyreBackgroundMode.values)
                      _BackgroundChoice(
                        mode: mode,
                        asset: _previewAssets[mode]!,
                        selected: appearance.backgroundMode == mode,
                        onTap: () {
                          unawaited(appearance.setBackgroundMode(mode));
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionLabel('BACKGROUND PRESENCE'),
                const SizedBox(height: 10),
                PyreGlassSurface(
                  tone: PyreGlassTone.standard,
                  radius: 22,
                  shadow: false,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Scene intensity',
                              style: TextStyle(
                                color: PyreColors.nightText,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            _visibilityLabel(appearance.backgroundVisibility),
                            style: const TextStyle(
                              color: PyreColors.emberGlow,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Turn the scenery down when you want the interface to feel quieter.',
                        style: TextStyle(
                          color: PyreColors.nightMuted,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Slider(
                        value: appearance.backgroundVisibility,
                        min: 0.35,
                        max: 1.0,
                        divisions: 13,
                        activeColor: PyreColors.emberGlow,
                        inactiveColor: Colors.white.withValues(alpha: 0.12),
                        onChanged: (value) {
                          unawaited(
                            appearance.setBackgroundVisibility(value),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: appearance.backgroundMode ==
                              PyreBackgroundMode.dynamic &&
                          appearance.backgroundVisibility >= 0.999
                      ? null
                      : () {
                          unawaited(appearance.reset());
                        },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset PyreChat appearance'),
                  style: TextButton.styleFrom(
                    foregroundColor: PyreColors.nightText,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _visibilityLabel(double value) {
    if (value < 0.52) return 'Quiet';
    if (value < 0.78) return 'Balanced';
    return 'Vivid';
  }
}

class _BackgroundChoice extends StatelessWidget {
  const _BackgroundChoice({
    required this.mode,
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final PyreBackgroundMode mode;
  final String asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${mode.label} background',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? PyreColors.emberGlow
                    : Colors.white.withValues(alpha: 0.10),
                width: selected ? 2 : 1,
              ),
              image: DecorationImage(
                image: AssetImage(asset),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(
                    alpha: mode == PyreBackgroundMode.dynamic ? 0.26 : 0.16,
                  ),
                  BlendMode.darken,
                ),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: PyreColors.emberGlow.withValues(alpha: 0.18),
                        blurRadius: 22,
                        spreadRadius: -6,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                if (mode == PyreBackgroundMode.dynamic)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'AUTO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          mode.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: PyreColors.emberGlow,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: PyreColors.nightMuted,
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.15,
      ),
    );
  }
}
