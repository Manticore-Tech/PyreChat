import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

enum PyreGlassTone { quiet, standard, strong, ember }

class PyreGlassSurface extends StatelessWidget {
  const PyreGlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = 22,
    this.tone = PyreGlassTone.standard,
    this.blurSigma = 14,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final PyreGlassTone tone;
  final double blurSigma;
  final bool shadow;

  Color get _fill => switch (tone) {
        PyreGlassTone.quiet => const Color(0x73090D12),
        PyreGlassTone.standard => const Color(0x990B1016),
        PyreGlassTone.strong => const Color(0xCC0B1016),
        PyreGlassTone.ember => const Color(0xA6160D0B),
      };

  Color get _border => switch (tone) {
        PyreGlassTone.quiet => Colors.white.withValues(alpha: 0.055),
        PyreGlassTone.standard => Colors.white.withValues(alpha: 0.075),
        PyreGlassTone.strong => Colors.white.withValues(alpha: 0.095),
        PyreGlassTone.ember => PyreColors.emberGlow.withValues(alpha: 0.14),
      };

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 24,
                    spreadRadius: -8,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _fill,
                borderRadius: borderRadius,
                border: Border.all(color: _border),
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
  }
}
