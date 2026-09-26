import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

/// Shared warm backdrop for signed-in and onboarding surfaces.
///
/// The goal is warmth without bathing every screen in a single flat orange.
class PyreWarmBackdrop extends StatelessWidget {
  const PyreWarmBackdrop({
    super.key,
    required this.child,
    this.light = false,
  });

  final Widget child;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final gradient = light
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PyreColors.canvas,
              PyreColors.paper,
              PyreColors.canvasWarm,
            ],
            stops: [0, 0.56, 1],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PyreColors.emberDeep,
              PyreColors.ember,
              PyreColors.sunset,
            ],
            stops: [0, 0.48, 1],
          );

    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            right: -100,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (light ? PyreColors.sunset : PyreColors.paper)
                      .withValues(alpha: light ? 0.18 : 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -130,
            child: IgnorePointer(
              child: Container(
                width: 330,
                height: 330,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PyreColors.emberSoft.withValues(
                    alpha: light ? 0.12 : 0.14,
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
