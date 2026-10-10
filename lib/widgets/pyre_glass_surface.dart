import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/services/appearance_prefs.dart';

enum PyreGlassTone { quiet, standard, strong, ember }

class PyreGlassSurface extends StatelessWidget {
  const PyreGlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = 22,
    this.tone = PyreGlassTone.standard,
    this.blurSigma = 10,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final PyreGlassTone tone;
  final double blurSigma;
  final bool shadow;

  Color _fill(double strength) {
    final base = switch (tone) {
      PyreGlassTone.quiet => const Color(0x66090D12),
      PyreGlassTone.standard => const Color(0x880B1016),
      PyreGlassTone.strong => const Color(0xB80B1016),
      PyreGlassTone.ember => const Color(0xA6160D0B),
    };
    return base.withValues(
      alpha: (base.a * strength).clamp(0.0, 0.96).toDouble(),
    );
  }

  Color _border(AppearancePrefs appearance) {
    final strength = appearance.glassStrength;
    return switch (tone) {
      PyreGlassTone.quiet =>
        Colors.white.withValues(alpha: (0.055 * strength).clamp(0.03, 0.12)),
      PyreGlassTone.standard =>
        Colors.white.withValues(alpha: (0.075 * strength).clamp(0.04, 0.16)),
      PyreGlassTone.strong =>
        Colors.white.withValues(alpha: (0.095 * strength).clamp(0.05, 0.20)),
      PyreGlassTone.ember => appearance.accentColor.withValues(
          alpha: (0.14 * strength).clamp(0.06, 0.26),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    final appearance = AppearancePrefs.instance;
    return AnimatedBuilder(
      animation: appearance,
      builder: (context, _) {
        final strength = appearance.glassStrength;
        return RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: shadow
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: (0.24 * strength).clamp(0.16, 0.34),
                        ),
                        blurRadius: 18,
                        spreadRadius: -10,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blurSigma * strength,
                  sigmaY: blurSigma * strength,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _fill(strength),
                    borderRadius: borderRadius,
                    border: Border.all(color: _border(appearance)),
                  ),
                  child: padding == null
                      ? child
                      : Padding(
                          padding: padding!,
                          child: child,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
