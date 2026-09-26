import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/capture/custom_lens.dart';

abstract final class CustomLensRenderer {
  static void draw(
    Canvas canvas,
    List<Offset> normPts,
    Size size,
    CustomLensDef lens,
    Map<String, ui.Image> images,
  ) {
    for (final el in lens.elements) {
      if (el.anchorIndex < 0 || el.anchorIndex >= normPts.length) continue;
      final anchor = normPts[el.anchorIndex];
      final img = images[el.asset];
      if (img == null) continue;

      final cx = (anchor.dx + el.offsetX) * size.width;
      final cy = (anchor.dy + el.offsetY) * size.height;
      final faceScale = size.shortestSide * 0.14 * el.scale;
      final w = faceScale;
      final h = faceScale * img.height / img.width;

      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
  }
}
