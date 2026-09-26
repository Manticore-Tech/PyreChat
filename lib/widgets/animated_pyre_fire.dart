import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

class AnimatedPyreFire extends StatefulWidget {
  const AnimatedPyreFire({
    super.key,
    this.size = 210,
    this.seed = 1,
    this.intensity = 1,
  });

  final double size;
  final int seed;
  final double intensity;

  @override
  State<AnimatedPyreFire> createState() => _AnimatedPyreFireState();
}

class _AnimatedPyreFireState extends State<AnimatedPyreFire>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _PyreFirePainter(
                t: reduceMotion ? 0.35 : _controller.value,
                seed: widget.seed,
                intensity: widget.intensity,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PyreFirePainter extends CustomPainter {
  const _PyreFirePainter({
    required this.t,
    required this.seed,
    required this.intensity,
  });

  final double t;
  final int seed;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.68);
    final baseWidth = size.width * 0.54;
    final baseHeight = size.height * 0.46;

    final glowRect = Rect.fromCircle(
      center: Offset(center.dx, center.dy - baseHeight * 0.25),
      radius: size.width * 0.44,
    );
    canvas.drawCircle(
      glowRect.center,
      glowRect.width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            PyreColors.emberGlow.withValues(alpha: 0.30 * intensity),
            PyreColors.ember.withValues(alpha: 0.13 * intensity),
            Colors.transparent,
          ],
        ).createShader(glowRect),
    );

    final stonePaint = Paint()..color = const Color(0xFF40332F);
    for (var i = 0; i < 9; i++) {
      final angle = math.pi * (0.1 + i / 8 * 0.8);
      final x = center.dx + math.cos(angle) * baseWidth * 0.46;
      final y = center.dy + math.sin(angle) * baseHeight * 0.13;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: size.width * 0.11,
          height: size.height * 0.055,
        ),
        stonePaint,
      );
    }

    final logPaint = Paint()
      ..color = const Color(0xFF5A2E20)
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - baseWidth * 0.24, center.dy - baseHeight * 0.02),
      Offset(center.dx + baseWidth * 0.22, center.dy + baseHeight * 0.08),
      logPaint,
    );
    canvas.drawLine(
      Offset(center.dx + baseWidth * 0.23, center.dy - baseHeight * 0.02),
      Offset(center.dx - baseWidth * 0.20, center.dy + baseHeight * 0.08),
      logPaint,
    );

    final phase = t * math.pi * 2;
    final sway = math.sin(phase + seed * 0.17) * size.width * 0.025;
    final pulse = 1 + math.sin(phase * 2.1 + seed) * 0.035;

    _drawFlame(
      canvas,
      center: Offset(center.dx + sway, center.dy - baseHeight * 0.04),
      width: baseWidth * 0.63 * pulse,
      height: baseHeight * 1.05 * intensity,
      color: const Color(0xFFFF5C24),
      tipBias: math.sin(phase * 1.3) * 0.16,
    );
    _drawFlame(
      canvas,
      center: Offset(center.dx - sway * 0.35, center.dy - baseHeight * 0.01),
      width: baseWidth * 0.44 * pulse,
      height: baseHeight * 0.84 * intensity,
      color: const Color(0xFFFFA52F),
      tipBias: math.sin(phase * 1.7 + 1.2) * 0.13,
    );
    _drawFlame(
      canvas,
      center: Offset(center.dx + sway * 0.18, center.dy + baseHeight * 0.02),
      width: baseWidth * 0.24 * pulse,
      height: baseHeight * 0.56 * intensity,
      color: const Color(0xFFFFE6A0),
      tipBias: math.sin(phase * 2.2 + 0.4) * 0.08,
    );

    final ember = Paint()..color = const Color(0xFFFFA24D);
    for (var i = 0; i < 12; i++) {
      final randomPhase = (i * 0.173 + t + (seed % 17) * 0.031) % 1.0;
      final rise = randomPhase;
      final side = math.sin((i + seed) * 2.2 + phase) * size.width * 0.12;
      final x = center.dx + side;
      final y = center.dy - baseHeight * (0.15 + rise * 1.05);
      canvas.drawCircle(
        Offset(x, y),
        0.8 + (i % 3) * 0.5,
        Paint()
          ..color = ember.color.withValues(alpha: (1 - rise) * 0.72),
      );
    }
  }

  void _drawFlame(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required Color color,
    required double tipBias,
  }) {
    final bottom = center.dy;
    final top = bottom - height;
    final left = center.dx - width / 2;
    final right = center.dx + width / 2;
    final tipX = center.dx + width * tipBias;

    final path = Path()
      ..moveTo(center.dx, bottom)
      ..cubicTo(
        left - width * 0.05,
        bottom - height * 0.18,
        left + width * 0.06,
        top + height * 0.48,
        tipX,
        top,
      )
      ..cubicTo(
        right - width * 0.02,
        top + height * 0.34,
        right + width * 0.04,
        bottom - height * 0.22,
        center.dx,
        bottom,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.95),
            color,
            color.withValues(alpha: 0.70),
          ],
        ).createShader(
          Rect.fromLTRB(left, top, right, bottom),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _PyreFirePainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.seed != seed ||
        oldDelegate.intensity != intensity;
  }
}
