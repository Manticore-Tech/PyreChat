import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/services/appearance_prefs.dart';
import 'package:pyrechat_flutter/services/user_image_picker.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/pyre_glass_surface.dart';
import 'package:pyrechat_flutter/widgets/pyre_night_backdrop.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  static const _builtInModes = <PyreBackgroundMode>[
    PyreBackgroundMode.dynamic,
    PyreBackgroundMode.night,
    PyreBackgroundMode.sunset,
    PyreBackgroundMode.ember,
  ];

  static const _previewAssets = <PyreBackgroundMode, String>{
    PyreBackgroundMode.dynamic: 'assets/background_night.webp',
    PyreBackgroundMode.night: 'assets/background_night.webp',
    PyreBackgroundMode.sunset: 'assets/background_sunset.webp',
    PyreBackgroundMode.ember: 'assets/background_ember.webp',
  };

  Future<void> _chooseCustomBackground(BuildContext context) async {
    try {
      final bytes = await UserImagePicker.pick(UserImagePurpose.background);
      if (bytes == null || !context.mounted) return;
      await AppearancePrefs.instance.setCustomBackground(bytes);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not use that image: $error')),
      );
    }
  }

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
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.55,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Make your Pyre yours.',
                  style: TextStyle(
                    color: PyreColors.nightText,
                    fontSize: 26,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Choose the background for your personal Pyre and the accent used across the app. Chats stay clear and consistent.',
                  style: TextStyle(
                    color: PyreColors.nightMuted,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('YOUR PYRE'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.93,
                  children: [
                    for (final mode in _builtInModes)
                      _BackgroundChoice(
                        mode: mode,
                        image: AssetImage(_previewAssets[mode]!),
                        selected: appearance.backgroundMode == mode,
                        onTap: () {
                          unawaited(appearance.setBackgroundMode(mode));
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _CustomBackgroundCard(
                  bytes: appearance.customBackgroundBytes,
                  selected:
                      appearance.backgroundMode == PyreBackgroundMode.custom,
                  onChoose: () => _chooseCustomBackground(context),
                  onUse: appearance.hasCustomBackground
                      ? () {
                          unawaited(
                            appearance.setBackgroundMode(
                              PyreBackgroundMode.custom,
                            ),
                          );
                        }
                      : null,
                  onRemove: appearance.hasCustomBackground
                      ? () {
                          unawaited(appearance.clearCustomBackground());
                        }
                      : null,
                ),
                const SizedBox(height: 24),
                const _SectionLabel('ACCENT'),
                const SizedBox(height: 10),
                PyreGlassSurface(
                  tone: PyreGlassTone.standard,
                  radius: 18,
                  shadow: false,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: appearance.accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: appearance.accentColor.withValues(
                                    alpha: 0.32,
                                  ),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Accent color',
                              style: TextStyle(
                                color: PyreColors.nightText,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Hue',
                        style: TextStyle(
                          color: PyreColors.nightMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Slider(
                        value: appearance.accentHue,
                        min: 0,
                        max: 360,
                        divisions: 72,
                        activeColor: appearance.accentColor,
                        onChanged: (value) {
                          unawaited(appearance.setAccentHue(value));
                        },
                      ),
                      const Text(
                        'Saturation',
                        style: TextStyle(
                          color: PyreColors.nightMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Slider(
                        value: appearance.accentSaturation,
                        min: 0.25,
                        max: 1.0,
                        divisions: 15,
                        activeColor: appearance.accentColor,
                        onChanged: (value) {
                          unawaited(appearance.setAccentSaturation(value));
                        },
                      ),
                      const Text(
                        'Brightness',
                        style: TextStyle(
                          color: PyreColors.nightMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Slider(
                        value: appearance.accentValue,
                        min: 0.62,
                        max: 1.0,
                        divisions: 19,
                        activeColor: appearance.accentColor,
                        onChanged: (value) {
                          unawaited(appearance.setAccentValue(value));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _TuningCard(
                  title: 'Background intensity',
                  valueLabel: _visibilityLabel(appearance.backgroundVisibility),
                  value: appearance.backgroundVisibility,
                  min: 0.35,
                  max: 1.0,
                  divisions: 13,
                  accent: appearance.accentColor,
                  description: 'Adjust how strongly artwork appears on your Pyre.',
                  onChanged: (value) {
                    unawaited(appearance.setBackgroundVisibility(value));
                  },
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    unawaited(appearance.reset());
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset appearance'),
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

class _CustomBackgroundCard extends StatelessWidget {
  const _CustomBackgroundCard({
    required this.bytes,
    required this.selected,
    required this.onChoose,
    required this.onUse,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final bool selected;
  final VoidCallback onChoose;
  final VoidCallback? onUse;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return PyreGlassSurface(
      tone: selected ? PyreGlassTone.ember : PyreGlassTone.standard,
      radius: 18,
      shadow: false,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 72,
              height: 72,
              child: bytes == null
                  ? const ColoredBox(
                      color: Color(0xFF161A20),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: PyreColors.nightMuted,
                        size: 30,
                      ),
                    )
                  : Image.memory(
                      bytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Custom background',
                        style: TextStyle(
                          color: PyreColors.nightText,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: PyreColors.emberGlow,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  bytes == null
                      ? 'Choose any photo from your device.'
                      : 'Stored locally on this device.',
                  style: const TextStyle(
                    color: PyreColors.nightMuted,
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton(
                      onPressed: onChoose,
                      child: Text(bytes == null ? 'Choose photo' : 'Change'),
                    ),
                    if (bytes != null && !selected)
                      TextButton(
                        onPressed: onUse,
                        child: const Text('Use'),
                      ),
                    if (bytes != null)
                      TextButton(
                        onPressed: onRemove,
                        child: const Text('Remove'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TuningCard extends StatelessWidget {
  const _TuningCard({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.accent,
    required this.description,
    required this.onChanged,
  });

  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color accent;
  final String description;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return PyreGlassSurface(
      tone: PyreGlassTone.standard,
      radius: 18,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: PyreColors.nightText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: PyreColors.nightMuted,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: accent,
            inactiveColor: Colors.white.withValues(alpha: 0.12),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _BackgroundChoice extends StatelessWidget {
  const _BackgroundChoice({
    required this.mode,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  final PyreBackgroundMode mode;
  final ImageProvider image;
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
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppearancePrefs.instance.accentColor
                    : Colors.white.withValues(alpha: 0.10),
                width: selected ? 2 : 1,
              ),
              image: DecorationImage(
                image: image,
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
                        color: AppearancePrefs.instance.accentColor.withValues(
                          alpha: 0.18,
                        ),
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
                          fontWeight: FontWeight.w800,
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
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppearancePrefs.instance.accentColor,
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
