import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// User-authored lens: stickers locked to face landmark indices.
class CustomLensDef {
  const CustomLensDef({
    required this.id,
    required this.name,
    required this.elements,
  });

  final String id;
  final String name;
  final List<CustomLensElement> elements;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'elements': elements.map((e) => e.toJson()).toList(),
      };

  factory CustomLensDef.fromJson(Map<String, dynamic> json) {
    return CustomLensDef(
      id: json['id'] as String,
      name: json['name'] as String,
      elements: (json['elements'] as List<dynamic>)
          .map((e) => CustomLensElement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CustomLensElement {
  const CustomLensElement({
    required this.anchorIndex,
    required this.asset,
    this.scale = 1,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  /// MediaPipe / ML Kit face mesh landmark index.
  final int anchorIndex;
  final String asset;
  final double scale;
  final double offsetX;
  final double offsetY;

  Map<String, dynamic> toJson() => {
        'anchorIndex': anchorIndex,
        'asset': asset,
        'scale': scale,
        'offsetX': offsetX,
        'offsetY': offsetY,
      };

  factory CustomLensElement.fromJson(Map<String, dynamic> json) {
    return CustomLensElement(
      anchorIndex: json['anchorIndex'] as int,
      asset: json['asset'] as String,
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Landmark anchor presets for the lens studio UI.
class LensAnchors {
  static const presets = <int, String>{
    10: 'Forehead',
    1: 'Nose',
    33: 'Left eye',
    263: 'Right eye',
    152: 'Chin',
    234: 'Left cheek',
    454: 'Right cheek',
  };
}

abstract final class CustomLensStore {
  static const _key = 'pyre_custom_lenses_v1';

  static Future<List<CustomLensDef>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => CustomLensDef.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> saveAll(List<CustomLensDef> lenses) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(lenses.map((l) => l.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  static Future<void> upsert(CustomLensDef lens) async {
    final all = await loadAll();
    final next = [...all.where((l) => l.id != lens.id), lens];
    await saveAll(next);
  }

  static Future<void> remove(String id) async {
    final all = await loadAll();
    await saveAll(all.where((l) => l.id != id).toList());
  }
}
