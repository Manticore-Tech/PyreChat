import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Color grades — mirrors `src/lib/lenses.ts` GRADES.
enum PyreGradeId { none, ember, flame, ash, night, ice }

class PyreGrade {
  const PyreGrade({required this.id, required this.label, this.matrix});

  final PyreGradeId id;
  final String label;

  /// 4×5 color matrix for live [ColorFiltered] preview.
  final List<double>? matrix;
}

abstract final class PyreGrades {
  static const all = [
    PyreGrade(id: PyreGradeId.none, label: 'Original'),
    PyreGrade(
      id: PyreGradeId.ember,
      label: 'Ember',
      matrix: [
        1.12, 0.08, 0.0, 0, 8,
        0.04, 1.02, 0.0, 0, 4,
        0.0, 0.04, 0.88, 0, 0,
        0, 0, 0, 1, 0,
      ],
    ),
    PyreGrade(
      id: PyreGradeId.flame,
      label: 'Flame',
      matrix: [
        1.28, 0.12, 0.0, 0, 12,
        0.06, 1.08, 0.0, 0, 6,
        0.0, 0.02, 0.92, 0, 0,
        0, 0, 0, 1, 0,
      ],
    ),
    PyreGrade(
      id: PyreGradeId.ash,
      label: 'Ash',
      matrix: [
        0.45, 0.45, 0.45, 0, 0,
        0.45, 0.45, 0.45, 0, 0,
        0.45, 0.45, 0.45, 0, 0,
        0, 0, 0, 1, 0,
      ],
    ),
    PyreGrade(
      id: PyreGradeId.night,
      label: 'Night',
      matrix: [
        0.55, 0.15, 0.55, 0, -8,
        0.08, 0.62, 0.55, 0, -8,
        0.12, 0.18, 0.95, 0, -4,
        0, 0, 0, 1, 0,
      ],
    ),
    PyreGrade(
      id: PyreGradeId.ice,
      label: 'Ice',
      matrix: [
        0.72, 0.12, 0.55, 0, 10,
        0.08, 0.88, 0.55, 0, 10,
        0.18, 0.22, 1.18, 0, 12,
        0, 0, 0, 1, 0,
      ],
    ),
  ];

  static PyreGrade byId(PyreGradeId id) =>
      all.firstWhere((g) => g.id == id, orElse: () => all.first);

  static String apiName(PyreGradeId id) => switch (id) {
        PyreGradeId.none => 'none',
        PyreGradeId.ember => 'ember',
        PyreGradeId.flame => 'flame',
        PyreGradeId.ash => 'ash',
        PyreGradeId.night => 'night',
        PyreGradeId.ice => 'ice',
      };

  /// Bake the grade into a captured JPEG.
  static img.Image applyToImage(img.Image source, PyreGradeId id) {
    return switch (id) {
      PyreGradeId.none => source,
      PyreGradeId.ember => img.adjustColor(
          source,
          saturation: 1.35,
          gamma: 1.02,
          contrast: 1.05,
        ),
      PyreGradeId.flame => img.adjustColor(
          source,
          saturation: 1.5,
          contrast: 1.28,
          gamma: 1.04,
        ),
      PyreGradeId.ash => img.grayscale(source),
      PyreGradeId.night => img.adjustColor(
          source,
          saturation: 0.75,
          brightness: 0.88,
          hue: 0.12,
        ),
      PyreGradeId.ice => img.adjustColor(
          source,
          saturation: 1.15,
          brightness: 1.05,
          hue: -0.08,
        ),
    };
  }
}
