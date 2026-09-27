import 'package:flutter/material.dart';

class PyreCampfireBackdrop extends StatelessWidget {
  const PyreCampfireBackdrop({
    super.key,
    required this.child,
    this.dim = 0.0,
  });

  final Widget child;
  final double dim;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF050608)),
        Positioned.fill(
          child: Image.asset(
            'assets/login_background.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
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
                    Colors.black.withValues(alpha: 0.20 + dim),
                    Colors.black.withValues(alpha: 0.02 + dim * 0.35),
                    Colors.black.withValues(alpha: 0.70 + dim * 0.20),
                  ],
                  stops: const [0, 0.52, 1],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
