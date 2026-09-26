import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/capture/pyre_lenses.dart';
import 'package:pyrechat_flutter/theme/pyre_colors.dart';

/// Ports `drawLens` from `src/lib/lenses.ts` for Canvas overlays.
abstract final class LensRenderer {
  static const _ink = PyreColors.ink;
  static const _ember = PyreColors.ember;

  static void draw(
    Canvas canvas,
    List<Offset> pts,
    PyreLensId lens,
    double timeMs,
  ) {
    if (lens == PyreLensId.none || pts.length < 468) return;

    final forehead = _at(pts, 10);
    final chin = _at(pts, 152);
    final leftEye = _at(pts, 33);
    final rightEye = _at(pts, 263);
    final nose = _at(pts, 1);
    final leftCheek = _at(pts, 234);
    final rightCheek = _at(pts, 454);
    final faceH = math.max(80.0, _dist(forehead, chin));
    final eyeSpan = math.max(40.0, _dist(leftEye, rightEye));

    canvas.save();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    switch (lens) {
      case PyreLensId.none:
        break;
      case PyreLensId.skull:
        _drawSkull(canvas, stroke, forehead, chin, leftEye, rightEye, nose, faceH, eyeSpan);
      case PyreLensId.fire:
        _drawFire(canvas, forehead, faceH, eyeSpan, timeMs);
      case PyreLensId.crown:
        _drawCrown(canvas, stroke, forehead, faceH, eyeSpan);
      case PyreLensId.shade:
        _drawShade(canvas, stroke, leftEye, rightEye, faceH, eyeSpan);
      case PyreLensId.ember:
        _drawEmberGlow(canvas, leftCheek, rightCheek, faceH);
    }

    canvas.restore();
  }

  /// Web-style: landmarks normalized 0–1, scaled to [size] inside caller's mirror transform.
  static void drawNormalized(
    Canvas canvas,
    List<Offset> normPts,
    Size size,
    PyreLensId lens,
    double timeMs,
  ) {
    if (lens == PyreLensId.none || normPts.length < 468) return;
    final pts = normPts
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList(growable: false);
    draw(canvas, pts, lens, timeMs);
  }

  static Offset _at(List<Offset> pts, int i) => pts[i];

  static double _dist(Offset a, Offset b) => (a - b).distance;

