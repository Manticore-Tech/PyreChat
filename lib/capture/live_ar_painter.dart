import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/capture/custom_lens.dart';
import 'package:pyrechat_flutter/capture/custom_lens_renderer.dart';
import 'package:pyrechat_flutter/capture/lens_renderer.dart';
import 'package:pyrechat_flutter/capture/pyre_lenses.dart';

/// Paints camera frame + AR lens on one canvas — mirrors web `drawCaptureFrame`.
class LiveArPainter extends CustomPainter {
  LiveArPainter({
    required this.frame,
    required this.normPts,
    required this.mirror,
    this.gradeMatrix,
    required this.lens,
    this.customLens,
    this.stickerImages = const {},
    required this.timeMs,
  });

  final ui.Image? frame;
  final List<Offset>? normPts;
  final bool mirror;
  final List<double>? gradeMatrix;
  final PyreLensId lens;
  final CustomLensDef? customLens;
  final Map<String, ui.Image> stickerImages;
  final double timeMs;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (mirror) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    if (frame != null) {
      if (gradeMatrix != null) {
        canvas.saveLayer(
          Offset.zero & size,
          Paint()..colorFilter = ColorFilter.matrix(gradeMatrix!),
        );
        _paintCover(canvas, size, frame!);
        canvas.restore();
      } else {
        _paintCover(canvas, size, frame!);
      }
    } else {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF141618));
    }

    final pts = normPts;
    if (pts != null && pts.length >= 468) {
      if (lens != PyreLensId.none) {
        LensRenderer.drawNormalized(canvas, pts, size, lens, timeMs);
      }
      if (customLens != null) {
        CustomLensRenderer.draw(canvas, pts, size, customLens!, stickerImages);
      }
    }

    canvas.restore();
  }

  static void _paintCover(Canvas canvas, Size size, ui.Image image) {
  final srcW = image.width.toDouble();
  final srcH = image.height.toDouble();
  final scale = math.max(size.width / srcW, size.height / srcH);
  final dstW = srcW * scale;
  final dstH = srcH * scale;
  final dx = (size.width - dstW) / 2;
  final dy = (size.height - dstH) / 2;
  final paint = Paint()..filterQuality = FilterQuality.medium;
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, srcW, srcH),
    Rect.fromLTWH(dx, dy, dstW, dstH),
    paint,
  );
}

  @override
  bool shouldRepaint(covariant LiveArPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.normPts != normPts ||
        oldDelegate.mirror != mirror ||
        oldDelegate.lens != lens ||
        oldDelegate.customLens != customLens ||
        oldDelegate.timeMs != timeMs ||
        oldDelegate.gradeMatrix != gradeMatrix;
  }
}
