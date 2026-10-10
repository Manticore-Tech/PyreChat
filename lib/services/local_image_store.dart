import 'dart:typed_data';

import 'local_image_store_stub.dart'
    if (dart.library.io) 'local_image_store_io.dart' as implementation;

abstract final class LocalImageStore {
  static Future<String?> write({
    required String name,
    required Uint8List bytes,
  }) {
    return implementation.writeImage(name: name, bytes: bytes);
  }

  static Future<Uint8List?> read(String? path) {
    if (path == null || path.isEmpty) return Future.value(null);
    return implementation.readImage(path);
  }

  static Future<void> delete(String? path) {
    if (path == null || path.isEmpty) return Future.value();
    return implementation.deleteImage(path);
  }
}
