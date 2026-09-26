import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

enum PyreNightMood { night, sunset, ember }

class PyreNightBackdrop extends StatelessWidget {
  const PyreNightBackdrop({
    super.key,
    required this.child,
    this.mood = PyreNightMood.night,
    this.showEmbers = true,
  });

  final Widget child;
  final PyreNightMood mood;
  final bool showEmbers;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _PyreNightPainter(
              mood: mood,
              showEmbers: showEmbers,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _PyreNightPainter extends CustomPainter {
  const _PyreNightPainter({
    required this.mood,
    required this.showEmbers,
  });

  final PyreNightMood mood;
  final bool showEmbers;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final colors = switch (mood) {
      PyreNightMood.night => const [
          Color(0xFF08111B),
          Color(0xFF0C1724),
          Color(0xFF111925),
          Color(0xFF171516),
        ],
      PyreNightMood.sunset => const [
          Color(0xFF14101B),
          Color(0xFF2A1730),
          Color(0xFF70302B),
          Color(0xFFDF633D),
        ],
      PyreNightMood.ember => const [
          Color(0xFF100C0D),
          Color(0xFF1C1111),
          Color(0xFF361716),
          Color(0xFF5D241C),
        ],
    };

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: const [0, 0.38, 0.72, 1],
        ).createShader(rect),
    );

    final horizon = size.height * 0.55;
    final glowCenter = Offset(size.width * 0.72, horizon * 0.92);
    final glowRect = Rect.fromCircle(
      center: glowCenter,
      radius: size.shortestSide * 0.65,
    );
    canvas.drawCircle(
      glowCenter,
      size.shortestSide * 0.65,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF8248).withValues(
              alpha: mood == PyreNightMood.night ? 0.10 : 0.25,
            ),
            Colors.transparent,
          ],
        ).createShader(glowRect),
    );

    final mountainBack = Path()
      ..moveTo(0, horizon)
      ..lineTo(size.width * 0.12, horizon - size.height * 0.06)
      ..lineTo(size.width * 0.25, horizon - size.height * 0.015)
      ..lineTo(size.width * 0.42, horizon - size.height * 0.11)
      ..lineTo(size.width * 0.58, horizon - size.height * 0.035)
      ..lineTo(size.width * 0.73, horizon - size.height * 0.13)
      ..lineTo(size.width * 0.9, horizon - size.height * 0.045)
      ..lineTo(size.width, horizon - size.height * 0.08)
      ..lineTo(size.width, horizon + size.height * 0.22)
      ..lineTo(0, horizon + size.height * 0.22)
      ..close();

    canvas.drawPath(
      mountainBack,
      Paint()..color = const Color(0xFF0A1118).withValues(alpha: 0.78),
    );

    final mountainFront = Path()
      ..moveTo(0, horizon + size.height * 0.08)
      ..lineTo(size.width * 0.16, horizon + size.height * 0.02)
      ..lineTo(size.width * 0.29, horizon + size.height * 0.07)
      ..lineTo(size.width * 0.47, horizon - size.height * 0.015)
      ..lineTo(size.width * 0.63, horizon + size.height * 0.06)
      ..lineTo(size.width * 0.82, horizon)
      ..lineTo(size.width, horizon + size.height * 0.04)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      mountainFront,
      Paint()..color = const Color(0xFF080C10).withValues(alpha: 0.92),
    );

    final lakeTop = horizon + size.height * 0.1;
    final lakeRect = Rect.fromLTWH(
      0,
      lakeTop,
      size.width,
      math.max(0, size.height - lakeTop),
    );
    if (lakeRect.height > 0) {
      canvas.drawRect(
        lakeRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF111A22).withValues(alpha: 0.80),
              const Color(0xFF05090D).withValues(alpha: 0.98),
            ],
          ).createShader(lakeRect),
      );
    }

    final ridge = Paint()
      ..color = const Color(0xFFFF8D52).withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = lakeTop + 18 + i * 18;
      canvas.drawLine(
        Offset(size.width * (0.45 - i * 0.02), y),
        Offset(size.width * (0.78 + i * 0.018), y),
        ridge,
      );
    }

    if (showEmbers) {
      final emberPaint = Paint()..color = PyreColors.emberGlow;
      for (var i = 0; i < 22; i++) {
        final fx = ((i * 73) % 101) / 101;
        final fy = ((i * 47) % 89) / 89;
        final x = size.width * fx;
        final y = size.height * (0.16 + fy * 0.62);
        final radius = i % 5 == 0 ? 1.6 : 0.8;
        canvas.drawCircle(
          Offset(x, y),
          radius,
          Paint()
            ..color = emberPaint.color.withValues(
              alpha: 0.14 + (i % 4) * 0.06,
            ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PyreNightPainter oldDelegate) {
    return oldDelegate.mood != mood || oldDelegate.showEmbers != showEmbers;
  }
}