  static void _drawSkull(
    Canvas canvas,
    Paint stroke,
    Offset forehead,
    Offset chin,
    Offset leftEye,
    Offset rightEye,
    Offset nose,
    double faceH,
    double eyeSpan,
  ) {
    final cx = (leftEye.dx + rightEye.dx) / 2;
    final cy = (forehead.dy + chin.dy) / 2 - faceH * 0.04;
    final rx = eyeSpan * 0.95;
    final ry = faceH * 0.42;

    final bone = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFFF4F0E6), Color(0xFFB9B0A4)],
        stops: const [0, 1],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy - ry * 0.2), radius: rx));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - ry * 0.08), width: rx * 2, height: ry * 2),
      bone,
    );

    final ink = Paint()..color = _ink;
    canvas.drawOval(
      Rect.fromCenter(center: leftEye, width: eyeSpan * 0.36, height: eyeSpan * 0.44),
      ink,
    );
    canvas.drawOval(
      Rect.fromCenter(center: rightEye, width: eyeSpan * 0.36, height: eyeSpan * 0.44),
      ink,
    );

    final ember = Paint()..color = _ember;
    canvas.drawOval(
      Rect.fromCenter(center: leftEye, width: eyeSpan * 0.1, height: eyeSpan * 0.12),
      ember,
    );
    canvas.drawOval(
      Rect.fromCenter(center: rightEye, width: eyeSpan * 0.1, height: eyeSpan * 0.12),
      ember,
    );

    stroke
      ..color = const Color(0xFF2A2420)
      ..strokeWidth = math.max(2.2, faceH * 0.016);
    canvas.drawLine(Offset(cx, nose.dy - 4), Offset(cx, nose.dy + faceH * 0.08), stroke);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, chin.dy - faceH * 0.18),
        width: rx * 0.84,
        height: rx * 0.84,
      ),
      0.12 * math.pi,
      0.76 * math.pi,
      false,
      stroke,
    );
    for (var i = -2; i <= 2; i++) {
      canvas.drawLine(
        Offset(cx + i * rx * 0.12, chin.dy - faceH * 0.2),
        Offset(cx + i * rx * 0.12, chin.dy - faceH * 0.12),
        stroke,
      );
    }
  }

  static void _drawFire(
    Canvas canvas,
    Offset forehead,
    double faceH,
    double eyeSpan,
    double timeMs,
  ) {
    for (var i = 0; i < 9; i++) {
      final t = (i - 4) / 4;
      final flicker = 0.55 + math.sin(timeMs / 90 + i * 1.3) * 0.45;
      final x = forehead.dx + t * eyeSpan * 0.62;
      final y = forehead.dy - faceH * 0.02;
      final hh = faceH * (0.14 + (math.sin(timeMs / 140 + i).abs()) * 0.16) * flicker;
      final paint = Paint()..color = i.isEven ? _ember : const Color(0xFFFF7A2A);
      final path = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x - 12 * flicker, y - hh * 0.5, x + math.sin(timeMs / 80 + i) * 6, y - hh)
        ..quadraticBezierTo(x + 12 * flicker, y - hh * 0.5, x, y);
      canvas.drawPath(path, paint);
    }
    final tip = Paint()..color = const Color(0xFFFFE08A);
    final flame = Path()
      ..moveTo(forehead.dx, forehead.dy)
      ..quadraticBezierTo(
        forehead.dx - 8,
        forehead.dy - faceH * 0.16,
        forehead.dx,
        forehead.dy - faceH * 0.28,
      )
      ..quadraticBezierTo(
        forehead.dx + 8,
        forehead.dy - faceH * 0.16,
        forehead.dx,
        forehead.dy,
      );
    canvas.drawPath(flame, tip);
  }

  static void _drawCrown(
    Canvas canvas,
    Paint stroke,
    Offset forehead,
    double faceH,
    double eyeSpan,
  ) {
    final y = forehead.dy - faceH * 0.12;
    final x0 = forehead.dx - eyeSpan * 0.7;
    final x1 = forehead.dx + eyeSpan * 0.7;
    final fill = Paint()..color = _ember;
    stroke
      ..color = const Color(0xFFFFD27A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(x0, y + 18)
      ..lineTo(x0, y)
      ..lineTo(x0 + (x1 - x0) * 0.2, y + 14)
      ..lineTo(forehead.dx, y - 16)
      ..lineTo(x0 + (x1 - x0) * 0.8, y + 14)
      ..lineTo(x1, y)
      ..lineTo(x1, y + 18)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  static void _drawShade(
    Canvas canvas,
    Paint stroke,
    Offset leftEye,
    Offset rightEye,
    double faceH,
    double eyeSpan,
  ) {
    final r = eyeSpan * 0.28;
    final fill = Paint()..color = const Color(0xFF0B0B0C);
    stroke
      ..color = const Color(0xFFF2E6C9)
      ..strokeWidth = math.max(2, faceH * 0.012)
      ..style = PaintingStyle.stroke;
    final left = RRect.fromRectAndRadius(
      Rect.fromLTWH(leftEye.dx - r, leftEye.dy - r * 0.55, r * 1.9, r * 1.15),
      Radius.circular(r * 0.35),
    );
    final right = RRect.fromRectAndRadius(
      Rect.fromLTWH(rightEye.dx - r * 0.9, rightEye.dy - r * 0.55, r * 1.9, r * 1.15),
      Radius.circular(r * 0.35),
    );
    canvas.drawRRect(left, fill);
    canvas.drawRRect(right, fill);
    canvas.drawRRect(left, stroke);
    canvas.drawRRect(right, stroke);
    canvas.drawLine(
      Offset(leftEye.dx + r * 0.95, (leftEye.dy + rightEye.dy) / 2),
      Offset(rightEye.dx - r * 0.95, (leftEye.dy + rightEye.dy) / 2),
      stroke,
    );
    final shine = Paint()..color = const Color(0x33FFFFFF);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(leftEye.dx - r * 0.15, leftEye.dy - r * 0.12),
        width: r * 0.7,
        height: r * 0.24,
      ),
      shine,
    );
  }

  static void _drawEmberGlow(
    Canvas canvas,
    Offset leftCheek,
    Offset rightCheek,
    double faceH,
  ) {
    for (final cheek in [leftCheek, rightCheek]) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [_ember.withValues(alpha: 0.53), _ember.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: cheek, radius: faceH * 0.22));
      canvas.drawCircle(cheek, faceH * 0.22, paint);
    }
  }
}

class LensPainter extends CustomPainter {
  LensPainter({
    required this.points,
    required this.lens,
    required this.timeMs,
  });

  final List<Offset>? points;
  final PyreLensId lens;
  final double timeMs;

  @override
  void paint(Canvas canvas, Size size) {
    if (points == null) return;
    LensRenderer.draw(canvas, points!, lens, timeMs);
  }

  @override
  bool shouldRepaint(covariant LensPainter oldDelegate) {
    return oldDelegate.lens != lens ||
        oldDelegate.timeMs != timeMs ||
        oldDelegate.points != points;
  }
}
