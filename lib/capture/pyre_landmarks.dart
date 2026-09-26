import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:pyrechat_flutter/capture/coordinates_translator.dart';

/// Normalized landmark (0–1) in [canvasSize] preview space.
typedef NormPt = Offset;

/// Map ML Kit mesh pixels → normalized coords aligned with [CameraPreview].
List<NormPt> meshToNormalized(
  List<Offset> pixels,
  Size imageSize, {
  required Size canvasSize,
  required InputImageRotation rotation,
  required CameraLensDirection lens,
}) {
  if (imageSize.width <= 0 ||
      imageSize.height <= 0 ||
      canvasSize.width <= 0 ||
      canvasSize.height <= 0) {
    return const [];
  }

  return pixels.map((p) {
    final mx = translateX(p.dx, canvasSize, imageSize, rotation, lens);
    final my = translateY(p.dy, canvasSize, imageSize, rotation, lens);
    return Offset(
      (mx / canvasSize.width).clamp(0.0, 1.0),
      (my / canvasSize.height).clamp(0.0, 1.0),
    );
  }).toList(growable: false);
}

List<NormPt> smoothNormPts(List<NormPt>? prev, List<NormPt> next, [double alpha = 0.26]) {
  if (prev == null || prev.length != next.length) return next;
  return List.generate(
    next.length,
    (i) => Offset(
      prev[i].dx * (1 - alpha) + next[i].dx * alpha,
      prev[i].dy * (1 - alpha) + next[i].dy * alpha,
    ),
  );
}

/// Pyre tracking frame — raw mesh in image space; normalize at paint time.
class MeshFrame {
  const MeshFrame({
    required this.pixels,
    required this.imageSize,
    required this.rotation,
    required this.lens,
  });

  final List<Offset> pixels;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lens;
}

/// Pyre tracking frame — normalized coords only, tiny payload for future lens runtime.
class TrackingFrame {
  const TrackingFrame({
    required this.timestampUs,
    required this.normMesh,
  });

  final int timestampUs;
  final List<NormPt> normMesh;
}
