import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/capture/custom_lens.dart';
import 'package:pyrechat_flutter/capture/custom_lens_renderer.dart';
import 'package:pyrechat_flutter/capture/lens_renderer.dart';
import 'package:pyrechat_flutter/capture/pyre_landmarks.dart';
import 'package:pyrechat_flutter/capture/pyre_lenses.dart';

/// Transparent AR overlay — native camera preview stays underneath.
class ArOverlayPainter extends CustomPainter {
  ArOverlayPainter({
    required this.frame,
    required this.lens,
    this.customLens,
    this.stickerImages = const {},
    required this.timeMs,
  });

  final MeshFrame? frame;
  final PyreLensId lens;
  final CustomLensDef? customLens;
  final Map<String, ui.Image> stickerImages;
  final double timeMs;

  @override
  void paint(Canvas canvas, Size size) {
    final mesh = frame;
    if (mesh == null || mesh.pixels.length < 468) return;

    final norm = meshToNormalized(
      mesh.pixels,
      mesh.imageSize,
      canvasSize: size,
      rotation: mesh.rotation,
      lens: mesh.lens,
    );
    if (norm.length < 468) return;

    if (lens != PyreLensId.none) {
      LensRenderer.drawNormalized(canvas, norm, size, lens, timeMs);
    }
    if (customLens != null) {
      CustomLensRenderer.draw(
        canvas,
        norm,
        size,
        customLens!,
        stickerImages,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ArOverlayPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.lens != lens ||
        oldDelegate.customLens != customLens ||
        oldDelegate.timeMs != timeMs;
  }
}
